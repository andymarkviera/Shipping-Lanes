"""Durable contract tests using isolated private SQLite; PostgreSQL has a runner."""
from concurrent.futures import ThreadPoolExecutor
import json
import tempfile
import time
import unittest
from pathlib import Path
from .private import PrivateStore
from .client import PublicClient
from .model import MarketError


def profile():
    return dict(ship=dict(id='oil-ship', definition='ship_oil_prototype_01', condition_bp=10000),
                cargo=[], jobs=[], delivered=[])


def request(op, **kwargs):
    return dict(realm='private:test', op=op, account='captain', epoch=1, generation=1, **kwargs)


class SettlementTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = PrivateStore(Path(self.temp.name)/'private.sqlite', 'private:test')
        self.store.initialize()
        self.store.provision('captain', profile(), 20000)
        self.now = int(time.time())

    def tearDown(self):
        self.temp.cleanup()

    def call(self, op, **kwargs):
        return self.store.execute('captain', request(op, **kwargs), clock=lambda:self.now)

    def quote(self, side='buy', barrels=100, lot_id='', port='port_brindle_quay'):
        result = self.call('oil_quote', port_id=port, side=side, barrels=barrels, lot_id=lot_id)
        self.assertTrue(result['ok'], result)
        return result['quote']

    def accept(self, q, action='trade', revision=0, **extra):
        return self.call('oil_accept', **dict(action_id=action, expected_revision=revision,
                         quote_id=q['id'], quote_version=q['version'], port_id=q['port'], **extra))

    def state(self):
        with self.store.connect() as db:
            return dict(db.execute('SELECT * FROM profiles').fetchone()), json.loads(db.execute('SELECT state FROM market').fetchone()[0]), db.execute('SELECT count(*) FROM receipts').fetchone()[0]

    def test_restart_replay_conflict_and_frozen_price(self):
        q = self.quote()
        self.now += 10
        first = self.accept(q)
        self.assertTrue(first['ok'])
        state = self.state()
        self.store = PrivateStore(self.store.path, self.store.realm)
        self.now += 100
        replay = self.accept(q)
        self.assertTrue(replay['duplicate'])
        self.assertEqual(first['quote']['total_minor'], 13000)
        self.assertEqual(self.state(), state)
        changed = self.call('oil_accept', action_id='trade', expected_revision=1,
                            quote_id=q['id'], quote_version=q['version'], port_id=q['port'])
        self.assertEqual(changed['code'], 'ID_CONFLICT')
        self.assertFalse(self.accept(q, action='another')['ok'])

    def test_expiry_boundary_and_cross_account(self):
        q = self.quote()
        self.now = q['expires_at']
        before = self.state()
        self.assertEqual(self.accept(q)['code'], 'QUOTE_EXPIRED')
        self.assertEqual(self.state(), before)
        self.store.provision('other', profile(), 20000)
        data = request('oil_accept', action_id='other', expected_revision=0, quote_id=q['id'], quote_version=q['version'], port_id=q['port'])
        data['account'] = 'other'
        self.assertEqual(self.store.execute('other', data)['code'], 'UNKNOWN_QUOTE')

    def test_rollback_all_fault_boundaries(self):
        q = self.quote()
        before = self.state()
        data = request('oil_accept', action_id='trade', expected_revision=0, quote_id=q['id'], quote_version=q['version'], port_id=q['port'])
        for stage in ('after_profile_write', 'after_market_write', 'before_commit'):
            def fault(at, _):
                if at == stage: raise RuntimeError('owned fixture fault')
            with self.assertRaises(RuntimeError):
                self.store.execute('captain', data, fault=fault)
            self.assertEqual(self.state(), before)
        def lost(at, _):
            if at == 'after_commit': raise RuntimeError('lost reply')
        with self.assertRaises(RuntimeError): self.store.execute('captain', data, fault=lost)
        self.assertTrue(self.store.execute('captain', data)['duplicate'])
        self.assertEqual(self.state()[2], 1)

    def test_sale_allocation_and_no_double_proceeds(self):
        q = self.quote(barrels=99)
        bought = self.accept(q)
        total_cost = 0
        for revision, quantity in enumerate((1, 33, 65), 1):
            sell = self.quote('sell', quantity, q['id'], 'port_slatewater_works')
            result = self.accept(sell, action='sell'+str(revision), revision=revision)
            self.assertTrue(result['ok'], result)
            total_cost += result['lot']['allocated_cost_minor']
            state = self.state()
            self.assertTrue(self.accept(sell, action='sell'+str(revision), revision=revision)['duplicate'])
            self.assertEqual(self.state(), state)
        self.assertEqual(total_cost, bought['quote']['total_minor'])
        self.assertEqual(json.loads(self.state()[0]['profile'])['cargo'], [])

    def test_sale_repays_saved_recovery_debt_once(self):
        q = self.quote()
        self.assertTrue(self.accept(q)['ok'])
        with self.store.connect() as db:
            data = json.loads(db.execute('SELECT profile FROM profiles').fetchone()[0])
            data['recovery_debt_minor'] = 1000
            db.execute('UPDATE profiles SET profile=?', (json.dumps(data),))
        sale = self.quote('sell', 10, q['id'], 'port_slatewater_works')
        result = self.accept(sale, 'repayment', 1)
        self.assertEqual(result['recovery_repaid_minor'], sale['total_minor'] // 2)
        self.assertEqual(result['amount'], sale['total_minor'] - result['recovery_repaid_minor'])
        state = self.state()
        self.assertTrue(self.accept(sale, 'repayment', 1)['duplicate'])
        self.assertEqual(self.state(), state)

    def test_private_isolation_missing_state_and_no_public_fallback(self):
        q = self.quote()
        other = PrivateStore(Path(self.temp.name)/'other.sqlite', 'private:test')
        other.initialize(); other.provision('captain', profile(), 20000)
        data = request('oil_accept', action_id='trade', expected_revision=0, quote_id=q['id'], quote_version=q['version'], port_id=q['port'])
        self.assertEqual(other.execute('captain', data)['code'], 'UNKNOWN_QUOTE')
        with self.assertRaises(MarketError): PrivateStore(other.path, 'public')
        with self.store.connect() as db: db.execute('DELETE FROM market')
        self.assertEqual(self.call('oil_snapshot')['code'], 'MARKET_UNAVAILABLE')
        Path(self.store.path).unlink()
        self.assertEqual(self.call('oil_snapshot')['code'], 'MARKET_UNAVAILABLE')
        self.assertFalse(Path(self.store.path).exists())
        with self.assertRaises(ValueError): PublicClient('http://localhost', 'a', 'b')

    def test_concurrent_private_connections_serialize_one_settlement(self):
        q = self.quote()
        with ThreadPoolExecutor(max_workers=8) as workers:
            results = list(workers.map(lambda _: self.accept(q), range(32)))
        self.assertTrue(all(r['ok'] for r in results))
        self.assertEqual(sum(not r.get('duplicate', False) for r in results), 1)
        self.assertEqual(self.state()[2], 1)

    def test_strict_input_revision_ship_and_capacity(self):
        q = self.quote()
        self.assertEqual(self.accept(q, revision=1)['code'], 'STALE_REVISION')
        data = request('oil_accept', action_id='trade', expected_revision=0, quote_id=q['id'], quote_version=True, port_id=q['port'])
        self.assertEqual(self.store.execute('captain', data)['code'], 'BAD_INTEGER')
        data['quote_version'] = 0; data['total_minor'] = 1
        self.assertEqual(self.store.execute('captain', data)['code'], 'BAD_REQUEST')
        with self.store.connect() as db:
            changed = profile(); changed['ship']['id'] = 'switched'
            db.execute('UPDATE profiles SET profile=?', (json.dumps(changed),))
        self.assertEqual(self.accept(q)['code'], 'SHIP_CHANGED')
        with self.store.connect() as db:
            changed['ship']['definition'] = 'ship_starter_container_01'
            db.execute('UPDATE profiles SET profile=?', (json.dumps(changed),))
        result = self.call('oil_quote', port_id=q['port'], side='buy', barrels=1, lot_id='')
        self.assertEqual(result['code'], 'NO_OIL_CAPACITY')

if __name__ == '__main__': unittest.main()
