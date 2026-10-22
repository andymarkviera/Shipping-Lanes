# Feature and uncertainty inventory

October 18, 2026 · Step 03 · Task ID: `feature-and-uncertainty-inventory`

This is the coverage map for `GAME_SPEC.md`, not an implementation report.
Steps 01–03 are planning; the project still contains only the setup scene.
Engineering choices in `ONLINE_ARCHITECTURE.md` remain unproven until their
implementation checks pass. Original roadmap numbers and task IDs are retained.
Supplemental prerequisites are defined in `BUILD_DEPENDENCIES.md`; unresolved
rules, owners, and deadlines are in `UNCERTAINTIES.md`.

Scope labels: **Core** = required by the agreed release; **Support** = roadmap
work needed to ship that release; **Conditional** = explicit scope decision
pending; **Expansion** = after the core release; **Deferred/Excluded** = outside
the required release. Every row is planned, conditional, or out of scope, not
implemented. Each primary task ID is stable; other numbers identify integration
steps/gates. An unresolved rule blocks its dependent implementation, not this
inventory's completion.

## Foundation, ships, and services

| ID | Feature and scope | Build placement (primary task ID; related steps) | Decisions/checks |
| --- | --- | --- | --- |
| F001 | Core: Windows/Godot baseline and measured renderer/hardware target | 04 `engine-and-hardware-baseline`; 06, 15, 98, 124–128 | U001; current engine is known, hardware/performance is not. |
| F002 | Support: source control, reusable project structure, extension instructions | 05 `repository-and-project-skeleton`; 85, 128 | Recoverable checkpoints; no source/reference files overwritten. |
| F003 | Core: original ship/port assets and supplied starter source | 07 `model-and-asset-conventions`; 27, 91, 123 | U002; inspect `starter_container_01` from `ASSET_REFERENCES.md` before replacing it. No capacity inferred from geometry. |
| F004 | Core: throttle/steering/thrusters/horn/camera/map input, rebind and focus | 08 `input-and-settings-foundation`; 09, 17–19, 55–56, 122 | U003; helm-only input context; zero throttle is not instant stop. |
| F005 | Support: boot/title/session/continue/pause/settings/error flows | 09 `application-flow-and-focus`; 38, 55–56, 108, 117–118 | U003, U032; hosted pause cannot freeze everyone. |
| F006 | Core: stable ship/cargo/port/berth IDs and separate runtime ownership | 10 `definitions-and-stable-ids`; 11, 13, 37, 85 | U004; distinguish DWT, holds/tanks/slots, mass, quantity, and draft. |
| F007 | Core: versioned schemas, units, rounding, lifecycle and offline clocks | 11 `save-and-protocol-contracts`; 12–14, 34–37 | U004–U007; geographic/storage prerequisite checks apply. |
| F008 | Core: balanced handling, inertia, reverse braking, turning and side thrust | 16 `handling-prototype`; 17–18, 22–24, 27, 30 | U008; numeric tolerances plus Andy's playtest. |
| F009 | Core: usable ship camera, zoom and feedback | 19 `camera`; 22, 55, 97, 122 | U003, U008; freecam/extra view modes are conditional (F049). |
| F010 | Support: lightweight visual water/bobbing | 20 `water-presentation`; 96, 98, 123 | U033; visual movement cannot move authoritative cargo or advance jobs. |
| F011 | Core: hull/shore collision, depth, loaded draft, grounding | 21 `hull-and-shore-collision`; 23, 25–26, 44, 59, 94 | U009; administrative eligibility and physical clearance are separate. |
| F012 | Core: propulsion fuel and paid refueling | 28 `fuel-simulation`; 58, 60, 67, 86 | U010; idle/reverse/thruster, pause/docked and empty-fuel behavior explicit. Cargo fuel is separate (F031). |
| F013 | Core: safe ship spawning, berth eligibility, reservations and docking | 44 `spawn-clearance-and-recovery-anchors`; 43, 45–46, 56, 65 | U011; compatible services come from data, not decorative crane counts. |
| F014 | Core: impact damage, sinking, cargo loss and paid recovery | 59 `impact-damage-and-recovery`; 44, 54, 62, 67 | U012; cargo removed/charge applied once, ownership retained, no free starter recovery. |
| F015 | Core: engine/hull/machinery wear, rust and repair services | 60 `component-wear`; 61–62, 67, 86 | U013; long-term wear and immediate damage are separate. |
| F016 | Core: starter funds, ship catalog, purchase, inspection and upgrades | 63 `ship-catalog-and-purchase`; 10, 49, 57, 64–67, 86 | U014; first playable milestone uses two ports and two simple hulls, including the container starter; final catalog/prices/capacities are not fixed. |
| F017 | Core: fleet spawning/switching, resale and voyage accounting | 65 `fleet-spawn-and-switching`; 54, 66–67 | U015; cargo/active-job restrictions; report net costs as well as gross revenue. |

