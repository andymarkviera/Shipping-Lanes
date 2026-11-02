"""Fleet lifecycle and production receipt dispatch, with explicit in-memory SQL double."""
import copy
import unittest
from test_ship_purchase import MemoryDB, ACCOUNT
import fleet
from authority import Authority, Rejected

class FleetTest(unittest.TestCase):
    def setUp(self):
        self.profile = dict(ship=dict(id='old', definition='ship_starter_container_01', fuel_liters=123.25,
            condition_bp=4321, wear_fraction_bp=.75, position=dict(latitude=.01,longitude=.02,heading=123)),
            stored_ships=[dict(id='new',definition='ship_coastal_container_01',fuel_liters=0.,condition_bp=9876,
                wear_fraction_bp=.4, storage_port_id='port_brindle_quay')],cargo=[],jobs=[],delivered=['history'])
        self.request=dict(realm='public',op='fleet_switch',account=ACCOUNT,epoch=1,generation=1,action_id='switch',
            expected_revision=1,port_id='port_brindle_quay',ship_id='new',slot=0)
    def test_roundtrip_preserves_every_owned_field(self):
        original=copy.deepcopy(self.profile)
        code, first, amount, _=fleet.transition(self.profile,self.request)
        self.assertEqual((code,amount),('FLEET_SWITCHED',0))
        self.assertEqual(first['ship']['fuel_liters'],0)
        self.assertEqual(first['ship']['condition_bp'],9876)
        self.assertEqual(first['ship']['wear_fraction_bp'],.4)
        _,second,_,_=fleet.transition(first,dict(self.request,ship_id='old',slot=-1))
        self.assertEqual(second['ship'],original['ship'])
        self.assertEqual(second['cargo'],[])
        self.assertEqual(second['delivered'],['history'])
        self.assertEqual(self.profile,original)
        self.assertEqual(len(second['stored_ships']),1)
    def test_loaded_and_pending_job_rejections_preserve_all_state(self):
        for changes in [dict(cargo=[dict(id='cargo',ship='old')]),*[dict(jobs=[dict(state=s)]) for s in ['active','loading','loaded','accepted','unknown']]]:
            before=dict(copy.deepcopy(self.profile),**changes)
            result=fleet.transition(before,self.request)
            self.assertEqual(result[0],'FLEET_LOADED');self.assertEqual(result[1],before)
    def test_reject_wrong_port_unknown_id_sunk_duplicate_unknown_definition(self):
        for mutate,code in [(lambda p:p['stored_ships'][0].update(storage_port_id='elsewhere'),'FLEET_WRONG_PORT'),
            (lambda p:p['stored_ships'][0].update(id='absent'),'SHIP_NOT_STORED'),
            (lambda p:p['ship'].update(condition_bp=0),'RECOVERY_REQUIRED'),
            (lambda p:p['stored_ships'][0].update(condition_bp=0),'RECOVERY_REQUIRED'),
            (lambda p:p['stored_ships'].append(copy.deepcopy(p['stored_ships'][0])),'OWNED_ID_CONFLICT'),
            (lambda p:p['stored_ships'][0].update(definition='unknown'),'UNKNOWN_SHIP')]:
            p=copy.deepcopy(self.profile);mutate(p);before=copy.deepcopy(p)
            self.assertEqual(fleet.transition(p,self.request)[0],code);self.assertEqual(p,before)
    def test_saved_transform_cannot_be_overridden_by_slot(self):
        self.profile['stored_ships'][0]['position']=dict(latitude=1,longitude=2,heading=37)
        self.assertEqual(fleet.transition(self.profile,self.request)[0],'BAD_SLOT')
        self.assertEqual(fleet.transition(self.profile,dict(self.request,slot=-1))[1]['ship']['position'],self.profile['stored_ships'][0]['position'])
    def test_strict_requests(self):
        authority=Authority({});authority._validate(self.request)
        for changes in [dict(slot=True),dict(slot=4),dict(slot=-2),dict(ship_id='../bad'),dict(fuel_liters=1000),dict(condition_bp=10000),dict(position={}),dict(recipient='other')]:
            with self.assertRaises(Rejected):authority._validate(dict(self.request,**changes))
    def test_receipt_replay_and_conflict(self):
        row=dict(profile=copy.deepcopy(self.profile),money=555,revision=1);db=MemoryDB(row);a=Authority({})
        call=lambda request:a._voyage(db,ACCOUNT,copy.deepcopy(row),request)
        first=call(self.request);self.assertTrue(first['ok'])
        self.assertTrue(call(self.request)['duplicate']);self.assertEqual(row['money'],555);self.assertEqual(len(db.journal),1)
        with self.assertRaises(Rejected):call(dict(self.request,ship_id='old'))
        self.assertTrue(call(dict(self.request,ship_id='old',slot=-1,action_id='back',expected_revision=2))['ok'])
        self.assertEqual(row['profile']['ship'],self.profile['ship'])
        self.assertTrue(call(self.request)['duplicate']);self.assertEqual(row['profile']['ship']['id'],'old')
    def test_stale_and_pending_recovery(self):
        for rev,recovery,code in [(2,{},'STALE_REVISION'),(1,dict(state='pending'),'RECOVERY_REQUIRED')]:
            row=dict(profile=dict(copy.deepcopy(self.profile),recovery=recovery),money=555,revision=rev);db=MemoryDB(row)
            self.assertEqual(Authority({})._voyage(db,ACCOUNT,copy.deepcopy(row),self.request)['code'],code)
            self.assertFalse(db.journal)
    def test_all_activated_classes_can_refuel_repair_and_take_jobs(self):
        import refueling, repairs, voyages
        for definition in fleet.CATALOG:
            p=copy.deepcopy(self.profile);p['ship']['definition']=definition
            self.assertIn(definition,refueling.CAPACITIES)
            self.assertGreater(repairs.quote(p['ship'])['cost_minor'],0)
            self.assertIn(definition,voyages.CATALOG)

if __name__=='__main__':unittest.main()
