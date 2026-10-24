# Step 49 — Seeded container offers

Port Test has a session-owned source with three offers in each direction between
Brindle Quay and Slatewater Works. Designed test terms: 1, 2 or 3 containers;
250.00 credits per container; 600 seconds of active preview simulation to accept.
These are intentional prototype values, not researched shipping rates or final
balance. IDs are deterministic container_seed_v1_route_index identifiers within
this disposable session. Production regeneration needs a persisted world/epoch
namespace, not repeated global IDs on every server restart.

Offers are exclusive. The authority resolves owner, ship, origin and manifest;
clients must never supply trusted identity or clocks. One synchronous validation
and assignment accepts the offer. Wrong origin, incompatible ship and overcapacity
fail without taking it. Pending accepted jobs count against that ship's capacity.
Accepted terms are frozen and do not expire; retry by the same owner and ship
returns the same terms, while competing owners/ships are rejected. Unaccepted
items expire exactly at the deadline. Authority clock updates cannot go backward.
Offer reads return copies. No player-to-player recipient/transfer API exists.

Preview UI shows the next available local offer, quantity, destination, quoted
reward, remaining time and accepted count, with an Accept offer button. Switching
ports retains the same source, preview identity and elapsed simulation time; exiting
Port Test discards it. Acceptance is allowed within that port's preview, without
requiring docking yet. No cargo is loaded, no reward paid and no save is written.

Step 50 must turn a pending capacity commitment into its actual manifest batch
without double-counting, tie loading to docked authority/operation state, and prevent
arbitrary offer-origin claims. Source stock and operation/offer persistence remain
integration work. Step 51 must persist accepted jobs and scoped IDs. Step 53 performs
delivery settlement; these quotes do not authorize payments on their own. The current
pending-job capacity model must not be used unchanged after actual loading exists.
Two logical captains compete in tests; public-world offer RPCs are not yet wired.

Validation: 119-script/startup, FlowCheck and Release export pass. Editor combined
suite: 174 at output/ports/ca10101b. Rendered Release: 177 checks at
output/ports/51542faf; offer HUD screenshot inspected. Fourteen new tests cover
seed stability, copied reads, origin/ship compatibility, exclusive acceptance,
retry/immutable terms, pending capacity, exact expiry and non-rewinding clock.

Next: repair the deferred heavy-loader pickup issue before Step 50 loading.
Later docking UI removes water guides in favor of grey/colored Dock feedback.
