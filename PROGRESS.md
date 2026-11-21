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
This is NOT preconfigured for Andy's remote host: known LAN IP SERVER_LAN_IP only;
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

## Step 66 — Resale and voyage accounting (draft) — November 2, 2026

Task ID: `resale-and-voyage-accounting`. Based on merged Step 65 main `f56de62`;
Steps 62–65 remain merged. Implemented ONLY Step 66 on
`feat/step-66-resale-and-voyage-accounting`. D123 and PUBLIC_RESALE_ACCOUNTING.md
record the lifecycle, provisional configurable valuation and cash reporting boundary.

Fleet / Compare now reviews/confirms/cancels sale of an empty stored ship at its
storage port. The active/last ship cannot be sold; cargo and any unfinished job
(including unknown states) block sale. Nested target cargo/jobs, pending damage,
recovery, stale quotes and concurrent service work are refused. Retain a supported
afloat active ship with fuel or enough post-sale money for at least 1 L. No orphan
manifests, automatic cancellation, player transfers, replacement ship or free fuel.

Shared per-definition valuation defaults to 60% of the lower of actual acquisition
cost/current catalog price, scaled by stored single condition and floored once.
New purchases retain their cost; legacy ships use catalog fallback without save
rewrites. Fuel is not reimbursed. Existing debt repayment applies to proceeds;
receipts show gross resale, debt repaid, actual wallet credit and before/after funds.
The trusted server consumes quotes, checkpoints live pose/fuel/wear, and commits
through the existing canonical revision/lease/profile/wallet/treasury/receipt/journal
transaction. Replay returns the original result; unknown outcomes fence authority.

Voyage cash reports start at acceptance and close at delivery/cancel/abandon/sinking.
They separate gross revenue, acquisition purchases, fuel, repair, recovery paid/debt
repaid, other cash and net cash. Net must equal ending minus starting wallet or the
transaction aborts. Failed/replayed operations add nothing. Current and last closed
reports persist in additive profile fields and settlement receipts. Existing active
voyages start a clearly marked partial window. The UI explicitly excludes prepaid
fuel/ships and future repairs: this is cash reporting, never gross revenue labeled
as profit. No Step 67 progression tuning or deferred local-save/visual work.

Game protocol 16 → 17 for the resale RPC; ticket protocol 7 and Godot 4.7.2 remain.
Existing save version, owned IDs and .gd.uid files are preserved; the new probe UID
is retained. Export includes shared resale valuation JSON. Single condition, one
nonexpiring job, no machinery wear, no hidden shallows and no player trades/gifts/
transfers remain intact. No live saves, accounts or dedicated server were changed.

### Linux checks actually run

Used existing `4.7.2.stable.official.ed1daf0bf`, not the system engine, with isolated
XDG state and disposable evidence under `/workspace/work/step66`, outside Git.

- Final editor/import, all 152 GDScripts and Main startup pass. New UID generated
  through editor import; existing UID preservation and git whitespace checks pass.
- All 39 Python tests pass: 11 resale/accounting, 8 fleet, 9 purchase, 11 repair.
  New coverage includes exact debt-adjusted sale/replay/conflict receipts, loaded/
  unknown-job/last-ship/port/duplicate-ID refusal, fuel-poor account protection,
  configurable valuation and every integer condition 1–10000, legacy valuation,
  treasury/stale/strict payload failures, acquisition/fuel/repair/delivery cash
  reconciliation, replayed delivery, cancellation/sinking, partial legacy/restart
  retention, failed charges and deliberate ledger-mismatch rejection. Tests use
  the production dispatch with an explicit SQL double, not real PostgreSQL.
- All 26 Godot resale assertions pass against actual quote/service/panel code with
  an explicit authority double: guards, expiry/condition changes, review/cancel/
  confirm, duplicate click, revenue/net wording, checkpoint/reload, stable active
  ID, wallet credit, retained wear, removed stored ID and unknown-outcome fencing.
  Fleet switch (34), inspection (32), purchase (35) and repair (20) regressions pass.
- Catalog, controls, flow, starter assets, units (50), diagnostics (9), contracts
  (66), geography (342), session (21), clocks (22), handling (134), camera (20), water
  (59), feedback (24), world size (2,042), heavy lifter (39), fuel (42), economy (82),
  compact snapshots (24), voyage (101), public shared physics (43) and isolated save
  slots (38) pass. Diagnostics' intentional validation error remains expected.
- All 28 SQLite storage/persistence/migration/durable recovery phases pass, including
  ten owned-process terminations at explicit ready markers, rollback/reopen,
  committed recovery, backup fallback and isolated persistence UI.
- Actual local host/client network/reconnect and actions pass, plus normal/impaired
  replication, cargo-network and connected-world profiles: 16 clean process results.
  These private fixtures do not substitute for authenticated public resale tests.
- Python source compilation passes. The initial Python run lacked psycopg; installed
  psycopg/psycopg-binary 3.2.10 in the isolated evidence venv, then all tests passed.
  Initial Godot import and Git fetch lacked network/socket access; permitted-network
  reruns passed. No runtime dependency records or engine baseline were changed.

### Reproduced Linux limits and unrun acceptance gates

Collision fails its existing lateral-contact assertion; composition fails two
side-course assertions. Ports reports 261 checks passed but emits two out-of-tree
transform errors, so it is not a clean gate. Shared gauges and wear reach 3 and 10
headless assertions then time out waiting for rendered frames. These match the
previous Step 62–65 records; no related physics/ports/gauge implementation changed.

- **Windows:** pinned PowerShell engine check, Debug/Release client/server exports,
  exported valuation resource inclusion and save/UID compatibility remain unrun.
- **PostgreSQL/HTTPS:** real sale/delivery concurrency, replay, before/after-commit
  crash, restart, canonical reload and transaction atomicity remain unrun. No
  PostgreSQL server/client or configured Windows integration stack is available.
- **Keycloak/authenticated peers:** native sign-in, two-account ownership/privacy,
  interrupted sale/disconnect/rebind, reconnect/server restart and matching protocol
  17 deployment remain unrun; no configured identity stack is available.
- **Visual/Andy's playtest:** rendered review/confirm/cancel, receipt layout/scrolling,
  focus/scaling, loaded/damaged restrictions and fuel-poor account scenarios remain
  unrun. No display/Xvfb or manual playtest; headless UI checks are not visual proof.

Deliver as a DRAFT PR against main. No deployment, manual/production acceptance,
Step 67 completion, or cleanup/reset of live data is claimed. No secrets, databases,
exports, caches or generated evidence are included in the commit.

## Step 67 — Economy gate (draft) — November 2, 2026

Task ID: `economy-gate`. Started from merged Step 66 main `5fd2739`; Steps 62–66
remain merged. Implemented ONLY Step 67 on `feat/step-67-economy-gate`. D124 and
ECONOMY_GATE.md record the target, measured costs, method, tuning and pending gates.

First useful upgrade means purchased, activated and fueled with 250 L, retaining
the starter. Target 10–15 minutes with a large first contract; 25–35 minutes with
smaller contracts or one halfway sinking. Tune only Coastal catalog cost 900 →
800 credits. Existing class properties, alternatives, rewards, fees and starting
funds/fuel remain. At 900, the largest first reward could buy the hull but could
not fund the benchmark's next-voyage fuel reserve; same-policy baseline required
two deliveries / 20.29 minutes. At 800 it takes one / 9.12 simulated minutes,
with 46.15 credits after purchase/fuel. No imported research-price table.

Added fixed-step Godot production handling/fuel route benchmark and Python
production authority progression scenarios using an explicit SQL double. Starter
outbound/return measured 530.18/653.22 s and 163.58/214.42 L; Coastal uses about
19.4% less fuel on the same routes. Smaller contracts reach the fueled upgrade in
28.99 minutes (three deliveries); halfway sinking/retry in 26.96 (two deliveries
plus failed half-voyage and 120 s assumed recovery approach). Costs include all
consumed fuel replacement, wear repair, 250 recovery credits including debt repayment,
800 acquisition and 62.50 upgrade fuel. Wallets reconcile exactly. These simulated
route/controller measurements exclude collision/docking admission, UI time and
network service latency; they are not manual/authenticated playtest evidence.

Every request replays without further writes; each scenario also runs with serialized
profile/receipt/journal reload and a fresh Authority after each operation/checkpoint.
Added 24 purchase/resale cycles over all classes, 150,000 valuation cases, repeated
cancel/deliver/recovery, conflicting intent and finite-offer exhaustion checks.
All tested resale cycles lose money; consumed ships/jobs cannot pay again after
reload. Recovery preserves ownership and adds charges/debt on each incident. No
unlimited-money loop found in the tested surface; real SQL race/crash gates remain.

Acquisition records, saves/IDs, existing .gd.uid files, Godot 4.7.2, game protocol
17 and ticket 7 preserved. New probe UID retained. Shared catalog JSON was already
explicitly exported; no new runtime resources require export changes. Prior
900-credit acquisitions are not rewritten; current-price resale cap now gives
480 maximum Coastal resale. Single condition, one active nonexpiring cargo job,
no machinery wear, hidden shallows or player trades/transfers/gifts remain intact.
No live service, account or save was used or changed; no deferred request implemented.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf` downloaded into isolated
`/workspace/work/step67`; the installed 4.6.3 engine was not used. All generated
logs, metrics, virtualenv and isolated XDG/SQLite evidence remain outside Git.

- Editor/import, all 153 GDScripts and Main startup pass. Initial sandbox import
  lacked socket access; the rerun with permitted local sockets and isolated XDG
  configuration passes. Initial route probe had a typed-array assignment error;
  corrected before measurement. Final two route runs are byte-identical, as are
  their complete progression reports (including pre-tuning price comparison).
- All **45 Python tests** pass (existing 39 plus six economy-gate cases). Three
  progression scenarios pass both normally and with serialized reload after every
  operation/checkpoint; every request is replayed. SQL/clock/lease/docking are
  explicit test boundaries, not real PostgreSQL proof.
- Resale (26), purchase (35), fleet switching (34), inspection (32), repair (20)
  pass. Initial purchase/resale UI tests retained old literal prices/wallets;
  updated expectations to 800/240 and reran both cleanly. The legacy 900-credit
  acquisition fixture remains, proving the new current-price resale cap.
- Catalog, controls, flow, starter assets, units (50), diagnostics (9), contracts
  (66), geography (342), session (21), clocks (22), handling (134), camera (20),
  water (59), feedback (24), world size (2,042), heavy lifter (39), fuel (42),
  economy (82), compact snapshots (24), voyage (101), public shared physics (43)
  and isolated save slots (38) pass. Diagnostics' intentional validation error is
  expected. No prior-step physics or persistence implementation changed.
- All **28 SQLite storage/persistence/migration/durable recovery phases** pass,
  including ten owned-process kills at explicit ready markers, rollback/reopen,
  committed recovery, backup fallback and persistence UI.
- Actual local host/client network/reconnect and actions pass, plus normal/impaired
  replication, cargo-network and connected-world: **16 clean process results**.
  Private networking fixtures do not substitute for public authenticated evidence.
- Python AST compilation (63 sources), whitespace and existing UID preservation
  checks pass. No secrets, accounts, databases, exports, caches or generated
  evidence are included in the commit.

### Reproduced Linux limits and unrun acceptance gates

Collision fails lateral contact; composition fails its two side-course contacts.
Ports reports 261 checks but emits two out-of-tree transform errors. Shared gauges
and wear reach 3 and 10 passing assertions then time out awaiting rendered frames.
These reproduce the Step 62–66 limits and are not clean passes.

- **Windows:** PowerShell pinned-engine checks, Debug/Release client/server exports,
  exported prices/UI/resources and save/UID compatibility remain unrun.
- **PostgreSQL/HTTPS:** real transaction concurrency, replay, before/after-commit
  crashes, canonical checkpoint/reload and server restart remain unrun; no DB
  server/client or configured integration stack is available.
- **Keycloak/authenticated peers:** native sign-in, two-account privacy/ownership,
  fencing, disconnect/rebind/reconnect and restart progression remain unrun. Java
  is present but no configured identity stack or accounts were used.
- **Visual/Andy playtest:** actual collision-safe voyages and docking, recovery
  placement, contract choice/discoverability, price/confirmation/refueling UI,
  focus/scaling and class feel; confirm the recorded 10–15/25–35 minute targets.
  No display/Xvfb or manual playtest. The 120 s recovery approach is an assumption.

Deliver as a DRAFT PR against main. No live deployment, production gate completion
or manual acceptance claimed. Step 68 and the deferred local-save UX remain out
of scope.

## Step 68 — Bulk capacity model (draft) — November 2, 2026

Task ID: `bulk-capacity-model`. Started from merged Step 67 main `629820b` on
`feat/step-68-bulk-capacity-model`. Implemented ONLY Step 68. D125 and
BULK_CAPACITY.md record quantities, compatibility, mixing and scope.

Added grain, coal, ore and limestone catalog resources using integer grams.
Ships can author stable bulk holds with individual gram limits and commodity
allowlists. The explicit single-commodity-per-hold policy allows same-commodity
batches to share a hold and different commodities in separate holds. Bulk batches
must identify their hold; overfill, invalid quantities/units/holds, incompatible
commodities and mixing fail atomically. An emptied hold releases its assignment.
Per-hold and aggregate usage retain separate units from container slot counts.

A data-only two-hold fixture carries 400 t forward and 600 t aft, supporting all
sixteen ordered commodity pairs. Its independently authored DWT is 1,500 t;
DWT is metadata, not capacity or a derived hold count. No existing ship gains
bulk support. The fixture is not added to the playable/purchasable fleet catalog.
Existing container batch shape, six-slot capacity and other pool checks remain.
All five new data resources are explicitly included in export_presets.cfg.

Godot remains 4.7.2; game protocol 17, ticket 7, save versions, existing stable IDs
and existing .gd.uid files are preserved. The new probe UID is retained. No bulk
income, port loading/delivery UI, online acquisition, bulk persistence/reconnect,
partial-discharge settlement or Step 69–70 work. No deferred requests, live saves,
accounts or dedicated service deployment were changed.

### Linux checks actually run

Pinned `4.7.2.stable.official.ed1daf0bf`, with isolated XDG fixtures, logs and
virtualenv under `/workspace/work/step68`, outside Git. Installed psycopg/binary
3.2.10 in that venv; no PostgreSQL service was installed or contacted.

- Editor/import, 154-script parse/load check and Main startup pass. Initial import
  lacked local socket access and a created XDG config directory; rerun with local
  network permission and explicit isolated directories passes without errors.
- All **102 bulk assertions** pass: every two-hold commodity pairing at exact
  capacity, one-gram overfill, same-commodity batching, empty-hold reuse, forbidden
  mixing, hold-specific compatibility, invalid/unknown inputs and policy, DWT/hold
  independence, mixed container/bulk budgets, copy isolation and catalog rejection.
- Catalog, controls, flow, starter assets; units (50), diagnostics (9), contracts
  (66), geography (342), session (21), clocks (22), handling (134), camera (20),
  water (59), feedback (24), world size (2,042), heavy lifter (39), fuel (42),
  economy (82), compact network (24), voyage (101), public physics (43), slots (38),
  repair (20), purchase (35), fleet inspection (32), fleet switching (34), resale
  (26) and the Step 67 route benchmark pass.
- Ports passes **261 checks cleanly** in this run. The initial sweep exposed an
  overly broad new manifest call to handling validation, affecting the existing
  mixed container/liquid fixture. Separated bulk-definition validation from handling
  and reran ports, bulk, catalog and all scripts successfully. Previously recorded
  ports transform warnings did not reproduce in the final run.
- All **45 Python tests** pass. Step 67's three progression scenarios pass with
  per-request replay and serialized reload equivalence using this run's route
  measurements. These use SQL doubles, not a database transaction proof.
- All **28 SQLite phases** pass: storage, persistence, migration and durable action
  recovery, including ten owned-process kills at explicit ready markers, rollback,
  committed recovery, backup fallback and persistence UI. Sailing save passes 330
  checkpoints with one retained cargo batch.
- Local host/client reconnect/actions and normal/impaired replication, cargo-network
  and connected-world profiles pass: **16 clean process results**. Private local
  networking does not establish public authenticated compatibility.
- Network-capacity fixtures ran dispersed and crowded layouts at 2, 10, 25, 50
  and 100 clients: 29 of 30 process results pass. The 25-client dispersed observer
  fails `Observer has no unbounded motion jump`; its server/bots and all other
  cases pass. This is an additional observed Linux limitation, not a clean capacity
  gate or a measured production capacity claim. No network implementation changed.
- Friends-client menu/configuration passes with `--friends-client`. An initial
  invocation omitted that required mode and tested the developer menu instead;
  its failures/time-out are retained in scratch evidence, not counted as a pass.
- Python AST compilation of 63 sources, whitespace and existing UID preservation
  checks pass. No generated evidence, caches, exports or databases are committed.

### Linux limits and unrun acceptance gates

Collision fails lateral contact; composition fails its two side-course contacts.
Shared gauges and wear pass 3 and 10 headless assertions respectively, then time out
waiting for rendered frames. These reproduce previously recorded limits. The first
sweep invoked gauge/wear flags not routed by Main; those idle timeouts are not test
results. The explicit probe scene runs above establish the assertion counts.

- **Windows:** pinned PowerShell suite, native identity/integration runners,
  Debug/Release client/server exports, new resource inclusion and save/UID compatibility.
- **PostgreSQL/HTTPS:** actual transaction concurrency/replay, before/after-commit
  crash recovery, canonical checkpoint/reload and server restart. No DB client/server
  or configured integration stack is available.
- **Keycloak/authenticated peers:** native sign-in, two-account isolation, fencing,
  disconnect/rebind/reconnect and restart progression. Java is present; no configured
  identity stack or accounts were used.
- **Visual/Andy playtest:** rendered client/ship/UI regression, focus/scaling,
  navigation/docking and retained Step 67 progression targets. No display/Xvfb or
  manual playtest was used. This capacity step introduces no new playable bulk UI.

Deliver as a DRAFT PR against main. No deployment or completed manual/production
acceptance claimed. Step 69 and deferred player requests remain unstarted.

## Step 69 — Bulk earnings (draft) — November 3, 2026

Task ID: `bulk-earnings`. Based on merged Step 68 main `5042661`, on
`feat/step-69-bulk-earnings`. The resumed environment initially contained only
Step 65 (`f56de62`) and no Step 69 edits/evidence. Fetched current main and
implemented ONLY Step 69; did not claim to recover nonexistent previous checks.
D126 and BULK_EARNINGS.md define the quote, quantity, partial and rounding rules.

Added a bulk authority model extending the container offer registry and its
one-active-job guard. It publishes nonexpiring quotes, accepts capacity-checked
jobs, loads actual bulk manifests at the origin and discharges at the recorded
destination. Frozen geographic direct distance, commodity rate and both configured
port modifiers determine gross earnings. Sailing detours/time and later content
changes cannot raise payout. Quote text includes every earnings modifier and
explicitly distinguishes fuel/repair/recovery costs from the gross quote.

Partial discharge pays floor(cumulative exact earnings) less prior payments;
integer quotient/remainder arithmetic avoids intermediate overflow/rounding.
Fragments retain provenance and the active job until final discharge; retries
return the original receipt and zero new reward delta. Reject wrong owner/ship/
port, undocked operations, malformed quantities, over-discharge, cargo mismatch,
capacity failures and conflicting request IDs. Guard manifest signal reentry.
The executable example quotes 122.22 credits for 123.456789 t over 1 NM at
1 credit/t/NM with 1.10/0.90 modifiers, then pays 49.50 + 72.72 = 122.22.

Scope is the in-memory bulk authority/settlement model and quote/receipt formatters
using Step 68's data-only hull. Existing playable ships remain unchanged. No bulk
panel, acquisition, public RPC/PostgreSQL wallet or durable bulk snapshot adapter
is claimed; service presentation and crash/restart recovery remain Step 70. This
is not an end-to-end authenticated bulk gameplay implementation. Existing container
acceptance/loading/reward paths are regression-tested through the shared model.

Godot stays at 4.7.2, game protocol 17 and ticket 7. Save versions, owned/content
IDs and all existing .gd.uid files are preserved; two new UID sidecars are retained.
The new runtime service is explicitly exported. Single condition, one active
nonexpiring cargo job, no player trades/transfers/gifts, no hidden shallows and
no machinery wear remain intact. No deferred player requests were implemented.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf` from the existing pinned tool directory.
All generated logs, isolated XDG/SQLite data, virtualenv and metrics are under
`/workspace/work/step69`, outside Git. No live accounts or saves were used/reset.

- Final bulk probe: **330 passing assertions**, including the worked receipt,
  million-metre detour comparison, full/partial delivery, 101 fragments, frozen
  terms, replay/conflict, zero modifier, all four commodities, malformed requests,
  capacity/provenance/ownership guards, container compatibility and signal reentry.
  Includes **257 independently calculated exact Python-integer pricing vectors**.
- Step 68 bulk capacity: **102 assertions** pass. Final **156-script** parse/load,
  Main startup and editor/import pass. Initial editor invocation lacked a created
  XDG config directory and logged settings-save errors; isolated rerun is clean.
- Catalog, controls, flow, starter assets, units, diagnostics, contracts, geography,
  session, clocks, handling, camera, water, feedback, world size, heavy lifter, fuel,
  economy, compact snapshots, voyage, public shared physics, repair, purchase,
  fleet inspection/switching and resale probes pass. Diagnostics intentionally
  emits its validation error. Ports passes **261** clean checks. Sailing-save
  passes **330 checkpoints** retaining one cargo batch.
- All **45 Python tests** pass with psycopg/binary 3.2.10 installed in an isolated
  venv. The production route benchmark and all three Step 67 progression scenarios
  pass with per-request replay and serialized reload equivalence. These remain
  explicit SQL doubles, not PostgreSQL transaction evidence.
- All **28 SQLite phases** pass in the final fresh `verified-*` fixture run,
  including **ten owned-process kills** at ready markers, rollback, committed
  recovery, backup fallback and persistence UI. Slots and friends-client checks
  pass. Initial harness attempts used an invalid short fixture ID and an incorrect
  friends-menu flag; these failures are not passes. An overlapping corrected
  harness also shared log/marker paths with the initial sweep; discarded that
  evidence and reran the whole persistence suite in fresh isolated namespaces.
- Local host/client reconnect and actions, impaired replication, normal/impaired
  cargo-network and connected-world pass. Normal replication passes its client
  but fails the host assertion requiring six rejected invalid requests, both in
  the full sweep and an isolated rerun: **15/16** process results pass. A separate
  archived checkout of merged Step 68 passes both processes for this case. The
  difference is unresolved, not labeled a proven pre-existing failure or hidden
  by the passing baseline. Its baseline editor import logged settings-save errors;
  the two runtime process results themselves are clean.
- Network capacity: **30/30** process results pass across 2/10/25/50/100 clients,
  dispersed and crowded layouts. These are local headless fixtures, not an
  authenticated production capacity guarantee.
- Python AST compilation (**63 sources**), existing UID preservation and whitespace
  checks pass. Final bulk/capacity/script/startup checks were repeated after the
  last service changes. No generated evidence, caches or databases are committed.

### Linux limits and unrun acceptance gates

Collision fails its existing lateral-contact assertion; composition fails two
side-course contacts. Shared gauges and wear pass 3 and 10 assertions respectively,
then time out awaiting rendered frames. These reproduce prior recorded Linux
limits; no physics/gauge/wear implementation changed. Normal replication also
fails its host request-rejection-count assertion as recorded above; no networking
implementation changed in this branch.

- **Windows:** pinned PowerShell checks, native integration runners, Debug/Release
  client/server exports, exported service/resource loading and save/UID compatibility.
- **PostgreSQL/HTTPS:** real transaction concurrency/replay, before/after-commit
  crashes, atomic cargo/wallet/receipt settlement, canonical reload and restart.
  No DB server/client or configured integration stack is available; the new bulk
  model does not yet have the Step 70 durable adapter.
- **Keycloak/authenticated peers:** native sign-in, two-account isolation/ownership,
  fencing, disconnect/rebind/reconnect and restart. Java exists, but no configured
  identity stack/accounts or new bulk public endpoint are present.
- **Visual/Andy playtest:** rendered quote/receipt layout, focus/scaling, docking,
  bulk loading/discharge interaction and unchanged ship/HUD behavior. No display,
  Xvfb or manual playtest; Step 70's bulk panel is intentionally not implemented.

Deliver via DRAFT PR against main. No deployment, real SQL durability, manual
acceptance or Step 70 completion claimed. No secrets, accounts, databases, exports
or caches belong in this commit.

## Step 70 — Bulk service presentation and recovery (draft) — November 3, 2026

Task ID: `bulk-service-presentation-and-recovery`. Started from merged Step 69
main `4ea9b72` on `feat/step-70-bulk-service-presentation-and-recovery`. Implemented
ONLY Step 70. D127 and BULK_SERVICE_RECOVERY.md document the lifecycle and scope.

Added developer-menu Bulk Port Test with explicit commodity/hold selection,
all-in gross quote, positive integer-gram partial discharge, receipts and a
read-only crane/progress presentation. Both loading and unloading use the existing
shared timed operation service. The separate private fixture reuses starter
presentation/handling with the authored bulk holds and copied bulk-compatible
berths; existing playable/public catalog ships do not gain bulk capacity.

The bulk adapter stages changes and commits frozen acquisition origin/destination,
quote inputs, hold allocation, cumulative discharge, receipts, wallet and operation
state together through the existing SQLite store before publishing success. Restore
validates bounded object-free history against reconstructed manifest/wallet/terminal
operations. Pending service resumes from its durable progress without offline time;
partial voyages retain pose, fuel and single condition and restart in neutral.
Cancel/berth loss stops unfinished work only. Stale/failed/unknown commits fence the
fixture until reopen, preserving the database. Crane drawing has no economic or
clock callback. Repeated operation completion/receipt replay cannot award twice.

The store gains optional codec callbacks with unchanged container/heavy defaults.
Bulk uses a separate private realm/version 1; no prior save migration or reset.
Godot remains **4.7.2**, game protocol **17**, ticket **7**, existing IDs and all
**156 existing .gd.uid files** are unchanged. Four new script UIDs are retained;
new runtime resources are explicitly exported. Single condition, one nonexpiring
active job, no player transfers/trades/gifts, no machinery wear and no hidden
shallows remain. No Step 71, deferred request, live deployment or live-save change.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf`, downloaded into isolated
`/workspace/work/step70`. Logs, engine, virtualenv, XDG fixtures and databases remain
outside Git. Installed 4.6.3 was not used for project checks.

- Bulk service suite: **65 assertions**; actual bulk panel/scene: **16 assertions**.
  Covers every commodity/hold pair, duplicate acceptance/completion, cumulative
  payout, malformed snapshots, frozen terms, hold mismatch, partial cancellation,
  stale writer fencing and 100 artificial visual-progress updates against an
  unfinished operation without changing cargo/wallet/authority progress.
- Portable `tools/check_bulk_service.py` passes all **15 process phases**, including
  **four owned-process kills** at before/after load and unload COMMIT markers.
  Reopen verifies rollback/committed recovery, lost-reply zero-delta receipt replay,
  partial and final settlement, and repeated final reopen. Actual scene checks
  verify destination partial discharge, hidden panel, berth loss, then restart at
  saved sailing position/fuel with remaining hold cargo and prior wallet intact.
- Bulk earnings **330** and capacity **102** assertions pass. All **160 scripts**
  parse/load; Main and editor/import pass. Initial imports lacked a writable cache
  directory and emitted settings/cache errors; rerun with isolated XDG data/config/
  cache is clean. Initial new probe parse issues and inherited container layout on
  the bulk fixture were corrected before the passing runs.
- Catalog, controls, application flow, starter assets, units, diagnostics, contracts,
  geography, session/clocks, handling, camera, water/feedback, world size, heavy
  lifter, fuel, economy, compact snapshots, public physics, repair, purchase,
  inspection/switching/resale pass. Diagnostics emits its intentional validation
  error. Ports passes **261**, voyage **101**, and sailing-save **330 checkpoints**.
  Slots and friends-client menu/configuration also pass.
- All **28 existing SQLite storage/persistence/migration/durable-recovery phases**
  pass, including **ten owned-process kills**, rollback/reopen, backup fallback and
  persistence UI. Existing voyage additionally passes nine ordered recovery phases
  with four intentional self-kills around loading/delivery commits. The scratch
  classifier initially labeled those four signal exits failures; verified each
  exact ready marker, signal exit, error-free log and subsequent recovered state.
- All **45 Python tests** pass with isolated psycopg/binary 3.2.10. Production route
  benchmark and all three Step 67 progression scenarios pass with request replay
  and serialized reload equivalence. SQL doubles are not PostgreSQL evidence.
- Local host/client reconnect/actions and normal/impaired replication, cargo-network
  and connected-world pass: **16/16 process results**. Step 69's normal replication
  rejection-count failure did not reproduce in this run.
- Python AST compilation (**64 sources**), whitespace, existing UID byte comparison
  and presence of all script sidecars pass. No secrets, accounts, databases,
  exports, caches or generated evidence are included in the commit.

### Linux limits and unrun acceptance gates

Collision fails lateral contact; composition fails its two side-course contacts.
Shared gauges and wear reach 3 and 10 passing assertions then time out waiting for
rendered frames. These reproduce the previously recorded Linux limits and are not
clean passes. Capacity fixtures cover 2/10/25/50/100 clients, dispersed and crowded:
**27/30 process results** pass. Observers fail `Observer has no unbounded motion
jump` for 10 dispersed, 25 dispersed and 25 crowded; all server/bot processes and
other observers pass. These are recorded failures, not a production capacity claim;
no networking implementation changed.

- **Windows:** pinned PowerShell check suite, native identity/integration runners,
  Debug/Release client/server exports, exported bulk scene/resource inclusion,
  Windows execution of the portable recovery probe and save/UID compatibility.
- **PostgreSQL/HTTPS:** real bulk cargo/wallet/receipt transaction concurrency,
  replay, before/after-commit crashes, canonical checkpoint/reload and server
  restart. No DB client/server or configured stack is present. Bulk public RPC/
  PostgreSQL wallet integration is not implemented by this private fixture;
  SQLite proof does not close that boundary.
- **Keycloak/authenticated peers:** native sign-in, two-account isolation/ownership,
  lease fencing, disconnect/rebind/reconnect, server handoff and authenticated
  partial-voyage restart. Java exists; no configured Keycloak stack/accounts or
  public bulk endpoint is present. No remote internet deployment was tested.
- **Visual/Andy playtest:** rendered crane/load/unload behavior, quote/receipt
  readability, scrolling/focus/scaling, helm suppression and reopening services,
  real collision-safe sailing/docking, bulk fixture appearance, unchanged ship/
  HUD behavior and retained progression targets. No display/Xvfb or manual playtest;
  headless scene assertions do not establish visual acceptance.

Deliver as a **DRAFT PR against main**. Step 71 remains unstarted. No complete
Windows/public-authenticated/rendered acceptance or live deployment is claimed.

## Step 71 — Gas capacity and terminal compatibility (draft) — November 5, 2026

Task ID: `gas-capacity-and-terminal-compatibility`. Branch
`feat/step-71-gas-capacity-and-terminal-compatibility` starts at merged Step 70
main `271f214`. Initial checkout ended at Step 68; fetching origin revealed
Steps 69–70, which were read before implementation. Implemented ONLY Step 71.
D128 and GAS_CAPACITY.md record the launch set, precision and authority boundary.

Added LNG, nitrogen, oxygen and argon definitions using bounded integer cubic meters
(1 m³ precision). LNG covers methane-based cargo; no duplicate methane commodity,
helium or hydrogen launch support. Explicit tank IDs/capacities/commodity allowlists
and single-commodity segregation reject mixing, overfill and unsupported allocations
atomically. Same-gas batches may share space; emptying releases assignment.
Container counts, bulk grams and gas m³ keep independent budgets, including when
hold/tank names collide. No existing ship gains gas capacity.

Berth pipelines explicitly select compatible commodities, LNG or industrial cryogenic
interface, and loading/unloading directions. Catalog validation rejects malformed
and mismatched definitions transactionally. Read-only `GasRules.transfer_error`
rejects unsupported ship/tank/commodity/terminal/pipeline/direction combinations.
It does not grant docking, ownership, stock or economic authority. Step 72 must use
this query and manifest checks at admission/completion; no gas transfer, quote,
service UI or persistence is activated here. Gas gets no oil market.

Data-only fixtures provide one 400 m³ LNG tank, two 600 m³ industrial tanks and a
terminal with two bidirectional pipelines. Fixtures are not playable/purchasable
or spawned in the world. All new runtime resources are explicitly exported.
Godot **4.7.2**, protocol **17**, ticket **7**, save schemas and all **160 existing
.gd.uid files** remain unchanged; two new script sidecars are retained. Single
condition, one active nonexpiring job, no trades/transfers/gifts, no hidden shallows
and no machinery wear remain. No deferred work, live-save change or deployment.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf`; installed 4.6.3 was not used. Engine, logs,
virtualenv and isolated XDG/SQLite fixtures remain under `/workspace/work/step71`,
outside Git. Initial editor import lacked local socket access; rerun with local
network permission and isolated XDG directories passes cleanly.

- Gas probe: **108 assertions** pass, covering launch commodities, exact capacity,
  one-m³ overfill, invalid inputs, exclusions, all segregated industrial pairs
  alongside LNG, batching, tank reuse, malformed definitions, catalog rollback,
  pipeline interfaces/directions, simultaneous full container/bulk/gas budgets,
  colliding hold/tank IDs and copy isolation. Initial probe issues (StringName
  fixture key and array context after typing a manifest as RefCounted) were fixed;
  final variables use the concrete preloaded script type and pass all assertions.
- Bulk capacity **102**, earnings **330**, service **65**, actual bulk scene **16**
  assertions pass. Portable service recovery passes all **15 phases**, including
  four owned-process kills at load/unload commit markers.
- Editor/import, **162-script** load check and Main startup pass. Catalog, controls,
  flow, starter assets, units (50), diagnostics (9), contracts (66), geography (342),
  session (21), handling (134), camera (20), water (59), feedback (24), world size
  (2,042), heavy lifter (39), fuel (42), economy (82), compact snapshots (24), public
  physics (43), repair (20), purchase (35), inspection (32), switching (34), resale
  (26) pass. Diagnostics emits its intentional validation error. Clocks initially
  failed its hosted-settings timer assertion during the concurrent sweep; isolated
  rerun passes all **22** checks.
- Voyage **101**, sailing-save **330 checkpoints**, friends-client configuration
  and isolated slots **38** pass. Initial slots invocation omitted its required
  proof argument; the corrected isolated invocation passes.
- All **28 SQLite storage/persistence/migration/durable-recovery phases** pass,
  including ten owned-process kills, rollback/reopen, backup and persistence UI.
  Container voyage additionally passes ten ordered recovery runs including four
  self-kills at verified fault markers and two final reopens without duplicate pay.
- All **45 Python tests** pass with isolated psycopg/binary 3.2.10. Production route
  benchmark and all three progression scenarios pass with request replay and
  serialized reload equivalence. SQL doubles are not PostgreSQL evidence.
- Local reconnect/actions and normal/impaired replication, cargo-network and
  connected-world initially pass **15/16 process results**. Normal replication
  client fails its buffered-motion bound (87.86 m/s maximum presentation speed);
  isolated rerun of the same host/client pair passes both. Preserve this initial
  timing failure; local fixtures are not public authenticated network proof.
- Capacity fixtures pass **30/30 process results** across 2/10/25/50/100 clients
  in dispersed and crowded layouts. These local synthetic loads do not establish
  production capacity or authenticated public-network acceptance.
- Python AST compilation (**64 sources**), whitespace and existing UID byte/presence
  checks pass. No secrets, accounts, databases, exports or caches are committed.

### Linux limits and unrun acceptance gates

Collision fails lateral contact; composition fails two side-course contacts.
Ports reaches **261** assertions but emits two out-of-tree transform errors.
Shared gauges/wear reach **3/10** passing assertions, then time out awaiting rendered
frames. These reproduce recorded Linux limitations and are not clean passes.
The timer/replication first-run failures are retained above.

- **Windows:** pinned PowerShell suite, native identity/integration runners,
  Debug/Release client/server exports, gas resource inclusion and Windows save/UID
  compatibility. PowerShell/Windows runtime is unavailable.
- **PostgreSQL/HTTPS:** real transaction concurrency/replay, before/after-commit
  crashes, canonical checkpoint/reload and restart. No PostgreSQL client/server
  or configured integration stack. Gas persistence is Step 72; SQLite regressions
  do not establish public gas durability.
- **Keycloak/authenticated peers:** native sign-in, two-account privacy/ownership,
  lease fencing, disconnect/rebind/reconnect, handoff and authenticated restart.
  Java exists; no configured identity stack/accounts or gas endpoint is present.
- **Visual:** rendered ship/HUD/port regression, resource appearance, focus/scaling
  and existing bulk loading presentation. No display/Xvfb or manual visual review.
- **Andy playtest:** collision-safe sailing/docking, cargo-service usability and
  retained progression targets. Gas has no playable service in this definition step.

Deliver as a **DRAFT PR against main**. No complete Windows/public-authenticated/
rendered acceptance, Step 72 work or live deployment is claimed.

## Step 72 — Gas delivery and persistence (draft) — November 5, 2026

Task ID: `gas-delivery-and-persistence`. Branch
`feat/step-72-gas-delivery-and-persistence`, based on merged Step 71 / PR #10,
main `e2e1b8d`. Read AGENTS.md, CLOUD_HANDOFF.md, latest progress/decisions,
FEATURE_INVENTORY.md, DEFERRED_PLAYER_REQUESTS.md, GAS_CAPACITY.md and original
roadmap Step 72 before implementation. Initial checkout was Step 70; fetched the
merged base after enabling workspace network access to the configured proxy.
Implemented ONLY Step 72. D129 and GAS_DELIVERY_PERSISTENCE.md record the contract.

Gas now shares the bulk quote/settlement, service/panel, timed operations and SQLite
checkpoint path. Trusted family configuration retains existing bulk defaults and
serialized field names; gas uses integer m³, explicit tank allocation and minor
credits/m³/NM. Freeze direct distance, rate and both port modifiers. Positive
whole-m³ partials pay cumulative exact earnings less prior payments. The documented
123 m³ LNG / 1,500 m / 1.10 / 0.90 quote is **98.62 credits**, paid **40.09 + 58.53**.
Fragmenting the remainder cannot increase or reduce final payment. Gas has no oil
market, buy/sell lots, resale price or propulsion-fuel conversion.

Added developer-menu Gas Port Test using the gas capacity fixture and explicitly
compatible copied berths. Commodity/tank selection, pipeline label, frozen gross
quote (also visible during service), whole-m³ unload amount, progress and receipts
reuse the bulk UI. Gas draws pipeline progress without economic callbacks. The
shared five-second authority operation loads a whole batch or unloads a requested
partial. Pipeline compatibility/direction and manifest/job eligibility are checked
at admission and completion. Unsupported delivery, over-discharge, wrong owner/ship/
port, provenance mismatch, conflicting replay and repeat final settlement fail.

New private gas realm/version 1 preserves acquisition/origin/destination, tank,
frozen terms, operation history, cumulative receipts, cargo, wallet, pose, fuel and
single condition atomically before publishing success. Exact replay returns the
historical receipt with zero new award. Cancel/berth or pipeline loss stops only
unfinished work; completed cargo/partials remain. Resume durable progress without
offline advance and sailing in neutral. Failed/uncertain commits and stale writers
fence until reopen. Unknown/corrupt saves are preserved, not reset. Loaded-job
abandonment, public gas RPC/wallet/handoff/sinking integration are not introduced;
the lifecycle table explicitly records these private-fixture boundaries.

Godot remains **4.7.2**, game protocol **17**, ticket **7**. All **162 existing
.gd.uid files** are byte-identical, with no new scripts requiring sidecars. The new
runtime scene is explicitly exported. Existing bulk/container/heavy save versions,
IDs and paths remain unchanged. One active nonexpiring job, single condition, no
player trades/transfers/gifts, no machinery wear and no hidden shallows remain.
No Step 73, deferred requests, live-save change or deployment.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf`, downloaded under `/workspace/work/step72`.
Installed 4.6.3 was not used. Engine, virtualenv, logs, generated compatibility
sources, XDG fixtures and databases remain outside Git.

- Gas service suite: **221 assertions**; actual panel/scene: **16 assertions**.
  Includes all compatible pairs in both directions, 40 independent Python-integer
  arithmetic vectors (finite and overflow), whole-m³ input rejection, cumulative
  fragments, provenance, origin/owner/ship/port rejection, stale writers, malformed
  saves, terminal permission/interface changes at admission and completion, and
  100 visual refreshes that cannot advance authority. Accepted quote remains visible.
- Gas portable recovery runner: all **15 process phases** pass, including **four
  owned-process kills** before/after loading and unloading COMMIT. Reopen verifies
  rollback, committed recovery, lost-reply zero-delta replay, partial/final payout
  and repeated final reopen. Actual scene restores loaded and partial voyages,
  cancels unfinished unloading on berth loss, and resumes saved pose/fuel in neutral.
- Bulk shared-path regression: **90 service assertions**, **16 scene assertions**,
  all **15 recovery phases** (four more owned-process kills), **330 earnings** and
  **102 capacity** assertions pass. Gas capacity retains **108** passing assertions.
- Generated isolated fixtures from the **pre-Step-72 main service and earnings
  sources**: current code restores pending loading/unloading, opens its partially
  paid SQLite save and completes the original 98.99-credit bulk quote unchanged.
- Editor/import and all **162 scripts** load; Main startup passes. Catalog, controls,
  flow, starter assets, units, diagnostics, contracts, geography, session/clocks,
  handling, camera, water/feedback, world size, heavy lifter, fuel, economy, compact
  snapshots, public physics, repair, purchase, inspection/switching/resale pass.
  Diagnostics emits its intentional validation error. Container voyage **101**,
  sailing-save **330 checkpoints**, slots **38**, and friends-client menu checks pass.
- All **28 existing SQLite storage/persistence/migration/durable-recovery phases**
  pass, including **ten owned-process kills**, rollback, backup fallback and UI.
  Container voyage additionally passes ten ordered recovery runs, including four
  intentional self-kills and two final reopens without duplicate payment.
- All **45 Python tests** pass with isolated psycopg/binary 3.2.10. Production route
  benchmark and all three progression scenarios pass with request replay and
  serialized reload equivalence. SQL doubles are not PostgreSQL evidence.
- Local reconnect/actions and normal/impaired replication, cargo-network and
  connected-world pass **16/16 process results**. Capacity fixtures pass **30/30**
  process results across 2/10/25/50/100 clients, dispersed and crowded. These local
  synthetic fixtures are not authenticated public-network or production capacity proof.
- Python AST compilation, whitespace, existing UID byte comparison and presence of
  every script sidecar pass. No secrets, accounts, databases, exports, caches or
  generated evidence are included.

Initial new-code failures were fixed before the passing focused runs: restore used
live changed terminal permissions too early to cancel unfinished service; capturing
self in store codec callbacks retained resources; the shared model constructor
needed explicit parent initialization to retain container offers. The original bulk
probe caught all three container failures and passes after that fix. Initial slots
invocation used the wrong proof option; corrected isolated invocation passes.

### Linux limits and unrun acceptance gates

Collision fails lateral contact; composition fails two side-course contacts. Ports
reaches **261 assertions** but emits two out-of-tree transform errors. Shared gauges
and wear reach **3/10 passing assertions**, then time out waiting for rendered frames.
These reproduce recorded Linux limitations and are not clean passes.

- **Windows:** pinned PowerShell suite; native identity/integration runners;
  Debug/Release client/server exports, exported gas resource inclusion; portable gas
  recovery runner and Windows save/UID compatibility. No Windows/PowerShell runtime.
- **PostgreSQL/HTTPS:** actual gas cargo/wallet/receipt transaction concurrency,
  replay, before/after-commit crashes, canonical reload and server restart. No
  configured PostgreSQL client/server/HTTPS integration stack or public gas endpoint;
  private SQLite proof does not close that boundary.
- **Keycloak/authenticated peers:** native sign-in, two-account isolation/ownership,
  lease fencing, disconnect/rebind/reconnect, server handoff and authenticated gas
  restart. Java exists; configured identity stack/accounts and public gas integration
  are absent. No remote internet deployment was tested.
- **Visual:** rendered pipeline progress, quote/receipt readability, small-screen
  scrolling/focus/scaling, helm suppression, placeholder hull/terminal appearance
  and unchanged HUD/ship presentation. No display/Xvfb or manual visual acceptance.
- **Andy playtest:** real collision-safe sailing/docking, gas-service usability,
  interruption/reopen and retained progression targets. Headless scene tests do not
  establish human voyage or visual acceptance.

Deliver as a **DRAFT PR against main**. Step 73 remains unstarted. No complete
Windows/public-authenticated/rendered acceptance or live deployment is claimed.

## Step 73 — Liquid trading inventory (draft) — November 5, 2026

Task ID: `liquid-trading-inventory`. Branch
`feat/step-73-liquid-trading-inventory` starts at merged Step 72 main `bb26589`.
Read AGENTS.md, CLOUD_HANDOFF.md, latest progress/decisions, FEATURE_INVENTORY.md,
DEFERRED_PLAYER_REQUESTS.md and original roadmap Step 73. Initial checkout was
Step 70; fetched current main with workspace network access before implementation.
Implemented ONLY Step 73. D130 and LIQUID_TRADING_INVENTORY.md define the contract.

Added whole-barrel oil, an independent 200-barrel data-only hull capacity and a
private durable trading API. Brindle Quay sells to the captain at 125 minor credits
per barrel; Slatewater Works buys at 175. Custom positive integer quantities are
rejected atomically if cash or capacity is insufficient. One unsold lot at a time
retains acquisition ID, origin, owner/ship, original quantity, unit/total cost,
remaining quantity and cumulative sold cost/proceeds/profit. Partial sales name
that lot explicitly. Purchase cost is charged once; sale credits proceeds and
reports the already-paid cost basis without charging it again.

The existing SQLite checkpoint store commits wallet, manifest, lots, action history
and receipts together before publishing success. Exact retry returns the historical
receipt with zero new delta; conflicting retries fail. Bounded history replay
validates all derived state. Failed/uncertain commits and stale writers fence until
a fresh instance reopens. A separate private version-1 realm preserves existing
bulk/gas/container/heavy saves. No new public endpoint, playable oil hull, UI or
market simulation is implied; Steps 74–76 remain separate and Step 74 is unstarted.

Godot remains **4.7.2**, game protocol **17**, ticket **7**. All **162 existing
.gd.uid files** are byte-identical; two new script sidecars are included. Runtime
resources are explicitly exported. Existing catalog indices and IDs are preserved.
Single condition, one active nonexpiring job, no player trades/transfers/gifts,
no machinery wear and no hidden shallows remain unchanged. No deferred requests,
live-save changes, live deployment, secrets, accounts, databases, exports or caches.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf`; installed 4.6.3 was not used. Downloaded
engine, virtualenv, logs and isolated XDG/SQLite fixtures are outside Git under
`/workspace/work/step73`.

- Final oil suite: **153 assertions** pass, including exact cash/capacity limits,
  malformed/fractional/overflow input, wrong owner/ship/port, docking, caller price
  rejection, conflicting replay, explicit partial cost basis, 107 one-barrel
  fragments, sold lot-ID reuse rejection, copy isolation, malformed save quarantine
  and stale-writer fencing with no published mutation.
- Portable oil recovery runner: **13 process phases** pass, including **four
  owned-process kills** before/after purchase and sale COMMIT. Reopen proves buy
  rollback/one debit, sale rollback/one credit, durable zero-delta retries,
  partial/final accounting and repeated final reopen. Worked 123-barrel lot ends
  with 6,150 minor-credit profit and 26,150 wallet, exactly as documented.
- Existing gas and bulk portable service runners each pass **15 process phases**,
  including their suites, actual scene checks and four owned-process kills each.
  Gas capacity **108**, bulk capacity **102**, bulk earnings **330** assertions pass.
- Editor/import, Main startup and **164-script** load check pass. Catalog, controls,
  application flow, starter assets, units, diagnostics, contracts, geography,
  session/clocks, handling, camera, water/feedback, world size, heavy lifter, fuel,
  economy, compact snapshots, public physics, repair, purchase, inspection,
  switching and resale pass. Diagnostics emits its intentional validation error.
  Ports passes **261** checks; voyage **101**, sailing-save **330 checkpoints**,
  isolated slots **38** and unconfigured friends-client menu checks pass.
- Existing SQLite storage/persistence/migration/recovery: all **28 phases** pass,
  including **ten owned-process kills**, rollback/reopen, backup fallback and UI.
  Container voyage additionally passes **14 runs**, including round-trip/repeated
  reopen and four self-kills around loading/delivery commits.
- All **45 Python tests** pass with isolated psycopg/binary 3.2.10. Production route
  benchmark and all three progression scenarios pass with per-request replay and
  serialized reload equivalence. SQL doubles are not real PostgreSQL evidence.
- Local network reconnect/actions, replication, cargo-network and connected-world
  pass **15/16 process results**. Impaired replication client fails its buffered
  motion bound (42.46 m/s maximum presentation speed); recorded below, not a pass.
- Capacity fixtures: **29/30 process results** pass across 2/10/25/50/100 clients,
  dispersed and crowded. The 25-client crowded observer fails `Observer has no
  unbounded motion jump`; all server/bot processes and other observers pass.
  These local synthetic fixtures are not authenticated production capacity proof.
- Python AST parsing (**65 sources**), whitespace, existing UID byte comparison and
  every script's sidecar presence pass. Generated evidence remains outside Git.

Initial catalog insertion shifted positional references used by existing probes;
fixed by appending oil after all existing records. Affected catalog, script load,
bulk/gas capacity/earnings, diagnostics and handling checks pass on rerun. Initial
editor import lacked socket permission; network-enabled import passes cleanly.
Initial Python tests lacked psycopg and friends-menu invocation lacked the friends
flag; corrected isolated runs pass. The usage-limit approval failure interrupted
one import attempt; no command was executed by that failed approval review.

### Linux limits and unrun acceptance gates

Collision fails lateral contact; composition fails two side-course contacts.
Shared gauges/wear reach **3/10 passing assertions** then time out awaiting rendered
frames. These match the prior recorded Linux limitations and are not clean passes.
Impaired replication's buffered-motion failure is retained above; no networking
implementation changed. Local synthetic fixtures do not prove public capacity.

- **Windows:** pinned PowerShell suite, native identity/integration runners,
  Debug/Release client/server exports, oil resource inclusion, portable oil recovery
  runner on Windows, Windows save/UID compatibility. No Windows/PowerShell runtime.
- **PostgreSQL/HTTPS:** real concurrent oil cargo/wallet/receipt transactions,
  retries, before/after-commit crashes, canonical reload and server restart. No
  configured PostgreSQL/HTTPS stack or public oil endpoint. SQLite results do not
  establish public settlement; centralized market integration remains Step 75.
- **Keycloak/authenticated peers:** native sign-in, two-account isolation/ownership,
  lease fencing, disconnect/rebind/reconnect, handoff and authenticated oil restart.
  Java exists, but no configured identity stack/accounts or public oil integration.
- **Visual:** rendered trade quantity/receipt/cost-basis UI, focus/scaling/scrolling,
  exported oil resource appearance and unchanged ship/HUD presentation. No display,
  Xvfb or visual acceptance; the oil interface is Step 76, not part of this API step.
- **Andy playtest:** collision-safe sailing/docking, future oil-service usability,
  interruption/reopen and retained progression targets. Headless proofs do not
  establish human voyage acceptance. Public oil handoff/sinking/recovery and ship
  switching/resale remain explicit integration gates outside this isolated fixture.

Deliver as a **DRAFT PR against main**. No complete Windows/public-authenticated/
rendered acceptance or live deployment is claimed. Step 74 remains unstarted.

## Step 74 — Oil market simulation (draft) — November 5, 2026

Task ID: `oil-market-simulation`. Branch `feat/step-74-oil-market-simulation`
is based on merged Step 73 main `1226e27`. Read AGENTS.md, CLOUD_HANDOFF.md,
latest progress/decisions, FEATURE_INVENTORY.md, DEFERRED_PLAYER_REQUESTS.md and
original roadmap Step 74. Initial checkout was stale; fetched current main with
workspace network access to the configured proxy before implementation.
Implemented ONLY Step 74; Step 75 remains unstarted. D131 and
OIL_MARKET_SIMULATION.md document the authority contract and limitations.

Added a dependency-free Python market model alongside the existing Python service
sources. Configuration controls cadence, quote lifetime, base/port offsets, hard
price bounds, bounded signed supply pressure/recovery and bounded quantity effect.
All prices/quantities use integer minor credits/whole barrels. Authority time is
monotonic; catch-up is constant-time and agrees with regular ticks. No live feed,
real-money dependency or random price source. Snapshots/configuration are copied.

Two public views share the same owner, prices and ordered state; views cannot
instantiate fallback markets. Missing authority fails MARKET_UNAVAILABLE. Private
hosts instantiate isolated markets using the same model; cross-market quotes and
binding a private owner to a public view fail. Issued quotes freeze their terms
across updates until the exclusive expiry boundary. Expiry returns QUOTE_EXPIRED
without a trade effect; callers must explicitly request new terms. Modified,
unknown or consumed quotes cannot produce another pressure change. Issued quote
storage is bounded and expired entries are pruned.

This is **model-level in-process evidence**, not two networked public servers or
live public deployment. The trusted simulation transition changes market pressure
only; it does not settle cargo or money. Durable centralized storage/transport,
authenticated quote ownership, account settlement and durable retry receipts are
Step 75. No public route is enabled. Step 73's fixed-price version-1 SQLite codec
and private inventory remain unchanged pending that deliberate integration; no
variable-price history is inserted into existing saves. Step 76 UI is untouched.

Godot stays **4.7.2**, game/ticket protocols **17/7**. All **164 existing .gd.uid**
files are byte-identical; no new GDScripts or exported runtime resources were added.
Existing saves/IDs, single condition, one active nonexpiring cargo job, nonexpiring
cargo offers, no player trades/transfers/gifts, no machinery wear and no hidden
shallows remain unchanged. No secrets/accounts/databases/exports/caches committed.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf` downloaded under `/workspace/work/step74`;
installed 4.6.3 was not used for checks. Engine, virtualenv, logs, XDG directories
and SQLite fixtures remain outside Git.

- **13 market unit tests pass:** shared public views/port differences, private-host
  isolation and cross-market rejection, unavailable public authority, worked integer
  prices, bounds, catch-up/backward clocks, expiry boundary/requote, frozen terms,
  forged/consumed quotes, copy isolation, invalid config/quantities and quote limit.
  Includes 500 updates across eight threads and 100 concurrent attempts to consume
  one quote, with exactly one pressure effect. Threads are not multi-server proof.
- **45 existing Python authority tests pass**, with isolated psycopg/binary 3.2.10.
  Production route benchmark and all three progression scenarios pass with replay
  and serialized reload equivalence. SQL doubles are not PostgreSQL evidence.
- Liquid inventory portable runner: **13 process phases pass**, including **153
  suite assertions** and **four owned-process kills** around purchase/sale COMMIT,
  rollback/reopen, partial/final accounting and repeated final reopen.
- Bulk and gas portable runners: **15 phases each pass**, including **90/221 suite
  assertions**, actual scene checks and **four owned-process kills each**. Bulk
  capacity **102**, earnings **330**, gas capacity **108** assertions pass.
- Editor/import, all **164-script** loading and Main startup pass. Catalog, controls,
  application flow, starter assets, units, contracts, geography, session/clocks,
  handling, camera, water/feedback, world size, heavy lifter, fuel, economy, compact
  snapshots, public physics, repair, purchase, inspection, switching and resale
  pass. Diagnostics passes with its intentional validation error. Voyage **101**,
  sailing-save **330 checkpoints**, slots **38**, unconfigured friends menu pass.
- Python AST parsing (**67 sources**), existing UID comparison/sidecar presence and
  whitespace checks pass. No game or account service route was modified.

### Failures, limits and unrun gates

Collision fails its lateral-contact assertion; composition fails two side-course
contacts. Ports reaches **261 checks** but emits two out-of-tree transform errors.
Shared gauges and wear pass **3/10 assertions**, respectively, then hit the
65-second harness timeout awaiting rendered frames. These match prior recorded
Linux limitations and are not clean passes. No changed physics/UI code is involved.
The full legacy 28-phase SQLite sweep and network/capacity fixtures were not rerun;
focused oil/bulk/gas durable recovery and the regressions above were run.

- **Windows:** pinned PowerShell suite, native integration runners, Debug/Release
  client/server exports and Windows save/UID/resource compatibility. No Windows or
  PowerShell runtime available.
- **PostgreSQL/HTTPS:** durable shared market concurrency/restart, quote/account
  binding, atomic market/cargo/wallet/receipt settlement and retries after uncertain
  commits. No configured PostgreSQL/HTTPS stack; these are Step 75 integration gates.
- **Keycloak/authenticated peers:** native sign-in, two-account ownership/isolation,
  fencing, reconnect/handoff and two public-server market consistency/outage tests.
  No configured identity stack/accounts or public oil endpoint; an in-process
  facade test is not this acceptance gate.
- **Visual/Andy playtest:** rendered ship/HUD/port regressions, future oil quote
  countdown/refresh/receipt presentation, focus/scaling and actual sailing/docking.
  No manual visual acceptance; the oil player interface remains Step 76.

Deliver as a **DRAFT PR against main**. No deployment, full platform acceptance,
public settlement, actual cross-server market operation or Step 75 work is claimed.

## Step 75 — Shared public oil market service (draft) — November 5, 2026

Task ID: `shared-public-oil-market-service`. Based on merged main **4b48613**
(Step 74), branch `feat/step-75-shared-public-oil-market-service`. Read AGENTS.md,
CLOUD_HANDOFF.md, latest progress/decisions, FEATURE_INVENTORY.md,
DEFERRED_PLAYER_REQUESTS.md and original roadmap Step 75. Implemented ONLY Step 75;
Step 76 remains unstarted. D132 and SHARED_PUBLIC_OIL_MARKET.md document the contract.

The existing authenticated HTTPS authority now dispatches market snapshot, quote
and acceptance requests under its server/account lease fences. An additive
PostgreSQL adapter persists the Step 74 model/configuration, identity, clock,
versions and account/ship-bound quotes. A singleton row lock orders public updates;
each successful operation appends a durable sequence. Acceptance atomically commits
market/history, cargo, wallet/treasury, debt repayment, revision, receipt and journal.
Exact action replay returns the original outcome after disconnect/rebind/handoff;
changed intent conflicts, foreign/consumed/expired quotes cannot settle again.
Missing existing market state cannot be reseeded by initialization.

A verified-HTTPS public-server client fails closed on outages and labels uncertain
acceptance, preserving original retry intent. No local public simulation/pricing
fallback. Private hosts use the same settlement contract with separately provisioned
SQLite files and serialized writes. Canonical oil lots retain their acquisition
terms and partial-sale basis; existing sinking/fleet cargo guards apply. Generic
fixture delivery cannot redeem oil. Only the authored oil prototype has capacity;
no new playable/public catalog hull, Godot oil RPC/UI, Step 76 work or historical
Step 73 save migration. Existing server-side docking attestation remains required.

The Windows host builder now includes the market package. No new Godot runtime
resources/scripts were added. Godot remains **4.7.2**, game/ticket protocols **17/7**;
all **164 existing .gd.uid files** are byte-identical. Existing saves/IDs, one
condition, nonexpiring cargo jobs/offers, no player transfers/trades/gifts, no
machinery wear and no hidden shallows are preserved.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf`, isolated psycopg/binary 3.2.10, cryptography
and PostgreSQL **17.11** under `/workspace/work/step75`. All dependencies, evidence,
certificates, credentials, caches and fixture databases stay outside Git.

- **21 market tests pass:** 13 Step 74 tests plus eight durable contract tests.
  Covers private isolation, restart/replay, conflicting intent, expiry, ownership,
  frozen prices, revision/ship/capacity validation, rollback boundaries, lost reply,
  cumulative sale costs, debt repayment and 32 concurrent attempts with one effect.
- **Real PostgreSQL/HTTPS integration passes:** two distinct public-server worker
  processes and two authority service processes share one database/history. Tests
  concurrent separate-account trades, same-account/same-quote contention through
  both services, retry storms, account isolation, stale generation rejection,
  disconnect/rebind and server handoff. Four owned service crashes after profile
  write, market write, before COMMIT and after COMMIT recover atomically. Temporary
  database and complete service outages return unavailable, then recover the same
  market. Seven successful settlements produce exactly seven journal entries;
  one rejected generic-delivery intent is also recorded. History is contiguous;
  wallet plus game balances reconcile. Missing singleton initialization refuses.
- **Windows host source packaging smoke passes on Linux:** executes the builder's
  actual copy function and service allowlist calls in an isolated folder, compares
  copied source bytes, then imports the relocated authority/market adapters and
  checks the packaged SQL resource. This is not a Windows executable/build pass.
- **45 existing Python authority tests pass.** Production route benchmark and all
  three progression scenarios pass with replay and serialized reload equivalence.
- Liquid inventory **13 phases**, bulk **15 phases**, gas **15 phases** pass,
  including four owned-process commit-boundary kills per family. Bulk capacity,
  bulk earnings and gas capacity pass. All **28** legacy SQLite storage,
  persistence, migration and durable-recovery phases pass, with ten owned-process
  kills. Voyage suite **101** and its ten recovery phases (four self-kills) pass;
  sailing-save **330 checkpoints**, ports **261**, slots **38** pass.
- Editor/import, **164-script** load and Main startup pass. Catalog, controls,
  application flow, starter assets, units, contracts, geography, session/clocks,
  handling, camera, water/feedback, world size, heavy lifter, fuel, economy,
  compact snapshots, public physics, repair, purchase, inspection, switching,
  resale and unconfigured friends menu pass. Diagnostics passes with its intended
  validation error.
- Network reconnect/actions and normal/impaired replication, cargo-network and
  connected-world: **16/16 process results pass**. Capacity at 2/10/25/50/100
  clients, dispersed/crowded: **30/30 process results pass**. These are local
  headless fixtures, not production capacity or authenticated Godot oil peers.
- Python AST parsing (**73 sources**), UID/sidecar preservation and whitespace
  checks pass. No secrets, accounts, databases, exports or caches are committed.

Initial harness attempts had denied loopback sockets, PostgreSQL SQL_ASCII/default
restart options, wrong private fixture roots, a missing slots authorization flag,
and a Node probe invoked as a script. Corrected these and reran in isolated
namespaces; those attempts are not counted as passes. The final editor import uses
network-enabled execution to avoid editor socket errors.

### Remaining failures and unrun gates

Collision still fails lateral contact; composition fails its two side-course
contacts. Shared gauges/wear reach **3/10 assertions** then the 65-second timeout
waiting for rendered frames. These match previously recorded Linux limits and are
not clean passes; no physics/HUD implementation changed in this step.

- **Windows:** pinned PowerShell suite, native integration runners, full Windows
  host-builder execution with actual dependencies, Debug/Release client/server
  exports, packaged service launch, save/UID/resource compatibility. Linux source
  packaging/import proof does not replace these checks.
- **PostgreSQL/production HTTPS:** local real SQL concurrency/crash/outage proof
  passed. Production deployment/upgrade on the existing host, backup/restore,
  failover/replication, operational load, external-network TLS/certificate lifecycle
  and real-server recovery are unrun. No live database or server was touched.
- **Keycloak/authenticated Godot peers:** native OIDC sign-in, real account/provider
  enrollment, in-game two-server oil requests, docking/ship admission and peer
  handoff/reconnect. Tests used operator-issued fixture tickets and approved server
  credentials; they do not prove Keycloak or an oil gameplay UI/RPC integration.
- **Visual/Andy playtest:** rendered ship/HUD/port regression, actual sailing and
  docking, future quote/receipt/quantity UI focus/scaling. No manual visual playtest;
  the oil interface remains Step 76.

Deliver via **DRAFT PR against main**. No deployment, Windows/Keycloak/rendered
acceptance, or Step 76 completion is claimed.

## Step 76 — Oil market interface and lot accounting (draft) — November 5, 2026

Task ID: `oil-market-interface-and-lot-accounting`. Based on merged Step 75 main
`4d10928`, on `feat/step-76-oil-market-interface-and-lot-accounting`. Read AGENTS.md,
CLOUD_HANDOFF.md, latest progress/decisions, FEATURE_INVENTORY.md,
DEFERRED_PLAYER_REQUESTS.md and original roadmap Step 76. The initial cloud
checkout ended at Step 70; fetched current main before implementation. ONLY Step
76 is implemented. D133 and OIL_MARKET_INTERFACE.md specify policy and boundaries.

Added a reusable Godot panel with underway inspection of both ports, per-port UTC
observation timestamps, separate exact-quote review, custom whole-barrel controls,
monotonic expiry feedback, current lot cost and durable trade receipt. Reference
prices are explicitly indicative. Selection changes invalidate quotes; responses
for changed selections are discarded. Refresh does not replace an executable
quote or its captured revision. Accept sends the displayed ID/version/port and
original revision. Expiry/rejection never auto-requotes. An uncertain reply locks
new trading until explicit retry of the same action and quote resolves it.

Retained the existing one-current-lot cumulative allocation policy: floor original
cost times cumulative sold quantity divided by original quantity, less previously
allocated cost. Remaining cost is the complement. Receipts separate gross,
allocated acquisition cost, realized profit, recovery-debt repayment and wallet
change. Final sale retains its receipt with zero remaining cost. PostgreSQL and
SQLite snapshots now return account-scoped lots/wallet/revision/last oil receipt;
new receipt fields are additive and historical receipt fields remain readable.
No separate wallet mutation, double charge, FIFO change or save migration.

Added a separately launched private oil sailing fixture using the existing port,
docking and starter presentation with copied oil-compatible definitions. The
operator-only Python launcher explicitly creates a NEW isolated Step 75 SQLite
store or reopens the supplied file, uses a child-only ephemeral loopback bearer,
and shuts down its owned service on exit. The trusted local scene attests docking;
this is not a public player RPC or local public-market fallback. No normal/friends
menu, playable public oil hull or public Godot oil peer routing is introduced.
Market/wallet/lots/receipts persist; fixture sailing pose/fuel restart at spawn.
Full oil voyage/sinking/handoff integration is not claimed by this interface step.

Godot stays **4.7.2**, game/ticket protocols **17/7**; all **164 existing .gd.uid
files** are byte-identical, with three new sidecars retained. New runtime resources
are explicit export roots. Existing saves/IDs, one condition, nonexpiring cargo
jobs/offers, no player transfers/gifts/trades, no machinery wear and no hidden
shallows remain. No Step 77, deferred request, live save or server deployment.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf`, isolated psycopg/binary **3.2.10**,
cryptography and PostgreSQL **17.11** under `/workspace/work/step76`. Engines,
logs, credentials, certificates, XDG/APPDATA fixtures and databases remain outside
Git. Installed 4.6.3 was not used for project checks.

- **26 actual interface assertions pass:** live Godot panel/HTTP/private SQLite,
  both timestamped ports underway, actual dock admission at both ports, custom
  quantity, changed selection and late response rejection, unchanged quote after
  price refresh, local and authority expiry rejection without automatic quote,
  real committed purchase with an injected lost reply, identical retry even after
  berth loss/local expiry, partial-sale cost conservation, panel reopen restoring
  canonical inventory/wallet/receipt, final sale and helm release after closing.
- **25 Python market/interface tests pass:** 13 model, eight settlement and four
  new presentation/accounting tests. Covers per-account receipt privacy, timestamps,
  frozen quote across another captain's trade, exclusive expiry with no mutation,
  partial/reopen/final cost reconciliation and synthetic fractional allocation
  3+3+4=10 across separate durable sales. All **45 existing Python authority tests**
  pass. Route benchmark and all three progression/replay/reload scenarios pass.
- **Real PostgreSQL/HTTPS integration passes:** two authority service processes
  and two public-server worker processes, concurrent trades/retry storms, account
  isolation, stale fencing, disconnect/rebind/handoff, four owned service crashes
  around profile/market writes and COMMIT, database/service outage and restart,
  contiguous history and exactly seven settlements. New per-account lot costs,
  wallet, latest receipt and timestamps are checked after actual database/service
  restart. Observation timestamps are excluded only from cross-reader price
  equality; each must equal its own authority observation time. Missing singleton
  initialization still refuses rather than reseeding.
- Oil inventory **13**, bulk **15**, gas **15** recovery phases pass, including
  four owned-process commit-boundary kills per family. All **28** legacy SQLite
  storage/persistence/migration/recovery phases pass, including ten owned-process
  kills. Container voyage suite **101** plus round-trip/reopen and nine ordered
  crash/recovery phases pass, including four intentional self-kills. Sailing-save
  **330 checkpoints**, ports **261**, slots **38** pass.
- Clean editor/import, **167-script** load and Main startup pass. Catalog, controls,
  application flow, starter assets, units, contracts, geography, session/clocks,
  diagnostics (its intentional validation error), handling, camera, water/feedback,
  world size, heavy lifter, fuel, economy, compact snapshots, public physics,
  repair, purchase, fleet inspection/switching/resale and unconfigured friends
  menu pass. Bulk capacity **102**, earnings **330**, gas capacity **108** pass.
- Network reconnect/actions and normal/impaired replication, cargo-network and
  connected-world: **16/16 process results pass**. These remain local headless
  fixtures, not authenticated public Godot oil peers or internet deployment.
  Capacity at 2/10/25/50/100 clients, dispersed/crowded, passes **30/30 process
  results**; this is not a production capacity guarantee.
- Python AST parsing (**75 sources**), all existing UID byte comparisons, script
  sidecar presence and whitespace checks pass. No generated evidence, secret,
  account, database, cache, engine or export is included in the commit.

Initial harness attempts are retained in scratch logs: the import without network
permission reported editor socket errors; the persistence sweep used roots rejected
by the probes' explicit safety patterns; the friends-menu run omitted its mode
flag. Corrected those invocations and reran successfully. The first interface run
checked helm release before the next process callback; awaiting the completed
frame resolves that probe ordering error. These attempts are not counted as passes.

### Remaining failures and unrun gates

Collision fails its lateral-contact assertion; composition fails two side-course
contacts. Shared gauges/wear pass **3/10 assertions** then hit the 60-second
headless rendered-frame wait timeout. These match recorded prior Linux limits;
no physics/condition/gauge code changed. They are not reported as clean passes.

- **Windows:** pinned PowerShell checks, native integration runners, Debug/Release
  client/server exports, exported oil scene/resource loading, launcher behavior
  and save/UID compatibility. No Windows engine or configured Windows runner here.
- **PostgreSQL/production HTTPS:** local real SQL acceptance passed. Existing-host
  deployment/upgrade, backup/restore, failover, operational load, external TLS/
  certificate lifecycle and production recovery remain unrun. No live database
  or server was touched.
- **Keycloak/authenticated Godot oil peers:** native OIDC enrollment/sign-in,
  in-game public oil requests, real account/ship/docking admission, public peer
  reconnect and handoff. No configured identity stack/accounts; the local HTTPS
  runner uses operator-issued fixture tickets. Public Godot oil routing remains
  an implementation/integration gate, not a passed UI test.
- **Visual/Andy playtest:** rendered quote/receipt/lot layout, scrolling, keyboard
  focus and scaling, expiry/retry readability, real sailing/docking, input release,
  ship/HUD regression and pacing. No manual visual playtest; headless assertions
  do not establish rendered acceptance. The new fixture does not claim full oil
  voyage-position, sinking or public scene-handoff persistence.

Deliver as a **DRAFT PR against main**, not a push to main. No Step 77, live
deployment or full Windows/public-authenticated/rendered acceptance is claimed.

## Step 77 — Refinery processing (draft) — November 6, 2026

Task ID: `refinery-processing`. Based on merged Step 76 main **0a3b6af**, branch
`feat/step-77-refinery-processing`. Read AGENTS.md, CLOUD_HANDOFF.md, latest
progress/decisions, FEATURE_INVENTORY.md, DEFERRED_PLAYER_REQUESTS.md and original
roadmap Step 77. The initial checkout was behind; fetched current main before
implementation. Implemented ONLY Step 77. D134 and REFINERY_PROCESSING.md describe
the configuration, fractional policy, lifecycle, save contract and boundaries.

Added one private refinery, `refinery_slatewater_01`, at Slatewater Works, through
the existing operator-only oil fixture (`--refinery`). The Godot panel supports
fractional crude submission in positive integer millibarrels, authoritative
processing progress, configured yield/rate/capacities, exact remaining crude,
allocated cost, stored cargo fuel and carried fractions. One processing slot;
output space is reserved at acceptance. No cancellation/refund after custody
transfer. No cargo-fuel withdrawal, transport, sale or propulsion-tank refill.
Shared public stock and its transactions remain Step 78; Step 79 remains unstarted.

Yield is a saved rational numerator/denominator, configurable only when explicitly
creating a NEW isolated fixture. Output uses integer divmod with a saved remainder
per account/facility. Cumulative output equals floor(completed input times yield),
including split fractional inputs and zero-output jobs. Crude debit, acquisition
cost allocation, profile revision, job and idempotent action receipt commit in one
SQLite transaction. Completion credits stock/remainder and terminal job together.
Reads reconstruct stock/progress/remainders from bounded retained jobs; malformed,
missing or incompatible saves fail closed. Ledger exhaustion rejects new work
without evicting replay identities. Unknown outcomes retain the original request;
clock failures fence the runtime until reopen.

Only the private host's monotonic clock advances saved integer progress. Closing
the panel or sailing away does not cancel processing; stopping the host pauses it.
Restart resumes the last durable checkpoint without offline catch-up. Existing
whole-barrel oil trading remains; optional refined quantity/cost fields preserve
sub-barrel residue and cumulative cost conservation across mixed sales/refining.
Existing lots need no migration. Refinery receipts cannot replace oil receipts.

This remains a separately launched private fixture, not public Godot refinery
routing or shared PostgreSQL stock. Existing Step 76 limitations on voyage-position,
sinking, fleet and public handoff integration remain. No old-save reset/conversion,
live server deployment, playable public oil hull or deferred feature is introduced.
Godot remains **4.7.2**, game/ticket protocols **17/7**. All **167 existing .gd.uid
files** are byte-identical; two new script sidecars retained and the runtime panel
is an explicit export root. One condition, nonexpiring cargo jobs/offers, no player
transfers/trades/gifts, no machinery wear and no hidden shallows are preserved.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf`, isolated psycopg/binary **3.2.10** and
cryptography under `/workspace/work/step77`. Engines, scratch harnesses, logs,
XDG/APPDATA state, ephemeral credentials and databases remain outside Git.

- **36 Python refinery/oil tests pass:** 11 new refinery tests plus all 25 oil
  model/settlement/interface tests. Covers 125 deterministic fractional partitions
  with reopen and replay after each, zero-output carry, new-lot/account isolation,
  configured 1/3 and 7/10 yields, input/output/ledger bounds, malformed saved numbers,
  ownership/docking/revision rejection, changed-action conflicts, 32 concurrent
  submission attempts with one effect, concurrent completion calls, and exact
  mixed sale/refining cost reconciliation (including 3+3+4=10 allocation).
- New refinery tests exercise rollback at profile/refinery writes and COMMIT,
  lost replies, paused restart progress and **four owned subprocess exits without
  cleanup** immediately before/after submission and completion COMMIT. Reopen
  proves atomic crude custody/output and exactly-once retry/completion.
- **26 actual refinery interface assertions pass** through Godot/HTTP/private
  SQLite: real berth admission, wrong-port/underway rejection, fractional submission,
  injected lost committed reply, identical retry after berth loss, authoritative
  progress, hidden-panel completion, exact carry and visual-progress independence.
  Existing oil interface also passes **26 assertions**. The refinery interface
  was rerun after the final stricter save validation.
- **45 existing Python authority tests pass.** Production route benchmark and
  all three progression scenarios pass with request replay and serialized reload
  equivalence. These use SQL doubles, not a PostgreSQL acceptance claim.
- Oil inventory **13**, bulk **15**, gas **15** portable recovery phases pass,
  including four owned-process kills per family. Bulk capacity **102**, earnings
  **330** and gas capacity **108** pass. All **28** legacy SQLite storage,
  persistence, migration and recovery phases pass, including **ten** owned-process
  kills, rollback/reopen, backup fallback and persistence UI.
- Voyage suite **101**, round-trip plus two reopens, and ten ordered voyage
  recovery phases pass, including four intentional self-kills. Sailing-save
  **330 checkpoints** and slots **38** pass.
- Clean editor/import, all **169-script** loading and Main startup pass. Catalog,
  controls, application flow, starter assets, units, contracts, geography, session,
  clocks, handling, camera, water/feedback, world size, heavy lifter, fuel, economy,
  compact snapshots, public physics, repairs, purchase, fleet inspection/switching,
  resale and unconfigured friends menu pass. Diagnostics passes with its deliberate
  validation error.
- Local reconnect/actions and normal/impaired replication, cargo-network and
  connected-world: **16/16 process results pass**. Capacity at 2/10/25/50/100 clients,
  dispersed/crowded: **29/30 process results pass**; failure detailed below. These
  are local headless fixtures, not authenticated public refinery or production
  capacity evidence.
- Python AST parsing (**77 sources**), all existing UID byte comparisons, script
  sidecar presence and whitespace checks pass. No secrets, accounts, databases,
  generated evidence, caches, engine binaries or exports are committed.

### Remaining failures and unrun gates

Collision fails its lateral-contact assertion; composition fails two side-course
contacts. Shared gauges/wear pass **3/10 assertions** then reach the 65-second
headless rendered-frame wait timeout. Ports reaches **261 passing checks** but
emits two out-of-tree transform errors. These reproduce previously documented
Linux limitations and are not clean passes; no physics/condition/gauge code changed.
The capacity observer at **100 dispersed clients** fails `Observer has no unbounded
motion jump` (maximum presentation speed 28.63 m/s). All server/bot processes and
other capacity observers pass. This observer assertion also failed intermittently
in earlier recorded steps; no networking implementation changed in this branch.
The capacity sweep is not reported as a clean pass.

- **Windows:** pinned PowerShell suite, native integration runners, Debug/Release
  client/server exports, exported refinery panel/resource loading, launcher/clock
  shutdown behavior and save/UID compatibility. No Windows runtime here.
- **PostgreSQL/HTTPS:** no PostgreSQL server/client or configured integration stack
  in this environment. Step 75/76's real SQL concurrency/crash/restart runner was
  not rerun. New refinery durability is proven only in private SQLite; public
  shared stock, multi-server processing/withdrawal and PostgreSQL refinery
  transactions belong to Step 78. Production deployment, upgrade, backup/restore,
  external TLS and live-host recovery remain unrun.
- **Keycloak/authenticated peers:** native sign-in, real account/provider enrollment,
  public oil/refinery admission, two-account public ownership/fencing, reconnect
  and server handoff. Java exists but no configured identity stack/accounts or
  public refinery endpoint. Loopback private-fixture tests do not close this gate.
- **Visual/Andy playtest:** rendered combined panel layout, scrolling/focus/scaling,
  quantity/yield/fraction/retry readability, actual sailing/docking, input release,
  unchanged ship/HUD behavior and refinery pacing. No manual rendered playtest;
  headless scene assertions do not establish visual acceptance.

Initial harness attempts: ordinary sandbox execution could not reach the Git
proxy; the network-enabled fetch succeeded. The first combined Python invocation
omitted the legacy test directory from PYTHONPATH, causing three import errors;
corrected discovery ran all 45 authority tests successfully. These attempts are
not counted as passes. No game implementation was changed to accommodate the
recorded legacy physics/rendering limitations.

Deliver as a **DRAFT PR against main**, not a push to main. No Step 78 completion,
live deployment or full Windows/public-authenticated/rendered acceptance claimed.

## Step 78 — Shared refinery stock (draft) — November 6, 2026

Task ID: `shared-refinery-stock`. Based on merged Step 77 main **fca60e2**, branch
`feat/step-78-shared-refinery-stock`. Read AGENTS.md, CLOUD_HANDOFF.md, latest
progress/decisions, FEATURE_INVENTORY.md, DEFERRED_PLAYER_REQUESTS.md and original
roadmap Step 78. The initial checkout stopped at Step 70; fetched current main
before implementation. Implemented ONLY Step 78. D135 and SHARED_REFINERY_STOCK.md
record ownership, durable transactions, clock/restart policy, quotes and boundaries.

Added an additive PostgreSQL `public_authority.refineries` table keyed by stable
physical refinery ID. Public replicas share this database alongside canonical
profiles, receipts, leases and treasury. Account-owned stock and fractional carry
remain isolated within the shared facility; no player transfers/gifts. Submission
atomically consumes owned canonical crude and saves its job/cost/receipt. A saved
central-database completion deadline credits output once, including public downtime;
multiple servers never add independent ticks. Clock rollback clamps to saved high
water. Scene unload, account release/handoff and process death do not own stock.

Withdrawal uses a frozen, nonexpiring account/ship/port/quantity quote, with no stock
reservation. Proposed handling fee is 1 minor credit/barrel, ceiling once per
withdrawal; pricing is prototype tuning. Acceptance rechecks stock/funds/revision
and atomically commits stock removal, wallet/treasury, quote consumption, durable
`awaiting_loading` collection allocation, receipt and journal. Retry returns the
original receipt; changed intent conflicts. Reconnect/handoff may change authority
generation without changing action identity. Public transport fails closed with
uncertain mutation outcomes; no local fallback, private import or client credit API.

Collection allocations remain refinery custody. They are not aboard/saleable cargo
and have no loading/transport/sale/refund endpoint. Step 79 must consume them
atomically when loading is implemented. The Step 77 private UI/save fixture remains
unchanged; a new explicitly created private stock adapter shares the transaction
model but uses isolated SQLite and host-active time only. No save reset/conversion,
public playable oil hull, new public Godot RPC, deferred feature or deployment.
Bounded ledgers retain deduplication identities and reject at exhaustion. Missing or
corrupt established refinery state fails rather than reseeding. The hosting bundle
now includes the refinery package/schema needed by the authority import.

Godot remains **4.7.2**, game/ticket protocols **17/7**. All **169 existing .gd.uid**
files are byte-identical; no new Godot resources or export roots are needed. Preserve
one condition, nonexpiring cargo jobs, no player transfers/trades/gifts, no machinery
wear and no hidden shallows.

### Linux checks actually run

Exact `4.7.2.stable.official.ed1daf0bf`, psycopg/binary **3.2.10**, cryptography and
isolated PostgreSQL **17.11**. PostgreSQL packages were downloaded/extracted into
`/workspace/work/step78`, without installing/replacing system services. All databases,
engine, dependencies, TLS keys, fixture accounts, harnesses and logs stay outside Git.
No live saves, production accounts, external server or running dedicated host touched.

- **45 refinery/oil Python tests pass:** 9 new shared-stock tests, 11 Step 77 and
  25 oil tests. New cases cover two-process competing and identical withdrawals,
  changed intent, receipt recovery across generation changes, ownership/private
  isolation, fractional carry, public deadline idempotence/backward-clock clamp,
  private paused restart, bounds/refilled capacity/history exhaustion, malformed
  requests/state, insufficient funds, rollback at each write and lost committed
  replies. Six owned SQLite subprocess deaths cover before/after submission,
  completion and withdrawal COMMIT, with exact durable recovery.
- **Real PostgreSQL/HTTPS shared refinery runner passes**, using two service replicas,
  two public-server client processes, two approved server identities/accounts and
  a separate private-host process with actual private output. Both public servers
  observe the same facility; owned balances remain isolated. Identical concurrent
  withdrawals produce one debit/collection; distinct quotes/action IDs cannot spend
  the same stock. A different server cannot bypass the account lease.
- The real SQL runner forces **six service process deaths** immediately before/after
  submission, completion and withdrawal COMMIT. Reopen/retry verifies rollback or
  retained transitions without duplicate output/withdrawal. Stopping all services
  during processing, initializer replay, PostgreSQL outage/restart, handoff fencing,
  original receipt recovery, treasury conservation and missing-row no-reseed checks
  pass. These are real PostgreSQL transactions, not SQL doubles.
- **Existing real PostgreSQL oil integration runner passes**, including concurrent
  two-server settlement/replay, four forced write/COMMIT crashes, rebind/handoff,
  database/service outage/restart, contiguous history, lot costs and conserved money.
- All **45 existing Python authority tests** pass. Production route benchmark and
  all three Step 67 progression scenarios pass with replay and reload equivalence.
- Existing actual Godot/HTTP/private SQLite oil and refinery panels each pass
  **26 assertions**. Liquid recovery **13**, bulk **15**, gas **15** portable phases
  pass, including four process kills per family. Bulk capacity **102**, earnings
  **330**, gas capacity **108** pass. All **28** legacy storage/persistence/migration/
  durable-recovery phases pass, including **ten** owned-process kills and backup/UI.
- Voyage suite **101**, round-trip/two reopens and ten ordered crash/recovery phases
  pass (four intentional process deaths). Sailing-save **330 checkpoints**, slots
  and unconfigured friends menu pass.
- Clean editor/import, all **169-script** loading and Main startup pass. Catalog,
  controls, application flow, starter assets, units, contracts, geography, session,
  clocks, handling, camera, water/feedback, world size, heavy lifter, fuel, economy,
  compact snapshots, public physics, repairs, purchase, fleet inspection/switching
  and resale pass. Diagnostics passes with its deliberate validation message.
- Local reconnect/actions and normal/impaired replication, cargo-network and
  connected-world: **16/16 process results pass**.
  Capacity fixtures at 2/10/25/50/100 clients, dispersed and crowded, pass
  **30/30 process results** in this run. These local headless fixtures are not a
  production capacity or authenticated refinery load claim.
- Python AST parsing (**83 sources**), existing UID byte comparisons, script sidecar
  presence and whitespace checks pass. No generated evidence, databases, secrets,
  caches, engine binaries or exports are included in the change.

### Remaining failures and unrun gates

Collision fails lateral contact and composition fails its two side-course contacts.
Shared gauges/wear hit their 65-second headless rendered-frame wait timeouts; ports
emits two out-of-tree transform errors despite successful assertions. These reproduce
previously recorded Linux limitations; they are not clean passes. No physics,
condition, gauges, networking or scene implementation changed.

- **Windows:** pinned PowerShell/native runners, Debug/Release client/server exports,
  hosting-bundle execution and Windows clock/restart/save compatibility. No Windows
  runtime is available here.
- **PostgreSQL/deployment:** local real SQL contention, crash and restart checks ran.
  Production upgrade/backup/restore/failover, provider-managed PostgreSQL, WAN TLS,
  external multi-host networking and production load/long-history throughput remain
  unrun. Fixture tests do not prove deployed durability or backup consistency.
- **Keycloak/authenticated game peers:** no configured identity stack/accounts or
  native login flow here. Real OIDC enrollment/sign-in, public Godot oil/refinery
  service admission, rendered two-player reconnect/handoff and full-voyage public
  integration remain unrun. The SQL runner uses operator-created fixture identities
  and approved-server HTTPS credentials, not Keycloak users.
- **Visual/Andy playtest:** no rendered/manual acceptance of refinery layout,
  quantity/fee/retry readability, pacing, sailing/docking, focus/input or ship/HUD
  behavior. The existing private panel assertions do not establish visual acceptance;
  Step 78 adds service/storage contracts, not Step 79 loading UI.

Initial attempts corrected: ordinary sandbox Git/import could not use the proxy/
listen sockets; network-enabled commands succeeded. Python discovery with `-t .`
cannot discover these namespace-package directories; explicit module runs passed.
The first SQLite crash test reused its setup action ID; corrected the test identities.
The expanded second-account SQL fixture initially used the pre-submission revision
for a foreign-quote check; corrected the fixture revision. Scratch legacy recovery
and friends-menu invocations used the wrong proof path/flag; corrected runs passed.
These attempts are not counted as successful checks and required no game changes.

Deliver as a **DRAFT PR against main**, not a push to main. Step 79 remains unstarted;
no complete Windows/Keycloak/rendered acceptance or live deployment is claimed.

## Step 79 — Cargo fuel transport and sale — November 6, 2026

Task ID: `cargo-fuel-transport-and-sale`.
Status: implemented and verified in the shared transaction service and private
Godot voyage fixture; Windows, public-game/authentication and visual gates below
remain open. Based on merged Step 78 (`7dfed8f`), on feature branch
`feature/cargo-fuel-transport-and-sale`. No Step 80 or deferred feature work.

Added atomic partial loading of Step 78 refinery collections into canonical
`cargo_fuel` aboard lots, and partial sales through Brindle's eligible pipeline.
Slatewater retains uncollected fractions. The fixture hull has a separate 200000
millibarrel cargo capacity and one aboard commodity lot. Acquisition records retain
refinery/collection/ship provenance, quantity, allocated handling cost and a frozen
prototype sale price of 220 minor credits/barrel. Cumulative integer rounding
conserves gross proceeds and allocated handling fees across partial sales. Crude
production costs remain in processing records, never presented as handling cost or
claimed net profit. Recovery debt repayment is separate from sale gross/wallet change.

Stock custody, cargo, wallet/treasury, receipt and public journal use the existing
fenced transaction. Exact retries survive changed berth, restart and account handoff;
changed action intent conflicts. New actions fail closed on stale revision, bad
quantity, capacity/ownership/recovery errors or bounded history exhaustion. Cargo
fuel operations never modify the ship's propulsion tank. Existing collection rows
need no reset; terminal loaded state requires compatible service versions.

The actual Godot fixture has a crude/cargo-fuel commodity selector, fractional
quantity input, quote review/acceptance, load/sell choices, authoritative stock and
aboard summary, and explicit identical-request retry. Private position/yaw/fuel/
condition checkpoints resume in neutral, stopped and undocked, without offline
motion. Corrupt/unavailable resume fences the fixture. The new `--cargo-fuel` launcher
uses a new isolated shared-stock file; existing Step 77 fixtures are not converted.
See D136 and CARGO_FUEL_TRANSPORT.md for arithmetic, API/lifecycle and reproduction.

### Linux checks actually run

Pinned **4.7.2.stable.official.ed1daf0bf**, isolated psycopg/binary **3.2.10**,
cryptography and extracted PostgreSQL **17.11**. All engines, scratch harnesses,
logs, isolated settings/saves, fixture identities, keys and databases are under
`/workspace/work/step79`, outside Git. No live service or player save was touched.

- **51 refinery/oil Python tests pass:** six new cargo-fuel tests plus all 45 existing
  tests. New tests cover the full 20000 → 22330 wallet example, fragmented sales,
  partial loads and fee conservation, unchanged propulsion quantity, reopen/replay,
  ownership/port/capacity/invalid quantity rejection, recovery/debt, corrupted lot
  rejection, history exhaustion and private navigation validation/reopen. Concurrent
  identical load/sale requests have one effect. Rollback at profile/refinery writes
  and COMMIT preserves prior state. Four owned SQLite subprocess deaths immediately
  before/after load/sale COMMIT recover exactly once.
- **Actual Godot/HTTP/SQLite cargo-fuel voyage passes across two processes:** first
  launch 9 assertions loads and saves underway; second launch 16 assertions restores
  position/propulsion/aboard quantity, performs partial sales, injects a lost committed
  response and retries after berth loss. Final wallet adds exactly 462 minor credits
  to the saved post-purchase/fee balance for 2100 millibarrels sold. Propulsion fuel
  is unchanged by both sales. The probe sets berth/underway positions; it does not
  claim manual sailing, rendering or public full-voyage acceptance.
- Existing actual oil/refinery Godot panels each pass **26 assertions**.
- **New real PostgreSQL/HTTPS cargo-fuel runner passes:** two service replicas,
  approved-server identities and canonical account lease. Four forced service deaths
  before/after load/sale COMMIT prove atomic rollback or durable receipt recovery.
  Concurrent identical retries retain one public journal entry, another server is
  fenced, wallet receives exactly 154 for 700 millibarrels, and propulsion stays
  321.5 liters. Database outage/restart and account handoff/replay pass.
- **Existing Step 78 real PostgreSQL refinery runner passes**, including shared
  stock/ownership, private isolation, contention, six service COMMIT crashes,
  processing while services are stopped, database outage/restart, handoff fencing,
  treasury conservation and missing-state rejection. **Existing real SQL oil runner
  passes**, including two-server settlement, four write/COMMIT deaths, retry/handoff,
  outage/restart, contiguous history and conserved money.
- All **45 existing Python authority tests** pass. Production route benchmark and
  all three progression scenarios pass with replay/serialized-reload equivalence.
- Oil inventory **13**, bulk **15**, gas **15** portable recovery phases pass,
  including four owned-process deaths per family. Bulk capacity **102**, earnings
  **330**, gas capacity **108** pass. All **28** storage/persistence/migration/
  durable-action recovery phases pass, with ten owned-process deaths and backup/UI.
- Voyage suite **101**, round trip plus two reopens, and all ten ordered crash/
  recovery phases pass (four intentional self-kills). Sailing-save **330 checkpoints**,
  slots **38**, and unconfigured friends menu pass.
- Editor/import, all **171 scripts**, and Main startup pass. Catalog, controls,
  flow, starter assets, units, contracts, geography, session/clocks, handling, camera,
  water/feedback, world size, heavy lifter, fuel, economy, compact snapshots, public
  physics, repairs, purchase, fleet inspection/switching and resale pass. Diagnostics
  passes with its deliberately invalid reference message.
- Local reconnect/actions and normal/impaired replication, cargo-network and
  connected-world: **16/16 process results pass**. Capacity at 2/10/25/50/100 clients,
  dispersed/crowded: **30/30 process results pass**. These are local headless fixture
  results, not production authenticated-player capacity evidence.
- Python AST parsing (**86 sources**), all **169 existing UID** byte comparisons,
  new script sidecars and whitespace checks pass. Runtime panel is an explicit export
  root. No caches, databases, credentials, binaries or exports are committed.

### Remaining failures and unrun gates

Collision still fails the lateral-contact assertion; composition still fails its
two side-course contacts. Shared gauges and wear reach the 65-second headless
rendered-frame wait timeout. Ports has 261 passing checks but emits two out-of-tree
transform errors. These match the prior recorded Linux limitations and are **not**
clean passes. No physics, condition, gauges or network implementation was changed.

- **Windows:** pinned PowerShell/native suites; Debug/Release client/server exports;
  exported panel/resource loading; hosting bundle/launcher; Windows clock, save and
  resume compatibility. This environment has no Windows runtime.
- **PostgreSQL/deployment:** local real SQL checks ran. Production upgrade, compatible
  mixed-version rollout, backup/restore/failover, provider-managed storage, WAN TLS,
  external multi-host operation and long-history/load behavior remain unrun. The
  10000-action bound is an explicit prototype limit, not production retention.
- **Keycloak/public game:** no configured identity stack or native account sign-in.
  OIDC enrollment/login, authenticated public Godot oil/fuel hull admission, actual
  public pipeline RPC routing, two-player rendered voyage/reconnect/handoff and fuel
  hull sinking/recovery remain gates. Approved-server HTTPS fixtures are not real
  Keycloak players; no new public playable hull is claimed.
- **Visual/Andy playtest:** commodity menu layout/scroll/focus/scaling, fractional
  quantity and fee/price/retry readability, actual sailing/docking, resumed placement,
  input release, unchanged HUD/ship behavior and pacing. Headless boundary probes
  do not constitute a manual rendered playtest.

Corrected harness attempts: initial sandbox import lacked socket/settings access;
rerun with isolated settings and loopback access passed. The first Godot sale
assertion assumed a fixed crude purchase price; the market had moved, so it now
checks the accepted saved balance plus exact sale proceeds. The first legacy
recovery invocation used `recovery-proof` rather than required `action-recovery`;
corrected eight phases passed. Friends-menu attempts omitted the actual
`--friends-client` flag; corrected invocation passed. These initial attempts are
not counted as passes and required no legacy game behavior changes.

Delivery: feature-branch commit and **draft PR against main**. No push to main,
live deployment, Step 80 completion, or Windows/Keycloak/visual acceptance claimed.

## Step 80 — Heavy-load jobs (draft) — November 6, 2026

Task ID: `heavy-load-jobs`. Branch `feat/step-80-heavy-load-jobs`, based on merged
Step 79 main **4cf4c73**. Read AGENTS.md, CLOUD_HANDOFF.md, current progress and
decisions, FEATURE_INVENTORY.md, DEFERRED_PLAYER_REQUESTS.md, U030/dependencies and
original roadmap Step 80. Fetched current main before implementation. Only Step 80
is implemented; D137 and HEAVY_LOAD_JOBS.md record scope, API and lifecycle.

Added `services/heavy_load/private.py`: a durable private-world job authority using
the existing private SQLite profile/wallet contract. One stable simple block,
one allowed lifter type (`ship_heavy_lifter_01`), immutable reward/zone terms,
nonexpiring account/ship claims and exclusive pickup/delivery reservations.
Competing lifter instances share one world database; different private worlds
remain isolated. No global public payload ownership is inferred from shared oil.

Claim, canonical profile job, zone reservations, cancellation, terminal delivery,
wallet/recovery debt and exact-intent receipt share one transaction. Cancel before
pickup releases without payment; carrying cancellation rejects. Delivered payloads
remain consumed. Retry/reconnect returns receipts/state without another reward.
Changed action reuse conflicts; stale cancellations cannot release a newer claim.
Missing storage, incompatible realm/definition or exhausted bounded history fails
closed. Explicit creation cannot overwrite an existing file. No live saves touched.

This is a callable job-authority slice, **not a new playable heavy voyage**.
Historical Port Test heavy jobs/saves remain unchanged and do not yet call this
adapter. Pickup/delivery take trusted-host attestation; clients cannot put it in
intent. Physical validation/controls remain Step 81; attachment, release,
sinking/despawn reconciliation and integration remain Step 82; presentation and
variants remain Step 83. No new public endpoint, player hull, machinery wear,
player transfer, expiring offer, hidden shallows or deferred feature. Godot remains
4.7.2; game/ticket protocols remain 17/7. No GDScript, UID, resource/export root or
original reference file changed.

### Linux checks actually run

Exact **4.7.2.stable.official.ed1daf0bf**, isolated Python psycopg/binary **3.2.10**,
cryptography and extracted PostgreSQL **17.11**. Engines, databases, private fixture
credentials, settings, scratch runners and logs are under `/workspace/work/step80`,
outside Git. The preinstalled Godot 4.6.3 was inspected but not used for checks.

- **10 new heavy authority tests pass.** 32 competing requests and **12 separate
  host processes** yield one claim; 32 identical delivery retries yield one payment.
  Covers cancellation/reclaim/stale actions, reconnect, zone contention, allowed
  hull/ownership/account/realm/revision checks, unchanged propulsion fuel, recovery
  debt, history bounds, missing storage and incompatible saved definitions.
  Rollback at job/profile writes and before COMMIT leaves state unchanged. **Eight
  owned subprocess exits** before/after claim, cancel, pickup and delivery COMMIT
  prove durable recovery; a committed lost reply recovers the original receipt.
- All **51 existing oil/refinery Python tests** and **45 authority tests** pass.
  Production route benchmark and all three progression/reload scenarios pass.
- All three **real PostgreSQL/HTTPS** regression runners pass: oil settlement,
  shared refinery and cargo-fuel voyage. Includes multi-service contention,
  transaction/service deaths, outage/restart, fencing/handoff, exact replay,
  conserved settlement and unchanged cargo-fuel propulsion. These exercise existing
  public adapters; they do not establish public heavy-job support.
- Actual Godot/HTTP/private SQLite interfaces: oil **26**, refinery **26**,
  cargo-fuel first process **9** and resumed sale process **16** assertions pass.
- Oil inventory **13**, bulk **15**, gas **15** portable phases pass, including
  their owned-process crash/recovery cases. Bulk capacity **102**, earnings **330**,
  gas capacity **108** pass. All **28** legacy storage/persistence/migration/action
  recovery phases pass, including ten owned-process terminations and backup/UI.
- Voyage suite **101**, round trip with two reopens, and ten ordered recovery
  phases pass (four intentional self-kills verified by fault files and subsequent
  recovery). Sailing-save **330 checkpoints**, slots **38**, friends menu pass.
- Editor/import, all **171 scripts**, Main startup, catalog, controls, application
  flow, starter assets, units, contracts, geography, session/clocks, handling,
  camera, water/feedback, world size, heavy lifter, fuel, economy, compact snapshots,
  public physics, repairs, purchase, fleet inspection/switching and resale pass.
  Diagnostics passes with its intentionally invalid-reference error.
- Python AST parsing **88 sources**, existing UID/reference preservation and
  whitespace checks pass. No databases, binaries, caches, exports or secrets added.

### Remaining platform and integration gates

Collision fails its lateral-contact assertion; composition fails two side-course
contacts. Shared gauges and wear reach the 65-second headless rendered-frame wait
timeout. Ports reaches **261** passing assertions but emits two out-of-tree transform
errors. These reproduce previously recorded limitations and are **not clean passes**.
No physics, condition, gauge or networking implementation changed in this branch.

- **Windows:** pinned PowerShell/native suite, Debug/Release exports, launcher and
  hosting bundle, runtime/save compatibility. No Windows runtime is available.
- **PostgreSQL:** existing local SQL regressions ran. A heavy-job PostgreSQL/public
  adapter is not implemented or tested. Production migration, mixed-version rollout,
  backup/restore/failover, multi-host/WAN deployment and long-history/load behavior
  remain unrun. Private-world SQLite evidence cannot close these gates.
- **Keycloak/public peers:** no configured native OIDC enrollment/sign-in stack;
  public heavy admission/RPC, two-player heavy reconnect and public server handoff
  remain unrun/unimplemented. Trusted service HTTPS fixtures are not Keycloak players.
- **Visual/Andy playtest:** no rendered manual acceptance. Physical block placement,
  lifter pickup/attachment, sailing, release, waypoint/UI readability and pacing
  remain the later control/lifecycle/presentation gates. This service-only step
  does not assert a complete player voyage or upgrade historical Port Test saves.

Harness corrections: initial sandbox import could not open its editor socket;
rerun with loopback permission and isolated settings passed. Initial authority
unittest discovery pointed at the source directory and discovered zero tests;
corrected discovery ran all 45. Initial storage runner supplied a short fixture ID
instead of the required 32 hexadecimal characters; all 28 corrected phases passed.
The generic exit-code summary marked intentional voyage SIGKILL cases as false;
the original runner's fault-marker/recovery criteria confirm all four expected
kills. None of those initial attempts is counted as a clean pass.

Network results: initial reconnect/actions plus normal/impaired replication,
cargo-network and connected-world run passed **13/16** process results. Normal
replication failed host guard and client motion assertions; impaired replication
failed client motion/acknowledgement timing. Initial capacity sweep (2/10/25/50/100,
dispersed/crowded) passed **28/30**: both 50-client observers failed motion bounds;
all server/bot processes passed. These ran alongside other Linux regressions.
After those finished, rerunning both replication profiles and both 50-client layouts
passed **10/10** process results. Retain the initial failures as timing instability;
do not label the initial sweeps clean or claim production capacity. No network code
was changed to obtain the rerun results. Private authenticated identity/reconnect
also passes **70 starter / 74 heavy** assertions using isolated loopback processes.
This tests existing private identity, not a public heavy-job or physical integration.

Delivery: feature-branch commit and **draft PR against main**, no push to main.
No live deployment, Step 81–83 completion, Windows/Keycloak/visual acceptance or
public heavy-job adapter is claimed.

## Step 81 — Lifter submerge controls (draft) — November 6, 2026

Task ID: `lifter-submerge-controls`. Branch
`feat/step-81-lifter-submerge-controls`, based on merged Step 80 main **6e97cd7**.
Read AGENTS.md, CLOUD_HANDOFF.md, latest progress/decisions, FEATURE_INVENTORY.md,
DEFERRED_PLAYER_REQUESTS.md and original roadmap Step 81. Implemented only Step 81.

Extended the existing test lifter's Lower/Raise controls and controlled attachment.
Pickup now rejects residual yaw, active thrusters and paused simulation as well as
motion, throttle, an operating deck and a deck above its lower stop. Every staged
payload is validated on Raise from the lower stop, including distant payloads:
out-of-tolerance raises provide feedback without changing the deck target,
attachment or collision ownership. Previously, distant payloads silently allowed
an empty raise. Inactive/delivered payloads still allow empty raising. Updated
release feedback to match this deliberate behavior.

Preserved inclusive local-frame centre tolerances (9/24/2 m lateral/longitudinal/
vertical) and unrestricted heading for crooked loads. Successful pickup uses the
existing fixed cargo mount and sole carrier collision shape; floating collision
is disabled, with no unconstrained stacked rigid bodies. Existing swept-clearance
checks and visible controls remain. Deck advancement ignores invalid time deltas
and paused simulation. D138 records these rules and the Step 82 boundary.

Godot remains **4.7.2**, game/ticket protocols **17/7**. All **171 .gd.uid** files
are byte-identical and all script sidecars are present. No new resource/export root,
new hull, machinery wear, player transfer, expiry, hidden shallows, save migration,
public endpoint or Step 82 work. Step 80's durable HeavyStore is not wired to this
physical fixture here; full heavy transport lifecycle remains a separate gate.

### Linux checks actually run

Exact **4.7.2.stable.official.ed1daf0bf**, isolated Python environment with
psycopg/binary **3.2.10**. Downloaded engine, test harnesses, logs, settings and
isolated databases remain in `/workspace/work/step81`, outside Git.

- **65 lifter assertions pass**, including six just-outside tolerance faces,
  distant payload rejection without mutation, inclusive boundaries, translated/
  rotated carrier frames, residual yaw/thruster rejection, pause, invalid deltas,
  busy-deck reversal, manual stern-first pickup, crooked Raise, duplicate prevention,
  single collision ownership, obstruction/resume, fixed attachment through real
  sailing/turning, release and visible Lower/staging/Raise controls.
- **61 Python service tests pass** (10 heavy plus 51 oil/refinery/cargo-fuel),
  including existing contention, retry, rollback and owned-process crash cases.
  All **45 Python authority tests pass**; SQL doubles are not real PostgreSQL proof.
- Editor import, all **171 script loads**, Main startup, catalog, controls,
  application flow and starter asset checks pass. Units **50**, contracts **66**,
  geography **342**, session **21**, clocks **22**, handling **134**, camera **20**,
  water **59**, feedback **24**, world-size **2042**, fuel **42**, economy **82**,
  compact snapshots **24** and public physics **43** pass.
- Historical voyage suite **101**, sailing-save **330 checkpoints**, slots **38**,
  bulk capacity **102**, bulk earnings **330**, gas capacity **108**, repairs **20**,
  purchase **35**, fleet inspection **32**, fleet switch **34** and resale **26** pass.
- Portable oil inventory **13**, bulk **15** and gas **15** recovery phases pass,
  including each family's four owned-process kills and subsequent reopen checks.
- Python AST parsing **88 sources**, UID byte preservation, sidecar presence and
  `git diff --check` pass. No engine, generated evidence, secret, account, database,
  export or cache is included in the commit.

Local network sweep: **14/16 process results pass**. Reconnect identity agreement,
actions, normal/impaired heavy-cargo replication and normal/impaired connected-world
checks pass. Both replication hosts pass; normal and impaired replication clients
fail `Buffered remote motion stays bounded`. This matches prior replication timing
instability, but this sweep is not clean and no rerun is substituted for its results.
No networking implementation changed. These are loopback fixtures, not authenticated
public heavy support or production capacity. The large-client capacity sweep,
legacy Windows persistence orchestration and full service/HTTPS interface runners
were not rerun for this control-only change.

### Failures, harness corrections and unrun gates

Collision fails its lateral-contact assertion; composition fails two side-course
contacts. Ports reports **261** passing assertions but emits two out-of-tree
transform errors. Shared gauges passes three assertions and wear passes ten before
both reach the **65-second** headless rendered-frame timeout. These match the
previously recorded Linux limitations and are **not clean passes**.

Initial sandbox import reported socket/settings errors; rerunning with loopback
permission and precreated isolated settings passed. Initial Python service discovery
found zero tests (namespace directories); explicit module selection ran all 61.
Initial authority discovery lacked psycopg; isolated dependency installation and
rerun passed all 45. These initial attempts are not counted as successful checks.

- **Windows:** pinned PowerShell/native suite, Debug/Release client/server exports,
  exported lifter resource loading, launcher/hosting bundle, save/UID compatibility
  and controls on Windows remain unrun; no Windows runtime or PowerShell here.
- **PostgreSQL:** no PostgreSQL server/client or configured integration stack here;
  real SQL/HTTPS regression runners were not rerun. Heavy-job public SQL adapter,
  production migration, backup/restore/failover, multi-host deployment and live
  recovery remain unimplemented/unrun. No live database/server was touched.
- **Keycloak/public peers:** no configured OIDC stack/accounts; native enrollment,
  sign-in, authenticated public heavy admission, two-player pickup/reconnect and
  server handoff remain unrun. Local fixtures cannot close this gate.
- **Visual/Andy playtest:** rendered Lower/Raise feedback, crooked block placement,
  keyboard/mouse focus, scaling, obstruction readability, sailing/docking and
  subjective tolerances/pacing still need manual acceptance. Headless assertions
  do not establish visual acceptance.

Deliver as a **draft PR against main** from the feature branch. No push to main,
live deployment, Step 82 completion or full Windows/SQL/Keycloak/visual acceptance.

## Step 82 — Heavy transport lifecycle (draft) — November 6, 2026

Task ID: `heavy-transport-lifecycle`. Feature branch
`feat/step-82-heavy-transport-lifecycle`, based on merged Step 81 **c9463e1**.
Read AGENTS.md, CLOUD_HANDOFF.md, latest progress/decisions, FEATURE_INVENTORY.md,
DEFERRED_PLAYER_REQUESTS.md, U030/dependencies and original roadmap Step 82.
Fetched current main before implementation. Only Step 82 is implemented.

Connected Step 80's private HeavyStore to the actual Step 81 lifter via an explicit
owned-process Godot/loopback HTTP/private SQLite fixture. Pickup commits custody
and navigation before attaching; lowered/stationary offshore delivery commits the
reward, job, release and receipt together. Unknown replies freeze play for exact
retry; canonical snapshots rebuild the scene without applying receipt money again.
Periodic revision-guarded navigation persists position/yaw, fuel, single condition
and deck height/target. Reconnect retains the same stable job/payload, stopped and
neutral, with no offline motion. Corrupt/missing/inconsistent state fails closed.

Added opt-in loaded acceleration scaling (100 t block / 1000 t empty prototype)
and 0.5 m visual hull draft. Retain fixed cargo mount, disabled floating collision
and the sole carrier payload shape; no unconstrained rigid-body stacking. Historical
fixtures keep zero mass tuning and existing saves. Requested despawn rejects active
jobs; disconnect/scene teardown retains the last committed voyage. Destruction at
zero condition atomically fails and permanently consumes the payload, releases zones
and pays zero. Hull ownership/zero condition remain; no free repair or replacement.
D139 and HEAVY_TRANSPORT_LIFECYCLE.md document this policy and reproduction.

No public heavy endpoint/admission, Step 83 variants/guidance/presentation, old-save
conversion, machinery wear, hidden shallows, expiry or player transfer. One active
nonexpiring job. Godot remains **4.7.2**, game/ticket protocols **17/7**. All **171
existing UID files** are byte-identical; two new script sidecars are included and
the new runtime scene is an explicit export root. Original references unchanged.
No database, credential, engine, export, cache or evidence artifact is committed.

### Linux checks actually run

Pinned **4.7.2.stable.official.ed1daf0bf**, isolated Python psycopg/binary **3.2.10**
and cryptography. Scratch harnesses, binaries, settings, logs and disposable saves
are in `/workspace/work/step82`, outside Git. Preinstalled Godot 4.6.3 was not used.

- **65 Python service tests pass:** 14 heavy (10 existing + 4 lifecycle), plus all
  51 oil/refinery/cargo-fuel tests. All **45 authority tests pass**. After the final
  navigation consistency guard, all 14 heavy tests were rerun and pass. Covers
  atomic navigation/custody, 16 concurrent delivery retries, stale checkpoints,
  invalid numbers/fields, rollback, no healthy resurrection and six new owned
  subprocess exits before/after pickup, delivery and destruction commits, alongside
  Step 80's contention and eight process-death cases.
- Actual new Godot/HTTP/SQLite lifecycle probes: **11 carry / 9 deliver / 4 terminal
  reopen** checks pass across three processes, including an intentionally lost
  committed delivery reply, frozen custody and exact retry. Separate new world:
  **11 carry / 4 destroy / 5 failed-reopen** pass. Proves stable IDs, saved loaded
  position, constrained attachment, loaded handling/draft, off-target release and
  active despawn rejection, terminal cleanup and no duplicate payment/respawn.
- Editor import, **173 script loads**, Main startup, catalog, controls, application
  flow, starter assets, units, contracts, geography, session/clocks, handling,
  camera, water/feedback, world size, **65 lifter assertions**, fuel, economy,
  compact snapshots and public physics pass. Diagnostics passes its intentional
  invalid-reference diagnostic. Bulk capacity/earnings, gas capacity, repairs,
  purchase, fleet inspection/switching, resale and friends menu pass.
- Historical voyage suite **101**, round trip with two reopens, and ten ordered
  crash/recovery phases pass (four expected SIGKILLs verified by fault markers).
  Sailing save **330 checkpoints**, corrected slots **38**, production route
  benchmark, and all **28** legacy storage/persistence/migration/action-recovery
  phases pass (ten owned-process terminations). Existing authority economy tests
  include progression/reload scenarios.
- Portable oil inventory **13**, bulk **15**, gas **15** recovery phases pass,
  including four owned-process kills per family. Actual existing Godot/HTTP/private
  SQLite interfaces pass: oil **26**, refinery **26**, cargo-fuel **9** first-process
  and **16** resumed-sale assertions.
- Local network sweep **16/16 process results pass**: identity rounds/actions,
  normal/impaired replication, cargo-network and connected-world. This is private
  loopback replication, not new public heavy-job support.
- Capacity sweep **30/30 process results pass** for 2/10/25/50/100 clients in
  dispersed/crowded layouts. These are headless local experiment checks, not
  production capacity or Windows CPU/memory acceptance.
- Python AST parsing, UID byte preservation/sidecar presence, reference preservation
  and `git diff --check` pass.

### Failures, harness corrections and unrun gates

Collision still fails lateral contact; composition fails its two side-course
contacts. Ports reaches **261** passing assertions but emits two out-of-tree
transform errors. Shared gauges passes three assertions and wear passes ten, then
both hit the **65-second** headless rendered-frame timeout. These match recorded
Linux limitations and are **not clean passes**; no shared physics/network/gauge
implementation was changed to hide them.

The first slots invocation omitted its required isolated-test proof flag; corrected
`--slots-proof` invocation passes. The first gauges/wear invocation incorrectly used
`--script` for Node scripts; corrected scene wrappers reach the timeouts above.
Neither initial harness attempt is counted as a pass. Initial private identity
starter run completed host assertions but emitted TLS handshake error **-30464**;
a second run with precreated settings directories passes **70 starter** assertions,
then the heavy host emits the same TLS error after its assertions and the strict
runner stops before recovery. Retain both errors; heavy authenticated identity is
**not a clean pass** and no public identity acceptance is claimed.

- **Windows:** PowerShell/native checks, Debug/Release client/server exports,
  exported resource loading, launcher/hosting bundle and Windows save/control/UID
  compatibility remain unrun; no Windows runtime here.
- **PostgreSQL:** no installed PostgreSQL server/client or configured integration
  stack. The three real SQL/HTTPS runners were not run; Python authority doubles
  and private SQLite do not substitute for them. Public heavy SQL adapter,
  production migration, mixed-version rollout, backup/restore/failover, live
  recovery and multi-host/WAN deployment remain unimplemented/unrun.
- **Keycloak/public peers:** no configured OIDC stack/accounts. Native sign-in,
  enrollment, authenticated public heavy admission/RPC, two-player heavy pickup/
  reconnect and public server handoff remain unrun. No live server touched.
- **Visual/Andy acceptance:** manual Lower/Raise/release and crooked pickup,
  visual draft/collision alignment, loaded handling/pacing, camera/input/focus,
  saved mid-deck travel and failure/retry readability remain unrun. Probe placement
  and fixed-step motion do not establish a manually sailed/rendered voyage.

Delivery is a feature-branch commit and **draft PR against main**, not a push to
main or live deployment. Step 83 and the platform/visual acceptance gates remain open.

## Step 83 — Heavy job presentation and variants (draft, UNVERIFIED) — November 11, 2026

Task ID: `heavy-job-presentation-and-variants`, from GitHub issue #23. Based on main
at **d69a709** (Step 82 merge b9a4f05 plus the Claude action commit). Read AGENTS.md,
CLOUD_HANDOFF.md, latest progress/decisions, DEFERRED_PLAYER_REQUESTS.md,
HEAVY_LOAD_JOBS.md, HEAVY_TRANSPORT_LIFECYCLE.md, HEAVY_LIFTER.md and original
roadmap Step 83. Only Step 83 is implemented.

**No automated or manual check of any kind ran for this step.** See "Checks" below.
Treat the whole entry as unverified source until the listed commands are run.

### Changes

- `services/heavy_load/private.py`: payload definitions `PAYLOADS` (block, 60 t
  compact module, 150 t long girder), `ENVELOPES` (label, size) and `LIFTERS` load
  limits (200000 kg, 14 x 8 x 32 m, 1.0 m draft). `payload_problems` /
  `definition_problems` check mass, envelope, draft, zone overlap and the
  +/-1000 m chart budget at import and on claim. Claim/pickup/deliver/destroy use
  the requested payload's own terms, zones and reward; evidence is bound to that
  payload. Snapshot adds `payloads` and `lifter`. Step 80 `TERMS` is unchanged.
- New worlds store the full definition set. Step 80-82 single-block worlds stay
  readable and offer only the block. No migration; other records fail closed.
- `features/handling/heavy_lifter.gd`: `configure_payload`, `load_within_limits`,
  `payload_pose`, `alignment`, `alignment_feedback`. Carrier box, floating collider,
  swept deck checks and visual scale follow `payload_size`; defaults remain the
  original block, so existing fixtures and saves are not retuned.
- `features/handling/heavy_transport_test.gd`: per-payload Claim offers, waypoint
  ring/marker and screen-edge pointer, distance/turn text, alignment offsets, load
  limit readout, state-change cues and a next-step line. All derived from the
  canonical snapshot; guards, commit order and evidence path are unchanged.
- `tools/heavy_transport_fixture.py` / `tools/heavy_transport_probe.gd`: evidence
  from the job's payload definition; new `--probe variants` mode.
- New `services/heavy_load/test_variants.py` (8 tests). New HEAVY_JOB_PRESENTATION.md,
  D140, and follow-through notes in the two earlier heavy docs.

Godot stays **4.7.2**; game/ticket protocols unchanged. No `.gd.uid` file was added,
removed or edited: no new script, scene or resource exists, so `export_presets.cfg`
needed no new entry and was not changed. Variants reuse `industrial_payload.glb`
scaled to the envelope as placeholder presentation. Original references untouched.
No database, credential, engine, export or cache is committed. No public heavy
endpoint, audio, new art, machinery wear, expiry, hidden shallows or player transfer.

### Known limitations by design

- The inherited block drop-off (Z -1800) is outside the +/-1000 m chart budget. It
  is an explicit exception in `CHART_EXCEPTIONS`, not a pass. New variants are inside.
- The fixture does no chart rebasing; variant behaviour across a real seam/pole
  transition is argued from the unchanged single-child/single-box arrangement only.
- Unclaimed payloads are not shown floating in the world; only the active job's
  load exists physically, as in Step 82.
- Limits, masses, zone positions and rewards are prototype tuning awaiting review.

### Checks

Nothing ran. This GitHub Actions runner denied every Python invocation
(`python -m unittest ...`, `python3 -m unittest ...`, `pytest`) and the download of
a Godot 4.7.2 Linux binary; only file edits and git were permitted. There is no
Godot on the runner. The new Python tests and all GDScript were checked by reading
only, which does not count as a pass. In particular:

- **Python (not run):** the 14 existing heavy tests, the 8 new variant tests and the
  51 oil/refinery/cargo-fuel tests. The existing heavy tests exercise code this step
  edited, so regressions there are possible and unmeasured.
- **Godot (not run):** editor import, script parse/load, the new `variants` probe,
  the Step 82 `carry`/`deliver`/`verify`/`destroy`/`failed` probes, the 65 lifter
  assertions and every other suite. `heavy_transport_test.gd` was largely rewritten
  and `heavy_lifter.gd` edited without a single parse; a GDScript error is possible.
- **Windows:** PowerShell/native checks, exports, exported resource loading: not run.
- **PostgreSQL / Keycloak / public peers:** not installed, not run, not applicable
  to this private fixture; no public heavy support exists.
- **Visuals / playtest:** ring, marker, pointer, colours, scaled payload model,
  readout length and the "complete a job without developer instructions" criterion
  are entirely unseen. No Andy acceptance is claimed.

### Handoff

Done (unverified): definitions, limits, rule checks, variant authority path,
presentation code, probe mode, tests and docs, on branch
`claude/issue-23-20261111-0025`. The requested name
`feat/step-83-heavy-job-presentation` could not be created: the action runner
denied branch creation. Rename or re-push under that name when opening the PR.
Nothing was pushed to main.

Next, in order:

1. `python -m unittest services.heavy_load.test_private services.heavy_load.test_transport services.heavy_load.test_variants -v`,
   then the full `services` test set. Fix anything red before going further.
2. With pinned Godot 4.7.2: import, script-load check, then
   `tools/heavy_transport_fixture.py --create --probe variants` on a new file and
   the five Step 82 probes. Expect to fix GDScript parse or typing errors first.
3. Run the lifter, voyage, cargo-network and connected-world suites, which share
   `heavy_lifter.gd`.
4. Record real results here and remove "UNVERIFIED" from the heading only then.
5. Manual visual pass of the guidance and a hand-sailed job per payload.
6. To let the Claude action run checks itself, add Python and a Godot 4.7.2 setup
   step to its `allowedTools`/workflow.

Step 84 (cargo compatibility matrix) should not start until 1-3 pass.

## Step 84 — Cargo compatibility matrix (draft, UNVERIFIED) — November 11, 2026

Task ID: `cargo-compatibility-matrix`, from GitHub issue #25. Based on main at
**11ecd77** (Step 83 merge). Read AGENTS.md, CLOUD_HANDOFF.md, latest progress and
decisions, FEATURE_INVENTORY.md, DEFERRED_PLAYER_REQUESTS.md and original roadmap
Step 84. Only Step 84 is implemented.

Step 83's handoff said this step should wait for Step 83's checks. Issue #25 asked
for it anyway, and Step 83's Python and Godot checks are **still unrun**. This step
builds on unverified Step 83 heavy code.

**No automated or manual check of any kind ran for this step.** See "Checks".
The "Done when" criterion (each family completes its own voyage without breaking
another) is written as tests but is **not demonstrated** until they run.

### Changes

- New `services/test_cargo_matrix.py` (3 tests). A test-only `World` class puts
  the heavy tables beside the oil/refinery tables in one isolated SQLite file, so
  oil, cargo fuel and heavy lifting share one profile, wallet and revision.
  - Hull x service matrix: container, bulk, gas, lifter and oil hulls against oil
    purchase, cargo-fuel loading and heavy claim; each wrong cell must return its
    own refusal code and leave all eight tables unchanged.
  - One world, three voyages in sequence (cargo fuel, oil, heavy), then oil again.
    Covers partial quantities, full oil capacity (200 barrels), over-quantity,
    faults before/after commit, duplicate actions, rounding (partial cargo-fuel
    sales total 15400; partial oil cost allocation equals the purchase), another
    family's unfinished cargo refused as `CARGO_BUSY`, and one wallet seen
    identically through the oil, refinery and heavy snapshots.
  - An oil action ID reused by a refinery action is `ID_CONFLICT`.
- New `tools/cargo_matrix_probe.gd` for the GDScript authorities: every family
  hull against every family cargo in the manifest; per-family full capacity,
  one-over, partial remove/refill, repeated batch IDs, bad quantities/units and
  claiming another family's compartment; a container job voyage (wrong ship,
  release before loading, duplicate accept/load/delivery, exact-fit capacity);
  bulk and gas voyages through the shared service (cancelled load, four partial
  discharges whose payments must equal the frozen quote, duplicate settlement,
  over-discharge, checkpoints not interchangeable between families); gas terminal
  and quay service cells; an oil lot voyage with partial sales and replays.
- Family rules split out of shared code, with check order and messages kept:
  - new `features/cargo/bulk_rules.gd`: bulk hold row rule, out of `cargo_manifest.gd`;
  - `GasRules.manifest_row_error`: gas tank row rule, out of `cargo_manifest.gd`;
  - `GasRules.job_transfer_error`: gas terminal/pipeline choice, out of `bulk_service.gd`.
- D141 in DECISIONS.md.

Godot stays **4.7.2**; game/ticket protocols, save formats and all stored keys are
unchanged. `export_presets.cfg` gains `res://features/cargo/bulk_rules.gd`. No
service or authority behaviour was intentionally changed. No database, credential,
engine, export or cache is committed. Original references and `.github/workflows`
untouched. No machinery wear, expiry, hidden shallows, player transfer or second
active job.

### Known limitations

- **Hand-written `.gd.uid` files.** `features/cargo/bulk_rules.gd.uid` and
  `tools/cargo_matrix_probe.gd.uid` were typed by hand because no Godot editor was
  available to generate them. If the editor rejects or regenerates them on first
  import, commit the editor's version. No existing `.gd.uid` was touched.
- The remaining `family == "gas"` branches in `bulk_service.gd`, `bulk_earnings.gd`,
  `bulk_service_panel.gd` and `bulk_port_test.gd` were left in place (D141): they
  select units, keys, labels and fixtures for one shared engine and decide stored
  key names, so moving them unverified risked save compatibility.
- The heavy voyage in the Python test uses host evidence, as the existing heavy
  tests do; it does not sail a lifter. Containers, bulk and gas have no Python
  service, so their voyages exist only in the Godot probe.
- The probe's interruption cases use cancel/release. Undocking mid-operation and
  process-kill recovery stay with the existing per-family runners.
- The probe has no Python runner or `.tscn` wrapper and is not in `CheckProject.ps1`.

### Checks

Nothing ran. This GitHub Actions runner again denied every Python invocation
(`python3 -m unittest ...` in three forms) and has no Godot binary; only file
edits, read-only shell and git were permitted. Both new test files were checked
by reading the code they call, which does not count as a pass.

- **Python (not run):** `services.test_cargo_matrix` (3 new tests), plus the 22
  heavy and 51 oil/refinery/cargo-fuel tests still unrun since Step 83.
- **Godot (not run):** import, script parse/load, `cargo_matrix_probe.gd`, and the
  existing bulk/gas capacity, bulk/gas service, liquid inventory, voyage, ports
  and catalog checks that exercise the three edited scripts. A GDScript parse or
  typing error in the edited or new files is possible.
- **Windows:** PowerShell/native checks, exports and exported resource loading
  (including the new export entry): not run.
- **PostgreSQL / Keycloak / public peers:** not installed, not run. Public oil and
  refinery SQL adapters are untouched; no public heavy, bulk or gas support exists.
- **Visuals / playtest:** not applicable to this step's code; no hand-sailed voyage
  of any family was made. No Andy acceptance is claimed.

### Handoff

On branch `claude/issue-25-20261111-0058`; the runner cannot create
`feat/step-84-cargo-compatibility-matrix`. Nothing was pushed to main.

Next, in order:

1. Step 83's list items 1-3 if still open.
2. `python -m unittest services.test_cargo_matrix -v`, then every `services` test.
   The expected refusal codes and totals were derived by reading; fix the test if
   a code differs for a sound reason, fix the service if a table changed.
3. With pinned Godot 4.7.2: import (watch the two hand-written `.uid` files), the
   script-load check, then with isolated user-data directories
   `godot --headless --path . --script tools/cargo_matrix_probe.gd`; expect
   `CARGO_MATRIX_PASS ... failures=0`.
4. Re-run bulk/gas capacity and service probes and the liquid inventory, voyage,
   ports and catalog checks to confirm the rule split changed nothing.
5. Record real results here and remove "UNVERIFIED" from the heading only then.
6. Backlog, not blocking: Windows export/load, PostgreSQL/Keycloak runners, a
   hand-sailed voyage per family, and adding the probe to `CheckProject.ps1`.

## Step 85 — Content extension rehearsal (draft, UNVERIFIED) — November 11, 2026

Roadmap task `content-extension-rehearsal`. See CONTENT_EXTENSION.md and D142.

### Changes

- New records, appended to `PrototypeCatalog.RECORDS` and `export_presets.cfg`:
  commodity `cargo_bulk_salt`, ship `ship_harbor_container_01`, port
  `port_cinder_point` with `berth_cinder_point_01` and `cinder_point.tscn`.
- `bulk_ship.tres` holds accept salt. The ship has rows in `ship_catalog.json`
  (1000.00 credits), `resale_values.json` and `repair_costs.json`.
- Hard-coded IDs removed: online hull allow-lists (`public_fleet_service.gd`,
  `public_authority_client.gd`) follow the ship catalog; bulk/gas commodity lists
  (`bulk_earnings.gd`) follow cargo records; port names in six scripts use
  `PrototypeCatalog.display_name` / `short_name`; `test_port.gd` landmark is a
  scene property set on `brindle_quay.tscn`.
- Checks that counted three ships now expect four or follow the catalog:
  `ship_purchase_probe.gd`, `test_ship_purchase.py`, `economy_gate.py`,
  `economy_gate_probe.gd`.
- New `tools/content_extension_probe.gd`.

No transaction math, save format, protocol version or ship-controller logic
changed. No machinery wear, expiry, hidden shallows, player transfer or second
active job.

### Known limitations

- **Cinder Point is not placed in any world.** It loads, validates, builds its
  scene and is accepted in save records and bulk quotes, but neither Port Test nor
  the public world contains it. Placement needs save and protocol changes and is
  left for the Step 88 world layout decision.
- **No seeded salt job and no salt entry in the bulk service panel.** Salt works
  through the bulk authority and manifest only.
- **The new ship changes online balance.** Price, resale rate, repair cost and
  handling are placeholder values; the economy gate has no metrics for it yet.
- **Hand-written `tools/content_extension_probe.gd.uid`.** If the editor
  regenerates it on first import, commit the editor's version.
- Remaining ID-bound code is listed in CONTENT_EXTENSION.md.

### Checks

Nothing ran. This runner denied `python3 -m unittest` and has no Godot binary;
only file edits, read-only shell and git were permitted. All edits were checked
by reading the code they touch, which does not count as a pass.

- **Python (not run):** `tools/public_handoff` tests (`test_ship_purchase`,
  `test_fleet`, `test_economy_gate`, `test_resale_accounting`) now see four ships;
  `services` tests are unaffected by this step but still unrun since Step 83.
- **Godot (not run):** import, script parse/load, `content_extension_probe.gd`,
  and the catalog, ports, bulk/gas, ship purchase, fleet inspection, fleet switch,
  resale and voyage checks that touch the edited scripts. A GDScript parse or
  typing error in the edited or new files is possible.
- **Economy gate (not run):** `economy_gate_probe.gd` must be re-run to produce
  metrics for the fourth ship before `economy_gate.py` can pass.
- **Windows:** PowerShell/native checks, export and exported resource loading
  (five new export entries): not run.
- **PostgreSQL / Keycloak / public peers:** not installed, not run.
- **Visuals / playtest:** none. No Andy acceptance is claimed.

### Handoff

On branch `claude/issue-27-20261111-1228`; the runner cannot create
`feat/step-85-content-extension-rehearsal`. Nothing was pushed to main.

Next, in order:

1. Step 84's open list if still pending.
2. With pinned Godot 4.7.2: import, script-load check, then
   `godot --headless --path . --script tools/content_extension_probe.gd` with an
   isolated user-data directory; expect `CONTENT_EXTENSION_PASS ... failures=0`.
3. Re-run CatalogCheck and the ports, bulk/gas service and earnings, ship purchase,
   fleet inspection/switch and resale probes.
4. Python: `tools/public_handoff` unit tests, then regenerate economy metrics and
   run the economy gate. Review the harbor ship's price and handling if it fails.
5. Record real results here and remove "UNVERIFIED" from the heading only then.
6. Backlog, not blocking: Windows export/load, PostgreSQL/Keycloak runners, a
   hand-sailed online purchase and voyage with the harbor ship, adding the probe
   to `CheckProject.ps1`, and placing Cinder Point at Step 88.

## Step 86 — Priority cargo balance (draft, UNVERIFIED) — November 11, 2026

Task ID `priority-cargo-balance`. D143. See CARGO_BALANCE.md for the saved table.

### Changed

- `features/cargo/bulk_service.gd`: seeded bulk rates 640/800/960/1200 (limestone,
  grain, coal, ore) and gas rates 800/1000/1200/1500 (argon, LNG, nitrogen, oxygen).
- `services/refinery/cargo_fuel.py`: sale price 220 → 320 minor credits per barrel.
- Pinned expectations updated by hand to match: `tools/bulk_service_probe.gd`,
  `tools/cargo_fuel_probe.gd`, `tools/check_cargo_fuel.py`,
  `services/refinery/test_cargo_fuel.py`, `services/test_cargo_matrix.py`.
- New `tools/public_handoff/cargo_balance.py` and `test_cargo_balance.py`.
- New CARGO_BALANCE.md; GAS_DELIVERY_PERSISTENCE.md and CARGO_FUEL_TRANSPORT.md
  examples updated.

No new Godot script or runtime resource, so no `.gd.uid` or export preset change.
Containers, oil prices, refinery yield/fee, heavy rewards, fuel, repair and
recovery values are unchanged. No protocol or save version change.

### Known limitations

- **Oil and cargo fuel are still not competitive** (2.10 and 3.50 net credits per
  minute against 77.70 for a full container load). The 200-barrel tanker is the
  cause; the scale-up is left for a decision with Andy.
- **Heavy has no measured voyage**, so it has rewards but no per-minute figure.
- Travel figures are the Step 67 starter-hull measurements reused for the bulk,
  gas and oil fixtures. No new voyage was sailed.
- Bulk and gas rates were raised by a flat factor; they are a first pass.
- Existing private bulk/gas saves keep their old frozen quotes; only newly seeded
  fixture worlds get the new rates.

### Checks

Nothing ran. This runner denied every `python3` invocation (unittest and direct
script) and has no Godot binary. All numbers were worked by hand.

- **Python (not run):** `tools/public_handoff` tests including the new
  `test_cargo_balance.py`; `services` tests, where `test_cargo_fuel.py` and
  `test_cargo_matrix.py` now expect 22400 / 29330 / 21400.
- **Godot (not run):** import, `bulk_service_probe.gd` for bulk and gas (now
  expects 32073 / 40091 partial and 98625 LNG total), `cargo_fuel_probe.gd`
  (now expects +672), and the bulk/gas scene and recovery runners.
- **PostgreSQL (not run):** `tools/check_cargo_fuel.py` (now expects +224).
- **Windows / Keycloak / visuals / playtest:** not run. No Andy acceptance.

### Handoff

On branch `claude/issue-29-20261111-1259`; the runner cannot create
`feat/step-86-priority-cargo-balance`. Nothing was pushed to main.

1. Run `python3 -m unittest discover -s tools/public_handoff -p 'test_*.py'` and
   `python3 -m unittest discover -s services -t . -p 'test_*.py'`. If
   `test_cargo_balance` disagrees with CARGO_BALANCE.md, trust the script output
   and correct the document.
2. With Godot 4.7.2: import, then the bulk and gas service probes and the cargo
   fuel probe. A hand-computed expectation may be off by a rounding unit.
3. Still open from Steps 84–85: their unrun check lists and the economy gate
   metrics for the harbor ship.
4. Backlog, not blocking: Windows export, PostgreSQL/Keycloak runners, a measured
   heavy-lifter voyage, the oil/tanker scale decision, and Andy's Step 87 playtest.

## Step 88 — World layout and traversal budget (draft, UNVERIFIED) — November 11, 2026

Task ID `world-layout-and-traversal-budget`. D144. See WORLD_LAYOUT.md. Step 87
(Andy's playtest/export gate) was skipped on instruction and stays in the backlog.

### Changed

- New `features/world/world_layout.json`: scale, budget model, size classes,
  seven ports, eight waypoints, two passages and 17 routes. Added to the
  `include_filter` in `export_presets.cfg`. Nothing loads it yet.
- New `tools/world_layout/traversal_budget.py` and `test_traversal_budget.py`
  (standard library only).
- New WORLD_LAYOUT.md; D144 in DECISIONS.md; a pointer in CONTENT_EXTENSION.md.
- Cinder Point is placed on the plan at 2.0° S, 2.0° E.

No GDScript, scene, record, service, save, protocol or price change, so no
`.gd.uid` change. `docs/original-references` and `.github/workflows` untouched.

### Known limitations

- **Every number is hand arithmetic.** Route lengths used flat-chart arithmetic
  with a cosine correction; the script uses exact great-circle lengths.
- **Cinder Point is not in the public world or Port Test.** Only its address is
  decided. The runtime wiring listed in CONTENT_EXTENSION.md is left for Step 89.
- The budget model is fitted to two measured 3–4 km starter legs and extrapolated
  to 14 km. Swift, Harbor and lifter planning paces are unmeasured.
- No coastline: lanes are straight segments that Step 91 scenery must respect.
- Bulk and gas pay by distance, so the longer routes pay about five times the
  fixture for about twice the time. Not rebalanced here.
- The D143 oil and tanker scale decision is still open.

### Checks

Nothing ran. This runner denied `python3` (also `awk`, `bc` and `node` as
calculators) and has no Godot binary. File edits, read-only shell and git only.

- **Python (not run):** `tools/world_layout` script and tests. A typo in the new
  script, or a hand length more than 0.5% off, would fail there.
- **Python (not run, unaffected by this step):** `tools/public_handoff` and
  `services` tests, still unrun since Step 83.
- **Godot (not run):** import and export with the new include-filter entry.
- **Windows / PostgreSQL / Keycloak / visuals / playtest:** not run. No Andy
  acceptance of the map, targets or names.

### Handoff

On branch `claude/issue-31-20261111-1331`; the runner cannot create
`feat/step-88-world-layout`. Nothing was pushed to main.

1. Run `python3 tools/world_layout/traversal_budget.py` and
   `python3 -m unittest discover -s tools/world_layout -p 'test_*.py'`. Expect
   `WORLD_LAYOUT_PASS routes=17 failures=0`. If a figure differs, trust the
   script and correct WORLD_LAYOUT.md; if a route misses its tier, move the
   waypoint rather than the tier.
2. Andy to review the map, port names, time targets and the two passages.
3. Step 89 should load this file, then wire Cinder Point into the public world
   with the protocol and save changes that needs.
4. Still open from Steps 84–86: their unrun check lists, the economy gate
   metrics for the harbor ship, and the oil/tanker scale decision.

## Project reset review — November 11, 2026 (planning only)

From GitHub issue #34. Added REBUILD_PLAN.md: an audit of what is playable, the
likely cause of the no-movement bug, a proposed single-player 1.0 scope, six
playable milestones, a verification approach and a fix-first list. It is a
proposal awaiting Andy's approval; no work starts before that.

No game code, scene, resource, service, save, protocol, export preset or
`.github/workflows` file changed. `docs/original-references` untouched.

Checks: nothing ran. The runner has no Godot and refused Python and a deeper git
fetch. The audit is a reading of source and records. The movement diagnosis
(`set_menu_open` called every frame in `oil_port_test.gd` and `bulk_port_test.gd`
re-arms `wait_for_release`, so held keys never reach the helm) is **not
reproduced** and must be confirmed in Godot on Windows before it is fixed.

## Rebuild plan approved — November 11, 2026 (docs only)

Andy approved REBUILD_PLAN.md on PR #35 (answers relayed by Hark). D145.

- REBUILD_PLAN.md: recorded Andy's four answers. 1.0 is a polished single-player
  first draft. Bulk and heavy stay in. Gas, oil, refinery and cargo fuel are
  "on hold until playtested" with code intact. Added the exact CI job: commands
  and test paths for Godot 4.7.2 and Python.
- Movement diagnosis revised. No menu entry is named "fuel test". The "Fuel test
  tools" buttons exist only in Boat Handling Test and Heavy-Lifter Test, which do
  not have the per-frame `set_menu_open` bug. New leading guess for Andy's report:
  "Empty tank (test)" was autosaved in Boat Handling Test and restored empty. The
  per-frame bug in the oil, bulk and gas scenes still stands as a separate bug.
  Neither is reproduced.
- AGENTS.md: agents now follow REBUILD_PLAN.md instead of the numbered roadmap.

No game code, scene, resource, service, save, protocol, export preset or
`.github/workflows` file changed. `docs/original-references` untouched.

Checks: nothing ran; no Godot or Python on this runner. The CI commands are
copied from `tools/Godot.ps1` and earlier PROGRESS.md entries and are untested.
The Godot download URL and the psycopg requirement are unconfirmed.

## Fix-first 1: the movement bug — November 11, 2026 (written, NOT RUN)

Issue #37. REBUILD_PLAN.md section 4, item 1.

- `features/input/player_controls.gd`: `set_menu_open` returns early when the value
  is unchanged. Before, the per-frame calls in `bulk_port_test.gd` and
  `oil_port_test.gd` re-armed `wait_for_release` every frame, so a held key never
  reached the helm in Bulk Port Test, Gas Port Test and the oil fixture.
- `features/ships/fuel_test_controls.gd`, `features/handling/handling_test.gd`:
  "Empty tank (test)" lasts for the visit only. Boat Handling Test saves the fuel
  level from before the button was clicked. A tank that ran dry by sailing is still
  saved as empty. The fuel line now reads "EMPTY — stop, then click Refuel (test)".
  A save that already holds an empty tank is not changed; the new text is the way out.
- `features/ports/bulk_port_test.gd`: new `voyage_path` export so a test can use an
  isolated save file. Empty (the default) keeps the normal bulk and gas save paths.
  No other change to bulk, gas, oil, refinery or cargo-fuel code.
- New `tools/check_helm_keys.gd`: opens Boat Handling Test, Heavy-Lifter Test, Port
  Test, Bulk Port Test, Gas Port Test and the oil fixture, holds the bound throttle
  key through PlayerControls and ShipHelm, and expects over 0.2 m/s. Also checks a
  test-emptied tank is not restored empty. Saves go to `user://helm_keys_check`.
  `tools/Godot.ps1` has a new `-Mode HelmKeysCheck`.

Checks: **nothing ran.** This runner has no Godot, and the Godot download and the
Python commands were refused. No Python file changed. The new check and the edited
scripts are unparsed and unexecuted, so `tools/check_helm_keys.gd` may itself need
fixes on its first run. `tools/check_helm_keys.gd.uid` is not committed: Godot must
generate it. No export preset change (the new file is a test tool, not a runtime
resource). `.github/workflows` not edited, so CI does not run the new check until
Hark adds it to Stage 2. Not reproduced or playtested on Windows.

## Fix-first 3: import, parse and run everything — November 11, 2026 (PARTIAL, NOT RUN)

Issue #39. REBUILD_PLAN.md section 4, item 3. **This item is not finished.**

**Nothing ran, and the CI log was not read.** This runner refused `godot`,
`python3 -m unittest`, `python3 -m compileall`, `gh run view`, `gh api`, `curl` and
web fetch. So run 43078248183 was not seen. The three Stage 4 diagnoses below come
from reading the source plus the failure wording in earlier entries here
("lateral-contact assertion", "two side-course contacts", "two out-of-tree
transform errors"). The Checks run on this PR is their first test.

Stage 4 probes:

- **collision_probe: stale test.** The "lateral collision" fixture coasts sideways
  at 1 m/s. That is under `neutral_stop_speed_mps` (1.03), so the neutral stopping
  assist plus lateral drag stop the hull after about 0.83 m (hand arithmetic). The
  wall is 1.45 m away, so no contact, on any platform. The fixture now holds the
  thruster toward the wall. No handling code changed.
- **composition_probe: stale test, same cause.** Both "side" fixtures (starter and
  heavy) had a 1.15 m gap. They now hold the thruster too.
- **ports_probe: small real bug, plus a probe fault.** A new heavy lifter adds its
  floating load with `call_deferred`. A snapshot taken later in the same tick read
  `payload_body.global_transform` outside the tree: an engine error, twice (capture,
  then checkpoint), and an identity pose saved for one tick. A player switching to
  the heavy loader in Port Test can hit it. `voyage_snapshot.gd` now has
  `floating_pose()`, which works out where the load will appear. Also: without
  `-- --ports-check` (CI does not pass it) the probe opened the default voyage save
  `user://worlds/private_port_voyage/voyage.db`. The probe now sets
  `save_enabled = false`, so it never touches that file.

Other changes:

- Deleted the three hand-written files `features/cargo/bulk_rules.gd.uid`,
  `tools/cargo_matrix_probe.gd.uid` and `tools/content_extension_probe.gd.uid`.
  Nothing referenced their IDs. None was replaced: this runner has no Godot, and a
  uid must not be typed by hand. Godot writes new ones on the next editor import;
  whoever runs that import on Windows should commit the three files (and
  `tools/check_helm_keys.gd.uid`).
- `tools/check_helm_keys.gd`: reviewed by reading against PlayerControls, ShipHelm,
  the six scenes and both save stores. No logic fault found. One change: the key
  code is cast `as Key`. Expected run time is 10–20 s plus scene loading, close to
  the 30 s CI limit.

Not done:

- Steps 83–88 keep "UNVERIFIED". No heading was changed, because I saw no passing
  result for any of them.
- The probes under "Not in CI yet" in REBUILD_PLAN.md (bulk, gas, oil, refinery,
  repairs, purchase, fleet, cargo matrix, content extension and the rest) were not
  run and not added to Stage 2.
- Stage 1–3 failures on main, if any, were not seen and not fixed.

No export preset change (no new runtime resource). No gas, oil, refinery or
cargo-fuel file changed. `.github/workflows` not edited. No Windows run, no playtest.

## Fix-first 4: no silent dead ends — November 12, 2026 (NOT RUN BY THE AGENT)

Issue #41. REBUILD_PLAN.md section 4, item 4. Last item of M0.

**Nothing ran on the agent runner.** `godot` was refused again. No Python file
changed, so the Python checks were not run either. The Checks run on the PR is the
first parse and run of this code.

What changed:

- New `features/ships/helm_notice.gd`: a banner above the throttle indicator. It is
  owned by `ShipHelm`, so Boat Handling, Heavy-Lifter, Port, Bulk, Gas and the oil
  fixture all get it. It shows after the helm has been off for 0.4 s and gives the
  cause, then the way out:
  - ship switched off (failed resume): leave and reopen;
  - paused: "Pause sim" clicked, save could not open (Boat Handling), voyage save
    stopped (Port), cargo save stopped (Bulk, Gas), or a general loading/saving line;
  - docked: which Undock button to click;
  - heavy-lifter deck moving or load not raised;
  - fuel tank empty: where to refuel;
  - panel open (oil price panel names its close button);
  - window not active; a control holding the keyboard; keys still held.
- `HandlingShip.pause_reason`: the scene that pauses the ship sets the wording.
- Two small behaviour changes, both to give a way out:
  - Port, Bulk and Gas: an empty tank at sea had no exit, because REFUEL needs a
    berth. The banner now offers "Add free test fuel (quarter tank)" once the ship
    has stopped. Test scenes only. M2 replaces it with paid recovery.
  - Esc releases keyboard focus from a button, list or text box while sailing. A
    second Esc opens the menu as before.
- Oil fixture: only a wording function was added (`helm_hints`). No free fuel there.
- `tools/check_helm_keys.gd` now also checks the banner is silent while the helm
  works and names a docked and a paused ship. That check is still not in CI.
- `export_presets.cfg` lists the new script.

Limits:

- Not covered: Local Multiplayer Test and the online client. They are frozen and do
  not use `ShipHelm`. The home menu's PLAY test page has no ship.
- Heavy transport fixture gets only the general paused line.
- Banner position and wording were not seen on screen. It may overlap a HUD panel
  in a small window.
- `features/ships/helm_notice.gd.uid` is not committed: Godot must generate it.
- `.github/workflows` not edited. No Windows run, no playtest.

## M1: One real voyage — November 12, 2026 (NOT RUN BY THE AGENT)

Issue #43. REBUILD_PLAN.md section 3, milestone M1. M0 was accepted by Andy.

**Nothing ran on the agent runner.** No Godot is installed; the Godot download,
Python and files outside the repository were refused. The code below is unparsed
and unexecuted. The Checks run on the PR is its first parse. The new playthrough
is not in CI until Hark adds it.

What changed:

- New `features/game/game.tscn`: the one real game scene. It is the Port Test
  script with the new `game_mode` export on and its own save,
  `user://worlds/game/voyage.db`. No new gameplay script.
- `features/ports/port_test.gd`: `game_mode`. In the game the panel says "Wallet",
  the "Test heavy loader" button is hidden, and free fuel and repair read "no
  charge yet". Port Test itself is unchanged.
- Home menu: the first button opens the game. It reads PLAY with no game save and
  CONTINUE with one. The old PLAY page is now LOCAL SAVE TEST (same action, same
  behaviour). Buttons are 2 px shorter so 13 fit.
- Wallet: the credit balance in the game save. Delivery and payment are one
  SQLite transaction (existing Port Test code). The fixed-price `world.db` test
  ledger is not used by the game.
- New `tools/check_m1_voyage.gd`: clicks PLAY, sails Brindle spawn → Brindle berth
  → Slatewater berth by holding the real throttle, steering and zero-throttle keys
  through PlayerControls and ShipHelm, takes and delivers a one-container job,
  checks the wallet (250.00), leaves by "Main menu", clicks CONTINUE and checks the
  wallet, the docked ship and the helm again. Buttons are clicked only when visible
  and enabled. Save folder: `user://m1_voyage_check`. `tools/Godot.ps1` has
  `-Mode M1VoyageCheck`.
- `tools/slots_probe.gd`: one expected button text updated.
- `export_presets.cfg` lists `game.tscn`.

Limits:

- The playthrough's route was worked out by hand arithmetic, not by a run. It may
  need tuning on first run. It fast-forwards by raising physics ticks per second
  with the step kept at 1/60 s; if the engine refuses, it falls back to real time
  (about 7 minutes). Run time is unmeasured and may exceed CI's 30-second rule.
- No Restart Progress and no New Game over an existing save (M2). To start over
  now, delete `worlds/game` in the Godot user data folder.
- Six container jobs in total (three each way). They do not come back.
- Fuel, repair and the rescue fuel are still free (M2).
- Test fixtures are still on the home menu. No Windows zip artifact.
- No new `.gd.uid` committed: Godot must generate `tools/check_m1_voyage.gd.uid`.
- No gas, oil, refinery or cargo-fuel file changed. `.github/workflows` not
  edited. No Windows run, no playtest.

## Simplify pass — November 12, 2026 (NOT RUN BY THE AGENT)

Issue #45. REBUILD_PLAN.md section 3, "Simplify pass". No new features.

**Nothing ran on the agent runner.** No Godot is installed and Python was refused
(no Python file changed). The code below is unparsed and unexecuted. The Checks
run on the PR is its first parse.

What changed:

- New `features/developer/dev_mode.gd` (`DevMode`): one switch, off by default,
  not saved. `PlayerControls` toggles it on F3. Not available in the friends client.
- Home menu (`application_menu.gd`): PLAY / CONTINUE (one button, as in M1),
  SETTINGS, QUIT. EXIT is now QUIT. The ten test buttons moved to a "DEVELOPER
  TESTS" column that shows only with F3 on. The footer and the test-save notice
  line also need F3.
- `developer_overlay.gd`: follows `DevMode`. Its own Ctrl+F3 handler is gone.
- Game HUD (`voyage_hud.gd`, `port_test.gd` in `game_mode` only): the top-right
  panel's last lines are now "Speed · Fuel" (plus Hull when damaged) and "Money".
  The gauge panel and the port/wallet line are hidden in the game unless F3 is on.
  Port Test and every other test scene look as before.
- Checks updated: `diagnostics_probe.gd` presses plain F3 and checks the test
  buttons start hidden; `check_flow.gd` turns developer mode on (it checks the
  Continue Test Session button); `check_m1_voyage.gd` reads the money from the HUD.
- `export_presets.cfg` lists `dev_mode.gd`. REBUILD_PLAN.md: Simplify status,
  Aesthetics milestone, new order.

Limits:

- Layout was not seen on screen. The menu notice moved under the buttons.
- The game still shows four panels: actions (Dock, Main menu, services), job HUD,
  throttle bar, minimap. Merging them further would change approved play controls.
- Test scenes keep their own HUDs and test tools; only the way in is hidden.
- `features/developer/dev_mode.gd.uid` is not committed: Godot must generate it.
- No gas, oil, refinery or cargo-fuel file changed. `.github/workflows` not
  edited. No Windows run, no playtest.

## M2 Costs and risk — November 12, 2026 (NOT RUN BY THE AGENT)

Issue #47. REBUILD_PLAN.md section 3, M2.

**Nothing ran on the agent runner.** No Godot is installed and Python was refused
(no Python file changed). The code below is unparsed and unexecuted. The Checks
run on the PR is its first parse.

What changed (the game only; Port Test behaves as before):

- `features/ports/port_test.gd` in `game_mode`: REFUEL costs 0.50 credits per
  litre, REPAIR 5.00 per 1% hull. Each buys what the wallet can cover and shows
  its price on the button. Collisions reduce hull (`validated_impact` was not
  connected before). At 0% hull the ship is held for 4 seconds under a banner,
  then recovered. `recover()` moves the ship to the current port's spawn point,
  sets hull to 50% if sunk, gives at least a quarter tank and charges 200.00
  credits or the whole wallet if less. Cargo stays on board.
- `features/ships/helm_notice.gd`: a scene can replace the free test-fuel button
  with its own text and action. The game uses it for "Call a tow to port".
- `features/cargo/voyage_snapshot.gd`: the game writes version 3 with a `spent`
  total; the wallet must equal delivered pay minus `spent`. Versions 1 and 2
  (Port Test, older game saves) are read and written as before.
- Home menu: RESTART PROGRESS, visible only with a save, behind a confirmation.
  It deletes `voyage.db` and its `-wal` / `-shm` files. The notice text moved down.
- `tools/check_m1_voyage.gd`: after the delivery it clicks REFUEL and checks the
  bill; after Continue it calls the tow, sinks, is recovered and uses Restart
  Progress. The empty tank and the 0% hull are set by code, not by key press.

Limits:

- No sinking animation or sound. Recovery fails over to "ship stays where it is"
  if every spawn point at the port is blocked; it still charges and refuels.
- A broke captain is towed free. That is deliberate (no dead end) and exploitable.
- Six container jobs in total, so money runs out (M3/M4). Prices are untested.
- No collision by key press in the playthrough. Menu layout was not seen on screen.
- No new file, so no `.gd.uid` and no `export_presets.cfg` change. No gas, oil,
  refinery or cargo-fuel file changed. `.github/workflows` not edited. No Windows
  run, no playtest.

## M3 Progression — November 12, 2026 (NOT RUN BY THE AGENT)

Issue #49. REBUILD_PLAN.md section 3, M3.

**Nothing ran on the agent runner.** No Godot is installed, and the Godot
download and Python were both refused. The code below is unparsed and
unexecuted. The Checks run on the PR is its first parse.

What changed (the game only; Port Test behaves as before):

- New `features/game/progression.gd`: three ships with prices, six bulk jobs, and
  the checks for the new save fields. Listed in `export_presets.cfg`.
- `features/ports/port_test.gd` in `game_mode`: a SHIPS button in the berth
  services opens one row per ship: buy, switch, or sell (half price, two clicks,
  never the ship being sailed). Each ship keeps its own fuel and hull. Switching
  needs no job in hand. On the bulk carrier CARGO lists bulk jobs; accept loads
  at once, "Deliver cargo at this port" pays at the other port, Abandon reopens
  the job. On the heavy lifter CARGO lists the existing heavy jobs.
- `features/cargo/voyage_snapshot.gd`: the game writes version 4 with `ship`,
  `fleet` and `bulk`. The wallet must equal container, heavy and bulk pay minus
  `spent`. A sale lowers `spent`. Versions 1 to 3 are read as before.
- `voyage_hud.gd`, `local_navigation.gd`: the job panel and minimap show a bulk job.
- `tools/check_m1_voyage.gd`: after the M2 part it buys the bulk carrier,
  switches, docks, accepts a bulk job, sells the container ship and uses
  Continue. The purchase money is one bulk job marked delivered by code.

Limits:

- The bulk carrier is the container ship's hull and handling under another name.
  Bulk cargo is not shown on deck and has no loading time.
- The game's bulk jobs are a simple accept and deliver. They do not use
  `bulk_service.gd` (holds, tonnes, its own save); Bulk Port Test is unchanged.
- A bulk delivery is saved by the next autosave tick, not in the same call as
  container deliveries are.
- Jobs do not come back: about 15,300 credits in total. Prices are untested.
- The new check steps dock twice more from the port's spawn point. That path has
  only been used at Brindle Quay before, and never run here.
- `features/game/progression.gd.uid` is not committed: Godot must generate it.
- No gas, oil, refinery or cargo-fuel file changed. `.github/workflows` not
  edited. No Windows run, no playtest.

## M4 A world worth sailing — November 12, 2026 (NOT RUN BY THE AGENT)

Issue #51. REBUILD_PLAN.md section 3, M4.

**Nothing ran on the agent runner.** The `godot` and `python3` commands were
both refused again. The code below is unparsed and unexecuted. The Checks run on the
PR is its first parse.

What changed (the game only; Port Test keeps two ports and its six jobs):

- `features/game/progression.gd`: the world table (four ports with positions),
  the land rectangles, and bulk jobs built from an ID with pay by distance.
- New port Gannet Light: `features/ports/gannet_light.tres`,
  `gannet_light_berth.tres`, `gannet_light.tscn`. Added to the catalog and to
  `export_presets.cfg`. Cinder Point already existed and is now in the game.
- `features/ports/port_test.gd` in `game_mode`: four ports, solid land, the sea
  sheet follows the ship, bulk and heavy pay is banked so those jobs repeat.
- `features/cargo/container_offers.gd`: game offers named
  `container_game_<port>_<slot>_<turn>`, three per port. A delivered or
  abandoned one is followed by the next turn. Nothing expires. The six Port
  Test offers are unchanged.
- `features/cargo/voyage_snapshot.gd`, `voyage_lifecycle.gd`: the game writes
  version 5 (four ports, game offers, `banked`). Versions 1 to 4 read as before;
  a version 4 save keeps its wallet and gets the new jobs on load.
- `features/ports/local_minimap.gd`: 200 by 240, land drawn, legend text removed.
  Port Test, Bulk and the oil fixture share this minimap and get the same look.
- `tools/check_m1_voyage.gd`: checks four ports and three open jobs at Brindle
  Quay after a delivery; the M3 purchase money is banked pay.

Limits:

- Land is flat sand and green blocks. Nothing was seen on screen: the look of
  the coast, the minimap and the camera near land are all unjudged.
- Delivered container jobs stay in the save as history. The save has a 4 MB
  limit, reached only after a few thousand deliveries.
- The heavy lifter cannot dock at Cinder Point: its berth record has no heavy
  service, and that record was left alone (a content check reads it).
- A tow still returns the ship to the last port it visited, not the nearest.
- Open sea to the south has no edge. Pay and distances are untested.
- No new script, so no new `.gd.uid`. `progression.gd.uid` is still not
  committed: Godot must generate it. No gas, oil, refinery or cargo-fuel file
  changed. `.github/workflows` not edited. No Windows run, no playtest.

## M5 Finish — November 12, 2026 (NOT RUN BY THE AGENT)

Issue #53. REBUILD_PLAN.md section 3, M5. Trimmed to the minimum on Andy's
instruction: no new screen, HUD, scene, script or document.

**Nothing ran on the agent runner.** `python3 -m compileall` and the download
of the pinned Godot 4.7.2 were both refused. The code below is unparsed and
unexecuted. The Checks run on the PR is its first parse. The PowerShell change
was not run either (no Windows, no export templates).

What changed (the game only, except the two new tones):

- `features/feedback/handling_feedback.gd`: `tone()` also makes "chime" and
  "thud", both one-shot. Engine, thruster and horn are unchanged.
- `features/ports/port_test.gd` in `game_mode`: plays the chime when a
  container, bulk or heavy delivery is paid and the thud on hull damage. The
  left panel lists the helm keys (read from Settings) until money is first
  earned or spent, then one short line.
- `features/ports/voyage_hud.gd`: with no job the panel says the next step
  (docked or not) and names a ship the wallet can buy; it adds a line below 25%
  fuel and below 50% hull. Port Test text is unchanged.
- `features/main/main.gd`: the home menu notice for a new game says what the
  game is and that it saves by itself.
- `tools/Godot.ps1`: `-Mode Export` also zips the exe, pck and DLLs to
  `exports/ShippingLanes-windows-<configuration>.zip` (ignored by Git).
- `tools/check_m1_voyage.gd`: two more checks at New Game (hints, sounds).

Limits:

- No art pass: left to the Aesthetics milestone, as the issue asks.
- The sounds are generated tones. Nobody has heard them; loudness is a guess.
- Hint wording and the 25% / 50% thresholds are untested with a player.
- No Settings inside the game: Esc saves and returns to the home menu.
- The zip is built by hand on Windows, not in CI. No installer, icon or signing.
- F3 developer mode still works in the packaged build (off at every launch).
- Open from M4: the heavy lifter cannot dock at Cinder Point; open sea to the
  south has no edge.
- No new runtime resource, so `export_presets.cfg` is unchanged and there is no
  new `.gd.uid`. No gas, oil, refinery or cargo-fuel file changed.
  `.github/workflows` not edited. No Windows run, no playtest.

## Aesthetics 1: Water — November 12, 2026 (NOT RUN BY THE AGENT)

Issue #55. REBUILD_PLAN.md section 3, Aesthetics item 1 of 5. Looks only.

**Nothing ran on the agent runner.** Running `godot` was refused again, so the
two shaders and the wake script are unparsed and nobody has seen the result.
The Checks run on the PR is the first parse; `tools/water_probe.gd` is in it and
was not edited. Colours, line density and wake size are guesses until Andy
looks at them on Windows.

What changed (all in `features/water`, existing files only):

- `stylized_ocean.gdshader`: three soft tone bands between the deep and surface
  colours; the foam net became separate white swirl strokes that taper off;
  cells a little larger (32 m, was 26 m). Wave motion and uniforms unchanged.
- `bright_ocean.tres`, `water_palette.gd`: more saturated blue and teal, pure
  white foam. `coastal_ocean.tres` is unchanged.
- `ship_foam.gdshader`: wake is solid white with a short fade at the end.
- `ship_wake.gd` `draw_foam()`: wider side crests and a white trail behind the
  stern. `advance()` and the wake samples are unchanged.

Limits:

- The tone bands are a drifting pattern, not real depth. There is no seabed or
  depth data, and the project uses the GL Compatibility renderer.
- Shallow-water colour near coasts and shore foam are not done.
- The old test scenes and the frozen online scenes share the ocean, so they get
  the new look too. No code of theirs changed.
- No new runtime resource: `export_presets.cfg` unchanged, no new `.gd.uid` or
  `.gdshader.uid`. No gameplay, physics, save, gas, oil, refinery or cargo-fuel
  file changed. `.github/workflows` not edited. No Windows run, no playtest.
- Aesthetics items 2 to 5 are not started.

## Aesthetics 2: Toon shader and ink outlines — November 12, 2026 (NOT RUN BY THE AGENT)

Issue #57. REBUILD_PLAN.md section 3, Aesthetics item 2 of 5. Looks only.

**Nothing ran on the agent runner.** Godot is not installed there, so the two
new shaders and the new script are unparsed and nobody has seen the result. The
Checks run on the PR is the first parse. Band levels, saturation, ink colour and
line thickness are guesses until Andy looks at them on Windows.

What changed:

- New `features/toon/toon.gdshader`: three hard light bands (shadow, mid, lit)
  and a saturation lift. Takes a colour, an optional texture and vertex colours.
- New `features/toon/toon_outline.gdshader`: ink outline by inverted hull, used
  as the next pass. Thickness scales with camera distance, capped at 800 m.
- New `features/toon/toon_look.gd`: `apply(node)` replaces every plain opaque
  material under a node with the toon material, keeping its colour or texture.
  Transparent, unshaded and custom shader materials are skipped.
- `features/ports/port_test.gd`: two calls, one for the ports and land, one for
  each ship when it spawns (hull and containers). Port Test shares this script,
  so it gets the look too.
- `export_presets.cfg`: the three new files added.

Limits:

- No `.gd.uid` or `.gdshader.uid` for the three new files. Godot must write
  them; open the project once in the editor and commit the files it creates.
- Only colour, colour texture and vertex colour carry over from the old
  materials. Normal maps, metal and emission on the ship models are dropped.
- The outline on the ship models and containers pushes along the normals, so
  small gaps can show at sharp corners. Box meshes (ports, land) avoid this.
- The old handling, collision and heavy test scenes and the frozen online scenes
  are not changed.
- No gameplay, physics, save, gas, oil, refinery or cargo-fuel file changed.
  `.github/workflows` not edited. No Windows run, no playtest.
- Aesthetics items 3 to 5 are not started.

## Aesthetics 3: Sky and lighting — November 12, 2026 (run on Linux, not on Windows)

Issue #59. REBUILD_PLAN.md section 3, Aesthetics item 3 of 5. Looks only.

What changed:

- New `features/sky/toon_sky.gdshader`: sky gradient (deep blue to pale cyan),
  flat two-tone puffy clouds made from circles, slow drift, flat sun disc.
- New `features/sky/sky_look.gd`: `apply(sun, environment)` sets the sky, a warm
  sun with shadows (two splits, 500 m), blue ambient light and depth haze from
  500 m to 2800 m in the horizon colour.
- `features/ports/port_test.gd`: one call after the light and environment are
  made. Port Test shares this script, so it gets the look too.
- `export_presets.cfg`: the two new files added. Their `.uid` files were written
  by Godot during the import below, not by hand.

Checks run on the agent's Linux runner with Godot 4.7.2 (official build, same
checksum as the Checks job):

- Passed: import, `check_scripts` (183 scripts), boot, `units_probe`,
  `check_catalog`, `diagnostics_probe`, `check_controls`, `check_flow`,
  `check_starter`, the twelve Stage 2 probes, `ports_probe`, `check_m1_voyage`.
- The game scene was rendered with GL Compatibility on a software driver
  (Mesa llvmpipe under Xvfb). The sky shader compiled with no errors and the
  agent looked at three screenshots: gradient, clouds, haze and shadows show.
- Failed: none.
- Not run: the Python stage (no Python file changed), anything on Windows, any
  real graphics card, any playtest. Frame rate with shadows on is not measured.

Limits:

- Shadows are new in this scene and cost frame time. If Windows runs slower,
  `shadow_enabled` in `sky_look.gd` is the one line to turn off.
- The haze tints far water and land through the engine's fog; no ocean file
  changed. The ocean plane's far edge can show as a thin pale line.
- Colours, cloud size and cover, haze distance and light levels are first
  guesses until Andy looks at them on Windows.
- The old handling, collision and heavy test scenes and the frozen online scenes
  are not changed.
- The import also wrote `.uid` files for older scripts that lack one (toon,
  progression and others). They are not in this change; item 3 only.
- No gameplay, physics, save, settings, gas, oil, refinery or cargo-fuel file
  changed. `.github/workflows` not edited.
- Aesthetics items 4 and 5 are not started.

## Aesthetics 4: Ships and ports — November 12, 2026 (run on Linux, not on Windows)

Issue #61. REBUILD_PLAN.md section 3, Aesthetics item 4 of 5. Looks only.

What changed:

- New `features/toon/chunky_look.gd`: builds chunky ship and port shapes in code
  with plain coloured materials. The existing toon shader and ink outline are
  applied to them by `toon_look.gd` as before. No model file or paid asset.
- Ships: rounded hull, white rail, rust-red bottom, big wheelhouse, banded
  funnel, mast, hatch covers. Container ship red, bulk carrier blue, heavy lifter
  yellow. The imported ship model is hidden, not deleted. The heavy lifter's
  lifting deck and load keep their own models.
- Ports: pitched warehouse roof and doors, stacked containers, domed fuel tank,
  crane boom and cab, bollards, striped harbour light, red and green buoys.
- `features/ports/port_test.gd`: two calls, both only when `game_mode` is on. The
  test scenes (Port Test, bulk, oil, gas) look as they did.
- `export_presets.cfg`: the new file added. Its `.uid` was written by Godot
  during the import below, not by hand.

Checks run on the agent's Linux runner with Godot 4.7.2 (official build, same
checksum as the Checks job):

- Passed: import, `check_scripts`, boot, `units_probe`, `check_catalog`,
  `diagnostics_probe`, `check_controls`, `check_flow`, `check_starter`, the
  twelve Stage 2 probes, `ports_probe`, `check_m1_voyage`.
- The game scene was rendered with GL Compatibility on a software driver (Mesa
  llvmpipe under Xvfb) with no script or shader errors. The agent looked at
  screenshots of all three ships and of the fuel-store and crane ports.
- Failed: none.
- Not run: the Python stage (no Python file changed), `collision_probe` and
  `composition_probe` (report-only in the Checks job), anything on Windows, any
  real graphics card, any playtest. Frame rate is not measured.

Limits:

- Every collider is unchanged, so the solid shapes are still boxes. The round
  bow, the buoys and the tank are drawn slightly inside or outside their boxes;
  a ship can touch a corner that is not drawn. The upper containers, crane boom
  and harbour light are not solid (they sit on the solid quay or high above it).
- The hull keeps its real size (13 m by 64 m; 24 m by 90 m for the heavy
  lifter), so the ships are chunky in shape and colour, not shorter or wider.
- Faces turned away from the sun fall in the toon mid band, so white walls read
  as pale blue-grey. The heavy lifter's sunk float shows a small dark outline
  tip at the stern.
- The container, bulk and heavy ships are the game's three kinds. The frozen
  online scenes, the old test scenes and the on-hold gas and oil scenes still
  use the imported model.
- Colours and proportions are first guesses until Andy looks on Windows.
- The import again wrote `.uid` files for older scripts that lack one. They are
  not in this change.
- No gameplay, physics, save, settings, gas, oil, refinery or cargo-fuel file
  changed. `.github/workflows` not edited.
- Aesthetics item 5 is not started.

## Aesthetics 5: HUD and UI — November 12, 2026 (run on Linux, not on Windows)

Issue #63. REBUILD_PLAN.md section 3, Aesthetics item 5 of 5. Looks only.

What changed:

- New `features/ui/playful_theme.gd`: one Godot theme built in code. Navy panels
  with a cream rim, chunky yellow buttons, bolder inked text, matching sliders,
  lists, drop-downs and dialog. It also draws the home menu backdrop (sky, sun,
  drifting clouds, sea, a small ship). No image, font or paid asset.
- `features/ui/application_menu.gd`: uses the theme and the backdrop; the old
  grey button styles and flat background are gone. Same buttons, same actions.
- `features/settings/settings_panel.gd`: uses the theme.
- `features/ports/port_test.gd`: when `game_mode` is on, the dock panel, job
  panel, throttle bar, warning banner (rust red), gauge panel and minimap take
  the look. The test scenes look as they did.
- `features/ports/local_minimap.gd`: brighter sea and land, cream rim, outlined
  port names and ship marker, only when the game asks.
- `throttle_indicator.gd`, `vessel_gauge_hud.gd`: the panel is now a member so
  the game can restyle it. No other change.
- `export_presets.cfg`: the new file added. Its `.uid` was written by Godot
  during the import below, not by hand.

Checks run on the agent's Linux runner with Godot 4.7.2 (official build, same
checksum as the Checks job):

- Passed: import, `check_scripts`, boot, `units_probe`, `check_catalog`,
  `diagnostics_probe`, `check_controls`, `check_flow`, `check_starter`, the
  twelve Stage 2 probes, `ports_probe`, `check_m1_voyage`.
- Rendered with GL Compatibility on a software driver (Mesa llvmpipe under Xvfb)
  at 1280x720. The agent looked at screenshots of the home menu, the Restart
  Progress question, Settings, the game at sea, at the berth, and docked with
  the CARGO list and the SHIPS list open.
- Failed: none.
- Not run: the Python stage (no Python file changed), `collision_probe` and
  `composition_probe` (report-only in the Checks job), anything on Windows, any
  real graphics card, any playtest. Other window sizes and fullscreen were not
  looked at.

Limits:

- The font is still Godot's built-in one, made bolder. No new typeface.
- The Dock button is tinted green over the yellow, so it reads olive.
- With the first-voyage key hints showing and CARGO open, the left panel is
  tall; it nearly reaches the warning banner at 1280x720. Buttons were made
  slightly shorter after the last screenshot; that final size was checked by
  the automatic checks but not looked at.
- The F3 developer overlay, the test scenes, the frozen online screens and the
  on-hold gas and oil screens keep their old look. The F3 test buttons on the
  home menu do take the new button style, because they are on the home menu.
- Colours and sizes are first guesses until Andy looks on Windows.
- The import again wrote `.uid` files for older scripts that lack one. They are
  not in this change.
- No gameplay, physics, save, settings, gas, oil, refinery or cargo-fuel file
  changed. `.github/workflows` not edited.
- All five Aesthetics items are written. None is accepted yet.

## Patch 2.0 item 1: Always running + Esc menu — November 12, 2026 (run on Linux, not on Windows)

Issue #66. REBUILD_PLAN.md section 5, item 1 only.

What changed, in the game (`features/game/game.tscn`):

- Esc opens a small menu over the running world: Resume, Settings, Main Menu,
  Quit. Esc again closes it. Main Menu and Quit save first. New file
  `features/game/game_menu.gd` (added to `export_presets.cfg`; its `.uid` was
  written by Godot). Settings is the same panel as on the home menu.
- The ship no longer stops when the keyboard is away. With the Esc menu open, a
  panel open, or the window not active, it holds its throttle order and sails
  on with the rudder centred. Before, `ShipHelm` ordered neutral in all three
  cases. Fuel burn, jobs, saving and the clock keep going as before.
- Nothing calls `get_tree().paused`, and nothing lowers the frame rate in the
  background (the project never turns on Godot's low-processor mode).
- The home scene (`main.gd`) no longer opens its session menu on focus loss.
- Hint text now says "Esc opens the menu". The top-left "Main menu" button
  stays until item 5 (HUD).

Kept as they were, on purpose: test and online scenes still order neutral when
input is blocked (`ShipHelm.keep_sailing` is set by the game only). The ship
still stops for real ship states: docked, sunk (4 s recovery), loading the save
at start, or a save error. The F3 "LOCAL SAVE TEST" clock fixture still stops
its test clock while its own session menu is open; it is not the game.

Checks run on the agent's Linux runner, Godot 4.7.2 official (checksum matches
the Checks job), headless:

- Passed: import, `check_scripts` (186), boot, `check_catalog`,
  `check_controls`, `check_flow` (updated: focus loss no longer pauses),
  `check_starter`, `check_helm_keys`, `check_m1_voyage`, `units_probe`,
  `diagnostics_probe`, the twelve Stage 2 probes, `ports_probe`.
- `check_m1_voyage` now also presses Esc under way and checks: the four buttons,
  the tree is not paused, the ship moves and the clock ticks for two seconds
  with the menu open, Settings opens and Esc returns, focus loss leaves the
  ship sailing, and Main Menu from the Esc menu saves (CONTINUE restores).
- One screenshot looked at (Mesa llvmpipe under Xvfb, 1280x720): menu centred
  over the sea, ship at 9.4 kn behind it.
- Failed: none.
- Not run: the Python stage (no Python file changed), `collision_probe`,
  `composition_probe`, anything on Windows, a real minimised or alt-tabbed
  window (focus loss was sent as a notification), the Quit button's actual
  exit, any playtest.

Limits:

- A minimised window on Windows is not proven here. Godot keeps stepping
  physics when minimised by default, but only Andy's playtest can confirm it.
- The Esc menu buttons are mouse-only (no arrow-key focus), so Esc always
  reaches the menu.
- Water quality chosen in the in-game Settings applies as it did before from
  the home menu; not re-checked here.
- The import again wrote `.uid` files for older scripts that lack one. They are
  not in this change.
- No gas, oil, refinery, cargo-fuel, online service or workflow file changed.

## Patch 2.0 item 2: Easy docking — November 12, 2026 (run on Linux, not on Windows)

REBUILD_PLAN.md section 5, item 2. Not playtested; Andy has not played it.

What changed (single-player game and its test ports):

- New easy rule (`berth_eligibility.gd` `evaluate_easy`, `test_port.gd`
  `dock_readiness`): Dock works when the ship's centre is within 45 m of the
  berth box and the ship is at 3 m/s (about 5.8 kn) or slower. No angle rule,
  no "whole hull inside the box" rule, no check on where the hull is now. The
  berth itself must be free (checked at the place the ship will end up).
- Auto-slide (`docking_authority.gd`): after Dock the game takes the helm and
  eases the ship to the berth centre and berth heading in 1 to 3 seconds
  (longer for a longer slide or a bigger turn), then it is docked. Cancel
  during the slide gives the helm back where the ship is.
- Messages say only what to do: "Sail closer to the berth to dock.", "Slow
  down to dock.", "Wait for the berth to clear.", "Ready to dock — select
  Dock.". Voyage hints now say "slow down" instead of "stop alongside".
- Save restore (`voyage_snapshot.gd`, `bulk_port_test.gd`) now waits out the
  longest slide, so an older save docked off centre still loads docked.

Kept as it was, on purpose: the old strict rule (`evaluate`,
`berth_readiness`) is still in the file because the frozen online code calls
it. The "Align with the berth direction" text now exists only on that online
path; the game never shows it.

Checks run on the agent's Linux runner, Godot 4.7.2 official (checksum matches
the Checks job), headless:

- Passed: import, `check_scripts`, boot, `check_catalog`, `check_controls`,
  `check_flow`, `check_starter`, `check_helm_keys`, `check_m1_voyage`,
  `units_probe`, `diagnostics_probe`, the twelve Stage 2 probes,
  `collision_probe`, `composition_probe`, `ports_probe` (299 checks),
  `voyage_probe`, `sailing_save_probe`, `public_physics_probe`.
- `ports_probe` now also checks: backward, crooked, off-centre, quay-touching
  and slowly moving approaches can dock; too fast and too far refuse with the
  plain messages; another hull in the berth blocks; a Dock from 120 degrees
  off and about 110 m away slides steadily (no jump, more than 1 s, at most
  3 s) and ends on the berth centre and heading; Undock and Cancel work after
  and during a slide.
- Failed: `oil_interface_probe` times out, the same on unchanged main (it
  needs its Python market fixture, which was not started). Not part of the
  Checks job.
- Not run: the Python stage (no Python file changed), `bulk_service_probe`
  (no scene; it runs through a Python runner), anything on Windows, any
  screenshot or look at the slide on screen, any playtest.

Limits:

- The slide was checked by numbers only. How it looks (camera, speed, a
  180 degree turn) needs Andy's eyes on Windows.
- The slide moves in a straight line and does not steer around the quay. From
  an odd spot (for example around the quay corner) the hull can pass through
  the quay edge for a moment.
- The ship always ends on the berth heading, so a ship that arrives backwards
  is turned around.
- `check_m1_voyage` still docks from a near stop at the quay; the crooked
  approach is proven in `ports_probe` on the same port scene script, not by a
  key-press voyage in the game scene.
- The on-hold oil, gas and bulk test ports share the docking authority, so
  they get easy docking too. None of their files changed except the one-line
  restore wait in `bulk_port_test.gd` (bulk is in 1.0).
- The import again wrote `.uid` files for older scripts that lack one. They are
  not in this change.
- No online service, export preset or workflow file changed. No new runtime
  resource was added.

## November 13, 2026 — Patch 2.0 item 3: Bigger loads (issue #70)

Written and checked on Linux. Not playtested. Nobody has looked at the stack on
screen yet.

What changed:

- The container ship carries 24 containers, up from 6: four bays, three across,
  two tiers. These are the 24 deck positions already authored for the hull
  (`asset_manifest.json`). The lower tier fills first, bow to stern, then the
  upper tier. The containers on deck are still drawn from the manifest.
- Game jobs (`container_offers.gd`): each port still has three open jobs. One is
  a handful (4, 6 or 8 containers), one a part load (10 to 16), one a full ship
  (24). The sizes change as jobs are delivered.
- Pay is per container and per distance: 3.00 credits per container per 100 m.
  That is 45.00 a container on the 1.5 km hop, so 180.00 for 4 and 1,080.00 for
  a full ship there (the old best job on that hop paid 750.00).
- Loading: 5 s a container for the first three (as before), then 0.5 s each. A
  full ship loads in 25.5 s instead of 2 minutes. The ship can cancel as before;
  nothing pauses.
- Older saves: the old 1, 2 and 3 container game jobs still read. A job in
  progress or already paid stays as it was; untaken old jobs are replaced by
  the new ones. Port Test and the frozen online service keep their six seeded
  1 to 3 container jobs and pay.
- The three other container ship records (coastal, harbor, swift) share the
  same hull and deck, so they are 24 as well. They are not sold in the game.

Checks run on the agent's Linux runner, Godot 4.7.2 official, headless:

- Passed: import, `check_scripts` (186 scripts), boot, `check_catalog`,
  `check_controls`, `check_flow`, `check_starter`, `check_helm_keys`,
  `check_m1_voyage` (it now takes a 4 container job for 180.00 credits), the
  Stage 2 probes, `collision_probe`, `composition_probe`, `ports_probe` (305
  checks), `voyage_probe`, `sailing_save_probe`, `public_physics_probe`,
  `cargo_matrix_probe`.
- `ports_probe` now also checks: 24 fit and 25 do not; the deck layout is two
  tiers, lower first; game jobs run from 4 to 24 and pay the same per container
  on the same leg; old small game jobs still read; restock withdraws untaken
  old jobs and keeps finished ones; loading times.
- Failed, the same on unchanged main: `fleet_inspection_probe` (3 checks),
  `ship_purchase_probe` (1 check). Both are online-panel probes outside the
  Checks job. `voyage_probe` passes on clean user data and fails if run a second
  time on the same user data ("Store opens"); main does the same.
- Not run: the Python unittest stage (no Python file changed; `compileall`
  passed), anything on Windows, any screenshot, any playtest.

Limits:

- The game sells one container ship, so "bigger ships carry many more" has no
  ship to apply to yet. Bulk and heavy jobs are unchanged.
- The pay rate and job sizes are first guesses for Andy to judge in play.
- Headless Godot does not keep MultiMesh transforms, so the stack positions are
  checked from the layout file, not from the drawn instances.
- A third tier would fit the count limit but would stand in front of the bridge
  windows, so the stack stops at two tiers.
- The import again wrote `.uid` files for older scripts that lack one. They are
  not in this change. No export preset or workflow file changed; no new runtime
  resource was added.

## November 13, 2026: Patch 2.0 item 4, Sailing feel (issue #72)

Written, checked headless on Linux. Nobody has looked at it on a screen yet:
the headless runner draws nothing and does not compile shaders. Andy's Windows
playtest is the first real look, and the amounts below are first guesses.

What changed (all in `features/water`, plus two wiring lines in
`ship_assembly.gd`; no new files):

- Swells: the ocean now rolls with two long swells (up to about 0.8 m; a third
  small one on high water) instead of the old 0.3 m ripple, and a lighter flat
  band rides each crest so the swell shows on the unshaded water.
- Rocking: the hull rides the same swell the water draws (sampled at bow, stern
  and both sides, tilt doubled), with a faster chop and a lifted bow that grow
  with speed, and it leans up to 6 degrees into a turn. Limits: 1.6 m heave,
  7 degrees pitch, 11 degrees roll. Only the visible hull and deck cargo move;
  the collision body, camera focus and saves do not.
- Foam: a scalloped foam ring round the whole waterline, two white curls
  peeling off the bow, and chunky white spray blobs at the bow above 30% of
  cruise speed.
- Wake: a 14 second V wake left in the water (about 110 m at full speed): a
  churned middle, two outer and two inner lines that sway and pinch into
  brush strokes, and a curl of foam every third step. It fades with age.
- Low water quality keeps a flat sea, a gentler rock, a coarser ring and no
  curls. The heavy lifter still does not rock (its record says so) but gets
  the new foam and wake.

Checks run on the agent's Linux runner, Godot 4.7.2 official, headless:

- Passed: import, `check_scripts` (186 scripts), boot, `units_probe`,
  `check_catalog`, `diagnostics_probe`, `check_controls`, `check_flow`,
  `check_starter`, `check_helm_keys`, `check_m1_voyage`, all twelve Stage 2
  probes, `collision_probe`, `composition_probe`, `ports_probe` (305),
  `voyage_probe`, `sailing_save_probe`, `public_physics_probe`.
- `water_probe` went from 59 to 69 checks. New: pitch grows with speed, the
  hull leans into a turn, rocking stays inside its limits and cannot move the
  navigation body, the wake opens into a V and fades, spray starts at speed and
  stops at rest. Three old checks were changed because the motion they
  measured was replaced on purpose: the 0.14 m bob limit, the loaded-hull
  height, and the wait for the wake to clear (9 s to 15 s).
- Failed once and fixed: `check_m1_voyage` reported "No vertices were added"
  from the new wake when the ship was nearly stopped.
- Not run: the Python stage (no Python file changed), `cargo_matrix_probe`,
  the online-panel probes, anything on Windows, any screenshot, any playtest.

Limits:

- The swell is not checked against dock and beach heights by eye; water now
  rises and falls about 0.8 m at the quays.
- A moored ship rocks on the swell like any other.
- The import again wrote `.uid` files for older scripts that lack one. They are
  not in this change. No export preset or workflow file changed.

## Patch 2.0 item 5: HUD simplification — November 13, 2026 (run on Linux, not on Windows)

Issue #74. REBUILD_PLAN.md section 5, item 5. The game only; test scenes keep
their HUDs. No save, cargo, money or docking rule changed.

What changed:

- New `features/game/game_hud.gd`: the game's HUD layout.
  - Helm bar, bottom centre: a slider marked R, N and D, the speed ("12 kn")
    and the Dock button. Dock is always there and greyed out with no berth in
    range; it reads Undock when docked. "Slow down to dock." shows under the
    slider when that is the only thing missing. The slider follows the
    throttle keys and can also be dragged or clicked to set the engine order.
  - Controls hint, top left: a new game only (no money earned or spent), for
    the first 45 seconds under way, then it fades and does not come back.
  - Notices (paid, refueled, collision and so on) show under the job card for
    6 seconds and fade. Loading progress stays up while loading.
  - Port card, top left, only while docked: port name, REFUEL, REPAIR, SHIPS
    and one card per job (a small picture of the load, what, from → to, pay,
    Accept). The cards are there as soon as the ship docks. CARGO, "Close
    services", the job list and "Accept selected job" are gone. Deliver shows
    only at the right port. SHIPS reads JOBS while the ship list is open.
- New `features/game/globe_minimap.gd`: a small globe, bottom right. The world
  is wrapped on a sphere that turns as the ship sails. Land, ports, the ship
  arrow and a dotted course to the destination, which is named and ringed.
- `features/ports/port_test.gd` (in `game_mode`): the top-left panel is gone at
  sea. No key list, "Berth:" line, Main menu button (Esc has it), receipt text
  or prices line. Uses the two new files. Job cards are listed on docking.
- `features/ports/voyage_hud.gd` (game only): money in large type at the top;
  no "NO ACTIVE JOB" heading, no cargo count, no speed (it is on the helm bar).
  Hint wording follows the new buttons.
- `features/ships/helm_notice.gd`: a scene may switch off the "DOCKED" banner.
  The game does; the Undock button is right there.
- `export_presets.cfg`: the two new files added. Their `.uid` files were
  written by Godot during the import, not by hand.
- `tools/check_m1_voyage.gd` follows the new HUD: Accept on a job card,
  Deliver, Esc then MAIN MENU where it clicked the removed Main menu button.
  New checks: the globe is the minimap, nothing top left at sea, Dock greyed
  out away from a berth, knots readout, slider orders ahead and neutral, the
  hint is gone after the first delivery, one card per offer.

Checks run on the agent's Linux runner, Godot 4.7.2 official, headless:

- Passed: import, `check_scripts` (188 scripts), boot, `units_probe`,
  `check_catalog`, `diagnostics_probe`, `check_controls`, `check_flow`,
  `check_starter`, `check_helm_keys`, `check_m1_voyage`, all twelve Stage 2
  probes, `collision_probe`, `composition_probe`, `ports_probe`,
  `voyage_probe`, `sailing_save_probe`, `public_physics_probe`.
- Rendered with GL Compatibility on a software driver (Mesa llvmpipe under
  Xvfb) at 1280x720. The agent looked at screenshots at sea, under way with a
  job, docked with the job cards, docked with a job aboard, and the SHIPS list.
- Failed once and fixed: `check_m1_voyage` reported a resource still in use at
  exit (the flat minimap the globe replaces was not freed).
- `voyage_probe` fails when run a second time on the same data folder (its own
  leftover test files); it does the same without this change. It passes on a
  clean folder, which is how the Checks job runs.
- `shared_gauges_probe` (not in the Checks job) passes its checks but does not
  exit; it does the same without this change.
- Not run: the Python stage (no Python file changed), `cargo_matrix_probe`,
  the online-panel probes, anything on Windows, any real graphics card, any
  playtest. Other window sizes and fullscreen were not looked at.

Limits:

- The slider was driven by code in the check, not by a real mouse drag.
- A heavy job still shows its Lower, Raise and Cancel pickup buttons and
  guidance text top left while it is active. Not seen on screen.
- The globe names only the destination port; other ports are dots.
- The import again wrote `.uid` files for older scripts that lack one. They
  are not in this change. No workflow file changed.

## Patch 2.1 item 1: 3D bow splash — November 13, 2026 (run on Linux, not on Windows)

Issue #77. Only this item; the wake trail, swells and rocking code is untouched.

- New `features/water/bow_splash.gd` and `bow_splash.gdshader`. White chunks
  are thrown up and out from both sides of the bow, arc under gravity and are
  gone when they sink back under the drawn swell. Two raised crests stand up
  off the stem and sweep back. A two-tone shader (white tops, pale blue
  undersides) makes them read as solid toon lumps.
- Bigger with speed: more chunks, larger chunks, thrown higher, taller crests.
  Nothing below about 10% of full foam strength, so nothing when stopped.
  At most 96 chunks; half the rate on low water quality. Reversing splashes at
  the stern. It does not use pausing and never writes to the ship.
- `features/water/ship_wake.gd`: the flat bow curls and the old small particle
  spray are removed and replaced by the splash. The V wake, swirls and hull
  foam ring are the same code as before.
- `export_presets.cfg`: the two new files added. Their `.uid` files were
  written by Godot during the import, not by hand.
- `tools/water_probe.gd`: the two old spray checks are replaced by seven for
  the splash (chunks at speed, height, at the bow, drawn, smaller when slow,
  stern when reversing, none when stopped).

Checks run on the agent's Linux runner, Godot 4.7.2 official, headless:

- Passed: import, `check_scripts` (189 scripts), boot, `check_catalog`,
  `check_controls`, `check_flow`, `check_starter`, `check_helm_keys`,
  `check_m1_voyage`, all twelve Stage 2 probes including `water_probe`
  (75 checks), `units_probe`, `diagnostics_probe`, `collision_probe`,
  `composition_probe`, `ports_probe`. Nothing failed.
- Rendered with GL Compatibility on a software driver (Mesa llvmpipe under
  Xvfb) at 1280x720 in the Boat Handling scene. The agent looked at three
  screenshots from the front quarter: full speed (chunks all round the bow),
  slow (a few small lumps), stopped (none).
- Not run: the Python stage (no Python file changed), the online probes,
  anything on Windows, any real graphics card, any playtest.

Limits:

- Seen only as still screenshots, not in motion, and not in the game scene
  (it uses the same `ShipWake`). In the stills the chunks read clearly; the
  raised crests are low and read mostly as white from above. Size, height and
  amount are first guesses for Andy to judge.
- The splash is full size at 8 m/s, like the wake. Item 2 (faster ships) has
  to rescale both.
- The import again wrote `.uid` files for older scripts that lack one. They
  are not in this change. No workflow file changed.

## Patch 2.1 item 2: Faster ships — November 13, 2026 (Godot checks NOT run)

Issue #79. Only this item. No Godot check ran for this change: the agent runner
has no Godot and was not allowed to fetch one this time. The PR must wait for
the Checks workflow.

New handling numbers (ship records in `features/catalog/records`):

| Ship | Ahead m/s² | Astern m/s² | Drag 1/s | Top speed | Astern top |
|---|---:|---:|---:|---:|---:|
| Starter, Coastal | 3.087 (was 0.8) | 1.25 (was 0.5) | 0.2 (was 0.08) | 30.0 kn (was 19.4) | 7.3 kn (same) |
| Swift | 3.704 | 1.25 | 0.2 | 36.0 kn (was 23.3) | 7.3 kn |
| Harbor | 2.778 | 1.25 | 0.2 | 27.0 kn (was 17.5) | 7.3 kn |
| Heavy lifter (empty) | 2.122 | 0.875 | 0.2 | 20.6 kn (was 13.4) | 5.1 kn |

- Every ship keeps its old share of the starter's speed (Swift +20%, Harbor
  -10%, heavy lifter about two thirds). All stay under the 20 m/s collision cap.
- Starter, holding full ahead from a stop: 27 kn at 12.6 s, 29.3 kn at 16 s,
  the HUD reads "30 kn" at about 21 s. Before, 95% of top speed took 38.5 s.
- Starter, from full speed: throttle to neutral stops in 16.4 s over 81 m
  (was 31 s); holding reverse stops in 9.6 s over 66 m (was 17.6 s).
- These times come from a Python replay of `HandlingShip.advance_motion`,
  written by the agent for this change (not in the repository). With the old
  numbers it reproduced the recorded handling baselines.
- Turn rate, thrusters, throttle and engine ramps, the neutral stop assist and
  the Dock speed limit (3 m/s, about 6 kn) are unchanged.
- Wake, bow splash and rocking were full strength at 8 m/s (80% of the old
  top speed). They are now full at 12.35 m/s (80% of 30 kn), one constant in
  `ship_wake.gd`, so each looks the same at the same throttle as before. Splash
  chunks are carried along a little more so they fall behind the bow at the
  old rate. No other wake, swell or rocking code changed.
- Fuel burn per second is unchanged, so a trip of the same length burns about
  a third less fuel. Job pay is by load and distance and has no time limit, so
  pay is unchanged. The camera trails about 3 m at top speed (was 2 m).
- `features/world/world_layout.json` (planning check only, not read by the
  game): new top speeds; the trip-time targets are shortened to fit (starter
  6-9 min, short 9-11, medium 11-16.5, long 16.5-24); the minimum shortcut
  saving is 120 s (was 180 s); the four legs measured at the old speed are
  removed and need measuring again.
- Probes updated for the new numbers: `tools/simulation_checkpoint.gd`
  (handling baselines, from the Python replay), `tools/handling_probe.gd` (two
  expected values), `tools/water_probe.gd` (uses the new full-strength speed).

Checks:

- Passed on the agent's Linux runner: `python3 -m compileall services tools`,
  the 76 service unit tests, the 6 `tools/world_layout` tests and
  `traversal_budget.py` (WORLD_LAYOUT_PASS, 17 routes).
- Could not run here: `tools/public_handoff` tests (4 of 18 need `psycopg`,
  which is not installed on this runner; no file they cover changed).
- Not run: every Godot check (import, `check_scripts`, boot, all probes,
  `check_m1_voyage`), anything on Windows, any playtest. The agent read each
  probe that moves a ship and replayed the handling and collision cases in
  Python, but that is not a run.

Limits:

- Nobody has felt or seen the new speeds. The numbers are a first guess for
  Andy to judge.
- The turning circle at full speed is about 1.5 times wider (same turn rate,
  higher speed).
- In `collision_probe`, a 1 m/s coast into a wall now reaches it with only
  about 0.1 m to spare (was 0.3 m). It may need a nudge if the Checks run
  disagrees.
- The bulk, gas and oil ship records use the built-in default handling and
  are unchanged; the game does not sail them with their own handling.
- WORLD_LAYOUT.md still shows the old trip-time tables. No workflow file
  changed. No new runtime resource, so `export_presets.cfg` is unchanged.

## Patch 2.1 item 3A: map wrapping and minimap — November 13, 2026 (run on Linux, not on Windows)

Issue #85. First half of item 3 only: the world wraps, and the globe minimap
shows it. No polar ports and no icebergs yet (3B).

What changed:

- The game world now repeats every 4000 pi metres (about 12.57 km) east-west
  and north-south, centred on the strait. A ship that sails off any edge,
  top and bottom included, carries on from the opposite edge
  (`Progression.WRAP_M`, `wrapped`, `nearest`; `wrap_world` in `port_test.gd`,
  game only). Sailing once round takes about 13.5 minutes at 30 kn. The land
  has at least 2.7 km of open sea to every edge.
- This is a flat wrap (top joins bottom), as the issue asks, not a true globe
  where crossing a pole brings you back on the far side of the same pole.
- Nothing jumps on screen at the edge: the camera, the wake trail and the bow
  splash chunks are moved with the ship. The size was picked so every swell
  and tone wave in the ocean shader fits a whole number of times, so the
  swell, rocking and colour bands match across the edge with no change to
  them. The white swirl lines do not repeat, so the ocean shader has one new
  uniform (`swirl_origin`, zero until the first wrap) that slides them by the
  same step. The wake, waves and rocking code is otherwise unchanged.
- Globe minimap: the ship now stays in the middle and the world rolls under
  it; once round the world is one full turn of the globe, either way. Land,
  ports and the dotted course are drawn the short way round, across an edge
  when that is closer. A destination over the horizon sits on the rim in the
  direction to sail. One globe radian is now 2,000 m (was 3,200 m), so the
  globe shows about 3.1 km around the ship.
- The heavy-job waypoint and its distance use the nearest copy of the target.
- `tools/check_m1_voyage.gd` also checks the wrap in each direction, the open
  sea round the land and the globe scale.

Checks (agent's Linux runner, Godot 4.7.2 stable, headless):

- Passed: import, `check_scripts`, boot, the whole stage 2 smoke set of the
  Checks workflow (18 runs), `check_m1_voyage` (M1_VOYAGE_CHECK_PASS),
  `python3 -m compileall services tools`, the `tools/world_layout` tests and
  `traversal_budget.py`.
- Software-rendered screenshots (xvfb): the globe at the start, south of the
  strait, at the east edge and at a corner. Frames 1 m before and 1 m after
  the east edge and the bottom edge differ no more than two ordinary frames
  1 m apart.
- Not run: the other Python suites (no file they cover changed), anything on
  Windows, any playtest.

Limits:

- Nobody has sailed across an edge on a real screen yet.
- Far out at sea the globe shows only water and grid lines until land comes
  over the horizon.
- The job panel's distance to a port is still the straight-line distance, not
  the way round. The ports are all nearer the straight way, so it reads the
  same today.
- After many trips round the world in the same direction in one sitting
  (dozens), the swirl lines may get slightly coarser; a reload resets it.
- The older test scenes (F3) do not wrap. Saves are unchanged. No workflow
  file changed. No new runtime resource, so `export_presets.cfg` is unchanged.

## Patch 2.1 item 3B: polar ports and icebergs — November 13, 2026 (run on Linux, not on Windows)

Issue #91. Second half of item 3, in two commits: the ports, then the icebergs.

What changed:

- Two new ports in the game scene: North Pole at (3700, 4000), north of all
  the strait land, and South Pole at (-2300, -4100), south of it. Ice-white
  dressing (`icy` on the port scene, `_dress_icy` in `chunky_look.gd`): frosty
  quay, snow on the roof, containers, crane or fuel tank, snow drifts and
  icicles. Each has a solid ice shelf beside the quay (`Progression.ICE_SHELVES`).
  Both have container, heavy, refuel and repair services.
- Jobs: each pole has three container jobs (to every other port in turn),
  three bulk jobs and the three heavy jobs. Each strait port gets a fourth
  container slot, a part load to the North Pole and the South Pole in turn.
  The strait ports' first three slots keep their old destinations, so saved
  jobs still match their IDs and old saves load.
- Leg length (pay) is now measured the short way round the world. No strait
  leg changes; the pole-to-pole leg (7.5 km) goes over the edge.
- Twenty solid toon icebergs, ten round each pole (`Progression.ICEBERGS`,
  `add_iceberg` in `port_test.gd`): a pale ice band at the waterline, a white
  body and one or two peaks, ink outline, collider like land. Each sits at its
  copy nearest the ship, so none is torn by the world's edge. They keep clear
  of every quay, approach and heavy drop area.
- Globe minimap: ice shelves in white, icebergs as small white dots.
- `check_m1_voyage` checks the polar ports, their jobs, that saved strait jobs
  keep their destinations, the icebergs' clearances and the edge copies.
  `ports_probe` expects the new job counts. `export_presets.cfg` lists the six
  new port resources. Wake, waves, rocking and bow splash are unchanged.

Checks (agent's Linux runner, Godot 4.7.2 stable, headless, fresh user data):

- Passed: import, `check_scripts`, boot, the whole stage 2 smoke set of the
  Checks workflow, stage 4 (`collision_probe`, `composition_probe`,
  `ports_probe`), `voyage_probe`, `check_m1_voyage` (M1_VOYAGE_CHECK_PASS),
  `python3 -m compileall services tools`, the stage 3 service tests, the
  `tools/world_layout` tests and `traversal_budget.py`.
- A throwaway probe (not committed) placed a ship at each polar berth: Dock is
  ready, and the spawn, recovery, heavy pickup and drop areas are clear.
- Software-rendered screenshots (xvfb) of both polar ports and of icebergs.
- Could not run: 4 `tools/public_handoff` tests need `psycopg` (not on this
  runner; no file they cover changed). `content_extension_probe` (not in CI)
  fails one ship check on main too. Nothing on Windows, no playtest.

Limits:

- Nobody has sailed to a pole on a real screen yet. Positions, iceberg sizes
  and the ice colours are a first draft for Andy to judge.
- The North Pole is reached round the east end of the strait, the South Pole
  round the west end, or over an edge.
- Bulk jobs from the strait ports still go only to strait ports.
- `voyage_probe` fails if run twice in the same user data folder (old saves
  left behind); it passes on a fresh folder, as in CI.
- The older test scenes (F3) have no polar ports or icebergs.

## Patch 2.1 item 4: multiplayer-safe docking — November 13, 2026 (run on Linux, not on Windows)

REBUILD_PLAN.md section 6, item 4. Not playtested; Andy has not played it.

- Every port now has two berths in a row along its quay, 150 m apart
  (`test_port.gd` `BERTH_COUNT`, `berth_anchors`, `berth_id`). Berth 1 is the
  authored one and keeps its ID; berth 2 is `..._02` and shares its rules. The
  quay runs on past berth 2 (`QuayExtension`). Land, ice shelves and icebergs
  stay clear of it.
- Berth claims (`berth_claims.gd`): one ship per berth, one berth per ship. The
  docking authority only asks it (`holder`, `claim`, `release`,
  `release_owner`), so a future server can own the table. The authority also
  gives up the slide if the claim is taken away mid-slide.
- Dock (`docking_authority.gd` `pick_berth`) keeps the auto-slide and takes the
  nearest free berth; a berth held by another ship or filled by one is
  skipped. With none free, Dock is greyed out and says "Port full — every
  berth is taken." A save docked at berth 2 should load back there (nearest berth; not tested).
- Ship collision: from Dock until the ship has left the berth box and is clear
  of every other ship, it sits on a new `CollisionRules.DOCKED_HULL` layer and
  meets only the shore, so ships pass through each other there. The berth
  check and spawn clearance still see these hulls, so ships never overlap.
- `ports_probe` has a new set: an AI ship holds berth 1, the captain is sent to
  berth 2, a third ship gets "port full", collision is off while sliding and
  docked, stays off while still in the berth or touching a ship, and comes back
  once clear. Still single-player. Wake, waves, rocking and splash unchanged.

Checks (agent's Linux runner, Godot 4.7.2 official, headless, fresh user data):

- Passed: import, `check_scripts`, boot, the whole stage 2 smoke set, stage 4
  (`collision_probe`, `composition_probe`, `ports_probe` 320 checks),
  `voyage_probe`, `sailing_save_probe`, `bulk_service_probe`, `check_m1_voyage`,
  `check_helm_keys`, `python3 -m compileall services tools`, the
  `tools/world_layout` tests and `traversal_budget.py`.
- Failed, same on unchanged main: `public_physics_probe` (frozen online code,
  not in CI; "head-on hulls never pass through one another").
- Passed: the stage 3 service unit tests. Not run: `tools/public_handoff`
  (needs `psycopg`, not on this runner; no file it covers changed). Nothing on Windows, no playtest, no screenshots.

Limits: two berths per port is a first draft. The older test scenes (F3) get
the second berth too. Undock still hands the helm back in place; the captain
sails out of the berth.

## Patch 2.2 item 1 — Container family ships 2-5 (November 13, 2026)

REBUILD_PLAN.md section 7, item 1. Not playtested; Andy has not played it.

- Ladder (`progression.gd` `SHIPS`, `CONTAINER_KINDS`; records
  `container_0{2..5}_ship.tres`). Speed, length × beam, containers, price:
  1 starter (unchanged) 30 kn, 64×13 m, 24, 800 · 2 Coastal feeder 33 kn,
  96×18 m, 60, 12,000 · 3 Panamax 36 kn, 140×25 m, 112, 45,000 ·
  4 Neo-Panamax 39 kn, 200×32 m, 180, 120,000 · 5 Ultra-large 42 kn,
  270×38 m, 288, 300,000 credits. Drag falls 0.2 → 0.1, so it takes about
  20 s → 40 s to reach full speed. Reverse, turn rate, thrusters and the
  neutral stop also fall with size. Fuel, tank, camera, wake and rocking
  scale with the hull. `CollisionRules.SUPPORTED_SPEED_MPS` went from 20 to
  22 m/s so ships 4 and 5 reach 39 and 42 kn.
- Models (`chunky_look.gd` `_dress_box_ship`): toon hulls sized from each
  record, in the container family colours. Ship 2 has two deck cranes, ship 3
  a tall stern house, ship 4 twin funnels, and ship 5 its bridge forward with
  the funnel aft. Container stacks come from per-ship layouts written by
  `tools/build_container_ladder.py`, with a 512-slot limit (was 256).
- Jobs (`container_offers.gd`): every port also has two jobs per ship 2-5
  (`container_t<tier>_…`). One is a 55-75% part load, the other a full ship.
  Bigger ships earn 10-40% more per container. Above 24 containers the crane
  is faster (0.15 s a box, about 65 s for 288). The board hides jobs the ship
  cannot carry, lists jobs for the ship's own tier first and shows at most 6.
  The starter's board and job IDs are unchanged.
- Berths: the berth boxes at all six ports went from 180-230 m to 290 m long,
  so every ship docks everywhere, polar ports included. Ship 5 is 38 m wide
  and stays clear of the quay face on the berth centreline. A ship too big
  for every berth now gets "Too big for this port…". The minimap arrow grows
  with the hull.
- Saves: the kind "container" is still ship 1. Version 4/5 saves that name a
  ship by record ID map onto the ladder (`Progression.migrate`):
  starter/harbor → ship 1, coastal/swift → ship 2. The manifest and fuel are
  checked against the sailed ship's own record. `world_layout.json` lists the
  new hulls, with a new XL class for ships 4-5.

Checks (agent's Linux runner, Godot 4.7.2 official, headless, fresh user data):

- Passed: import, `check_scripts` (191), boot, the whole stage 2 smoke set,
  stage 4 (`collision_probe`, `composition_probe`, `ports_probe` 320),
  `check_m1_voyage`, `voyage_probe`, `sailing_save_probe`, `check_helm_keys`.
  New `tools/container_ladder_check.gd` passed 484 checks: ladder data, tier
  jobs, old IDs, and in the game scene each ship spawns, wears its model and
  docks at all six ports with no quay overlap. Its job board and saves pass too.
- Passed: stage 3 (compileall, service unit tests, `tools/public_handoff` 48
  with psycopg in a temporary venv, `tools/world_layout`, `traversal_budget.py`).
- Updated for the new jobs or the new cap: counts in `ports_probe` and
  `check_m1_voyage` now count only starter jobs, and `collision_probe` reads
  the cap.
- `voyage_probe` fails when rerun on top of its own earlier run's user data.
  It passes on fresh data, which is how CI runs it.
- Not run: anything on Windows, a playtest or screenshots (headless cannot
  render).

Limits: ships 2-5 sail the starter's runtime scene with their own record. The
imported starter GLB is hidden under the toon model, as before, and Port Test
(F3) still has only the starter. Upkeep and repair prices do not scale by
tier. The hangar is item 4.

## Patch 2.2 item 2 — Bulk family ships 1-5 (November 13, 2026)

REBUILD_PLAN.md section 7, item 2. Not playtested; Andy has not played it.

- Ladder (`progression.gd` `SHIPS`, `BULK_KINDS`; records `bulk_0{1..5}_ship.tres`).
  Speed, length × beam, deadweight, price: 1 Handysize 28 kn, 60×13 m, 6,000 t,
  1,200 (old bulk price) · 2 Supramax 31 kn, 92×18 m, 15,000 t, 18,000 ·
  3 Panamax 34 kn, 136×24 m, 28,000 t, 67,500 · 4 Capesize 37 kn, 204×32 m,
  45,000 t, 180,000 · 5 Valemax 40 kn, 276×38 m, 72,000 t, 450,000 credits.
  Drag, turning, reverse, thrusters, fuel, camera and wake follow the container
  tiers. Ship 1 now has its own record (it used to sail the starter's).
- Models (`chunky_look.gd` `_dress_bulker`): blue and orange toon hulls sized
  from each record. Hatch rows grow from 4 to 11 covers and the stern house gets
  taller with each tier. Ships 1-2 have deck cranes, ships 3-5 a raised
  forecastle, and ship 5 twin funnels.
- Jobs: the ship 1 job IDs, titles and pay are unchanged (`bulk_<port>_<cargo>`).
  Ships 2-5 get `bulk_t<tier>_<port>_<cargo>`, three per port per tier. Their
  tonnage is in step with deadweight (ore is a full load) and they pay 10-40%
  more per tonne. The board lists the ship's own tier first, then smaller
  loads, never anything bigger, and at most 6 cards. A bulk ship docks
  without the container cargo check. Bulk still loads at once, so there is no
  crane time to scale.
- Saves: the kind "bulk" is still ship 1, and the old prototype record ID maps
  onto it. A save cannot hold a job bigger than its ship.
  `world_layout.json` lists the five hulls. The check_m1_voyage button label
  now reads the ship name ("Handysize bulker").

Checks (agent's Linux runner, Godot 4.7.2 official, headless, fresh user data):

- Passed: import, `check_scripts` (192), boot, the whole stage 2 smoke set,
  stage 4 (`collision_probe`, `composition_probe`, `ports_probe`),
  `check_m1_voyage` (the bulk buy, switch, dock and continue still work),
  `voyage_probe`, `sailing_save_probe`, `check_helm_keys`, and
  `container_ladder_check`.
- New `tools/bulk_ladder_check.gd` passed 503 checks. It covers the ladder
  data, tier jobs and refused IDs. In the game scene, each ship spawns, wears
  its model, docks at all six ports clear of the quay, sees a board it can
  carry, takes and saves its own job, and an old prototype save loads.
- Passed: stage 3 (compileall, service unit tests, `tools/world_layout`,
  `traversal_budget.py`, `tools/public_handoff` with psycopg in a temp venv).
- Not run: anything on Windows, a playtest or screenshots (headless cannot
  render).

Limits: Bulk Port Test (the on-hold service prototype) still uses
`bulk_ship.tres`. Upkeep and repair prices do not scale by tier.

## Patch 2.2 item 3 — Heavy-lift family ships 2-5 (November 13, 2026)

REBUILD_PLAN.md section 7, item 3. Not playtested; Andy has not played it.

- Ladder (`progression.gd` `SHIPS`, `HEAVY_KINDS`; records `heavy_0{2..5}_ship.tres`).
  Speed, length × beam, price: 1 Heavy lifter (unchanged) 90×24 m, 3,000 ·
  2 Twin-crane project ship 29 kn, 130×26 m, 45,000 · 3 Twin-crane heavy lifter
  32 kn, 175×30 m, 150,000 · 4 Semi-submersible 35 kn, 220×36 m, 400,000 ·
  5 Giant semi-submersible 38 kn, 270×38 m, 900,000 credits. Drag falls
  0.2 → 0.1 (about 20 s → 40 s to full speed); reverse, turn, thrusters, fuel,
  camera and wake scale with the hull. All sail heavy mode on the same runtime.
- Lifter (`heavy_lifter.gd`): deck, colliders, deck model, pickup reach and load
  limits scale by beam and length from ship 1 (`k`); deck heights unchanged.
  Ship 1 is unchanged (k = 1).
- Models (`chunky_look.gd` `_dress_heavy`): ship 1's look, stretched to match the
  colliders. Ships 2-3 have two deck cranes on the port wall, ships 4-5 stern
  buoyancy towers and a funnel on the bridge, ship 5 a helideck.
- Jobs (`heavy_ocean_job.gd`): ship 1 jobs, IDs and pay are unchanged. Ships 2-5
  get three jobs per port (`<port>_heavy_t<tier>_<i>`) with bigger, heavier
  pieces (70/85/95% of the ship's biggest load) and 6×/18×/42×/90× ship 1 pay
  (ship 5's best job pays 90,000 credits, about 10 trips to buy it). Own tier first,
  then smaller, never bigger, at most 6. Heavier loads sit the hull lower.
- Saves: "heavy" is still ship 1 and `ship_heavy_lifter_01` maps onto it; the new
  record IDs map to their kinds. heavy_mode follows any heavy kind. A save cannot
  hold a heavy job bigger than its ship; a restored load keeps its tier's size.
  `world_layout.json` lists the new hulls.

Checks (agent's Linux runner, Godot 4.7.2 official, headless, fresh user data):

- New `tools/heavy_ladder_check.gd` passed 603 checks: ladder data, tier jobs,
  old IDs; in the game scene every ship spawns, wears its model, docks clear of
  the quay at the five heavy ports, sees a board it can carry, gets its biggest
  load staged at each port, lifts it, saves, delivers it at sea and is paid;
  a ship 5 carrying save restores in a fresh scene with its load aboard.
- Passed: import, `check_scripts` (193), boot, stage 2 smoke set, stage 4
  (`collision_probe`, `composition_probe`, `ports_probe` 320), `check_m1_voyage`,
  `check_helm_keys`, `voyage_probe`, `sailing_save_probe`, `cargo_matrix_probe`,
  `container_ladder_check`, `bulk_ladder_check`; stage 3 Python (compileall,
  service tests, world_layout, traversal_budget, public_handoff with psycopg in
  a temp venv).
- Failed on main too (not in CI, unchanged): `fleet_inspection_probe` (3) and
  `heavy_transport_probe` (needs the real HTTP heavy service).
- Not run: Windows, a playtest or screenshots.

Limits: heavy ship 1 still tops out at about 20.6 kn, not the plan table's
26 kn (item 3 keeps the current heavy lifter; Andy to decide). Cinder Point has
no heavy berth (as before), so no heavy ship docks there. A big lifter's piece is staged at
the same spot off each quay as ship 1's.

## Patch 2.2 item 4 — Boat hangar screen (November 13, 2026)

REBUILD_PLAN.md section 7, item 4. Not playtested; Andy has not played it.

- SHIPS on the port card now opens `features/game/boat_hangar.gd`: a full-screen
  toon boat shed (plank floor, water slip, red pitched roof, back doors swung
  open onto sea and sky, six warm hanging lamps) in its own SubViewport world,
  with one ship turning slowly in the slip. Every ship is drawn the same length;
  its real size is in the stats. The world keeps running under it (no pause);
  the helm is released while it is open.
- Ladder: the 15 container, bulk and heavy-lift ships (no gas or oil). Left /
  right: on-screen arrows, arrow keys, A/D, d-pad. Filter All / Container / Bulk
  / Heavy lift at the top (also up/down, W/S). Card: name (ACTIVE / OWNED), family
  and tier, size, top speed, capacity, price, wallet. Stats and model are read
  from the same index every frame, so they cannot desync.
- Not owned: Buy (or "Need X more" when short). Owned: Select (the old switch
  rules: docked, no job aboard; the reason shows when refused), then back to the
  game. Active ship: Active. Sell (two presses) kept from the old list. Presses
  within 0.6 s of a Buy/Select/Sell are ignored, so a double press charges once.
  Enter / A acts; Esc / B is Back and does not open the Esc menu.
- Models: `chunky_look.gd` `model(kind, definition)` is the sailing look on its
  own (dress_ship now calls it). All 15 are built once on first open and cached.
- Fix: switching to a bigger ship at the same port failed with "Spawn
  occupied", because the ship being replaced (its hull and its own spawn hold)
  blocked the new spawn. `select_port` now ignores the outgoing ship while
  reserving and restores both if the reservation still fails.
- `check_m1_voyage` drives the hangar for its buy/switch/sell steps.
  `export_presets.cfg` lists the new script.

Checks (agent's Linux runner, Godot 4.7.2 official, headless, fresh user data):

- New `tools/hangar_check.gd` passed 179 checks: in the game scene, SHIPS opens
  the hangar without pausing; 15 models cached; arrows/keys cycle and wrap with
  matching stats and one visible model; filters; short-wallet Buy; Esc goes back
  without the menu; every ship bought (double press charges once) and selected
  through the hangar, refused with a reason when undocked, docked and offered a
  board it can carry; a reload keeps all 15 ships, the active ship and the wallet.
- Passed: import, `check_scripts` (195), boot, stage 2 smoke set, stage 4
  probes, `check_m1_voyage`, `check_helm_keys`, `voyage_probe`,
  `sailing_save_probe`, `cargo_matrix_probe`, the container, bulk and heavy
  ladder checks; stage 3 Python except `tools/public_handoff` (compileall,
  service unit tests, world_layout, traversal_budget).
- Not run: Windows, a playtest, screenshots (headless cannot render, so the
  shed has not been seen by anyone), `tools/public_handoff` (needs psycopg).

Limits: the old row list behind SHIPS is still built (hidden) because its
refresh code is shared; it is no longer shown in the game.

## Patch 2.3 item 1: debug game mode (November 14, 2026)

A temporary test tool. It is not a feature, and it is easy to remove: the code is in `features/debug/debug_game.gd`, and the few hooks elsewhere are marked "Patch 2.3 debug".

- Title menu: a DEBUG button under PLAY and SETTINGS. The title screen is otherwise unchanged. The button sets one tree flag and opens the real game scene. Back at the title, `main.gd` clears the flag.
- In a debug world the game scene creates no voyage persistence, so it never opens, reads or writes a save file or save slot. MAIN MENU and Quit throw the world away.
- What the debug layer does:
  - Shows a red DEBUG tag on its own top layer, so it stays visible over the hangar and the Esc menu.
  - Owns all 15 ladder ships and holds 1,000,000,000 credits, topped up whenever the balance falls below half.
  - Adds a HANGAR button that opens the hangar anywhere. Away from a berth, Select swaps ships on the spot, keeping position and heading. The ship starts stopped, with a full tank and full hull. When docked, it uses the normal switch.
  - Has a quick-travel list for all six ports, polar ports included. It jumps the ship, stopped, to the port's spawn point. It is refused while docked or loading.
  - Shows a readout: ship name, current kn, top kn, and the time to full speed. "Full speed" means within 0.5 kn of top speed, worked out from the engine ramp and drag in `HandlingShip`. The starter ship comes out at about 21 s.
- Jobs, docking, wake, splash, world wrap and fuel all run as normal. The only rule relaxed is "dock to switch ships", and only in debug.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: the new `tools/debug_game_check.gd` (72 checks). A normal game writes a real save. A debug session then confirms no persistence, the tag, all 15 ships, credits refill, a hangar Select while undocked that keeps the ship in place, swaps to all 15 ships with the readout, and quick travel to all six ports with ship 5. MAIN MENU then clears the flag. The real save files are byte-for-byte identical (MD5), and the default save path is untouched.
- Also passed: import, `check_scripts` (197), boot, `check_flow`, `check_controls`, `check_starter`, `check_catalog`, `hangar_check`, `check_m1_voyage`, `check_helm_keys`, the container, bulk and heavy ladder checks, `diagnostics_probe`, `ports_probe`, `voyage_probe` and `sailing_save_probe`.
- Not run: Windows, a playtest, screenshots (the panel layout has not been seen), and the Python stages. `debug_game_check` is not in the CI job, because `.github/workflows` was not edited.

## Patch 2.4 item 1: hull trim bug (November 14, 2026)

Cause: the hulls themselves were fine (every chunky hull has its origin at
mid-length with the waterline at y = 0, keel -3.2 s, deck 2.6 s, s = hull
height / 4). The fault was in `ShipVisualMotion`: pitch was a fixed angle
(up to 7 degrees, 1.2 degrees bow-up at speed, a 1.4 degree chop and a 2x swell
tilt) on every ship, so on a 270 m hull a degree moves the ends by more than
2 m. At full speed ship 5's deck went 2.66 m under water (bulk 5: 2.90 m).

- `ShipVisualMotion.configure_hull(definition)` (used by `ShipAssembly`) sizes
  the rocking per hull. Pitch, chop, trim and swell tilt scale by deck height
  over hull length (ship 1 = 1.0, ship 5 about 0.47). The pitch limit keeps
  the ends within 30% of their deck height. Roll scales with sqrt(beam), and
  the lean is included. Trim at speed is 0.4 degrees bow-up on ship 1 (was 1.2),
  and the speed heave chop is 0.2 m (was 0.3).
- Max pitch now: ship 1 is 1.4 degrees (was up to about 5.6 at speed), ship 5 is
  0.66 degrees. Heavy lifters keep `visual_bobbing = false` and sit still and
  level as before. Wake, splash, load sink and the navigation body are unchanged.
- The automated check is in `tools/water_probe.gd` `check_ladder_trim`, already
  in CI Stage 2. All 15 ladder ships, empty and loaded, are run at rest and at
  full speed on high water for 60 s. Bow and stern decks must stay at least 10%
  of deck height above the local water. The keel stays wet at both ends. The
  pitch stays within the hull's limit. The mean trim is between level and 0.5
  degrees bow-up (never bow-down). The mean heave stays within 0.25 m of the
  waterline. It prints a TRIM line per case. Ship 5 at full speed: 2.72 m of
  deck clear empty, 1.88 m loaded.

Checks (agent's Linux runner, official Godot 4.7.2 with a verified SHA-512, headless):

- Passed: import, `check_scripts`, boot, and the whole CI Stage 2 set
  (`water_probe` went from 75 to 336 checks; `handling_probe`, `feedback_probe`,
  `heavy_lifter_probe`, `camera_probe` and the others are unchanged).
- Not run: Windows, a playtest, screenshots, the Stage 3 Python and Stage 4.
  The smaller ships now rock noticeably less than in Patch 2.0. Andy should
  confirm that it still feels lively.

## Patch 2.4 item 2: faster turning (November 14, 2026)

- Every ship's `max_turn_rate_degrees` and `turn_acceleration_degrees` are doubled
  in its catalog record, so each ship's full-speed turning circle is half its old
  size. The ladder order is kept: bigger ships still turn wider. Rudder authority
  at low speed, the handling code and save IDs are unchanged.
- Turn rate in deg/s (old → new) and the full-speed, full-rudder radius in metres
  (old → new):
  - Container 1-5: 3.0→6.0 (295→147 m), 2.7→5.4 (360→180), 2.4→4.8 (442→221),
    2.0→4.0 (575→287), 1.7→3.4 (728→364).
  - Bulk 1-5: 3.0→6.0 (275→138), 2.7→5.4 (338→169), 2.4→4.8 (418→209),
    2.0→4.0 (545→273), 1.7→3.4 (694→347).
  - Heavy 1-5: 2.0→4.0 (304→152), 1.8→3.6 (475→237), 1.6→3.2 (590→295),
    1.4→2.8 (737→368), 1.25→2.5 (896→448).
  - Swift and coastal: 3.0→6.0. Harbor: 3.6→7.2. Turn acceleration is doubled too
    (for example, the starter goes from 2.0 to 4.0 deg/s², and container 5 goes
    from 0.9 to 1.8).
- New checks in the three ladder checks: each tier's turning circle must be wider
  than the tier before, and every ship must turn within 460 m at full speed.
- Test updates for the new tuning:
  - The `simulation_checkpoint` "turn" baseline was recaptured from the
    production replay. Heading is 55.55 deg (was 27.77) and speed is unchanged.
  - `handling_probe` now reads the yaw acceleration bound from the definition.
  - `water_probe` turns at the ship's own max rate for the lean check. At the
    same yaw rate the hull leans half as much as before, but at full rudder the
    lean is unchanged.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: import, `check_scripts`, boot, `check_catalog`, the whole CI Stage 2
  set (including `handling_probe` with 134 checks and `water_probe` with 336),
  the container ladder check (493), bulk ladder, heavy ladder (612),
  `hangar_check`, `debug_game_check`, `check_helm_keys` and `check_m1_voyage`.
- Before the test updates, `handling_probe` and `water_probe` failed only on the
  hard-coded old turn numbers. Both passed on the base commit.
- Not run: Windows, a playtest, Stage 3 Python (no Python was changed), Stage 4,
  and the network probes (online is frozen). Andy should check whether the big
  ships now feel right or need more turn.

## Patch 2.4 item 3: bigger ports and quay gap (November 14, 2026)

- Every port (polar ones included) now has three berths 285 m apart (was two,
  150 m apart). Each berth fits a ship 5 (276 m), so three of the biggest ships
  can dock at once. Berth 3's ID is `<berth>_03`. Old berth IDs and save IDs are
  unchanged. Berth claiming from Patch 2.1 works as before.
- The quays are now about 800 m long (Cinder Point is 790 m, so it ends just
  short of the northern shore). The longer quays have three warehouses
  (`Warehouse`, `Warehouse2`, `Warehouse3`). The chunky and icy dressing roofs,
  tints and snow-caps each one. Bollards, the timber face, snow drifts and
  icicles run the full length.
- The quay gap is scaled per hull. The docking slide now ends with the hull's
  quay-side edge 8% of its beam off the timber face, clamped to 1.2-3 m. The
  starter sits 1.2 m off, and the 38 m-beam ship 5s sit 3 m off. Before, every
  ship was centred on the berth line: small ships sat about 13 m out, and ship 5
  sat 0.1 m from the face. The gap comes from `test_port.gd`
  `quay_gap_m`/`quay_offset_m`, and `berth_eligibility.berth_pose` uses it. The
  frozen online strict rule is unchanged.
- `tools/ports_probe.gd` has new and updated checks for every port:
  - the gap for 10 ladder hulls stays within 1.2-3 m and grows with the beam;
  - each hull, docked at each berth, stays clear of the quay;
  - three ship 5s fit end to end;
  - the quay covers the last berth;
  - the berth tests now use three berths (a second AI ship fills berth 3 for the
    "port full" check), and the slide and undock positions use the gap.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: import, `check_scripts` (197), boot, the whole CI Stage 2 set,
  `collision_probe`, `composition_probe` and `ports_probe` (489 checks, was 320).
  These also passed: the container ladder (493), bulk ladder (512) and heavy
  ladder (612) checks, `hangar_check` (179), `debug_game_check` (72),
  `check_helm_keys` and `check_m1_voyage`.
- Not run: Windows, a playtest, screenshots, Stage 3 Python and Stage 4, and the
  network probes (online is frozen). Nobody has seen the longer quays or the
  fender gap on screen yet. Andy should check that the ports look good and the
  gap looks right.

## Patch 2.4 item 4: mooring ropes (November 14, 2026)

- Every ladder ship model (all 15, built in `chunky_look.gd`) now has a pair of
  black bitts and a fairlead on the rail at the bow and the stern, on both
  sides. Heavy lifters carry theirs on the side walls. A marker on each fairlead
  (`MooringBowL/R`, `MooringSternL/R`) is where a line leaves the ship.
- New `features/ports/mooring_lines.gd` (the game only). When a ship finishes
  docking, toon rope lines arc out over 1.2 s and settle with a gentle sag
  on the quay's existing bollards. The lines leave from the quay side, and
  each makes fast to the nearest bollard where it should lead. Every ship gets
  a bow line (leads forward) and a stern line (leads aft). Ships 120 m or longer
  also get a fore and an aft spring. On Undock the lines let go and arc back
  aboard. The docking authority's new `undock_seconds` (0.5 s as before; the game
  sets 1.0 s) holds the ship in the berth until they are in. Cancelling Undock
  puts them back out. The lines are only visuals and never change docking state.
- `test_port.bollard_points()` is the single list of quay bollards. The port
  dressing draws its bollards from it, in the same places as before.
- Limitation: a ship 5 at berth 1 hangs about 40-65 m past the start of the
  quay (layout from item 3), so its stern line goes to the aftmost bollard and
  leads slightly forward. Andy should say whether berth 1 or the quay start
  should move.
- New `tools/mooring_check.gd` (386 checks): every model has its four
  fairleads on the rail. In the real game scene, ships 1 and 5 of each family
  dock and tie up with 2 or 4 lines on quay bollards that lead the right way.
  On Undock each ship stays put while the lines come in, and the helm returns
  only after that.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: import, `check_scripts` (199), boot, the whole CI Stage 2 set,
  `collision_probe`, `composition_probe`, `ports_probe` (489), `voyage_probe`,
  `mooring_check` (386), the container (493), bulk (512) and heavy (612) ladder
  checks, `hangar_check` (179), `debug_game_check` (72), `check_helm_keys` and
  `check_m1_voyage`.
- Not run: Stage 3 Python (no Python changed), Windows, screenshots, a
  playtest and the network probes (online is frozen). Nobody has seen the ropes
  on screen yet. Andy should check that they read as ropes, that the arc out and
  back looks right, and that the bitts don't clash with deck houses or cranes on
  the bigger ships.

## Patch 2.4 item 5: containers one by one (November 14, 2026)

- New `features/ports/container_cranes.gd` (the game only): every berth of
  every port, polar too, has six toon ship-to-shore cranes on quay rails. Idle
  cranes park with their booms raised. When a container ship is docked,
  `cranes_for(capacity)` of them lower their booms and work: ship 1 gets 2,
  ship 2 3, ship 3 4, ship 4 5 and ship 5 6. Each crane owns a band of whole
  bays. It rolls to a bay, hoists, trolleys across and lowers one box at a
  time, bottom tier first (top first when unloading). The cranes never come
  closer than 13 m on the rails.
- Looks only. The manifest and the loading timer (`port_loading.gd`) stay the
  authority, and loading times are unchanged. The cranes start a move for each
  container the timer has reached, at a pace that matches it. Full loads in the
  check: ship 1, 24 boxes in 26.3 s (timer 25.5 s); ship 3, 112 in 41.2 s
  (38.7 s); ship 5, 288 in 67.0 s (65.1 s). Delivery and Abandon empty the
  manifest at once as before, and the cranes then take the boxes ashore one by
  one, at the same pace. Undock stays greyed out until the last box is down. The
  status line says "The cranes are working: N containers to go."
- `container_visuals.gd` can now show or hide single slots. Without cranes
  (test scenes, a ship at sea, a reload) it still shows the manifest straight
  away, as before. `public_world_view.gd` goes through the same call. Nothing
  new is saved, so old saves load unchanged.
- The old landmark gantry at North Pole and Slatewater Works is hidden in the
  game. The berth cranes replace it, and it stood in their path. Its nodes stay,
  so the test scenes keep it. The polar snow drifts moved landward of the crane
  rails.
- New `tools/crane_check.gd` (153 checks). In the real game scene, ships 1, 3
  and 5 dock and load a full job one box at a time, in about the timer's time,
  never over an empty slot. Undock waits for the cranes, and the cranes stay
  spaced on the rails. Abandoning the cargo takes it off one box at a time.
  After undocking the booms go up. A bulk ship gets no crane work.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: import, `check_scripts` (201), boot, the whole CI Stage 2 set,
  `collision_probe`, `composition_probe`, `ports_probe` (489), `voyage_probe`
  (101), `crane_check` (153), `mooring_check` (386), the container (493), bulk
  (512) and heavy (612) ladder checks, `hangar_check` (179),
  `debug_game_check` (72) and `check_helm_keys`.
- Failed, as on `main` without this change: `check_m1_voyage` passes but takes
  70 s, over the 30 s rule. `content_extension_probe` still fails its one
  check, "inspection reads capacity from the definition".
- Not run: Stage 3 Python (no Python changed), Windows, screenshots, a
  playtest and the network probes (online is frozen). Nobody has seen the
  cranes on screen yet. Andy should check:
  - how 108 cranes (6 ports x 3 berths x 6) run on Windows;
  - whether the raised booms look right;
  - whether a box every ~1.1-1.8 s per crane reads well or looks frantic;
  - that boxes appearing on, and vanishing from, the quay under the crane
    are acceptable (there are no trucks).

## Patch 2.4 item 6: heavy-lift load looks (November 14, 2026)

- New `features/cargo/heavy_load_looks.gd` builds three toon loads in code: a
  white wind turbine tower section on two saddles, a green transformer block
  with radiator fins, bushings and conservator on a skid, and a tug hull in
  three steel cradles. Each one is built at its job load's real size (width,
  height, length), stands on the deck and fills that envelope. So a bigger
  heavy lifter's bigger load is a bigger piece.
- Job `i` at a port wears look `i` on every tier (`heavy_ocean_job.gd`
  `load_of` now returns `look`). Job titles name the piece ("Transformer
  block, <mass> t"). Ship 1's titles changed from "Platform module" etc. to the
  look names. Job IDs, sizes, masses, pay and saves are unchanged.
- `heavy_lifter.gd` hangs the look under the existing `payload_visual`, undoing
  its envelope scale, and hides the placeholder model. Pickup, release,
  collider, draft, saves and the online code see the same node as before.
  Fixtures and online keep the old placeholder model. The look shows on the
  staged floating load while loading and on deck while carrying.
- `heavy_ladder_check.gd` adds 95 checks: three different looks per tier;
  each look fits its envelope, rests on the deck and fills the envelope; the
  biggest piece grows each tier; in the game scene, every heavy ship's staged
  load wears its look at real size.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: import, `check_scripts` (202), boot, the whole CI Stage 2 set,
  `heavy_ladder_check` (707), `heavy_lifter_probe` (65), `voyage_probe` (101),
  `debug_game_check` (72), `crane_check` (153), `mooring_check` (386),
  `check_m1_voyage`.
- Failed, as on `main` without this change: `heavy_transport_probe` and
  `cargo_network_probe`, which need the private service and network.
- Not run: Stage 3 Python (no Python changed), Windows, screenshots and a
  playtest. Nobody has seen the looks on screen yet. Andy should check that
  the three pieces read clearly and sit right on every heavy ship's deck.

## Patch 2.4 item 7: 3D globe map (November 14, 2026)

- New `features/game/globe_map.gd`, added to the game scene only
  (`port_test.gd`, game mode): M (the existing "Map" binding) opens a large
  globe in a 3D SubViewport in the middle of the screen. The world is laid on
  it like an atlas page: east-west wraps round, the north and south edges are
  the poles. It shows land, ice shelves, icebergs, every port with its name
  (polar ports too, current port in yellow), the ship as a yellow arrow sized
  like the minimap's and a pulsing ring on the job's destination. Toon shading
  and an ink rim.
- It opens centred on the ship, north up. Dragging turns it about the screen's
  axes, so it rolls freely in every direction, over the poles too. The wheel
  zooms between set limits. M or Esc closes it before the Esc menu sees the key.
  The hangar or Esc menu opening closes it. Nothing pauses; the helm keeps the
  keyboard and the small minimap stays.
- Limitation: the world wraps north-south, so a ship sailing over the north
  edge jumps from the north pole to the south pole on the big globe.
- `export_presets.cfg` lists the new script. No new resource files.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: import, `check_scripts` (204), new `globe_map_check` (46),
  `check_m1_voyage`, `check_helm_keys`, `check_controls`, `check_flow`,
  `hangar_check` (179), `debug_game_check` (72).
- Not run: the rest of the CI Stage 2 set, Stage 3 Python (no Python changed),
  Windows, screenshots and a playtest. Nobody has seen the globe on screen yet.
  Andy should check that it reads clearly, drags smoothly and that the
  north-south jump is acceptable.

## Patch 2.4 item 8: small boats family (November 14, 2026)

- Three new ladder kinds in `progression.gd` (`SMALL_KINDS`, `small_tier`)
  with their own records (`features/catalog/records/small_*_ship.tres`, save
  IDs `ship_small_*` map to the kinds): fishing boat (16 × 5 m, 12 kn, 200
  credits), speedboat (8.5 × 2.8 m, 36 kn, 400 credits) and offshore racer
  (13 × 2.8 m, 42 kn, 600 credits). They sail the starter runtime, turn
  sharply and reach full speed in a few seconds. No cargo: the job board stays
  empty and Accept says "Small boats take no cargo jobs"; they dock (no cargo
  check) to refuel and switch ships. Old save IDs are unchanged.
- Toon models in `chunky_look.gd` (`_dress_small`), each with mooring fairleads.
  Hangar: a fifth filter, "Small boats" ("boat N of 3", capacity "none, just
  for fun"). Debug mode owns them through `Hangar.ladder()`.
- Jumping (`ship_visual_motion.gd`, presentation only, body and collider stay
  on the water plane): records set `jump_lift` and `chop_height_m`. On the
  water the hull rides the swell plus a speed-dependent chop; the wave face
  gives it lift × the water's rise rate. When the water falls away faster than
  gravity, the hull flies a ballistic arc (9.81 m/s²), bow following the arc,
  and lands with a critically damped dip and no relaunch for 0.25 s. Pitch is
  capped at 14°, roll at 12°. Bow spray stops while airborne; `BowSplash.burst`
  throws a spray ring on landing. Bow spray and crests scale with the hull
  (ladder ships unchanged, factor 1).
- Limitation: the racer's top speed is held to 42 kn by the existing 22 m/s
  collision speed cap (`CollisionRules.SUPPORTED_SPEED_MPS`), which was not
  raised. It feels fast through its acceleration and turning.
- `export_presets.cfg` lists the three new records.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: import, `check_scripts` (205), `--quit-after 10`, new
  `small_boats_check` (70: records, prices, models, migration, and 60 s at
  full speed at 30 and 60 fps: racer longest jump 1.5 s, speedboat 0.5 s,
  fishing boat none, no snaps, no chatter, no flip), `hangar_check` (213,
  now 18 ships incl. buying, selecting and docking each small boat),
  `debug_game_check` (81), `water_probe` (336), `mooring_check`,
  `crane_check`, the three ladder checks, `globe_map_check`, `check_catalog`,
  `check_controls`, `check_flow`, `check_starter`, `check_m1_voyage`,
  `check_helm_keys`, and every CI Stage 2 probe (units to economy).
- Not run: Stage 3 Python (no Python changed), Windows, screenshots and a
  playtest. Nobody has seen the boats jump on screen yet; Andy should judge the
  airtime, the landing splash and whether 42 kn is fast enough for the racer.

Follow-up fix (CI Stage 3 Python): `tools/world_layout/traversal_budget.py`
failed with "planned hulls do not match the ship records" because it expected
every ShipDefinition record to have a planned cargo hull. It now leaves out
ship records with no `cargo_type_ids` (the three small boats take no cargo jobs,
so they have no route budget). Gas and oil hulls are still planned and checked,
and `world_layout.json` is unchanged. Not run: the agent was not allowed to run
Python on this runner, so the unittest discovery and `traversal_budget.py`
still need a CI run.

## Patch 2.5 item 1A: landmasses, straits and oceans (November 14, 2026)

- `progression.gd` `LAND` now holds two continents built round the existing
  strait. Hearthland is behind Brindle Quay and Cinder Point, with the South
  Pole on its southern tip. Ironreach is behind Slatewater Works and Gannet
  Light. Between them are the Northern Neck, Kelp Isle, Gull Isle and the two
  old islets. `LANDMASSES` names the blocks.
- `STRAITS` holds three straits and a canal:
  - Needle Gut (Bosphorus-like, 200 m wide)
  - Gannet Narrows (Gibraltar-like, 550 m)
  - Kelp Strait (Malacca-like, 250 m wide, 4 km long)
  - Ironreach Canal (Panama-like, 140 m)

  Each one takes 2.5 beams of a ship 5. Open oceans run across the wrapping
  edges. All land stays 2 km inside the edges, so wrap and polar behaviour are
  unchanged. Each polar ice shelf now runs on to its quay.
- Every port ID, position, job and save format is unchanged. Each quay backs
  onto land. Berths, approach, spawn and the heavy drop area stay open water.
- Land is solid: one SHORE box per block, as before. The blocks share four
  materials, and the green top only steps back on sides that face the sea, so
  there are no sand seams across a continent. The camera's 3 km far plane
  culls distant land.
- Navigation: `SEA_LANES` plus `Progression.sea_route`/`course` find the
  shortest way that stays 60 m off land, ice, icebergs and quays, the short
  way round the wrap. The route is cached until the ship moves 50 m.
  `LocalNavigation.target` adds `route` in the game, and the globe minimap's
  dotted course follows it. Nothing steers the ship.
- Spawn clearance already queries SHORE. The new check proves a ship 5 spawns
  clear at every port.
- Tests:
  - New `tools/world_land_check.gd` (88 checks): landmasses, coasts, port
    water, all 30 port-to-port sea routes (longest 9.4 km), the straits, solid
    bodies, shared materials, spawn clearance, a minimap course round the land,
    and a ship driven full ahead at Kelp Isle stopping at the shore.
  - `traversal_budget.py` reads the game world from `progression.gd`. It checks
    the same rules plus every cargo hull's leg time and fuel on each sea route.
    Settings are in the new `game_world` block of `world_layout.json`, with 4
    new unit tests. The old planning layout is untouched.
- Part B still needs: toon coastlines and beaches (shaped coast meshes instead
  of boxes, sand, surf), the minimap and the M globe drawing the land properly
  (both still draw the blocks as rectangles), and the globe's course line along
  the route.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: import, `check_scripts`, `--quit-after 10`, `world_land_check` (88),
  `check_catalog`, `check_controls`, `check_flow`, `check_starter`,
  `check_m1_voyage`, `check_helm_keys`, `globe_map_check`, `debug_game_check`,
  `hangar_check`, `small_boats_check`, `heavy_ladder_check`, `mooring_check`,
  `crane_check`, every CI Stage 2 probe, `voyage_probe`, `ports_probe`,
  `traversal_budget.py` and its unittest discovery (10).
- Not run: the rest of CI Stage 3 Python (no service code changed), Windows,
  screenshots, frame timing and a playtest. Nobody has seen the new land on
  screen yet.

## Patch 2.5 item 1B: toon coasts, minimap and globe land (November 14, 2026)

- New `features/toon/toon_coast.gd` builds the look of each land block from
  part A. The SHORE collision box under it is unchanged. Each block gets:
  - a sloped beach on every side that faces the sea, running from below the
    waterline up to deck height (4 m);
  - a green hill on top, sloping up to 18 m; ice shelves get the same shape in
    ice and snow;
  - a straight harbour wall at deck height on any side within 320 m of a port,
    so every quay still backs onto land;
  - a surf band at the waterline on its beaches. The surf follows the same
    swell as the sea, so the white line moves up and down the sand. It uses one
    shared alpha-scissor shader and is not drawn past 1.5 km.
  - Sides covered by another block stay flat, so a continent has no seams.
- Land uses one mesh with two surfaces per block. The blocks share their
  materials, so the toon pass still makes two land shaders. There is one draw
  call more per beach block (the surf), and the 3 km far plane still culls
  distant land.
- Minimap globe: each block is drawn as an ink coast, then a sand beach, then
  green land. All the outlines go down before any fills, so a continent reads
  as one shape and the seams between blocks are gone.
- M globe: the atlas draws the ink before the fills too, with a 1 px coast so
  the 140 m canal stays open. A new dotted course runs along the sea route
  (`draw_course`), each leg taking the short way round the wrap.
- Port IDs, jobs, saves, land data and sea routes are all unchanged. The
  traversal budget therefore has nothing new to check; it still passes.
- Tests:
  - `world_land_check` is now 130 checks. New ones: every block has a coast, the
    materials are shared, the surf uses one shader, is culled at range and
    follows the sea's swell, every port has a harbour wall, each landmass is
    green on the globe atlas, and each strait is open water there.
  - `globe_map_check` is now 48 checks. New ones: the course is drawn along the
    route, and with no job there is no course.

Checks (agent's Linux runner, official Godot 4.7.2, headless):

- Passed: import, `check_scripts` (207), `--quit-after 10`, `world_land_check`
  (130), `globe_map_check` (48), `check_catalog`, `check_controls`,
  `check_flow`, `check_starter`, `check_m1_voyage`, `check_helm_keys`,
  `debug_game_check`, `hangar_check`, `small_boats_check`, `heavy_ladder_check`,
  `mooring_check`, `crane_check`, every CI Stage 2 probe, `voyage_probe`,
  `ports_probe`, `traversal_budget.py` (17 routes) and its unittest discovery.
- Not run: CI Stage 3 Python (no service code changed), Windows, screenshots
  and frame timing (headless renders nothing), and a playtest. Nobody has seen
  the coasts, the surf or the globe course on screen yet.

## Patch 2.5 item 2: bridges you pass under (November 14, 2026)

- Four toon bridges, one per strait (`Progression.BRIDGES`, built by
  `features/toon/toon_bridge.gd` into the real game scene under `Bridges`):
  - Gannet Narrows Bridge: the big red suspension bridge. Two 174 m towers,
    main cables that sag to the deck, hangers every 15 m, anchor blocks on
    both shores.
  - Needle Gut Bridge: a green tied arch over the deck.
  - Kelp Strait Bridge: a white cable-stayed bridge with fans of stays.
  - Ironreach Canal Bridge: a blue through truss.
- The deck underside is 70 m above the sea. The tallest ship in any family,
  measured dressed as in the game, is the Valemax bulker at 49.8 m. Heavy
  lifters stay under about 18 m even with their biggest load.
- Towers and piers are solid (`SHORE` collision) and stand on land, out of the
  channel. Each deck runs flat past the beach, then ramps down onto the hills
  on stone piers. The deck has no collision: no ship reaches it, and the chase
  camera passes under it smoothly instead of being pulled in.
- Frame time: each bridge is two merged meshes (structure and rigging) with
  shared materials. All four take about 5 ms to build and come to roughly
  5,500 triangles in total. The rigging stops drawing at 3 km and the
  structure at 9 km.
- Ports, jobs, saves, land, sea lanes and routes are unchanged.
- `world_land_check` is now 161 checks. New: at least three bridges with one
  suspension bridge; the deck clears the measured tallest ship by 15 m; both
  ends land on land; every tower and pier stands on land, out of the channel;
  a ship 5 sized box sweeps under each bridge without hitting anything; the
  bridges cull far away and share their materials.
- Fixed a timing race in that check: the surf test could run before the game's
  second drawn frame, so it now waits two frames.

Checks (agent's Linux runner, official Godot 4.7.2):

- Passed, headless: import, `check_scripts`, `--quit-after 10`,
  `world_land_check` (161, 4 of 4 runs), `globe_map_check` (48),
  `check_catalog`, `check_controls`, `check_flow`, `check_starter`,
  `check_m1_voyage`, `check_helm_keys`, `debug_game_check`, `hangar_check`,
  `small_boats_check`, `heavy_ladder_check`, `mooring_check`, `crane_check`,
  every CI Stage 2 probe, `voyage_probe`, `ports_probe`, `traversal_budget.py`
  (17 routes) and its unittests.
- Screenshots: chase-camera views of all four bridges, rendered with OpenGL
  under Xvfb on Linux. They read well, including from straight under the
  Gannet deck.
- Not run: Windows, frame timing on the target, and a playtest.
- Known: `world_land_check` sometimes ends with "2 ObjectDB instances were
  leaked". That happens on main too; it comes from game audio.

## Patch 2.5 item 3: North Pole biome — November 14, 2026

- New `features/sky/polar_biome.gd`, added to the real game scene only. Near
  the world's north/south edge it blends in a colder look: cooler colour
  grading (lower saturation, slight blue colour correction), paler sky and
  clouds, paler icy sea, cooler sun and ambient light, closer pale fog, and
  light snow falling round the camera.
- Region: fully polar within 2,350 m of the north/south edge (both polar ports
  and all icebergs), none beyond 2,950 m; a smoothstep over that 600 m band,
  also eased in time (at least 1.5 s), so debug quick travel fades rather than
  snaps. The world wraps north-south, so the North Pole sea runs on into the
  South Pole sea; both share the look and there is no seam at the edge.
- Frame time: one pooled `GPUParticles3D` (900 flakes, `amount_ratio` follows
  the blend, stops emitting outside). Look values repaint only when the blend
  changes; grading is off outside the polar sea. On a world wrap the snow
  moves with the ship. Leaving restores the temperate look exactly.
- Ports, jobs, saves, land, bridges, icebergs and the hangar are unchanged.
  `export_presets.cfg` lists the new script.
- New check `tools/polar_biome_check.gd` (46 checks).

Checks (agent's Linux runner, official Godot 4.7.2):

- Passed, headless: import, `check_scripts`, `--quit-after 10`,
  `polar_biome_check` (46), `world_land_check` (161), `globe_map_check` (48),
  `debug_game_check` (81), `hangar_check` (213), `check_flow`,
  `check_m1_voyage`.
- Screenshot: the chase camera at Brindle Quay before and with the polar look
  forced on, OpenGL under Xvfb. It renders: cold, pale, foggy, with snow.
- Not run: Windows, frame timing on the target, sailing into the polar sea in
  a playtest, the full CI probe list.

## Patch 2.5 item 4: Desert biome — November 14, 2026

- Region: north Hearthland round Cinder Point (`port_cinder_point`, same ID,
  berth, jobs and saves). Fully desert within 1,600 m of (-1700, 2300), none
  past 2,300 m, eased in time (at least 1.5 s). Every other port is outside;
  the desert is tapered out where the polar look is, and never shows in the
  full polar sea.
- New `features/sky/desert_biome.gd`: warm haze (closer sandy fog), warm sun
  and ambient light, sandy horizon, few clouds, a desert sea tone, dry warm
  grading. It paints over the polar look: `polar_biome.gd` gained one
  `overlay` hook, called after each repaint, so the two never fight. At zero
  it changes nothing; leaving restores the temperate look exactly.
- New `features/toon/desert_look.gd`: seeded dunes and banded mesas over the
  desert land blocks (one MultiMesh per kind, so few draw calls; dunes cast
  no shadow), clear of the sea and 450 m from every quay, not solid. Desert
  blocks get a sand top in place of green. Cinder Point gets a sandstone
  quay, adobe sheds with terracotta roofs, flat-roofed houses, a domed tower
  and cacti (looks only; colliders unchanged).
- `export_presets.cfg` lists both scripts. `world_land_check` now allows five
  shared land materials (the desert's sand top is the fifth).
- New check `tools/desert_biome_check.gd` (41 checks).

Checks (agent's Linux runner, official Godot 4.7.2, headless): import,
`check_scripts` (213), `--quit-after 10`, `desert_biome_check` (41),
`polar_biome_check` (46), `world_land_check` (161), `globe_map_check` (48),
`debug_game_check` (81), `hangar_check` (213), `check_flow`,
`check_m1_voyage`: all passed.

Not run: a rendered screenshot (software OpenGL under Xvfb timed out),
Windows, frame timing on the target, a playtest, the full CI probe list.

## Patch 2.5 item 5: Tropical biome — November 14, 2026

- Region: the southern strait round Gannet Light (`port_gannet_light`, same
  ID, berth, jobs and saves). Fully tropical within 1,250 m of (1000, -2300),
  none past 1,900 m, eased in time (at least 1.5 s). Every other port is
  outside. The tropical look fades out where the polar look is and never
  overlaps the desert.
- New `features/sky/tropical_biome.gd`: clear air (fog pushed back), bright
  sun, a vivid sky with an aqua horizon, a turquoise sea, bright saturated
  grading. It paints after the polar and desert looks: `polar_biome.gd` gained
  an `overlays` list next to its `overlay` hook. At zero it changes nothing.
- Palm Isles: three small solid islands (about 200-240 m across) added at the
  end of `Progression.LAND` as a new landmass. They are real land (collision,
  navigation, minimap, globe). Sea routes and the traversal budget are
  unchanged.
- New `features/toon/tropical_look.gd`: seeded palms (leaning trunks and
  drooping-frond crowns) along the beaches and on the hill tops, plus lush
  bushes, as three MultiMeshes, not solid, 450 m from every quay. Tropical
  land gets a lush green top. Turquoise lagoon rings (two toon bands, wavy
  edges) sit round every tropical island. They ride the same swell as the
  surf, use one shared material, are culled past 1.8 km and are paint only:
  no collider, nothing in the navigation, no hidden shallows. Gannet Light
  gets a whitewashed quay, pastel sheds under thatch, stilt huts, palms and a
  thatched lookout (looks only; colliders unchanged).
- `export_presets.cfg` lists both scripts. `world_land_check` now allows six
  shared land materials. New check `tools/tropical_biome_check.gd` (55).

Checks (agent's Linux runner, official Godot 4.7.2, headless): import,
`check_scripts` (216), `--quit-after 10`, `tropical_biome_check` (55),
`desert_biome_check` (41), `polar_biome_check` (46), `world_land_check`
(166), `globe_map_check` (48), `debug_game_check` (81), `hangar_check`
(213), `crane_check`, `mooring_check`, container/bulk/heavy ladder checks,
`check_m1_voyage`, `check_catalog`, `check_controls`, `check_flow`,
`check_starter`, the CI Stage 2 probe set, `traversal_budget.py` and the
`tools/world_layout` tests: all passed.

Not run: a rendered screenshot, Windows, frame timing on the target, a
playtest. Nobody has seen the tropics on screen yet.

## Patch 2.5 item 6: Rainy city port biome — November 14, 2026

- Region: Ironreach's west coast round Slatewater Works
  (`port_slatewater_works`, same ID, slot, berth, jobs and saves). Always
  raining within 740 m of (1650, 700), dry past 1,150 m, eased in time (at
  least 1.5 s). Brindle Quay (the start) and every other port stay dry; it
  never overlaps the polar, desert or tropical looks.
- New `features/sky/rain_biome.gd`: wet darker grading (less saturation and
  brightness, a cool ramp), grey overcast sky, murky fog, dim sun, dark sea.
  Painted last over the other biomes (`polar.overlays`). One pooled
  `GPUParticles3D` (1,600 streaks) follows the camera and carries over a world
  wrap; `amount_ratio` follows the blend, so the rain fades at the edge.
  Rain rings on the sea: a `rain_amount` uniform in `stylized_ocean.gdshader`
  (0 = off and skipped everywhere else), faded out past 180 m.
- New `features/toon/city_look.gd`: a seeded skyline of 218 towers on the city
  land as three MultiMeshes (slate, brick, concrete) plus roofs and red roof
  lights; windows are a shader grid with lit panes that glows brighter in the
  rain and blends flat far away (no shimmer); four yellow tower cranes. Not
  solid, 200 m clear of every quay. City land gets a wet dark top.
  Slatewater gets a wet slate quay, brick sheds, lit brick blocks behind the
  quay and street lamps (looks only; colliders unchanged).
- `export_presets.cfg` lists both scripts. `world_land_check` allows seven
  shared land materials. New check `tools/rain_biome_check.gd` (54).

Checks (agent's Linux runner, official Godot 4.7.2, headless): import,
`check_scripts` (219), `--quit-after 10`, `rain_biome_check` (54),
`tropical_biome_check` (55), `desert_biome_check` (41), `polar_biome_check`
(46), `world_land_check` (166), `globe_map_check`, `debug_game_check`,
`hangar_check`, `crane_check`, `mooring_check`, `small_boats_check`,
container/bulk/heavy ladder checks, `check_m1_voyage`, `check_catalog`,
`check_controls`, `check_flow`, `check_starter`, the CI Stage 2 and Stage 4
probe sets, `traversal_budget.py` and the `tools/world_layout` tests: all
passed.

Not run: a rendered screenshot, Windows, frame timing on the target, a
playtest. Nobody has seen the rain on screen yet.

## Patch 2.5 item 7: Volcano island — November 14, 2026

- Ember Isle: one volcano island, fixed in `progression.gd` (`VOLCANO`, LAND
  block 27, its own landmass) at (4480, -4120) in the cold south-eastern sea.
  It is over 1 km off every sea-lane leg, over 2.5 km off every port, over
  600 m off every iceberg and 470 m off Ironreach. Sea routes are unchanged.
  As a LAND block it gets a solid box, a toon coast and a place on the minimap
  and globe for free.
- New `features/toon/volcano_look.gd`: a chunky toon cone (ash skirt and rock
  cone, toon paint and ink outline), a lava crater and three lava runs, a
  solid cylinder collider, one pooled smoke emitter (48 puffs) and an orange
  glow light. The lava glows softly by day and brightly at night, and the glow
  light comes on only at night. The game has no day/night cycle yet, so "night"
  is read from the sun: set below the horizon, or dimmed well under daytime
  energy. Past 3.2 km the smoke and light switch off.
- `export_presets.cfg` lists the script. New check `tools/volcano_check.gd` (24).

Checks (agent's Linux runner, official Godot 4.7.2, headless): import,
`check_scripts`, `--quit-after 10`, `volcano_check` (24), `world_land_check`
(169), `polar/desert/tropical/rain_biome_check`, `globe_map_check`,
`debug_game_check`, `hangar_check`, `crane_check`, `mooring_check`,
`small_boats_check`, `check_m1_voyage`, `check_catalog`, `check_controls`,
`check_flow`, `check_starter`, the CI Stage 2 probe set, `traversal_budget.py`
and the `tools/world_layout` tests: all passed.

Not run: a rendered screenshot, Windows, frame timing on the target, a
playtest. Nobody has seen the volcano on screen yet, and it has never been
shown at a real night because the game has none yet.

## Patch 2.5 item 8: Polish pass — November 14, 2026

- The game's HUD has no key hints any more. The first-voyage controls panel
  (`game_hud.gd`) and `port_test.gd controls_hint()` are gone.
- Esc menu: RESUME, CONTROLS, SETTINGS, MAIN MENU, QUIT. CONTROLS
  (`game_menu.gd`) lists the keys as bound right now (throttle, steer,
  thrusters, engine to zero, horn, map, recenter) plus mouse look, zoom, map
  drag and Esc, with BACK; Esc returns to the menu. The "The world keeps
  running." note is gone.
- Plain words: the globe map's top line just says WORLD MAP; Settings is
  "Settings" with "Click a key to change it. Esc cancels."; the Esc binding row
  reads "Menu"; the title screen no longer says "four ports"; the game's port
  card shows the ship's name and wallet (it said "Container ship" for every
  ship); the game's helm banners for a paused or unloadable voyage no longer
  say "see the panel text" or "open this scene again"; the heavy-lift pickup
  hint drops "Crooked is fine — no angle matching required."
- Unchanged: test fixtures (Port Test, handling, bulk, gas, oil), the debug
  mode tag, quick travel and readout, the F3 developer overlay. No new runtime
  resources, so `export_presets.cfg` is unchanged.
- `check_m1_voyage` now checks there is no HUD hint, that CONTROLS lists the
  bound throttle keys and M for the map, and that Esc on it returns to the menu.

Checks (agent's Linux runner, official Godot 4.7.2, headless): import,
`check_scripts`, `--quit-after 10`, `check_m1_voyage`, `check_controls`,
`check_flow`, `check_starter`, `check_catalog`, `check_helm_keys`, every
`*_check.gd` (ladders, crane, debug_game, hangar, mooring, small boats, globe
map, world land, polar/desert/tropical/rain biomes, volcano), the CI Stage 2
probe set plus `voyage_probe`, `traversal_budget.py` and the
`tools/world_layout` tests: all passed. `migration_probe`, `slots_probe` and
`tools/public_handoff` (not in CI) fail the same way on unchanged main.

Not run: a rendered screenshot, Windows, a playtest. Nobody has seen the
Controls screen on screen yet.

## Patch 2.6 item 1: macOS export preset — November 14, 2026

- `export_presets.cfg` has a second preset, `macOS`: universal (arm64 +
  x86_64), built-in ad-hoc signing, notarization off, bundle id
  `com.andyviera.shippinglanes`, App Store category Games, HiDPI on, the same
  export file list and include filter as `Windows Desktop`, output
  `exports/macos/release/Container Ship Sim.zip`. The Windows preset is
  byte-for-byte unchanged.
- `project.godot`: `config/name.macos="Container Ship Sim"` (Mac app and
  window name only; Windows still says Shipping Lanes) and
  `import_etc2_astc=true`, which Godot requires for arm64 exports. Windows
  still exports S3TC/BPTC only.
- The repo had no game icon, so `features/app/app_icon.icns` is a new toon
  container-ship icon (32-1024 px), drawn by
  `art_sources/app_icon/make_icon.py` (Python standard library only).
- EXPORT.md: Mac export steps and how to open an unsigned app (right-click >
  Open, or `xattr -dr com.apple.quarantine`).

Checks (agent's Linux runner, official Godot 4.7.2 and its official export
templates, headless): import; `--export-release "macOS"` exit 0. The zip holds
`Container Ship Sim.app` with a universal Mach-O (x86_64 + arm64), ad-hoc
`_CodeSignature`, our icon, the right bundle id/name and
`NSHighResolutionCapable`. `check_scripts`, boot `--quit-after 10`,
`check_catalog`, `check_controls`, `check_flow`, `check_starter`,
`check_m1_voyage` and the CI Stage 2 probe set: all passed.

Export warning (known, for item 2): `addons/godot-sqlite` has no macOS
library, so the Mac app cannot save yet. Not run: a Windows export (preset
unchanged), opening the app on a Mac, a playtest.

## Patch 2.6 item 2: Mac compatibility pass — November 14, 2026

Audit of everything the game loads at runtime:
- Saves and preferences already use `user://` only (slots, voyage.db,
  preferences.json); no backslash paths, drive letters, `.exe` calls, Windows
  API or environment-variable paths in the single-player game. Godot maps
  `user://` to `~/Library/Application Support/Godot/app_userdata/Shipping
  Lanes` on macOS. Save format is unchanged, so saves load on both systems.
- Case-sensitive names: every `res://` reference in tracked `.gd/.tscn/.tres/
  .cfg/.godot/.gdextension/.json` files matches the file's exact case; no two
  tracked files differ only by case.
- **Fixed: SQLite had no macOS library** (item 1's export warning), so the Mac
  app could not save. Added the upstream godot-sqlite v4.9 macOS universal
  frameworks (`libgdsqlite.macos.template_{debug,release}.framework`, from the
  same `addons.zip` already pinned; archive hash matched) and their two lines
  in `gdsqlite.gdextension`. `sqlite-dependency.json` lists and hashes the new
  files. Windows/Linux binaries untouched.
- **Renderer:** `project.godot` keeps Compatibility for Windows/Linux and sets
  `rendering_method.macos="forward_plus"` with `driver.macos="metal"` and
  `fallback_to_opengl3=true` (if Metal fails Godot drops to Compatibility).
- **Shaders:** `atan(x, z)` in the toon sky and globe map is guarded at
  x=z=0 (zenith / poles), which is undefined on Metal. The bow splash flat
  normal now always faces the camera, so its white tops do not flip with the
  OpenGL vs Metal derivative sign. Same look as before on Windows.
- Left as-is (online, frozen): the friends-client flag/config files are read
  next to the executable, which on macOS is inside the `.app` bundle.

Checks (agent's Linux runner, official Godot 4.7.2, headless): import,
`check_scripts`, `--quit-after 10`, `check_catalog`, `check_controls`,
`check_flow`, `check_starter`, `check_m1_voyage`, the CI Stage 2 probe set,
`voyage_probe`, `sailing_save_probe` and every `tools/*_check.gd`: all passed.
`storage_probe`/`persistence_probe` need the Windows PowerShell runners'
isolated-root arguments and were not run. Not run: a Mac export with the new
frameworks, Forward+/Metal on a Mac, a Windows run, a playtest.

## Patch 2.6 item 3: Mac controls and display — November 14, 2026

- **Keys:** audit of every hard-coded key and default binding: letters, Space,
  Esc and F3 (dev toggle, Fn+F3 on a MacBook) only; no numpad, Home/End,
  Insert or Page keys are needed (they stay optional rebind targets). No game
  shortcut uses Ctrl; text fields get Cmd copy/paste from Godot on macOS.
- **Trackpad** (`player_controls.gd`, `orbit_camera_rig.gd`, `globe_map.gd`):
  two-finger scroll up/down zooms the ship camera and the M globe, sideways
  turns them; pinch zooms both. On macOS click-drag (and Ctrl-click drag) also
  orbits the ship camera, alongside right-drag. Windows input is unchanged
  (left-drag orbit is Mac-only; gestures only arrive from trackpads).
- **Retina/HiDPI:** on macOS the window's content scale is set to the screen
  scale (and follows `dpi_changed` when dragged between screens), so the HUD
  is its normal size and fonts/3D render at full pixel resolution; the first
  windowed start scales the window up to match (capped at 90% of the screen).
  Windows/Linux skip this.
- **Fullscreen/resize:** the fullscreen setting is now applied at start and
  when it changes, not on every scene change, so the macOS green button /
  Ctrl+Cmd+F is not undone when a scene loads.
- **Cmd+Q:** Godot's Mac app menu sends Cmd+Q as the window close request,
  which the game scene already answers by saving first (same as the Esc-menu
  Quit). A fallback catches Cmd+Q if it reaches the game and sends the same
  close request.

Checks (agent's Linux runner, official Godot 4.7.2, headless): import,
`check_scripts`, `--quit-after 10`, `check_catalog`, `diagnostics_probe`,
`check_controls`, `check_flow`, `check_starter`, `check_m1_voyage`, the CI
Stage 2 probe set, `voyage_probe`, `sailing_save_probe`: all passed, plus a
throwaway script (not committed) feeding pan/pinch gestures to
`PlayerControls`. Not run: anything on a Mac (gesture deltas, Retina scale,
window size, Cmd+Q are untested there), a Windows run, a playtest.

## Patch 2.6 item 4 — Apple Silicon performance (November 14, 2026)

Quality settings for an M2 MacBook Air (16 GB, fanless). Every change is
macOS-only (`.macos` project overrides or `OS.has_feature("macos")`), so the
Windows build and its quality are unchanged.

- **3D resolution:** on a Retina (2x) screen the 3D view renders at 0.75 of the
  window's pixel size (1.5x the logical size), upscaled with FSR 1 (sharpness
  0.3). HUD and text stay at full Retina resolution. Non-Retina Mac screens
  render at 1.0. (`PlayerControls.apply_display_scale`, `rendering/scaling_3d/*.macos`)
- **Frame cap:** `application/run/max_fps.macos=60`, together with V-Sync, gives
  a steady 60 and stops an external 120 Hz monitor from doubling the heat.
- **Sky radiance:** the animated toon sky would rebuild a 256 px radiance
  cubemap every frame under Forward+/Metal, and nothing reads it (sky ambient
  and reflections are off). On Mac it is 32 px. The visible sky does not change.
- **Auto quality preset:** on first run (no saved settings), Apple Silicon
  starts on Medium water and Intel Macs start on Low. Windows and Linux keep
  Medium. Saved settings always win.
- **No thermal-only effects:** checked. No SSAO/SSR/SDFGI/SSIL/volumetric fog/glow
  is turned on anywhere. Fog is depth fog. Shadows stay as they are (2 splits,
  500 m, hard edge). Rain, snow and smoke particle counts are unchanged.

Checks (agent's Linux runner, official Godot 4.7.2, headless): import,
`check_scripts`, `check_controls`, `water_probe`, `sailing_save_probe`,
`rain_biome_check` and `polar_biome_check` all passed. Not run: anything on a
Mac (frame rate, FSR look, heat and the arm64 feature tag are untested there),
a Windows run, a playtest.

## Patch 2.7 item 1 — title logo and Press Any Button screen (November 14, 2026)

- **Attract screen** (`features/title/title_screen.gd`): shown once per launch
  over the existing menu. The game's own ocean shader (royal-blue palette,
  `title_ocean.tres`) seen straight down in a small SubViewport, the mockup's
  light-blue streaks and curled swirl foam drifting on top, the logo centre-top
  and "Press Any Button" with its swirl flourishes pulsing below. Layout uses
  the mockup's proportions; keep-aspect art scales cleanly on 16:10 and
  ultrawide. Any key, mouse click or gamepad button fades it out (0.35 s) and
  shows the menu; the press is consumed so it cannot also press a menu button.
  Ctrl/Cmd/Alt shortcuts (Cmd+Q, Alt+F4) pass through; F3 still toggles debug
  mode. Skipped on headless runs unless `--title-check` is given, so scripted
  checks still start at the menu.
- **Art:** `tools/build_title_art.gd` cuts the logo and the "Press Any Button"
  line out of Andy's mockup (keyed, fringe removed, 2x Lanczos, 2456 px wide
  logo) plus the streak layer. It is a cleaned-up crop, not hand-drawn vector
  art.
- **Name:** visible title is Shipping Lanes (window title, menu heading, macOS
  app name and export zip, EXPORT.md). Bundle id, save paths and internal IDs
  unchanged. The frozen online screens/login text still say Container Ship Sim.
- **Export:** new files are picked up by the presets' "all resources" filter;
  both presets now exclude `docs/*` so the mockups do not ship.

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`,
`check_flow`, `check_controls`, `check_catalog`, `check_starter`,
`check_m1_voyage`, `--diagnostics-check`, `--quit-after 10`, new `check_title`
(headless and under xvfb at 1672x941, 1440x900, 2560x1080 with screenshots), a
120-frame windowed boot under xvfb: all passed. Not run: an export, Windows,
Mac, a real gamepad, a playtest.

## Patch 2.7 item 2 — logo moves and ship sails in (November 14, 2026)

- **Arrival** (`features/title/title_screen.gd`): the press fades "Press Any
  Button" (0.35 s), slides and shrinks the logo to the mockup's top-left spot
  (1.2 s) and sails a container ship in from off-screen left to centre-right,
  bow right, settling at 2.6 s with an ease-out. A second press skips to the
  end. It then cruises in place: the live ocean, streaks and wake slide left,
  the hull rolls and heaves a little. Layout from `menu_ship_arrives.png`
  (ship 0.80 screen heights long); on 16:10 the ship pulls in to stay on screen.
- **Ship:** a random tier 3-5 from the container ladder (tiers 1-2 are too short
  for the mockup's full deck), the same chunky toon model the hangar shows,
  every slot filled with bright boxes. Built at startup in its own transparent
  SubViewport, which only renders from the press on, so the press does not hitch.
- **Wake:** `features/title/menu_wake.gdshader`, a screen-space toon foam fan
  under the ship: light-blue tongues with sea showing through, a broken white
  rim and curled swirls on the edges. Its pattern scrolls with the water.
- **Menu:** once arrived, the screen drops below the menu layer and becomes the
  home page's backdrop. The old drawn sky and heading are hidden there and the
  old buttons, save notice and developer list move down under the logo. Other
  pages show the old backdrop, and the title viewports stop rendering while
  hidden. Item 3 replaces the buttons.

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`,
`--quit-after 10`, `check_catalog`, `diagnostics_probe`, `check_controls`,
`check_flow`, `check_starter`, `check_m1_voyage`, the 13 CI smoke probes,
`--title-check` boot, the extended `check_title` (headless and under xvfb with
screenshots), main-scene screenshots under xvfb at 1672x941, 1440x900,
1280x720 and 2560x1080, and a 120-frame windowed boot: all passed. On the first
xvfb run `check_title` failed its 6 s wall-clock wait while software GL compiled
shaders; the wait is now 15 s and later runs passed. Not run: an export,
Windows, Mac, a real gamepad, frame-time measurement on real hardware, a
playtest.

## Patch 2.7 item 3 — menu list and yellow swirl cursor (November 14, 2026)

- **Menu** (`features/ui/swirl_menu.gd`, used by `application_menu.gd`): the
  home page is now the mockup's text list, Start, Options, Credits, Quit Game,
  under the corner logo at `menu_ship_arrives.png`'s place and size (scaled by
  screen height). White bold serif (Georgia on Windows/Mac, a system font, no
  font file) with a navy outline and soft shadow. A yellow wind-swirl cursor,
  drawn in code, glides to the selected word and bobs. Arrows, W/S, mouse hover
  and click, gamepad d-pad/stick and A all move and choose; Esc/B goes back. A
  short tick on move and a rising blip on select (generated tones).
- **Start** begins a new game or continues the one save (the game has one
  save; the local save slots stay developer tests). **Options** holds Settings,
  Controls (the Patch 2.5 key list), Debug Mode (moved from the title), Restart
  Progress (only with a save) and Back; Settings closes back to Options.
  **Credits** rolls up: Shipping Lanes, a game by Andy Viera, made with the
  Godot Engine. **Quit Game** quits; Cmd+Q still works on Mac. The save notice
  is empty unless there is a message (the mockup has no text there). The
  friends-client menu is unchanged.
- `check_m1_voyage` now clicks Start, and Options > Restart Progress.

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`,
`--quit-after 10`, `check_flow`, `check_controls`, `check_starter`,
`check_title`, `check_m1_voyage`, `debug_game_check`, the friends-client menu
check, `diagnostics_probe`, `session_probe`, `handling_probe`,
`economy_probe`: all passed. `slots_probe` and `migration_probe` fail on this
runner with identical output before and after the change. Under xvfb at
1672x941: screenshots of home, Options, Controls and Credits, and a scripted
S / Down / Esc walk. Not run: an export, Windows, Mac (Georgia only seen via its
Linux fallback, DejaVu Serif), a real gamepad, sound on real hardware, a
playtest.

## Patch 2.7 item 4 — transitions and scaling (November 15, 2026)

- **Start** (`title_screen.gd` `depart`, `main.gd` `start_game`): the menu
  and logo fade, the camera follows the menu ship from straight above down to a
  low side view (34 degrees, closing in 1.9x) over 1.9 s while the wake and sea
  keep moving, then the screen fades to the sea's blue and the game loads under
  it. Presses during the dive are ignored (Cmd/Ctrl/Alt shortcuts still work).
- **Back to the main menu**: the game's Esc-menu Main menu (`port_test.gd`
  `leave`, after the save checkpoint as before) fades to the same blue, and the
  main menu replays the ship's arrival (no "Press Any Button"; a press skips).
  The fade (`features/title/screen_fade.gd`, new, in both export presets) lives
  on the tree root, waits a few frames into the new scene so its load hitch is
  hidden, then lifts. Headless runs skip both fades, so scripted checks are
  unchanged. Friends-client menu unchanged (no replay).
- **Scaling**: the title's 3D views now render at the window's real pixel size
  instead of the logical size, so on a 2x Retina screen the ship is drawn at
  full resolution (the sea is capped at 1.5x like the game's Mac 3D view).
  Layout was already scaled by screen height; checked again at 16:9, 16:10 and
  21:9.
- `check_title` now also checks the replay, the dive, the fade and that the
  fade frees itself.

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`,
`--quit-after 10`, `--title-check` boot, `check_title` (headless and under xvfb
at 1672x941, 1440x900 and 2560x1080 with screenshots), `check_flow`,
`check_controls`, `check_starter`, `check_catalog`, `check_m1_voyage`,
`debug_game_check`, friends-client menu check: all passed. Not run: the full
Start-to-game-and-back loop on a screen (checked in parts only), a Retina
display (content scale 2 was not simulated), an export, Windows, Mac, a real
gamepad, frame-time measurement on real hardware, a playtest.

## Patch 2.9 item 1 — city boxes and visual oddities sweep (November 15, 2026)

- **Cause:** the ink outline (`features/toon/toon_outline.gdshader`, an inverted
  hull) pushed vertices out in the mesh's own space, so the push was multiplied
  by the node's or MultiMesh instance's scale. The city towers are unit boxes
  scaled up to about 32 x 166 x 32 m, so each outline shell became a dark box tens
  to hundreds of metres across. Fog made them look translucent
  (`city_skyscraper_boxes.jpg`, `city_boxes_rain_night.jpg`). The desert mesas
  (scaled cylinders that cast shadows) had the same oversized shells, and those
  shells threw the large blotchy octagon shadows over the land
  (`odd_shadows_on_land.jpg`).
- **Fix:** the shader divides the push by the object's per-axis scale, so the
  line is a few centimetres to a few metres wide in the world, depending on
  camera distance. This is what the shader's comment always said it did.
  Unscaled meshes are unchanged. Scaled ones (city towers and roofs, mesas,
  dunes, palms, bushes, hangar models, crane ropes) now get the same line
  width as everything else. No other files changed.
- **Sweep:** checked the city skyline, desert, tropical and volcano dressing:
  no fog volumes, LOD shells or helper meshes are left visible. The outline was
  the only cause found. One thing is still open: a pale straight strip across the
  desert land, probably a seam between two land blocks (visible in the after shot). That land is replaced
  in item 6A, so it is left for that item. The crane bar and the ropes are
  items 2 and 3.
- **Screenshots:** `docs/reference/patch_2_9/city_skyscraper_boxes_{before,after}.png`
  and `odd_shadows_on_land_{before,after}.png` (Linux, xvfb, 1600x900).

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`,
`check_flow`, `check_starter`, `check_catalog`, `check_controls`,
`rain_biome_check`, `desert_biome_check`, `tropical_biome_check`,
`polar_biome_check`, `check_title` (xvfb): all passed. Not run: Windows, Mac,
an export, a playtest.

## Patch 2.9 item 2 — container crane black bar (November 15, 2026)

- **Cause:** the spreader was a 1 m unit box stretched to 2.8 x 0.6 x 6.5 m by
  its node. Its ink-outline shell was stretched by the same 6.5 along the quay,
  which made a dark bar about 20 m wide across each crane at hook height. In
  fog it looked grey and see-through (`crane_black_bar_1..3.jpg`). Item 1's
  outline fix had already shrunk the bar. This item removes the cause: the
  spreader mesh is now built at its real size (one mesh per container size,
  rebuilt only when the size changes), so nothing depends on the outline
  shader's scale handling. The ink-black boom-head and counterweight blocks
  at the two ends of each crane (the black squares in the photos) are now
  white, the same colour as the machinery house. The bogies stay dark.
  Booms, trolley, spreader, rope and all crane behaviour are unchanged. Only
  `features/ports/container_cranes.gd` changed.
- **Screenshots** (Linux, xvfb, 1600x900, a scratch script that was not
  committed): `docs/reference/patch_2_9/crane_black_bar_{before,after}.png`
  (from about 400 m out; "before" uses the outline shader from before item 1,
  as Andy played it) and `cranes_close_{before,after}.png` (current main
  compared with this fix).

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`
(226 scripts), `crane_check` (153 checks, ships 1/3/5 load and unload): passed.
Not run: Windows, Mac, an export, a playtest.

## Patch 2.9 item 3 — mooring ropes (November 15, 2026)

- **Cause:** each line was one sagging curve straight from the ship's
  fairlead to the bollard head. On most ships the fairlead sits below the
  quay top, so the line cut through the timber face and edge strip
  (`mooring_rope_through_dock.jpg`).
- **Fix** (`features/ports/mooring_lines.gd`, new `lie()` and `fly()`): the
  rest line now goes out over the rail to just outside the hull at rail
  height, sags across the gap (never deeper than lets it keep falling toward
  the edge), rests over the quay edge clear of the timber face and edge
  strip, runs to the existing bollard and makes a full loop round the post
  under its head. While a line is thrown out or reeled in it follows the
  same path with an upward heave, so it never clips more than at rest. Same
  bollards, berths, timings and Undock hold; no new geometry on the quay.
- **Check:** `tools/mooring_check.gd` now also checks every line of ships
  1 and 5 of each family at their first port: no point of the rope tube is
  below the edge strip or deck over the quay, below the rail inside the hull
  edge, or inside a bollard post, and the line ends looped round its bollard.
- **Screenshots** (Linux, xvfb, 1600x900, a scratch script that was not
  committed): `docs/reference/patch_2_9/mooring_rope_ship1_{before,after}.png`
  (before: the bow line vanishes into the quay edge; after: it lies over it
  and loops the bollard) and `mooring_rope_ship5_{before,after}.png`.

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`
(226 scripts), `mooring_check` (422 checks): passed.
Not run: Windows, Mac, an export, a playtest.

## Patch 2.9 item 4 — speeds and knots (November 15, 2026)

- **Speeds:** speedboat top speed 36 -> 50 kn, offshore (cigarette) racer
  42 -> 200 kn (`small_*_ship.tres`; the racer also grips more sideways,
  lateral drag 0.8 -> 2.0, so it does not skate wide in turns at 103 m/s).
  `CollisionRules.SUPPORTED_SPEED_MPS` is 22 -> 103 m/s.
- **Still controllable at 200 kn:** the camera is carried along above 22 m/s,
  so its lag is capped near 4.4 m (it was 20 m). The wake samples by distance
  above 22 m/s and the bow spray grows up to 2.5x. The wave-jumps meet the
  chop at no more than the old 21.6 m/s pace, so the racer is not thrown
  skyward. No tunnelling: `move_and_slide` sweeps the hull along each 1.7 m
  step, and `collision_probe`'s "overspeed clamped" fixture now hits its
  0.1 m wall at 103 m/s and stops. Land, bridges and the volcano use solid
  box or cylinder colliders.
- **Knots finding:** the maths is right. 1 world unit is 1 m and every
  readout uses 1 kn = 1852/3600 m/s. The HUD showed the raw velocity
  unsmoothed (still non-zero when pinned against land). It now shows the
  speed actually covered, smoothed over about 0.2 s. It feels off because
  hulls are about half real length (ship 1 is 64 m, a real feeder about
  140 m) and top speeds are arcade (30-42 kn against a real 16-24 kn). So a
  ship covers its own length 3-4x faster than a real one at the same
  number. Not rescaled: that would retune every ladder and the traversal
  budget.
- **Checks added:** `small_boats_check` checks 50 and 200 kn.
  `camera_probe` checks the lag behind a 102.9 m/s focus (19.7 m without the
  fix, under 6 m with it).

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`
(226 scripts), boot, `check_catalog`, `check_controls`, `check_flow`,
`check_starter`, `units_probe`, `diagnostics_probe`, `contracts_probe`,
`geography_probe`, `session_probe`, `clocks_probe`, `handling_probe`,
`camera_probe`, `water_probe`, `feedback_probe`, `world_size_probe`,
`heavy_lifter_probe`, `fuel_probe`, `economy_probe`, `collision_probe`,
`small_boats_check`, `hangar_check`, `debug_game_check`, the container, bulk
and heavy ladder checks, `check_m1_voyage`, `mooring_check` and
`world_land_check`: all passed.
Not run: Windows, Mac, an export, a playtest. 200 kn has not been seen on
screen, and frame time at 200 kn has not been measured.

## Patch 2.9 item 5 — cigarette boat remodel (November 15, 2026)

- **Model:** the offshore racer is rebuilt as a Cigarette Racing-style
  powerboat (`chunky_look.gd` `racer_hull_mesh` and `_dress_racer`): a long,
  narrow (4.6:1) deep-V hull with sharp chines, a step in the bottom just aft
  of amidships, a pointed bow and a flat transom; yellow, red and black racing
  bands that sweep up toward the stern, a black deck stripe and race-number
  roundels; long foredeck with a hatch, low wraparound windscreen, open
  cockpit with two bucket seats, a bench, dash and wheel; four outboards on
  the transom. Its mooring bitts are small flush cleats on the low deck (the
  fairlead markers stay). Toon shaded and outlined like every other model.
- **On the plane:** new record field `plane_trim_degrees` (0 for every other
  hull, 5 for the racer). `ShipVisualMotion` trims the bow up from about a
  third of cruise speed and lifts the hull with it so the stern stays wet, not
  sunk; at rest it floats level. Wave-jumps are unchanged.
- **Rooster tail:** `BowSplash` throws a plume of spray up from behind the
  transom of a planing hull while it is on the water going ahead (none in the
  air or astern); spray pool 96 -> 140 chunks, half rate on low quality.
- **Checks added:** `small_boats_check` checks the hull is long, narrow and
  deep-V, the model is fully dressed, the racer is level at rest (pitch
  within 0.6 deg, height within 5 cm) and bow-up (at least 3.5 deg) and lifted
  on the plane, and that only the racer has a planing trim.
- **Screenshots:** `docs/reference/patch_2_9/cigarette_boat_{before,after}.png`
  (Linux, xvfb, 1600x900, model on a flat sea).

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`
(226 scripts), `check_catalog`, `check_flow`, `check_starter`,
`small_boats_check` (79), `mooring_check`, `hangar_check`, `debug_game_check`,
`water_probe`, `contracts_probe`, `feedback_probe`, `camera_probe`,
`handling_probe`, `collision_probe`: all passed.
Not run: Windows, Mac, an export, a playtest. The rooster tail and the
bow-up ride have not been seen in the live game on screen.

## Patch 2.9 item 6A — natural seeded world land (November 15, 2026)

- **Generator:** `tools/world_layout/natural_land.py` (standard library,
  seed 2906) bends the old Patch 2.5 block layout with a seeded domain warp
  and fractal noise into irregular continents, peninsulas, bays and islands,
  and adds two new seeded isles (Driftwood Isle, Tern Isle) in open sea. It
  bakes `features/world/natural_land.json` (a 25 m grid of metres from the
  coast, plus each coast's outline for the maps; added to both export
  presets) and rewrites `Progression.LAND`/`LANDMASSES` (now 730 blocks: the
  land's 25 m samples merged into rectangles, one landmass's blocks together)
  and the volcano's land index. Same seed, same world on every machine.
- **Kept until 6B:** every port, strait, bridge, biome region and Ember Isle
  stays where it is, so the shapes are bent round them: open water at every
  berth, approach, heavy drop area and every sea route the ports used; land
  behind every quay; each strait its full width with rounded headlands under
  both ends of its bridge; sea round icebergs and Ember Isle; 2 km of sea at
  every world edge. Judgement call: the continents keep their rough places
  (Hearthland west, Ironreach east, Kelp Isle beyond) so nothing breaks
  before 6B moves the ports; their coasts are all new.
- **Solid:** one StaticBody per landmass with a box per block (same 12 m
  boxes as before). Navigation (`clear_line`) tests each block once (its
  nearest wrapped copy) instead of nine times; the lane graph is built at
  load, not on the first minimap course.
- **Toon coast:** `toon_coast.gd` `natural_chunk` contours the grid by
  marching squares into 70 one-kilometre chunks: the old beach and hill
  profile by distance from the coast, flat hill tops merged per row (43k
  triangles in all), biome hill-top colours, steep harbour walls by the
  quays, surf along the waterline. Chunks are culled past 3.6 km and surf
  past 1.5 km. Build time about 0.4 s at load on the Linux runner.
- **Dressing:** desert dunes and mesas, tropical palms and bushes and the city
  skyline are placed on the grid by distance inland (beach palms follow the
  coast 42 m in); lagoons ring each small tropical isle by its real coast.
- **Maps:** the minimap globe draws each coast outline (cut at the horizon so a
  continent stays one fill); the M globe's atlas is painted from the grid
  with an ink coastline; the Port Test minimap draws the outlines.
- **Checks changed:** `world_land_check` (a body per landmass, coast chunks
  culled, shared materials, harbour walls, seed 2906, no straight coast over
  400 m away from the quays, bridge ends land within 35 m of the channel
  because the grid is 25 m), `volcano_check`, `tropical_biome_check`,
  `desert_biome_check`, `rain_biome_check` read the natural land.
- **Screenshots:** `docs/reference/patch_2_9/natural_land_{before,after}*.png`
  (Linux, xvfb, 1600x900: the southern strait and Palm Isles, and the globe
  atlas page).
- **Limits:** the four port quays still have straight harbour walls (6B moves
  the ports). A save made at sea where new land now stands would load inside
  it; 6B moves such ships to a port. The land is the same 25 m grid for
  looks and collision, so the solid edge can sit up to about 18 m off the
  drawn waterline.

Checks (agent's Linux runner, official Godot 4.7.2): import, `check_scripts`
(226 scripts), `traversal_budget.py` (17 routes), `world_land_check` (151),
`volcano_check`, `tropical_biome_check`, `desert_biome_check`,
`rain_biome_check`, `polar_biome_check`, `globe_map_check`,
`debug_game_check`, `check_m1_voyage`, `check_flow`, `check_starter`,
`check_catalog`, `check_controls`, `check_helm_keys`, `check_title`,
`small_boats_check`, `mooring_check`, `hangar_check`, `crane_check`, the
container, bulk and heavy ladder checks, `geography_probe`,
`collision_probe`, `world_size_probe`, `water_probe`, `camera_probe`,
`units_probe`, `handling_probe`, `heavy_lifter_probe`, `fuel_probe`,
`economy_probe`: all passed.
Not run: Windows, Mac, an export, a playtest; frame time on Andy's PC not
measured (load-time build and chunk culling only checked headless).

## Patch 2.9.1 item 1 — pirate galleon (November 15, 2026)

Built in parallel with Patch 2.9 item 6B on Andy's instruction (through Hark).
No port, world generation or port data file is touched.

- **Ship:** new kind `small_galleon` ("Pirate galleon", record
  `pirate_galleon_ship.tres`, save ID `ship_pirate_galleon_01`): 112 x 24 m,
  11 kn, about 40 s to full speed, 2.2 deg/s turns (slower than every cargo
  ship), 200,000 credits, no cargo and no jobs ("Pirate ships take no cargo
  jobs"). It sits in the same `small` family, so saves are unchanged, debug
  mode owns it through `Hangar.ladder()` and it docks, refuels and switches
  like the small boats. `Progression.PIRATE_KINDS` lists the pirate ships.
- **Hangar:** the "Small boats" filter is now **Other boats** (same family
  ID); the galleon is boat 4 of 4.
- **Model** (`features/toon/pirate_galleon.gd`, built in code): stepped hull
  (poop, quarterdeck, waist, forecastle) with sheer, tumblehome, wales and
  colour bands; carved stern with two rows of lit cabin windows, a balustraded
  gallery, taffrail crest, three great lanterns and quarter galleries;
  beakhead, head rails and a gold figurehead; 64 cannons (two gun decks with
  open port lids, deck guns on carriages, two stern chasers); three masts in
  three lengths with tops, a crow's nest on the main, yards, shrouds with
  ratlines, stays, backstays, lifts, braces and sheets; nine set sails
  (square sails, lateen, jib); ship's wheel and binnacle, hatch gratings,
  capstan, barrels, belfry, anchors on catheads, stairs and balustrades at
  every deck break, 12 lanterns; mooring bitts and the four mooring markers.
- **Flags:** a big black Jolly Roger at the main truck, a second on the
  ensign staff and red pennants on the fore and mizzen; they flap in a vertex
  shader (`pirate_flag.gdshader`).
- **Deep roll:** new record field `roll_gain` (1 for every other ship, 1.6
  here): the galleon rolls to about 10 degrees on high water where the Panamax
  reaches 8; level at rest.
- **Frame time:** the ship is 7 meshes and about 23,000 triangles (the merged
  parts carry their own outline push, `toon_outline_custom.gdshader`); built
  once in about 45 ms and shared by the hangar and the sea; the small detail
  stops drawing past 700 m and the rigging past 520 m (never at the chase
  camera's furthest zoom, 480 m).
- **Judgement calls:** the mastheads stop at 55 m, not higher, because
  `world_land_check` requires the 70 m bridges to clear the tallest ship by
  15 m and the bridges are not this item's to change; the rig is broad
  instead. Guns and yardarms overhang the collision box by under 2 m. It
  still burns fuel like every ship (nothing in the plan says otherwise).
- **Left for later items:** the sails are set and still (item 3 furls and
  billows them); the guns do not fire (item 4); no brigantine (item 2).
- `export_presets.cfg` lists the record, the model script and the two new
  shaders in both presets. That edits the same long `export_files` line any
  other PR that adds a file edits, so merging beside 6B may need that one
  line resolved by hand.
- **Screenshots:** `docs/reference/patch_2_9_1/galleon_*.png` (Linux, xvfb,
  1600x900: three-quarter view, stern, deck, sailing in the debug game and
  the hangar card).

Checks (agent's Linux runner, official Godot 4.7.2, checksum verified):
import, `check_scripts` (228 scripts), boot, new `pirate_galleon_check` (84),
`small_boats_check` (79), `hangar_check` (224: buys, selects and docks all 19
ships), `debug_game_check` (84), `mooring_check`, `crane_check`,
`world_land_check` (151), the container, bulk and heavy ladder checks,
`globe_map_check`, `check_m1_voyage`, `check_catalog`, `check_controls`,
`check_flow`, `check_starter`, `check_title`, `check_helm_keys`, every CI
Stage 2 probe (units to economy), `collision_probe`, and
`tools/world_layout` unit tests with `traversal_budget.py` (17 routes): all
passed. `world_land_check` failed once on the first, 66 m rig and passes
with the 55 m rig.
Not run: the other Stage 3 Python service tests (no Python or service file
changed), Windows, Mac, an export, a playtest. Frame time was only compared
on the runner's software renderer (galleon 154 ms a frame, Panamax 144 ms in
the same spot), which says little about Andy's PC. Nobody has sailed it.

## Patch 2.9.1 item 2 — pirate brigantine (November 16, 2026)

Second pirate ship, built from item 1's pieces. Only item 2: no living sails
(item 3), no cannon salute (item 4), no port, world or port-data change.

- **Ship:** new kind `small_brigantine` ("Pirate brigantine", record
  `pirate_brigantine_ship.tres`, save ID `ship_pirate_brigantine_02`): 64 x 14 m,
  15.0 kn, turns twice as fast as the galleon (4.4 deg/s), 60,000 credits, no
  cargo and no jobs. It is boat 4 of 5 in the hangar's Other boats filter (the
  galleon moves to 5 of 5, cheapest first as in every family) and is owned in
  debug mode. Old saves load unchanged.
- **Model** (`features/toon/pirate_brigantine.gd`, built in code): low black
  hull with a red wale, white rail and green bottom; raised quarterdeck with
  stairs, cabin door and lit windows; stern with four lit windows, gold
  mouldings, crested taffrail and three lanterns; 18 deck guns behind the
  bulwarks, 2 stern chasers, 4 swivel guns; skull figurehead, bowsprit and
  jibboom; square-rigged foremast (three yards, fighting top) and gaff-rigged
  mainmast (crow's nest, gaff and boom); shrouds with ratlines, stays,
  backstays, braces, lifts and sheets; eight red sails; ship's wheel and
  binnacle, hatch grating, upturned longboat, capstan, barrels, bell, anchors
  on catheads, 7 lanterns; mooring bitts and the four mooring markers.
- **Own colours and flag:** black, crimson and bone against the galleon's
  wood, ochre and navy; a black flag with a skull over crossed cutlasses at
  the main truck and the gaff peak, and a white pennant on the foremast.
- **Reused from the galleon:** merged batches, the custom outline, the flag
  shader, windows, lanterns, ratlines and sails. `pirate_galleon.gd` changed
  only to share them: sails take an optional cloth colour, and mesh placement
  and materials moved into `place()` and `finish()`. The galleon looks and
  checks the same.
- **Frame time:** 7 meshes, about 12,600 triangles, built once in about 20 ms
  and shared; detail stops drawing past 500 m and rigging past 380 m (the
  chase camera's furthest zoom is 288 m).
- **Judgement calls:** `roll_gain` 1.2 (about 11 degrees on high water; 1.4
  gave 12.7, close to the 14 degree limit). Rig tops out at 41.3 m, under
  the galleon's 55 m. It burns fuel like every ship.
- `export_presets.cfg` lists the record and the model script in both presets
  (the same long line Patch 2.9 item 6B may edit).
- **Screenshots:** `docs/reference/patch_2_9_1/brigantine_*.png` (Linux, xvfb,
  1600x900, a plain test stage, not the game scene: three-quarter view, stern,
  deck).

Checks (agent's Linux runner, official Godot 4.7.2, checksum verified):
import, `check_scripts` (230 scripts), boot, new `pirate_brigantine_check`
(75), `pirate_galleon_check` (84), `small_boats_check` (79), `hangar_check`
(235: buys, selects and docks all 20 ships), `debug_game_check` (87),
`mooring_check`, `crane_check`, `world_land_check`, the container, bulk and
heavy ladder checks, `globe_map_check`, `check_m1_voyage`, `check_catalog`,
`check_controls`, `check_flow`, `check_starter`, `check_title`,
`check_helm_keys` and every CI Stage 2 probe (units to economy): all passed.
Not run: the Stage 3 Python tests (no Python or service file changed), the
biome checks, Windows, Mac, an export, a playtest, any frame-time measurement
in the game scene, and no in-game or hangar-card screenshot. Nobody has
sailed it.

## Patch 2.9 item 6B: seeded port placement — November 16, 2026

Draft PR from `claude/issue-179-20261116-0109` (it replaces draft PR #180, whose
commits it carries). **Done:** `natural_land.py` now draws the four strait ports from the
seed (`PLACE_SEED` 2912) and gives each one a coastal spot. The quay backs onto
land, the berths and drop area are open sea, and every route is within budget.
The North and South Pole ports have not moved. The generator also places the
Palm Isles, Ember Isle (volcano), the four bridge crossings and the desert,
tropical and rain centres, then re-bends the land round them. Port IDs are
unchanged. Each moved port keeps its old spot as `"was"`/`"was_side"` in
`Progression.WORLD`.

**Pay and saves:** `Progression.chart_at()` gives a port's
old spot (`"was"`), and `leg_units` uses it, so container and bulk pay and the
saved offers that `voyage_snapshot.valid()` rebuilds are as before. A saved
heavy drop round the old spot is accepted. On load it moves with the port: the
same distance out and south, on the new open side. `restore()` starts the ship
at its port's spawn when the saved pose is inside land, ice or an iceberg
(`Progression.afloat`). When a docked save is off every berth, it docks again
from that spawn. A floating heavy load moves with its ship.
**Checks fixed:** `crane_check` (bays are now grouped by the stack's
z on the ship; float error far from the origin split container_3's stacks) and
`check_m1_voyage` (it follows the sea lanes to Slatewater's gate, and the
iceberg edge test no longer depends on Brindle's spot).

**Re-bake (November 16):** the first placement that fits every rule is attempt
277. New spots: Brindle Quay (-10, -300), Slatewater Works (1660, 1410), Cinder
Point (-210, 1830), Gannet Light (1810, -1900). Ember Isle is at (4480, -4060).
The four bridges, the Palm Isles and the desert, tropical and rain centres
moved with them. What changed in `natural_land.py` to get there:
- The volcano is drawn from the spots of open sea that meet every fixed rule.
  Only the south-east corner does, so Ember Isle is 60 m from where it was.
- Strait ports are drawn on the inner sea's coasts only (`INNER_SEA_X`). From
  Hearthland's west coast or Kelp Isle's east coast the sea route to an inner
  port is 12 km or more, over the 11 km budget in `world_layout.json`.
- The keep-out rectangle round each strait's bank headlands had its sides
  swapped for north-south straits, so a port's berths could land on a
  headland. Fixed.
- A fine seeded ripple (`RIPPLE_M`) stops a coast following the sample grid
  dead straight (Kelp Isle had 450 m).
- Each baked candidate must pass `traversal_budget.py`'s world rules.

**For Andy to judge:** three of the four ports moved only 300 to 370 m
(Slatewater moved 1.4 km). The 11 km route budget and the fixed sea lanes
leave the inner sea as the only place all four fit. The budget was not
changed. Every hull's time and fuel budget allows 15.5 km or more, so raising
`max_route_m` to about 13 km would let ports reach the outer coasts, at the
cost of longer sails for the same pay.

**Limits:** no real pre-2.9 save file was loaded. `heavy_ladder_check` now
restores a ship 5 save edited to the old layout (ship inside new land, drop off
Brindle's old spot) and it passes. A heavy load still waiting for pickup beside
an old quay moves only when its ship is moved or re-docked.

Checks (agent's Linux runner, official Godot 4.7.2, headless), all passed:
import, `check_scripts`, boot; `world_land_check`, `volcano_check`, the
tropical, desert, rain and polar biome checks, `heavy_ladder_check`,
`globe_map_check`, the bulk and container ladder checks, `crane_check`,
`check_m1_voyage`, `debug_game_check`, `hangar_check`, `mooring_check`,
`small_boats_check`, `pirate_galleon_check`, `check_catalog`, `check_controls`,
`check_flow`, `check_starter`, `check_helm_keys`, `check_title`; the units,
diagnostics, contracts, geography, session, clocks, handling, camera, water,
feedback, world size, heavy lifter, fuel, economy, sailing save, voyage,
collision, composition and ports probes. Python: `traversal_budget.py`
(WORLD_LAYOUT_PASS, 17 routes) and the 10 world-layout unit tests.
Not run: the service and public-handoff Python tests (no file of theirs
changed), the probes that need the HTTP/SQLite service, Windows, Mac, an
export, a playtest, any frame-time measurement.

## Patch 2.9.1 item 3 — living sails, rigging and flags (November 16, 2026)

Both pirate ships. Looks only: no handling, save, port, job or price change.

- **Sails.** Furled on their yards while the ship is stopped. They unfurl one
  after another (about 4 s) when the throttle goes up, fill with speed, flutter
  faster at speed, back when going astern, and furl (about 6 s) once the
  throttle is at zero and the ship is under 10% of her top speed. The hangar
  and title ships keep their sails set, as before.
- **Flags and pennants** hang and wave lazily at rest and stream straight out
  at speed.
- **Rigging.** Sails and ropes of 8 m or longer swing sideways behind the
  hull's roll (a damped spring, at most 1.6 m for cloth and 0.6 m for a rope).
- **Wake.** New record field `wake_full_speed_mps` (0 = the fleet's 12.35 m/s,
  so every other ship is unchanged). Galleon 7.0, brigantine 8.6: at top speed
  the galleon's wake, bow wave and spray are at 81% strength (was 46%) and the
  brigantine's at 90% (was 62%). Trim is untouched: both still float level at
  rest (the existing Patch 2.4 style checks pass).
- **How.** `pirate_cloth.gdshader` (toon shading plus the movement) and
  `pirate_cloth_outline.gdshader` (its ink line) move the vertices on the GPU.
  Each sail vertex carries its furled spot and its belly; the flag shader
  gained `stream` and `flow`. `pirate_rig.gd` is one small node per ship that
  sets four numbers on its own three materials each frame; the meshes are
  still built once and shared. Still seven meshes per ship. Long ropes are cut
  in four pieces so they can bow: galleon rigging 4,080 triangles, brigantine
  2,360.
- **Export:** the two new shaders and `pirate_rig.gd` are in both presets.
- **Screenshots:** `docs/reference/patch_2_9_1/galleon_sails_*.png` and
  `brigantine_sails_*.png` (Linux, xvfb, 1600x900, a scratch script that was
  not committed, model on a flat sea).

Checks (agent's Linux runner, official Godot 4.7.2, headless), all passed:
import, `check_scripts` (232 scripts), boot, new `pirate_rig_check` (69),
`pirate_galleon_check` (84), `pirate_brigantine_check` (75),
`debug_game_check` (91, now also checks the live rig and wake speed in the
real game), `small_boats_check`, `hangar_check`, `mooring_check`,
`check_catalog`, `check_starter`, `check_title`, `check_controls`,
`check_flow`, `check_helm_keys`, the container, bulk and heavy ladder checks,
`check_m1_voyage`, `globe_map_check`, `crane_check`; the water, composition,
handling, feedback, camera, collision, units, diagnostics and sailing save
probes.
Not run: the biome, land and volcano checks, the Python and service tests (no
file of theirs changed), Windows, Mac, an export, a playtest. Frame time was
not measured; the sails were only seen as still xvfb frames, not in motion.

## Patch 2.9.1 item 4 — cannon salute and Other boats (November 16, 2026)

REBUILD_PLAN.md section 13 item 4. Looks and sound only: no damage, no combat,
nothing is launched and nothing is hit.

- **Salute.** G (new action `cannon_salute`, rebindable in Settings and listed
  on the Controls screen) fires the active pirate ship's broadside: the guns go
  off bow to stern over about 1.1 s on both sides, each with a muzzle flash and
  three toon smoke puffs, booms, and a splash 110-190 m abeam about a second
  later. 5 s cooldown. Galleon 62 guns, brigantine 18 (broadside guns only).
  Other ships have no guns and the key does nothing.
- **Nothing hit.** There are no projectiles and no collision bodies. A splash
  is only drawn over open water (15 m or more off the natural land grid), so
  none lands on a shore. Ship, fuel, condition, credits and saves are untouched.
- **Frame time.** `features/toon/pirate_cannons.gd`, one node per pirate ship.
  All flashes, puffs and splash lumps are instances of one MultiMesh (7 per
  gun: 434 galleon, 126 brigantine), built on the first salute and reused;
  five boom players share one generated sound. Nothing is created while
  firing, and the node does not run between salutes.
- **Saved settings.** Settings files from before this patch have no salute
  key. They now load with every chosen key kept and the new action added (G,
  or the first free letter if G is already in use) instead of being rejected.
- **Other boats.** Already in place from items 1 and 2 and re-checked here in
  the real game scene: the hangar filter reads "Other boats" (family ID
  `small` unchanged), both pirate ships are in it, debug mode owns both, and
  neither is offered cargo jobs. No port, port ID or job was changed.
- **Export:** `pirate_cannons.gd` is in both presets.
- **Screenshots:** `docs/reference/patch_2_9_1/cannon_salute_galleon.png` and
  `cannon_salute_brigantine.png` (Linux, xvfb, 1600x900, a scratch script that
  was not committed, model on a flat sea).

Checks (agent's Linux runner, official Godot 4.7.2, headless), all passed:
import, `check_scripts` (234 scripts), boot, new `cannon_salute_check` (60:
gun counts and firing order, reuse of the puffs and players, cooldown, no
splash on land, the G key in the real game in debug mode on both ships with
ship, fuel, credits and fleet unchanged, old settings files, Controls screen),
`pirate_rig_check`, `pirate_galleon_check`, `pirate_brigantine_check`,
`debug_game_check`, `small_boats_check`, `hangar_check`, `mooring_check`,
`check_catalog`, `check_starter`, `check_title`, `check_controls`,
`check_flow`, `check_helm_keys`, the container, bulk and heavy ladder checks,
`check_m1_voyage`, `globe_map_check`, `crane_check`; the feedback, water,
composition, handling, camera, collision, units, diagnostics and sailing save
probes.
Not run: the biome, land and volcano checks, the Python and service tests (no
file of theirs changed), Windows, Mac, an export, a playtest. Frame time was
not measured. The salute was only seen as still xvfb frames with the model on
a flat sea, not in motion in the game, and the boom was not heard (the runner
has no audio device).

## Patch 2.9.1 item 5 — 3D boats on the M map (November 16, 2026)

REBUILD_PLAN.md section 13 item 5. M map only; the corner minimap is unchanged.
No multiplayer or networking work.

- **Boats.** On the M globe the flat yellow arrow is replaced by a small toon
  3D model of the boat's own hull kind, sitting on the globe with its bow along
  the heading: container ship (navy hull, coloured stacks, bridge aft), bulk
  carrier (rust hull, hatches), heavy lifter (orange hull, bridge forward,
  crane), small boats (white hull, cabin), brigantine (black hull, two masts,
  red sails) and galleon (brown hull, three masts, cream sails). Same two-band
  toon light as the globe plus an ink outline. Bigger hulls draw bigger (0.6
  to 2 times the starter's).
- **Ship-entry list.** `globe_map.gd` draws from `ship_entries()`: a list of
  `{kind, position, heading}` (Progression ship kind, world position, radians
  from north). Today it holds the player's boat; `other_ships` is the empty
  list Patch 3.0 fills, and anything in it is drawn the same way. An unknown
  kind draws as a container ship.
- **Frame time.** Models are pooled and rebuilt only when an entry's kind
  changes; 7 to 12 small meshes each, shared materials, one shared outline
  pass; boats round the back of the globe are hidden and not built; at most 64
  drawn. Nothing runs while the map is closed.
- **Files.** All in `features/game/globe_map.gd`; no new runtime file, so
  `export_presets.cfg` is unchanged. No port, port ID, job or save changed.
- **Screenshot:** `docs/reference/patch_2_9_1/m_map_boats.png` (Linux, xvfb,
  1600x900, a scratch script that was not committed: eight kinds placed side
  by side on the globe, closer together than real boats would be).

Checks (agent's Linux runner, official Godot 4.7.2, headless), all passed:
import, `check_scripts` (234 scripts), boot, `globe_map_check` (70, was 48:
the entry list, the model at the ship, bow north and east, each kind its own
look, pool reuse, other ships drawn, hidden round the back, spares kept),
`world_land_check` (149), `debug_game_check`, `hangar_check`,
`small_boats_check`, `cannon_salute_check`, `pirate_galleon_check`,
`pirate_brigantine_check`, `check_m1_voyage`, `check_flow`, `check_controls`.
Not run: the other checks and probes, the Python and service tests (no file of
theirs changed), Windows, Mac, an export, a playtest. Frame time was not
measured. The models were only seen in one still xvfb frame, not in the
running game. An earlier agent run on this item stopped before pushing; this
entry describes the code as rebuilt and checked in this run.

## Patch 2.9.1 item 6 — polar ice cap (November 16, 2026)

REBUILD_PLAN.md section 13 item 6. No port, port ID, job or save changed.

- **Where it is.** The world wraps north-south, so its top and bottom ends are
  one line. The ice cap lies along that line all the way round the world,
  up to about 1.3 km deep on each side, and replaces the four square ice
  shelves. On the M globe it is a white cap on each pole.
- **Ports.** Neither polar port moved. A tongue of the cap runs out to the
  North Pole port and backs its whole quay. The South Pole port keeps an ice
  island behind its quay, where its shelf stood: joining it to the cap would
  have closed the water the pole-to-pole route uses. Berths, approach and
  heavy drop area are open sea at both, checked as for every other port.
- **Leads (a choice to confirm).** A full band of ice would end north-south
  sailing across the edge. Three leads roughly 300 to 400 m wide are cut
  through it:
  two along the routes that already cross the edge (Needle Gut to the southern
  lane, and pole to pole) and one in the east near X 5500. Port-to-port sea
  routes are unchanged (longest still 9,166 m).
- **Look.** Blue ice cliffs 8 to 30 m high straight out of the sea, snow
  rising to a flat plateau, snow peaks inland, calved floes off the coast,
  surf at the cliff foot, a quay-height wall by the two ports. Ice and snow
  share two materials; peaks are MultiMeshes.
- **Solid.** 694 blocks in `Progression.ICE_SHELVES` (same name, so collision,
  sea lanes, `afloat` and the checks keep using it), in 20 chunks. Each chunk
  sits at its copy nearest the ship, as the icebergs do, so the cap is whole
  across both edges of the world.
- **Icebergs.** 14 of the 20 were inside or too near the new ice and moved to
  the nearest open polar water; still 20, still clear of ports and drop areas.
- **Frame time.** Coast in up to 40 bands culled past 4 km, surf past 1.9 km; the
  flat plateau is one quad per run. Under xvfb the polar views draw 190k to
  420k primitives against 530k at the home port. Game load went from about
  1.0 s to 1.2 s headless. Frame time itself was not measured (software GL).
- **Files.** New: `tools/world_layout/polar_ice.py` (the bake, standard
  library only, repeatable), `features/world/polar_ice.json` (added to both
  export presets), `features/toon/polar_ice.gd`. Changed: `progression.gd`
  (blocks, loader, `ice_depth`), `port_test.gd`, `globe_map.gd`,
  `globe_minimap.gd`, and three checks: `world_land_check` and
  `check_m1_voyage` no longer ask for 2 km of sea between ice and the edge,
  and `traversal_budget.py` asks that of land only.
- **Screenshots:** `docs/reference/patch_2_9_1/ice_cap_coast.png`,
  `ice_cap_lead.png`, `ice_cap_north_pole_port.png` (Linux, xvfb, 1600x900,
  ship placed by a scratch script that was not committed).

Checks (agent's Linux runner, official Godot 4.7.2, headless), all passed:
import, and all 27 `tools/*_check.gd` and `tools/check_*.gd` scripts,
including `world_land_check` (166, was 149: the ice chunks, blocks, leads,
both quays, the maps), `check_m1_voyage`, `polar_biome_check`,
`volcano_check`, `globe_map_check`, `debug_game_check`, `hangar_check`,
`small_boats_check` and the pirate checks; `traversal_budget.py` and its 10
unit tests. Not run: the probes, the other Python and service tests (no file
of theirs changed), Windows, Mac, an export, a playtest. The ice was only seen
in still xvfb frames from four spots, not sailed along.

## Patch 2.9.1 item 7 — menu beach ambience (November 16, 2026)

- Title, arrival, menu, Options and Credits share gentle surf and occasional
  synthetic gull calls. Two preloaded 32-second PCM loops, baked overlap seam,
  two reusable players; 1.2 s fades on entry/departure, including debug entry
  and return. No runtime synthesis, player churn or steady-state frame work;
  stopped players sleep during gameplay. Patch 2.7 visuals/navigation unchanged.
- Added saved Music/Ambience volume with live preview, Cancel rollback, Reset
  defaults and old-preferences fallback; Master volume/mute still applies.
  Audio is generated by `tools/audio/generate_menu_beach.py`, credited and
  dedicated to CC0 in `features/audio/CREDITS.md`. Both export presets include it.
- Linux checks use official Godot 4.7.2 (CI checksum verified), isolated XDG data.
  Import, parse, boot, title, controls, flow, debug, new ambience lifecycle/mixer
  check and the other existing `*_check.gd`/`check_*.gd` checks passed. The voyage check timed out at 40 s in the parallel run, then
  passed alone with a 120 s allowance; the standard 30 s budget is not verified. Python audio check passed (reproducible bake, PCM
  bounds and loop joins). Windows and macOS resource-pack exports passed; packed
  audio and credits load successfully. This is not a native executable export.
- Headless runs skip playback unless `--menu-audio-check` is supplied; the audio
  check opts in and allows the mixer to release playback references before exit.
  Initial checks caught disabled looping, cold-boot node attachment and immediate
  headless shutdown references; corrected and relevant checks rerun successfully.
- Not listened to or visually playtested here; Windows/Mac acceptance and real
  hardware frame-time measurement remain pending. No gameplay, port/job IDs,
  on-hold cargo code, engine baseline or workflows changed. Existing UIDs kept;
  new GDScript UIDs generated by Godot. Items 8 and 9 remain untouched.

## Patch 2.9.1 item 8 — in-game ambience (November 16, 2026)

- Sea waves, speed-sensitive hull wash/wind, and port layers selected from
  existing services/biomes: crane motors/horns, tropical surf/gulls, polar
  wind/ice creaks, rainy-city rain/hum, desert wind. Nine preloaded reusable
  players, 5 Hz wrap-aware distance sampling (350–1500 m), smooth fades and
  stopped distant/muted layers; follows ship swaps and debug travel. Existing
  Music/Ambience preview/Save/Cancel and Master apply; Main Menu fades out
  with the existing screen transition. No world pause or gameplay changes.
- Six reproducible in-repo CC0 PCM loops plus reused item 7 surf/gulls;
  source/license in `features/audio/CREDITS.md`. Both export presets extended;
  existing UIDs preserved, new script UIDs generated by Godot. Workflows,
  port/job/save data, visual/physics code and on-hold cargo code untouched.
- Checks: checksum-verified official Godot 4.7.2 on Linux with isolated XDG
  data/config/cache. Import/boot and all 29 `*_check.gd` / `check_*.gd` checks
  passed (239 scripts parsed), including both audio mixer checks and earlier
  fleet, hangar, debug, world/biome, map, crane, mooring and pirate checks.
  Voyage passed in 110 s with a 120 s allowance; 30 s budget remains unverified.
  The new check covers all six ports, service selection, approach attenuation,
  both wrap axes, speed/astern, culling, pool reuse, volume rollback, ship swap
  and exit. Python PCM/reproducible-bake/seam test and py_compile passed.
- Windows/macOS resource-pack exports and packed audio/credits loading passed.
  Opening those packs on Linux reports missing platform-specific SQLite
  libraries; this does not validate native executables. Initial import hit
  unwritable default editor config/cache paths (rerun clean with isolated XDG);
  initial audio check hit float32 tolerance at 0.8 (assertion corrected, passed).
- Not run: native Windows/Mac builds or playtests, listening, real-hardware
  frame-time measurements, remaining scene probes and service/Python suites
  outside audio. Item 9 remains untouched; acceptance stays pending.

## Patch 2.9.1 item 9 — sprite-sheet lettering (November 16, 2026)

Andy’s sheets now supply shared bitmap display fonts: white/navy titles, menus,
headings, knots and map labels; gold money, prices, rewards and pirate names;
red warnings and a two-second cosmetic cannon flourish. Body copy stays in its
original font. Offline bake splits red G/H, tints missing glyphs from white/navy,
adds licensed serif punctuation, aliases coloured lowercase to caps and retains
Unicode fallback. Three atlases, per-glyph advances, nearest filtering; no runtime
slicing/uploads. Both export presets include font images. Rebased over items 7/8;
no workflow, port ID, job, save, physics or on-hold cargo code changed.

Passed on Linux, official Godot 4.7.2: import, scripts (241), title, controls,
flow, M1 voyage, hangar (235), globe map (70), cannon salute, both pirate ships,
rigging, world land, menu ambience and game ambience. New lettering check: 518
assertions (ASCII coverage, 1x/2x metrics, all 20 hangar cards and screen bounds at
1440x900 and 2560x1080, warning/body transitions). Software-GL visual run: 325
checks; six screenshots in `docs/reference/patch_2_9_1/lettering_*.png`. Repeat
font bake is byte-identical. Windows preset PCK export passed with font resources;
no build/cache committed. `git diff --check` passed.

Initial 4.6.3 import failed the SQLite version gate; downloaded 4.7.2 without
changing the baseline. Initial title check exposed a Label minimum-size issue,
fixed with bounded logo drawing; rerun passed. Existing ObjectDB exit warnings
remain in some game checks; software GL lacks VSync/audio hardware. Not run:
Windows/Mac clients, native executable exports, remaining probes/Python/service
suites, listening or hardware frame-time playtests. PR stays draft for acceptance.

## Patch 3.0 item A — cranes supported by the quay (November 17, 2026)

- Based on main `36716ef`. The first berth's cranes parked behind local Z=0,
  beyond the pier. Extended the existing solid quay and edge behind that berth
  using the same 140 m allowance as the far end; no new nodes or per-frame work.
  Screenshot `docs_refs/floating_crane_ports_nov16.jpeg` was absent; inspected
  placement code and checked full bogie corners against actual quay colliders.
- Linux, SHA512-verified official Godot 4.7.2: import, 241-script parse, boot,
  section 3 smoke set, ports (489), cranes (267), mooring (422), world-land and
  controls/flow passed. Crane coverage includes all 108 parked cranes across six
  ports and continuous support while tiers 1/3/5 load and unload. Voyage passed
  with a 120 s allowance (not the required 30 s budget), with the existing
  ObjectDB exit warning. Python compile, 76 service tests, 48 public-handoff
  tests, 10 world-layout tests and traversal budget (17 routes) passed.
- Initial regression-check indentation error corrected; parse/crane checks
  rerun clean. Public-handoff initially lacked psycopg; installed the pinned
  dependency outside the repo and reran successfully. `git diff --check` passed.
  Existing UIDs, crane behavior, port/job/save data, on-hold code, workflows,
  engine baseline and toon materials unchanged; no generated artifacts committed.
  Native Windows/Mac playtests, rendered inspection, exports and hardware frame
  time remain unverified; draft PR only. No other Patch 3.0 item implemented.

### PR #201 import follow-up (November 17, 2026)

- CI run 44041128402 failed only import: dummy renderer
  `texture_2d_initialize` reported a null texture RID while importing the
  unchanged heavy-lifter GLB (which has no textures), after bitmap fonts.
  The crane scripts are not editor tools, and the patch added no resources.
  Four clean imports each of main 36716ef and head f37f17a passed locally;
  the exact intermittent trigger is not reproduced or proven patch-specific.
- Mitigation: `editor/import/use_multiple_threads=false` in project.godot
  keeps resource import on the main thread, avoiding worker-queued texture
  initialization in Godot 4.7.2's dummy renderer. Import can take longer;
  runtime rendering, crane code/assets, engine version and workflows unchanged.
- Fresh-cache official 4.7.2 import passed with no ERROR/SCRIPT ERROR lines,
  followed by parse (241), boot, cranes (267), mooring (422), ports (489) and
  bitmap-font checks (518), all within 30 s. Isolated font-only imports also
  passed 10 times each with threaded and serial import. `git diff --check`
  passed; remote CI must confirm the mitigation. No caches or UIDs changed.

## Patch 3.0 item B — map remix (November 17, 2026)

- Seed 3002, placement 3: 27 landmasses, nine seeded islands, three separate
  Palm Isles and two winding western passages. Reused every port/asset; pole
  ports, ice, four bridge straits, job IDs/quotes and save recovery stay intact.
  All routes are 3.99–9.81 km (starter 7.9–15.7 min), inside the unchanged
  11 km, fuel-reserve and time budgets. Outer coast wrap clearance is 1.7 km.
- Port scenery, ink and city lights fade at 1.6–2.2 km from the captain, so
  camera zoom cannot reveal another harbour. Cached materials, one shader
  uniform per frame, existing meshes/collision/culling; no pause or networking.
  Both export presets include the new shaders; Godot generated their/test UIDs.
- Passed: SHA512-verified Godot 4.7.2 import, 242-script parse and all 31 headless
  script checks; software-GL map isolation (1,276 assertions, nearest foreign
  scenery 2,268 m) and globe map (70); 11 Python world tests, traversal budget,
  Python compile, byte-identical rebake of all five outputs; Windows/macOS PCK
  exports and packed-resource checks; git diff check. Voyage took 110 s with
  a 180 s allowance: the required 30 s budget remains unverified.
- Initial checks caught merged/erased Palm Isles, a palm too near the coast and
  disconnected rain window paints; corrected. Updated old test assumptions for
  lagoon approach, mirrored fairleads, offshore audio and wrap margin; reruns
  passed. Existing ObjectDB exit warnings and software-GL VSync warning remain.
  No native Windows/Mac playtest/export, listening, hardware frame-time or full
  service/remaining scene-probe suites ran. Draft only; acceptance pending.
  Existing UIDs, on-hold cargo code, workflows and engine baseline preserved.


## Patch 3.0 item 1 — headless authoritative split (November 17, 2026)

- Based on main 032aae8, including 3.0-A/B. Boot routes `--server` (or the
  dedicated export feature) before menus/save readers; `--connect` renders the
  same game and sends helm only. Default UDP 24565/loopback; `--port`, `--host`
  and server `--bind` are explicit overrides. Ordinary Play/debug are unchanged.
- One shared world/berth registry; per-peer simulation uses existing handling,
  fuel, condition, jobs, wallet and fleet code. Server-only physics; bounded
  20 Hz input/snapshots, existing ShipActions validation, 500 ms stale-input
  neutral, 150 ms wrap-aware interpolation and pooled edge collision copies.
  Disconnect releases hulls/claims/input state. No player DBs or live services.
- Linux, SHA512-verified Godot 4.7.2: import, 246-script parse, boot, smoke and
  earlier patch checks passed after reruns; new three-process loopback passed
  54 assertions (ownership/invalid input, movement, timeout, tamper correction,
  shared ports/berths, bounded buffers, Esc, cleanup and no databases).
  Python compile, 76 service tests, 48 handoff tests, 11 world tests and 17-route
  budget passed. Voyage passed in 152 s with a 180 s allowance after a
  120 s timeout; the required 30 s budget remains unverified.
- Windows client, macOS client and dedicated Windows server PCK exports passed.
  Server pack feature-boot passed with the Linux SQLite library supplied beside
  it; without that library the Windows pack reports missing SQLite on Linux.
  This does not validate native executables. Existing UIDs preserved; new UIDs
  generated by Godot. No workflow, world/job data or on-hold cargo code edits.
- Initial snapshot field-count mistake fixed; loopback rerun passed. Flow and
  cannon checks initially failed under concurrent checks, passed isolated;
  hangar exceeded 30 s, passed with 120 s. Handoff initially lacked psycopg;
  platform-specific binary hash rejected, verified pinned pure wheel + system
  libpq passed. A helper accidentally invoked as a test was not a SceneTree.
- Not run: native Windows/Mac exports/playtests, rendered/listening checks,
  hardware frame-time measurements, remaining service/scene probes or internet
  deployment. Item 2 gameplay/action replication and items 3–6 remain deferred;
  this explicit connection path is an ephemeral helm preview. Draft only.

## Patch 3.0 item 2 - replication (November 18, 2026)

- Extended PR #203's dedicated runtime: all connected hulls, captain labels,
  corner minimap and pooled 3D M-map entries; shared authoritative berths/cranes,
  container slots, container/bulk/heavy jobs, deck/payload, fleets, services and
  payouts. Reused existing game authorities and ShipActions replay/ownership
  rules; one UDP ENet port, no client simulation or player transfers/combat.
- 20 Hz wrap-aware interpolation (150 ms), compressed sub-MTU chunks, bounded
  reassembly/history and changed owner projections with a canonical heartbeat.
  Local/debug paths retained; corrected peer-1 HUD assumptions and render-only
  helm notices. No new runtime resource paths, workflow or on-hold cargo edits.
- Windows recorded Godot 4.7.2: container server + two-client loopback passed
  45 assertions; bulk/heavy variant 14; split/helm/timeout/remote motion 56;
  legacy two-process ActionCheck 49. Both new loops verify real RPC actions,
  presentation/maps and payouts; container covers forgery, replay/conflict and
  wallet correction. Server-only probes stage approaches/travel, not real sailing.
- Passed full 247-script parse, starter, controls, flow, helm keys, globe map
  (70), cranes (267), mooring (422), debug game (91), container ladder (493),
  bulk ladder (512), heavy ladder (711) and cannon salute (60); diff whitespace
  check. PowerShell runner isolates APPDATA and cleans up only its own children;
  Python launcher extended but not executed (Python unavailable on PATH).
- Initial checks exposed duplicate declarations/indentation, unsupported dynamic
  FastLZ decoding, client berth teardown and test staging/early-departure errors;
  corrected and rerun. Windows sandbox reports an unreadable OS certificate
  store: logs retain it, runner exempts only that diagnostic (UDP has no TLS),
  and every other engine/script error fails. Initial editor import also could
  not save Steam's editor settings; runtime imports/parse subsequently worked.
- Not verified: native executable exports, Mac, visual/audio playtests, hardware
  frame time, impaired/internet/tunnel deployment, full service suite or M1's
  30-second voyage budget. Item 2 awaits Andy's review/playtest; items 3-6 still
  own Play/identity, durable migrating saves, server launcher and release setup.
- Restricted-host diagnostics: Windows CA-store access is denied; the UDP runner
  prints that message and excludes only it from error matching. Initial editor
  import also could not save settings beside the Steam executable. Runtime
  checks pass; no TLS/internet validation is claimed. Early parse/fixture,
  compression and teardown failures were corrected before the passing reruns.

## Patch 3.0 item 3 — direct Play connection (November 18, 2026)

- Main now routes Play (keeping the title dive) through a fresh public Releases
  `server.json` lookup, threaded HTTP and queued DNS, then the existing ENet
  runtime. Bounded lookup/join/stale-state timeouts; themed offline/updating/
  mismatch cards with Retry and Back. Feed accepts host/port, optional version
  and status; `--updating` rejects new joins. Release 3.0.0 is checked before
  admission. Retry never reuses an address; no address is stored on disk.
- Debug is labelled Single-player Test Mode: existing unlocked, disposable
  offline world, no persistence. Local Restart Progress is developer-only;
  old saves stay intact. All export presets include the new runtime resources;
  existing UIDs, Wind Waker assets, on-hold cargo code and workflows unchanged.
- Passed on checksum-verified Godot 4.7.2 Linux: import, 249-script parse,
  HTTP/DNS/UDP loopback (135 assertions, eight cases, no databases), existing
  server/two-client split (56) and container replication (45), debug/save
  isolation (91), flow, title and voyage/save/fleet regression (180 s allowance;
  30 s budget unverified). Windows/macOS PCK exports include the new resources;
  Python compile and git diff checks passed. Voyage now opens the local scene
  directly because Play is online; its save and sailing assertions remain.
- Initial HTTP fixture lacked Content-Length; corrected. Tests caught a later
  disconnect overwriting the mismatch card; fixed, reruns passed. Existing
  voyage ObjectDB exit warning remains. Not run: native Windows/Mac builds or
  playtests, visual/hardware frame-time checks, full service/biome suites or
  live feed/server deployment. No live server or player saves touched. Identity,
  persistent/migrating saves and updater are outside this item; acceptance pending.

## Patch 3.0 item 4 — persistent saves (November 18, 2026)

- Dedicated versioned JSON store (D147): ordered migrations, byte-exact backups
  before migration/checkpoints (last five), validated temporary-file commits,
  one IO worker, minute/disconnect/shutdown saves. Corrupt/future/locked saves
  and failed writes stop safely without resetting. Random local install key
  resumes the same server record; protocol 30003. Capture precedes loading/
  docking teardown; restore uses the real owner ID. Debug/test saves stay local.
- SHA512-verified Godot 4.7.2 Linux: import and 252-script parse; frozen synthetic
  pre-3.0/3.0 loaded-cargo/paid-receipt fixtures and 47 migration/backup/lock/
  corruption/write-failure checks; four UDP reconnect/shutdown rounds, including
  an unsaved payout and unfinished loading. Container replication (45), bulk/
  heavy replication (14), Play cards/lookup (135), starter/controls/flow,
  sailing/save (330 checkpoints), local persistence init/UI and migration
  init/verify/compatibility passed. All three PCK exports include the new store.
  Python compile, 76 service tests and diff whitespace check passed.
- Initial host 4.6.3 import/parse failed (SQLite requires 4.7); replaced the test
  binary with pinned 4.7.2. Initial fixture StringName/tolerance issues, hidden
  backup-marker pruning and shutdown teardown order were fixed; reruns passed.
  Local phase probes first exited without required arguments; correct isolated
  phases passed. Play runner first hit its killed server's lock; it now supplies
  separate temporary save paths. These were isolated test folders only.
- Not run: native Windows/Mac executables/playtests, hardware frame-time/power-
  loss testing, full crash-injection/local/service/biome suites or live server.
  Forced termination retains the writer guard for operator inspection; graceful
  shutdown is required for a final checkpoint. No live/player data, on-hold
  cargo code, existing UIDs, engine baseline or workflows changed. Draft only.

## Patch 3.0 item 5 — server package and launcher (November 18, 2026)

- Windows PowerShell/WPF launcher: Start, graceful Stop, listening/player/version
  status, Open saves folder, public address/config and playit process warning.
  Navy/gold style; closing leaves the server running, reopening adopts only its
  verified executable/PID/start time. Package needs no Python on the server PC.
- Token-free `Shipping-Lanes-Server-Releases` latest-release check; exact Windows
  asset, stable newer tag, GitHub SHA256 digest, bounded safe ZIP extraction and
  per-file manifest verification. Download/backup/hash work uses background jobs.
  Stop must confirm a successful checkpoint; then verify a full saves backup
  (last five), switch the version pointer, reload the launcher and start again.
  Failed updates preserve saves/config/old packages; never kill or auto-rollback.
- Build: `python tools/server_package/build.py --godot <4.7.2> --output <outside-source ZIP>`;
  unzip and open `LaunchServer.cmd`. Edit the generated `server-config.json` for
  port/bind/public address. Saves/config/backups stay outside version folders.
- Passed: 34 synthetic PowerShell core assertions (PowerShell 7 on Linux), two
  Python package tests, Python compile, Godot 4.7.2 import/253-script parse,
  real heartbeat/player count/two graceful stops/save restart, existing split
  and container replication loopbacks, persistent-save fixtures/47 assertions
  and four reconnect/shutdown rounds, starter/controls/flow/debug (91), dedicated
  Windows PCK export and whitespace check. New control UID generated by Godot;
  all presets include the resource. Existing UIDs and on-hold code unchanged.
- Initial PowerShell cache permissions/null-string atomic replacement and editor
  settings writes failed; isolated XDG paths and a named atomic backup fixed
  them, reruns passed. Full Windows ZIP build failed: 4.7.2 Windows templates
  absent. Native Windows PowerShell 5.1/WPF/process adoption/update/relaunch,
  native Mac/client builds, visual playtests, hardware frame time, power loss,
  public feed/tunnel deployment and full service/biome suites remain unverified.
  No live server/player data, addresses, exports or workflows changed/committed.

## Patch 3.0 item 6 — server release pipeline (November 19, 2026)

- Andy-approved separate release workflow: published full releases only, matching
  game/server tag, SHA512-pinned Godot 4.7.2 and Windows templates, item 5 builder,
  exact server ZIP and SERVER.md notes to the public server releases repo via
  RELEASES_TOKEN. New releases stay draft until the uploaded SHA256 matches.
  Token needs Contents read/write on that repo; no source/private assets mirrored.
- SERVER.md: Windows install, UDP firewall/playit setup by Hark/Andy, launcher
  updates, saves, both five-backup locations and graceful shutdown. Windows/Mac
  two-client/no-jank checklist in PR; patch status updated.
- Passed: actionlint, shell syntax/release gates, six tag cases, mocked new/existing
  publication, missing token/bad digest and import/export failures; two package
  tests, Python compile, 76 service tests; verified 4.7.2 import/253-script parse/
  boot and full Windows server ZIP export on Linux. ZIP/manifest hashes and blank
  operator config checked; whitespace check passed. Exports remain outside source.
- Not run: native Windows launcher/Mac clients, real publication/token access,
  tunnel/internet play or hardware frame time. Public repo/main exists. Draft
  pending acceptance; no real addresses, secrets, saves or exports committed.
  claude.yml/checks.yml, gameplay and on-hold cargo code unchanged.

## Patch 3.0.1 — captain name, smoother online play, optimization (November 19, 2026)

- Captain name: first Play shows a small modal (LineEdit, Set sail, Enter submits;
  3-16 letters/digits/space/_/-, trimmed) saved to `user://captain_name.txt` beside
  the install key and sent in `hello`; `--captain=` still overrides for tests.
  Pause menu CAPTAIN NAME renames live (rate-limited). The server re-cleans every
  name (`features/network/captain_name.gd`) instead of disconnecting on it.
- Own hull: a bare, shapeless HandlingShip runs the same `advance_motion` from local
  helm every physics tick; snapshots carry the last applied helm sequence, the
  client resets to the server hull, replays unacknowledged input and fades the
  difference over 0.15 s (snap past 20 m / 0.6 rad). Berthing, docked and paused
  hulls still follow the server. Other hulls: per-ship tracks, buffer
  2 × measured interval + jitter clamped 80-250 ms, up to 0.25 s extrapolation.
  Unreliable 1 s ping; `NN ms` in the HUD's top-right corner.
- Wire: binary quantized motion frames (`public_snapshot_codec.gd`, 1/256 m, u16
  yaw, half rates; f64 heavy deck height because RAISED/LOWERED are compared
  exactly) with an 8-hex epoch tag instead of the 32-char epoch; ship status
  reliable and only on change at 10 Hz; gameplay state only on change or after an
  action (no forced 1 Hz resend); cranes only near the recipient; ships outside
  `ship_relevance` range at 5 Hz (seam-aware). Fewer per-frame allocations in the
  client present path and server physics loop. Protocol 30003 → 30101, VERSION
  3.0.1 (`play_connection.gd`, server package runtime check). Saves unchanged.
- Measured (Linux loopback, Godot 4.7.2): ~867 B/ship/s server motion with two
  captains (3.0.0-format equivalent ~2715); budget tool 985 close / 516 spread
  B/ship/s for 8 captains (budget 1024 incl. 64 B/packet overhead); server send
  path ~0.1 ms/tick; client snapshot decode ~66 µs; prediction max gap 0.51 m,
  max frame step 0.11 m, 0 snaps. Server prints `DEDICATED_TICK` once a minute.
- Passed: import + 254-script parse, new `tools/check_snapshot_budget.gd` (26),
  `check_dedicated_split.py` split, `--replication`, `--families` and new
  `--prediction` (server + 2 clients, physics on, held keys, live rename, ping),
  `check_play_connection.py`, `check_server_saves.py` (frozen 3.x fixtures).
  The families probe first failed on half-float deck height; fixed and rerun.
- Not verified: Windows/Mac play, the playit.gg relay or real latency/loss, feel
  of the correction tuning, the modal's look. Gas/oil/refinery/cargo-fuel code
  and workflows unchanged.

## Patch 3.1 — day/night cycle, sunset, songs (November 20, 2026)

Issue #214; REBUILD_PLAN.md section 16. Status: implemented for draft review.
- `features/sky/day_night.gd`: 40-minute cycle (day, sunset, night, dawn) painted
  last over the biome chain at 10 Hz: sun arc (noon = the old fixed sun), moon on
  the same light at night, ambient, fog, sky colours, ocean tint. `toon_sky.gdshader`
  gains a banded sunset glow and stars (both default 0, so the day sky is unchanged).
  Headless runs see a fixed noon so older look checks stay exact.
- Time of day: server Unix time sent in `welcome` and every `pong` (half-RTT
  corrected, sub-second jitter ignored); offline uses the local clock. Protocol
  30101 → 31000, VERSION 3.1.0. Saves unchanged.
- `features/audio/game_music.gd`: Andy Viera's three songs (credit in
  `features/audio/CREDITS.md`), 15 s sailing gate, 10 s fade-in to 0.32 × the
  Music/Ambience slider, loop, 8 s fade-out on a full stop, 5 s fade-out + 3 s
  silence on a phase change. mp3s imported with loop on, added to all export presets.
- Debug mode: NEXT TIME OF DAY button.
- Passed (Linux, Godot 4.7.2 headless): import, 259-script parse, boot, new
  `tools/day_night_check.gd` (27), polar/desert/tropical/rain biome checks,
  volcano, game ambience, play connection, `check_dedicated_split.py --prediction`.
- Not verified: the look and sound on screen, Windows/Mac frame time.

## Patch 3.1.1 — shorter day/night, docked port menu online (November 20, 2026)

Issue #216. Status: implemented for draft review.
- `features/sky/day_night.gd`: 18-minute cycle (day 5 min, sunset 5, night 5,
  dawn 3). Songs change at the new phase starts; the server clock is unchanged
  (same Unix time, same protocol 31000). The sun keeps its 3.1.0 height at each
  phase boundary (piecewise arc), noon moved to `NOON` (headless fixed time).
- Bug: docked online, the port card showed with nothing in it. The client view
  runs with physics off (`dedicated_runtime.gd`), and `port_test.gd` only showed
  the services row (CARGO/REFUEL/REPAIR/SHIPS, job cards) in `_physics_process`.
  Now `show_services()` also runs from `_process` on a client. Not day/night.
- New `tools/port_menu_check.gd`: real game scene built as an online client view,
  docked by a snapshot-style member, checks the port card, services, job panel,
  REFUEL/REPAIR/SHIPS on screen, a real mouse click reaching REFUEL, and the menu
  hiding on undock. Without the fix 6 of 9 fail; with it 9/9 pass.
- VERSION 3.1.0 → 3.1.1 (`play_connection.gd`, `server_package/check_runtime.py`).
- Passed (Linux, Godot 4.7.2 headless): import, check_scripts, boot, every Stage 2
  Checks command, `day_night_check.gd` (29), `port_menu_check.gd` (9),
  `check_m1_voyage.gd`, `check_play_connection.py`.
- Not done: adding `port_menu_check` to `.github/workflows/checks.yml`; workflow
  edits are off-limits for this patch. Not verified: Windows play, a real online dock.

### Patch 3.1.1 additions — berths, admin debug name, Single Player label

Andy's PR #217 comment. VERSION stays 3.1.1; no workflow edits; gas/oil untouched.
- Berths: every berth box is 64 × 290 m and already holds the largest hull
  (38 × 276 m) plus margin. The fault was distance: the port pick (250 m),
  "approaching" (150 m) and the Dock button measured to **berth 1 only**, and
  berths 2 and 3 sit 285 m and 570 m along the quay. `test_port.gd` gains
  `nearest_berth()` / `berth_distance()`; `docking_authority.gd` (new
  `APPROACH_M`) and `port_test.gd` use them. `ports_probe` gains
  `check_berth_detection()`: all 6 ports × 3 berths × every catalog hull — the
  footprint fits the box, moored and arriving ships are detected at that berth,
  and the authority reads "approaching", picks, docks and holds that berth.
  The frozen online `public_physics_world.gd` was not changed.
- Debug captain name (server-authoritative, `dedicated_runtime.gd`): an admin
  renamed "debug" (any case) gets infinite money and every ship until renamed.
  Admins are player keys (sha256 of the install key — the keys under `players`
  in `saves/world.json`) listed in an `admin_keys` array in `server-config.json`
  beside the saves folder (or `--server-config=`); that file is not in the repo.
  The real money, fleet and voyage are kept aside and are all a checkpoint ever
  writes; renaming restores them and, if a debug-only ship is being sailed,
  swaps back to the captain's own ship once no job is under way. The nameplate
  still reads "debug". Others named debug only get the label.
  New `tools/debug_captain_check.gd` (21 checks).
- Main menu > Options: "Single-player Test Mode" → "Single Player" (id `debug`).
  Cause of the jank: the font baker put every glyph's bottom on the baseline,
  so "-" drew like "_" and quotes sat low. The three `.fnt` files re-seat
  - = + ~ < > ( ) [ ] { } | " ' ` ^ * _ , ; and `tools/bake_display_fonts.py`
  does the same on a re-bake. New `tools/menu_glyph_check.gd` (57 checks): every
  swirl label's glyphs exist in its sprite font, plus punctuation placement
  (15 fail on the old fonts).
- Passed (Linux, Godot 4.7.2 headless): import, check_scripts, boot, all Stage 2
  commands, Stage 3 Python, Stage 4 report probes (`ports_probe` 598 checks),
  `debug_captain_check`, `menu_glyph_check`, `port_menu_check`,
  `day_night_check`, `display_fonts_check`, `check_m1_voyage`, `mooring_check`,
  `debug_game_check`, `hangar_check`, `crane_check`, `check_snapshot_budget`,
  `check_dedicated_split.py` (plain, `--prediction`, `--replication`).
- Not verified: Windows play, a real online session with an admin key, the
  re-seated punctuation on screen. The new checks are not in the Checks workflow.

## Patch 3.2 — one typography system, Debug Menu, polar ice redesign (November 20, 2026)

Issue #218. Status: implemented for draft review. VERSION 3.1.1 → 3.2.0
(`play_connection.gd`, `server_package/check_runtime.py`). Gas/oil code untouched;
no port moved; no workflow edits.
- Typography (`display_fonts.gd` `plain_font()` / `style_button()` / `plain()` /
  `fit()`): sprite lettering only on the port name heading (shrinks to fit its
  card), the money figure, the objective card title and the hangar headings.
  Every game button (port card, helm Dock, job Accept, hangar, debug) uses one
  plain bold face at `BUTTON_SIZE` 18, in Title Case; Refuel/Repair show their
  price as "Refuel  4.10". Job amounts, knots, the salute, warnings and toasts
  are plain bold in colour. The debug DEBUG tag is now a small corner badge.
- Debug Menu: debug mode's panel is collapsed into a "Debug Menu" button at the
  bottom left (clear of the throttle bar and minimap); the button toggles it,
  Esc closes it (`debug_game_check` covers both).
- New `tools/ui_text_check.gd` (627 checks at 1280×720, 1440×900, 2560×1080,
  under way, docked, debug open, map and hangar): every visible Button uses the
  shared font and size, sprite fonts only where allowed, no Label/Button text
  wider or taller than its rect or off screen, the badge and Debug Menu overlap
  no heading, throttle bar or minimap.
- North Pole (`tools/world_layout/polar_ice.py`, re-baked): an ice field from
  the cap down to Ironreach; the port sits in a bay reached only by three
  winding straits (west past the Ironreach headland, south to Kelp Strait,
  east to the open sea), each also a run of new SEA_LANES points. The straight
  eastern lead (a streak from the pole) is gone. The globe samples mipmaps
  (seam-free gradients) so the pole reads as a cap, not a fan. Grid now 185 rows
  per side. Polar look reaches 3.7 km from the edge.
- South Pole: 17 seeded glaciers of varied size and shape and 25 more icebergs
  (45 in all), clear of every port-to-port sea route, the ports and the land. A
  natural glacier off Hearthland backs the quay instead of the rectangular patch.
  Two-stage bake; a second run is byte-identical. All ice is baked data
  (`polar_ice.json`, `ICE_SHELVES`, `ICEBERGS`), so client and server match.
  Glaciers and the new icebergs keep open sea round Ember Isle's volcano.
- Passed (Linux, Godot 4.7.2 headless): import, check_scripts, boot, every
  Stage 2 command, Stage 4 report probes (`ports_probe` 598), `ui_text_check`,
  `debug_game_check`, `world_land_check`, `polar_biome_check`, `volcano_check`,
  `port_menu_check`, `hangar_check`, `display_fonts_check` (warnings now plain
  red), `check_m1_voyage`, `day_night_check`, `menu_glyph_check`,
  `debug_captain_check`, `mooring_check`, `crane_check`, `cannon_salute_check`,
  pirate ship checks, `check_snapshot_budget`, `check_dedicated_split.py`
  (plain, `--prediction`, `--replication`), `check_play_connection.py`.
  Python: Stage 3 in full (`traversal_budget.py` PASS; North Pole routes now
  5–8 turns), and a second `polar_ice.py` bake is byte-identical.
- Same on `main` (not this patch): `dedicated_split_check.gd` alone times out
  (it needs its Python runner), `play_connection_check.gd` prints one
  "Error parsing URL" line but passes.
- Not done: adding `ui_text_check` to `.github/workflows/checks.yml` (workflow
  edits are Andy's/Hark's call).
- Not verified: Windows play, the globe's look on screen (headless has no
  renderer), sailing the straits by hand with the biggest hulls.

## Patch 4.0 — planes, levels, boat lineup, globe relief (November 20, 2026)

Issue #220, draft PR #221. VERSION 3.2.0 → 4.0.0. No workflow edits. The gas,
oil, refinery and cargo-fuel code is untouched.
- A: the fishing boat can no longer be bought. A save that owns one gets the full
  price back and the boat leaves the fleet (voyage `retire_ships`, server save
  schema 1→2). If it was the active ship, the captain moves to another owned ship
  or the starter. Speedboat 2,500, offshore racer 12,000 (calmer on the chop).
  New Jetty: 30,000, five times the racer's top speed, no cargo jobs, toon jet
  flame that grows with throttle.
- B: XP for each delivery, scaled by its pay, awarded by the server or local
  authority only (`levels.gd`, with a quest hook). Level 10 takes a few hours.
  Everyone starts at level 1. "Lv N" and an XP bar sit under the credits; the hint
  text is gone and the ping label no longer overlaps the panel.
- C: one seeded coastal airport per port (the same on client and server). Each
  has a card with Refuel, Repair, Planes, Switch to Boat and the plane jobs
  (Passengers and Packages). Three planes from level 10. Flight model with lift,
  drag, stall, the poles and runways. The low-altitude warning is followed by a
  fine. A crash means an explosion, lost cargo, a repair bill and a respawn at the
  nearest airport. The port card has Switch to Plane, disabled while a load is
  aboard.
- Arcade controls (Andy's addenda): the plane steers towards the mouse cursor.
  The cursor's offset is turned into the plane's frame, so the plane banks
  towards the cursor and pulls. W/S move the throttle, which holds where it is
  left. A/D roll and Q/E yaw are optional. The gear is automatic: down near an
  airport below 60 m when slow, up after take-off. There is no auto-level or
  auto-trim; with the cursor centred the plane keeps its attitude. The assists
  are a coordinated turn, sideslip cancelling, a stall-recovery assist and a
  runway-alignment yaw on final. The HUD shows an aim reticle and a
  flight-direction marker. The arrow-key nose bindings are removed.
- D: the M globe has a land relief shell, built once from the baked land grid
  plus seeded ridge noise: hills, mountains, snowy peaks and the volcano cone.
  Port markers sit above it. The globe and the minimap mark every airport.
- E: snapshots carry an air block (altitude, attitude, climb rate). The own plane
  is predicted with the server's physics and replayed; leftover error is smoothed,
  not snapped.
- Checks: new `tools/patch_4_0_check.gd` (183 checks, about 5 s), and its
  scene-free part (`tools/patch_4_0_logic.gd`) also runs inside `check_catalog.gd`
  in the Checks job. It covers: the fishing boat gone and refunded, the prices,
  the Jetty at 5× the racer with no cargo, XP only from the authority, the
  level-10 gate, airports deterministic and one per port, lift and stall, a
  held bank with no auto-level, the gear, a scripted take-off → landing for
  every plane, a crash (respawn at the nearest airport, cargo lost, repair
  billed), Switch to Plane refused with a load, the low-altitude fine, and the
  3.2 fishing save loading.
  `globe_map_check.gd` adds relief and airport-marker checks.
- Passed (Linux, Godot 4.7.2 headless): import, check_scripts, boot, every
  Stage 2 command, Stage 4 probes, `patch_4_0_check`, `small_boats_check`,
  `debug_game_check`, `ui_text_check`, `globe_map_check`, `server_saves_check`,
  `hangar_check`, `check_snapshot_budget`, `debug_captain_check`,
  `port_menu_check`, `display_fonts_check`, `menu_glyph_check`,
  `world_land_check`, `polar_biome_check`, `day_night_check`, `mooring_check`,
  `crane_check`.
- Not run here: Python was not permitted in this job, so Stage 3 and
  `check_dedicated_split.py` (`--prediction`, `--replication`) did not run
  locally. No Python changed in this round; CI runs Stage 3.
- Seen while testing: adding 20 million credits to a wallet stopped the ship
  from finishing docking (it stayed "docking"). 2 million is fine. Not
  investigated; may be pre-existing.
- Not verified: Windows play, how the planes feel with a real mouse, the globe
  relief on screen (headless has no renderer), a real online session at plane
  and Jetty speeds.

## Patch 4.0.1 — plane feel, crash cam, Fighter jet, turbofans, planes for all, airport ground (November 20, 2026)

Issue #222 (Andy's first plane playtest). VERSION 4.0.0 → 4.0.1. No workflow
edits. The gas, oil, refinery and cargo-fuel code is untouched. The HUD layout is
unchanged; the plane HUD rework is the next patch.
- 1, auto-level (flight_model.gd): hands off (no pitch or roll command), the
  plane rolls gently wings-level (at most 28°/s) and pitches the flight path
  towards level. When set up to land (gear down, throttle under half) it holds a
  gentle 3° glide instead. It fades out completely at 0.12 of any pitch or roll
  command, so it never fights the aim. The aim's dead zone keeps a centred cursor
  at exactly zero.
- 2, landing: the gear and flaps come down near an airport below 250 m when slow.
  The flaps add more lift and drag as the throttle drops. In the last 9 m over
  the airfield the auto-flare eases the sink to 2.5 m/s and levels the wings.
  Touchdown now tolerates an 8.5 m/s sink (was 6), 30° of bank (was 20) and 10°
  nose-down (was 6). Wear only starts above a 3.5 m/s sink. The runway assist
  reaches 3 km out, ±25° and 450 m off the line. It also drifts the plane gently
  onto the centre line, and it now tries every airport: the 4.0 version only
  looked at the nearest runway middle, and the airports are 2–3 km apart. The
  mouse aim is smoothed (0.14 s) and softer near the centre (aviation.gd). On the
  wheels at idle the spoilers dump lift and add drag. The brakes (S at idle) are
  stronger (1.1 g). The airfield grass beside a runway is landable and counts as
  stopped at the airport.
- 3, crash cam: the authority still bills, drops the cargo and parks the plane
  at the nearest airport at once. The view (local play, and the online client
  from `crashes`/`crash_at` in the plane state) holds on the wreck for
  `CRASH_VIEW_S` = 4 s. During that time you see the explosion (fireball, smoke,
  debris), and the camera orbits and pulls back. The laid-up boat (and so the
  sea) stays at the wreck, the respawned plane is hidden and the controls are
  held at idle. Then the view joins the plane. dedicated_runtime.gd places the
  client's boat at `aviation.view_anchor()`.
- 4, Fighter jet `plane_fighter` (3,000,000.00): top speed about 1,350 kn
  (2.2× the Cargo jet, faster than the Jetty), roll 200°/s, pitch 55°/s, a 90 L
  tank (about 7 min at full throttle), no cargo and no jobs. It is a grey swept
  delta with twin fins, a bubble canopy and an afterburner (JET_FLAME) that grows
  with the throttle. It appears in the Planes menu ("no cargo: for the joy of
  flying") and the debug overlay. Snapshot: the plane motion frame's climb-rate
  clamp is raised from ±500 to ±1500 m/s, so a full-speed dive is not clipped
  (no rubber band). The frame size is unchanged.
- 5, the Cargo jet's engines are turbofans (`"fan2"`): pylon-mounted nacelles
  with an intake lip, a 12-blade front fan that spins with the throttle, a grey
  core nozzle and a heat shimmer (alpha at most 0.1). There is no flame node.
- 6, planes are open to everyone: `Levels.PLANE_UNLOCK_LEVEL` = 1 replaces
  `PLANE_LEVEL` = 10. It is the one gate for buying and flying, on the client
  and on the server (the server runs the same `aviation.unlocked()`). XP and
  levels are unchanged.
- 7, airport ground: the 4.0 embankment mesh had its top face wound
  backwards. From above it was a back face and got culled, so the hills under
  it showed through ("yellow blobs") and the toon ink shell drew a black slab.
  Each airport now stands on one grass airfield whose faces all point outward.
  The airfield is level at the runway height over the whole footprint (runway
  and 60 m past each end, 30 m seaward, 95 m inland over the apron, terminal
  and tower; `Airports.field_across/on_airfield/airfield_at`). Terrain.sample
  is flat ("airfield") over all of it.
- Checks: new `tools/patch_4_0_1_logic.gd`, run by `check_catalog.gd` in the
  Checks job (about 5 s), and `tools/patch_4_0_1_check.gd` (123 checks: the
  logic plus the game scene). They cover: the auto-level returns to
  wings-level and level flight hands off and never stops a held roll; a sloppy
  approach lands and stops for every plane at every airport, from two set-ups
  (110–140 m off the line, 9–11° off heading, 15–25 m high, 1.4–1.5× stall,
  coarse inputs, no flare); the crash view lasts 4 s, with the boat at the
  wreck, the plane hidden and the controls idle, then the plane is shown; the
  Fighter jet is ≥ 2× the Cargo jet and faster than every ship, takes no jobs
  and replicates a full-speed dive; the Cargo jet has two fans and no flame; a
  level-1 captain buys and flies a plane; no terrain is above the runway inside
  any airport's footprint and the airfield faces up; 4.0 progress rows load;
  VERSION is 4.0.1. `patch_4_0_logic.gd` and `patch_4_0_check.gd` now expect
  the auto-level and the level-1 gate. A wider offline matrix of the same
  sloppy pilot (4 planes × 6 airports × 6 set-ups, offsets up to 200 m and 12°)
  landed all 144 flights.
- Passed (Linux, Godot 4.7.2 headless): import, check_scripts (277), boot,
  every Stage 2 command (check_catalog with the new logic, diagnostics, controls,
  flow, starter and the twelve probes), `patch_4_0_check` (195), `patch_4_0_1_check`
  (123), `check_snapshot_budget`, `small_boats_check`, `globe_map_check`, and
  `check_dedicated_split.py` plain, `--prediction` and `--replication`. Python
  Stage 3: compileall, the services unittests (76 OK), world_layout and
  traversal budget pass. The `tools/public_handoff` suite has 4 import errors
  because `psycopg` is not installed in this job; this is the same on main.
- Not verified: Windows play, how it feels with a real mouse (smoothing, the
  auto-level and landing were only flown by scripted pilots), the crash camera
  and the new models on screen (headless has no renderer), and an online session
  at Fighter speed.

## Patch 4.0.2 — no upside-down, manual gear + nudge, plane hangar, runway fixes, polar relief, new boat looks (November 21, 2026)

Issue #224 (Andy's second plane playtest). VERSION 4.0.1 → 4.0.2. No workflow
edits. The gas, oil, refinery and cargo-fuel code is untouched. The plane HUD
rework and 4.1 gacha are out of scope.
- 1, polar relief: `PolarIce.relief(at, depth)` (polar_ice.gd) adds icy ridges
  (up to about 74 m), snow hills and massifs on the cap, fading in from 150 m
  inside the ice coast. It is plain maths, with whole-turn frequencies, so it
  meets itself across every world edge. The ice mesh draws every plateau square
  with it (no more flat run quads); steep ridge faces are blue glacier ice; the
  snow peaks stand on it. `Terrain.sample` (planes, client and server) adds the
  same relief. The M-map globe gets a polar relief shell (every 4th ice sample),
  levelled right at the pole. The ships' ice colliders (`ICE_SHELVES`) are
  unchanged.
- 2, planes on the maps: the minimap draws a top-down plane silhouette for the
  own plane and for other captains' planes (`icon_for`, `own_icon`,
  `plane_outline`). The globe's entries use the plane kind while flying and build
  a small plane model (`build_plane`).
- 3, runways: the airfield's grass top now stands 0.12 m below the runway and is
  cut away under the runway and the apron. The runway is one solid slab, and its
  markings (edge lines, a dashed centre line, threshold bars) are painted into its
  own top as a mipmapped texture. Before, stripe boxes lay on it. No two surfaces
  overlap, so nothing z-fights at any distance. The apron is a slab 4 cm below
  the runway's surface. Plane physics is unchanged (runway and airfield at
  `RUNWAY_Y`).
- 4, decorations: `Airports.clear_of_airfields(at, reach)` keeps dunes, mesas,
  palms, bushes and city towers 40 m plus their own reach off every airfield.
  Each item's random draws still happen, so the rest of each layer stays where it
  was. The hills were already clear (4.0.1).
- 5, no upside-down: `FlightModel.limit_aim` (used by `Aviation.steer_order`)
  keeps the mouse aim inside a 60° bank (Fighter 75°). It aims 3° inside the
  limit and eases the roll off near it; past the limit it rolls back. The aim's
  coordinating yaw eases off with the roll. Pitch is held inside 60° (aimed 6°
  inside), so there are no loops. A held A / D is an intentional roll (no bank
  limit; the pitch limit still holds). When the key is released the plane rolls
  back to the limit, and hands off the 4.0.1 auto-level levels it. Root cause of
  the flips: aiming below a banked plane rolled it further over ("steer towards
  the cursor").
- 6, manual gear: the model's input `"gear"` is a lever (1 down, 0 up). The gear
  moves in the air when the lever changes, so a late "down" from before an
  automatic retraction never lowers it again. On the ground it stays down. It
  comes up on its own after a real lift-off, climbing above 30 m. G (the
  salute key; while flying it is the gear, not the salute) toggles it. The helm
  payload carries `gear` (ship_actions accepts 4, 5 or 6 fields). The server's
  gear state was already in the motion frame and drives other players' models.
  Gear-up touchdown: a belly landing (35 % repair bill now, capped by the wallet;
  the cargo stays; it slides to a stop on 0.45 g and is put back on its wheels).
  Over 12 m/s sink is still a crash. HUD nudge "Press G — Gear down" pulses
  under the warning banner, with one chime, when gear up, descending, below
  300 m and within 2 km of any runway threshold. Every plane has legs (strut,
  silver oleo, torque link, axle, black tyres on pale hubs, twin wheels on the
  jet and turboprop), a well and two doors per leg. The legs fold in 1.5 s, the
  nose forward and the mains inward (`PlaneLook.fold_gear`). The 4.0.1 auto-gear
  (`gear_for`) is gone. The scripted test pilot now lowers the gear for its
  approach.
- 7, plane hangar: `features/planes/plane_hangar.gd` extends the boat hangar
  (same screen, layout, fonts, buttons and keys). It overrides only the plane
  parts: an aircraft hangar (concrete floor, guide line, turntable, steel walls,
  red arched trusses, doors open onto the apron), every plane on the turntable,
  price / top speed / stall / fuel / capacity, Buy · Select · Fly through
  Aviation's own actions. Both Planes buttons open it (the old list stays as a
  fallback). It is in export_presets.cfg.
- 8, debug panel: the Debug Menu shows the boat controls while sailing and, while
  flying, a plane readout (speed, height, gear, fuel), a plane picker, Refuel,
  Repair, Gear, Nearest Airport, Next Time of Day and Spawn at Airport.
- 9, boats (looks only; stats, prices and hitboxes unchanged): the Speedboat is
  a Grady-White Marlin-style walkaround. It has a deep-V white hull with a navy
  boot stripe and a raised, flared bow, a centre console under a white hard top
  on steel T-top legs with rod holders, a leaning post, bow rails and twin white
  outboards. The Jetty is a long delta hull (needle nose, widest at the stern)
  with a slim canopy, winglets and hydrofoil struts. Its nozzle, ring and
  JetFlame are byte-for-byte the same code and position.
- Checks: new `tools/patch_4_0_2_logic.gd` (220 checks), run by `check_catalog.gd`
  in the Checks job (check_catalog about 13 s locally), and
  `tools/patch_4_0_2_check.gd` (272 checks: the logic plus the game scene). The
  game-scene part covers: Planes opens the hangar, it cycles and buys, and Fly
  takes off; the minimap and globe show the plane; G in the air only; the nudge
  shows only when it should; a belly landing bills, keeps the cargo and does not
  explode; the debug panel switches and its plane buttons work. Updated to the new
  design: `patch_4_0_logic` (G raises the gear in cruise), `patch_4_0_1_logic`
  (the cut airfield top and VERSION ≥ 4.0.1) and `world_land_check` (three ice
  materials; the plateau carries the relief).
- Passed (Linux, Godot 4.7.2 headless): import, check_scripts, boot, every
  Stage 2 command (units_probe, check_catalog, diagnostics_probe, check_controls,
  check_flow, check_starter and the twelve probes), the Stage 4 report probes,
  patch_4_0_check, patch_4_0_1_check, patch_4_0_2_check, ui_text_check,
  display_fonts_check, small_boats_check, globe_map_check, hangar_check,
  debug_game_check, cannon_salute_check, world_land_check, the polar, desert,
  tropical and rain biome checks, volcano_check, map_remix_check,
  port_menu_check, mooring_check, server_saves_check, check_helm_keys,
  check_snapshot_budget, and `check_dedicated_split.py` plain, `--prediction`
  and `--replication`. Python: compileall, the services unittests, world_layout
  and the traversal budget. `play_connection_check` (empty service URL) and
  `action_probe` (ENet port) print the same errors on main in this environment.
- Not verified: Windows play; how the bank limit, barrel roll and gear nudge feel
  with a real mouse and keyboard; the new models, hangar, runway paint and polar
  relief on screen (headless has no renderer); an online session with two
  players watching each other's gear. Note: with the gear up the runway assists
  (alignment, glide, flare) stay off, as they are for a plane set up to land.

### Patch 4.0.2 follow-up — the Jetty hovers; Shift Blaster Boost (November 21, 2026)

Andy's comment on PR #225. VERSION stays 4.0.2. No workflow edits. The gas, oil,
refinery and cargo-fuel code is untouched.
- Hover (looks only): `ShipVisualMotion` lifts the Jetty's hull 2.0 m off the
  water at rest (keel about 0.9 m clear), up to 0.8 m more at full speed and
  0.5 m more in a blast. It floats slowly, trims calmly, leans into turns and
  follows only a third of the swell. It never "jumps". The body, collider,
  camera and every stat stay as they were. The other boats are unchanged.
- New `features/toon/jetty_fx.gd` ("JettyFx", built by `_dress_jetty` next to
  the unchanged nozzle, ring and JetFlame). On the water under the hull it
  draws "Downwash" (CPUParticles3D spray blown out flat), "RoosterTail" (a
  plume up and back behind the stern that grows with speed) and "Glow" plus
  "GlowLight" (a pulsing teal pool of light).
- Blaster Boost: new `features/ships/jetty_boost.gd`. Every `HandlingShip`
  has one; only the Jetty can fire it (`request_boost`). Shift starts a 0.6 s
  charge, then the blast gives +60 % speed for 2.5 s (a 0.15 s kick in, a
  0.35 s ease out), then a 6 s cooldown. Docking, an empty tank or the blast's
  end cancels it. The speed is changed only in `advance_motion`. The local hull
  does it offline. Online, the server's hull does it (gameplay action
  `"boost"`). `CollisionRules.SUPPORTED_SPEED_MPS` is 520 → 830 m/s, which
  covers the boosted 823 m/s.
- Blaster looks: during the charge a "ChargeOrb" swells and spins through the
  colours at the nozzle. On the blast a "BoostFlame" fires: three nested cones,
  22 m long (4× the thruster's), cycling the colour wheel 3.2 times a second.
  A "BlastRing" shock wave bursts off the stern and the under-glow flares.
- Sound: `JettyFx.charge_sound()` and `blast_sound()` are built once in code
  from sine, saw and noise. The charge is a whine rising three octaves, a
  quickening flutter, a rising hum and a fizz. The blast is a falling boom, a
  detuned saw zap diving from 1.8 kHz to 120 Hz, a roaring filtered-noise beam
  and a throbbing rumble, soft-clipped. No recorded or copyrighted audio.
- Input/HUD: Shift is a fixed key in `PlayerControls`
  (`BOOST_COMMAND = &"jetty_boost"`). No binding can take it, so saved
  bindings are untouched. Esc > Controls lists "Jetty: blaster boost — Shift".
  On the Jetty the helm bar shows BLASTER READY / CHARGING... / BOOST! /
  the cooldown in seconds.
- Checks: `patch_4_0_2_logic.gd` adds the parts `jetty_hover`, `jetty_boost`,
  `jetty_blaster_look` and `jetty_blaster_sound` (they run in check_catalog,
  about 14 s). `patch_4_0_2_check.gd` (354 checks) adds two things: a boosted
  Jetty at 823 m/s stops at a 0.1 m wall, and the game scene on the Jetty.
  There, the hull hovers with its effects, Shift through PlayerControls
  charges, the HUD says so, the blast fires (flame and sound), and a second
  Shift is refused.
- Passed (Linux, Godot 4.7.2 headless): import, check_scripts (282), boot,
  every Stage 2 command, collision_probe, small_boats_check, patch_4_0_check,
  patch_4_0_1_check, patch_4_0_2_check, ui_text_check, display_fonts_check,
  hangar_check, debug_game_check, check_helm_keys, check_snapshot_budget,
  globe_map_check, bulk/heavy ladder checks and cannon_salute_check.
- Not run: Python was refused in this job, so `check_dedicated_split.py`
  (plain, `--prediction`, `--replication`) and the Stage 3 Python checks did
  not run after this change. The online boost path is not verified.
- Not verified: Windows play; how the hover, particles, RGB flame and sound look
  and sound (headless has no renderer or audio); other captains see the hover
  but not another player's blaster flame (the speed is replicated, the looks
  are not).

## Patch 4.0.3 — keyboard flight, polar seams, globe icons, heavy-lift dock, dock menu, plane jobs, Point Nemo, polar runways (November 21, 2026)

Issue #226 (Andy's playtest of 4.0.2) and its addendum. VERSION 4.0.2 → 4.0.3.
No workflow edits. The gas, oil, refinery and cargo-fuel code is untouched. The
4.1 gacha is out of scope.
- 1, keyboard-only flight: the mouse no longer steers (right-drag still orbits).
  W / S climb and descend; released, the auto-trim levels off and holds the
  altitude it captures. A / D bank to 45° (Fighter 60°) in a coordinated turn
  and roll level when released. Shift / Ctrl move a throttle lever that stays
  put. Space is the wheel brakes on the ground and the air brake in the air.
  Q / E barrel roll; G gear (with the 4.0.2 nudge). Stall protection, the
  pitch and bank limits, runway line-up, auto-flare and belly landings stay.
  The help text and the scripted pilot (`flight_autopilot.gd`) use the keys.
- 2, polar seams: the ice is rebaked solid 800 m either side of each pole,
  with no lead crossing the world's edge; the cap relief levels off at the
  pole, so the globe has no wedges or streaks.
- 3, globe icons: airports are the runway only (no red plane); ports are a
  small pier with a crane, on the globe and the minimap.
- 4, heavy-lift docks: the cause was Cinder Point. Its berth offered no
  `heavy_transfer` and took no industrial cargo (every other port did), so
  every heavy lifter was refused there. Both records now offer it. The port
  card shows one platform button whenever a heavy lifter is docked or on a
  job: Drop (lowers the deck), then Lift (raises it). Online it sends the
  existing `lower` / `raise` actions. Cancel pickup shows only with a job.
- 5, dock menu: row 1 Refuel, Repair … Ships; row 2 Switch to Plane … Planes.
  The actions are on the left and the two shops stack on the right.
- 6, plane job board: the boat board's cards (`GameHud.job_card`, now shared):
  a cargo picture (people for passengers, parcels for packages), the route,
  a trip line (km, minutes at 80 % of top speed, litres of fuel at full
  burn, `PlaneJobs.trip`), the gold pay and Accept. Both boards' cards get a
  gold edge under the mouse. With a plane job aboard, the minimap and the
  globe point at the job's airport and the globe draws the dotted course.
- 7, Point Nemo: three islets (`tools/world_layout/point_nemo.py`), a port and
  a runway, out in the empty ocean between Slatewater Works and Brindle Quay.
- 8, polar runways: Cinder Strip is on the north cap; Gannet Aerodrome is
  South Runway at the south cap's centre. Both keep their index and ID, so
  saved planes and job IDs follow them.
- Addendum, plane throttle: flying, the helm bar keeps the boat's throttle
  slider in the same place and style, running 0 to 100 % (no reverse), marked
  0% / 50% / 100%. Shift / Ctrl move it; dragging it sets the lever. Back on
  a boat it is R / N / D again.
- Checks: new `tools/patch_4_0_3_logic.gd` (631 checks), run by
  `check_catalog.gd` in the Checks job (check_catalog about 20 s locally,
  under the 30 s limit). It covers: released keys hold the altitude within
  20 m for 30 s (level, and after W or S once the plane has levelled off);
  A / D bank up to, never past, the limit, turn, and roll level; Space brakes;
  the lever stays put; every port offers the container and heavy services,
  takes both cargo types and fits every buyable hull; the trip estimates on
  every board; Point Nemo; the polar runways; VERSION. New
  `tools/patch_4_0_3_check.gd` (755 checks: the logic plus the game scene):
  every buyable class docks at Cinder Point and every heavy lifter at every
  port; docked, a heavy lifter shows Drop, which lowers the deck, then Lift,
  which raises it, and no other class shows the button; the dock menu order
  and right-hand column; the throttle slider flying (range, marks, both ways)
  and back on a boat; the plane job cards (picture, trip, gold pay, hover
  edge, Accept), and the globe's course to the job's airport.
- Passed (Linux, Godot 4.7.2 headless): import, check_scripts (284), boot,
  every Stage 2 command (units_probe, check_catalog, diagnostics_probe,
  check_controls, check_flow, check_starter and the twelve probes),
  patch_4_0_3_check, patch_4_0_check, patch_4_0_1_check, patch_4_0_2_check,
  heavy_ladder_check, check_m1_voyage, world_land_check, globe_map_check,
  ui_text_check, port_menu_check, hangar_check and the Stage 4 report probes
  (ports_probe, collision_probe, composition_probe). Two old counts assumed
  six ports and failed after Point Nemo; they now count the world's ports:
  `ports_probe` (the restocked container jobs) and `check_m1_voyage` (the
  ports after a reload).
- Not run: Python was refused in this job, so Stage 3 (compileall, the
  services unittests, world_layout tests, the traversal budget) did not run
  locally; CI runs it.
- CI fix (after fcad7ce): Stage 3 failed with `test_cinder_point_is_placed_as_recorded`,
  `test_layout_agrees` and `WORLD_LAYOUT_FAIL ... port_cinder_point: planned
  services drop a recorded service`. Cinder Point's position was fine; the
  planned services in `features/world/world_layout.json` were missing the
  `heavy_transfer` that item 4 added to its port and berth records. Added it,
  so the plan keeps every recorded service. Heavy hulls now also plan
  Brindle–Cinder (5.6 km) and Slatewater–Cinder (6.7 km); the slowest, the
  Heavy Lifter, needs about 16 min and 660 L of its 1,600 L limit, inside the
  40 min / fuel limits. Python was refused in this job too, so this was
  worked by hand from `traversal_budget.py` and checked by CI.
- Not verified: Windows play; how keyboard flight, the throttle slider and the
  new cards feel and look (headless has no renderer); the altitude hold after
  a long steep climb on a fast plane (the plane first levels off, which takes
  some height: the check bounds the time, not the height); online Lift / Drop
  with a real server.

## Patch 4.0.4 — audit fixes, plane HUD, plane job and replication checks (November 21, 2026)

Issue #228. VERSION 4.0.3 → 4.0.4. No workflow edits. The gas, oil, refinery
and cargo-fuel code is untouched. No save format changes: old saves load as
before. `docs/AUDIT_4_0_4.md` and the `audit-4-0-4` branch do not exist, so the
audit was done fresh, file by file.
- 1, perf and bug pass:
  - Online, a cannon salute was sent twice per press. The second send was
    refused (rate limit, then the 5 s cooldown), so the client showed "Action
    refused" after every salute and the server rebuilt the gameplay snapshot
    for nothing. It is now sent once (`dedicated_runtime.client_command`).
  - The plane job board (`Jobs.board`, its sort and a `map`) was rebuilt every
    frame while stopped at an airport. It is now built only when the airport,
    the plane or the job changes (`aviation.board_key`).
  - `PlaneLook.animate` searched the whole plane model three times every frame,
    for your plane and for every other captain's. It now finds the moving
    parts once per model (`anim_parts` meta).
  - The game rebuilt the delivery receipt from every offer each frame and
    then hid it, and refreshed the hidden old Ships list each frame. Both
    now run only where they are shown. The deliver reason is worked out once
    per frame, not three times.
  - The docked port title re-ran `DISPLAY.fit` every frame. It set a theme
    override, which re-laid the label out. It now re-fits only when the name
    or the card width changes.
  - The server deep-copied the gameplay state twice per player, five times a
    second. Now it copies once: the copy it compares against.
  - Every crash had the same debris pattern: the explosion seeded its random
    numbers before it was placed. It is now placed first.
  - The Jetty's two cached sounds were held past exit, so Godot reported
    "2 ObjectDB instances were leaked" after a blaster had played. They are
    released when the last Jetty effect leaves the tree.
  - Dead code: `JettyBoost.readiness()` (no callers) is gone.
  - `dedicated_split_check.gd` still expected six ports. It has failed since
    Point Nemo in 4.0.3, but CI does not run it. It now counts
    `Progression.WORLD`.
- 2, plane HUD: while flying, the helm bar has an instrument row above the
  throttle slider, in the boat bar's style (cream captions, sunny figures,
  the same plain bold face). The cells are: THR, a drawn 0–100 % gauge with
  its percentage; IAS in knots; ALT in metres, with the height over the
  ground (AGL) in its caption; V/S in m/s, smoothed; HDG in degrees with
  its compass point (north +Z, east -X); FUEL %, which turns red under 20 %;
  and GEAR, a light that is green for DOWN, red for UP, and blinks red while
  "Press G — Gear down" shows. The big helm figure is now the airspeed, as
  the boat's is its speed. The row is hidden on a boat.
- 3, a headless plane job end to end, `tools/patch_4_0_4_check.gd` (66
  checks), in the real game scene with an isolated save. It docks, switches
  to the Turboprop and checks the instrument row. It takes the shortest job
  from the airport board with the card's Accept. It flies with the keys:
  `flight_autopilot.gd` presses W / S / A / D / Space through the input map,
  moves the lever as Shift / Ctrl do, and presses G on final. It lands and
  stops at the destination and presses Deliver. Paid: banked +pay, XP up.
  Then it switches back to the boat. The flight runs at 1/60 s physics steps,
  eight steps a frame: 214 s of flight in about 27 s, about 34 s in all.
  It is not in CI (the 30 s limit). The scene-free part,
  `tools/patch_4_0_4_logic.gd` (the HDG compass, the blaster use count, the
  cached plane parts, VERSION), runs in `check_catalog.gd` (about 20 s).
- 4, online replication. Other captains now see a Jetty's blaster: the status
  row carries `boost` (`JettyBoost.uses()`, which rises once per Shift), and a
  rise starts the replica's charge, so JettyFx plays the orb, flame and
  sound. New `python3 tools/check_dedicated_split.py --flight`
  (`tools/dedicated_flight_check.gd`): a real UDP server and two clients.
  The server stages client1 airborne in a plane and swaps client2 to the
  Jetty. Client1 holds the lever and presses G; client2 presses Shift. Both
  go through the real helm frames and actions. It checks:
  - client2 sees client1's plane: the right kind, in the air, its nameplate,
    and its gear folding from down to up after G;
  - client1 sees client2's Jetty hovering (JettyFx and the hover lift) and
    its blaster charge and blast;
  - client1's own plane HUD shows online;
  - the server's plane flew, its gear came up, and the Jetty's boost fired.
- Passed (Linux, Godot 4.7.2 headless): import, check_scripts, boot, every
  Stage 2 command (units_probe, check_catalog, diagnostics_probe,
  check_controls, check_flow, check_starter and the twelve probes), Stage 3
  (compileall, the services unittests, public_handoff with psycopg,
  world_layout tests, traversal_budget). Also patch_4_0_check through
  patch_4_0_4_check, check_m1_voyage, ui_text_check, display_fonts_check,
  hangar_check, debug_game_check, check_helm_keys, check_snapshot_budget,
  globe_map_check, port_menu_check and cannon_salute_check, and
  `check_dedicated_split.py` plain, `--prediction`, `--replication`,
  `--families` and `--flight`.
- Not verified: Windows play; how the instrument row looks at each window
  size (headless has no renderer); how other captains' blaster sound plays
  (headless has no audio). The minimap still redraws every frame. That is
  left for 4.0.5 (below).

### 4.0.5 notes (left over from the 4.0.4 audit)
- The minimap (`globe_minimap._draw`) re-projects and re-triangulates the
  land every frame, even docked. Redraw it only when the ship moves or turns,
  or while a destination ring pulses.
- `aviation.state()` still deep-copies `planes` five times a second per
  flying captain. It is small; drop the copy once nothing mutates it.
- Consider running `patch_4_0_4_check` and `check_dedicated_split.py --flight`
  in CI. That needs a workflow edit, which only Andy or Hark can ask for, and
  the 30 s limit would need to cover the flight.

## Patch 4.0.5 — controllers, crash and error reports, plane engine sounds (November 21, 2026)

Issue #230. VERSION 4.0.4 → 4.0.5. No workflow edits. The gas, oil, refinery
and cargo-fuel code is untouched. No save or settings format changes: old saves
and `preferences.json` load as before. Every existing `.gd.uid` is kept; the new
scripts' `.uid` files were made by Godot's import. The five new runtime
scripts are added to all three presets' `export_files` in `export_presets.cfg`.
- 1, controllers (`features/input/gamepad.gd`, `pad_cursor.gd`,
  `player_controls.gd`). Godot reads Xbox and PlayStation pads through SDL's
  standard layout. The pad's events are added to the same InputMap actions,
  after the keys. The key bindings, their checks and Settings' rebinding are
  untouched, and the pad layout is fixed.
  - Boats: the left stick steers and moves the throttle order. RT / LT also
    move it. LB / RB are the thrusters, A Interact, B engine to zero, X the
    Jetty's blaster, Y the cannon salute, L3 the horn and R3 recenters the
    camera. The right stick looks around, View opens the map and Menu
    (Options) the Esc menu.
  - Planes: the left stick climbs, descends and turns. RT / LT are the
    throttle lever (Shift / Ctrl), LB / RB a barrel roll, X the brakes and Y
    the gear.
  - Menus: many of the game's buttons never take focus (so Esc always reaches
    the menu), so a cursor ring (`pad_cursor.gd`) does not use focus. The
    D-pad (or the left stick in a menu) moves it to the nearest button. A
    clicks the button at its centre, as the mouse does, and left / right move
    a slider. With a menu open, only its top layer counts.
  - Screens that already use focus (the main menu list, Settings, popups)
    keep Godot's own focus moves; A was added to `ui_accept`. The hangars step
    with the D-pad themselves (`Gamepad.NAV_GROUP`).
  - Menu, and B in a menu, send a real Esc press, so every screen's own Esc
    handling runs. Sailing, the D-pad can put the ring on a HUD button while
    the sticks keep steering; B hides it.
  - Glyphs: whichever device was used last (`Gamepad.pad_last`) sets the
    words. After a pad press, the helm notice, the game's hints, the plane's
    take-off line and "Press [Y] — Gear down", and Esc > CONTROLS (it refreshes
    on a switch) show pad buttons: `[A]`, `[RT]`, `[Menu]`, or `[Cross]`,
    `[R2]`, `[Options]` on a PlayStation pad. These are text glyphs, not
    images. A key press switches back to key names.
- 2, crash and error reports (`features/network/error_reports.gd`,
  `client_error_log.gd`, `dedicated_runtime.gd`, `boot.gd`).
  - A Godot `Logger` catches every engine and script error (not warnings) with
    its GDScript backtrace. A report holds only the version, the OS name and
    version, the scene file, the message, the location and the stack.
    `scrub` replaces the user and install folders, the OS user name, the
    captain name, IPv4 / IPv6 addresses and e-mail addresses.
  - Each report is capped (500-character message, 3,000-character stack,
    4 KB). Repeats raise a count. The outbox (`user://crash_reports/outbox.json`)
    keeps 20, and one run adds at most 40.
  - A crash cannot run code, so each run writes `running.json` and a clean
    exit removes it. If it is still there at the next start and the previous
    Godot log has "Program crashed", that backtrace becomes a crash report.
  - Online, the client sends one report every 3 s to the server
    (`client_error_report`, joined captains only). The server checks it again:
    known fields only, text only, cut and scrubbed, more than 8 KB refused. It
    rate limits each captain (a burst of 5, then 1 every 3 s, at most 30 per
    connection) and the whole server (600 an hour).
  - The server writes one JSON line per report with the arrival time and no
    peer, captain, key or address. The log is `<root>/logs/client_errors/
    client_errors.log`, beside `<root>/saves`. For the packaged server that is
    `C:\ShippingLanesServer\logs\client_errors\`; `--client-errors-dir=`
    overrides it. It rotates at 1 MiB and keeps 5 files.
  - Single-player reports wait in the outbox until the next online session.
    There is no other upload.
- 3, plane engine sounds (`features/planes/plane_engine_sound.gd`), made in
  code (CC0, credited in `features/audio/CREDITS.md`). Each family is a
  one-second seamless loop set:
  - Bush prop: a 42 Hz piston firing buzz with a propeller beat.
  - Regional turboprop: a 70 Hz four-blade hum with a turbine whine.
  - Cargo jet: the turbofan's buzz-saw fan tone and whine, plus a roar layer.
  - Fighter jet: turbine whine and roar, plus an afterburner rumble and
    crackle above 85 % lever once the engine has spooled up.

  The core is pitched by the engine's RPM (`model.engine`, which follows the
  lever), and the roar rises with it. Your plane plays flat; it replaces the
  boat engine tone the planes used. Other captains' planes play from the
  plane (AudioStreamPlayer3D), with a doppler factor worked out from their
  velocity and the camera's, clamped to 0.5–2.
- Checks:
  - `tools/patch_4_0_5_logic.gd` (in `check_catalog`): the pad layout and
    dead zones, the keys unchanged, the glyphs (Xbox, PlayStation, swaps, the
    Controls list), scrubbing, report caps and repeats, the outbox, the
    Logger, crash detection from a fake log, and the server's limits, fields,
    scrubbing and rotation. Also the engine loops (seamless, audible, four
    families), pitch by RPM, the afterburner rule and doppler.
  - `tools/patch_4_0_5_check.gd` (165 checks, about 12 s, not in CI): the
    game scene driven by pad events through Input. It sails (stick, B,
    triggers, right-stick camera), checks that W still works and the bindings
    are the same, then opens the Esc menu with Menu. The ring reaches
    CONTROLS, A opens it (it lists pad buttons), B goes back and A on RESUME
    closes it. It puts the ring on the HUD while steering, flies (RT / LT
    lever, the turboprop's sound rising, X brakes to a stop) and works the
    main menu list with the D-pad, A and B.
  - `python3 tools/check_dedicated_split.py --errors`
    (`tools/dedicated_errors_check.gd`): a real UDP server and two clients.
    Each client raises an error through the Logger with an address, an e-mail
    and its captain name, then floods the server. The server's log holds only
    scrubbed, known-field lines; the flood is rate limited and the oversized
    report refused.
- Passed (Linux, Godot 4.7.2 headless):
  - The CI set: import, check_scripts, boot, Stage 2 (units_probe,
    check_catalog in about 14 s, diagnostics_probe, check_controls,
    check_flow, check_starter and the twelve probes), Stage 3 (compileall,
    the services unittests, public_handoff with psycopg, world_layout tests,
    traversal_budget) and the Stage 4 report probes.
  - Also patch_4_0_check through patch_4_0_5_check, check_m1_voyage,
    ui_text_check, display_fonts_check, hangar_check, debug_game_check,
    check_helm_keys, check_snapshot_budget, globe_map_check, port_menu_check,
    cannon_salute_check and check_title.
  - `check_dedicated_split.py` plain, `--prediction`, `--replication`,
    `--families`, `--flight` and `--errors`.
- Not verified:
  - A real controller on Windows. The checks send SDL-style pad events
    through Input, and the PlayStation names come from the pad's reported
    name.
  - How the cursor ring and the engine sounds look and sound (headless has no
    renderer or audio).
  - A real native crash picked up from a Windows Godot log. The check uses a
    log in Godot's crash format.
  - The packaged server writing to `C:\ShippingLanesServer\logs\
    client_errors` (worked out from its `--saves-dir`; the Linux check uses a
    temp folder the same way).
- Left from the 4.0.4 notes (not part of #230): the minimap still redraws
  every frame, and `aviation.state()` still copies `planes`.

## Patch 4.0.7 — arcade turns, real props, Jetty restyle, Jetty over land, Jetty water effects (November 21, 2026)

Issue #234, draft PR #235. VERSION 4.0.6 → 4.0.7. No workflow edits. The gas,
oil, refinery and cargo-fuel code is untouched. No save format change: the
saved pose stays on the sea plane, so old saves load as before. Every existing
`.gd.uid` is kept; the new scripts' `.uid` files were made by Godot's import.
`features/ships/jetty_land.gd` is added to the presets' `export_files`.
Reference images: `docs/reference/patch_4_0_7/` (from `patch-4-0-7-refs`).
- 1, flight turning (`features/planes/flight_model.gd`). A / D now command the
  heading rate (`turn_rate_cmd`): 23°/s at cruise (1.6× stall speed and up;
  a share of it when slower), the Fighter 35°/s. It eases in over 0.3 s and
  back out on release. The bank is the result of the turn (the bank that
  turn would need, capped at 45°, Fighter 60°, less when slow). The wing's
  lift, the angle of attack and the nose are worked out in the wings-level
  frame, so the nose stays level and the altitude holds; the velocity turns
  with the nose. A barrel roll, or a bank past 85° after one, flies the old
  physical model. On the ground A / D steer the nose wheel as before. The
  old turn was `g·tan(bank)/V`, about 4°/s at cruise.
- 2, props and turbines (`features/planes/plane_look.gd`). The old blades
  were rotated by their angle but offset along a different line, so two of
  three made a V that missed the hub (the "arrow"). Now: the bush plane has a
  2-blade prop and the turboprop two 4-blade props, each blade on its own
  pivot evenly round the hub, pitched, tapered, with painted tips, a pointed
  spinner and a back plate; props sit clear of the ground. The blur disc
  shows only from 55 % RPM (at most 16 % opaque). The RPM spools after the
  engine, and props and fans spin by it. Turbofans: a lip ring, 18 pitched
  fan blades behind it, a spinner with a swirl mark, a core nozzle and a
  pointed exhaust cone. The Fighter: a ring of nozzle petals and a throat
  (`NozzleGlow`) that goes dull red → orange → white-hot in afterburner. The
  same models are used in the plane hangar and in the world.
- 3, the Jetty's look (`features/toon/chunky_look.gd`). The hydrofoil struts
  and foils (the legs) are gone. New faceted wedge hull
  (`wedge_hull_mesh`): a delta in plan, a Cybertruck-style straight ridge
  line in profile, flat-shaded in brushed steel, gunmetal and black, metallic.
  Black glass canopy, panel seams, steel strakes, angular fins, a steel and
  black engine block. Small cool-white lights only: a bow tip, a light bar
  across the stern and a running light on each fin. The under-glow is cool
  white. The thruster, its flame and the hover and blaster effects are kept.
  The keel is now 1.5 m clear of the water at rest.
- 4, the Jetty over land (`features/ships/jetty_land.gd`, `handling_ship.gd`).
  Land, Point Nemo, the polar ice and the icebergs join the `jetty_passable`
  group; a Jetty hull takes a collision exception with each (the dedicated
  server's wrap copies are split the same way). Instead it meets the shared
  terrain (`features/planes/terrain.gd`, baked data, the same on the client
  and the server): its body follows the ground's height (climbing to the
  ground ahead quickly, settling smoothly, never below it), carried in its
  velocity and pose, so the server's simulation, the client's prediction and
  the snapshot (which already sends Y) agree. Slopes steeper than 35° stop it
  (sliding along X or Z if that is clear), so cliffs, the ice cliffs, the
  icebergs' flanks and mountains block, and a hard stop is an impact like the
  shore. The volcano's cone and the bridges' piers stay solid bodies. The
  land round each port's quay (260 m) blocks it from land (buildings and
  cranes; no docking from land), and docking is refused while over land
  ("Hover back onto the water to dock."). A runway, or its airfield, blocks
  while a plane is on it or on final (`note_plane` in the planes' authority
  tick, 5 s). The terrain now follows the drawn beach: before, the hill's
  foot height (3.8 m) stood right at every waterline, a step no hover could
  climb (planes' crash checks are unaffected). A save made over land keeps
  the sea-level pose, so the format is unchanged; such a save starts at its
  port on load (as for any pose inside land since Patch 2.9).
- 5, the Jetty's water effects (`features/toon/jetty_fx.gd`), looks only.
  Under the hover: a dark depression, two ripple rings running out, spray
  mist. Moving: a tall rooster-tail plume (about eight hull lengths at full
  speed), a wide V wake with a dark trench, heavy spray sheets off both sides,
  all scaled by speed; near top speed (own Jetty only) speed lines and a FOV
  kick of up to 7° (+5° in a blast, given back after). The blaster adds a big
  white-hot burst and a flash. Over land: sand-brown dust, snow over ice,
  grey over rock, and no water effects. All emitters are GPUParticles3D made
  once per Jetty and reused; their materials, meshes and the soft puff
  texture come from one shared pool. The water effects lie flat on the
  water (heading only), not tilted with the hover. LOD by camera distance
  (full to 260 m, thinning to 1.1 km, off beyond); other captains' Jetties
  (`remote_replica`) run at 55 % and never touch this camera. Other captains
  see the effects (each client draws them for the replica it sees).
- Checks:
  - `tools/patch_4_0_7_logic.gd` (159 checks, in `check_catalog.gd`): the
    turn for every plane both ways (90° in 4.07 s, Fighter 2.72 s; altitude
    within 2.3 m; ease-in; level on release), nose-wheel steering, W / S,
    altitude hold, barrel roll, gear, throttle and brakes; the props, fans
    and nozzle; the Jetty's look; the terrain rules (an island crossing found
    by search, the volcano and an ice cliff block, port grounds, a runway
    only while busy, the height follow); the effects (GPU, pooled, scaled by
    speed, burst, dust and snow, remote LOD).
  - `tools/patch_4_0_7_check.gd` (181 checks, not in CI): the game scene.
    A real Jetty crosses an island from beach to beach (about 700 m, over an
    18 m hill) under power, never under the ground, with spray then dust;
    docking from land is refused there and a save there keeps the sea-level
    pose. A speedboat sent the same way is stopped by the coast; the volcano
    still stops the Jetty. The flying turboprop has two 4-blade props, and D
    held through the real controls turns a plane 90° in under 5 s within
    20 m of altitude.
  - Old checks updated: `patch_4_0_3_logic.gd` adds up the heading change
    (at the new rate the plane comes full circle in 15 s);
    `patch_4_0_2_logic.gd` expects GPU particles. `patch_4_0_6_logic.gd`'s
    turbulence part used the wall clock and failed whenever no storm had a
    clear core that minute (it failed on the untouched baseline too); it now
    moves the shared clock on a minute at a time, as `patch_4_0_6_check.gd`
    does.
- Passed (Linux, Godot 4.7.2 headless):
  - The CI set: import, check_scripts, boot, units_probe, check_catalog,
    diagnostics_probe, check_controls, check_flow, check_starter and the
    twelve Stage 2 probes. Stage 3 (Python) was not rerun: no Python changed.
  - patch_4_0_check through patch_4_0_7_check, world_land_check,
    volcano_check, small_boats_check, polar_biome_check, tropical_biome_check,
    hangar_check, debug_game_check, debug_captain_check, check_m1_voyage,
    globe_map_check, mooring_check, check_helm_keys and collision_probe.
  - `check_dedicated_split.py` plain, `--flight`, `--prediction`,
    `--replication`, `--families` and `--errors`. `--families` failed once
    while run beside other Godot checks (a server exit) and passed when run
    alone.
  - Renders under Xvfb (OpenGL, software) of every plane at idle and at full
    RPM, and of the Jetty at rest, at speed and in a blast. Seen by me, not yet
    by Andy.
- Not verified:
  - Andy's Windows playtest: how the turn feels, the props, the Jetty's look,
    crossing land in the real world and the effects at full speed (frame
    rate on his GPU).
  - Two real clients watching each other's Jetty cross land (the
    `--flight` split covers the replicated hover and blaster on water).

