# Supplemental dependencies and roadmap interpretation

October 18, 2026 · Step 03 · `feature-and-uncertainty-inventory`

The attached roadmap stays read-only. Original task IDs and numbers are stable.
The following tasks have individual status below; insert each before its
dependent task. They address new map goals and the Step 02 selected providers.
They do not advance the current task beyond documentation or renumber 01–142.

## Supplemental tasks

### Current multiplayer priority — October 21, 2026

Andy asked to keep development efficient toward multiplayer that works well.
Keep Step 38 limited to necessary save/recovery feedback, then prioritize Step 39
reconnect/lifecycle, the authentication proof, Step 40 durable identity/control,
and Step 41 single-server authority/handoff. Complete the public adapter
integration and `bounded-replication-and-client-pacing` before the Step 42
foundation gate. The measured packet size/bandwidth and acknowledgement latency
need correction and retesting; existing loopback checks are not internet readiness.
Avoid extra art/content/polish detours along this path. Previously scheduled
neutral, pickup, and water follow-ups remain recorded at their existing gates.
Actual public deployment/operations still require the later rollout work.

### Geographic contract feasibility

Task ID: `geographic-contract-feasibility`  
Placement: after 10, before 11. Owner: Agent. Uncertainties: U004, U031.
Status: complete October 19, 2026; see GEOGRAPHIC_CONTRACT.md. Physical proof remains pending.

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
Status: complete October 19, 2026 with cold-import pre-registration; see STORAGE_PROOF.md.

Select and pin a compatible SQLite binding for Godot 4.7.2 and Windows/headless
exports, record its license/build requirements, and exercise a tiny non-gameplay
schema. Pass import/export, atomic commit/rollback, kill/reopen, a sample migration,
and database-safe backup/restore. No economy or player data is implemented here.
If unavailable, record and prove a replacement decision before dependent saves;
do not quietly fall back to unverified live-file replacement.

### Connected-world network feasibility

Task ID: `connected-world-network-feasibility`  
Placement: after 25, 26, 29–31; before 35–36/41. Owner: Agent. U004, U016, U031.
Status: complete October 20, 2026 for the bounded two-process experiment; see
CONNECTED_WORLD_NETWORK.md for the spatial contract, evidence and integration limits.

Extend the physical experiment with two peers, seam/polar/chart transitions,
camera/velocity/orientation and one attached heavy payload. Use disposable save
fixtures to test address serialization/reload and reconnect without waiting for
the later production save system. Pass when one owner/identity persists through
transitions and payload/markers/collision/interest remain coherent at measured
precision limits. Then approve the production spatial schema; fixtures do not
claim durable economic recovery. Record the world revision and chosen method.

### Bounded replication and client pacing

Task ID: `bounded-replication-and-client-pacing`  
Placement: after 32, before 42 or production multiplayer expansion, whichever
comes first. Owner: Agent. Status: scheduled from measured capacity evidence.

Step 32 measured 71.154 Mbps of application egress and 6,124-byte snapshots at
100 crowded connections. The rendered client's acknowledgement p95 was 227 ms.
Implement changed-state/keyframe updates, separate slow metadata, bounded compact
packets (provisional maximum 1,200 bytes), safe revision/chunk recovery and
measured client polling/queue deadlines. Preserve collision-near relevance.
Repeat 100-crowded with bounded queues, loss recovery, p99 authority work below
12 ms and a local rendered acknowledgement p95 target below 150 ms; record any
remaining gap. See CAPACITY_EXPERIMENT.md for the concrete architecture decision,
measurement limits and hosting/network budget gate. This does not block Step 33.

### Public storage adapter proof

Task ID: `public-storage-adapter-proof`  
Placement: after 33–34; before 35. Owner: Agent. Uncertainties: U006, U017.
Status: complete October 21, 2026 for isolated synthetic accounts; see
PUBLIC_STORAGE_PROOF.md. Production authentication/leases remain later gates.

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

Completed as a bounded component proof October 21, 2026; see
AUTHENTICATED_ADMISSION_PROOF.md. Provider PKCE, ticket transactions, private guest
generations and Godot DTLS are tested separately. System-browser UI and connected
admission/gameplay integration remain required, including the gate below.

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

