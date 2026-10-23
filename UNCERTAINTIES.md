# Unresolved rules and decision deadlines

October 18, 2026 · Step 03 · `feature-and-uncertainty-inventory`

All U-rows below are **open** unless explicitly described as a selected baseline
awaiting proof. Confirmed Windows/helm-only scope, both hosting modes, public
portability/private isolation, shared public oil/refinery state, container starter,
and mandatory paid recovery are not reopened by this list. Step 02 already selects
identity/storage/authority rules; compatibility and failure proofs remain work.

**Agent** means the implementation agent owns proposing/documenting a rule and
running available technical checks. **Andy** owns material scope/preferences and
play-feel review. **Operator** means a future person responsible for public
infrastructure, not an already appointed party. The agent must surface an unmet
operator decision before deployment. Do not ask Andy to supply unknown source
formulas; choose explicit original game rules at the indicated task.

“Before N” means before dependent implementation begins inside that task, even
if the task itself contains the decision work. Temporary test values must be
labelled fixtures, isolated from trusted public state, and replaced/revalidated
before the relevant gate. No unresolved capacity, clearance, or cost means zero
or unlimited. Deadlines below refer to original roadmap numbers plus the stable
supplemental IDs in `BUILD_DEPENDENCIES.md`.

## Foundation and ship rules

| ID | Open rule / evidence limit | Owner | Latest decision point and required result |
| --- | --- | --- | --- |
| U001 | Baseline and local debug/release export verified at 04/06; representative performance and clean-machine Windows support remain open | Agent; Andy reviews practical target | `ENVIRONMENT.md` and `EXPORT.md` record exact engine, hardware and writable-data limits. Measure full 1080p/representative load at 24/32/57/98/124 before launch promises. |
| U002 | Partly resolved at 07: measured dimensions/axes/waterline, materials, sockets, collision reference and reproducible GLB import; art/provenance and gameplay acceptance remain | Agent inspects; Andy reviews style/provenance | `ASSET_CONVENTIONS.md` records preserved source and passed checks. Silhouette approval before catalog art/123; body/impact checks at 16/21; integration at 27. Capacity remains U014; loaded draft is not inferred from old metadata. |
| U003 | Partly resolved at 08: editable defaults, persistence and local focus/input gating; throttle increments, camera limits, broader UI scaling remain | Agent proposes; Andy playtests | CONTROLS.md records tested keyboard/mouse defaults and preferences. Session transitions and local/hosted pause policy tested at 09 (network transport still pending), throttle at 17, camera at 19; accessibility targets before 122. |
| U004 | Draft scalar address/revision, projections and pole frame verified by geographic-contract-feasibility; physical frame transport, scale and durable schema remain | Agent | `geographic-contract-feasibility` before 11 sketch; measured final choice at 25 and `connected-world-network-feasibility` before spatial durability 35–36/41. Never freeze tile IDs/global scene vectors as sole locations. |
| U005 | Steps 11–12 verify bounded integer units, explicit conversion rounding and fixture distance agreement; family settlement rounding, canonical payload hashing and receipt retention remain | Agent | Before 11 schema and 12 conversions; retention/retry policy before 35; family-specific rounding before 68/71/73/77. Test conservation and overflow boundaries. |
| U006 | Private binding/transaction/migration/backup proof complete; public PostgreSQL atomic receipt/concurrency/process-crash proof complete for isolated synthetic accounts. Production integration remains pending. | Agent | See STORAGE_PROOF.md and PUBLIC_STORAGE_PROOF.md. Integrate durable actions/saves at 35–38; real identity/leases at their later gates. |
| U007 | Step 11 records fail-closed migration/missing-content policy; autosave/slots/corruption/rollback implementation remains | Agent | Before 11 contracts and 35–38 durability; global clock/offline policy before 14. Restore and upgrade rehearsals at 115/127; ordinary crashes cannot erase accepted money/cargo effects. |
| U008 | Ship body, thrust/drag, braking, turn/side thrust, maximum speed, camera/feedback tolerances | Agent tunes; Andy approves feel | Before 16–19 consuming code, recorded handling checkpoint at 24; initial test values may change after 22. Recheck loaded/heavy and network behavior at 26/30–31. |
| U009 | Cargo mass/draft relation, depth query, grounding and collision envelopes | Agent | Before 21/23, validate empty/full hulls; include heavy geometry at 26 and spawn at 44. Do not substitute DWT/administrative limits for physical clearance. |
| U010 | Fuel burn curve/ticks, idle/reverse/thruster/docked/paused use and zero-fuel recovery | Agent proposes; Andy reviews pacing | Before 28: explicit configurable rule and a test-fixture recovery path. Actual paid refuel before 58 and recovery integration before 59. Never infer emergency propulsion or free fuel from source prose. |
| U011 | Dock speed/distance/angle, boundary equality, queues/occupancy, cancellation and safe spawn fallback | Agent | Before 44–46: numeric ship/berth rules, simultaneous requests, docked input/collision policy and recovery anchors; evidence from invalid/contended cases. |
| U012 | Damage/health/cooldown, sinking duration, fee/debt repayment, recovery fuel/condition and location | Agent proposes; Andy reviews economy | Loss/ownership/paid fee already fixed. Before 59 choose/test amounts, insolvent earning path, job cleanup and charge/loss atomicity; paid refuel implications decided by 58. No waiver or hidden free refill. |
| U013 | Component wear clock, offline/docked/stationary behavior, penalty/rust curves, repair units/prices | Agent proposes; Andy reviews costs | General offline policy by 14; exact channels/rates before 60 and repair charging before 62. Source 50%/80% thresholds and per-ship prices are candidates, not approved constants. |
| U014 | Starter capacity/funds/support, first-trip time/reward, catalog prices and first-upgrade target | Agent proposes; Andy playtests pacing | Sample definitions labelled at 10; first affordable earning loop before 49 offer/quote generation, revalidated at 57; purchase/upgrade targets before 63, economy check 67 and family balance 86. No automatic $5,000 wallet or mesh-derived capacity. |
| U015 | Active-ship count, fleet switches/despawn, resale eligibility/valuation and orphan jobs | Agent proposes | Before 65–66: define constraints and no-unusable-account path; reconcile cargo/jobs. Source 30% resale, ownership data cap and fleet count are not adopted. |

