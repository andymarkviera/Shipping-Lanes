"""Owned loopback processes only; separate user data, no real save/credentials."""
import argparse, json, os, socket, subprocess, time, uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parent

def run(runtime, heavy):
    folder = WORKSPACE / 'output/identity' / (runtime + '-' + ('heavy-' if heavy else 'starter-') + uuid.uuid4().hex[:8])
    folder.mkdir(parents=True)
    print('Evidence:', folder, flush=True)
    binary = WORKSPACE / 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe' if runtime == 'editor' else ROOT / 'exports/windows-x86_64/release/ShippingLanes.exe'
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    children = {}
    logs = []
    def start(role):
        args = [str(binary), '--headless', '--log-file', str(folder / (role + '.log'))]
        if runtime == 'editor': args += ['--path', str(ROOT)]
        args += ['--', '--identity-check', '--identity-role=' + role, '--identity-folder=' + str(folder), '--identity-port=' + str(port), '--identity-heavy=' + ('yes' if heavy else 'no')]
        env = os.environ.copy()
        env['APPDATA'] = str(folder / 'a' / ('host' if role == 'recovery' else role))
        log = (folder / (role + '.console')).open('wb')
        logs.append(log)
        children[role] = subprocess.Popen(args, env=env, stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
    def marker(name, timeout=15):
        deadline = time.monotonic() + timeout
        while not (folder / name).exists() and time.monotonic() < deadline:
            if children.get('recovery', children['host']).poll() is not None: break
            time.sleep(.05)
        assert (folder / name).exists(), 'Missing ' + name + '; inspect ' + str(folder)
    def finish(role):
        assert children[role].wait(timeout=40) == 0, role + ' failed; inspect ' + str(folder)
        result = json.loads((folder / (role + '.json')).read_text())
        assert result['failures'] == 0
        log = (folder / (role + '.log')).read_text(errors='replace')
        assert 'SCRIPT ERROR:' not in log and '\nERROR:' not in log, role + ' engine error'
        return result['checks']
    try:
        start('host'); marker('invite.json')
        start('first'); marker('armed'); marker('test-credential')
        total = 0
        for role in ['forged', 'wrongworld', 'fresh']:
            start(role); total += finish(role)
        start('replacement')
        for role in ['first', 'replacement', 'host']: total += finish(role)
        start('recovery'); marker('recovery_ready')
        start('returning')
        for role in ['returning', 'recovery']: total += finish(role)
        (folder / 'summary.json').write_text(json.dumps({'passed': True, 'checks': total, 'runtime': runtime, 'heavy': heavy}, indent=2))
        print('IDENTITY_PASS', runtime, 'heavy' if heavy else 'starter', total, flush=True)
    finally:
        for child in children.values():
            if child.poll() is None: child.kill(); child.wait()
        for log in logs: log.close()
        (folder / 'test-credential').unlink(missing_ok=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', choices=['editor', 'release', 'both'], default='editor')
    parser.add_argument('--hull', choices=['starter', 'heavy', 'both'], default='both')
    args = parser.parse_args()
    for runtime in ['editor', 'release'] if args.runtime == 'both' else [args.runtime]:
        for heavy in [False, True] if args.hull == 'both' else [args.hull == 'heavy']:
            run(runtime, heavy)
