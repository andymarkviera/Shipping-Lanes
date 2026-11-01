# Shipping game — initial game specification

October 18, 2026 • Planning baseline • No gameplay implementation started

## Purpose

Create a standalone Godot shipping game with approachable ship handling, a useful earned-money economy, varied cargo work, and cartoon-style boats and ports. Build a small complete playable loop first, then expand through tested systems. Preserve room for Andy's original features without hard-coding the fleet or cargo catalog into controllers.

The research reference is evidence about Shipping Lanes. This specification records our own game's decisions. Unknown source-game details become explicit design choices rather than invented facts.

## Confirmed by Andy

| Topic | Decision |
| --- | --- |
| Development platform | Windows PC. PC is currently off; planning can continue without installation or hardware inspection. |
| Engine | Godot; pin the supported stable version at environment setup. |
| Multiplayer modes | Both player-hosted sessions and dedicated multiplayer servers. |
| Dedicated session target | Roughly 100 simultaneous players in one server/session; validate through measured load tests. |
| Server discovery | A Multiplayer tab containing a joinable server list; player hosts choose public listing or private access. |
| First-release control scope | Ship/helm controls only. Walking, boarding, passengers, and furniture are deferred. |
| Public oil market | One authoritative oil market shared across our public servers; private-host markets remain separate. |
| Refinery stock | Shared across our public servers; private-host inventories stay separate. |
| Sinking and recovery | Lose current cargo, retain ship ownership, and pay a recovery fee. No free recoveries, including for the starter ship. |
| Public progression | Money, ships, and associated owned-ship state follow the player across our public servers. |
| Private progression | Player-hosted games retain separate saves and cannot import balances or fleets into public progression. |
| World arrangement | Choose the more efficient approach; architecture recommendation below. |
| Handling | Balanced between accessibility and simulation; tune during development. |
| Starting progression | A small container starter ship. Ports are generally open from the beginning; slower starter boats take longer to reach distant ports. |
| Initial customization | Simple colors, flags, and boat name. |
| Art | Cartoon-like, relatively simple boats and ports with a comparable broad visual feel to Shipping Lanes. |
| Asset creation | The agent should help create boats and ports, not require Andy to provide every model. |
| Project location | Actual development files live on Andy's PC. |
| Testing | Agent performs available technical checks; Andy plays builds and evaluates feel and usability. |

Previously confirmed: prioritize containers, bulk, gas, oil trading/refining, cargo fuel, and heavy lifting. Vehicle transport and rockets come after the core game. Exclude real-money purchases, paid advantages, ads, and cash crates; retain earned in-game currency.

## Core player experience

Start with a small usable cargo ship and enough support to complete an initial voyage. Select cargo at a compatible service, load it, sail to a destination, dock, unload or sell, receive an accurate receipt, and use earnings toward ship progression and upkeep. Save and resume without losing or duplicating the voyage.

Do not gate ordinary ports behind levels. Geography, distance, berth compatibility, draft, fuel range, ship size, and the economics of a trip can still create practical choices. Access to a port does not mean every berth accepts every ship. Avoid creating distant starter-accessible jobs that are impossible to complete without warning or recovery.

The first playable build uses two original test ports and two simple hulls, not the full final world. Andy selected a small container ship as the starter. Its exact model, capacities, handling, and price progression will be tuned in the first playable loop.

## Recommended world architecture

Start with a compact, geographically coherent world divided into loadable scenery regions, all owned by the same session/server. A player sailing to another region remains in the same multiplayer session. Region boundaries are loading boundaries, not separate public matchmaking servers.

Keep economic state, ships, jobs, and shared inventories independent of loaded visual scenery. Load detailed shore, port meshes, and nearby actors where needed. Maintain a lightweight logical identity/position for distant ships; decide distant map visibility separately from detailed replication. Do not run full graphics or nearby-character simulation for every distant object.

This is a proposed efficiency choice, not a benchmark result. Validate it against the 100-player target and desired travel feel before detailed world production. Avoid custom double-precision builds or seamless origin shifting unless the chosen scale and tests demonstrate a need. Regions must not visibly shrink the design into isolated tiny levels; test transitions as part of normal travel.

## Multiplayer and service architecture

Use the same authoritative gameplay rules in both session types:

| Mode | Runtime owner | Intended behavior |
| --- | --- | --- |
| Player-hosted session | The host's game process runs the server alongside a local player | Players can host and others connect. Host departure ends the session initially; host migration is not a launch requirement. |
| Dedicated server | A headless server process | Players join through the Multiplayer tab. A server's configured capacity follows verified performance; roughly 100 is the design target. |

Server authority owns ship-control permissions, cargo, balances, accepted quotes, loading operations, purchases, shared refinery stocks, and trades. Clients request actions and display state. A player host can control their own local server process; this is a separate trust boundary from centrally operated progression.

