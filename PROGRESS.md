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
The entry point is `features/main/main.tscn`, with the Container Ship Sim menu.
Play uses local development saves until public services are configured; Servers
opens public server selection. Earlier setup-screen descriptions below are history.
See DEVELOPMENT_REVIEW.md for the latest consolidated assessment.

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

## Step 28 — Fuel simulation

Task ID: `fuel-simulation`.
Status: complete — October 20, 2026.
Both ships consume per-instance propulsion fuel from actual engine output,
with configurable idle, reverse, thruster and docked rules. Simulation pause
stops burn. Empty tanks cut power and preserve coasting; stopped/neutral test
refueling recovers both hulls without automatic refilling.
Live fuel displays and labelled test controls are in both handling scenes.
Rates/capacities are provisional; paid services, durable fuel and authority
remain later steps. See FUEL_SIMULATION.md.

Full suite passes 20 stages / 64 scripts. FuelCheck passes 42 assertions in
editor and native Windows Release, with identical consumption at 30/60/144
render caps. Starter handling regressions pass; native HUD inspected.
Recovery tag: `step-28-fuel-simulation`.
Source backup: `../output/checkpoints/step-28-fuel-simulation-2026-10-20.zip`.
Next: Step 29 — local network session, verified with two processes.

## Step 29 — Local network session

Task ID: `local-network-session`.
Status: complete — October 20, 2026.
Added Local Multiplayer Test with loopback host/join/disconnect controls and
actual runtime hulls. Host-authoritative, revisioned lifecycle snapshots give
both instances the same stable session entity IDs. Repeated joins do not
duplicate ships; disconnect and host loss clean up their entities.

Two independent processes pass 21 host and 26 client checks plus identity-list
comparisons over three rounds, in both editor and Windows Release.
The network-restricted sandbox blocked local traffic; normal localhost execution
passed without changing firewall or system networking settings.
Full suite: 21 stages / 67 scripts. Native menu/host UI inspected.
See LOCAL_NETWORK_SESSION.md for use, evidence and authority boundaries.
Recovery tag: `step-29-local-network-session`.
Source backup: `../output/checkpoints/step-29-local-network-session-2026-10-20.zip`.
Next: Step 30 — ship movement replication. Internet play remains later work.

## Step 30 — Ship replication

Task ID: `ship-replication`.
Status: complete — October 20, 2026.
Local Multiplayer Test now supports both players sailing with saved helm
bindings, follow cameras, wakes and live fuel. Host physics owns both ships;
client input is ownership/bounds/sequence validated. Missing input orders
neutral; client hulls interpolate bounded authoritative snapshots.

Two-process normal and simulated 100 ms each-way / jitter / 10% message-loss
profiles pass in editor and Windows Release (24 and 26 assertions respectively).
Release input-ack means: 19.3 ms local, 228.3 ms impaired; interpolation adds
150 ms. Prediction deferred pending steering-feel review and later internet
measurements. See SHIP_REPLICATION.md for exact metrics and limits.
Native two-boat sailing capture inspected; disconnect wake cleanup fixed.
Full suite: 22 stages / 69 scripts, including lifecycle and both motion profiles.
Recovery tag: `step-30-ship-replication`.
Source backup: `../output/checkpoints/step-30-ship-replication-2026-10-20.zip`.
Next: Step 31 — attached-payload networking feasibility.

## Step 31 — Attached-payload networking feasibility

Task ID: `attached-payload-networking-feasibility`.
Status: complete — October 20, 2026.
Added Host heavy locally and owner-validated deck/load controls. Full cargo
state travels with ship motion; client attachment and deck transforms share
the interpolation timeline. The host alone owns carried/floating collision.
Reliable cargo commands preserve submission order through the delay shim.

Two-process normal and impaired profiles pass 32 assertions each in editor
and Windows Release. Loaded turns, late join/reconnect, foreign/duplicate
command rejection, release/reattachment and actual high-rail collision pass.
Recorded cargo-anchor positional error is 0.0 m across attached samples.
Native loaded client scene and controls inspected. Guest persistence remains
later work; no walking controller was added. See ATTACHED_PAYLOAD_NETWORKING.md.
Full suite: 23 stages / 71 scripts.
Recovery tag: `step-31-attached-payload-networking`.
Source backup: `../output/checkpoints/step-31-attached-payload-networking-2026-10-20.zip`.
Next: Step 32 — early dedicated capacity experiment.

## Deferred player feedback — October 20, 2026

Recorded three requested follow-ups in BUILD_DEPENDENCIES.md and
HANDLING_FEEDBACK.md: reproduce and fix cargo pickup failure, improve neutral
selection/full-stop recognition before docking/loading, and polish placeholder
foam/wakes during fleet/world content work before the experience gate.
These are scheduled work, not completed fixes. Gameplay is unchanged; Step 32
has not started as part of this documentation update.

## Supplemental step — Connected-world network feasibility

Task ID: `connected-world-network-feasibility`.
Status: complete — October 20, 2026.
Completed the prerequisite scheduled after Step 31: two-process seam and polar
chart transitions with a loaded heavy ship, preserved camera/velocity/heading,
solid payload collision, nearby marker coherence, disposable spatial JSON reload
and observer reconnect preserving the host ship and cargo identity.

Normal and delayed profiles pass 75 assertions each in editor and Windows Release.
Spatial identity/atomic transition contract and explicit integration limits are
recorded in CONNECTED_WORLD_NETWORK.md. The playable scene and reported cargo/
neutral issues are unchanged. Windows release startup passes.
Full suite: 24 stages / 73 scripts.
Recovery tag: `connected-world-network-feasibility`.
Source backup: `../output/checkpoints/connected-world-network-2026-10-20.zip`.
Next: Step 32 — early dedicated capacity experiment.

## Step 32 — Early dedicated capacity experiment

Task ID: `early-dedicated-capacity-experiment`.
Status: complete as an early measurement/architecture experiment — October 20, 2026.

Added a repeatable three-process load harness with 2/10/25/50/100 real loopback
connections, dispersed and non-overlapping port layouts, actual hull/fuel physics,
quay contact, input/actions, reconnects and a separate interpolating observer.
Added a tested 350 m relevance grid. All ten corrected Windows Release cases pass;
75 scripts compile, editor capacity smoke and Windows startup pass. A rendered
100-crowded repeat also passes the fixture's stated assertions.

At 100 crowded, authority work p95 is 6.28 ms, memory 83.4 MiB, and application
egress 71.154 Mbps. Rendered acknowledgement p95 is 227 ms. These short local
measurements do not approve a production player limit. D062 and the supplemental
`bounded-replication-and-client-pacing` gate require packet/queue and responsiveness
work before Step 42 or production multiplayer expansion. Detailed measurements,
scope and retained machine-readable results: CAPACITY_EXPERIMENT.md.

Playable handling, water and cargo behavior remain unchanged; Andy's reports
remain scheduled. Full now offers 25 stages; unchanged older stages were not
rerun for this isolated diagnostic addition.
Recovery tag: `step-32-early-dedicated-capacity`.
Source backup: `../output/checkpoints/step-32-early-dedicated-capacity-2026-10-20.zip`.
Next: Step 33 — action validation.

## Step 33 — Action validation

Task ID: `action-validation`.
Status: complete — October 20, 2026.

Added one fixed typed request/result authority path for helm and a harmless test
pulse. Transport sender, current session epoch and live roster control ownership.
Canonical action IDs, bounded receipts and retained sequence high-water marks
prevent repeated effects, including after cache eviction. Payload conflicts,
invalid types/ranges and rate limits return explicit errors. A retry cannot
refresh helm timeout or turn a previously failed command into a new effect.

Live helm requests now use this authority path; session protocol is 4. Public
identity and durable economic receipts remain later prerequisites. Cargo pickup,
stopping usability and water follow-ups are unchanged. See ACTION_VALIDATION.md.

49 action assertions pass in editor and Windows Release; full suite passes
26 stages / 77 scripts. Exported impaired movement and normal startup pass.
Recovery tag: `step-33-action-validation`.
Source backup: `../output/checkpoints/step-33-action-validation-2026-10-20.zip`.
Next: Step 34 — money and transfer rules.

## Step 34 — Money and transfer rules

Task ID: `money-and-transfer-rules`.
Status: complete as an in-memory authority/atomicity proof — October 20, 2026.

Andy excluded player-to-player economic transfers/gifts/trading. D064, GAME_SPEC,
F047/U037 and BUILD_DEPENDENCIES record that scope; Steps 103–105 are not applicable.
Game-owned purchases/resale, service fees and earned cargo/job payments remain core.

Added an integer wallet/inventory ledger with game-owned endpoints, fixed test
prices, atomic prepare/publish, balanced journal entries and retained outcomes.
No caller-selected peer recipient or price is accepted. Retries do not duplicate
charges/payments/cargo; failures preserve all economic state. Overflow, stock,
funds, stale revisions and receipt capacity are checked before committing.
The existing menu test purchase now uses this ledger; continue retains its state.

82 economy assertions, 21 session checks and 22 clock checks pass in editor and
native Windows Release. Application flow, 79-script compilation, export and
startup pass. Full now offers 27 stages; unchanged network/physics suites were
not rerun. See ECONOMY_RULES.md for fixture-only limits and test prices.

Recovery tag: `step-34-money-and-transfer-rules`.
Source backup: `../output/checkpoints/step-34-money-and-transfer-rules-2026-10-20.zip`.
Next: supplemental public-storage adapter proof, required before Step 35 durable
action recovery. The no-peer-economy decision does not remove this storage gate.

## Supplemental — Public storage adapter proof

Task ID: `public-storage-adapter-proof`.
Status: complete for isolated synthetic accounts — October 21, 2026.

Added a separate loopback Python service backed by real pinned PostgreSQL, with
strict game-owned transaction requests, actor-scoped durable receipts, ordered
row locks and an atomic resource/journal/receipt commit. No peer transfers are
accepted. Godot receives service credentials only; no database credentials.

Proved duplicate and competing concurrent requests, payload conflicts, retained
failures, private/public isolation, service death before/after commit, database
crash with a partial write, WAL recovery, outage and retry. The committed audit
reconstructs every wallet and inventory with conserved total resources.

98 harness checks pass with both editor and Windows Release; each includes four
Godot HTTP assertions. All 80 GDScripts compile, export and normal startup pass.
The older physics/network suites were not rerun for this isolated adapter proof.
Accepted reports: tools/baselines/public-storage-proof.json. Full limitations,
dependencies and commands: PUBLIC_STORAGE_PROOF.md. Production identity, TLS,
leases, scalability and playable game persistence are not claimed. The game and
previously scheduled handling/cargo/water follow-ups remain unchanged.

Recovery tag: `public-storage-adapter-proof`.
Source backup: `../output/checkpoints/public-storage-adapter-proof-2026-10-21.zip`.
Next: Step 35 — durable action recovery.

## Step 35 — Durable action recovery

Task ID: `durable-action-recovery`.
Status: complete for bounded private authority economy — October 21, 2026.

Added a SQLite-backed EconomyLedger with one transaction for the authoritative
wallet/inventory snapshot and retained terminal receipt. SessionAuthority can
explicitly bind a private recovery store, using its existing transaction flow.
Startup replays validated receipts and compares the recovered snapshot; wrong
realms, future schemas and inconsistent records disable writes without resetting
money. Cross-connection requests read current state under the database write lock.

107 completed-phase assertions plus three forced-termination boundaries pass in
editor and Windows Release. Compile (82 scripts), session (21), economy (82),
clock (22), application flow, Release export/startup and Release economy pass.
Full now has 28 stages; unchanged physics/network stages were not rerun.

See DURABLE_ACTION_RECOVERY.md for exact retention/retry policy, evidence and
limits. Receipts never expire; the prototype stops new intents at 1,024 outcomes.
Play remains disposable until the full-world save identity/startup integration
at Step 36. Physical ship/cargo state, fuel and timers are not saved here.
Previously scheduled pickup/neutral/water follow-ups remain unchanged.

