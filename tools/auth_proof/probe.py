"""Disposable provider + transport proof. Does not configure public accounts."""
import argparse, json, os, secrets, shutil, ssl, subprocess, sys, time, urllib.error, urllib.request, uuid, zipfile, hashlib
from pathlib import Path
import cryptography
from cryptography.exceptions import InvalidSignature
from common import ROOT, WORKSPACE, certificates, free_port, transport_proof, PYTHON_FLAGS
from oidc import NativeFlow, synthetic_browser, validate_jwt
CHECKS=[]
def check(ok,name):
    if not ok:raise AssertionError(name)
    CHECKS.append(name);print('PASS',name,flush=True)
def rejects(call,name):
    try:call()
    except urllib.error.HTTPError as error:
        if error.code!=400:raise
        check(True,name);return
    except (ValueError,InvalidSignature):check(True,name);return
    raise AssertionError('Expected rejection: '+name)

def dependencies(run):
    manifest=json.loads((Path(__file__).parent/'dependencies.json').read_text())
    check(cryptography.__version__==manifest['cryptography'],'pinned cryptography')
    base=WORKSPACE/'output/tools/auth'
    for name in ['java','keycloak']:
        info=manifest[name];archive=base/name/'distribution.zip'
        expected=info.get('sha256') or info['digest'].split(':')[1]
        check(hashlib.sha256(archive.read_bytes()).hexdigest()==expected,'pinned '+name+' archive')
    with zipfile.ZipFile(base/'keycloak/distribution.zip') as z:
        for entry in z.infolist():
            if entry.is_dir():continue
            relative=Path(*Path(entry.filename).parts[1:]);target=run/'kc'/relative
            assert target.resolve().is_relative_to((run/'kc').resolve())
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(entry))
    java_root=base/'java'
    with zipfile.ZipFile(java_root/'distribution.zip') as z:
        for entry in z.infolist():
            if not entry.is_dir():check_file=java_root/entry.filename;assert hashlib.sha256(check_file.read_bytes()).digest()==hashlib.sha256(z.read(entry)).digest()
    return java_root/manifest['java']['runtime_directory']/'bin/java.exe'

