"""Normal dedicated runtime: combined voyage lifecycle and bounded eight-peer load.

Fixture tickets isolate gameplay from the separately tested native OIDC login.
Windows process counters include all dedicated-process threads, not backend peers.
"""
import argparse
import ctypes
from ctypes import wintypes
import json
import math
import time
from peer_probe import PeerProof
from probe import CHECKS, check, free_port
from psycopg.types.json import Jsonb


class Memory(ctypes.Structure):
    _fields_ = [('cb', wintypes.DWORD), ('faults', wintypes.DWORD)] + [
        (name, ctypes.c_size_t) for name in ['peak_working', 'working', 'peak_paged',
        'paged', 'peak_nonpaged', 'nonpaged', 'pagefile', 'peak_pagefile', 'private']]


def process_sample(child):
    times = [wintypes.FILETIME() for _ in range(4)]
    handle = wintypes.HANDLE(int(child._handle))
    if not ctypes.windll.kernel32.GetProcessTimes(handle, *[ctypes.byref(t) for t in times]):
        raise ctypes.WinError()
    cpu = sum((t.dwHighDateTime << 32) + t.dwLowDateTime for t in times[2:]) / 1e7
    memory = Memory(); memory.cb = ctypes.sizeof(memory)
    if not ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(memory), memory.cb):
        raise ctypes.WinError()
    return dict(cpu_seconds=cpu, working_bytes=memory.working, private_bytes=memory.private)


def p95(values):
    return sorted(values)[math.ceil(len(values) * .95) - 1]


