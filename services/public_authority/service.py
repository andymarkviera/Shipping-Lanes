"""Isolated HTTPS authority adapter. No account creation/private import routes."""
import json
import os
import ssl
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import psycopg
from authority import Authority, Rejected
from identity import validate
from cryptography.exceptions import InvalidSignature

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError('duplicate field')
        result[key] = value
    return result

def main(config_path):
    config = json.loads(Path(config_path).read_text())
    def fault(stage, request):
        if config.get('fault') == {'stage': stage, 'action_id': request.get('action_id', request.get('transfer_id'))}:
            Path(config['fault_marker']).write_text(stage)
            os._exit(91) # Only operator-owned fixture configuration can arm this.
    authority = Authority(config['database'], fault)
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args): pass
        def do_POST(self):
            self.connection.settimeout(8)
            code, result = 200, {'ok': False, 'code': 'BAD_REQUEST'}
            try:
                if self.path not in ('/v1/authority', '/v1/ticket'): raise ValueError('route')
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= 16384: raise ValueError('size')
                request = json.loads(self.rfile.read(size), object_pairs_hook=unique_object,
                                     parse_constant=lambda _: (_ for _ in ()).throw(ValueError('nonfinite')))
                authorization = self.headers.get('Authorization', '')
                if not authorization.startswith('Bearer '): raise ValueError('authorization')
                credential = authorization[7:]
                if self.path == '/v1/ticket':
                    if not config.get('identity'): raise ValueError('identity unavailable')
                    try:
                        claims = validate(credential, config['identity'])
                    except (ValueError, TypeError, KeyError, InvalidSignature):
                        raise Rejected('INVALID_IDENTITY') from None
                    result = authority.identity_ticket(claims, request)
                else:
                    server = self.headers.get('X-Server-Id', '')
                    if len(server) > 128 or len(credential) > 256: raise ValueError('headers')
                    result = authority.execute(server, credential, request)
            except Rejected as error:
                code, result = 403, {'ok': False, 'code': str(error)}
            except (ValueError, TypeError):
                code = 400
            except psycopg.Error:
                code, result = 503, {'ok': False, 'code': 'BACKEND_UNAVAILABLE'}
            payload = json.dumps(result, allow_nan=False).encode()
            self.send_response(code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            try: self.wfile.write(payload)
            except (BrokenPipeError, ConnectionResetError, ssl.SSLError): pass
    http = ThreadingHTTPServer(('127.0.0.1', int(config['port'])), Handler)
    http.daemon_threads = True
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(config['certificate'], config['key'])
    http.socket = context.wrap_socket(http.socket, server_side=True)
    Path(config['ready']).write_text(str(http.server_port))
    http.serve_forever()

if __name__ == '__main__': main(sys.argv[1])
