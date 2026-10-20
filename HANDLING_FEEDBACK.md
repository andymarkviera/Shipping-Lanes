# Step 22 — Handling feedback baseline

Step 28 update: fuel is now connected to per-ship state in both handling scenes.
The original unconnected-fuel descriptions below record Step 22 history.
See FUEL_SIMULATION.md for current rules, recovery and validation.

Status: accepted handling baseline, October 19, 2026. Andy reported that he really
loves how it all feels. Preserve current tuning; revisit loaded/network behavior
in their later steps. No separate detailed audio audition is claimed.

## Added feedback

The HUD shows speed in knots, ahead/astern/lateral direction, local heading,
commanded throttle, actual engine output, effective lateral-thruster output,
side drift and yaw rate. Local +Z is test north (000°), starboard is 090°; this is
not a geographical compass. Fuel is explicitly "not connected": this isolated
fixture has no authoritative fuel source or consumption model. No invented fuel
quantity or simulated usage is shown.

Original synthesized engine and thruster loops follow actual output, not just
key presses. Above the thruster speed cutoff, the sound fades and the instrument
shows TOO FAST when a thruster is requested. H plays a 1.2-second horn with soft
attack/release; repeated requests while it plays cannot stack voices. Saved
bindings and master volume apply. Menu/focus blocking stops the sounds. Feedback
only reads the ship; it cannot change velocity, throttle, fuel or navigation.

Loops are mono 22,050 Hz, 16-bit PCM, generated once per feedback node. Engine
output varies pitch and volume; thruster output controls a separate loop. Full
output is capped at -25 dB for engine, -27 dB for thruster and -18 dB for horn,
before master volume. These are simple prototype tones, not final engine assets.

## Recorded baseline

Tuning is unchanged from Steps 17–21. At 60 Hz, starting from rest and continuously
holding W reaches 4 m/s (7.78 knots) in 7.40 s, over 14.06 m. Immediately holding S
from there reaches zero ahead motion in 11.58 s, over another 26.33 m. The recorded
distances integrate fixed-tick velocity in an unobstructed numerical fixture;
they are regression references, not Andy's playtest results. Continuing S then
accelerates astern. X orders neutral and coasts; it is not an instant brake.

## Optional future regression playtest

1. Open Boat Handling Test. Hold W until roughly 8 knots, then hold S until ahead
   motion stops. Judge acceleration, engine response and stopping distance.
2. Try A/D at speed and astern. Orbit with RMB, zoom, then C to recenter. Check
   whether the camera or bobbing feels uncomfortable or hides nearby obstacles.
3. Start a fresh test, leave throttle at zero and use E toward the starting quay,
   then Q away. Try H and listen to the engine/thrusters during movement.

Report what feels too slow/fast, hard to line up, uncomfortable, or hard to hear.
There is no need to test every prior build step.

## Prioritized review queue (not reported defects)

| Priority | Review | Status |
| --- | --- | --- |
| P0 | Camera/bobbing discomfort or obscured docking view | Overall feel accepted; revisit if an issue arises |
| P1 | Brake distance, throttle lag, turning and sideways docking controllability | Overall feel accepted; revisit if an issue arises |
| P1 | Instrument readability and ahead/astern interpretation | Native HUD inspected; overall feel accepted |
| P2 | Engine/thruster/horn loudness and timbre | Signal checks pass; player audition pending |
| Later dependency | Connect real fuel state when fuel simulation exists | Unconnected field labelled honestly |

Andy approved continuing from this handling baseline. The queue above remains
a reference for future regressions, not a requirement to repeat each step.

## Verification

FeedbackCheck passes 24 checks in editor and native Windows Release: unit/heading
instruments, separate command/engine/motion, honest fuel, audio activation/cutoff,
blocked input, no navigation mutation, non-silent/unclipped PCM, loop/envelope
policy, mapped horn and automatic stop. Full passes 16 stages / 50 scripts;
handling/camera/water/collision checks remain passing. Native HUD capture inspected.
Verification mutes its own audio bus and does not change saved user volume; no
human audition is claimed.

Run tools/Godot.ps1 -Mode FeedbackCheck. Exported check:
-Mode RunExport -Configuration Release -FeedbackProbe.
