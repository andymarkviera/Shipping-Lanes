"""Isolated SQLite contract/crash tests; real public SQL runner is separate."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ProcessPoolExecutor
from services.oil_market.test_settlement import profile, request as oil_request
from services.oil_market.model import MarketError
from .private import SharedPrivateStore
from .processing import REFINERY_ID, PORT_ID
from . import shared


def remote(path, request):
    return os.getpid(), SharedPrivateStore(path, 'private:test').refinery('captain', request)


class SharedTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = str(Path(self.temp.name)/'stock.sqlite')
        self.store = SharedPrivateStore(self.path, 'private:test')
        self.store.initialize()
        self.store.provision('captain', profile(), 20000)
        q = self.store.execute('captain', oil_request('oil_quote', port_id='port_brindle_quay', side='buy', barrels=100, lot_id=''))['quote']
        result = self.store.execute('captain', oil_request('oil_accept', action_id='buy', expected_revision=0, quote_id=q['id'], quote_version=q['version'], port_id=q['port']))
        self.assertTrue(result['ok'])
        self.lot = q['id']

    def tearDown(self): self.temp.cleanup()

    def req(self, op, **extra):
        return dict(realm='private:test', account='captain', epoch=1, generation=1,
                    refinery_id=REFINERY_ID, op=op, **extra)

    def call(self, op, **extra): return self.store.refinery('captain', self.req(op, **extra))
    def snap(self): return self.call('refinery_snapshot')
    def submit(self, action='submit', units=1000):
        return self.req('refinery_submit', action_id=action, expected_revision=self.snap()['revision'],
                        lot_id=self.lot, input_millibarrels=units, port_id=PORT_ID)
    def finish(self, request=None):
        request = request or self.submit()
        self.assertTrue(self.store.refinery('captain', request)['ok'])
        self.store.advance(1000)
        return request
    def quote(self, units=700):
        result = self.call('refinery_quote', millibarrels=units, port_id=PORT_ID)
        self.assertTrue(result['ok'], result)
        return result['quote']
    def withdraw(self, q, action='withdraw'):
        return self.req('refinery_withdraw', action_id=action, expected_revision=self.snap()['revision'], quote_id=q['id'], port_id=PORT_ID)
    def durable(self):
        with self.store.connect() as db:
            return [list(map(tuple, db.execute('SELECT * FROM '+table))) for table in ('profiles','game','refineries','receipts')]

    def test_two_processes_cannot_withdraw_same_stock(self):
        self.finish()
        quotes = [self.quote(), self.quote()]
        intents = [self.withdraw(q, 'withdraw'+str(i)) for i,q in enumerate(quotes)]
        with ProcessPoolExecutor(2) as pool:
            jobs = [pool.submit(remote, self.path, intent) for intent in intents]
            results = [j.result() for j in jobs]
        self.assertEqual(len({r[0] for r in results}),2)
        self.assertEqual(sum(r[1]['ok'] for r in results),1)
        self.assertEqual(self.snap()['owner']['stock_millibarrels'],0)
        self.assertEqual(len(self.snap()['collections']),1)
        # Refreshing the losing revision still cannot spend depleted stock.
        loser = next(intent for intent, result in zip(intents, results) if not result[1]['ok'])
        loser['expected_revision'] = self.snap()['revision']
        self.assertEqual(self.store.refinery('captain', loser)['code'],'INSUFFICIENT_STOCK')

    def test_duplicate_withdrawal_and_handoff_fingerprint(self):
        self.finish(); q=self.quote(); intent=self.withdraw(q)
        with ProcessPoolExecutor(2) as pool:
            results = list(pool.map(remote, [self.path]*2, [intent]*2))
        self.assertTrue(all(r[1]['ok'] for r in results))
        self.assertEqual(sum(bool(r[1].get('duplicate')) for r in results),1)
        replay=self.store.refinery('captain',dict(intent,epoch=2,generation=3))
        self.assertTrue(replay['duplicate'])
        self.assertEqual(self.store.refinery('captain',dict(intent,quote_id='different'))['code'],'ID_CONFLICT')
        self.assertEqual(self.store.refinery('captain',dict(intent,action_id='second',expected_revision=3))['code'],'QUOTE_CONSUMED')
        self.assertEqual(self.snap()['money'],results[0][1]['wallet_minor'])

    def test_owned_process_crashes_for_all_commit_boundaries(self):
        for operation in ('submit','complete','withdraw'):
            for stage in ('before_commit','after_commit'):
                if operation=='submit': intent=self.submit(operation+stage)
                else:
                    self.finish(self.submit('prepare-'+operation+stage)) if operation=='withdraw' else self.assertTrue(self.store.refinery('captain',self.submit(operation+stage))['ok'])
                    intent=self.withdraw(self.quote(),operation+stage) if operation=='withdraw' else {}
                before=self.durable()
                program='''import os,sys,json
from services.refinery.private import SharedPrivateStore
s=SharedPrivateStore(sys.argv[1],'private:test')
def fault(at,_):
 if at==sys.argv[3]: os._exit(78)
if sys.argv[2]=='complete': s.advance(1000,fault=fault)
else: s.refinery('captain',json.loads(sys.argv[4]),fault=fault)
'''
                run=subprocess.run([sys.executable,'-c',program,self.path,operation,stage,json.dumps(intent)])
                self.assertEqual(run.returncode,78)
                self.store=SharedPrivateStore(self.path,'private:test')
                if stage=='before_commit': self.assertEqual(self.durable(),before)
                if operation=='complete':
                    stock=self.snap()['owner']['stock_millibarrels']
                    self.store.advance(1000)
                    self.assertEqual(self.snap()['owner']['stock_millibarrels'],stock+(700 if stage=='before_commit' else 0))
                else:
                    result=self.store.refinery('captain',intent)
                    self.assertTrue(result['ok'],result)
                    self.assertEqual(result.get('duplicate',False),stage=='after_commit')
                    self.assertTrue(self.store.refinery('captain',intent)['duplicate'])
                    if operation=='submit': self.store.advance(1000)

    def test_rollback_and_uncertain_reply(self):
        for operation in ('submit','withdraw'):
            if operation=='withdraw': self.store.advance(1000)
            intent=self.submit() if operation=='submit' else self.withdraw(self.quote())
            before=self.durable()
            for stage in ('after_profile_write','after_refinery_write','before_commit'):
                def fault(at,_):
                    if at==stage: raise RuntimeError('owned fault')
                with self.assertRaises(RuntimeError): self.store.refinery('captain',intent,fault=fault)
                self.assertEqual(self.durable(),before)
            def lost(at,_):
                if at=='after_commit': raise RuntimeError('lost reply')
            with self.assertRaises(RuntimeError): self.store.refinery('captain',intent,fault=lost)
            self.assertTrue(self.store.refinery('captain',intent)['duplicate'])

    def test_private_isolation_and_public_rejection(self):
        self.finish()
        other=SharedPrivateStore(Path(self.temp.name)/'other.sqlite','private:other')
        other.initialize(); other.provision('captain',profile(),20000)
        self.assertEqual(other.refinery('captain',dict(self.req('refinery_snapshot'),realm='private:other'))['stock_millibarrels'],0)
        self.assertEqual(self.store.refinery('captain',dict(self.req('refinery_snapshot'),realm='public'))['code'],'WRONG_REALM_OR_ACCOUNT')
        with self.assertRaises(MarketError): SharedPrivateStore(self.path,'public')
        q=self.quote()
        self.store.provision('other',profile(),20000)
        intent=dict(self.withdraw(q),account='other',expected_revision=0)
        self.assertEqual(self.store.refinery('other',intent)['code'],'UNKNOWN_QUOTE')
        with self.store.connect() as db: state=json.loads(db.execute('SELECT state FROM refineries').fetchone()[0])
        with self.assertRaises(MarketError): shared.validate(state,'public')

    def test_clock_restart_fraction_and_capacity_after_withdrawal(self):
        # 1+999 input preserves exact carry through restart, withdrawals free space.
        intent=self.submit(units=1); self.finish(intent)
        self.assertEqual(self.snap()['owner']['remainder'],7)
        self.assertEqual(self.snap()['owner']['stock_millibarrels'],0)
        self.assertTrue(self.store.refinery('captain',self.submit('fraction',999))['ok'])
        self.store=SharedPrivateStore(self.path,'private:test')
        self.assertEqual(self.snap()['owner']['stock_millibarrels'],0) # private downtime pauses
        self.store.advance(1000)
        self.assertEqual(self.snap()['owner']['stock_millibarrels'],700)
        with self.store.connect() as db:
            state=json.loads(db.execute('SELECT state FROM refineries').fetchone()[0])
        shared.advance(state,state['time_ms']-1000)
        shared.validate(state,'private:test')
        self.assertEqual(state['owners']['captain']['stock_millibarrels'],700)
        # Public algorithm: a saved absolute deadline completes once after downtime.
        self.assertTrue(self.store.refinery('captain',self.submit('next'))['ok'])
        with self.store.connect() as db: state=json.loads(db.execute('SELECT state FROM refineries').fetchone()[0])
        shared.advance(state,1000000); shared.advance(state,1000000)
        shared.validate(state,'private:test')
        self.assertEqual(state['owners']['captain']['stock_millibarrels'],1400)

    def test_quote_cost_no_propulsion_or_cargo_and_tamper(self):
        self.finish(); q=self.quote()
        self.assertEqual(q['cost_minor'],1)
        with self.store.connect() as db: before=json.loads(db.execute('SELECT profile FROM profiles').fetchone()[0])
        result=self.store.refinery('captain',self.withdraw(q)); self.assertTrue(result['ok'])
        with self.store.connect() as db:
            after=json.loads(db.execute('SELECT profile FROM profiles').fetchone()[0])
            state=json.loads(db.execute('SELECT state FROM refineries').fetchone()[0])
        self.assertEqual(before,after)
        for change in ('owner','quantity','price','clock'):
            bad=copy.deepcopy(state)
            if change=='owner': bad['owners']['captain']['stock_millibarrels']+=1
            if change=='quantity': bad['withdrawals'][0]['millibarrels']+=1
            if change=='price': bad['quotes'][q['id']]['cost_minor']+=1
            if change=='clock': bad['time_ms']=True
            with self.assertRaises(MarketError): shared.validate(bad,'private:test')
        with self.store.connect() as db: db.execute('DELETE FROM refineries')
        self.assertEqual(self.snap()['code'],'REFINERY_UNAVAILABLE')
        with self.assertRaises(FileExistsError): self.store.initialize()

    def test_freed_capacity_and_bounded_history(self):
        from unittest.mock import patch
        with self.store.connect() as db:
            state=json.loads(db.execute('SELECT state FROM refineries').fetchone()[0])
            state['config']['output_capacity_millibarrels']=700
            state['config']['max_submissions']=2
            db.execute('UPDATE refineries SET state=?',(json.dumps(state),))
        self.finish()
        self.assertEqual(self.store.refinery('captain',self.submit('full'))['code'],'OUTPUT_CAPACITY')
        q=self.quote()
        with patch.object(shared,'LIMIT',1):
            self.assertEqual(self.call('refinery_quote',millibarrels=1,port_id=PORT_ID)['code'],'REFINERY_LEDGER_FULL')
        self.assertTrue(self.store.refinery('captain',self.withdraw(q))['ok'])
        self.finish(self.submit('refill'))
        self.assertEqual(self.snap()['owner']['stock_millibarrels'],700)
        self.assertEqual(self.store.refinery('captain',self.submit('exhausted'))['code'],'REFINERY_LEDGER_FULL')
        # Old action remains recoverable even at the history bound.
        with self.store.connect() as db:
            row=db.execute("SELECT result FROM receipts WHERE action_id='submit'").fetchone()
        self.assertEqual(json.loads(row[0])['job']['input_millibarrels'],1000)

    def test_bad_fields_stale_busy_funds_and_receipt_namespace(self):
        intent=self.submit()
        for bad in (dict(intent,input_millibarrels=True),dict(intent,time_ms=100),dict(intent,refinery_id='scene'),dict(intent,port_id='wrong'),dict(intent,expected_revision=99),dict(intent,lot_id='foreign')):
            before=self.durable(); self.assertFalse(self.store.refinery('captain',bad)['ok']); self.assertEqual(before,self.durable())
        self.assertEqual(self.store.refinery('captain',dict(intent,action_id='buy'))['code'],'ID_CONFLICT')
        self.assertTrue(self.store.refinery('captain',intent)['ok'])
        self.assertEqual(self.store.refinery('captain',self.submit('busy'))['code'],'REFINERY_BUSY')
        self.store.advance(1000)
        q=self.quote()
        with self.store.connect() as db: db.execute('UPDATE profiles SET money=0')
        before=self.durable()
        self.assertEqual(self.store.refinery('captain',self.withdraw(q))['code'],'INSUFFICIENT_FUNDS')
        self.assertEqual(before,self.durable())


if __name__=='__main__': unittest.main()
