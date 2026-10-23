"""Actual Godot browser-code exchange -> HTTPS ticket -> normal dedicated server.
The test browser alone handles the fixture password. No token is couriered to Godot.
"""
import argparse
import hashlib
import http.cookiejar
import json
import os
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from peer_probe import PeerProof
from godot_probe import load
from probe import ROOT, WORKSPACE, CHECKS, check, free_port, psycopg
sys.path.insert(0, str(ROOT / 'tools/auth_proof'))
from oidc import LoginForm

class LoginProof(PeerProof):
    def until(self, worker, predicate, timeout=35):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            result = self.status(worker)
            if predicate(result): return result
            time.sleep(.08)
        safe = {k: result.get(k) for k in ['phase', 'notice', 'busy', 'joined', 'token_cleared', 'connection_notice', 'http_status']}
        (self.run / 'login-timeout.json').write_text(json.dumps(safe))
        raise AssertionError('Native login timed out: ' + json.dumps(safe))

    def player(self, config):
        folder = self.run / 'login-player'; folder.mkdir()
        path = folder / 'config.json'; path.write_text(json.dumps(config))
        executable = WORKSPACE / 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe' if self.runtime == 'editor' else ROOT / 'exports/windows-x86_64/release/ShippingLanes.exe'
        args = [str(executable), '--headless']
        if self.runtime == 'editor': args += ['--path', str(ROOT)]
        args += ['--', '--public-login-check', '--login-folder=' + str(folder)]
        env = os.environ.copy(); env['APPDATA'] = str(folder / 'user')
        log = (folder / 'godot.log').open('wb'); self.logs.append(log)
        child = subprocess.Popen(args, env=env, stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        self.children.append(child)
        worker = dict(child=child, folder=folder, sequence=0)
        check(self.wait_worker(worker, folder / 'ready.json')['ok'], 'actual public entry accepts configured approved server')
        path.unlink()
        return worker

    def browser(self, url, identity, credentials):
        browser = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ssl.create_default_context(cafile=str(self.run / 'provider/ca.pem'))), urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        with browser.open(url, timeout=15) as response: page = response.read().decode()
        form = LoginForm(); form.feed(page)
        assert form.action and form.action.startswith(identity['issuer'] + '/')
        data = urllib.parse.urlencode(dict(username=credentials['username'], password=credentials['password'], credentialId='')).encode()
        with browser.open(urllib.request.Request(form.action, data=data), timeout=15) as response:
            check(response.status == 200 and 'Return to Container Ship Sim' in response.read().decode(), 'real provider redirects to native Godot callback')

    def integrate_browser(self, identity, claims, credentials):
        self.identity = identity; self.start_service()
        port = free_port(udp=True)
        self.peer_worker('server', port, dedicated=True)
        cert = self.run / 'peer-cert.pem'
        config = dict(login=dict(issuer=identity['issuer'], authorization_endpoint=identity['issuer'] + '/protocol/openid-connect/auth', token_endpoint=identity['issuer'] + '/protocol/openid-connect/token', client_id='shipping-native', callback_port=self.callback_port, ca=str(self.run / 'provider/ca.pem')), authority_endpoint='https://127.0.0.1:' + str(self.port), authority_ca=str(self.run / 'ca.pem'), servers=[dict(name='Local integration server', server='server-a', host='127.0.0.1', hostname='localhost', port=port, certificate=str(cert), fingerprint=hashlib.sha256(cert.read_bytes()).hexdigest())])
        player = self.player(config)
        check(not self.status(player)['joined'], 'entry does not join or open browser automatically')
        self.worker_call(player, {'op': 'begin'})
        first = self.until(player, lambda s: bool(s['url']))
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(first['url']).query)
        check(query['code_challenge_method'] == ['S256'] and len(query['code_challenge'][0]) == 43 and 'client_secret' not in query, 'native entry creates PKCE S256 request without a client secret')
        redirect = query['redirect_uri'][0]
        for suffix in ['?state=wrong&code=wrong', '?state=' + query['state'][0] + '&state=duplicate&code=wrong']:
            try: urllib.request.urlopen(redirect + suffix, timeout=5); raise AssertionError('callback accepted')
            except urllib.error.HTTPError as error: check(error.code == 400, 'wrong or duplicate callback state rejected')
        check(self.status(player)['phase'] == 'browser', 'bad callbacks do not consume legitimate sign-in')
        self.worker_call(player, {'op': 'cancel'})
        check(not self.status(player)['busy'] and not self.status(player)['url'], 'cancel closes browser flow and clears transient state')
        self.worker_call(player, {'op': 'begin'})
        next_state = self.until(player, lambda s: bool(s['url']))
        check(urllib.parse.parse_qs(urllib.parse.urlsplit(next_state['url']).query)['state'] != query['state'], 'retry creates a fresh state')
        self.worker_call(player, {'op': 'expire'})
        expired = self.until(player, lambda s: not s['busy'])
        check('timed out' in expired['notice'], 'expired native login cannot proceed')
        self.worker_call(player, {'op': 'begin'})
        self.browser(self.until(player, lambda s: bool(s['url']))['url'], identity, credentials)
        rejected = self.until(player, lambda s: not s['busy'])
        if 'not been enrolled' not in rejected['notice']: print('SIGNIN_DIAGNOSTIC', rejected['phase'], rejected['notice'], rejected.get('connection_notice'), rejected.get('token_result'), rejected.get('token_status'), flush=True)
        check(not rejected['joined'] and 'not been enrolled' in rejected['notice'] and rejected['token_cleared'], 'unenrolled identity shows clear failure without spawning or retaining access token')
        self.account = self.authority.create_fixture_account(claims['iss'], claims['sub'])
        blocker_account = self.authority.create_fixture_account('https://fixture.invalid', 'spawn-blocker')
        blocker = self.peer_worker('client', port)
        nonce = self.until(blocker, lambda s: bool(s['nonce']))['nonce']
        self.worker_call(blocker, {'op': 'ticket', 'ticket': self.authority.issue_ticket(blocker_account, 'server-a', nonce)})
        self.until(blocker, lambda s: bool(s['binding']))
        with psycopg.connect(**self.fixture.admin) as db:
            before = db.execute('SELECT revision,profile FROM public_authority.profiles WHERE account=%s', (self.account,)).fetchone()
        self.worker_call(player, {'op': 'begin'})
        self.browser(self.until(player, lambda s: bool(s['url']))['url'], identity, credentials)
        occupied = self.until(player, lambda s: not s['busy'] and 'too close to your saved position' in s['notice'])
        check(occupied['overlay'] and not occupied['binding'] and occupied['token_cleared'], 'blocked spawn displays specific retry guidance without a boat or retained token')
        time.sleep(.4)
        check(self.status(player)['notice'] == occupied['notice'], 'disconnect cleanup preserves the refused-admission explanation')
        with psycopg.connect(**self.fixture.admin) as db:
            after = db.execute('SELECT revision,profile FROM public_authority.profiles WHERE account=%s', (self.account,)).fetchone()
            phase = db.execute('SELECT phase FROM public_authority.leases WHERE account=%s', (self.account,)).fetchone()[0]
        check(before == after and phase == 'VACANT', 'occupied spawn leaves the complete canonical save unchanged and releases ownership')
        self.worker_call(blocker, {'op': 'disconnect'})
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            with psycopg.connect(**self.fixture.admin) as db:
                if db.execute('SELECT phase FROM public_authority.leases WHERE account=%s', (blocker_account,)).fetchone()[0] == 'VACANT': break
            time.sleep(.1)
        else: raise AssertionError('Blocker departure did not release ownership')
        self.worker_call(player, {'op': 'begin'})
        self.browser(self.until(player, lambda s: bool(s['url']))['url'], identity, credentials)
        joined = self.until(player, lambda s: s['joined'] and s['ready'])
        check(not joined['overlay'] and joined['binding'] and joined['token_cleared'], 'fresh sign-in after occupied spawn enters playable boat with credentials cleared')
        self.worker_call(player, {'op': 'drive'})
        check(self.until(player, lambda s: s['snapshot'].get('speed', 0) > .02)['ready'], 'signed-in player controls normal dedicated server boat')
        self.worker_call(player, {'op': 'disconnect'})
        disconnected = self.until(player, lambda s: not s['joined'] and s['overlay'])
        check(not disconnected['binding'], 'disconnect returns player to sign-in/server selection')
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            with psycopg.connect(**self.fixture.admin) as db:
                phase = db.execute('SELECT phase FROM public_authority.leases WHERE account=%s', (self.account,)).fetchone()[0]
            if phase == 'VACANT': break
            time.sleep(.1)
        check(phase == 'VACANT', 'browser-joined player releases canonical lease on departure')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--runtime', choices=['editor', 'release'], default='editor'); args = parser.parse_args()
    proof = LoginProof(args.runtime)
    try:
        proof.setup(); proof.callback_port = free_port()
        provider = load('native_login_provider', ROOT / 'tools/auth_proof/probe.py')
        folder = proof.run / 'provider'; folder.mkdir()
        provider.oidc_proof(folder, browser_integration=proof.integrate_browser, extra_redirects=['http://127.0.0.1:%d/callback' % proof.callback_port], provider_host='127.0.0.1')
        (proof.run / 'login-summary.json').write_text(json.dumps(dict(passed=True, runtime=args.runtime, checks=CHECKS, provider_checks=provider.CHECKS), indent=2))
        print('PUBLIC_LOGIN_PASS', len(CHECKS), args.runtime, flush=True)
    finally:
        proof.close()
        for path in (proof.run / 'login-player').glob('reply-*.json'):
            data = json.loads(path.read_text()); data.pop('url', None); path.write_text(json.dumps(data))
