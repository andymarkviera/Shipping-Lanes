"""Loopback-only synthetic-account proof. Not an internet service or game save."""
import argparse
import hashlib
import hmac
import json
import os
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import psycopg
from psycopg.types.json import Jsonb

LIMIT = 9_000_000_000_000
FIELDS = {'version', 'realm', 'action_id', 'operation', 'quantity', 'expected_revision'}
PRICES = {'purchase_container': 10000, 'deliver_container': 5000, 'service_fee': 1000}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate_key')
        result[key] = value
    return result


def decode(raw):
    return json.loads(raw.decode('utf-8'), object_pairs_hook=unique_object,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError('nonfinite')))


def validate(data):
    if type(data) is not dict or set(data) != FIELDS:
        return 'bad_request'
    if type(data['version']) is not int or data['version'] != 1:
        return 'bad_request'
    if data['realm'] != 'public_fixture':
        return 'wrong_realm'
    if type(data['action_id']) is not str or not re.fullmatch(r'[a-z][a-z0-9_]{0,63}', data['action_id']):
        return 'bad_request'
    if type(data['operation']) is not str or data['operation'] not in PRICES:
        return 'unsupported_operation'
    for key, minimum in [('quantity', 1), ('expected_revision', 0)]:
        if type(data[key]) is not int or not minimum <= data[key] <= LIMIT:
            return 'bad_request'
    if data['operation'] == 'service_fee' and data['quantity'] != 1:
        return 'bad_request'
    return None


