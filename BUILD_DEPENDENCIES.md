# Supplemental dependencies and roadmap interpretation

October 18, 2026 · Step 03 · `feature-and-uncertainty-inventory`

The attached roadmap stays read-only. Original task IDs and numbers are stable.
The following tasks are **planned, not implemented**; insert each before its
dependent task. They address new map goals and the Step 02 selected providers.
They do not advance the current task beyond documentation or renumber 01–142.

## Supplemental tasks

### Geographic contract feasibility

Task ID: `geographic-contract-feasibility`  
Placement: after 10, before 11. Owner: Agent. Uncertainties: U004, U031.

Use a tiny world catalog and stand-in markers to prove coordinate normalization,
globe/flat round trips, seam adjacency and pole-safe orientation/frame fields.
Define world/content revision and geographic location units for draft schemas.
No ship controller or detailed globe UI is required for this math experiment.
Pass when example saved/networked addresses round-trip with documented tolerances
and do not confuse transient tile/scene coordinates with persistent identity.
This permits a draft schema; full physical proof remains at 25 and the next
network experiment. A rotating map alone does not pass circumnavigation.

### Private storage dependency proof

Task ID: `private-storage-dependency-proof`  
Placement: after 06/10, before 11. Owner: Agent. Uncertainties: U006–U007.

Select and pin a compatible SQLite binding for Godot 4.7.2 and Windows/headless
exports, record its license/build requirements, and exercise a tiny non-gameplay
schema. Pass import/export, atomic commit/rollback, kill/reopen, a sample migration,
and database-safe backup/restore. No economy or player data is implemented here.
If unavailable, record and prove a replacement decision before dependent saves;
do not quietly fall back to unverified live-file replacement.

### Connected-world network feasibility

Task ID: `connected-world-network-feasibility`  
Placement: after 25, 26, 29–31; before 35–36/41. Owner: Agent. U004, U016, U031.

Extend the physical experiment with two peers, seam/polar/chart transitions,
camera/velocity/orientation and one attached heavy payload. Use disposable save
fixtures to test address serialization/reload and reconnect without waiting for
the later production save system. Pass when one owner/identity persists through
transitions and payload/markers/collision/interest remain coherent at measured
precision limits. Then approve the production spatial schema; fixtures do not
claim durable economic recovery. Record the world revision and chosen method.

### Public storage adapter proof

Task ID: `public-storage-adapter-proof`  
Placement: after 33–34; before 35. Owner: Agent. Uncertainties: U006, U017.

Use the selected local service/PostgreSQL path with synthetic test accounts to
prove a small atomic resource transfer and operation receipt, payload mismatch,
concurrent requests, lost reply/retry, crash recovery and private/public namespace
isolation. Establish the service boundary and schema at 11; game processes have
no database credentials. Pass with recorded committed-or-not outcomes and one
receipt/result per intent. Disposable test authentication is allowed only in an
isolated development environment; it cannot admit real public profiles.

### Authenticated admission feasibility

Task ID: `authenticated-admission-feasibility`  
Placement: after 39, before 40 or any real credential use, whichever is earlier.
Owner: Agent. Uncertainties: U019–U021.

Prove the selected native OIDC flow, authenticated DTLS identity, scoped server
trust/tickets, private guest reconnect credentials and superseded-connection
rejection with test identities. Pin component versions and credential storage
policy. Pass valid/replayed/expired/wrong-server tests without logging secrets.
No custom password scheme, real account enrollment or production deployment is
needed. Earlier loopback fixtures cannot bypass this prerequisite for public use.

### Public authority integration gate

Task ID: `public-authority-integration-gate`  
Placement: after 40–41, before 42. Owner: Agent. Uncertainties: U017–U020.

Run two local server processes against the selected authenticated adapter and
transactional store. Exercise duplicate login, renewal/expiry races, stale writes,
quiesce/seal/claim faults, lost responses, destination failure, restart and backend
outage. Pass only with one canonical committing owner and preserved receipts,
cargo/job/ship IDs and private isolation. Pure in-memory mocks may aid development
but cannot pass this adapter integration gate. Public deployment and load capacity
remain later tasks; the approximately 100-player target is unproven.

### Starter route and distance proof

Task ID: `starter-route-distance-proof`  
Placement: after 43, before 49. Owner: Agent. Uncertainties: U014, U025, U032.

Prove a navigable starter pair using selected scale, ship range and a useful
travel-time budget. A narrow two-port fixture is sufficient. Define direct port
separation, navigable route length, actual sailed odometer, and ETA as distinct
quantities. Pass a worked quote/receipt-distance example and a water-valid route
without paying for detours or requiring an unaffordable first crossing. Step 92
expands validation; it cannot first invent this distance basis after cargo pays.

