# Rebuild plan — November 11, 2026

Status: **proposal, waiting for Andy's approval.** No game code, workflow or save
changed in this pass. Requested in issue #34.

## How this audit was done

By reading the docs and the code only. **Nothing was run.** This runner has no
Godot, and it refused Python and a deeper git history fetch. Every finding below
that is not marked "confirmed by Andy" is a reading of the source, not a test result.

## 1. Audit

### Why the ship won't move (most likely cause)

Not reproduced, but the code shows a clear input bug in three test scenes:

- `PlayerControls.set_menu_open()` (`features/input/player_controls.gd:84`) sets
  `wait_for_release = true` on every call, even when nothing changed.
- `oil_port_test.gd:151` and `bulk_port_test.gd:136` call it **every frame**.
- While any key is held, `PlayerControls._process` (line 112) never clears that
  flag, so `input_allowed()` stays false.
- `ShipHelm._physics_process` (`features/ships/ship_helm.gd:30`) then calls
  `zero_throttle()` on every tick.

Result: holding the throttle key gives at most one tick of throttle (under 1%),
then it is reset to zero. Steering and thrusters are blocked the same way.

Scenes affected: the oil / refinery / **cargo-fuel** fixture (Step 79, the scene
launched by `tools/oil_market_fixture.py --cargo-fuel`), **Bulk Port Test** and
**Gas Port Test**. Boat Handling Test and Port Test do not make this per-frame call.

Why it was never caught: the probes for these scenes move the ship by code. None
of them presses a key, so the keyboard path in these scenes has never been tested.

Other things that also stop the ship, to rule out when reproducing:

| Cause | Where | What Andy would see |
| --- | --- | --- |
| Price panel open counts as a menu, so the helm is off until it is closed | `oil_port_test.gd:151` | Panel on screen at start |
| Failed resume turns the ship's physics off for the session | `oil_port_test.gd:89` | "Voyage unavailable; reopen the fixture." |
| A save with an empty tank restores empty; an empty tank refuses throttle | `oil_port_test.gd:96`, `local_world_save.gd:228`, `handling_ship.gd:63` | "EMPTY" in the fuel readout |
| Save could not open, so the sim is paused | `handling_test.gd:126` | "SIM PAUSED" plus a save message |
| A script edited in Steps 83–88 fails to parse | `heavy_transport_test.gd`, `heavy_lifter.gd`, `cargo_manifest.gd` | Errors in the Godot output panel |

`cargo_manifest.gd` matters most in that last row: every ship loads it
(`handling_ship.gd:47`), so a parse error there would break every scene. I read it
and `bulk_rules.gd` and saw no error, but reading is not a parse.

**Andy: which menu entry or command did you use for the "fuel test"?** That
decides which row is the real one.

### What is playable today

| Group | State |
| --- | --- |
| Boat handling, camera, water, collision (Steps 16–28) | **Confirmed by Andy** on Windows, October 19. |
| Port Test: dock, take a container job, load, sail, deliver, get paid, autosave; heavy-lifter delivery (Steps 43–56) | **Hand-played by Andy** on Windows, October 25–26 (cargo loading, docking, a heavy delivery are recorded). Free refuel and repair, test wallet. |
| Online starter container ship: sign-in, ports, cargo, refuel, damage, recovery, saves (Steps 57–61) | Passed automated Windows Release runs. Andy's hands-on online feedback is still recorded as pending. Needs the local server stack; internet hosting unresolved. |
| Repairs, ship shop, fleet, resale, economy gate, bulk, gas, oil market, refinery, cargo fuel, heavy jobs (Steps 62–82) | Linux headless tests only, mostly against test doubles. Never run on Windows, never hand-played. Bulk, gas and cargo fuel likely cannot be sailed at all (bug above). |
| Heavy variants, cargo matrix, content rehearsal, cargo balance, world layout (Steps 83–88; 87 skipped; no Step 89 entry exists) | **Nothing ran.** Not parsed, not imported, tests not executed. `world_layout.json` is loaded by nothing. Three `.gd.uid` files were typed by hand. |

### The bigger problem

- **There is no game, only test scenes.** The menu is a list of fixtures. PLAY
  opens a "Local test session" page with test buttons, not a ship. Oil and cargo
  fuel need a Python launcher and environment variables.
- Each cargo family is its own fixture with its own save file and wallet. Nothing
  joins them into one world, one wallet and one save.
- Most effort went into online durability (accounts, PostgreSQL, crash recovery)
  for features nobody has played yet.
- Process weight: 121 root documents (16,550 lines), a 4,870-line PROGRESS.md,
  64 probe and check scripts, a 142-step roadmap. The checks that exist do not press keys.
- Step 83 recorded "do not start the next step until these checks pass". Four
  more steps (84, 85, 86, 88) were then built on top without them.

## 2. Goals: what "complete" means

**Version 1.0 = a single-player game Andy can install, play for a couple of
hours and enjoy.** Online comes after, as its own project.

This is an explicit change to GAME_SPEC.md, which lists online play in version 1.
It needs Andy's yes.