## Authority, online state and access

| ID | Open rule / selected baseline awaiting proof | Owner | Latest decision point and required result |
| --- | --- | --- | --- |
| U016 | Tick/input/snapshot rates, prediction, relevance and attached-payload ownership | Agent | Before 29–31 protocol behavior; basic interest/load proof at 32, seamless-boundary proof before 35; later 112 extends late join/relevance. Clients never author final economic/physics results. |
| U017 | Public synthetic resource/receipt schema, ordered locks, concurrency and crash/retry proof complete. Real ownership fencing, expiry and durable family reconciliation remain pending. | Agent | PUBLIC_STORAGE_PROOF.md passes the pre-35 adapter gate; real lease/transfer proof 41 plus integration gate before 42. Player-to-player economic trading is excluded (D064). |
| U018 | Practical player/ship capacity, hardware/bandwidth/storage budgets and load clients | Agent measures; Andy/Operator choose launch target | Early evidence at 32, representative world at 98; actual hosting/capacity commitment before 110. Approximately 100 is the design target, never an untested setting. |
| U019 | Component versions, Keycloak/PKCE/native callback, DTLS identity/trust, ticket/guest secret storage and recovery UX | Agent | `authenticated-admission-feasibility` before 40 or any real credential use. Existing Step 02 sign-in/guest policy stands; use test identities beforehand. 113 is rollout/hardening, not first trust design. |
| U020 | Lease/transfer timeouts, monotonic stop margin, quiesce/respawn, interrupted handoff and coordinated restore | Agent | Before 40–41; fault matrix and selected adapters pass `public-authority-integration-gate` before 42. Never revive a stale epoch, overwrite canonical state, or duplicate spawn/settlement. |
| U021 | UDP/NAT/relay path, trusted directory enrollment, private invites/passwords and join-error UX | Agent evaluates; Andy decides invitation scope | LAN direct path at 29; no internet promise before path tests; chosen public deployment path by 110, directory/browser/connection acceptance 116–118. Listing never changes economy trust. |
| U022 | Public operator, account/service host, storage/backups, domains/certificates, regions and budget | Agent prepares options; Andy/future Operator decide | Before 110 deployment and any service launch. No paid service commitment implied. Operational shutdown/abuse/restore duties documented by 115/119–120. |

