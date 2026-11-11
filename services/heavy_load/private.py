"""Step 80 private-world job authority; called only by the trusted host.

No player RPC, public fallback, timer expiry or physics implementation. The host
supplies pickup/delivery evidence after checking its authoritative simulation.
"""
import json
import math
import sqlite3
from services.oil_market.private import PrivateStore
from services.oil_market.model import MarketError, integer
from services.oil_market.settlement import encode, MAX_MONEY

PAYLOAD = 'payload_offshore_block_01'
LIFTER = 'ship_heavy_lifter_01'
TERMS = dict(payload_id=PAYLOAD, payload_definition='block', mass_kg=100000,
             allowed_lifters=[LIFTER], reward_minor=70000,
             pickup_zone='offshore_block_pickup_01', delivery_zone='offshore_block_delivery_01',
             pickup_position_m=[-950, 0, -800], delivery_position_m=[-950, 0, -1800],
             zone_radius_m=30)
# Step 83 variants. TERMS above stays byte-identical so Step 80-82 single-block
# worlds remain readable; those worlds keep offering only the block.
PAYLOADS = {
    PAYLOAD: TERMS,
    'payload_offshore_module_01': dict(
        payload_id='payload_offshore_module_01', payload_definition='module', mass_kg=60000,
        allowed_lifters=[LIFTER], reward_minor=45000,
        pickup_zone='offshore_module_pickup_01', delivery_zone='offshore_module_delivery_01',
        pickup_position_m=[-700, 0, -800], delivery_position_m=[-300, 0, -300],
        zone_radius_m=30),
    'payload_offshore_girder_01': dict(
        payload_id='payload_offshore_girder_01', payload_definition='girder', mass_kg=150000,
        allowed_lifters=[LIFTER], reward_minor=100000,
        pickup_zone='offshore_girder_pickup_01', delivery_zone='offshore_girder_delivery_01',
        pickup_position_m=[-950, 0, -500], delivery_position_m=[-100, 0, -900],
        zone_radius_m=30),
}
# Physical/presentation definitions: label and width/height/length envelope (m).
ENVELOPES = {
    PAYLOAD: dict(label='Offshore block', size_m=[14, 8, 32]),
    'payload_offshore_module_01': dict(label='Compact module', size_m=[10, 6, 20]),
    'payload_offshore_girder_01': dict(label='Long girder', size_m=[8, 5, 32]),
}
# Lifter rules. The envelope limit is the 14 x 8 x 32 m compound payload already
# proven as one constrained child through deck travel and chart transitions.
LIFTERS = {LIFTER: dict(max_payload_kg=200000, max_envelope_m=[14, 8, 32],
                        empty_displacement_kg=1000000, draft_m_per_100t=0.5, max_draft_m=1.0)}
CHART_RANGE_M = 1000  # measured local-chart budget (WORLD_SIZE_EXPERIMENT.md)
# Inherited Step 82 zone outside that budget; kept for saved-world compatibility.
CHART_EXCEPTIONS = ('offshore_block_delivery_01',)
WORLD = dict(version=2, payloads=PAYLOADS, envelopes=ENVELOPES, lifters=LIFTERS)
MAX_ACTIONS = 10000
TERMINAL = ('delivered', 'abandoned', 'cancelled', 'canceled', 'failed')


def require(value, code):
    if not value:
        raise MarketError(code)


