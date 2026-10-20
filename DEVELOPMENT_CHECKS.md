# Developer tools and checks — Step 15

Completed October 19, 2026. Ctrl+F3 toggles a read-only developer overlay, off by
default on every launch. It displays session role, ship ID, fixture fuel, frame
interval and process CPU time. Speed, throttle and position are explicitly
"Not connected" until the physical ship controller exists. No fake zero movement
or scene position is substituted. Future controller integration must populate
these diagnostics from the same authoritative movement state used by gameplay.

The overlay owns no game state. The session supplies copied diagnostics; mouse
filters ignore clicks and it never takes keyboard focus. Ctrl+F3 is consumed only
as a developer shortcut and does not change the single-key gameplay bindings.
Disabling it leaves ordinary test loading and pause usable. The panel sits on the
right below the title. It is currently available in development release exports
as well as the editor; production exposure can be restricted at release hardening.

Frame interval averages process delta over roughly 250 ms and says Sampling
before its first window. This includes frame pacing; process CPU uses Godot's
TIME_PROCESS monitor. Neither is GPU timing or proof of representative performance.
The empty menu cannot establish a ship/world performance budget.

## Repeatable runner

From ShippingLanes:

```powershell
./tools/CheckProject.ps1
./tools/CheckProject.ps1 -Full
```

The default four-stage runner verifies pinned engine/dependency setup, imports the
project, loads/compiles every GDScript in features/ and tools/ (without executing
those scripts' entrypoints), boots Main, then runs UnitsCheck, CatalogCheck and
DiagnosticsCheck. Failure stops the run through launcher exceptions. Tests receive
only trusted project scripts; this is not a save-data loading path.

Full adds ControlsCheck, FlowCheck, ContractsCheck, GeographyCheck, SessionCheck,
ClocksCheck and AssetCheck for 11 stages total. Logs are under .godot/ and rewritten
for each run. Existing SQLite process-kill tests remain opt-in via CheckStorage.ps1;
Full does not launch forced-shutdown fixtures or rebuild exports.

Checks and exported probes time out after 30 seconds and terminate only their
owned child process. Interactive game/editor runs remain open until closed.
The launcher separately detects nonzero exits and engine/script errors in logs.

Export validation:

```powershell
./tools/Godot.ps1 -Mode Export -Configuration Release
./tools/Godot.ps1 -Mode RunExport -Configuration Release -Headless -DiagnosticsProbe
```

## Evidence

Full passed all 11 stages, including compilation of 35 project/tool scripts.
DiagnosticsCheck passed nine checks in editor and Windows Release: useful bad
reference diagnostics, default-off overlay, real shortcut events, honest readout,
nonblocking pointer filters, copy isolation, toggle-off and normal action/pause.
The deliberately invalid in-memory definition reports:

`Missing or wrong-type cargo reference: ship_starter_container_01 -> missing_cargo_for_diagnostic`

It does not edit the real catalog. Native startup and a 1152 x 648 overlay capture
were inspected. This completes development-tools-and-checks; Step 16 begins actual
handling. There is no new movement simulation in this step, and no manual user
testing is required.

Step 16 adds HandlingCheck to Full (12 stages). It checks 300 fixed physics ticks at each of three loop caps. Export verification: tools/Godot.ps1 -Mode RunExport -Configuration Release -Headless -HandlingProbe.

Step 17 expands HandlingCheck to 42 checks, including throttle ramps, rapid reversals, definition validation, and mapped scene input/focus behavior. The same HandlingProbe verifies the Windows Release build.

Step 18 expands HandlingCheck to 72 checks, adding repeatable turning, bounded lateral motion, steering signs, maneuvering input, and a solid-quay sideways approach.

Step 19 adds CameraCheck to Full (13 stages / 41 scripts). Twenty camera checks cover size-independent focus, smoothing, input and pier avoidance. Release verification uses -Mode RunExport -Configuration Release -Headless -CameraProbe.

Step 20 adds WaterCheck to Full (14 stages / 45 scripts). Thirty-five checks verify visual/physics separation, tiers, palettes and preference compatibility/save/cancel. Exported -WaterProbe without -Headless also exercises native shader rendering.

Step 21 adds CollisionCheck to Full (15 stages / 48 scripts): 35 assertions, 16 contact/mask fixtures, 180 ticks. Release uses -Mode RunExport -Configuration Release -Headless -CollisionProbe.

Step 22 adds FeedbackCheck to Full (16 stages / 50 scripts). Twenty-four checks validate instruments, synthesized audio state/PCM and the recorded handling baseline. Native Release uses -FeedbackProbe; the check mutes its own audio only.

Step 24 adds recorded fixed-input motion checkpoints inside HandlingCheck. See
SIMULATION_CHECKPOINTS.md for playback inputs, SI tolerances, power telemetry,
regression sensitivity checks and intentional-baseline-update policy. Full still
runs 16 stages; the same HandlingProbe is packaged for Windows Release.

Step 25 adds WorldSizeCheck to Full. It measures distant float32 controls versus
local patches, scalar spherical navigation/seam/poles/circuits, marker precision,
shared hull contact and coherent camera/velocity/visual frame mapping. Release
uses -WorldSizeProbe. Scope and measured travel budgets: WORLD_SIZE_EXPERIMENT.md.

Step 26 adds HeavyLifterCheck to Full (18 stages). The heavy carrier's imported
Blender assets, deck endpoints/clearance, alignment/ownership, real turning,
payload collision envelope, release/reload and visible buttons are checked.
Exported check uses -HeavyLifterProbe. See HEAVY_LIFTER.md for scope and usage.
