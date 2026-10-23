"""Persistent, loopback-only online development stack. Never production accounts."""
import argparse, datetime, hashlib, importlib.util, json, os, secrets
import ssl, subprocess, sys, time, urllib.request, uuid
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT.parent
PACKAGES = WORKSPACE / 'output/tools/public-storage-python'
sys.path[:0] = [str(PACKAGES), str(ROOT / 'services/public_authority'), str(ROOT / 'tools/auth_proof')]
import psycopg
from psycopg import sql
from psycopg.types.json import Jsonb
from authority import Authority, digest
from common import free_port
FLAGS = subprocess.CREATE_NO_WINDOW
BASE = WORKSPACE / 'output/local-online'
BIN = WORKSPACE / 'output/tools/postgresql-17.11/pgsql/bin'

def write(path, value):
    path.write_text(json.dumps(value, indent=2), encoding='utf-8')

def read(path): return json.loads(path.read_text(encoding='utf-8'))

def command(args):
    # Detached postgres must not inherit a captured pipe.
    import tempfile
    with tempfile.TemporaryFile() as log:
        result = subprocess.run([str(a) for a in args], stdout=log, stderr=log, creationflags=FLAGS, timeout=60)
    if result.returncode: raise RuntimeError('Local command failed: ' + Path(str(args[0])).name)

def protect(folder):
    sid = subprocess.check_output(['whoami', '/user', '/fo', 'csv', '/nh'], creationflags=FLAGS).decode().strip().split(',')[-1].strip('"')
    command(['icacls', folder, '/inheritance:r', '/grant:r', '*' + sid + ':(OI)(CI)F', '*S-1-5-18:(OI)(CI)F'])

def provider_module():
    spec = importlib.util.spec_from_file_location('local_provider_dependencies', ROOT / 'tools/auth_proof/probe.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module

def certificates(folder):
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.x509.oid import NameOID
    import ipaddress
    now = datetime.datetime.now(datetime.timezone.utc)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Container Ship Sim local development only')])
    cert = x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=5)).not_valid_after(now+datetime.timedelta(days=90)).add_extension(x509.BasicConstraints(ca=True,path_length=0),True).add_extension(x509.SubjectAlternativeName([x509.DNSName('localhost'),x509.IPAddress(ipaddress.ip_address('127.0.0.1'))]),False).sign(key,hashes.SHA256())
    (folder/'local-cert.pem').write_bytes(cert.public_bytes(serialization.Encoding.PEM))
    (folder/'local-key.pem').write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))

def initialize(folder):
    if folder.exists(): raise RuntimeError('Setup already exists; use run. Existing data will not be overwritten.')
    folder.mkdir(parents=True)
    protect(folder)
    java = provider_module().dependencies(folder)
    certificates(folder)
    ports = [free_port() for _ in range(4)]
    if len(set(ports)) != 4: raise RuntimeError('Port selection collided; use a new setup name.')
    database = dict(host='127.0.0.1', port=ports[0], dbname='postgres', user='local_admin', password=secrets.token_urlsafe(32))
    settings = dict(version=1, java=str(java), database=database, provider_port=ports[1], authority_port=ports[2], callback_port=ports[3], game_port=free_port(True))
    issuer = 'https://127.0.0.1:%d/realms/shipping-local' % ports[1]
    users = [dict(username='dev-sailor-'+str(i+1), subject=str(uuid.uuid4()), password=secrets.token_urlsafe(18)) for i in range(2)]
    settings['issuer'] = issuer; settings['users'] = users
    write(folder/'private.json', settings)
    (folder/'login-info.txt').write_text('LOCAL DEVELOPMENT ACCOUNTS ONLY\n' + '\n'.join(u['username'] + ': ' + u['password'] for u in users) + '\n', encoding='utf-8')
    pw = folder/'init-password'; pw.write_text(database['password'])
    try: command([BIN/'initdb.exe','-D',folder/'postgres','-U','local_admin','--encoding=UTF8','--locale=C','--auth=scram-sha-256','--pwfile',pw])
    finally: pw.unlink(missing_ok=True)
    with (folder/'postgres/postgresql.conf').open('a') as f:
        f.write("\nlisten_addresses='127.0.0.1'\nport=%d\nfsync=on\nsynchronous_commit=on\nfull_page_writes=on\nmax_connections=40\n" % ports[0])
    realm = dict(realm='shipping-local', enabled=True, registrationAllowed=False, resetPasswordAllowed=False, sslRequired='all', users=[dict(id=u['subject'],username=u['username'],enabled=True,email=u['username']+'@example.invalid',emailVerified=True,firstName='Development',lastName='Sailor',credentials=[dict(type='password',value=u['password'],temporary=False)]) for u in users], clients=[dict(clientId='shipping-native',enabled=True,publicClient=True,standardFlowEnabled=True,directAccessGrantsEnabled=False,redirectUris=['http://127.0.0.1:%d/callback'%ports[3]],attributes={'pkce.code.challenge.method':'S256'},protocolMappers=[dict(name='service-audience',protocol='openid-connect',protocolMapper='oidc-audience-mapper',config={'included.custom.audience':'shipping-service','access.token.claim':'true','id.token.claim':'false'})])])
    imports=folder/'kc/data/import'; imports.mkdir(parents=True,exist_ok=True)
    write(imports/'shipping-local-realm.json', realm)
    write(folder/'initialized.json', dict(version=1))
    print('LOCAL_SETUP_CREATED', folder, flush=True)

