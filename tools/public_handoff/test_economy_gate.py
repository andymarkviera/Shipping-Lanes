"""Exploit sweeps through production transitions with reloadable SQL doubles."""
import copy
import unittest
from economy_gate import Scenario, STARTER, COASTAL, ACCOUNT
import resale
import ship_purchase
import voyages
from authority import Rejected


class EconomyGateTest(unittest.TestCase):
    def test_purchase_resale_cycles_all_classes_lose_money_after_reload(self):
        for definition, terms in ship_purchase.CATALOG.items():
            with self.subTest(definition=definition):
                s = Scenario(reload_each=True)
                # Explicit capital fixture, conserved against the test treasury.
                s.row['money'] += 500000
                s.db.money -= 500000
                for cycle in range(8):
                    before = s.row['money']
                    purchase = s.ok('ship_purchase', port_id=voyages.PORTS[0],
                                    definition_id=definition, cost_minor=terms['cost_minor'])
                    ship = purchase['owned_ship']
                    value = resale.value(ship)
                    s.ok('ship_resale', port_id=voyages.PORTS[0], ship_id=ship['id'], value_minor=value)
                    self.assertEqual(s.row['money'], before-terms['cost_minor']+value)
                    self.assertLess(s.row['money'], before)
                    self.assertEqual(s.call('ship_resale', port_id=voyages.PORTS[0],
                                           ship_id=ship['id'], value_minor=value)['code'], 'SHIP_NOT_STORED')
                    self.assertEqual(s.row['profile']['ship']['id'], 'starter')

    def test_all_conditions_and_cost_bases_cannot_raise_resale_above_purchase(self):
        for definition, terms in ship_purchase.CATALOG.items():
            for basis in (0, 1, terms['cost_minor']//2, terms['cost_minor'], terms['cost_minor']*2):
                for condition in range(1, 10001):
                    amount = resale.value(dict(definition=definition, condition_bp=condition,
                                               acquisition_cost_minor=basis))
                    self.assertGreaterEqual(amount, 0)
                    self.assertLessEqual(amount, min(basis, terms['cost_minor']))

    def test_cancel_reload_reaccept_and_delivery_pay_only_once(self):
        s = Scenario(reload_each=True)
        for _ in range(10):
            accepted = s.ok('voyage_accept', port_id=voyages.PORTS[0], offer_id='container_seed_v1_0_0')
            s.ok('voyage_cancel', job_id=accepted['job']['id'], abandon=False)
            self.assertEqual(s.row['money'], 20000)
        job = s.loaded(0, 0)
        s.ok('voyage_deliver', port_id=voyages.PORTS[1], job_id=job)
        before = copy.deepcopy(s.row)
        for _ in range(10):
            self.assertFalse(s.call('voyage_deliver', port_id=voyages.PORTS[1], job_id=job)['ok'])
            self.assertEqual(s.call('voyage_accept', port_id=voyages.PORTS[0],
                                   offer_id='container_seed_v1_0_0')['code'], 'OFFER_CLOSED')
            self.assertEqual(s.row, before)
        self.assertEqual(s.row['money'], 45000)
        self.assertEqual(len(s.row['profile']['delivered']), 1)

    def test_finite_offer_pool_cannot_be_reset_by_reload(self):
        s = Scenario(reload_each=True)
        for index in range(3):
            for route in range(2):
                job = s.loaded(route, index)
                s.ok('voyage_deliver', port_id=voyages.PORTS[1-route], job_id=job)
        self.assertEqual(s.row['money'], 20000 + sum(o['reward_minor'] for o in voyages.OFFERS.values()))
        before = copy.deepcopy(s.row)
        for offer in voyages.OFFERS.values():
            self.assertEqual(s.call('voyage_accept', port_id=offer['origin'], offer_id=offer['offer_id'])['code'], 'OFFER_CLOSED')
        self.assertEqual(s.row, before)
        self.assertEqual(len(s.row['profile']['delivered']), 6)

    def test_recovery_cycles_charge_debt_and_keep_owned_ids(self):
        s = Scenario(reload_each=True)
        for i in range(5):
            ship = s.row['profile']['ship']
            s.ok('impact', damage_bp=10000, fuel_liters=ship['fuel_liters'], position=ship['position'])
            incident = s.row['profile']['recovery']['id']
            s.ok('recover', incident_id=incident, slot=0)
            before = copy.deepcopy(s.row)
            self.assertEqual(s.call('recover', incident_id=incident, slot=0)['code'], 'NO_RECOVERY')
            self.assertEqual(s.row, before)
            self.assertEqual(s.row['money'], 0)
            self.assertEqual(s.row['profile']['recovery_debt_minor'], (i+1)*25000-20000)
            self.assertEqual(s.row['profile']['ship']['id'], 'starter')

    def test_reload_preserves_failed_receipts_and_conflicting_intents_reject(self):
        s = Scenario(reload_each=True)
        result = s.call('ship_purchase', port_id=voyages.PORTS[0], definition_id=COASTAL,
                        cost_minor=ship_purchase.CATALOG[COASTAL]['cost_minor'])
        self.assertEqual(result['code'], 'INSUFFICIENT_FUNDS')
        # Replay every original receipt after later state/clock changes; never write again.
        before = copy.deepcopy(s.row)
        request = dict(realm='public', op='ship_purchase', account=ACCOUNT,
                       epoch=1, generation=1, action_id='gate_1', expected_revision=0,
                       port_id=voyages.PORTS[0], definition_id=STARTER, cost_minor=50000)
        with self.assertRaisesRegex(Rejected, 'ID_CONFLICT'):
            s.authority._voyage(s.db, request['account'], copy.deepcopy(s.row), request)
        self.assertEqual(s.row, before)

if __name__ == '__main__': unittest.main()