## State, multiplayer, and persistence

| ID | Feature and scope | Build placement (primary task ID; related steps) | Decisions/checks |
| --- | --- | --- | --- |
| F018 | Core: shared authoritative request path in local/host/dedicated play | 13 `state-ownership-boundaries`; 29–30, 33–34, 111 | U016; clients supply intent and cannot mint results. |
| F019 | Core: atomic money/goods, durable action IDs, receipts and retries | 35 `durable-action-recovery`; 33–34, 48, 51, 75, 78, 107, 114 | U005, U017; lost replies, mismatched payloads, contention, restart. |
| F020 | Core: versioned local/private saves, slots, missing content and recovery | 36 `versioned-local-persistence`; 37–39, 51, 90, 115, 127 | U006–U007; SQLite-safe commits/backups, not replacement of a live database file. |
| F021 | Core: both hosting modes, ship/payload replication and relevance | 29 `local-network-session`; 30–32, 39, 111–112 | U016, U018; headless server is not a player; late joins reconstruct authoritative state. |
| F022 | Core: account/private guest identity, reconnect and host departure | 40 `session-identity-and-control-handoff`; 39, 113, 119 | U019; authentication component proof and Step 40 private identity/control pass; Step 41 public lease/handoff adapter passes; integrated OIDC/Godot authority remains the pre-42 gate. |
| F023 | Core: public progression, single owner and durable server switching | 41 `public-profile-and-server-switch-handoff`; 35, 40, 42, 113–115 | U017–U020; money/fleet/cargo/job IDs preserved, private worlds isolated. |
| F024 | Core: directory, Multiplayer browser, direct connect and hosting access | 116 `server-directory-service`; 110, 117–120 | U021–U022; listed player hosts still use private saves; NAT/relay must be tested. |
| F025 | Core: representative dedicated capacity target and operational controls | 32 `early-dedicated-capacity-experiment`; 98, 110–112, 119–120, 124 | U018, U022; target approximately 100, measure launch capacity rather than assert it. |

## Cargo and economy

| ID | Feature and scope | Build placement (primary task ID; related steps) | Decisions/checks |
| --- | --- | --- | --- |
| F026 | Core: manifests, quotes, reservations and authoritative timed operations | 47 `cargo-manifest`; 48–51, 54, 84 | U023–U024; common operation rules plus explicit family exceptions. |
| F027 | Core: container offers, multi-destination loads, visuals and delivery | 49 `container-offers`; 50–57 | U024–U025; lock selected quote terms and capacity; menu/animation cannot pay twice. |
| F028 | Core: bulk commodities/hold allocation, direct-distance earnings and explicit partial-discharge policy | 68 `bulk-capacity-model`; 69–70, 84, 86–87 | U026; hold count is not DWT or cargo tonnage; no payout from sailing circles. |
| F029 | Core: gas tanks, commodity/terminal compatibility, delivery and saves | 71 `gas-capacity-and-terminal-compatibility`; 72, 84, 86–87 | U027; explicit commodity set and cubic-meter quantities. |
| F030 | Core: oil purchase/sale, lot cost basis, shared public price history | 73 `liquid-trading-inventory`; 74–76, 84, 86–87 | U028; account+market settlement atomic; private markets isolated. |
| F031 | Core: refinery processing/shared stock and cargo-fuel loading, transport and sale | 77 `refinery-processing`; 78–79, 84, 86–87 | U029; stable public facility IDs, queues/offline rules, rounding, withdrawal prices and concurrent access. |
| F032 | Core: offshore heavy jobs, lifter submerge/attach/raise, transport and delivery | 80 `heavy-load-jobs`; 26, 31, 81–84, 86–87 | U030; payload limits and job scope; no implicit player-ownership transfer. |
| F033 | Core: interruption/reconciliation for every cargo family | 54 `voyage-lifecycle-reconciliation`; 51, 70, 72, 76–79, 82, 84 | U023; complete the lifecycle matrix below separately for each family. |
| F034 | Core: compatibility, content extension, useful cargo roles and pacing | 84 `cargo-compatibility-matrix`; 67, 85–87, 100, 107 | U014, U025–U030; measured net income, capital, costs/time/risk; no unlimited resale/reload loop. |