Recovery tag: `step-35-durable-action-recovery`.
Source backup: `../output/checkpoints/step-35-durable-action-recovery-2026-10-21.zip`.
Next: Step 36 — versioned local persistence.

## Step 36 — Versioned local persistence

Task ID: `versioned-local-persistence`.
Status: complete for the starter private development world — October 21, 2026.

Play now restores a durable local authority. Boat Handling Test entered through
the main menu saves/restores the starter ship's geographic pose and fuel, every
ten seconds and on normal departure. Stable player/ship/owner/inventory IDs and
versioned current/previous checkpoints share the database with the receipt ledger.
The restored ship is stationary/neutral. Preview cargo remains visual; heavy and
local-network fixtures remain independent. Settings remain separate.

SQLite transactions replace generic live-file replacement. Native backup creates
a separate last-successful-checkpoint database. Malformed spatial data can recover
the previous checkpoint without reverting newer payments/cargo. Unsupported or
unrecoverable saves fail closed and preserve files instead of resetting progress.

79 assertions plus two forced-termination boundaries pass in editor and Release,
including actual menu/handling integration. All 84 scripts compile; application
flow, 21 session checks, 22 clock checks and Step 35 recovery pass. Export and
normal startup pass. Full now has 29 stages; old physics/network suites were not
rerun. See LOCAL_PERSISTENCE.md for evidence, fixed-slot limits and recovery policy.

Recovery tag: `step-36-versioned-local-persistence`.
Source backup: `../output/checkpoints/step-36-versioned-local-persistence-2026-10-21.zip`.
Next: Step 37 — migration and missing content.

## Step 37 — Migration and missing content

Task ID: `migration-and-missing-content`.
Status: complete for the private starter world — October 21, 2026.

World schema 1 upgrades atomically to schema 2, making cargo identity and neutral
restart policy explicit. A native pre-upgrade backup is retained. Pose/fuel,
ownership, money/cargo and successful/failed payment receipts are preserved.
Missing ship/cargo content and unsupported versions stop safely with a visible
menu explanation; no replacement wallet/session is created. Settings are untouched.

190 migration checks and three process-kill boundaries pass in Godot and Windows
Release. The 79-check/two-crash persistence regression also passes in both. All
85 scripts compile; application flow, Release export/startup pass. Full now offers
30 stages. See SAVE_MIGRATION.md for evidence and limits.

The multiplayer priority is recorded in BUILD_DEPENDENCIES.md: minimal recovery
feedback, reconnects, authentication/ownership, safe handoff, public storage
integration, and correction of the measured bandwidth/client-pacing issues.
No art or extra content was added. This is still local saving, not online accounts.

Recovery tag: `step-37-save-migration`.
Source backup: `../output/checkpoints/step-37-save-migration-2026-10-21.zip`.
Next: Step 38 — save and recovery feedback, kept focused on the multiplayer path.

## Step 38 — Save slots and recovery interface

Task ID: `save-slots-and-recovery-interface`.
Status: complete for local development worlds — October 21, 2026.

Local Saves provides three slots, explicit empty-slot creation, save compatibility
status, and confirmed backup recovery into a separate empty slot. No existing
progression is overwritten. Selection applies to Play and starter handling;
switching clears the previous session continuation. Failed/interrupted recovery
copies remain blocked. Unwritable folder failures are visible and preferences
remain separate. Slot 1 preserves the original development save location.

38 checks pass in Godot and Windows Release. All 87 scripts compile; application
flow, editor persistence/migration regressions, export and Release startup pass.
Full offers 31 stages. See SAVE_SLOTS.md for evidence and bounded prototype limits.

Recovery tag: `step-38-save-slots`.
Source backup: `../output/checkpoints/step-38-save-slots-2026-10-21.zip`.
Next: Step 39 — reconnect and lifecycle. Multiplayer remains the priority.

## Step 39 — Reconnect and lifecycle

Task ID: `reconnect-and-lifecycle`.
Status: complete for the running two-player local host — October 21, 2026.

Guest reconnect reclaims the same authoritative ship, pose, fuel and attached
payload. Disconnected hulls park neutral with simulation/collision/presentation
disabled. Private fixture economic ledgers retain payment receipts through drops
and close durably on host shutdown. Wrong credentials cannot replace ownership;
old transport senders cannot regain control. Main-menu departure ends that peer's
connection; host departure ends the session. Host migration is unsupported.

72 lifecycle assertions pass in editor and Windows Release. Action ownership,
guest attached-cargo recovery, impaired motion and connected-world regressions
pass; all 87 scripts compile and export/startup pass. Full remains 31 stages.
See RECONNECT_LIFECYCLE.md for evidence and scope. Client application restart and
automatic host-world restoration remain identity work; internet play is not enabled.

Recovery tag: `step-39-reconnect-lifecycle`.
Source backup: `../output/checkpoints/step-39-reconnect-lifecycle-2026-10-21.zip`.
Next: authenticated-admission feasibility, required before Step 40 identity/control.

## Supplemental prerequisite — Authenticated admission feasibility

Task ID: `authenticated-admission-feasibility`.
Status: component proof complete — October 21, 2026.

Real Keycloak HTTPS/PKCE, validated token identity, single-use PostgreSQL tickets
and scoped SQLite private guest reconnect generations are proven. Godot DTLS
accepts the trusted server and rejects wrong names, wrong certificates and
plaintext in editor and Release. No public login or internet gameplay is enabled.
The HTTP test browser and direct registry calls are limited fixtures; integration
must connect them to the game and enforce ownership on gameplay writes.

39 authentication/registry assertions plus three PostgreSQL setup checks and
eight paired DTLS cases pass. All 88 GDScripts compile; Release export and normal
startup pass. Full remains 31 stages; the provider proof is opt-in.
See AUTHENTICATED_ADMISSION_PROOF.md for pins, evidence and remaining boundaries.

Recovery tag: `authenticated-admission-proof`.
Source backup: `../output/checkpoints/authenticated-admission-proof-2026-10-21.zip`.
Next: Step 40 — durable identity/control integration, then Step 41 ownership leases
and handoff. Public authority and replication/pacing gates still precede Step 42.

## Step 40 — Session identity and control handoff

Task ID: `session-identity-and-control-handoff`.
Status: complete for the selected private-world path — October 21, 2026.

The menu's local multiplayer scene now uses verified DTLS and explicit host
invitations. Stable world/player/ship IDs, hashed reconnect credentials and durable
connection generations replace connection numbers as ownership. Reconnect replaces
one helm, neutralizes the hull and rejects old-peer/old-generation commands.
Host worlds reopen with pose, fuel, attached cargo and existing payment receipts.
Client credentials remain memory-only; closing a client window loses its reconnect
credential until OS-secured persistence is implemented. No public login is enabled.

70 starter and 74 heavy-lifter assertions pass in editor and Release (288 total),
including real fresh-process recovery and missing-ledger refusal. Action/cargo
regressions pass in both; lifecycle and impaired replication pass in editor.
All 92 scripts compile; Release export and ordinary startup pass. Full remains
31 stages plus the explicit CheckIdentity runner. See PRIVATE_SESSION_IDENTITY.md.

Recovery tag: `step-40-private-identity-control`.
Source backup: `../output/checkpoints/step-40-private-identity-control-2026-10-21.zip`.
Next: Step 41 — public profile and server-switch handoff. Connect public authenticated
admission to server ownership leases; complete the two-server authority integration
and bounded replication/client-pacing gates before Step 42.

## Step 41 — Public profile and server-switch handoff

Task ID: `public-profile-and-server-switch-handoff`.
Status: complete through the selected-storage integration fixture — October 22, 2026.

PostgreSQL now owns portable public profiles, expiring server leases, connection
generations, durable quiesce/seal/claim transfers and payment receipts. Real HTTPS
server-adapter processes cannot concurrently spend one account or revive an old
owner. Transfers preserve canonical ship/cargo/job IDs, fuel, position and money;
private imports and peer economic transfers have no accepted operation.

86 assertions plus three PostgreSQL setup checks pass, including concurrent
claims/payments, five real service crashes, two database stops, lost replies,
expiry races, destination-process death, stale-owner rejection and late claim
retries returning current state. See PUBLIC_PROFILE_HANDOFF.md and evidence
`../output/handoff/020fddf3/summary.json`. Game code/export remains Step 40.

Recovery tag: `step-41-public-profile-handoff`.
Source backup: `../output/checkpoints/step-41-public-profile-handoff-2026-10-22.zip`.
Next: public authority integration with validated OIDC admission and two headless
Godot instances, followed by bounded replication/client pacing, before Step 42.
The Python adapter-worker proof is not a playable dedicated server or public launch.
Keep the eventual dedicated-server launch and player join flow straightforward.

## Public Godot ownership adapter checkpoint

Task ID: `public-authority-integration-gate` (server adapter portion).
Status: adapter implemented; full public transport/gameplay gate remains open.

Validated OIDC access tokens now issue scoped tickets through the HTTPS service.
Real Godot processes acquire ownership, move the starter hull, renew on a timer,
checkpoint actual departure position/fuel, and quiesce physics/collisions/input
before transfer. Destination restart and backend-outage recovery preserve canonical
ship/cargo records and receipts while rejecting old ownership generations.

The test courier is operator-owned, not a public player connection. Public DTLS
peer admission, system-browser sign-in/server selection, world/cargo/action
integration and dedicated-server launch configuration remain next. Bounded
replication/client pacing still follows before Step 42. See PUBLIC_GODOT_OWNERSHIP.md.

Verified October 22: 40 integration assertions plus 16 real-provider assertions
pass in each of editor and Release; three PostgreSQL setup checks accompany each.
Evidence: `../output/handoff/d04d1341/godot-summary.json` (editor) and
`../output/handoff/de4d472e/godot-summary.json` (Release). The separate 86-check
backend suite passes at `../output/handoff/76271b4e/summary.json`. All 95 scripts
compile; Release export and ordinary startup pass. The original project.godot
working-tree customization is preserved outside this source checkpoint.

Recovery tag: `public-godot-ownership-adapter`.
Source backup: `../output/checkpoints/public-godot-ownership-adapter-2026-10-22.zip`.

## Public peer admission and dedicated runtime checkpoint

Task ID: `public-authority-integration-gate` (authenticated player transport).
Status: transport checkpoint complete — October 22, 2026; shared gameplay/UI gate open.

Real sign-in tickets now cross verified DTLS into a separate Godot server. The
server binds each transport to its canonical ship/epoch/generation, rejects
cross-account and stale controls, and sends owner movement snapshots. Two distinct
accounts can hold separate helms; replacement removes the previous helm before
activating another. Disconnect checkpoints pose/fuel and releases ownership;
automatic renewal failure disconnects the player and parks the hull.

A normal headless server configuration entry point and StartDedicatedServer.ps1
launcher now exist. The launcher reports process/log paths. Persistent authority
provisioning/enrollment is not packaged; the placeholder configuration is not a
working public server. No hosting purchase or network/router changes were made.

48 integration checks plus 16 provider checks pass in both editor and Release:
`../output/handoff/ccbaecb9/peer-summary.json` and
`../output/handoff/c8a6a644/peer-summary.json`. Backend regressions pass all 86
checks (`../output/handoff/d67d8ef7/summary.json`). All 98 scripts compile;
Release export, ordinary startup and the actual PowerShell launcher smoke test pass.
See PUBLIC_PEER_ADMISSION.md for the precise tested boundary.

Next: public world/client integration and player-facing sign-in/server selection.
Hulls still use separate local charts; shared placement/collisions, cargo actions,
periodic saves and the server-switch player flow remain open. Bounded replication/
client pacing still follows before Step 42. Keep the full authority gate open.

Recovery tag: `public-peer-admission`.
Source backup: `../output/checkpoints/public-peer-admission-2026-10-22.zip`.

## Public nearby boat presentation checkpoint