class Foundation(PeerProof):
    def profile_for(self, account):
        with self.authority.connect() as db:
            return dict(db.execute('SELECT revision,money,profile FROM public_authority.profiles WHERE account=%s', (account,)).fetchone())

    def position_fixture(self, account, latitude=0, longitude=0, heading=0):
        with self.authority.connect() as db:
            row = db.execute('SELECT profile FROM public_authority.profiles WHERE account=%s', (account,)).fetchone()['profile']
            row['ship']['position'] = dict(latitude=latitude, longitude=longitude, heading=heading)
            db.execute('UPDATE public_authority.profiles SET profile=%s WHERE account=%s', (Jsonb(row), account))

    def join(self, port, account, rendered=False):
        client = self.peer_worker('client', port, rendered=rendered)
        nonce = self.until(client, lambda s: bool(s['nonce']))['nonce']
        self.worker_call(client, dict(op='ticket', ticket=self.authority.issue_ticket(account, 'server-a', nonce)))
        self.until(client, lambda s: s.get('presentation', {}).get('ready', False))
        return client

    def vacant(self, accounts):
        end = time.monotonic() + 15
        while time.monotonic() < end:
            with self.authority.connect() as db:
                phases = [db.execute('SELECT phase FROM public_authority.leases WHERE account=%s', (a,)).fetchone()['phase'] for a in accounts]
            if all(p == 'VACANT' for p in phases): return
            time.sleep(.1)
        raise AssertionError('Ownership not released')

    def drain(self, server, marker, accounts):
        marker.touch()
        check(server['child'].wait(timeout=25) == 0, 'normal dedicated shutdown confirms final saves')
        self.vacant(accounts)
        check(True, 'all connected accounts release canonical ownership')

    def reparent_checkpoint(self):
        owner = self.worker('server-a')
        grant = self.worker_call(owner, self.join_request('server-a'))
        check(grant['ok'], 'regression fixture acquires canonical owner')
        result = self.worker_call(owner, dict(op='reparent_checkpoint'))
        check(result['ok'] and result['inflight'], 'checkpoint completes when owner is reparented during its live HTTPS request')
        check(self.worker_call(owner, self.owned(grant, 'release'))['ok'], 'reparented owner releases lease after completed save')
        owner['child'].terminate(); owner['child'].wait(timeout=8)

    def combined(self):
        accounts = [self.account, self.authority.create_fixture_account('https://fixture.invalid', 'foundation-second')]
        self.position_fixture(accounts[1], latitude=math.degrees(100 / 100000), heading=180)
        initial = [self.profile_for(a) for a in accounts]
        port = free_port(True); marker = self.run / 'combined-stop'
        server = self.peer_worker('server', port, dedicated=True, stop_file=str(marker))
        clients = [self.join(port, a, rendered=(i == 0)) for i, a in enumerate(accounts)]
        ids = [self.status(c)['binding']['ship'] for c in clients]
        check(len(set(ids)) == 2, 'two accounts control distinct canonical boats')
        self.until(clients[0], lambda s: len(s['replicas']) == 2)
        for c in clients: self.worker_call(c, dict(op='drive'))
        minimum = 1000; contact_samples = 0; deadline = time.monotonic() + 35
        while time.monotonic() < deadline:
            states = [self.status(c) for c in clients]
            rows = {r['ship']: r for r in states[0]['replicas']}
            if len(rows) != 2: raise AssertionError('Missing collision-relevant replica')
            dz = rows[ids[1]]['z'] - rows[ids[0]]['z']
            minimum = min(minimum, dz)
            if 63.8 <= dz < 64.4 and all(s['snapshot']['speed'] < .1 and s['presentation']['order'] > .9 for s in states):
                contact_samples += 1
                if contact_samples >= 6: break
            time.sleep(.2)
        check(contact_samples >= 6 and minimum >= 63.8, 'opposing live boats stop at hull contact without crossing while forward orders remain applied')
        check(all(s['snapshot']['fuel'] < 800 for s in states), 'both authoritative boats consume fuel during combined sailing')
        # Clear the conservative spawn exclusion before saving/restarting.
        for c in clients: self.worker_call(c, dict(op='drive', axis=-1))
        for c in clients: self.until(c, lambda s: s['snapshot'].get('forward_speed', 0) < -.3)
        time.sleep(5)
        for c in clients: self.worker_call(c, dict(op='menu', open=True))
        self.worker_call(clients[0], dict(op='disconnect'))
        self.vacant([accounts[0]])
        check(bool(self.status(clients[1])['binding']), 'one departure saves independently while the second player stays connected')
        self.drain(server, marker, accounts)
        saved = [self.profile_for(a) for a in accounts]
        for before, after in zip(initial, saved):
            check(after['revision'] > before['revision'] and after['profile']['ship']['fuel_liters'] < 800, 'sailing and shutdown persist fuel and advance revision')
            check(after['profile']['ship']['position'] != before['profile']['ship']['position'], 'authoritative movement persists geographic position')
            check(after['money'] == before['money'] and after['profile']['cargo'] == before['profile']['cargo'] and after['profile']['jobs'] == before['profile']['jobs'], 'sailing lifecycle preserves wallet cargo and jobs')
        marker.unlink()
        restarted = self.peer_worker('server', port, dedicated=True, stop_file=str(marker))
        resumed = [self.join(port, a) for a in accounts]
        check([self.status(c)['binding']['ship'] for c in resumed] == ids, 'fresh dedicated process restores both original ship identities')
        check([self.profile_for(a) for a in accounts] == saved, 'both reconnects preserve complete committed profiles and revisions')
        self.until(resumed[0], lambda s: len(s['replicas']) == 2)
        check(True, 'restarted clients see the complete two-boat roster')
        self.drain(restarted, marker, accounts)
        for c in clients + resumed:
            c['child'].terminate(); c['child'].wait(timeout=8)
        return dict(minimum_observed_center_separation_m=minimum, contact_samples=contact_samples)

    def workload(self, seconds):
        port = free_port(True); marker = self.run / 'load-stop'
        server = self.peer_worker('server', port, dedicated=True, stop_file=str(marker))
        base = process_sample(server['child']); start = time.monotonic(); time.sleep(3)
        idle = (process_sample(server['child'])['cpu_seconds'] - base['cpu_seconds']) / (time.monotonic() - start)
        clients = []; accounts = []
        for i in range(8):
            account = self.authority.create_fixture_account('https://fixture.invalid', 'foundation-load-' + str(i))
            accounts.append(account); self.position_fixture(account, longitude=i * .04)
            clients.append(self.join(port, account, rendered=(i == 0)))
        for c in clients: self.worker_call(c, dict(op='drive'))
        self.until(clients[0], lambda s: len(s['replicas']) == 8)
        base = process_sample(server['child']); start = time.monotonic(); samples = []; frames = []; polls = 0
        while time.monotonic() - start < seconds:
            samples.append(process_sample(server['child']))
            for c in clients:
                state = self.status(c)
                check_state = state['presentation']['ready'] and len(state['replicas']) == 8 and state['snapshot']['fuel'] > 0
                if not check_state: raise AssertionError('A loaded client lost ready state, fuel or complete nearby roster')
            frames = self.status(clients[0])['frame_ms']
            polls += 1; time.sleep(.75)
        elapsed = time.monotonic() - start; end = process_sample(server['child'])
        check(polls >= 30, 'eight sailing clients retain fresh complete rosters throughout sustained sample')
        revisions = [self.profile_for(a)['revision'] for a in accounts]
        check(all(r >= 3 for r in revisions), 'all eight players receive repeated periodic saves under load')
        check(self.status(clients[0])['frames_drawn'] > 0, 'loaded player sample includes native graphics frames')
        metrics = dict(seconds=elapsed, polls=polls, clients=8, idle_cpu_core_equivalents=idle,
            server_cpu_core_equivalents=(end['cpu_seconds']-base['cpu_seconds'])/elapsed,
            peak_working_mib=max(s['working_bytes'] for s in samples)/1048576,
            peak_private_mib=max(s['private_bytes'] for s in samples)/1048576,
            private_growth_mib=(end['private_bytes']-base['private_bytes'])/1048576,
            rendered_recent_frame_p95_ms=p95(frames), rendered_recent_frame_max_ms=max(frames),
            saved_revisions=revisions)
        self.drain(server, marker, accounts)
        return metrics


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--runtime', choices=['editor', 'release'], default='release')
    parser.add_argument('--load-seconds', type=int, default=60); args = parser.parse_args()
    if args.load_seconds < 60: parser.error('Use at least 60 seconds for the workload sample')
    proof = Foundation(args.runtime)
    try:
        proof.setup(); proof.reparent_checkpoint(); combined = proof.combined(); workload = proof.workload(args.load_seconds)
        report = dict(passed=True, runtime=args.runtime, fixture_tickets=True, checks=CHECKS, combined=combined, workload=workload)
        (proof.run/'foundation-summary.json').write_text(json.dumps(report, indent=2))
        print('FOUNDATION_PASS', len(CHECKS), json.dumps(workload), flush=True)
    finally: proof.close()