class Stack:
    def __init__(self, folder, runtime='editor'):
        self.folder=folder; self.settings=read(folder/'private.json'); self.runtime=runtime
        if read(folder/'initialized.json') != {'version':1}: raise RuntimeError('Incomplete setup')
        self.children=[]; self.logs=[]; self.db_started=False; self.lock=None
    def spawn(self, args, name, env=None):
        log=(self.folder/(name+'.log')).open('wb'); self.logs.append(log)
        child=subprocess.Popen([str(a) for a in args],stdout=log,stderr=log,env=env,creationflags=FLAGS)
        self.children.append(child); return child
    def wait(self, condition, child, timeout=100):
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            if child.poll() is not None: raise RuntimeError('Service exited; see local logs')
            try:
                if condition(): return
            except (OSError, ValueError): pass
            time.sleep(.2)
        raise RuntimeError('Local service readiness timeout')
    def start(self):
        import msvcrt
        self.lock=(self.folder/'run.lock').open('a+b'); self.lock.seek(0)
        try: msvcrt.locking(self.lock.fileno(),msvcrt.LK_NBLCK,1)
        except OSError: self.lock.close(); self.lock=None; raise RuntimeError('This setup is already running')
        f=self.folder; s=self.settings
        command([BIN/'pg_ctl.exe','-D',f/'postgres','-l',f/'postgres.log','-w','start']); self.db_started=True
        authority=Authority(s['database']); authority.initialize()
        cert=f/'local-cert.pem'; fingerprint=hashlib.sha256(cert.read_bytes()).hexdigest()
        credential=secrets.token_urlsafe(32); service_password=secrets.token_urlsafe(32)
        with authority.connect() as db:
            for i,u in enumerate(s['users']):
                existing=db.execute('SELECT account FROM public_authority.profiles WHERE issuer=%s AND subject=%s',(s['issuer'],u['subject'])).fetchone()
                if existing: continue
                account=str(uuid.uuid4())
                # Development-only funds and deliberately separated fixed starts; no real enrollment API.
                profile=dict(version=1,ship=dict(id=str(uuid.uuid4()),definition='ship_starter_container_01',fuel_liters=800.0,position=dict(latitude=0.0,longitude=i*.2,heading=0.0)),cargo=[],jobs=[],delivered=[])
                db.execute('INSERT INTO public_authority.profiles VALUES(%s,%s,%s,20000,0,%s)',(account,s['issuer'],u['subject'],Jsonb(profile)))
                db.execute("INSERT INTO public_authority.leases(account,phase) VALUES(%s,'VACANT')",(account,))
            db.execute("INSERT INTO public_authority.servers VALUES('local-development',%s,%s,true,clock_timestamp()+interval '1 hour') ON CONFLICT(id) DO UPDATE SET credential_hash=EXCLUDED.credential_hash,fingerprint=EXCLUDED.fingerprint,approved=true,expires=EXCLUDED.expires",(digest(credential),fingerprint))
            if not db.execute("SELECT 1 FROM pg_roles WHERE rolname='local_authority'").fetchone(): db.execute('CREATE ROLE local_authority LOGIN')
            db.execute(sql.SQL('ALTER ROLE local_authority PASSWORD {}').format(sql.Literal(service_password)))
            db.execute('GRANT USAGE ON SCHEMA public_authority TO local_authority')
            db.execute('GRANT SELECT,INSERT,UPDATE ON ALL TABLES IN SCHEMA public_authority TO local_authority')
        home=f/'kc'
        args=[s['java'],'--add-opens=java.base/java.lang=ALL-UNNAMED','--enable-native-access=ALL-UNNAMED','-Xms128m','-Xmx512m','-Dkc.home.dir='+str(home),'-Djboss.server.config.dir='+str(home/'conf'),'-Djava.util.concurrent.ForkJoinPool.common.threadFactory=io.quarkus.bootstrap.forkjoin.QuarkusForkJoinWorkerThreadFactory','-cp',str(home/'lib/quarkus-run.jar'),'io.quarkus.bootstrap.runner.QuarkusEntryPoint','start','--cache=local','--db=dev-file','--http-enabled=false','--http-host=127.0.0.1','--https-port='+str(s['provider_port']),'--hostname=https://127.0.0.1:'+str(s['provider_port']),'--https-certificate-file='+str(cert),'--https-certificate-key-file='+str(f/'local-key.pem'),'--import-realm']
        provider=self.spawn(args,'provider')
        context=ssl.create_default_context(cafile=str(cert))
        def fetch(url):
            with urllib.request.urlopen(url,context=context,timeout=2) as reply: return json.load(reply)
        deadline=time.monotonic()+110; restarted=False
        while time.monotonic()<deadline:
            if provider.poll()==10 and not restarted:
                provider=self.spawn(args[:1]+['-Dkc.config.built=true']+args[1:],'provider-built'); restarted=True
            if provider.poll() is not None: raise RuntimeError('Provider startup failed; see logs')
            try: discovery=fetch(s['issuer']+'/.well-known/openid-configuration'); break
            except OSError: time.sleep(.3)
        else: raise RuntimeError('Provider readiness timeout')
        (home/'data/import/shipping-local-realm.json').unlink(missing_ok=True)
        identity=dict(issuer=s['issuer'],audience='shipping-service',jwks=fetch(discovery['jwks_uri']))
        ready=f/'authority-ready'; ready.unlink(missing_ok=True)
        write(f/'authority.json',dict(database=dict(s['database'],user='local_authority',password=service_password),port=s['authority_port'],certificate=str(cert),key=str(f/'local-key.pem'),ready=str(ready),identity=identity))
        env=os.environ.copy(); env['PYTHONPATH']=str(PACKAGES)
        service=self.spawn([sys.executable,ROOT/'services/public_authority/service.py',f/'authority.json'],'authority',env)
        self.wait(ready.exists,service,15)
        server=dict(certificate=str(cert),key=str(f/'local-key.pem'),fingerprint=fingerprint,endpoint='https://127.0.0.1:'+str(s['authority_port']),server='local-development',credential=credential,ca=str(cert),port=s['game_port'],bind_ip='127.0.0.1')
        write(f/'server.json',server)
        args=self.game_args()+['--headless','--','--public-server-config='+str(f/'server.json')]
        env=os.environ.copy();env['APPDATA']=str(f/'server-user')
        game=self.spawn(args,'server',env)
        self.wait(lambda:'PUBLIC_SERVER_LISTENING' in (f/'server.log').read_text(errors='replace'),game,15)
        public=dict(login=dict(issuer=s['issuer'],authorization_endpoint=discovery['authorization_endpoint'],token_endpoint=discovery['token_endpoint'],client_id='shipping-native',callback_port=s['callback_port'],ca=str(cert)),authority_endpoint=server['endpoint'],authority_ca=str(cert),servers=[dict(name='Local development server',server=server['server'],host='127.0.0.1',hostname='localhost',port=s['game_port'],certificate=str(cert),fingerprint=fingerprint)])
        write(f/'public-services.json',public)
        write(f/'ready.json',dict(version=1,development_only=True))
        self.refresh_at=time.monotonic()+600
        print('LOCAL_ONLINE_READY',f,flush=True)
    def game_args(self):
        if self.runtime=='release': return [str(ROOT/'exports/windows-x86_64/release/ShippingLanes.exe')]
        return [str(WORKSPACE/'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe'),'--path',str(ROOT)]
    def maintain(self):
        if any(c.poll() is not None and c.returncode != 10 for c in self.children): raise RuntimeError('A local service stopped')
        if time.monotonic()>=self.refresh_at:
            with psycopg.connect(**self.settings['database']) as db:
                db.execute("UPDATE public_authority.servers SET expires=clock_timestamp()+interval '1 hour' WHERE id='local-development'")
            self.refresh_at=time.monotonic()+600
    def close(self):
        # Players must disconnect first; graceful game-server shutdown is a separate tracked task.
        for c in reversed(self.children):
            if c.poll() is None:
                c.terminate()
                try:c.wait(timeout=20)
                except subprocess.TimeoutExpired:c.kill();c.wait()
        for log in self.logs:log.close()
        if self.db_started:
            command([BIN/'pg_ctl.exe','-D',self.folder/'postgres','-m','fast','-w','stop']); self.db_started=False
        if self.lock:
            for name in ['ready.json','authority.json','server.json']:(self.folder/name).unlink(missing_ok=True)
            self.lock.close();self.lock=None

