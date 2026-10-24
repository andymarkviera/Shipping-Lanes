# Step 47 — Per-ship cargo manifest

Each runtime HandlingShip initializes its own ShipState.manifest. Batches contain
batch_id, cargo_id, positive integer quantity, unit (count/gram/milliliter), origin
and destination port IDs, and acquisition_id/job_id (at least one nonempty).
Separate batch IDs preserve different job provenance for the same cargo type.
References are syntactically checked and ports resolved against catalog copies;
job/acquisition existence and ownership must be checked by future operation authority.

Ship data declares independent capacity pools; cargo data selects a pool and quantity
unit. Current provisional fixture limits are six container slots on the starter
and one heavy slot on the lifter, not final fleet balance or visual loading counts.
Quantity consumes the same number of units in its pool. Future tank/weight pools
use their own integer base units, never add milliliters to container counts. Mixed
units within one used pool fail closed. These rules do not implement slot geometry,
weight distribution, variable per-item capacity costs or physical pickup.

Add and full replacement validate a detached candidate before publishing; removal
is batch-specific and cannot exceed held quantity. Duplicate IDs, incompatible
cargo, invalid references/units, fractional/zero/negative quantities, overflow and
excess capacity fail without mutation. At most 256 batches and 1 billion units per
pool/quantity; bounds are checked by subtraction before adding. Input batches,
output lists and definitions are copied so caller edits cannot corrupt a manifest.

This is a runtime domain component for authority-owned cargo operations. It has no
RPC, trading, purchase, payment or loading UI. Existing legacy cargo fixtures and
private/public persisted inventory formats remain unchanged. The manifest starts
empty and is not yet populated from those saves; Step 51 must supply a versioned,
validated persistence adapter and reconcile legacy inventory rather than silently
replacing it. Step 48 operations and Step 50 loading will call this validation;
job settlement must validate acquisition references on its authority. Public world
port integration remains later work. No claim that heavy-loader pickup is repaired.

Validation: 116-script/startup, CatalogCheck, 66 contract checks and Release export
pass. Editor and Release combined port/manifest suites pass 138 checks:
output/ports/5f9a3e3e and output/ports/2508a1de. Twenty-two new manifest checks cover
copy isolation, capacity across job batches, rejected mutations, removals, per-ship
isolation, industrial module capacity and separate liquid/container budgets.

Next: Step 48 reusable operation state machine. Pickup repair is still due before
Step 50. Later docking UI will remove water markings in favor of disabled/colored
Dock feedback, per the user's preference.