### Server directory and Multiplayer tab

A joinable public server list needs a directory/discovery service as well as game servers. Plan a small versioned interface for registration, heartbeat, expiration, list query, and connection metadata. The browser shows server name, current/maximum players, compatible build/protocol, status, and measured latency where practical. Support refresh, joining, a clear error state, and direct connection as a fallback.

Dedicated servers register through the selected trusted mechanism. Player hosts explicitly choose a publicly listed or private session. Publicly listed player-hosted games still use separate private-host progression and markets; listing never grants access to public-economy saves. Private sessions are not returned by ordinary directory queries. Whether private sessions also need invitation codes or passwords is undecided.

Directory presence does not make a residential host reachable. Internet hosting needs a tested connection path: direct UDP with router configuration where applicable, or a chosen relay/NAT solution. Select that path before promising easy worldwide host-and-join. Godot supports the networking building blocks; discovery and internet reachability remain implementation work.

### Progression and identity — confirmed

Andy accepted shared progression across our public servers and separate privately hosted saves on October 18, 2026. Persist money, owned ships and their associated state through the authoritative public account service. Private hosts cannot mint wealth or ships for that public economy, and public fleet records must not be overwritten by private-host saves.

Implement one active public account session, a server-owned session lease/lock, and a durable handoff when switching public servers. The old server must settle or persist its accepted operations before the new server gains control. Define disconnect/timeout recovery and validate that retrying a switch cannot duplicate ships, cargo, or payments. A disconnected client's local files are not proof of ownership.

The exact provider/storage technology remains an implementation choice. Private progression can still be persistent within a private world; separation does not mean it resets on every join. Oil prices and public trading volume belong to one shared authoritative market across our public servers. Port-specific prices may differ, but one port has consistent market state across those servers. Market updates, quote versions, and account settlements must remain coherent under concurrent trades and retries. A failed market connection must not invent an independent public price history. Privately hosted markets are isolated. Andy also confirmed refinery stock shared across our public servers. Use stable refinery IDs so each refinery has one inventory consistent across public servers, with atomic withdrawals and durable exactly-once processing credits. Private hosts retain isolated stock. A server restart or switch cannot recreate output or reset inventory. Active offshore world-job scope remains a separate design decision.

No account provider, public server operator, machine, domain, hosting budget, or deployment has been chosen. Excluding real-money gameplay purchases does not specify how multiplayer infrastructure will be operated. Keep deployment choices open until requirements and measured resource use are known; no paid service is assumed.

### Capacity proof

Benchmark progressively at 2, 10, 25, 50, and approximately 100 simulated/real clients using representative scenarios. Test widely dispersed ships, a crowded port, concurrent cargo transactions, late joins, reconnects, and loaded/furnished hulls where supported. Record server simulation frame time, CPU/memory, inbound/outbound bandwidth, database latency if used, and a real client's frame time and motion quality.

Use network relevance/visibility filters so detailed nearby state is sent only to peers who need it. Keep distant updates cheap and avoid simulating each container as a free physical object. Test join/disconnect bursts and save growth. Synthetic clients demonstrate load, not visual comfort; retain real-client checks. Set launch capacity from evidence and keep optimizing toward the design target. Do not present an untested max-client setting as proof of 100-player support.

## Handling and ship foundation

Use inertia, finite acceleration, reverse braking, speed-sensitive turning, and docking thrusters. Keep tuning in ship definitions. Prioritize readable, repeatable docking and satisfying travel over a highly detailed hydrodynamics model.

Begin with visual waves separate from authoritative hull movement. Test depth/draft, grounding, collisions, and loaded clearance. Prototype a heavy payload early because it can influence the body, transform, and networking approach. Walking on moving decks, boarding, passengers, and furniture are deferred; ship-control play has no walking-character prerequisite. Avoid physically simulating every cargo item during ordinary transport.

Adjust acceleration, top speed, turning radius, stopping distance, game-world travel scale, fuel use, and voyage rewards together through playtesting. Changes must preserve consistent units and explicit economy formulas.

## Sinking, cargo loss, and paid recovery

Confirmed by Andy: sinking removes the current cargo and preserves ownership of the ship. Recovery always incurs an in-game fee; the starter boat has no exemption. Settle cargo loss, affected job cleanup, recovery charge, and safe relocation through an idempotent authoritative operation. Reconnecting, switching servers, or retrying cannot restore lost cargo or remove the charge. Cargo held elsewhere or unrelated owned ships are not automatically confiscated.

