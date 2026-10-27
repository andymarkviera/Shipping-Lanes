"""Real helm -> quay impact -> sinking -> reconnect -> paid safe recovery."""
import argparse,json,math,time
from cargo_peer_probe import Cargo
from cargo_interruption_probe import Interrupted
from probe import CHECKS,check,free_port
from psycopg.types.json import Jsonb

class RecoveryPeers(Interrupted):
    def prepared_account(self,name):
        account=self.authority.create_fixture_account('https://fixture.invalid',name)
        g=self.call('server-a',self.join_request('server-a',account))
        a=self.call('server-a',self.owned(g,'voyage_accept',action_id='accept',expected_revision=g['revision'],offer_id='container_seed_v1_0_0',port_id='port_brindle_quay'))
        check(a['ok'],'cargo contract prepared through authority')
        time.sleep(5.1)
        loaded=self.call('server-a',self.owned(g,'voyage_load',action_id='load',expected_revision=a['revision'],job_id=a['job']['id'],port_id='port_brindle_quay'))
        check(loaded['ok'],'cargo aboard before impact fixture')
        self.call('server-a',self.owned(g,'release'))
        # Low initial health makes one ordinary quay collision lethal. No damage RPC.
        with self.authority.connect() as db:
            row=db.execute('SELECT profile FROM public_authority.profiles WHERE account=%s',(account,)).fetchone()['profile']
            row['ship']['condition_bp']=1
            db.execute('UPDATE public_authority.profiles SET profile=%s WHERE account=%s',(Jsonb(row),account))
        self.position_fixture(account,latitude=math.degrees(60/100000),longitude=-math.degrees(60/100000),heading=90)
        return account

    def collide(self,p,crash=False):
        deadline=time.monotonic()+70;seq=0;maximum=0
        while time.monotonic()<deadline:
            seq+=1
            self.worker_call(p,dict(op='helm',sequence=seq,throttle=1.0))
            state=self.status(p);maximum=max(maximum,state.get('snapshot',{}).get('speed',0))
            if crash and self.process.poll() is not None:break
            if state.get('voyage',{}).get('recovery',{}).get('state')=='pending':break
            time.sleep(.15)
        else:raise AssertionError('No physical impact within budget')
        check(maximum>2,'ordinary helm accelerated above harmless impact threshold')
        return state

    def exercise(self):
        account=self.prepared_account('impact-sailor')
        other=self.authority.create_fixture_account('https://fixture.invalid','recovery-space-blocker')
        self.position_fixture(other,latitude=math.degrees(-350/100000))
        port=free_port(True);server,marker=self.dedicated(port)
        p=self.join(port,account,rendered=True);blocker=self.join(port,other)
        state=self.collide(p)
        incident=state['voyage']['recovery']['id']
        check(state['voyage']['wallet']==0 and state['voyage']['recovery_debt_minor']==5000 and state['voyage']['cargo']==0,'real quay impact removes cargo and records full fee/debt')
        self.worker_call(p,dict(op='capture'))
        self.worker_call(p,dict(op='helm',sequence=1000,throttle=1.0));time.sleep(.5)
        check(self.status(p)['snapshot']['speed']==0,'sunk ship cannot sail away')
        self.worker_call(blocker,dict(op='recover',incident=incident,candidate=state['binding']))
        time.sleep(.4);check(self.status(p)['voyage']['recovery']['state']=='pending','other peer cannot recover another account')
        self.worker_call(p,dict(op='disconnect'));self.vacant([account])
        self.resume(p,account)
        state=self.until(p,lambda s:s.get('voyage',{}).get('recovery',{}).get('state')=='pending')
        check(state['voyage']['cargo']==0 and state['voyage']['wallet']==0,'reconnect cannot restore cargo or avoid fee')
        self.worker_call(p,dict(op='recover_button'))
        state=self.until(p,lambda s:s.get('voyage',{}).get('recovery',{}).get('state')=='recovered' and not s['voyage'].get('recovery_placing'),timeout=15)
        check(state['voyage']['recovery']['slot']!=0,'occupied recovery slot skipped')
        check(state['voyage']['condition_bp']==10000 and state['voyage']['recovery_debt_minor']==5000,'restored hull retains unpaid recovery balance')
        check(state['snapshot']['fuel']>=99.9,'paid recovery leaves usable propulsion fuel')
        self.worker_call(p,dict(op='recover',incident=incident));time.sleep(.5)
        check(self.status(p)['voyage']['wallet']==0 and self.status(p)['voyage']['recovery_debt_minor']==5000,'repeated recovery cannot charge or forgive debt')
        moved=False
        for sequence in range(2000,2020):
            self.worker_call(p,dict(op='helm',sequence=sequence,throttle=.5));time.sleep(.15)
            state=self.status(p)
            if state['snapshot']['speed']>.05:
                moved=True;break
        check(moved and state['snapshot']['sequence']>=2000,'recovered boat responds to acknowledged ordinary helm')
        self.worker_call(p,dict(op='disconnect'));self.vacant([account])
        self.worker_call(blocker,dict(op='disconnect'));self.vacant([other]);self.drain(server,marker,[account,other])
        saved=self.profile_for(account)
        check(saved['profile']['cargo']==[] and saved['profile']['recovery_debt_minor']==5000,'saved recovery never restores lost load')
        port=free_port(True);server,marker=self.dedicated(port)
        p=self.join(port,account)
        state=self.until(p,lambda s:bool(s.get('voyage')))
        check(state['voyage']['condition_bp']==10000 and state['voyage']['wallet']==0 and state['voyage']['recovery_debt_minor']==5000,'server restart preserves hull and recovery balance')
        self.drain(server,marker,[account])

    def interruption(self,stage):
        account=self.prepared_account('impact-'+stage)
        port=free_port(True);server,marker=self.dedicated(port)
        p=self.join(port,account)
        self.start_service(dict(stage=stage,operation='impact'))
        self.collide(p,crash=True)
        check(self.process.wait(timeout=8)==91,'physical impact kills authority at '+stage)
        time.sleep(1);self.start_service();self.resume(p,account)
        state=self.until(p,lambda s:s.get('voyage',{}).get('recovery',{}).get('state')=='pending',timeout=15)
        check(state['voyage']['wallet']==0 and state['voyage']['recovery_debt_minor']==5000 and state['voyage']['cargo']==0,'pending impact reconciles exactly once after '+stage)
        self.worker_call(p,dict(op='recover_button'))
        self.until(p,lambda s:s.get('voyage',{}).get('recovery',{}).get('state')=='recovered')
        self.worker_call(p,dict(op='disconnect'));self.vacant([account]);marker.touch()
        check(server['child'].wait(timeout=25)==2,'uncertain-save history remains explicit after recovery')
        check(self.profile_for(account)['profile']['recovery_debt_minor']==5000,'final save preserves one recovery charge')
        p['child'].terminate();p['child'].wait(timeout=8)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--runtime',choices=['editor','release'],default='editor');parser.add_argument('--interruptions',action='store_true');args=parser.parse_args()
    proof=RecoveryPeers(args.runtime)
    try:
        proof.setup()
        if args.interruptions:
            for stage in ['before_commit','after_commit']:proof.interruption(stage)
        else:proof.exercise()
        for log in proof.run.rglob('godot.log'):check('ERROR:' not in log.read_text(errors='replace'),'clean engine log '+str(log.relative_to(proof.run)))
        (proof.run/'recovery-peer-summary.json').write_text(json.dumps(dict(passed=True,checks=CHECKS,runtime=args.runtime,interruptions=args.interruptions),indent=2),encoding='utf-8')
        print('RECOVERY_PEER_PASS',len(CHECKS),proof.run,flush=True)
    finally:proof.close()
