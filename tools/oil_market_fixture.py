"""Developer-only local host for the oil sailing interface; never a public fallback.

Explicit --create provisions a NEW isolated file. Existing files are never reset.
Only the owned Godot child receives the ephemeral loopback bearer credential.
"""
import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from services.oil_market.private import PrivateStore

REALM = 'private:oil-interface'
ACCOUNT = 'oil-fixture-captain'


def dispatch(store, payload):
    """Caller is the trusted private scene, not remote player input."""
    if type(payload) is not dict or set(payload) != {'request', 'context'}:
        return dict(ok=False, code='BAD_REQUEST')
    request, context = payload['request'], payload['context']
    if type(request) is not dict or type(context) is not dict:
        return dict(ok=False, code='BAD_REQUEST')
    data = dict(request, realm=REALM, account=ACCOUNT, epoch=1, generation=1)
    if request.get('op') in ('oil_quote', 'oil_accept'):
        # A recovery retry may read an existing receipt after berth loss. New
        # settlement always requires the authoritative local scene's dock state.
        replay = False
        if request['op'] == 'oil_accept':
            with store.connect() as db:
                replay = db.execute('SELECT 1 FROM receipts WHERE account=? AND action_id=?',
                                    (ACCOUNT, request.get('action_id'))).fetchone() is not None
        if not replay and (context.get('docked') is not True or
                           context.get('port_id') != request.get('port_id')):
            return dict(ok=False, code='DOCK_REQUIRED')
    return store.execute(ACCOUNT, data)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--db', type=Path, required=True)
    p.add_argument('--create', action='store_true')
    p.add_argument('--probe', action='store_true', help='Run the real scene headlessly through its UI callbacks')
    args = p.parse_args()
    store = PrivateStore(args.db, REALM)
    if args.create:
        store.initialize()
        store.provision(ACCOUNT, dict(ship=dict(id='oil-ship', definition='ship_oil_prototype_01',
                                              condition_bp=10000), cargo=[], jobs=[], delivered=[]), 20000)
    # Fail before launch if unavailable; never initialize on a failed open.
    with store.connect() as db:
        if not db.execute('SELECT 1 FROM profiles WHERE account=?', (ACCOUNT,)).fetchone():
            raise RuntimeError('Oil fixture account missing; preserve the file')
    token = secrets.token_hex(32)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            if self.path != '/oil' or self.headers.get('Authorization') != 'Bearer ' + token:
                self.send_error(403)
                return
            try:
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= 8192:
                    raise ValueError('request size')
                result = dispatch(store, json.loads(self.rfile.read(size)))
                status = 200
            except Exception:
                result = dict(ok=False, code='MARKET_UNAVAILABLE', uncertain=True)
                status = 503
            body = json.dumps(result).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = HTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    env = dict(os.environ, SHIPPING_OIL_FIXTURE_URL=f'http://127.0.0.1:{server.server_port}/oil',
               SHIPPING_OIL_FIXTURE_TOKEN=token)
    scene = 'tools/oil_interface_probe.tscn' if args.probe else 'features/ports/oil_port_test.tscn'
    command = [args.godot, '--path', str(ROOT), scene]
    if args.probe:
        command.insert(1, '--headless')
    try:
        return subprocess.call(command, env=env)
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == '__main__':
    sys.exit(main())
