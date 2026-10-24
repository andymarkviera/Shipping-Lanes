> Updated October 24: DOCK_SERVICES_REDESIGN.md supersedes the timed-offer, water-guide and test-service assumptions below. This file retains earlier checkpoint history.

# Step 50 — Port loading and prerequisite heavy pickup repair

Heavy fixture: the lowered deck collider's top exactly touched the floating
payload's underside. A 0.15 m inset of the deck collision surface provides clearance
for the stern-first approach without removing cargo, hull or shore collision.
A regression check restores the old flush collision and reproduces the blocked
sweep, then verifies the corrected carrier reverses 72 m under the stationary load,
secures it without staging, releases and drives clear. Existing lift-obstruction,
attachment and collision ownership tests remain. The HUD now shows lateral/length/
heading offset and stern-approach guidance; the staging button is explicitly optional.
This fixes a reproduced pickup path, not every possible user-reported collision.

Port Test: accept a container job, dock at its origin, then Load accepted cargo.
The authority node owns progress at five seconds per container. The UI reads it;
hiding presentation cannot complete or pause the transaction. Repeated start is
rejected. Completion rechecks ownership, docked state, origin and capacity, adds the
validated manifest batch and changes the accepted offer to loaded synchronously.
Pending accepted commitments count toward capacity; loaded offers no longer count
as commitments because their actual batch now occupies that space. No payout occurs.

Cancellation policy: no partial cargo; release the accepted job back to available
if unexpired, otherwise expired. Disconnect/preview exit cancels unfinished loading
and releases all this ship's unstarted accepted jobs. Lost docked state interrupts
loading. Undock is disabled in the preview during loading, with authority validation
still protecting non-UI requests. Completed cargo is not rolled back. Switching test
ports cancels pending work but carries the completed manifest to the replacement
starter boat. This is still a temporary preview; leaving it discards session state.

Scope: one local authority in Port Test; the same node/rule is intended to run on
a server. Trusted identity is bound by the caller. Public ports/loading RPCs and
network-disconnect routing are not installed by this step. Tests invoke the authority
interruption hook rather than claim actual public-peer loading coverage. Completion
is atomic in this synchronous runtime, not crash durable; Step 51 must persist offer,
manifest and operation receipt together. No new private/public save format yet.
Container visuals, delivery settlement and production shared-world travel remain
later work. Heavy fixture payload is still separate from container offer loading.

Validation: 121 scripts/startup, FlowCheck and Release export pass. Heavy checks
pass 37 in editor and Release (output/heavy-pickup-release.log). Editor port/cargo
suite passes 184 (output/ports/6d2a23c5); final rendered Release passes 187
(output/ports/955e8c81), including screenshot inspection. Added loading coverage:
undocked rejection, double start, progress without cargo, cancellation, hidden-UI
completion, duplicate-load rejection, capacity conversion, interruption and dock loss.
An initial typed-array scene-switch failure was corrected before final checks.

Next: Step 51 in-flight operation persistence. Preserve the later UI preference:
remove water docking guides and use disabled/colored Dock feedback. Foam polish later.
