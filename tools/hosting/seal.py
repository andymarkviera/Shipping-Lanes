"""Seal only the explicit build manifest; generated accounts/data cannot enter ZIP."""
import hashlib,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT.parent/'output/hosting/ShippingLanes-Windows-Host'
manifest=json.loads((OUT/'package-manifest.json').read_text(encoding='utf-8'))
for p in (OUT/'Licenses').iterdir():
    if p.is_file():manifest[p.relative_to(OUT).as_posix()]=''
for name in manifest:
    parts=Path(name).parts
    if any(x in ('local-online','PlayerData','__pycache__') for x in parts) or Path(name).name in ('private.json','local-key.pem','login-info.txt'):
        raise RuntimeError('Private/generated material in manifest')
    path=(OUT/name).resolve()
    assert path.is_relative_to(OUT.resolve()) and path.is_file()
    manifest[name]=hashlib.sha256(path.read_bytes()).hexdigest()
(OUT/'package-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
archive=OUT.with_suffix('.zip')
if archive.exists():raise RuntimeError('Archive already exists; do not silently replace a delivered build')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
    for name in [*manifest,'package-manifest.json']:z.write(OUT/name,OUT.name+'/'+name)
print('ZIP_WRITTEN',archive,flush=True)
with zipfile.ZipFile(archive) as z:
    assert len(z.namelist())==len(manifest)+1
    for name,digest in manifest.items():assert hashlib.sha256(z.read(OUT.name+'/'+name)).hexdigest()==digest,name
sha=hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix('.zip.sha256').write_text(sha+'  '+archive.name+'\n',encoding='utf-8')
print('HOST_ZIP_VERIFIED',len(manifest),'files',round(archive.stat().st_size/1024/1024,1),'MiB',sha,flush=True)
