# Step 44 — Spawn clearance and recovery anchors

Both test ports now author a primary spawn and two ordered recovery anchors, at
local z=-180, -280 and -380 metres. Port Test allocates its starter hull through
the same reusable clearance component before adding the boat to the world.
All occupied locations return SPAWN_OCCUPIED and the preview explains how to retry.
There is no depth test, hidden grounding rule, forced teleport or save mutation.

The allocator checks an oriented hull box with 2 m horizontal / 1 m vertical
padding against hull, visible shore and cargo collision layers (including areas).
Explicit world-space cargo AABBs also block allocation. Authority-owned berth
reservations can use hold_volume and release. Ordered selection is synchronous:
a successful allocation immediately holds its bounds, so a second request cannot
choose that space before physics catches up. Reservation bounds are conservative
world AABBs, so rotated holds may refuse more space than the actual hull occupies.
Invalid hull/cargo envelopes fail closed. Port transforms apply to all anchors.

Integration contract: use one allocator for simultaneous allocations in a shared
physics world; supply all applicable berth/cargo envelopes. Hold tickets until
cancellation or physical materialization has synchronized. The disposable preview
keeps its hold until the port is freed. Reservations are ephemeral, not saves.
A loaded ship must supply an envelope enclosing its hull and carried load.

Scope: used by the two-port preview. Public servers retain their existing saved
spawn rejection and canonical-save protection. Test ports do not yet have geographic
world placement. Shared-world port installation, production reservation lifecycle
and saved-position recovery transactions must use this component when those systems
are connected; this step does not claim those later integrations already exist.

Validation: 113 scripts and startup, CatalogCheck, FlowCheck, Release export pass.
Editor ports probe: 38 checks at output/ports/5fbcef81 (before two berth-hold checks).
Final Release probe: 40 checks at output/ports/dc18b974. Covers original port data
and approach tests plus ordered reservations, exhaustion, release/retry, existing
hulls, physical/explicit cargo, reserved berth volumes, quay rejection, invalid
hulls, rotated open-water placement, transformed ports and preview switching.

Next: Step 45 berth eligibility. Stop/neutral review remains before Step 46;
heavy-loader pickup repair before Step 50; wake/foam polish remains later.