## Connected world and release experience

| ID | Feature and scope | Build placement (primary task ID; related steps) | Decisions/checks |
| --- | --- | --- | --- |
| F035 | Core: canonical geographic location, globe/flat agreement, circumnavigation | 25 `world-size-experiment`; 11, 31, 88–93, 101 | U004, U031; early inserted proofs; seam/poles, heading/velocity/camera, not only a rotating map. |
| F036 | Core: streamed scenery inside one session with durable entities | 89 `region-loading`; 25, 31, 90, 98, 101 | U031; scenery teardown cannot erase cargo/market/refinery state; region travel is not server transfer. |
| F037 | Core: original continents/islands, spacious oceans, polar destinations and starter neighbors | 88 `world-layout-and-traversal-budget`; 43, 91, 99–101 | U031–U032; ten named concept ports are design baseline, launch set is not frozen; Harbor Point remains proposed. |
| F038 | Core: map/globe search, selection, position, filters, waypoints, distance and ETA | 93 `map-and-waypoints`; 43, 56, 88, 92, 97, 101 | U025, U031–U032; one dataset; distinguish payout separation, safe route length, actual odometer, ETA. |
| F039 | Core: open Panama connection/fixed bridge, channels, depth/beam/air-draft warnings | 94 `channels-and-constraints`; 23, 88, 92, 99–101 | U034; launch hull envelope before detailed passage; no level/war closures or forced route network. |
| F040 | Core: name/color/flag customization with defaults and isolated materials | 102 `names-and-paint`; 07, 27, 65, 109, 123 | U035; appearance persists without changing hull authority or shared materials. |
| F041 | Support: readable voyage/service UI and onboarding | 55 `voyage-interface`; 56, 97, 108–109, 122 | U003, U014, U032; errors, receipts, first trip and restart are understandable. |
| F042 | Support: environment presentation and player visual settings | 96 `environment`; 20, 98, 121–122 | U033; day/night, rain/fog/storm are roadmap presentation work; physical forces are conditional (F050). |
| F043 | Support: original/licensed engine, horn, collision, water, service and UI audio | 121 `audio-implementation-and-mix`; 08, 122–124 | U036; volume/distance/voice budgets and provenance; no paid horn catalog copied. |
| F044 | Support: accessibility, focus, rebinding and settings persistence | 122 `interface-and-accessibility-pass`; 08–09, 38, 108, 124–125 | U003, U036; supported scaling/readability/input needs recorded and tested. |
| F045 | Support: asset replacement/import regression and launch-content audit | 123 `art-replacement-and-import-regression`; 07, 85, 91, 99–100 | U002, U032, U034; scale, anchors, collision, IDs, paint and appearance survive reimport. |
| F046 | Support: exports, integration gates, backup/restore, installation/upgrade and release guide | 06 `export-pipeline-smoke-test`; 42, 57, 67, 87, 101, 109, 115, 124–128 | U001, U006–U007, U022; fresh install/rollback, actual exports/playtests, known issues and extension instructions. |

## Conditional, expansion, deferred and excluded features

