"""Real OIDC -> HTTPS tickets -> two Godot live-hull ownership adapters.

Operator file courier is deliberately not a public game transport or login UI.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import time

from probe import Proof, ROOT, WORKSPACE, CHECKS, check
import http.client


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GodotProof(Proof):
    def __init__(self, runtime):
        super().__init__()
        self.runtime = runtime
        self.worker_number = 0

    def worker(self, server, wrong_ca=False):
        self.worker_number += 1
        folder = self.run / ('godot-' + str(self.worker_number))
        folder.mkdir()
        config = folder / 'config.json'
        config.write_text(json.dumps({'endpoint': 'https://127.0.0.1:' + str(self.port), 'server': server,
                                     'credential': self.credentials[server], 'ca': str(self.run / ('wrong-ca.pem' if wrong_ca else 'ca.pem'))}))
        executable = (WORKSPACE / 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe' if self.runtime == 'editor'
                      else ROOT / 'exports/windows-x86_64/release/ShippingLanes.exe')
        args = [str(executable), '--headless']
        if self.runtime == 'editor': args += ['--path', str(ROOT)]
        args += ['--', '--public-owner-check', '--owner-folder=' + str(folder)]
        log = (folder / 'godot.log').open('wb'); self.logs.append(log)
        env = os.environ.copy(); env['APPDATA'] = str(folder / 'user')
        child = subprocess.Popen(args, env=env, stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        self.children.append(child)
        worker = {'child': child, 'folder': folder, 'sequence': 0}
        self.wait_worker(worker, folder / 'ready.json')
        config.unlink()
        return worker

    def wait_worker(self, worker, path):
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            if path.exists(): return json.loads(path.read_text())
            if worker['child'].poll() is not None: break
            time.sleep(.025)
        raise AssertionError('Godot response missing; inspect ' + str(worker['folder'] / 'godot.log'))

    def worker_call(self, worker, request):
        sequence = worker['sequence']; worker['sequence'] += 1
        path = worker['folder'] / ('command-' + str(sequence) + '.json')
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps(request)); temporary.replace(path)
        result = self.wait_worker(worker, worker['folder'] / ('reply-' + str(sequence) + '.json'))
        return result

    def ticket_call(self, token, request):
        client = http.client.HTTPSConnection('localhost', self.port, context=self.context, timeout=8)
        try:
            client.request('POST', '/v1/ticket', json.dumps(request), {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token})
            response = client.getresponse()
            return response.status, json.loads(response.read())
        finally: client.close()

    def integrate(self, identity, tokens, claims):
        self.identity = identity
        self.start_service()
        access = tokens['access_token']
        def ticket(server, op='admit', **extra):
            nonce = extra.pop('nonce', None) or secrets.token_hex(16)
            status, response = self.ticket_call(access, {'server': server, 'nonce': nonce})
            check(status == 200 and response['ok'], 'validated OIDC issues scoped ' + server + ' ticket')
            return {'realm': 'public', 'op': op, 'ticket': response['ticket'], 'nonce': nonce, **extra}
        request = {'server': 'server-a', 'nonce': secrets.token_hex(16)}
        check(self.ticket_call(access, request)[1]['code'] == 'ACCOUNT_NOT_ENROLLED', 'sign-in cannot silently create a funded profile')
        self.account = self.authority.create_fixture_account(claims['iss'], claims['sub'])
        check(self.ticket_call(tokens['id_token'], request)[1]['code'] == 'INVALID_IDENTITY', 'ID token rejected by service audience')
        check(self.ticket_call('malformed', request)[1]['code'] == 'INVALID_IDENTITY', 'malformed identity fails closed')
        check(self.ticket_call(access[:-12] + 'AAAAAAAAAAAA', request)[1]['code'] == 'INVALID_IDENTITY', 'forged signature rejected by HTTPS service')
        check(self.ticket_call(access, dict(request, account=self.account))[1]['code'] == 'BAD_REQUEST', 'caller cannot choose account or import private profile')
        self.exercise_workers(ticket)

    def exercise_workers(self, ticket):
        untrusted = self.worker('server-a', wrong_ca=True)
        check(self.worker_call(untrusted, ticket('server-a'))['code'] == 'OUTCOME_UNKNOWN', 'Godot rejects HTTPS authority with wrong certificate trust')
        check(not self.worker_call(untrusted, {'op': 'status'})['has_hull'], 'untrusted service cannot spawn a hull')
        untrusted['child'].terminate(); untrusted['child'].wait(timeout=8)
        first, second = self.worker('server-a'), self.worker('server-b')
        grant = self.worker_call(first, ticket('server-a'))
        check(grant['ok'], 'Godot acquires public lease through verified HTTPS')
        check(self.worker_call(second, ticket('server-b'))['code'] == 'ACCOUNT_BUSY', 'second Godot cannot spawn same active public account')
        check(not self.worker_call(second, {'op': 'status'})['has_hull'], 'rejected admission creates no hull')
        binding = {key: grant[key] for key in ('account', 'epoch', 'generation')}
        check(self.worker_call(first, {'op': 'helm', 'binding': binding, 'throttle': 1, 'rudder': 0})['ok'], 'lease owner accepts helm input')
        time.sleep(1.2)
        moving = self.worker_call(first, {'op': 'status'})
        check(moving['speed'] > 0 and moving['distance'] > 0 and moving['collision'] > 0, 'actual starter hull advances physics with collisions')
        initial_deadline = moving['deadline']
        time.sleep(10)
        renewed = self.worker_call(first, {'op': 'status'})
        check(renewed['active'] and renewed['deadline'] > initial_deadline, 'Godot automatically renews lease at ten seconds')
        purchase = self.owned(grant, 'purchase', action_id='godot-buy', expected_revision=0)
        check(self.worker_call(first, purchase)['ok'], 'Godot purchase commits through shared authority')
        check(self.worker_call(first, self.owned(grant, 'begin', transfer_id='godot-transfer', destination='server-b'))['ok'], 'Godot departure begins')
        stopped = self.worker_call(first, {'op': 'status'})
        check(not stopped['active'] and stopped['paused'] and stopped['collision'] == 0 and stopped['speed'] == 0 and stopped['throttle'] == 0 and not stopped['visible'], 'departure parks actual hull physics collisions visibility and helm')
        check(not self.worker_call(first, {'op': 'helm', 'binding': binding, 'throttle': 1, 'rudder': 1})['ok'], 'quiesced hull rejects input')
        time.sleep(.3)
        check(self.worker_call(first, {'op': 'status'})['distance'] == stopped['distance'], 'parked hull remains stationary across frames')
        check(self.worker_call(first, self.owned(grant, 'seal', transfer_id='godot-transfer'))['ok'], 'Godot seals transfer')
        arrived = self.worker_call(second, ticket('server-b', 'claim', transfer_id='godot-transfer'))
        check(arrived['ok'], 'second Godot claims canonical public profile')
        arrival = self.worker_call(second, {'op': 'status'})
        check(arrival['active'] and arrival['ship_id'] == grant['profile']['ship']['id'] and len(arrival['cargo']) == 1 and arrival['speed'] == 0, 'destination restores stable hull and cargo records at neutral')
        check(abs(arrived['profile']['ship']['fuel_liters'] - stopped['fuel']) < .0001 and arrival['fuel'] <= stopped['fuel'] < grant['profile']['ship']['fuel_liters'], 'departure checkpoints actual consumed fuel before transfer')
        check(arrival['anchor']['latitude'] > 0 and abs(arrival['anchor']['latitude'] * 3.141592653589793 / 180 * 100000 - stopped['distance']) < .01, 'destination geographic anchor matches actual traveled meters')
        check(self.worker_call(first, purchase)['code'] == 'LOCAL_QUIESCED', 'source rejects economic writes after handoff')
        # Crash the actual destination executable, then recover on a fresh process.
        second['child'].kill(); second['child'].wait(timeout=8)
        self.expire()
        third = self.worker('server-c')
        recovered = self.worker_call(third, ticket('server-c'))
        check(recovered['ok'] and recovered['epoch'] > arrived['epoch'] and recovered['profile'] == arrived['profile'], 'new Godot process restores canonical state after destination crash')
        check(self.worker_call(third, self.owned(recovered, 'purchase', action_id='godot-buy', expected_revision=0)).get('duplicate'), 'payment receipt survives Godot process death')
        self.fixture.stop_db(immediate=True)
        check(self.worker_call(third, self.owned(recovered, 'renew'))['code'] == 'BACKEND_UNAVAILABLE', 'Godot detects actual database outage')
        outage = self.worker_call(third, {'op': 'status'})
        check(not outage['active'] and outage['paused'] and outage['collision'] == 0, 'backend outage removes live hull authority')
        self.fixture.start_db()
        time.sleep(.2)
        check(not self.worker_call(third, {'op': 'status'})['active'], 'database restart cannot silently reactivate hull')
        rebound = self.worker_call(third, ticket('server-c'))
        check(rebound['ok'] and rebound['generation'] > recovered['generation'], 'fresh authenticated admission restores explicit ownership')
        old_binding = {key: recovered[key] for key in ('account', 'epoch', 'generation')}
        check(not self.worker_call(third, {'op': 'helm', 'binding': old_binding, 'throttle': 1, 'rudder': 0})['ok'], 'old client generation cannot control recovered hull')
        self.expire()
        check(self.worker_call(third, self.owned(rebound, 'renew'))['code'] == 'STALE_AUTHORITY', 'expired database lease fences Godot owner')
        check(not self.worker_call(third, {'op': 'status'})['active'], 'expired owner is locally inactive')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', choices=['editor', 'release'], default='editor')
    args = parser.parse_args()
    proof = GodotProof(args.runtime)
    try:
        proof.setup()
        provider = load('real_oidc_fixture', ROOT / 'tools/auth_proof/probe.py')
        provider_folder = proof.run / 'provider'; provider_folder.mkdir()
        provider.oidc_proof(provider_folder, proof.integrate)
        (proof.run / 'godot-summary.json').write_text(json.dumps({'passed': True, 'runtime': args.runtime, 'checks': CHECKS, 'provider_checks': provider.CHECKS, 'scope': 'OIDC HTTPS live Godot owner adapters; operator courier, no public gameplay transport'}, indent=2))
        print('GODOT_AUTHORITY_PASS', len(CHECKS), args.runtime, flush=True)
    finally:
        proof.close()
