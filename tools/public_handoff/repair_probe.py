"""Real HTTPS/PostgreSQL repair/replay/crash gate; uses the existing Windows fixture stack."""
import json
from concurrent.futures import ThreadPoolExecutor
from voyage_probe import VoyageProof
from probe import CHECKS, check


class RepairProof(VoyageProof):
    def damaged(self, name):
        grant = self.session(name)
        current = self.call('server-a', self.owned(grant, 'inspect'))
        request = self.command(grant, 'impact', 'damage', damage_bp=2445,
                               fuel_liters=current['profile']['ship']['fuel_liters'],
                               position=current['profile']['ship']['position'])
        check(self.call('server-a', request)['code'] == 'HULL_DAMAGED', 'damage fixture saved')
        return grant

    def request(self, grant, action):
        return self.command(grant, 'repair', action, port_id='port_brindle_quay',
                            condition_bp=7555, cost_minor=6113)

    def exercise(self):
        a = self.damaged('repair-a')
        original = self.call('server-a', self.owned(a, 'inspect'))
        for code, fields in [('QUOTE_CHANGED', {'cost_minor': 6112}),
                             ('QUOTE_CHANGED', {'condition_bp': 7554}),
                             ('NO_REPAIR_SERVICE', {'port_id': 'ocean'}),
                             ('BAD_CONDITION', {'condition_bp': True}),
                             ('BAD_PRICE', {'cost_minor': 1.5}),
                             ('BAD_REQUEST', {'recipient': 'another_player'}),
                             ('STALE_AUTHORITY', {'generation': a['generation']+1})]:
            request = dict(self.request(a, 'reject_'+str(len(CHECKS))), **fields)
            check(self.call('server-a', request)['code'] == code, 'reject '+code)
        request = self.request(a, 'repair_once')
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: self.call('server-a', request), range(2)))
        check(all(r['ok'] for r in results) and sum(bool(r.get('duplicate')) for r in results) == 1,
              'concurrent replay charges once')
        check(self.call('server-a', dict(request, cost_minor=6114))['code'] == 'ID_CONFLICT', 'changed intent rejected')
        check(self.call('server-a', dict(request, action_id='stale'))['code'] == 'STALE_REVISION', 'stale revision rejected')
        current = self.call('server-a', self.owned(a, 'inspect'))
        check(current['money'] == original['money']-6113 and current['profile']['ship']['condition_bp'] == 10000,
              'exact payment and full restoration saved together')
        check(current['profile']['cargo'] == original['profile']['cargo'], 'cargo preserved')
        check(self.call('server-a', self.request(a, 'full'))['code'] == 'NO_REPAIR_NEEDED', 'full condition cannot charge')
        self.start_service()
        check(self.call('server-a', self.owned(a, 'inspect')) == current, 'service restart preserves repair and wallet')
        with self.authority.connect() as db:
            rows = db.execute('SELECT amount FROM public_authority.journal WHERE account=%s', (a['account'],)).fetchall()
        check(sum(row['amount'] for row in rows) == -6113, 'repair debit recorded once in journal')

    def crashes(self):
        for stage in ('after_profile_write', 'before_commit', 'after_commit'):
            a = self.damaged('repair-crash-'+stage)
            request = self.request(a, 'crash_'+stage)
            self.start_service(dict(stage=stage, action_id=request['action_id']))
            try: self.call('server-a', request)
            except Exception:
                self.process.wait(timeout=8)
                check(self.process.returncode == 91 and (self.run/'fault-marker').read_text() == stage,
                      'real authority termination at '+stage)
            else: raise AssertionError('fault not triggered')
            self.start_service()
            current = self.call('server-a', self.owned(a, 'inspect'))
            committed = stage == 'after_commit'
            check(current['money'] == (13887 if committed else 20000) and
                  current['profile']['ship']['condition_bp'] == (10000 if committed else 7555),
                  'money and condition atomic at '+stage)
            result = self.call('server-a', request)
            check(result['ok'] and bool(result.get('duplicate')) == committed, 'same intent recovers once at '+stage)
            check(self.call('server-a', request).get('duplicate'), 'further replay harmless')


if __name__ == '__main__':
    proof = RepairProof()
    try:
        proof.setup(); proof.exercise(); proof.crashes()
        (proof.run/'repair-summary.json').write_text(json.dumps(dict(passed=True, checks=CHECKS), indent=2))
        print('PUBLIC_REPAIR_PASS', len(CHECKS), 'Evidence:', proof.run, flush=True)
    finally: proof.close()
