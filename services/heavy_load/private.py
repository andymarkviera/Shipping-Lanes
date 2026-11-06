"""Step 80 private-world job authority; called only by the trusted host.

No player RPC, public fallback, timer expiry or physics implementation. The host
supplies pickup/delivery evidence after checking its authoritative simulation.
"""
import json
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
MAX_ACTIONS = 10000
TERMINAL = ('delivered', 'abandoned', 'cancelled', 'canceled', 'failed')


def require(value, code):
    if not value:
        raise MarketError(code)


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
            db.execute('INSERT INTO heavy_world VALUES(1,?,?)', (self.realm, encode(TERMS)))

    def _world(self, db):
        row = db.execute('SELECT * FROM heavy_world WHERE id=1').fetchone()
        require(row is not None and row['realm'] == self.realm and row['terms'] == encode(TERMS), 'INCOMPATIBLE_WORLD')

    def snapshot(self, account):
        """Reconnect reads state, never re-applies a receipt or releases a claim."""
        with self.connect() as db:
            db.execute('BEGIN')
            self._world(db)
            row = db.execute('SELECT money, revision FROM profiles WHERE account=?', (account,)).fetchone()
            require(row is not None, 'UNKNOWN_ACCOUNT')
            jobs = [dict(r, terms=json.loads(r['terms'])) for r in db.execute('SELECT * FROM heavy_jobs WHERE account=? ORDER BY rowid', (account,))]
            occupied = db.execute("SELECT 1 FROM heavy_jobs WHERE payload=? AND state!='cancelled'", (PAYLOAD,)).fetchone()
            return dict(terms=json.loads(encode(TERMS)), available=not occupied, jobs=jobs,
                        zones=[dict(r) for r in db.execute('SELECT * FROM heavy_zones ORDER BY zone')], **dict(row))

    def heavy(self, account, request, *, evidence=None, fault=lambda *_: None):
        """Intent has op/action_id/ship_id/payload_id/job_id/expected_revision/realm.

        claim uses job_id == action_id (account-qualified internally). Later
        transitions use the returned job_id. Evidence is a host-only argument,
        never accepted from intent. Exact retries precede revision/evidence checks.
        """
        try:
            require(type(request) is dict and set(request) == {'op', 'action_id', 'ship_id', 'payload_id', 'job_id', 'expected_revision', 'realm'}, 'BAD_REQUEST')
            require(identity(account) and all(identity(request[k]) for k in ('action_id', 'ship_id')) and type(request['job_id']) is str and 0 < len(request['job_id']) <= 2048, 'BAD_ID')
            require(request['realm'] == self.realm, 'WRONG_REALM')
            require(request['op'] in ('claim', 'pickup', 'cancel', 'deliver'), 'BAD_OPERATION')
            require(request['payload_id'] == PAYLOAD and integer(request['expected_revision'], 0, MAX_MONEY), 'BAD_REQUEST')
            intent = encode(request)
            with self.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                self._world(db)
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
                require(ship['id'] == request['ship_id'] and ship['definition'] in TERMS['allowed_lifters'], 'WRONG_LIFTER')
                require(integer(ship['condition_bp'], 1, 10000), 'SHIP_UNAVAILABLE')
                op = request['op']
                gross = repayment = 0
                if op == 'claim':
                    require(request['job_id'] == request['action_id'], 'BAD_JOB_ID')
                    require(not profile['cargo'] and not any(j.get('state') not in TERMINAL for j in profile['jobs']), 'CARGO_BUSY')
                    require(not db.execute("SELECT 1 FROM heavy_jobs WHERE payload=? AND state!='cancelled'", (PAYLOAD,)).fetchone(), 'PAYLOAD_RESERVED')
                    job_id = encode([account, request['action_id']])
                    require(not db.execute('SELECT 1 FROM heavy_zones WHERE zone IN (?,?)', (TERMS['pickup_zone'], TERMS['delivery_zone'])).fetchone(), 'ZONE_RESERVED')
                    db.execute('INSERT INTO heavy_jobs VALUES(?,?,?,?,?,?)', (job_id, account, ship['id'], PAYLOAD, 'pickup', encode(TERMS)))
                    db.executemany('INSERT INTO heavy_zones VALUES(?,?)', [(TERMS[k], job_id) for k in ('pickup_zone', 'delivery_zone')])
                    profile['jobs'].append(dict(id=job_id, family='heavy', payload_id=PAYLOAD, state='pickup', ship=ship['id']))
                    state = 'pickup'
                else:
                    job_id = request['job_id']
                    job = db.execute('SELECT * FROM heavy_jobs WHERE id=?', (job_id,)).fetchone()
                    require(job is not None and job['account'] == account and job['ship'] == ship['id'], 'JOB_NOT_OWNED')
                    require(job['terms'] == encode(TERMS), 'INCOMPATIBLE_WORLD')
                    entry = next((j for j in profile['jobs'] if j.get('id') == job_id and j.get('family') == 'heavy'), None)
                    require(entry is not None and entry['state'] == job['state'], 'JOB_MISMATCH')
                    if op == 'cancel':
                        require(job['state'] == 'pickup', 'CANNOT_CANCEL')
                        state = 'cancelled'
                    elif op == 'pickup':
                        require(job['state'] == 'pickup', 'NOT_AT_PICKUP')
                        self._evidence(evidence, job_id, TERMS['pickup_zone'], ship['id'])
                        state = 'carrying'
                    else:
                        require(job['state'] == 'carrying', 'NOT_CARRYING')
                        self._evidence(evidence, job_id, TERMS['delivery_zone'], ship['id'])
                        state = 'delivered'
                        gross = TERMS['reward_minor']
                        debt = profile.get('recovery_debt_minor', 0)
                        require(integer(debt, 0, MAX_MONEY), 'BAD_DEBT')
                        repayment = min(debt, gross // 2)
                        if repayment:
                            profile['recovery_debt_minor'] -= repayment
                    entry['state'] = state
                    db.execute('UPDATE heavy_jobs SET state=? WHERE id=?', (state, job_id))
                    if state in TERMINAL:
                        db.execute('DELETE FROM heavy_zones WHERE job=?', (job_id,))
                fault('after_job_write', request)
                money = row['money'] + gross - repayment
                require(integer(money, 0, MAX_MONEY), 'WALLET_LIMIT')
                db.execute('UPDATE profiles SET money=?,revision=revision+1,profile=? WHERE account=?', (money, encode(profile), account))
                fault('after_profile_write', request)
                result = dict(ok=True, job_id=job_id, payload_id=PAYLOAD, state=state,
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

    @staticmethod
    def _evidence(evidence, job, zone, ship):
        require(evidence == dict(job_id=job, payload_id=PAYLOAD, zone_id=zone,
                                 ship_id=ship, validated=True), 'HOST_VALIDATION_REQUIRED')
