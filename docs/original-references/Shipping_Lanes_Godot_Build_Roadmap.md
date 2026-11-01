# Shipping game — Godot build roadmap

Prepared for Andy • Revised October 18, 2026 • Dependency audit revision • Planning, not an implementation

## The recommended path

Build one trustworthy voyage, then widen the game. First prove ship handling, ownership, transactions, saves, and a small host/client session. Next complete one container delivery from start to restart. Only then add more cargo, the large world, customization, and public online services. Vehicle transport and rockets come after the core release, as requested.

The number is an output of the task breakdown, not a target or cap. This is a dependency-ordered plan with **142 build requests after a dependency and integration audit**. A request is a bounded piece of work, not a promise of one response or one day. Some engine or networking problems will need several fix-and-test cycles. Never advance because a checkbox looks complete: advance because the completion check passed in the current project.

The core version includes containers, bulk, gas, oil trading/refining, cargo fuel, heavy lifting, ship progression, fuel, damage/maintenance, ports/navigation, saves, and the agreed multiplayer scope. It uses earned in-game money. Real-money purchases, rewarded ads, paid speed advantages, and loot crates are excluded. Retired companies, staff-only ships, historical events, aircraft/carriers, sail simulation, elaborate quests, and a full furniture catalog are separate optional expansions; they are not silently required to finish this core game. Andy's original features enter a backlog and are slotted in at a stable milestone.

The exact launch fleet, port count, final art samples, and tested launch capacity remain decisions. The confirmed dedicated-session design target is roughly 100 players, with a simple cartoon style and both hosting modes. The researched 90 ship records are not a launch-content requirement. Begin with two hulls and two ports, then select a useful launch set. A compact polished game is a better foundation for expansion than an unverified reproduction of every catalog row.

## How to use the requests

Attach this roadmap and the research reference to the project. Keep the actual Godot project in a versioned repository or exchange a current project archive; project-reference documents alone do not give me the latest code. At the beginning of a new work session, make the current project and progress record available.

Send: **“Do Step 01 from the Godot roadmap. Follow the working agreement.”** When its checks pass, say **“Do the next step.”** Use the numbered request below when you want tighter control. If a step is too large for one reviewable change, give the new substeps stable IDs and preserve the original completion check. Insert newly discovered work wherever its prerequisites belong; completed task IDs remain stable even if display numbers change.

### Working agreement to include with build requests

> Read the current project, GAME_SPEC.md, decision record, and progress record before changing code. Implement only the requested step and the necessary integration with previous steps. Use the pinned Godot version and typed GDScript. Prefer focused reusable scenes and explicit state ownership. Preserve existing IDs and saves. Keep UI separate from economic and simulation authority. Use placeholders where appearance is not the task. Do not add speculative features or silently replace working systems. If a prerequisite is missing, repair the smallest prerequisite and report the scope change. Run the relevant available checks; distinguish actual engine/runtime verification from static inspection and checks Andy must perform. Report what changed, how to test it, results, known issues, and the next step. Update the progress record and preserve a recoverable checkpoint when the step passes.

Every implementation handoff should include exact run instructions and a short acceptance checklist. If direct project editing is available, edit the project. If it is not, provide the exact file paths, complete changed files, required scene/input changes, and testing instructions; avoid disconnected snippets that leave assembly ambiguous. A parser check is not proof that sailing, networking, or saves work.

### Completion rule

Each step must import cleanly, preserve relevant earlier behavior, and satisfy its stated check. Use automated checks for high-value rules such as transactions, capacities, units, migrations, and replay handling. Use playtests for feel, collision, moving decks, interface, and performance. Do not write tests that merely duplicate decorative scene structure.

At each gate: export a runnable build, exercise the relevant features, fix blocking failures, record evidence and limitations, and preserve a known-good checkpoint. No claim of “tested” without saying what actually ran. Andy approves feel and design by playing; the agent owns the repeatable technical checks it can run.

## Foundation decisions and extension boundaries

These are proposed engineering choices, not claims about the source game's implementation:

| Concern | Recommended starting choice | Why it helps later |
| --- | --- | --- |
| Engine | Pin a supported stable Godot 4 release at setup; typed GDScript | Consistent APIs and understandable code |
| Ship/port/cargo catalog | Custom Resources with stable IDs; immutable shared definitions | Ordinary content additions can be data changes |
| Runtime state | Separate per-instance records for owned ships, cargo, jobs, wallets | Shared resources cannot leak mutable state between ships |
| Scene structure | Small reusable scenes; parent supplies outside dependencies | A ship or berth can work in a test scene and the world |
| Gameplay actions | Validated authoritative requests with explicit results | UI, local play, and network play follow the same rules |
| Money and goods | Atomic operations, bounded integer money, persisted idempotency where needed | Avoid duplicate payments and half-completed trades |
| Network work | Tiny host/client proof early; internet services later | Reveals ownership and moving-platform problems before content multiplies |
| Saves | Versioned stable-ID state, backups, migration fixtures | New features can extend old progress safely |
| World | Measure scale/precision before committing; prefer bounded regions initially | Avoid a premature seamless-world rewrite |
| Ship physics | Tune one handling prototype; use controlled cargo attachments | Prioritize repeatable docking and transport |
| Extensibility | Add interfaces at proven boundaries, then validate by adding content | Avoid both hard-coded catalogs and a huge unused plugin framework |

Adding a new ship with existing behavior should mostly mean a definition, hull scene, collision, and attachment layout. Adding an unprecedented mechanic will still require new code, authority rules, save fields, and tests. A solid foundation makes that work local; it does not make every future idea automatic.

## The build requests

Steps proceed in numeric order except where a selected deployment scope explicitly defers a branch. Fixes can loop back to an earlier step. The order is optimized for risk reduction and avoiding rework, not for producing the most visually impressive first screenshot.

## Starter, refinery, and recovery confirmation

Andy selected a small container starter ship. Refinery stock is shared across our public servers and remains isolated from private-host worlds. Sinking removes current cargo, preserves ship ownership, and always incurs a recovery fee, including on the starter boat. No free recoveries or starter fee waivers. If the wallet cannot cover recovery, the proposed no-soft-lock policy records the full charge as a recovery balance repaid from later earnings; fee amounts and repayment tuning remain design work.

## Scope confirmation — ship controls first

Andy confirmed helm/ship controls only for the first release. Walking, boarding, passengers, and furniture are outside its required sequence and retained as an optional later module. References to passenger/furniture envelopes in future-proofing checks are conditional, not instructions to build them now. Public oil trading uses one shared authoritative market across our public servers; port-specific differences are allowed, but the same port does not have independent prices on each server. Private host markets stay isolated. Hosts can explicitly choose public listing or private access. Public listing and private save ownership are independent settings.

## Confirmed specification update — October 18

Use Shipping_Game_Specification.md for Andy's latest decisions: Windows, both player-hosted and dedicated sessions, a Multiplayer server list, roughly 100-player dedicated-server target, efficient regional loading within one session, balanced handling, an unrestricted port network subject to practical voyage/service limits, a small container starter ship, simple colors/flags/names, and original low-poly cartoon assets made with agent assistance. Local PC files must be made available through a repository or project archive when implementation starts. The PC is currently off. Andy confirmed shared public money/fleet progression and isolated private-host saves. Public server switching requires a durable single-session handoff; backend/provider remains an implementation choice. Public oil markets and refinery stocks are confirmed shared across our public servers.

## Audit and maintenance rules

The first draft used 100 display steps. The revised task count follows missing prerequisites and oversized tasks discovered in review. It is not a guarantee that development will reveal no additional work. Treat this as a living dependency plan.

Each task has a stable ID derived from its name. Track status by ID, not only display number. Before each request, check its prerequisites against actual working code and the selected scope. After each gate, audit the next phase for missing integration and split tasks that are not reviewable in one change. Record discovered defects as tasks with their own acceptance checks; do not hide them in “polish.”

The normal prerequisite is the previously accepted applicable task. Public-service branches may be explicitly deferred for a local/LAN release, but their economic correctness requirements still apply to that session's authoritative state. A step that requires a later system must use a documented test fixture until that system exists, then be revisited at the integration gate.

Extra checks added in this audit include early export, model/import conventions, online scope before saves, clocks and lifecycle ownership, durable replay recovery, moving-deck networking, heavy-load feasibility, saved operations, cargo-fuel sales, transition recovery, trade locks and settlement, art replacement, backups, and clean installation. Research uncertainties are decisions to resolve, not omissions to bury in code.

## Milestone index

| Milestone | Current step | Meaning |
| --- | --- | --- |
| Foundation gate | 42 | Handling, authority, saves, reconnects proven |
| First voyage gate | 57 | First exported end-to-end container voyage |
| Cargo milestone gate | 87 | All priority cargo families playable |
| World gate | 101 | Launch-scale travel and loading proven |
| Player experience gate | 109 | Walking, permissions, customization, trading integrated |
| Core release and extension guide | 128 | Finished agreed core release |
| Expanded release | 142 | Vehicles and rockets integrated |

## Foundation and decisions — Steps 01–15

### 01. Project contract

**Task ID:** `project-contract`  
**Prerequisite:** No implementation prerequisites; use the research and agreed scope.

**Ask me:**

