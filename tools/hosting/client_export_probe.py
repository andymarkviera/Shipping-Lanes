import argparse,json,sys,uuid
from pathlib import Path
SOURCE=Path(__file__).resolve().parents[2];WS=SOURCE.parent
BUNDLE=WS/'output/hosting/ShippingLanes-Windows-Host'
sys.path.insert(0,str(SOURCE/'tools/hosting'))
import host
folder=WS/'output/host-check'/('export-'+uuid.uuid4().hex[:8]);folder.mkdir()
parser=argparse.ArgumentParser();parser.add_argument('--evidence',required=True);args=parser.parse_args()
source=Path(args.evidence).resolve()
host.FOLDER=folder
(folder/'ready.json').write_text('{}')
(folder/'private.json').write_text(json.dumps(dict(hosting=dict(name='Friends',lan_ip='192.168.1.25'),password='MUST_NOT_COPY')))
(folder/'public-services.json').write_bytes((source/'public-services.json').read_bytes())
(folder/'local-cert.pem').write_bytes((source/'local-cert.pem').read_bytes())
client=folder/'Client';host.client_files(client)
lan=json.loads((client/'lan.json').read_text());internet=json.loads((client/'internet.json').read_text())
assert lan['servers'][0]['host']=='192.168.1.25'
assert lan['servers'][0]['server']==internet['servers'][0]['server']
assert lan['login']==internet['login'] and lan['authority_endpoint']==internet['authority_endpoint']
assert lan['servers'][0]['certificate']=='server-certificate.pem' and lan['login']['ca']=='server-certificate.pem'
assert (client/'Game/ShippingLanes.exe').exists()
assert not any(p.name in ('private.json','local-key.pem','login-info.txt') for p in client.rglob('*'))
for p in client.glob('*.json'):assert 'MUST_NOT_COPY' not in p.read_text()
assert not list(client.rglob('*.TMP'))
(folder/'ready.json').unlink()
assert (client/'Game/friends-client.flag').exists()
assert (client/'Launch-Client.ps1').exists() and (client/'Launch-Client.cmd').exists()
print('CLIENT_EXPORT_PASS 10',folder)
