"""New isolated private stock files only. No public realm or import/fallback."""
import json
import sqlite3
from services.oil_market.private import PrivateStore, Transaction as OilTransaction
from services.oil_market.model import MarketError, integer
from services.oil_market.settlement import encode
from . import shared
from .processing import REFINERY_ID


class SharedPrivateStore(PrivateStore):
    def initialize(self, config=None):
        super().initialize()
        with self.connect() as db:
            db.execute('CREATE TABLE refineries(refinery_id TEXT PRIMARY KEY, state TEXT NOT NULL)')
            db.execute('INSERT INTO refineries VALUES(?,?)', (REFINERY_ID, encode(shared.initial(self.realm, config))))

    def refinery(self, account, request, *, fault=lambda *_: None):
        if request.get('account') != account or request.get('realm') != self.realm:
            return dict(ok=False, code='WRONG_REALM_OR_ACCOUNT')
        try:
            with self.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                row = db.execute('SELECT * FROM profiles WHERE account=?', (account,)).fetchone()
                if row is None: raise MarketError('UNKNOWN_ACCOUNT')
                profile = dict(row, profile=json.loads(row['profile']))
                tx = Transaction(db)
                # Private host clock is persisted and advances only via advance().
                def clock():
                    state = tx.refinery(REFINERY_ID)
                    if state is None: raise MarketError('REFINERY_UNAVAILABLE')
                    return state['time_ms']
                result = shared.execute(tx, self.realm, profile, request, clock, fault)
                fault('before_commit', request)
            fault('after_commit', request)
            return result
        except MarketError as error:
            return dict(ok=False, code=str(error))
        except sqlite3.Error:
            return dict(ok=False, code='REFINERY_UNAVAILABLE', uncertain=request.get('op') in ('refinery_submit', 'refinery_withdraw'))

    def advance(self, elapsed_ms, *, fault=lambda *_: None):
        if not integer(elapsed_ms, 0, 1000): raise MarketError('BAD_REFINERY_TICK')
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            tx = Transaction(db)
            state = tx.refinery(REFINERY_ID)
            if state is None: raise MarketError('REFINERY_UNAVAILABLE')
            shared.validate(state, self.realm)
            shared.advance(state, state['time_ms'] + elapsed_ms)
            shared.validate(state, self.realm)
            tx.save_refinery(REFINERY_ID, state)
            fault('before_commit', {})
        fault('after_commit', {})


class Transaction(OilTransaction):
    def refinery(self, refinery_id):
        row = self.db.execute('SELECT state FROM refineries WHERE refinery_id=?', (refinery_id,)).fetchone()
        return json.loads(row['state']) if row else None

    def save_refinery(self, refinery_id, state):
        self.db.execute('UPDATE refineries SET state=? WHERE refinery_id=?', (encode(state), refinery_id))
