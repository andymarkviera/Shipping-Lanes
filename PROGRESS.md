# Shipping Lanes progress

## Setup checkpoint — October 18, 2026

- Created a minimal Godot 4.7 project with a startup scene and typed GDScript.
- Verified direct file creation, editing, and readback in this workspace.
- No gameplay implemented during initial setup.
- Engine verified: Godot 4.7.2.stable.steam.ed1daf0bf.
- Executable: `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`.
- Headless editor import completed with exit code 0.
- Headless startup completed with exit code 0 and printed the setup success message.
- Default user log location was not writable in the sandbox; reran successfully with an explicit log under `.godot/`.
- Requested a visible setup window launch; visual appearance still needs Andy's confirmation.

## Open and check

Use `tools/Godot.ps1 -Mode Editor` through PowerShell 7, then F5 to run the
project. `-Mode Run` runs it directly and `-Mode Check` verifies import/startup
headlessly. See `README.md` and `ENVIRONMENT.md` for complete commands.
The current entry point is `features/main/main.tscn`; the window says “Shipping
Lanes” and “Project ready”. Output includes “Shipping Lanes: Main scene loaded
successfully.” Step 05 replaces the earlier setup scene referenced historically
below.

## Step 01 — Project contract

Task ID: `project-contract`  
Status: complete — October 18, 2026.

- Read the current setup project and all five supplied design/reference files at
  the level relevant to the contract.
- Added `GAME_SPEC.md` separating confirmed scope, provisional defaults, open
  decisions with deadlines, and deferred/excluded features.
- Preserved the connected-world/globe/circumnavigation design direction from the
  newer map reference without finalizing its proposed geometry or launch count.
- Added `DECISIONS.md` with stable decision IDs and source precedence.
- Distinguished the first container-voyage milestone from the complete version 1
  release. No gameplay or project settings changed in Step 01.
- No additional product answer is needed to complete this documentation step.

Review checklist: cargo scope, Windows/Godot baseline, both online modes,
public/private ownership, ship-only controls, recovery, placeholder art, and
version 1 criteria are explicit. Research uncertainties remain evidence gaps,
not silently adopted mechanics.

Validation: reviewed the contract against the supplied confirmed scope and
research caveats. Godot 4.7.2 headless editor import and setup startup each
returned exit code 0; startup printed the setup success message and neither
log contained errors. Logs: `.godot/step-01-import.log` and
`.godot/step-01-startup.log`. This verifies the existing scaffold only; no
gameplay, visual playtest, export, or multiplayer capacity is claimed.

Recoverable checkpoint: `../output/checkpoints/step-01-project-contract-2026-10-18.zip`,
containing the project files and these records, excluding generated `.godot`
cache/logs. Extract to a new folder and import `ShippingLanes/project.godot`
to restore it. The archive's SHA-256 is recorded in the adjacent `.sha256` file.

Step 01's next task was Step 02, `online-architecture-decision`, subsequently
requested by Andy. Hardware baseline, full project skeleton, and export pipeline
steps remain incomplete despite the minimal setup scaffold.

## Step 02 — Online architecture decision

Task ID: `online-architecture-decision`  
Status: complete — October 18, 2026 (architecture decision only).

- Added `ONLINE_ARCHITECTURE.md` covering both modes, authority/save boundaries,
  public identity and private guests, selected providers/storage, lease fencing,
  durable handoff, host departure, outages, and a later implementation proof matrix.
- Selected Keycloak/OIDC + PostgreSQL-backed public account service, per-world
  SQLite private saves, and Godot ENet/UDP with authenticated DTLS. These are
  engineering decisions; nothing was installed, registered, or deployed.
- Updated the contract's identity/storage decision and decisions D011–D017.
- No gameplay, network code, project settings, service code, or assets changed.
- Public sign-in is required; guests use private/local worlds. A listed player
  host remains private-economy. Stale public owners cannot write after transfer.

Acceptance review: both modes have explicit authority/save rules; public money
and fleet follow canonical account state; private saves cannot import public
wealth; one backend owner and durable handoff are defined; 100 players remains
an unmeasured target. Dependency, crash/retry, identity, networking, and load
proofs are assigned to later runtime work and are not reported as passed here.

Validation: reviewed against Step 02 and official Godot 4.7, Keycloak/OIDC,
PostgreSQL, SQLite, and native-app authentication references. Independent scope
and failure-path review passed after clarifying that operation hashes exclude
transport/lease fields and normal business rejections do not freeze simulation.
Godot 4.7.2 headless editor import and startup each returned exit code 0; startup
printed the setup success message and neither log contained errors. Runtime
file hashes matched their pre-step baseline. Logs: `.godot/step-02-import.log`
and `.godot/step-02-startup.log`. No backend, networking, database durability,
identity, export, visual playtest, or load test ran in this documentation step.

Recoverable checkpoint: `../output/checkpoints/step-02-online-architecture-2026-10-18.zip`.
Includes project files and records, excluding generated cache/logs; archive
entries are checked against source SHA-256 hashes. The archive checksum is in
the adjacent `.sha256` file. Extract to a new folder and import
`ShippingLanes/project.godot` to restore the scaffold and decision records.

Step 02's next task was Step 03, `feature-and-uncertainty-inventory`, subsequently
requested by Andy.

## Step 03 — Feature and uncertainty inventory

Task ID: `feature-and-uncertainty-inventory`  
Status: complete — October 18, 2026 (inventory and scheduling only).

- Created `FEATURE_INVENTORY.md`: 56 rows placing every agreed feature or
  reference category into core/support, conditional, expansion or deferred/excluded
  scope, with original stable task IDs and milestone/gate references.
