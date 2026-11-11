"""Cargo custody, partial sales and restart use real isolated SQLite transactions."""
import json
import os
import subprocess
import sys
import unittest
from concurrent.futures import ProcessPoolExecutor
from . import test_shared as fixtures
from .test_shared import remote
from .private import SharedPrivateStore
from .cargo_fuel import SALE_PORT
from .processing import PORT_ID


class CargoFuelTest(unittest.TestCase):
    setUp = fixtures.SharedTest.setUp
    tearDown = fixtures.SharedTest.tearDown
    req = fixtures.SharedTest.req
    call = fixtures.SharedTest.call
    snap = fixtures.SharedTest.snap
    submit = fixtures.SharedTest.submit
    quote = fixtures.SharedTest.quote
    withdraw = fixtures.SharedTest.withdraw
    durable = fixtures.SharedTest.durable
    def prepare(self):
        # Refine the entire purchased lot: no mixed crude/fuel hold.
        self.assertTrue(self.store.refinery('captain', self.submit(units=100000))['ok'])
        for _ in range(100): self.store.advance(1000)
        self.assertTrue(self.store.refinery('captain', self.withdraw(self.quote(70000)))['ok'])
        with self.store.connect() as db:
            p=json.loads(db.execute('SELECT profile FROM profiles').fetchone()[0])
            p['ship']['fuel_ml']=123456
            db.execute('UPDATE profiles SET profile=?',(json.dumps(p),))

    def load(self, action='load', units=70000):
        return self.req('refinery_load', action_id=action, expected_revision=self.snap()['revision'],
                        collection_id='withdraw', millibarrels=units, port_id=PORT_ID)

    def sale(self, action='sell', units=70000, lot='load'):
        return self.req('refinery_sell', action_id=action, expected_revision=self.snap()['revision'],
                        lot_id=lot, millibarrels=units, port_id=SALE_PORT)

    def fuel(self):
        with self.store.connect() as db:
            return json.loads(db.execute('SELECT profile FROM profiles').fetchone()[0])['ship']['fuel_ml']

    def test_complete_voyage_partial_sale_reload_and_wallet(self):
        self.prepare()
        self.assertEqual(self.snap()['money'], 6930) # 20000 - 13000 crude - 70 fee
        load=self.load()
        self.assertTrue(self.store.refinery('captain',load)['ok'])
        self.assertTrue(self.store.refinery('captain',load)['duplicate'])
        self.assertEqual(self.snap()['collections'],[])
        total=0
        for i, units in enumerate((1, 999, 12345, 56655)):
            self.store=SharedPrivateStore(self.path,'private:test')
            sale=self.sale('sell'+str(i), units)
            result=self.store.refinery('captain',sale)
            self.assertTrue(result['ok'],result)
            total+=result['amount']
            self.assertTrue(self.store.refinery('captain',sale)['duplicate'])
            self.assertEqual(self.fuel(),123456)
        self.assertEqual(total,22400)
        self.assertEqual(self.snap()['money'],29330)
        self.assertEqual(self.snap()['cargo_fuel'],[])
        self.assertEqual(self.store.refinery('captain',self.sale('again'))['code'],'CARGO_NOT_OWNED')

    def test_partial_load_cost_conservation_and_rejections(self):
        self.prepare()
        for bad in (dict(self.load(),millibarrels=True),dict(self.load(),millibarrels=200001),
                    dict(self.load(),collection_id='foreign'),dict(self.load(),port_id=SALE_PORT)):
            before=self.durable()
            self.assertFalse(self.store.refinery('captain',bad)['ok'])
            self.assertEqual(before,self.durable())
        costs=0
        for i,units in enumerate((1,999,69000)):
            result=self.store.refinery('captain',self.load('load'+str(i),units))
            self.assertTrue(result['ok'],result)
            costs+=result['lot']['handling_cost_minor']
            self.assertEqual(self.store.refinery('captain',self.load('busy',1))['code'],'CARGO_BUSY')
            self.assertTrue(self.store.refinery('captain',self.sale('sale'+str(i),units,'load'+str(i)))['ok'])
        self.assertEqual(costs,70)
        self.assertEqual(self.fuel(),123456)
        self.assertEqual(self.store.refinery('captain',self.load('empty',1))['code'],'INSUFFICIENT_COLLECTION')

    def test_load_and_sale_crash_boundaries(self):
        self.prepare()
        for op in ('load','sell'):
            intent=self.load() if op=='load' else self.sale()
            for stage in ('before_commit','after_commit'):
                before=self.durable()
                program='''import os,sys,json
from services.refinery.private import SharedPrivateStore
s=SharedPrivateStore(sys.argv[1],'private:test')
def fault(at,_):
 if at==sys.argv[2]: os._exit(79)
s.refinery('captain',json.loads(sys.argv[3]),fault=fault)
'''
                run=subprocess.run([sys.executable,'-c',program,self.path,stage,json.dumps(intent)])
                self.assertEqual(run.returncode,79)
                self.store=SharedPrivateStore(self.path,'private:test')
                if stage=='before_commit': self.assertEqual(self.durable(),before)
                else: self.assertTrue(self.store.refinery('captain',intent)['duplicate'])
                self.assertEqual(self.fuel(),123456)
        self.assertEqual(self.snap()['money'],29330)

    def test_concurrent_loading_and_sale_and_rollback(self):
        self.prepare()
        for intent in (self.load(),):
            for stage in ('after_profile_write','after_refinery_write','before_commit'):
                before=self.durable()
                def fault(at,_):
                    if at==stage: raise RuntimeError('fault')
                with self.assertRaises(RuntimeError): self.store.refinery('captain',intent,fault=fault)
                self.assertEqual(self.durable(),before)
        for intent in (self.load(),):
            with ProcessPoolExecutor(2) as pool:
                results=list(pool.map(remote,[self.path]*2,[intent]*2))
            self.assertTrue(all(r[1]['ok'] for r in results))
            self.assertEqual(sum(bool(r[1].get('duplicate')) for r in results),1)
        intent=self.sale()
        with ProcessPoolExecutor(2) as pool:
            results=list(pool.map(remote,[self.path]*2,[intent]*2))
        self.assertEqual(sum(bool(r[1].get('duplicate')) for r in results),1)
        self.assertEqual(self.snap()['money'],29330)
        self.assertEqual(self.fuel(),123456)

    def test_debt_recovery_capacity_corruption_and_history_bounds(self):
        from unittest.mock import patch
        from . import shared
        self.prepare()
        intent=self.load()
        with patch.object(shared, 'LIMIT', 1):
            self.assertTrue(self.store.refinery('captain',intent)['ok'])
            before=self.durable()
            self.assertEqual(self.store.refinery('captain',self.sale())['code'],'REFINERY_LEDGER_FULL')
            self.assertEqual(self.durable(),before)
            self.assertTrue(self.store.refinery('captain',intent)['duplicate'])
        with self.store.connect() as db:
            p=json.loads(db.execute('SELECT profile FROM profiles').fetchone()[0])
        original=json.loads(json.dumps(p))
        for change,code in [('ship','NO_CARGO_FUEL_CAPACITY'),('recovery','RECOVERY_REQUIRED'),('quantity','CARGO_FUEL_INVALID')]:
            p=json.loads(json.dumps(original))
            if change=='ship': p['ship']['definition']='ship_starter_container_01'
            if change=='recovery': p['recovery']={'state':'pending'}
            if change=='quantity': p['cargo'][0]['remaining_millibarrels']+=1
            with self.store.connect() as db: db.execute('UPDATE profiles SET profile=?',(json.dumps(p),))
            # Malformed snapshots fail closed; use known revision for that case.
            request=self.req('refinery_sell',action_id='sell',expected_revision=4,lot_id='load',millibarrels=70000,port_id=SALE_PORT)
            before=self.durable()
            self.assertEqual(self.store.refinery('captain',request)['code'],code)
            self.assertEqual(self.durable(),before)
        original['recovery_debt_minor']=1000
        with self.store.connect() as db: db.execute('UPDATE profiles SET profile=?',(json.dumps(original),))
        result=self.store.refinery('captain',self.sale())
        self.assertEqual(result['gross_minor'],22400)
        self.assertEqual(result['debt_repayment_minor'],1000)
        self.assertEqual(result['amount'],21400)
        self.assertEqual(self.fuel(),123456)

    def test_private_navigation_checkpoint_validation_and_reopen(self):
        from tools.oil_market_fixture import voyage_checkpoint, ACCOUNT
        from services.oil_market.test_settlement import profile
        self.store.provision(ACCOUNT, profile(), 20000)
        nav=dict(position=[750,0,-400],yaw=.7,fuel_liters=123.5,condition=.9)
        self.assertEqual(voyage_checkpoint(self.store)['navigation'],{})
        self.assertEqual(voyage_checkpoint(self.store,nav)['navigation'],nav)
        reopened=SharedPrivateStore(self.path,'private:test')
        self.assertEqual(voyage_checkpoint(reopened)['navigation'],nav)
        before=self.durable()
        for bad in (dict(nav,position=[float('nan'),0,0]),dict(nav,fuel_liters=-1),dict(nav,condition=True)):
            with self.assertRaises(ValueError): voyage_checkpoint(reopened,bad)
            self.assertEqual(self.durable(),before)
        with self.store.connect() as db:
            p=json.loads(db.execute('SELECT profile FROM profiles WHERE account=?',(ACCOUNT,)).fetchone()[0])
            p['fixture_navigation']['position']=['broken',0,0]
            db.execute('UPDATE profiles SET profile=? WHERE account=?',(json.dumps(p),ACCOUNT))
        before=self.durable()
        with self.assertRaises(ValueError): voyage_checkpoint(reopened)
        self.assertEqual(self.durable(),before)
