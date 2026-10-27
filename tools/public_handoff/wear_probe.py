"""Real authority persistence/replay tests for the single-condition wear clock."""
import json
from recovery_probe import Recovery
from probe import CHECKS, check

class Wear(Recovery):
    def exercise_wear(self):
        a=self.session('wear')
        def snapshot(seconds):
            cur=self.call('server-a',self.owned(a,'inspect'))
            return self.owned(a,'checkpoint',expected_revision=cur['revision'],position=cur['profile']['ship']['position'],fuel_liters=cur['profile']['ship']['fuel_liters'],operating_seconds=seconds)
        def health():return self.call('server-a',self.owned(a,'inspect'))['profile']['ship']
        initial=snapshot(1800)
        check(self.call('server-a',initial)['condition_bp']==9950,'half active hour removes half percent')
        check(self.call('server-a',initial)['code']=='STALE_REVISION','replayed checkpoint cannot wear twice')
        self.start_service()
        check(health()['condition_bp']==9950,'condition survives service restart')
        check(self.call('server-a',snapshot(0))['condition_bp']==9950,'zero operating time preserves condition')
        for value in [-1,True,86401,'10']:
            check(self.call('server-a',snapshot(value))['code']=='BAD_WEAR_TIME','invalid wear time rejected '+str(value))
        for _ in range(2):check(self.call('server-a',snapshot(18))['ok'],'fractional wear checkpoint accepted')
        check(health()['condition_bp']==9949,'fractional wear survives repeated checkpoints')
        request=self.impact(a,'shared_condition',1000);request['operating_seconds']=3600
        check(self.call('server-a',request)['ok'],'impact settles pending operating time')
        check(health()['condition_bp']==8849,'collision and wear reduce the same meter')
        check(self.call('server-a',request).get('duplicate') and health()['condition_bp']==8849,'impact replay cannot repeat wear')
        for _ in range(4):check(self.call('server-a',snapshot(86400))['ok'],'long operating period saved')
        check(health()['condition_bp']==1000,'wear alone stops at ten percent without sinking')
        sink=self.impact(a,'worn_sink',1000)
        check(self.call('server-a',sink)['code']=='SHIP_SUNK','collision can still sink worn boat')
        check(self.call('server-a',self.recover(a,'worn_sink'))['ok'],'paid recovery restores worn boat')
        check(health()['condition_bp']==10000 and health()['wear_fraction_bp']==0,'recovery restores single meter and fraction')

if __name__=='__main__':
    proof=Wear()
    try:
        proof.setup();proof.exercise_wear()
        (proof.run/'wear-summary.json').write_text(json.dumps(dict(passed=True,checks=CHECKS),indent=2),encoding='utf-8')
        print('WEAR_AUTHORITY_PASS',len(CHECKS),proof.run,flush=True)
    finally:proof.close()
