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

Step 27 adds CompositionCheck to Full (19 stages / 61 scripts). Sixty checks
exercise both runtime ships in independent transformed parents, component and
definition isolation, forward/reverse/side contacts, turning and payload cleanup.
Native Windows Release uses -CompositionProbe; HeavyLifterProbe also passes
after the refactor. See SHIP_COMPOSITION.md.

Step 28 adds FuelCheck to Full (20 stages / 64 scripts). Forty-two assertions
cover consumption, policies, frame-rate independence, empty behavior, bounded
recovery and both ships' test controls. Native Release uses -FuelProbe.
See FUEL_SIMULATION.md. FeedbackCheck now verifies connected fuel.

Step 29 adds NetworkCheck (21 stages / 67 scripts), using two real processes.
CheckNetwork.ps1 -Runtime Release verifies the exported binary. Host/client
assertions and cross-process roster comparisons cover three join rounds,
duplicate hello, cleanup and host failure. Localhost traffic must be permitted
by the execution environment. Evidence: LOCAL_NETWORK_SESSION.md.

Step 30 adds ReplicationCheck (22 stages / 69 scripts). It runs two-process
normal and impaired movement profiles with host/client assertions and latency
metrics. Release uses CheckNetwork.ps1 -Runtime Release -Replication, with
-Profile impaired for the delayed/lossy profile. See SHIP_REPLICATION.md.

Step 31 adds CargoNetworkCheck (23 stages / 71 scripts). Both two-process
profiles check loaded motion, reconnect, command ownership/order, release and
carried collision (15 host + 17 client assertions per profile). Windows build:
CheckNetwork.ps1 -Runtime Release -Cargo, optionally -Profile impaired.
See ATTACHED_PAYLOAD_NETWORKING.md.

The connected-world prerequisite adds ConnectedWorldCheck (24 stages / 73 scripts).
Two-process normal/delayed profiles each have 75 assertions: geographic chart
transitions, camera/velocity/heading, attached collision, retained marker, JSON
reload, reconnect and invalid spatial envelopes. Windows Release uses
CheckNetwork.ps1 -Runtime Release -ConnectedWorld, optionally -Profile impaired.
This profile uses reliable delayed transitions, not the motion loss simulation.
See CONNECTED_WORLD_NETWORK.md for exact scope and remaining integration gates.

Step 32 adds CapacityCheck (Full now has 25 stages / 75 scripts). This is a short
two-client crowded editor smoke test; it does not rerun the entire capacity matrix.
Use CheckCapacity.ps1 -Runtime Release for all ten 2/10/25/50/100 layout cases,
or add -Counts 100 -Layouts crowded -VisibleObserver for a rendered repeat.
Raw process/timing/bandwidth/motion results are retained per run; the accepted
Step 32 summaries are also tracked in tools/baselines/capacity-step32.json.
CPU and packet sizes are measurements, not hardware-independent pass thresholds.
See CAPACITY_EXPERIMENT.md for the measured limits and mandatory follow-up gate.

Step 33 adds ActionCheck (Full now has 26 stages / 77 scripts). It uses two real
local processes to verify typed errors, owner/sender identity, retries with and
without retained receipts, payload conflicts, failed-result retention, timeout
behavior and reconnect isolation. Release uses CheckNetwork.ps1 -Runtime Release
-Actions. Existing motion/cargo checks exercise the integrated live helm path.
See ACTION_VALIDATION.md; its receipts are deliberately session-scoped.

Step 34 adds EconomyCheck (Full now offers 27 stages / 79 scripts). It covers
82 atomic wallet/inventory, audit, retry, failure, overflow and no-peer-transfer
assertions. SessionCheck verifies the existing menu test uses this ledger;
ClocksCheck and FlowCheck cover session lifecycle. Native Release uses
Godot.ps1 -Mode RunExport -Configuration Release -EconomyProbe.
This is an in-memory proof, not the Step 35 crash/restart durability test.
