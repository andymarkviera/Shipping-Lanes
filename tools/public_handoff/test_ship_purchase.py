"""Portable purchase and receipt-dispatch checks; SQL atomicity has a separate gate."""
import copy
import datetime
import sys
import unittest
import uuid
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'services/public_authority'))
import ship_purchase
from authority import Authority, Rejected

ACCOUNT = str(uuid.uuid4())


class MemoryDB:
    """Explicit SQL adapter double exercising production _voyage receipt dispatch."""
    def __init__(self, profile):
        self.profile = profile
        self.receipts = {}
        self.journal = []
        self.money = 1000000
        self.row = None
    def execute(self, sql, args=()):
        if sql.startswith('SELECT * FROM public_authority.receipts'):
            self.row = self.receipts.get(args[1])
        elif sql.startswith('SELECT * FROM public_authority.game'):
            self.row = {'money': self.money}
        elif sql.startswith('SELECT clock_timestamp'):
            self.row = {'now': datetime.datetime.now(datetime.timezone.utc)}
        elif sql.startswith('UPDATE public_authority.profiles'):
            self.profile['profile'] = copy.deepcopy(args[0].obj)
            self.profile['money'] += args[1]
            self.profile['revision'] += 1
        elif sql.startswith('UPDATE public_authority.game'):
            self.money -= args[0]
        elif sql.startswith('INSERT INTO public_authority.receipts'):
            assert args[1] not in self.receipts
            self.receipts[args[1]] = dict(fingerprint=args[2], result=copy.deepcopy(args[3].obj))
        elif sql.startswith('INSERT INTO public_authority.journal'):
            self.journal.append(args)
        else: raise AssertionError(sql)
        return self
    def fetchone(self): return self.row


