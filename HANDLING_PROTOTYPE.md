# Step 16: handling prototype

Open **Boat Handling Test** on the main menu, or run
`tools/Godot.ps1 -Mode Run -Scene res://features/handling/handling_test.tscn`.
Hold W for forward thrust; release to coast; hold S to brake and then reverse.
Saved key bindings apply. Escape returns to the title. Ctrl+F3 shows live motion.
The simple box hull has a gold bow marker and a white aft block. Fixed markers
beside the lane show motion across flat water in the selected coastal palette.

## Body decision and comparison

Selected CharacterBody3D in floating mode, advancing only at the explicit 60 Hz
physics tick. Its controlled velocity is straightforward to tune and constrain
to a flat water plane. Linear drag preserves inertia at zero thrust, while reverse
thrust first brakes forward motion and then accelerates astern. move_and_slide
keeps a collision-capable boundary, though collision response is not tuned here.

A force-driven RigidBody3D would naturally exchange impulses and support later
physical buoyancy, but requires mass, rotational constraints and contact tuning.
Those behaviors are unnecessary for this planar propulsion test. This is a design
comparison, not a claim that both bodies were implemented or benchmarked. Revisit
if wave/contact requirements demand force-driven handling.

Prototype values: forward acceleration 0.8 m/s², reverse 0.5 m/s², linear drag
0.08 /s; asymptotic speeds +10 / -6.25 m/s. These are disposable handling values,
not approved ship balance. Velocity uses the exact constant-thrust linear-drag
solution per tick; position uses fixed-step CharacterBody movement. This physics
clock is separate from the authority's 20 Hz operation clock.

## Verification and limits

HandlingCheck runs actual physics callbacks with rendering-loop caps 30/60/144,
300 ticks per run: accelerate 60, coast 60, reverse 180. Eighteen checks cover
acceleration, continued coasting, reverse braking, eventual reverse, planar motion,
and matching final speed/position within 0.00001. Headless caps exercise loop
scheduling, not GPU performance. Editor and Windows Release pass. Full project
checks pass (12 stages / 38 compiled scripts). Native scene capture inspected.

Controls use the existing focus/menu input boundary; losing input removes thrust
while inertia continues. There is no persisted ship state or multiplayer movement.
The camera is a temporary fixed follower. Steering, engine ramping, production
camera controls and waves remain steps 17–20. The starter model is preserved for
later integration; the roadmap explicitly requests a box in this isolated scene.