def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['init','run','stop','client']);p.add_argument('--name',default='development');p.add_argument('--runtime',choices=['editor','release'],default='editor');a=p.parse_args()
    if not a.name or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in a.name):p.error('Use a lowercase name with digits/hyphens')
    folder=BASE/a.name
    if a.action=='init':initialize(folder)
    elif a.action=='stop':
        if not (folder/'ready.json').exists():raise RuntimeError('Setup is not ready/running')
        (folder/'stop-request').touch()
    elif a.action=='client':
        if not (folder/'ready.json').exists():raise RuntimeError('Start the services first')
        stack=Stack(folder,a.runtime)
        # Separate app-data profile prevents changes to ordinary local saves/settings.
        appdata=folder/'client-user'; target=appdata/'Godot/app_userdata/Shipping Lanes/public_services.json'
        target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((folder/'public-services.json').read_bytes())
        env=os.environ.copy();env['APPDATA']=str(appdata)
        subprocess.Popen(stack.game_args(),env=env,creationflags=FLAGS)
    else:
        stack=Stack(folder,a.runtime)
        try:
            stack.start();(folder/'stop-request').unlink(missing_ok=True)
            while not (folder/'stop-request').exists():stack.maintain();time.sleep(.5)
        finally:stack.close()

if __name__=='__main__':main()
