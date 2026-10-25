"""Durable container contracts through real HTTPS/PostgreSQL; no Godot port RPC yet."""
import json
import time
from concurrent.futures import ThreadPoolExecutor
from probe import Proof, CHECKS, check

class VoyageProof(Proof):
    def session(self, name, server='server-a'):
        account = self.authority.create_fixture_account('https://fixture.invalid', name)
        grant = self.call(server, self.join_request(server, account))
        check(grant['ok'], 'authenticated fixture account admitted: '+name)
        return grant

    def command(self, grant, op, action, server='server-a', **extra):
        current = self.call(server, self.owned(grant, 'inspect'))
        check(current['ok'], 'canonical profile inspected before '+action)
        return self.owned(grant, op, action_id=action, expected_revision=current['revision'], **extra)

    def ready_load(self, grant, suffix, server='server-a'):
        request = self.command(grant, 'voyage_accept', 'accept_'+suffix, server,
            offer_id='container_seed_v1_0_0', port_id='port_brindle_quay')
        accepted = self.call(server, request)
        check(accepted['ok'], 'contract accepted '+suffix)
        time.sleep(5.1)
        request = self.command(grant, 'voyage_load', 'load_'+suffix, server,
            job_id=accepted['job']['id'], port_id='port_brindle_quay')
        loaded = self.call(server, request)
        check(loaded['ok'], 'durable timer permits loading '+suffix)
        return loaded['job']

    def contracts(self):
        a, b = self.session('voyage-a'), self.session('voyage-b')
        ra = self.command(a, 'voyage_accept', 'accept', offer_id='container_seed_v1_0_0', port_id='port_brindle_quay')
        rb = self.command(b, 'voyage_accept', 'accept', offer_id='container_seed_v1_0_0', port_id='port_brindle_quay')
        with ThreadPoolExecutor(2) as pool:
            aa, bb = list(pool.map(lambda r: self.call('server-a', r), [ra, rb]))
        check(aa['ok'] and bb['ok'] and aa['job']['id'] != bb['job']['id'], 'two accounts have independent cargo contracts')
        check(self.call('server-a', ra).get('duplicate'), 'repeated acceptance returns original receipt')
        check(self.call('server-a', dict(ra, offer_id='container_seed_v1_0_1'))['code']=='ID_CONFLICT', 'same request ID cannot change contract')
        check(self.call('server-a', dict(ra, reward_minor=999999))['code']=='BAD_REQUEST', 'client/server request cannot supply a reward')
        second = self.command(a, 'voyage_accept', 'second', offer_id='container_seed_v1_0_1', port_id='port_brindle_quay')
        check(self.call('server-a', second)['code']=='JOB_ALREADY_ACTIVE', 'one active voyage enforced')
        early = self.command(a, 'voyage_load', 'early', job_id=aa['job']['id'], port_id='port_brindle_quay')
        check(self.call('server-a', early)['code']=='LOADING_PENDING', 'early loading cannot create cargo')
        check(self.call('server-a', self.owned(a, 'inspect'))['profile']['cargo']==[], 'pending load has no phantom cargo')
        time.sleep(5.1)
        # Reopening service does not reset database-backed loading time or acceptance.
        self.start_service()
        for g, accepted in [(a, aa), (b, bb)]:
            load = self.command(g, 'voyage_load', 'load', job_id=accepted['job']['id'], port_id='port_brindle_quay')
            check(self.call('server-a', load)['ok'], 'load completes after service restart')
            check(self.call('server-a', load).get('duplicate'), 'load retry never duplicates cargo')
        current = self.call('server-a', self.owned(a, 'inspect'))
        cargo_id = current['profile']['cargo'][0]['id']
        wrong = self.command(a, 'deliver', 'fixture_bypass', cargo_id=cargo_id)
        check(self.call('server-a', wrong)['code']=='CARGO_NOT_OWNED', 'legacy fixture delivery cannot consume contract cargo')
        wrong = self.command(a, 'voyage_deliver', 'wrong_port', job_id=aa['job']['id'], port_id='port_brindle_quay')
        check(self.call('server-a', wrong)['code']=='WRONG_PORT', 'delivery requires contract destination')
        request = self.command(a, 'voyage_deliver', 'pay', job_id=aa['job']['id'], port_id='port_slatewater_works')
        with ThreadPoolExecutor(2) as pool:
            paid = list(pool.map(lambda _: self.call('server-a', request), range(2)))
        check(all(r['ok'] for r in paid) and sum(bool(r.get('duplicate')) for r in paid)==1, 'concurrent repeated payout commits once')
        current = self.call('server-a', self.owned(a, 'inspect'))
        check(current['money']==45000 and current['profile']['cargo']==[], 'exact quoted payment and cargo removal commit together')
        check(len(current['profile']['delivered'])==1, 'one cargo tombstone retained')
        other = self.call('server-a', self.owned(b, 'inspect'))
        check(other['money']==20000 and len(other['profile']['cargo'])==1, 'other account remains unchanged')
        request = self.command(b, 'voyage_cancel', 'no_confirm', job_id=bb['job']['id'], abandon=False)
        check(self.call('server-a', request)['code']=='CONFIRM_ABANDON', 'loaded cancellation requires explicit abandonment')
        request = self.command(b, 'voyage_cancel', 'abandon', job_id=bb['job']['id'], abandon=True)
        check(self.call('server-a', request)['ok'], 'loaded contract can be abandoned')
        current = self.call('server-a', self.owned(b, 'inspect'))
        check(current['money']==20000 and current['profile']['cargo']==[], 'abandonment pays nothing')

    def loading_crashes(self):
        for stage in ['after_profile_write', 'before_commit', 'after_commit']:
            grant = self.session('loading-crash-'+stage)
            request = self.command(grant, 'voyage_accept', 'loading_accept', offer_id='container_seed_v1_0_0', port_id='port_brindle_quay')
            accepted = self.call('server-a', request)
            check(accepted['ok'], 'loading-crash fixture accepted')
            time.sleep(5.1)
            request = self.command(grant, 'voyage_load', 'load_crash_'+stage, job_id=accepted['job']['id'], port_id='port_brindle_quay')
            self.start_service(dict(stage=stage, action_id=request['action_id']))
            try: self.call('server-a', request)
            except Exception:
                self.process.wait(timeout=8)
                check(self.process.returncode==91 and (self.run/'fault-marker').read_text()==stage, 'real loading authority crash at '+stage)
            else: raise AssertionError('loading fault did not terminate authority')
            self.start_service()
            current = self.call('server-a', self.owned(grant, 'inspect'))
            committed = stage=='after_commit'
            check(current['money']==20000 and len(current['profile']['cargo'])==int(committed), 'loading crash retains all-or-nothing cargo at '+stage)
            result = self.call('server-a', request)
            check(result['ok'] and bool(result.get('duplicate'))==committed, 'same loading request safely reconciles '+stage)
            check(len(self.call('server-a', self.owned(grant, 'inspect'))['profile']['cargo'])==1, 'exactly one loaded batch after crash recovery')

    def handoff(self):
        a = self.session('voyage-handoff')
        job = self.ready_load(a, 'handoff')
        check(self.call('server-a', self.owned(a, 'begin', transfer_id='voyage-transfer', destination='server-b'))['ok'], 'loaded voyage begins server transfer')
        check(self.call('server-a', self.owned(a, 'seal', transfer_id='voyage-transfer'))['ok'], 'loaded voyage sealed')
        b = self.call('server-b', self.join_request('server-b', a['account'], op='claim', transfer_id='voyage-transfer'))
        check(b['ok'] and len(b['profile']['cargo'])==1, 'destination receives same loaded voyage')
        request = self.command(b, 'voyage_deliver', 'handoff_pay', 'server-b', job_id=job['id'], port_id='port_slatewater_works')
        check(self.call('server-b', request)['ok'], 'new owner settles transferred voyage')
        stale = dict(request, epoch=a['epoch'], generation=a['generation'])
        check(self.call('server-a', stale)['code']=='STALE_AUTHORITY', 'old server cannot settle after transfer')

    def crashes(self):
        for stage in ['after_profile_write', 'before_commit', 'after_commit']:
            grant = self.session('voyage-crash-'+stage)
            job = self.ready_load(grant, stage)
            request = self.command(grant, 'voyage_deliver', 'crash_'+stage, job_id=job['id'], port_id='port_slatewater_works')
            self.start_service(dict(stage=stage, action_id=request['action_id']))
            try: self.call('server-a', request)
            except Exception:
                # The test requires both process exit and the exact armed marker.
                self.process.wait(timeout=8)
                check(self.process.returncode==91 and (self.run/'fault-marker').read_text()==stage, 'real authority process terminated at '+stage)
            else: raise AssertionError('fault did not terminate authority')
            self.start_service()
            state = self.call('server-a', self.owned(grant, 'inspect'))
            committed = stage=='after_commit'
            check(state['money']==(45000 if committed else 20000) and len(state['profile']['cargo'])==(0 if committed else 1), 'crash preserves atomic cargo/payment at '+stage)
            result = self.call('server-a', request)
            check(result['ok'] and bool(result.get('duplicate'))==committed, 'same request recovers uncertain payout at '+stage)
            check(self.call('server-a', request).get('duplicate'), 'further payout replay remains idempotent')

if __name__=='__main__':
    proof=VoyageProof()
    try:
        proof.setup(); proof.contracts(); proof.handoff(); proof.crashes(); proof.loading_crashes()
        (proof.run/'voyage-contract-summary.json').write_text(json.dumps(dict(passed=True, checks=CHECKS, scope='trusted-server HTTPS contract authority; no player RPC/physical docking yet'), indent=2))
        print('PUBLIC_VOYAGE_CONTRACT_PASS',len(CHECKS), 'Evidence:',proof.run,flush=True)
    finally: proof.close()
