"""Actual peer commands interrupted at authority commit boundaries.
Approach placement is fixture-only; navigated_voyage_probe covers real travel.
"""
import argparse,json,math,time
from cargo_peer_probe import Cargo
from probe import CHECKS,check,free_port

class Interrupted(Cargo):
    def resume(self,p,account):
        self.worker_call(p,dict(op='disconnect'))
        # Fenced owners may deliberately leave the lease to expire rather than
        # issuing another write after an ambiguous commit. Wait real DB time.
        deadline=time.monotonic()+35
        while True:
            with self.authority.connect() as db:
                available=db.execute("SELECT phase='VACANT' OR expires<=clock_timestamp() AS available FROM public_authority.leases WHERE account=%s",(account,)).fetchone()['available']
            if available:break
            if time.monotonic()>deadline:raise AssertionError('Fenced lease never became available')
            time.sleep(.2)
        self.worker_call(p,dict(op='reconnect'))
        nonce=self.until(p,lambda s:bool(s['nonce']))['nonce']
        self.worker_call(p,dict(op='ticket',ticket=self.authority.issue_ticket(account,'server-a',nonce)))
        self.until(p,lambda s:s.get('presentation',{}).get('ready',False))

    def crash(self,operation,stage):
        account=self.authority.create_fixture_account('https://fixture.invalid',operation+stage)
        self.position_fixture(account,latitude=math.degrees(60/100000))
        port=free_port(True);server,marker=self.dedicated(port)
        p=self.join(port,account)
        self.dock(p,'port_brindle_quay')
        if operation=='voyage_load':self.start_service(dict(stage=stage,operation=operation))
        self.worker_call(p,dict(op='cargo_accept'))
        if operation=='voyage_deliver':
            self.until(p,lambda s:s.get('voyage',{}).get('job',{}).get('state')=='loaded',timeout=15)
            self.worker_call(p,dict(op='disconnect'));self.vacant([account])
            self.drain(server,marker,[account])
            self.position_fixture(account,latitude=math.degrees(60/100000),longitude=-math.degrees(1500/100000))
            port=free_port(True);server,marker=self.dedicated(port)
            p=self.join(port,account);self.dock(p,'port_slatewater_works')
            self.start_service(dict(stage=stage,operation=operation))
            self.worker_call(p,dict(op='cargo_deliver'))
        check(self.process.wait(timeout=20)==91,operation+' actual peer command kills service '+stage)
        # Let the in-flight HTTP failure fence its owner before restarting.
        time.sleep(1)
        after=self.profile_for(account)
        expected_loaded=(operation=='voyage_load' and stage=='after_commit') or (operation=='voyage_deliver' and stage!='after_commit')
        check(bool(after['profile']['cargo'])==expected_loaded,'atomic cargo outcome '+operation+' '+stage)
        check(after['money']==(45000 if operation=='voyage_deliver' and stage=='after_commit' else 20000),'atomic wallet outcome '+operation+' '+stage)
        self.start_service()
        self.resume(p,account)
        destination='port_brindle_quay' if operation=='voyage_load' else 'port_slatewater_works'
        self.dock(p,destination)
        if operation=='voyage_load':
            state=self.until(p,lambda s:s.get('voyage',{}).get('job',{}).get('state')=='loaded',timeout=15)
            check(state['voyage']['cargo']==1 and state['voyage']['wallet']==20000,'loading recovers once after '+stage)
        else:
            state=self.until(p,lambda s:bool(s.get('voyage')))
            if stage!='after_commit':
                check(state['voyage']['job'].get('state')=='loaded','unpaid cargo remains deliverable after rollback')
                self.worker_call(p,dict(op='cargo_deliver'))
            self.until(p,lambda s:s.get('voyage',{}).get('wallet')==45000)
            self.worker_call(p,dict(op='voyage',action='deliver'))
            time.sleep(.7)
            state=self.status(p)
            check(state['voyage']['wallet']==45000 and state['voyage']['cargo']==0,'payment recovers once after '+stage)
        self.worker_call(p,dict(op='disconnect'));self.vacant([account])
        marker.touch()
        check(server['child'].wait(timeout=25)==2 and 'PUBLIC_SERVER_DRAIN_FAILED' in (server['folder']/'godot.log').read_text(),'shutdown retains the earlier uncertain-save warning')
        self.vacant([account])
        check(True,'recovered account releases ownership after final save')
        p['child'].terminate();p['child'].wait(timeout=8)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--runtime',choices=['editor','release'],default='release');args=parser.parse_args()
    proof=Interrupted(args.runtime)
    try:
        proof.setup()
        for operation in ['voyage_load','voyage_deliver']:
            for stage in ['before_commit','after_commit']:proof.crash(operation,stage)
        for log in proof.run.rglob('godot.log'):
            check('ERROR:' not in log.read_text(errors='replace'),'no engine errors during controlled outage '+str(log.relative_to(proof.run)))
        (proof.run/'cargo-interruption-summary.json').write_text(json.dumps(dict(passed=True,runtime=args.runtime,checks=CHECKS,scope='actual peer loading/payment crash recovery, fixture approaches'),indent=2))
        print('CARGO_INTERRUPTION_PASS',len(CHECKS),proof.run,flush=True)
    finally:proof.close()
