"""Step 77 private refinery. Integer quantities, no public stock/withdrawal API."""
from dataclasses import asdict, dataclass
import copy
import hashlib
import json
import sqlite3

from services.oil_market.model import MarketError, integer
from services.oil_market.private import PrivateStore
from services.oil_market.settlement import encode, consume_lot, remaining_units, lot_summary

REFINERY_ID = 'refinery_slatewater_01'
PORT_ID = 'port_slatewater_works'


@dataclass(frozen=True)
class Config:
    yield_numerator: int = 7
    yield_denominator: int = 10
    input_capacity_millibarrels: int = 200000
    output_capacity_millibarrels: int = 1000000
    rate_millibarrels_per_second: int = 1000
    max_submissions: int = 10000

    def __post_init__(self):
        for key, value in asdict(self).items():
            if not integer(value, 1, 10**9):
                raise MarketError('INVALID_REFINERY_CONFIG')
        if not self.yield_numerator <= self.yield_denominator <= 10000 or self.max_submissions > 10000:
            raise MarketError('INVALID_REFINERY_CONFIG')


def initial(realm, config):
    return dict(schema=1, realm=realm, refinery_id=REFINERY_ID, config=asdict(config),
                jobs=[], owners={})


def validate(state, realm):
    """Reconstruct every credit and remainder; malformed saves never seed stock."""
    try:
        if type(state['schema']) is not int or state['schema'] != 1 or state['realm'] != realm or state['refinery_id'] != REFINERY_ID:
            raise ValueError()
        config = Config(**state['config'])
        jobs, owners = state['jobs'], state['owners']
        if type(jobs) is not list or len(jobs) > config.max_submissions or type(owners) is not dict:
            raise ValueError()
        for owner in owners.values():
            if type(owner) is not dict or set(owner) != {'stock_millibarrels', 'remainder', 'processed_millibarrels'}:
                raise ValueError()
            if (not integer(owner['stock_millibarrels'], 0, config.output_capacity_millibarrels) or
                    not integer(owner['remainder'], 0, config.yield_denominator - 1) or
                    not integer(owner['processed_millibarrels'], 0, config.input_capacity_millibarrels * config.max_submissions)):
                raise ValueError()
        rebuilt, identities, active, reserved = {}, set(), 0, 0
        for job in jobs:
            account = job['account']
            key = (account, job['action_id'])
            if key in identities or not all(type(v) is str and 0 < len(v) <= 128 for v in key):
                raise ValueError()
            identities.add(key)
            for field in ('output_millibarrels', 'remainder_after', 'duration_ms', 'allocated_cost_minor'):
                if not integer(job[field], 0, 9_000_000_000_000): raise ValueError()
            if type(job['lot_id']) is not str or not 0 < len(job['lot_id']) <= 128: raise ValueError()
            units = job['input_millibarrels']
            if not integer(units, 1, config.input_capacity_millibarrels): raise ValueError()
            owner = rebuilt.setdefault(account, dict(stock_millibarrels=0, remainder=0, processed_millibarrels=0))
            output, remainder = divmod(units * config.yield_numerator + owner['remainder'], config.yield_denominator)
            duration = (units * 1000 + config.rate_millibarrels_per_second - 1) // config.rate_millibarrels_per_second
            if (job['output_millibarrels'] != output or job['remainder_after'] != remainder or
                    job['duration_ms'] != duration or not integer(job['elapsed_ms'], 0, duration) or
                    job['status'] not in ('processing', 'complete')): raise ValueError()
            if job['status'] == 'complete':
                if job['elapsed_ms'] != duration: raise ValueError()
                owner['stock_millibarrels'] += output
                owner['remainder'] = remainder
                owner['processed_millibarrels'] += units
            else:
                if job is not jobs[-1] or job['elapsed_ms'] >= duration: raise ValueError()
                active += 1
                reserved += output
        if active > 1 or rebuilt != owners: raise ValueError()
        if sum(o['stock_millibarrels'] for o in owners.values()) + reserved > config.output_capacity_millibarrels:
            raise ValueError()
        return config
    except (KeyError, TypeError, ValueError, OverflowError):
        raise MarketError('REFINERY_STATE_INVALID') from None