## Playtest follow-ups — October 20, 2026

Andy requested these be scheduled for later, without changing gameplay now.
Original step numbers remain unchanged. Details and the original observations
are recorded in `HANDLING_FEEDBACK.md`.

| Supplemental task ID | Placement | Completion criteria | Status |
| --- | --- | --- | --- |
| `neutral-stop-usability` | Before Step 46 docking, and before retesting cargo pickup | Make neutral easy to select and show command, engine output and actual motion clearly. Review practical stopped thresholds and hysteresis so docking/loading can recognize a stable stop without flickering or accepting meaningful drift. Verify ahead/astern/lateral movement, coasting and loaded/unloaded ships while preserving the accepted handling feel. | Scheduled; player reported difficulty |
| `cargo-pickup-playtest-repair` | After the neutral/stop review, before Step 50 loading operations | Reproduce the reported failure in the relevant test scene; identify the cause rather than assume it is stopping. Check alignment, deck state, stopped gate and action feedback. Make the next required action or blocking condition clear; verify a complete pickup/secure/raise/release cycle in solo and local multiplayer where applicable. | Scheduled; cause unverified |
| `stylized-hull-foam-wake-polish` | Alongside Steps 99–100 fleet/world content, before Step 109 experience gate | Replace or refine placeholder hull foam, bow water, ripples and trailing wake around the settled hulls. Follow the bold-blue, broad-white-pattern Zelda-inspired direction, with muted coastal palettes where appropriate. Check transitions from rest to motion, turns, reversing and different hull sizes, plus quality-tier performance. Keep visual effects separate from handling forces. | Scheduled; current placeholders accepted |

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
| 103–106 trading/achievements | Andy excluded player-to-player economic transfers/trading on October 20, 2026: 103–105 are not applicable, U037 resolved. Achievements (106/U038) remain conditional. Apply 109 to selected scope; core reward/receipt audit 107 still applies. |
| 110–118 public rollout | Deployment budget, operator, identity/trust, connection path and services must be ready. Steps 113–114 harden/extend earlier verified identity/transactions; they cannot first establish authority after handoff, markets or refinery code. |
| 124–128 release | All applicable core inventory rows and due uncertainties are audited in exported builds. Public services cannot be silently dropped to declare a local milestone version 1. |
| 129–142 and optional later module | Post-core expansion; no car driving, rockets, walking, aircraft, or historical systems are needed to finish core tasks. |

## How to execute this schedule

Historical Step 03 scheduling baseline: the next task then was Step 04. At each task boundary, check whether a
supplemental prerequisite above is due. After 10, complete both early geography
and private-storage proofs before 11. After 31, complete the connected-world
network experiment; after 34, prove public storage before 35. Inserted work is
requested/executed at that boundary, not silently reported complete now.

Keep stable IDs when splitting discoveries. A passed fixture proves only its
documented boundary; later integration gates must revisit it with actual cargo,
spatial state, services and reconnects. Raise new blockers before dependent work,
record repairs and preserve a recoverable checkpoint. Never bypass an unmet
architecture decision to maintain the appearance of numeric progress.

October 21 follow-through: Step 40 now integrates the private authenticated path
with durable member/ship IDs, DTLS invitations, generation-fenced control and
fresh-process recovery. See PRIVATE_SESSION_IDENTITY.md. Public service admission,
leases/handoff, the two-server integration gate and replication/pacing work remain
required before Step 42; no numeric milestone bypasses those gates.

October 22 follow-through: Step 41 completes the real PostgreSQL/HTTPS public
profile and handoff adapter fixture (PUBLIC_PROFILE_HANDOFF.md). The remaining
public-authority integration gate must connect actual validated OIDC admission
and two headless Godot instances, including stopping live physics/collisions when
authority is uncertain. Complete that and bounded replication/client pacing before
42. Dedicated-server launch/join usability is an explicit implementation target;
production rollout and capacity validation remain later work.

