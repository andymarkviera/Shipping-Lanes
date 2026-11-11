"""Step 86: the saved balance table, its tuned inputs and each family's role."""
import re
import unittest
import cargo_balance as balance

# (earned, net, net per minute) in minor credits, worked by hand for CARGO_BALANCE.md.
EXPECTED = {
    ('containers', '1 container'): (25000, 20865, 2330),
    ('containers', '3 containers'): (75000, 70865, 7770),
    ('bulk', 'grain'): (79193, 75058, 8306),
    ('bulk', 'ore'): (118790, 114655, 12688),
    ('gas', 'lng'): (98625, 94490, 10456),
    ('gas', 'oxygen'): (147938, 143803, 15913),
    ('oil', 'crude one way'): (6000, 1865, 210),
    ('cargo_fuel', 'crude out, refine, fuel back'): (17660, 8105, 350),
}


class CargoBalanceTest(unittest.TestCase):
    def setUp(self):
        self.rows = {(r['family'], r['voyage']): r for r in balance.rows()}

    def test_measured_rows_match_saved_table(self):
        document = (balance.ROOT / 'CARGO_BALANCE.md').read_text(encoding='utf-8')
        for key, expected in EXPECTED.items():
            row = self.rows[key]
            self.assertEqual((row['earned'], row['net'], row['per_minute']), expected, key)
            for value in expected:
                self.assertIn(balance.credits(value), document, key)

    def test_rates_match_seeded_fixture(self):
        source = (balance.ROOT / 'features/cargo/bulk_service.gd').read_text(encoding='utf-8')
        for family, rates in (('bulk', balance.BULK_RATES), ('gas', balance.GAS_RATES)):
            for cargo, rate in rates.items():
                found = re.search(r'"cargo_%s_%s": (\d+)' % (family, cargo), source)
                self.assertEqual(int(found.group(1)), rate, cargo)

    def test_each_family_has_a_role(self):
        per_minute = {key: row['per_minute'] for key, row in self.rows.items()}
        for key in EXPECTED:
            self.assertGreater(self.rows[key]['net'], 0, key)
        # Starter family needs no cargo capital; dedicated hulls out-earn it per trip.
        self.assertEqual(self.rows[('containers', '3 containers')]['capital'], 0)
        self.assertGreater(per_minute[('bulk', 'grain')], per_minute[('containers', '3 containers')])
        self.assertGreater(per_minute[('gas', 'lng')], per_minute[('bulk', 'grain')])
        # Refining and hauling the fuel back must beat selling the crude and returning empty.
        buy, sell, fuel, fee = balance.oil()
        self.assertGreater(fuel - fee - balance.BACK_COST, sell)
        self.assertGreater(self.rows[('cargo_fuel', 'crude out, refine, fuel back')]['net'],
                           self.rows[('oil', 'crude one way')]['net'])
        # Heavy rewards are listed without invented travel figures.
        heavy = [row for row in self.rows.values() if row['family'] == 'heavy']
        self.assertEqual(sorted(row['earned'] for row in heavy), [45000, 70000, 100000])
        self.assertTrue(all(row['per_minute'] is None for row in heavy))


if __name__ == '__main__': unittest.main()
