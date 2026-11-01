# Shipping Lanes

A Windows shipping game built with typed GDScript and Godot 4.7.2 using the
Compatibility renderer. It includes playable local container/heavy-loader voyages
and authenticated dedicated-server container gameplay.

**New cloud task? Read [CLOUD_HANDOFF.md](CLOUD_HANDOFF.md) and [AGENTS.md](AGENTS.md)
first.** Windows development is tested; cloud platform setup still needs validation.
The source includes Blender models, runtime assets, backend services and tests.
It excludes generated builds, engine downloads, live credentials and player saves.

## Open, run and check

From this `ShippingLanes` folder, use PowerShell 7.4 or later:

```powershell
# Open the editor. F5 runs the project's Main scene.
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Editor

# Run the project directly. Close the window when finished.
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Run

# Import and start headlessly, waiting for both checks to finish.
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Check
```

The launcher verifies the pinned engine and uses writable local editor and
save locations. It can work with the Godot editor closed. Check mode exits
automatically; ordinary Editor and Run modes stay open until closed. See
[ENVIRONMENT.md](ENVIRONMENT.md) for the exact engine, installation source,
isolated save paths, logs, measured hardware and current platform limits.

Successful startup prints `Shipping Lanes: Main scene loaded successfully.`
The project entry point is `res://features/main/main.tscn`. The development menu exposes the implemented playtests; the friends build uses
Servers, Settings and Quit. See PROGRESS.md for the current implementation.

## Feature layout

```text
ShippingLanes/
  project.godot
  features/
    main/       Main scene and application entry script
    world/      World scene; future world presentation belongs here
    ui/         Startup interface scene
    ships/      Starter model, wrapper, manifest and inspection scene
  art_sources/  Preserved Blender sources, excluded from Godot auto-import
  tools/        Local engine launcher
  *.md          Scope, architecture, decisions, progress and references
```

Keep a feature's scenes, scripts and resources together. Add further feature
folders when their roadmap tasks begin; reusable shared code should have an
actual second consumer before becoming a shared framework. Use snake_case
filenames and descriptive node names. Track GDScript `.uid` sidecars so resource
identities survive moves. Asset scale, rigging and import conventions are Step 07.

The original supplied Blender ship remains preserved outside the project, with
a tracked source copy and explicit GLB export. See [ASSET_REFERENCES.md](ASSET_REFERENCES.md).
The workspace's `sources/` and attached reference documents are read-only.

## Scope and progress

- [GAME_SPEC.md](GAME_SPEC.md): concise product contract and first playable goal.
- [ONLINE_ARCHITECTURE.md](ONLINE_ARCHITECTURE.md): selected online design, with
  implementation proofs still pending.
- [DECISIONS.md](DECISIONS.md) and [PROGRESS.md](PROGRESS.md): decisions and checked
  milestones.
- [FEATURE_INVENTORY.md](FEATURE_INVENTORY.md), [UNCERTAINTIES.md](UNCERTAINTIES.md)
  and [BUILD_DEPENDENCIES.md](BUILD_DEPENDENCIES.md): coverage and decision gates.

Step 06 adds tested Windows debug and release exports. See [EXPORT.md](EXPORT.md)
for exact build/run commands and the sandbox's writable-data requirement.
Step 07 prepares the starter model and a static inspection scene. See
[ASSET_CONVENTIONS.md](ASSET_CONVENTIONS.md) for source/export/check/preview commands.
Step 08 adds **Controls & settings** to the startup screen, with editable keys
and persistent preferences. See [CONTROLS.md](CONTROLS.md).
Next is Step 09, application flow and focus.

[ART_DIRECTION.md](ART_DIRECTION.md) records Andy's coastal photo palette:
muted blue-green water, warm gray-brown rocks, pale foam and regional variation.
Reusable material swatches are ready for later map work; the current world is empty.

## Local version control and recovery

The Git repository is rooted here, not in the enclosing ChatGPT project.
Generated `.godot/` data, `exports/`, local environment files and `secrets/` are
ignored. Keep source, scene files, `.uid` sidecars and future non-secret export
presets tracked. The engine copy, runtime data and checkpoint archives live in
the sibling `../output/` directory, outside this repository.

Git history preserves the previous setup as `step-04-engine-baseline` and this
foundation as `step-05-project-skeleton`. These local checkpoints use the
automation identity `Codex <codex@localhost>` for their commits; user-wide Git
identity settings are unchanged. There is no configured remote or cloud backup.