## Cargo lifecycle and economy rules

| ID | Open rule / evidence limit | Owner | Latest decision point and required result |
| --- | --- | --- | --- |
| U023 | Per-family resume/cancel/complete/refund policy for every lifecycle event | Agent proposes and verifies | Base matrix/schema by 11/48, container policy before 49–51 and acceptance at 54; extend before bulk 68–70, gas 71–72, liquids 73–79 and heavy 80–82. Decide private/public outage and processing cases independently. |
| U024 | Offers: spawn/refresh/expiry, exclusivity, quoted terms, partial loads/unloads, loading clock/cancel | Agent proposes; Andy reviews pace | Before 48–50; persist at 51, prove simultaneous acceptance and boundary/retry outcomes. Source one-minute cap/subtype catalog are not adopted defaults. |
| U025 | Reward distance versus water-valid routes/ETA/odometer, modifiers and quote revisions | Agent | `starter-route-distance-proof` and container reward formula/distance policy/rounding/accepted quote terms before 49; verify payout at 53. Bulk/gas formula before 69/72; extend validation at 92–93. No sailed detour can inflate a separation-based payout. |
| U026 | Bulk commodities, hold/quantity/mass model, mixing, partial discharge, rate/modifier inclusion and same-port pay | Agent proposes | Before 68 capacity and 69 settlement; worked receipts and interruption/partials at 70. Source UI “profit/NM” is not certified net profit or our formula. |
| U027 | Gas commodity set, cubic-meter tanks, segregation, terminal permissions and delivery formula | Agent proposes | Before 71–72: explicit launch subset and same-port/partial/quote rules, bounded capacity and save behavior; reconcile research five/seven-gas disagreement through our own definitions. |
| U028 | Oil commodities/lot accounting, buy/sell spreads, ticks/bounds/volume effects, port offsets, quote expiry/rounding and external feed | Agent designs; Andy reviews risk | Contract before 73–74, two-server coherent pricing/account settlement before public 75 acceptance, cost-basis UI at 76. No external real-world feed dependency assumed; decide explicitly. Shared public market/private isolation are fixed. |
| U029 | Refinery yield/remainders, queue/rate/capacity, submission/withdrawal fees, stock ownership/expiry and offline/restart clocks | Agent proposes; Andy reviews pricing | Reserve facility/job/operation IDs at 11; exact lifecycle before 77; concurrent durable shared stock before 78; cargo-fuel loading/sale before 79. Source 10:7 conversion and server-local stock are not our rules. |
| U030 | Heavy-job world/session scope, spawn/claim TTL, payloads/masses, allowed lifters, alignment/attach/delivery/failure | Agent chooses engineering scope; Andy decides material play policy | Attachment envelope before 26/31; job scope/claim ownership before 80, controls before 81 and full lifecycle before 82–83. Transporting occupied player ships, if desired, needs explicit scope; do not confuse carrying with transfer of ownership. |

## World, presentation, content and conditional scope

