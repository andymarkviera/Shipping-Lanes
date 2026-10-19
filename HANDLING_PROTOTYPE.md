# Boat handling prototype — current controls (Step 18)

Open **Boat Handling Test** on the main menu. Hold W to raise commanded throttle,
S to lower it through neutral into reverse. Release either key to keep the order.
Press X to order zero throttle; this does not stop the ship instantly. The engine
winds down and water drag slows the remaining motion. Saved bindings apply.
Escape returns to the title. Ctrl+F3 shows live motion diagnostics.

The HUD separates command, engine output and signed speed. A negative engine
order can brake a ship that is still moving forward. Losing window focus, opening
a menu or blocking ship input orders neutral; returning requires held keys to be
released before commands resume. The Space brake binding remains reserved.

## Tunable ship data

The starter ShipDefinition stores all current handling values. Catalog validation
rejects non-finite/nonpositive values and throttle limits above 1. The handling
fixture copies its definition, preserving the shared asset.

| Parameter | Prototype value |
| --- | --- |
| Forward / reverse acceleration | 0.8 / 0.5 m/s² per unit throttle |
| Linear drag | 0.08 /s |
| Forward / reverse throttle limit | +100% / −60% |
| Command adjustment | 50 percentage points/s |
| Engine power increase / decrease | 50 / 100 percentage points/s |

Opposite orders first reduce actual throttle to zero; opposite power starts on
the next physics tick. Actual throttle never jumps to the command. At these
values the flat-water asymptotic speeds are +10 and −3.75 m/s. These are temporary
handling values, not approved ship balance. No fuel consumption is implied.

## Body decision (Step 16)

Selected CharacterBody3D in floating mode at an explicit 60 Hz physics tick,
with +Z as the bow. Controlled velocity is straightforward to tune and constrain
to a flat water plane. Linear drag preserves inertia. move_and_slide provides a
collision-capable boundary; collision response has not been tuned.

A force-driven RigidBody3D would naturally exchange impulses and support physical
buoyancy, but requires mass, rotational constraints and contact tuning. Those
behaviors are unnecessary for this planar propulsion test. This is a design
comparison, not a claim that both bodies were implemented or benchmarked.
Revisit if wave/contact requirements demand force-driven handling.

Velocity uses the constant-thrust linear-drag solution for each tick, with the
new engine output sampled once per tick. Position uses fixed-step body movement.
This clock is separate from the authority's 20 Hz operation clock.

## Verification and limits

HandlingCheck now has 72 checks: forward/reverse command limits, invalid commands,
command retention, independent engine ramping, zero preserving momentum, reversal
through neutral, 600 rapid reversal orders, copied tuning, catalog rejection and
mapped input/focus behavior in the actual scene. Physics runs at loop caps
30/60/144 for 300 ticks each: forward 60, zero 60, reverse 180. It checks powered
motion, coasting after engine neutral, reverse braking, astern motion and matching
final position/velocity within 0.00001. Headless caps exercise scheduling, not GPU
performance. The checks pass in editor and Windows Release. The full 12-stage
suite passed, and the updated native HUD capture was inspected.

The box hull has a gold bow marker and white aft block. Lane markers show motion
across flat coastal water. The Step 19 orbit camera provides RMB orbit, wheel zoom and recenter; see CAMERA.md. No persisted ship
state or multiplayer movement yet. Water presentation remains Step 20. The starter model is preserved for later integration.

## Step 18: maneuvering

Hold A/D for port/starboard rudder and Q/E for port/starboard lateral thrust.
These are ship-relative directions, not screen-relative. Releasing the rudder
winds yaw rate down; releasing a thruster leaves sideways momentum to decay.
At zero forward speed the rudder has no authority. Authority rises linearly to
full at 4 m/s; yaw is limited to 3 degrees/s and changes at 2 degrees/s².

Reverse steering rule: rudder yaw reverses with signed forward speed. D swings
the bow starboard while going ahead, port while going astern. Throttle command
does not decide steering direction: actual travel does. Thrusters always push
toward their labelled ship side in both ahead and astern travel and introduce no
yaw. With +Z bow and +X port, starboard thrust is local -X.

Editable ShipDefinition parameters: max_turn_rate_degrees (3),
turn_acceleration_degrees (2), rudder_full_effect_speed_mps (4),
thruster_acceleration_mps2 (0.4), lateral_drag_per_second (0.4),
thruster_cutoff_speed_mps (4). All must be positive finite values.
Thruster power fades linearly from full at rest to zero at 4 m/s ahead or astern.
Linear lateral drag bounds steady sideways speed to 1 m/s at rest; it does not
instantly erase drift. This controlled-body model turns the local velocity with
the hull; it does not yet model realistic sideslip, prop wash, separate bow/stern
thrusters, grounding, damage or angular collision response.

### Practice course

From the starting heading, sail toward the first gold marker 100 m ahead. Use D
to make a broad starboard turn toward the next two gold markers, forming a U.
The markers are visual guides, not scoring triggers or collision obstacles.
For a sideways approach, start a fresh test, leave throttle at zero, and hold E
toward the brown quay on the starboard side. Q pushes away. The quay has a solid
collision shape and a pale edge strip. Contact is only a practice collision;
there is no mooring or cargo transaction here. Return to title and reopen the
test to reset. The camera follows smoothly; RMB orbits, wheel zooms and C recenters.

Added checks cover speed-sensitive yaw, bounded yaw acceleration/rate, neutral
rudder at rest, forward and astern signs, gradual yaw release, finite lateral
terminal speed after 60 seconds of simulated input, lateral coasting, high-speed
thruster cutoff, invalid input/tuning and mapped controls/focus. A real physics
approach uses the box collider and solid quay. A parallel turning body checks
position/heading repeatability at 30/60/144 loop caps. All 72 checks pass in editor
and Windows Release; Full remains 12 stages. Native course/HUD capture inspected.
