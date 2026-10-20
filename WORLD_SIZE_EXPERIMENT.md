# Step 25 — World-size experiment

## Selected technical direction

Preserve the connected, continuously navigable world selected in the map reference.
Use scalar-double geographic addresses for global identity, with nearby hulls,
colliders and cameras in shared meter-scale local physics patches. Shift/rotate
related entities together when the local frame changes. Scenery regions belong
to the same session; they are not isolated levels or automatic server transfers.

The experiment uses a 100,000 m navigation radius and 1 meter per scene unit.
This is an explicit engineering profile, not an approved final voyage-time scale.
Compare 50,000 and 250,000 m profiles below before final content dimensions.
Target a frame change around 500 m from the local center, keeping active interaction
geometry within the tested +/-1 km range. Do not send float32 globe coordinates
to CharacterBody3D. A custom double-precision engine build is not needed for this
prototype: local coordinates solve the demonstrated precision problem.

## Measured precision

Pinned Godot 4.7.2, ordinary float32 scene vectors, scalar-double navigation math.
Each hull coasts at an initial 0.1 m/s for 60 physics ticks, then travels at up to
20 m/s into a 0.1 m thick pier. The same production controller/collider/camera is
used at each coordinate offset. Baseline travel includes drag.

| Offset on X and Z | Slow travel in one second | Final hull center Z relative to origin | Contact | Camera lag after settling |
| --- | --- | --- | --- | --- |
| 0 m | 0.096040525 m | 7.931005 m | yes | 0.001079 m |
| +1,000 m | 0.096008301 m | 7.930969 m | yes | 0.001038 m |
| -1,000 m | 0.096008301 m | 7.930969 m | yes | 0.001038 m |
| 100,000 m | 0 m | 7.929688 m | yes | 0.046875 m |
| 1,000,000 m | 0 m | 8.25 m | no | 0.375 m |
| 10,000,000 m | 0 m | 0 m | no | 0 m (hull did not move) |

Far controls are intentionally unsuitable; their failures are measurements, not
supported ranges. At +/-1 km the slow-motion error is about 0.032 mm and contact
position differs by about 0.036 mm. The runtime assertions allow 5 mm motion error,
require actual pier contact without penetration, and camera lag below 1 cm.

## Connected geography and frame proof

`navigation_experiment.gd` advances great-circle position and transports the
forward tangent using scalar-double sine/cosine arithmetic. It avoids dividing
longitude by cos(latitude). Exact poles retain a reference meridian. The local
projection is azimuthal equidistant, +X port and +Z local north. Antipodal points
are outside a local chart and return an invalid local position.

One-meter steps across the seam and both poles preserve distance within 10 microns;
500 m endpoints and equatorial/meridian full circuits close within 1 mm. Scalar
address JSON round trips preserve location. Nearby markers 200 m apart at a 900 m
patch offset agree with spherical separation within 5 mm. These are synthetic
unobstructed navigation paths, not coastline-safe shipping routes.

Two actual hull pairs on opposite sides of the seam/pole are projected into one
shared local physics space; their collisions remain solid. A polar frame-change
fixture maps a ship, solid pier, camera pose/smoothing state and attached visual
together. It preserves relative view, solid placement and payload offset within
1 mm, local velocity within 0.00001 m/s, and speed. Contact still works after the
physics broadphase updates. This is a bounded rigid frame-change experiment, not
a claim that arbitrary distant chart geometry is exactly isometric.

A tiny negative bearing could round to exactly 360 degrees, failing the existing
canonical-address validator. The experiment explicitly maps that endpoint to zero;
it does not use approximate equality that could erase real near-seam differences.

All open water remains navigable under D048. No depth restriction or grounding
query is reintroduced. Collision checks cover the visible solid boundary instead.

## Voyage-time comparison

At a constant 10 m/s (19.44 knots), without acceleration, land detours or stops:

| Navigation radius | Circumference | 10-degree medium trip | Opposite-side direct separation | Full circuit |
| --- | --- | --- | --- | --- |
| 50 km | 314.159 km | 14.54 min | 4.36 h | 8.73 h |
| 100 km (experiment) | 628.319 km | 29.09 min | 8.73 h | 17.45 h |
| 250 km | 1,570.796 km | 72.72 min | 21.82 h | 43.63 h |

A synthetic 2 km starter trip takes 3.33 minutes at that speed, regardless of the
radius; at the earlier 4 m/s maneuvering benchmark it takes 8.33 minutes. This does
not assign Harbor Point coordinates or approve travel pacing. East Coast–Harbor
Point and actual longest water-valid crossings still require authored endpoints
and routes. Global positions, local meters and distance units must share one
chosen profile; do not invent unrelated payout distances to hide long voyages.

## Boundaries and next gates

The experiment is isolated from Boat Handling Test and changes no approved handling.
It selects a coordinate approach; it does not add a finished globe, streaming world,
authoritative multi-region owner, production rebase scheduler or seamless network
handoff. Network ownership, reconnect, heavy payload physics and durable spatial
schema still belong to connected-world-network-feasibility after Steps 29–31.

Before integrating frame changes with the playable scene, also map wake histories,
shader sampling origins, camera smoothing, payloads and every nearby collider in
the same commit. The experiment tests a simple attached visual only. It does not
claim that the current handling scene can already sail around the planet.

Run tools/Godot.ps1 -Mode WorldSizeCheck. Included in CheckProject.ps1 -Full.
Export verification: -Mode RunExport -Configuration Release -WorldSizeProbe.
The normal menu remains the default launch; the diagnostic route is explicit.
