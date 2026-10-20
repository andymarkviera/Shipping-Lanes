# Connected-world network feasibility

Supplemental prerequisite after Step 31, October 20, 2026.

## Result and selected contract

The scalar-double geographic address plus bounded shared local-meter chart method
passes the two-process experiment with a real heavy-lifter and compound payload.
Retain world ID, content revision, latitude/longitude/altitude, transported heading
and reference-meridian frame as the persistent spatial identity fields. The
fixture uses `world_coordinate_fixture`, revision 1 and a 100,000 m radius; these
are engineering values, not a final production world catalog or voyage scale.

Session epoch, authoritative entity/owner ID and an increasing chart/state revision
accompany the network envelope. Origin, local position, local velocity, yaw, nearby
marker and cargo-parent identity travel together in one reliable transition
snapshot. Receivers validate the address and its agreement with local position;
stale revisions, wrong world revision/owner/epoch, nonfinite velocity and mixed
chart/local positions are rejected. The fixture has one host owner throughout;
it does not transfer ownership on crossing the seam or poles.

This establishes the spatial field and atomic transition contract for later
save/network integration. Local chart coordinates remain derived/transient;
they must not replace geographic identity in durable ship records. A new world
radius/content revision requires deliberate migration, not silent reinterpretation.
Production frame transitions must invalidate or remap old interpolation samples
at the same revision boundary. The isolated fixture uses reliable complete states;
it does not yet splice rebasing into the playable 20 Hz motion buffer.

## Reproducible evidence

Run `tools/Godot.ps1 -Mode ConnectedWorldCheck`. Exported checks use
`tools/CheckNetwork.ps1 -Runtime Release -ConnectedWorld` and the same command
with `-Profile impaired`. Included in `CheckProject.ps1 -Full`.

Each run starts two real loopback ENet processes. The observer receives six states:
before/after a 500 m chart transition at the longitude seam, north pole and south
pole. Endpoints use the Step 25 great-circle transport; the fixture places the
ship at those endpoints rather than pretending to sail the whole trip in real time.

The host lowers, aligns, secures and raises a disposable payload using the actual
heavy-lifter methods. Each transition maps hull, marker, velocity and camera
together. The attached visual follows its parent once. The loaded ship then moves
into a high solid rail: the payload blocks it, while the bare hull clears the
same sweep. A nearby marker is retained in the observer's interest set and tested
in ship-local space. This is a bounded interest-coherence proof, not a streaming
or interest-culling implementation.

The host writes its final envelope to a disposable JSON file, closes it, reloads
and validates it. The observer disconnects and reconnects, receives that reloaded
state, and verifies the same retained host ship/payload identity. Rejoining still
creates a fresh temporary guest roster entry, as in Step 29. This is not account
recovery, economic durability, host restart recovery or a storage transaction.

Both normal and impaired profiles pass **75 assertions** (36 host, 39 client)
in the pinned editor and Windows Release. Here impaired means 120 ms state delay
and 80 ms acknowledgement delay over the reliable channel; it does not simulate
packet loss or reuse the motion test's jitter/loss profile.

| Measurement | Maximum recorded |
| --- | --- |
| Host camera-relative shift error | 0.000003815 m |
| Client camera-relative shift error | 0.000030518 m |
| Client payload-anchor position error | 0 m |

One-millimeter camera/payload checks pass. Speed remains 4 m/s across received
transitions, and host local velocity changes by less than 0.00001 m/s. The tested
local range remains the Step 25 +/-1 km budget. Reliable acknowledgement handshakes
finish before reconnect/shutdown, including delayed acknowledgements.

## Boundaries

No playable-world expansion, camera/water change or boat handling retune is part
of this prerequisite. Before playable rebasing, transport wake history, shader
origins, camera smoothing, all nearby bodies and buffered motion as one operation.
Final scale, streaming, durable saves and public authority retain their later
gates. Andy's manually reported cargo pickup/sticking and neutral difficulty are
still open; successful automated alignment does not resolve those reports.

Next numbered step: **32 — early dedicated capacity experiment**.
