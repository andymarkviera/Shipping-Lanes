"""Portable isolated oil inventory recovery checks; kill only owned children at commit markers."""
import argparse
import os
from pathlib import Path
import subprocess
import time
import uuid

p = argparse.ArgumentParser()
p.add_argument('--godot', required=True)
p.add_argument('--work', required=True, type=Path)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
folder = a.work.resolve() / ('oil-' + uuid.uuid4().hex[:10])
folder.mkdir(parents=True)

sequence = 0

def run(mode, realm, killed=False):
    global sequence
    sequence += 1
    env = os.environ.copy()
    for key, suffix in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('APPDATA', 'appdata'), ('XDG_CACHE_HOME', 'cache')]:
        path = folder / realm / suffix
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    log = folder / (f'{sequence:02d}-' + mode + '.log')
    with log.open('w') as out:
        child = subprocess.Popen([a.godot, '--headless', '--path', str(root), '--script',
                                  'tools/liquid_inventory_probe.gd', '--', '--oil-mode=' + mode],
                                 env=env, stdout=out, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 45
            marker = False
            while child.poll() is None and time.monotonic() < deadline:
                text = log.read_text(errors='replace')
                if killed and 'OIL_KILL_READY' in text:
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
for mode in ['seed', 'buy_before', 'verify_empty', 'buy_after', 'verify_loaded',
             'sell_before', 'verify_loaded', 'sell_after', 'verify_partial',
             'finish', 'verify_final', 'verify_final']:
    run(mode, 'crash', mode in {'buy_before', 'buy_after', 'sell_before', 'sell_after'})
print('Evidence:', folder)