October 22, 2026: authenticated peers now receive complete nearby boat rosters
and materialize inert, smoothed hull replicas in recipient-relative geographic
coordinates. Departure removes the hull; disconnect clears the view. Saves and
observer snapshots share one canonical address calculation. See PUBLIC_NEARBY_BOATS.md.

Validation: 52 integrated editor checks plus 16 provider checks passed in
`../output/handoff/bd1a0d33/peer-summary.json`. The added distinct-anchor spacing
assertion also passed in the 43-check editor adapter-only run at
`../output/handoff/dc93438a/peer-summary.json`. All 53 integrated Release checks
plus 16 provider checks passed at `../output/handoff/9fd21a01/peer-summary.json`.
All 99 scripts compile, Release exports, and normal exported startup passes.
These are headless transport/scene-node checks, not visual acceptance testing.

Next: safe shared server placement/collision physics and player-facing public
camera/control scene, followed by sign-in/server selection. Public cargo/actions,
periodic saves and bounded replication/client pacing remain required. The full
public authority integration gate and Step 42 are not marked complete. Main-menu
Play remains unchanged; this checkpoint is infrastructure for the public flow.

Recovery tag: `public-nearby-boats`.
Source backup: `../output/checkpoints/public-nearby-boats-2026-10-22.zip`.
Existing project.godot customization stays outside this checkpoint.

## Public shared boat physics checkpoint

October 22, 2026: nearby authenticated hulls now share real collision spaces.
Groups merge/split and rebase before physics while preserving geographic pose,
heading, velocity and fuel. Public hull vertical translation is locked to prevent
collision recovery pushing one boat beneath another. Occupied saved spawns are
refused and their leases released without overwriting saved position/fuel.
Departing hulls detach safely while asynchronous save/release completes.
Also corrected an existing double-close warning during client disconnect.
See PUBLIC_SHARED_PHYSICS.md and decision D078.

Validation: 26 focused physics checks pass in both editor and Release at
`../output/shared-physics/3dd8d8a9/summary.json` and
`../output/shared-physics/7edf5758/summary.json`. The integrated peer suite passes
58 checks plus 16 provider checks in editor (`../output/handoff/1284bccc/peer-summary.json`)
and final Release (`../output/handoff/848b50af/peer-summary.json`). A 48-check final
Release adapter-only run additionally verifies transport cleanup at
`../output/handoff/f4cbbbb9/peer-summary.json`. All 101 scripts compile; Release
export and ordinary startup pass. An earlier Release run was invalidated by
rebuilding its resource pack while active; it was replaced by the complete final
run against the finished export. Final logs have no script/resource parse or
double-close errors; deliberate wrong-hostname fixtures still log TLS rejection.

Next: playable public camera/control scene and sign-in/server selection.
Starting-berth allocation and occupied-spawn messaging, public cargo/actions,
periodic saves and bounded replication/client pacing remain open. The full public
integration gate and Step 42 remain open. Main-menu Play is unchanged.

Recovery tag: `public-shared-physics`.
Source backup: `../output/checkpoints/public-shared-physics-2026-10-22.zip`.
Existing project.godot customization remains outside the checkpoint.

## Public camera and helm scene checkpoint

October 22, 2026: the actual public player scene now composes authenticated boats
with the existing bright-blue ocean, follow/orbit camera, opaque speed/fuel HUD,
saved throttle/steering input and an unpaused connection menu. Input is sequenced
at 10 Hz; menu, focus loss, stale owner/roster updates and disconnect neutralize
orders. Visual replicas remain inert and speed/fuel come from server snapshots.
The scene exposes a verified connection challenge/ticket boundary for the upcoming
browser sign-in flow; it does not implement login or store passwords.
See PUBLIC_CLIENT_SCENE.md and D079.

Validation: editor adapter-only checks passed 54 assertions at
`../output/handoff/0caa648d/peer-summary.json`; the final Release integration passed
65 assertions plus 16 provider assertions, including the added stale-update check,
at `../output/handoff/0238235c/peer-summary.json`. Fixtures inherit the actual player
scene and drive a normal dedicated server. All 103 scripts compile, Release
exports, normal title startup passes, and the disconnected player-scene preview
opens/exits cleanly (`../output/public-client-preview/smoke.log`). These are headless
checks; final visual quality and network-latency feel have not been established.

Next: wire the player-facing system-browser sign-in and server-selection flow.
Approved enrollment, starting positions/occupied-spawn feedback, public cargo and
thrusters, water-motion/wakes, periodic saves and capacity/pacing remain open.
Main-menu Play is unchanged until public admission UI is connected. The full
integration gate and Step 42 remain open.

Recovery tag: `public-client-scene`.
Source backup: `../output/checkpoints/public-client-scene-2026-10-22.zip`.
The preexisting project.godot customization remains outside this checkpoint.

## Public browser sign-in checkpoint

October 22, 2026: Servers now opens the public server-selection page. Configured
players can sign in in their system browser using native Godot PKCE, exchange the
code over HTTPS, obtain an enrolled-account ticket, and enter the playable public
boat scene. Cancellation, timeout, retry and disconnect clear transient credentials.
The game does not collect passwords or persist access/refresh tokens. Play retains
local development saves until an operator installs the public service configuration.
See PUBLIC_SIGN_IN.md and decision D080.

Validation: 18 native entry/integration assertions plus 16 provider assertions pass
in both editor (`../output/handoff/b26b7a11/login-summary.json`) and final Release
(`../output/handoff/dadc09e4/login-summary.json`). The tests navigate a real disposable
identity provider and exercise Godot's callback, token exchange, unenrolled-account
rejection, ticket admission, driving and lease release on a normal dedicated server.
All 106 scripts compile; FlowCheck verifies Servers navigation and Escape return;
Release export and disconnected entry startup/exit smoke pass. The test browser is
headless: interactive browser launch and visual acceptance still need user testing.
An initial fixture timeout was resolved by matching HTTPS addresses to the services'
IPv4 listeners, without weakening TLS verification.

No persistent online services or real accounts were provisioned. Unconfigured
builds show a clear setup message. Next: repeatable persistent service/account setup
and safe starting positions, followed by the remaining public integration gate.
Public cargo/actions, periodic saves, capacity and replication pacing remain open;
Step 42 remains gated. No player-to-player economy features were added.

Recovery tag: `public-browser-sign-in`.
Source backup: `../output/checkpoints/public-browser-sign-in-2026-10-22.zip`.
The preexisting project.godot customization remains outside this checkpoint.

## Development review — October 22, 2026

Reviewed roadmap Steps 01–142 and coverage/dependencies against progress records,
current public login/helm/ownership code, stored integration evidence and the
reported heavy-loader defect. See DEVELOPMENT_REVIEW.md. Corrected stale current
scope wording about grounding/setup-only state; retained original reference files.
No gameplay changed. Step 42 remains open. Reconfirmed pickup repair before Step
50, with neutral/stop usability before Step 46. Added explicit near-term save,
shutdown and bounded-network priorities without adding production content scope.

Fresh verification: 106 scripts compile and startup passes; FlowCheck passes;
PersistenceCheck passes 79 assertions across five editor phases, including owned
process termination/recovery. Evidence: ../output/persistence-checks/Editor-875ed4a4e18841ab8bf98c66df9c2c42.
Recent editor/Release online evidence was reviewed, not rerun in this documentation
review. No WAN/capacity/visual acceptance or heavy-loader repair is claimed.
Recovery tag: development-review-2026-10-22. Source archive uses the same tag name.
Preexisting project.godot customization remains untouched and outside Git archive.

## Player preference update — October 22, 2026

100-player capacity is an optional stress-test reference, not a product requirement.
Actual supported server size remains to be measured and selected. Added a small
reverse/neutral/forward throttle slider indicator to the next handling/neutral-stop
pass, alongside actual motion feedback. No gameplay or aesthetic changes made.

## Persistent local online setup checkpoint — October 22, 2026

Added tools/LocalOnline.ps1 (Setup/Start/Stop/Play) and a persistent loopback-only
supervisor using the already pinned provider, PostgreSQL, authority and dedicated
runtime. Two generated development accounts preserve their identity and canonical
progress across restarts. Setup refuses overwrite; concurrent supervision is
locked; credentials live in a restricted directory and are not console output.
Play selects a separate APPDATA profile, leaving ordinary saves unchanged.
No new downloads, production accounts, firewall or OS trust changes were made.

Validation: 13 persistent-stack assertions passed at
../output/local-online/check-84f7430f/check-summary.json. Both accounts completed
native Godot sign-in, movement, departure saving and lease release before and after
a full service restart. Canonical account/ship IDs, money, revision, fuel and pose
were identical across restart. Duplicate supervisor refusal and cleanup passed.
The PowerShell Start/Stop wrapper separately started the existing Release server,
reached readiness and stopped its services successfully. Python compilation and
PowerShell parsing passed. No game scripts changed or export rebuild was needed.

Browser navigation in the proof uses an HTTP test browser with explicit certificate
trust. Ordinary browser trust and interactive acceptance remain pending; no claim
of one-click browser readiness is made. Certificate expiry/rotation, orphan cleanup,
real enrollment/hosting and general safe spawning remain open. Fixed separated
initial fixture positions do not solve occupied saved positions. Server Stop still
requires players to disconnect first: periodic saves and graceful drain are next.
See LOCAL_ONLINE.md and D081. Step 42 remains open.

Recovery tag: persistent-local-online.
Verified source backup: ../output/checkpoints/persistent-local-online-2026-10-22.zip.
Existing project.godot customization remains outside this Git archive.

## Public periodic saves and shutdown checkpoint — October 23, 2026

Public owners now attempt coherent geographic pose/heading/fuel saves every ten
seconds while sailing. Pending-save guards protect disconnect, transfer and
replacement cleanup. The dedicated server accepts an operator-owned stop marker,
refuses new admission, parks boats and awaits final checkpoints/releases before
reporting success. LocalOnline waits for this drain before stopping the backends.
Standalone stop tooling and configuration example are included. See PUBLIC_DURABILITY.md
and D082. No handling/UI polish or player-to-player economy changes were made.

Final verification: 26 durability checks pass in editor at
../output/handoff/7c32861a/durability-summary.json and Release at
../output/handoff/62fb72ab/durability-summary.json. These exercise actual DTLS peers
and the normal dedicated runtime with fixture-issued tickets (not an OIDC rerun):
periodic moving saves, process kill, real lease expiry, crash recovery, final save,
release/immediate reconnect, replacement-admission shutdown and backend failure.
The existing adapter-only peer regression passed 55 checks at
../output/handoff/f3994737/peer-summary.json. All 106 scripts compile; startup and
final Release export pass. PowerShell/Python syntax checks pass. LocalOnline's
exported server Stop separately reached PUBLIC_SERVER_DRAINED before backend exit.

The first durability driver attempted throttle before its client was input-ready;
its timing was corrected. A replacement/shutdown race correctly rejects the stale
owner's final write and reports incomplete drain; the test now verifies explicit
outcome and released ownership rather than requiring an unsafe stale write to pass.
No failed-save success is claimed. Ten seconds is a scheduling interval, not a hard
crash-loss guarantee: service latency and pending work add delay. Forced termination
or unavailable authority restores the last committed snapshot. Browser acceptance,
safe saved-spawn handling, public gameplay parity and network pacing remain open.
Step 42 stays open; next is bounded replication/client pacing at practical capacity.

Recovery tag: public-periodic-saves.
Verified source backup: ../output/checkpoints/public-periodic-saves-2026-10-23.zip.
The preexisting project.godot customization remains outside the Git checkpoint.

## Compact public network checkpoint — October 23, 2026

Combined owner/nearby updates into validated fixed-size complete frames, using
binary ship UUIDs and local float coordinates. At the current eight-peer cap the
payload is 352 bytes and serialized RPC arguments 444 bytes. Snapshots now run at
10 Hz instead of two separate 5 Hz streams; skipped frames need no delta history.
Helm orders are sequenced unreliable-ordered and client send deadlines are monotonic,
so a stalled client sends latest state rather than a catch-up burst. Existing
ownership, freshness, idle neutralization and save boundaries remain in force.
See PUBLIC_NETWORK_PACING.md and D083. Matching client/server builds are required.

