"""Real HTTPS/PostgreSQL ship purchase gate; uses the isolated Windows fixture stack."""
import json
from concurrent.futures import ThreadPoolExecutor
from voyage_probe import VoyageProof
from probe import CHECKS, check


class ShipPurchaseProof(VoyageProof):
    def funded(self, name):
        grant = self.session(name)
        # Explicit disposable harness account only, never a live player account.
        with self.authority.connect() as db:
            db.execute('UPDATE public_authority.profiles SET money=300000 WHERE account=%s', (grant['account'],))
        return grant

    def request(self, grant, action):
        return self.command(grant, 'ship_purchase', action, port_id='port_brindle_quay',
                            definition_id='ship_coastal_container_01', cost_minor=90000)

    def exercise(self):
        a = self.funded('ship-purchase-a')
        original = self.call('server-a', self.owned(a, 'inspect'))
        request = self.request(a, 'buy_once')
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: self.call('server-a', request), range(2)))
        check(all(r['ok'] for r in results) and sum(bool(r.get('duplicate')) for r in results) == 1,
              'concurrent duplicate request commits only once')
        check(results[0]['owned_ship']['id'] == results[1]['owned_ship']['id'], 'replay returns original owned ID')
        check(self.call('server-a', dict(request, cost_minor=90001))['code'] == 'ID_CONFLICT', 'changed intent rejected')
        check(self.call('server-a', dict(request, action_id='stale'))['code'] == 'STALE_REVISION', 'stale revision rejected')
        second = self.call('server-a', self.request(a, 'buy_twice'))
        check(second['ok'] and second['owned_ship']['id'] != results[0]['owned_ship']['id'],
              'two deliberate purchases have distinct owned IDs')
        current = self.call('server-a', self.owned(a, 'inspect'))
        check(current['money'] == 120000 and len(current['profile']['stored_ships']) == 2,
              'two ships and exact two debits saved')
        for field in ('ship', 'cargo', 'jobs'):
            check(current['profile'][field] == original['profile'][field], 'preserve '+field)
        for code, fields in [('UNKNOWN_SHIP', {'definition_id': 'unknown'}),
                             ('QUOTE_CHANGED', {'cost_minor': 89999}),
                             ('NO_SHIP_SERVICE', {'port_id': 'ocean'}),
                             ('BAD_PRICE', {'cost_minor': True}),
                             ('BAD_REQUEST', {'recipient': 'another_player'}),
                             ('STALE_AUTHORITY', {'generation': a['generation']+1})]:
            bad = dict(self.request(a, 'reject_'+str(len(CHECKS))), **fields)
            check(self.call('server-a', bad)['code'] == code, 'reject '+code)
        self.start_service()
        check(self.call('server-a', self.owned(a, 'inspect')) == current, 'restart preserves owned IDs and wallet')
        check(self.call('server-a', request).get('duplicate'), 'old purchase replay survives restart')
        with self.authority.connect() as db:
            rows = db.execute('SELECT amount FROM public_authority.journal WHERE account=%s', (a['account'],)).fetchall()
        check(len(rows) == 2 and sum(row['amount'] for row in rows) == -180000, 'exactly two journal debits')

    def crashes(self):
        for stage in ('after_profile_write', 'before_commit', 'after_commit'):
            a = self.funded('ship-crash-'+stage)
            request = self.request(a, 'crash_'+stage)
            self.start_service(dict(stage=stage, action_id=request['action_id']))
            try: self.call('server-a', request)
            except Exception:
                self.process.wait(timeout=8)
                check(self.process.returncode == 91 and (self.run/'fault-marker').read_text() == stage,
                      'authority process terminated at '+stage)
            else: raise AssertionError('fault not triggered')
            self.start_service()
            current = self.call('server-a', self.owned(a, 'inspect'))
            committed = stage == 'after_commit'
            check(current['money'] == (210000 if committed else 300000) and
                  len(current['profile'].get('stored_ships', [])) == int(committed),
                  'money and owned ship atomic at '+stage)
            result = self.call('server-a', request)
            check(result['ok'] and bool(result.get('duplicate')) == committed, 'same intent recovers once at '+stage)
            check(self.call('server-a', request).get('duplicate'), 'further replay harmless')


if __name__ == '__main__':
    proof = ShipPurchaseProof()
    try:
        proof.setup(); proof.exercise(); proof.crashes()
        (proof.run/'ship-purchase-summary.json').write_text(json.dumps(dict(passed=True, checks=CHECKS), indent=2))
        print('PUBLIC_SHIP_PURCHASE_PASS', len(CHECKS), 'Evidence:', proof.run, flush=True)
    finally: proof.close()