> Turn our research and this roadmap into a concise GAME_SPEC.md. Record the core cargo scope, Windows desktop development target as a provisional default, intended online play, control style, placeholder art policy, and an explicit definition of version 1. Ask only for unresolved choices that would materially change the architecture. Do not implement gameplay yet.

**Done when:** The scope separates confirmed decisions, provisional defaults, unresolved questions, and later additions. Research uncertainties are not presented as verified mechanics.

### 02. Online architecture decision

**Task ID:** `online-architecture-decision`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Use Andy's confirmed requirement for both player-hosted sessions and dedicated servers targeting roughly 100 players. Follow Shipping_Game_Specification.md. Implement the confirmed policy: money and owned ships follow players across our public servers, while private hosts keep separate saves with no public-economy import. Decide guest identity, provider/storage, session leases, and host departure before durable economy work. Do not ask Andy to choose just one hosting mode.

**Done when:** Both modes have explicit authority/save rules. Shared public progression and isolated private saves are documented; public-session ownership has a single authority, and no untested 100-player support is claimed.

### 03. Feature and uncertainty inventory

**Task ID:** `feature-and-uncertainty-inventory`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Map every agreed gameplay feature from the research to an implementation milestone. Record unknown formulas, lifecycle rules, optional features, and original-design decisions. Give each unresolved rule an owner and a latest decision point; do not automatically reproduce retired or paid systems.

**Done when:** Every agreed feature has a place in the plan or an explicit exclusion. Unknown rules that affect architecture are resolved before their dependent implementation.

### 04. Engine and hardware baseline

**Task ID:** `engine-and-hardware-baseline`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Inspect the actual development environment. Choose and pin an installed supported stable Godot 4 release and typed GDScript, select the renderer using the target hardware, and record installation and export instructions. Define a provisional performance target and revise it after measuring the test scene.

**Done when:** The editor opens an empty project; its exact version, renderer, target OS, and test hardware are recorded. Any unavailable editor or runtime is reported plainly.

### 05. Repository and project skeleton

**Task ID:** `repository-and-project-skeleton`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Create the Godot project, Git ignore rules, README, and folders grouped by feature. Add a minimal Main scene with separate World and UI children. Create progress and decision records and establish a recoverable baseline commit when Git is available.

**Done when:** The project imports without script errors, launches to an identifiable empty scene, and generated cache files are excluded from version control.

### 06. Export pipeline smoke test

**Task ID:** `export-pipeline-smoke-test`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Install matching export templates, produce a minimal desktop build, and run it outside the editor. Document the exact import, check, build, and launch commands and any platform limits. Keep secrets and generated export outputs out of the repository.

**Done when:** An exported empty build launches on the target platform or an explicit environment blocker is recorded before gameplay development.

### 07. Model and asset conventions

**Task ID:** `model-and-asset-conventions`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Set ship forward/up axes, meter scale, origin/waterline conventions, collision simplification, attachment naming, import settings, and material limits. Import a small original placeholder model and track its license/source. Describe how visual models can be replaced without changing gameplay IDs.

**Done when:** A replacement model has correct orientation and scale, preserves collision/anchors, and can be reimported reproducibly.

### 08. Input and settings foundation

**Task ID:** `input-and-settings-foundation`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add named input actions for throttle, steering, thrusters, brake command, camera, interaction, map, horn, pause, and walking. Add a small settings resource and persistent user preferences. Keep vehicle and walking input contexts separate.

**Done when:** Changing a binding does not require editing ship code; a focused menu prevents its keys from steering the ship.

### 09. Application flow and focus

**Task ID:** `application-flow-and-focus`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add boot, title, new session, continue, gameplay, pause/settings, and return-to-title transitions. Define pause behavior for offline versus hosted play, keyboard focus, window focus loss, and input capture. Keep gameplay reset separate from settings.

**Done when:** Repeated start/quit cycles do not leave stale sessions or duplicate UI; pause cannot freeze an online server for everyone.

### 10. Definitions and stable IDs

**Task ID:** `definitions-and-stable-ids`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Create small custom Resource definitions for ships, cargo types, ports, and berths with stable IDs. Separate shared definitions from per-ship mutable runtime state. Add a registry that rejects duplicate IDs and missing required references. Use only a few placeholder records.

**Done when:** Two ships can reference one definition while retaining different fuel and cargo; mutating one instance does not alter the other or the source asset.

### 11. Save and protocol contracts

**Task ID:** `save-and-protocol-contracts`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Sketch versioned records for players, ships, jobs, inventories, operations, and world state before their implementations grow. Specify stable IDs, units, optional/default fields, clock semantics, protocol versions, and safe serialization boundaries. Use plain validated data rather than loading arbitrary user-supplied scripts/resources as saves.

**Done when:** Representative records can be validated; malformed fields fail clearly and never execute content. Schema changes have a recorded migration policy.

### 12. Units and time

**Task ID:** `units-and-time`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Create explicit conversions for meters, nautical miles, seconds, knots, currency, and each cargo unit. Use integer minor units for money, and document rounding and game distance/time scaling. Keep hold count, DWT, mass, barrels, cubic meters, and container slots distinct.

**Done when:** Known conversion examples pass; the same voyage distance is used by navigation and payout without mixing world meters and nautical miles.

### 13. State ownership boundaries

**Task ID:** `state-ownership-boundaries`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement the smallest session layer that owns authoritative player, ship, wallet, and cargo state. UI and controllers request actions through narrow methods instead of editing balances or inventories directly. Document how local play uses the same action path as hosted play.

**Done when:** A debug UI request reaches the session and returns success or a reason for rejection; no all-purpose global manager owns every feature.

### 14. Simulation lifecycle and clocks

**Task ID:** `simulation-lifecycle-and-clocks`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Define authoritative simulation ticks, monotonic operation time, persisted timestamps, offline progress policy, and the ownership of timers. Make scene teardown cancel or transfer work explicitly; UI must not own jobs or their timers.

**Done when:** Pausing, hiding a menu, or changing scenes cannot accidentally advance or reset a test operation. Offline progress is deliberate rather than a side effect of wall-clock changes.

### 15. Development tools and checks

**Task ID:** `development-tools-and-checks`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add a developer overlay for speed, throttle, position, ship ID, fuel, session role, and frame timing. Add a repeatable project import/script check and a small headless runner for unit conversions and definition validation. Record how to run these checks.

**Done when:** A deliberately invalid definition produces a useful error, and turning off the overlay leaves normal play usable.

## Ship handling and the physical world — Steps 16–28

### 16. Handling prototype

**Task ID:** `handling-prototype`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> In an isolated scene, build one box-shaped ship with forward propulsion, drag, inertia, and reverse braking at the fixed physics tick. Evaluate a controlled body approach against a force-driven body only if the handling requires it; record the selected approach. Keep the ocean visual flat for now.

**Done when:** Ship motion is usable at different rendering frame rates, coasts at zero throttle, and slows under reverse thrust. Record a short handling comparison and the chosen body type.

### 17. Throttle and reverse

**Task ID:** `throttle-and-reverse`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add commanded versus actual throttle, bounded ramp rates, forward/reverse limits, and an explicit zero-throttle action. Expose tunable handling parameters on the ship definition.

**Done when:** Rapid input reversals stay bounded; zero command does not erase momentum; the HUD can show command separately from motion.

### 18. Rudder and thrusters

**Task ID:** `rudder-and-thrusters`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add speed-sensitive turning and lateral thrusters to the prototype. Give reverse steering an explicit documented rule. Add a maneuvering test course and editable turning and thruster parameters.

**Done when:** The ship can make a repeatable turn and approach a berth sideways without unlimited lateral acceleration or instant heading changes.

### 19. Camera

**Task ID:** `camera`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add an orbit camera with zoom limits, smoothing, recentering, collision avoidance, and a camera-focus interface. Keep it independent of a particular ship node path.

**Done when:** It works on two placeholder hull sizes, avoids pier clipping, and does not jump when switching camera targets.

### 20. Water presentation

**Task ID:** `water-presentation`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add a lightweight ocean material and visual ship bobbing. Keep presentation movement separate from authoritative navigation and collision unless a later prototype proves physical waves necessary. Add scalable water quality settings.

**Done when:** Visual waves do not make docking or networked transforms oscillate unpredictably; a low-quality mode remains readable.

### 21. Hull and shore collision

**Task ID:** `hull-and-shore-collision`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add simple hull collision, coastline collision, and a test pier. Prevent high-speed tunneling using an approach suitable for the chosen body. Define collision layers for hulls, shore, triggers, cargo visuals, and characters.

**Done when:** Head-on and glancing impacts at the supported speed range cannot pass through the pier or create uncontrollable repeated impulses.

### 22. Handling feedback pass

**Task ID:** `handling-feedback-pass`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add simple engine/thruster/horn feedback and visible speed, heading, throttle, and fuel instruments. Have Andy test acceleration, braking, turning, camera motion, and docking-scale maneuvers before locking the controller approach.

**Done when:** The handling has a recorded playable baseline and prioritized feedback. Discomfort or unreadable motion is fixed before adding detailed hull art.

### 23. Depth and draft

**Task ID:** `depth-and-draft`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add a simple depth query and loaded-versus-empty draft values. Prototype shallow water and grounding behavior; keep physical clearance checks separate from administrative ship-size restrictions.