def oidc_proof(run, integration=None, browser_integration=None, extra_redirects=(), provider_host='localhost'):
    java=dependencies(run);certificates(run);port=free_port();issuer='https://%s:%d/realms/shipping-proof'%(provider_host,port)
    flows=[NativeFlow(issuer,run/'ca.pem') for _ in range(2)]
    password=secrets.token_urlsafe(24)
    realm=dict(realm='shipping-proof',enabled=True,registrationAllowed=False,resetPasswordAllowed=False,sslRequired='all',users=[dict(username='synthetic-sailor',enabled=True,email='sailor@example.invalid',emailVerified=True,firstName='Test',lastName='Sailor',credentials=[dict(type='password',value=password,temporary=False)])],clients=[dict(clientId='shipping-native',enabled=True,publicClient=True,standardFlowEnabled=True,directAccessGrantsEnabled=False,redirectUris=[f.redirect for f in flows] + list(extra_redirects),attributes={'pkce.code.challenge.method':'S256'},protocolMappers=[dict(name='service-audience',protocol='openid-connect',protocolMapper='oidc-audience-mapper',config={'included.custom.audience':'shipping-service','access.token.claim':'true','id.token.claim':'false'})])])
    imports=run/'kc/data/import';imports.mkdir(parents=True,exist_ok=True);realm_file=imports/'shipping-proof-realm.json';realm_file.write_text(json.dumps(realm))
    home=run/'kc'
    args=[str(java),'--add-opens=java.base/java.lang=ALL-UNNAMED','--enable-native-access=ALL-UNNAMED','-Xms128m','-Xmx512m','-Dkc.home.dir='+str(home),'-Djboss.server.config.dir='+str(home/'conf'),'-Djava.util.concurrent.ForkJoinPool.common.threadFactory=io.quarkus.bootstrap.forkjoin.QuarkusForkJoinWorkerThreadFactory','-cp',str(home/'lib/quarkus-run.jar'),'io.quarkus.bootstrap.runner.QuarkusEntryPoint','start','--cache=local','--db=dev-file','--http-enabled=false','--http-host=127.0.0.1','--https-port='+str(port),'--hostname=https://'+provider_host+':'+str(port),'--https-certificate-file='+str(run/'server.pem'),'--https-certificate-key-file='+str(run/'server-key.pem'),'--import-realm']
    log=(run/'keycloak.log').open('wb');child=None
    try:
        child=subprocess.Popen(args,stdout=log,stderr=log,creationflags=PYTHON_FLAGS)
        deadline=time.monotonic()+100;ready=False;restarted=False
        while time.monotonic()<deadline:
            if child.poll()==10 and not restarted:
                child=subprocess.Popen(args[:1]+['-Dkc.config.built=true']+args[1:],stdout=log,stderr=log,creationflags=PYTHON_FLAGS);restarted=True
            if child.poll() is not None:raise RuntimeError('Provider exited; inspect keycloak.log')
            try:flows[0].discovery();ready=True;break
            except Exception:time.sleep(.3)
        check(ready,'real Keycloak HTTPS discovery')
        realm_file.unlink()
        flows[0].deadline=time.monotonic()+60
        rejects(lambda:urllib.request.urlopen(flows[0].redirect+'?state=wrong&code=wrong'),'callback state mismatch rejected')
        flows[0].deadline=0
        rejects(lambda:urllib.request.urlopen(flows[0].redirect+'?state='+flows[0].state+'&code=wrong'),'expired callback rejected')
        flow=flows[0];synthetic_browser(flow,'synthetic-sailor',password)
        tokens=flow.exchange();jwks=flow.get_json(flow.discovery()['jwks_uri'])
        identity=validate_jwt(tokens['id_token'],jwks,issuer,'shipping-native',flow.nonce)
        access=validate_jwt(tokens['access_token'],jwks,issuer,'shipping-service')
        check(identity['sub']==access['sub'],'real PKCE login maps issuer plus subject')
        rejects(flow.exchange,'authorization code cannot be replayed')
        rejects(lambda:urllib.request.urlopen(flow.redirect+'?state='+flow.state+'&code=again'),'loopback callback consumed once')
        bad=flows[1];synthetic_browser(bad,'synthetic-sailor',password)
        rejects(lambda:bad.exchange('x'*64),'provider rejects wrong PKCE verifier')
        rejects(lambda:validate_jwt(tokens['id_token'],jwks,issuer,'shipping-native','wrong'),'nonce mismatch')
        rejects(lambda:validate_jwt(tokens['access_token'],jwks,issuer,'other-service'),'wrong audience')
        rejects(lambda:validate_jwt(tokens['access_token'],jwks,issuer+'/other','shipping-service'),'wrong issuer')
        rejects(lambda:validate_jwt(tokens['access_token'],jwks,issuer,'shipping-service',now=access['exp']+1),'expired token')
        pieces=tokens['access_token'].split('.');pieces[1]=pieces[1][:-4]+'AAAA'
        rejects(lambda:validate_jwt('.'.join(pieces),jwks,issuer,'shipping-service'),'modified signed token')
        check('refresh_token' in tokens,'provider returns refresh credential kept only in memory')
        if integration is not None:
            integration(dict(issuer=issuer, audience='shipping-service', jwks=jwks), tokens, access)
        if browser_integration is not None:
            browser_integration(dict(issuer=issuer, audience='shipping-service', jwks=jwks), access, {'username': 'synthetic-sailor', 'password': password})
        return dict(issuer=issuer,subject=identity['sub'])
    finally:
        for flow in flows:flow.close()
        if child and child.poll() is None:child.terminate();child.wait(timeout=20)
        log.close();realm_file.unlink(missing_ok=True)

