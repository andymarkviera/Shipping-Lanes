# Step 23 — Visual cargo draft

Andy approved replacing depth restrictions with freely navigable open water.
Visible land, rocks and docks remain solid. There are no hidden shallows,
under-keel checks, grounding penalties or draft-based route restrictions.

Boat Handling Test includes a Cargo preview button: Empty, Half load, Full load.
The visible hull smoothly settles by up to 0.85 m at 0.3 m/s, plus existing bobbing.
This is a provisional presentation range for the box hull, not a real draft value.
Only VisualRoot moves; the navigation body, collider, camera focus and handling
parameters remain unchanged. The button releases focus so helm input can resume.

ShipVisualMotion.set_visual_load accepts a normalized 0–1 load, clamps finite
out-of-range values and ignores nonfinite input. A future authoritative cargo
system can supply this ratio. The preview creates no cargo, money or saved state;
real cargo mass/capacity integration and final hull calibration remain future work.
The final map must keep open-water passages usable by all supported ships.

Next: Step 23B, original Wind Waker-inspired wakes and hull foam: bold blue water,
clean white bow/side foam, speed-responsive ripples and fading trails. Visual only.