October 22 Godot integration follow-through: validated OIDC access tokens now
issue scoped tickets through HTTPS, and real Godot hull owners renew, checkpoint
on departure, quiesce, transfer, and recover against the public backend. See
PUBLIC_GODOT_OWNERSHIP.md. This proves the live simulation/identity adapter portion;
keep the public-authority gate open for authenticated DTLS player admission and
public world/cargo/action integration. The file courier is not player transport.
Bounded replication/client pacing still precedes Step 42.

October 22 transport follow-through: PUBLIC_PEER_ADMISSION.md now proves real
OIDC-issued tickets through pinned DTLS and peer-bound helm/snapshot traffic in
editor and Release, including two accounts, disconnect saving and the normal
headless configuration entry point. Keep the authority gate open for shared
world/cargo/actions, rendered client integration and player login/server selection.
The eight-connection bounded fixture is not the capacity/pacing gate or public rollout.

Public nearby presentation adds no external dependencies. The exported resource
list explicitly includes public_world_view.gd; verification reuses the pinned
Godot/PostgreSQL/HTTPS/OIDC peer fixture. See PUBLIC_NEARBY_BOATS.md.

Public shared physics adds no external dependencies. Export explicitly includes public_physics_world.gd and public_physics_probe.tscn. Run `tools/public_handoff/physics_probe.py --runtime editor` or `--runtime release` with the existing Python runtime after export.

Public player presentation reuses existing Godot water, camera, input and ship assets. Export explicitly includes public_client.gd, public_client.tscn and public_client_presentation.gd. No new external dependency.

Native sign-in adds no runtime beyond Godot. public_browser_login.gd uses Crypto, TCPServer and HTTPRequest; public_entry resources and the login probe are explicitly exported. tools/public_handoff/login_probe.py reuses the existing disposable Keycloak/PostgreSQL fixture. Native HTTPS test endpoints explicitly use 127.0.0.1 to match the IPv4 service binds; TLS certificate checks remain enabled.

## Current execution order — October 22 review

See DEVELOPMENT_REVIEW.md for the current consolidated assessment. Finish a
bounded persistent local service/enrollment setup, safe starting positions and
clear join failures; then periodic public spatial/fuel saves and graceful shutdown.
Complete bounded replication/client pacing and the integrated two-peer foundation
scenario before accepting Step 42. Include the existing prototype cargo and action
boundaries in authority checks, but do not require the unbuilt Steps 47–54 or
80–83 production job systems to pass a pre-cargo gate. Carry their integration
requirements forward to their own gates. Do not expand this into production
hosting, live discovery or additional art before the first voyage milestone.
Neutral-stop and reported heavy-loader pickup repairs keep their existing deadlines.

## Player clarification after the development review

100 players is not a required server size. Keep earlier 100-client measurements
as historical stress evidence and an optional optimization reference. The bounded
replication/pacing task remains necessary, but its acceptance should measure and
justify a practical supported capacity, rather than require 100 to proceed.
The next neutral-stop-usability pass includes a small reverse/neutral/forward
throttle slider indicator, with a clear center and actual speed/direction feedback;
see HANDLING_FEEDBACK.md. Aesthetic menu/world work remains planned for later.

Persistent local online setup now reuses the pinned runtimes through LocalOnline.ps1;
see LOCAL_ONLINE.md. It proves restart-stable development enrollment and normal
server launch, but browser trust, real deployment and safe saved-position admission
remain open. Next prioritize periodic public saves and graceful server shutdown,
then bounded replication and the integrated foundation gate.

October 23 durability follow-through: public sailing now attempts periodic spatial/
fuel checkpoints, and dedicated shutdown drains final saves/releases before exit.
LocalOnline waits for the drain result before backend teardown. See PUBLIC_DURABILITY.md.
Browser trust, general safe spawning, public gameplay parity and bounded replication/
client pacing remain due; Step 42 is still open. The next implementation priority
is bounded replication/client pacing at a measured practical capacity, not a mandatory
100-player requirement.

October 23 network follow-through: PUBLIC_NETWORK_PACING.md implements compact
complete frames and monotonic latest-input sends for the bounded eight-peer path.
At this cap full frames already fit comfortably; defer delta/chunk complexity until
measured capacity requires it. Loss/latency/reordering, rendered client timing and
total sustained server/transport measurements remain before foundation acceptance.
The old 100-client fixture remains historical stress evidence, not the required cap.