def admission_proof(run,identity):
    # Reuse the already-proven disposable PostgreSQL launcher; no external database.
    import importlib.util
    from concurrent.futures import ThreadPoolExecutor
    sys.path.insert(0,str(WORKSPACE/'output/tools/public-storage-python'))
    sys.path.insert(0,str(ROOT/'tools/public_storage'))
    spec=importlib.util.spec_from_file_location('public_storage_fixture',ROOT/'tools/public_storage/probe.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    from admission import AdmissionRegistry,PrivateGuests
    fixture=module.Proof()
    # This proof uses the database registry directly, not the earlier HTTP store.
    fixture.start_service=lambda: None
    try:
        fixture.setup();fixture.stop_service()
        registry=AdmissionRegistry(fixture.admin)
        claims={'iss':identity['issuer'],'sub':identity['subject']}
        account=registry.account(claims)
        check(registry.account(claims)==account,'issuer-subject stable account mapping')
        check(registry.account(dict(claims,iss=claims['iss']+'/other'))!=account,'different issuer cannot claim same subject')
        credential=registry.server('server-a','certificate-a')
        other=registry.server('server-b','certificate-b')
        nonce=secrets.token_urlsafe(32)
        ticket=registry.issue(account,'server-a',nonce)
        check(registry.redeem(ticket,'server-b',other,'certificate-b',nonce) is None,'wrong-server ticket rejected')
        check(registry.redeem(ticket,'server-a',other,'certificate-a',nonce) is None,'untrusted server credential rejected')
        check(registry.redeem(ticket,'server-a',credential,'wrong-certificate',nonce) is None,'ticket bound to server certificate identity')
        check(registry.redeem(ticket,'server-a',credential,'certificate-a','wrong') is None,'ticket bound to connection nonce')
        check(registry.redeem(ticket,'server-a',credential,'certificate-a',nonce,4) is None,'ticket protocol mismatch rejected')
        with ThreadPoolExecutor(max_workers=8) as pool:
            outcomes=list(pool.map(lambda _:registry.redeem(ticket,'server-a',credential,'certificate-a',nonce),range(8)))
        check(outcomes.count(account)==1 and outcomes.count(None)==7,'concurrent ticket redemption commits exactly once')
        check(registry.redeem(ticket,'server-a',credential,'certificate-a',nonce) is None,'consumed ticket replay rejected')
        expired=registry.issue(account,'server-a',nonce,expires=int(time.time())-1)
        check(registry.redeem(expired,'server-a',credential,'certificate-a',nonce) is None,'expired ticket rejected')
        rotation=registry.issue(account,'server-a',nonce)
        with module.psycopg.connect(**fixture.admin) as db:db.execute("UPDATE auth_servers SET fingerprint='rotated' WHERE id='server-a'")
        check(registry.redeem(rotation,'server-a',credential,'rotated',nonce) is None,'certificate rotation invalidates previously issued ticket')
        with module.psycopg.connect(**fixture.admin) as db:db.execute("UPDATE auth_servers SET approved=false WHERE id='server-a'")
        check(registry.redeem(rotation,'server-a',credential,'rotated',nonce) is None,'revoked server cannot redeem tickets')
        rejects(lambda:registry.issue(account,'server-a',nonce),'revoked server cannot receive tickets')
        with module.psycopg.connect(**fixture.admin) as db:db.execute("UPDATE auth_servers SET expires=0 WHERE id='server-b'")
        check(registry.redeem(ticket,'server-b',other,'certificate-b',nonce) is None,'expired server credential rejected')
        rejects(lambda:registry.issue(account,'server-b',nonce),'expired server cannot receive tickets')
        guests=PrivateGuests(run/'guests.sqlite')
        player,secret=guests.create('world-a','certificate-a')
        first=guests.reconnect('world-a',player,'certificate-a',secret)
        check(first==1 and guests.current('world-a',player,first),'private guest accepted with scoped credential')
        check(guests.reconnect('world-b',player,'certificate-a',secret) is None,'private credential wrong world rejected')
        check(guests.reconnect('world-a',player,'certificate-b',secret) is None,'private credential wrong host identity rejected')
        check(guests.reconnect('world-a',player,'certificate-a','wrong') is None,'private credential forgery rejected')
        reopened=PrivateGuests(run/'guests.sqlite');second=reopened.reconnect('world-a',player,'certificate-a',secret)
        check(second==2 and not reopened.current('world-a',player,first) and reopened.current('world-a',player,second),'reconnect persists and supersedes old connection generation')
        check(secret.encode() not in (run/'guests.sqlite').read_bytes(),'private store contains credential hash only')
        check(registry.redeem(secret,'server-b',other,'certificate-b',nonce) is None,'private credential cannot redeem public ticket')
        with module.psycopg.connect(**fixture.admin) as db:check(db.execute('SELECT count(*) FROM auth_tickets WHERE used').fetchone()[0]==1,'only one ticket consumed')
    finally:fixture.close()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--runtime',choices=['editor','release','both','none'],default='editor');args=parser.parse_args()
    run=WORKSPACE/'output/auth'/uuid.uuid4().hex[:8];run.mkdir(parents=True)
    print('Evidence:',run,flush=True)
    identity=oidc_proof(run)
    admission_proof(run,identity)
    for runtime in (['editor','release'] if args.runtime=='both' else [] if args.runtime=='none' else [args.runtime]):
        transport_proof(run,runtime)
    (run/'summary.json').write_text(json.dumps({'checks':CHECKS,'runtime':args.runtime,'passed':True},indent=2))
    print('AUTH_PROOF_PASS',len(CHECKS),'checks',args.runtime,flush=True)
