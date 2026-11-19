"""Patch 3.0 item 3: isolated HTTP/ENet loopback; no live feed or player saves."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    if not subprocess.check_output([args.godot, '--version'], text=True).startswith('4.7.2.'):
        raise SystemExit('Godot 4.7.2 required')
    root = Path(__file__).resolve().parents[1]
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            data = {'host': 'localhost', 'port': port}
            code = 200
            if self.path == '/updating':
                data = {'status': 'updating'}
            elif self.path == '/mismatch':
                data['version'] = 'older-release'
            elif self.path == '/missing':
                code = 404
            body = b'invalid JSON' if self.path == '/malformed' else json.dumps(data).encode()
            self.send_response(code)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_args):
            pass

    http = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=http.serve_forever, daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix='shipping-play-') as temporary:
            folder = Path(temporary)
            env = dict(os.environ, APPDATA=str(folder / 'data'), XDG_DATA_HOME=str(folder / 'data'),
                       XDG_CONFIG_HOME=str(folder / 'config'), XDG_CACHE_HOME=str(folder / 'cache'))
            command = [args.godot, '--headless', '--path', str(root)]
            def check(mode):
                with (folder / f'{mode}.log').open('w+') as output:
                    result = subprocess.run(command + ['--script', 'res://tools/play_connection_check.gd', '--',
                        f'--case={mode}', f'--feed=http://127.0.0.1:{http.server_port}/{mode}',
                        f'--port={port}'], env=env, stdout=output, stderr=subprocess.STDOUT, timeout=40)
                    output.seek(0)
                    text = output.read()
                print(mode, text, flush=True)
                if result.returncode or 'PLAY_CONNECTION_PASS' not in text or 'SCRIPT ERROR' in text or 'ERROR:' in text:
                    raise RuntimeError(f'{mode} failed')
            for updating in (False, True):
                with (folder / 'server.log').open('w+') as log:
                    server = subprocess.Popen(command + ['--', '--server', f'--port={port}', f'--saves-dir={folder / ("updating-saves" if updating else "online-saves")}'] + (['--updating'] if updating else []), env=env, stdout=log, stderr=subprocess.STDOUT)
                    try:
                        deadline = time.monotonic() + 30
                        while time.monotonic() < deadline:
                            log.seek(0)
                            if 'DEDICATED_SERVER_READY' in log.read():
                                break
                            if server.poll() is not None:
                                raise RuntimeError('server startup failed')
                            time.sleep(.1)
                        else:
                            raise RuntimeError('server startup timeout')
                        for mode in (['handshake_updating'] if updating else ['success', 'handshake_mismatch', 'updating', 'mismatch', 'missing', 'malformed']):
                            check(mode)
                    finally:
                        server.terminate()
                        server.wait(timeout=10)
            check('offline')
            if list(folder.rglob('*.db')) or list(folder.rglob('*.sqlite*')):
                raise RuntimeError('Play created local save data')
            print('PLAY_LOOPBACK_PASS; no local databases')
    finally:
        http.shutdown()
        http.server_close()


if __name__ == '__main__':
    main()
