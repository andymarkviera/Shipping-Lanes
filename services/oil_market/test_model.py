import dataclasses
from concurrent.futures import ThreadPoolExecutor
import unittest

from services.oil_market.model import Config, Market, MarketError, PublicView

A = 'port_brindle_quay'
B = 'port_slatewater_works'


class MarketTests(unittest.TestCase):
    def test_worked_integer_prices_and_port_local_pressure(self):
        owner = Market('public')
        buy = owner.quote(A, 'buy', 123, 0)
        sell = owner.quote(B, 'sell', 123, 0)
        self.assertEqual((buy.unit_minor, buy.total_minor), (131, 16113))
        self.assertEqual((sell.unit_minor, sell.total_minor), (169, 20787))
        owner.record_simulated_trade(buy, 0)
        state = owner.snapshot(0)
        self.assertEqual(state['ports'][A]['pressure_barrels'], 123)
        self.assertEqual(state['ports'][B]['pressure_barrels'], 0)

    def test_concurrent_consumption_has_exactly_one_effect(self):
        owner = Market('public')
        q = owner.quote(A, 'buy', 123, 0)
        def consume(_):
            try:
                owner.record_simulated_trade(q, 0)
                return True
            except MarketError as error:
                self.assertEqual(str(error), 'UNKNOWN_OR_CHANGED_QUOTE')
                return False
        with ThreadPoolExecutor(max_workers=8) as pool:
            self.assertEqual(sum(pool.map(consume, range(100))), 1)
        self.assertEqual(owner.snapshot(0)['ports'][A]['pressure_barrels'], 123)

    def test_public_views_share_prices_and_changes(self):
        owner = Market('public')
        a, b = PublicView(owner), PublicView(owner)
        self.assertEqual(a.snapshot(0), b.snapshot(0))
        self.assertEqual(a.quote(A, 'buy', 123, 0).unit_minor,
                         b.quote(A, 'buy', 123, 0).unit_minor)
        self.assertNotEqual(a.quote(A, 'buy', 123, 0).unit_minor,
                            b.quote(B, 'buy', 123, 0).unit_minor)
        owner.record_simulated_trade(a.quote(A, 'buy', 200, 0), 0)
        self.assertEqual(a.snapshot(0), b.snapshot(0))
        self.assertEqual(b.snapshot(0)['ports'][A]['pressure_barrels'], 200)

    def test_private_isolation_and_cross_realm_quotes(self):
        public = Market('public')
        private = Market('private:host')
        other = Market('private:host')
        before = public.snapshot(0)
        q = private.quote(A, 'buy', 200, 0)
        for owner in (public, other):
            with self.assertRaisesRegex(MarketError, 'WRONG_MARKET'):
                owner.record_simulated_trade(q, 0)
        private.record_simulated_trade(q, 0)
        self.assertEqual(before, public.snapshot(0))
        self.assertEqual(other.snapshot(0)['ports'][A]['pressure_barrels'], 0)
        with self.assertRaisesRegex(MarketError, 'WRONG_MARKET'):
            PublicView(private)

    def test_no_public_fallback(self):
        for call in (lambda: PublicView().snapshot(0),
                     lambda: PublicView().quote(A, 'buy', 1, 0)):
            with self.assertRaisesRegex(MarketError, 'MARKET_UNAVAILABLE'):
                call()

    def test_expiry_boundary_and_requote(self):
        owner = Market('public')
        q = owner.quote(A, 'buy', 10, 0)
        with self.assertRaisesRegex(MarketError, 'QUOTE_EXPIRED'):
            owner.record_simulated_trade(q, 20)
        self.assertEqual(owner.snapshot(20)['ports'][A]['pressure_barrels'], 0)
        owner.record_simulated_trade(owner.quote(A, 'buy', 10, 20), 39)
        self.assertEqual(owner.snapshot(39)['ports'][A]['pressure_barrels'], 10)

    def test_frozen_quote_survives_updates_and_no_second_consumption(self):
        owner = Market('public', Config(quote_seconds=120))
        q = owner.quote(A, 'buy', 100, 0)
        owner.record_simulated_trade(owner.quote(A, 'buy', 200, 0), 0)
        owner.snapshot(60)
        self.assertEqual(owner.record_simulated_trade(q, 61), q)
        with self.assertRaisesRegex(MarketError, 'UNKNOWN_OR_CHANGED_QUOTE'):
            owner.record_simulated_trade(q, 61)

    def test_forgery_and_copy_isolation(self):
        offsets = {A: -25, B: 25}
        owner = Market('public', Config(port_offsets=offsets))
        offsets[A] = 500
        state = owner.snapshot(0)
        state['ports'][A]['pressure_barrels'] = 10000
        self.assertEqual(owner.snapshot(0)['ports'][A]['reference_minor'], 125)
        q = owner.quote(A, 'buy', 1, 0)
        for bad in (dataclasses.replace(q, unit_minor=1),
                    dataclasses.replace(q, expires_at=200),
                    dataclasses.replace(q, barrels=200),
                    dataclasses.replace(q, port=B),
                    dataclasses.replace(q, barrels=True),
                    dataclasses.replace(q, total_minor=0)):
            with self.assertRaisesRegex(MarketError, 'UNKNOWN_OR_CHANGED_QUOTE'):
                owner.record_simulated_trade(bad, 0)
        owner.record_simulated_trade(q, 0)

    def test_cadence_catchup_and_monotonic_clock(self):
        a, b = Market('public'), Market('public')
        for owner in (a, b):
            owner.record_simulated_trade(owner.quote(A, 'buy', 200, 0), 0)
        self.assertEqual(a.snapshot(59)['ports'][A]['pressure_barrels'], 200)
        self.assertEqual(a.snapshot(60)['ports'][A]['pressure_barrels'], 100)
        self.assertEqual(a.snapshot(60)['version'], 2)
        self.assertEqual(a.snapshot(180)['ports'], b.snapshot(180)['ports'])
        self.assertEqual(a.snapshot(180)['version'], b.snapshot(180)['version'])
        for bad in (179, True, 180.0, -1, 2**63):
            with self.assertRaisesRegex(MarketError, 'INVALID_TIME'):
                a.snapshot(bad)
        self.assertEqual(a.snapshot(2**63 - 1)['ports'][A]['pressure_barrels'], 0)

    def test_bounded_supply_and_volume(self):
        owner = Market('public', Config(supply_limit_barrels=400, floor_minor=100,
                                      ceiling_minor=180, supply_effect_minor=100))
        for side, expected in [('buy', 400), ('sell', -400)]:
            for _ in range(100):
                q = owner.quote(A, side, 200, 0)
                self.assertTrue(100 <= q.unit_minor <= 180)
                self.assertEqual(q.total_minor, q.unit_minor * 200)
                owner.record_simulated_trade(q, 0)
            self.assertEqual(owner.snapshot(0)['ports'][A]['pressure_barrels'], expected)
        self.assertEqual(owner.snapshot(60)['ports'][A]['pressure_barrels'], -300)
        self.assertEqual(owner.snapshot(240)['ports'][A]['pressure_barrels'], 0)
        self.assertLessEqual(owner.quote(A, 'buy', 1, 240).unit_minor,
                             owner.quote(A, 'buy', 200, 240).unit_minor)
        self.assertGreaterEqual(owner.quote(A, 'sell', 1, 240).unit_minor,
                                owner.quote(A, 'sell', 200, 240).unit_minor)

    def test_invalid_config_and_quantities(self):
        for kwargs in ({'cadence_seconds': 0}, {'quote_seconds': True},
                       {'base_minor': 501}, {'floor_minor': 200},
                       {'port_offsets': {}}, {'port_offsets': {A: 1.5}},
                       {'volume_effect_minor': -1}, {'supply_limit_barrels': 0}):
            with self.assertRaisesRegex(MarketError, 'INVALID_CONFIG'):
                Config(**kwargs)
        owner = Market('public')
        before = owner.snapshot(0)
        for quantity in (True, 1.0, '1', 0, -1, 201, 10**100):
            with self.assertRaisesRegex(MarketError, 'INVALID_QUANTITY'):
                owner.quote(A, 'buy', quantity, 0)
        for port, side in [('unknown', 'buy'), (A, 'gift')]:
            with self.assertRaisesRegex(MarketError, 'INVALID_MARKET_REQUEST'):
                owner.quote(port, side, 1, 0)
        self.assertEqual(before, owner.snapshot(0))

    def test_quote_limit_prunes_expired(self):
        owner = Market('public', Config(max_open_quotes=1))
        q = owner.quote(A, 'buy', 1, 0)
        with self.assertRaisesRegex(MarketError, 'QUOTE_LIMIT'):
            owner.quote(A, 'buy', 1, 19)
        owner.quote(A, 'buy', 1, 20)
        with self.assertRaisesRegex(MarketError, 'QUOTE_EXPIRED'):
            owner.record_simulated_trade(q, 20)

    def test_shared_owner_serializes_threads(self):
        owner = Market('public')
        def trade(_):
            owner.record_simulated_trade(PublicView(owner).quote(A, 'buy', 1, 0), 0)
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(trade, range(500)))
        snapshot = owner.snapshot(0)
        self.assertEqual(snapshot['version'], 500)
        self.assertEqual(snapshot['ports'][A]['pressure_barrels'], 500)


if __name__ == '__main__':
    unittest.main()