class PurchaseTest(unittest.TestCase):
    def setUp(self):
        self.profile = dict(ship=dict(id='existing-starter', definition='ship_starter_container_01',
                                     fuel_liters=432, condition_bp=7555, wear_fraction_bp=0.5,
                                     position=dict(latitude=0, longitude=0, heading=0)),
                            jobs=[dict(state='loaded')], cargo=[dict(id='keep-cargo')], delivered=['keep-history'])
        self.request = dict(realm='public', op='ship_purchase', account=ACCOUNT, epoch=1, generation=1,
                            action_id='purchase_one', expected_revision=1, port_id='port_brindle_quay',
                            definition_id='ship_coastal_container_01', cost_minor=80000)
    def test_distinct_owned_instances_and_definition_unchanged(self):
        definitions = copy.deepcopy(ship_purchase.CATALOG)
        original = copy.deepcopy(self.profile)
        code, first, debit, owned = ship_purchase.transition(self.profile, self.request, 160000)
        self.assertEqual((code, debit), ('SHIP_PURCHASED', -80000))
        _, second, _, another = ship_purchase.transition(first, dict(self.request, action_id='purchase_two'), 80000)
        self.assertNotEqual(owned['id'], another['id'])
        self.assertNotEqual(owned['id'], original['ship']['id'])
        self.assertEqual(owned['definition'], another['definition'])
        self.assertEqual(second['ship'], original['ship'])
        self.assertEqual(second['cargo'], original['cargo'])
        self.assertEqual(second['jobs'], original['jobs'])
        self.assertEqual(self.profile, original)
        second['stored_ships'][0]['condition_bp'] = 1234
        self.assertEqual(second['stored_ships'][1]['condition_bp'], 10000)
        self.assertEqual(first['stored_ships'][0]['condition_bp'], 10000)
        self.assertEqual(ship_purchase.CATALOG, definitions)
        self.assertEqual(owned['fuel_liters'], 0)
    def test_rejections_do_not_mutate(self):
        for changes, wallet, code in [({},79999,'INSUFFICIENT_FUNDS'),
                                      ({'definition_id':'unknown'},80000,'UNKNOWN_SHIP'),
                                      ({'cost_minor':79999},80000,'QUOTE_CHANGED'),
                                      ({'port_id':'ocean'},80000,'NO_SHIP_SERVICE')]:
            before = copy.deepcopy(self.profile)
            result, candidate, debit, owned = ship_purchase.transition(self.profile, dict(self.request, **changes), wallet)
            self.assertEqual((result, debit, owned), (code, 0, None))
            self.assertEqual(candidate, before)
            self.assertEqual(self.profile, before)
    def test_loading_and_storage_bound(self):
        self.profile['jobs'][0]['state'] = 'loading'
        self.assertEqual(ship_purchase.transition(self.profile, self.request, 80000)[0], 'LOADING_PENDING')
        self.profile['jobs'] = []
        self.profile['stored_ships'] = [dict(id=str(n)) for n in range(100)]
        self.assertEqual(ship_purchase.transition(self.profile, self.request, 80000)[0], 'FLEET_LIMIT')
    def test_strict_request_and_no_recipient_or_client_owned_id(self):
        authority = Authority({})
        authority._validate(self.request)
        for changes in ({'cost_minor':True}, {'cost_minor':1.5}, {'cost_minor':-1}, {'cost_minor':0},
                        {'definition_id':True}, {'definition_id':'../unknown'}, {'recipient':'another'},
                        {'owned_id':'injected'}, {'fuel_liters':1000}):
            with self.subTest(changes=changes), self.assertRaises(Rejected):
                authority._validate(dict(self.request, **changes))
    def test_production_receipt_dispatch_replay_and_two_purchases(self):
        row = dict(profile=copy.deepcopy(self.profile), money=300000, revision=1)
        db = MemoryDB(row)
        authority = Authority({})
        def call(request): return authority._voyage(db, ACCOUNT, copy.deepcopy(row), request)
        one = call(self.request)
        replay = call(self.request)
        self.assertTrue(replay.pop('duplicate'))
        self.assertEqual(replay, one)
        self.assertEqual(len(row['profile']['stored_ships']), 1)
        self.assertEqual(row['money'], 220000)
        self.assertEqual(len(db.journal), 1)
        with self.assertRaisesRegex(Rejected, 'ID_CONFLICT'):
            call(dict(self.request, definition_id='ship_swift_container_01'))
        two = call(dict(self.request, action_id='purchase_two', expected_revision=2))
        self.assertNotEqual(one['owned_ship']['id'], two['owned_ship']['id'])
        self.assertEqual(row['money'], 140000)
        self.assertEqual(db.money, 1160000)
        self.assertEqual(len(db.journal), 2)
        # An old successful receipt remains replayable after subsequent purchases.
        self.assertEqual(call(self.request)['owned_ship'], one['owned_ship'])
    def test_stale_revision_and_recovery_reject_in_dispatch(self):
        for revision, recovery, expected in [(2,{},'STALE_REVISION'), (1,{'state':'pending'},'RECOVERY_REQUIRED')]:
            row = dict(profile=dict(copy.deepcopy(self.profile), recovery=recovery), money=300000, revision=revision)
            db = MemoryDB(row)
            result = Authority({})._voyage(db, ACCOUNT, copy.deepcopy(row), self.request)
            self.assertEqual(result['code'], expected)
            self.assertEqual(row['money'], 300000)
            self.assertFalse(db.journal)
    def test_failed_purchase_receipt_cannot_later_charge(self):
        row = dict(profile=copy.deepcopy(self.profile), money=79999, revision=1)
        db = MemoryDB(row)
        authority = Authority({})
        first = authority._voyage(db, ACCOUNT, copy.deepcopy(row), self.request)
        self.assertEqual(first['code'], 'INSUFFICIENT_FUNDS')
        row['money'] = 300000  # Simulate a later earning; old receipt is still final.
        replay = authority._voyage(db, ACCOUNT, copy.deepcopy(row), self.request)
        self.assertTrue(replay['duplicate'])
        self.assertEqual(replay['code'], 'INSUFFICIENT_FUNDS')
        self.assertEqual(row['money'], 300000)
        self.assertNotIn('stored_ships', row['profile'])
        self.assertFalse(db.journal)
    def test_stored_instances_survive_existing_service_transitions(self):
        import repairs, recovery, wear
        _, bought, _, _ = ship_purchase.transition(self.profile, self.request, 80000)
        stored = copy.deepcopy(bought['stored_ships'])
        terms = repairs.quote(bought['ship'])
        _, repaired, _, _ = repairs.transition(bought, dict(terms, port_id='port_brindle_quay'), 100000)
        wear.apply(repaired['ship'], 3600)
        recovery.repay(repaired, 1000)
        self.assertEqual(repaired['stored_ships'], stored)
    def test_catalog_has_three_positive_integer_prices(self):
        self.assertEqual(len(ship_purchase.CATALOG), 3)
        for row in ship_purchase.CATALOG.values():
            self.assertIs(type(row['cost_minor']), int)
            self.assertGreater(row['cost_minor'], 20000)
            self.assertTrue(row['description'])

if __name__ == '__main__': unittest.main()