| ID | Open rule / evidence limit | Owner | Latest decision point and required result |
| --- | --- | --- | --- |
| U031 | Connected-world physical method, navigation radius/scale, poles/seam, travel-time budget and streaming/rollback | Agent proves; Andy reviews travel feel | Geographic sketch before 11; actual method/range/travel timing at 25; network/payload/reload before 35. Refine 88–90 rather than choose an incompatible new world there. |
| U032 | Starter neighbor, exact coastline/port services/approaches, launch fleet/ports and onboarding targets | Agent proposes; Andy selects content | Usable pair before 43/49; geography/service authoring plan before 88/91; explicit selected launch catalog before 99/100. Ten concept names retained as design baseline; Harbor Point/seed coordinates/services remain proposals. |
| U033 | Water/weather quality, day/night duration and weather probabilities; whether physical wind/current/waves are wanted | Agent handles presentation; Andy decides expanded physics | Simple visuals by 20; presentation rules before 96. Any physical-force proposal needs a separate measured change before affecting handling/fuel/rewards; no implicit core requirement. |
| U034 | Maximum launch hull loaded/air-draft envelope, Panama width/depth/clearance and optional moving infrastructure | Agent proves; Andy decides optional infrastructure | `launch-hull-passage-envelope` before 94/detailed Panama; choose or defer moving locks before 95. Open fixed bridge/passage cannot silently become a compulsory lock/war/level barrier. |
| U035 | Name limits, flag/paint palette and material/customization save validation | Agent proposes; Andy reviews appearance | Before 102; source paint-region data may inform inspection but cannot overwrite supplied model structure or shared materials. |
| U036 | UI/accessibility and audio targets, asset provenance, quality/voice budgets and user settings | Agent proposes/tests; Andy reviews usability | Baseline settings before 08, budgets before 121–122 and tested at 124–125; only licensed/original assets, no source horn catalog quota. |
| U037 | Resolved October 20, 2026: no player-to-player economic transfers, gifts or trades | Andy excluded peer economy | Steps 103–105 are not applicable. Game-owned shops/services/cargo payments remain required; multiplayer sailing remains in scope. |
| U038 | Whether achievements are included, criteria, reward amounts and anti-replay/odometer accumulation | Andy decides scope; Agent designs/tests if selected | Before 106; selected events must join durable ledger/receipt audit 107. Source badges, historical grants and grind targets are not automatically core. |
| U039 | Extra camera modes and any crew/shared-income/chat/party systems | Andy decides scope; Agent supplies design | Camera extras before 19 if requested; social/crew systems require a separate accepted proposal before networking/economy additions. No current implementation commitment. |
| U040 | Ro-Ro/mixed cargo: car representatives, controls, ramps, loading/partial/cancel/loss, permissions and network transitions | Agent proposes; Andy selects expansion feel | Before 129 design and 130–134 implementation; carry forward vehicle-specific state/save/quote proofs, not core placeholders. No research speed/count is binding. |
| U041 | Rocket models/contracts, cost/rewards, failure RNG, launch radius/lock, abort/recovery and interruption | Agent proposes; Andy selects expansion rules | Before 136 contract; durable stages at 137–141. No early-access narration or paid failure protection becomes a requirement. |
| U042 | Walking/passengers/furniture, aircraft/sails, historical quests/events or new original features | Andy selects future scope; Agent maps dependencies | Before activating a separately accepted module. Create stable task IDs, authority/lifecycle tests and a checkpoint; none block version 1 or are silently added by inventory. |

## Evidence policy and resolution workflow

Research facts come from the supplied reference's wiki/changelog/caption record;
exact live parity is unproven. Unknown source-game constants need not be guessed
or reverse-engineered before choosing our original values. Explicit research
gaps above are design inputs, not claims that those features already work.

Before implementing a due rule, record the selected rule, affected state/owner,
units, inputs/outputs, invalid/interruption cases and validation evidence. Add a
stable decision ID to `DECISIONS.md`, update the U-row's status/reference, and
revisit affected features/dependents. Resolve engineering choices autonomously;
ask Andy for material remaining scope/play-policy choices only at their deadline.
Do not mark an uncertainty resolved solely because a task was scheduled.

U008 update (Step 16): initial planar CharacterBody3D and thrust/drag fixture selected in HANDLING_PROTOTYPE.md. Loaded handling, steering, camera and Andy's approval of feel remain open.

U008 update (Step 17): command/engine ramping and limits are implemented and checked; values remain provisional pending handling-feel approval.

U008 update (Step 18): rudder/thruster fixture parameters and astern rule implemented; tuning and controlled-body lateral grip remain provisional pending handling-feel review.

U008 update (Step 19): orbit/zoom/recenter and two-size focus/pier checks complete; camera distances and smoothing remain subject to feel review.

U033 update (Step 20): initial water art is bold blue with flowing pale patterns; coastal palette retained for future regions. Three quality tiers and visual-only bobbing verified. Physical waves/current/wind remain unapproved; no networked sea state implemented.

Step 21 collision checkpoint: current planar hull/shore contacts verified through 20 m/s. Real ship geometry, moving-body mass exchange, grounding, damage and network reconciliation still require their later implementation/checks.

U008 update (Step 22): playable feedback baseline recorded and automatically verified. Andy's acceleration/braking/turning/camera/docking and sound review is pending; controller approach and tuning are not locked.

U008 update (Step 23): Andy accepted the overall handling feel; preserve baseline.
U009 update (Step 23, supersedes depth/grounding requirement): Andy approved all
open water navigable for all ships. No hidden shallows or grounding restrictions.
Normalized visual load preview implemented; actual cargo mass/capacity connection
and final hull-specific visual offsets remain pending. Keep visible solid boundaries.

