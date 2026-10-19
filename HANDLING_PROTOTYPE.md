# Boat handling prototype — current controls (Step 17)

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

HandlingCheck now has 42 checks: forward/reverse command limits, invalid commands,
command retention, independent engine ramping, zero preserving momentum, reversal
through neutral, 600 rapid reversal orders, copied tuning, catalog rejection and
mapped input/focus behavior in the actual scene. Physics runs at loop caps
30/60/144 for 300 ticks each: forward 60, zero 60, reverse 180. It checks powered
motion, coasting after engine neutral, reverse braking, astern motion and matching
final position/velocity within 0.00001. Headless caps exercise scheduling, not GPU
performance. The checks pass in editor and Windows Release. The full 12-stage
suite passed, and the updated native HUD capture was inspected.

The box hull has a gold bow marker and white aft block. Lane markers show motion
across flat coastal water. The camera is a temporary follower. No persisted ship
state or multiplayer movement yet. Steering, production camera controls and waves
remain steps 18–20. The starter model is preserved for later integration.
