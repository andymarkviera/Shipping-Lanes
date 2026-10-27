"""Real SQL/HTTPS impact, loss, fee, debt and recovery transaction proofs."""
import json
from voyage_probe import VoyageProof
from probe import CHECKS,check

class Recovery(VoyageProof):
    def impact(self,g,action,damage=10000):
        cur=self.call('server-a',self.owned(g,'inspect'))
        return self.command(g,'impact',action,damage_bp=damage,fuel_liters=cur['profile']['ship']['fuel_liters'],position=cur['profile']['ship']['position'])
    def recover(self,g,incident,action='recover',slot=0):
        return self.command(g,'recover',action,incident_id=incident,slot=slot)
    def exercise(self):
        a=self.session('recovery-a');job=self.ready_load(a,'recovery')
        original=self.call('server-a',self.owned(a,'inspect'));ship=original['profile']['ship']['id']
        minor=self.impact(a,'minor',1000)
        check(self.call('server-a',minor)['code']=='HULL_DAMAGED','nonlethal damage saves hull condition')
        check(self.call('server-a',minor).get('duplicate'),'same impact does not apply twice')
        current=self.call('server-a',self.owned(a,'inspect'))
        check(current['profile']['ship']['condition_bp']==9000 and current['money']==20000,'nonlethal hit charges no recovery fee')
        for damage in [0,-1,10001,1.5,True]:
            check(self.call('server-a',dict(minor,damage_bp=damage))['code']=='BAD_DAMAGE','invalid damage rejected '+str(damage))
        sink=self.impact(a,'sink')
        result=self.call('server-a',sink);check(result['code']=='SHIP_SUNK','lethal hit enters durable recovery state')
        check(self.call('server-a',sink).get('duplicate'),'duplicate sinking cannot charge twice')
        check(self.call('server-a',dict(sink,fee_minor=0))['code']=='BAD_REQUEST','caller cannot waive recovery fee')
        current=self.call('server-a',self.owned(a,'inspect'))
        check(current['money']==0 and current['profile']['recovery_debt_minor']==5000,'insolvent starter pays available credits and owes full remainder')
        check(current['profile']['cargo']==[] and current['profile']['ship']['id']==ship,'cargo lost but ship ownership unchanged')
        check(any(j.get('id')==job['id'] and j['state']=='failed' for j in current['profile']['jobs']),'affected contract fails with no payout')
        check(current['profile']['recovery']['lost_cargo']==[original['profile']['cargo'][0]['id']],'lost cargo identity recorded once')
        check(self.call('server-a',self.impact(a,'again'))['code']=='RECOVERY_REQUIRED','new damage ID on sunk ship cannot charge again')
        blocked=self.command(a,'refuel','wreck_fuel',port_id='port_brindle_quay',liters=1,unit_price_minor=25)
        check(self.call('server-a',blocked)['code']=='RECOVERY_REQUIRED','wreck cannot buy fuel instead of recovering')
        check(self.call('server-a',self.recover(a,'wrong'))['code']=='NO_RECOVERY','wrong incident rejected')
        check(self.call('server-a',self.recover(a,'sink','bad_slot',99))['code']=='BAD_SLOT','arbitrary recovery position rejected')
        recovery=self.recover(a,'sink','valid_recover',1)
        check(self.call('server-a',recovery)['code']=='SHIP_RECOVERED','same owned ship recovered at approved slot')
        check(self.call('server-a',recovery).get('duplicate'),'repeated recovery returns receipt without new fee')
        check(self.call('server-a',self.recover(a,'sink','extra_recovery'))['code']=='NO_RECOVERY','new ID cannot recover already restored ship')
        check(self.call('server-a',sink).get('duplicate'),'late impact receipt cannot sink restored ship again')
        self.start_service();cur=self.call('server-a',self.owned(a,'inspect'))
        check(cur['profile']['ship']['condition_bp']==10000 and cur['profile']['recovery_debt_minor']==5000,'restart preserves restored hull and unpaid debt')
        new_job=self.ready_load(a,'repay')
        pay=self.command(a,'voyage_deliver','repay',job_id=new_job['id'],port_id='port_slatewater_works')
        result=self.call('server-a',pay)
        check(result['amount']==20000 and result['recovery_repaid_minor']==5000,'delivery repays only outstanding debt and credits remainder')
        check(self.call('server-a',pay).get('duplicate'),'duplicate delivery cannot repay debt twice')
        cur=self.call('server-a',self.owned(a,'inspect'))
        check(cur['money']==20000 and cur['profile']['recovery_debt_minor']==0,'debt fully cleared without losing earned remainder')
        paid=next(j for j in cur['profile']['jobs'] if j['id']==new_job['id'])
        check(paid['paid_minor']==20000 and paid['recovery_repaid_minor']==5000,'receipt distinguishes net payment from recovery repayment')
        # Second sinking remains chargeable on the starter; no special waiver.
        check(self.call('server-a',self.impact(a,'second_sink'))['ok'],'second sinking incurs another full fee')
        cur=self.call('server-a',self.owned(a,'inspect'))
        check(cur['money']==0 and cur['profile']['recovery_debt_minor']==5000,'starter is never exempt from recovery charge')
        check(self.call('server-a',self.recover(a,'second_sink','recover_second'))['ok'],'second recovery retains ownership')
        third=self.impact(a,'third_sink');third['fuel_liters']=0
        check(self.call('server-a',third)['ok'],'empty-fuel ship can enter paid recovery')
        check(self.call('server-a',self.recover(a,'third_sink','recover_third'))['ok'],'empty-fuel ship returns through charged recovery')
        cur=self.call('server-a',self.owned(a,'inspect'))
        check(cur['profile']['ship']['fuel_liters']==100 and cur['profile']['recovery_debt_minor']==30000,'recovery includes usable fuel while retaining entire unpaid cost')
        accept=self.command(a,'voyage_accept','large_accept',offer_id='container_seed_v1_0_1',port_id='port_brindle_quay')
        accepted=self.call('server-a',accept);check(accepted['ok'],'indebted player can accept another job')
        import time
        time.sleep(10.1)
        loaded=self.call('server-a',self.command(a,'voyage_load','large_load',job_id=accepted['job']['id'],port_id='port_brindle_quay'))
        check(loaded['ok'],'indebted player can load a new job')
        paid=self.call('server-a',self.command(a,'voyage_deliver','partial_repay',job_id=accepted['job']['id'],port_id='port_slatewater_works'))
        cur=self.call('server-a',self.owned(a,'inspect'))
        check(paid['amount']==25000 and paid['recovery_repaid_minor']==25000 and cur['profile']['recovery_debt_minor']==5000,'only half of earnings withheld when debt exceeds half; player still earns')
        rich=self.session('solvent-recovery')
        with self.authority.connect() as db:db.execute('UPDATE public_authority.profiles SET money=100000 WHERE account=%s',(rich['account'],))
        check(self.call('server-a',self.impact(rich,'solvent_sink'))['ok'],'solvent ship sinking settled')
        cur=self.call('server-a',self.owned(rich,'inspect'))
        check(cur['money']==75000 and cur['profile']['recovery_debt_minor']==0,'solvent account pays exact full fee with no debt')
    def crashes(self):
        for op in ['impact','recover']:
            for stage in ['after_profile_write','before_commit','after_commit']:
                a=self.session(op+'-'+stage)
                sink=self.impact(a,'sink_'+op+'_'+stage)
                req=sink
                if op=='recover':
                    check(self.call('server-a',sink)['ok'],'crash recovery fixture sunk')
                    req=self.recover(a,sink['action_id'],'recover_'+stage)
                self.start_service(dict(stage=stage,action_id=req['action_id']))
                try:self.call('server-a',req)
                except Exception:
                    self.process.wait(timeout=8)
                    check(self.process.returncode==91 and (self.run/'fault-marker').read_text()==stage,'actual '+op+' service death '+stage)
                else:raise AssertionError('fault not triggered')
                self.start_service();cur=self.call('server-a',self.owned(a,'inspect'));committed=stage=='after_commit'
                if op=='impact':check(cur['money']==(0 if committed else 20000) and cur['profile'].get('recovery_debt_minor',0)==(5000 if committed else 0),'fee/debt atomic '+stage)
                else:check(cur['money']==0 and cur['profile']['recovery']['state']==('recovered' if committed else 'pending'),'recovery cannot charge again '+stage)
                result=self.call('server-a',req)
                check(result['ok'] and bool(result.get('duplicate'))==committed,'uncertain '+op+' resolves once '+stage)
                check(self.call('server-a',req).get('duplicate'),'further replay harmless')

if __name__=='__main__':
    proof=Recovery()
    try:
        proof.setup();proof.exercise();proof.crashes()
        (proof.run/'recovery-summary.json').write_text(json.dumps(dict(passed=True,checks=CHECKS),indent=2),encoding='utf-8')
        print('RECOVERY_AUTHORITY_PASS',len(CHECKS),proof.run,flush=True)
    finally:proof.close()
