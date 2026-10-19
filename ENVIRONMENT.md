# Engine and hardware baseline

October 18, 2026 · Step 04 · Task ID: `engine-and-hardware-baseline`

## Selected development baseline

| Setting | Recorded value |
| --- | --- |
| Engine | Godot `4.7.2.stable.steam.ed1daf0bf`, x64; commit `ed1daf0bf001b61586d9930840f2f1394092c079` |
| Language | Typed GDScript; native editor build, no .NET requirement for game code |
| Renderer / driver | Compatibility / OpenGL (`gl_compatibility` / `opengl3`) |
| Platform | Windows x64; current test OS reports 26H2, build 26300.9711 |
| CPU | Intel Core i7-12700KF; 12 physical cores, 20 logical processors |
| RAM | 15.84 GiB OS-visible physical RAM; exact installed DIMM capacity was unavailable |
| GPU | NVIDIA GeForce RTX 3070; 8192 MiB dedicated VRAM; driver 617.14 |
| Tool shell | PowerShell 7.6.5 tested; launcher requires PowerShell 7.4+ |
| Desktop export target | Windows x86_64. Windows 10/11 compatibility is a provisional distribution target, not a tested support matrix. |

`engine-baseline.json` pins the exact executable SHA-256 and source. The launcher
rejects a different binary; Steam updates do not silently upgrade the cached
development engine. Hardware evidence is in `hardware-baseline.json`. The OS
registry's ProductName contains “Windows 10 Home”; it can be a legacy value, so
the measured NT build is recorded without claiming a marketing name.

Compatibility is selected for the current original low-poly art and simple
water/lighting needs, and for a broad potential Windows hardware range. The
RTX 3070 successfully initializes it. A stronger renderer is not required by the
current feature contract. Revisit with a measured water/port scene if required
effects justify a change; do not promise final visual quality or lower-end support
from a setup screen. Godot's [renderer comparison](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html)
describes the tradeoffs; these project choices still need representative testing.

## Working editor and user-data paths

Installed source, left unchanged:
`C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`.

`tools/Godot.ps1` uses a hash-identical local copy at
`../output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe`. It creates a portable
`_sc_` marker, so editor settings/cache live beside that copy in `editor_data/`.
It also sets **APPDATA in the Godot child process only** to
`../output/tools/godot-4.7.2/user_data/`, with the project's data under
`Godot/app_userdata/Shipping Lanes/`. User/system environment variables, the
installed Steam editor, and other projects are not reconfigured.

