"""Isolated voyage restore and real process-death transaction tests."""
import argparse, os, subprocess, uuid, json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--runtime', choices=['editor', 'release'], default='editor')
a = p.parse_args()
folder = root.parent / 'output/voyage' / uuid.uuid4().hex[:8]
folder.mkdir(parents=True)
exe = (root.parent / 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe'
       if a.runtime == 'editor' else root / 'exports/windows-x86_64/release/ShippingLanes.exe')
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = subprocess.SW_HIDE
results = []

def run(mode, realm='crash', killed=False):
    env = os.environ.copy()
    env['APPDATA'] = str(folder / realm)
    args = [str(exe), '--headless']
    if a.runtime == 'editor': args += ['--path', str(root)]
    args += ['--', '--voyage-check', '--voyage-mode=' + mode]
    result = subprocess.run(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=45, creationflags=subprocess.CREATE_NO_WINDOW, startupinfo=startup)
    output = result.stdout.decode('utf-8', errors='replace')
    (folder / (realm + '-' + mode + '.log')).write_text(output, encoding='utf-8')
    passed = (any((folder / realm).rglob('fault_' + mode)) and 'VOYAGE_PASS' not in output and 'ERROR:' not in output if killed else
              result.returncode == 0 and 'VOYAGE_PASS' in output and 'ERROR:' not in output)
    results.append(dict(mode=mode, passed=passed, exit_code=result.returncode))
    print(mode, 'PASS' if passed else 'FAIL', flush=True)
    if not passed: print(output, flush=True)
    return passed

ok = run('suite', 'suite')
if ok:
    ok = run('round_trip', 'round_trip') and run('verify_round_trip', 'round_trip') and run('verify_round_trip', 'round_trip')
if ok:
    for mode in ['seed', 'before_commit', 'verify_partial', 'after_commit', 'verify_loaded', 'delivery_before_commit', 'verify_loaded', 'delivery_after_commit', 'verify_delivered', 'verify_delivered']:
        if not run(mode, killed=mode in ['before_commit', 'after_commit', 'delivery_before_commit', 'delivery_after_commit']):
            ok = False
            break
(folder / 'summary.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
print('Evidence:', folder)
raise SystemExit(0 if ok else 1)