- Created `UNCERTAINTIES.md`: 42 open rule groups with a responsible owner,
  latest decision point, and required resolution evidence. Existing confirmed
  scope and Step 02 provider/authority choices are not reopened.
- Created `BUILD_DEPENDENCIES.md`: eight planned prerequisite tasks, including
  early geographic/storage proofs, connected-world network proof, public storage,
  authenticated admission, public authority integration, starter-route distances,
  and a launch hull/passage envelope. Original roadmap numbering remains stable.
- Resolved scheduling conflicts: schema before world proof, route/quotes before
  late world expansion, SQLite-safe backup behavior, and early identity/storage
  integration before public handoff and shared markets/refineries.
- Recorded the first playable two-port/two-hull milestone explicitly. Container
  quote/reward rules must be decided before offers, then verified at payout.
- Supplied starter Blender model remains untouched and unimported; asset inspection
  is assigned to Step 07. The external model is not copied into checkpoint archives.
- No gameplay, project settings, network/service code, assets, or original attached
  reference documents were changed.

Acceptance and document validation:

- Scope and dependency reviews found no missing agreed category or dependency
  cycle after correcting the container quote deadline, two-hull milestone, and
  explicit partial-discharge policy.
- 56 unique feature rows, 42 unique uncertainty groups, eight unique supplemental
  tasks and 59 distinct valid task references; no duplicate IDs or missing refs.
  Report: `../output/checks/step-03-inventory-validation.json`.
- Due uncertainties remain open with owners/deadlines. Completing this inventory
  does not mark any proposed provider/asset/geographic/network experiment passed.

Engine validation and correction to earlier quick checks:

- Waited explicitly for Godot processes to exit this time. Earlier quick shell
  invocations could return before the Windows GUI-subsystem executable finished;
  their import/no-error claims did not establish full editor readiness. Those
  earlier readiness claims are superseded by this fuller check.
- Installed Steam Godot import completed with exit code 0 and no project script
  or resource-import failures, but logged user-data access and editor-settings
  permission errors. A hash-identical local verification copy, with portable
  editor data under `../output/tools/godot-4.7.2/`, removed the installation-folder
  settings errors. Its remaining editor error is inability to open `user://` for
  profiler snapshot storage; full editor readiness is not yet passed.
- The local copy's headless setup startup passed with exit code 0, the expected
  success message and no runtime errors. All four project runtime file hashes
  and the external starter Blender source hash were unchanged.
- Logs: `.godot/step-03-portable-import.log` and
  `.godot/step-03-portable-startup.log`; structured result:
  `../output/checks/step-03-engine-validation.json`.
- Remaining environment issue is assigned to U001 and Step 04. The Steam
  installation was not modified. No gameplay, export, network, durability or
  capacity test ran in this documentation step.
