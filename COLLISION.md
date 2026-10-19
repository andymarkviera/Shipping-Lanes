# Step 21 — Hull and shore collision

Boat Handling Test now includes a thin head-on pier 300 m ahead, an angled pier
on the port side, two rock blocks, and an L-shaped coastline beyond the gold
turning course. The original starboard practice berth remains available. These
are collision blockouts, not final island or dock art.

## Collision policy

| Godot layer | Bit | Role |
| --- | --- | --- |
| 1 | 1 | Ship hulls |
| 2 | 2 | Shore, rocks and piers |
| 3 | 4 | Non-solid triggers (reserved) |
| 4 | 8 | Cargo visual proxies (reserved) |
| 5 | 16 | Characters (reserved; walking still deferred) |

Hull queries collide with hulls and shore only. Shore has hull/character mask bits.
Camera sweeps consider hull/shore solids and exclude the focused hull. Real cargo
visuals, ocean, decorative markers and visible hull meshes remain render-only.
Triggers should use Area3D with a hull mask; this step reserves the policy but
adds no cargo/character gameplay. Constants are in CollisionRules; layer names
are also visible in the project settings.

## Motion and contact

The prototype uses a simple 13 × 4 × 64 m box collider at local Y=1, independent
of visible bobbing. CollisionRules.add_box_hull constructs it. Movement remains
CharacterBody3D at 60 Hz: move_and_slide sweeps the entire shape across each step,
with a 2 cm safety margin and at most six slide resolutions. Contacts remove
velocity directed into the surface and cannot increase speed above its pre-contact
value. There are no rebound impulses or moving-platform velocity inheritance.

Supported total speed is capped at 20 m/s before translation, above the current
10 m/s ahead and 3.75 m/s astern tuning. Tests cover impacts within this envelope
and an oversized velocity request that must clamp. This does not authorize a
future faster ship without revisiting collision checks.

Turning is checked separately because translational body sweeps do not sweep
rotation. The proposed hull pose is overlap-tested with an extra margin equal
to its bounding radius times the turn angle, conservatively covering the angular
arc. A blocked turn holds heading and clears yaw rate. Close to a pier this can
prevent even a small turn; move sideways away before rotating. Prototype hulls
must have direct CollisionShape3D children, unit scale, and start outside solids.

Shore/rock proxies are vertical prisms, keeping this planar fixture from climbing
sloped faces. The initial spawn must be clear; teleporting inside obstacles is
not a supported recovery path. No damage, grounding depth, realistic angular
impact, moving-ship mass exchange or network collision reconciliation is claimed.

## Verification

CollisionCheck runs 16 separated fixtures for 180 actual physics ticks. Thirty-
five assertions cover head-on 1/10/20 m/s, reverse 3.75/20 m/s, glancing and angled
hulls, sideways contact, corners, held thrust, near-wall rotation, excluded layers,
other-hull layer and overspeed clamp. Every tick checks bounds, planar position,
finite speed and maximum movement. Thin test walls are 0.1 m thick, narrower than
a maximum-speed tick's travel. Glancing contact must retain along-wall movement;
held thrust must settle without bounce.

The checks pass in editor and Windows Release. Full passes 15 stages and compiles
48 scripts; all handling/camera/water checks still pass. Native course capture
inspected. Run tools/Godot.ps1 -Mode CollisionCheck, or exported
-Mode RunExport -Configuration Release -Headless -CollisionProbe.