The Step 03 profiler error persisted when only an ordinary user-data folder was
created. A child-process APPDATA override, a precreated project data directory,
and portable editor settings resolved it: import, settings storage and user-data
write/read now succeed. This is the verified direct-file workflow; launching the
Steam source executable directly may still hit the sandbox's original path limits.
Our checks use the launcher consistently. [Godot data paths](https://docs.godotengine.org/en/4.7/tutorials/io/data_paths.html)
document portable mode; the [Windows implementation](https://raw.githubusercontent.com/godotengine/godot/4.7/platform/windows/os_windows.cpp)
shows its APPDATA-based user-data path.

Future development saves created through this launcher use that isolated path.
They are not automatically migrated from any existing normal user profile.
Do not delete or replace `user_data/` when refreshing editor binaries. A launcher
restore needs the cached binary or the exact recorded source build; the large
engine, generated settings and runtime data are excluded from project checkpoints.

## Run and check

From the workspace folder containing `ShippingLanes`, use PowerShell 7:

```powershell
# Open the project editor; press F5 there to run it.
pwsh -NoProfile -File .\ShippingLanes\tools\Godot.ps1 -Mode Editor

# Run the current Main scene directly.
pwsh -NoProfile -File .\ShippingLanes\tools\Godot.ps1 -Mode Run

# Wait for complete editor import and a bounded headless startup.
pwsh -NoProfile -File .\ShippingLanes\tools\Godot.ps1 -Mode Check
```

On a restored project, the launcher recreates its local engine copy from the
recorded installed source if necessary. Supply `-EngineSource <path>` when the
same exact executable is elsewhere. A different executable requires a deliberate
baseline update and validation, not bypassing the hash check. No download or
installation is performed by the launcher.

Logs are written under `.godot/environment-*.log`; engine errors fail the check
even if the engine returns exit code 0. The script waits for process completion
and uses structured arguments, including paths with spaces. It does not automate
the editor UI. The current Main window displays “Shipping Lanes” and “Project
ready”; `.godot/environment-startup.log` includes “Shipping Lanes: Main scene
loaded successfully.” Step 05 replaces the earlier setup scene; historical
measurements below describe that earlier scene.

## Actual checks and measured limits

| Check | Result / evidence |
| --- | --- |
| Hash/version | Local executable matches the installed source and pinned SHA-256. Engine reports the recorded 4.7.2 Steam stable build. |
| Headless full editor import | Exit 0; filesystem scan and editor layout finished; no script/resource or environment errors using isolated paths. `.godot/environment-import.log`. |
| Headless setup | Exit 0, expected success message, no engine errors. `.godot/environment-startup.log`. |
| Native Windows editor startup | Exit 0 with Compatibility/OpenGL on RTX 3070; no logged errors. `.godot/step-04-editor-graphics.log`. |
| Native graphics/setup capture | Windows display, actual `gl_compatibility` / `opengl3`, RTX 3070, exit 0. Capture visually inspected; centered setup text was readable. |
| User-data write/read | Passed inside isolated project `user://`; temporary probe removed. |
| Frame pacing, setup UI only | 60 warmup + 180 measured frames; cap 60 FPS, VSync disabled. Mean 16.666 ms, p95 16.679 ms, approximately 60.00 paced FPS. This is not uncapped throughput or GPU timing. |
| Actual render dimensions | Requested 1920×1080 window; Windows constrained drawable height to 1061. Captured viewport is **1920×1061**, not a claimed full 1080p benchmark. |
| Memory metric | Godot MEMORY_STATIC approximately 47.3 MiB; this excludes other process/GPU allocations and is not total working set. |

Raw measurement: `../output/checks/step-04-graphics.json`; viewport capture:
`../output/checks/step-04-setup.png`. The temporary probe is outside the game
project. No 3D ship/world, export, physics, public services or player-capacity
benchmark ran here. Hardware alone does not prove a 100-player dedicated server.

## Provisional performance targets

- Client: aim for 60 FPS at 1920×1080 on this development PC, with steady-state
  p95 frame intervals at most 20 ms and no routine hitches over 50 ms. The empty
  UI meets the pacing target at its actual dimensions; full 1080p and representative
  ship/port/water load remain unverified.
- Initial client resource planning: aim below 2 GiB process working set in the
  first representative port scene. This is a provisional budget, not measured
  current total memory or a minimum machine specification.
- Simulation: start with a 60 Hz fixed-physics target; aim below 8 ms server
  simulation time per tick to leave headroom. Reassess in the handling and early
  dedicated-load experiments. Do not set launch player capacity from this budget.
- Measure again at handling checkpoint 24, dedicated experiment 32, first voyage
  gate 57, world performance 98 and release soak 124. Record test scene, real
  resolution, caps, graphics settings, process/GPU memory and contention each time.

No minimum hardware promise is set yet. Test lower-end machines and the actual
Windows distribution targets before release; Godot's own [system requirements](https://docs.godotengine.org/en/4.7/about/system_requirements.html)
are an engine baseline, not this game's proven requirements.

## Windows export workflow — completed at Step 06

Matching Windows x86_64 templates are pinned in `export-templates.json` and
staged in the writable portable template directory. `tools/Godot.ps1` now
supports `-Mode Export` and `-Mode RunExport`, with `-Configuration Debug` or
`Release`. See `EXPORT.md` for complete commands, output locations and evidence.

Both standalone builds launch cleanly using writable child APPDATA. A separate
copy of the release EXE/PCK also passed outside the project. An inherited
Windows APPDATA launch reached Main but could not write shader cache under the
sandbox; normal-profile clean-machine behavior remains unverified. Use the
saved launcher for the verified local workflow.

Step 07 subsequently prepares the starter model and static inspection scene.
Next original task: Step 08, input and settings. The gameplay world is empty;
the coastal palette is prepared for later map implementation.
