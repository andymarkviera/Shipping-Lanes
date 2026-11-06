"""Real SQLite contention, replay and process-death tests; no live save access."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from .private import HeavyStore, TERMS, PAYLOAD, LIFTER


class HeavyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = HeavyStore(Path(self.temp.name)/'world.sqlite', 'private:heavy-test')
        self.store.initialize()
        for name in ('alice', 'bob'):
            self.store.provision(name, dict(ship=dict(id=name+'-ship', definition=LIFTER, condition_bp=10000), cargo=[], jobs=[], delivered=[], fuel_liters=321.5), 1000)

    def tearDown(self):
        self.temp.cleanup()

    def req(self, op='claim', action='claim', job=None, revision=0, account='alice'):
        return dict(op=op, action_id=action, job_id=job or action, expected_revision=revision,
                    ship_id=account+'-ship', payload_id=PAYLOAD, realm=self.store.realm)

    def call(self, r, account='alice', **kw):
        return self.store.heavy(account, r, **kw)

    def evidence(self, job, delivery=False):
        return dict(job_id=job, payload_id=PAYLOAD, ship_id='alice-ship', validated=True,
                    zone_id=TERMS['delivery_zone' if delivery else 'pickup_zone'])

    def carrying(self):
        result = self.call(self.req())
        self.assertTrue(result['ok'], result)
        job = result['job_id']
        self.assertTrue(self.call(self.req('pickup', 'pickup', job, 1), evidence=self.evidence(job))['ok'])
        return job

    def test_two_lifters_contend_and_reconnect(self):
        def claim(i):
            owner = 'alice' if i % 2 else 'bob'
            store = HeavyStore(self.store.path, self.store.realm)
            return store.heavy(owner, self.req(action='claim'+str(i), account=owner))
        with ThreadPoolExecutor(16) as pool:
            results = list(pool.map(claim, range(32)))
        self.assertEqual(sum(r['ok'] for r in results), 1)
        snapshot = self.store.snapshot('alice')
        self.assertEqual(len(snapshot['zones']), 2)
        self.assertEqual(snapshot, HeavyStore(self.store.path, self.store.realm).snapshot('alice'))
        self.assertFalse(snapshot['available'])

    def test_competing_host_processes_share_one_claim(self):
        code = """import json, sys
