"""Real encrypted UDP impairment, blackout recovery, persistence; optional rendered client."""
import argparse,json,time,math
from peer_probe import PeerProof
from probe import CHECKS,check,free_port
from impairment import Impairment
from psycopg.types.json import Jsonb

def percentile(values,p):return sorted(values)[max(0,math.ceil(len(values)*p)-1)]
class ImpairedProof(PeerProof):
    def exercise(self,rendered):
        port=free_port(True);server=self.peer_worker('server',port)
        relay=Impairment(port)
        try:
            client=self.peer_worker('client',relay.port,rendered=rendered)
            nonce=self.until(client,lambda s:bool(s['nonce']))['nonce']
            self.worker_call(client,dict(op='ticket',ticket=self.authority.issue_ticket(self.account,'server-a',nonce)))
            ready=self.until(client,lambda s:s.get('presentation',{}).get('ready',False))
            check(ready['binding'] and ready['presentation']['camera'],'actual player scene admitted through opaque DTLS relay')
            if rendered:check(ready['display']!='headless' and ready['frames_drawn']>0,'rendered client draws frames with native graphics backend')
            account2=self.authority.create_fixture_account('https://fixture.invalid','impairment-observer')
            with self.authority.connect() as db:
                profile=db.execute('SELECT profile FROM public_authority.profiles WHERE account=%s',(account2,)).fetchone()['profile']
                profile['ship']['position']['longitude']=.1
                db.execute('UPDATE public_authority.profiles SET profile=%s WHERE account=%s',(Jsonb(profile),account2))
            observer=self.peer_worker('client',port)
            nonce2=self.until(observer,lambda s:bool(s['nonce']))['nonce']
            self.worker_call(observer,dict(op='ticket',ticket=self.authority.issue_ticket(account2,'server-a',nonce2)))
            self.until(client,lambda s:len(s['visible_ships'])==2)
            original=self.profile();baseline=relay.metrics();started=time.monotonic()
            relay.configure('impaired');last_tick=-1;last_ack=-1;ages=[];visible_samples=0
            for sequence in range(1,81):
                self.worker_call(client,dict(op='helm',sequence=sequence,throttle=.5))
                state=self.status(client)
                tick=state['tick'];ack=state['snapshot'].get('sequence',-1)
                assert tick>=last_tick and ack>=last_ack,'old encrypted packets regressed applied state'
                if ack>last_ack and 'ack_ms' in state:ages.append(state['ack_ms'])
                last_tick=tick;last_ack=ack
                if len(state['visible_ships'])==2:visible_samples+=1
                assert all(math.isfinite(r['x']) and math.isfinite(r['z']) for r in state['replicas'])
                time.sleep(.08)
            check(last_ack>50 and state['snapshot']['speed']>0,'commands and movement continue through delay loss duplication and reordering')
            check(last_tick>0 and visible_samples>60,'full snapshots retain both nearby boats throughout impairment')
            check(True,'applied snapshot ticks and input acknowledgements never regress')
            stats=relay.metrics()
            check(stats['dropped']>0 and stats['duplicated']>0 and stats['reordered']>0,'relay actually injects dropped duplicate and reordered encrypted datagrams')
            check(stats['max_queued']<=512,'impairment queue stays bounded')
            duration=time.monotonic()-started
            measured=dict(runtime=self.runtime,rendered=rendered,seconds=duration,unique_ack_samples=len(ages),ack_p95_ms=percentile(ages,.95),ack_max_ms=max(ages),frame_p95_ms=percentile(state['frame_ms'],.95),frame_max_ms=max(state['frame_ms']),udp_payload_bytes_per_second=((stats['bytes_to_client']-baseline['bytes_to_client'])+(stats['bytes_to_server']-baseline['bytes_to_server']))/duration,relay=stats)
            relay.configure('blackout')
            stale=self.until(client,lambda s:not s['presentation']['ready'] and not s['visible_ships'],timeout=5)
            check(stale['presentation']['order']==0,'blackout disables helm readiness and clears stale boat presentation')
            neutral=self.until(server,lambda s:all(abs(h['throttle'])<.001 for h in s['ships']),timeout=5)
            check(len(neutral['ships'])==2,'missing input neutralizes orders without deleting healthy owners')
            relay.configure('clear')
            recovered=self.until(client,lambda s:s['presentation']['ready'] and len(s['visible_ships'])==2,timeout=8)
            check(recovered['binding']==ready['binding'],'brief interruption restores complete state without duplicate admission')
            self.worker_call(client,dict(op='helm',sequence=1000,throttle=.3))
            self.until(client,lambda s:s['snapshot'].get('sequence',-1)==1000)
            check(True,'latest helm command resumes after blackout')
            self.worker_call(client,dict(op='disconnect'))
            deadline=time.monotonic()+12
            while time.monotonic()<deadline:
                with self.authority.connect() as db:phase=db.execute('SELECT phase FROM public_authority.leases WHERE account=%s',(self.account,)).fetchone()['phase']
                if phase=='VACANT':break
                time.sleep(.1)
            check(phase=='VACANT','impaired session still checkpoints and releases ownership on departure')
            final=self.profile()
            check(final['profile']['ship']['id']==original['profile']['ship']['id'] and final['money']==original['money'] and final['profile']['cargo']==original['profile']['cargo'],'connection impairment preserves canonical ship money and cargo identity')
            check(final['revision']>original['revision'] and final['profile']['ship']['fuel_liters']<original['profile']['ship']['fuel_liters'],'actual movement and fuel remain durably saved')
            self.worker_call(observer,dict(op='disconnect'));self.until(server,lambda s:s['members']==0)
            (self.run/'impairment-metrics.json').write_text(json.dumps(measured,indent=2));print(json.dumps(measured),flush=True)
        finally:relay.close()
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--runtime',choices=['editor','release'],default='editor');p.add_argument('--rendered',action='store_true');a=p.parse_args();proof=ImpairedProof(a.runtime)
    try:
        proof.setup();proof.exercise(a.rendered)
        (proof.run/'impairment-summary.json').write_text(json.dumps(dict(passed=True,fixture_tickets=True,checks=CHECKS),indent=2))
        print('PUBLIC_IMPAIRMENT_PASS',len(CHECKS),a.runtime,flush=True)
    finally:proof.close()