Validation: 23 codec checks pass in editor and Release, including malformed/truncated
frames, duplicate identity, nonfinite/range/generation checks and precision. All 108
scripts compile; startup/export pass. The existing editor adapter-only peer suite
passes 55 checks at ../output/handoff/42685b2d/peer-summary.json. The final eight-peer
Release probe passes 18 checks at ../output/handoff/88b871c5/pacing-summary.json.
Its pacing-metrics.json records 34,636 serialized snapshot argument bytes/second
aggregate over 9.64 seconds, 444 maximum argument bytes, client send-to-ack p95/max
137 ms, snapshot-building p99 3.409 ms and group-sync p99 0.362 ms. Those work samples
do not include all physics/server work; clients were headless on loopback.

Same-data serialization comparison: 4,440 bytes/second/recipient at the new 10 Hz
versus at least 6,620 for the old 5 Hz format, about 33% less even with twice the
update frequency. This excludes transport overhead. The first eight-peer run at
../output/handoff/b8300b75 measured test-runner-polled acknowledgement (172 ms p95);
final instrumentation uses client-local send/receive timestamps and removes polling
delay. Do not attribute that measurement-definition difference to a code speedup.

This completes the bounded compact-frame/latest-input implementation pass, not
full WAN/capacity acceptance. Controlled loss/latency/reordering, rendered timing,
sustained load/total frame work and final integrated foundation review remain due.
The practical cap stays eight; 100 players is not required. No aesthetic/handling
changes or deferred heavy-loader repair were made. Step 42 remains open.

Recovery tag: public-compact-network.
Verified source backup: ../output/checkpoints/public-compact-network-2026-10-23.zip.
The preexisting project.godot customization is preserved outside the checkpoint.

## Controlled public network impairment checkpoint — October 23, 2026

Added an opaque loopback UDP impairment relay and integration runner. It exercises
actual DTLS transport with 7% random loss, 20–100 ms one-way delay, deterministic
additional delays/duplication and a brief blackout. No production gameplay or
security rules changed. The peer probe records bounded process-delta/graphics
telemetry; its launcher optionally runs a hidden graphics client at a 60 fps cap.

Final editor checks: 17 pass at ../output/handoff/87f895d7/impairment-summary.json.
Final rendered Release checks: 18 pass at ../output/handoff/97044f47/impairment-summary.json.
Both verify live movement, two-boat relevance, nonregressing state, injected faults,
stale presentation/input handling, blackout recovery, resumed helm and durable
identity/money/cargo/fuel preservation on departure. The rendered client confirms
native backend frames are drawn. Script check (108), startup and Release export pass.

The final short samples record observed distinct acknowledgement-age p95 of 287 ms
(headless editor) and 399 ms (rendered Release) under the injected faults. See
PUBLIC_NETWORK_IMPAIRMENT.md for sample counts, transport accounting and limits.
Initial fixture cleanup mishandled Windows UDP endpoint-reset notifications; fixed
and rerun. Repeated-ack sampling and uncapped hidden rendering were also corrected
in the harness. No production speedup is claimed from those measurement changes.

Short controlled impairment coverage is now available. Step 42 remains open pending
integrated foundation acceptance and remaining control/spawn/usability issues;
longer outages, WAN/NAT, sustained total workload and broader hardware/soak evidence
remain unproven. No need to repeat every old step manually. Next is the consolidated
foundation acceptance review and fixing any concrete blockers it identifies.

Recovery tag: public-impaired-network.
Verified source backup: ../output/checkpoints/public-impaired-network-2026-10-23.zip.
The preexisting project.godot customization remains outside the Git checkpoint.

## Public thrusters and throttle indicator — October 23, 2026

Consolidated the foundation review in FOUNDATION_ACCEPTANCE.md. Repaired the missing
public lateral input path with existing authoritative validation/fencing. Added a
shared opaque reverse/neutral/forward throttle indicator to local and public helm
views, with actual signed motion and coasting feedback. Public signed speed adds
four bytes per complete frame; game protocol 8/snapshot version 2 require matching
builds. HTTPS ticket protocol remains unchanged. No handling or pickup retune.

Checks: 109 scripts/startup, FlowCheck, FeedbackCheck (24), CompositionCheck (60),
compact codec (24 editor and 24 Release), peer regression (55 editor adapter checks,
e4bb18bd), controls (11 editor 228f6975 / 12 rendered Release d651e434). Export passes.
Rendered HUD inspected. See PUBLIC_HELM.md for evidence paths and test limits.

Step 42 remains open: next give refused admissions useful feedback/retry guidance,
then perform combined two-account foundation acceptance. General spawn allocation
is Step 44; manual browser/WAN/sustained workload limits stay explicit. No mandatory
100-player requirement, no player-to-player transfers, no new cargo prerequisites.

Recovery tag: public-helm-feedback.
Verified source backup: ../output/checkpoints/public-helm-feedback-2026-10-23.zip.
The preexisting project.godot customization is preserved outside the checkpoint.

## Clear public join failures and retry — October 23, 2026

Added bounded reliable refusal messages for occupied saved spawns, wrong game
version, invalid/expired join permission, admission busy, account busy/transfer
and online save-service failure. Cleanup preserves the explanation; starting a new
sign-in clears it. No arbitrary backend text, automatic retry or saved-position
teleport. Game protocol is 9; matching builds required, HTTPS tickets remain 7.

The actual native entry integration now blocks an enrolled account's spawn, verifies
its complete saved profile/revision remain unchanged and lease is released, removes
the blocking boat and signs in again to sail. This caught a stale-reason retry bug,
fixed before completion. Final editor 43c95f14 and Release 6535806f each pass 23
integration + 16 provider checks. Editor peer regression 1ed3c65d passes 60 checks,
including protocol/ticket refusal, reason reset and occupied-spawn delivery.
Script check (109), startup, FlowCheck and Release export pass. See
PUBLIC_JOIN_FEEDBACK.md for evidence and limits. No real browser trust or WAN claim.

Step 42 remains open. FOUNDATION_ACCEPTANCE.md now marks join feedback complete;
next is the combined two-account foundation run with practical workload limits,
then two ports once that gate passes. Heavy-loader pickup/stopping deadlines remain.

Recovery tag: public-join-feedback.
Verified source backup: ../output/checkpoints/public-join-feedback-2026-10-23.zip.
The preexisting project.godot customization is preserved outside the checkpoint.

## Step 42 foundation gate passed — October 23, 2026

Combined normal dedicated/player Release test: two distinct boats spawn, sail into
contact without crossing, consume fuel, reverse apart, save on departure/shutdown,
restart and reconnect with original identities and complete canonical profiles.
The initial ba1ca0a3 run exposed a hung final save: reparenting a hull could cancel
its child HTTPRequest while the authority coroutine kept waiting. HTTP requests
now live under the stable root, still freed on completion; lifecycle fencing and
wait-before-free remain. A real in-flight reparent/checkpoint regression passes.

Final 85fb23a5 foundation evidence passes 41 checks. Its eight-player normal-server
sample lasts 60.219 seconds with 61 all-client polls, six periodic commits per
account, successful final drain, 0.236 total dedicated-process CPU core equivalents,
91.55 MiB sampled peak working set and 50.19 MiB peak private bytes. Recent rendered
process delta p95 is 16.666 ms at a 60 fps cap. This is not WAN or long-soak evidence.

Fresh Release safeguards: 26 physics checks (c6bbbf27); 79 persistence checks
(Release-c74523fe2e4c4a4fa6605e1f50582579); 49 action checks
(Release-normal-85095b3979f54945872965ace1b3c69b); 34 impaired cargo checks
(Release-impaired-a65102021a794754804b2730ac72c79b); 26 post-fix durability checks
(173de595). Script check (109), startup and Release export pass. See
PUBLIC_FOUNDATION.md for exact evidence locations, scope and initial failure.

Step 42 is accepted for bounded local development, with manual browser trust,
WAN/NAT, broader hardware and long-soak limits explicit. Next: Step 43 two reusable
test ports, separate from economy logic. No new public cargo jobs, player transfers,
100-player promise or resolution of the user's heavy-pickup issue is implied.
Stop usability before 46, pickup repair before 50 and foam/wake polish at 99–100
remain scheduled. Source references under sources/ and attached Library files
remain untouched.

Recovery tag: foundation-gate.
Verified source backup: ../output/checkpoints/foundation-gate-2026-10-23.zip.
The preexisting project.godot customization remains outside the Git checkpoint.

## Step 43 complete — Two test ports — October 23, 2026

Created independently loadable Brindle Quay (container/refuel) and Slatewater Works
(container/heavy/repair) placeholder ports. Port/berth IDs, planned service IDs,
cargo references, spawn/approach anchors and berth envelopes are authoring data.
Quays and buildings are visible shore solids; open water remains navigable.
Port content has no economy/network/save transaction code.

Main menu PORT TEST opens a disposable starter boat preview with port selection,
existing bright blue water, wake, saved controls, orbit camera and throttle indicator.
Switching port resets the test boat only; private slots/public worlds are unchanged.
Service names describe future capabilities, not working loading/refuel/repair UI.
The compact opaque panel and title-menu spacing were visually inspected.

Checks: 112 scripts/startup, CatalogCheck, FlowCheck and Release export pass.
Independent editor probe passes 18 checks (output/ports/864ed3b9); final rendered
Release passes 21 (output/ports/25c28e0e), including overview/menu captures. Checks
cover independent loading, references, immutable service views, authored markers,
solid quays, sampled starter approach clearance and disposable boat switching.
See TWO_TEST_PORTS.md for details and scope. The approach sampling does not replace
runtime spawn checks, reservations, cargo envelopes or fallback recovery.

Next: Step 44 spawn clearance and recovery anchors. Neutral/stop usability remains
before 46 and heavy-loader pickup repair before 50. No peer transfers or hidden
shallows. Final art, world placement and public cargo integration remain later work.

Recovery tag: two-test-ports.
Verified source backup: ../output/checkpoints/two-test-ports-2026-10-23.zip.
The preexisting project.godot customization remains outside the Git checkpoint.

## Step 44 — Spawn clearance and recovery anchors — October 23, 2026

Two test ports now use padded hull clearance and ordered recovery anchors.
Reservations, hulls, shore and cargo block unsafe locations; full occupancy
returns a retry message. No shallow-water restrictions. See SPAWN_CLEARANCE.md
for integration boundaries: the preview uses this now; public geographic port
placement and saved-position recovery transactions remain later integration.
113 script/startup, CatalogCheck, FlowCheck, Release export and 40 Release port
checks pass (output/ports/dc18b974). Next: Step 45 berth eligibility.
Recovery tag: spawn-clearance.
Verified source backup: ../output/checkpoints/spawn-clearance-2026-10-23.zip.
Preexisting project.godot changes remain outside this checkpoint.

## Step 45 complete — Berth eligibility — October 24, 2026

Port Test shows live readiness based on ship position, total speed, heading,
service/cargo compatibility, hull fit and physical clearance. Thresholds are berth
data, validated before catalog publication. This step reports readiness; docking
controls and authority-owned state transitions are Step 46. See BERTH_ELIGIBILITY.md.
114-script/startup, CatalogCheck, FlowCheck, Release export and 105 rendered Release
port checks passed (output/ports/97a7b200). Opaque readiness panel visually inspected.
Next: stop/neutral usability review before Step 46 docking. Heavy pickup repair
remains before Step 50; no hidden shallows or peer transfers.
Recovery tag: berth-eligibility.
Verified source backup: ../output/checkpoints/berth-eligibility-2026-10-24.zip.
Preexisting project.godot customization remains outside this checkpoint.

## Neutral/stop usability — October 24, 2026