**Done when:** A shallow passage accepts an eligible empty hull but rejects or grounds its loaded variant under the documented rule.

### 24. Simulation checkpoints

**Task ID:** `simulation-checkpoints`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add deterministic input playback where practical, and numeric tolerance checks for acceleration, stopping distance, turn behavior, and fuel-ready throttle telemetry. Do not require bit-identical cross-machine physics.

**Done when:** A handling change can be compared with recorded tolerances rather than judged only from memory.

### 25. World-size experiment

**Task ID:** `world-size-experiment`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Prototype the planned maximum travel extent with the chosen world scale. Check camera, hull collision, depth queries, and markers near the furthest coordinates. Choose bounded regions first unless seamless travel is confirmed as a requirement; document whether origin shifting or a custom precision build is actually needed.

**Done when:** An explicit world-coordinate strategy is supported by measurements. There is no speculative map-wide precision framework without a demonstrated need.

### 26. Special cargo feasibility prototype

**Task ID:** `special-cargo-feasibility-prototype`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> In an isolated test scene, prove one heavy-lifter deck can lower, align, attach a large payload, raise it, and carry it while turning. Reuse the planned ship controller and coordinate conventions. This is a risk experiment, not a complete job system.

**Done when:** The chosen collision, attachment, and transform approach supports heavy loads without unstable stacked physics. Any controller change is made while only two hulls depend on it.

### 27. Reusable ship composition

**Task ID:** `reusable-ship-composition`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Package propulsion, helm control, collision, visual hull, cargo attachment points, and camera anchor into reusable scenes/components. Create a second ship definition with different dimensions and handling without duplicating the controller.

**Done when:** Both hulls pass the handling course and can be instanced in a separate test scene without broken external node paths.

### 28. Fuel simulation

**Task ID:** `fuel-simulation`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add propulsion fuel capacity and throttle-based consumption with configurable idle, reverse, and thruster rules. Define zero-fuel behavior explicitly as our game design. Include pause and docked states in the consumption policy.

**Done when:** Fuel never becomes negative; changing frame rate does not change consumption materially; empty fuel has a tested recovery path.

## Authority, transactions, and durable saves — Steps 29–42

### 29. Local network session

**Task ID:** `local-network-session`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add minimal host and join over localhost using Godot networking. Replicate ship spawn and despawn with stable entity IDs and explicit authority. Use a second process for verification; public matchmaking is outside this step.

**Done when:** Two processes see the same two ship identities; joining or disconnecting does not duplicate ships.

### 30. Ship replication

**Task ID:** `ship-replication`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Route helm inputs to the authoritative simulation and interpolate remote ship motion. Validate input bounds and helm ownership. Measure latency before deciding whether local prediction and reconciliation are necessary.

**Done when:** Only the authorized helm controls its ship; remote motion remains usable under a recorded simulated latency and packet-loss profile.

### 31. Attached-payload networking feasibility

**Task ID:** `attached-payload-networking-feasibility`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Repeat the heavy-lifter attached-payload prototype with a host and client. Verify authority, transforms, attachment/release ordering, and carried collision under latency. Walking and passenger replication are deferred until a later walking expansion.

**Done when:** The payload stays coherent during turns and reconnects under the documented network profile; no walking controller is required for the first release.

### 32. Early dedicated capacity experiment

**Task ID:** `early-dedicated-capacity-experiment`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Run an initial headless authority prototype with 2, 10, 25, 50, and approximately 100 synthetic clients as resources permit. Exercise dispersed ships, a crowded port-shaped test zone, joins/reconnects, and action traffic. Measure server tick time, CPU, memory, bandwidth, and a real client's motion quality. Establish relevance filtering and a repeatable load harness before extensive world/content work.

**Done when:** A capacity report distinguishes measured counts from untested targets. Bottlenecks that threaten the 100-player design have a concrete fix or architecture decision before expansion.

### 33. Action validation

**Task ID:** `action-validation`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add one typed request/result path for gameplay actions with player identity, action IDs, validation, and clear error codes. Start with a harmless test action and ship-control requests; avoid a generic scripting/plugin framework.

**Done when:** A peer cannot act for another owner, and repeated action IDs do not repeat an already committed effect.

### 34. Money and transfer rules

**Task ID:** `money-and-transfer-rules`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement an authoritative wallet ledger and atomic transfer operation for money and cargo quantities. Validate all inputs before mutation and commit all affected state together. Add meaningful checks for duplicate actions, insufficient funds, invalid quantities, and overflow boundaries.

**Done when:** A failed action changes neither side; a repeated successful request cannot charge or pay twice.

### 35. Durable action recovery

**Task ID:** `durable-action-recovery`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Persist committed transaction IDs and the minimal authoritative snapshot or journal needed to recover local/hosted economy actions. Define retention and retry policy. For persistent dedicated scope, select a transactional storage adapter now and prove one transfer before building cargo.

**Done when:** Terminate and restart around the transfer commit: either all money/inventory changes exist or none do, and retrying the same action cannot duplicate it.

### 36. Versioned local persistence

**Task ID:** `versioned-local-persistence`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Save player, owned ship, transform, fuel, wallet, and empty cargo state using stable IDs and a versioned schema. Use temporary writes plus replacement, retain a last-known-good backup, and define who owns saving in local and hosted sessions.

**Done when:** A fresh process restores the same state; an interrupted or malformed write falls back safely without silently wiping progress.

### 37. Migration and missing content

**Task ID:** `migration-and-missing-content`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add one real migration fixture from the first save schema to a changed schema. Define safe treatment of missing ship/cargo IDs and newer unsupported save versions. Keep settings separate from progression.

**Done when:** The old fixture loads with expected values; missing content yields a visible recoverable condition, not a crash or an invented reward.

### 38. Save slots and recovery interface

**Task ID:** `save-slots-and-recovery-interface`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add profile/slot selection where appropriate, save status, a useful failure message, backup recovery, and explicit new-game handling. Protect unrelated progression files and avoid silently replacing a corrupt save with an empty one.

**Done when:** The player can distinguish new, existing, incompatible, and recoverable saves; an unwritable directory produces a visible failure without claiming a successful save.

### 39. Reconnect and lifecycle

**Task ID:** `reconnect-and-lifecycle`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Define and implement disconnect, reconnect, return-to-menu, despawn, and server-shutdown policies for the features built so far. Save at meaningful transaction boundaries. State explicitly that host migration is unsupported unless we later choose to build it.

**Done when:** Disconnecting either peer cannot duplicate ownership or money; reconnect attaches to the existing authoritative record.

### 40. Session identity and control handoff

**Task ID:** `session-identity-and-control-handoff`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement reconnect tokens or the selected authenticated identity path appropriate to the chosen scope. Define guest behavior, duplicate logins, host departure, and helm ownership after reconnect. Do not use a peer connection number as permanent account ownership.

**Done when:** A reconnecting player recovers only their permitted ship; a second connection cannot seize another player's profile or leave two active helms.

### 41. Public profile and server-switch handoff

**Task ID:** `public-profile-and-server-switch-handoff`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Model the confirmed portable public profile and separate private-world profile namespaces. Implement single active public account authority using a lease/lock and a durable departure/arrival handoff through the selected storage adapter or integration fixture. Preserve ship/cargo/job lifecycle rules and handle timeout, retry, old-server crash, and a client attempting two logins.

**Done when:** Two public servers cannot simultaneously spend or mutate the same profile; an interrupted switch restores one valid owner without duplicate money, ships, or cargo. Private-world records cannot overwrite the public account.

### 42. Foundation gate

**Task ID:** `foundation-gate`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Review and exercise the entire foundation with two local peers: spawn, sail, collide, consume fuel, disconnect, save, restart, and reconnect. Fix defects within these systems before adding cargo. Update architecture and progress records with measured results.

**Done when:** There are no unresolved blocking errors in these flows; manual-only or unavailable checks are explicitly identified.

## The first complete cargo voyage — Steps 43–57

### 43. Two test ports

**Task ID:** `two-test-ports`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Create two small reusable test ports with different IDs, spawn anchors, berth definitions, service capabilities, and safe water approaches. Use original placeholder names and shapes. Keep port scenes separate from economy logic.

**Done when:** Each port can be loaded alone and its services can be inspected from data.

### 44. Spawn clearance and recovery anchors

**Task ID:** `spawn-clearance-and-recovery-anchors`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Validate spawn volumes against shore, draft, berth reservations, existing hulls, and cargo envelopes. Add safe fallback anchors and deterministic handling of occupied spawn slots.

**Done when:** Two simultaneous spawn requests cannot overlap hulls; a missing or blocked anchor gives a useful fallback or error.

### 45. Berth eligibility

**Task ID:** `berth-eligibility`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add berth detection based on ship position, speed, heading, service compatibility, and physical clearance. Put thresholds in data and explain why docking is unavailable.

**Done when:** Being nearby is insufficient when moving too fast or using an incompatible berth; a valid approach consistently enables docking.

### 46. Docking state machine

**Task ID:** `docking-state-machine`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement approaching, docking, docked, undocking, and underway states with authoritative berth reservation. Disable propulsion where appropriate and define cancellation and disconnect cleanup.