October 23 impairment follow-through: PUBLIC_NETWORK_IMPAIRMENT.md records real
DTLS loss/delay/duplicate/reordering and blackout recovery in editor and rendered
Release. The short controlled scenario passes, without establishing WAN capacity,
long-outage handling or visual usability. Next consolidate the Step 42 foundation
acceptance checklist and repair its concrete control/spawn/lifecycle blockers;
retain sustained workload, browser usability and deployment evidence limits.

October 23 controls/review follow-through: public lateral thrusters and the shared
throttle indicator are implemented (PUBLIC_HELM.md). No new dependencies. Matching
client/server builds use game protocol 8; HTTPS ticket protocol remains 7. The
current finite foundation checklist is FOUNDATION_ACCEPTANCE.md. Next: clear refused
admission/retry feedback, then combined foundation acceptance before two ports.
General safe port allocation remains Step 44; stop review before 46 and pickup
repair before 50 are still due.

October 23 admission follow-through: PUBLIC_JOIN_FEEDBACK.md completes specific
refused-admission feedback and fresh sign-in retry. Editor and exported native
login paths pass blocked-spawn/save-preservation/retry checks. Next is the combined
two-account foundation scenario and explicit practical workload limits before
accepting Step 42. General port spawn allocation stays at Step 44.

October 23 foundation acceptance: Step 42 passes after a concrete authority-I/O
lifetime repair and combined Release validation (PUBLIC_FOUNDATION.md). The next
applicable task is Step 43, two test ports, then 44 safe spawn/recovery anchors.
Do not repeat the completed pre-42 infrastructure sequence without new failures.
Retain eight as the development cap; WAN/browser trust/long-soak and hosting-hardware
validation remain explicitly limited. Retest workload when port/cargo content grows.

October 23 ports follow-through: Step 43 passes (TWO_TEST_PORTS.md). Both static
port scenes and planned service records are reusable independently of economy.
Next is Step 44 runtime spawn clearance/recovery anchors. The current starter
approach geometry checks are only a static baseline, not dynamic reservation or
cargo-envelope validation. Public world placement remains explicit later integration.

October 23 spawn follow-through: Step 44 port component and preview integration
pass (SPAWN_CLEARANCE.md). Production world placement must share the allocator
across simultaneous spawns and supply berth/cargo holds; public canonical recovery
remains an explicit future integration. Next: 45 berth eligibility; stop review
before 46, heavy pickup repair before 50. No hidden shallows or peer transfers.

October 24 berth follow-through: Step 45 passes (BERTH_ELIGIBILITY.md), with live
Port Test readiness and 105 rendered Release checks. Review stop/neutral usability
before Step 46 docking; recheck eligibility on the docking authority. Production
port placement and loaded-cargo clearance remain integration work. Heavy-loader
pickup remains unresolved and due before Step 50.

October 24 neutral follow-through: requested capture and low-speed stopping assist
implemented and tested for both hulls and public-server full-stop replication.
See NEUTRAL_ASSIST.md. Step 46 docking is next; heavy pickup remains due before 50.

October 24 docking follow-through: Step 46 component and Port Test integration pass
(DOCKING_STATE.md). Public-world port placement and trusted network-owner binding
are still integration work; local two-owner arbitration is covered now. Next: 47
cargo manifest. Heavy-loader pickup repair remains mandatory before Step 50.

Later docking UI pass: remove temporary water-surface berth markings. Show a greyed
Dock button near the berth and color it when stopped and eligible. User explicitly
requested recording this for later, so no current gameplay/presentation change.

October 24 manifest follow-through: Step 47 runtime manifests pass (CARGO_MANIFEST.md).
Step 48/50 operations must enforce authority and use manifest validation; Step 51
must version/migrate persisted inventory into manifests without losing legacy cargo.
Do not treat an empty new runtime manifest as an empty saved inventory. Heavy-loader
pickup remains unresolved and required before Step 50. Dock water-guide removal is
still deferred per user preference.

