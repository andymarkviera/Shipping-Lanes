"""Durability tests use fixture-issued tickets, actual DTLS peers and dedicated runtime."""
import argparse,json,time
from peer_probe import PeerProof
from probe import CHECKS,check,free_port,psycopg

class Durability(PeerProof):
    def join(self,port):
        client=self.peer_worker('client',port)
        nonce=self.until(client,lambda s:bool(s['nonce']))['nonce']
        self.worker_call(client,dict(op='ticket',ticket=self.authority.issue_ticket(self.account,'server-a',nonce)))
        self.until(client,lambda s:bool(s['binding']) and s.get('presentation',{}).get('ready',False))
        return client
    def revision(self):return self.profile()['revision']
    def wait_revision(self,initial):
        end=time.monotonic()+24
        while time.monotonic()<end:
            if self.revision()>initial:return self.profile()
            time.sleep(.1)
        raise AssertionError('No periodic commit while sailing')
    def exercise(self):
        port=free_port(True);stop=self.run/'stop-server'
        server=self.peer_worker('server',port,dedicated=True,stop_file=str(stop))
        client=self.join(port);initial=self.revision()
        self.worker_call(client,dict(op='drive'))
        saved=self.wait_revision(initial)
        check(saved['profile']['ship']['fuel_liters']<800,'periodic save commits fuel while player remains connected')
        check(saved['profile']['ship']['position']!={'latitude':0.0,'longitude':0.0,'heading':0.0},'periodic save commits moving geographic pose')
        check(bool(self.status(client)['binding']),'autosave preserves live connection')
        server['child'].kill();server['child'].wait()
        committed=self.profile()
        check(committed['revision']>=saved['revision'],'abrupt server kill preserves latest committed revision')
        # Wait out the actual lease rather than mutating the database clock.
        time.sleep(31)
        server=self.peer_worker('server',port,dedicated=True,stop_file=str(stop))
        resumed=self.join(port)
        check(self.profile()==committed,'crash restart and reacquisition preserve canonical ship fuel pose and receipts')
        self.worker_call(resumed,dict(op='drive'))
        self.until(resumed,lambda s:s['snapshot'].get('speed',0)>.05)
        before=self.revision();stop.touch()
        check(server['child'].wait(timeout=25)==0,'operator drain exits successfully with connected player')
        check('PUBLIC_SERVER_DRAINED' in (server['folder']/'godot.log').read_text(),'successful shutdown explicitly confirms final saves')
        check(self.revision()>before,'shutdown performs final checkpoint beyond periodic save')
        with self.authority.connect() as db:phase=db.execute('SELECT phase FROM public_authority.leases WHERE account=%s',(self.account,)).fetchone()['phase']
        check(phase=='VACANT','shutdown releases canonical ownership')
        stop.unlink();server=self.peer_worker('server',port,dedicated=True,stop_file=str(stop))
        final=self.join(port)
        check(bool(self.status(final)['binding']),'clean shutdown permits immediate reconnect without waiting for lease')
        replacement=self.peer_worker('client',port)
        nonce=self.until(replacement,lambda s:bool(s['nonce']))['nonce']
        self.worker_call(replacement,dict(op='ticket',ticket=self.authority.issue_ticket(self.account,'server-a',nonce)))
        stop.touch()
        race_exit=server['child'].wait(timeout=25)
        check(race_exit in (0,2),'replacement race terminates with explicit complete or incomplete drain result')
        marker='PUBLIC_SERVER_DRAINED' if race_exit==0 else 'PUBLIC_SERVER_DRAIN_FAILED'
        check(marker in (server['folder']/'godot.log').read_text(),'replacement fencing never silently reports a failed final save as complete')
        with self.authority.connect() as db:phase=db.execute('SELECT phase FROM public_authority.leases WHERE account=%s',(self.account,)).fetchone()['phase']
        check(phase=='VACANT','replacement shutdown leaves no owned lease')
        stop.unlink();server=self.peer_worker('server',port,dedicated=True,stop_file=str(stop))
        final=self.join(port)
        before=self.profile();self.stop_service();stop.touch()
        check(server['child'].wait(timeout=25)==2,'backend outage reports failed drain instead of false save success')
        check('PUBLIC_SERVER_DRAIN_FAILED' in (server['folder']/'godot.log').read_text(),'failed drain emits explicit failure marker')
        check(self.profile()==before,'outage drain preserves last committed profile without fabricated save')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--runtime',choices=['editor','release'],default='editor');a=p.parse_args()
    proof=Durability(a.runtime)
    try:
        proof.setup();proof.exercise()
        (proof.run/'durability-summary.json').write_text(json.dumps(dict(passed=True,runtime=a.runtime,fixture_tickets=True,checks=CHECKS),indent=2))
        print('PUBLIC_DURABILITY_PASS',len(CHECKS),a.runtime,flush=True)
    finally:proof.close()
