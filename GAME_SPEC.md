# Shipping Lanes — project contract

October 18, 2026 · Roadmap Step 01 · Task ID: `project-contract`

## Purpose and source rules

Build an original Windows shipping game with approachable ship handling, useful
earned-money progression, varied cargo work, and simple cartoon ships and ports.
Prove one complete voyage before expanding the world and cargo systems.

This contract consolidates Andy's supplied specification, research, roadmap, map
reference, ship rig guide, and subsequent setup confirmations. Confirmed choices
below are requirements; provisional choices are working defaults. Source-game
research is reference evidence, not a requirement for exact reproduction.
Later explicit instructions from Andy take precedence. Resolve conflicting
design records explicitly and update the decision record before dependent work.

## Confirmed scope

| Area | Requirement |
| --- | --- |
| Platform and engine | Windows PC; Godot 4.7, with installed build `4.7.2.stable.steam.ed1daf0bf` as the current baseline; typed GDScript. |
| Player controls | Ship/helm controls only for version 1. Handling balances accessibility and simulation, with readable docking and navigation. |
| Cargo | Containers, bulk, gas, oil trading/refining, cargo fuel, and heavy lifting are core release work. Cargo fuel is distinct from ship propulsion fuel. |
| Progression and upkeep | Small container starter ship; earned in-game money; ship purchases/progression, propulsion fuel, damage and maintenance. Initial customization is ship name, colors, and flags. |
| Port access | Ordinary ports and passages are open without level locks. Distance, fuel, depth, ship size, berth compatibility, and service availability still matter. |
| Recovery | Sinking loses current onboard cargo, preserves ship ownership, and always incurs a recovery fee, including for the starter ship. |
| Multiplayer | Both player-hosted sessions and dedicated servers, with a Servers browser and Play quick-join entry. The visible title is Container Ship Sim; local test sessions stand in until networking is implemented. Player hosts choose public listing or private access. |
| Capacity goal | Roughly 100 simultaneous players in a dedicated session is a design target. Supported launch capacity must follow measured tests. |
| Public progression | Money, fleet, and associated owned-ship state follow players across our public servers through authoritative persistence. One active public account session and durable server handoff must prevent duplication. |
| Private progression | Player-hosted worlds have isolated persistent saves, markets, and refinery stocks. Public directory listing does not grant public-economy access or permit wealth/fleet imports. |
| Shared public economy | One authoritative oil market and shared refinery inventory across our public servers. Port-specific prices are allowed; the same port cannot have independent public-server histories. |
| Art and workflow | Original low-poly cartoon ships and ports, with agent-assisted asset creation and direct project-file editing. Andy evaluates play feel; the agent performs available technical checks and states their limits. |
| Monetization | Earned currency only; no real-money purchases, paid gameplay advantages, rewarded ads, or cash/loot crates. |

## Connected-world design direction

The selected map reference adds recognizable Earth-inspired geography, fictional
islands, a rotatable globe map interface, and continuous circumnavigation. Include
polar destinations and a fictional widened Panama passage beneath a large
suspension bridge. Oceans should feel spacious while nearby coastal trips remain
practical for the starter. No war closures, restriction zones, or compulsory route
lines appear in the default map.

Travel between scenery regions stays in one multiplayer session; switching
public servers is a separate ownership handoff. The concept illustration defines
broad appearance, not measured coastlines, depths, spawn positions, or capacity.
Its ten named ports are the map-design baseline, not a frozen launch-content
count. Harbor Point is a proposed nearby starter destination. Final port services,
coordinates, clearances, scale, and travel times require authoring and testing.

## Version 1 and the first playable milestone

The first playable milestone is a small test area with two ports and two simple
hulls, including the small container starter. A player can select a compatible
container job, load, sail, dock, deliver, receive a correct receipt, and save and
resume that voyage without lost or duplicated state. This milestone establishes
the loop; it does not satisfy the full release scope.

Version 1 is complete when:

- All six core cargo families have usable loading, transport, delivery/sale, and
  applicable processing lifecycles, integrated with money, capacity, and saves.
- Ship handling, docking, ownership/spawning, purchases/resale, fuel,
  damage/maintenance, paid recovery, navigation, and name/color/flag customization
  work together with progression and saves.
- The selected connected-world experience supports useful starter trips and long
  voyages, map/globe agreement, circumnavigation, and safe scenery transitions.
  Launch content is chosen after prototypes; researched catalog size is no quota.
- Both hosting modes, server discovery/joining, isolated private progression,
  shared public progression/markets/refinery stocks, and reconnect/server-switch
  recovery work at a capacity established by representative tests.
- A Windows export passes the relevant roadmap gates, including end-to-end
  voyages, restart/reconnect, failed/retried operations, and empty-wallet recovery.
  Andy has evaluated handling and usability in playable builds.
- Onboarding, settings/accessibility, audio, and measured performance meet the
  recorded targets; installation, save upgrade, backup/rollback, and release
  instructions have been rehearsed for the supported build.

A local/LAN milestone may precede public services. Deferring public services does
not silently redefine the agreed version 1 release.

## Provisional engineering and art defaults

