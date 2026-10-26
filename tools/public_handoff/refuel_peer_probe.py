"""Actual peer refueling UI, dock checks, anti-replay and saved live fuel."""
import argparse,json,math,time
from cargo_peer_probe import Cargo
from probe import CHECKS,check,free_port

class FuelPeers(Cargo):
    def exercise(self):
        accounts=[self.authority.create_fixture_account('https://fixture.invalid','fuel-peer-'+str(i)) for i in range(2)]
        for i,a in enumerate(accounts):self.position_fixture(a,latitude=math.degrees((30+80*i)/100000),heading=0)
        port=free_port(True);server,marker=self.dedicated(port)
        players=[self.join(port,a,rendered=(i==0)) for i,a in enumerate(accounts)]
        p=players[0]
        self.worker_call(p,dict(op='refuel',quote='fake',liters=10))
        self.until(p,lambda s:'Dock before' in s.get('voyage',{}).get('message',''))
        check(True,'undocked refueling refused by actual server')
        self.dock(p,'port_brindle_quay')
        state=self.until(p,lambda s:bool(s['voyage'].get('refuel')))
        quote=state['voyage']['refuel'];before=quote['fuel']
        self.worker_call(players[1],dict(op='refuel',quote=quote['id'],liters=10,candidate=state['binding']))
        time.sleep(.5)
        check(self.status(p)['voyage']['wallet']==20000,'other peer cannot spend this account money')
        self.worker_call(p,dict(op='fuel_buy',liters=25))
        state=self.until(p,lambda s:s['voyage']['wallet']==19375)
        state=self.until(p,lambda s:bool(s['voyage'].get('refuel')))
        check(abs(state['voyage']['refuel']['fuel']-before-25)<.001,'actual buy button adds selected liters to live tank')
        self.worker_call(p,dict(op='refuel',quote=quote['id'],liters=25))
        self.until(p,lambda s:'quote changed' in s['voyage'].get('message','').lower())
        check(self.status(p)['voyage']['wallet']==19375,'new sequence cannot reuse consumed quote')
        quote=self.status(p)['voyage']['refuel']
        self.worker_call(p,dict(op='refuel',quote=quote['id'],liters=1000))
        self.until(p,lambda s:'tank' in s['voyage'].get('message','').lower())
        check(self.status(p)['voyage']['wallet']==19375,'oversized request cannot charge')
        self.worker_call(p,dict(op='capture'))
        self.worker_call(p,dict(op='disconnect'));self.vacant([accounts[0]])
        saved=self.profile_for(accounts[0])
        check(abs(saved['profile']['ship']['fuel_liters']-before-25)<.001 and saved['money']==19375,'disconnect retains purchased live fuel and balance')
        self.dock(players[1],'port_brindle_quay')
        self.worker_call(players[1],dict(op='cargo_accept'))
        self.until(players[1],lambda s:s['voyage']['job'].get('state')=='loading')
        check(not self.status(players[1])['voyage'].get('refuel'),'loading disables fuel quote')
        self.worker_call(players[1],dict(op='disconnect'));self.vacant([accounts[1]])
        self.drain(server,marker,accounts)
        port=free_port(True);server,marker=self.dedicated(port)
        p=self.join(port,accounts[0],rendered=True)
        self.dock(p,'port_brindle_quay')
        state=self.until(p,lambda s:bool(s['voyage'].get('refuel')))
        check(state['voyage']['wallet']==19375 and abs(state['voyage']['refuel']['fuel']-before-25)<.1,'server restart restores purchase without another debit')
        self.drain(server,marker,[accounts[0]])

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--runtime',choices=['editor','release'],default='editor');args=parser.parse_args()
    proof=FuelPeers(args.runtime)
    try:
        proof.setup();proof.exercise()
        for log in proof.run.rglob('godot.log'):check('ERROR:' not in log.read_text(errors='replace'),'clean Godot log '+log.parent.name)
        (proof.run/'refuel-peer-summary.json').write_text(json.dumps(dict(passed=True,checks=CHECKS,runtime=args.runtime),indent=2),encoding='utf-8')
        print('PUBLIC_REFUEL_PEER_PASS',len(CHECKS),'Evidence:',proof.run,flush=True)
    finally:proof.close()
