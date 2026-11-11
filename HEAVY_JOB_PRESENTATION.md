# Heavy job presentation and variants — Step 83

Task `heavy-job-presentation-and-variants`. Builds on Steps 80–82. Still the
explicitly provisioned private host fixture: no public heavy endpoint, no Port
Test migration, no new hull, protocol or save schema. Run it exactly as in
HEAVY_TRANSPORT_LIFECYCLE.md (`tools/heavy_transport_fixture.py`).

**Verification status: nothing in this step was executed.** The cloud runner
that produced it could not run Python or obtain Godot 4.7.2. Every claim below
is by code reading only until the commands in "Reproduction" are run.

## Payload definitions

`services/heavy_load/private.py` holds the definitions; the Godot fixture reads
them from the canonical snapshot and has no payload table of its own.

| Payload ID | Label | Mass | Envelope W×H×L | Reward (minor) | Pickup X/Z | Drop-off X/Z |
| --- | --- | --- | --- | --- | --- | --- |
| `payload_offshore_block_01` | Offshore block | 100 t | 14 × 8 × 32 m | 70000 | -950, -800 | -950, -1800 |
| `payload_offshore_module_01` | Compact module | 60 t | 10 × 6 × 20 m | 45000 | -700, -800 | -300, -300 |
| `payload_offshore_girder_01` | Long girder | 150 t | 8 × 5 × 32 m | 100000 | -950, -500 | -100, -900 |

`PAYLOADS` are the frozen economic terms (same keys as the Step 80 `TERMS`,
which is unchanged byte for byte). `ENVELOPES` adds label and size. Each payload
has its own two 30 m zones. Masses, sizes, positions and rewards are prototype
tuning for review, not accepted balance. A further variant is one `PAYLOADS`
entry plus one `ENVELOPES` entry: claim, pickup evidence, attachment, release,
destruction and payout all take the job's own terms.

All three use the existing `industrial_payload.glb`, scaled to the defined
envelope. That is placeholder presentation, not new or approved art.

## Rules checked for every definition

`definition_problems()` runs at import and refuses to load invalid definitions.
`payload_problems()` also runs on every claim (`OVER_LOAD_LIMIT`).

| Rule | Limit | Source |
| --- | --- | --- |
| Mass | ≤ 200000 kg | New prototype load limit for `ship_heavy_lifter_01` |
| Envelope | ≤ 14 × 8 × 32 m per axis | The compound payload already carried through deck travel, swept clearance and the connected-world chart transitions |
| Loaded visual draft | ≤ 1.0 m (0.5 m per 100 t) | Step 82 draft rule; follows from the mass limit |
| Zones | at sea level, pickup and drop-off not overlapping, no zone shared or overlapping between payloads | Step 80 reservation model |
| Zone extent | centre plus radius within ±1000 m | Measured local-chart budget in WORLD_SIZE_EXPERIMENT.md |

The inherited block drop-off at Z = -1800 is **outside** the ±1000 m budget. It
is listed in `CHART_EXCEPTIONS` and kept so Step 82 worlds stay valid; it is a
recorded exception, not a pass. Both new variants are inside the budget.

World transitions: a carried payload remains one visual child of the fixed cargo
mount with one carrier-owned box, exactly the arrangement the connected-world
experiment transitioned. This fixture itself performs no chart rebasing, so a
variant crossing a real seam or pole has not been exercised.

In Godot, `HeavyLifter.configure_payload(size, mass)` applies a definition to the
existing carrier box, floating collider, swept deck checks, visual scale, loaded
acceleration and draft. It refuses anything over `BASE_PAYLOAD_SIZE` or
`MAX_PAYLOAD_KG`. Defaults are the original block, so the lifter test, Port Test
and network fixtures behave as before. Pickup tolerance (9 m lateral, 24 m
longitudinal, any heading) is unchanged for every variant.

## Presentation

- **Offers:** one Claim button per defined payload with mass, envelope and
  reward. Taken or over-limit offers are disabled and labelled. Offers hide
  while a job is active (one job at a time, never expiring).
- **Waypoint guidance:** a ring of the zone's radius on the water with a high
  marker, yellow for pickup and green for drop-off; a screen-edge pointer with
  distance; and a text line with distance and turn to port or starboard.
- **Alignment feedback:** at pickup, the load centre's offset from the platform
  centre in metres to port/starboard and ahead/astern against the tolerance, and
  an "in position" line. At drop-off, the waypoint line reports inside the ring.
- **Load limits:** current load against the lifter limit and its loaded draft.
- **Cues:** one-time messages when the canonical state changes (accepted,
  secured, delivered with amount, cancelled, failed) and a "NEXT:" instruction
  for each phase.

All of this is derived from the saved snapshot and live ship pose. It never
supplies evidence, position or reward to the authority; the Step 82 guards and
host commit order are unchanged. No audio cue was added.

## Saved worlds

The world record now stores the full definition set. A world created by Steps
80–82 (record equal to the single block terms) stays readable and offers only
the block. Any other record, or a job whose frozen terms differ from the current
definition, fails closed with `INCOMPATIBLE_WORLD`. There is no migration and no
way to add variants to an existing world. The snapshot gains additive `payloads`
and `lifter` fields; `terms` and `available` still describe the block.

## Reproduction

```sh
python -m unittest services.heavy_load.test_private services.heavy_load.test_transport services.heavy_load.test_variants -v
python tools/heavy_transport_fixture.py --godot /path/to/godot --db /path/to/new.sqlite --create --probe variants
```

`variants` uses a new world file and one process: definition limits, claim of the
module, waypoint and alignment values, pickup, loaded draft and scale, refusal
away from its drop-off, delivery of its own reward, remaining offers, then a
girder claim and cancellation. Rerun the Step 82 `carry`/`deliver`/`verify` and
`destroy`/`failed` probes too, since the shared fixture script changed.
