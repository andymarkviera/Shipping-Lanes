"""Isolated real bundled runtime, native login and gateway boundary checks."""
import http.client,json,os,ssl,sys,time,uuid
from pathlib import Path
SOURCE=Path(__file__).resolve().parents[2]; WS=SOURCE.parent
BUNDLE=WS/'output/hosting/ShippingLanes-Windows-Host'; PROJECT=BUNDLE/'ShippingLanes'
sys.path[:0]=[str(PROJECT/'tools/public_handoff'),str(PROJECT/'tools/hosting')]
import local_online as local
from gateway import route,Limits
sys.path.insert(0,str(SOURCE/'tools/public_handoff'))
import login_probe
login_probe.ROOT=PROJECT
from login_probe import LoginProof
checks=[]
def check(value,text):
    assert value,text
    checks.append(text);print('PASS',text,flush=True)
folder=WS/'output/host-check'/uuid.uuid4().hex[:8]
print('EVIDENCE',folder,flush=True)
settings=dict(host='127.0.0.1',name='Packaged host proof',bind_ip='127.0.0.1',https_port=local.free_port(),game_port=local.free_port(True),lan_ip='127.0.0.1')
check(route('POST','/v1/authority') is None,'authority route excluded')
check(route('GET','/admin/') is None and route('GET','/realms/master/') is None,'admin and other realms excluded')
check(route('GET','http://attacker.invalid/realms/shipping-local/login-actions/x') is None,'absolute proxy targets excluded')
check(route('POST','/realms/shipping-local/login-actions/%2e%2e/admin') is None,'encoded path escapes excluded')
limits=Limits()
check(all(limits.allow('a','post',0) for _ in range(20)) and not limits.allow('a','post',0),'per-IP post budget enforced')
check(limits.allow('a','post',61),'budget recovers after window')
local.initialize(folder,settings)
before=None
for cycle in range(2):
    stack=local.Stack(folder,'release');proof=None
    try:
        stack.start()
        auth=local.Authority(stack.settings['database'])
        with auth.connect() as db:current=db.execute('SELECT account,subject,money,revision,profile FROM public_authority.profiles ORDER BY subject').fetchall()
        if before is not None:check(current==before,'full packaged stack restart retains canonical accounts and saves')
        proof=LoginProof.__new__(LoginProof);proof.run=folder/('client-'+str(cycle));proof.run.mkdir();proof.runtime='release';proof.logs=[];proof.children=[]
        (proof.run/'provider').mkdir();(proof.run/'provider/ca.pem').write_bytes((folder/'local-cert.pem').read_bytes())
        player=proof.player(local.read(folder/'public-services.json'))
        proof.worker_call(player,{'op':'begin'})
        proof.browser(proof.until(player,lambda s:bool(s['url']))['url'],{'issuer':stack.settings['issuer']},stack.settings['users'][0])
        joined=proof.until(player,lambda s:s.get('joined',False) and s.get('ready',False))
        check(joined['token_cleared'],'packaged native PKCE login through HTTPS front door and DTLS join')
        proof.worker_call(player,{'op':'drive'});proof.until(player,lambda s:s['snapshot'].get('speed',0)>.02)
        check(True,'packaged client drives authoritative boat')
        proof.worker_call(player,{'op':'disconnect'});proof.until(player,lambda s:not s.get('joined',True))
        deadline=time.monotonic()+15
        while time.monotonic()<deadline:
            with auth.connect() as db:active=db.execute("SELECT count(*) AS n FROM public_authority.leases WHERE phase!='VACANT'").fetchone()['n']
            if active==0:break
            time.sleep(.1)
        check(active==0,'disconnect saves and releases ownership')
        context=ssl.create_default_context(cafile=str(folder/'local-cert.pem'))
        def request(path,body=b'{}',headers=None):
            client=http.client.HTTPSConnection('127.0.0.1',settings['https_port'],context=context,timeout=10)
            try:
                client.request('POST',path,body,headers or {});response=client.getresponse();status=response.status;response.read();return status
            finally:client.close()
        check(request('/v1/authority')==404,'live gateway rejects private mutation route')
        check(request('/v1/ticket',headers={'Host':'wrong.invalid'})==400,'live gateway rejects untrusted Host')
        check(request('/v1/ticket',body=b'x'*32769)==413,'live gateway rejects oversized request')
        responses=[request('/v1/ticket',headers={'Authorization':'Bearer invalid','X-Forwarded-For':'198.51.100.'+str(i)}) for i in range(25)]
        check(429 in responses and responses[-1]==429,'live rate limit ignores spoofed forwarding headers')
        with auth.connect() as db:before=db.execute('SELECT account,subject,money,revision,profile FROM public_authority.profiles ORDER BY subject').fetchall()
    finally:
        if proof:
            for child in proof.children:
                if child.poll() is None:child.terminate();child.wait(timeout=10)
            for log in proof.logs:log.close()
            for path in proof.run.rglob('reply-*.json'):
                data=local.read(path);data.pop('url',None);local.write(path,data)
        stack.close()
check(not (folder/'ready.json').exists(),'normal bundled host shutdown completes')
for log in folder.rglob('godot.log'):check('ERROR:' not in log.read_text(errors='replace'),'clean native client engine log')
local.write(folder/'hosting-summary.json',dict(passed=True,checks=checks,bundle=str(BUNDLE),network_scope='same-machine localhost; remote LAN/internet not tested'))
print('HOSTING_PACKAGE_PASS',len(checks),folder,flush=True)
