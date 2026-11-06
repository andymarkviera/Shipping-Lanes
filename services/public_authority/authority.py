"""PostgreSQL owns public profiles, fenced leases, receipts and handoff state.

The administration methods are fixture/operator-only, never HTTP routes. Public
OIDC token-to-account admission is a separate integration boundary.
"""
import hashlib
import hmac
import json
import math
import re
import secrets
import uuid
import voyages
import refueling
import repairs
import ship_purchase
import resale
import voyage_accounting
import fleet
import recovery
import wear
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from services.oil_market import settlement as oil, postgres as oil_postgres
from services.oil_market.model import MarketError

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

LEASE_SECONDS = 30
TRANSFER_SECONDS = 30
PROTOCOL = 7
MAX_INTEGER = 9_000_000_000_000

def digest(value):
    return hashlib.sha256(value.encode('utf-8')).hexdigest()

def canonical(data):
    return json.dumps(data, sort_keys=True, separators=(',', ':'), allow_nan=False)

class Rejected(Exception):
    pass

def require(ok, code):
    if not ok: raise Rejected(code)

class Authority:
    def __init__(self, database, fault=None):
        self.database = database
        self.fault = fault or (lambda stage, data: None)

    def connect(self):
        return psycopg.connect(**self.database, row_factory=dict_row, connect_timeout=3)

    def initialize(self):
        with self.connect() as db:
            present = db.execute("SELECT to_regclass('public_authority.version') AS name").fetchone()['name']
            if present:
                require(db.execute('SELECT version FROM public_authority.version').fetchall() == [{'version': 1}], 'SCHEMA_VERSION')
            else:
                db.execute((Path(__file__).parent / 'schema.sql').read_text(encoding='utf-8'))
            oil_postgres.initialize(db, int(self._now(db).timestamp()))

    def register_server(self, server, fingerprint):
        credential = secrets.token_urlsafe(32)
        with self.connect() as db:
            db.execute("INSERT INTO public_authority.servers VALUES(%s,%s,%s,true,clock_timestamp()+interval '1 hour')", (server, digest(credential), fingerprint))
        return credential

    def create_fixture_account(self, issuer, subject):
        account = str(uuid.uuid4())
        ship = str(uuid.uuid4())
        profile = {'version': 1, 'ship': {'id': ship, 'definition': 'ship_starter_container_01', 'fuel_liters': 800.0,
                   'position': {'latitude': 0.0, 'longitude': 0.0, 'heading': 0.0}}, 'cargo': [],
                   'jobs': [{'id': str(uuid.uuid4()), 'state': 'active', 'kind': 'fixture_delivery'}], 'delivered': []}
        with self.connect() as db:
            db.execute('INSERT INTO public_authority.profiles VALUES(%s,%s,%s,20000,0,%s)', (account, issuer, subject, Jsonb(profile)))
            db.execute("INSERT INTO public_authority.leases(account,phase) VALUES(%s,'VACANT')", (account,))
        return account

    def issue_ticket(self, account, server, nonce):
        # Only a trusted identity boundary may call this; no arbitrary-account HTTP API.
        ticket = secrets.token_urlsafe(32)
        with self.connect() as db:
            row = db.execute('SELECT *,expires>clock_timestamp() AS live FROM public_authority.servers WHERE id=%s FOR SHARE', (server,)).fetchone()
            require(row and row['approved'] and row['live'], 'UNTRUSTED_DESTINATION')
            db.execute("INSERT INTO public_authority.tickets VALUES(%s,%s,%s,%s,%s,7,clock_timestamp()+interval '30 seconds',false)", (digest(ticket), account, server, row['fingerprint'], nonce))
        return ticket

    def identity_ticket(self, claims, request):
        # claims must come exclusively from the service's signature validator.
        require(type(request) is dict and set(request) == {'server', 'nonce'}, 'BAD_REQUEST')
        for field in ('server', 'nonce'):
            require(type(request[field]) is str and re.fullmatch(r'[A-Za-z0-9_-]{1,128}', request[field]) is not None, 'BAD_REQUEST')
        with self.connect() as db:
            row = db.execute('SELECT account FROM public_authority.profiles WHERE issuer=%s AND subject=%s', (claims['iss'], claims['sub'])).fetchone()
        require(row is not None, 'ACCOUNT_NOT_ENROLLED')
        ticket = self.issue_ticket(row['account'], request['server'], request['nonce'])
        return {'ok': True, 'code': 'TICKET', 'ticket': ticket, 'protocol': PROTOCOL, 'expires_in': 30}

    def _server(self, db, server, credential):
        row = db.execute('SELECT * FROM public_authority.servers WHERE id=%s FOR SHARE', (server,)).fetchone()
        now = db.execute('SELECT clock_timestamp() AS now').fetchone()['now']
        require(row and row['approved'] and row['expires'] > now and hmac.compare_digest(row['credential_hash'], digest(credential)), 'UNTRUSTED_SERVER')
        return row

    def _lease(self, db, account):
        row = db.execute('SELECT * FROM public_authority.leases WHERE account=%s FOR UPDATE', (account,)).fetchone()
        require(row is not None, 'UNKNOWN_ACCOUNT')
        return row

    def _now(self, db):
        # Read after obtaining the lock, never transaction-start time.
        return db.execute('SELECT clock_timestamp() AS now').fetchone()['now']

    def _owned(self, db, lease, server, request, phases=('ACTIVE',)):
        require(lease['owner'] == server and lease['epoch'] == request['epoch'] and lease['generation'] == request['generation'] and lease['phase'] in phases and lease['expires'] > self._now(db), 'STALE_AUTHORITY')

    def _profile(self, db, account):
        row = db.execute('SELECT * FROM public_authority.profiles WHERE account=%s FOR UPDATE', (account,)).fetchone()
        return {'account': account, 'revision': row['revision'], 'money': row['money'], 'profile': row['profile']}

    def _grant(self, db, lease, server, fresh):
        row = db.execute("UPDATE public_authority.leases SET owner=%s,epoch=epoch+%s,generation=generation+1,phase='ACTIVE',expires=clock_timestamp()+interval '30 seconds',transfer_id=NULL WHERE account=%s RETURNING epoch,generation", (server, 1 if fresh else 0, lease['account'])).fetchone()
        return {'ok': True, 'code': 'ACTIVE', 'epoch': row['epoch'], 'generation': row['generation'], 'lease_ms': 30000, **self._profile(db, lease['account'])}

    def _ticket(self, db, request, server_row):
        # Lease lock is taken before ticket lock by callers, matching claim/admit ordering.
        ticket = db.execute('SELECT * FROM public_authority.tickets WHERE digest=%s FOR UPDATE', (digest(request['ticket']),)).fetchone()
        require(ticket and ticket['server'] == server_row['id'] and ticket['fingerprint'] == server_row['fingerprint'] and ticket['nonce'] == request['nonce'] and ticket['protocol'] == PROTOCOL, 'INVALID_TICKET')
        return ticket

    def _ticket_account(self, db, request):
        row = db.execute('SELECT account FROM public_authority.tickets WHERE digest=%s', (digest(request['ticket']),)).fetchone()
        require(row is not None, 'INVALID_TICKET')
        return row['account']

    def _consume(self, db, ticket):
        require(not ticket['used'] and ticket['expires'] > self._now(db), 'EXPIRED_OR_USED_TICKET')
        db.execute('UPDATE public_authority.tickets SET used=true WHERE digest=%s', (ticket['digest'],))

    def execute(self, server, credential, request):
        try:
            self._validate(request)
            with self.connect() as db:
                db.execute("SET LOCAL lock_timeout='3s'")
                db.execute("SET LOCAL statement_timeout='4s'")
                server_row = self._server(db, server, credential)
                if 'fingerprint' in request:
                    require(hmac.compare_digest(server_row['fingerprint'], request['fingerprint']), 'SERVER_CERTIFICATE_MISMATCH')
                account = self._ticket_account(db, request) if request['op'] in ('admit', 'claim') else request['account']
                lease = self._lease(db, account)
                require(server_row['expires'] > self._now(db), 'UNTRUSTED_SERVER')
                result = self._dispatch(db, server_row, lease, request)
                self.fault('before_commit', request)
                require(server_row['expires'] > self._now(db), 'UNTRUSTED_SERVER')
                if request['op'] not in ('admit', 'claim'):
                    require(lease['expires'] > self._now(db), 'STALE_AUTHORITY')
            self.fault('after_commit', request)
            return result
        except (Rejected, MarketError) as error:
            return {'ok': False, 'code': str(error)}

    def _validate(self, request):
        require(type(request) is dict and request.get('realm') == 'public', 'WRONG_REALM')
        if request.get('op') in oil.OPERATIONS:
            oil.validate(request)
            return
        base = {'realm', 'op'}
        owned = {'account', 'epoch', 'generation'}
        fields = {'admit': {'ticket', 'nonce'}, 'claim': {'ticket', 'nonce', 'transfer_id'},
                  'renew': owned, 'release': owned, 'inspect': owned,
                  'checkpoint': owned | {'expected_revision', 'position', 'fuel_liters'},
                  'purchase': owned | {'action_id', 'expected_revision'},
                  'ship_resale': owned | {'action_id', 'expected_revision', 'port_id', 'ship_id', 'value_minor'},
                  'fleet_switch': owned | {'action_id', 'expected_revision', 'port_id', 'ship_id', 'slot'},
                  'ship_purchase': owned | {'action_id', 'expected_revision', 'port_id', 'definition_id', 'cost_minor'},
                  'deliver': owned | {'action_id', 'expected_revision', 'cargo_id'},
                  'impact': owned | {'action_id', 'expected_revision', 'damage_bp', 'fuel_liters', 'position'},
                  'recover': owned | {'action_id', 'expected_revision', 'incident_id', 'slot'},
                  'repair': owned | {'action_id', 'expected_revision', 'port_id', 'condition_bp', 'cost_minor'},
                  'refuel': owned | {'action_id', 'expected_revision', 'port_id', 'liters', 'unit_price_minor'},
                  'voyage_accept': owned | {'action_id', 'expected_revision', 'offer_id', 'port_id'},
                  'voyage_load': owned | {'action_id', 'expected_revision', 'job_id', 'port_id'},
                  'voyage_deliver': owned | {'action_id', 'expected_revision', 'job_id', 'port_id'},
                  'voyage_cancel': owned | {'action_id', 'expected_revision', 'job_id', 'abandon'},
                  'begin': owned | {'transfer_id', 'destination'}, 'seal': owned | {'transfer_id'},
                  'cancel': owned | {'transfer_id'}}
        op = request.get('op')
        if op in ('checkpoint', 'impact') and 'operating_seconds' in request:
            base.add('operating_seconds')
            seconds = request['operating_seconds']
            require(type(seconds) in (int, float) and math.isfinite(seconds) and 0 <= seconds <= 86400, 'BAD_WEAR_TIME')
        if op == 'admit' and 'fingerprint' in request:
            base.add('fingerprint')
            require(type(request['fingerprint']) is str and re.fullmatch(r'[a-f0-9]{64}', request['fingerprint']) is not None, 'BAD_FINGERPRINT')
        require(type(op) is str and op in fields and set(request) == base | fields[op], 'BAD_REQUEST')
        for name in ['epoch', 'generation', 'expected_revision']:
            if name in request: require(type(request[name]) is int and 0 <= request[name] <= MAX_INTEGER, 'BAD_INTEGER')
        for name in ['account', 'ticket', 'nonce', 'transfer_id', 'destination', 'action_id', 'cargo_id', 'job_id', 'offer_id', 'port_id', 'incident_id', 'definition_id', 'ship_id']:
            if name in request: require(type(request[name]) is str and 0 < len(request[name]) <= 128 and re.fullmatch(r'[A-Za-z0-9_-]+', request[name]) is not None, 'BAD_IDENTIFIER')
        if op == 'impact':
            require(type(request['damage_bp']) is int and 1 <= request['damage_bp'] <= 10000, 'BAD_DAMAGE')
        if op == 'recover':
            require(type(request['slot']) is int and 0 <= request['slot'] < len(recovery.SLOTS), 'BAD_SLOT')
        if op == 'fleet_switch':
            require(type(request['slot']) is int and -1 <= request['slot'] < max(map(len, fleet.SLOTS.values())), 'BAD_SLOT')
        if op == 'ship_resale':
            require(type(request['value_minor']) is int and 0 <= request['value_minor'] <= MAX_INTEGER, 'BAD_PRICE')
        if op == 'ship_purchase':
            require(type(request['cost_minor']) is int and 0 < request['cost_minor'] <= MAX_INTEGER, 'BAD_PRICE')
        if op == 'repair':
            require(type(request['condition_bp']) is int and 1 <= request['condition_bp'] <= 10000, 'BAD_CONDITION')
            require(type(request['cost_minor']) is int and 0 <= request['cost_minor'] <= MAX_INTEGER, 'BAD_PRICE')
        if op == 'refuel':
            require(type(request['liters']) is int and 1 <= request['liters'] <= 1000, 'BAD_QUANTITY')
            require(type(request['unit_price_minor']) is int and 0 <= request['unit_price_minor'] <= MAX_INTEGER, 'BAD_PRICE')
        if op == 'voyage_cancel': require(type(request['abandon']) is bool, 'BAD_REQUEST')
        if op in ('checkpoint', 'impact'):
            p = request['position']
            require(type(p) is dict and set(p) == {'latitude', 'longitude', 'heading'}, 'BAD_POSITION')
            for name, maximum in [('latitude', 90), ('longitude', 180), ('heading', 360)]:
                require(type(p[name]) in (int, float) and math.isfinite(p[name]) and abs(p[name]) <= maximum, 'BAD_POSITION')
            fuel = request['fuel_liters']
            require(type(fuel) in (int, float) and math.isfinite(fuel) and 0 <= fuel <= 1000, 'BAD_FUEL')

    def _dispatch(self, db, server_row, lease, request):
        server, op, account = server_row['id'], request['op'], lease['account']
        if op == 'admit':
            ticket = self._ticket(db, request, server_row)
            if lease['phase'] == 'SEALED':
                transfer = db.execute('SELECT * FROM public_authority.transfers WHERE id=%s FOR UPDATE', (lease['transfer_id'],)).fetchone()
                require(transfer['expires'] <= self._now(db), 'TRANSFER_PENDING')
            elif lease['phase'] != 'VACANT' and lease['expires'] > self._now(db):
                require(lease['owner'] == server and lease['phase'] == 'ACTIVE', 'ACCOUNT_BUSY')
            fresh = lease['owner'] != server or lease['phase'] != 'ACTIVE' or lease['expires'] <= self._now(db)
            self._consume(db, ticket)
            if fresh and lease['transfer_id']:
                db.execute("UPDATE public_authority.transfers SET phase='ABANDONED' WHERE id=%s AND phase IN ('PREPARED','SEALED')", (lease['transfer_id'],))
            return self._grant(db, lease, server, fresh)
        if op == 'claim':
            ticket = self._ticket(db, request, server_row)
            transfer = db.execute('SELECT * FROM public_authority.transfers WHERE id=%s FOR UPDATE', (request['transfer_id'],)).fetchone()
            require(transfer and transfer['account'] == account and transfer['destination'] == server, 'WRONG_DESTINATION')
            if transfer['phase'] == 'CLAIMED':
                require(transfer['claim_ticket'] == ticket['digest'], 'ALREADY_CLAIMED')
                prior = transfer['outcome']
                current = lease['owner'] == server and lease['epoch'] == prior['epoch'] and lease['generation'] == prior['generation'] and lease['phase'] == 'ACTIVE' and lease['expires'] > self._now(db)
                require(current, 'STALE_OUTCOME')
                # Keep the original binding, but never send an obsolete spawn
                # snapshot after this owner has already changed the profile.
                return dict(prior, **self._profile(db, account), duplicate=True, lease_ms=max(0, int((lease['expires'] - self._now(db)).total_seconds()*1000)))
            require(transfer['phase'] == 'SEALED' and transfer['expires'] > self._now(db) and lease['phase'] == 'SEALED' and lease['transfer_id'] == transfer['id'] and lease['epoch'] == transfer['source_epoch'], 'TRANSFER_UNAVAILABLE')
            self._consume(db, ticket)
            require(self._profile(db, account) == transfer['snapshot'], 'CANONICAL_REVISION_CHANGED')
            result = self._grant(db, lease, server, True)
            db.execute("UPDATE public_authority.transfers SET phase='CLAIMED',claim_ticket=%s,outcome=%s WHERE id=%s", (ticket['digest'], Jsonb(result), transfer['id']))
            return result
        if op == 'seal' and lease['phase'] == 'SEALED':
            self._owned(db, lease, server, request, ('SEALED',))
            require(lease['transfer_id'] == request['transfer_id'], 'TRANSFER_UNAVAILABLE')
            transfer = db.execute('SELECT snapshot FROM public_authority.transfers WHERE id=%s', (lease['transfer_id'],)).fetchone()
            return {'ok': True, 'code': 'SEALED', 'transfer_id': lease['transfer_id'], 'revision': transfer['snapshot']['revision'], 'duplicate': True}
        self._owned(db, lease, server, request, ('ACTIVE', 'QUIESCING') if op in ('renew', 'inspect', 'cancel', 'seal', 'begin') else ('ACTIVE',))
        if op == 'renew':
            db.execute("UPDATE public_authority.leases SET expires=clock_timestamp()+interval '30 seconds' WHERE account=%s", (account,))
            return {'ok': True, 'code': lease['phase'], 'lease_ms': 30000}
        if op == 'inspect': return {'ok': True, 'code': lease['phase'], **self._profile(db, account)}
        if op == 'release':
            db.execute("UPDATE public_authority.leases SET phase='VACANT',owner=NULL,expires=clock_timestamp() WHERE account=%s", (account,))
            return {'ok': True, 'code': 'RELEASED'}
        if op == 'begin':
            destination = db.execute('SELECT * FROM public_authority.servers WHERE id=%s FOR SHARE', (request['destination'],)).fetchone()
            require(destination and destination['approved'] and destination['expires'] > self._now(db) and destination['id'] != server, 'UNTRUSTED_DESTINATION')
            previous = db.execute('SELECT * FROM public_authority.transfers WHERE id=%s', (request['transfer_id'],)).fetchone()
            if previous:
                require(previous['account'] == account and previous['source'] == server and previous['source_epoch'] == lease['epoch'] and previous['destination'] == request['destination'] and previous['phase'] == 'PREPARED' and lease['transfer_id'] == previous['id'], 'TRANSFER_ID_CONFLICT')
                return {'ok': True, 'code': 'QUIESCING', 'transfer_id': previous['id'], 'duplicate': True}
            require(lease['phase'] == 'ACTIVE', 'ALREADY_TRANSFERRING')
            db.execute("INSERT INTO public_authority.transfers(id,account,source,source_epoch,destination,phase,expires) VALUES(%s,%s,%s,%s,%s,'PREPARED',clock_timestamp()+interval '30 seconds')", (request['transfer_id'], account, server, lease['epoch'], request['destination']))
            db.execute("UPDATE public_authority.leases SET phase='QUIESCING',transfer_id=%s WHERE account=%s", (request['transfer_id'], account))
            return {'ok': True, 'code': 'QUIESCING', 'transfer_id': request['transfer_id']}
        if op in ('seal', 'cancel'):
            require(lease['phase'] == 'QUIESCING' and lease['transfer_id'] == request['transfer_id'], 'TRANSFER_UNAVAILABLE')
            transfer = db.execute('SELECT * FROM public_authority.transfers WHERE id=%s FOR UPDATE', (request['transfer_id'],)).fetchone()
            require(transfer['source'] == server and transfer['source_epoch'] == lease['epoch'] and transfer['phase'] == 'PREPARED', 'TRANSFER_UNAVAILABLE')
            if op == 'cancel':
                db.execute("UPDATE public_authority.transfers SET phase='CANCELLED' WHERE id=%s", (transfer['id'],))
                db.execute("UPDATE public_authority.leases SET phase='ACTIVE',transfer_id=NULL WHERE account=%s", (account,))
                return {'ok': True, 'code': 'ACTIVE'}
            snapshot = self._profile(db, account)
            db.execute("UPDATE public_authority.transfers SET phase='SEALED',snapshot=%s,expires=clock_timestamp()+interval '30 seconds' WHERE id=%s", (Jsonb(snapshot), transfer['id']))
            db.execute("UPDATE public_authority.leases SET phase='SEALED' WHERE account=%s", (account,))
            return {'ok': True, 'code': 'SEALED', 'transfer_id': transfer['id'], 'revision': snapshot['revision']}
        profile = self._profile(db, account)
        if op in oil.OPERATIONS:
            return oil.execute(oil_postgres.Transaction(db), 'public', profile, request,
                               lambda: int(self._now(db).timestamp()), self.fault)
        if op == 'checkpoint':
            if recovery.pending(profile['profile']): return {'ok': True, 'code': 'SAVED', 'revision': profile['revision']}
            require(profile['revision'] == request['expected_revision'], 'STALE_REVISION')
            wear.apply(profile['profile']['ship'], request.get('operating_seconds', 0))
            profile['profile']['ship']['position'] = request['position']
            profile['profile']['ship']['fuel_liters'] = request['fuel_liters']
            db.execute('UPDATE public_authority.profiles SET profile=%s,revision=revision+1 WHERE account=%s', (Jsonb(profile['profile']), account))
            return {'ok': True, 'code': 'SAVED', 'revision': profile['revision']+1, 'condition_bp': profile['profile']['ship']['condition_bp']}
        if op in voyages.OPERATIONS or op in recovery.OPERATIONS or op in ('refuel', 'repair', 'ship_purchase', 'fleet_switch', 'ship_resale'):
            return self._voyage(db, account, profile, request)
        require(not recovery.pending(profile['profile']), 'RECOVERY_REQUIRED')
        # Only game-owned purchase/delivery; no peer economic operations exist.
        intent = {key: request[key] for key in ('op', 'action_id', 'expected_revision', 'cargo_id') if key in request}
        fingerprint = digest(canonical(intent))
        prior = db.execute('SELECT * FROM public_authority.receipts WHERE account=%s AND action_id=%s', (account, request['action_id'])).fetchone()
        if prior:
            require(hmac.compare_digest(prior['fingerprint'], fingerprint), 'ID_CONFLICT')
            return dict(prior['result'], duplicate=True)
        game = db.execute('SELECT * FROM public_authority.game WHERE id=1 FOR UPDATE').fetchone()
        code, amount = 'COMMITTED', 0
        cargo = profile['profile']['cargo']
        if profile['revision'] != request['expected_revision']: code = 'STALE_REVISION'
        elif op == 'purchase' and (profile['money'] < 10000 or game['stock'] < 1): code = 'INSUFFICIENT_RESOURCES'
        elif op == 'deliver' and not any(item['id'] == request['cargo_id'] and 'job_id' not in item and item.get('definition') != 'cargo_oil' for item in cargo): code = 'CARGO_NOT_OWNED'
        elif op == 'deliver' and game['money'] < 5000: code = 'INSUFFICIENT_RESOURCES'
        if code == 'COMMITTED':
            amount = -10000 if op == 'purchase' else 5000
            require(0 <= profile['money']+amount <= MAX_INTEGER, 'OVERFLOW')
            amount, repayment = recovery.repay(profile['profile'], amount)
            if op == 'purchase':
                cargo.append({'id': str(uuid.uuid5(uuid.UUID(account), request['action_id'])), 'definition': 'test_container', 'state': 'aboard', 'ship': profile['profile']['ship']['id']})
            else:
                profile['profile']['cargo'] = [item for item in cargo if item['id'] != request['cargo_id']]
                profile['profile']['delivered'].append(request['cargo_id'])
            voyage_accounting.record(profile['profile'], profile['profile'], op, code, profile['money'], amount, repayment)
            db.execute('UPDATE public_authority.profiles SET money=money+%s,revision=revision+1,profile=%s WHERE account=%s', (amount, Jsonb(profile['profile']), account))
            self.fault('after_profile_write', request)
            db.execute('UPDATE public_authority.game SET money=money-%s,stock=stock+%s WHERE id=1', (amount, -1 if op == 'purchase' else 1))
        result = {'ok': code == 'COMMITTED', 'code': code, 'action_id': request['action_id'], 'revision': profile['revision']+(1 if code == 'COMMITTED' else 0), 'amount': amount}
        db.execute('INSERT INTO public_authority.receipts VALUES(%s,%s,%s,%s)', (account, request['action_id'], fingerprint, Jsonb(result)))
        if code == 'COMMITTED': db.execute('INSERT INTO public_authority.journal VALUES(%s,%s,%s)', (account, request['action_id'], amount))
        return result

    def _voyage(self, db, account, profile, request):
        # Lease and profile are already locked. Reject unknown request fields above.
        intent = {k: v for k, v in request.items() if k not in ('realm', 'account', 'epoch', 'generation')}
        fingerprint = digest(canonical(intent))
        prior = db.execute('SELECT * FROM public_authority.receipts WHERE account=%s AND action_id=%s', (account, request['action_id'])).fetchone()
        if prior:
            require(hmac.compare_digest(prior['fingerprint'], fingerprint), 'ID_CONFLICT')
            return dict(prior['result'], duplicate=True)
        game = db.execute('SELECT * FROM public_authority.game WHERE id=1 FOR UPDATE').fetchone()
        candidate, amount, job = profile['profile'], 0, None
        if profile['revision'] != request['expected_revision']:
            code = 'STALE_REVISION'
        elif recovery.pending(profile['profile']) and request['op'] not in recovery.OPERATIONS:
            code = 'RECOVERY_REQUIRED'
        else:
            now_ms = int(self._now(db).timestamp()*1000)
            if request['op'] in recovery.OPERATIONS:
                code, candidate, amount, job = recovery.transition(profile['profile'], request, profile['money'])
            elif request['op'] == 'fleet_switch':
                code, candidate, amount, job = fleet.transition(profile['profile'], request)
            elif request['op'] == 'ship_resale':
                code, candidate, amount, job = resale.transition(profile['profile'], request, game['money'], profile['money'])
            elif request['op'] == 'ship_purchase':
                code, candidate, amount, job = ship_purchase.transition(profile['profile'], request, profile['money'])
            elif request['op'] == 'repair':
                code, candidate, amount, job = repairs.transition(profile['profile'], request, profile['money'])
            elif request['op'] == 'refuel':
                code, candidate, amount, job = refueling.transition(profile['profile'], request, profile['money'])
            else:
                code, candidate, amount, job = voyages.transition(profile['profile'], request, now_ms, game['money'])
        ok = code in ('JOB_ACCEPTED', 'CARGO_LOADED', 'VOYAGE_DELIVERED', 'JOB_CLOSED', 'REFUELED', 'REPAIRED', 'SHIP_PURCHASED', 'SHIP_SOLD', 'FLEET_SWITCHED', 'HULL_DAMAGED', 'SHIP_SUNK', 'SHIP_RECOVERED')
        repayment = 0
        report = None
        if ok:
            amount, repayment = recovery.repay(candidate, amount)
            if job is not None and code == 'VOYAGE_DELIVERED':
                job['paid_minor'] = amount
                job['recovery_repaid_minor'] = repayment
            report = voyage_accounting.record(profile['profile'], candidate, request['op'], code, profile['money'], amount, repayment)
            if code == 'SHIP_SOLD':
                job.update(recovery_repaid_minor=repayment, wallet_delta_minor=amount, wallet_before_minor=profile['money'], wallet_after_minor=profile['money']+amount)
                candidate['last_resale_receipt'] = job
            require(candidate.get('recovery_debt_minor', 0) <= MAX_INTEGER, 'OVERFLOW')
            require(0 <= profile['money']+amount <= MAX_INTEGER, 'OVERFLOW')
            db.execute('UPDATE public_authority.profiles SET profile=%s,money=money+%s,revision=revision+1 WHERE account=%s', (Jsonb(candidate), amount, account))
            self.fault('after_profile_write', request)
            require(0 <= game['money']-amount <= MAX_INTEGER, 'OVERFLOW')
            if amount: db.execute('UPDATE public_authority.game SET money=money-%s WHERE id=1', (amount,))
        result = dict(ok=ok, code=code, action_id=request['action_id'], revision=profile['revision']+int(ok), amount=amount)
        if report is not None: result['voyage_report'] = report
        if repayment: result['recovery_repaid_minor'] = repayment
        if job is not None: result['owned_ship' if request['op'] == 'ship_purchase' else 'resale' if request['op'] == 'ship_resale' else 'job'] = job
        db.execute('INSERT INTO public_authority.receipts VALUES(%s,%s,%s,%s)', (account, request['action_id'], fingerprint, Jsonb(result)))
        if ok: db.execute('INSERT INTO public_authority.journal VALUES(%s,%s,%s)', (account, request['action_id'], amount))
        return result