Implemented the requested 4% snap-to-neutral zone and gentle stopping below 2 knots
on both boats. Active propulsion overrides assistance; above threshold normal
coasting remains. Local/private/public inputs share the adjustment, and the server
owns stopping. HUD distinguishes slowing from stopped. See NEUTRAL_ASSIST.md.
Script/startup, fuel/catalog, 102 Release port checks and 12 Release public helm
checks pass, including replicated full stop. Final Release handling suite passes 134 checks
(output/neutral-handling.log). Next: Step 46 docking; pickup repair before Step 50.
Recovery tag: neutral-assist.
Source backup: ../output/checkpoints/neutral-assist-2026-10-24.zip.
Preexisting project.godot customization remains outside the checkpoint.

## Step 46 — Docking state machine — October 24, 2026

Port Test now supports Dock/Undock/Cancel, approaching/docking/docked/undocking/
underway states, exclusive authority-owned reservations, propulsion lock and
cancellation/disconnect cleanup. Added non-solid berth guides. See DOCKING_STATE.md.
Public-world port binding remains later work; two logical owners were tested on
the component, not two network clients docking at a public-world port.
115 script/startup, 42 fuel, FlowCheck, export and 119 rendered Release port checks
passed (output/ports/3bedd6f5). Next: Step 47 cargo manifest; pickup repair before 50.
Recovery tag: docking-state.
Verified source backup: ../output/checkpoints/docking-state-2026-10-24.zip.
Preexisting project.godot customization remains outside the checkpoint.

### Docking presentation preference — October 24, 2026

User requests a later presentation change, not an immediate gameplay edit:
remove water-surface docking markings from the intended game. Prefer a greyed-out
Dock button appearing near a berth, becoming colored when stopped and docking is
available. Preserve compatibility, alignment, clearance and reservation checks;
stopping alone must not bypass those checks. Current test guides remain temporary.

## Step 47 — Cargo manifest — October 24, 2026

Added per-runtime-ship cargo batches with units, quantities, origin/destination and
acquisition/job references, independent capacity pools, compatibility validation,
atomic changes and defensive copies. No loading UI or save migration yet. Current
limits are provisional (starter six container slots; lifter one heavy slot).
See CARGO_MANIFEST.md for persistence/authority integration boundaries.
116-script/startup, catalog, 66 contract checks and Release export pass. Combined
Release port/manifest suite passes 138 checks (output/ports/2508a1de).
Next: Step 48 reusable operations; heavy pickup repair before Step 50. Preserve the
later docking UI preference: no water markings, grey Dock until eligible.
Recovery tag: cargo-manifest.
Verified source backup: ../output/checkpoints/cargo-manifest-2026-10-24.zip.
Preexisting project.godot customization remains outside this checkpoint.

## Step 48 — Reusable operation state machine — October 24, 2026

Added authority-owned cargo operation records, ship reservations, start/progress/
commit/cancel/interruption states and manifest load/unload adapters. Completion
revalidates; repeated completion does not repeat cargo effects; release occurs once.
Pending records reconstruct their progress and locks from data without animations.
See CARGO_OPERATIONS.md for lifecycle, authority and persistence boundaries.
No new loading UI or disk-save schema. Step 51 must persist effects and receipts
atomically; network disconnect and docking/source rules are integration obligations.
118 script/startup, 66 contracts, FlowCheck, export and 160 combined Release checks
pass (output/ports/7717b220). Next: Step 49 container offers; pickup repair before 50.
Recovery tag: cargo-operations.
Verified source backup: ../output/checkpoints/cargo-operations-2026-10-24.zip.
Preexisting project.godot customization remains outside the checkpoint.

## Step 49 — Container offers — October 24, 2026

Port Test now displays a small seeded offer source and Accept offer action.
Exclusive authoritative acceptance preserves quotes, checks compatibility/origin
and reserves capacity across pending jobs. Unaccepted offers expire after 600
active simulation seconds; accepted terms remain fixed. No cargo/reward/save effects.
See CONTAINER_OFFERS.md for provisional values, scope and integration obligations.
119-script/startup, FlowCheck, export and 177 rendered Release checks pass
(output/ports/51542faf). HUD visually inspected.
Next: deferred heavy-loader pickup repair before Step 50 loading operations.
Recovery tag: container-offers.
Verified source backup: ../output/checkpoints/container-offers-2026-10-24.zip.
Preexisting project.godot customization remains outside the checkpoint.

## Step 50 — Loading operation and heavy pickup repair — October 24, 2026

Reproduced and fixed lowered heavy-deck/cargo collision contact. Manual stern-first
pickup, release and forward exit now pass without using the staging shortcut; added
alignment guidance. 37 editor/Release heavy checks pass. This addresses a reproduced
path, with further playtesting still useful for other collision cases.
Port Test loads accepted jobs only while docked at their origin, with authority-owned
progress, exact-once runtime completion, capacity conversion and cancellation/
interruption cleanup. Completed cargo follows preview port switching. No payment,
persistent save or public-world loading integration yet. See PORT_LOADING.md.
121-script/startup, FlowCheck, export and 187 rendered Release port/cargo checks pass
(output/ports/955e8c81). Next: Step 51 in-flight operation persistence.
Recovery tag: port-loading.
Verified source backup: ../output/checkpoints/port-loading-2026-10-24.zip.
Preexisting project.godot customization remains outside the checkpoint.

## User-directed dock services redesign and heavy camera fix — October 24, 2026

Replaced expiring offers with docked CARGO / REFUEL / REPAIR and multiple
ship-specific non-expiring jobs. Container jobs sail between two coexisting test
ports and deliver once; heavy jobs spawn nearby cargo for physical pickup and a
random open-ocean drop-off. Added free prototype refuel/repair and temporary test
earnings. Removed water docking guides; nearby Dock uses disabled/colored feedback.
Fixed own floating cargo blocking the heavy camera, with reproduction/regression.
See DOCK_SERVICES_REDESIGN.md for scope and changed roadmap requirements.
122 scripts/startup, catalog, FlowCheck, 20 camera, 39 heavy and 205 final rendered
Release combined checks pass (output/ports/2aaae26f). Both menus inspected.
This supersedes the timed-offer/port-only-heavy-delivery assumptions in earlier notes.
Step 51 remains next: persist the redesigned job types and dock service state safely.
Recovery tag: dock-services-redesign.
Verified source backup: ../output/checkpoints/dock-services-redesign-2026-10-24.zip.
Preexisting project.godot customization remains outside this checkpoint.

## Docking usability correction — October 24, 2026

Fixed sailing HUD keyboard focus traps, including cargo-list scrollbars. Both hulls
restart forward/reverse from rest through PlayerControls. Heavy berths now allow a
practical approach tolerance, preserving physical clearance and heading checks.
One active job per captain; accepting a container job automatically starts loading.
Heavy jobs retain nearby pickup. See DOCKING_USABILITY.md.
ControlsCheck, 134 handling checks and 220 final rendered Release port/cargo checks
pass (output/ports/4b745e41). Final menu captures inspected. Step 51 remains next;
visible containers Step 52; temporary minimap added to Step 56 scope.
Recovery tag: docking-usability; verified source backup:
../output/checkpoints/docking-usability-2026-10-24.zip.
Preexisting project.godot customization remains outside this checkpoint.

## Step 51 — In-flight voyage persistence — October 24, 2026

Local Port Test now saves jobs, loading progress, manifest/receipts, heavy attachment
and ocean target, pose, fuel/condition and test credits atomically. Restart is neutral;
loading and deck travel resume. Failed/corrupt saves pause without resetting progress.
Heavy pickup now uses platform-under-load rather than tight angle alignment: Raise
picks up automatically; Lower at the destination delivers. Secure is removed.
See IN_FLIGHT_PERSISTENCE.md for recovery policies and public-integration limits.
126 scripts/startup, FlowCheck, 39 heavy and 220 rendered Release port/cargo checks pass.
41-case voyage suite plus actual before/after-COMMIT process-death and reopened
single-payment checks pass in editor and Release (output/voyage/dea4dccd).
Next: Step 52 container visuals; temporary minimap remains recorded for Step 56.
Recovery tag: in-flight-voyages; verified source backup:
../output/checkpoints/in-flight-voyages-2026-10-24.zip.
Preexisting project.godot customization remains outside this checkpoint.

## Step 52 — Container visuals — October 24, 2026

User has not yet play-tested Step 51; its status remains automated verification only.
Starter cargo now appears as temporary colored, ribbed containers derived from the
manifest. Six authored deck slots, one bounded MultiMesh, no individual physics or
saved visual objects. Loading completion, delivery and restore update visibility.
Heavy industrial payload remains separate. See CONTAINER_VISUALS.md.
128 scripts/startup, catalog, 234 rendered Release port/cargo checks and 44 voyage
suite checks plus separate-process crash/restart/delivery tests pass. Empty/partial/
full views inspected (output/ports/9ed2a9a7; output/voyage/c147974b).
Next: Step 53 delivery/payout; temporary minimap remains Step 56.
Recovery tag: container-visuals; verified source backup:
../output/checkpoints/container-visuals-2026-10-24.zip.
Preexisting project.godot customization remains outside this checkpoint.

## Step 53 — Delivery and payout — October 25, 2026

Container delivery commits cargo removal, job completion and reward together before
showing success. Failed commits preserve live cargo/balance. Added authoritative
eligibility, exact accepted-batch matching, disabled-action reasons and a persistent
readable delivery receipt. See DELIVERY_PAYOUT.md for local/public scope.
129 scripts/startup, 241 rendered Release port/cargo checks and 48 voyage cases plus
actual loading/delivery process-death recovery checks pass. Evidence:
output/ports/263016bc and output/voyage/b44b9b2b. Receipt layout inspected.
Steps 51–53 remain awaiting Andy's play-test feedback; no user acceptance inferred.
Next: Step 54 voyage lifecycle reconciliation. Temporary minimap remains Step 56.
Recovery tag: delivery-payout; verified source backup:
../output/checkpoints/delivery-payout-2026-10-25.zip.
Preexisting project.godot customization remains outside this checkpoint.

## Play-test fix — Sailing save freeze — October 25, 2026

Andy confirmed cargo loaded, but repeatedly hit the save-error pause while sailing.
Reproduced on a copy of the actual save at 600 steering ticks: rotation accumulated
scale drift rejected by rigid-pose validation. Normalizing each proposed yaw fixes
the source without weakening save checks or modifying the user's save.
130 scripts/startup, 134 handling and 39 heavy checks pass. Loaded sailing, reopening
and continued opposite steering pass 330 checkpoints for copied and fresh voyages
in Release. Existing voyage/crash recovery checks pass. See SAILING_SAVE_FIX.md.
Cargo-loading animation recorded for later presentation polish. Step 54 remains next.
Partial play-test feedback received; confirmation of the fix remains pending.
Recovery tag: sailing-save-fix; verified source backup:
../output/checkpoints/sailing-save-fix-2026-10-25.zip.

## Play-test adjustment — Alongside docking — October 25, 2026

Andy confirms the save freeze is fixed and heavy-loader pickup works. Expanded berth
width/length and removed the artificial shore gap so stopped ships can dock right
alongside either quay. Other-boat/cargo clearance and actual shore physics remain.
261 editor/Release port checks and voyage/crash recovery checks pass; see
ALONGSIDE_DOCKING.md (output/ports/133ed93b; output/voyage/44e357ba).
Record mooring-rope tie-up/release animations for later port presentation polish,
alongside the already-requested cargo-loading animation. Step 54 remains next.
Recovery tag: alongside-docking; verified source backup:
../output/checkpoints/alongside-docking-2026-10-25.zip.

## Step 54 — Voyage lifecycle — October 25, 2026

Cancellation, confirmed container abandonment, ship-switch guards and conservative
orphan-loading recovery implemented. Added tested future despawn hook; carrying heavy
cargo remains protected. 78 editor/Release voyage checks and real loading/delivery
commit crash tests pass. See VOYAGE_LIFECYCLE.md. Container delivery, heavy pickup
and save-freeze fix confirmed by Andy; wider docking and Step 54 await play-test.
Next Step 55: voyage HUD. Recovery tag: voyage-lifecycle; source backup:
../output/checkpoints/voyage-lifecycle-2026-10-25.zip.