**Done when:** Two peers cannot reserve the same single-capacity berth; failed docking releases the reservation and returns to a valid state.

### 47. Cargo manifest

**Task ID:** `cargo-manifest`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Create a per-ship cargo manifest with cargo IDs, quantities, unit types, origin, destination, and acquisition/job references. Add capacity and compatibility validation without assuming all cargo shares one numeric capacity.

**Done when:** An incompatible cargo or excessive amount is rejected without changing the manifest.

### 48. Reusable operation state machine

**Task ID:** `reusable-operation-state-machine`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement a narrow reusable loading/unloading operation record with reservation, start, progress, commit, cancellation, and interruption states. Cargo-family rules provide validation and completion effects rather than a giant switch in the UI.

**Done when:** State transitions reject invalid orderings, release reservations once, and can reconstruct a pending operation without relying on animation callbacks.

### 49. Container offers

**Task ID:** `container-offers`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add a small seeded container offer source with destination, quantity, quoted reward, expiry policy, and stable offer IDs. Use explicit designed values where research is uncertain. Reserve or accept offers authoritatively.

**Done when:** Two peers cannot accept the same exclusive offer; quoted terms remain consistent under the documented acceptance policy.

### 50. Loading operation

**Task ID:** `loading-operation`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement a server-owned loading operation with time-based progress, capacity reservation, completion, and a defined cancellation policy. The UI displays progress but does not own the timer or completion.

**Done when:** Closing a menu, clicking twice, or disconnecting cannot create free cargo or leave permanent reserved capacity.

### 51. In-flight operation persistence

**Task ID:** `in-flight-operation-persistence`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Extend saves and reconnect snapshots to accepted offers, reservations, manifest entries, quote terms, and active operations. Define exactly whether each operation resumes, cancels, or completes after reconnect or restart.

**Done when:** Restart before, during, and after loading completion never loses paid cargo, duplicates the manifest, or leaves a reservation permanently locked.

### 52. Container visuals

**Task ID:** `container-visuals`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Display container load using reusable slot layouts and lightweight instances. Derive visuals from the manifest and keep individual container physics disabled during ordinary sailing.

**Done when:** Partial and full loads look correct on both hulls; reloading reconstructs the same visuals without saving duplicate visual objects.

### 53. Delivery and payout

**Task ID:** `delivery-and-payout`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> At the correct destination berth, unload eligible container cargo and credit its accepted reward through one atomic transaction. Leave other destinations aboard. Add a clear receipt.

**Done when:** One delivery pays once; wrong-port unloading is rejected; mixed destinations preserve the undelivered portion.

### 54. Voyage lifecycle reconciliation

**Task ID:** `voyage-lifecycle-reconciliation`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Define a common cargo lifecycle matrix for cancel, abandon, despawn, ship switch, sinking, quit, disconnect, and restart. Implement the container policy and make orphan-job reconciliation run safely on session load.

**Done when:** Each lifecycle event has one outcome; active offers and cargo cannot be simultaneously refunded and delivered for a profit.

### 55. Voyage interface

**Task ID:** `voyage-interface`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add a minimal HUD, cargo list, current port/service panel, wallet display, and delivery receipt. Use state-driven updates and readable units; make pending and rejected requests visible.

**Done when:** The complete voyage is understandable without the developer overlay, and fast repeated clicks cannot trigger duplicate operations.

### 56. Service menu and navigation usability

**Task ID:** `service-menu-and-navigation-usability`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add a simple local route marker and port approach aids for the first voyage. Make service menus preserve selection, display units/price/quantity, disable unavailable actions with reasons, and handle network pending/timeouts without unsafe auto-resubmission.

**Done when:** A new tester can find the second port and understand a rejected action without using debug coordinates or console messages.

### 57. First voyage gate

**Task ID:** `first-voyage-gate`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Build and export the first complete playable voyage. Verify start, spawn, accept, load, sail, dock, unload, earn, save, quit, and resume. Repeat with two peers and interruptions during loading and payout. Fix failures before more cargo families.

**Done when:** An exported build completes two consecutive voyages and restores correctly after restart. Andy can judge ship feel and the loop before expansion.

## Economy, ownership, and ship care — Steps 58–67

### 58. Refueling service

**Task ID:** `refueling-service`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add propulsion refueling at eligible berths with a quote, custom quantity, tank-space checks, and atomic payment. Distinguish propulsion fuel from tradeable cargo fuel everywhere.

**Done when:** Insufficient funds, a full tank, and repeated requests cannot waste money or overfill the tank.

### 59. Impact damage and recovery

**Task ID:** `impact-damage-and-recovery`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Convert validated impacts and grounding into configurable damage and sinking. Apply the confirmed sinking policy: lose current cargo, retain ship ownership, and charge a recovery fee on every ship including the starter. Implement exactly-once cargo removal, affected-job cleanup, paid recovery, and a safe return location. Propose a persisted recovery balance repaid from later earnings for insufficient funds; no fee waiver or free starter recovery.

**Done when:** Sinking charges once and removes cargo once; retry/reconnect cannot restore lost cargo or avoid the fee. An insolvent account can resume earning while its full recovery charge remains recorded.

### 60. Component wear

**Task ID:** `component-wear`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add engine, hull, and machinery condition with configurable wear and performance curves. Keep long-term wear separate from immediate damage. Use researched thresholds only as candidate tuning, and document our selected wear clock.

**Done when:** Changing condition affects only its specified performance channel; offline, docked, and paused wear follow the documented rule.

### 61. Damage and wear visual separation

**Task ID:** `damage-and-wear-visual-separation`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add inexpensive visual damage/condition feedback and optional rust by hull condition. Rebuild it from authoritative state; keep visual thresholds configurable and independent of economic calculations.

**Done when:** Visual state survives reload and does not mutate hull statistics or shared materials on other ships.

### 62. Repair service

**Task ID:** `repair-service`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add itemized damage repair and component maintenance quotes at compatible services. Use per-ship configurable costs and integer-currency rounding through the transaction path.

**Done when:** The charged amount matches the accepted repair and restored condition; repair can never exceed its maximum.

### 63. Ship catalog and purchase

**Task ID:** `ship-catalog-and-purchase`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add an earned-money catalog with a few small progression ships, preview data, affordability checks, and purchase confirmation. Create an owned-ship instance separately from its shared definition.

**Done when:** Buying twice creates two distinct owned IDs; duplicate network requests still purchase only once.

### 64. Fleet inspection and comparison

**Task ID:** `fleet-inspection-and-comparison`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add readable ship statistics, cargo compatibility, operating condition, ownership, name, and preview to fleet/catalog screens. Show unavailable acquisition states distinctly from ordinary purchases.

**Done when:** The player can choose an appropriate ship for a cargo family without confusing DWT, hold count, and actual cargo capacity.

### 65. Fleet spawn and switching

**Task ID:** `fleet-spawn-and-switching`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add fleet selection, valid spawn slots, active-ship switching, and despawn rules for loaded or damaged ships. Preserve fuel, cargo, condition, and transform according to the written lifecycle policy.

**Done when:** Switching ships cannot reset fuel, repair damage for free, duplicate cargo, or spawn overlapping hulls.

### 66. Resale and voyage accounting

**Task ID:** `resale-and-voyage-accounting`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add ship resale with explicit loaded-ship restrictions and configurable valuation. Add gross revenue, acquisition cost, fuel, repair, and net voyage reporting without treating revenue as profit.

**Done when:** Selling cannot leave orphan cargo/jobs or an unusable account; the receipt reconciles to wallet changes.

### 67. Economy gate

**Task ID:** `economy-gate`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Run short repeatable progression scenarios from a new save through the first upgrade. Measure voyage duration, operating cost, and failure recovery. Tune a small useful progression rather than importing all research prices blindly.

**Done when:** The first upgrade has a recorded target time; no loop creates unlimited money through resale, reloads, or repeated requests.

## The other priority cargo families — Steps 68–87

### 68. Bulk capacity model

**Task ID:** `bulk-capacity-model`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Extend ship capacity with bulk holds and commodity compatibility. Add grain, coal, ore, and limestone as data, with explicit quantities and mixing rules. Keep DWT and hold count independent.

**Done when:** Two holds can carry supported loads under the chosen mixing policy; capacity checks remain correct for containers.

### 69. Bulk earnings

**Task ID:** `bulk-earnings`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add bulk loading and delivery using recorded direct origin-destination distance and configurable port modifiers. Explain whether the displayed quote includes every modifier, and define partial discharge and rounding.

**Done when:** Sailing detours cannot raise payout; a worked numeric example matches the receipt.

### 70. Bulk service presentation and recovery

**Task ID:** `bulk-service-presentation-and-recovery`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add bulk loading/unloading presentation and commodity/hold selection through the shared operation path. Save bulk acquisition origin, quote inputs, hold allocation, and partial discharge state.

**Done when:** A partial bulk voyage survives interruption, and visual crane progress cannot finish a second economic operation.

### 71. Gas capacity and terminal compatibility

**Task ID:** `gas-capacity-and-terminal-compatibility`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add cubic-meter gas tanks, compatible commodity definitions, segregated tank rules, and pipeline capabilities. Resolve the research gas-list disagreements through an explicit launch commodity set.

