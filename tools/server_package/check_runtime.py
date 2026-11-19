"""Real dedicated heartbeat, player count and graceful checkpoint in temp folders.

python tools/server_package/check_runtime.py --godot /path/to/Godot-4.7.2
"""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def wait_for(predicate, processes, timeout=45):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        if any(p.poll() is not None for p in processes):
            raise RuntimeError('Process exited before expected status')
        time.sleep(.1)
    raise TimeoutError('Expected launcher status/checkpoint not received')


def read(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    if not subprocess.check_output([args.godot, '--version'], text=True).startswith('4.7.2.'):
        parser.error('Godot 4.7.2 required')
    with tempfile.TemporaryDirectory(prefix='shipping-launcher-runtime-') as temporary:
        root = Path(temporary)
        processes, logs = [], []
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]

        def start(name, arguments):
            log = (root / (name + '.log')).open('w+')
            logs.append(log)
            env = dict(os.environ, APPDATA=str(root / name), XDG_DATA_HOME=str(root / name),
                       XDG_CONFIG_HOME=str(root / name / 'config'), XDG_CACHE_HOME=str(root / name / 'cache'))
            process = subprocess.Popen([args.godot, '--headless', '--path', str(ROOT), '--',
                                        f'--port={port}', *arguments], env=env, stdout=log, stderr=subprocess.STDOUT)
            processes.append(process)
            return process

        try:
            for round_number in range(2):
                control = root / f'control-{round_number}'
                control.mkdir()
                server = start(f'server-{round_number}', ['--server', f'--saves-dir={root / "saves"}', f'--control-dir={control}'])
                status_path = control / 'status.json'
                status = wait_for(lambda: read(status_path), [server])
                assert status['listening'] and status['pid'] == server.pid and status['players'] == 0
                assert status['version'] == '3.0.1' and not status['save_failed']
                if round_number == 0:
                    client = start('client', ['--connect', '--captain=LauncherCheck'])
                    wait_for(lambda: read(status_path).get('players') == 1, [server, client])
                (control / 'stop.request').write_text('stop')
                assert server.wait(timeout=45) == 0
                receipt = read(control / 'stopped.json')
                assert receipt == {'pid': server.pid, 'saved': True}
                assert not (root / 'saves.lock').exists()
                assert (root / 'saves/world.json').is_file()
                if round_number == 0:
                    saved = (root / 'saves/world.json').read_bytes()
                    client.terminate()
                    client.wait(timeout=10)
                else:
                    # Opening/closing the stored world without a captain changes
                    # neither identity nor voyage. No resets on restart.
                    assert (root / 'saves/world.json').read_bytes() == saved
            for log in logs:
                log.seek(0)
                output = log.read()
                assert 'SCRIPT ERROR' not in output and 'ERROR:' not in output, output
            print('SERVER_LAUNCHER_RUNTIME_PASS heartbeat/players/2 graceful checkpoints/save restart')
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            for log in logs:
                log.seek(0)
                if any(p.returncode not in (None, 0, -15) for p in processes):
                    print(log.read())
                log.close()


if __name__ == '__main__':
    main()