| In 1.0 | Deferred (code stays, frozen) | Still excluded |
| --- | --- | --- |
| One PLAY button: New Game, Continue, Restart Progress, one save | Online accounts, public servers, friends client, hosting | Player trades, gifts, transfers |
| Current handling, docking, gauges, single condition meter | LAN / player-hosted sessions | Machinery wear |
| One small region, 4–5 ports (from the Brindle Reach layout) | Gas, oil trading, refinery, cargo fuel | Hidden shallows |
| Container jobs, then bulk jobs as the step up | Globe map, curvature, circumnavigation, Panama | Expiring cargo offers |
| Paid fuel, paid repair, sinking with a recovery fee | Ship names, colours, flags | Real-money anything |
| Buy, switch and sell 3–4 ships | Docking cutscene, turn roll, weather | |
| Heavy-lifter jobs (already hand-played in Port Test) | Ro-Ro, rockets, walking | |
| Minimap with destination, settings, basic sound, Windows build | | |

## 3. New build approach

Rules:

1. **One game scene.** Features go into the real game, not a new fixture. Existing
   fixtures move behind a developer menu.
2. **A milestone is done when Andy has played it on Windows and said so.** Not before.
3. **Nothing merges unverified.** If the checks cannot run, the PR waits. No more
   "draft, unverified" merges.
4. **Reuse what Andy already approved** (handling, Port Test loop, docking, saves).
   Do not rewrite it.
5. **Less paper.** This file plus short PROGRESS.md entries. No new document per
   feature. The 142-step roadmap becomes reference only.

Milestones — each ends with a Windows build and a short checklist for Andy:

| # | Milestone | Andy can… |
| --- | --- | --- |
| M0 | **Stabilise** (the fix-first list below) | Open every menu entry and sail in it. |
| M1 | **One real voyage** | Press PLAY, take a container job at Brindle Quay, sail, deliver at Slatewater, get paid into a real wallet, quit, Continue. |
| M2 | **Costs and risk** | Pay for fuel and repairs, run dry, crash, sink and pay recovery, Restart Progress. |
| M3 | **Progression** | Earn enough to buy a second ship, switch, sell, and take bulk and heavy jobs that pay more. |
| M4 | **A world worth sailing** | Sail between 4–5 ports with coastline, a minimap and sensible trip times. |
| M5 | **Finish** | Play two hours from a fresh install with no developer help: hints, settings, sound, art pass, packaged build. |

Online returns after M5, starting from the frozen Step 57–61 code.

### How each milestone gets verified

1. **Automatic, every PR.** Godot 4.7.2 headless on the CI runner: import the
   project, parse every script (`tools/check_scripts.gd`), run a short smoke set
   and the Python unit tests.
2. **One scripted playthrough per milestone** that sends real key presses through
   `PlayerControls`, so an input bug like today's fails the build.
3. **Andy's Windows playtest** against a 5–10 line checklist written in the PR.

**Flagged, not done — needs Andy:** step 1 requires a change under
`.github/workflows`, which I am not allowed to edit.

- Add a step that downloads the official Godot 4.7.2 Linux build (same commit
  `ed1daf0bf`), checks its SHA-512 and puts it on the path. PROGRESS.md (November 1)
  records this exact build importing the project and running checks on Linux, and
  the Linux SQLite libraries are already in `addons/godot-sqlite/bin`.
- Allow the Claude action to run `godot` and `python3`. Both were refused in every
  run since Step 83; that is the direct reason those steps are unverified.
- Later (M1): have CI export a Windows zip as a build artifact, so Andy downloads
  and runs it instead of opening the editor. Needs the 4.7.2 export templates.

Known limit: Linux headless cannot judge feel or visuals, and PROGRESS.md records
three probes (collision, composition, ports) that already fail or are unclean on
Linux. Those need a decision in M0: fix, or mark Windows-only.

## 4. Fix-first list

Nothing new until these are done.

1. **The movement bug.** Reproduce on Windows with Andy's exact steps. Make
   `set_menu_open` only re-arm when the value changes (or stop calling it per
   frame). Add a test that holds the throttle key in each sailing scene and
   checks the ship gains speed.
2. **Get Godot and Python running in CI** (the workflow change above). Until
   then every fix is another guess.
3. **Import and parse the whole project, then run everything that has not run
   since Step 82.** Fix what is red. Expect trouble in the Step 83–88 files and
   the three hand-written `.gd.uid` files. Remove "UNVERIFIED" from a step only
   when its checks pass.
4. **No silent dead ends.** Whenever a scene disables the ship (paused, empty
   tank, failed save, failed resume, panel open), say why on screen and how to
   get out.
5. **Freeze the roadmap.** No Step 89. Park online work. Keep Steps 62–88 code
   but treat it as untrusted until item 3 passes.

## Questions for Andy

1. Which "fuel test" did you run (menu entry or command)?
2. Is single-player 1.0 with online later the right goal?
3. Is the in/deferred table right? In particular: bulk and heavy lifter in,
   gas and oil out for now.
4. Will you make the workflow change, or allow it to be made, so checks can run?
