"""Interface fields against real isolated SQLite commits, including restart."""
import json
import unittest
from . import test_settlement as base
from .test_settlement import profile, request
from .private import PrivateStore


class InterfaceTest(unittest.TestCase):
    setUp = base.SettlementTest.setUp
    tearDown = base.SettlementTest.tearDown
    call = base.SettlementTest.call
    quote = base.SettlementTest.quote
    accept = base.SettlementTest.accept
    state = base.SettlementTest.state

    def test_timestamp_inventory_and_last_receipt_survive_reopen(self):
        snap = self.call('oil_snapshot')
        self.assertTrue(snap['ok'])
        self.assertEqual(snap['server_time'], self.now)
        self.assertTrue(all(p['observed_at'] == self.now for p in snap['market']['ports'].values()))
        self.assertEqual(snap['lots'], [])
        buy = self.quote(barrels=123)
        bought = self.accept(buy)
        sale = self.quote('sell', 50, buy['id'], 'port_slatewater_works')
        sold = self.accept(sale, 'partial', 1)
        self.store = PrivateStore(self.store.path, self.store.realm)
        snap = self.call('oil_snapshot')
        lot = snap['lots'][0]
        self.assertEqual(lot['remaining_barrels'], 73)
        self.assertEqual(lot['remaining_cost_minor'] + sold['lot']['allocated_cost_minor'], buy['total_minor'])
        self.assertEqual(sold['realized_profit_minor'], sale['total_minor'] - sold['lot']['allocated_cost_minor'])
        self.assertEqual(snap['money'], 20000 + bought['amount'] + sold['amount'])
        self.assertEqual(snap['last_receipt'], sold)
        self.assertEqual(lot['acquired_quote'], buy)
        self.now += 100
        self.assertTrue(self.accept(sale, 'partial', 1)['duplicate'])
        self.assertEqual(self.call('oil_snapshot')['lots'], snap['lots'])
        final = self.quote('sell', 73, buy['id'], 'port_slatewater_works')
        ended = self.accept(final, 'final', 2)
        self.assertEqual(ended['lot']['allocated_cost_minor'] + sold['lot']['allocated_cost_minor'], buy['total_minor'])
        self.assertEqual(ended['lot']['remaining_cost_minor'], 0)
        self.assertEqual(self.call('oil_snapshot')['lots'], [])
        self.assertEqual(self.call('oil_snapshot')['last_receipt'], ended)

    def test_snapshot_cannot_reprice_issued_quote_and_expiry_does_not_settle(self):
        q = self.quote(barrels=100)
        # Another captain changes this port's pressure and quote version.
        self.store.provision('other', profile(), 100000)
        def other(op, **kw):
            data = request(op, **kw); data['account'] = 'other'
            return self.store.execute('other', data, clock=lambda: self.now)
        oq = other('oil_quote', port_id=q['port'], side='buy', barrels=200, lot_id='')['quote']
        self.assertTrue(other('oil_accept', action_id='other', expected_revision=0,
                             quote_id=oq['id'], quote_version=oq['version'], port_id=oq['port'])['ok'])
        self.assertGreater(self.call('oil_snapshot')['market']['version'], q['version'])
        self.assertEqual(self.accept(q)['quote'], q)
        sale = self.quote('sell', 50, q['id'])
        self.now = sale['expires_at']
        state = self.state()
        self.assertEqual(self.accept(sale, 'expired', 1)['code'], 'QUOTE_EXPIRED')
        self.assertEqual(self.state(), state)
        fresh = self.quote('sell', 50, q['id'])
        self.assertNotEqual(fresh['id'], sale['id'])
        self.assertEqual(self.call('oil_snapshot')['lots'][0]['remaining_barrels'], 100)

    def test_fractional_legacy_cost_cumulative_allocation_is_fragmentation_neutral(self):
        # The policy remains defined even if a future migration has fractional unit cost.
        q = self.quote(barrels=3)
        self.accept(q)
        with self.store.connect() as db:
            data = json.loads(db.execute('SELECT profile FROM profiles').fetchone()[0])
            data['cargo'][0]['acquisition_cost_minor'] = 10
            db.execute('UPDATE profiles SET profile=?', (json.dumps(data),))
        costs = []
        for revision in (1, 2, 3):
            sale = self.quote('sell', 1, q['id'])
            result = self.accept(sale, 'fraction'+str(revision), revision)
            costs.append(result['lot']['allocated_cost_minor'])
            self.assertEqual(result['lot']['sold_cost_minor'] + result['lot']['remaining_cost_minor'], 10)
            self.store = PrivateStore(self.store.path, self.store.realm)
        self.assertEqual(costs, [3, 3, 4])

    def test_snapshot_last_receipt_is_account_private(self):
        self.accept(self.quote())
        self.store.provision('other', profile(), 10000)
        data = request('oil_snapshot'); data['account'] = 'other'
        snap = self.store.execute('other', data)
        self.assertEqual(snap['lots'], [])
        self.assertEqual(snap['last_receipt'], {})
        self.assertEqual(snap['money'], 10000)
