# Rebuild plan — November 11, 2026

Status: **approved by Andy on November 11, 2026** (relayed on PR #35). This file is
now the plan every agent follows. It replaces the numbered step roadmap. Requested
in issue #34. No game code, workflow or save has changed yet.

## How this audit was done

By reading the docs and the code only. **Nothing was run.** This runner has no
Godot, and it refused Python and a deeper git history fetch. Every finding below
that is not marked "confirmed by Andy" is a reading of the source, not a test result.

## Andy's answers (November 11, 2026)

| Question | Answer | Effect on this plan |
| --- | --- | --- |
| Which "fuel test"? | A menu entry he remembers as "fuel test". He does not know the exact command. | No menu entry has that name. See "Which scene Andy was in" below. The movement diagnosis is now less certain. |
| Is single-player 1.0 the goal? | Yes. 1.0 is a polished single-player first draft. Online comes later. | Section 2 is confirmed. It overrides GAME_SPEC.md, which lists online play in version 1. |
| In / on-hold split? | Bulk and heavy stay in. Andy liked gas and oil as of about Step 50. Keep their code intact and mark them "on hold until playtested", not removed. | Section 2 table changed. |
| CI? | Approved: Godot 4.7.2 and Python checks in GitHub Actions. Hark edits `.github/workflows`; agents do not. | Section 3 lists exactly what the job should run. |

## 1. Audit

### Which scene Andy was in

The home menu has no entry called "fuel test". Its entries are PLAY, BOAT HANDLING
TEST, HEAVY-LIFTER TEST, PORT TEST, BULK PORT TEST, GAS PORT TEST, LOCAL MULTIPLAYER
TEST, CONTINUE TEST SESSION, SERVERS, SETTINGS, LOCAL SAVES and EXIT
(`features/ui/application_menu.gd:59`).

The words "Fuel test tools" appear on screen in only two scenes: **Boat Handling
Test** and **Heavy-Lifter Test**. Both show a row of buttons: Empty tank (test),
Refuel (test), Pause sim, Dock (test) (`features/ships/fuel_test_controls.gd:13`).
So Andy was most likely in Boat Handling Test. This is a guess from the name.

That matters, because neither of those two scenes has the per-frame input bug
described below. If Andy was in Boat Handling Test, the likely causes are:

| Cause | Where | What Andy would see |
| --- | --- | --- |
| **Empty tank was saved.** "Empty tank (test)" sets fuel to zero. Boat Handling Test autosaves every 10 seconds and on leaving, and restores the tank on the next visit. An empty tank refuses throttle and thrusters. It stays empty across restarts until "Refuel (test)" is clicked. | `fuel_test_controls.gd:20`, `handling_test.gd:163`, `local_world_save.gd:228`, `handling_ship.gd:63` | "EMPTY" at the end of the fuel line |
| The save could not open, so the sim is paused for the session | `handling_test.gd:126` | "SIM PAUSED" plus a save message |
| "Pause sim" or "Dock (test)" was clicked | `fuel_test_controls.gd:28` | "SIM PAUSED" or "DOCKED" on the fuel line |

The empty-tank row is my leading guess for Andy's report. It is **not reproduced**.
The quick check on Windows: open Boat Handling Test, read the end of the fuel line,
click "Refuel (test)" and try the throttle.

### The input bug in the oil, bulk and gas scenes

Still stands as a separate bug, found by reading and not reproduced:

- `PlayerControls.set_menu_open()` (`features/input/player_controls.gd:84`) sets
  `wait_for_release = true` on every call, even when nothing changed.
- `oil_port_test.gd:151` and `bulk_port_test.gd:136` call it **every frame**.
- While any key is held, `PlayerControls._process` (line 112) never clears that
  flag, so `input_allowed()` stays false.
- `ShipHelm._physics_process` (`features/ships/ship_helm.gd:30`) then calls
  `zero_throttle()` on every tick.

Result: holding the throttle key gives at most one tick of throttle (under 1%),
then it is reset to zero. Steering and thrusters are blocked the same way.

Scenes affected: the oil / refinery / cargo-fuel fixture (Step 79, launched by
`tools/oil_market_fixture.py --cargo-fuel`, not from the menu), **Bulk Port Test**
and **Gas Port Test**. Boat Handling Test, Heavy-Lifter Test and Port Test do not
make this per-frame call.

Why it was never caught: the probes for these scenes move the ship by code. None
of them presses a key, so the keyboard path in these scenes has never been tested.

Other things that also stop the ship in those scenes:

| Cause | Where | What Andy would see |
| --- | --- | --- |
| Price panel open counts as a menu, so the helm is off until it is closed | `oil_port_test.gd:151` | Panel on screen at start |
| Failed resume turns the ship's physics off for the session | `oil_port_test.gd:89` | "Voyage unavailable; reopen the fixture." |
| A save with an empty tank restores empty | `oil_port_test.gd:96` | "EMPTY" in the fuel readout |
| A script edited in Steps 83–88 fails to parse | `heavy_transport_test.gd`, `heavy_lifter.gd`, `cargo_manifest.gd` | Errors in the Godot output panel |

`cargo_manifest.gd` matters most in that last row: every ship loads it
(`handling_ship.gd:47`), so a parse error there would break every scene, including
Boat Handling Test. I read it and `bulk_rules.gd` and saw no error, but reading is
not a parse. The CI job in section 3 settles this.

### What is playable today

| Group | State |
| --- | --- |
| Boat handling, camera, water, collision (Steps 16–28) | **Confirmed by Andy** on Windows, October 19. |
| Port Test: dock, take a container job, load, sail, deliver, get paid, autosave; heavy-lifter delivery (Steps 43–56) | **Hand-played by Andy** on Windows, October 25–26 (cargo loading, docking, a heavy delivery are recorded). Free refuel and repair, test wallet. |
| Online starter container ship: sign-in, ports, cargo, refuel, damage, recovery, saves (Steps 57–61) | Passed automated Windows Release runs. Andy's hands-on online feedback is still recorded as pending. Needs the local server stack; internet hosting unresolved. |
| Repairs, ship shop, fleet, resale, economy gate, bulk, gas, oil market, refinery, cargo fuel, heavy jobs (Steps 62–82) | Linux headless tests only, mostly against test doubles. Never run on Windows, never hand-played. Bulk, gas and cargo fuel likely cannot be sailed at all (input bug above). |
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

**Version 1.0 = a polished single-player first draft: a game Andy can install,
play for a couple of hours and enjoy.** Online comes after, as its own project.
Confirmed by Andy. This overrides GAME_SPEC.md, which lists online play in version 1.

| In 1.0 | On hold until playtested (code stays intact) | Deferred (code stays, frozen) | Still excluded |
| --- | --- | --- | --- |
| One PLAY button: New Game, Continue, Restart Progress, one save | Gas cargo (Gas Port Test) | Online accounts, public servers, friends client, hosting | Player trades, gifts, transfers |
| Current handling, docking, gauges, single condition meter | Oil trading | LAN / player-hosted sessions | Machinery wear |
| One small region, 4–5 ports (from the Brindle Reach layout) | Refinery | Globe map, curvature, circumnavigation, Panama | Hidden shallows |
| Container jobs, then bulk jobs as the step up | Cargo fuel | Ship names, colours, flags | Expiring cargo offers |
| Paid fuel, paid repair, sinking with a recovery fee | | Docking cutscene, turn roll, weather | Real-money anything |
| Buy, switch and sell 3–4 ships | | Ro-Ro, rockets, walking | |
| Heavy-lifter jobs (already hand-played in Port Test) | | | |
| Minimap with destination, settings, basic sound, Windows build | | | |

What "on hold until playtested" means for gas and oil:

- **Do not delete, stub out or rewrite their code, scenes, services or tests.**
  Andy liked gas and oil as of about Step 50.
- No new gas or oil features until Andy has played them and said what he wants.
- Their existing checks stay in CI so the code does not rot while it waits.
- M0 still fixes the movement bug in these scenes. They must be sailable for Andy
  to playtest them at all.
- After Andy's playtest he decides: into 1.0, after 1.0, or dropped. Until then
  nothing in the 1.0 game depends on them.

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
| — | **Simplify pass** (issue #45; no new features) | See a four-button menu and one small HUD. No test buttons or debug readouts unless F3 is pressed. |
| M2 | **Costs and risk** | Pay for fuel and repairs, run dry, crash, sink and pay recovery, Restart Progress. |
| M3 | **Progression** | Earn enough to buy a second ship, switch, sell, and take bulk and heavy jobs that pay more. |
| M4 | **A world worth sailing** | Sail between 4–5 ports with coastline, a minimap and sensible trip times. |
| M5 | **Finish** | Play two hours from a fresh install with no developer help: hints, settings, sound, art pass, packaged build. |
| — | **Aesthetics** (after M5; all 5 items written, waiting for Andy's playtest) | See the Wind Waker look described below. |

**Order (Andy, issue #45): M1 done → Simplify → M2 → M3 → M4 → M5 → Aesthetics.**

Online returns after M5, starting from the frozen Step 57–61 code.

**Aesthetics milestone (after M5, item 1 in progress).** Target: a Wind Waker look.
Toon shading with ink outlines, a flat-colour ocean with white swirl foam and wake,
puffy clouds and sky, chunky ships and ports, a playful HUD and UI. Items, one at
a time, in this order:

1. Water: flat-colour ocean, white swirl foam and wake.
2. Toon shader and ink outlines.
3. Sky and lighting: puffy clouds.
4. Ships and ports: chunky models.
5. HUD and UI: playful style.

**Aesthetics status (November 12, 2026):**

| # | Item | Status |
| --- | --- | --- |
| 1 | Water | Code written (issue #55), not run or seen by the agent. Waiting for the Checks run and Andy's look on Windows. |
| 2 | Toon shader and ink outlines | Code written (issue #57), not run or seen by the agent. Waiting for the Checks run and Andy's look on Windows. |
| 3 | Sky and lighting | Code written (issue #59). Checks and a software-rendered screenshot passed on the agent's Linux runner. Waiting for Andy's look on Windows. |
| 4 | Ships and ports | Code written (issue #61). Checks and software-rendered screenshots passed on the agent's Linux runner. Waiting for Andy's look on Windows. |
| 5 | HUD and UI | Code written (issue #63). Checks and software-rendered screenshots passed on the agent's Linux runner. Waiting for Andy's look on Windows. |

All five items are written. The milestone is not accepted until Andy has played
it on Windows (checklist in the item 5 pull request).

Item 1, what exists: the same ocean plane and wake nodes, restyled in place
(`features/water`). The ocean is a saturated blue-to-teal in three soft tone
bands, with separate white swirl strokes instead of a full foam net. The wake is
pure white with a hard toon edge, wider side crests and a new white trail behind
the stern. The tone bands are a drifting pattern, not real water depth: the game
has no seabed to measure. No gameplay, physics, save or settings change; the
three water quality tiers still work the same way.

Item 2, what exists: `features/toon`. `toon.gdshader` lights a surface in three
hard bands (shadow, mid, lit) and lifts colour saturation. `toon_outline.gdshader`
draws a dark ink line around each mesh (inverted hull) that keeps a steady
thickness on screen. `toon_look.gd` swaps the plain materials for these, keeping
each mesh's own colour or texture. The game applies it to the ports, the land,
the ship and its containers. The ocean, wake and labels are not touched. No
gameplay, physics, save or settings change.

Item 3, what exists: `features/sky`. `toon_sky.gdshader` draws the sky: deep blue
overhead fading to pale cyan at the horizon, flat white puffy clouds with a pale
blue underside (a big bank on the horizon, smaller ones higher up, drifting very
slowly) and a flat sun disc. `sky_look.gd` sets it up with a warm sun that casts
shadows, soft blue ambient light and a light haze that fades far land and water
into the horizon colour. The game scene calls it once. No ocean, ship or HUD
file changed. No gameplay, physics, save or settings change.

Item 4, what exists: `features/toon/chunky_look.gd`, called by the game scene only.
It builds the shapes in code; no model file was added or changed. Ships: a fat
rounded hull with a blunt bow, white rail and rust-red bottom, a big white
wheelhouse with a dark window band, a fat banded funnel, mast and hatch covers.
The container ship is red, the bulk carrier blue with hatches end to end, the
heavy lifter yellow with side walls and a bow tower; its lifting deck and load
keep their models. The old ship model is hidden, not removed. Ports: a pitched
red warehouse roof with blue doors, stacked bold containers, a domed fuel tank,
a crane boom over the berth, bollards, a striped harbour light and red and green
channel buoys. Every collider, anchor, berth and hull size is unchanged. No
gameplay, physics, save or settings change.

Item 5, what exists: `features/ui/playful_theme.gd`, one look built in code (no
image or font file). Navy panels with a thick cream rim and rounded corners,
chunky yellow buttons with a dark lower lip, bolder text with an ink outline,
matching sliders, lists, drop-downs and the Restart Progress question. The home
menu gets a drawn backdrop: sky, sun, drifting puffy clouds, sea and a small red
ship. Used by the home menu, Settings and the game's HUD (dock panel, job panel,
throttle bar, warning banner, minimap). The test scenes behind F3 keep their
plain panels. No text, button, layout rule, gameplay, save or settings change.

**M0 status: accepted by Andy** (Windows playtest; relayed in issue #43).

**M1 status (November 12, 2026): code written, not run by the agent. Waiting for
the Checks run and Andy's Windows playtest.** What exists:

- The home menu's first button opens the one real game scene,
  `features/game/game.tscn`. It says PLAY with no save and CONTINUE once a save
  exists. The old PLAY page is now LOCAL SAVE TEST.
- The game scene is the approved Port Test loop (`features/ports/port_test.gd`
  with `game_mode` on): same handling, docking, loading, delivery and autosave.
  The test heavy-loader switch is hidden.
- One save: `user://worlds/game/voyage.db`, separate from every test save.
- The wallet is the credit balance in that save. A delivery and its payment are
  written in one transaction. It is not the fixed-price test ledger in `world.db`.
- Scripted key-press playthrough: `tools/check_m1_voyage.gd` (see "Not in CI yet").

Left for later milestones, on purpose: fuel and repairs are still free and the
free rescue fuel is still there (M2); no Restart Progress or New Game over an
existing save (M2); only the six seeded container jobs, three each way, which do
not come back once delivered (M3/M4); no Windows zip artifact (needs Hark's
workflow edit). Test fixtures moved behind F3 in the Simplify pass below.

**Simplify pass status (November 12, 2026): code written, not run by the agent.
Waiting for the Checks run and Andy's Windows playtest.** Andy's direction:
"heavily simplify it and make it so it's actually playable and not filled with a
billion testing things and huds everywhere". What exists:

- Home menu: PLAY (it reads CONTINUE once a save exists), SETTINGS, QUIT. Nothing
  else. One button, not two, because New Game over a save is M2.
- One developer toggle: **F3**, off by default, off again at every launch
  (`features/developer/dev_mode.gd`). It shows the test-scene buttons (Local Save
  Test, Boat Handling, Heavy-Lifter, Port, Bulk, Gas, Local Multiplayer, Continue
  Test Session, Servers, Local Saves), the developer overlay (was Ctrl+F3), the
  test-save notice and the game's extra readouts. No test code was removed.
- In-game HUD: the top-right panel shows the current job, speed, fuel and money
  (hull too, only when damaged). The gauge panel and the old port/wallet line are
  developer-only in the game. Still on screen: the Dock / Main menu / services
  panel, the throttle bar and the minimap, because the game cannot be played
  without them.
- Test scenes keep their own HUDs. They can only be opened with F3 on.

**M2 status (November 12, 2026): code written, not run by the agent. Waiting for
the Checks run and Andy's Windows playtest.** In the game only; Port Test is
still free. What exists:

- Fuel costs 0.50 credits per litre and repairs 5.00 per 1% hull, paid from the
  wallet at a berth. REFUEL and REPAIR show the price and buy what the wallet can
  cover.
- Collisions above 2 m/s now damage the hull (the single condition meter).
- Out of fuel at sea: the banner offers "Call a tow to port". At 0% hull the ship
  sinks and is recovered after a few seconds, patched to 50%. Either way the ship
  goes to the current port's spawn point with at least a quarter tank and keeps
  its cargo. The fee is 200.00 credits, or the whole wallet if it holds less. The
  free test fuel is gone from the game.
- Home menu: RESTART PROGRESS appears when a save exists. It asks first, then
  erases the game save. PLAY then starts a new game.
- The save records money spent (snapshot version 3; older game saves still load).
- `tools/check_m1_voyage.gd` now also covers M2 in the same run.

Left for later, on purpose: no sinking animation; the six container jobs still
do not come back, so money is finite until M3/M4; prices are a first guess.

**M3 status (November 12, 2026): code written, not run by the agent. Waiting for
the Checks run and Andy's Windows playtest.** In the game only. What exists:

- A SHIPS button at a berth, next to CARGO, REFUEL and REPAIR. It lists three
  ships: Container ship (800.00), Bulk carrier (1,200.00), Heavy lifter (3,000.00).
  Buy one, switch to one you own, or sell one you are not sailing for half its
  price (two clicks). Data: `features/game/progression.gd`.
- Each ship keeps its own fuel and hull. Switching needs no job in hand and puts
  the new ship just off the quay.
- Bulk carrier: six bulk jobs, three each way, paying 900 / 1,200 / 1,500
  (containers pay 250 / 500 / 750). Accept at a berth, deliver at the other port.
- Heavy lifter: the six heavy jobs Andy played in Port Test, 700 / 850 / 1,000.
- The save records the ship, the fleet and the bulk jobs (snapshot version 4;
  older game saves still load).
- `tools/check_m1_voyage.gd` now also buys, switches, takes a bulk job and sells.

Left for later, on purpose: the bulk carrier uses the container ship's hull and
handling (no bulk model yet); bulk cargo loads at once and is not shown on deck;
the game's bulk jobs do not use the hold-by-hold rules of Bulk Port Test; jobs
still do not come back, so about 15,300 credits can be earned in total (M4);
prices are a first guess.

**M4 status (November 12, 2026): code written, not run by the agent. Waiting for
the Checks run and Andy's Windows playtest.** In the game only; Port Test keeps
its two ports. What exists:

- Four ports on the two shores of a strait: Brindle Quay and Slatewater Works
  where they were, Cinder Point to the north and Gannet Light (new) to the south.
  Names are from the Brindle Reach layout. Data: `features/game/progression.gd`.
- Coastline: two shores, the head of the strait and two islands, as solid blocks.
- Trip times at full speed: about 2.5 minutes (Brindle–Slatewater, 1.5 km),
  4 to 5 minutes to Cinder Point or Gannet Light (2.2 to 2.8 km), 8 minutes for
  Cinder Point–Gannet Light (4.8 km). Worked out from 10 m/s, not timed.
- Minimap: smaller, no text except port names. Land, ports, the ship and a
  dashed line to the job's destination.
- Money is no longer finite. Each port always has three container jobs; when one
  is delivered or abandoned, a new one takes its place, to the next port along.
  Bulk and heavy jobs can be taken again at once. No offer expires. Pay grows
  with distance: 250.00 to 800.00 per container, 900.00 to 4,800.00 for bulk.
- The save is snapshot version 5; older game saves still load.
- `tools/check_m1_voyage.gd` now also checks four ports and the replaced job.

Left for later, on purpose: land is flat blocks (art pass is M5 and Aesthetics);
the heavy lifter cannot dock at Cinder Point (its berth has no heavy service);
the sea has no edge to the south; pay and distances are a first guess.

**M5 status (November 12, 2026): code written, not run by the agent. Waiting for
the Checks run and Andy's Windows playtest.** Trimmed on Andy's instruction
(issue #53: simplify, no testing clutter, no extra HUDs). No new screen, panel or
file. What exists:

- Hints, in the game only, in the two panels already on screen. Until the first
  money is earned or spent, the left panel lists the helm keys as bound in
  Settings. With no job, the top-right panel says the next step, and says when
  a new ship is affordable. It warns below 25% fuel and below 50% hull.
- The home menu says in two lines what the game is and that it saves by itself.
- Sound: a chime when a delivery is paid and a thud on a collision, added to the
  engine, thruster and horn sounds. All follow the Settings volume.
- Settings: unchanged. Volume, camera, fullscreen, water quality and keys were
  already on the home menu. In the game, Esc saves and returns there.
- Packaged build: `tools/Godot.ps1 -Mode Export -Configuration Release` now also
  writes `exports/ShippingLanes-windows-release.zip` (exe, pck and DLLs only).
  Unzip anywhere and run `ShippingLanes.exe`.
- `tools/check_m1_voyage.gd` now also checks the first hints and the two sounds.

Left out, on purpose: the art pass (land stays flat blocks; the look belongs to
the Aesthetics milestone); no Settings button inside the game; no installer,
icon or code signing; the zip is not built in CI (needs Hark's workflow edit and
the 4.7.2 export templates); F3 developer mode is still in the packaged build.

### How each milestone gets verified

1. **Automatic, every PR.** The CI job below.
2. **One scripted playthrough per milestone** that sends real key presses through
   `PlayerControls`, so an input bug like the one above fails the build.
3. **Andy's Windows playtest** against a 5–10 line checklist written in the PR.

### CI job: exactly what to run

Approved by Andy. **Hark makes the `.github/workflows` edit. Agents do not touch
workflow files.**

None of these commands were run for this plan. They are taken from
`tools/Godot.ps1`, `tools/CheckProject.ps1` and the Linux runs recorded in
PROGRESS.md on November 1–2. Expect to adjust a line or two on the first run.

**Setup**

- Runner: `ubuntu-latest`, x86_64. Python 3.12.
- Godot: the official 4.7.2 stable Linux editor build. `godot --version` must
  print `4.7.2.stable.official.ed1daf0bf`. Any other version fails the job.
- Expected download (standard Godot release naming, not checked from here):
  `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`.
  Verify it against the `SHA512-SUMS.txt` of the same release and pin that hash in
  the workflow. The repository does not record the Linux hash.
- Python package: `pip install "psycopg[binary]==3.2.10"`. The
  `tools/public_handoff` tests import `services/public_authority/authority.py`,
  which imports psycopg. No database server is needed.
- Keep Godot's user data out of the home directory:

```bash
export XDG_DATA_HOME="$RUNNER_TEMP/xdg/data"
export XDG_CONFIG_HOME="$RUNNER_TEMP/xdg/config"
export XDG_CACHE_HOME="$RUNNER_TEMP/xdg/cache"
```

- The SQLite extension needs no download. Its Linux libraries are already in
  `addons/godot-sqlite/bin`.
- Allow the Claude action to run `godot` and `python3`. Both were refused in every
  run since Step 83. That is the direct reason those steps are unverified.

**Pass rule for every Godot command** (the same rule as `tools/Godot.ps1`): exit
code 0, **and** no output line that starts with `ERROR:` or `SCRIPT ERROR:`, **and**
finished inside 30 seconds. Give the import step 10 minutes instead. Run all
commands from the repository root. Save each command's output as a job artifact.

**Stage 1 — required: import, parse, boot**

```bash
godot --headless --path . --editor --import
godot --headless --path . --script res://tools/check_scripts.gd   # prints SCRIPT_CHECK_PASS (N scripts)
godot --headless --path . --quit-after 10
```

`check_scripts.gd` loads every `.gd` file under `features/` and `tools/`. This is
the step that would have caught a parse error in Steps 83–88.

**Stage 2 — required: Godot smoke set**

These are the checks PROGRESS.md records as passing on Linux on November 2.

```bash
godot --headless --path . --scene  res://tools/units_probe.tscn
godot --headless --path . --script res://tools/check_catalog.gd
godot --headless --path . --scene  res://tools/diagnostics_probe.tscn
godot --headless --path . --script res://tools/check_controls.gd
godot --headless --path . --script res://tools/check_flow.gd
godot --headless --path . --script res://tools/check_starter.gd
godot --headless --path . --scene  res://tools/contracts_probe.tscn
godot --headless --path . --scene  res://tools/geography_probe.tscn
godot --headless --path . --scene  res://tools/session_probe.tscn
godot --headless --path . --scene  res://tools/clocks_probe.tscn
godot --headless --path . --scene  res://tools/handling_probe.tscn
godot --headless --path . --scene  res://tools/camera_probe.tscn
godot --headless --path . --scene  res://tools/water_probe.tscn
godot --headless --path . --scene  res://tools/feedback_probe.tscn
godot --headless --path . --scene  res://tools/world_size_probe.tscn
godot --headless --path . --scene  res://tools/heavy_lifter_probe.tscn
godot --headless --path . --scene  res://tools/fuel_probe.tscn
godot --headless --path . --scene  res://tools/economy_probe.tscn
```

**Stage 3 — required: Python**

The `services` folders have no `__init__.py`, so name the modules. Do not use
`discover` for `services`; PROGRESS.md records it finding zero tests.

```bash
python3 -m compileall -q services tools

python3 -m unittest -v \
  services.test_cargo_matrix \
  services.heavy_load.test_private \
  services.heavy_load.test_transport \
  services.heavy_load.test_variants \
  services.oil_market.test_model \
  services.oil_market.test_settlement \
  services.oil_market.test_interface \
  services.refinery.test_processing \
  services.refinery.test_shared \
  services.refinery.test_cargo_fuel

python3 -m unittest discover -v -s tools/public_handoff -p 'test_*.py'
python3 -m unittest discover -v -s tools/world_layout   -p 'test_*.py'
python3 tools/world_layout/traversal_budget.py   # prints WORLD_LAYOUT_PASS routes=17 failures=0
```

The six `tools/public_handoff` test files are `test_repairs.py`,
`test_ship_purchase.py`, `test_fleet.py`, `test_resale_accounting.py`,
`test_economy_gate.py` and `test_cargo_balance.py`. The oil and refinery tests
stay in this list on purpose: gas and oil are on hold, not removed.

**Stage 4 — report only, does not fail the job yet**

```bash
godot --headless --path . --scene res://tools/collision_probe.tscn
godot --headless --path . --scene res://tools/composition_probe.tscn
godot --headless --path . --scene res://tools/ports_probe.tscn
```

PROGRESS.md records these three as failing or unclean on Linux before any recent
change. M0 decides for each one: fix it, or mark it Windows-only.

**Expect red on the first run.** Stages 1 and 3 include everything from Steps
83–88, which has never run. That is the point. Fixing it is fix-first item 3.
Until then, a new PR must not add failures to the first run's list.

**Not in CI yet**

- The other probes and runners in `tools/` (bulk, gas, oil, refinery, repairs,
  purchase, fleet, network, storage, recovery, persistence, migration, slots).
  Most need launcher arguments, two processes or a `check_*.py` driver. An agent
  runs them in fix-first item 3 and adds each one to Stage 2 once it passes.
- PostgreSQL, Keycloak and the online stack. Frozen with online.
- The scripted key-press playthroughs. Added to Stage 2 as each one is written.
  The first one exists and is waiting for Hark to add it to the workflow:
  `godot --headless --path . --script res://tools/check_helm_keys.gd`
  (prints `HELM_KEYS_CHECK_PASS`; about 10–20 s; Windows: `-Mode HelmKeysCheck`).
  The M1 one is also waiting for Hark:
  `godot --headless --path . --script res://tools/check_m1_voyage.gd`
  (prints `M1_VOYAGE_CHECK_PASS`; Windows: `-Mode M1VoyageCheck`). It sails about
  seven minutes of game time, fast-forwarded. Its real run time is not measured
  yet and may need more than the 30-second limit.
- Later (M1): export a Windows zip as a build artifact, so Andy downloads and
  runs it instead of opening the editor. Needs the 4.7.2 export templates.

Known limit: Linux headless cannot judge feel or visuals. Windows stays the
platform where a milestone is accepted.

## 4. Fix-first list

Nothing new until these are done.

1. **The movement bug.** First reproduce on Windows in **Boat Handling Test**,
   Andy's most likely scene: read the fuel line, click "Refuel (test)", try the
   throttle. Then fix what is found. In any case:
   - Make `set_menu_open` only re-arm when the value changes (or stop calling it
     per frame), so Bulk, Gas and the oil fixture can be sailed.
   - Stop a test-emptied tank from following Andy into the next session, or at
     least say so on screen (see item 4).
   - Add a test that holds the throttle key in each sailing scene and checks the
     ship gains speed.

   **Status (November 11, 2026): code written, not yet run.** `set_menu_open` now
   ignores an unchanged value. "Empty tank (test)" is no longer saved, and the fuel
   line says how to recover from EMPTY. The new check is
   `tools/check_helm_keys.gd`. It has not run anywhere: no Godot on the agent
   runner. Still open: run it in CI (Hark adds the line below to Stage 2), and the
   Windows reproduction in Boat Handling Test.
2. **Get Godot and Python running in CI** (the job above; Hark's workflow edit).
   Until then every fix is another guess.
3. **Import and parse the whole project, then run everything that has not run
   since Step 82.** Fix what is red. Expect trouble in the Step 83–88 files and
   the three hand-written `.gd.uid` files. Remove "UNVERIFIED" from a step only
   when its checks pass.

   **Status (November 11, 2026): partly done, by reading only. Still open.** The
   agent runner again refused Godot, Python and the CI logs, so nothing was run
   and run 43078248183 was not read. Done: the three Stage 4 probes were
   diagnosed from source and fixed (collision and composition were stale tests,
   ports was a small real bug plus a probe that opened the default save); the
   three hand-written `.gd.uid` files were deleted so Godot can generate them;
   `tools/check_helm_keys.gd` was reviewed. Not done: every Step 83–88 heading
   keeps "UNVERIFIED", the probes listed under "Not in CI yet" were not run, and
   no generated `.gd.uid` is committed. Details in PROGRESS.md.
4. **No silent dead ends.** Whenever a scene disables the ship (paused, empty
   tank, failed save, failed resume, panel open, docked), say why on screen and
   how to get out.

   **Status (November 12, 2026): code written, not run by the agent.** A banner
   owned by `ShipHelm` (`features/ships/helm_notice.gd`) appears above the
   throttle whenever the helm is off for more than 0.4 s. It names the cause and
   the way out, in Boat Handling, Heavy-Lifter, Port, Bulk, Gas and the oil
   fixture. Godot was refused on the agent runner again, so the Checks run on the
   PR is the first parse and run. Not covered: Local Multiplayer Test and the
   online client (frozen; they do not use `ShipHelm`). M0 still needs Andy's
   Windows playtest. Details in PROGRESS.md.
5. **Freeze the roadmap.** No Step 89. Park online work. Keep Steps 62–88 code
   but treat it as untrusted until item 3 passes. Gas and oil code stays intact.

## Open question for Andy

One left, and it does not block starting M0:

- In the scene where the ship would not move, what did the end of the fuel line
  say: **EMPTY**, **SIM PAUSED**, **DOCKED**, or nothing? And was the entry you
  clicked BOAT HANDLING TEST?

## 5. Patch 2.0 (Andy, November 12, 2026)

v1.0 is done and Andy played it on Windows. He loves the look (color, models,
docks). Patch 2.0 is his playtest feedback. Work the items in this order, one
PR each. Keep the Wind Waker look, Godot 4.7.2, saves, and the on-hold
gas/oil/refinery/cargo-fuel code intact. Single-player still; multiplayer is a
later patch, so build nothing online now, but never design anything that relies
on pausing the world.

1. **Always running + Esc menu.** The game never pauses: the ship keeps sailing
   and the world keeps ticking when the window loses focus, is minimized, or
   when any panel or menu is open (no `get_tree().paused`, no focus-out pause,
   no frame-rate drop to zero in the background). Esc no longer jumps to the
   home menu: it toggles a small in-game menu with Resume, Settings, Main Menu
   and Quit, drawn over a world that keeps running. Main Menu saves first.
2. **Easy docking.** Drop the berth-angle rule ("Align with the berth
   direction (within 10 degrees)") and other fussy checks. If the ship is near
   a berth and slow (generous range, generous speed), Dock works; the game
   then smoothly slides and turns the ship into the berth by itself. Any
   message about docking says only what to do ("Slow down to dock").
3. **Bigger loads.** Jobs are no longer 1, 2 or 3 containers. Offers range from
   a handful up to the ship's full capacity (raise ship capacities so the
   starter ship carries a real stack, bigger ships many more), with pay scaled
   to the load. The containers on deck show the load.
4. **Sailing feel: waves, rocking and foam.** Reference: Andy's video, The
   Legend of Zelda: Wind Waker HD "Peaceful Sailing"
   (https://youtu.be/dERxAAP4Ybo). Replace the placeholder motion and foam:
   rolling stylized swells, a clearly exaggerated bob, pitch and roll that
   grow with speed and lean into turns, a white bow spray and hull foam ring,
   and a long white V wake with swirls that fades behind the ship. Toon style
   to match the water from Aesthetics 1.
5. **HUD simplification.** Less on screen:
   - Throttle: just a slider with R, N and D and a speed readout in knots
     ("12 kn"), with a small Dock button beside it that is greyed out when no
     berth is in range and docks when pressed.
   - Minimap: a small globe (a rotating sphere showing the world, ports and the
     ship) instead of the flat map.
   - Job hub: much simpler; be creative (for example one card per offer:
     from, to, containers, pay, Accept).
   - Top-left panel (instructions plus the dock and main-menu buttons): remove
     the clutter. Controls hints appear briefly on the first voyage and then go;
     the main menu is reached with Esc.
   - Any other simplification the agent thinks helps, as long as it stays
     playful and readable.
   The last item's PR carries a 5-10 line Windows playtest checklist.

**Later patches:** Patch 2.1 (section 6) is done; Patch 2.2 (section 7) is done; Patch 2.3 (section 8, debug mode) is written and waits for Andy's playtest. Patch 3 is a new main menu
(Andy's design, later; do not start). Patch 4 is multiplayer (do not start).

**Patch 2.0 status (November 13, 2026):** all five items are written and pass
the automatic checks on Linux: 1 (Always running + Esc menu), 2 (Easy docking),
3 (Bigger loads), 4 (Sailing feel) and 5 (HUD simplification). All five wait
for Andy's Windows playtest; the checklist is in the item 5 pull request.
Item 4 has not been judged on a screen by anyone yet; item 5 was seen only as
software-rendered screenshots by the agent.
Details in PROGRESS.md.

## 6. Patch 2.1 (Andy, November 12, 2026)

Andy played Patch 2.0 and loves it: the long wake trail, the waves and the
boat motion are "perfect". Keep all of that exactly as it is. Patch 2.1 is his
next round. Same rules as section 5: one PR each, in this order, Wind Waker
look, Godot 4.7.2, saves and on-hold gas/oil/refinery/cargo-fuel code intact,
nothing that relies on pausing, single-player for now.

1. **3D bow splash.** Replace the flat bow foam with a real 3D splashing effect
   at the bow: white toon spray chunks/particles that kick up and fall back,
   bigger with speed, gone when stopped. Do not change the wake trail, waves or
   rocking from Patch 2.0.
2. **Faster ships.** The starter ship tops out at about 30 knots; bigger ships
   scale sensibly from that. Acceleration and deceleration must feel
   reasonable, not crazy slow: the starter ship reaches full ahead in roughly
   15-25 seconds and stops from full speed in a similar time (tune by feel and
   note the numbers in PROGRESS.md). Reverse stays slower. Rocking, wake and
   splash keep scaling correctly at the new speeds.
3. **Polar ports and a loopable globe.** The world wraps like a globe: sailing
   off any edge (east/west and over the poles) continues around the world, and
   the globe minimap shows it. Add a North Pole port and a South Pole port,
   ice themed (snowy docks, ice-white palette), with icebergs around the polar
   seas (solid obstacles, toon style). Both ports get jobs like any other port.
4. **Multiplayer-safe docking.** Docking keeps the automatic slide into the
   berth. Prepare it for multiplayer later: each berth holds one ship at a time
   (a taken berth is skipped and the next free berth at that port is used; if
   none is free, Dock says the port is full); ships never overlap at a port;
   and while a ship is sliding into or sitting at a berth its collision with
   other ships is off, coming back on only once it has left the berth and is
   clear of other ships. Keep it single-player now, but write berth claiming so
   a future server can own it (simulate a second, AI-held berth in a test).
   The last item's PR carries a 5-10 line Windows playtest checklist for all of
   Patch 2.1.

**Patch 2.1 status (November 13, 2026):** item 1 (3D bow splash) is written
and passes the automatic checks on Linux; seen only as software-rendered
screenshots by the agent. Item 2 (faster ships: starter 30 kn, about 21 s to
full speed, about 16 s to stop) is written; its Godot checks have not run yet
(only the Python checks ran) and wait for the Checks workflow. Item 3 is
written: 3A (the world wraps in every direction and the globe minimap shows
it) and 3B (North Pole and South Pole ports with jobs, and solid toon icebergs
in the polar seas) both pass the automatic checks on Linux; 3B was seen only
as software-rendered screenshots by the agent. All wait for Andy's Windows
playtest. Item 4 (multiplayer-safe docking: two berths per port, one ship
each, "port full" when both are taken, ship collision off at a berth) is
written and passes the automatic checks on Linux; not seen on a screen. All
of Patch 2.1 now waits for Andy's Windows playtest. Details in PROGRESS.md.

## 7. Patch 2.2 (Andy, November 13, 2026)

Andy's next round: a real fleet ladder and a boat hangar. Same rules as
sections 5 and 6: one PR each, in this order, Wind Waker look, Godot 4.7.2,
saves and on-hold gas/oil/refinery/cargo-fuel code intact (gas and oil ships
stay out of the ladder and the hangar for now), nothing that relies on
pausing, single-player for now, Patch 2.0/2.1 wake, waves, rocking and bow
splash keep working and scale with each hull. Hark chose the designs (Andy:
"decided by you or the AI, find different real-life ships and get inspired").

**Fleet ladder.** Three families of five ships each. Ship 1 is the smallest,
ship 5 is huge. Bigger is faster (Andy's call), but bigger also takes longer
to speed up, stop and turn, so a big ship feels heavy. Prices climb steeply so
ship 5 is a long-term goal. Saves keep working: existing starter, coastal,
harbor, swift container ships, the bulk prototype and the heavy lifter map
onto the new ladder by ID (no save loses a ship or credits).

| Family | 1 | 2 | 3 | 4 | 5 (huge) |
| --- | --- | --- | --- | --- | --- |
| Container (inspired by) | Starter feeder (current) | Coastal feeder, ~1,000 TEU | Panamax, ~4,500 TEU | Neo-Panamax, ~14,000 TEU | Ultra-large box ship like MSC Irina, ~24,000 TEU |
| Container top speed | 30 kn | 33 kn | 36 kn | 39 kn | 42 kn |
| Bulk (inspired by) | Handysize with deck cranes | Supramax | Panamax bulker | Capesize | Valemax ore carrier |
| Bulk top speed | 28 kn | 31 kn | 34 kn | 37 kn | 40 kn |
| Heavy lift (inspired by) | Current heavy lifter | Twin-crane project cargo ship (Jumbo J-class style) | Big twin-crane heavy lifter | Semi-submersible (BigLift Happy-Star style) | Giant semi-submersible like BOKA Vanguard |
| Heavy lift top speed | 26 kn | 29 kn | 32 kn | 35 kn | 38 kn |

Sizes roughly double in length every one to two steps (ship 5 is several times
the starter; on screen it should feel enormous next to ship 1). Time to full
speed grows from about 21 s (ship 1) to about 40 s (ship 5); stopping grows
similarly; turning gets wider. Capacity, price and fuel use scale with size.
Each ship gets its own low-poly toon model in the Wind Waker look with a
distinct silhouette and color scheme per family; berths and the auto-slide
docking must fit every size (big ships use bigger berths or a longer slide;
no clipping into the quay).

1. **Container family:** container ships 2-5 (models, definitions, cargo
   capacity, prices, speeds), save mapping for the old container variants.
2. **Bulk family:** bulk ships 1-5, replacing the bulk prototype by mapping.
3. **Heavy-lift family:** heavy-lift ships 2-5 (ship 1 is the current heavy
   lifter).
4. **Boat hangar.** The ship purchase list becomes a full screen: a toon boat
   hangar (shed doors open to the water, warm lights) with one ship shown at a
   time, slowly turning. Left/right arrows (on screen and keys) cycle every
   ship in the ladder; a family filter (All, Container, Bulk, Heavy lift)
   at the top. Each ship shows name, family, size, top speed, capacity and
   price. Not owned: Buy (if affordable, else shows how much more is needed).
   Owned: Select, which makes it your active ship (the same switching rules
   the fleet already uses: switch while docked at a port). The current ship is
   marked Active. Back returns to the game. Opened from the existing buy/fleet
   button at ports. The last item's PR carries a 5-10 line Windows playtest
   checklist for all of Patch 2.2.

**Bigger ships, bigger jobs (Andy, Nov 13).** Jobs scale with the ship: ports
offer jobs sized to each ship tier, so a bigger ship gets jobs with far more
containers (or tonnage for bulk, or bigger/heavier pieces for heavy lift) and
pays far more per trip. The job board shows jobs that fit your active ship
first, never offers a job your ship cannot carry, and every family's ship 5
gets jobs worth its price. Loading and unloading time scales sensibly (big
ships take longer but not painfully: use a faster crane rate per tier).
Each item's PR wires its new ships into these jobs; item 4 checks the board
for every tier.

**No-jank checklist (Andy: "consider everything that's needed so the game
ain't jank").** Every item must hold all of these:
- Camera: chase distance, height and zoom limits scale with hull size, so a
  huge ship fills the view without clipping into it or losing the horizon.
- Physics: no jitter, sinking, tipping or bouncing on any hull; rocking,
  wake, bow splash and buoyancy scale with size; collision shapes match each
  model; ships cannot clip through quays, icebergs or each other.
- Docking: every port (polar ports included) has berths each tier fits; a
  ship too big for every berth at a port gets a clear "too big for this port"
  message instead of a broken slide; ship 5 can dock at the major ports.
- Map and world wrap: big ships wrap around the globe edges cleanly with no
  pop or snap, and minimap icons scale with size.
- Economy: prices, pay, fuel use and upkeep (if any) are balanced so each
  step up is worth it and no tier is useless; starting a new game is still
  the starter ship and fair.
- Saves: old saves load with every ship and credits kept; buying and
  switching ships saves correctly; the active ship survives a reload.
- Hangar: arrow cycling never desyncs from the stats shown; Buy cannot be
  double-pressed into two charges; Select only works when allowed and says
  why when not; controller/keyboard and mouse both work; no frame drops when
  swapping models (load or cache them).
- Performance: big models stay low-poly, run smoothly on Andy's Windows PC
  and the export includes every new asset.

**Patch 2.2 status (November 13, 2026):** items 1 (container ships 2-5), 2
(bulk ships 1-5) and 3 (heavy-lift ships 2-5) built and checked on Linux
headless; not playtested on Windows. Item 4 (boat hangar screen) is built
and passes the automatic checks on Linux headless; not seen on a screen by
anyone. All of Patch 2.2 now waits for Andy's Windows playtest.

## 8. Patch 2.3 (Andy, November 13, 2026)

Andy wants a temporary debug game mode so he can try every boat on the map.
It is a test tool, not a feature: keep it small, clearly labeled, and easy to
remove later (one flag or one folder). Same rules as before: Godot 4.7.2,
Wind Waker look, nothing that relies on pausing, saves and on-hold
gas/oil/refinery/cargo-fuel code intact, Patch 2.0-2.2 behavior unchanged
outside debug mode. Patch 3 (Andy's new main menu) will redo the title screen
later, so do not redesign it now.

1. **Debug game mode.** The title menu gets a DEBUG button beside PLAY and
   SETTINGS (always visible for now). It starts a throwaway debug world:
   - A "DEBUG" tag stays on screen the whole time.
   - It never reads or writes the player's real save or save slots; quitting
     throws it away (MAIN MENU returns to the title with the real save
     untouched).
   - Every ship in the Patch 2.2 ladder (all three families, ships 1-5) is
     owned, and credits are effectively unlimited.
   - The boat hangar opens anywhere (not only at ports) and Select swaps to
     that ship on the spot, at the current position and heading, with no
     docking needed.
   - A quick-travel list jumps the active ship to any port, the polar ports
     included, so big ships can be tried at every berth.
   - A small readout shows the active ship's name, speed in knots, top speed
     and time to full speed, so ship tuning can be judged.
   - Jobs, docking, wake, splash, world wrap and everything else work as in a
     normal game, so the real feel of each ship can be tested.
   Use the existing DevMode/developer overlay pieces where they fit. Add a
   check that a debug session leaves the real save files unchanged. The PR
   carries a short Windows playtest checklist (try all 15 ships, dock ship 5
   at a major port and a polar port, wrap the globe with a big ship).

**Patch 2.3 status (November 14, 2026):** item 1 (debug game mode) is written
and passes the automatic checks on Linux headless, including the new
`tools/debug_game_check.gd` (the real save is unchanged after a debug
session); not seen on a screen by anyone. It waits for Andy's Windows
playtest. It lives in `features/debug/`; removal steps are at the top of
`debug_game.gd`. Details in PROGRESS.md.

## 9. Patch 2.4 (Andy, November 13, 2026)

Andy's playtest of Patch 2.2/2.3 (debug mode) on Windows, with photos. Same
rules as before: one PR each, in this order, Godot 4.7.2, Wind Waker look,
nothing that relies on pausing, saves and on-hold gas/oil/refinery/cargo-fuel
code intact, debug mode (section 8) keeps working and includes every new
boat, the section 7 no-jank checklist applies to every item.

1. **Hulls sitting wrong in the water (bug, first).** Andy's photo of the
   largest container ship (ship 5, 42 kn) shows the bow dug down into the
   water while sailing, as if the model is nose-heavy or its buoyancy/trim
   points are wrong for its size. Check all 15 ladder ships at rest and at
   full speed: each must float level at a sensible waterline (bow not
   submerged, stern not sunk, no hull floating above the water), rocking and
   squat stay mild and scale with size. Fix buoyancy points, center of mass
   and model origin per hull. Add an automated check that each ship's
   resting and full-speed pitch and draft stay within limits.
2. **Faster turning.** Turning is too slow on every ship. Raise turn rate
   (tighter turning circle) noticeably across all ships; big ships still turn
   wider than small ones but no ship should feel like a slog. Note the
   numbers in PROGRESS.md.
3. **Bigger ports and proper berth spacing.** One ship 5 covers a whole port
   today. Enlarge every port (quays, water area, berths; polar ports too) so
   several big ships fit and the port still looks good. Docking leaves a
   realistic gap from the quay scaled to the hull (the big ships currently
   end up almost touching or inside the dock). Berth claiming from Patch 2.1
   keeps working.
4. **Mooring ropes.** Every ship model gets bollards/fairleads at bow and
   stern. When a ship finishes docking, toon mooring lines animate out and tie
   to the quay bollards like real life (bow, stern and spring lines on big
   ships); on undock they let go and reel in before the ship moves.
5. **Containers load one by one.** When a container ship loads or unloads,
   containers appear (and disappear) one at a time, moved by the port crane,
   instead of all at once. Loading time stays sensible for big ships (the
   crane can work faster per tier, or several cranes on big berths).
6. **Heavy-lift loads.** Three different heavy-lift cargo looks (for example
   a wind-turbine blade/tower section, a big industrial transformer or
   machinery block, and a harbor crane or boat hull on a cradle), each sized
   to the heavy lifter tier carrying it, so bigger heavy lifters carry bigger
   pieces. They sit on deck believably and show during loading.
7. **M opens a 3D globe map.** Pressing M opens a large 3D globe in the middle
   of the screen showing the whole world: ports (polar included), your ship,
   icebergs region. Click-and-drag rotates the planet freely in every
   direction (all the way around, over the poles), scroll zooms, M or Esc
   closes. The world keeps running while it is open (no pausing). The small
   minimap stays.
8. **Small fun boats.** A new "Small boats" family in the hangar and debug
   mode: a cigarette-style offshore racer (tiny, very fast, jumps waves a lot
   with big airtime and splashes), a regular speedboat (fast, jumps waves
   less), and a fishing boat (slow, chunky, cosy). Cheap; no cargo jobs.
   Toon models, own wake and splash; jumping is physics-driven from the
   waves and lands without jitter or flipping. The last item's PR carries a
   5-10 line Windows playtest checklist for all of Patch 2.4.

**Patch 2.4 status (November 14, 2026):** item 1 (hull trim), item 2 (faster turning: turn rates doubled, radius at most 460 m, big still wider) and item 3 (bigger ports: three 285 m berths and ~800 m quays at every port, polar too; docked hulls lie a 1.2-3 m fender gap off the quay, scaled to the beam) are each in a draft PR. Item 4 (mooring ropes: fairleads and bitts at bow and stern on every ladder model; after docking, toon bow and stern lines, plus springs on ships 120 m or longer, fly out to the quay bollards; Undock holds the ship 1 s while they let go and reel in) is in a draft PR too. Item 5 (containers one by one: six toon quay cranes on every berth, booms up while idle; a docked container ship gets 2 (ship 1) to 6 (ship 5) of them, and they lift each box from the quay onto its slot or back, bay by bay and bottom tier first; loading time stays the timer's, about 26 s for a full ship 1 and 65 s for a full ship 5; Undock waits for the last box) is in a draft PR too. Item 6 (heavy-lift loads: job 1, 2 and 3 at every port carry a wind turbine tower section, a transformer block and a tug hull on cradles, toon pieces built at the job load's real size, so bigger heavy lifters carry bigger pieces, shown on the floating load while loading and on deck) is in a draft PR too. All six were checked headless on Linux and await a Windows playtest. Items 7-8 are not started.
