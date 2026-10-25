"""Two actual DTLS clients: physical shared port, berth exclusion and departure."""
import argparse,json,math,time
from foundation_probe import Foundation
from probe import CHECKS,check,free_port

class Ports(Foundation):
    def dedicated(self, port):
        marker=self.run/('stop-'+str(port))
        return self.peer_worker('server',port,dedicated=True,stop_file=str(marker)),marker

    def run_ports(self):
        accounts=[self.authority.create_fixture_account('https://fixture.invalid', 'port-player-'+str(i)) for i in range(2)]
        for i,a in enumerate(accounts): self.position_fixture(a,latitude=math.degrees((30+i*80)/100000),heading=0)
        port=free_port(True)
        server, marker=self.dedicated(port)
        first=self.join(port,accounts[0],rendered=True)
        second=self.join(port,accounts[1])
        self.until(first,lambda s:s.get('dock',{}).get('eligible',False))
        self.until(second,lambda s:s.get('dock',{}).get('eligible',False))
        check(len(self.status(first)['ports'])==2 and len(self.status(second)['ports'])==2, 'both clients render both canonical test ports')
        # A client may not use another account's ship binding to claim a berth.
        other=self.status(second)['binding']
        self.worker_call(first,dict(op='dock',candidate=other))
        time.sleep(.4)
        check(self.status(first)['dock']['state']=='underway' and self.status(second)['dock']['state']=='underway', 'forged dock binding changes neither player')
        self.worker_call(first,dict(op='dock_button'))
        self.until(first,lambda s:s['dock']['state']=='docked')
        check(self.status(first)['dock_ack']>0, 'actual Dock button receives server acknowledgment')
        self.worker_call(second,dict(op='dock'))
        denied=self.until(second,lambda s:s['dock_ack']>0)
        check(denied['dock']['state']=='underway' and 'occupied' in denied['dock_notice'].lower(), 'second player cannot reserve occupied berth')
        self.worker_call(first,dict(op='helm',sequence=1,throttle=1.0,rudder=1.0))
        time.sleep(.3)
        check(self.status(first)['snapshot']['speed']<.01, 'docked ship cannot respond to helm orders')
        self.worker_call(first,dict(op='capture'))
        # Owner departure changes physics grouping; the remaining peer must not get stuck.
        self.worker_call(first,dict(op='disconnect'))
        self.until(second,lambda s:s['dock'].get('eligible',False))
        self.worker_call(second,dict(op='dock'))
        self.until(second,lambda s:s['dock']['state']=='docked')
        check(True, 'disconnect releases berth and surviving player docks after regrouping')
        self.worker_call(second,dict(op='dock',action='undock'))
        self.until(second,lambda s:s['dock']['state']=='underway' and not s['dock_notice'])
        check(True, 'undocking releases server lock')
        self.drain(server,marker,accounts)
        # Reconnect after complete server restart; no stale saved berth ownership.
        port=free_port(True);server,marker=self.dedicated(port)
        resumed=self.join(port,accounts[1])
        state=self.until(resumed,lambda s:s['dock'].get('eligible',False))
        check(state['dock']['state']=='underway', 'restart restores position with no stale berth reservation')
        self.worker_call(resumed,dict(op='dock'))
        self.until(resumed,lambda s:s['dock']['state']=='docked')
        check(True, 'reopened account docks again')
        self.drain(server,marker,[accounts[1]])

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--runtime',choices=['editor','release'],default='editor');args=p.parse_args()
    proof=Ports(args.runtime)
    try:
        proof.setup();proof.run_ports()
        (proof.run/'ports-summary.json').write_text(json.dumps(dict(passed=True,checks=CHECKS,runtime=args.runtime,scope='two-peer physical ports and docking; cargo services not wired yet'),indent=2))
        print('PUBLIC_PORTS_PASS',len(CHECKS),'Evidence:',proof.run,flush=True)
    finally:proof.close()
