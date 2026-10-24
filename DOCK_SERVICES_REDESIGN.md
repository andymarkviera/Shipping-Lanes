# Dock services and ship-specific jobs — October 24, 2026

User direction supersedes timed-offer design: dock first, then CARGO / REFUEL /
REPAIR. CARGO lists multiple jobs appropriate to the current ship. Jobs do not
expire. Container jobs deliver to another port; heavy-loader jobs spawn a nearby
physical load and deliver it to a random open-ocean point. No peer transfers.

Implemented in Port Test: both ports coexist 1500 m apart. Sailing into another
port's approach updates its docking/service context without replacing the boat or
clearing underway velocity. The docked-only panel exposes service actions and the
cargo list. Acceptance is guarded by docked state; container loading continues to
use the authoritative operation node. Docking water guides are removed. Dock appears
near a berth, grey while unavailable and colored when eligible. The throttle HUD
is hidden while docked to avoid overlap with services. Close services hides the
job list without owning or stopping operation progress.

Container jobs: three per origin, selectable simultaneously in the list, exclusive
acceptance, no expiry (legacy expires_ms is -1 and unused). Pending commitments still
reserve capacity. Delivery while docked at the matching destination removes the
batch, marks the offer delivered, and credits the temporary session exactly once.
No job availability regeneration yet; finite seeded jobs reset with a new test session.

Heavy jobs: switch using Test heavy loader when not carrying/in an active job.
Both ports offer three heavy jobs. Acceptance while docked activates one nearby
floating payload after a collision check. No free payload is present in this preview
before acceptance. Undock, lower, reverse under it, stop, Secure, Raise, then sail.
The authority chooses a point in the known empty test ocean, 450–850 m on the open
side and 800–1200 m seaward of the port. No hidden depth restrictions. A world label
and distance identify pickup/drop-off. Only one physical heavy job can be active.
At destination, stop within 30 m, Lower and Drop load. Releasing elsewhere is refused.
Completion hides the delivered payload, records the job and credits the session once.
Pickup can be cancelled before attaching. Ship switching is blocked during a heavy
job or while container cargo is aboard. Heavy physical job state remains separate
from container manifest records because its destination is geographic, not a port.
Step 51 must persist/reconcile both forms rather than invent a port ID for the ocean.

Camera repair: CameraFocus can exclude associated collision bodies. The heavy
loader registers its own floating load, so the camera's inside-obstacle guard no
longer freezes the view while the pivot passes through that load. Attached cargo
already shares the excluded hull. Shore and other ships remain camera obstacles.
A regression places the pivot inside the load, reproduces the old freeze without
the exclusion, and confirms that orbit moves with the correction.

Refuel fills fuel only while docked and not loading. Repair restores a new runtime
condition field; the initial condition is 100%, so undamaged ships report no repairs
needed. Both are free prototype services. Damage generation, service prices, durable
balances, online ownership/receipts and saves are not implemented here. Earnings
are temporary test credits, not updates to the existing private/public economy.
Closing this preview discards jobs/cargo/credits as before. Public-world service
RPCs, distributed locks and job persistence remain explicit integration work.

Validation: 122 script/startup, catalog, FlowCheck, 20 camera checks and Release
export pass. Heavy suite passes 39 in editor and Release, including the reproduced
camera failure (output/services-heavy-release.log). Final rendered Release suite
passes 205 checks (output/ports/2aaae26f). Coverage includes non-expiring jobs,
wrong-port and repeat delivery, underway service rejection, refuel/repair effects,
physical heavy pickup/drop restrictions, random-point bounds, duplicate acceptance,
and changing port context without stopping the boat. Container/heavy service menus
were captured and inspected; shortened job names fit without clipped prices.

Next: Step 51 persistence must follow this redesigned flow. Later steps must adapt
container visuals, heavy geographic completion, settlement and priced dock services.
Do not restore offer expiry or old water docking guides.
