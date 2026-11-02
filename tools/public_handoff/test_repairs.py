"""Portable unit checks; these do not replace real PostgreSQL/HTTPS gates."""
import copy
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'services/public_authority'))
import repairs
import wear


class RepairsTest(unittest.TestCase):
    def setUp(self):
        self.profile = dict(ship=dict(definition='ship_starter_container_01', condition_bp=7555,
                                     wear_fraction_bp=0.75, fuel_liters=456), jobs=[], cargo=[{'id': 'kept'}])
        self.original = copy.deepcopy(self.profile)
        self.request = dict(port_id='port_brindle_quay', condition_bp=7555, cost_minor=6113)

    def reject(self, code, wallet=20000):
        before = copy.deepcopy(self.profile)
        result, candidate, amount, _ = repairs.transition(self.profile, self.request, wallet)
        self.assertEqual((result, amount), (code, 0))
        self.assertEqual(candidate, before)
        self.assertEqual(self.profile, before)

    def test_full_repair_exact_debit_preserves_other_state(self):
        code, candidate, amount, _ = repairs.transition(self.profile, self.request, 6113)
        self.assertEqual((code, amount), ('REPAIRED', -6113))
        self.assertEqual(candidate['ship']['condition_bp'], 10000)
        self.assertEqual(candidate['ship']['wear_fraction_bp'], 0)
        self.assertEqual(candidate['ship']['fuel_liters'], 456)
        self.assertEqual(candidate['cargo'], self.profile['cargo'])
        self.assertEqual(self.profile, self.original)
        self.profile = candidate
        self.reject('NO_REPAIR_NEEDED')

    def test_every_condition_rounds_once_and_never_overfills(self):
        for condition in range(1, 10000):
            self.profile['ship']['condition_bp'] = condition
            quote = repairs.quote(self.profile['ship'])
            expected = ((10000-condition)*25000+9999)//10000
            self.assertEqual(quote['cost_minor'], expected)
            self.request.update(condition_bp=condition, cost_minor=expected)
            _, candidate, debit, _ = repairs.transition(self.profile, self.request, 25000)
            self.assertEqual(candidate['ship']['condition_bp'], 10000)
            self.assertEqual(debit, -expected)

    def test_per_ship_configuration(self):
        with patch.dict(repairs.FULL_COSTS, {'fixture_ship': 12345}):
            self.profile['ship'].update(definition='fixture_ship', condition_bp=9999)
            self.assertEqual(repairs.quote(self.profile['ship'])['cost_minor'], 2)

    def test_insufficient_funds(self): self.reject('INSUFFICIENT_FUNDS', 6112)
    def test_wrong_port(self):
        self.request['port_id'] = 'ocean'
        self.reject('NO_REPAIR_SERVICE')
    def test_loading(self):
        self.profile['jobs'] = [{'state': 'loading'}]
        self.reject('LOADING_PENDING')
    def test_stale_condition_and_price(self):
        for field in ('condition_bp', 'cost_minor'):
            old = self.request[field]
            self.request[field] -= 1
            self.reject('QUOTE_CHANGED')
            self.request[field] = old
    def test_unknown_ship_and_invalid_condition(self):
        self.profile['ship']['definition'] = 'unknown'
        self.reject('WRONG_SHIP')
        self.profile['ship']['definition'] = 'ship_starter_container_01'
        for condition in (0, -1, 10001, True, 1.5):
            self.profile['ship']['condition_bp'] = condition
            self.reject('WRONG_SHIP')
    def test_pending_wear_requires_requote(self):
        wear.apply(self.profile['ship'], 36)
        self.reject('QUOTE_CHANGED')
    def test_loaded_cargo_can_repair_without_transfer(self):
        self.profile['jobs'] = [{'state': 'loaded'}]
        code, candidate, _, _ = repairs.transition(self.profile, self.request, 20000)
        self.assertEqual(code, 'REPAIRED')
        self.assertEqual(candidate['jobs'], self.profile['jobs'])
        self.assertEqual(candidate['cargo'], self.profile['cargo'])

class RequestValidationTest(unittest.TestCase):
    def test_strict_repair_request(self):
        try:
            from authority import Authority, Rejected
        except ModuleNotFoundError as exc:
            if exc.name.startswith('psycopg'): self.skipTest('Install backend psycopg dependency for schema check')
            raise
        authority = Authority({})
        valid = dict(realm='public', op='repair', account='fixture', epoch=1, generation=1,
                     action_id='repair_fixture', expected_revision=1, port_id='port_brindle_quay',
                     condition_bp=7555, cost_minor=6113)
        authority._validate(valid)
        for changes in ({'condition_bp': True}, {'condition_bp': 0}, {'condition_bp': 10001},
                        {'cost_minor': -1}, {'cost_minor': 1.5}, {'cost_minor': True},
                        {'recipient': 'other_player'}, {'restored_bp': 10000}):
            with self.subTest(changes=changes), self.assertRaises(Rejected):
                authority._validate(dict(valid, **changes))


if __name__ == '__main__': unittest.main()