## Step 55 — Voyage interface — October 25, 2026

Added read-only voyage HUD: actual cargo, job quantity, destination, quoted payment,
next action, loading progress and readable instruments. Corrected container routing
to follow the accepted destination even at arrival; labelled previous receipts and
removed stale loading notices. Heavy pickup/drop-off and save-block states included.
132-script/startup check, 88 Release voyage checks plus crash-recovery and 270 rendered
port checks pass. See VOYAGE_INTERFACE.md. Awaiting user play-test; Step 56 minimap
next. Recovery tag voyage-interface; verified source backup:
../output/checkpoints/voyage-interface-2026-10-25.zip.

## Step 56 — Service menu and navigation usability — October 25, 2026

Added local minimap with named ports, ship heading and active container/heavy target.
Job selection survives refresh; unavailable actions display reasons, pending loading
locks service actions, and free refuel/repair test pricing is explicit. No new water
docking markings. 134-script/startup, 101 editor/Release voyage assertions plus crash
recovery, and 270 rendered port checks pass. See LOCAL_NAVIGATION.md. Public network
service timeout wiring remains outstanding; local UI never auto-resubmits commands.
Awaiting user play-test. Next Step 57 first voyage gate. Recovery tag local-navigation;
verified backup ../output/checkpoints/local-navigation-2026-10-25.zip.

## Step 57 — First voyage gate audit — October 25, 2026 (OPEN)

Added repeatable two-consecutive-job settlement and fresh-process restart checks:
101 suite + 34 round-trip checks pass in editor/Release, with two restart verifications
and existing process-kill loading/payout checks. Extended sailing passes 330 saves.
Gate is NOT accepted: Port Test remains separate from authenticated public sessions,
so two-peer cargo loading/delivery cannot yet be exercised. See FIRST_VOYAGE_GATE.md
for the required port/world, per-account job, settlement and presentation integration.
Do not advance to Step 58 until this gap is closed and the two-peer voyage passes.
Save policy clarified without changes: public account profile, three private dev
slots, and a separate single Port Test autosave. Recovery tag first-voyage-audit;
backup ../output/checkpoints/first-voyage-audit-2026-10-25.zip.

Fresh exported two-peer baseline passes 24 checks (sailing, contact, independent
saves and server restart), ../output/handoff/81248558. Full cargo gate stays open.

## Step 57 integration — Durable public container contracts — October 25, 2026

Added account-fenced accept/load/deliver/cancel transactions with canonical cargo,
server-owned terms, durable loading readiness and atomic payment/receipts. 99 real
HTTPS/PostgreSQL checks pass, including six process-kill loading/payout scenarios;
41 existing admission/economy/handoff checks pass. 134-script/startup and Release
export pass. See PUBLIC_VOYAGE_CONTRACTS.md. Full gate remains OPEN: physical online
ports/docking, peer commands, service UI and cargo replication are next. No save
policy or player save changed. Tag public-voyage-contracts; verified source backup
../output/checkpoints/public-voyage-contracts-2026-10-25.zip.

## Step 57 integration — Online port anchors and docking — October 25, 2026

Online players now see both authored test ports and use server-controlled Dock/
Undock. One server-wide berth lock survives physics regroup/rebase and releases on
disconnect, lost authority or drain. 19 editor/Release two-peer checks and 37 physics
checks pass; local voyage regression passes. Fixed tiny negative heading rounding
to invalid 360 degrees; 342 geography assertions pass. Game protocol now 10, backend
ticket protocol remains 7. See PUBLIC_PORTS.md. Gate stays OPEN: online cargo
service/contract requests and manifest presentation are next. User play-test pending.
Tag public-ports; backup ../output/checkpoints/public-ports-2026-10-25.zip.

Existing exported two-peer sailing/contact/save/restart baseline also passes 24
checks after adding physical ports: ../output/handoff/470b1bae.

## Step 57 integration — Online cargo menu and settlement — October 25, 2026

Connected authenticated docked players to canonical container contracts. Added
one-job cargo menu, loading/undock lock, nearby visible containers, destination/
wallet HUD, delivery receipt and reconnect-safe loading. Game protocol 11.
138-script/startup check, Release export, 38 actual two-peer cargo checks,
37 physics checks and local voyage/crash regressions pass. Rendered UI inspected.
See PUBLIC_CARGO_SERVICES.md. Full gate stays OPEN: these cargo checks use fixture
approach positions; complete navigated two-peer consecutive voyages remain next.
User play-test pending. Tag public-cargo-services; verified source backup:
../output/checkpoints/public-cargo-services-2026-10-25.zip.


## Deferred player-request planning — October 25, 2026

Reviewed the original 142-step roadmap and current implementation notes. Recorded
all eight new preferences with specific follow-up placements and a Wind Waker HD
reference-picture shortlist in DEFERRED_PLAYER_REQUESTS.md. D111 records the local
single-save policy change for later implementation. Runtime and saves unchanged;
Step 57 online voyage gate remains next.

## Step 57 — Automated online voyage validation — October 26, 2026

Windows Release: 37 full navigated two-player checks pass across four deliveries,
mid-trip reconnect and exact canonical restoration after server restart. A separate
66-check run passes actual loading/payment service-death recovery before/after
COMMIT. Final engine logs clean. See PUBLIC_VOYAGE_VALIDATION.md.
Added repeatable helm-driven routes and bounded read-only probe observations;
no gameplay tuning or user save changes. Automated gate evidence is complete;
manual online feedback remains pending before full acceptance. Step 58 not started.
Tag public-voyage-validation; verified backup:
../output/checkpoints/public-voyage-validation-2026-10-26.zip.


## Step 58 — Online refueling — October 26, 2026

Added dock-only REFUEL with custom whole-liter quantity, visible quote, tank-space
and balance checks. Live propulsion fuel is checkpointed before atomic purchase;
canonical tank/payment/receipt commit together. Consumed quotes cannot buy twice;
unknown outcomes fence ownership until reconnect. Protocol 12. See
PUBLIC_REFUELING.md for evidence and the local free-test-service boundary.
User authorizes continuing while manual online voyage feedback remains pending.
Andy confirmed a local Port Test heavy delivery and undock; the earlier two-window
test is not treated as confirmed authenticated online cargo acceptance.
Recovery tag: public-refueling; source backup:
../output/checkpoints/public-refueling-2026-10-26.zip.

Validation: 58 HTTPS/payment checks, 28 final Release refueling peer checks,
25 final Release commit-interruption/reconnect checks and 38 Release cargo
regression checks pass; 138-script/startup and Release export pass. Development
stack restarted and test client reopened cleanly after preserving/rebuilding its
shader cache. Manual feedback remains pending.


## Step 59 — Online impact damage and paid recovery — October 26, 2026

Server-observed hard impacts now save hull damage; gentle/glancing contact remains
harmless. Sinking atomically loses cargo, fails affected jobs and records the full
250-credit development recovery fee while retaining ship ownership. Insufficient
funds create a persisted balance repaid from half of later earnings. Recovery
restores the hull with usable propulsion fuel at an unoccupied approved return
spot. Unconfirmed impacts reconcile across connection replacement; confirmed state
survives restart. Game protocol 13. No shallow zones or local fixture changes.
109 authority, 43 physics, 34 Release peer and 27 Release interruption checks pass;
38 cargo and 28 refueling regression checks pass. 139-script/startup and Release
export pass. See PUBLIC_RECOVERY.md for scope and evidence. Manual feedback pending.
Recovery tag: public-impact-recovery; verified source backup:
../output/checkpoints/public-impact-recovery-2026-10-26.zip.
Next numbered step: 60 component wear, separate from immediate impact damage.


## Step 60 — Single boat condition and icon HUD — October 26, 2026

User supersedes separate component wear: one condition for collisions and gradual
active use, no machinery degradation. Added unlabeled engine/fuel fill gauges to
the online HUD. Initial wear 1% per active propulsion hour, no offline/docked/paused
or neutral-idle wear; a 10% wear-only floor prevents wear-induced sinking. Lower
condition mildly reduces main propulsion; lifting equipment remains unaffected.
Canonical fractional wear persists with checkpoints/impact receipts. No save reset.
27 authority checks, 10 runtime clock/curve checks, 34 editor and 34 Release real
two-peer recovery checks pass. 141-script/startup check and Release export pass.
Full/half/low icon render and actual Release HUD inspected. See PUBLIC_CONDITION.md.
Local Port Test remains separate; manual player feedback pending.
Checkpoint tag: public-single-condition; source backup:
../output/checkpoints/public-single-condition-2026-10-26.zip.
Next: Step 61 feedback polish should follow the new single-meter design; Step 62
remains paid repairs. Never reintroduce machinery wear or separate wear/damage HUDs.


## Step 61 — Shared condition feedback — October 27, 2026

Corrected the online-only gauge scope. A shared bottom-left opaque icon HUD now
follows the active ship in Port Test, other ShipHelm driving fixtures, local
multiplayer and authenticated online play. It remains visible when dock services
hide the throttle panel. Container/heavy tanks use their actual capacities. Local
Port Test numeric fuel/condition duplicate removed; icons remain unlabeled.
Condition <=25% changes amber to coral; fuel <=15% changes aqua to amber. Thresholds
are configurable presentation values only. UI reads current/restored ship state and
does not mutate statistics, materials, saves or machinery. Optional rust deferred.
Seven real Port Test HUD checks pass across both hulls, including boat switching,
service visibility and read-only thresholds. Rendered both views inspected.
143-script/startup check passes. Hosting/sign-in requirements recorded separately
in WINDOWS_HOSTING_PLAN.md; no public deployment or welcome email implemented.

Release export and exported startup pass. Checkpoint: shared-gameplay-gauges;
verified source backup ../output/checkpoints/shared-gameplay-gauges-2026-10-27.zip.
Next requested follow-up: portable Windows LAN hosting package; Step 62 paid repairs
remains the next numbered gameplay implementation.


## Windows portable hosting preview — October 27, 2026

User requests Windows LAN/internet hosting and a handoff to ChatGPT on the server PC.
Built a relocatable runtime bundle with exported Godot game, Python/cryptography,
PostgreSQL and Keycloak dependencies. No developer-PC account/save/key is included.
Setup creates protected data and two random invited test accounts on the destination.
Host settings select IPv4 bind, advertised hostname, HTTPS/game ports and local IP.
One account issuer/server identity is retained between generated LAN/hostname client
configs; native sign-in still happens through the server list. Bare arbitrary Direct
Connect and public discovery are not implemented. Welcome email remains deferred.

Added a bounded HTTPS front door: only realm login/resources and ticket issuance
are exposed; authority mutations/admin/database stay private. Per-IP/global request
budgets, bounded workers/body sizes/timeouts and temporary provider account lockout
are enabled for hosted previews. No claim of production readiness: Google enrollment,
public trusted-certificate lifecycle, production provider storage, and public abuse/
reset testing remain rollout gates. No firewall/router/DNS/trust changes made here.

27 real packaged-runtime checks passed: native browser PKCE login, DTLS join, drive,
disconnect persistence, full stack restart, route isolation, Host/body rejection,
rate limits ignoring spoofed forwarding headers and clean client logs. Evidence:
../output/host-check/cc33cb55/hosting-summary.json. Eight client export checks passed
in ../output/host-check/export-12dbb636: shared identity, LAN host, portable certificate
paths, matching runtime and no private export. PowerShell syntax checks pass.
Tests ran on this PC via IPv4 loopback; remote LAN/internet are NOT verified.
Initial localhost proof exposed IPv6-first connection failure; preview is explicitly
IPv4/A-record only. A rate-limit response race caused by unread rejected POST bodies
was corrected and the full check passed. Original failed build copied unnecessary
pgAdmin paths; final bundle includes only PostgreSQL runtime bin/lib/share/licenses.