**Done when:** Gas definitions validate, unsupported tank/terminal combinations fail, and container/bulk capacities remain unaffected.

### 72. Gas delivery and persistence

**Task ID:** `gas-delivery-and-persistence`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Reuse the bulk-style delivery/quote path for gas with clear units and rate modifiers. Add loading/unloading UI, timed transfer, origin records, partial quantities, and lifecycle/save rules. Do not give gas an oil market.

**Done when:** A gas voyage completes and resumes after interruption, pays the documented quote, and rejects replayed or incompatible deliveries.

### 73. Liquid trading inventory

**Task ID:** `liquid-trading-inventory`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add barrel-based oil cargo with an acquisition lot/cost record and custom quantities. Implement one fixed-price buy/sell port pair first through atomic transactions.

**Done when:** Purchase cost is paid once; capacity and cash both limit purchases; realized profit can be calculated from the sold lot.

### 74. Oil market simulation

**Task ID:** `oil-market-simulation`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement a configurable market model with update cadence, port offsets, bounded supply/volume effects, and quote expiry. All our public servers must share one authoritative market; prices may vary by port but the same port has the same market state across public servers. Private hosts simulate a separate market. Use no live external feed or real-money dependency.

**Done when:** Port-specific prices are consistent across public servers, expired quotes are handled explicitly, and private trading cannot affect the public market.

### 75. Shared public oil market service

**Task ID:** `shared-public-oil-market-service`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Connect the public market model to durable centralized state through the selected service/storage adapter. Serialize concurrent updates, version quotes, make trade retries idempotent, and integrate quote acceptance with authoritative account settlement. Test two server processes and temporary market-service failure. Private hosts use isolated state through the same contract.

**Done when:** Two public servers observe one ordered market history; no duplicate settlement occurs across retries or disconnects, and a market outage fails safely rather than inventing local public prices.

### 76. Oil market interface and lot accounting

**Task ID:** `oil-market-interface-and-lot-accounting`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add underway price inspection, per-port timestamps, quote expiry feedback, custom quantity controls, and a trade receipt. Specify a lot-cost allocation policy for partial sales and preserve it through saves.

**Done when:** A partial sale reconciles acquisition cost and remaining lots; displayed stale prices cannot silently become a different accepted trade.

### 77. Refinery processing

**Task ID:** `refinery-processing`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add refinery submission, processing progress, and crude-to-cargo-fuel conversion with configurable yield, storage bounds, fractional remainder policy, and save behavior. Start with one refinery.

**Done when:** Repeated submissions, restarts, and fractional inputs cannot create more output than the selected yield allows.

### 78. Shared refinery stock

**Task ID:** `shared-refinery-stock`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Use one authoritative public refinery inventory across our public servers. Store each physical refinery's stock under a stable refinery ID so the same refinery is consistent across servers; private hosts keep separate inventories. Implement durable processing/stock credits and concurrent withdrawals with transaction IDs, quote/cost rules, and clock/restart policy. Exercise two public server processes and a private host.

**Done when:** Two servers cannot withdraw the same public stock; retry or restart cannot duplicate refinery output, and private stock cannot enter public progression. Shared inventory persists independently of a game server's scenery or lifetime.

### 79. Cargo fuel transport and sale

**Task ID:** `cargo-fuel-transport-and-sale`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement withdrawing/loading, transporting, and selling refined cargo fuel as its own commodity through eligible pipelines. Add commodity-menu selection, capacity, price, acquisition records, and partial quantities; do not confuse it with propulsion refueling.

**Done when:** A complete refinery-to-sale voyage produces the expected wallet change and resumes correctly; cargo-fuel sales never alter the propulsion tank.

### 80. Heavy-load jobs

**Task ID:** `heavy-load-jobs`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add offshore heavy-load pickup/delivery jobs with stable payload IDs, allowed lifter types, reward terms, and zone reservations. Begin with one simple block payload and one lifter.

**Done when:** Two lifters cannot claim the same payload; cancelling or reconnecting cannot duplicate job rewards.

### 81. Lifter submerge controls

**Task ID:** `lifter-submerge-controls`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement deck lowering/raising and alignment checks for the test lifter. Use a controlled carrying attachment after a validated pickup rather than unconstrained stacked rigid-body physics.

**Done when:** Pickup needs a valid stationary/aligned state; raising outside tolerance provides feedback and cannot attach distant payloads.

### 82. Heavy transport lifecycle

**Task ID:** `heavy-transport-lifecycle`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add attachment, loaded draft/mass effects, offshore delivery, release, failure recovery, and persistence of the heavy job. Keep payload physics disabled or constrained while carried as the prototype supports.

**Done when:** The same payload survives save/reconnect and delivers once; hull destruction or despawn follows an explicit recovery rule.

### 83. Heavy job presentation and variants

**Task ID:** `heavy-job-presentation-and-variants`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add offshore waypoint guidance, alignment feedback, load limits, pickup/delivery cues, and a few payload variants through definitions. Verify each payload envelope against the lifter and world transition rules.

**Done when:** The player can complete a heavy job without developer instructions, and a second payload type requires no rewrite of basic attachment or payout logic.

### 84. Cargo compatibility matrix

**Task ID:** `cargo-compatibility-matrix`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Exercise every priority cargo family across valid and invalid ships and services. Add focused regression scenarios for partial quantities, full capacity, interruption, rounding, and duplicate actions. Split any family-specific special cases out of unrelated cargo code.

**Done when:** Containers, bulk, gas, oil, cargo fuel, and heavy lifting each complete their own voyage without breaking another family.

### 85. Content extension rehearsal

**Task ID:** `content-extension-rehearsal`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Use the existing tools to add one new commodity, one conventional ship, and one port without editing core transaction, save, or generic ship-controller logic. Document exactly where configuration is sufficient and where genuinely new behavior needs code.

**Done when:** New records load, validate, save, and function; the exercise reveals and fixes accidental hard-coded IDs.

### 86. Priority cargo balance

**Task ID:** `priority-cargo-balance`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Compare net income per minute, upfront capital, operating costs, travel time, and risk across the priority families. Tune each toward a useful role and define starter access to them.

**Done when:** A saved table of measured example voyages explains why each cargo family is worth playing.

### 87. Cargo milestone gate

**Task ID:** `cargo-milestone-gate`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Export a playable build with all priority cargo families. Have Andy complete representative voyages and record handling, interface, and pacing issues. Fix blocking issues before building the large world.

**Done when:** Each family works in the exported build and save format; unresolved unknowns are documented as deliberate designs or remaining issues.

## World expansion and navigation — Steps 88–101

### 88. World layout and traversal budget

**Task ID:** `world-layout-and-traversal-budget`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Design an original compact regional map with travel-time targets, cargo services, progression routes, shortcuts, and ship-size constraints. Use the research as inspiration; do not copy its distances blindly into differently scaled geometry.

**Done when:** The planned route lengths, top speeds, and time scale agree numerically before detailed scenery is built.

### 89. Region loading

**Task ID:** `region-loading`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement bounded region loading/unloading around the selected coordinate strategy. Keep economic and job state separate from scenery nodes, and define transitions for ships, passengers, and attached loads.

**Done when:** Unloading scenery does not delete cargo/jobs; crossing a boundary preserves ship and payload state without duplication.

### 90. Transition and streaming recovery

**Task ID:** `transition-and-streaming-recovery`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Persist pending region transitions and define rollback/fallback locations if target scenery fails to load. Handle travel envelopes including passengers, furniture anchors, and carried payloads; ensure source and destination cannot both own the same entity.

**Done when:** An interrupted transition restores one valid ship with the same cargo/job state and a usable camera.

### 91. Port authoring kit

**Task ID:** `port-authoring-kit`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Build reusable pier, berth, pipeline, crane, spawn, depth, and navigation-marker components with editor validation. Add one new full-service port using the kit.

**Done when:** The port has correct services, collision, spawn clearance, and save IDs without custom gameplay code.

### 92. Distance and route data validation

**Task ID:** `distance-and-route-data-validation`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Create a validated port-distance service derived from our selected map geometry and distance policy. Distinguish payout separation, sailed distance, navigable route length, and approximate ETA. Validate reachability by relevant ship constraints.

**Done when:** The same service supplies quote and map distance where appropriate; unreachable cargo destinations are not generated as ordinary valid jobs.

### 93. Map and waypoints

**Task ID:** `map-and-waypoints`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add a readable world map, current position, port/service filters, waypoints, bearing, distance, and ETA based on our game scale. Mark ETA assumptions rather than promise arrival through obstacles.

**Done when:** Markers match world positions in every region; a simple straight voyage matches the ETA within a documented tolerance.

### 94. Channels and constraints

**Task ID:** `channels-and-constraints`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add one canal or narrow channel with depth/width limits and approach markers. Add configurable administrative restrictions separately from collision and draft.

**Done when:** A small ship can traverse; an oversized or over-draft ship receives useful warning and cannot bypass a closed obstacle.

### 95. Moving infrastructure

**Task ID:** `moving-infrastructure`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add one lock, gate, or movable bridge with reservation, animation, collision, and interruption handling. Make its authoritative state visible to nearby peers.

**Done when:** Two ships cannot produce contradictory open/closed states; disconnect and restart do not permanently jam the passage.

