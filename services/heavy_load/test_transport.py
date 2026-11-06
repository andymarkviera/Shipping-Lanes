"""Step 82 atomic navigation/custody and explicit destruction policy."""
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
import unittest
from . import test_private as base
from .private import HeavyStore


def navigation(**kw):
    return dict(position=[-950, 0, -1000], yaw=0.3, deck_height=2.6,
                deck_target=2.6, fuel_liters=321.5, condition_bp=9000, attached=True, **kw)


class TransportTests(unittest.TestCase):
    setUp = base.HeavyTests.setUp
    tearDown = base.HeavyTests.tearDown
    req = base.HeavyTests.req
    call = base.HeavyTests.call
    evidence = base.HeavyTests.evidence
    carrying = base.HeavyTests.carrying
    def test_carrying_checkpoint_reopen_delivery_once(self):
        job = self.carrying()
        nav = navigation()
        self.assertTrue(self.store.checkpoint('alice', 2, nav)['ok'])
        self.store = HeavyStore(self.store.path, self.store.realm)
        snap = self.store.snapshot('alice')
        self.assertEqual(snap['navigation'], nav)
        self.assertEqual(snap['jobs'][0]['id'], job)
        self.assertEqual(snap['jobs'][0]['payload'], 'payload_offshore_block_01')
        self.assertEqual(self.store.checkpoint('alice', 2, nav)['code'], 'STALE_REVISION')
        req = self.req('deliver', 'delivery', job, 3)
        arrived = dict(nav, position=[-950, 0, -1792], deck_height=-1, deck_target=-1)
        with ThreadPoolExecutor(8) as pool:
            results = list(pool.map(lambda _: self.call(req, evidence=self.evidence(job, True), navigation=arrived), range(16)))
        self.assertTrue(all(r['ok'] for r in results))
        snap = self.store.snapshot('alice')
        self.assertEqual(snap['money'], 71000)
        self.assertFalse(snap['navigation']['attached'])
        self.assertEqual(snap['navigation']['fuel_liters'], nav['fuel_liters'])
        self.assertFalse(self.store.checkpoint('alice', 4, nav)['ok'])
        self.assertFalse(self.call(self.req('deliver', 'again', job, 4), evidence=self.evidence(job, True), navigation=arrived)['ok'])
        self.assertEqual(snap, self.store.snapshot('alice'))

    def test_destroy_cleanup_no_reward_no_resurrection(self):
        job = self.carrying()
        nav = dict(navigation(), condition_bp=0)
        req = self.req('destroy', 'loss', job, 2)
        evidence = dict(self.evidence(job), zone_id='destroyed')
        self.assertEqual(self.store.checkpoint('alice', 2, nav)['code'], 'RECOVERY_REQUIRED')
        self.assertFalse(self.call(req, navigation=nav)['ok'])
        result = self.call(req, evidence=evidence, navigation=nav)
        self.assertTrue(result['ok'], result)
        self.assertEqual(result['state'], 'failed')
        self.assertTrue(self.call(req)['duplicate'])
        snap = self.store.snapshot('alice')
        self.assertEqual(snap['money'], 1000)
        self.assertEqual(snap['zones'], [])
        self.assertFalse(snap['available'])
        self.assertFalse(snap['navigation']['attached'])
        self.assertEqual(snap['navigation']['condition_bp'], 0)
        self.assertFalse(self.call(self.req('claim', 'new', revision=3))['ok'])
        self.assertFalse(self.store.checkpoint('alice', 3, dict(navigation(), attached=False))['ok'])
        self.assertEqual(snap, self.store.snapshot('alice'))

    def test_navigation_validation_and_atomic_rollback(self):
        job = self.carrying()
        before = self.store.snapshot('alice')
        for field, value in [('position',[0, float('nan'), 0]), ('yaw',float('inf')), ('deck_height',-2), ('fuel_liters',2001), ('condition_bp', True), ('attached',1)]:
            self.assertFalse(self.store.checkpoint('alice', 2, dict(navigation(), **{field:value}))['ok'])
        req = self.req('destroy', 'loss', job, 2)
        for stage in ('after_job_write', 'after_profile_write', 'before_commit'):
            def fault(at, _):
                if at == stage: raise sqlite3.OperationalError('rollback')
            self.assertFalse(self.call(req, evidence=dict(self.evidence(job), zone_id='destroyed'), navigation=dict(navigation(), condition_bp=0), fault=fault)['ok'])
            self.assertEqual(before, self.store.snapshot('alice'))

    def test_transport_owned_process_deaths(self):
        for op in ('pickup', 'deliver', 'destroy'):
            for stage in ('before_commit', 'after_commit'):
                with self.subTest(op=op, stage=stage):
                    path = Path(self.temp.name)/(op+stage+'.sqlite')
                    with self.store.connect() as db, sqlite3.connect(path) as target: db.backup(target)
                    store = HeavyStore(path, self.store.realm)
                    job = store.heavy('alice', self.req())['job_id']
                    revision = 1
                    if op != 'pickup':
                        store.heavy('alice', self.req('pickup', 'pickup', job, 1), evidence=self.evidence(job), navigation=dict(navigation(), attached=False))
                        revision = 2
                    req = self.req(op, 'transition', job, revision)
                    evidence = dict(self.evidence(job, op == 'deliver'), **({'zone_id':'destroyed'} if op == 'destroy' else {}))
                    nav = dict(navigation(), condition_bp=0 if op == 'destroy' else 9000)
                    code = '''import json, os, sys
from services.heavy_load.private import HeavyStore
s=HeavyStore(sys.argv[1],sys.argv[2])
def fault(at, _):
    if at==sys.argv[6]: os._exit(83)
s.heavy('alice',json.loads(sys.argv[3]),evidence=json.loads(sys.argv[4]),navigation=json.loads(sys.argv[5]),fault=fault)
'''
                    child = subprocess.run([sys.executable,'-c',code,str(path),store.realm,json.dumps(req),json.dumps(evidence),json.dumps(nav),stage],timeout=15)
                    self.assertEqual(child.returncode,83)
                    result = store.heavy('alice',req,evidence=evidence,navigation=nav)
                    self.assertTrue(result['ok'], result)
                    self.assertEqual(result.get('duplicate',False),stage=='after_commit')
                    snap = store.snapshot('alice')
                    self.assertEqual(snap['navigation']['attached'],op=='pickup')
                    self.assertEqual(snap['money'],71000 if op=='deliver' else 1000)
