"""One canonical row per physical refinery, in the public profile database."""
from pathlib import Path
from psycopg.types.json import Jsonb
from services.oil_market.postgres import Transaction as OilTransaction
from services.oil_market.model import MarketError
from .shared import initial, validate
from .processing import REFINERY_ID


def initialize(db):
    db.execute('SELECT pg_advisory_xact_lock(780078)')
    existed = db.execute("SELECT to_regclass('public_authority.refineries') AS name").fetchone()['name']
    db.execute(Path(__file__).with_name('schema.sql').read_text())
    if existed:
        row = db.execute('SELECT state FROM public_authority.refineries WHERE refinery_id=%s', (REFINERY_ID,)).fetchone()
        if row is None: raise MarketError('REFINERY_UNAVAILABLE')
        validate(row['state'], 'public')
    else:
        db.execute('INSERT INTO public_authority.refineries VALUES(%s,%s)', (REFINERY_ID, Jsonb(initial('public'))))


class Transaction(OilTransaction):
    def refinery(self, refinery_id):
        row = self.db.execute('SELECT state FROM public_authority.refineries WHERE refinery_id=%s FOR UPDATE', (refinery_id,)).fetchone()
        return row['state'] if row else None

    def save_refinery(self, refinery_id, state):
        self.db.execute('UPDATE public_authority.refineries SET state=%s WHERE refinery_id=%s', (Jsonb(state), refinery_id))
