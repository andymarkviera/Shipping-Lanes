"""Restart proof using the persistent local launcher and actual native login scene."""
import json, time, uuid
from pathlib import Path
from local_online import BASE, Stack, initialize, read, write, Authority
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from login_probe import LoginProof

def main():
    folder=BASE/('check-'+uuid.uuid4().hex[:8]); initialize(folder)
    checks=[]; before=None
    for cycle in range(2):
        stack=Stack(folder)
        try:
            stack.start()
            if cycle==0:
                duplicate=Stack(folder)
                try:
                    try:duplicate.start()
                    except RuntimeError as e:assert 'already running' in str(e);checks.append('duplicate supervisor refused')
                    else:raise AssertionError('duplicate accepted')
                finally:duplicate.close()
            authority=Authority(stack.settings['database'])
            with authority.connect() as db:
                current=db.execute('SELECT account,subject,money,revision,profile FROM public_authority.profiles ORDER BY subject').fetchall()
            if before is not None:assert current==before;checks.append('accounts money ship IDs position fuel revisions persist across full stack restart')
            for index,user in enumerate(stack.settings['users']):
                proof=LoginProof.__new__(LoginProof)
                proof.run=folder/('check-%d-%d'%(cycle,index));proof.run.mkdir()
                proof.runtime='editor';proof.logs=[];proof.children=[]
                (proof.run/'provider').mkdir();(proof.run/'provider/ca.pem').write_bytes((folder/'local-cert.pem').read_bytes())
                try:
                    player=proof.player(read(folder/'public-services.json'))
                    proof.worker_call(player,{'op':'begin'})
                    identity={'issuer':stack.settings['issuer']}
                    proof.browser(proof.until(player,lambda s:bool(s['url']))['url'],identity,user)
                    joined=proof.until(player,lambda s:s['joined'] and s['ready'])
                    assert joined['token_cleared'];checks.append('native sign-in and stable enrolled account enters boat')
                    proof.worker_call(player,{'op':'drive'})
                    proof.until(player,lambda s:s['snapshot'].get('speed',0)>.02)
                    proof.worker_call(player,{'op':'disconnect'})
                    proof.until(player,lambda s:not s['joined'])
                    deadline=time.monotonic()+12
                    while time.monotonic()<deadline:
                        with authority.connect() as db:active=db.execute("SELECT count(*) AS count FROM public_authority.leases WHERE phase!='VACANT'").fetchone()['count']
                        if active==0:break
                        time.sleep(.1)
                    assert active==0;checks.append('drive disconnect and durable lease release')
                finally:
                    for child in proof.children:
                        if child.poll() is None:child.terminate();child.wait(timeout=10)
                    for log in proof.logs:log.close()
                    for path in proof.run.rglob('reply-*.json'):
                        data=read(path);data.pop('url',None);write(path,data)
            with authority.connect() as db:before=db.execute('SELECT account,subject,money,revision,profile FROM public_authority.profiles ORDER BY subject').fetchall()
            assert len(before)==2;assert all(row['profile']['jobs']==[] for row in before)
            checks.append('two development accounts only with no invented active jobs')
        finally:stack.close()
    assert not (folder/'ready.json').exists();assert not (folder/'server.json').exists()
    checks.append('owned services stopped and runtime credentials removed')
    write(folder/'check-summary.json',dict(passed=True,checks=checks))
    print('LOCAL_ONLINE_CHECK_PASS',len(checks),folder,flush=True)

if __name__=='__main__':main()
