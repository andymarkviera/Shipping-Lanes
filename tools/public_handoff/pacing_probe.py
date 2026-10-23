"""Bounded eight-peer loopback measurement; no production/WAN capacity claim."""
import argparse,json,time,math
from peer_probe import PeerProof
from probe import CHECKS,check,free_port
from psycopg.types.json import Jsonb

def percentile(values,p):return sorted(values)[max(0,math.ceil(len(values)*p)-1)]
class Pacing(PeerProof):
    def exercise(self):
        port=free_port(True);server=self.peer_worker('server',port)
        clients=[]
        for i in range(8):
            account=self.account if i==0 else self.authority.create_fixture_account('https://fixture.invalid','pacing-'+str(i))
            with self.authority.connect() as db:
                row=db.execute('SELECT profile FROM public_authority.profiles WHERE account=%s',(account,)).fetchone()['profile']
                row['ship']['position']['longitude']=i*.04
                db.execute('UPDATE public_authority.profiles SET profile=%s WHERE account=%s',(Jsonb(row),account))
            client=self.peer_worker('client',port)
            nonce=self.until(client,lambda s:bool(s['nonce']))['nonce']
            self.worker_call(client,dict(op='ticket',ticket=self.authority.issue_ticket(account,'server-a',nonce)))
            self.until(client,lambda s:bool(s['binding']) and s.get('presentation',{}).get('ready',False))
            clients.append(client)
        check(self.status(server)['members']==8,'eight actual DTLS clients admitted with distinct nearby hulls')
        check(len(self.until(clients[0],lambda s:len(s['visible_ships'])==8)['visible_ships'])==8,'complete compact snapshot retains every nearby collision-relevant boat')
        start=self.status(server);started=time.monotonic();ages=[]
        for sequence in range(1,41):
            sent=time.monotonic()
            self.worker_call(clients[0],dict(op='helm',sequence=sequence,throttle=.5))
            result=self.until(clients[0],lambda s:s['snapshot'].get('sequence',-1)>=sequence)
            ages.append(result["ack_ms"])
            time.sleep(.1)
        end=self.status(server);elapsed=time.monotonic()-started
        check(end['max_snapshot_bytes']<=1200,'actual eight-player serialized snapshot arguments stay below 1200 bytes')
        check(result['snapshot']['speed']>0,'sequenced unreliable helm commands drive the real authoritative boat')
        # Skip old commands deliberately: latest sequence must work without retransmitted history.
        self.worker_call(clients[0],dict(op='helm',sequence=1000,throttle=0))
        self.until(clients[0],lambda s:s['snapshot'].get('sequence',-1)==1000)
        check(True,'missing earlier helm sequences do not block latest command')
        self.worker_call(clients[0],dict(op='helm',sequence=999,throttle=1))
        time.sleep(.3)
        check(self.status(clients[0])['snapshot']['sequence']==1000,'late obsolete command cannot overwrite newer order')
        check(self.worker_call(clients[0],dict(op='pace_burst'))['sent']<=1,'thirty catch-up physics callbacks send at most one latest command')
        metrics=dict(runtime=self.runtime,clients=8,seconds=elapsed,max_serialized_snapshot_bytes=end['max_snapshot_bytes'],serialized_snapshot_bytes_per_second=(end['snapshot_bytes']-start['snapshot_bytes'])/elapsed,client_ack_p95_ms=percentile(ages,.95),client_ack_max_ms=max(ages),snapshot_build_p99_ms=percentile(end['snapshot_work_us'],.99)/1000,group_sync_p99_ms=percentile(end['physics_work_us'],.99)/1000)
        # Report responsiveness rather than make a noisy single-machine timing a correctness oracle.
        (self.run/'pacing-metrics.json').write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics),flush=True)
        for client in clients:self.worker_call(client,dict(op='disconnect'))
        self.until(server,lambda s:s['members']==0)
        check(True,'all eight clients disconnect without retained live hulls')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--runtime',choices=['editor','release'],default='editor');a=p.parse_args();proof=Pacing(a.runtime)
    try:
        proof.setup();proof.exercise()
        (proof.run/'pacing-summary.json').write_text(json.dumps(dict(passed=True,fixture_tickets=True,checks=CHECKS)))
        print('PUBLIC_PACING_PASS',len(CHECKS),a.runtime,flush=True)
    finally:proof.close()
