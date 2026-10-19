# Private storage dependency proof

Completed October 19, 2026. The private-world architecture retains SQLite, now
verified through godot-sqlite v4.9 on pinned Godot 4.7.2 Windows x64. Runtime query
reports SQLite 3.51.0. This adds a dependency and disposable probes only, not game
saves, accounts, wallet, cargo persistence, autosaving or a public storage adapter.

## Pin, license and build

sqlite-dependency.json records the official release URL, archive SHA-256, source
commit, godot-cpp submodule commit, and hashes of the installed DLLs/descriptor/
license. The two Windows x64 DLLs are unchanged official release artifacts.
The descriptor is restricted to Windows x64. No editor plugin script is needed.
The upstream MIT license and godot-cpp MIT notice are retained and exported.
SQLite itself is public domain. These are vendored binaries, not locally rebuilt
or reproducible-build attestations. Source rebuild needs the pinned recursive
repository/submodule, Python, SCons and a compatible C++ compiler (MSVC or MinGW
on Windows), with separate template_debug/template_release x86_64 builds. No
compiler installation or engine rebuild was required for these artifacts.

Primary references:
- https://github.com/2shady4u/godot-sqlite/tree/v4.9
- https://github.com/2shady4u/godot-sqlite/releases/tag/v4.9
- https://www.sqlite.org/backup.html
- https://www.sqlite.org/copyright.html

## Cold-import issue and supported launch path

First scan-time discovery of the extension reproducibly exited with access
violation -1073741819 at editor shutdown, including a minimal fresh project.
Subsequent imports and runtime executions passed. A fresh project with the
extension registered before import exited cleanly. Godot.ps1 now verifies the
pinned files and adds this extension to .godot/extension_list.cfg before launching,
preserving other entries. Use the launcher for a fresh restore/cache reset rather
than relying on direct editor first discovery. This is a tested initialization
workaround; the native crash's underlying cause is not claimed fixed upstream.
Normal launch after registration and native Windows release startup pass.

## Executed checks

Run from ShippingLanes (import first on a fresh restore):

```powershell
./tools/Godot.ps1 -Mode Check
./tools/CheckStorage.ps1 -Runtime Editor
./tools/Godot.ps1 -Mode Export -Configuration Debug
./tools/CheckStorage.ps1 -Runtime Debug
./tools/Godot.ps1 -Mode Export -Configuration Release
./tools/CheckStorage.ps1 -Runtime Release
```

All three runtimes passed the five-phase fixture:
- Bound quoted text round-trips; two-row transaction rolls back together and
  commits together under WAL with synchronous=FULL.
- ALTER TABLE plus user_version migration rolls back schema and version, then
  commits both while preserving existing values.
- Live connection backup_to and restore_from preserve the committed records and
  schema. This uses the SQLite backup API, not copying an open database file.
- An owned child process is forcibly killed after an uncommitted two-row update
  and 1 MiB payload with a small cache. Reopen retains the previous committed pair
  and discards the uncommitted schema/payload.
- A second child is killed after COMMIT but before close. Reopen retains the new
  complete pair. Integrity checks and schema revision checks pass.

Each run uses a GUID directory under output/storage-checks and a separate APPDATA;
no regular preferences or saves are opened. Only the child PID created by the
harness is killed. Ready markers establish the exact pre/post-commit boundary.
Logs and disposable databases remain as evidence outside source control.

Evidence directories: Editor-802394e11b104be6ab84f879390c688d,
Debug-e669ef94d95349809d87994c261cdb40,
Release-f84ef0fa85f940958f449af27bcf026e.
Cold import reproduction: output/storage-clean-import-c387c0d33af2415e812b2f824ed75fea.
Pre-registration success: output/storage-preloaded-import-1d4c651885614add9cfc253850cd92cb.

## Boundaries

Forced process termination is not a machine power-loss test. This does not prove
hardware durability, concurrent-writer behavior, disk-full handling, interrupted
backup/restore, production recovery policy, Linux hosting, clean-machine Windows
runtime dependencies, or public PostgreSQL adapters. Those remain later gates.
Game transaction authority/idempotency and save contracts are still Step 11+.
Keep the complete export folder: EXE, PCK and the matching SQLite DLL. RunExport
verifies the exported DLL hash before launch. The project checkpoint now includes
vendored native dependencies and notices but no test databases or engine builds.
