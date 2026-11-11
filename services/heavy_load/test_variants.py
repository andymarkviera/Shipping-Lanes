"""Step 83 payload variants: definitions, load limits and unchanged payout logic."""
import sqlite3
import unittest
from unittest.mock import patch
from . import test_private as base
from . import private
from .private import (TERMS, PAYLOAD, PAYLOADS, ENVELOPES, LIFTERS, LIFTER,
                      WORLD, CHART_RANGE_M, payload_problems, definition_problems)
from services.oil_market.settlement import encode

MODULE = 'payload_offshore_module_01'
GIRDER = 'payload_offshore_girder_01'


class VariantTests(unittest.TestCase):
    setUp = base.HeavyTests.setUp
    tearDown = base.HeavyTests.tearDown
    call = base.HeavyTests.call

    def req(self, payload, op='claim', action='claim', job=None, revision=0, account='alice'):
        return dict(base.HeavyTests.req(self, op, action, job, revision, account), payload_id=payload)

    def evidence(self, payload, job, delivery=False):
        return dict(job_id=job, payload_id=payload, ship_id='alice-ship', validated=True,
                    zone_id=PAYLOADS[payload]['delivery_zone' if delivery else 'pickup_zone'])

    def test_every_definition_fits_lifter_and_transition_rules(self):
        self.assertEqual(definition_problems(), [])
        self.assertEqual(len(PAYLOADS), 3)
        self.assertIs(PAYLOADS[PAYLOAD], TERMS)
        limit = LIFTERS[LIFTER]
        for key, terms in PAYLOADS.items():
            with self.subTest(payload=key):
                size = ENVELOPES[key]['size_m']
                self.assertEqual(payload_problems(terms, ENVELOPES[key]), [])
                self.assertLessEqual(terms['mass_kg'], limit['max_payload_kg'])
                self.assertTrue(all(a <= b for a, b in zip(size, limit['max_envelope_m'])))
                self.assertLessEqual(limit['draft_m_per_100t'] * terms['mass_kg'] / 100000, limit['max_draft_m'])
        # New variants stay inside the measured chart; only the inherited block
        # delivery zone is an explicit recorded exception.
        for key in (MODULE, GIRDER):
            for field in ('pickup_position_m', 'delivery_position_m'):
                p = PAYLOADS[key][field]
                self.assertLessEqual(max(abs(p[0]), abs(p[2])) + PAYLOADS[key]['zone_radius_m'], CHART_RANGE_M)

    def test_rule_violations_are_reported(self):
        good, shape = PAYLOADS[MODULE], ENVELOPES[MODULE]
        cases = [
            (dict(good, mass_kg=200001), shape, 'OVER_MASS_LIMIT'),
            (good, dict(shape, size_m=[14.5, 6, 20]), 'OVER_ENVELOPE'),
            (good, dict(shape, size_m=[10, 8.1, 20]), 'OVER_ENVELOPE'),
            (good, dict(shape, size_m=[10, 6, 33]), 'OVER_ENVELOPE'),
            (good, dict(shape, size_m=[10, 0, 20]), 'BAD_ENVELOPE'),
            (good, dict(shape, size_m=[10, float('nan'), 20]), 'BAD_ENVELOPE'),
            (good, None, 'BAD_ENVELOPE'),
            (good, dict(shape, label=''), 'BAD_LABEL'),
            (dict(good, mass_kg=0), shape, 'BAD_MASS'),
            (dict(good, allowed_lifters=['ship_container_01']), shape, 'UNKNOWN_LIFTER'),
            (dict(good, allowed_lifters=[]), shape, 'NO_LIFTER'),
            (dict(good, delivery_position_m=[-300, 0, -990]), shape, 'ZONE_OUTSIDE_CHART'),
            (dict(good, pickup_position_m=[-700, 2, -800]), shape, 'ZONE_NOT_AT_SEA_LEVEL'),
            (dict(good, delivery_position_m=[-700, 0, -850]), shape, 'ZONES_OVERLAP'),
        ]
        for terms, envelope, code in cases:
            with self.subTest(code=code, envelope=envelope):
                self.assertIn(code, payload_problems(terms, envelope))
        tight = {LIFTER: dict(LIFTERS[LIFTER], max_draft_m=0.2)}
        self.assertIn('OVER_DRAFT', payload_problems(good, shape, tight))
        clash = dict(PAYLOADS, **{MODULE: dict(good, pickup_position_m=[-950, 0, -790])})
        self.assertIn((MODULE, 'ZONE_OVERLAPS_offshore_block_pickup_01'), definition_problems(clash))
        self.assertIn((MODULE, 'BAD_TERMS'), definition_problems(dict(PAYLOADS, **{MODULE: dict(good, extra=1)})))
        self.assertIn(('*', 'DUPLICATE_ZONE'), definition_problems(dict(PAYLOADS, **{MODULE: dict(good, pickup_zone='offshore_girder_pickup_01')})))

    def test_snapshot_lists_variants_and_limits(self):
        snap = self.store.snapshot('alice')
        self.assertEqual([p['payload_id'] for p in snap['payloads']], list(PAYLOADS))
        self.assertTrue(all(p['available'] for p in snap['payloads']))
        self.assertEqual(snap['payloads'][1]['size_m'], [10, 6, 20])
        self.assertEqual(snap['payloads'][1]['label'], 'Compact module')
        self.assertEqual(snap['lifter']['max_payload_kg'], 200000)
        self.assertEqual(snap['terms'], TERMS)

    def test_second_payload_uses_same_attachment_and_payout_path(self):
        job = self.call(self.req(MODULE))['job_id']
        snap = self.store.snapshot('alice')
        self.assertEqual(snap['jobs'][0]['terms'], PAYLOADS[MODULE])
        self.assertEqual([z['zone'] for z in snap['zones']], ['offshore_module_delivery_01', 'offshore_module_pickup_01'])
        self.assertEqual([p['available'] for p in snap['payloads']], [True, False, True])
        self.assertTrue(snap['available'])
        # Evidence and payload identity are bound to this job's own definition.
        pickup = self.req(MODULE, 'pickup', 'pickup', job, 1)
        wrong = dict(self.evidence(MODULE, job), payload_id=PAYLOAD, zone_id=TERMS['pickup_zone'])
        self.assertEqual(self.call(pickup, evidence=wrong)['code'], 'HOST_VALIDATION_REQUIRED')
        self.assertEqual(self.call(self.req(PAYLOAD, 'pickup', 'cross', job, 1), evidence=wrong)['code'], 'JOB_MISMATCH')
        self.assertTrue(self.call(pickup, evidence=self.evidence(MODULE, job))['ok'])
        # One active job per account/ship, whichever payload it is.
        self.assertEqual(self.call(self.req(GIRDER, action='second', revision=2))['code'], 'CARGO_BUSY')
        # Another lifter may take a different payload but never the claimed one.
        self.assertEqual(self.call(self.req(MODULE, action='bob-module', account='bob'), account='bob')['code'], 'PAYLOAD_RESERVED')
        self.assertTrue(self.call(self.req(GIRDER, action='bob-girder', account='bob'), account='bob')['ok'])
        deliver = self.req(MODULE, 'deliver', 'deliver', job, 2)
        self.assertFalse(self.call(deliver, evidence=self.evidence(MODULE, job))['ok'])
        result = self.call(deliver, evidence=self.evidence(MODULE, job, True))
        self.assertEqual((result['state'], result['gross_minor'], result['money']), ('delivered', 45000, 46000))
        self.assertTrue(self.call(deliver)['duplicate'])
        self.assertEqual(self.store.snapshot('alice')['money'], 46000)
        # Delivered variant is consumed; the remaining block is still claimable.
        self.assertEqual(self.call(self.req(MODULE, action='again', revision=3))['code'], 'PAYLOAD_RESERVED')
        block = self.call(self.req(PAYLOAD, action='block', revision=3))
        self.assertTrue(block['ok'], block)
        self.assertEqual([p['available'] for p in self.store.snapshot('alice')['payloads']], [False, False, False])

    def test_unknown_payload_and_over_limit_claim_refused(self):
        self.assertEqual(self.call(self.req('payload_unknown_01'))['code'], 'BAD_REQUEST')
        self.assertEqual(self.call(dict(self.req(MODULE), payload_id=7))['code'], 'BAD_REQUEST')
        small = {LIFTER: dict(LIFTERS[LIFTER], max_payload_kg=100000)}
        with patch.object(private, 'LIFTERS', small):
            self.assertEqual(self.call(self.req(GIRDER))['code'], 'OVER_LOAD_LIMIT')
            self.assertTrue(self.call(self.req(MODULE))['ok'])
        self.assertEqual(len(self.store.snapshot('alice')['jobs']), 1)

    def test_legacy_single_block_world_stays_readable_without_variants(self):
        with self.store.connect() as db:
            db.execute('UPDATE heavy_world SET terms=?', (encode(TERMS),))
        snap = self.store.snapshot('alice')
        self.assertEqual([p['payload_id'] for p in snap['payloads']], [PAYLOAD])
        self.assertEqual(self.call(self.req(MODULE))['code'], 'BAD_REQUEST')
        job = self.call(self.req(PAYLOAD))['job_id']
        self.assertTrue(self.call(self.req(PAYLOAD, 'pickup', 'pickup', job, 1), evidence=self.evidence(PAYLOAD, job))['ok'])
        result = self.call(self.req(PAYLOAD, 'deliver', 'deliver', job, 2), evidence=self.evidence(PAYLOAD, job, True))
        self.assertEqual(result['money'], 71000)

    def test_changed_definitions_fail_closed(self):
        job = self.call(self.req(MODULE))['job_id']
        changed = dict(PAYLOADS, **{MODULE: dict(PAYLOADS[MODULE], reward_minor=999999)})
        with patch.object(private, 'PAYLOADS', changed):
            # The job's frozen terms no longer match these definitions.
            self.assertEqual(self.call(self.req(MODULE, 'cancel', 'cancel', job, 1))['code'], 'INCOMPATIBLE_WORLD')
        with patch.object(private, 'WORLD', dict(WORLD, version=3)):
            self.assertEqual(self.call(self.req(MODULE, 'cancel', 'cancel', job, 1))['code'], 'INCOMPATIBLE_WORLD')
        with self.assertRaises(private.MarketError): self.broken_snapshot()
        self.assertTrue(self.call(self.req(MODULE, 'cancel', 'cancel', job, 1))['ok'])

    def broken_snapshot(self):
        with patch.object(private, 'WORLD', dict(WORLD, version=3)):
            return self.store.snapshot('alice')

    def test_variant_rollback_leaves_no_partial_claim(self):
        before = self.store.snapshot('alice')
        for stage in ('after_job_write', 'after_profile_write', 'before_commit'):
            def fault(at, _):
                if at == stage: raise sqlite3.OperationalError('fault')
            self.assertFalse(self.call(self.req(GIRDER), fault=fault)['ok'])
            self.assertEqual(self.store.snapshot('alice'), before)


if __name__ == '__main__': unittest.main()
