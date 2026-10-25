# Step 57 integration — Online port anchors and docking

October 25, 2026. Physical online ports and docking now work; full cargo gate OPEN.

Brindle Quay is anchored at latitude/longitude 0/0. Slatewater Works is 1,500 meters
west in the existing provisional 100 km globe model, matching the local +X layout.
Nearby server physics charts instantiate authored port scenes and reposition them
with the same geographic projection/transport used for boats. Ports outside the
2,500-meter chart neighborhood are absent. Client presentation receives up to two
port poses within 2,200 meters and renders them with all local collisions disabled.
Only server port geometry collides. Saved hull spawns intersecting authored quay
or approach-marker bounds are conservatively refused, without teleport/save edits.
The spawn guard covers current surface obstacles; keep it synchronized with any
future authored solid geometry beyond quay/approach footprints.

A server-wide docking coordinator owns berth reservations by stable port ID and
maps each authenticated peer to its server-owned hull. It checks real shared-space
position, heading, speed, cargo/service compatibility and obstruction. No supplied
ship/account data can substitute for the peer binding. Dock/Undock requests check
ship, lease epoch, connection generation, increasing sequence and rate. Requests
are explicit actions, not toggles; no automatic retry. One berth means one owner.
Docking takes one second; undocking half a second. Docked helm orders are refused.

Port ownership is independent of transient physics-space nodes, surviving chart
regrouping and rebases. Eligibility queries wait through the chart-changing frame
so new collider transforms can settle. Disconnect, ownership loss and server drain
release reservations. Reconnect restores saved position neutral and underway;
berths are not blindly reclaimed from stale saved locks.

The online player sees server readiness and a grey/green Dock button, changing to
Undock when secured. Buttons do not capture helm keyboard focus. Pending actions
wait for sequence acknowledgment; after four seconds the UI reports an unconfirmed
request and asks for reconnect/reconciliation rather than resubmitting. No new
water docking markings. Existing temporary approach buoys remain authored geometry.

Game DTLS protocol is now 10 because of new port-update/docking RPCs; client and
server builds must match. Backend authority ticket protocol remains 7. Port update
bytes/packets are included in snapshot counters. Two fixed ports at 10 Hz are a
bounded first-voyage implementation; previous bandwidth measurements must not be
quoted as measurements of this new payload without rerunning those workloads.

## Bug found by the rebase check

A tiny negative north bearing could round to 360 degrees, which the canonical
address decoder rejects. wrap_scalar now handles the exact excluded upper endpoint
without approximate comparisons that erase valid near-seam values. Docked rebase
and the existing 342 geography assertions pass after the fix.

## Evidence

136-script/startup check and updated Release export pass.
- Two actual DTLS players on normal dedicated server: 19 checks in editor and
  Release, including rendered ports, forged binding refusal, occupied berth,
  docked helm refusal, disconnect/regroup, undock and full server restart.
  Editor ../output/handoff/a5d9d20a; Release ../output/handoff/57d9597d.
  Rendered docked view inspected at peer-2/helm.png.
- 37 shared-physics checks: editor ../output/shared-physics/31d56c79;
  Release ../output/shared-physics/34bcfcb7. Includes geographic berth placement,
  actual shared collision world, retained lock/pose through rebase and authority loss.
- Existing local voyage, two-consecutive deliveries, reopen and transaction-crash
  regression passes in Release: ../output/voyage/92b2c04b.
- 342 geography assertions pass in editor.

No local save conversion or public player progression reset. Existing private
Port Test remains available. Next: peer-bound cargo service requests, durable
contract calls and client job/manifest presentation. This is not yet the complete
two-peer accept/load/sail/deliver gate. No Step 58 progression yet.
Recovery tag public-ports; archive ../output/checkpoints/public-ports-2026-10-25.zip.

Additional Release regression: 24 two-player sailing/contact/independent-save/server-
restart checks pass, ../output/handoff/470b1bae/ports-sailing-regression.json.
