"""Run shared-physics fixtures in the editor or the packaged executable."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import uuid

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--runtime', choices=['editor', 'release'], default='editor')
args = parser.parse_args()
folder = root.parent / 'output/shared-physics' / uuid.uuid4().hex[:8]
folder.mkdir(parents=True)
exe = root.parent / 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe' if args.runtime == 'editor' else root / 'exports/windows-x86_64/release/ShippingLanes.exe'
command = [str(exe), '--headless']
if args.runtime == 'editor': command += ['--path', str(root)]
command += ['--', '--public-physics-check']
env = os.environ.copy()
env['APPDATA'] = str(folder / 'user')
result = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30, creationflags=subprocess.CREATE_NO_WINDOW)
output = result.stdout.decode('utf-8', errors='replace')
(folder / 'godot.log').write_text(output, encoding='utf-8')
passed = result.returncode == 0 and 'PUBLIC_PHYSICS_PASS' in output and 'ERROR:' not in output
(folder / 'summary.json').write_text(json.dumps({'runtime': args.runtime, 'passed': passed, 'exit_code': result.returncode}, indent=2))
print(output)
print('Evidence:', folder)
raise SystemExit(0 if passed else 1)