With Git available, inspect `git status` and `git log --oneline --decorate` from
this folder. To recover without replacing current work, use `git archive` to
export either tag to a new archive, then extract it into a separate folder.
A source-only ZIP checkpoint is also recorded in [PROGRESS.md](PROGRESS.md).
Both recovery methods require the engine setup described in ENVIRONMENT.md;
neither includes the external Blender source or development saves.

Git available on this machine at setup:
`C:/Users/andyv/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/git/cmd/git.exe`.
This is a local tooling path, not a bundled game dependency.

## Menu and session testing

The main menu now displays Container Ship Sim. Play opens a local test session;
Servers explains online availability, and Fleet remains disabled. The background
is reserved for later artwork. See [APPLICATION_FLOW.md](APPLICATION_FLOW.md)
for Continue, pause, focus handling and the repeatable `-Mode FlowCheck` command.

## Content foundation

[DEFINITIONS.md](DEFINITIONS.md) describes the four prototype definitions, stable
IDs, independent ship state and `-Mode CatalogCheck`. Main validates the catalog
on startup. These records do not yet create a playable ship, port or cargo job.

Geographic feasibility checks and their exported diagnostic route are documented
in [GEOGRAPHIC_CONTRACT.md](GEOGRAPHIC_CONTRACT.md). This prerequisite has no
visible gameplay change and requires no manual playtest.

Private storage dependency proof is complete with a cold-import workaround; see
[STORAGE_PROOF.md](STORAGE_PROOF.md). On a fresh restore, run tools/Godot.ps1 -Mode
Check before opening directly in Godot. Export distributions now require the
matching SQLite DLL alongside EXE and PCK. No gameplay saves exist yet.

Save/protocol record drafts and safe plain-data validation are documented in
[SAVE_PROTOCOL_CONTRACTS.md](SAVE_PROTOCOL_CONTRACTS.md). ContractsCheck exercises
representative and malformed records; it does not write game saves.

[UNITS_AND_TIME.md](UNITS_AND_TIME.md) records shared conversions and rounding.
UnitsCheck verifies math and navigation/payout fixture agreement; no playtest needed.

[STATE_OWNERSHIP.md](STATE_OWNERSHIP.md) explains the session-owned test state.
Play now includes a disposable container-load button with approval/rejection
feedback. SessionCheck verifies this path automatically, including Continue/reset.

[SIMULATION_LIFECYCLE.md](SIMULATION_LIFECYCLE.md) records timer ownership and pause/
Continue/cancel rules. Play includes a no-economy ten-second timer test; ClocksCheck
verifies it without requiring a manual playtest.

[DEVELOPMENT_CHECKS.md](DEVELOPMENT_CHECKS.md): run tools/CheckProject.ps1 for the
foundation checks or add -Full for 11 stages. Ctrl+F3 toggles the read-only developer
overlay; motion fields will connect in the handling prototype.

Step 16: [Boat handling prototype](HANDLING_PROTOTYPE.md). Launch it from **Boat Handling Test** in the main menu.

Step 17 updates the handling test: W/S adjust a retained throttle order; X orders zero. HUD separates command, engine output and speed.

Step 18: A/D rudder, Q/E lateral thrusters, gold turning markers and a solid practice quay are available in Boat Handling Test.

Step 19: [Orbit camera](CAMERA.md) adds RMB orbit, wheel zoom, C recenter and pier avoidance to Boat Handling Test.

Step 20: [Stylized water](WATER_PRESENTATION.md) adds bold-blue animated patterns, gentle visual bobbing and saved water quality settings. A muted coastal palette is ready for later regions.

Step 21: [Hull and shore collision](COLLISION.md) adds coast/rock blockouts, thin/angled piers and guarded turning to Boat Handling Test.

Step 22: [Handling feedback baseline](HANDLING_FEEDBACK.md) adds engine/thruster sounds, H horn and clearer instruments. Implementation is verified; Andy's short playtest remains pending before controller lock.

## Private multiplayer test — Step 40

Choose LOCAL MULTIPLAYER TEST on the main menu. In the host window, choose
Host / resume starter (or heavy), then Copy invitation. In a second window,
choose Join invitation, paste it and confirm trust. Reconnect restores the same
ship while the client window retains its credential. Host worlds persist across
host restarts; closing a client window currently loses its reconnect credential.
This remains two players on one computer. See PRIVATE_SESSION_IDENTITY.md.
