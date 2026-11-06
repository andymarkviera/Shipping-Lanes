"""Isolated private-host adapter. Explicit provisioning; never a public fallback."""
from contextlib import contextmanager
import json
import sqlite3
import time
from pathlib import Path
from .model import MarketError
from .settlement import encode, execute, initial, MAX_MONEY


class PrivateStore:
    def __init__(self, path, realm):
        if type(realm) is not str or not realm.startswith('private:') or not 8 < len(realm) <= 128:
            raise MarketError('WRONG_REALM')
        self.path, self.realm = str(Path(path).resolve()), realm

    @contextmanager
    def connect(self):
        # Missing storage must fail closed, never silently create a fresh economy.
        db = sqlite3.connect(Path(self.path).as_uri() + '?mode=rw', uri=True, timeout=3)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def initialize(self):
        # Operator only. Exclusive creation protects existing private saves.
        with open(self.path, 'xb'):
            pass
        with self.connect() as db:
            db.executescript('''
                CREATE TABLE market(id INTEGER PRIMARY KEY, state TEXT NOT NULL);
                CREATE TABLE profiles(account TEXT PRIMARY KEY, money INTEGER NOT NULL,
                                      revision INTEGER NOT NULL, profile TEXT NOT NULL);
                CREATE TABLE receipts(account TEXT, action_id TEXT, fingerprint TEXT, result TEXT,
                                      PRIMARY KEY(account, action_id));
                CREATE TABLE history(sequence INTEGER PRIMARY KEY, event TEXT NOT NULL);
                CREATE TABLE game(id INTEGER PRIMARY KEY, money INTEGER NOT NULL);
                INSERT INTO game VALUES(1,1000000);
            ''')
            db.execute('INSERT INTO market VALUES(1,?)', (encode(initial(self.realm, int(time.time()))),))

    def provision(self, account, profile, money):
        """Trusted host enrollment only, never a client operation."""
        if type(money) is not int or not 0 <= money <= MAX_MONEY:
            raise MarketError('BAD_INTEGER')
        with self.connect() as db:
            db.execute('INSERT INTO profiles VALUES(?,?,0,?)', (account, money, encode(profile)))

    def execute(self, account, request, *, clock=lambda: int(time.time()), fault=lambda *_: None):
        # Host authentication binds account; payload cannot select another owner.
        if request.get('account') != account or request.get('realm') != self.realm:
            return dict(ok=False, code='WRONG_REALM_OR_ACCOUNT')
        try:
            with self.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                row = db.execute('SELECT * FROM profiles WHERE account=?', (account,)).fetchone()
                if row is None:
                    raise MarketError('UNKNOWN_ACCOUNT')
                profile = dict(row)
                profile['profile'] = json.loads(profile['profile'])
                result = execute(Transaction(db), self.realm, profile, request, clock, fault)
                fault('before_commit', request)
            fault('after_commit', request)
            return result
        except MarketError as error:
            return dict(ok=False, code=str(error))
        except sqlite3.Error:
            return dict(ok=False, code='MARKET_UNAVAILABLE')


class Transaction:
    def __init__(self, db):
        self.db = db

    def market(self):
        row = self.db.execute('SELECT state FROM market WHERE id=1').fetchone()
        return json.loads(row['state']) if row else None

    def receipt(self, account, action):
        row = self.db.execute('SELECT * FROM receipts WHERE account=? AND action_id=?', (account, action)).fetchone()
        return dict(fingerprint=row['fingerprint'], result=json.loads(row['result'])) if row else None

    def latest_receipt(self, account):
        row = self.db.execute("SELECT result FROM receipts WHERE account=? "
                              "AND json_extract(result, '$.code')='OIL_SETTLED' ORDER BY rowid DESC LIMIT 1", (account,)).fetchone()
        return json.loads(row['result']) if row else {}

    def settle(self, account, candidate, amount):
        money = self.db.execute('SELECT money FROM game WHERE id=1').fetchone()['money']
        if not 0 <= money - amount <= MAX_MONEY:
            raise MarketError('INSUFFICIENT_RESOURCES')
        self.db.execute('UPDATE profiles SET profile=?,money=money+?,revision=revision+1 WHERE account=?', (encode(candidate), amount, account))
        self.db.execute('UPDATE game SET money=money-? WHERE id=1', (amount,))

    def save_market(self, state, event):
        self.db.execute('UPDATE market SET state=? WHERE id=1', (encode(state),))
        self.db.execute('INSERT INTO history VALUES(?,?)', (event['sequence'], encode(event)))

    def save_receipt(self, account, action, fingerprint, result):
        self.db.execute('INSERT INTO receipts VALUES(?,?,?,?)', (account, action, fingerprint, encode(result)))
