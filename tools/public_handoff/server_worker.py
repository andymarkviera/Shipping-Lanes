"""Headless server-adapter fixture, not a playable Godot dedicated server.

Its stdin is an operator-owned test control channel. It has only a scoped server
credential and public TLS trust material; no database credentials or user saves.
"""
import http.client
import json
from pathlib import Path
import ssl
import sys
import time

config = json.loads(Path(sys.argv[1]).read_text())
context = ssl.create_default_context(cafile=config['ca'])
active = False
deadline = 0.0
binding = None
for line in sys.stdin:
    request = json.loads(line)
    active = active and time.monotonic() < deadline
    if request.get('op') == 'local_status':
        result = {'active': active, 'binding': binding}
    elif request.get('op') not in ('admit', 'claim') and (binding is None or time.monotonic() >= deadline or any(request.get(k) != binding[k] for k in ['account', 'epoch', 'generation']) or (request['op'] in ('purchase', 'deliver', 'checkpoint', 'begin') and not active)):
        result = {'ok': False, 'code': 'LOCAL_QUIESCED'}
    else:
        start = time.monotonic()
        if request['op'] in ('begin', 'seal', 'release'): active = False
        client = http.client.HTTPSConnection('127.0.0.1', config['port'], context=context, timeout=6)
        try:
            client.request('POST', '/v1/authority', json.dumps(request), {'X-Server-Id': config['server'],
                           'Authorization': 'Bearer ' + config['credential'], 'Content-Type': 'application/json'})
            response = client.getresponse()
            result = json.loads(response.read())
            if result.get('ok') and request['op'] in ('admit', 'claim'):
                binding = {k: result[k] for k in ['account', 'epoch', 'generation']}
                deadline = start + result['lease_ms']/1000.0 - .5
                active = time.monotonic() < deadline
            elif result.get('ok') and request['op'] == 'renew':
                deadline = start + result['lease_ms']/1000.0 - .5
            elif result.get('ok') and request['op'] == 'cancel':
                active = time.monotonic() < deadline
            if response.status != 200 or result.get('code') in ('STALE_AUTHORITY', 'UNTRUSTED_SERVER', 'BACKEND_UNAVAILABLE', 'STALE_OUTCOME'):
                active = False
        except (OSError, http.client.HTTPException, ValueError):
            active = False
            result = {'ok': False, 'code': 'OUTCOME_UNKNOWN'}
        finally: client.close()
    print(json.dumps(result), flush=True)
