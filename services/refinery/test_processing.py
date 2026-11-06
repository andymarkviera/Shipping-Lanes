"""Conservation, atomic recovery and adversarial private-refinery inputs."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest

from services.oil_market.test_settlement import profile, request
from services.oil_market.model import MarketError
from services.refinery.processing import Config, RefineryStore, REFINERY_ID, PORT_ID


class RefineryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'refinery.sqlite'
        self.store = RefineryStore(self.path, 'private:test')
        self.store.initialize()
        self.store.provision('captain', profile(), 20000)
        q = self.store.execute('captain', request('oil_quote', port_id='port_brindle_quay', side='buy', barrels=100, lot_id=''))['quote']
        self.bought = self.store.execute('captain', request('oil_accept', action_id='buy', expected_revision=0, quote_id=q['id'], quote_version=q['version'], port_id=q['port']))
        self.lot = q['id']

    def tearDown(self): self.temp.cleanup()

    def snapshot(self, account='captain'):
        result = self.store.refinery(account, dict(op='refinery_snapshot', refinery_id=REFINERY_ID))
        self.assertTrue(result['ok'], result)
        return result

    def intent(self, amount=1000, action='submit'):
        return dict(op='refinery_submit', refinery_id=REFINERY_ID, action_id=action,
                    expected_revision=self.snapshot()['revision'], lot_id=self.lot, input_millibarrels=amount)

    def submit(self, data, **kwargs):
        return self.store.refinery('captain', data, docked=True, port_id=PORT_ID, **kwargs)

    def finish(self):
        while self.snapshot()['busy']: self.store.advance(1000)

    def durable(self):
        with self.store.connect() as db:
            return tuple((table, db.execute('SELECT * FROM '+table).fetchall()) for table in ('profiles','refinery','receipts','game','market'))

    def test_fractional_partition_restart_and_exact_retry(self):
        rng = random.Random(77)
        total = 0
        for i in range(125):
            amount = rng.randint(1, 99)
            data = self.intent(amount, 'part-'+str(i))
            result = self.submit(data)
            self.assertTrue(result['ok'], result)
            total += amount
            self.store = RefineryStore(self.path, 'private:test')
            self.finish()
            before = self.durable()
            self.assertTrue(self.submit(data)['duplicate'])
            self.assertEqual(before, self.durable())
            owner = self.snapshot()['owner']
            self.assertEqual(owner['stock_millibarrels'], total * 7 // 10)
            self.assertEqual(owner['remainder'], total * 7 % 10)
        lot = self.snapshot()['lots'][0]
        self.assertEqual(lot['remaining_millibarrels'], 100000 - total)
        self.assertEqual(lot['refined_cost_minor'] + lot['remaining_cost_minor'], self.bought['quote']['total_minor'])

    def test_reopen_pauses_no_offline_time_and_completion_once(self):
        data = self.intent(2000)
        self.assertTrue(self.submit(data)['ok'])
        self.store.advance(123)
        before = self.snapshot()
        self.store = RefineryStore(self.path, 'private:test')
        self.assertEqual(before, self.snapshot())
        self.store.advance(1000)
        self.store.advance(877)
        self.assertEqual(self.snapshot()['owner']['stock_millibarrels'], 1400)
        for _ in range(5): self.store.advance(1000)
        self.assertEqual(self.snapshot()['owner']['stock_millibarrels'], 1400)
        self.assertEqual(self.snapshot()['jobs'][0]['elapsed_ms'], 2000)

    def test_invalid_inputs_and_dock_ownership_revision(self):
        data = self.intent()
        for amount in (0, -1, True, 0.5, '1', 10**12):
            before = self.durable()
            self.assertFalse(self.submit(dict(data, input_millibarrels=amount))['ok'])
            self.assertEqual(before, self.durable())
        for change, code in (({'input_millibarrels':200001}, 'INPUT_CAPACITY'),
                             ({'lot_id':'foreign'}, 'CARGO_NOT_OWNED'),
                             ({'expected_revision':0}, 'STALE_REVISION'),
                             ({'refinery_id':'foreign'}, 'BAD_REQUEST'),
                             ({'yield_numerator':999}, 'BAD_REQUEST'),
                             ({'input_millibarrels':100001}, 'CARGO_NOT_OWNED')):
            self.assertEqual(self.submit(dict(data, **change))['code'], code)
        self.assertEqual(self.store.refinery('captain', data)['code'], 'DOCK_REQUIRED')
        self.store.provision('other', profile(), 100)
        self.assertEqual(self.store.refinery('other', dict(data, expected_revision=0), docked=True, port_id=PORT_ID)['code'], 'CARGO_NOT_OWNED')
        self.assertTrue(self.submit(data)['ok'])
        self.assertEqual(self.submit(dict(data, input_millibarrels=1))['code'], 'ID_CONFLICT')
        self.assertTrue(self.store.refinery('captain', data)['duplicate'])
        self.assertEqual(self.submit(self.intent(1,'other'))['code'], 'REFINERY_BUSY')

    def test_atomic_faults_and_lost_reply(self):
        data = self.intent()
        before = self.durable()
        for stage in ('after_profile_write', 'after_refinery_write', 'before_commit'):
            def fault(at, _):
                if at == stage: raise RuntimeError('owned fault')
            with self.assertRaises(RuntimeError): self.submit(data, fault=fault)
            self.assertEqual(before, self.durable())
        def lost(at, _):
            if at == 'after_commit': raise RuntimeError('lost reply')
        with self.assertRaises(RuntimeError): self.submit(data, fault=lost)
        self.assertTrue(self.submit(data)['duplicate'])
        before = self.durable()
        def rollback(at, _):
            if at == 'before_commit': raise RuntimeError('completion rollback')
        with self.assertRaises(RuntimeError): self.store.advance(1000, fault=rollback)
        self.assertEqual(before, self.durable())
        with self.assertRaises(RuntimeError): self.store.advance(1000, fault=lost)
        self.store = RefineryStore(self.path, 'private:test')
        self.store.advance(1000)
        self.assertEqual(self.snapshot()['owner']['stock_millibarrels'], 700)

    def test_real_process_death_at_submission_and_completion_commit(self):
        # Child exits without SQLite/Python cleanup; parent reopens the same file.
        for operation in ('submit', 'advance'):
            for stage in ('before_commit', 'after_commit'):
                if operation == 'submit':
                    data = self.intent(1000, 'kill-'+stage)
                else:
                    data = self.intent(1000, 'complete-'+stage)
                    self.assertTrue(self.submit(data)['ok'])
                before = self.snapshot()['owner']['stock_millibarrels']
                program = '''import os,sys,json
from services.refinery.processing import RefineryStore,PORT_ID
s=RefineryStore(sys.argv[1],'private:test')
def fault(at,_):
    if at == sys.argv[3]: os._exit(77)
if sys.argv[2]=='submit': s.refinery('captain',json.loads(sys.argv[4]),docked=True,port_id=PORT_ID,fault=fault)
else: s.advance(1000,fault=fault)
'''
                result = subprocess.run([sys.executable,'-c',program,str(self.path),operation,stage,json.dumps(data)])
                self.assertEqual(result.returncode,77)
                self.store = RefineryStore(self.path,'private:test')
                if operation == 'submit':
                    replay = self.submit(data)
                    self.assertTrue(replay['ok'])
                    self.assertEqual(replay.get('duplicate',False), stage == 'after_commit')
                else:
                    self.assertEqual(self.snapshot()['owner']['stock_millibarrels'], before + (700 if stage == 'after_commit' else 0))
                self.finish()
                self.assertEqual(self.snapshot()['owner']['stock_millibarrels'], before + 700)

    def test_concurrent_submission_and_ticks(self):
        data = self.intent(1000)
        with ThreadPoolExecutor(max_workers=8) as workers:
            results = list(workers.map(lambda _: self.submit(data), range(32)))
        self.assertTrue(all(r['ok'] for r in results))
        self.assertEqual(sum(not r.get('duplicate',False) for r in results),1)
        with ThreadPoolExecutor(max_workers=8) as workers:
            list(workers.map(lambda _: self.store.advance(1000), range(16)))
        self.assertEqual(self.snapshot()['owner']['stock_millibarrels'],700)
        self.assertEqual(self.snapshot()['lots'][0]['remaining_millibarrels'],99000)

    def test_mixed_fractional_refining_and_sale_cost_conservation(self):
        for index, amount in enumerate((1, 999)):
            self.assertTrue(self.submit(self.intent(amount, 'fraction'+str(index)))['ok'])
            self.finish()
            if index == 0:
                q = self.store.execute('captain', request('oil_quote', port_id=PORT_ID, side='sell', barrels=99, lot_id=self.lot))['quote']
                sale = self.store.execute('captain', request('oil_accept', action_id='sell', expected_revision=2, quote_id=q['id'], quote_version=q['version'], port_id=q['port']))
                self.assertTrue(sale['ok'],sale)
                self.assertEqual(sale['lot']['remaining_millibarrels'],999)
                self.assertEqual(sale['lot']['remaining_barrels'],0)
                self.assertEqual(sale['lot']['sold_cost_minor'] + sale['lot']['refined_cost_minor'] + sale['lot']['remaining_cost_minor'], self.bought['quote']['total_minor'])
        self.assertEqual(self.snapshot()['lots'],[])
        self.assertEqual(self.snapshot()['owner']['stock_millibarrels'],700)
        snap = self.store.execute('captain',request('oil_snapshot'))
        self.assertEqual(snap['last_receipt']['code'],'OIL_SETTLED')
        self.assertEqual(snap['last_receipt']['action_id'],'sell')

    def test_bounds_config_and_corruption_fail_closed(self):
        # Only edit a newly provisioned, unused test configuration.
        with self.store.connect() as db:
            state = self.store.read(db)
            state['config'].update(yield_numerator=1, yield_denominator=3, output_capacity_millibarrels=1)
            self.store.write(db,state)
        self.assertTrue(self.submit(self.intent(3))['ok']); self.finish()
        before = self.durable()
        self.assertEqual(self.submit(self.intent(3,'full'))['code'],'OUTPUT_CAPACITY')
        self.assertEqual(before,self.durable())
        with self.store.connect() as db:
            state = self.store.read(db)
            state['owners']['captain']['stock_millibarrels'] += 1
            db.execute('UPDATE refinery SET state=?',(json.dumps(state),))
        self.assertEqual(self.store.refinery('captain',dict(op='refinery_snapshot',refinery_id=REFINERY_ID))['code'],'REFINERY_STATE_INVALID')
        with self.assertRaises(MarketError): self.store.advance(1000)
        for config in (dict(yield_numerator=True),dict(yield_denominator=0),dict(yield_numerator=11),dict(rate_millibarrels_per_second=0)):
            with self.assertRaises(MarketError): Config(**config)

    def test_fraction_carry_survives_new_lot_and_account_isolation(self):
        # Use 1/3 so whole barrels also produce a carried fraction.
        with self.store.connect() as db:
            state = self.store.read(db)
            state['config'].update(yield_numerator=1, yield_denominator=3)
            self.store.write(db, state)
        self.assertTrue(self.submit(self.intent(100000))['ok']); self.finish()
        self.assertEqual(self.snapshot()['owner']['remainder'], 1)
        self.store.provision('other', profile(), 20000)
        self.assertEqual(self.snapshot('other')['owner']['remainder'], 0)
        q = self.store.execute('captain', request('oil_quote', port_id='port_brindle_quay', side='buy', barrels=1, lot_id=''))['quote']
        buy = self.store.execute('captain', request('oil_accept', action_id='new-buy', expected_revision=2, quote_id=q['id'], quote_version=q['version'], port_id=q['port']))
        self.assertTrue(buy['ok'], buy)
        self.lot = q['id']
        self.assertTrue(self.submit(self.intent(2, 'carry-new-lot'))['ok']); self.finish()
        self.assertEqual(self.snapshot()['owner']['stock_millibarrels'], 33334)
        self.assertEqual(self.snapshot()['owner']['remainder'], 0)
        # Both economic actions share the same receipt identity namespace.
        self.assertEqual(self.submit(self.intent(1, 'new-buy'))['code'], 'ID_CONFLICT')

    def test_fractional_cost_and_malformed_saved_numbers(self):
        with self.store.connect() as db:
            data = json.loads(db.execute('SELECT profile FROM profiles').fetchone()[0])
            data['cargo'][0]['acquisition_cost_minor'] = 10
            db.execute('UPDATE profiles SET profile=?', (json.dumps(data),))
        allocated = 0
        for i, amount in enumerate((33333, 33333, 33334)):
            result = self.submit(self.intent(amount, 'cost-'+str(i)))
            self.assertTrue(result['ok'], result)
            self.assertEqual(result['job']['allocated_cost_minor'], (3, 3, 4)[i])
            allocated += result['job']['allocated_cost_minor']
            self.finish()
        self.assertEqual(allocated, 10)
        with self.store.connect() as db:
            original = self.store.read(db)
        for field in ('stock_millibarrels', 'remainder', 'processed_millibarrels'):
            corrupted = json.loads(json.dumps(original))
            corrupted['owners']['captain'][field] = float(corrupted['owners']['captain'][field])
            with self.store.connect() as db:
                db.execute('UPDATE refinery SET state=?', (json.dumps(corrupted),))
            result = self.store.refinery('captain', dict(op='refinery_snapshot', refinery_id=REFINERY_ID))
            self.assertEqual(result['code'], 'REFINERY_STATE_INVALID')

    def test_ledger_capacity_isolation_and_missing_state(self):
        with self.store.connect() as db:
            state = self.store.read(db); state['config']['max_submissions']=1; self.store.write(db,state)
        self.assertTrue(self.submit(self.intent(1))['ok']); self.finish()
        self.assertEqual(self.submit(self.intent(1,'next'))['code'],'REFINERY_LEDGER_FULL')
        other = RefineryStore(Path(self.temp.name)/'other.sqlite','private:test')
        other.initialize(); other.provision('captain',profile(),20000)
        result = other.refinery('captain',dict(op='refinery_snapshot',refinery_id=REFINERY_ID))
        self.assertEqual(result['owner']['stock_millibarrels'],0)
        with self.store.connect() as db: db.execute('DELETE FROM refinery')
        self.assertEqual(self.store.refinery('captain',dict(op='refinery_snapshot',refinery_id=REFINERY_ID))['code'],'REFINERY_UNAVAILABLE')


if __name__ == '__main__': unittest.main()
