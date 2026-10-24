# Step 48 — Reusable cargo operations

A narrow authority service owns records keyed by operation ID and an exclusive
ship reservation. States: reserved -> running -> ready -> committing -> committed;
cancelled, interrupted and failed are terminal alternatives. Invalid ordering is
rejected. Progress consumes explicit finite simulation seconds, not animation
callbacks. Durations are positive and at most one day. Repeated commit on a committed
record returns success without repeating effects. Terminal states release the
ship reservation once; cancellation after completion cannot undo cargo.

Cargo-family adapters provide validation and synchronous atomic completion effects.
The included per-ship manifest adapter validates load/unload requests and applies a
fully checked manifest replacement. It revalidates before completion, rejects the
wrong ship, and fails without cargo effects if inventory changed incompatibly.
The state machine has no cargo-family switch or UI logic. New cargo families can
register their own trusted adapters. No payments, trades, offers or loading buttons.

Runtime HandlingShip initializes ShipState.operations and a manifest adapter. The
service must only be invoked by the local/server authority, using resolved owner
identity. Caller is responsible for docking, stock/source reservation, job ownership
and offer eligibility. Ship reservation here does not reserve a warehouse item or
berth. Loading integration will supply those constraints and advance progress.
interrupt_ship and HandlingShip.interrupt_cargo_operation are explicit disconnect/
teardown hooks. Temporary shared-physics-world reparenting is not a disconnect, so
ordinary tree exit does not interrupt an operation. Network lifecycle wiring remains
part of the operation integration; no live public loading RPC is exposed now.

Snapshots copy plain data; a fresh service with trusted registered adapters can
restore reserved/running/ready records and reconstruct their locks. Invalid recovery
records fail atomically. Tests include a Godot variant-bytes roundtrip preserving
integer quantity types. This is reconstruction capability, not disk durability:
no new save file/schema is written. Step 51 must atomically persist cargo effects
and terminal receipts together, reconcile unknown commits, and migrate IDs. Never
replay a stale pending snapshot against newer committed inventory. An uncertain
committing state is refused, not blindly resumed. JSON normalization and stable
saved ship IDs must be handled by that adapter; current runtime IDs are not saves.
The existing durable economy and inventory formats remain unchanged.

Validation: script/startup 118, contracts 66, FlowCheck and Release export pass.
Editor combined suite: 160 checks at output/ports/986b031f; Release: 160 at
output/ports/7717b220. Twenty-two added checks cover ordering, exclusive reservations,
progress/no premature cargo effect, partial-operation reconstruction, defensive
copies, duplicate completion, cancel/interruption, commit-time revalidation failure,
invalid restore, ownership mismatch and successful load/unload effects.

Next: Step 49 container offers. Heavy-loader pickup repair remains due before 50.
Later docking UI removes water guides and uses grey/colored Dock feedback.