def payload_problems(terms, envelope, lifters=None):
    """Envelope, load-limit and world-transition rule violations for one payload."""
    lifters = LIFTERS if lifters is None else lifters
    found = []
    size = envelope.get('size_m') if type(envelope) is dict else None
    if not (type(size) is list and len(size) == 3 and all(type(n) in (int, float) and math.isfinite(n) and n > 0 for n in size)):
        return ['BAD_ENVELOPE']
    if not (type(envelope.get('label')) is str and envelope['label']): found.append('BAD_LABEL')
    if not integer(terms['mass_kg'], 1, 10**9): return found + ['BAD_MASS']
    if not terms['allowed_lifters']: found.append('NO_LIFTER')
    for lifter in terms['allowed_lifters']:
        rule = lifters.get(lifter)
        if rule is None:
            found.append('UNKNOWN_LIFTER')
            continue
        if terms['mass_kg'] > rule['max_payload_kg']: found.append('OVER_MASS_LIMIT')
        if any(a > b for a, b in zip(size, rule['max_envelope_m'])): found.append('OVER_ENVELOPE')
        if rule['draft_m_per_100t'] * terms['mass_kg'] / 100000 > rule['max_draft_m']: found.append('OVER_DRAFT')
    for key in ('pickup', 'delivery'):
        p = terms[key + '_position_m']
        if p[1] != 0: found.append('ZONE_NOT_AT_SEA_LEVEL')
        if terms[key + '_zone'] not in CHART_EXCEPTIONS and max(abs(p[0]), abs(p[2])) + terms['zone_radius_m'] > CHART_RANGE_M:
            found.append('ZONE_OUTSIDE_CHART')
    if math.dist(terms['pickup_position_m'], terms['delivery_position_m']) <= 2 * terms['zone_radius_m']: found.append('ZONES_OVERLAP')
    return found


def definition_problems(payloads=None, envelopes=None, lifters=None):
    """Every (payload, problem) pair across the catalog, including zone clashes."""
    payloads = PAYLOADS if payloads is None else payloads
    envelopes = ENVELOPES if envelopes is None else envelopes
    found = []
    zones = []
    for key, terms in payloads.items():
        if terms['payload_id'] != key or set(terms) != set(TERMS):
            found.append((key, 'BAD_TERMS'))
            continue
        found += [(key, p) for p in payload_problems(terms, envelopes.get(key), lifters)]
        mine = [(terms[k + '_zone'], terms[k + '_position_m'], terms['zone_radius_m']) for k in ('pickup', 'delivery')]
        found += [(key, 'ZONE_OVERLAPS_' + b[0]) for a in mine for b in zones if math.dist(a[1], b[1]) <= a[2] + b[2]]
        zones += mine
    if len({z[0] for z in zones}) != len(zones): found.append(('*', 'DUPLICATE_ZONE'))
    return found


# Fail closed at import: no world may be served from unverified definitions.
if definition_problems():
    raise RuntimeError('heavy payload definitions invalid: %r' % definition_problems())


def identity(value):
    return type(value) is str and 0 < len(value) <= 128


