"""Actual game peer loses refuel reply at both SQL commit boundaries."""
import json,math,time
from cargo_interruption_probe import Interrupted
from probe import CHECKS,check,free_port

class FuelInterrupted(Interrupted):
    def refuel_crash(self,stage):
        account=self.authority.create_fixture_account('https://fixture.invalid','fuel-peer-'+stage)
        self.position_fixture(account,latitude=math.degrees(60/100000))
        port=free_port(True);server,marker=self.dedicated(port)
        p=self.join(port,account);self.dock(p,'port_brindle_quay')
        state=self.until(p,lambda s:bool(s['voyage'].get('refuel')))
        before=state['voyage']['refuel']['fuel'];old_quote=state['voyage']['refuel']['id']
        self.start_service(dict(stage=stage,operation='refuel'))
        self.worker_call(p,dict(op='fuel_buy',liters=40))
        check(self.process.wait(timeout=20)==91,'actual peer refueling terminates authority '+stage)
        time.sleep(1)
        after=self.profile_for(account);committed=stage=='after_commit'
        check(after['money']==(19000 if committed else 20000) and abs(after['profile']['ship']['fuel_liters']-before-(40 if committed else 0))<.001,'live consumed fuel and debit remain atomic '+stage)
        self.start_service();self.resume(p,account);self.dock(p,'port_brindle_quay')
        state=self.until(p,lambda s:bool(s['voyage'].get('refuel')))
        check(state['voyage']['wallet']==after['money'] and abs(state['voyage']['refuel']['fuel']-after['profile']['ship']['fuel_liters'])<.1,'reconnect restores canonical fuel without stale overwrite '+stage)
        self.worker_call(p,dict(op='refuel',quote=old_quote,liters=40))
        self.until(p,lambda s:'quote changed' in s['voyage'].get('message','').lower())
        check(self.status(p)['voyage']['wallet']==after['money'],'pre-reconnect quote cannot charge again '+stage)
        self.worker_call(p,dict(op='disconnect'));self.vacant([account])
        marker.touch()
        check(server['child'].wait(timeout=25)==2 and 'PUBLIC_SERVER_DRAIN_FAILED' in (server['folder']/'godot.log').read_text(),'historical uncertain-save warning retained')
        check(self.profile_for(account)['money']==after['money'],'final save does not duplicate debit')
        p['child'].terminate();p['child'].wait(timeout=8)

if __name__=='__main__':
    proof=FuelInterrupted('release')
    try:
        proof.setup()
        for stage in ['before_commit','after_commit']:proof.refuel_crash(stage)
        for log in proof.run.rglob('godot.log'):check('ERROR:' not in log.read_text(errors='replace'),'clean outage log '+str(log.relative_to(proof.run)))
        (proof.run/'refuel-interruption-summary.json').write_text(json.dumps(dict(passed=True,checks=CHECKS),indent=2),encoding='utf-8')
        print('REFUEL_INTERRUPTION_PASS',len(CHECKS),proof.run,flush=True)
    finally:proof.close()
