"""Step 84 cargo compatibility matrix for the service-side cargo families.

Oil, cargo fuel and heavy lifting use one profile, one wallet and one revision
counter. Here they share one isolated SQLite world: each family completes its
own voyage, and a wrong hull or another family's unfinished cargo is refused
without changing durable state. Containers, bulk and gas are GDScript
authorities and are covered by tools/cargo_matrix_probe.gd.

Run: python -m unittest services.test_cargo_matrix
"""
import json
import sqlite3
import tempfile
import time
import unittest
from pathlib import Path
from services.heavy_load.private import HeavyStore, PAYLOAD, TERMS, LIFTER
from services.refinery.private import SharedPrivateStore
from services.refinery.processing import REFINERY_ID, PORT_ID
from services.refinery.cargo_fuel import SALE_PORT

REALM = 'private:cargo-matrix'
SHIP_ID = 'matrix-ship'
OIL_SHIP = 'ship_oil_prototype_01'
OTHER_SHIPS = ('ship_starter_container_01', 'ship_bulk_prototype_01', 'ship_gas_prototype_01')
MODULE = 'payload_offshore_module_01'
BUY_PORT, SELL_PORT = 'port_brindle_quay', 'port_slatewater_works'
TABLES = ('profiles', 'game', 'market', 'refineries', 'receipts',
          'heavy_jobs', 'heavy_zones', 'heavy_receipts')


class World(HeavyStore, SharedPrivateStore):
    """Test fixture only: heavy tables beside the oil/refinery tables in one file."""


def fault(stage, error=RuntimeError):
    def hook(at, _):
        if at == stage: raise error('matrix fault')
    return hook


class CargoMatrixTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = World(Path(self.temp.name)/'world.sqlite', REALM)
        self.store.initialize()
        self.store.provision('captain', dict(ship=dict(id=SHIP_ID, definition=OIL_SHIP, condition_bp=10000),
                                             cargo=[], jobs=[], delivered=[]), 100000)
        self.now = int(time.time())

    def tearDown(self):
        self.temp.cleanup()

    # --- durable state -------------------------------------------------
    def row(self):
        with self.store.connect() as db:
            return db.execute('SELECT money, revision, profile FROM profiles WHERE account=?', ('captain',)).fetchone()

    def money(self): return self.row()['money']
    def revision(self): return self.row()['revision']
    def profile(self): return json.loads(self.row()['profile'])

    def durable(self):
        with self.store.connect() as db:
            return [list(map(tuple, db.execute('SELECT * FROM ' + table))) for table in TABLES]

    def use_hull(self, definition):
        """Trusted fixture edit, as in the family tests: same ship ID, other definition."""
        data = self.profile()
        data['ship']['definition'] = definition
        with self.store.connect() as db:
            db.execute('UPDATE profiles SET profile=? WHERE account=?', (json.dumps(data), 'captain'))

    # --- oil market ----------------------------------------------------
    def send(self, request, **kw):
        return self.store.execute('captain', request, clock=lambda: self.now, **kw)

    def oil(self, op, **extra):
        return dict(realm=REALM, op=op, account='captain', epoch=1, generation=1, **extra)

    def oil_quote(self, side='buy', barrels=100, lot=''):
        return self.send(self.oil('oil_quote', port_id=BUY_PORT if side == 'buy' else SELL_PORT,
                                  side=side, barrels=barrels, lot_id=lot))

    def accept(self, quote, action):
        return self.oil('oil_accept', action_id=action, expected_revision=self.revision(),
                        quote_id=quote['id'], quote_version=quote['version'], port_id=quote['port'])

    def buy_crude(self, action, barrels=100):
        quoted = self.oil_quote(barrels=barrels)
        self.assertTrue(quoted['ok'], quoted)
        request = self.accept(quoted['quote'], action)
        result = self.send(request)
        self.assertTrue(result['ok'], result)
        return quoted['quote'], request

    # --- refinery and cargo fuel ---------------------------------------
    def ref(self, op, **extra):
        return dict(realm=REALM, account='captain', epoch=1, generation=1, refinery_id=REFINERY_ID, op=op, **extra)

    def refinery(self, request, **kw):
        return self.store.refinery('captain', request, **kw)

    def stage_cargo_fuel(self, prefix):
        """Buy 100 barrels, refine all of it and pay for a 70000 mbbl collection."""
        crude, _ = self.buy_crude(prefix + '-buy')
        submit = self.ref('refinery_submit', action_id=prefix + '-submit', expected_revision=self.revision(),
                          lot_id=crude['id'], input_millibarrels=100000, port_id=PORT_ID)
        self.assertTrue(self.refinery(submit)['ok'])
        for _ in range(100): self.store.advance(1000)
        fee = self.refinery(self.ref('refinery_quote', millibarrels=70000, port_id=PORT_ID))
        self.assertTrue(fee['ok'], fee)
        withdraw = self.ref('refinery_withdraw', action_id=prefix + '-withdraw', expected_revision=self.revision(),
                            quote_id=fee['quote']['id'], port_id=PORT_ID)
        self.assertTrue(self.refinery(withdraw)['ok'])
        self.assertEqual(self.profile()['cargo'], [])
        return prefix + '-withdraw'

    def load(self, action, collection, units):
        return self.ref('refinery_load', action_id=action, expected_revision=self.revision(),
                        collection_id=collection, millibarrels=units, port_id=PORT_ID)

    def sale(self, action, lot, units):
        return self.ref('refinery_sell', action_id=action, expected_revision=self.revision(),
                        lot_id=lot, millibarrels=units, port_id=SALE_PORT)

    # --- heavy lifting -------------------------------------------------
    def heavy(self, request, **kw):
        return self.store.heavy('captain', request, **kw)

    def lift(self, op, action, job=None, payload=PAYLOAD):
        return dict(op=op, action_id=action, job_id=job or action, expected_revision=self.revision(),
                    ship_id=SHIP_ID, payload_id=payload, realm=REALM)

    def evidence(self, job, zone, payload=PAYLOAD):
        return dict(job_id=job, payload_id=payload, ship_id=SHIP_ID, validated=True, zone_id=zone)

    # --- tests ---------------------------------------------------------
    def test_every_hull_against_every_service(self):
        collection = self.stage_cargo_fuel('stage')
        attempts = dict(
            oil=lambda: self.oil_quote(barrels=1),
            cargo_fuel=lambda: self.refinery(self.load('matrix-load', collection, 1)),
            heavy=lambda: self.heavy(self.lift('claim', 'matrix-claim')))
        refusal = dict(oil='NO_OIL_CAPACITY', cargo_fuel='NO_CARGO_FUEL_CAPACITY', heavy='WRONG_LIFTER')
        valid = {OIL_SHIP: ('oil', 'cargo_fuel'), LIFTER: ('heavy',)}
        for hull in OTHER_SHIPS + (LIFTER, OIL_SHIP):
            self.use_hull(hull)
            for family, attempt in attempts.items():
                if family in valid.get(hull, ()): continue
                with self.subTest(hull=hull, family=family):
                    before = self.durable()
                    result = attempt()
                    self.assertFalse(result['ok'], result)
                    self.assertEqual(result.get('code'), refusal[family], result)
                    self.assertEqual(self.durable(), before)
        # Every valid cell, on the hull that owns it.
        self.use_hull(OIL_SHIP)
        self.assertTrue(self.oil_quote(barrels=1)['ok'])
        self.assertTrue(self.refinery(self.load('matrix-load', collection, 70000))['ok'])
        self.assertTrue(self.refinery(self.sale('matrix-sale', 'matrix-load', 70000))['ok'])
        self.use_hull(LIFTER)
        self.assertTrue(self.heavy(self.lift('claim', 'matrix-claim'))['ok'])

    def test_each_family_completes_its_voyage_in_one_world(self):
        # Cargo fuel: capacity and collection limits, interrupted load, partial sales.
        collection = self.stage_cargo_fuel('fuel')
        start = self.money()
        for units, code in ((200001, 'CAPACITY_EXCEEDED'), (70001, 'INSUFFICIENT_COLLECTION')):
            before = self.durable()
            self.assertEqual(self.refinery(self.load('fuel-load', collection, units))['code'], code)
            self.assertEqual(self.durable(), before)
        load = self.load('fuel-load', collection, 70000)
        before = self.durable()
        with self.assertRaises(RuntimeError): self.refinery(load, fault=fault('before_commit'))
        self.assertEqual(self.durable(), before)
        with self.assertRaises(RuntimeError): self.refinery(load, fault=fault('after_commit'))
        self.assertTrue(self.refinery(load)['duplicate'])
        self.assertEqual(self.money(), start)
        # Unfinished cargo fuel blocks the other families, whichever hull asks.
        self.assertEqual(self.oil_quote(barrels=1)['code'], 'CARGO_BUSY')
        self.use_hull(LIFTER)
        self.assertEqual(self.heavy(self.lift('claim', 'early'))['code'], 'CARGO_BUSY')
        self.use_hull(OIL_SHIP)
        self.assertEqual(self.refinery(self.sale('fuel-over', 'fuel-load', 70001))['code'], 'INSUFFICIENT_CARGO')
        paid = 0
        for index, units in enumerate((1, 999, 12345, 56655)):
            sale = self.sale('fuel-sale%d' % index, 'fuel-load', units)
            result = self.refinery(sale)
            self.assertTrue(result['ok'], result)
            paid += result['amount']
            wallet = self.money()
            self.assertTrue(self.refinery(sale)['duplicate'])
            self.assertEqual(self.money(), wallet)
        self.assertEqual(paid, 15400)  # 70 barrels at 220, rounded once over the whole lot
        self.assertEqual(self.money(), start + paid)
        self.assertEqual(self.profile()['cargo'], [])
        self.assertEqual(self.refinery(self.sale('fuel-again', 'fuel-load', 1))['code'], 'CARGO_NOT_OWNED')

        # Oil: full capacity, over-quantity, interrupted sale, partial sales.
        start = self.money()
        self.assertEqual(self.oil_quote(barrels=201)['code'], 'INVALID_MARKET_REQUEST')
        crude, buy = self.buy_crude('oil-buy', 200)
        self.assertTrue(self.send(buy)['duplicate'])
        self.assertEqual(self.money(), start - crude['total_minor'])
        self.assertEqual(self.oil_quote(barrels=1)['code'], 'CARGO_BUSY')
        self.use_hull(LIFTER)
        self.assertEqual(self.heavy(self.lift('claim', 'early-again'))['code'], 'CARGO_BUSY')
        self.use_hull(OIL_SHIP)
        cost = proceeds = 0
        for index, barrels in enumerate((1, 66, 133)):
            quoted = self.oil_quote('sell', barrels, crude['id'])
            self.assertTrue(quoted['ok'], quoted)
            request = self.accept(quoted['quote'], 'oil-sale%d' % index)
            if index == 0:
                before = self.durable()
                with self.assertRaises(RuntimeError): self.send(request, fault=fault('before_commit'))
                self.assertEqual(self.durable(), before)
            result = self.send(request)
            self.assertTrue(result['ok'], result)
            cost += result['lot']['allocated_cost_minor']
            proceeds += result['amount']
            wallet = self.money()
            self.assertTrue(self.send(request)['duplicate'])
            self.assertEqual(self.money(), wallet)
        self.assertEqual(cost, crude['total_minor'])  # partial cost allocation loses nothing
        self.assertEqual(self.money(), start - crude['total_minor'] + proceeds)
        self.assertEqual(self.profile()['cargo'], [])
        self.assertEqual(self.oil_quote('sell', 1, crude['id'])['code'], 'CARGO_NOT_OWNED')

        # Heavy lifting: cancelled claim, one active job, interrupted pickup, single payout.
        self.use_hull(LIFTER)
        start = self.money()
        dropped = self.heavy(self.lift('claim', 'heavy-dropped', payload=MODULE))
        self.assertTrue(dropped['ok'], dropped)
        self.assertEqual(self.heavy(self.lift('cancel', 'heavy-cancel', dropped['job_id'], MODULE))['state'], 'cancelled')
        claim = self.lift('claim', 'heavy-claim')
        claimed = self.heavy(claim)
        self.assertTrue(claimed['ok'], claimed)
        job = claimed['job_id']
        self.assertTrue(self.heavy(claim)['duplicate'])
        self.assertEqual(self.heavy(self.lift('claim', 'heavy-second', payload=MODULE))['code'], 'CARGO_BUSY')
        self.use_hull(OIL_SHIP)
        self.assertEqual(self.oil_quote(barrels=1)['code'], 'CARGO_BUSY')
        self.use_hull(LIFTER)
        pickup = self.lift('pickup', 'heavy-pickup', job)
        at_pickup = self.evidence(job, TERMS['pickup_zone'])
        before = self.durable()
        lost = self.heavy(pickup, evidence=at_pickup, fault=fault('before_commit', sqlite3.OperationalError))
        self.assertFalse(lost['ok'])
        self.assertEqual(self.durable(), before)
        self.assertEqual(self.heavy(pickup)['code'], 'HOST_VALIDATION_REQUIRED')
        self.assertTrue(self.heavy(pickup, evidence=at_pickup)['ok'])
        deliver = self.lift('deliver', 'heavy-deliver', job)
        self.assertEqual(self.heavy(deliver, evidence=at_pickup)['code'], 'HOST_VALIDATION_REQUIRED')
        done = self.heavy(deliver, evidence=self.evidence(job, TERMS['delivery_zone']))
        self.assertTrue(done['ok'], done)
        self.assertEqual((done['state'], done['gross_minor']), ('delivered', TERMS['reward_minor']))
        self.assertTrue(self.heavy(deliver)['duplicate'])
        self.assertEqual(self.money(), start + TERMS['reward_minor'])

        # The earlier families still work, and all three views agree on one wallet.
        self.use_hull(OIL_SHIP)
        crude, _ = self.buy_crude('oil-after-heavy', 1)
        quoted = self.oil_quote('sell', 1, crude['id'])
        self.assertTrue(quoted['ok'], quoted)
        self.assertTrue(self.send(self.accept(quoted['quote'], 'oil-after-heavy-sale'))['ok'])
        wallet = self.money()
        self.assertEqual(self.send(self.oil('oil_snapshot'))['money'], wallet)
        self.assertEqual(self.refinery(self.ref('refinery_snapshot'))['money'], wallet)
        snapshot = self.store.snapshot('captain')
        self.assertEqual(snapshot['money'], wallet)
        self.assertEqual([j['state'] for j in snapshot['jobs']], ['cancelled', 'delivered'])
        self.assertEqual(self.profile()['cargo'], [])

    def test_action_id_cannot_be_reused_by_another_family(self):
        crude, buy = self.buy_crude('shared-id')
        clash = self.ref('refinery_submit', action_id='shared-id', expected_revision=self.revision(),
                         lot_id=crude['id'], input_millibarrels=1000, port_id=PORT_ID)
        before = self.durable()
        self.assertEqual(self.refinery(clash)['code'], 'ID_CONFLICT')
        self.assertEqual(self.durable(), before)
        self.assertTrue(self.send(buy)['duplicate'])
        self.assertEqual(self.durable(), before)


if __name__ == '__main__': unittest.main()
