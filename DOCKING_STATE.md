> Updated October 24: DOCK_SERVICES_REDESIGN.md supersedes the timed-offer, water-guide and test-service assumptions below. This file retains earlier checkpoint history.

# Step 46 — Docking state machine

Port Test now has Dock, Undock and transient Cancel controls. Readiness is checked
again on request. Approaching means within 150 metres of the berth anchor; it is
not eligibility. Valid requests atomically acquire a single-capacity berth, enter
docking for one second, then docked. Propulsion, residual speed and yaw are cleared
while securing or secured. The ship stays where the player positioned it.
Undocking holds the reservation for half a second, then returns to underway with
neutral controls, without teleporting. The existing hull collider continues to
block another ship until the departing ship actually leaves the berth.

Cancel docking releases the hold and returns underway. Cancel undocking returns
to docked with the reservation intact. Eligibility/clearance is rechecked during
securing; new obstructions abort and release. Explicit disconnect, body/port tree
exit and authority teardown release reservations. Exit callbacks check body/port
identity so an old port cannot unregister a replacement using the same owner ID.
Berth reservations also hold their world volume in the Step 44 spawn allocator.
Non-solid corner guides and a bow label identify the berth without blocking water.

The authority component takes trusted owner IDs resolved by its caller. It has no
RPC endpoint accepting client ownership or readiness claims. In Port Test it runs
as local authority. Tests use two logical owners against the same authority and
verify exclusive allocation. Actual two-network-peer port docking is not yet
wired/tested: public geographic port installation and peer-owner binding remain
integration work. No public saved docking state, cargo operations or economy changes
are claimed here. This component must run only on the server when wired online.

Validation: 115-script/startup check, 42 fuel checks, FlowCheck and Release export
pass. Editor port suite: 116 checks, output/ports/5391b413. Final rendered Release:
119 checks, output/ports/3bedd6f5, with screenshots; Brindle HUD visually inspected.
Added tests cover fast approach rejection, approaching, securing, competing owners,
repeated requests, docked propulsion lock, undocking cancellation/completion,
no teleport, docking cancellation, new obstruction and disconnect cleanup.

Next: Step 47 cargo manifest. Heavy-loader pickup repair remains due before
Step 50. Wake/foam polish later; no peer transfers or hidden shallows.