def canonical(data):
    # All accepted strings are ASCII and integers are exact: no float normalization.
    return json.dumps(data, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode('ascii')


class Store:
    def __init__(self, config):
        self.config = config
        self.fault_lock = threading.Lock()

    def fault(self, action_id, stage):
        # Only the local harness configuration can arm a fault; no HTTP fault API.
        if self.config.get('fault') != {'action_id': action_id, 'stage': stage}:
            return
        with self.fault_lock:
            Path(self.config['fault_marker']).write_text(stage, encoding='utf-8')
            os._exit(91)  # abrupt service death, no Python context cleanup

    def execute(self, actor, data):
        invalid = validate(data)
        if invalid:
            return {'ok': False, 'code': invalid}
        realm, action_id = data['realm'], data['action_id']
        fingerprint = hashlib.sha256(canonical(data)).hexdigest()
        with psycopg.connect(**self.config['database'], connect_timeout=3) as conn:
            conn.execute("SET LOCAL lock_timeout = '4s'")
            conn.execute("SET LOCAL statement_timeout = '5s'")
            # Lock affected accounts in stable lexical order BEFORE receipt lookup.
            # Shared game row serializes this deliberately small experiment.
            rows = conn.execute(
                'SELECT actor,money,cargo,revision FROM economy.accounts '
                'WHERE realm=%s AND actor IN (%s,%s) ORDER BY actor FOR UPDATE',
                (realm, actor, 'game')).fetchall()
            states = {row[0]: list(row[1:]) for row in rows}
            if len(states) != 2:
                raise RuntimeError('fixture_account_missing')
            previous = conn.execute(
                'SELECT fingerprint,result FROM economy.receipts '
                'WHERE realm=%s AND actor=%s AND action_id=%s', (realm, actor, action_id)).fetchone()
            if previous:
                if not hmac.compare_digest(previous[0], fingerprint):
                    return {'ok': False, 'code': 'id_conflict'}
                return dict(previous[1], duplicate=True)
            player, game = states[actor], states['game']
            quantity, operation = data['quantity'], data['operation']
            amount = quantity * PRICES[operation]
            debit, credit = (game, player) if operation == 'deliver_container' else (player, game)
            code = 'committed'
            if data['expected_revision'] != player[2]:
                code = 'stale_revision'
            elif amount > LIMIT or player[2] == LIMIT or game[2] == LIMIT:
                code = 'overflow'
            elif debit[0] < amount:
                code = 'insufficient_funds'
            elif credit[0] > LIMIT - amount:
                code = 'overflow'
            elif operation != 'service_fee' and (game if operation == 'purchase_container' else player)[1] < quantity:
                code = 'insufficient_stock'
            elif operation != 'service_fee' and (player if operation == 'purchase_container' else game)[1] > LIMIT - quantity:
                code = 'overflow'
            success = code == 'committed'
            if success:
                debit[0] -= amount
                credit[0] += amount
                if operation != 'service_fee':
                    source, target = (game, player) if operation == 'purchase_container' else (player, game)
                    source[1] -= quantity
                    target[1] += quantity
                for state in (player, game):
                    state[2] += 1
                # Intentional multi-row writes to prove rollback across partial work.
                conn.execute('UPDATE economy.accounts SET money=%s,cargo=%s,revision=%s '
                             'WHERE realm=%s AND actor=%s', (*player, realm, actor))
                self.fault(action_id, 'after_first_write')
                conn.execute('UPDATE economy.accounts SET money=%s,cargo=%s,revision=%s '
                             'WHERE realm=%s AND actor=%s', (*game, realm, 'game'))
            result = {'ok': success, 'code': code, 'action_id': action_id,
                      'revision': player[2], 'amount_minor': amount if success else 0,
                      'quantity': quantity if success else 0, 'duplicate': False}
            conn.execute('INSERT INTO economy.receipts VALUES (%s,%s,%s,%s,%s,%s)',
                         (realm, actor, action_id, fingerprint, Jsonb(data), Jsonb(result)))
            if success:
                payer, payee = ('game', actor) if operation == 'deliver_container' else (actor, 'game')
                conn.execute('INSERT INTO economy.journal VALUES (%s,%s,%s,%s,%s,%s,%s)',
                             (realm, actor, action_id, payer, payee, amount,
                              0 if operation == 'service_fee' else quantity))
            self.fault(action_id, 'before_commit')
        # Context exits with a synchronous durable commit before acknowledging.
        self.fault(action_id, 'after_commit')
        return result


def serve(config):
    if config.get('mode') != 'isolated_synthetic_fixture':
        raise ValueError('explicit_fixture_mode_required')
    if config['database']['host'] != '127.0.0.1' or config['database']['dbname'] != 'storage_proof':
        raise ValueError('isolated_loopback_database_required')
    store = Store(config)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass  # Never log authorization headers or request payloads.

        def do_POST(self):
            try:
                self.connection.settimeout(5)
                token = self.headers.get('Authorization', '')
                actor = next((actor for actor, secret in config['tokens'].items()
                              if hmac.compare_digest(token.encode('utf-8'), ('Bearer ' + secret).encode('utf-8'))), None)
                if actor not in ('alice', 'bob'):
                    return self.reply(401, {'ok': False, 'code': 'unauthorized'})
                if self.path != '/v1/operation':
                    return self.reply(404, {'ok': False, 'code': 'not_found'})
                lengths = self.headers.get_all('Content-Length', [])
                if self.headers.get('Transfer-Encoding') or len(lengths) != 1:
                    return self.reply(400, {'ok': False, 'code': 'bad_length'})
                length = int(lengths[0])
                if not 1 <= length <= 4096:
                    return self.reply(413, {'ok': False, 'code': 'bad_length'})
                data = decode(self.rfile.read(length))
                self.reply(200, store.execute(actor, data))
            except (ValueError, UnicodeError, RecursionError):
                self.reply(400, {'ok': False, 'code': 'bad_request'})
            except psycopg.Error:
                # May have committed if the connection died during COMMIT: retry SAME intent.
                self.reply(503, {'ok': False, 'code': 'outcome_unknown_retry_same_id'})

        def reply(self, status, data):
            payload = json.dumps(data).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    ready = Path(config['ready'])
    temporary = ready.with_suffix('.tmp')
    temporary.write_text(str(server.server_port), encoding='ascii')
    temporary.replace(ready)
    server.serve_forever()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('config', type=Path)
    serve(json.loads(parser.parse_args().config.read_text(encoding='utf-8')))