Recommended insolvency implementation, still subject to economy tuning: when funds are insufficient, record the full fee as a persisted recovery balance and deduct a bounded portion from later voyage earnings. The charge is never waived, but the player can regain an earning-capable ship. Show the balance and repayments on receipts and account UI. Apply the same no-free-service principle to any paid tow or refueling recovery. Define the minimum supplied fuel and its charge explicitly so a recovered ship can actually resume play. Do not invent a free fuel refill or condition reset as a hidden bonus. Decide separately what condition is restored by the recovery fee versus an additional paid repair.

Test wallet-empty accounts, repeated sinking, active jobs, purchased oil, refinery work already submitted off-ship, disconnect during recovery, and server switching. Prevent perpetual soft-locks without disguising a free recovery as a fee waiver. Fee amounts and repayment proportions are provisional until playtested.

## Art and asset creation

Create an original low-poly cartoon asset kit: simple hull silhouettes, flat or restrained stylized materials, readable paint regions, modular superstructures, cranes, piers, warehouses, tanks, buoys, and coastline pieces. Use the source game's broad readability and simplicity as reference; do not extract its models, textures, branding, or map.

The agent can create procedural/reusable Godot meshes, scene assemblies, materials, and authoring scripts. If Blender is part of the available pipeline, scripts can produce editable mesh assets. Verify actual tool availability during setup; detailed model quality still needs visual review and iteration. Do not promise imported final art before reviewing scale, silhouette, waterline, collision, attachment anchors, and lighting in Godot.

Start with one small ship, one larger hull variant, and a modular port kit. Confirm the visual style with these before producing a large fleet. Keep artistic variation separate from shared gameplay behavior. A ship's visual model can be replaced without changing its stable identity or corrupting saves.

Initial customization covers name, paint regions, and flags, saved per owned ship. Advanced furniture, walking, and passenger systems are optional later expansions and are excluded from the first release. Do not let a large furnishings catalog delay the basic game Andy described.

## Project workflow while files live on Andy's PC

No access to the powered-off PC or its files is assumed. Planning and documentation can proceed now. Once the PC is available, choose a Git repository or provide a current project archive so the agent can inspect and edit the actual version. Merely keeping files on a PC does not grant the agent access.

Preserve the project locally and use versioned checkpoints. Keep GAME_SPEC.md, the roadmap, progress/task status, and a decision record with the project. Handoffs include exact file changes, launch/test instructions, actual check results, and any checks Andy must perform. Keep source models and their provenance with the project as appropriate.

When resuming later, inspect the current project rather than regenerate it from this document. Confirm Windows version, CPU, GPU, RAM, installed Godot version, and available modeling tools then. No installation or hardware answer is needed while the PC is off.

## First-release scope and remaining decisions

The release must support the priority cargo families and complete economic/save lifecycles, reliable travel and docking, useful ship progression, basic customization, and both multiplayer session types. Public capacity and internet connection support must be explicitly tested. Launch fleet/port counts are selected after the initial prototypes and authoring kit, not copied from the full research catalog.

Still unresolved, with decision deadlines:

- Before durable progression: account provider/storage and the implementation of confirmed single-session public ownership and server-switch handoff. Implement the confirmed shared public oil market and refinery inventories with concurrent transaction/retry checks.
- Before defining the final starter economy: starting funds, paid recovery fee/repayment tuning, starter capacities, and first-upgrade pacing. The container starter and no-free-recovery rule are confirmed.
- Before finalizing network scale: intended server hardware, operating location, practical bandwidth, and test resource availability.
- Before public host-and-join: connection/relay path, directory operation, and optional invitation controls. Hosts already have the confirmed choice of public listing or private access.
- Before detailed asset production: one approved in-engine ship/port style sample.
- Before feature freeze: exact launch content and whether ship trading beyond basic customization is a release essential. Walking, passengers, and furniture are already deferred.

Rockets and car-carrying ships remain later work. Aircraft, historical quests, retired companies, and other unconfirmed side systems are optional. New original features get a small proposal, dependency placement, and acceptance checks.

## Completion and next action

This completes the initial specification draft using Andy's answers. It does not mark engine setup, networking, or any gameplay as implemented. The roadmap must now reflect both hosting modes, server discovery, and the early 100-player capacity experiment.

Public/private progression ownership is now confirmed. Ship-only first-release controls, a shared public oil market, and host-selectable listing/privacy are also confirmed. Container starter, shared public refinery stock, and paid recovery on all ships are also confirmed. Account provider/storage, actual internet connection path, and numeric economy tuning remain implementation/planning decisions. Environment setup and runtime tests wait until the PC/project is available.

## Technical references checked

- [Godot high-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html): host/client setup, authority/RPC foundations, and internet-hosting considerations.
- [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html): visibility filters and synchronization behavior support relevance experiments.
- [Dedicated server export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html): headless operation and dedicated export workflow.

These document capabilities, not a measured guarantee for our game or a complete matchmaking/account service. All architecture recommendations above remain subject to the stated prototype and acceptance checks.