### 96. Environment

**Task ID:** `environment`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add day/night, clear, rain, fog, and storm presentation with configurable visibility and weather settings. Introduce physical wind/current effects only as a separately measured gameplay decision.

**Done when:** Weather does not silently change reward or propulsion rules; navigation remains playable on the lowest supported visual setting.

### 97. World navigation feedback

**Task ID:** `world-navigation-feedback`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add buoys, lights, berth labels, shallow-water warnings, and clear region-boundary indicators. Verify readability in fog/night and at the lowest supported settings.

**Done when:** The longest launch route can be navigated without debug overlays, including a constrained approach in poor visibility.

### 98. World performance

**Task ID:** `world-performance`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Profile ship count, container rendering, scenery, water, collision, and loading on the target hardware. Add LOD, visibility ranges, instancing, and reduced update rates only where measurements justify them.

**Done when:** The agreed frame-time and memory budget holds in a documented worst-case port, including a region transition.

### 99. World content batches

**Task ID:** `world-content-batches`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Populate the agreed launch ports and fleet in small reviewed batches using the authoring kit. Give each port valid services and routes, and each ship valid capacity, collision, scale, spawn, and handling. Keep staff/retired research records out of the normal shop by default.

**Done when:** Every batch passes definition validation and a representative spawn/load/deliver check before the next batch.

### 100. Fleet and port audit

**Task ID:** `fleet-and-port-audit`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Run validation across every selected launch hull, cargo service, berth, route, and spawn. Check model scale, camera range, loaded draft, attachment layout, mesh/collision alignment, economy data, and IDs. Keep a per-content-item readiness record.

**Done when:** No item reaches the release catalog merely because its model loads; each selected item passes its applicable voyage and service checks.

### 101. World gate

**Task ID:** `world-gate`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Play the longest intended route with a large loaded ship, including a constrained passage and a region transition. Restart at the difficult points and repeat with another peer.

**Done when:** No precision instability, missing berth, broken save, or stranded progression blocks the route.

## Basic customization, trading, and onboarding — Steps 102–109

### 102. Names and paint

**Task ID:** `names-and-paint`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add earned/included ship naming, paint regions, and flags with persisted appearance and preview/confirm controls. Keep customization separate from physics definitions and preserve defaults.

**Done when:** Appearance survives spawn, save, and reconnect; one ship's paint never changes another's shared resource.

### 103. Trade offers and locking

**Task ID:** `trade-offers-and-locking`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Build invitations, eligible cash/ship selection, authoritative offer revisions, expiration, cancellation, and temporary asset locks. Exclude active/loaded ships according to the selected rule. Any offer change clears both confirmations.

**Done when:** The same ship or money cannot be promised in two simultaneous trades or spent through another menu while locked.

### 104. Trade settlement and recovery

**Task ID:** `trade-settlement-and-recovery`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement both-side confirmation of one offer revision, explicit fee arithmetic, and atomic durable settlement. Release locks on cancellation/disconnect and reconstruct or expire pending trades after restart.

**Done when:** Crash/reconnect and replayed confirmations never transfer only one side, charge twice, or leave permanent locks.

### 105. Trade interface and adversarial playtest

**Task ID:** `trade-interface-and-adversarial-playtest`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add review/confirm screens that show each side, net fees, revision changes, pending status, and final receipts. Exercise last-second offer changes, concurrent purchase/resale attempts, disconnect, and timeouts.

**Done when:** Both testers can verify exactly what they accept; changed offers cannot settle under old confirmations.

### 106. Achievements and progression rewards

**Task ID:** `achievements-and-progression-rewards`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add a small earned achievement system triggered by authoritative events, with idempotent grants and persisted progress. Include first delivery, first upgrade, and cargo-family milestones.

**Done when:** Reloading or replaying an event cannot grant the same reward twice; criteria match visible progress.

### 107. Economy event and reward audit

**Task ID:** `economy-event-and-reward-audit`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Audit all reward-producing events, ledger receipts, achievement grants, and cancellation/refund paths together. Ensure offline/local profile policy cannot accidentally create a trusted online reward source.

**Done when:** Delivery plus achievement plus reconnect cannot duplicate money or grant incompatible progression; wallet totals reconcile to accepted ledger events.

### 108. Onboarding

**Task ID:** `onboarding`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Build a short guided first voyage using the real controls, ports, and transaction systems. Teach fuel, docking, cargo, payout, and recovery without a separate fake tutorial economy.

**Done when:** A new tester reaches a completed delivery and understands how to continue without developer intervention.

### 109. Player experience gate

**Task ID:** `player-experience-gate`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Test simple names/colors/flags, trading, and onboarding together in an exported multiplayer build. Fix confusing states and persistence failures before public-service work. The first release is helm/ship-control only; walking, boarding, passengers, and furniture are deferred.

**Done when:** Both players can complete onboarding, customize a ship, and trade safely without a walking-character dependency.

## Online deployment and a shippable core game — Steps 110–128

### 110. Deployment readiness review

**Task ID:** `deployment-readiness-review`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Revisit the online architecture already chosen at the foundation. Confirm the tested player count, hosting path, account scope, persistence, operating constraints, and applicable service branches. Propose a scoped change only if measurements or Andy's requirements justify it.

**Done when:** Deployment does not silently change ownership/save semantics; any architecture change has an explicit migration and retest plan.

### 111. Server build

**Task ID:** `server-build`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Export and run a headless server for the selected architecture, separating presentation from simulation. Add configuration, graceful shutdown, logs, and world-save loading. If public dedicated hosting is deferred, prove it locally without deploying services.

**Done when:** Two clients connect to the headless process, sail, and complete a cargo transaction with no renderer dependency.

### 112. Network relevance and late join

**Task ID:** `network-relevance-and-late-join`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Limit world/ship replication to the state each peer needs and implement a consistent late-join snapshot followed by live updates. Add spawn/despawn ordering and content/protocol compatibility checks.

**Done when:** Joining during a loading operation or region transition reconstructs a coherent world, and bandwidth is measured at the intended peer count.

### 113. Player identity

**Task ID:** `player-identity`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> For persistent public worlds, implement the selected authenticated identity provider and server-owned progression; do not trust a client-supplied account ID or a local save as proof of ownership. For invited sessions, implement clearly scoped session identities instead and document the limits.

**Done when:** A client cannot impersonate another persistent account or overwrite another player's save. No custom password scheme is invented.

### 114. Durable online transactions

**Task ID:** `durable-online-transactions`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> For persistent dedicated worlds, move durable economy operations to the selected transactional storage and persist idempotency records. Prove crash recovery across cargo delivery, purchase, refinery withdrawal, and trading; local/LAN deployments retain the validated session-save policy.

**Done when:** Restarting at each commit boundary yields either the entire transaction or none of it, without duplicate awards. Cross-server transfers remain out of scope unless designed separately.

### 115. Backup and restoration rehearsal

**Task ID:** `backup-and-restoration-rehearsal`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Create and restore a real backup of the selected authoritative storage into an isolated session. Document backup frequency, recovery boundaries, operation IDs, and schema compatibility. Avoid restoring production over a live world as part of this test.

**Done when:** The restored world has reconciled ownership, jobs, wallets, refinery stock, and transaction history, with a stated recovery point.

### 116. Server directory service

**Task ID:** `server-directory-service`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement a minimal versioned directory for dedicated-server registration, heartbeat, expiration, compatible version metadata, player counts, and list queries. Define trusted registration, rate limits, stale-entry cleanup, and host opt-in policy. Keep the service separate from game simulation and test with local fixtures before public deployment.

**Done when:** A valid server appears, updates, and expires correctly; spoofed or incompatible listings are handled under the documented policy. The directory does not imply NAT traversal.

### 117. Multiplayer server browser

**Task ID:** `multiplayer-server-browser`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Build the confirmed Multiplayer tab with server list, name, population/capacity, version compatibility, status, measured latency where feasible, refresh, selection, join, and connection feedback. Include host-session and direct-connect paths. Integrate with the directory and selected internet connection method.

**Done when:** The browser joins a real compatible test server, handles full/stale/incompatible entries, and can host a player session. Listing a private host requires explicit host opt-in.

### 118. Connection experience

**Task ID:** `connection-experience`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add the appropriate connect/disconnect UI, timeouts, full-session rejection, reconnection feedback, and compatibility/version checks. If internet play is chosen, select and test direct connections or a relay/NAT solution; do not mistake localhost success for internet support.

**Done when:** A remote tester connects through the actual supported path, or the build is explicitly labelled local/LAN only.

### 119. Host and server operational controls

**Task ID:** `host-and-server-operational-controls`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add orderly shutdown/drain behavior, configurable limits, log rotation, actionable error reporting, and minimal admin recovery for the selected deployment. Keep admin actions permission-checked and auditable.

**Done when:** Stopping the server during play releases or persists work under the documented policy; logs do not grow without bound or expose secrets.

### 120. Abuse and contention checks

**Task ID:** `abuse-and-contention-checks`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Exercise bounded action rates, malformed quantities, unauthorized IDs, stale quotes, replayed requests, berth conflicts, shared stocks, and trade interruptions. For public communication, define moderation/reporting before adding chat.

