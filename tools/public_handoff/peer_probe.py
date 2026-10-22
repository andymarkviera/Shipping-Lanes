"""Real OIDC tickets -> verified DTLS -> peer-bound Godot hull commands."""
import argparse
import hashlib
import json
import os
import subprocess
import time
import datetime

from godot_probe import GodotProof, load
from probe import ROOT, WORKSPACE, CHECKS, check, free_port, psycopg


class PeerProof(GodotProof):
    def setup(self):
        super().setup()
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.x509.oid import NameOID
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'localhost')])
        now = datetime.datetime.now(datetime.timezone.utc)
        cert = x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=5)).not_valid_after(now+datetime.timedelta(days=1)).add_extension(x509.BasicConstraints(ca=True, path_length=0), critical=True).add_extension(x509.SubjectAlternativeName([x509.DNSName('localhost')]), critical=False).sign(key, hashes.SHA256())
        (self.run / 'peer-cert.pem').write_bytes(cert.public_bytes(serialization.Encoding.PEM))
        (self.run / 'peer-key.pem').write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))

    def peer_worker(self, role, port, dedicated=False, **overrides):
        self.worker_number += 1
        folder = self.run / ('peer-' + str(self.worker_number)); folder.mkdir()
        cert = self.run / 'peer-cert.pem'
        fingerprint = hashlib.sha256(cert.read_bytes()).hexdigest()
        config = {'role': role, 'port': port, 'server': 'server-a', 'certificate': str(cert), 'fingerprint': fingerprint}
        if role == 'server':
            config.update(endpoint='https://127.0.0.1:' + str(self.port), credential=self.credentials['server-a'], ca=str(self.run / 'ca.pem'), key=str(self.run / 'peer-key.pem'))
            with psycopg.connect(**self.fixture.admin) as db:
                db.execute("UPDATE public_authority.servers SET fingerprint=%s WHERE id='server-a'", (fingerprint,))
        config.update(overrides)
        path = folder / 'config.json'; path.write_text(json.dumps(config))
        executable = WORKSPACE / 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe' if self.runtime == 'editor' else ROOT / 'exports/windows-x86_64/release/ShippingLanes.exe'
        args = [str(executable), '--headless']
        if self.runtime == 'editor': args += ['--path', str(ROOT)]
        args += ['--', '--public-server-config=' + str(path)] if dedicated else ['--', '--public-peer-check', '--peer-folder=' + str(folder)]
        env = os.environ.copy(); env['APPDATA'] = str(folder / 'user')
        log = (folder / 'godot.log').open('wb'); self.logs.append(log)
        child = subprocess.Popen(args, env=env, stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        self.children.append(child)
        worker = {'child': child, 'folder': folder, 'sequence': 0}
        if dedicated:
            deadline = time.monotonic() + 12
            while time.monotonic() < deadline:
                if 'PUBLIC_SERVER_LISTENING' in (folder / 'godot.log').read_text(errors='replace'): break
                if child.poll() is not None: break
                time.sleep(.05)
            check('PUBLIC_SERVER_LISTENING' in (folder / 'godot.log').read_text(errors='replace'), 'dedicated server configuration entry point starts')
        else:
            ready = self.wait_worker(worker, folder / 'ready.json')
            check(ready['ok'], role + ' DTLS runtime starts')
        path.unlink()
        return worker

    def status(self, worker): return self.worker_call(worker, {'op': 'status'})

    def until(self, worker, predicate, timeout=10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            result = self.status(worker)
            if predicate(result): return result
            time.sleep(.08)
        raise AssertionError('Peer state timeout; inspect ' + str(worker['folder']))

    def rejected(self, server, client, command):
        before = self.status(server)
        deadline = time.monotonic() + 6
        while time.monotonic() < deadline:
            self.worker_call(client, command)
            time.sleep(.12)
            after = self.status(server)
            if after['rejected'] > before['rejected']:
                check(after['accepted'] == before['accepted'], 'rejected command never advances accepted helm count')
                return after
        raise AssertionError('Invalid input did not reach rejection path')

    def exercise_workers(self, ticket):
        port = free_port()
        server = self.peer_worker('server', port)
        wrong = self.peer_worker('client', port, hostname='wrong.invalid')
        bad = self.until(wrong, lambda s: s['notice'] == 'Disconnected')
        check(not bad['nonce'] and not bad['ticket_sent'], 'no credential sent before certificate hostname verification')
        wrong['child'].terminate(); wrong['child'].wait()
        rotated = self.peer_worker('client', port)
        rotation_nonce = self.until(rotated, lambda s: bool(s['nonce']))['nonce']
        with psycopg.connect(**self.fixture.admin) as db:
            original = db.execute("SELECT fingerprint FROM public_authority.servers WHERE id='server-a'").fetchone()[0]
            db.execute("UPDATE public_authority.servers SET fingerprint=%s WHERE id='server-a'", ('0' * 64,))
        self.worker_call(rotated, {'op': 'ticket', 'ticket': ticket('server-a', nonce=rotation_nonce)['ticket']})
        self.until(rotated, lambda s: s['notice'] == 'Disconnected')
        check(self.status(server)['members'] == 0, 'presented game certificate must match backend server registration')
        with psycopg.connect(**self.fixture.admin) as db:
            db.execute("UPDATE public_authority.servers SET fingerprint=%s WHERE id='server-a'", (original,))
        rotated['child'].terminate(); rotated['child'].wait()
        first = self.peer_worker('client', port)
        challenge = self.until(first, lambda s: bool(s['nonce']))['nonce']
        check(not self.status(first)['binding'] and self.status(server)['members'] == 0, 'DTLS alone grants no hull or helm')
        issued = ticket('server-a', nonce=challenge)
        thief = self.peer_worker('client', port)
        other_nonce = self.until(thief, lambda s: bool(s['nonce']))['nonce']
        check(other_nonce != challenge, 'server issues distinct connection-bound challenges')
        self.worker_call(thief, {'op': 'ticket', 'ticket': issued['ticket']})
        self.until(thief, lambda s: s['notice'] == 'Disconnected')
        check(self.status(server)['members'] == 0, 'ticket from another connection cannot spawn or consume identity')
        thief['child'].terminate(); thief['child'].wait()
        self.worker_call(first, {'op': 'ticket', 'ticket': issued['ticket']})
        joined = self.until(first, lambda s: bool(s['binding']))
        binding = joined['binding']
        check(self.status(server)['members'] == 1, 'OIDC ticket over DTLS installs one authenticated helm')
        # Actual commands traverse ENet RPC; no server-side courier controls motion.
        for sequence in range(1, 12):
            self.worker_call(first, {'op': 'helm', 'sequence': sequence, 'throttle': 1.0})
            time.sleep(.08)
        moving = self.until(first, lambda s: s['snapshot'].get('distance', 0) > .01)
        check(moving['snapshot']['speed'] > 0 and moving['snapshot']['ship'] == binding['ship'], 'server simulates boat and sends matching owner snapshots over DTLS')
        before = self.status(server)
        self.rejected(server, first, {'op': 'helm', 'sequence': moving['snapshot']['sequence'], 'throttle': -1.0})
        self.rejected(server, first, {'op': 'helm', 'sequence': 12, 'throttle': 1.0, 'candidate': dict(binding, ship='another-ship')})
        self.rejected(server, first, {'op': 'helm', 'sequence': 13, 'throttle': 1.0, 'candidate': dict(binding, generation=binding['generation'] + 1)})
        after = self.rejected(server, first, {'op': 'helm', 'sequence': 14, 'throttle': 4.0})
        check(after['accepted'] == before['accepted'], 'duplicate sequence wrong ship wrong generation and invalid throttle rejected')
        stranger = self.peer_worker('client', port)
        self.until(stranger, lambda s: bool(s['nonce']))
        self.rejected(server, stranger, {'op': 'helm', 'sequence': 20, 'throttle': 1.0, 'candidate': binding})
        check(self.status(server)['accepted'] == after['accepted'], 'unauthenticated peer cannot use another player binding')
        self.worker_call(stranger, {'op': 'disconnect'})
        stranger['child'].terminate(); stranger['child'].wait()
        second_account = self.authority.create_fixture_account('https://fixture.invalid', 'second-peer-account')
        with psycopg.connect(**self.fixture.admin) as db:
            db.execute("UPDATE public_authority.profiles SET profile=jsonb_set(profile, '{ship,position,longitude}', '0.1'::jsonb) WHERE account=%s", (second_account,))
        second = self.peer_worker('client', port)
        second_nonce = self.until(second, lambda s: bool(s['nonce']))['nonce']
        self.worker_call(second, {'op': 'ticket', 'ticket': self.authority.issue_ticket(second_account, 'server-a', second_nonce)})
        second_join = self.until(second, lambda s: bool(s['binding']))
        check(self.status(server)['members'] == 2 and second_join['binding']['ship'] != binding['ship'], 'two enrolled accounts receive distinct concurrent helms')
        visible = self.until(first, lambda s: len(s['visible_ships']) == 2)
        check(set(visible['visible_ships']) == {binding['ship'], second_join['binding']['ship']}, 'authenticated observer materializes both canonical hulls')
        check(len(self.until(second, lambda s: len(s['visible_ships']) == 2)['visible_ships']) == 2, 'both clients receive the shared nearby roster')
        remote = next(r for r in visible['replicas'] if r['ship'] == second_join['binding']['ship'])
        check(-176 < remote['x'] < -173 and all(r['inert'] for r in visible['replicas']), 'distinct geographic anchors map to nearby inert visual hulls without spawning at zero')
        self.rejected(server, second, {'op': 'helm', 'sequence': 1, 'throttle': 1.0, 'candidate': binding})
        for seq in range(2, 12):
            self.worker_call(second, {'op': 'helm', 'sequence': seq, 'throttle': .8})
            time.sleep(.08)
        second_state = self.until(second, lambda s: s['snapshot'].get('speed', 0) > 0)
        check(second_state['snapshot']['ship'] == second_join['binding']['ship'], 'second authenticated peer receives only its own ship state')
        self.worker_call(second, {'op': 'disconnect'})
        self.until(server, lambda s: s['members'] == 1)
        check(self.until(first, lambda s: len(s['visible_ships']) == 1)['visible_ships'] == [binding['ship']], 'departed hull removed by complete roster snapshot')
        check(not self.status(second)['visible_ships'], 'disconnect clears all presentation replicas')
        neutral = self.until(server, lambda s: s['ships'] and s['ships'][0]['throttle'] == 0)
        check(neutral['ships'][0]['active'], 'missing input neutralizes throttle without revoking healthy lease')
        replacement = self.peer_worker('client', port)
        nonce = self.until(replacement, lambda s: bool(s['nonce']))['nonce']
        self.worker_call(replacement, {'op': 'ticket', 'ticket': ticket('server-a', nonce=nonce)['ticket']})
        rebound = self.until(replacement, lambda s: bool(s['binding']))
        self.until(first, lambda s: s['notice'] == 'Disconnected')
        check(rebound['binding']['ship'] == binding['ship'] and rebound['binding']['generation'] > binding['generation'] and self.status(server)['members'] == 1, 'authenticated replacement disconnects previous peer before activating one hull')
        self.rejected(server, replacement, {'op': 'helm', 'sequence': 1, 'throttle': 1.0, 'candidate': binding})
        check(self.status(server)['ships'][0]['throttle'] == 0, 'old generation remains fenced on the new transport')
        self.worker_call(replacement, {'op': 'helm', 'sequence': 2, 'throttle': .8})
        time.sleep(.3)
        self.worker_call(replacement, {'op': 'disconnect'})
        self.until(server, lambda s: s['members'] == 0)
        deadline = time.monotonic() + 8
        released = False
        while time.monotonic() < deadline:
            with psycopg.connect(**self.fixture.admin) as db:
                released = db.execute('SELECT phase FROM public_authority.leases WHERE account=%s', (self.account,)).fetchone()[0] == 'VACANT'
            if released: break
            time.sleep(.1)
        check(released, 'disconnect parks hull then checkpoints and releases backend lease')
        check(self.profile()['profile']['ship']['fuel_liters'] < 800, 'disconnect saves actual fuel consumption')
        final = self.peer_worker('client', port)
        nonce = self.until(final, lambda s: bool(s['nonce']))['nonce']
        self.worker_call(final, {'op': 'ticket', 'ticket': ticket('server-a', nonce=nonce)['ticket']})
        self.until(final, lambda s: bool(s['binding']))
        self.fixture.stop_db(immediate=True)
        self.until(final, lambda s: s['notice'] == 'Disconnected', timeout=18)
        check(self.status(server)['members'] == 0, 'automatic renewal detects database outage and disconnects live helm')
        self.fixture.start_db()
        time.sleep(.25)
        check(self.status(server)['members'] == 0, 'backend restart does not silently re-admit disconnected client')
        server['child'].terminate(); server['child'].wait()
        dedicated_port = free_port(udp=True)
        self.peer_worker('server', dedicated_port, dedicated=True)
        live = self.peer_worker('client', dedicated_port)
        nonce = self.until(live, lambda s: bool(s['nonce']))['nonce']
        self.worker_call(live, {'op': 'ticket', 'ticket': ticket('server-a', nonce=nonce)['ticket']})
        self.until(live, lambda s: bool(s['binding']))
        check(bool(self.until(live, lambda s: bool(s['snapshot']))['snapshot']), 'normal dedicated entry point accepts authenticated player and replicates state')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', choices=['editor', 'release'], default='editor')
    parser.add_argument('--adapter-only', action='store_true', help='Use fixture-issued tickets for transport diagnostics; not the OIDC integration result.')
    args = parser.parse_args()
    proof = PeerProof(args.runtime)
    try:
        proof.setup()
        provider_checks = []
        if args.adapter_only:
            def ticket(server, op='admit', **extra):
                nonce = extra['nonce']
                return {'ticket': proof.authority.issue_ticket(proof.account, server, nonce)}
            proof.exercise_workers(ticket)
        else:
            provider = load('peer_oidc_fixture', ROOT / 'tools/auth_proof/probe.py')
            folder = proof.run / 'provider'; folder.mkdir()
            provider.oidc_proof(folder, proof.integrate)
            provider_checks = provider.CHECKS
        (proof.run / 'peer-summary.json').write_text(json.dumps({'passed': True, 'runtime': args.runtime, 'adapter_only': args.adapter_only, 'checks': CHECKS, 'provider_checks': provider_checks}, indent=2))
        print('PUBLIC_PEER_PASS', len(CHECKS), args.runtime, flush=True)
    finally: proof.close()