from services.heavy_load.private import HeavyStore
s=HeavyStore(sys.argv[1], sys.argv[2])
print(json.dumps(s.heavy(sys.argv[3], json.loads(sys.argv[4]))))
"""
        children = []
        for i in range(12):
            owner = 'alice' if i % 2 else 'bob'
            children.append(subprocess.Popen([sys.executable, '-c', code,
                self.store.path, self.store.realm, owner,
                json.dumps(self.req(action='process-' + str(i), account=owner))],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
        replies = []
        try:
            for child in children:
                out, err = child.communicate(timeout=15)
                self.assertEqual(child.returncode, 0, err)
                replies.append(json.loads(out))
        finally:
            for child in children:
                if child.poll() is None:
                    child.kill()
                    child.wait()
        self.assertEqual(sum(r['ok'] for r in replies), 1)
        self.assertEqual(len(self.store.snapshot('alice')['zones']), 2)

    def test_cancel_reclaim_stale_intent_and_no_reward(self):
        job = self.call(self.req())['job_id']
        cancel = self.req('cancel', 'cancel', job, 1)
        self.assertTrue(self.call(cancel)['ok'])
        before = self.store.snapshot('alice')
        self.assertEqual(before['money'], 1000)
        self.assertEqual(before['zones'], [])
        self.assertTrue(self.call(cancel)['duplicate'])
        self.assertTrue(self.call(self.req())['duplicate'])
        self.assertEqual(before, self.store.snapshot('alice'))
        new = self.call(self.req(action='claim-again', revision=2))
        self.assertTrue(new['ok'])
        self.assertTrue(self.call(cancel)['duplicate'])
        self.assertEqual(len(self.store.snapshot('alice')['zones']), 2)
        self.assertFalse(self.call(self.req('pickup', 'stale', job, 3), evidence=self.evidence(job))['ok'])
        self.assertEqual(self.store.snapshot('alice')['money'], 1000)

    def test_delivery_retries_different_ids_and_lost_reply(self):
        job = self.carrying()
        r = self.req('deliver', 'delivery', job, 2)
        def lost(stage, _):
            if stage == 'after_commit': raise RuntimeError('lost reply')
        with self.assertRaises(RuntimeError):
            self.call(r, evidence=self.evidence(job, True), fault=lost)
        self.store = HeavyStore(self.store.path, self.store.realm)
        with ThreadPoolExecutor(16) as pool:
            replies = list(pool.map(lambda _: self.call(r), range(32)))
        self.assertTrue(all(x.get('duplicate') for x in replies))
        snap = self.store.snapshot('alice')
        self.assertEqual(snap['money'], 71000)
        self.assertEqual(snap['zones'], [])
        self.assertFalse(snap['available'])
        self.assertFalse(self.call(self.req('deliver', 'new', job, 3), evidence=self.evidence(job, True))['ok'])
        self.assertFalse(self.call(self.req('cancel', 'cancel', job, 3))['ok'])
        self.assertEqual(snap, self.store.snapshot('alice'))

    def test_validation_and_zone_conflict(self):
        r = self.req()
        for changed in ({'realm':'private:other'}, {'expected_revision':True}, {'payload_id':'foreign'}, {'ship_id':'bob-ship'}, {'reward_minor':999999}):
            self.assertFalse(self.call(dict(r, **changed))['ok'])
        with self.store.connect() as db:
            db.execute('INSERT INTO heavy_zones VALUES(?,?)', (TERMS['delivery_zone'], 'other-job'))
        self.assertEqual(self.call(r)['code'], 'ZONE_RESERVED')
        with self.store.connect() as db:
            db.execute('DELETE FROM heavy_zones')
        job = self.call(r)['job_id']
        self.assertEqual(self.call(dict(r, expected_revision=1))['code'], 'ID_CONFLICT')
        pickup = self.req('pickup', 'pickup', job, 1)
        self.assertEqual(self.call(pickup)['code'], 'HOST_VALIDATION_REQUIRED')
        self.assertFalse(self.call(self.req('pickup', 'other', job, 0, 'bob'), account='bob', evidence=self.evidence(job))['ok'])
        self.assertFalse(self.call(self.req('deliver', 'early', job, 1), evidence=self.evidence(job, True))['ok'])

    def test_ineligible_and_busy_profile(self):
        with self.store.connect() as db:
            original = json.loads(db.execute("SELECT profile FROM profiles WHERE account='alice'").fetchone()[0])
        for field, value in [('definition', 'ship_container_01'), ('condition_bp', 0)]:
            profile = json.loads(json.dumps(original)); profile['ship'][field] = value
            with self.store.connect() as db:
                db.execute("UPDATE profiles SET profile=? WHERE account='alice'", (json.dumps(profile),))
            self.assertFalse(self.call(self.req())['ok'])
        original['cargo'] = [{'id':'occupied'}]
        with self.store.connect() as db:
            db.execute("UPDATE profiles SET profile=? WHERE account='alice'", (json.dumps(original),))
        self.assertEqual(self.call(self.req())['code'], 'CARGO_BUSY')

    def test_debt_and_propulsion_preserved(self):
        with self.store.connect() as db:
            p = json.loads(db.execute("SELECT profile FROM profiles WHERE account='alice'").fetchone()[0])
            p['recovery_debt_minor'] = 50000
            db.execute("UPDATE profiles SET profile=? WHERE account='alice'", (json.dumps(p),))
        job = self.carrying()
        self.assertFalse(self.call(self.req('cancel', 'no-cancel', job, 2))['ok'])
        result = self.call(self.req('deliver', 'delivery', job, 2), evidence=self.evidence(job, True))
        self.assertEqual(result['debt_repayment_minor'], 35000)
        self.assertEqual(result['money'], 36000)
        with self.store.connect() as db:
            p = json.loads(db.execute("SELECT profile FROM profiles WHERE account='alice'").fetchone()[0])
        self.assertEqual(p['fuel_liters'], 321.5)
        self.assertEqual(p['recovery_debt_minor'], 15000)

    def test_rollback_and_history_bound(self):
        job = self.carrying()
        r = self.req('deliver', 'delivery', job, 2)
        before = self.store.snapshot('alice')
        for stage in ('after_job_write', 'after_profile_write', 'before_commit'):
            def fault(at, _):
                if at == stage: raise sqlite3.OperationalError('fault')
            self.assertFalse(self.call(r, evidence=self.evidence(job, True), fault=fault)['ok'])
            self.assertEqual(self.store.snapshot('alice'), before)
        with patch('services.heavy_load.private.MAX_ACTIONS', 2):
            self.assertEqual(self.call(r, evidence=self.evidence(job, True))['code'], 'HISTORY_FULL')
            self.assertTrue(self.call(self.req())['duplicate'])

    def test_world_isolation_missing_and_incompatible(self):
        self.assertFalse(HeavyStore(self.store.path, 'private:other').heavy('alice', dict(self.req(), realm='private:other'))['ok'])
        other = HeavyStore(Path(self.temp.name)/'other.sqlite', 'private:other')
        other.initialize()
        other.provision('alice', dict(ship=dict(id='alice-ship', definition=LIFTER,
                        condition_bp=10000), cargo=[], jobs=[], delivered=[]), 1000)
        self.assertTrue(other.heavy('alice', dict(self.req(), realm=other.realm))['ok'])
        self.assertTrue(self.store.snapshot('alice')['available'])
        with self.assertRaises(FileExistsError): self.store.initialize()
        missing = HeavyStore(Path(self.temp.name)/'missing.sqlite', self.store.realm)
        self.assertFalse(missing.heavy('alice', self.req())['ok'])
        self.assertFalse(Path(missing.path).exists())
        with self.store.connect() as db:
            db.execute("UPDATE heavy_world SET terms='{}'")
        self.assertEqual(self.call(self.req())['code'], 'INCOMPATIBLE_WORLD')

    def test_process_death_before_and_after_commits(self):
        for op in ('claim', 'cancel', 'pickup', 'deliver'):
            for stage in ('before_commit', 'after_commit'):
                with self.subTest(op=op, stage=stage):
                    path = Path(self.temp.name)/(op+stage+'.sqlite')
                    # SQLite backup makes an isolated copy of the initial fixture.
                    with self.store.connect() as db, sqlite3.connect(path) as dest: db.backup(dest)
                    store = HeavyStore(path, self.store.realm)
                    job = ''
                    if op != 'claim': job = store.heavy('alice', self.req())['job_id']
                    if op == 'deliver': store.heavy('alice', self.req('pickup', 'pickup', job, 1), evidence=self.evidence(job))
                    revision = 0 if op == 'claim' else (2 if op == 'deliver' else 1)
                    r = self.req(op, op, job or None, revision)
                    evidence = self.evidence(job, op == 'deliver') if op in ('pickup','deliver') else None
                    code = '''import json, os, sys
from services.heavy_load.private import HeavyStore
s=HeavyStore(sys.argv[1], sys.argv[2])
def fault(at, r):
    if at == sys.argv[5]: os._exit(83)
s.heavy('alice', json.loads(sys.argv[3]), evidence=json.loads(sys.argv[4]), fault=fault)
'''
                    child = subprocess.run([sys.executable, '-c', code, str(path), store.realm, json.dumps(r), json.dumps(evidence), stage], timeout=15)
                    self.assertEqual(child.returncode, 83)
                    result = store.heavy('alice', r, evidence=evidence)
                    self.assertTrue(result['ok'], result)
                    self.assertEqual(result.get('duplicate', False), stage == 'after_commit')
                    self.assertEqual(store.snapshot('alice')['money'], 71000 if op == 'deliver' else 1000)
                    self.assertTrue(store.heavy('alice', r)['duplicate'])


if __name__ == '__main__': unittest.main()
