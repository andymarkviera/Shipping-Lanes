"""Real-time two-peer voyages using only normal helm/dock/cargo commands.
Only initial spawn positions are fixtures. No mid-voyage relocation or time scaling.
"""
import argparse,json,math,time
from cargo_peer_probe import Cargo
from probe import CHECKS,check,free_port

BRINDLE='port_brindle_quay'
SLATE='port_slatewater_works'
def clamp(x,a,b):return max(a,min(b,x))
def angle(x):return (x+180)%360-180

class Navigated(Cargo):
    def peer_worker(self,role,port,**kw):
        if role=='client':kw['probe_lifetime_ms']=1800000
        return super().peer_worker(role,port,**kw)

    def helm(self,p,s,throttle=0,rudder=0,lateral=0):
        # Respect traffic using only the same nearby replicas a player sees.
        # Never drive the following hull into a stopped ship's docking clearance.
        heading=math.radians(s.get('navigation',{}).get('heading',0))
        forward=(-math.sin(heading),math.cos(heading))
        for other in s.get('replicas',[]):
            if other['ship']==s['binding']['ship']:continue
            ahead=other['x']*forward[0]+other['z']*forward[1]
            side=other['x']*forward[1]-other['z']*forward[0]
            if ahead>0 and abs(side)<40:
                safe_speed=max(0,(ahead-110)/18)
                speed=s['snapshot'].get('forward_speed',0)
                safe_order=clamp(safe_speed/10+(safe_speed-speed)*.4,-.6,1)
                if safe_speed<.1 and abs(speed)<1:safe_order=0
                if throttle>0:throttle=min(throttle,safe_order)
        p['helm_seq']=max(p.get('helm_seq',0),s['snapshot'].get('sequence',0))+1
        self.worker_call(p,dict(op='helm',sequence=p['helm_seq'],throttle=throttle,rudder=rudder,lateral=lateral))

    def route(self,leg):
        # Port-local coordinates of Brindle; mirrored destination approach.
        return ([(0,350),(350,600),(1100,600),(1250,300),(1250,-300),(1500,-300)]
                if leg==0 else
                [(1500,850),(1150,1100),(400,1100),(250,750),(250,-300),(0,-300)])

    def reconnect(self,p,account):
        self.worker_call(p,dict(op='disconnect'));self.vacant([account])
        self.worker_call(p,dict(op='reconnect'))
        nonce=self.until(p,lambda s:bool(s['nonce']))['nonce']
        self.worker_call(p,dict(op='ticket',ticket=self.authority.issue_ticket(account,'server-a',nonce)))
        self.until(p,lambda s:s.get('presentation',{}).get('ready',False))
        return self.until(p,lambda s:s.get('voyage',{}).get('job',{}).get('state')=='loaded')

    def exercise(self):
        accounts=[self.authority.create_fixture_account('https://fixture.invalid','navigated-'+str(i)) for i in range(2)]
        for i,a in enumerate(accounts):self.position_fixture(a,latitude=math.degrees((110-80*i)/100000),heading=0)
        port=free_port(True);server,marker=self.dedicated(port)
        players=[self.join(port,a,rendered=(i==0)) for i,a in enumerate(accounts)]
        fleet=[]
        for i,p in enumerate(players):
            self.dock(p,BRINDLE)
            self.worker_call(p,dict(op='cargo_accept'))
            self.until(p,lambda s:s.get('voyage',{}).get('job',{}).get('state')=='loaded',timeout=15)
            self.worker_call(p,dict(op='dock',action='undock',port_id=BRINDLE))
            self.until(p,lambda s:s['dock']['state']=='underway')
            fleet.append(dict(p=p,account=accounts[i],leg=0,waypoint=0,phase='sail',last_heading=0,last_time=time.monotonic(),reconnected=False,trace=[]))
        start=time.monotonic();next_print=0
        while any(f['phase']!='done' for f in fleet):
            if time.monotonic()-start>1500:raise AssertionError('Voyage exceeded 25 minute test budget')
            for index,f in enumerate(fleet):
                if f['phase']=='done':continue
                p=f['p'];s=self.status(p)
                if not s.get('binding') or not s.get('navigation'):raise AssertionError('Lost live voyage state '+str(s))
                pos=s['navigation'][BRINDLE];x,z=pos['x'],pos['z']
                heading=s['navigation']['heading'];speed=s['snapshot'].get('forward_speed',0)
                now=time.monotonic();dt=max(.05,now-f['last_time'])
                yaw_rate=angle(heading-f['last_heading'])/dt
                f['last_heading']=heading;f['last_time']=now
                if f.get('observed_phase')!=f['phase']:
                    f['observed_phase']=f['phase'];f['phase_since']=now
                if f['phase'] not in ['sail','approach'] and now-f['phase_since']>90:
                    raise AssertionError('Stalled voyage phase '+str((index,f['phase'],s['dock'],s.get('voyage'))))
                destination=SLATE if f['leg']==0 else BRINDLE
                if not f['trace'] or now-f['trace'][-1]['t']>1:
                    f['trace'].append(dict(t=now,x=x,z=z,speed=speed,heading=heading,leg=f['leg'],phase=f['phase']))
                if f['phase']=='sail':
                    route=self.route(f['leg'])
                    if f['waypoint']>=len(route):
                        f['phase']='approach';continue
                    tx,tz=route[f['waypoint']]
                    dx,dz=tx-x,tz-z
                    if math.hypot(dx,dz)<55:
                        f['waypoint']+=1
                        print('WAYPOINT',index,f['leg'],f['waypoint'],round(x),round(z),flush=True)
                        continue
                    desired=math.degrees(math.atan2(-dx,dz))
                    error=angle(desired-heading)
                    target=3.5 if abs(error)>25 else 8
                    throttle=clamp(target/10+(target-speed)*.25,-.6,1)
                    rudder=clamp(error*.045-yaw_rate*.5,-1,1)
                    self.helm(p,s,throttle,rudder)
                    if index==0 and f['leg']==0 and f['waypoint']==3 and not f['reconnected']:
                        before=self.profile_for(f['account'])
                        restored=self.reconnect(p,f['account'])
                        check(restored['voyage']['cargo']==1 and restored['voyage']['wallet']==20000,'loaded ship reconnects mid-voyage with cargo and unpaid job')
                        check(self.profile_for(f['account'])['revision']>before['revision'],'mid-voyage disconnect checkpoints authoritative movement')
                        f['reconnected']=True;f['last_time']=time.monotonic();f['last_heading']=restored['navigation']['heading']
                elif f['phase']=='approach':
                    rel=s['navigation'][destination];ex=rel['x'];ez=rel['z']
                    # Straighten before entering the berth; allow lateral trim at low speed.
                    desired=clamp(math.degrees(math.atan2(ex,max(45,70-ez))),-25,25)
                    error=angle(desired-heading)
                    if ez>25 and abs(ex)<16 and abs(angle(heading))<7:
                        f['phase']='stop';self.helm(p,s);continue
                    target=min(3,max(1.1,(65-ez)/15))
                    self.helm(p,s,clamp(target/10+(target-speed)*.35,-.6,.6),clamp(error*.07-yaw_rate*.7,-1,1),clamp(ex/15,-1,1) if speed<2 else 0)
                    if ez>150:raise AssertionError('Approach overshot '+str((ex,ez,heading)))
                elif f['phase']=='stop':
                    self.helm(p,s)
                    if s['dock'].get('eligible') and s['dock'].get('port_id')==destination:
                        self.worker_call(p,dict(op='dock',port_id=destination));f['phase']='docking'
                    elif s['snapshot']['speed']<.01 and 'occupied' not in s['dock'].get('message','').lower():
                        if time.monotonic()-f.get('stop_since',time.monotonic())>8:raise AssertionError('Stopped but cannot dock '+str(s['dock']))
                        f.setdefault('stop_since',time.monotonic())
                elif f['phase']=='docking':
                    if s['dock']['state']=='docked' and s.get('voyage',{}).get('port')==destination:
                        self.worker_call(p,dict(op='cargo_deliver'));f['phase']='paying'
                elif f['phase']=='paying':
                    if s.get('voyage',{}).get('wallet')==45000+25000*f['leg']:
                        check(s['voyage']['cargo']==0,'player '+str(index)+' leg '+str(f['leg'])+' navigated delivery clears cargo and pays once')
                        self.worker_call(p,dict(op='voyage',action='deliver'))
                        if f['leg']==0:f['phase']='next_job';f['next_at']=now+.8
                        else:
                            self.worker_call(p,dict(op='disconnect'));self.vacant([f['account']]);f['phase']='done'
                elif f['phase']=='next_job':
                    if now>=f['next_at'] and not s['voyage'].get('busy'):
                        check(s['voyage']['wallet']==45000,'duplicate delivery cannot pay again after navigated arrival')
                        self.worker_call(p,dict(op='cargo_accept'));f['phase']='loading'
                elif f['phase']=='loading':
                    if s.get('voyage',{}).get('job',{}).get('state')=='loaded':
                        self.worker_call(p,dict(op='dock',action='undock',port_id=destination));f['phase']='undocking'
                elif f['phase']=='undocking':
                    if s['dock']['state']=='underway':
                        f.update(leg=1,waypoint=0,phase='sail')
            if time.monotonic()>next_print:
                print('PROGRESS',[(i,f['leg'],f['phase'],f['waypoint'],{k:round(f['trace'][-1][k],1) for k in ['x','z','speed','heading']}) for i,f in enumerate(fleet)],flush=True)
                (self.run/'navigation-progress.json').write_text(json.dumps([dict(player=i,phase=f['phase'],trace=f['trace']) for i,f in enumerate(fleet)]))
                next_print=time.monotonic()+15
            time.sleep(.12)
        (self.run/'navigation-progress.json').write_text(json.dumps([dict(player=i,phase=f['phase'],trace=f['trace']) for i,f in enumerate(fleet)]))
        self.drain(server,marker,accounts)
        saved=[self.profile_for(a) for a in accounts]
        for i,profile in enumerate(saved):
            check(profile['money']==70000 and not profile['profile']['cargo'] and len(profile['profile']['delivered'])==2,'player '+str(i)+' retains two complete navigated settlements')
            check(profile['profile']['ship']['fuel_liters']<790,'real voyage consumed and saved fuel')
        port=free_port(True);server,marker=self.dedicated(port)
        for a,previous in zip(accounts,saved):
            p=self.join(port,a)
            self.until(p,lambda s:s.get('voyage',{}).get('wallet')==70000)
            check(self.profile_for(a)==previous,'fresh server restores exact post-voyage canonical profile')
            self.worker_call(p,dict(op='disconnect'));self.vacant([a])
        self.drain(server,marker,accounts)
        return dict(seconds=time.monotonic()-start,players=[dict(player=i,trace=f['trace']) for i,f in enumerate(fleet)])

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--runtime',choices=['editor','release'],default='editor');args=parser.parse_args()
    proof=Navigated(args.runtime)
    try:
        proof.setup();result=proof.exercise()
        for log in proof.run.rglob('godot.log'):check('ERROR:' not in log.read_text(errors='replace'),'clean runtime log '+str(log.relative_to(proof.run)))
        (proof.run/'navigated-voyage-summary.json').write_text(json.dumps(dict(passed=True,runtime=args.runtime,checks=CHECKS,**result),indent=2))
        print('NAVIGATED_VOYAGES_PASS',len(CHECKS),proof.run,flush=True)
    finally:proof.close()
