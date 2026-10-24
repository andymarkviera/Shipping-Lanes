# Neutral and stopping usability — October 24, 2026

User-requested comfort update before Step 46. Both hull definitions inherit a
4 percent neutral capture zone, a 2 knot (1.028889 m/s) stopping-assist threshold,
and 0.35 m/s² additional deceleration. Values are validated catalog data.
Approaching/crossing zero with throttle keys captures exact neutral. Releasing
within the zone also selects neutral. Continued held input can leave neutral on
the next tick, so deliberate reverse remains available without an extra key.
The same adjustment function is used by local, private-network and public controls.
Direct authority throttle commands still retain their precise validated values.

Once commanded and actual engine output are both zero, with no side-thruster
order, speed at or below the threshold decays to exact zero using move_toward.
It never reverses velocity. It handles forward, backward and sideways motion;
active throttle/side thrusters override it. Above threshold ordinary drag remains.
Zero speed also clears residual yaw. This is a gameplay comfort assist, including
when fuel is exhausted, not a physical anchor or docking state.
The HUD distinguishes Slowing down from Stopped using motion, not the throttle
position alone. Public feedback uses replicated server velocity.

Legacy recorded physics fixtures explicitly disable assistance and replay the
original throttle ramp to retain their historical comparisons. New production-
tuning tests separately cover both hulls, 30/60/120 Hz, reverse/diagonal stopping,
monotonic deceleration, exact rest within four seconds from near 2 knots, throttle
capture/release, normal high-speed coasting and deliberate propulsion overrides.
The scene-input fixture now waits for the input release gate and physics ticks,
rather than a startup wall-clock timer. The old reverse test no longer assumes
forward momentum persists after the new assistance has reduced it.

Validation: script/startup 114, fuel 42 and catalog passed. Release port suite
102 passed (output/ports/15fb284e). Release multiplayer helm suite 12 passed
(output/handoff/842e8c67), including authority full stop and client stopped feedback.
Final Release handling suite passed 134 checks (output/neutral-handling.log).

Next: Step 46 docking controls and state. Heavy-loader pickup repair remains due
before Step 50. No hidden shallows, peer transfers or wake/foam art changes.
