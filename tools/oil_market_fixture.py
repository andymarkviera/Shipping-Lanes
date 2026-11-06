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
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from services.oil_market.private import PrivateStore
from services.refinery.processing import RefineryStore, Config

REALM = 'private:oil-interface'
ACCOUNT = 'oil-fixture-captain'


def dispatch(store, payload):
    """Caller is the trusted private scene, not remote player input."""
    if type(payload) is not dict or set(payload) != {'request', 'context'}:
        return dict(ok=False, code='BAD_REQUEST')
    request, context = payload['request'], payload['context']
    if type(request) is not dict or type(context) is not dict:
        return dict(ok=False, code='BAD_REQUEST')
    if request.get('op') in ('refinery_snapshot', 'refinery_submit'):
        if not isinstance(store, RefineryStore): return dict(ok=False, code='REFINERY_UNAVAILABLE')
        return store.refinery(ACCOUNT, request, docked=context.get('docked') is True,
                              port_id=context.get('port_id', ''))
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
    p.add_argument('--refinery', action='store_true', help='Enable Step 77 in a new refinery-capable fixture or reopen one')
    p.add_argument('--refinery-config', type=Path, help='Operator JSON Config, only with --create --refinery')
    p.add_argument('--refinery-probe', action='store_true')
    args = p.parse_args()
    if args.refinery_probe and not args.refinery: p.error('--refinery-probe needs --refinery')
    if args.refinery_config and not (args.create and args.refinery): p.error('Config is frozen at creation')
    config = Config(**json.loads(args.refinery_config.read_text())) if args.refinery_config else Config()
    store = (RefineryStore if args.refinery else PrivateStore)(args.db, REALM)
    if args.create:
        store.initialize(config) if args.refinery else store.initialize()
        store.provision(ACCOUNT, dict(ship=dict(id='oil-ship', definition='ship_oil_prototype_01',
                                              condition_bp=10000), cargo=[], jobs=[], delivered=[]), 20000)
    # Fail before launch if unavailable; never initialize on a failed open.
    with store.connect() as db:
        if not db.execute('SELECT 1 FROM profiles WHERE account=?', (ACCOUNT,)).fetchone():
            raise RuntimeError('Oil fixture account missing; preserve the file')
        if args.refinery: store.read(db)
    token = secrets.token_hex(32)
    stop_clock = threading.Event()
    clock_failed = threading.Event()

    def process_clock():
        last = time.monotonic_ns()
        while not stop_clock.wait(0.1):
            now = time.monotonic_ns()
            elapsed = (now - last) // 1_000_000
            last += elapsed * 1_000_000
            try:
                store.advance(min(elapsed, 1000))
            except Exception:
                # Unknown COMMIT outcome: fence this runtime, reopen durable state.
                clock_failed.set()
                return

    worker = threading.Thread(target=process_clock, daemon=True) if args.refinery else None
    if worker: worker.start()

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
                if clock_failed.is_set(): raise RuntimeError('Refinery clock fenced; reopen storage')
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
               SHIPPING_OIL_FIXTURE_TOKEN=token, SHIPPING_REFINERY_FIXTURE='1' if args.refinery else '0')
    scene = 'tools/oil_interface_probe.tscn' if args.probe else 'features/ports/oil_port_test.tscn'
    if args.refinery_probe: scene = 'tools/refinery_probe.tscn'
    command = [args.godot, '--path', str(ROOT), scene]
    if args.probe or args.refinery_probe:
        command.insert(1, '--headless')
    try:
        return subprocess.call(command, env=env)
    finally:
        stop_clock.set()
        if worker: worker.join()
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == '__main__':
    sys.exit(main())
