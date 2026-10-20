# Step 24 — Simulation checkpoints

The accepted handling is now protected by fixed-input, 60 Hz playback. Run
`tools/Godot.ps1 -Mode HandlingCheck` or `tools/CheckProject.ps1 -Full`.
For Windows Release use `-Mode RunExport -Configuration Release -Headless -HandlingProbe`.
No gameplay tuning or player settings are changed by this step.

## Saved inputs and tolerances

`tools/simulation_checkpoint.gd` owns immutable fixture segments and recorded
reference values. Segment inputs are normalized throttle-adjustment, rudder and
thruster axes, plus neutral order, applied before each production motion tick.
Orders persist when the adjustment axis returns to zero. Every run starts with
a fresh ship and a private copy of its definition.

| Playback | Accepted reference | Absolute tolerance |
| --- | --- | --- |
| Hold W for 444 ticks | 4.00465 m/s, 14.05862 m travelled; reaches 4 m/s in 7.40 s | 0.03 m/s, 0.15 m, 0.10 s |
| Then hold S for 720 ticks | Ahead motion stops after 11.5833 s of braking, over 26.32986 m | 0.10 s, 0.25 m |
| Accelerate, then hold D for 600 ticks | 27.77449 degrees starboard; x -14.33049 m, z 70.40244 m | 0.20 degrees, 0.20 m, 0.30 m |
| Hold E for 300 ticks, release for 120 | x -4.03194 m, side speed -0.38852 m/s; heading unchanged | 0.08 m, 0.02 m/s, 0.02 degrees |
| Accelerate, then X for 300 ticks | 2.95517 m/s remaining; 32.08505 m total travel | 0.03 m/s, 0.20 m |

Braking playback continues briefly into reverse to allow a tolerance around the
zero-speed crossing. Braking distance sums ahead travel before the first crossing;
it excludes the tiny first astern tick. Stop time is measured from the whole replay
start in the machine report; subtract the 7.4-second acceleration segment.
Additional guards cover final speeds, positions, engine output and power exposure.

## Fuel-ready telemetry

Returned replay data includes one-second samples with tick, elapsed seconds,
commanded throttle, actual engine output, speed, rudder and thruster order.
Segment endpoints and separate integrals of positive/negative actual engine
output are recorded. Units are full-output-equivalent seconds, not liters or fuel
consumption. A later fuel model can consume these inputs without treating command
as delivered power. No fuel formula is invented in this step.

## Limits and maintenance

Playback runs the production motion model with explicit fixed delta and integrates
unobstructed position numerically; it does not emulate collision sweeps, network
latency, a real clock or saved-game playback. CollisionCheck and the existing
30/60/144-render-cap handling checks still cover the live CharacterBody path.
The fixture constants provide input playback, not a player-facing replay recorder.

Same-process repeated telemetry must match; comparisons against recorded baselines
use tolerances and do not promise bit-identical physics across machines. Tests
prove the guard rejects a 20% thrust change and nonfinite results, while accepting
small numerical drift. The altered definition exists only in a private test copy.

Failures name the fixture, metric, expected value, tolerance and observation.
JSON summary lines are written to the handling check log; detailed telemetry is
returned by replay for later analysis. Baselines never rewrite themselves. For an
intentional tuning change, inspect results and user feel before explicitly revising
references; do not widen limits merely to make a failed test pass.
