# Shipping Lanes

A Windows shipping game built with typed GDScript and Godot 4.7.2, using the
Compatibility renderer. The project currently opens an empty Main scene with
separate World and UI children and a readable “Shipping Lanes / Project ready”
screen. The starter ship is imported in a separate inspection scene; gameplay
has not started.

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
The project entry point is `res://features/main/main.tscn`. The World child is
an empty Node3D; the UI child is a CanvasLayer containing the startup screen.

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