October 24 operation follow-through: Step 48 runtime records/adapters and pending
reconstruction pass (CARGO_OPERATIONS.md). Step 49/50 must bind trusted ownership,
source stock, docking and disconnect hooks. Step 51 must persist operation receipts
and manifest effects together; no crash-safe operation save is claimed by Step 48.
Next: container offers, with heavy-loader pickup repair still due before Step 50.

October 24 offer follow-through: Step 49 source/preview passes (CONTAINER_OFFERS.md).
Before Step 50 repair heavy-loader pickup. Loading must atomically convert accepted
capacity commitments into manifest batches without double-counting, validate docked
origin and bind trusted identity. Step 51 persists offers/jobs with world-scoped IDs;
Step 53 settles quoted rewards. Public offer networking remains integration work.

October 24 loading follow-through: Step 50 local authority/preview passes
(PORT_LOADING.md). Heavy pickup prerequisite now has a reproduced collision fix and
37 passing checks, including manual approach/exit. Public network disconnect binding,
port placement and loading RPCs remain integration work. Step 51 must persist manifest,
loaded offer and operation receipt together and recover pending reservations safely.

October 24 user-directed redesign supersedes timed offers: non-expiring ship-specific
jobs behind docked CARGO / REFUEL / REPAIR. Containers deliver port-to-port; heavy
jobs use nearby physical pickup and random ocean destinations. Step 51 must persist
both job types, physical heavy attachment/drop target, manifest/operation receipts,
service condition/fuel and eventual durable settlement together. Free prototype
services and temporary credits are not production economy integration. Do not restore
expiry, water docking guides or assume heavy destinations are ports. Camera own-load
exclusion is regression tested. See DOCK_SERVICES_REDESIGN.md.

October 24 usability correction: one active job per captain supersedes multi-job
acceptance and mixed-destination gameplay assumptions; manifest batching remains a
generic storage capability. Step 51 must preserve this uniqueness on reconnect.
Container acceptance starts loading automatically; heavy jobs keep nearby pickup.
Step 52 is the next cargo-visual milestone. Extend Step 56 with a temporary minimap
showing the boat, ports and current delivery target, before Step 57's voyage gate.
HUD focus and heavy berth tolerance fixes verified; see DOCKING_USABILITY.md.

October 24 Step 51 follow-through: local voyage persistence and authority reconnect
snapshot reconstruction pass, including real process interruption at COMMIT. Public
port/service ownership RPCs and production settlement integration remain outstanding;
never trust a client-provided checkpoint. Step 52 must derive container visuals solely
from the restored manifest. Heavy pickup no longer requires angle matching or Secure:
Raise attaches if the platform is under the load, Lower at destination delivers.
Preserve this flow in later UI/ship work. See IN_FLIGHT_PERSISTENCE.md.

October 24 Step 52: manifest-driven container visuals pass local/restore checks.
Next Step 53 must preserve one active job, atomic consumption/reward, wrong-port
rejection and idempotent receipts. Public manifest/network service wiring is still
an integration dependency, not completed by visual work. Step 51 remains awaiting
user play-test feedback. See CONTAINER_VISUALS.md.

October 25 Step 53: local delivery now commits before success acknowledgment; exact
batch matching, receipts and real before/after-delivery-COMMIT recovery checks pass.
Step 54 must reconcile cancellation, abandonment, despawn and ship-switch outcomes
without refund/delivery duplication. Keep public port/service settlement integration
explicitly outstanding. Steps 51–53 still await user play-test feedback.
See DELIVERY_PAYOUT.md.

October 25 play-test prerequisite: repeated steering/save freeze reproduced and fixed
by preserving orthonormal physical hull rotations. Cargo loading succeeded in Andy's
test; full steps 51–53 acceptance and confirmation of this fix remain pending.
Add cargo-loading animation to later port/cargo presentation polish after lifecycle
stability. Drive the animation from loading state/progress, handle cancel/restart,
and never use animation completion to award cargo. Step 54 remains next.
See SAILING_SAVE_FIX.md.

