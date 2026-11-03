# Step 68 — Bulk capacity model

Task ID: `bulk-capacity-model`. D125. Capacity and commodity data only.

The four catalog commodities are `cargo_bulk_grain`, `cargo_bulk_coal`,
`cargo_bulk_ore`, and `cargo_bulk_limestone`. Each uses positive integer **grams**
and the `bulk_holds` family. One tonne is 1,000,000 grams. Each batch and each
hold capacity is bounded to 1,000,000,000 grams; no float quantity or implicit
conversion is accepted. At most 256 batches and 256 holds are supported.

A ship's `bulk_holds` dictionary maps stable compartment IDs to `capacity_grams`
and explicit `cargo_type_ids`. Ship compatibility and hold compatibility must
both allow a commodity. Bulk capacity cannot also be defined in the aggregate
`cargo_capacities` dictionary. Containers and other existing pools retain their
own independent quantity units and budgets.

The authored `single_commodity_per_hold` policy permits multiple batches of the
same commodity in a hold, preserving individual batch/job/acquisition provenance.
Different commodities can occupy different holds, but cannot share one hold even
when space remains. Unknown policies fail validation. A fully emptied hold can
accept any supported commodity; this step introduces no cleaning, residue or
machinery degradation. There is no automatic splitting or allocation: callers
must provide a stable `hold_id` on each bulk batch. Split loads require distinct
batch IDs. Existing container batches remain unchanged and cannot specify a hold.

The data-only `bulk_ship.tres` fixture has a 400,000,000 g forward hold and a
600,000,000 g aft hold. Both support all four commodities. Thus 400 t grain plus
600 t coal is valid, as are all sixteen ordered commodity pairs at those limits.
One extra gram in either full hold fails atomically, regardless of spare space
in another hold. Its independent DWT rating is 1,500 t; hold count is two, derived
from the authored compartments. DWT is informational metadata, **not a cargo
budget** or a source of hold capacity. Zero DWT means unspecified. This model
does not simulate displacement, fuel/ballast deadweight or volumetric density.
Existing ships retain their unspecified DWT and their existing capacities.

`CargoManifest.validate/add/replace/remove` enforce the same rules. Failed edits
leave the previous manifest intact. `usage()` reports grams in the bulk pool;
`hold_usage()` reports occupied grams by hold ID. Returned data and ship definitions
are defensive copies. The existing manifest operation adapter revalidates these
rules at completion; this does not add player-facing bulk loading or settlement.

The bulk hull is a data/test fixture with existing placeholder scene references,
not a purchase, fleet activation or new playable class. Commodities are registered;
the hull is loaded explicitly by the probe, outside the playable catalog. All five
resources are included explicitly in the export preset. No save migration, protocol
change or backend capacity claims are introduced. Bulk services, earnings, partial
discharge settlement, persistence/reconnect and presentation remain Steps 69–70.
Deferred save UX, turning roll and all other requests remain untouched.

Run with the pinned Godot 4.7.2 engine after headless editor import:

```sh
"$GODOT" --headless --path . --script tools/bulk_capacity_probe.gd
```

The probe covers all sixteen two-hold combinations, exact limits/overfill,
same-commodity batching, hold release, compatibility, malformed inputs, independent
DWT/container budgets, defensive copies and transactional catalog rejection.
PROGRESS.md records the complete Linux sweep and outstanding platform gates.
