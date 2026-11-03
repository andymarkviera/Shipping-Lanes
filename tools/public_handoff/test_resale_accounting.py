"""Production transitions/receipt dispatch with an explicit SQL double, not PostgreSQL."""
import copy
import unittest
from test_ship_purchase import MemoryDB, ACCOUNT
from authority import Authority, Rejected
import resale
import voyages
import voyage_accounting

class ResaleAccountingTest(unittest.TestCase):
    def setUp(self):
        self.p = dict(ship=dict(id='active', definition='ship_starter_container_01', condition_bp=9000,
                     fuel_liters=500, position=dict(latitude=0, longitude=0, heading=0)),
                     stored_ships=[dict(id='stored', definition='ship_coastal_container_01', condition_bp=5000,
                     acquisition_cost_minor=90000, storage_port_id=voyages.PORTS[0])], cargo=[], jobs=[], delivered=[])
        self.row = dict(profile=copy.deepcopy(self.p), money=300000, revision=1)
        self.db = MemoryDB(self.row)
        self.a = Authority({})
        self.n = 0
    def call(self, op, **fields):
        self.n += 1
        r = dict(realm='public', op=op, account=ACCOUNT, epoch=1, generation=1,
                 action_id='action_'+str(self.n), expected_revision=self.row['revision'], **fields)
        self.a._validate(r)
        result = self.a._voyage(self.db, ACCOUNT, copy.deepcopy(self.row), r)
        return result, r
    def sale(self):
        return self.call('ship_resale', port_id=voyages.PORTS[0], ship_id='stored', value_minor=27000)
    def test_sale_reconciles_debt_and_replay(self):
        self.row['profile']['recovery_debt_minor'] = 20000
        first, req = self.sale()
        self.assertTrue(first['ok'])
        self.assertEqual(first['resale'], dict(ship_id='stored', gross_minor=27000, recovery_repaid_minor=13500,
                         wallet_delta_minor=13500, wallet_before_minor=300000, wallet_after_minor=313500))
        self.assertEqual(self.row['profile']['ship'], self.p['ship'])
        self.assertFalse(self.row['profile']['stored_ships'])
        replay = self.a._voyage(self.db, ACCOUNT, copy.deepcopy(self.row), req)
        self.assertTrue(replay.pop('duplicate')); self.assertEqual(replay, first)
        self.assertEqual(len(self.db.journal), 1)
        with self.assertRaises(Rejected):
            self.a._voyage(self.db, ACCOUNT, copy.deepcopy(self.row), dict(req, value_minor=1))
        self.assertEqual(self.sale()[0]['code'], 'SHIP_NOT_STORED')
    def test_restrictions_preserve_everything(self):
        for change, expected in [
            (lambda p:p.update(cargo=[dict(id='cargo')]), 'FLEET_LOADED'),
            *[(lambda p, state=state:p.update(jobs=[dict(state=state)]), 'FLEET_LOADED') for state in ['loading','loaded','unknown','active']],
            (lambda p:p['stored_ships'][0].update(cargo=[dict(id='x')]), 'FLEET_LOADED'),
            (lambda p:p['stored_ships'][0].update(jobs=[dict(state='unknown')]), 'FLEET_LOADED'),
            (lambda p:p['stored_ships'][0].update(storage_port_id=voyages.PORTS[1]), 'FLEET_WRONG_PORT'),
            (lambda p:p['stored_ships'].append(copy.deepcopy(p['stored_ships'][0])), 'OWNED_ID_CONFLICT'),
            (lambda p:p['ship'].update(condition_bp=0), 'RECOVERY_REQUIRED'),
            (lambda p:p.update(recovery=dict(state='pending')), 'RECOVERY_REQUIRED'),
            (lambda p:p['stored_ships'][0].update(definition='unknown'), 'RESALE_UNAVAILABLE')]:
            with self.subTest(expected=expected):
                self.row['profile'] = copy.deepcopy(self.p); change(self.row['profile'])
                before = copy.deepcopy(self.row)
                self.assertEqual(self.sale()[0]['code'], expected)
                self.assertEqual(self.row, before)
        self.assertFalse(self.db.journal)
    def test_unfueled_active_ship_must_remain_refuelable(self):
        self.row['profile']['ship']['fuel_liters'] = 0
        self.row['profile']['stored_ships'][0]['condition_bp'] = 1
        self.row['money'] = 0
        result, _ = self.call('ship_resale', port_id=voyages.PORTS[0], ship_id='stored', value_minor=5)
        self.assertEqual(result['code'], 'KEEP_USABLE_SHIP')
        self.assertEqual(len(self.row['profile']['stored_ships']), 1)
        self.row['money'] = 25
        result, _ = self.call('ship_resale', port_id=voyages.PORTS[0], ship_id='stored', value_minor=5)
        self.assertTrue(result['ok'])
    def test_active_and_last_ship_never_sold(self):
        self.row['profile']['stored_ships'] = []
        result, _ = self.call('ship_resale', port_id=voyages.PORTS[0], ship_id='active', value_minor=27000)
        self.assertEqual(result['code'], 'ACTIVE_SHIP_RETAINED')
        self.assertEqual(self.row['profile']['ship'], self.p['ship'])
    def test_price_treasury_stale_strict_and_failed_replay(self):
        self.db.money = 0
        result, req = self.sale()
        self.assertEqual(result['code'], 'INSUFFICIENT_RESOURCES')
        self.db.money = 1000000
        self.assertEqual(self.a._voyage(self.db, ACCOUNT, copy.deepcopy(self.row), req)['code'], result['code'])
        self.assertEqual(self.call('ship_resale', port_id=voyages.PORTS[0], ship_id='stored', value_minor=1)[0]['code'], 'QUOTE_CHANGED')
        for change in [dict(value_minor=True),dict(value_minor=-1),dict(recipient='other'),dict(ship_id='../id'),dict(value_minor=1.5)]:
            with self.assertRaises(Rejected): self.a._validate(dict(req, **change))
        self.assertEqual(self.a._voyage(self.db, ACCOUNT, copy.deepcopy(dict(self.row,revision=99)),dict(req,action_id='stale'))['code'], 'STALE_REVISION')
    def test_valuation_rounding_cap_legacy_and_configuration(self):
        ship = self.p['stored_ships'][0]
        for condition in range(1,10001):
            self.assertEqual(resale.value(dict(ship, condition_bp=condition)),90000*6000*condition//100000000)
        self.assertEqual(resale.value(dict(ship, acquisition_cost_minor=10000)), 3000)
        legacy = dict(ship);legacy.pop('acquisition_cost_minor')
        self.assertEqual(resale.value(legacy),27000)
        key = ship['definition'];old=resale.VALUATION[key]
        try:
            resale.VALUATION[key]=5000;self.assertEqual(resale.value(ship),22500)
            resale.VALUATION[key]=10001;self.assertIsNone(resale.value(ship))
        finally: resale.VALUATION[key]=old
    def start_loaded(self):
        accepted, _ = self.call('voyage_accept', port_id=voyages.PORTS[0], offer_id='container_seed_v1_0_0')
        self.assertTrue(accepted['ok'])
        job = self.row['profile']['jobs'][-1];job['ready_ms']=0
        self.assertTrue(self.call('voyage_load', port_id=voyages.PORTS[0], job_id=job['id'])[0]['ok'])
        return job['id']
    def test_full_cash_window_and_replayed_delivery(self):
        job = self.start_loaded()
        self.assertTrue(self.call('refuel',port_id=voyages.PORTS[0],liters=100,unit_price_minor=25)[0]['ok'])
        self.assertTrue(self.call('repair',port_id=voyages.PORTS[0],condition_bp=9000,cost_minor=2500)[0]['ok'])
        self.assertTrue(self.call('ship_purchase',port_id=voyages.PORTS[0],definition_id='ship_starter_container_01',cost_minor=50000)[0]['ok'])
        self.row['profile']['recovery_debt_minor']=10000
        result, req = self.call('voyage_deliver',port_id=voyages.PORTS[1],job_id=job)
        report=result['voyage_report']
        self.assertEqual((report['gross_revenue_minor'],report['acquisition_cost_minor'],report['fuel_minor'],report['repair_minor']), (25000,50000,2500,2500))
        self.assertEqual(report['recovery_repaid_minor'],10000)
        self.assertEqual(report['net_minor'],-40000)
        self.assertEqual(report['net_minor'], self.row['money']-300000)
        self.assertEqual(sum(j[2] for j in self.db.journal),report['net_minor'])
        self.assertEqual(self.a._voyage(self.db,ACCOUNT,copy.deepcopy(self.row),req)['voyage_report'],report)
        self.assertNotIn('voyage_accounting',self.row['profile'])
        self.assertEqual(self.row['profile']['last_voyage_report'],report)
    def test_cancel_and_sinking_close_costs_once(self):
        for close in ['cancel','sink']:
            self.setUp();job=self.start_loaded()
            self.call('refuel',port_id=voyages.PORTS[0],liters=10,unit_price_minor=25)
            if close=='cancel': result,_=self.call('voyage_cancel',job_id=job,abandon=True)
            else: result,_=self.call('impact',damage_bp=10000,fuel_liters=510,position=self.p['ship']['position'])
            report=result['voyage_report']
            self.assertEqual(report['net_minor'],self.row['money']-300000)
            self.assertEqual(report['gross_revenue_minor'],0)
            self.assertEqual(report['recovery_paid_minor'],25000 if close=='sink' else 0)
            self.assertFalse(self.row['profile']['cargo'])
            self.assertNotIn('voyage_accounting',self.row['profile'])
    def test_legacy_partial_and_restart_retention(self):
        job=self.start_loaded();self.row['profile'].pop('voyage_accounting')
        result,_=self.call('refuel',port_id=voyages.PORTS[0],liters=10,unit_price_minor=25)
        self.assertTrue(result['voyage_report']['partial'])
        self.a=Authority({}) # persisted profile is the sole accounting source
        report=self.call('voyage_deliver',port_id=voyages.PORTS[1],job_id=job)[0]['voyage_report']
        self.assertEqual(report['net_minor'],24750)
        self.assertTrue(report['partial'])
    def test_no_phantom_costs_before_acceptance_and_no_failed_debits(self):
        self.call('refuel',port_id=voyages.PORTS[0],liters=10,unit_price_minor=25)
        self.assertNotIn('voyage_accounting',self.row['profile'])
        self.start_loaded();before=copy.deepcopy(self.row)
        result,_=self.call('refuel',port_id=voyages.PORTS[0],liters=1000,unit_price_minor=25)
        self.assertFalse(result['ok']);self.assertEqual(self.row,before)
        self.assertEqual(self.row['profile']['voyage_accounting']['fuel_minor'],0)
    def test_broken_ledger_fails_closed(self):
        self.start_loaded();self.row['profile']['voyage_accounting']['wallet_start_minor']-=1
        with self.assertRaisesRegex(ValueError,'does not reconcile'):
            self.call('refuel',port_id=voyages.PORTS[0],liters=10,unit_price_minor=25)

if __name__ == '__main__': unittest.main()