Transfer package: ../output/hosting/ShippingLanes-Windows-Host.zip.
Setup and ChatGPT handoff guides are included. Next deployment work is configuration
on the actual Windows server and the public-access gates; Step 62 repairs unstarted.


## Friends client — October 27, 2026

Requested distributable client with only Servers, Settings and Quit. A portable
friends-client.flag beside the executable selects this menu even on direct launch;
--friends-client supports the launcher. Development menu remains available in the
normal build. Friends navigation excludes local fixtures/save actions and skips
local save status reads. Settings returns to the correct menu. Servers uses the
existing authenticated entry, with portable public internet.json/certificate paths
resolved beside the Client folder (optional --lan uses lan.json). No protocol,
authority, account, gameplay or save format changed.

Added Internet-default double-click launcher and Configure-Friends-Client.ps1.
On the actual host this script copies only its generated public connection files
and creates a sharing ZIP that excludes PlayerData and all host credentials/saves.
Host client exports now include the friends marker/launchers and only the three
required runtime files, excluding transient Godot export .TMP files. Original
already-delivered host ZIP is unchanged and remains compatible.

Validation: 144-script/startup check, Release export, 9 unconfigured and 10 configured
Release menu/config relocation checks; 10 public client export checks; Windows
PowerShell 5.1 configuration/ZIP test excludes a PlayerData sentinel. New client
against original packaged server passed 27 real login/drive/save/restart/gateway
checks in ../output/host-check/af43d27b. Initial sandbox run could not connect to
loopback Postgres; isolated elevated execution passed. Menu logs and packaging
fixture live in ../output/friends-check. All test servers stopped normally.

Delivered template: ../output/hosting/ShippingLanes-Friends-Template.zip (40,109,523
bytes), every ZIP entry hash verified. SHA256:
2494cbea6dc47b20fe8a818936077bd6ea90f35d8419fb1d00b32963d3b784df.
This is NOT preconfigured for Andy's remote host: known LAN IP 192.168.1.17 only;
no confirmed running host, final DuckDNS name or public certificate was supplied.
Use included Configure-Friends-Client.ps1 on server PC to create Friends-Ready.zip.
Actual internet reachability, browser trust and distinct enrolled accounts remain
required before inviting friends. Existing preview has two accounts; no Google or
open signup. Step 62 paid repairs remains unstarted.

## Cloud development environment — November 1, 2026

Prepared a Linux x86_64 headless development baseline without advancing gameplay.
Installed the official Godot 4.7.2 editor outside the repository, verified its
published SHA-512 and exact `4.7.2.stable.official.ed1daf0bf` version/commit, and
kept the existing Windows baseline and export records unchanged. Extended the
pinned, checksum-verified godot-sqlite v4.9 dependency with its unmodified Linux
debug/release libraries and recorded their hashes alongside the existing Windows
DLLs. The dependency remains MIT licensed.

Godot import and all five GLB imports pass. The repository check compiles all 144
GDScripts; Main starts headlessly; Units (50), Catalog and Diagnostics (9) pass.
The isolated SQLite proof passes initialization, WAL/full-sync transactions,
rollback, migration, online backup/restore, two owned-process crash recoveries,
reopen and integrity checks. Logs contain no engine or script errors. Cloud state
uses workspace-local XDG config/cache/data paths because the managed home directory
is read-only.

Windows PowerShell runners, Windows export templates, Windows client/server builds,
rendered visual checks and the PostgreSQL/Keycloak integration stack remain separate
platform gates and were not claimed here. No live saves, accounts, server data,
gameplay logic, protocols or recorded player requirements changed. Step 62 paid
repairs remains the next gameplay step after this environment change is reviewed.

## Step 62 — Paid online repairs (draft) — November 2, 2026

Implemented `repair-service` on `feat/step-62-paid-repairs`, following D115's
single boat condition. Online dock services now offer REPAIR with current condition,
restored percentage and accepted total. Shared per-ship full-scale prices live in
services/public_authority/repair_costs.json; starter tuning is provisionally 250
credits per 100 percentage points. Integer arithmetic rounds the proportional total
up once to minor credits. Full condition does not charge; repair sets condition to
10000 and clears fractional wear, never exceeding maximum. No machinery/component
wear, player transfers, local fixture changes or live save resets.

The trusted server binds and consumes the quote, validates actual dock/service and
peer ownership, settles pending simulated wear/fuel/pose, and buys against that
canonical revision. The backend independently checks condition/price and uses the
existing atomic profile/wallet/treasury/receipt/journal path. Canonical refresh updates
the hull and gauge. Unknown outcomes fence authority without automatic purchase
retry. D119 and PUBLIC_REPAIRS.md record pricing, tests and Andy's acceptance steps.
Game protocol 13 → 14 is required by the new Godot repair RPC table; ticket protocol
remains 7. Matching client/server/backend updates are required. Godot remains 4.7.2;
no existing .gd.uid files changed, and the new probe's UID is retained. The shared
price JSON is explicitly included in export_presets.cfg.

### Linux checks actually run

Used checksum-verified official 4.7.2.stable.official.ed1daf0bf and isolated
workspace XDG state. The system's 4.6.3 executable was not used for project checks.
Evidence logs remain outside the repository at /workspace/work/step62.

- Clean editor/import, all 145 GDScripts, Main startup, catalog, controls, flow,
  starter assets, units, diagnostics (its intentional validation message is expected),
  contracts, geography, session, clocks, handling, camera, water, feedback, world
  size, heavy lifter, fuel, economy, compact snapshots and voyage suite passed.
- All 11 Python repair tests passed with psycopg installed, including strict request
  validation, every damaged integer condition (1–9999), rounding, custom ship cost,
  full/invalid condition, pending wear, loading, stale quote, funds and cargo retention.
- 20 Godot repair checks passed: actual service quote/accept flow and actual panel
  Buy button, expiry, services, dock/loading/funds checks, pending wear settlement,
  consumed quote, full condition and unknown-outcome fencing. Authority is an
  explicit in-memory double: this is not PostgreSQL or authenticated-peer proof.
- SQLite storage, versioned persistence, migration and durable economic recovery
  passed, including owned-process termination at their explicit crash markers,
  reopen/rollback/committed recovery, backup fallback and UI phases. Isolated local
  save-slot checks passed when invoked with the required proof argument.
- Actual local host/client probes passed for network (44 host + 28 client checks),
  cargo network, connected world and actions. Replication passed final host/client
  checks (10 + 14); an earlier host ownership/epoch/bounds/sequence assertion failed
  transiently. The unchanged baseline passed too. No replication code changed;
  retain the earlier failure as timing sensitivity, not an all-green first run.
- Python compilation and git diff whitespace checks passed.

### Known Linux failures and unavailable gates

Collision's lateral-contact assertion and composition's side-course contact
assertions fail on both this branch and an unchanged archive of base 89cc8c7.
They are pre-existing Linux failures; neither probe/physics implementation was
changed. Ports printed PORTS_PASS (261 checks) on the working branch but emitted
out-of-tree transform errors; the baseline also emitted these and failed additional
service assertions. This is not a clean ports gate. Shared-gauge and wear probes
reached their headless assertions (3 and 10 respectively) then timed out waiting
for rendered frame signals; visual completion is unverified. Initial isolated
editor import lacked socket permission; import rerun with network permission passed.
Initial standalone replication/slots invocations lacked required harness arguments;
final results above use the required peers/proof argument and isolated data.

PostgreSQL/HTTPS repair/replay/crash tests are **pending**: the existing fixture stack
requires Windows PostgreSQL binaries/process flags and is not configured here.
Added tools/public_handoff/repair_probe.py for that gate; it was syntax-checked, not
executed. Windows checks/exports, Keycloak/native login, real authenticated two-peer
repair/interruption/reconnect tests, rendered Repair panel/HUD and Andy's playtest
are also pending. No public internet deployment or production acceptance claimed.

Deliver as a DRAFT PR against main, not a main push. Next: run the pending Step 62
acceptance gates on the configured isolated Windows stack and review provisional
pricing; then Step 63 ship catalog and purchase. No secrets, databases, exports,
caches or generated evidence are included in the commit.

## Step 63 — Ship catalog and purchase (draft) — November 2, 2026

Task ID: `ship-catalog-and-purchase`. Based on merged Step 62 main `706e73a`.
Added an online dock catalog with three small earned-credit ships, shared preview
and price data, affordability checks, review/confirm/cancel and stored purchase
feedback. Starter/coastal/swift prices are provisionally 500/900/1,200 credits.
Coastal and Swift have separate stable definitions and reuse starter placeholder
art; see D120 and PUBLIC_SHIP_PURCHASE.md. Fleet comparison, activation/switching,
resale and local-save UX remain later steps.

Purchases create distinct owned records in additive profile.stored_ships, leaving
the active ship ID, cargo and jobs intact. Empty stored fleet needs no migration;
purchases start with full single condition and empty propulsion tanks. The server
binds and consumes quotes, checkpoints live wear/fuel/pose, then commits through
the existing canonical wallet/profile/treasury/receipt/journal transaction. Backend
receipt replay returns the original owned ID and debit only once; mismatched intent
is rejected. Unknown outcomes fence ownership without automatic purchase retry.

Game protocol 14 → 15 for the added RPC; ticket protocol 7 and Godot 4.7.2 remain.
Existing .gd.uid files and saves/IDs are preserved; the new probe has a UID sidecar.
Export presets include catalog JSON and new definitions. No player trades/transfers/
gifts, hidden shallows, cargo expiry, machinery wear or live server changes.

### Linux checks actually run

Exact official `4.7.2.stable.official.ed1daf0bf`, downloaded outside the repository
and verified against published SHA-512. The system's Godot 4.6.3 was not used.
Isolated XDG state and disposable fixture data/logs are under /workspace/work/step63.

- Editor/import and Main startup pass; all 146 GDScripts compile. Catalog, controls,
  flow, starter assets, units (50), diagnostics (9), contracts (66), geography (342),
  session (21), clocks (22), handling (134), camera (20), water (59), feedback (24),
  world size (2,042), heavy lifter (39), fuel (42), economy (82), compact snapshots
  (24) and voyage (101) pass. Diagnostics' intentional validation message is expected.
- 20 Python tests pass: 11 existing repair checks and 9 purchase checks, including
  two distinct owned IDs, definition/instance independence, exact debit, rejection
  cases, strict payloads, production receipt dispatch replay/conflict, failed receipt
  replay, stale revision/recovery and stored-ship preservation during other services.
  The SQL adapter is an explicit double, not actual PostgreSQL.
- 29 real Godot purchase service/panel assertions pass with an explicit authority
  double: preview/definition agreement, port/berth/loading/dock guards, expiry,
  wallet changes/funds, review/confirm/cancel, changed-quote confirmation, pending
  double-click guard, live-state checkpoint, two distinct stored IDs, consumed-quote
  rejection and uncertain-outcome fencing. All 20 repair regression assertions pass.
- SQLite storage, versioned persistence, migrations and durable economic recovery
  pass all 28 harness phases, including ten owned-process kills at explicit crash
  markers, rollback/reopen, committed recovery, backups/fallback and persistence UI.

### Pending platform and acceptance gates

PostgreSQL/HTTPS concurrent replay, restart and atomic crash tests are **not run**:
no PostgreSQL runtime/stack is configured here, and the existing integration harness
uses Windows binaries/process flags. Added tools/public_handoff/ship_purchase_probe.py
for those checks; portable receipt-dispatch tests do not substitute for this gate.
Windows engine checks/exports, Keycloak/native authentication, actual authenticated
peer purchase/interruption/reconnect, rendered catalog/HUD and Andy's playtest remain
**pending**. No public deployment or production acceptance is claimed.

Prior Step 62 Linux collision/composition failures, non-clean ports results and
render-frame-dependent wear/gauge limits remain recorded above; those platform gates
are not closed by this purchase work. No physics or gauge behavior was changed.
Deliver via draft PR against main; no secrets, databases, exports, caches or generated
evidence are included. Step 63 implementation does not advance Steps 64–67.