**Done when:** Invalid requests do not mutate state or stall the simulation; multi-client contention has no duplication path in tested cases.

### 121. Audio implementation and mix

**Task ID:** `audio-implementation-and-mix`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement spatial engine, horn, collision, water, weather, loading, and UI audio with volume buses, distance limits, and voice-count limits. Track rights/source for every asset and provide fallback behavior.

**Done when:** Audio responds to gameplay without driving authoritative state; a busy port stays within audio/performance limits.

### 122. Interface and accessibility pass

**Task ID:** `interface-and-accessibility-pass`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Review every supported screen for UI scaling, keyboard navigation, remapping, focus, contrast, units, error feedback, loading states, and destructive-action confirmation. Add reduced camera motion and readable low-quality settings where relevant.

**Done when:** The full game loop is usable at supported resolutions without clipped controls, unreadable prices, or input leaking into the helm.

### 123. Art replacement and import regression

**Task ID:** `art-replacement-and-import-regression`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Replace the agreed launch placeholders with original/licensed art in small batches. Preserve stable IDs, hull scale, anchors, collisions, deck traversal, materials, and LOD budgets. Reimport and check the affected ship/port each time.

**Done when:** The launch art set is explicit and each replacement passes gameplay checks; appearance upgrades cannot silently move service triggers or cargo slots.

### 124. Soak and regression

**Task ID:** `soak-and-regression`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Run an exported multi-client session through repeated voyages, region changes, purchases, refinery use, and reconnects. Measure memory, frame time, server tick time, bandwidth, and save growth over a stated duration.

**Done when:** No unbounded growth or critical state corruption appears in the measured session; any remaining capacity limits are documented.

### 125. External playtest and defect triage

**Task ID:** `external-playtest-and-defect-triage`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Give the packaged build to a fresh tester within the chosen distribution scope. Observe onboarding, navigation, purchases, every priority cargo family, recovery, and multiplayer where supported. Classify blockers, serious defects, and polish separately.

**Done when:** Critical failures are fixed and retested. The next implementation request addresses the highest-impact defect rather than adding unrelated features.

### 126. Release candidate

**Task ID:** `release-candidate`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Freeze features and verify fresh install, first launch, tutorial, every priority cargo family, longest route, save migration, backup recovery, settings, multiplayer scope, and export packaging. Prepare release notes and known issues.

**Done when:** A clean machine or equivalent isolated setup can install and play the packaged build; every supported feature has an actual result recorded.

### 127. Upgrade, install, and rollback rehearsal

**Task ID:** `upgrade-install-and-rollback-rehearsal`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Install the candidate from a clean package, then upgrade a representative earlier build/save. Verify settings paths, content lookup, migrations, platform permissions, version messages, and a safe rollback/backup procedure. Produce a checksum and asset-license inventory.

**Done when:** The package is reproducible and an upgrade does not silently overwrite progression; rollback limits after schema migration are explained.

### 128. Core release and extension guide

**Task ID:** `core-release-and-extension-guide`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Package the completed core version and write a practical extension guide for adding a ship, port, cargo definition, service, job behavior, and UI panel. Include one worked example and a backlog for Andy's original features. Capture a recoverable release tag.

**Done when:** The agreed version-1 checklist is satisfied, and one small original feature can be added without rewriting the foundation.

## Vehicle transport and rockets — after the core game — Steps 129–142

### 129. Vehicle transport design

**Task ID:** `vehicle-transport-design`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Define Ro-Ro loading with representative drivable vehicles, ramp compatibility, completion rules, and failure recovery. Keep nominal commercial capacity separate from the number of cars physically driven. Reuse berth and cargo job infrastructure.

**Done when:** A small design and test scene specify the full loading/unloading lifecycle before car mechanics enter the main game.

### 130. Vehicle driving prototype

**Task ID:** `vehicle-driving-prototype`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Build one simple car with predictable driving, brakes, reverse, camera, ramp collision, water recovery, and authority. Test it on the proven moving-deck setup before adding many cars.

**Done when:** A car can drive onto a docked carrier without jitter, clipping, uncontrolled bouncing, or ownership ambiguity.

### 131. Networked vehicle ramp feasibility

**Task ID:** `networked-vehicle-ramp-feasibility`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Test a remotely controlled representative car boarding a docked carrier under latency, with explicit control handoff between character, car, and ship. Define car attachment/authority while commercially stowed.

**Done when:** The networked car cannot keep a conflicting controller, fall through the ramp, or remain as duplicate physics cargo after loading.

### 132. Ro-Ro operations

**Task ID:** `ro-ro-operations`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement representative-car loading/unloading, carrier ramps, progress, cancel/reposition, lost-car handling, reward settlement, and persistence. Keep cargo quantity authoritative and independent of disposable car visuals.

**Done when:** Finishing, cancelling, reconnecting, or losing a car cannot duplicate cargo or payout.

### 133. Vehicle operation interruption audit

**Task ID:** `vehicle-operation-interruption-audit`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Test loading progress, cancel/reposition, missing cars, occupied seats, despawn, sinking, disconnect, and server restart across Ro-Ro operations. Persist cargo facts separately from temporary representative vehicles.

**Done when:** Every interruption produces a documented valid state with no duplicate commercial capacity, trapped player, or repeat reward.

### 134. Mixed cargo ships

**Task ID:** `mixed-cargo-ships`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add a container/Ro-Ro ship with distinct simultaneous capacities and explicit service selection. Verify both cargo operations independently and together.

**Done when:** Loading cars never overwrites containers; save/reload restores both and docking UI chooses a valid service explicitly.

### 135. Vehicle milestone

**Task ID:** `vehicle-milestone`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Integrate a small vehicle fleet/terminal set and balance its full voyage. Export and verify onboarding hints, permissions, recovery, save, and multiplayer behavior.

**Done when:** A tester completes a mixed-cargo and a dedicated Ro-Ro voyage in the packaged build.

### 136. Rocket contract model

**Task ID:** `rocket-contract-model`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Define rocket models, mission types, upfront costs, launch zones, deterministic server-resolved outcomes, optional recovery bonuses, and abort rules. Store accepted terms and outcome state before showing launch effects.

**Done when:** Every abort/failure/success transition has an explicit payment rule and a stable job ID; reloading cannot reroll a committed result.

### 137. Rocket mission state and persistence

**Task ID:** `rocket-mission-state-and-persistence`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement the mission transition table and durable accepted terms/outcome records without launch visuals first. Separate upfront payment, launch payment, recovery bonus, abort, expiry, and failure in authoritative state.

**Done when:** A table-driven check covers every valid and invalid transition, including restart before and after each financial commit.

### 138. Launch sequence

**Task ID:** `launch-sequence`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Implement tower preparation, stationary/alignment checks, countdown, launch, abort, and rocket camera presentation on one launch ship. Keep visual effects separate from payment and job completion.

**Done when:** Closing the camera or disconnecting cannot alter committed mission outcomes; an invalid launch cannot bypass the zone check.

### 139. Rocket recovery

**Task ID:** `rocket-recovery`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add the selected recovery interaction and its separate bonus, failure states, timers, save behavior, and restart handling. Use controlled presentation for distant flight rather than assuming map-scale rigid-body simulation.

**Done when:** Successful launch payment and recovery bonus settle independently and at most once, under the published contract rules.

### 140. Launch presentation and control recovery

**Task ID:** `launch-presentation-and-control-recovery`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Finish rocket camera transitions, countdown/tower feedback, effects quality settings, sound, and return-to-helm handling. Exercise menu close, owner disconnect, ship removal, abort, and region changes while viewing a rocket.

**Done when:** Every sequence returns the player to a usable view/control state, and low-quality effects do not alter mission outcomes.

### 141. Rocket milestone

**Task ID:** `rocket-milestone`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Add the agreed launch ships and mission variety in small batches. Test every state transition, reward combination, interruption, and camera return in an exported multiplayer build.

**Done when:** A tester can complete, abort, fail, and recover missions without stuck controls, repeat rewards, or invalid saves.

### 142. Expanded release

**Task ID:** `expanded-release`  
**Prerequisite:** The preceding applicable task is accepted; revisit earlier dependencies if its checks no longer pass.

**Ask me:**

> Run the core regression suite plus vehicle, mixed-cargo, and rocket scenarios. Migrate a pre-expansion save, export the expanded build, update the extension guide, and preserve a release tag.

**Done when:** An existing player's fleet/economy survives the expansion, and all newly supported cargo families have verified packaged-build flows.

## Cross-system coverage checks

These are regression responsibilities for the relevant tasks and gates, not additional features. Apply each row to every applicable cargo/ship type; do not assume a container fix automatically covers heavy loads or trading.

