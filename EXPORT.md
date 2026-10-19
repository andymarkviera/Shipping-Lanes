# Windows export workflow

Step 06 — October 18, 2026. Windows x86_64 debug and release builds are available.
They contain the empty Main scene, World and startup UI. This is a development
smoke build, not a gameplay release.

## Commands

From the `ShippingLanes` project folder, using PowerShell 7.4+:

```powershell
# Import and verify project startup.
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Import
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Check

# Stage matching templates, import, and export each configuration.
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Export -Configuration Debug
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Export -Configuration Release

# Launch the actual exported executable, without the editor.
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode RunExport -Configuration Release

# Bounded smoke check; omit QuitAfter for ordinary use.
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode RunExport -Configuration Release -QuitAfter 30
```

Outputs are `exports/windows-x86_64/debug/` and
`exports/windows-x86_64/release/`, each containing `ShippingLanes.exe` and
`ShippingLanes.pck`. Keep these two files together. Generated exports and logs
are ignored by Git; `export_presets.cfg` and template hashes are tracked.

`export-templates.json` pins the installed 4.7.2 template files by SHA-256.
Export stages verified copies into the portable editor's
`../output/tools/godot-4.7.2/editor_data/export_templates/4.7.2.stable/`.
The Steam installation remains unchanged. If the source moved, pass
`-TemplateSource <directory>` containing the exact pinned files. A different
build requires deliberate pin updates and validation. The engine source can
likewise be supplied with `-EngineSource`; see `ENVIRONMENT.md`.

The preset explicitly exports Main, default preferences and their dependencies.
Step 08 added the script-loaded preferences Resource after a standalone test
caught its omission from the original Main-only selection. Future dynamically loaded
assets must be explicitly included or the resource selection revised. The
unused coastal material swatches stay in source until a scene uses them.
Scripts compile to bytecode; PCK encryption, signing, console wrappers and
executable icon/metadata customization are disabled for this smoke stage.
No certificate, credential or signing service is needed.

The export operation uses Godot's `--headless --export-debug` or
`--headless --export-release` with preset `Windows Desktop`. RunExport executes
the built EXE from its own directory without project-path overrides and does
not require an editor binary. Both commands wait for process completion and
fail on nonzero exit or engine errors. Logs are in `.godot/export-*.log`.

## Verified behavior and limits

- Both exports completed and both built executables opened the startup scene
  with Compatibility/OpenGL on the RTX 3070, exit 0 and no engine/script errors
  through the launcher. Templates report `4.7.2.stable.official.ed1daf0bf`,
  matching the pinned Steam editor's version and source commit.
- A copy of only the release EXE and PCK ran from
  `../output/smoke/step-06 standalone/`, outside the project. Its native
  1152×648 frame was captured and visually checked. Evidence:
  `../output/checks/step-06-isolated.log` and `step-06-isolated00000009.png`.
- The launcher sets child-only APPDATA to the writable development data path
  described in ENVIRONMENT.md. The separate copied-build check used its own
  writable `appdata/` directory. No user-wide environment setting changed.
- An inherited Windows APPDATA launch reached Main but logged a shader-cache
  write error under this sandbox. This is recorded in
  `../output/checks/step-06-standalone.log`. Normal-profile clean-machine
  behavior and installed-player save permissions remain unverified; use
  RunExport for the verified local workflow.
- No installer, signing, lower-end hardware support, other operating systems,
  gameplay performance or multiplayer capacity was validated here.

References: [Godot Windows export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html),
[command-line export and capture](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html),
[Windows export options](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformwindows.html).

Step 09 also explicitly includes `features/main/test_session.gd`, loaded by Main.
The release was rebuilt and its native startup verified after this addition.

Step 10 explicitly exports the prototype catalog scripts/records and the starter
ship scene referenced by path. Catalog validation runs at exported startup. Typed
Array[String] reference fields passed release validation after packed-string
fields were observed empty in the first release attempt.

The geographic probe is explicitly packaged. Run it with RunExport -Headless
-GeographyProbe (application user argument); the release template does not permit
--scene overrides. Normal RunExport remains the main menu startup path.

SQLite packaging: keep the entire export folder, including the selected
libgdsqlite.windows.template_debug.x86_64.dll or template_release DLL. The launcher
verifies its hash. Licenses are packaged in the PCK. STORAGE_PROOF.md records
successful tests in Debug and Release and the fresh-import pre-registration fix.

Step 11 packages plain contract fixtures and supports RunExport -Headless
-ContractsProbe. Editor and release report CONTRACT_CHECK_PASS (66 checks).

Step 12 includes the units probe; RunExport -Headless -UnitsProbe passes 50 checks.

Step 13 packages the session authority and probe; RunExport -Headless -SessionProbe
passes 21 checks including the real menu button signal and response display.

Step 14 adds ClocksProbe: RunExport -Headless -ClocksProbe passes 22 checks.