### Launch hull and passage envelope

Task ID: `launch-hull-passage-envelope`  
Placement: after 88–93, before 94 and detailed Panama production. Owner: Agent.
Uncertainties: U009, U032, U034.

Select a bounded intended launch hull/payload envelope, including loaded draft,
beam/length, air draft and clearance margins. Validate water-connected approaches,
depth, bridge/pier collision and passage in both directions using stand-ins.
Pass before authoring detailed Panama art. Content selected at 99 must fit the
proved envelope or reopen this test; do not assume the largest research ship is
required or that a fixed suspension bridge needs the optional moving-lock task.

## Required interpretations of existing tasks

| Original task(s) | Local interpretation / dependency rule |
| --- | --- |
| 07 model conventions | Inspect Andy's supplied starter source first; a placeholder may demonstrate conventions without declaring the final model approved. Follow the rig guide and preserve original source. |
| 08 input, 109 experience gate, later generic character references | Walking/passengers/furniture remain deferred. Helm-only requirements govern; no character/deck/furniture prerequisites are introduced by old milestone wording. |
| 11 save/protocol contracts | Draft after geographic/storage experiments. Spatial schema stays provisional until 25 plus network feasibility; later content must migrate deliberately. |
| 14 clocks | Decide general offline/pause/lifecycle policy now. Refineries later specify their own durable job clocks; UI timers never own work. |
| 25 world-size experiment | Seamless circumnavigation is selected, so the old bounded-regions fallback is not the product goal. Measure the connected-world physical method, scale/travel timing, seam and polar behavior before durable spatial saves. Local streamed regions still belong to one session. |
| 28 fuel | Declare empty-fuel behavior now and use an explicit recovery fixture. Real paid refueling/recovery integration follows 58–59; no implicit free refill or assumed emergency propulsion. |
| 35–36 durability/local persistence | Selected SQLite/private and PostgreSQL/public adapters must be proven. Interpret temporary-write/backup wording through safe database transaction/backup semantics; do not copy or replace a live SQLite file arbitrarily. |
| 40–41 identity/public handoff | Implement chosen identity/lease/handoff path with proofs now. Fixtures must be labelled, and the adapter integration gate must pass before foundation acceptance. |
| 48–54 operation/first voyage | Resolve generic lifecycle terms before operations, then each family before its implementation. Starter route basis must exist before offers/rewards. |
| 73–76 oil | Before 73–74 decide the market/lot/quote model in U028. Step 75 must prove two-server authoritative price/account settlement before public oil voyages pass. |
| 77–79 refinery/cargo fuel | Decide U029 before processing. Step 78 proves shared processing credits/stock; 79 proves distinct cargo-fuel transport/sale, not propulsion refueling. |
| 80–82 heavy jobs | Resolve job scope/claim lifetime before reservation/persistence. Shared public oil/refineries do not automatically make offshore payloads globally shared. |
| 88–93 world/map | Expand the selected connected world and early distance/coordinate service; do not replace it with isolated compact levels or independently authored globe/flat positions. |
| 94–95 channels/infrastructure | Fixed open Panama and safe hull clearance are core. Moving locks/gates are conditional. No war/level barriers; optional reservations or moving geometry need explicit scope. |
| 99–100 content | Select launch fleet/ports/services explicitly and validate against all hull/service/passage constraints; concept seed coordinates and source fleet counts are not runtime data. |
| 103–106 trading/achievements | Conditional pending U037/U038. If declined, record explicit exclusion and apply 109 to selected scope. Core reward/receipt audit 107 still applies. |
| 110–118 public rollout | Deployment budget, operator, identity/trust, connection path and services must be ready. Steps 113–114 harden/extend earlier verified identity/transactions; they cannot first establish authority after handoff, markets or refinery code. |
| 124–128 release | All applicable core inventory rows and due uncertainties are audited in exported builds. Public services cannot be silently dropped to declare a local milestone version 1. |
| 129–142 and optional later module | Post-core expansion; no car driving, rockets, walking, aircraft, or historical systems are needed to finish core tasks. |

## How to execute this schedule

Proceed next with original Step 04. At each task boundary, check whether a
supplemental prerequisite above is due. After 10, complete both early geography
and private-storage proofs before 11. After 31, complete the connected-world
network experiment; after 34, prove public storage before 35. Inserted work is
requested/executed at that boundary, not silently reported complete now.

Keep stable IDs when splitting discoveries. A passed fixture proves only its
documented boundary; later integration gates must revisit it with actual cargo,
spatial state, services and reconnects. Raise new blockers before dependent work,
record repairs and preserve a recoverable checkpoint. Never bypass an unmet
architecture decision to maintain the appearance of numeric progress.