| System boundary | Required checks before its gate passes |
| --- | --- |
| Definitions ↔ runtime instances | No mutable shared state; missing/duplicate IDs diagnosed; content removal handled |
| Input ↔ UI ↔ helm | Focus, pause, rebind, seat exit, and camera switching cannot create conflicting controllers |
| Simulation ↔ presentation | Cameras, water, cranes, rust, and effects cannot commit money or advance jobs |
| Hull ↔ world | Model scale, collision, depth, loaded draft, spawn clearance, region extent, maximum speed |
| Character/car ↔ moving ship | Stand/drive/seat transitions, turn, latency, attachment, despawn, overboard recovery |
| Ship ↔ service | Eligibility, reservations, permissions, capacity, contention, cancellation, cleanup |
| Quote ↔ operation | Stable terms, expiry, capacity/cash reservation, exactly-once commit, cancellation policy |
| Manifest ↔ visuals | Partial loads, mixed destinations, multiple holds/tanks, reconstruction after reload |
| Cargo ↔ lifecycle | Quit, disconnect, restart, switch, despawn, sinking, abandonment, partial delivery |
| Money ↔ goods ↔ storage | No half-transfers; committed action IDs survive the required restarts; receipts reconcile |
| Refinery ↔ shared stock | Yield/rounding, ownership policy, concurrent withdrawal, processing clocks, restart |
| Trade ↔ shop/resale | Asset locks, changed offers, disconnect, replay, fees, atomic settlement |
| World streaming ↔ saved entities | One owner for each entity, passengers/payload preserved, transition failure fallback |
| Offline ↔ online progression | Explicit trusted state boundary; no accidental import of untrusted wealth |
| Client ↔ authority | Ownership checks, bounded inputs, late join, compatibility, timeout, retries, rate limits |
| Art ↔ existing gameplay | Reimport preserves anchors, stable IDs, deck geometry, material isolation, LOD and collision |
| Build ↔ player installation | Matching engine/templates, clean launch, assets, settings paths, upgrade and backup |

## Decisions that must not be guessed during implementation

At the project-contract and feature-inventory tasks, resolve or explicitly schedule: target hardware/platform and controls; online session type and intended player count; profile ownership/portability; compact regional versus seamless world; intended handling feel and wave physics; launch fleet and ports; starting funds and first-upgrade time; accepted quote terms and partial-load rules; interruption/refund/recovery policies; offline clocks and refinery-stock lifetime; trade fee/eligibility rules; launch art scope; and version-1 versus expansion boundaries. The active decision record, rather than a guessed source-game number, becomes authoritative for our implementation.

## How the agent prevents omissions during each build request

Before implementation, inspect prerequisites and list the state, owner, inputs, outputs, failure paths, and affected saved records. During implementation, keep core logic separate from its UI/effects and wire it into existing lifecycle handling. Before marking complete, check ordinary play, one invalid action, a relevant interruption, persistence, and network authority where applicable. At every gate, compare implemented coverage against the agreed feature inventory and this matrix. Insert any missing work before dependent features continue.

This process aims to make development orderly. A written roadmap cannot eliminate debugging or anticipate every problem with hardware, assets, physics, or networking. Discoveries become explicit tasks with tests and checkpoints rather than improvised changes spread across the project.

## Optional later module — walking, passengers, and furniture

These tasks are deferred by Andy's first-release choice. They are not prerequisites for the core release, vehicle transport, or rockets unless a later mechanic explicitly requires them. Keep the stable IDs and re-audit their dependencies when the module is chosen.

### Deferred: Walking on ships risk prototype

**Task ID:** `walking-on-ships-risk-prototype`

**Ask me when selected:**

> Prototype a walking character on a moving and turning deck, helm entry/exit, and safe return to ship. Test the chosen moving-platform approach with both hulls. Keep this isolated until stable; record whether deck walking is ready for the main game.

**Acceptance:** A character can stand, walk, and re-enter the helm during a turn without sliding through the deck or being launched. Failure blocks passenger/furniture expansion, not basic cargo work.

### Deferred: Deck walking integration

**Task ID:** `deck-walking-integration`

**Ask me when selected:**

> Integrate the proven moving-deck character and helm entry/exit into the main session. Add safe spawning, falling-overboard recovery, and rules for unattended ships. Revisit the isolated prototype if networking exposes instability.

**Acceptance:** A local and remote character can walk on a turning ship and return to the helm without duplicate control or falling through the deck.

### Deferred: Passenger permissions

**Task ID:** `passenger-permissions`

**Ask me when selected:**

> Add owner-controlled boarding, helm, and edit permissions. Validate each on the authority, and implement permission revocation while another player is aboard.

**Acceptance:** A passenger cannot seize the helm or edit without permission; revoking access leaves both players in valid states.

### Deferred: Character and seating lifecycle

**Task ID:** `character-and-seating-lifecycle`

**Ask me when selected:**

> Add networked sitting/standing, safe seat exit, scene transition attachment, overboard recovery, and reconnect while aboard another owner's ship. Persist only the character state required by the selected session model.

**Acceptance:** A passenger cannot stay attached to a deleted ship, inherit helm control, or duplicate a character by reconnecting.

### Deferred: Furniture placement

**Task ID:** `furniture-placement`

**Ask me when selected:**

> Add a small furniture catalog and placement preview with deck bounds, overlap rules, snapping, rotation, item limits, and confirm/cancel. Start with static decorative objects and a single seat.

**Acceptance:** Invalid placements cannot commit; repeated requests cannot charge twice or exceed the item limit.

### Deferred: Furniture lifecycle

**Task ID:** `furniture-lifecycle`

**Ask me when selected:**

> Persist furniture by stable IDs and ship-local transforms. Add move, remove, undo policy, ownership checks, and a safe fallback helm so customization cannot remove all controls.

**Acceptance:** Moving the ship does not detach furniture; deleting the last control still leaves a way to operate the ship.

### Deferred: Furniture contention and performance

**Task ID:** `furniture-contention-and-performance`

**Ask me when selected:**

> Validate concurrent edits, edit permission revocation, item ID uniqueness, transform bounds, refunds if any, and update/save limits. Batch cosmetic network changes and keep static furnishings out of unnecessary physics updates.

**Acceptance:** Two editors cannot spend/refund the same item twice, and a maximum-supported furnished ship meets the agreed performance/save-size budget.

### Deferred: Functional furnishings

**Task ID:** `functional-furnishings`

**Ask me when selected:**

> Add seats, lights, doors, and a map display as small reusable behaviors. Measure update and network costs before expanding the catalog.

**Acceptance:** Each item works on a moving ship, obeys permissions, and reconstructs correctly after reload.

## Adding your own features without derailing the project

Use this request whenever you have a new idea:

> Evaluate this feature against our current build: [idea]. Explain its player benefit, affected systems, new state and save fields, authority/permission needs, content/UI needs, and smallest playable version. Place it after the earliest milestone that supplies its dependencies. Preserve current progression and give it an acceptance check. Implement only after that scope is clear.

If the idea changes a fundamental assumption—seamless ocean, mobile controls, persistent public worlds, physical waves, or walkable moving interiors—evaluate it as soon as it is raised, before building more on the old assumption. Ordinary content and optional side activities can wait for a gate. There is no need to freeze creativity until all planned requests are complete.

## Definition of the first finished game

The core release is Step 128. It is complete only when the chosen scope is recorded and all of the following work in the packaged build:

- A new player can learn the controls, complete deliveries, recover from mistakes, and afford meaningful upgrades.
- Every priority cargo family completes its full acquisition/loading, travel, delivery/sale, and payment lifecycle.
- Fuel, repairs, maintenance, ownership, spawning, and resale agree with the economy and save rules.
- The launch world and fleet are selected explicitly; all selected content is validated and navigable.
- Supported multiplayer permissions and shared resources remain coherent under concurrent actions and reconnects.
- Saves survive restart, the tested interruption cases, and the supported migration path.
- Settings, audio, interface, and performance meet the recorded target on supported hardware.
- Installation/export instructions, known issues, asset provenance, and extension instructions are included.

The expanded release is Step 142 and adds Ro-Ro/mixed cargo and rocket missions. Optional aircraft, historical systems, and Andy's new features get their own accepted scope and completion checks.

## What to ask first

> Do Step 01 from Shipping_Lanes_Godot_Build_Roadmap.md. Use Shipping_Lanes_Research_Reference.md as the mechanics evidence, preserve our priority cargo scope, and follow the working agreement. Produce the game specification and identify only the decisions that materially affect the foundation. Do not build gameplay yet.

## Evidence and limits

Mechanics input: Shipping_Lanes_Research_Reference.md, current saved revision read October 18, 2026. Its current wiki findings, caption evidence, historical behavior, and unresolved gaps retain their original evidence labels. This roadmap is a proposed original implementation sequence, not an assertion that hidden source-game algorithms are known. Undocumented rates and formulas require an explicit design choice or measurement before implementation; do not fill them with plausible-looking “facts.”

Official Godot documentation checked for the engineering foundations:

- [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html): focused reusable scenes and explicit dependencies support the proposed composition approach.
- [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html): custom data resources support catalog definitions. Keep per-instance mutations out of shared definitions.
- [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html): authority and RPC behavior inform the early network prototype; the API does not replace our validation and transaction design.
- [Large world coordinates](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html): distance from origin and precision choices make the early world-scale experiment necessary. Origin shifting and custom precision builds have tradeoffs.
- [Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html): persistence examples provide a starting point; schema migrations, atomic economy commits, and crash recovery are additional project requirements.

The stable documentation alias can change; The engine and hardware baseline task pins the engine version and subsequent implementation should use matching versioned documentation. No Godot project has been built or playtested as part of this planning deliverable. No fixed schedule or guarantee that all future mechanics fit without changes is implied.
