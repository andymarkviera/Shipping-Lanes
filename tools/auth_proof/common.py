import datetime, hashlib, ipaddress, json, os, socket, subprocess, time
from pathlib import Path
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT.parent
PYTHON_FLAGS = subprocess.CREATE_NO_WINDOW

def free_port(udp=False):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM if udp else socket.SOCK_STREAM) as s:
        s.bind(('127.0.0.1',0)); return s.getsockname()[1]

def certificates(folder):
    now=datetime.datetime.now(datetime.timezone.utc)
    def key(): return rsa.generate_private_key(public_exponent=65537,key_size=2048)
    def name(text): return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,text)])
    ca_key=key(); ca_name=name('Shipping Lanes disposable proof CA')
    ca=x509.CertificateBuilder().subject_name(ca_name).issuer_name(ca_name).public_key(ca_key.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=5)).not_valid_after(now+datetime.timedelta(days=2)).add_extension(x509.BasicConstraints(ca=True,path_length=0),critical=True).sign(ca_key,hashes.SHA256())
    server_key=key()
    leaf=x509.CertificateBuilder().subject_name(name('localhost')).issuer_name(ca_name).public_key(server_key.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=5)).not_valid_after(now+datetime.timedelta(days=1)).add_extension(x509.SubjectAlternativeName([x509.DNSName('localhost'),x509.IPAddress(ipaddress.ip_address('127.0.0.1'))]),critical=False).sign(ca_key,hashes.SHA256())
    wrong_key=key(); wrong_name=name('Untrusted test CA')
    wrong=x509.CertificateBuilder().subject_name(wrong_name).issuer_name(wrong_name).public_key(wrong_key.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=5)).not_valid_after(now+datetime.timedelta(days=1)).add_extension(x509.BasicConstraints(ca=True,path_length=0),critical=True).sign(wrong_key,hashes.SHA256())
    for filename,cert in [('ca.pem',ca),('server.pem',leaf),('wrong-ca.pem',wrong)]:
        (folder/filename).write_bytes(cert.public_bytes(serialization.Encoding.PEM))
    (folder/'server-key.pem').write_bytes(server_key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
    return leaf.fingerprint(hashes.SHA256()).hex()

def transport_proof(run, runtime='editor'):
    binary=WORKSPACE/'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe' if runtime=='editor' else ROOT/'exports/windows-x86_64/release/ShippingLanes.exe'
    for mode in ['valid','wrong_name','wrong_ca','plaintext']:
        folder=run/(runtime+'-'+mode);folder.mkdir();certificates(folder);port=free_port(True)
        children=[]; logs=[]
        try:
            for role in ['server','client']:
                args=[str(binary),'--headless','--log-file',str(folder/(role+'.log'))]
                if runtime=='editor':args+=['--path',str(ROOT)]
                args+=['--','--auth-transport-check','--auth-role='+role,'--auth-folder='+str(folder),'--auth-port='+str(port),'--auth-mode='+mode]
                env=os.environ.copy();env['APPDATA']=str(folder/'a')
                log=(folder/(role+'.console')).open('wb');logs.append(log)
                child=subprocess.Popen(args,stdout=log,stderr=log,env=env,creationflags=PYTHON_FLAGS);children.append(child)
                if role=='server':
                    deadline=time.monotonic()+10
                    while not (folder/'ready').exists() and child.poll() is None and time.monotonic()<deadline:time.sleep(.05)
                    assert (folder/'ready').exists(), 'DTLS server did not start'
            for child in children:assert child.wait(timeout=12)==0, 'DTLS case failed: '+mode
            for role in ['server','client']:assert json.loads((folder/(role+'.json')).read_text())['ok']
            print('PASS DTLS',runtime,mode,flush=True)
        finally:
            for child in children:
                if child.poll() is None:child.kill();child.wait()
            for log in logs:log.close()
