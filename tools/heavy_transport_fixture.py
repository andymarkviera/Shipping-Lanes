"""Owned local Godot host + private SQLite. Never accept remote player evidence."""
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
from services.heavy_load.private import HeavyStore, LIFTER, TERMS, validate_navigation

REALM = 'private:heavy-transport'
ACCOUNT = 'heavy-fixture-captain'
SHIP = 'heavy-fixture-ship'


def dispatch(store, payload):
    request = payload['request']
    op = request.get('op')
    if op == 'snapshot':
        result = store.snapshot(ACCOUNT)
        validate_navigation(result['navigation'])
        return dict(result, ok=True)
    if op == 'checkpoint':
        return store.checkpoint(ACCOUNT, request['revision'], payload['navigation'])
    # This authenticated channel belongs to the spawned host simulation. It is
    # not a client RPC: the Godot guard has already checked space and alignment.
    evidence = None
    if op in ('pickup', 'deliver', 'destroy'):
        evidence = dict(job_id=request['job_id'], ship_id=SHIP,
                        payload_id=TERMS['payload_id'], validated=True,
                        zone_id='destroyed' if op == 'destroy' else TERMS['pickup_zone' if op == 'pickup' else 'delivery_zone'])
    return store.heavy(ACCOUNT, request, evidence=evidence, navigation=payload['navigation'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--db', type=Path, required=True)
    parser.add_argument('--create', action='store_true')
    parser.add_argument('--probe', choices=['carry', 'deliver', 'verify', 'destroy', 'failed'])
    args = parser.parse_args()
    store = HeavyStore(args.db, REALM)
    if args.create:
        store.initialize()
        store.provision(ACCOUNT, dict(ship=dict(id=SHIP, definition=LIFTER, condition_bp=10000),
            cargo=[], jobs=[], delivered=[], heavy_navigation=dict(position=[-950, 0, -792],
            yaw=0, deck_height=2.6, deck_target=2.6, fuel_liters=2000, condition_bp=10000, attached=False)), 1000)
    validate_navigation(store.snapshot(ACCOUNT)['navigation'])
    token = secrets.token_hex(32)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_): pass
        def do_POST(self):
            if self.path != '/heavy' or self.headers.get('Authorization') != 'Bearer ' + token:
                self.send_error(403)
                return
            try:
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= 8192: raise ValueError('size')
                result = dispatch(store, json.loads(self.rfile.read(size)))
            except Exception:
                result = dict(ok=False, code='HEAVY_UNAVAILABLE', uncertain=True)
            data = json.dumps(result).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    server = HTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    env = dict(os.environ, SHIPPING_HEAVY_URL=f'http://127.0.0.1:{server.server_port}/heavy',
               SHIPPING_HEAVY_TOKEN=token, SHIPPING_HEAVY_PROBE=args.probe or '')
    scene = 'tools/heavy_transport_probe.tscn' if args.probe else 'features/handling/heavy_transport_test.tscn'
    command = [args.godot, '--path', str(ROOT), scene]
    if args.probe: command.insert(1, '--headless')
    try: return subprocess.call(command, env=env)
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == '__main__': sys.exit(main())