- Step 04 selects Compatibility/OpenGL as the development renderer, pins the exact
  engine in `engine-baseline.json`, and records hardware/startup evidence and
  provisional performance budgets in `ENVIRONMENT.md`. Representative gameplay
  and launch performance remain unproven.
- Start with small reusable scenes, stable IDs, immutable shared definitions, and
  separate mutable ship/job/account records. Keep UI separate from authority.
- Use authoritative validated gameplay requests in both hosting modes; versioned
  saves and atomic, retry-safe money/goods operations must preserve ownership.
- Use one geographic dataset for globe/flat views and streamed nearby scenery.
  The physical-world method, local coordinate frames, seam/polar handling, and
  scale need an early prototype before spatial saves or detailed geography freeze.
- Tune inertia, acceleration, reverse braking, turning, and docking thrusters.
  Separate visual waves from authoritative motion initially; avoid free-body
  simulation for every transported cargo item.
- Use simple original placeholder meshes/materials until appearance is the task.
  A visual replacement must preserve gameplay IDs, scale, collision, and anchors.
  Review one ship/port style sample before producing a large asset catalog.
- Proposed insolvency rule: retain the full recovery fee as a persisted balance
  repaid from later earnings, keeping an earning-capable ship available. Repayment,
  recovery fuel, and restored condition remain explicit tuning decisions; no
  hidden free recovery or refill is assumed.
- Initial player-host departure ends that session; host migration is not required
  for version 1. Step 02's selected identity/storage architecture is recorded in
  `ONLINE_ARCHITECTURE.md`; deployment hosts and budgets remain open.

## Open decisions and latest decision points

| Decision | Resolve before |
| --- | --- |
| Identity, storage, leases and handoff implementation proof | Step 02 selects Keycloak/OIDC public sign-in, PostgreSQL public persistence, SQLite private saves, fenced leases, and durable transfers; see `ONLINE_ARCHITECTURE.md`. Validate dependencies before durable progression; implement/test runtime at dependent steps. |
| Geographic simulation method, coordinate/save contract, seam/pole behavior, world scale and voyage durations | Early world feasibility prototype and durable spatial schema; before detailed world production. |
| Internet connection path, directory operation, optional passwords/invitations | Public internet host/join promises or deployment. |
| Server operator, hardware, bandwidth, region, budget, and tested capacity | Public deployment and launch-capacity commitment. |
| Starting funds, capacities, rewards, fuel/maintenance formulas, recovery fees/repayment and supplied fuel/condition | First playable economy and recovery acceptance tests. |
| Refinery yield/rates/queues, withdrawal charges, market ticks/rounding, cargo cancellation/expiry rules | Their authoritative transaction implementations. Research figures are not automatically adopted. |
| Offshore heavy-job scope across sessions | Heavy-job persistence and reservation design. |
| Final launch fleet/ports/services, approved art sample, and whether player-to-player ship trading is essential | Asset production/content selection and feature freeze. |

None of these requires a new answer to complete Step 01. Resolve architecture
choices at their dependent steps using the existing requirements; ask Andy when a
remaining product choice materially changes scope or architecture.

## Deferred and excluded work

Vehicle transport/Ro-Ro and rockets come after the core release. Walking,
boarding, passengers, interiors/furniture, aircraft/carriers, sail simulation,
historical quests/events, retired-company content, and staff-only ships are
optional later work. Roadmap references to those systems do not make them first
release prerequisites. New original ideas enter an explicit backlog.

Do not extract source-game models, textures, branding, maps, or code. Do not
automatically reproduce its paid/Roblox-specific systems, entire fleet, exact
prices, progression limits, or unverified formulas.

## Evidence limits and completion checks

The supplied research records wiki/changelog and video-caption evidence; it does
not establish exact live parity. Starting wallet, handling/fuel/docking formulas,
market behavior, refinery persistence/charging, damage/recovery, cargo exit/crash
rules, and exact geometry remain partly unverified. Our confirmed recovery,
public-market, and refinery-sharing policies are deliberate design choices even
where the researched game's rules differ or remain uncertain.

For every step: inspect the current project and records, implement the requested
scope, run relevant checks, record results/limits, and preserve a recoverable
checkpoint. Static inspection or headless startup does not prove sailing feel,
network reliability, or 100-player capacity. Gate builds require actual exports
and applicable playtests. Do not mark later roadmap tasks complete from this
planning document.

Source set (read-only originals, dated October 18, 2026):
`Shipping_Game_Specification.md`, `Shipping_Lanes_Research_Reference.md`,
`Shipping_Lanes_Godot_Build_Roadmap.md`, `Shipping_Game_Map_Reference.md`, and
`Shipping_Game_Ship_Rig_Guide.md`. The rig guide's technical conventions remain
proposals until validated during asset setup. Setup confirmations in this chat
supersede the older documents' powered-off-PC assumption.

Step 03 coverage is maintained in `FEATURE_INVENTORY.md`, with rule owners and
deadlines in `UNCERTAINTIES.md` and prerequisite insertions in
`BUILD_DEPENDENCIES.md`. These schedule implementation without changing the
confirmed scope or marking later steps complete.