## Step 64 — Fleet inspection and comparison (draft) — November 2, 2026

Task ID: `fleet-inspection-and-comparison`. Based on merged Step 63 main `9b4648b`;
branch `fleet-inspection-and-comparison`. Only Step 64 implemented. Online dock
services now expose FLEET / COMPARE with two independently selectable catalog/owned
ships, cargo-family comparison and isolated visual previews. The left starts on
the catalog selection and the right on the active owned ship. Names/default names,
class, stable owned ID, ownership/storage, single condition, propulsion fuel,
capacity units, acceleration, turn rate and full-output fuel burn are readable.

Capacity comes from existing cargo IDs/pools: six container slots or one heavy
module slot. DWT and hold count remain explicitly unspecified, not invented from
geometry or tank size. Total capacity is distinguished from remaining space and
propulsion fuel from cargo fuel. Bulk/gas/oil/cargo-fuel capability is not inferred.
Heavy-lifter preview is marked local prototype with no online purchase/jobs.
Purchasable, insufficient funds, full storage, temporarily unavailable and unavailable
prototype states are distinct. Current server quotes supply displayed purchase
prices; existing review/confirm/cancel remains the only purchase path.

Only the authenticated owner's bounded active/stored projection enters docked voyage
snapshots. It excludes accounts, jobs and other private profile fields. Inspection
reads live active condition/fuel and canonical stored values; it never mutates
saves, IDs, definitions, wallets or jobs. Missing stored arrays and definitions are
handled without migration/reset. Preview worlds contain disabled visual scenes,
never runtime ship authority. No new RPC or protocol version: game 15/ticket 7,
Godot 4.7.2 retained. Existing UID sidecars unchanged; all three new scripts retain
UIDs, and new runtime scripts are explicit in exports. D121 and FLEET_INSPECTION.md
record behavior and limits. Switching, resale, renaming and subsequent steps remain
unimplemented. All recorded player constraints remain unchanged.

### Linux checks actually run

Used the existing pinned `4.7.2.stable.official.ed1daf0bf` binary, not system 4.6.3.
All fixture data, dependency installation and evidence are isolated outside the
repository under `/workspace/work/step64`.

- Editor/import and Main startup pass; all 149 GDScripts compile. Initial import
  lacked socket permission; the permitted-network import rerun is clean.
- 32 fleet inspection assertions pass: explicit cargo units, six families,
  compatibility, all acquisition states, server quote price, legacy/unknown content,
  active/stored condition and names, isolated previews, stable selection on refresh,
  owner-field projection, clearing prior entries, read-only state and 101-row bound.
- 35 purchase service/panel checks pass, including real panel opening without a
  purchase, stale/disconnected cleanup, both distinct stored purchases appearing in
  the owner's view and omission outside dock services. All 20 repair checks pass.
  These use explicit in-memory authority doubles, not real PostgreSQL or login.
- Catalog, controls, flow, starter assets, units (50), diagnostics (9), contracts
  (66), geography (342), session (21), clocks (22), handling (134), camera (20), water
  (59), feedback (24), world size (2,042), heavy lifter (39), fuel (42), economy (82),
  compact snapshots (24) and voyage (101) pass. Diagnostics' intentional validation
  message is expected. Save slots pass 38 checks after supplying the required
  32-character proof ID; the initial shorthand proof argument was rejected.
- All 28 SQLite storage/persistence/migration/recovery phases pass, including ten
  owned-process kills at explicit ready markers, transaction rollback/reopen,
  committed recovery, backup fallback and persistence UI.
- Actual local host/client checks pass: network/reconnect and actions, plus both
  normal and impaired replication, cargo-network and connected-world profiles
  (16 successful process results). These are private local networking fixtures,
  not authenticated public-fleet transmission proof.
- All 20 Python repair/purchase tests pass; Python source compilation passes.
  The first run lacked psycopg. The repository's pinned psycopg-binary hash targets
  Windows and rejected the Linux wheel; installed the same version in an isolated
  venv using the Linux wheel hash verified against PyPI metadata, preserving the
  repository's dependency records. No database server was installed or configured.
- Whitespace and existing UID preservation checks pass. No secrets, accounts,
  databases, exports, caches or generated logs are included in the commit.

### Existing Linux limitations reproduced

Collision fails its lateral-contact assertion; composition fails its two side-course
contact assertions. Ports prints 261 checks passed but emits two out-of-tree
transform errors, so it is not a clean gate. Shared-gauge and wear probes reach
3 and 10 headless assertions respectively, then time out waiting for rendered
frames. These match the previously recorded Step 62/63 Linux limitations; no
physics, ports, wear or gauge implementation changed in Step 64.

### Unrun backlog gates — not blockers to this draft implementation

- **Windows:** pinned PowerShell engine checks, Debug/Release client/server exports,
  exported previews/resource inclusion, save/UID compatibility.
- **PostgreSQL:** real HTTPS purchase/replay/concurrency/crash/restart and canonical
  fleet reload. The existing configured Windows database stack is unavailable here.
- **Keycloak/authenticated peers:** native login, two-account fleet privacy,
  disconnect/reconnect/binding replacement and full-fleet snapshot bandwidth.
- **Visual:** rendered preview framing/lighting, long-name/ID layout and scrolling,
  supported resolutions/scaling, keyboard focus and HUD overlap. No display/Xvfb
  runtime is installed; headless node assertions are not visual acceptance.
- **Andy's playtest:** choose a container ship using the comparisons; distinguish
  cargo units/DWT/holds/fuel; recognize unavailable acquisition; inspect two owned
  ships of the same class; close without buying and verify retained state on reconnect.

Deliver via DRAFT PR against main. No live server deployment or completed manual/
production acceptance claimed. Follow-up gameplay remains Step 65, not part of this
branch; backlog acceptance items above stay visible for later tracking.

## Step 65 — Fleet spawn and switching (draft) — November 2, 2026

Task ID: `fleet-spawn-and-switching`. Based on merged Step 64 main `fd2d2c9`;
Steps 62–64 remain merged. Implemented only Step 65 on
`feat/step-65-fleet-spawn-and-switching`. D122 and FLEET_LIFECYCLE.md record the
explicit lifecycle policy, extending Step 54's loaded/job switch refusal.

Fleet / Compare now selects and confirms an owned stored ship at its storage port.
One active ship is exchanged atomically with storage through the existing
lease/revision/receipt/journal path. Checkpoint live fuel, position, condition and
fractional wear before exchange; preserve complete owned records and stable IDs.
No active job/cargo can switch, transfer or disappear. Damaged afloat ships can
be stored without healing; pending impacts and sunk/recovering ships block it.
Unknown commits fence authority without automatic retry; departure waits for the
canonical replacement before checkpointing, preventing an old-hull overwrite.

New purchases use authored service-berth slots with retained berth ownership, so
empty tanks can receive paid fuel. Previously used ships return to their exact
saved latitude/longitude/heading without a fallback teleport. Clearance includes
visible solids, other hull envelopes and in-flight reservations. After commit,
the incoming hull remains inert until a two-frame clearance recheck permits it.
Peer binding changes clear old owner views and set a server snapshot floor.

Runtime initialization now installs the active catalog definition before creating
the hull. The three existing purchasable classes participate in admission, cargo,
paid refueling and paid repairs; the two additional classes provisionally use the
same 250-credit full-scale repair price. Their handling/fuel differences remain.
No resale, accounting, heavy-loader online activation or other later-step work.

Game protocol 15 → 16 for the fleet RPC/binding update; ticket protocol remains 7.
Godot remains 4.7.2. Save version/IDs and existing .gd.uid files are unchanged;
new service/probe UIDs are retained and the shared slot JSON is explicitly exported.
Single condition, one nonexpiring job, no player transfers, no hidden shallows and
no machinery wear remain intact. No live saves or dedicated server were changed.

### Linux checks actually run

Exact existing `4.7.2.stable.official.ed1daf0bf`, with isolated XDG fixture state
and evidence under `/workspace/work/step65`, outside the repository. Python uses
an isolated venv with psycopg/psycopg-binary 3.2.10 for Linux, not a database server.

- Final import/editor, all 151 GDScripts and Main startup pass without script errors.
- 34 fleet bridge/hull/clearance/UI assertions pass: cargo/loading/damage/dock/port
  guards, unowned IDs, both authored slots, reservations and an actual blocking hull,
  unchanged state on failed placement, exact saved transform with no fallback,
  class installation, empty tank, retained condition/fractional wear/live fuel,
  damaged roundtrip, berth retention, inert placement, uncertain-result fencing,
  stable-ID review/confirmation and cancellation when cargo arrives.
- Public shared physics passes all 43 assertions. Two older physics/wear fixtures
  omitted the class definition under the former starter-only runtime; they now
  supply the explicit starter definition required by class-aware initialization.
  The initial wear run exposed this fixture omission; the corrected run passes
  all ten headless assertions before its existing rendered-frame wait.
- All 28 Python tests pass (8 fleet, 9 purchase, 11 repair). Fleet tests exercise
  exact roundtrips, unknown unfinished jobs, duplicate IDs, sunk/unknown targets,
  strict payloads, stored-pose protection, production receipt dispatch replay and
  conflicts, stale revision and pending recovery. Authority/SQL are explicit doubles,
  not evidence of real PostgreSQL transactions or authenticated peers.
- Fleet inspection (32), purchase (35), repair (20), catalog, controls, flow, starter
  assets, units (50), diagnostics (9), contracts (66), geography (342), session (21),
  clocks (22), handling (134), camera (20), water (59), feedback (24), world size
  (2,042), heavy lifter (39), fuel (42), economy (82), compact snapshots (24), voyage
  (101) and isolated save slots (38) pass. Diagnostics' intentional error is expected.
- All 28 SQLite storage/persistence/migration/durable recovery phases pass, including
  ten owned-process kills at explicit ready markers, rollback, committed recovery,
  backup fallback and persistence UI. Initial harness absolute paths were correctly
  rejected; rerun with the required user:// proof paths passed. Persistence UI first
  shared the slots test's disposable XDG state; a fresh isolated UI run passes all
  eight assertions. No gameplay saves were reset to fix tests.
- Actual local host/client checks pass for network/reconnect and actions, plus normal
  and impaired replication, cargo-network and connected-world (16 process results).
  These are private networking regressions, not public fleet/authentication proof.
- Python source compilation, whitespace and existing UID preservation checks pass.
  Final targeted service/UI regressions were rerun after the last runtime changes.

### Reproduced Linux limits and unavailable acceptance gates

Collision fails lateral contact; composition fails its two side-course contacts.
Ports reports 261 checks passed but emits two out-of-tree transform errors and is
not a clean gate. Shared gauges and wear reach 3 and 10 assertions then time out
waiting for rendered frames. These match the previously documented Linux limits.
The first sweep also attempted the new fleet probe before its file was written;
its final completed 34-check run passes. No initial-failure evidence is hidden.

- **Windows:** PowerShell pinned-engine checks, Debug/Release client/server exports,
  exported slot resource inclusion and save/UID compatibility remain unrun here.
- **PostgreSQL/HTTPS:** real switch replay/concurrency, before/after-commit crash,
  restart, canonical fleet reload and atomicity remain unrun; the configured database
  stack and Windows integration runtime are unavailable in this environment.
- **Keycloak/authenticated peers:** native login, two-account ownership/privacy,
  in-flight disconnect/rebind, restart/reconnect, delayed A→B→A frames and contention
  with another authenticated hull remain unrun; no identity stack is configured.
- **Visual/Andy's playtest:** fleet confirmation/layout/focus/scaling, class handling,
  empty-tank refueling at the retained berth, occupied-spawn waiting, damaged roundtrip
  and HUD/camera/replica behavior require rendered testing. No display/Xvfb or manual
  playtest was used. No deployment or public internet acceptance is claimed.

Deliver as a DRAFT PR against main. No secrets, accounts, databases, exports,
caches or generated evidence are included in the commit. Step 66 remains unstarted.
