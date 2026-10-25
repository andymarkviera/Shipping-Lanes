"""Two real peers exercise online cargo UI and persistence; approaches are fixtures."""
import argparse,json,math,time
from port_probe import Ports
from probe import CHECKS,check,free_port

class Cargo(Ports):
    def dock(self, player, port):
        self.until(player,lambda s:s.get('dock',{}).get('eligible',False))
        self.worker_call(player,dict(op='dock',port_id=port))
        self.until(player,lambda s:s['dock']['state']=='docked')
        self.until(player,lambda s:s.get('voyage',{}).get('port')==port)

    def exercise(self):
        accounts=[self.authority.create_fixture_account('https://fixture.invalid','cargo-peer-'+str(i)) for i in range(2)]
        for i,a in enumerate(accounts):self.position_fixture(a,latitude=math.degrees((30+80*i)/100000),heading=0)
        port=free_port(True);server,marker=self.dedicated(port)
        players=[self.join(port,a,rendered=(i==0)) for i,a in enumerate(accounts)]
        self.until(players[0],lambda s:bool(s.get('voyage')))
        self.worker_call(players[0],dict(op='voyage',action='accept',offer='container_seed_v1_0_0'))
        self.until(players[0],lambda s:'Dock before' in s['voyage'].get('message',''))
        check(True,'cargo requests away from a dock are rejected')
        for i,p in enumerate(players):
            self.dock(p,'port_brindle_quay')
            self.worker_call(p,dict(op='cargo_accept'))
            self.until(p,lambda s:s['voyage']['job'].get('state')=='loading')
            self.worker_call(p,dict(op='dock',action='undock',port_id='port_brindle_quay'))
            self.until(p,lambda s:'loading' in s['dock_notice'])
            check(self.status(p)['dock']['state']=='docked','loading locks server undocking')
            if i==0:
                self.worker_call(p,dict(op='disconnect'));self.vacant([accounts[i]])
                self.worker_call(p,dict(op='reconnect'))
                nonce=self.until(p,lambda s:bool(s['nonce']))['nonce']
                self.worker_call(p,dict(op='ticket',ticket=self.authority.issue_ticket(accounts[i],'server-a',nonce)))
                self.until(p,lambda s:s.get('presentation',{}).get('ready',False))
                self.dock(p,'port_brindle_quay')
                check(True,'interrupted loading resumes after reconnect and redocking')
            loaded=self.until(p,lambda s:s['voyage']['job'].get('state')=='loaded',timeout=15)
            check(loaded['voyage']['cargo']==1 and loaded['voyage']['wallet']==20000,'loaded cargo appears without premature payment')
            self.until(p,lambda s:s['cargo_visuals'].get(s['binding']['ship'])==1)
            check(True,'owned replicated cargo visuals show loaded container')
            if i==0:
                self.worker_call(p,dict(op='capture'))
                self.until(players[1],lambda s:s['cargo_visuals'].get(loaded['binding']['ship'])==1)
                check(True,'other peer sees loaded cargo count')
            self.worker_call(p,dict(op='disconnect'));self.vacant([accounts[i]])
        self.drain(server,marker,accounts)
        # Test-only canonical approach placement: no production teleport/RPC exists.
        for i,a in enumerate(accounts):self.position_fixture(a,latitude=math.degrees((50+80*i)/100000),longitude=-math.degrees(1500/100000),heading=0)
        port=free_port(True);server,marker=self.dedicated(port)
        players=[self.join(port,a,rendered=(i==0)) for i,a in enumerate(accounts)]
        for i,p in enumerate(players):
            self.dock(p,'port_slatewater_works')
            self.worker_call(p,dict(op='cargo_deliver'))
            paid=self.until(p,lambda s:s.get('voyage',{}).get('wallet')==45000)
            self.worker_call(p,dict(op='voyage',action='deliver'))
            time.sleep(.6)
            check(self.status(p)['voyage']['wallet']==45000 and self.status(p)['voyage']['cargo']==0,'delivery pays once and removes cargo through actual peer commands')
            check(paid['voyage']['receipt']['amount']==25000,'paid receipt reaches online HUD')
            if i==0:self.worker_call(p,dict(op='capture'))
            self.worker_call(p,dict(op='disconnect'));self.vacant([accounts[i]])
        self.drain(server,marker,accounts)
        for a in accounts:
            profile=self.profile_for(a)
            check(profile['money']==45000 and profile['profile']['cargo']==[] and len(profile['profile']['delivered'])==1,'both canonical profiles retain exactly one settlement')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--runtime',choices=['editor','release'],default='editor');args=p.parse_args()
    proof=Cargo(args.runtime)
    try:
        proof.setup();proof.exercise()
        for log in proof.run.rglob('godot.log'):
            check('ERROR:' not in log.read_text(errors='replace'),'Godot log has no runtime errors: '+log.parent.name)
        (proof.run/'cargo-peer-summary.json').write_text(json.dumps(dict(passed=True,checks=CHECKS,runtime=args.runtime,scope='actual two-peer cargo UI/reconnect; fixture approach positions, not full navigated voyages'),indent=2))
        print('PUBLIC_CARGO_PEER_PASS',len(CHECKS),'Evidence:',proof.run,flush=True)
    finally:proof.close()