class HeavyStore(PrivateStore):
    """Explicitly provisioned isolated world, using the existing profile/wallet.

    Every adapter/process for a world must open the same file. Initialize never
    modifies existing saves; host authentication selects account, never the client.
    """
    def initialize(self):
        super().initialize()
        with self.connect() as db:
            db.executescript('''
                CREATE TABLE heavy_world(id INTEGER PRIMARY KEY CHECK(id=1), realm TEXT NOT NULL, terms TEXT NOT NULL);
                CREATE TABLE heavy_jobs(id TEXT PRIMARY KEY, account TEXT NOT NULL,
                    ship TEXT NOT NULL, payload TEXT NOT NULL, state TEXT NOT NULL,
                    terms TEXT NOT NULL);
                CREATE UNIQUE INDEX heavy_payload ON heavy_jobs(payload) WHERE state != 'cancelled';
                CREATE UNIQUE INDEX heavy_account ON heavy_jobs(account) WHERE state IN ('pickup','carrying');
                CREATE UNIQUE INDEX heavy_ship ON heavy_jobs(ship) WHERE state IN ('pickup','carrying');
                CREATE TABLE heavy_zones(zone TEXT PRIMARY KEY, job TEXT NOT NULL REFERENCES heavy_jobs(id));
                CREATE TABLE heavy_receipts(account TEXT, action TEXT, intent TEXT NOT NULL,
                    result TEXT NOT NULL, PRIMARY KEY(account,action));
            ''')
            db.execute('INSERT INTO heavy_world VALUES(1,?,?)', (self.realm, encode(WORLD)))

    def _world(self, db):
        """Return this world's offered payload terms; unknown definitions fail closed."""
        row = db.execute('SELECT * FROM heavy_world WHERE id=1').fetchone()
        require(row is not None and row['realm'] == self.realm, 'INCOMPATIBLE_WORLD')
        if row['terms'] == encode(TERMS): return {PAYLOAD: TERMS}  # Step 80-82 world
        require(row['terms'] == encode(WORLD), 'INCOMPATIBLE_WORLD')
        return PAYLOADS

    def snapshot(self, account):
        """Reconnect reads state, never re-applies a receipt or releases a claim."""
        with self.connect() as db:
            db.execute('BEGIN')
            offered = self._world(db)
            row = db.execute('SELECT money, revision, profile FROM profiles WHERE account=?', (account,)).fetchone()
            require(row is not None, 'UNKNOWN_ACCOUNT')
            jobs = [dict(r, terms=json.loads(r['terms'])) for r in db.execute('SELECT * FROM heavy_jobs WHERE account=? ORDER BY rowid', (account,))]
            taken = {r['payload'] for r in db.execute("SELECT payload FROM heavy_jobs WHERE state!='cancelled'")}
            payloads = [dict(terms, **ENVELOPES[key], available=key not in taken) for key, terms in offered.items()]
            profile = json.loads(row['profile'])
            navigation = profile.get('heavy_navigation')
            if navigation is not None:
                validate_navigation(navigation)
                require(navigation['attached'] == any(j['state'] == 'carrying' for j in jobs), 'ATTACHMENT_MISMATCH')
                require(navigation['condition_bp'] == profile['ship']['condition_bp'], 'CONDITION_MISMATCH')
            # terms/available keep describing the original block for older callers.
            return dict(terms=json.loads(encode(TERMS)), available=PAYLOAD not in taken, jobs=jobs,
                        payloads=json.loads(encode(payloads)), lifter=json.loads(encode(LIFTERS[LIFTER])),
                        zones=[dict(r) for r in db.execute('SELECT * FROM heavy_zones ORDER BY zone')],
                        money=row['money'], revision=row['revision'],
                        navigation=navigation)

    def heavy(self, account, request, *, evidence=None, navigation=None, fault=lambda *_: None):
        """Intent has op/action_id/ship_id/payload_id/job_id/expected_revision/realm.

        claim uses job_id == action_id (account-qualified internally). Later
        transitions use the returned job_id. Evidence is a host-only argument,
        never accepted from intent. Exact retries precede revision/evidence checks.
        """
        try:
            require(type(request) is dict and set(request) == {'op', 'action_id', 'ship_id', 'payload_id', 'job_id', 'expected_revision', 'realm'}, 'BAD_REQUEST')
            require(identity(account) and all(identity(request[k]) for k in ('action_id', 'ship_id')) and type(request['job_id']) is str and 0 < len(request['job_id']) <= 2048, 'BAD_ID')
            require(request['realm'] == self.realm, 'WRONG_REALM')
            require(request['op'] in ('claim', 'pickup', 'cancel', 'deliver', 'destroy'), 'BAD_OPERATION')
            require(type(request['payload_id']) is str and integer(request['expected_revision'], 0, MAX_MONEY), 'BAD_REQUEST')
            intent = encode(request)
            with self.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                terms = self._world(db).get(request['payload_id'])
                require(terms is not None, 'BAD_REQUEST')
                payload = terms['payload_id']
                prior = db.execute('SELECT * FROM heavy_receipts WHERE account=? AND action=?', (account, request['action_id'])).fetchone()
                if prior:
                    require(prior['intent'] == intent, 'ID_CONFLICT')
                    return dict(json.loads(prior['result']), duplicate=True)
                require(db.execute('SELECT count(*) FROM heavy_receipts').fetchone()[0] < MAX_ACTIONS, 'HISTORY_FULL')
                row = db.execute('SELECT * FROM profiles WHERE account=?', (account,)).fetchone()
                require(row is not None, 'UNKNOWN_ACCOUNT')
                require(row['revision'] == request['expected_revision'], 'STALE_REVISION')
                profile = json.loads(row['profile'])
                ship = profile['ship']
                require(ship['id'] == request['ship_id'] and ship['definition'] in terms['allowed_lifters'], 'WRONG_LIFTER')
                require(integer(ship['condition_bp'], 0 if request['op'] == 'destroy' else 1, 10000), 'SHIP_UNAVAILABLE')
                require('heavy_navigation' not in profile or navigation is not None, 'NAVIGATION_REQUIRED')
                if navigation is not None:
                    validate_navigation(navigation)
                    require(navigation['condition_bp'] == 0 if request['op'] == 'destroy' else navigation['condition_bp'] > 0, 'SHIP_UNAVAILABLE')
                    profile['heavy_navigation'] = navigation
                    ship['condition_bp'] = navigation['condition_bp']
                    ship['fuel_liters'] = navigation['fuel_liters']
                op = request['op']
                gross = repayment = 0
                if op == 'claim':
                    require(request['job_id'] == request['action_id'], 'BAD_JOB_ID')
                    require(not profile['cargo'] and not any(j.get('state') not in TERMINAL for j in profile['jobs']), 'CARGO_BUSY')
                    require(not payload_problems(terms, ENVELOPES[payload]), 'OVER_LOAD_LIMIT')
                    require(not db.execute("SELECT 1 FROM heavy_jobs WHERE payload=? AND state!='cancelled'", (payload,)).fetchone(), 'PAYLOAD_RESERVED')
                    job_id = encode([account, request['action_id']])
                    require(not db.execute('SELECT 1 FROM heavy_zones WHERE zone IN (?,?)', (terms['pickup_zone'], terms['delivery_zone'])).fetchone(), 'ZONE_RESERVED')
                    db.execute('INSERT INTO heavy_jobs VALUES(?,?,?,?,?,?)', (job_id, account, ship['id'], payload, 'pickup', encode(terms)))
                    db.executemany('INSERT INTO heavy_zones VALUES(?,?)', [(terms[k], job_id) for k in ('pickup_zone', 'delivery_zone')])
                    profile['jobs'].append(dict(id=job_id, family='heavy', payload_id=payload, state='pickup', ship=ship['id']))
                    state = 'pickup'
                else:
                    job_id = request['job_id']
                    job = db.execute('SELECT * FROM heavy_jobs WHERE id=?', (job_id,)).fetchone()
                    require(job is not None and job['account'] == account and job['ship'] == ship['id'], 'JOB_NOT_OWNED')
                    require(job['payload'] == payload, 'JOB_MISMATCH')
                    require(job['terms'] == encode(terms), 'INCOMPATIBLE_WORLD')
                    entry = next((j for j in profile['jobs'] if j.get('id') == job_id and j.get('family') == 'heavy'), None)
                    require(entry is not None and entry['state'] == job['state'], 'JOB_MISMATCH')
                    if op == 'cancel':
                        require(job['state'] == 'pickup', 'CANNOT_CANCEL')
                        state = 'cancelled'
                    elif op == 'pickup':
                        require(job['state'] == 'pickup', 'NOT_AT_PICKUP')
                        self._evidence(evidence, job_id, payload, terms['pickup_zone'], ship['id'])
                        state = 'carrying'
                    elif op == 'destroy':
                        require(job['state'] in ('pickup', 'carrying'), 'JOB_TERMINAL')
                        self._evidence(evidence, job_id, payload, 'destroyed', ship['id'])
                        require(navigation is not None and navigation['condition_bp'] == 0, 'HULL_NOT_DESTROYED')
                        state = 'failed'
                    else:
                        require(job['state'] == 'carrying', 'NOT_CARRYING')
                        self._evidence(evidence, job_id, payload, terms['delivery_zone'], ship['id'])
                        state = 'delivered'
                        gross = terms['reward_minor']
                        debt = profile.get('recovery_debt_minor', 0)
                        require(integer(debt, 0, MAX_MONEY), 'BAD_DEBT')
                        repayment = min(debt, gross // 2)
                        if repayment:
                            profile['recovery_debt_minor'] -= repayment
                    entry['state'] = state
                    db.execute('UPDATE heavy_jobs SET state=? WHERE id=?', (state, job_id))
                    if state in TERMINAL:
                        db.execute('DELETE FROM heavy_zones WHERE job=?', (job_id,))
                if navigation is not None:
                    profile['heavy_navigation'] = dict(navigation, attached=state == 'carrying')
                fault('after_job_write', request)
                money = row['money'] + gross - repayment
                require(integer(money, 0, MAX_MONEY), 'WALLET_LIMIT')
                db.execute('UPDATE profiles SET money=?,revision=revision+1,profile=? WHERE account=?', (money, encode(profile), account))
                fault('after_profile_write', request)
                result = dict(ok=True, job_id=job_id, payload_id=payload, state=state,
                              gross_minor=gross, debt_repayment_minor=repayment,
                              money=money, revision=row['revision'] + 1)
                db.execute('INSERT INTO heavy_receipts VALUES(?,?,?,?)', (account, request['action_id'], intent, encode(result)))
                fault('before_commit', request)
            fault('after_commit', request)
            return result
        except MarketError as error:
            return dict(ok=False, code=str(error))
        except (sqlite3.Error, ValueError, KeyError, TypeError):
            return dict(ok=False, code='HEAVY_UNAVAILABLE', uncertain=True)

    def checkpoint(self, account, revision, navigation):
        """Host-only navigation CAS. Never overwrite an economic transition."""
        try:
            validate_navigation(navigation)
            require(integer(revision, 0, MAX_MONEY), 'BAD_REVISION')
            with self.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                self._world(db)
                row = db.execute('SELECT * FROM profiles WHERE account=?', (account,)).fetchone()
                require(row is not None, 'UNKNOWN_ACCOUNT')
                require(row['revision'] == revision, 'STALE_REVISION')
                profile = json.loads(row['profile'])
                require(profile['ship']['definition'] == LIFTER, 'WRONG_LIFTER')
                carrying = db.execute("SELECT 1 FROM heavy_jobs WHERE account=? AND state='carrying'", (account,)).fetchone() is not None
                require(navigation['attached'] == carrying, 'ATTACHMENT_MISMATCH')
                # Destruction must commit through destroy, with job cleanup.
                active = db.execute("SELECT 1 FROM heavy_jobs WHERE account=? AND state IN ('pickup','carrying')", (account,)).fetchone()
                require(navigation['condition_bp'] > 0 or not active, 'RECOVERY_REQUIRED')
                require(profile['ship']['condition_bp'] > 0 or navigation['condition_bp'] == 0, 'SHIP_UNAVAILABLE')
                profile['heavy_navigation'] = navigation
                profile['ship']['condition_bp'] = navigation['condition_bp']
                profile['ship']['fuel_liters'] = navigation['fuel_liters']
                db.execute('UPDATE profiles SET profile=?,revision=revision+1 WHERE account=?', (encode(profile), account))
            return dict(ok=True, revision=revision+1)
        except MarketError as error:
            return dict(ok=False, code=str(error))
        except (sqlite3.Error, ValueError, KeyError, TypeError):
            return dict(ok=False, code='HEAVY_UNAVAILABLE', uncertain=True)

    @staticmethod
    def _evidence(evidence, job, payload, zone, ship):
        require(evidence == dict(job_id=job, payload_id=payload, zone_id=zone,
                                 ship_id=ship, validated=True), 'HOST_VALIDATION_REQUIRED')


def validate_navigation(value):
    require(type(value) is dict and set(value) == {'position', 'yaw', 'deck_height', 'deck_target', 'fuel_liters', 'condition_bp', 'attached'}, 'BAD_NAVIGATION')
    def finite(n, low, high):
        return type(n) in (int, float) and low <= n <= high and math.isfinite(n)
    require(type(value['position']) is list and len(value['position']) == 3 and all(finite(n, -1000000, 1000000) for n in value['position']), 'BAD_NAVIGATION')
    require(finite(value['yaw'], -math.tau, math.tau) and finite(value['deck_height'], -1, 2.6) and finite(value['deck_target'], -1, 2.6), 'BAD_NAVIGATION')
    require(finite(value['fuel_liters'], 0, 2000) and integer(value['condition_bp'], 0, 10000) and type(value['attached']) is bool, 'BAD_NAVIGATION')
