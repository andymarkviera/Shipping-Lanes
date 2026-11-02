# Step 65 — Fleet spawn and switching

Task ID: `fleet-spawn-and-switching`. D122 extends the Step 54 refusal to switch
with cargo/jobs to the canonical online fleet. No resale or Step 66 accounting.

One owned ship is active. Fleet / Compare selects an owned ID in the left column;
review and confirm activation while docked at its storage port. Catalog definitions
are not activatable. The server accepts only a bounded ID and validates peer,
current ship, epoch/generation, monotonic sequence, rate and service state.

| Lifecycle event | Policy |
| --- | --- |
| Cargo or unfinished job, including pending loading | Refuse switching; no transfer, forfeiture, cancellation or duplication. Finish/deliver or explicitly cancel through existing cargo services. |
| Damaged but afloat, empty ship | Allow storage, preserving integer condition and fractional wear. No free repair. |
| Sunk ship, pending damage/recovery, active checkpoint/service | Refuse until the existing save/recovery/service completes. |
| Outgoing ship | Pause while docked, checkpoint live fuel, pose and pending wear, then atomically move the whole owned record to storage at this port. Preserve IDs, name and all other fields. No inactive/offline wear. |
| Newly purchased ship | Empty tank and existing condition retained. Spawn at the authored service berth in fleet_slots.json, retaining the berth reservation so paid refueling is available immediately. One slot per current port. |
| Previously active stored ship | Restore its exact canonical latitude/longitude/heading, at its recorded storage port. Reject an occupied position; no fallback teleport. Docked velocity/throttle are zero, not persisted motion. |
| No valid spawn | Retain current hull and fleet; do not commit the exchange. |
| Commit and installation | Consume the existing revision under lease/profile lock and atomic receipt/journal transaction. Install the new class before hull initialization; update peer active ID and invalidate service quotes. |
| Object enters spawn during I/O | Hold incoming hull inert with collisions disabled until the existing two-frame placement recheck confirms clearance. No live overlapping hull is released. |
| Lost reply/outage | Fence authority; no automatic new action/retry. Reconnect reads canonical active ship; blocked reconnect preserves its saved position. |
| Disconnect during commit | Departure waits; confirmed commit installs the incoming canonical record before departure checkpoint, preventing old hull state from overwriting the new ship. Uncertain commit fences and skips departure checkpoint. |

Clearance uses the actual definition's hull envelope against authored visible shore
solids and conservative hull bounding circles with 2 m separation. Reservations
cover asynchronous fleet I/O and are checked by admission and recovery placement;
other fleet requests cannot claim the same area. The single existing berth lock
remains held across activation. Stored hulls have no world collision body.

Starter, Coastal and Swift share placeholder geometry and six container slots;
activation uses each class's actual handling/fuel definition. Admission, container
jobs, paid refueling and paid repair now accept these already-purchasable classes.
All three provisionally use the existing 250-credit full-scale repair rate. This
adds no starter grant and preserves their purchased empty tanks. Nearby replicas
still share their common placeholder art. Heavy lifter online activation is excluded.

Game protocol **16** (was 15), ticket protocol **7**, Godot **4.7.2**. Deploy matching
client/server/backend source together. A binding update clears old owner views and
sets a server snapshot floor, so delayed frames from an earlier activation cannot
revive stale state after A → B → A. Save version and existing IDs are unchanged;
stored records gain a position only on first activation and retain storage_port_id
while stored. The slot JSON is explicitly exported; existing UIDs are retained.

## Evidence and remaining gates

`tools/fleet_switch_probe.gd` exercises the real bridge, real runtime hulls,
clearance/reservations, roundtrip preservation and actual confirmation panel with
an explicit authority double. `tools/public_handoff/test_fleet.py` covers canonical
exchange, cargo/job restrictions, malformed requests, receipt replay/conflicts,
stale revision and recovery fencing through the production dispatch with a SQL
double. Neither proves real PostgreSQL atomicity or authenticated networking.

Before release, run the configured Windows Debug/Release checks and exports; real
PostgreSQL/HTTPS concurrent/replayed switch and crash tests before/after commit;
Keycloak two-account ownership, interrupted switching, reconnect/server restart and
A → B → A delayed frames; rendered fleet selection, empty-tank refueling, damaged
roundtrips, occupied slots, supported resolutions and Andy's playtest. No live
server deployment, reset, manual playtest or public internet acceptance is claimed.
