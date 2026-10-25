"""Loaded steering/save regression, optionally using a read-only extracted checkpoint."""
import argparse, os, subprocess, uuid
from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--runtime', choices=['editor', 'release'], default='editor')
p.add_argument('--checkpoint', type=Path)
a = p.parse_args()
folder = root.parent / 'output/sailing-save' / uuid.uuid4().hex[:8]
folder.mkdir(parents=True)
exe = (root.parent / 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe'
       if a.runtime == 'editor' else root / 'exports/windows-x86_64/release/ShippingLanes.exe')
args = [str(exe), '--headless']
if a.runtime == 'editor': args += ['--path', str(root)]
args += ['--', '--sailing-save-check']
if a.checkpoint: args += ['--checkpoint=' + str(a.checkpoint.resolve())]
env = os.environ.copy()
env['APPDATA'] = str(folder / 'user')
result = subprocess.run(args, env=env, capture_output=True, timeout=45, creationflags=subprocess.CREATE_NO_WINDOW)
output = (result.stdout + result.stderr).decode('utf-8', errors='replace')
(folder / 'godot.log').write_text(output, encoding='utf-8')
print(output)
print('Evidence:', folder)
raise SystemExit(0 if result.returncode == 0 and 'SAILING_SAVE_PASS' in output and 'ERROR:' not in output else 1)
