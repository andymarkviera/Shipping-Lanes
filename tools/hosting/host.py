"""Portable invited-player Windows host; uses the same game runtime for LAN/internet."""
import argparse, ipaddress, json, os, re, shutil, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/public_handoff'))
from local_online import BASE, Stack, initialize, read, write
FOLDER=BASE/'hosted'

def validate(config):
    if set(config)!={'host','name','bind_ip','https_port','game_port','lan_ip'}: raise ValueError('Unexpected or missing host settings')
    host=config['host']
    if not isinstance(host,str) or not re.fullmatch(r'[A-Za-z0-9.-]{1,253}',host) or 'CHANGE-ME' in host: raise ValueError('Set host to the actual stable IP or DNS name first')
    if not isinstance(config['name'],str) or not 1<=len(config['name'])<=80: raise ValueError('Invalid display name')
    ipaddress.IPv4Address(config['bind_ip'])
    if config['lan_ip']: ipaddress.IPv4Address(config['lan_ip'])
    for key in ('https_port','game_port'):
        if type(config[key]) is not int or not 1024<=config[key]<=65535: raise ValueError('Use ports 1024 through 65535')
    return config

def client_files(output=None):
    if not (FOLDER/'ready.json').exists(): raise RuntimeError('Start the host before generating client files')
    output=output or ROOT.parent/'Client'; output.mkdir(exist_ok=True)
    config=read(FOLDER/'public-services.json'); settings=read(FOLDER/'private.json')['hosting']
    # Explicit public allowlist: private settings, credentials and keys never copied.
    shutil.copy2(FOLDER/'local-cert.pem',output/'server-certificate.pem')
    config['login']['ca']='server-certificate.pem';config['authority_ca']='server-certificate.pem'
    config['servers'][0]['certificate']='server-certificate.pem'
    config['servers'][0]['name']=settings['name']+' (Internet / DNS)'
    if settings['lan_ip']:
        local=dict(config['servers'][0],name=settings['name']+' (Home / LAN)',host=settings['lan_ip'],server='local-development')
        # Entry IDs must be unique in the existing picker. Separate configs preserve the same server/account identity.
        lan=dict(config,servers=[local]);write(output/'lan.json',lan)
    write(output/'internet.json',config)
    runtime=ROOT/'exports/windows-x86_64/release'
    target=output/'Game'
    shutil.copytree(runtime,target,dirs_exist_ok=True)
    licenses=ROOT.parent/'Licenses'
    if licenses.exists():shutil.copytree(licenses,output/'Licenses',dirs_exist_ok=True)
    print('CLIENT_FILES_READY',output,flush=True)

def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['setup','run','stop','clients','check']);p.add_argument('--config',default=str(ROOT.parent/'host-settings.json'));a=p.parse_args()
    if a.action=='check':
        import cryptography,psycopg
        assert (ROOT/'exports/windows-x86_64/release/ShippingLanes.exe').is_file()
        print('HOST_RUNTIME_CHECK_PASS');return
    if a.action=='setup':initialize(FOLDER,validate(read(Path(a.config))));return
    if a.action=='clients':client_files();return
    if a.action=='stop':
        if not (FOLDER/'ready.json').exists():raise RuntimeError('Host is not ready/running')
        (FOLDER/'stop-request').touch()
        deadline=time.monotonic()+60
        while (FOLDER/'ready.json').exists() and time.monotonic()<deadline:time.sleep(.25)
        if (FOLDER/'ready.json').exists():raise RuntimeError('Stop not confirmed; inspect logs before restarting')
        print('HOST_STOP_CONFIRMED');return
    stack=Stack(FOLDER,'release')
    try:
        stack.start();(FOLDER/'stop-request').unlink(missing_ok=True);client_files()
        print('HOST_READY - invited-player preview; see hosting guide before internet access',flush=True)
        while not (FOLDER/'stop-request').exists():stack.maintain();time.sleep(.5)
    finally:stack.close()

if __name__=='__main__':main()
