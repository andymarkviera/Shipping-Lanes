"""Real disposable PostgreSQL + HTTPS authority + headless Godot worker tests."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import http.client
import importlib.util
import json
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT.parent
PACKAGES = WORKSPACE / 'output/tools/public-storage-python'
sys.path.insert(0, str(PACKAGES))
sys.path.insert(0, str(ROOT / 'services/public_authority'))
sys.path.insert(0, str(ROOT / 'tools/auth_proof'))
sys.path.insert(0, str(ROOT / 'tools/public_storage'))
from authority import Authority
from common import certificates, free_port
import psycopg
from psycopg import sql

CHECKS = []
def check(ok, name):
    if not ok: raise AssertionError(name)
    CHECKS.append(name)
    print('PASS', name, flush=True)

class Proof:
    def __init__(self):
        self.run = WORKSPACE / 'output/handoff' / uuid.uuid4().hex[:8]
        self.run.mkdir(parents=True)
        print('Evidence:', self.run, flush=True)
        spec = importlib.util.spec_from_file_location('storage_fixture', ROOT / 'tools/public_storage/probe.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        self.fixture = module.Proof()
        self.fixture.start_service = lambda: None
        self.process = None
        self.log = None
        self.children = []
        self.logs = []
        self.service_counter = 0

    def setup(self):
        import cryptography
        check(cryptography.__version__ == json.loads((ROOT / 'tools/auth_proof/dependencies.json').read_text())['cryptography'], 'pinned TLS certificate tooling')
        self.fixture.setup()
        self.authority = Authority(self.fixture.admin)
        self.authority.initialize()
        self.authority.initialize() # Restart must not reinitialize profiles or money.
        self.credentials = {server: self.authority.register_server(server, 'certificate-' + server) for server in ['server-a', 'server-b', 'server-c']}
        self.account = self.authority.create_fixture_account('https://fixture.invalid', 'synthetic-sailor')
        password = secrets.token_urlsafe(32)
        with psycopg.connect(**self.fixture.admin) as db:
            db.execute(sql.SQL('CREATE ROLE authority_service LOGIN PASSWORD {}').format(sql.Literal(password)))
            db.execute('GRANT USAGE ON SCHEMA public_authority TO authority_service')
            db.execute('GRANT SELECT,INSERT,UPDATE ON ALL TABLES IN SCHEMA public_authority TO authority_service')
        self.database = dict(self.fixture.admin, user='authority_service', password=password)
        certificates(self.run)
        self.context = ssl.create_default_context(cafile=str(self.run / 'ca.pem'))
        self.port = free_port()
        self.start_service()

    def start_service(self, fault=None):
        self.stop_service()
        self.service_counter += 1
        ready = self.run / ('ready-' + str(self.service_counter))
        config = {'database': self.database, 'port': self.port, 'certificate': str(self.run / 'server.pem'),
                  'key': str(self.run / 'server-key.pem'), 'ready': str(ready), 'fault': fault,
                  'fault_marker': str(self.run / 'fault-marker')}
        path = self.run / 'service-config.json'
        path.write_text(json.dumps(config))
        env = os.environ.copy(); env['PYTHONPATH'] = str(PACKAGES)
        self.log = (self.run / ('service-' + str(self.service_counter) + '.log')).open('wb')
        self.process = subprocess.Popen([sys.executable, str(ROOT / 'services/public_authority/service.py'), str(path)], env=env,
                                        stdout=self.log, stderr=self.log, creationflags=subprocess.CREATE_NO_WINDOW)
        self.wait_file(ready)
        path.unlink()

    def wait_file(self, path, timeout=12):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if path.exists(): return
            if self.process and self.process.poll() is not None: break
            time.sleep(.03)
        raise AssertionError('Missing evidence file: ' + path.name)

    def stop_service(self):
        if self.process and self.process.poll() is None: self.process.terminate(); self.process.wait(timeout=10)
        self.process = None
        if self.log: self.log.close(); self.log = None

    def close(self):
        for child in self.children:
            if child.poll() is None: child.kill(); child.wait()
        for log in self.logs: log.close()
        self.stop_service()
        for path in self.run.rglob('*config.json'): path.unlink(missing_ok=True)
        for path in self.run.rglob('command-*.json'): path.unlink(missing_ok=True)
        self.fixture.close()

    def call(self, server, request, credential=None):
        client = http.client.HTTPSConnection('127.0.0.1', self.port, context=self.context, timeout=8)
        try:
            client.request('POST', '/v1/authority', json.dumps(request), {'Content-Type': 'application/json',
                           'X-Server-Id': server, 'Authorization': 'Bearer ' + (credential or self.credentials[server])})
            response = client.getresponse()
            return json.loads(response.read())
        finally: client.close()

    def join_request(self, server, account=None, op='admit', **extra):
        nonce = secrets.token_hex(16)
        ticket = self.authority.issue_ticket(account or self.account, server, nonce)
        return {'realm': 'public', 'op': op, 'ticket': ticket, 'nonce': nonce, **extra}

    def owned(self, grant, op, **extra):
        return {'realm': 'public', 'op': op, 'account': grant['account'], 'epoch': grant['epoch'], 'generation': grant['generation'], **extra}

    def expire(self, account=None, transfer=None):
        with psycopg.connect(**self.fixture.admin) as db:
            if transfer:
                db.execute("UPDATE public_authority.transfers SET expires=clock_timestamp()-interval '1 second' WHERE id=%s", (transfer,))
            else:
                db.execute("UPDATE public_authority.leases SET expires=clock_timestamp()-interval '1 second' WHERE account=%s", (account or self.account,))

    def profile(self, account=None):
        with self.authority.connect() as db: return self.authority._profile(db, account or self.account)

    def admission_security(self):
        request = self.join_request('server-a')
        check(self.call('server-a', dict(request, nonce='wrong'))['code'] == 'INVALID_TICKET', 'ticket bound to connection nonce')
        check(self.call('server-b', request)['code'] == 'INVALID_TICKET', 'ticket cannot admit to a different server')
        with psycopg.connect(**self.fixture.admin) as db:
            db.execute("UPDATE public_authority.servers SET fingerprint='rotated' WHERE id='server-a'")
        check(self.call('server-a', request)['code'] == 'INVALID_TICKET', 'certificate change invalidates issued ticket')
        with psycopg.connect(**self.fixture.admin) as db:
            db.execute("UPDATE public_authority.servers SET fingerprint='certificate-server-a' WHERE id='server-a'")
            db.execute("UPDATE public_authority.tickets SET expires=clock_timestamp()-interval '1 second'")
        check(self.call('server-a', request)['code'] == 'EXPIRED_OR_USED_TICKET', 'expired admission ticket rejected')
        try:
            with psycopg.connect(**self.database) as db: db.execute('SELECT * FROM economy.accounts')
        except psycopg.errors.InsufficientPrivilege: check(True, 'authority service role cannot access other fixture schema')
        else: raise AssertionError('service role too broad')

    def core(self):
        requests = {server: self.join_request(server) for server in ['server-a', 'server-b']}
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda server: self.call(server, requests[server]), requests))
        check(sum(r['ok'] for r in results) == 1, 'concurrent logins produce one public owner')
        source = 'server-a' if results[0]['ok'] else 'server-b'
        target = 'server-b' if source == 'server-a' else 'server-a'
        grant = next(r for r in results if r['ok'])
        check(self.call(source, requests[source])['code'] == 'EXPIRED_OR_USED_TICKET', 'admission ticket cannot be replayed')
        newer = self.call(source, self.join_request(source))
        check(newer['epoch'] == grant['epoch'] and newer['generation'] > grant['generation'], 'same-server reconnect replaces connection generation')
        check(self.call(source, self.owned(grant, 'renew'))['code'] == 'STALE_AUTHORITY', 'old connection cannot renew authority')
        grant = newer
        buy = self.owned(grant, 'purchase', action_id='first_purchase', expected_revision=0)
        with ThreadPoolExecutor(8) as pool: outcomes = list(pool.map(lambda _: self.call(source, buy), range(8)))
        check(all(r['ok'] for r in outcomes) and sum(r.get('duplicate', False) for r in outcomes) == 7, 'eight concurrent purchases commit one receipt')
        profile = self.profile()
        check(profile['money'] == 10000 and len(profile['profile']['cargo']) == 1, 'one debit and one stable cargo instance')
        ship, cargo, jobs = profile['profile']['ship']['id'], profile['profile']['cargo'][0]['id'], profile['profile']['jobs']
        check(self.call(source, dict(buy, realm='private'))['code'] == 'WRONG_REALM', 'private profile cannot overwrite public namespace')
        check(self.call(source, dict(buy, op='transfer_money'))['code'] == 'BAD_REQUEST', 'player-to-player money transfer has no operation')
        check(self.call(source, self.owned(grant, 'inspect'), credential='wrong')['code'] == 'UNTRUSTED_SERVER', 'server instance credential required')
        check(self.call(target, self.owned(grant, 'inspect'))['code'] == 'STALE_AUTHORITY', 'other approved server cannot read or mutate owned profile')
        checkpoint = self.owned(grant, 'checkpoint', expected_revision=1, position={'latitude': 12.0, 'longitude': -45.0, 'heading': 90.0}, fuel_liters=543.0)
        check(self.call(source, checkpoint)['ok'], 'server checkpoints only canonical simulation fields')
        check(self.call(source, dict(checkpoint, money=999999))['code'] == 'BAD_REQUEST', 'snapshot cannot overwrite wallet')
        begin = self.owned(grant, 'begin', transfer_id='cancel-test', destination=target)
        check(self.call(source, begin)['code'] == 'QUIESCING', 'departure quiesces before sealing')
        check(self.call(source, begin).get('duplicate'), 'duplicate departure resolves same transfer')
        check(self.call(source, self.owned(grant, 'purchase', action_id='while_quiescing', expected_revision=2))['code'] == 'STALE_AUTHORITY', 'quiescing source cannot spend')
        check(self.call(source, self.owned(grant, 'cancel', transfer_id='cancel-test'))['ok'], 'pre-seal cancellation resumes current owner')
        check(self.call(source, self.owned(grant, 'begin', transfer_id='switch-one', destination=target))['ok'], 'second departure creates new transfer')
        seal = self.owned(grant, 'seal', transfer_id='switch-one')
        check(self.call(source, seal)['code'] == 'SEALED', 'seal persists exact canonical state and fences source')
        check(self.call(source, seal).get('duplicate'), 'lost seal reply can be reconciled')
        check(self.call(source, self.owned(grant, 'cancel', transfer_id='switch-one'))['code'] == 'STALE_AUTHORITY', 'sealed source cannot cancel itself back into ownership')
        check(self.call(source, self.owned(grant, 'renew'))['code'] == 'STALE_AUTHORITY', 'sealed source cannot renew')
        check(self.call('server-c', self.join_request('server-c'))['code'] == 'TRANSFER_PENDING', 'third server cannot steal sealed handoff')
        wrong = self.join_request('server-c', op='claim', transfer_id='switch-one')
        check(self.call('server-c', wrong)['code'] == 'WRONG_DESTINATION', 'handoff claim bound to selected destination')
        claim = self.join_request(target, op='claim', transfer_id='switch-one')
        with ThreadPoolExecutor(8) as pool: claims = list(pool.map(lambda _: self.call(target, claim), range(8)))
        check(all(r['ok'] for r in claims) and sum(r.get('duplicate', False) for r in claims) == 7 and len({r['epoch'] for r in claims}) == 1, 'concurrent claim commits one new owner epoch')
        arrival = claims[0]
        check(arrival['epoch'] > grant['epoch'] and arrival['profile']['ship']['id'] == ship and arrival['profile']['cargo'][0]['id'] == cargo and arrival['profile']['jobs'] == jobs, 'ship cargo and job IDs survive transfer unchanged')
        check(arrival['money'] == 10000 and arrival['profile']['ship']['fuel_liters'] == 543.0 and arrival['profile']['ship']['position']['longitude'] == -45, 'wallet fuel and geographic position follow canonical profile')
        check(self.call(source, buy)['code'] == 'STALE_AUTHORITY', 'old server cannot spend after destination claim')
        replay = self.owned(arrival, 'purchase', action_id='first_purchase', expected_revision=0)
        check(self.call(target, replay).get('duplicate') and self.profile()['money'] == 10000, 'receipt replay across handoff does not debit again')
        delivery = self.owned(arrival, 'deliver', action_id='deliver_once', expected_revision=2, cargo_id=cargo)
        check(self.call(target, delivery)['ok'] and self.call(target, delivery).get('duplicate'), 'delivery pays once after transfer')
        check(self.profile()['money'] == 15000 and not self.profile()['profile']['cargo'] and self.profile()['profile']['delivered'] == [cargo], 'delivered cargo retained as one terminal identity')
        late_reply = self.call(target, claim)
        check(late_reply['money'] == 15000 and not late_reply['profile']['cargo'] and late_reply['epoch'] == arrival['epoch'], 'late claim retry returns current canonical state instead of resurrecting delivered cargo')
        self.expire()
        check(self.call(target, self.owned(arrival, 'renew'))['code'] == 'STALE_AUTHORITY', 'expired lease cannot be renewed')
        check(self.call(target, claim)['code'] == 'STALE_OUTCOME', 'old claim receipt cannot reactivate expired lease')
        recovered = self.call(source, self.join_request(source))
        check(recovered['epoch'] > arrival['epoch'] and recovered['money'] == 15000, 'expired owner recovery loads latest profile with fresh epoch')
        check(self.call(target, delivery)['code'] == 'STALE_AUTHORITY', 'failed previous owner cannot replay writes')
        self.grant, self.source, self.target = recovered, source, target

    def interrupted(self):
        source, target, grant = self.source, self.target, self.grant
        check(self.call(source, self.owned(grant, 'begin', transfer_id='abandon-sealed', destination=target))['ok'], 'prepare interrupted transfer')
        check(self.call(source, self.owned(grant, 'seal', transfer_id='abandon-sealed'))['ok'], 'seal interrupted transfer')
        late_claim = self.join_request(target, op='claim', transfer_id='abandon-sealed')
        self.expire(transfer='abandon-sealed')
        check(self.call(target, late_claim)['code'] == 'TRANSFER_UNAVAILABLE', 'expired transfer cannot be claimed')
        grant = self.call('server-c', self.join_request('server-c'))
        check(grant['ok'] and grant['epoch'] > self.grant['epoch'] and grant['money'] == 15000, 'abandoned sealed transfer recovers one canonical owner')
        check(self.call(source, self.owned(self.grant, 'checkpoint', expected_revision=3, position={'latitude': 0, 'longitude': 0, 'heading': 0}, fuel_liters=1000))['code'] == 'STALE_AUTHORITY', 'late source snapshot cannot overwrite recovered profile')
        check(self.call('server-c', self.owned(grant, 'begin', transfer_id='crashed-source', destination=source))['ok'], 'prepare source-failure case')
        self.expire()
        grant2 = self.call(source, self.join_request(source))
        check(grant2['ok'] and grant2['epoch'] > grant['epoch'], 'pre-seal source failure recovers after lease expiry')
        check(self.call('server-c', self.owned(grant, 'seal', transfer_id='crashed-source'))['code'] == 'STALE_AUTHORITY', 'old source cannot seal after recovery')
        with psycopg.connect(**self.fixture.admin) as db:
            db.execute("UPDATE public_authority.servers SET approved=false WHERE id=%s", (source,))
        check(self.call(source, self.owned(grant2, 'renew'))['code'] == 'UNTRUSTED_SERVER', 'revoked game server loses mutation and renewal rights')
        with psycopg.connect(**self.fixture.admin) as db:
            db.execute("UPDATE public_authority.servers SET approved=true WHERE id=%s", (source,))
        self.grant = grant2

    def crashes(self):
        for stage in ['after_profile_write', 'before_commit', 'after_commit']:
            account = self.authority.create_fixture_account('https://fixture.invalid', 'crash-' + stage)
            grant = self.call('server-a', self.join_request('server-a', account))
            request = self.owned(grant, 'purchase', action_id='crash_' + stage, expected_revision=0)
            self.start_service({'stage': stage, 'action_id': request['action_id']})
            try: self.call('server-a', request)
            except (OSError, http.client.HTTPException): pass
            else: raise AssertionError('service fault did not fire')
            check(self.process.wait(timeout=8) == 91, 'real authority process crash ' + stage)
            self.start_service()
            result = self.call('server-a', request)
            check(result['ok'] and result.get('duplicate', False) == (stage == 'after_commit'), 'uncertain purchase reconciles original intent ' + stage)
            check(self.profile(account)['money'] == 10000 and len(self.profile(account)['profile']['cargo']) == 1, 'crash preserves one debit/cargo ' + stage)
        # Real database outage and immediate process stop exercise WAL recovery too.
        before = self.profile()
        self.fixture.stop_db(immediate=True)
        check(self.call(self.source, self.owned(self.grant, 'inspect'))['code'] == 'BACKEND_UNAVAILABLE', 'database outage fails closed without empty profile fallback')
        self.fixture.start_db()
        check(self.profile() == before, 'PostgreSQL restart preserves canonical profile')
        self.authority.initialize()
        check(self.profile() == before, 'schema initialization on restart never resets an existing profile')
        with psycopg.connect(**self.fixture.admin) as db:
            total = db.execute('SELECT (SELECT sum(money) FROM public_authority.profiles)+(SELECT money FROM public_authority.game WHERE id=1)').fetchone()[0]
            count = db.execute('SELECT count(*) FROM public_authority.profiles').fetchone()[0]
        check(total == 1000000 + count * 20000, 'global money conserved through crashes and transfers')

    def transfer_crashes(self):
        account = self.authority.create_fixture_account('https://fixture.invalid', 'transfer-crash')
        grant = self.call('server-a', self.join_request('server-a', account))
        check(self.call('server-a', self.owned(grant, 'begin', transfer_id='lost-seal', destination='server-b'))['ok'], 'prepare lost-reply transfer')
        for op, server, request in [
            ('seal', 'server-a', self.owned(grant, 'seal', transfer_id='lost-seal')),
            ('claim', 'server-b', self.join_request('server-b', account, op='claim', transfer_id='lost-seal'))]:
            self.start_service({'stage': 'after_commit', 'action_id': 'lost-seal'})
            try: self.call(server, request)
            except (OSError, http.client.HTTPException): pass
            else: raise AssertionError('transfer crash did not fire')
            check(self.process.wait(timeout=8) == 91, 'real service crash after ' + op + ' commit')
            self.start_service()
            recovered = self.call(server, request)
            check(recovered['ok'] and recovered.get('duplicate'), 'lost ' + op + ' reply resolves committed outcome')
        check(self.call('server-a', self.owned(grant, 'renew'))['code'] == 'STALE_AUTHORITY', 'lost arrival reply does not restore source authority')
        # A renewal queued behind a row lock must use time/state AFTER that lock.
        account = self.authority.create_fixture_account('https://fixture.invalid', 'renewal-race')
        grant = self.call('server-c', self.join_request('server-c', account))
        with ThreadPoolExecutor(1) as pool:
            with psycopg.connect(**self.fixture.admin) as db:
                db.execute('SELECT account FROM public_authority.leases WHERE account=%s FOR UPDATE', (account,))
                waiting = pool.submit(self.call, 'server-c', self.owned(grant, 'renew'))
                time.sleep(.2)
                check(not waiting.done(), 'renewal waits for canonical lease lock')
                db.execute("UPDATE public_authority.leases SET expires=clock_timestamp()-interval '1 second' WHERE account=%s", (account,))
            check(waiting.result()['code'] == 'STALE_AUTHORITY', 'blocked renewal cannot revive lease expired while waiting')

    def worker(self, server):
        path = self.run / (server + '-config.json')
        path.write_text(json.dumps({'server': server, 'credential': self.credentials[server], 'port': self.port, 'ca': str(self.run / 'ca.pem')}))
        log = (self.run / (server + '-worker.log')).open('wb'); self.logs.append(log)
        child = subprocess.Popen([sys.executable, str(Path(__file__).parent / 'server_worker.py'), str(path)],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=log, text=True,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        self.children.append(child)
        # The first reply proves configuration has been loaded before deletion.
        self.worker_call(child, {'op': 'local_status'})
        path.unlink()
        return child

    def worker_call(self, worker, request):
        worker.stdin.write(json.dumps(request) + '\n'); worker.stdin.flush()
        # Each worker HTTP call has a six-second socket deadline.
        result = worker.stdout.readline()
        if not result: raise AssertionError('server worker stopped unexpectedly')
        return json.loads(result)

    def workers(self):
        account = self.authority.create_fixture_account('https://fixture.invalid', 'two-worker-account')
        first, second = self.worker('server-a'), self.worker('server-b')
        join_a, join_b = self.join_request('server-a', account), self.join_request('server-b', account)
        grant = self.worker_call(first, join_a)
        check(grant['ok'] and self.worker_call(second, join_b)['code'] == 'ACCOUNT_BUSY', 'two separate server processes cannot both acquire account')
        buy = self.owned(grant, 'purchase', action_id='worker_purchase', expected_revision=0)
        check(self.worker_call(first, buy)['ok'], 'scoped server process purchases through HTTPS without database access')
        check(self.worker_call(first, self.owned(grant, 'begin', transfer_id='worker-switch', destination='server-b'))['ok'], 'source worker prepares departure')
        check(not self.worker_call(first, {'op': 'local_status'})['active'] and self.worker_call(first, buy)['code'] == 'LOCAL_QUIESCED', 'source worker locally stops gameplay writes during departure')
        check(self.worker_call(first, self.owned(grant, 'seal', transfer_id='worker-switch'))['ok'], 'source worker seals departure')
        arrived = self.worker_call(second, self.join_request('server-b', account, op='claim', transfer_id='worker-switch'))
        check(arrived['ok'] and arrived['money'] == 10000 and len(arrived['profile']['cargo']) == 1, 'destination process loads canonical ship wallet and cargo')
        check(not self.worker_call(first, {'op': 'local_status'})['active'] and self.worker_call(second, {'op': 'local_status'})['active'], 'exactly one server worker is active after handoff')
        second.kill(); second.wait()
        check(second.returncode is not None, 'actual destination server process terminated')
        self.expire(account)
        third = self.worker('server-c')
        restored = self.worker_call(third, self.join_request('server-c', account))
        check(restored['ok'] and restored['epoch'] > arrived['epoch'] and restored['profile'] == arrived['profile'], 'new process recovers crashed destination without duplicate ship or cargo')
        replay = self.owned(restored, 'purchase', action_id='worker_purchase', expected_revision=0)
        check(self.worker_call(third, replay).get('duplicate'), 'payment receipt survives destination process death')
        self.fixture.stop_db(immediate=True)
        check(self.worker_call(third, self.owned(restored, 'renew'))['code'] == 'BACKEND_UNAVAILABLE', 'worker observes backend outage on renewal')
        check(not self.worker_call(third, {'op': 'local_status'})['active'], 'worker quiesces immediately on uncertain authority')
        self.fixture.start_db()
        check(self.worker_call(third, replay)['code'] == 'LOCAL_QUIESCED', 'restored backend does not silently reactivate stale worker')
        rebound = self.worker_call(third, self.join_request('server-c', account))
        check(rebound['ok'] and rebound['generation'] > restored['generation'] and rebound['money'] == 10000, 'fresh ticket explicitly restores authority after outage')
        check(self.worker_call(third, replay)['code'] == 'LOCAL_QUIESCED', 'old client binding remains fenced after recovery')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    args = parser.parse_args()
    proof = Proof()
    try:
        proof.setup(); proof.admission_security(); proof.core(); proof.interrupted(); proof.crashes(); proof.transfer_crashes(); proof.workers()
        (proof.run / 'summary.json').write_text(json.dumps({'passed': True, 'checks': CHECKS, 'scope': 'PostgreSQL HTTPS server-adapter fixture'}, indent=2))
        print('HANDOFF_PASS', len(CHECKS), flush=True)
    finally: proof.close()