| ID | Feature and disposition | Reserved placement / decision |
| --- | --- | --- |
| F047 | Excluded by Andy: player-to-player money, ship and cargo trades/gifts/transfers | 103–105 not applicable by scope decision (October 20, 2026); U037 resolved. Game shop purchase/resale, payments and fees remain core. |
| F048 | Conditional: earned achievements/reward milestones | 106 `achievements-and-progression-rewards`; U038 before 106. No source badge/event catalog is adopted. Step 107's core reward audit still runs if omitted. |
| F049 | Conditional: freecam, extra camera modes, companies/crew/chat/parties or shared income | Camera subset at 19 `camera`; social/crew module has no committed implementation slot. U039 before adding scope; no gameplay/shared-income assumption from visible peer ships. |
| F050 | Conditional: physical waves/wind/currents and moving locks/gates/bridges | 95 `moving-infrastructure`, 96 `environment`; U033–U034 before dependent work. Fixed Panama bridge/open passage does not require moving infrastructure. |
| F051 | Expansion: Ro-Ro vehicles and mixed container/vehicle ships | 129–135, primary `vehicle-transport-design`; U040 before 129/132. Driving, ramps, representative counts, crash/cancel and network attachment belong here. |
| F052 | Expansion: rocket contracts, launch, optional recovery and control restoration | 136–142, primary `rocket-contract-model`; U041 before 136. Costs/rewards, RNG/failure, moving-launch lock, abort and recovery rules are new decisions. |
| F053 | Deferred: walking/boarding/passengers/furniture/interiors | Optional roadmap module beginning `walking-on-ships-risk-prototype`; U042 before activation. No walking input, deck character, or furniture work blocks core release. |
| F054 | Deferred: aircraft/carriers, sail simulation, elaborate historical quests/events | Separate future proposal and acceptance checks; U042. Preserve no hidden release obligation or source NPC/quest dependency. |
| F055 | Excluded: real-money currency, paid advantages, ads, cash/loot crates and paid refuel/repair | No implementation slot. Earned currency and charged in-game recovery/services remain core. |
| F056 | Excluded: extracting source assets/code/branding/map or cloning catalog counts, paid/retired/staff systems | No implementation slot. Research fleet/port counts, data caps, limited stock, old companies, badge lists and exact prices are not our launch requirements. |

## Lifecycle coverage required before accepting each cargo family

For containers, bulk, gas, oil, cargo fuel, and heavy payloads, record one outcome
for each event below before its first persistent implementation. Do not copy a
container policy into another family without checking its purchased lots,
offshore reservations, processing input/output, and partial quantities.

| Event | Required explicit rule / evidence |
| --- | --- |
| Acquire/reserve/start | Accepted terms, funds/capacity/stock ownership, expiry and one operation ID. |
| Partial load/discharge and complete | Quantity/rounding, which cargo/job is consumed, reward/cost, durable receipt. |
| Cancel/abandon/berth loss | Refund/forfeit, capacity/stock release, job cleanup and retry behavior. |
| Menu close/pause/focus loss | UI cannot commit or advance/cancel work accidentally; hosted clocks explicit. |
| Despawn/switch/resale/optional trade | Eligible ship state, manifest destination, transfer locks and forbidden cases. |
| Quit/disconnect/crash/restart/reconnect | Resume/cancel/complete rule, last durable boundary, orphan reconciliation. |
| Public server handoff / scenery transition | Stable IDs, one owner, no duplicated output/refund; private namespace isolation. |
| Grounding/damage/sinking/recovery | Cargo loss and affected-job cleanup once; full recovery charge remains recorded. |
| Backend outage/retry/concurrent requests | No half debit/delivery, no duplicate award/withdrawal, no local public fallback. |
| Definition removal/world revision/backup restore | Safe migration or quarantine, canonical receipts, no silent wipe or restored stale authority. |

Full system-boundary regression responsibility remains in the roadmap's
cross-system table and the Step 02 proof matrix. Character/car interactions are
conditional on the relevant later module rather than core tests.

## Evidence and use

Research sections 3–5 feed F004–F017; section 6 feeds F026–F034/F051–F052;
section 7 feeds F017–F023/F047; section 8 feeds F035–F039; section 9 feeds
F040–F044/F048–F054; section 10 feeds exclusions F055–F056. Tables in sections
11–14 are reference candidates for data authoring and conflict resolution, not
automatically approved catalogs. Section 16 feeds `UNCERTAINTIES.md`.

The later map and rig references add the connected-world goals and asset
validation contracts; the supplied Blender file is the starter asset candidate,
not a tested physics hull. Original documents and model remain unchanged.

Before each next task, inspect its row, linked uncertainties, supplemental
dependencies, and actual project state. Resolve each due rule in `DECISIONS.md`
with evidence/default status before dependent code; mark it implemented only
after its acceptance checks run. Step 03 completion means coverage is assigned,
not that the open questions or later prototypes have passed.

Public authority adapter follow-through (October 22): real OIDC-to-HTTPS tickets
and live Godot ownership/fencing/checkpoint/handoff are implemented in
PUBLIC_GODOT_OWNERSHIP.md. This is not completion of public player transport,
world/cargo integration or the pre-42 authority gate; retain those dependencies.