U008 update (Step 24): accepted handling now has fixed-input playback and numerical
reference tolerances; deliberate thrust mutation proves the regression guard.
Loaded/network behavior remains a later check, not inferred from these fixtures.

U004/U031 update (Step 25): selected scalar-double global addresses with shared
local-meter patches and coordinated frame mapping after measured precision loss
in distant float32 controls. Seam/poles, circuits, shared hull contacts and camera/
velocity/attached-visual mapping verified in the isolated experiment. 100 km radius
is the provisional measurement profile; final authored travel pacing remains open.
Production streaming/rebase integration and network/payload/reload proofs remain
the connected-world-network-feasibility gate. See WORLD_SIZE_EXPERIMENT.md.

Step 28 update for U010: configurable simulation and explicit empty/test-recovery rules implemented and checked (D057, FUEL_SIMULATION.md). Rates and tank sizes remain provisional pending Andy's pacing review; paid refueling/recovery and authority are still later gates.

October 22 update: U017/U020 now have real PostgreSQL/HTTPS lease, receipt and
transfer proofs in PUBLIC_PROFILE_HANDOFF.md, including separate adapter processes
and crash recovery. Integrated OIDC admission, Godot simulation fencing, renewal
cadence and production timeout tuning remain open until the pre-42 gate and later
rollout measurements. U019's OS credential persistence/recovery UX remains open.

October 22 adapter integration update: U017/U020 now have real Godot live-hull
fencing, automatic renewal and canonical departure checkpoints connected to
OIDC-protected HTTPS tickets. See PUBLIC_GODOT_OWNERSHIP.md. Public DTLS peer
admission, provider key-rotation operations, player sign-in/recovery UX, periodic
spatial saves and production timeout/capacity tuning remain open. U019 is unchanged.

October 22 U017/U020 follow-through: real authenticated peers now control only
their installed hull; disconnect persistence, automatic authority-loss fencing,
two-account isolation and headless startup pass editor/Release. Pending work:
shared geographic placement, periodic spatial saves, operator registration/key
rotation, graceful shutdown, player sign-in/browser UX and congestion/capacity
measurement. See PUBLIC_PEER_ADMISSION.md. No production availability is inferred.

October 22 nearby presentation update: authenticated clients now materialize nearby
hulls in recipient-relative geographic charts. Shared collision/spawn placement,
player-facing camera/login flow, periodic saves and capacity remain unresolved.
Headless node checks do not establish final visual quality. See PUBLIC_NEARBY_BOATS.md.

October 22 shared physics follow-through: nearby public hulls now collide in shared local spaces and blocked saved spawns are refused without save mutation. Starting-berth allocation, blocked-spawn UI, group-threshold performance/capacity and visual validation remain open; this is the existing kinematic collision model. See PUBLIC_SHARED_PHYSICS.md.

Public client follow-through: camera/helm/HUD now connect to authenticated snapshots. Browser login/enrollment and server-selection entry, public water movement/wakes and visual/latency evaluation remain open. Tests are headless. See PUBLIC_CLIENT_SCENE.md.

October 22 browser-entry follow-through: native callback, PKCE token exchange, approved server selection and HTTPS-ticket admission now connect the public player scene. Persistent provider/authority deployment, enrollment and starting positions, live discovery and production certificate/key operations remain open. Headless tests simulate provider navigation, not interactive system-browser appearance. See PUBLIC_SIGN_IN.md.

Persistent local setup follow-through: LocalOnline.ps1 preserves two development
identities and canonical profiles across full restarts. This does not resolve real
account enrollment, production deployment, certificate/key rotation or general
safe spawning. Browser trust is deliberately not installed automatically; interactive
browser acceptance remains pending. See LOCAL_ONLINE.md.

October 23: periodic public spatial/fuel checkpoints and an operator-triggered final
save/release drain are implemented. A 10-second schedule is not a hard rollback bound;
request delay and in-flight work add latency. Backend outage or replacement fencing
may prevent a final save and must report failure. Crash recovery uses committed state.
Production durability/latency budgets and capacity remain to be measured. See PUBLIC_DURABILITY.md.
