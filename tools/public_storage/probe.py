"""Owns a fresh disposable cluster and service processes; never connects to a user DB."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import http.client
import json
import os
from pathlib import Path
import secrets
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid

import psycopg
from psycopg import sql
from service import LIMIT

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WORKSPACE = ROOT.parent
CHECKS = []


def check(condition, name):
    if not condition:
        raise AssertionError(name)
    CHECKS.append(name)
    print('PASS', name, flush=True)


def command(args):
    # pg_ctl's detached Windows children can inherit pipe handles; use a file.
    with tempfile.TemporaryFile() as output:
        result = subprocess.run([str(a) for a in args], stdout=output, stderr=output, timeout=60,
                                creationflags=subprocess.CREATE_NO_WINDOW)
        output.seek(0)
        message = output.read().decode('utf-8', errors='replace')
    if result.returncode:
        raise RuntimeError(f'{Path(str(args[0])).name}: {message}')
    return message.strip()


class Proof:
    def __init__(self):
        self.run = WORKSPACE / 'output/public-storage' / str(uuid.uuid4())
        self.run.mkdir(parents=True)
        self.bin = WORKSPACE / 'output/tools/postgresql-17.11/pgsql/bin'
        self.data = self.run / 'data'
        self.process = None
        self.log = None
        self.started = False
        self.config = None
        self.service_count = 0

    def setup(self):
        check(command([self.bin / 'postgres.exe', '--version']) == 'postgres (PostgreSQL) 17.11', 'pinned PostgreSQL 17.11')
        check(psycopg.__version__ == '3.2.10', 'pinned psycopg 3.2.10')
        password = secrets.token_urlsafe(32)
        pwfile = self.run / 'init-password'
        pwfile.write_text(password, encoding='ascii')
        try:
            command([self.bin / 'initdb.exe', '-D', self.data, '-U', 'proof_admin',
                     '--encoding=UTF8', '--locale=C', '--auth=scram-sha-256', '--pwfile', pwfile])
        finally:
            pwfile.unlink(missing_ok=True)
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        with (self.data / 'postgresql.conf').open('a', encoding='ascii') as stream:
            stream.write(f"\nlisten_addresses='127.0.0.1'\nport={port}\nfsync=on\n"
                         "synchronous_commit=on\nfull_page_writes=on\nmax_connections=40\n")
        self.start_db()
        self.admin = dict(host='127.0.0.1', port=port, dbname='postgres', user='proof_admin', password=password)
        service_password = secrets.token_urlsafe(32)
        with psycopg.connect(**self.admin, autocommit=True) as db:
            db.execute('CREATE DATABASE storage_proof')
            db.execute(sql.SQL('CREATE ROLE fixture_service LOGIN PASSWORD {}').format(sql.Literal(service_password)))
        self.admin['dbname'] = 'storage_proof'
        with psycopg.connect(**self.admin) as db:
            db.execute((HERE / 'schema.sql').read_text(encoding='utf-8'))
            settings = db.execute("SELECT current_setting('fsync'), current_setting('synchronous_commit'), "
                                  "current_setting('full_page_writes')").fetchone()
            check(settings == ('on', 'on', 'on'), 'durable WAL settings enabled')
        self.config = dict(mode='isolated_synthetic_fixture',
                           database=dict(self.admin, user='fixture_service', password=service_password),
                           tokens={actor: secrets.token_urlsafe(32) for actor in ('alice', 'bob')})
        private = self.run / 'private.sqlite'
        with sqlite3.connect(private) as db:
            db.execute('CREATE TABLE sentinel (money INTEGER)')
            db.execute('INSERT INTO sentinel VALUES (777)')
        self.private_hash = hashlib.sha256(private.read_bytes()).hexdigest()
        self.start_service()

    def start_db(self):
        command([self.bin / 'pg_ctl.exe', '-D', self.data, '-l', self.run / 'postgres.log', '-w', 'start'])
        self.started = True

    def stop_db(self, immediate=False):
        command([self.bin / 'pg_ctl.exe', '-D', self.data, '-m', 'immediate' if immediate else 'fast', '-w', 'stop'])
        self.started = False

    def stop_service(self):
        if self.process:
            if self.process.poll() is None:
                self.process.terminate()
            self.process.wait(timeout=10)
            self.process = None
        if self.log:
            self.log.close()
            self.log = None
        for path in self.run.glob('service-*.json'):
            path.unlink()  # disposable credentials, not evidence

    def start_service(self, fault=None):
        self.stop_service()
        self.service_count += 1
        ready = self.run / f'ready-{self.service_count}'
        self.marker = self.run / f'fault-{self.service_count}'
        config = dict(self.config, ready=str(ready), fault=fault, fault_marker=str(self.marker))
        path = self.run / f'service-{self.service_count}.json'
        path.write_text(json.dumps(config), encoding='utf-8')
        self.log = (self.run / f'service-{self.service_count}.log').open('w', encoding='utf-8')
        self.process = subprocess.Popen([sys.executable, str(HERE / 'service.py'), str(path)],
                                        stdout=self.log, stderr=self.log, creationflags=subprocess.CREATE_NO_WINDOW)
        deadline = time.monotonic() + 10
        while not ready.exists():
            if self.process.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('service startup failed; see run log')
            time.sleep(.02)
        self.port = int(ready.read_text())

    def state(self):
        with psycopg.connect(**self.admin) as db:
            return db.execute('SELECT actor,money,cargo,revision FROM economy.accounts ORDER BY actor').fetchall()

    def revision(self, actor='alice'):
        return next(row[3] for row in self.state() if row[0] == actor)

    def request(self, action, operation='service_fee', quantity=1, revision=None, actor='alice', **extra):
        result = dict(version=1, realm='public_fixture', action_id=action, operation=operation,
                      quantity=quantity, expected_revision=self.revision(actor) if revision is None else revision)
        return dict(result, **extra)

    def call(self, data, actor='alice', token=None, raw=None):
        client = http.client.HTTPConnection('127.0.0.1', self.port, timeout=8)
        try:
            client.request('POST', '/v1/operation',
                           body=raw if raw is not None else json.dumps(data).encode('utf-8'),
                           headers={'Authorization': 'Bearer ' + (token or self.config['tokens'][actor]),
                                    'Content-Type': 'application/json'})
            response = client.getresponse()
            return response.status, json.loads(response.read())
        finally:
            client.close()

    def result(self, data, **kwargs):
        status, result = self.call(data, **kwargs)
        check(status == 200, 'HTTP operation response')
        return result

    def receipts(self, action):
        with psycopg.connect(**self.admin) as db:
            return db.execute('SELECT count(*) FROM economy.receipts WHERE action_id=%s', (action,)).fetchone()[0]

    def crash_case(self, stage):
        action = 'crash_' + stage
        request = self.request(action)
        before = self.state()
        self.start_service(dict(action_id=action, stage=stage))
        try:
            self.call(request)
            raise AssertionError('fault request unexpectedly returned')
        except (http.client.RemoteDisconnected, ConnectionError):
            pass
        self.process.wait(timeout=10)
        check(self.process.returncode == 91 and self.marker.read_text() == stage, stage + ' service killed')
        committed = stage == 'after_commit'
        check((self.state() != before) == committed, stage + ' committed-or-not state')
        check(self.receipts(action) == int(committed), stage + ' matching receipt presence')
        # Abrupt DB stop leaves recovery required; restart is against the SAME data directory.
        self.stop_db(immediate=True)
        self.start_db()
        check((self.state() != before) == committed, stage + ' restart state preserved')
        self.start_service()
        replay = self.result(request)
        check(replay['ok'] and replay['duplicate'] == committed, stage + ' safe retry')
        state_after = self.state()
        check(self.result(request)['duplicate'] and self.state() == state_after,
              stage + ' second retry no extra debit')
        alice_before = next(row for row in before if row[0] == 'alice')
        alice_after = next(row for row in state_after if row[0] == 'alice')
        check(alice_after[1] == alice_before[1] - 1000 and alice_after[3] == alice_before[3] + 1,
              stage + ' exactly one fee and revision')
        check(self.receipts(action) == 1, stage + ' exactly one receipt')

    def run_tests(self, runtime):
        initial = self.state()
        purchase = self.request('purchase', 'purchase_container')
        first = self.result(purchase)
        check(first['ok'] and first['amount_minor'] == 10000, 'purchase committed')
        check(self.state() == [('alice',10000,1,1), ('bob',20000,0,0), ('game',1010000,99,1)],
              'purchase moves both wallets and cargo atomically')
        check(self.result(purchase) == dict(first, duplicate=True), 'exact retry returns original receipt')
        reordered = json.dumps(dict(reversed(list(purchase.items()))), indent=3).encode()
        check(self.call(None, raw=reordered)[1]['duplicate'], 'semantic hash ignores JSON layout and key order')
        before = self.state()
        check(self.result(dict(purchase, quantity=2))['code'] == 'id_conflict', 'payload mismatch rejected')
        check(self.state() == before and self.receipts('purchase') == 1, 'conflict has no effect')
        check(self.call(purchase, token='private_guest_fixture')[0] == 401, 'private credential cannot access public receipt')
        check(self.result(dict(purchase, realm='private_fixture'))['code'] == 'wrong_realm', 'private realm denied before lookup')
        check(self.result(dict(purchase, recipient='bob'))['code'] == 'bad_request', 'no peer recipient field')
        check(self.result(dict(purchase, operation='transfer_player'))['code'] == 'unsupported_operation', 'no peer transfer operation')
        for quantity in [True, 1.0, '1', 0, -1, LIMIT+1]:
            check(self.result(dict(purchase, action_id='invalid', quantity=quantity))['code'] == 'bad_request',
                  'strict quantity ' + repr(quantity))
        for raw in [b'{"version":1,"version":1}', b'{"quantity":NaN}', b'['*1000]:
            check(self.call(None, raw=raw)[0] == 400, 'ambiguous or invalid JSON rejected')
        check(self.call(None, raw=b' '*4097)[0] == 413, 'body size bounded')
        check(self.state() == before and self.receipts('invalid') == 0, 'invalid requests leave no state or receipts')

        denied = self.request('denied', 'purchase_container', quantity=2)
        failed = self.result(denied)
        check(failed['code'] == 'insufficient_funds' and self.state() == before, 'insufficient funds atomic rejection')
        delivered = self.result(self.request('delivery', 'deliver_container'))
        check(delivered['ok'] and self.state()[0][1:3] == (15000, 0), 'game-owned delivery payout')
        check(self.result(denied) == dict(failed, duplicate=True), 'failed receipt survives changed balance/revision')

        same = self.request('race_same')
        with ThreadPoolExecutor(max_workers=12) as pool:
            replies = list(pool.map(lambda _: self.call(same), range(12)))
        check(all(status == 200 and result['ok'] for status, result in replies), '12 simultaneous identical requests succeed')
        check(sum(not result['duplicate'] for _, result in replies) == 1 and self.receipts('race_same') == 1,
              'concurrent same intent commits once')
        revision = self.revision()
        with ThreadPoolExecutor(max_workers=8) as pool:
            replies = list(pool.map(lambda n: self.call(self.request('race_'+str(n), revision=revision)), range(8)))
        check(sum(result['ok'] for _, result in replies) == 1, 'one winner for eight competing revisions')
        check(sum(result['code'] == 'stale_revision' for _, result in replies) == 7,
              'seven competing stale failures retained')
        check(self.result(self.request('purchase', actor='bob'), actor='bob')['ok'], 'same action ID isolated by authenticated actor')
        check(self.receipts('purchase') == 2, 'actor-scoped receipt keys')
        self.crash_case('after_first_write')
        self.crash_case('before_commit')
        self.crash_case('after_commit')

        # Real PostgreSQL crash while a transaction contains only its first resource write.
        before = self.state()
        pending = psycopg.connect(**self.admin)
        pending.execute("UPDATE economy.accounts SET money=money-123 WHERE actor='alice'")
        self.stop_db(immediate=True)
        pending.close()
        self.start_db()
        check(self.state() == before, 'database crash rolls back active partial write')
        check('redo' in (self.run / 'postgres.log').read_text(encoding='utf-8').lower(), 'WAL recovery observed in server log')
        self.stop_db()
        status, result = self.call(self.request('outage', revision=self.revision_from(before)))
        check(status == 503 and result['code'] == 'outcome_unknown_retry_same_id', 'database outage produces retryable unknown outcome')
        self.start_db()
        check(self.state() == before, 'outage made no economic change')
        check(self.result(self.request('outage'))['ok'], 'same intent succeeds after database returns')
        check(self.result(purchase) == dict(first, duplicate=True), 'original success receipt survives all restarts')
        check(self.result(denied) == dict(failed, duplicate=True), 'original failure receipt survives all restarts')

        with psycopg.connect(**self.config['database']) as db:
            try:
                db.execute('SELECT * FROM private_fixture.sentinel')
                raise AssertionError('private schema accessible')
            except psycopg.errors.InsufficientPrivilege:
                check(True, 'service role cannot read private schema')
        with psycopg.connect(**self.config['database']) as db:
            try:
                db.execute('DELETE FROM economy.receipts')
                raise AssertionError('receipts deletable')
            except psycopg.errors.InsufficientPrivilege:
                check(True, 'service role cannot delete receipts')
        check(hashlib.sha256((self.run / 'private.sqlite').read_bytes()).hexdigest() == self.private_hash,
              'private SQLite file unchanged')
        if runtime != 'none':
            env = dict(os.environ, SHIPPING_STORAGE_PORT=str(self.port),
                       SHIPPING_STORAGE_TOKEN=self.config['tokens']['bob'],
                       SHIPPING_STORAGE_REVISION=str(self.revision('bob')))
            # No database password, DSN or service config path goes to the game process.
            env['APPDATA'] = str(WORKSPACE / 'output/tools/godot-4.7.2/user_data')
            if runtime == 'editor':
                args = [WORKSPACE / 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe',
                        '--headless', '--path', ROOT, 'res://tools/public_storage_probe.tscn']
            else:
                args = [ROOT / 'exports/windows-x86_64/release/ShippingLanes.exe',
                        '--headless', '--', '--public-storage-check']
            result = subprocess.run([str(a) for a in args], env=env, capture_output=True, text=True, timeout=30)
            (self.run / 'godot.log').write_text(result.stdout + result.stderr, encoding='utf-8')
            check(result.returncode == 0 and 'PUBLIC_STORAGE_GODOT_PASS (4 checks)' in result.stdout,
                  runtime + ' Godot HTTP commit/retry/conflict (4 assertions)')
        with psycopg.connect(**self.admin) as db:
            check(db.execute('SELECT money FROM private_fixture.sentinel').fetchone() == (777,), 'private schema sentinel unchanged')
            check(db.execute('SELECT sum(money),sum(cargo) FROM economy.accounts').fetchone() == (1040000,100),
                  'total money and cargo conserved across all faults')
            counts = db.execute("SELECT (SELECT count(*) FROM economy.journal),"
                                "(SELECT count(*) FROM economy.receipts WHERE result->>'ok'='true')").fetchone()
            check(counts[0] == counts[1], 'every successful receipt has exactly one journal entry')
            check(db.execute("SELECT count(*) FROM economy.journal WHERE debit<>'game' AND credit<>'game'").fetchone() == (0,),
                  'all economic movements have game-owned endpoint')
            # Reconstruct every wallet and cargo balance from the committed audit trail.
            journals = db.execute('SELECT actor,debit,credit,amount,quantity FROM economy.journal').fetchall()
            reconstructed = {actor: [money, cargo] for actor, money, cargo, _ in initial}
            for actor, debit, credit, amount, quantity in journals:
                reconstructed[debit][0] -= amount
                reconstructed[credit][0] += amount
                reconstructed[credit][1] -= quantity
                reconstructed[debit][1] += quantity
            check(all(reconstructed[actor] == [money,cargo] for actor,money,cargo,_ in self.state()),
                  'journal reconstructs every wallet and inventory')

    @staticmethod
    def revision_from(state):
        return next(row[3] for row in state if row[0] == 'alice')

    def close(self):
        self.stop_service()
        if self.started:
            self.stop_db()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', choices=['none', 'editor', 'release'], default='editor')
    args = parser.parse_args()
    proof = Proof()
    try:
        proof.setup()
        proof.run_tests(args.runtime)
        report = dict(status='pass', checks=len(CHECKS), assertions=CHECKS,
                      postgres='17.11', psycopg=psycopg.__version__, final_state=proof.state(),
                      run_id=proof.run.name, runtime=args.runtime)
        (proof.run / 'result.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
        print(f'PUBLIC_STORAGE_CHECK_PASS ({len(CHECKS)} checks) {proof.run}', flush=True)
    finally:
        proof.close()
