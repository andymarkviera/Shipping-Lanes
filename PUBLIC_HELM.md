# Public helm completion and throttle indicator

Public clients now transmit saved left/right thruster input alongside throttle
and rudder. The server validates finite, bounded lateral intent within the same
peer/ship/epoch/generation, sequence and rate checks. Existing server physics,
fuel use and speed-dependent thruster effectiveness remain authoritative. Menu,
focus loss, stale state and input timeout select zero lateral intent.

Game admission wire protocol is now 8, and complete snapshot encoding is version 2.
Run matching client/server builds. This is separate from the unchanged HTTPS
service ticket protocol 7. Header size is 36 bytes (previously 32), adding signed
forward velocity alongside total speed. Decode rejects non-finite velocity or
forward magnitude exceeding total speed. Eight hulls use 356 payload bytes / 448
serialized RPC argument bytes, still below the 1,200 argument-byte limit. Historical
pacing results remain labeled with the old 444-byte arguments; no fresh throughput
measurement is claimed here.

The shared opaque bottom-center indicator shows commanded reverse/neutral/forward
position and actual movement, including coasting at neutral. It cannot capture
keyboard focus or change the throttle with a mouse. Local ShipHelm scenes and the
local/private network fixture use their hull state; public motion is authoritative
snapshot data. No braking, acceleration, stop threshold or pickup eligibility was
retuned. Nearly stopped is a display label, not docking/pickup eligibility.

## Verification

- Godot script check: 109 scripts and startup pass.
- FlowCheck, FeedbackCheck (24), CompositionCheck (60) pass.
- Compact snapshot checks: 24 in editor and Release; signed reverse velocity,
  finite data, malformed sizes/records and existing budget covered.
- Public peer regression: 55 editor checks, adapter tickets, evidence
  ../output/handoff/e4bb18bd/peer-summary.json. Authenticated ownership/admission,
  two boats, input fences, saves/outage and normal dedicated entry remain intact.
- Saved thruster inputs, both directions, menu/focus/timeout clearing, invalid
  lateral rejection, authoritative reverse motion and neutral/coasting display:
  11 editor checks in ../output/handoff/228f6975/helm-summary.json;
  12 graphics-enabled Release checks in ../output/handoff/d651e434/helm-summary.json.
- Rendered HUD inspected at ../output/handoff/d651e434/peer-2/helm.png. This is
  automated local testing and agent visual inspection, not a human playtest.

The initial controls fixture relied on one unreliable packet and timed out; its
final timeout setup sends paced repeated intent like the game. No production change
was needed for that harness assumption. Expected wrong-host TLS rejection logs in
the peer regression are intentional; no script errors appeared in final runs.

Step 42 remains open; see FOUNDATION_ACCEPTANCE.md for the finite remaining work.