- Portable-mode basis: [Godot 4.7 data paths](https://docs.godotengine.org/en/4.7/tutorials/io/data_paths.html).

Recoverable checkpoint: `../output/checkpoints/step-03-feature-inventory-2026-10-18.zip`.
Includes local project/decision/inventory files, excluding generated `.godot`
cache/logs, the external Blender source and the verification engine copy.
Archive contents are checked against source SHA-256 hashes; the archive checksum
is in its adjacent `.sha256` file. Extract to a new folder and import
`ShippingLanes/project.godot` to restore the scaffold and records; see the known
environment limitation above before claiming full editor readiness.

Step 03's next task was Step 04, `engine-and-hardware-baseline`, subsequently
requested by Andy. Its remaining environment issue is resolved below.

## Step 04 — Engine and hardware baseline

Task ID: `engine-and-hardware-baseline`  
Status: complete — October 18, 2026.

- Recorded measured Windows x64 hardware: i7-12700KF (12 cores/20 threads),
  RTX 3070 (8192 MiB VRAM, driver 617.14), and 15.84 GiB OS-visible physical
  RAM. Exact installed DIMM capacity was unavailable; raw evidence and limits
  are in `hardware-baseline.json`.
- Pinned exact Godot 4.7.2 Steam build/commit/SHA-256 in `engine-baseline.json`;
  selected Compatibility/OpenGL and made the driver explicit in `project.godot`.
- Added `tools/Godot.ps1` to launch the editor, run the project, or check full
  import/startup using the pinned engine copy. Child-only APPDATA plus portable
  editor settings resolves the Step 03 user-data/settings error. No Steam
  installation or user/system environment change was required.
- Added `ENVIRONMENT.md` with launch/check/install/export instructions, actual
  evidence, limits and provisional client/server performance/resource targets.
  Matching named installed Windows export templates were found; staging them and
  creating/running an export remain Step 06, not completed here.

Validation:

- Full headless editor import and setup startup via saved launcher `-Mode Check`
  passed with exit code 0 and no engine/script/environment errors. The editor
  filesystem scan/layout completed, and setup printed its expected success message.
- Saved launcher `-Mode Run -QuitAfter 10` and `-Mode Editor -QuitAfter 120`
  each passed with exit code 0 using the actual RTX 3070 / OpenGL driver.
- Native setup frame capture was inspected. After 60 warmup frames, 180 measured
  frames at a 60 FPS cap averaged 16.666 ms (p95 16.679 ms). The actual drawable
  size was 1920×1061 after Windows constrained the requested 1920×1080 window.
  This is a setup UI/frame-pacing check, not ship/world throughput or full 1080p proof.
- Isolated `user://` write/flush/read passed and the temporary file was removed.
- All setup scene/script/UID and external Blender source hashes matched the
  pre-step baseline. Gameplay and ship assets were not changed or imported.
- Launcher/path approach received independent review. Raw reports/capture are
  `../output/checks/step-04-hardware.json`, `step-04-graphics.json` and
  `step-04-setup.png`; engine logs are `.godot/environment-*.log` and
  `.godot/step-04-*.log`.

Known limits: only this Windows build/hardware and an empty setup project were
tested. Export, lower-end support, representative gameplay memory/frame budgets,
networking, public services and 100-player capacity remain unverified. Normal
Steam launches do not inherit the isolated launcher paths; use the saved helper
for the verified direct-file workflow. Development saves through the helper use
its separate local data directory and must not be discarded when refreshing tools.

Recoverable checkpoint: `../output/checkpoints/step-04-engine-baseline-2026-10-18.zip`.
Includes project source/records/launcher/pins; excludes generated cache, runtime
data, the large verification engine and the external Blender source. Archive
entries are checked against source SHA-256 hashes and a sidecar records the
archive checksum. Restore to a new directory and follow `ENVIRONMENT.md`; the
launcher needs the cached or exact installed engine build.

Step 04's next task was Step 05, `repository-and-project-skeleton`, subsequently
requested by Andy.

## Step 05 — Repository and project skeleton

Task ID: `repository-and-project-skeleton`  
Status: complete — October 18, 2026.

- Initialized a local Git repository only inside `ShippingLanes`, with the
  existing Step 04 project preserved in commit `8cf76a4` and tag
  `step-04-engine-baseline` before editing the skeleton. No remote was configured.
- Replaced the original setup entry point with `features/main/main.tscn`.
  Main directly composes `World` (an empty Node3D scene) and `UI` (a CanvasLayer
  with the identifying startup screen). The typed startup script retains its UID.
- Grouped scenes/scripts by feature in `features/main`, `features/world` and
  `features/ui`. Added `README.md` with launch commands, layout, scope links and
  recovery instructions; updated current commands without rewriting historical
  validation records.
- Expanded ignore rules for generated Godot data, export output and local
  credentials. Added text normalization and retained Markdown's intentional
  line breaks. Source scenes, script UID sidecars and future export presets
  remain trackable.
- Commit identity is explicitly `Codex <codex@localhost>` for these automation
  checkpoints. User-wide Git settings and synced reference files are unchanged.

Validation:

- Saved launcher `-Mode Check` passed full editor import and Main startup with
  exit code 0, the expected Main success message and no engine/script errors.
- Native Windows/OpenGL launch on the RTX 3070 passed with exit code 0. The
  loaded tree contains Main with World and UI as siblings; the captured
  1152×648 screen clearly displays “Shipping Lanes” and “Project ready”.
- Capture: `../output/checks/step-05-main.png`; native log:
  `.godot/step-05-graphics.log`; import/startup logs:
  `.godot/environment-import.log` and `.godot/environment-startup.log`.
- Independent read-only scene/path/scope review passed. Git ignore checks
  confirm cache/build/credential exclusion and source/UID/preset inclusion.
- The world remains empty. Gameplay, ship import, multiplayer services and
  desktop export are not implemented by this step.

Recoverable baseline: Git tag `step-05-project-skeleton` plus
`../output/checkpoints/step-05-project-skeleton-2026-10-18.zip`. The ZIP includes
tracked project source/records, excludes `.git`, generated caches, the engine,
development saves and the external Blender source, and has a SHA-256 sidecar.
Its file contents are verified against the saved source. Extract into a new
folder and follow `README.md` / `ENVIRONMENT.md` to restore without replacing
current work. The Git repository also retains the previous setup baseline.

Step 05's next task was Step 06, `export-pipeline-smoke-test`, subsequently
requested by Andy.

## Step 06 — Export pipeline smoke test

Task ID: `export-pipeline-smoke-test`  
Status: complete — October 18, 2026 (local Windows smoke test).

- Pinned matching 4.7.2 Windows x86_64 export template hashes and staged verified
  copies into the portable editor's writable template folder. Steam originals
  remain unchanged.
- Added a Windows Desktop preset selecting Main and its dependencies, with
  separate EXE/PCK and no signing credentials. Added Export and RunExport modes
  to the saved launcher, plus complete commands and limits in `EXPORT.md`.
- Debug and release export operations passed full import/packaging with exit 0.
  Both built executables launched through RunExport on RTX 3070 / OpenGL, printed
  the Main startup marker and exited 0 without engine/script errors.
- Copied only the release EXE/PCK outside the project into
  `../output/smoke/step-06 standalone/`. With a writable child APPDATA directory,
  this independent copy launched without editor or project-path arguments,
  exited 0 with no errors, and produced a visually checked 1152×648 startup frame.
  Evidence: `../output/checks/step-06-isolated.log` and
  `step-06-isolated00000009.png`.
- The initial standalone attempt using inherited Windows APPDATA reached Main
  but logged a shader-cache write error under the sandbox. It is not recorded
  as a clean pass. Normal-profile/clean-machine behavior remains unverified;
  use the saved launcher for the verified development workflow.
- Generated builds/cache and local credentials remain excluded from Git.
  No gameplay, installer, signing, cross-platform or capacity validation is claimed.

Additional user-requested art direction:

- Recorded the supplied photo's ocean/rock palette and regional variation in
  `ART_DIRECTION.md`, D026 and the asset references. Prepared three original
  StandardMaterial3D swatches for coastal water, rock and foam; all three loaded
  successfully in Godot (`../output/checks/step-06-materials.log`).
- The source photo remains external and unchanged. Map geometry, water effects
  and ship import are later work. These unused swatches are not included in the
  Main-only smoke export.

Recoverable baseline: Git tag `step-06-export-pipeline` and source-only archive
`../output/checkpoints/step-06-export-pipeline-2026-10-18.zip`, with verified
contents and SHA-256 sidecar. Generated builds, large templates, engine,
development data and external art sources are excluded. Follow `EXPORT.md`
to rebuild from this source checkpoint.

Step 06's next task was Step 07, `model-and-asset-conventions`, subsequently
requested by Andy.

## Step 07 — Model and asset conventions

Task ID: `model-and-asset-conventions`  
Status: complete — October 18, 2026 (asset preparation; gameplay acceptance later).

- Inspected the supplied Blender file and rig guide. Preserved the Downloads
  source and added a byte-identical editable source copy under `art_sources/`
  with `.gdignore`. Earlier local ship output differs and was not substituted.
- Added a pinned Blender 3.6.1 export script, explicit GLBs, import sidecars,
  manifest, separate wrapper/convex hull reference, and static inspection scene.
  Excluded preview cargo, extra scene objects, cameras/lights and old proxy boxes.
  Fixed existing weighted-normal evaluation and sign orientations in memory only.
- Adopted metre units and calibrated Blender -Y bow/+Z up to Godot +Z bow/+Y up.
  Measured 64×13 m hull, 3.2 m reference keel depth; full visual bounds and all
  12 sockets agree after import. Empty export: 79 meshes, 2,728 triangles,
  seven material roles. Loaded draft and gameplay capacity remain undecided.
- Added repeatable `-Mode AssetCheck` and optional `-Mode Run -Scene` to the
  launcher. Checked no imported physics owners or baked cargo, stable IDs,
  socket positions/normals, pivots, visual bounds and hull reference points.
- Harmless exported metadata change produced a changed GLB; reimport retained
  wrapper/collision hashes and passed all checks. Restoring the baseline produced
  the same GLB hash. Original and source-copy SHA-256 remained identical.
- Native 1152×648 static preview was inspected, using the coastal water swatch.
  Preview: `../output/checks/step-07-preview-b00000007.png`. Full project
  import/startup and saved preview launcher also passed without errors.
- Conventions, exact commands, limits and remaining acceptance are in
  `ASSET_CONVENTIONS.md`. Asset-check log: `.godot/asset-check.log`; export and
  reimport evidence: `../output/checks/step-07-*.log`.

This step does not select a movement body, implement collision response, cargo
simulation, repainting or sailing. Those remain later tasks. Art/provenance
review and full runtime acceptance are not marked complete by import checks.

Recoverable baseline: tag `step-07-asset-conventions` and archive
`../output/checkpoints/step-07-asset-conventions-2026-10-18.zip`, with verified
contents and SHA-256 sidecar. This checkpoint includes the preserved project
Blender source copy and GLBs; generated `.godot/`, exports and engine tools remain
excluded. The external Downloads original remains unchanged.

Step 07's next task was Step 08, `input-and-settings-foundation`, subsequently
requested by Andy.

## Step 08 — Input and settings foundation

Task ID: `input-and-settings-foundation`  
Status: complete — October 18, 2026.

- Added named throttle, steering, thruster, brake/zero, camera, interaction,
  map, horn and pause actions. Keyboard bindings are editable without ship-code
  changes. Walking remains deferred under the helm-only contract.
- Added a defaults Resource, validated/versioned plain-JSON preferences, and a
  settings panel with key-conflict checks, reset, save/cancel, volume, camera
  sensitivity/inversion and fullscreen. Save stages writes before replacement;
  errors preserve active settings. Malformed files are not silently overwritten.
- Added a local input boundary: inactive ship contexts, menus, focused GUI and
  window focus loss block vehicle commands/polling. Closing a menu or returning
  focus requires release before fresh input. No global simulation pause is set.
- Native 1152×648 settings capture was inspected. Automated checks pass for
  persistence, replacement/failure/malformed data, conflicts, rebinding, UI drafts,
  Escape, held keys, focus, audio volume and camera request scaling/inversion.
  Test saves use unique temporary paths and are removed. `-Mode ControlsCheck`
  is repeatable; logs: `.godot/controls-check.log`.
- Project import/startup passed. Standalone release testing caught a missing
  script-loaded defaults asset; explicit export roots now include it. Re-export
  and native RunExport then passed with exit 0 and no engine/script errors.
- User instructions and scope limits are in `CONTROLS.md`. Sailing, camera
  movement, actual map/horn/interactions and session flow remain later tasks.

Recoverable baseline: tag `step-08-input-settings` and source-only archive
`../output/checkpoints/step-08-input-settings-2026-10-18.zip`, with verified
contents and SHA-256 sidecar. Generated builds/cache and local preferences are
excluded; preserved Blender source and game resources remain tracked.

Next roadmap task: Step 09, `application-flow-and-focus`.

## Step 09 — Application flow and focus

Task ID: `application-flow-and-focus`  
Status: complete — October 18, 2026.

- Built Container Ship Sim title UI from Andy's layout: Play, Servers, Settings,
  disabled Fleet, Exit, and conditional Continue test session. Background art is
  deferred. Play starts a local fixture until quick-join networking exists.
- Added boot/title/session/pause/settings/return transitions, disposable session
  ownership, in-memory continuation, independent settings, and keyboard focus.
- Hosted-style session processing continues behind menus; offline test policy
  pauses only its own updates. SceneTree is never globally paused.
- Focus loss releases mouse and opens the local pause menu; returning focus
  requires Resume. Mouse capture and release-before-input rules are enforced.
- FlowCheck passed twelve repeated session lifecycles and pause/focus/settings
  checks; ControlsCheck still passes. Native title/pause renders inspected.
- Release export initially exposed an omitted script-loaded fixture; explicit
  export roots fixed it. Rebuilt Windows release launched with no script errors.
- See APPLICATION_FLOW.md for limits: no actual servers, sailing or disk saves.

Recovery: tag `step-09-application-flow`; verified source ZIP with SHA-256 sidecar:
`../output/checkpoints/step-09-application-flow-2026-10-18.zip`.

Next roadmap task: Step 10, `definitions-and-stable-ids`.

## Step 10 — Definitions and stable IDs

Task ID: `definitions-and-stable-ids`  
Status: complete — October 19, 2026.

- Added four custom definition types with a four-record prototype catalog and
  preserved the existing starter ship definition ID. Main validates it at boot.
- Added transactional registry validation and defensive copies; mutable ShipState
  contains independent fuel and deeply copied cargo, referencing a stable ID.
- CatalogCheck passes instance isolation, source safety, bad references/types,
  duplicate IDs, failed replacement retention, and wrapper metadata checks.
- User-requested settings changes are complete: opaque panel, continuous sliders,
  sensitivity number retained, volume number removed. ControlsCheck passes and
  the native settings capture was visually inspected. FlowCheck also passes.
- Export validation caught packed reference fields disappearing in the release;
  typed string arrays corrected the issue. Rebuilt release boots and validates
  the complete catalog without errors. See DEFINITIONS.md for limits.
- No capacities, prices, starting supplies, map geometry or save contracts are
  inferred from these placeholders.

Recovery: tag `step-10-definitions`; verified source archive and SHA-256 sidecar:
`../output/checkpoints/step-10-definitions-2026-10-19.zip`.

Next: geographic-contract-feasibility, then private-storage-dependency-proof,
both required before Step 11 save-and-protocol-contracts (BUILD_DEPENDENCIES.md).

## Supplemental — Geographic contract feasibility

Task ID: `geographic-contract-feasibility`  
Status: complete — October 19, 2026.

- Added synthetic markers, canonical scalar addresses with explicit world/content
  revision and tangent frame, unit-globe and flat projections, pole-safe basis.
- Corrected approximate longitude snapping found in Godot wrapf by the seam test.
- 342 assertions pass in both the pinned engine and exported Windows release.
  Normal native release startup also passes. See GEOGRAPHIC_CONTRACT.md for
  measured tolerances, commands, evidence limits and pending physical validation.
- Globe vectors/tile IDs never replace canonical location identity. No actual
  map, ship simulation, geographic save file or networking is implemented.
- Saved tag `geographic-contract-feasibility` and verified source archive:
  `../output/checkpoints/geographic-contract-feasibility-2026-10-19.zip`, with
  SHA-256 sidecar.

Next task: private-storage-dependency-proof, required before Step 11 contracts.

## Supplemental — Private storage dependency proof

Task ID: `private-storage-dependency-proof`  
Status: complete — October 19, 2026, with documented cold-import workaround.

Pinned godot-sqlite v4.9 Windows x64 binaries, source references and licenses.
Editor, Debug export and Release export passed transaction commit/rollback,
parameter binding, transactional migration/rollback, live database backup/restore,
uncommitted-process-kill recovery and committed-process-kill durability checks.
SQLite reports 3.51.0. No gameplay save or public storage code was implemented.

Fresh scan-time extension discovery exposed a reproducible shutdown crash.
Pre-registering the extension before import passes on a fresh fixture; Godot.ps1
now performs this setup while preserving other entries and verifying hashes.
STORAGE_PROOF.md records evidence, commands, packaging and remaining limits.

Recovery: tag `private-storage-dependency-proof`; verified source checkpoint:
`../output/checkpoints/private-storage-dependency-proof-2026-10-19.zip` plus SHA-256.
Next: Step 11, save-and-protocol-contracts.

## Step 11 — Save and protocol contracts

Task ID: `save-and-protocol-contracts`  
Status: complete — October 19, 2026.

Added six versioned plain-data record fixtures and bounded JSON validation with
clear field errors and no accepted partial output. SAVE_PROTOCOL_CONTRACTS.md
specifies IDs, units, defaults, clocks, protocol/authority boundaries, retry and
migration policy. This is not actual gameplay saving or networking.

66 contract checks pass in editor and exported Release; 342 geographic checks
pass after rejecting boolean content revisions. Native release startup passed.
Export includes fixtures and a diagnostic route. No user playtest is needed.

Recovery: tag `step-11-save-protocol-contracts`; verified source ZIP and SHA-256:
`../output/checkpoints/step-11-save-protocol-contracts-2026-10-19.zip`.
Next: Step 12, units-and-time.

## Step 12 — Units and time

Task ID: `units-and-time`  
Status: complete — October 19, 2026.

Added explicit dimensional conversions, integer decimal-money parsing/formatting
and checked addition, rounding choices, positive time scaling, and a fixed voyage
distance shared by navigation and payout fixtures. Holds, DWT, mass, volume,
container count/slots and heavy payload counts remain distinct.

50 checks pass in editor and exported Release; native release startup passes.
UNITS_AND_TIME.md records references, defaults, rounding/bounds and limitations.
No final map compression, clock, reward rate or physical cargo capacity is chosen.
The check launcher now times out failed probes after 30 seconds.

Recovery: tag `step-12-units-time`; verified source ZIP and SHA-256:
`../output/checkpoints/step-12-units-time-2026-10-19.zip`.
Next: Step 13, state-ownership-boundaries.

## Step 13 — State ownership boundaries

Task ID: `state-ownership-boundaries`  
Status: complete — October 19, 2026.

Added a per-session in-memory authority for fixture player/ship/wallet/inventory.
A real test button sends a narrow request; the owner validates actor/ship/revision/
funds and publishes the wallet/cargo change together or returns a clear rejection.
UI reads defensive copies. Local and hosted-policy fixtures share the action path.
Continue retains the authority; New Session resets it without changing settings.

21 checks pass in editor and exported Release; FlowCheck and native startup also
pass. The test screen was visually inspected. STATE_OWNERSHIP.md records limits:
no actual multiplayer, durable transactions, real loading or economy tuning yet.

Recovery: tag `step-13-state-ownership`; verified source ZIP and SHA-256:
`../output/checkpoints/step-13-state-ownership-2026-10-19.zip`.
Next: Step 14, simulation-lifecycle-and-clocks.

## Step 14 — Simulation lifecycle and clocks

Task ID: `simulation-lifecycle-and-clocks`  
Status: complete — October 19, 2026.

Added a session-authority-owned 20 Hz operation clock with integer microsecond
remainder and bounded monotonic sample catch-up. A ten-second no-economy test
operation has explicit start/deadline/completion timestamps and completes once.
Menus display copied progress; hosted menus do not pause work, offline fixture
pause does, and title/Continue explicitly transfer and suspend authority.
New Session and application teardown cancel pending work.

22 checks pass in editor and exported Release. SessionCheck (21) and FlowCheck
also pass; native release startup and the timer UI capture were inspected.
SIMULATION_LIFECYCLE.md records clock domains, 250 ms catch-up cap, timestamp
policy and limits: no durable timers, offline awards or public backend time yet.

Recovery: tag `step-14-simulation-lifecycle`; verified source ZIP and SHA-256:
`../output/checkpoints/step-14-simulation-lifecycle-2026-10-19.zip`.
Next: Step 15, development-tools-and-checks.

## Step 15 — Development tools and checks

Task ID: `development-tools-and-checks`  
Status: complete — October 19, 2026.

Added an optional read-only Ctrl+F3 overlay for role, ship ID, fuel and timing;
speed/throttle/position explicitly remain unconnected until movement exists.
Added recursive GDScript compilation to Check and a four-stage CheckProject runner
with an 11-stage Full option. Invalid definition diagnostics name source/target.

Full passed all 11 stages and 35 scripts compiled. Nine diagnostic checks pass
in editor and Windows Release, including overlay-off normal action/pause. Native
startup and the overlay capture were inspected. DEVELOPMENT_CHECKS.md has commands
and timing/fixture limits. No manual testing required.

Recovery: tag `step-15-development-checks`; verified source ZIP and SHA-256:
`../output/checkpoints/step-15-development-checks-2026-10-19.zip`.
Next: Step 16, handling-prototype.

## Step 16 — Handling prototype

Task ID: `handling-prototype`  
Status: complete — October 19, 2026.

Added an isolated box-ship scene, reachable through Boat Handling Test on the
main menu. Forward propulsion, linear drag, inertia and reverse braking use an
explicit 60 Hz CharacterBody3D physics loop. Flat coastal water, stationary lane
markers, a temporary camera and live diagnostics make movement inspectable.
HANDLING_PROTOTYPE.md records the controlled/force-driven body comparison.

Eighteen handling checks pass at 30/60/144 loop caps in editor and Release;
Full passes all 12 stages, including compilation of 38 scripts. Native scene
capture inspected. No multiplayer, final ship tuning, rudder or waves yet.

Recovery: tag `step-16-handling-prototype`; verified source ZIP and SHA-256:
`../output/checkpoints/step-16-handling-prototype-2026-10-19.zip`.
Next: Step 17, throttle-and-reverse.

## Step 17 — Throttle and reverse

Task ID: `throttle-and-reverse`  
Status: complete — October 19, 2026.

Added retained commanded throttle, independent actual engine output, bounded
ramp rates, +100% / -60% limits and the explicit X zero order. W/S adjust the
command; releasing keeps it. Opposite orders ramp through neutral. Zero preserves
momentum. HUD shows command, engine and speed separately. Ship definitions expose
validated tuning; focus/menu blocking orders neutral and waits for key release.

HandlingCheck passes 42 checks in editor and Windows Release, including mapped
input/focus, 600 rapid reversals and matching motion at three loop caps. Full
12-stage suite passes; native HUD inspected. Values remain provisional; no steering,
fuel consumption or multiplayer movement introduced.

Recovery: tag `step-17-throttle-reverse`; verified source ZIP and SHA-256:
`../output/checkpoints/step-17-throttle-reverse-2026-10-19.zip`.
Next: Step 18, rudder-and-thrusters.

## Step 18 — Rudder and thrusters

Task ID: `rudder-and-thrusters`  
Status: complete — October 19, 2026.

Added A/D speed-sensitive rudder with bounded yaw rate/acceleration, explicit
astern steering reversal, and Q/E lateral thrusters with low-speed authority and
lateral drag. Six editable, validated ShipDefinition parameters control tuning.
The test scene includes gold turning-course markers and a solid practice quay.
HUD shows signed ahead/sideways speed and yaw rate. HANDLING_PROTOTYPE.md records
ship-relative directions, course use and the simplified controlled-body model.

All 72 handling checks pass in editor and Windows Release: repeatable turns at
three loop caps, bounded sustained lateral motion, speed-sensitive rudder,
reverse steering, input focus and a real sideways collision approach. Full
passes all 12 stages. Native HUD/course inspected. No actual mooring, wave physics,
network synchronization or collision-damage model yet.

Recovery: tag `step-18-rudder-thrusters`; verified source ZIP and SHA-256:
`../output/checkpoints/step-18-rudder-thrusters-2026-10-19.zip`.
Next: Step 19, camera.

## Step 19 — Camera

Task ID: `camera`  
Status: complete — October 19, 2026.

Added a reusable orbit rig and CameraFocus interface, independent of ship paths.
RMB drag orbits, wheel zooms within hull-relative limits, C recenters. Saved
sensitivity/inversion apply. Position/orientation/zoom and focus switches smooth;
sphere sweeps avoid solid piers, with immediate obstruction pull-in and smooth
recovery. Capture releases on mouse-up, blocked input, focus loss and scene exit.

CameraCheck passes 20 checks in editor and Windows Release, including 16 m/80 m
hulls, target switching, real mouse events and tall-pier avoidance. Full passes
13 stages, 41 scripts compile, and 72 handling checks still pass. Native aft/orbit
captures inspected. CAMERA.md records interface, limits and static-pier scope.

Recovery: tag `step-19-camera`; verified source ZIP and SHA-256:
`../output/checkpoints/step-19-camera-2026-10-19.zip`.
Next: Step 20, water presentation.

## Step 20 — Water presentation

Task ID: `water-presentation`  
Status: complete — October 19, 2026.

Added original procedural bright-blue water with broad pale drifting patterns,
soft swells and a separate muted coastal palette resource. Andy chose bold blue
for the first area; region selection remains future work. Low/Medium/High quality
is saved in Settings, with backward-compatible defaulting for old preferences.

Visual hull bobbing is isolated below VisualRoot; the navigation body, collider
and camera focus stay steady. No physical wave force or network transform change.
WATER_PRESENTATION.md records boundaries, quality costs and pending water effects.

WaterCheck passes 35 checks in editor and native OpenGL Windows Release. Full
passes 14 stages / 45 scripts; 72 handling and 20 camera checks remain passing.
Low/Medium/High and settings captures inspected. No actual networked sea state,
shore foam, detailed wake or global ocean yet.

Recovery: tag `step-20-water-presentation`; verified source ZIP and SHA-256:
`../output/checkpoints/step-20-water-presentation-2026-10-19.zip`.
Next: Step 21, hull-and-shore-collision.

## Step 21 — Hull and shore collision

Task ID: `hull-and-shore-collision`  
Status: complete — October 19, 2026.

Added shared collision layer policy, reusable simple hull collider, coast/rock
blockouts and thin/angled piers. Hull movement uses fixed-tick shape sweeps with
20 m/s supported total-speed cap and non-bouncing contact velocity. Rotation is
conservatively checked against solids before applying it. Camera queries use the
same solid layers; water/bobbing remain isolated.

CollisionCheck passes 35 assertions over 16 fixtures / 180 ticks in editor and
Windows Release. Full passes 15 stages / 48 compiled scripts; existing handling,
camera and water checks still pass. Native course inspected. COLLISION.md records
supported speed, masks, angular checks, clear-spawn requirement and limitations.

Recovery: tag `step-21-hull-shore-collision`; verified source ZIP and SHA-256:
`../output/checkpoints/step-21-hull-shore-collision-2026-10-19.zip`.
Next: Step 22, handling-feedback-pass.

## Step 22 — Handling feedback pass

Task ID: `handling-feedback-pass`  
Status: playable implementation ready — October 19, 2026; Andy's playtest pending.

Added engine/thruster tone feedback, mapped one-shot horn, and readable speed,
heading, commanded/actual throttle, effective thruster and drift instruments.
Fuel is displayed as unconnected, without inventing a simulation. Feedback is
read-only and respects master volume and input focus/menu gating.

Recorded a repeatable numerical acceleration/braking baseline and a prioritized
playtest queue in HANDLING_FEEDBACK.md. Tuning was not changed or locked. This
step's requirement for Andy to test feel/comfort remains outstanding; no player
feedback or acceptance is claimed.

FeedbackCheck passes 24 checks in editor and native Windows Release. Full passes
16 stages / 50 compiled scripts; all earlier checks still pass. HUD capture
inspected. Sound waveforms verified programmatically; player audition pending.

Recovery: tag `step-22-handling-feedback-baseline`; verified source ZIP and SHA-256:
`../output/checkpoints/step-22-handling-feedback-baseline-2026-10-19.zip`.
Next: Andy's short handling playtest and prioritized adjustments; then Step 23,
depth-and-draft. Controller choice remains provisional until review.

## Step 22 acceptance — October 19, 2026

Andy reported: "i really love how it all feels" and approved continuing. This
supersedes the pending overall-feel review above; preserve the current handling.
No separate detailed sound audition or final network handling approval is claimed.

## Step 23 — Visual cargo draft

Task ID: `depth-and-draft` (user-approved replacement scope).
Open water stays navigable for every ship; no hidden shallow zones or grounding.
The handling test now previews empty/half/full loading with a smooth visual sink.
Body, collider, camera focus and approved handling remain unchanged. The normalized
load input is ready for future cargo integration; current loads are preview only.
See VISUAL_DRAFT.md. Original synced roadmap remains untouched.

Next: Step 23B — stylized wakes and hull foam, following Andy's Zelda reference.

Verification: full project suite passes 16 stages / 50 scripts. WaterCheck now
passes 46 checks in editor and native OpenGL Windows Release, including loading,
unloading, invalid input and unchanged body/collider/focus. Loaded HUD capture
inspected at 1152x648. Existing handling/collision/feedback checks remain passing.
Status: complete, October 19, 2026. Recovery tag: `step-23-visual-draft`.
Verified source archive: `../output/checkpoints/step-23-visual-draft-2026-10-19.zip`.

## Step 23B — Stylized wakes and hull foam

Status: complete — October 19, 2026. User-requested water-effects follow-up.
Boat Handling Test now shows speed-responsive pale hull/bow foam and spreading,
fading world-space wake crests. Reverse and lateral movement use actual velocity;
all water quality tiers and both palette resources apply. Handling is unchanged.
See SHIP_WAKE.md for limits and later real-hull calibration.

Full suite: 16 stages / 51 scripts. WaterCheck: 59 checks in editor and native
Windows Release. Native moving wake capture inspected. No separate human style
approval claimed. Recovery tag: `step-23b-ship-wake`.
Verified source ZIP: `../output/checkpoints/step-23b-ship-wake-2026-10-19.zip`.
Next: Step 24 — simulation checkpoints: repeatable handling input playback and
numeric tolerances for acceleration, stopping, turning and throttle telemetry.

## Step 24 — Simulation checkpoints

Task ID: `simulation-checkpoints`.
Added recorded 60 Hz input playback for acceleration, braking, turning, sideways
thrust and neutral coasting. Named numerical tolerances protect the accepted
handling; repeat runs and a deliberate private 20% thrust mutation verify the guard.
Timestamped command/actual engine telemetry and ahead/astern power-seconds are
available for future fuel work without inventing a consumption formula.

SIMULATION_CHECKPOINTS.md records fixtures, values, tolerances, limits and the
manual baseline-update policy. Gameplay code and player settings are unchanged.
Collision and render-cap checks remain alongside the unobstructed numerical replays.

Next: Step 25 — world-size experiment, measuring long-distance coordinate behavior
before selecting the world-coordinate strategy.

Status: complete — October 19, 2026. Full suite passes 16 stages; HandlingCheck
passes 98 checks in editor and Windows Release, including the final stopping-distance
guard. Recovery tag: `step-24-simulation-checkpoints`; verified source backup:
`../output/checkpoints/step-24-simulation-checkpoints-2026-10-19.zip`.

## Step 25 — World-size experiment

Task ID: `world-size-experiment`.
Status: complete as an isolated technical experiment — October 20, 2026.
Measured slow motion, thin-pier collision and camera behavior from origin through
10 million meter controls. Unbounded scene coordinates lose motion/contact;
+/-1 km local patches pass. Selected scalar-double global geographic identity
with shared local-meter physics and coordinated frame mapping, preserving the
continuous-world goal. No speculative custom double engine build is required.

Seam/pole travel, full equatorial/meridian circuits, local marker agreement,
two-hull contacts across geographic boundaries and coherent camera/velocity/
attached-visual frame changes pass. Native Windows Release reproduces the result.
A 100 km navigation radius is the experiment profile, with 50/250 km timing
comparisons documented. Final authored voyage pacing, world streaming, multiplayer
frame ownership and production spatial schema remain explicit later gates.
No hidden shallows were added and the playable handling scene is unchanged.

Full suite: 17 stages. WorldSizeCheck: 2,042 assertions in editor and native Windows
Release. Details, measured table and scope: WORLD_SIZE_EXPERIMENT.md.
Recovery tag: `step-25-world-size-experiment`; verified source backup:
`../output/checkpoints/step-25-world-size-experiment-2026-10-20.zip`.
Next: Step 26 — isolated heavy-lifter deck/payload feasibility prototype.

## Step 26 — Special cargo feasibility prototype

Task ID: `special-cargo-feasibility-prototype`.
Status: complete — October 20, 2026.
Created a new heavy-lifter and industrial payload in Blender 3.6.1, matching the
starter's low-poly geometry language and exact material roles. Preserved editable
source and three GLBs; the original starter source remains hash-identical.

Heavy-Lifter Test is available in the menu: lower, align the test payload, secure,
raise, sail/turn, lower and release. Compound collision ownership avoids unstable
stacked bodies. Stopped/alignment gates, swept lift clearance, cargo-height
obstacles, release/reload and visible buttons are verified. Starter handling is
unchanged; wake dimensions now support the wider prototype while keeping defaults.

Full checks pass 18 stages / 57 scripts. HeavyLifterCheck passes 32 checks in editor
and native Windows Release. A missing explicit export entry was caught and fixed;
standalone packaging now includes the heavy script and all model GLBs. Blender
preview and loaded/turning native Godot captures inspected. Final art preference,
rated mass/capacity, buoyancy and production job/networking remain later work.
See HEAVY_LIFTER.md. Recovery tag: `step-26-heavy-lifter`.
Verified source backup: `../output/checkpoints/step-26-heavy-lifter-2026-10-20.zip`.
Next: Step 27 — reusable ship composition.

## Step 27 — Reusable ship composition

Task ID: `reusable-ship-composition`.
Status: complete — October 20, 2026.
Starter and heavy-lifter runtime scenes share propulsion, helm input, visual
assembly, collision construction, cargo anchors, camera and wake setup.
Ship definitions own dimensions and handling; the heavy carrier has gentler
acceleration/turning while the starter's accepted baseline stays unchanged.
Boat Handling Test now displays the preserved Blender starter model.

Both hulls pass a separate handling course under translated/rotated parents,
including forward/reverse/side contacts, turning and instance independence.
Full suite passes 19 stages / 61 scripts. Native Windows Release passes
CompositionProbe (60 checks) and HeavyLifterProbe (32 checks). Starter scene
capture inspected. See SHIP_COMPOSITION.md for composition and remaining scope.
Recovery tag: `step-27-ship-composition`.
Source backup: `../output/checkpoints/step-27-ship-composition-2026-10-20.zip`.
Next: Step 28 — fuel simulation.
