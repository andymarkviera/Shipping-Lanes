"""Build a relocatable Windows preview using explicit runtime/source allowlists."""
import hashlib,json,shutil,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];WS=ROOT.parent
OUT=WS/'output/hosting/ShippingLanes-Windows-Host'
if OUT.exists():raise SystemExit('Output already exists; choose/archive it explicitly instead of overwriting')
OUT.mkdir(parents=True)
def copy(source,target):
    if source.is_dir():shutil.copytree(source,target,ignore=shutil.ignore_patterns('__pycache__','*.pyc','.git','*.TMP'))
    else:target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
project=OUT/'ShippingLanes'
copy(ROOT/'exports/windows-x86_64/release',project/'exports/windows-x86_64/release')
copy(ROOT/'services/public_authority',project/'services/public_authority')
copy(ROOT/'tools/auth_proof',project/'tools/auth_proof')
copy(ROOT/'tools/public_handoff/local_online.py',project/'tools/public_handoff/local_online.py')
for name in ['host.py','gateway.py']:copy(ROOT/'tools/hosting'/name,project/'tools/hosting'/name)
copy(ROOT/'tools/hosting/Host.ps1',OUT/'Host.ps1')
copy(ROOT/'tools/hosting/Launch-Client.ps1',OUT/'Client/Launch-Client.ps1')
for name in ['README-WINDOWS-HOST.md','CHATGPT-SERVER-HANDOFF.md']:copy(ROOT/'tools/hosting'/name,OUT/name)
(OUT/'host-settings.json').write_text(json.dumps(dict(host='CHANGE-ME.duckdns.org',name='Shipping Lanes - Friends',bind_ip='0.0.0.0',https_port=8443,game_port=24560,lan_ip=''),indent=2),encoding='utf-8')
# Pristine dependency distributions only; never copy output/local-online or user data.
for name in ['public-storage-python','auth/java']:
    copy(WS/'output/tools'/name,OUT/'output/tools'/name)
for part in ['bin','lib','share']:
    copy(WS/'output/tools/postgresql-17.11/pgsql'/part,OUT/'output/tools/postgresql-17.11/pgsql'/part)
copy(WS/'output/tools/auth/keycloak/distribution.zip',OUT/'output/tools/auth/keycloak/distribution.zip')
py=Path(sys.executable).parent;target=OUT/'Runtime/python'
for name in ['python.exe','pythonw.exe','python3.dll','python312.dll','vcruntime140.dll','vcruntime140_1.dll','LICENSE.txt','DLLs']:copy(py/name,target/name)
shutil.copytree(py/'Lib',target/'Lib',ignore=shutil.ignore_patterns('site-packages','__pycache__','*.pyc','test','tests','idlelib','tkinter','turtledemo'))
site=py/'Lib/site-packages';bundled=target/'Lib/site-packages';bundled.mkdir()
for item in site.iterdir():
    if item.name.startswith(('cryptography','cffi-','cffi.','_cffi_backend','pycparser')) or item.name=='cffi':copy(item,bundled/item.name)
copy(WS/'output/hosting/godot-licenses.json',OUT/'Licenses/Godot.json')
copy(ROOT/'addons/godot-sqlite/LICENSE.md',OUT/'Licenses/godot-sqlite-LICENSE.md')
copy(ROOT/'addons/godot-sqlite/GODOT_CPP_LICENSE.md',OUT/'Licenses/GODOT_CPP_LICENSE.md')
for name in ['commandlinetools_3rd_party_licenses.txt','server_license.txt']:
    copy(WS/'output/tools/postgresql-17.11/pgsql'/name,OUT/'Licenses'/name)
rows={str(p.relative_to(OUT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.rglob('*') if p.is_file()}
(OUT/'package-manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print('PACKAGE_BUILT',OUT,len(rows),flush=True)
