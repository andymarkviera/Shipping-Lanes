"""Portable isolated bulk recovery checks; kill only owned children at commit markers."""
import argparse
import os
from pathlib import Path
import subprocess
import time
import uuid

p = argparse.ArgumentParser()
p.add_argument('--family', choices=['bulk', 'gas'], default='bulk')
p.add_argument('--godot', required=True)
p.add_argument('--work', required=True, type=Path)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
folder = a.work.resolve() / (a.family + '-' + uuid.uuid4().hex[:10])
folder.mkdir(parents=True)

def run(mode, realm, killed=False):
    env = os.environ.copy()
    for key, suffix in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('APPDATA', 'appdata'), ('XDG_CACHE_HOME', 'cache')]:
        path = folder / realm / suffix
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    log = folder / (mode + '.log')
    with log.open('w') as out:
        child = subprocess.Popen([a.godot, '--headless', '--path', str(root), '--script',
                                  'tools/bulk_service_probe.gd', '--', '--bulk-mode=' + mode, '--cargo-family=' + a.family],
                                 env=env, stdout=out, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 45
            marker = False
            while child.poll() is None and time.monotonic() < deadline:
                text = log.read_text(errors='replace')
                if killed and 'BULK_KILL_READY' in text:
                    marker = True
                    child.kill()
                    break
                time.sleep(.05)
            if child.poll() is None and not marker:
                child.kill()
                raise RuntimeError(f'{mode} timed out: {log}')
            code = child.wait(timeout=5)
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()
    text = log.read_text(errors='replace')
    passed = ('ERROR:' not in text and 'failures=0' in text and code == 0) if not killed else marker and 'ERROR:' not in text
    print(mode, 'PASS' if passed else 'FAIL', flush=True)
    if not passed:
        raise RuntimeError(text)

run('suite', 'suite')
run('scene', 'scene')
for mode in ['seed', 'load_before', 'verify_pending', 'load_after', 'verify_loaded',
             'prepare_partial', 'unload_before', 'verify_unpaid', 'unload_after',
             'verify_partial', 'finish', 'verify_final']:
    run(mode, 'crash', mode in {'load_before', 'load_after', 'unload_before', 'unload_after'})
run('verify_final', 'crash')
print('Evidence:', folder)