October 25 play-test follow-through: Andy confirms the sailing-save fix and successful
heavy pickup. Wider, quay-contact docking is now implemented and automatically tested.
Add mooring-rope tie-up/release animations to later port presentation polish. Bind them
to authoritative docking state, cancellation and reconnect; no independent control
locks. Cargo-loading animation remains queued. Step 54 remains next.
See ALONGSIDE_DOCKING.md.

October 25 Step 54: local voyage lifecycle rules and conservative orphan recovery
implemented and tested. Future sinking/despawn must call before_ship_removal and honor
failure before deleting a ship; carrying heavy loads currently refuse removal.
Public network port/service settlement remains outstanding. Step 55 voyage HUD next,
Step 56 minimap after it. Andy confirms full container delivery, heavy pickup and
save-freeze fix; alongside docking and lifecycle changes still await play-test.
Cargo-loading and mooring-rope animations remain later presentation work.
See VOYAGE_LIFECYCLE.md.

October 25 Step 55: state-derived voyage interface implemented and tested for local
container and heavy trips, reload and save failure. Public network services remain
a separate dependency. Step 56 minimap should reuse accepted destination/pickup/drop
state, without introducing docking water markings or another authority. Cargo and
mooring animations remain queued for later polish. See VOYAGE_INTERFACE.md.

October 25 Step 56: local minimap and service usability implemented/tested; Step 57
first voyage gate next. Local chart uses ship frame, not geographic global projection.
Public network port/service request pending and timeout recovery remain outstanding;
reuse request identities and reconcile before retry, never auto-resubmit from HUD
refresh. Full local voyage regression passes; user acceptance of Steps 54–56 remains
pending. See LOCAL_NAVIGATION.md.

October 25 Step 57 audit: HOLD. Local double-delivery/restart, crash recovery and
loaded sailing checks pass. Missing public server port anchors, per-account job
state, durable public settlement and client service/manifest replication prevent
the required two-peer voyage test. Implement and verify these before Step 58;
standalone two-peer sailing is only a baseline. See FIRST_VOYAGE_GATE.md.

October 25 Step 57 integration update: public container contract transaction layer
now tested with real HTTPS/SQL crashes and handoff. Remaining: canonical port world
anchors, server-side docking/berth ownership, peer-bound command validation, reliable
owned-job state and client service/manifest presentation. Do not call backend port
assertions proof of physical eligibility. Step 57 remains open; no Step 58 yet.
See PUBLIC_VOYAGE_CONTRACTS.md.

October 25 Step 57 update: online physical ports, rebase-safe server docking and
client Dock/Undock are implemented and tested with two actual peers. Remaining:
validate cargo service requests against this authoritative docked state, call
canonical contract transactions, replicate owned job/manifest/wallet/receipts and
complete two-peer voyage/crash gate. Loading must lock undocking before enabling
peer-facing cargo acceptance. Step 57 remains OPEN. See PUBLIC_PORTS.md.

October 25 Step 57 update: online cargo command/UI/replication wiring now connects
physical docking to canonical contracts. Release two-peer cargo/reconnect/
settlement checks pass (38), plus physics/local voyage regressions. Protocol 11.
The test uses fixture approaches; full consecutive navigated two-peer voyages and
live interruption validation remain next before closing the gate. Public heavy,
refuel/repair and minimap integration remain outstanding. See PUBLIC_CARGO_SERVICES.md.


## October 25 player-request placements

See DEFERRED_PLAYER_REQUESTS.md for the full eight-item plan and Zelda picture
shortlist. Keep Step 57 first and original roadmap numbers unchanged.
- After 67/before 68: one-local-save/Restart Progress follow-up and turning-roll
  presentation follow-up. Migration/reset must preserve recoverability; no reset now.
- Before/at 88: Wind Waker HD art-direction brief and curved-world scale/rendering
  decision; integrate curvature with 89–90 and validate at 98/101.
- 91: angled, skippable docking camera with later ropes/loading presentation.
- 93: actual globe minimap supersedes temporary Step 56 flat chart.
- 96: subtle distant softening, bow/hull foam and wake polish, optional visual waves.
- 98: performance/readability validation; 108/122: save UX/accessibility; 123: art polish.
One local progression slot supersedes the player-facing three-slot intention;
online canonical profiles remain separate. Existing saves are untouched.