class RefineryStore(PrivateStore):
    """Same private DB transaction as oil cargo; explicitly enabled in NEW fixtures.

    Reopening requires existing refinery data. No reseeding or automatic migration.
    The trusted host alone calls advance with active monotonic elapsed milliseconds.
    """
    def initialize(self, config=None):
        super().initialize()
        with self.connect() as db:
            db.execute('CREATE TABLE refinery(id INTEGER PRIMARY KEY CHECK(id=1), state TEXT NOT NULL)')
            db.execute('INSERT INTO refinery VALUES(1,?)', (encode(initial(self.realm, config or Config())),))

    def read(self, db):
        row = db.execute('SELECT state FROM refinery WHERE id=1').fetchone()
        if not row: raise MarketError('REFINERY_UNAVAILABLE')
        try:
            state = json.loads(row[0])
        except (ValueError, TypeError):
            raise MarketError('REFINERY_STATE_INVALID') from None
        validate(state, self.realm)
        return state

    def write(self, db, state):
        validate(state, self.realm)
        db.execute('UPDATE refinery SET state=? WHERE id=1', (encode(state),))

    def advance(self, elapsed_ms, *, fault=lambda *_: None):
        # Not exposed in dispatch. Bound each host tick; no wall-clock/offline catchup.
        if not integer(elapsed_ms, 0, 1000): raise MarketError('BAD_REFINERY_TICK')
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            state = self.read(db)
            if state['jobs'] and state['jobs'][-1]['status'] == 'processing':
                job = state['jobs'][-1]
                job['elapsed_ms'] = min(job['duration_ms'], job['elapsed_ms'] + elapsed_ms)
                if job['elapsed_ms'] == job['duration_ms']:
                    owner = state['owners'][job['account']]
                    owner['stock_millibarrels'] += job['output_millibarrels']
                    owner['processed_millibarrels'] += job['input_millibarrels']
                    owner['remainder'] = job['remainder_after']
                    job['status'] = 'complete'
                self.write(db, state)
                fault('after_refinery_write', {})
            fault('before_commit', {})
        fault('after_commit', {})

    def refinery(self, account, request, *, docked=False, port_id='', fault=lambda *_: None):
        try:
            op = request.get('op')
            fields = {'op', 'refinery_id'}
            if op == 'refinery_submit': fields |= {'action_id', 'expected_revision', 'lot_id', 'input_millibarrels'}
            if op not in ('refinery_snapshot', 'refinery_submit') or set(request) != fields or request['refinery_id'] != REFINERY_ID:
                raise MarketError('BAD_REQUEST')
            if op == 'refinery_submit':
                if not integer(request['input_millibarrels'], 1, 10**9) or not integer(request['expected_revision'], 0, 9_000_000_000_000):
                    raise MarketError('BAD_INTEGER')
                for key in ('action_id', 'lot_id'):
                    if type(request[key]) is not str or not 0 < len(request[key]) <= 128: raise MarketError('BAD_IDENTIFIER')
            fingerprint = hashlib.sha256(encode(request).encode()).hexdigest()
            with self.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                state = self.read(db)
                row = db.execute('SELECT * FROM profiles WHERE account=?', (account,)).fetchone()
                if row is None: raise MarketError('UNKNOWN_ACCOUNT')
                profile = json.loads(row['profile'])
                if op == 'refinery_snapshot':
                    return dict(ok=True, code='REFINERY', refinery_id=REFINERY_ID, port_id=PORT_ID,
                                config=state['config'], revision=row['revision'],
                                owner=state['owners'].get(account, dict(stock_millibarrels=0, remainder=0, processed_millibarrels=0)),
                                busy=bool(state['jobs'] and state['jobs'][-1]['status'] == 'processing'),
                                jobs=[j for j in state['jobs'] if j['account'] == account][-1:],
                                lots=[lot_summary(c) for c in profile['cargo'] if c.get('definition') == 'cargo_oil'])
                prior = db.execute('SELECT * FROM receipts WHERE account=? AND action_id=?', (account, request['action_id'])).fetchone()
                if prior:
                    if prior['fingerprint'] != fingerprint: raise MarketError('ID_CONFLICT')
                    return dict(json.loads(prior['result']), duplicate=True)
                if not docked or port_id != PORT_ID: raise MarketError('DOCK_REQUIRED')
                if row['revision'] != request['expected_revision']: raise MarketError('STALE_REVISION')
                config = Config(**state['config'])
                if len(state['jobs']) >= config.max_submissions: raise MarketError('REFINERY_LEDGER_FULL')
                if state['jobs'] and state['jobs'][-1]['status'] == 'processing': raise MarketError('REFINERY_BUSY')
                units = request['input_millibarrels']
                if units > config.input_capacity_millibarrels: raise MarketError('INPUT_CAPACITY')
                if profile.get('recovery', {}).get('state') == 'pending' or profile['ship'].get('condition_bp', 10000) <= 0:
                    raise MarketError('RECOVERY_REQUIRED')
                lot = next((c for c in profile['cargo'] if c.get('id') == request['lot_id'] and c.get('definition') == 'cargo_oil' and c.get('ship') == profile['ship']['id']), None)
                if lot is None: raise MarketError('CARGO_NOT_OWNED')
                owner = state['owners'].setdefault(account, dict(stock_millibarrels=0, remainder=0, processed_millibarrels=0))
                output, remainder = divmod(units * config.yield_numerator + owner['remainder'], config.yield_denominator)
                if sum(o['stock_millibarrels'] for o in state['owners'].values()) + output > config.output_capacity_millibarrels:
                    raise MarketError('OUTPUT_CAPACITY')
                cost = consume_lot(lot, units, refining=True)
                if not remaining_units(lot): profile['cargo'].remove(lot)
                job = dict(account=account, action_id=request['action_id'], lot_id=request['lot_id'],
                           input_millibarrels=units, output_millibarrels=output, remainder_after=remainder,
                           allocated_cost_minor=cost, elapsed_ms=0,
                           duration_ms=(units * 1000 + config.rate_millibarrels_per_second - 1) // config.rate_millibarrels_per_second,
                           status='processing')
                state['jobs'].append(job)
                db.execute('UPDATE profiles SET profile=?,revision=revision+1 WHERE account=?', (encode(profile), account))
                fault('after_profile_write', request)
                self.write(db, state)
                fault('after_refinery_write', request)
                result = dict(ok=True, code='REFINERY_SUBMITTED', action_id=request['action_id'], job=copy.deepcopy(job), revision=row['revision']+1)
                db.execute('INSERT INTO receipts VALUES(?,?,?,?)', (account, request['action_id'], fingerprint, encode(result)))
                fault('before_commit', request)
            fault('after_commit', request)
            return result
        except MarketError as error:
            return dict(ok=False, code=str(error))
        except sqlite3.Error:
            return dict(ok=False, code='REFINERY_UNAVAILABLE', uncertain=op == 'refinery_submit')
