"""Public market shares the existing PostgreSQL account transaction, never 2PC."""
from pathlib import Path
from psycopg.types.json import Jsonb
from .model import MarketError
from .settlement import initial, MAX_MONEY


def initialize(db, now):
    # Serialize additive migration across service initializers. An existing table
    # with a missing singleton is corruption, never permission to reseed prices.
    db.execute("SELECT pg_advisory_xact_lock(750075)")
    existed = db.execute("SELECT to_regclass('public_authority.oil_market') AS name").fetchone()['name']
    db.execute(Path(__file__).with_name('schema.sql').read_text())
    if existed:
        if db.execute('SELECT state FROM public_authority.oil_market WHERE id=1').fetchone() is None:
            raise MarketError('MARKET_UNAVAILABLE')
    else:
        db.execute('INSERT INTO public_authority.oil_market(id,state) VALUES(1,%s)',
                   (Jsonb(initial('public', now)),))


class Transaction:
    def __init__(self, db):
        self.db = db

    def market(self):
        row = self.db.execute('SELECT state FROM public_authority.oil_market WHERE id=1 FOR UPDATE').fetchone()
        return row['state'] if row else None

    def receipt(self, account, action):
        return self.db.execute('SELECT * FROM public_authority.receipts WHERE account=%s AND action_id=%s', (account, action)).fetchone()

    def settle(self, account, candidate, amount):
        game = self.db.execute('SELECT * FROM public_authority.game WHERE id=1 FOR UPDATE').fetchone()
        if not 0 <= game['money'] - amount <= MAX_MONEY:
            raise MarketError('INSUFFICIENT_RESOURCES')
        self.db.execute('UPDATE public_authority.profiles SET profile=%s,money=money+%s,revision=revision+1 WHERE account=%s', (Jsonb(candidate), amount, account))
        self.db.execute('UPDATE public_authority.game SET money=money-%s WHERE id=1', (amount,))

    def save_market(self, state, event):
        self.db.execute('UPDATE public_authority.oil_market SET state=%s WHERE id=1', (Jsonb(state),))
        self.db.execute('INSERT INTO public_authority.oil_history VALUES(%s,%s)', (event['sequence'], Jsonb(event)))

    def save_receipt(self, account, action, fingerprint, result):
        self.db.execute('INSERT INTO public_authority.receipts VALUES(%s,%s,%s,%s)', (account, action, fingerprint, Jsonb(result)))
        self.db.execute('INSERT INTO public_authority.journal VALUES(%s,%s,%s)', (account, action, result['amount']))
