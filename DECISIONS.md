# Shipping Lanes decisions

October 18, 2026 · Initial record for `project-contract`

`GAME_SPEC.md` is the concise local scope contract. Keep requirement decisions
separate from proposed implementation choices and append deliberate revisions.

| ID | Status | Decision and basis |
| --- | --- | --- |
| D001 | Confirmed | Windows, Godot 4.7; observed setup build `4.7.2.stable.steam.ed1daf0bf`; typed GDScript. The PC/project is accessible now, superseding the old planning limitation. |
| D002 | Confirmed | Version 1 uses helm controls only. Walking, boarding, passengers, and furniture are deferred even where generic roadmap text mentions them. |
| D003 | Confirmed | Core cargo is containers, bulk, gas, oil trading/refining, cargo fuel, and heavy lifting. Vehicles and rockets follow core release. |
| D004 | Confirmed | Both player-hosted and dedicated sessions; Multiplayer server list; hosts choose listing/privacy. Approximately 100 dedicated players is a target to measure, not supported capacity. |
| D005 | Confirmed | Public money/fleet progression follows accounts with one active public ownership session. Player-hosted saves stay isolated regardless of directory listing. |
| D006 | Confirmed | Public oil market and refinery stocks are shared across our public servers; private-host equivalents stay isolated. Offshore heavy-job scope remains open. |
| D007 | Confirmed | Small container starter; ordinary ports open subject to physical/service limits; name/color/flag customization; earned currency, without real-money gameplay monetization. |
| D008 | Confirmed | Sinking loses current cargo, preserves ship ownership, and charges recovery on every ship. Debt/repayment mechanics and rates are provisional. |
| D009 | Selected design direction | Map reference adds a connected Earth-inspired world with fictional islands, a globe map, circumnavigation, and fictional Panama passage/bridge. Physical method, seed coordinates, services, Harbor Point, and launch count are not finalized. |
| D010 | Partly resolved | Initial engineering defaults: shared definitions/separate runtime records, authoritative actions, streamed scenery, retry-safe transactions, versioned saves and placeholder art require dependent proofs. Compatibility renderer is selected/verified in D021; host departure is specified in D017. |
| D011 | Resolved in Step 02 | Identity/storage, public leases/handoff, and host departure are defined in `ONLINE_ARCHITECTURE.md` and D012–D017. Hosting budget and deployment remain open. |
| D012 | Selected engineering baseline | Public sign-in uses self-hostable Keycloak/OIDC with issuer+subject mapped to internal accounts. Native browser authorization code + PKCE; no public guests initially. Private/local worlds support host-issued world-scoped guests and reconnect credentials. Not installed or integrated yet. |
| D013 | Selected engineering baseline | Central HTTPS account/economy service + PostgreSQL owns all durable public progression, shared market/refinery state, leases, transfers, and operation receipts. Private hosts use per-world SQLite; validate/pin Godot binding before save implementation. |
| D014 | Selected engineering baseline | Godot ENet/UDP, shared authoritative host/dedicated gameplay path; authenticated DTLS before credentials, HTTPS service calls. Direct LAN connectivity first; internet NAT/relay path remains to be proven. |
| D015 | Required architecture rule | One backend lease owner per public account, with increasing fencing epoch, server-instance identity, backend expiry, and atomic lease checks in every persistent operation. Stale or uncertain owners stop consequential simulation; no fallback public economy. |
| D016 | Required architecture rule | Source quiesces/reconciles and backend seals canonical state while revoking old authority. Destination claims the durable transfer once with a new epoch; retries/crashes resolve through backend records. Scenery travel never transfers server ownership. |
| D017 | Selected engineering baseline | Player-host departure ends the session: graceful commit/disconnect or crash recovery from last valid commit. No host migration in version 1; clients cannot promote cached saves. |
| D018 | Planned dependencies | Step 03 assigns 56 feature/scope rows, 42 unresolved rule groups and eight supplemental prerequisites in `FEATURE_INVENTORY.md`, `UNCERTAINTIES.md` and `BUILD_DEPENDENCIES.md`. Original roadmap IDs/numbers stay stable; none of those future checks is marked passed. |
| D019 | Scope interpretation | Peer trading, achievements, extra social/crew systems, physical weather forces and moving infrastructure remain conditional. Core fixed Panama/globe/circumnavigation and helm-only goals govern older generic roadmap wording. Shop purchase/resale and core reward auditing remain required. |
| D020 | Received asset reference | Andy supplied `starter_container_01.blend` from Downloads for later use. Inspect it at Step 07 before making replacement art; receipt does not certify geometry, rights, scale, import or gameplay capacity. Original source remains outside the project. |
| D021 | Selected and startup-verified | Step 04 pins exact Godot 4.7.2 Steam executable/hash and Compatibility/OpenGL. Actual RTX 3070 native startup, full editor import and isolated user-data write/read passed. Hardware and limited UI pacing evidence are in `ENVIRONMENT.md`; no gameplay/capacity claim. |
| D022 | Verified development workflow | `tools/Godot.ps1` runs a hash-checked local engine copy with portable editor settings and a child-only APPDATA directory. Steam/user-wide configuration remains untouched. This resolves the sandbox path issue for our workflow; later saves must account for this isolated data location. |
| D023 | Selected project structure | Step 05 groups scenes/scripts/resources by feature under `features/`. Main composes an empty World Node3D and a UI CanvasLayer. Scope/progress records remain at the project root; further feature folders are added with their implementation tasks. |
| D024 | Local recovery baseline | Git is rooted only in `ShippingLanes`, tracking source and `.uid` sidecars while ignoring generated caches/builds and local credentials. Local tags preserve Steps 04 and 05; commits identify the automation as Codex without changing user-wide identity. No remote is configured. |
| D025 | Export smoke verified | Step 06 pins/stages matching Windows x86_64 templates and builds debug/release EXE + external PCK. Both launch outside the editor with writable child APPDATA. Normal-profile sandbox shader-cache writes remain restricted; see EXPORT.md. |
| D026 | User-selected art direction | Andy's coastal photograph supplies muted blue-green/blue-gray ocean, warm brown-gray rocks and pale foam, with regional variation allowed. ART_DIRECTION.md and three material swatches preserve this direction for later terrain/water implementation. |
| D027 | Import-verified asset conventions | Metres, Blender -Y bow/+Z up to Godot +Z bow/+Y up, reference empty waterline at Y=0. Explicit GLB export from preserved source using Blender 3.6.1; calibrated axes, sockets, outward name normals and measured envelopes. See ASSET_CONVENTIONS.md. |
| D028 | Starter prototype separation | Empty ship visual exports separately from preview cargo and from its editable wrapper/convex hull reference. Stable asset and future ship-definition IDs survive reimport. Physics body choice remains Step 16; commercial capacity and loaded draft remain undecided. |
| D029 | Input foundation verified | Physical keyboard bindings, fixed mouse orbit/wheel actions and validated local JSON preferences are owned by Main's PlayerControls. Menus, GUI focus and window focus gate all vehicle requests; release controls before resuming. Walking stays deferred under helm-only scope. See CONTROLS.md. |
| D030 | Preferences and export boundary | Settings drafts apply only after successful Save; invalid/future data uses defaults without automatic overwrite. Main and the script-loaded defaults Resource are explicit export roots. Session pause/title/continue behavior remains Step 09. |

| D031 | Application flow and branding | Container Ship Sim is the visible menu/window title; internal Shipping Lanes preferences path stays stable. Play uses a local hosted-policy fixture until quick-join exists; Servers is an honest placeholder. Continue is in-memory only. No global tree pause; gameplay reset preserves preferences. |

| D032 | Definition ownership | Four prototype records use stable IDs; the starter ID is preserved. Registry owns defensive copies, validates references transactionally, and per-ship fuel/cargo live only in ShipState. No prototype amounts establish balance or save contracts. |

| D033 | Draft geographic identity | Scalar latitude/longitude/altitude and explicit world revision/meridian heading frame survive projection and JSON tests. Exact pole retains a meridian hint. Unit-sphere math does not choose physical scale, local origin transport or final save schema. See GEOGRAPHIC_CONTRACT.md. |

| D034 | Private SQLite binding proven | Pin godot-sqlite v4.9 Windows x64 (runtime SQLite 3.51.0). Use launcher pre-registration for fresh imports. Transaction/migration/backup/process-kill tests pass in editor and both exports; power-loss, production concurrency and public adapter remain unproven. |

| D035 | Draft save/protocol contracts | Versioned plain JSON records validate before acceptance; no resource/script loading from saves. Integer minor credits, milliliter fuel and explicit cargo units are bounded. Migration policy fails closed and preserves prior saves. Actual persistence, authorization and replay handling remain later work. |

| D036 | Units and distance | Explicit compatible dimensions only; integer minor-credit money and checked arithmetic. Prototype scales are 1:1, not final geography. One fixed millimeter route measurement feeds navigation and payout fixtures; holds, slots, mass, DWT and volume never substitute for each other. |

| D037 | Session mutation ownership | A per-session authority owns fixture player/ship/wallet/cargo. UI sends a narrow revision-based request and reads copies; approved state publishes together. Continue retains authority in memory. This does not implement durable replay handling or authenticate network clients. |

| D038 | Simulation clock lifecycle | Authority owns 50 ms operation ticks and monotonic baseline/remainder. At most 250 ms per sample is credited; no queued offline catch-up. Hosted menus continue, offline pause freezes, Continue transfers/reanchors, and replacement/teardown cancels pending test work. Public backend and durable timers remain later work. |

| D039 | Developer diagnostics | Default-off Ctrl+F3 overlay reads copies and shows absent motion fields honestly. CheckProject combines import, all-script compilation, unit/catalog and overlay checks; Full runs 11 stages. Empty-menu timing is not representative performance evidence. |

Source precedence: Andy's later explicit decisions, then confirmed choices in the
supplied design documents; proposals remain proposals. Research describes another
game and cannot override our requirements. The map guide adds selected visual
goals without silently fixing physical implementation or launch catalog size.

Step 01 adds documentation only. It does not implement online architecture,
world geography, gameplay, or assets.

Step 02 records the online architecture only. The selected providers are a
development path, not deployed services or measured multiplayer support. Later
implementation must pass the proof matrix in `ONLINE_ARCHITECTURE.md` before
these rules can be claimed as working behavior.

Step 03 maps feature coverage and decision deadlines only. Due rules must be
resolved before their dependent implementation; known evidence gaps do not
become approved formulas just because they appear in the inventory.

| D040 | Initial handling body | CharacterBody3D, floating mode, explicit 60 Hz physics; +Z bow and planar linear-drag motion. Force-driven body reconsidered only if contacts/buoyancy require it. See HANDLING_PROTOTYPE.md; tuning remains provisional. |

| D041 | Throttle prototype | Retained command with independent bounded engine output; +100% / -60% limits, ramp through neutral on reversal, X zero preserves momentum. ShipDefinition owns validated provisional tuning. Input focus/menu loss orders neutral. |

| D042 | Maneuvering prototype | Rudder yaw scales with signed forward speed, with bounded rate and acceleration; astern reverses yaw. Paired lateral thrust translates without yaw, fades with speed, and is bounded by lateral drag. ShipDefinition owns six validated tuning fields. Controlled local velocity rotates with hull; realistic sideslip/angular contact deferred. |

| D043 | Camera rig | Explicit CameraFocus interface, hull-relative zoom, heading-relative orbit and exponential smoothing. Sphere sweep shortens the camera arm around solid geometry, excluding the target hull; recovery smooths. No fixed ship path. See CAMERA.md for target-switch and collision limits. |

| D044 | Water art and motion | Andy selected bright bold blue with broad pale animated patterns from his stylized reference; muted coastal colors remain for later areas. Original opaque procedural shader, visual-only waves/bobbing, steady body/collider/camera focus. Saved Low/Medium/High tiers; no physical sea forces. |

| D045 | Prototype collision | Swept CharacterBody movement at 60 Hz, 20 m/s total cap, no bounce impulses; conservative angular overlap guard prevents hull turning into solids. Hull/shore are solid layers; triggers, cargo visuals and characters separate. Vertical shore proxies and clear spawns required. See COLLISION.md. |

| D046 | Handling feedback baseline | Read-only instruments and original synthesized engine/thruster/horn cues; unconnected fuel labelled honestly. No handling retune or controller lock before Andy's required comfort/docking playtest. Baseline and prioritized pending review in HANDLING_FEEDBACK.md. |

| D047 | Handling acceptance | Andy loves the current overall feel and approved continuation. Preserve the Step 22 baseline; later loaded/network behavior still requires verification. Supersedes D046 pending overall-feel review. |
| D048 | Navigable water and visual draft | Andy approved no confusing shallow areas: all open water supports all ships. Cargo affects visual hull height only at this step; no grounding or depth restriction. Visible land/rocks/docks remain solid. Prototype preview sink is 0–0.85 m, not final ship specifications. |
| D049 | Water effects follow-up | After visual draft, add Step 23B for original Zelda-inspired bright-blue water, white bow/hull foam, speed-responsive ripples and fading wakes; preserve handling physics. |

| D050 | Ship water effects | Original procedural pale ribbon crests driven by actual velocity; bounded world-space history fades over eight seconds. Hull/leading-end foam remains presentation only, matches water quality/palette, and preserves accepted handling. Prototype dimensions require fitting to final hull art. |

| D051 | Simulation regression references | Fixed 60 Hz input segments replay production unobstructed motion with explicit recorded SI tolerances. Cover acceleration, braking, turning, coasting, thrusters and separate command/output telemetry. No bit-identical cross-machine physics promise or invented fuel consumption. Keep collision/render-cap checks alongside numerical playback. |

| D052 | World coordinate method | Step 25 measurements reject unbounded float32 scene coordinates: slow movement disappears by the 100 km control. Select scalar-double geographic identity plus shared local-meter physics patches and coordinated frame transport. Preserve continuous circumnavigation and one session. Tested +/-1 km local range; prototype reframe target 500 m. No custom double engine needed for this scope. |
| D053 | Experiment scale and integration gate | Use a 100 km navigation radius for the isolated experiment and compare 50/250 km travel budgets. Final voyage pacing and authored port separations remain unresolved. This selects a technical method, not a finished map or production networking/spatial schema. See WORLD_SIZE_EXPERIMENT.md. |

| D054 | Heavy-lifter visual prototype | Andy requested Blender authoring matching the starter boat. Original 90 x 24 m faceted heavy carrier, separate moving deck and industrial payload reuse the starter material palette. Preserve editable .blend and GLBs; dimensions are feasibility values, not fleet ratings. |
| D055 | Secured large payload | Extend the existing kinematic controller with a moving deck and one compound cargo collider. Switch collision ownership at attach/release; no stacked dynamic bodies. Check alignment, neutral/stopped state and swept lift clearance. Prototype fixture alignment helper is not a production cargo job. |

| D056 | Reusable ships | One HandlingShip controller, shared ShipHelm and ShipAssembly, self-contained runtime scenes and definition-driven hull/camera/wake/cargo geometry. Heavy special deck behavior extends the shared body. Preserve starter tuning; heavy uses gentler provisional acceleration and turning. See SHIP_COMPOSITION.md. |

| D057 | Prototype fuel policy | Actual engine output plus configurable idle/reverse/lateral burn; no paused burn, default zero docked burn. Empty cuts powered output but preserves coasting/rudder. Stopped/neutral test refill proves recovery, not production free fuel. Rates/capacities await Andy's pacing review. Paid services and authority follow later. See FUEL_SIMULATION.md. |

| D058 | Local network lifecycle | ENet loopback-only two-process fixture, host authority 1, random session epoch plus monotonic entity IDs, reliable revisioned rosters and idempotent hello. Rejoining creates a fresh temporary guest entity; no durable identity or credentials. Ships remain stationary until Step 30. See LOCAL_NETWORK_SESSION.md. |

| D059 | Ship replication | Host-only 60 Hz physics/fuel, validated 20 Hz helm intent, 20 Hz authoritative snapshots, 150 ms client interpolation buffer, 500 ms stale-input neutral. Separate unreliable-ordered motion channels. Tested 100 ms each-way jittered delay and 10% application-message loss. Defer prediction pending feel review/later internet measurements. See SHIP_REPLICATION.md. |

| D060 | Networked attached cargo | Owner-validated reliable sequenced cargo commands; self-contained cargo state inside each ship snapshot. Apply parenting/deck changes on the ship interpolation timeline. Host alone switches compound/floating collision ownership. Reconnecting observers rebuild retained loads; temporary guest ownership and later save gates remain unchanged. See ATTACHED_PAYLOAD_NETWORKING.md. |

| D061 | Connected-world spatial contract | Two-process seam/polar transitions retain geographic identity, host ownership and attached cargo with bounded local coordinates. Keep scalar geographic fields for saves; make network chart changes atomic with epoch/entity/revision and cargo parenting. Approve this field/transition basis within the measured 100 km experimental profile; final world catalog/scale, durable adapters and playable buffered-motion/wake integration remain explicit later work. See CONNECTED_WORLD_NETWORK.md. |

| D062 | Early multiplayer capacity | Measure 2/10/25/50/100 real loopback connections with production hull motion, synthetic input/actions, reconnects and one separate observer. Use grid-based nearby relevance; retain host physics. The 100-crowded prototype passes bounded-work checks but 71.154 Mbps egress, 6,124-byte messages and rendered acknowledgement p95 227 ms require bounded/delta packet and client-pacing integration before Step 42 or production multiplayer expansion. No production 100-player rating or internet readiness is declared. See CAPACITY_EXPERIMENT.md. |

| D063 | Session action validation | Fixed typed request/result fields for helm and harmless test pulse; transport sender and current roster determine ownership. Canonical kind/sequence action IDs, 128 receipts per live entity and retained per-kind high-water marks prevent duplicate effects even after receipt eviction. Exact retries return original results without refreshing helm timeout; failed rate-limited requests remain failed on retry. Protocol 4; temporary peer identity and in-memory receipts are not public account authentication or durable economic idempotency. See ACTION_VALIDATION.md. |

| D064 | No peer economy | Andy explicitly excludes player-to-player money/ship/cargo transfers, gifting and trading. U037 resolved; F047 and Steps 103–105 are not applicable. Game-owned purchases/resale, service fees and earned job/cargo payments remain core. Multiplayer sailing remains in scope; D019's conditional peer-trading option is superseded. |
| D065 | Atomic fixture economy | Integer minor units and cargo counts, server-owned prices, prepare-and-publish balances/inventory/journal/receipt together. One retained outcome per action ID; reject payload conflicts and stop new operations at receipt capacity rather than evicting payment receipts. Fixed game-to-player operations only. This is in-memory Step 34 arithmetic/authority proof, not durable public settlement; storage proof and Step 35 remain required. |
| D066 | Public adapter proof | Pin PostgreSQL 17.11 and psycopg 3.2.10 behind a separate loopback-only synthetic Python service. Lock affected rows in stable order before receipt lookup; commit resources, journal and retained outcome atomically. Godot receives only a service token, never database credentials. Real process crashes/restarts and concurrent HTTP calls pass the bounded adapter gate; HTTPS/OIDC, fencing, production scale and game save integration remain required later. See PUBLIC_STORAGE_PROOF.md. |
| D067 | Durable private economy | SQLite immediate transaction commits snapshot and terminal receipt together; publish memory/reply after commit. Validate ordered receipt replay against snapshot on restore, fail closed without reset, retain all outcomes indefinitely and refuse new intents at the prototype 1,024 bound. Reconcile uncertain outcomes with the same ID/payload. SessionAuthority exposes explicit private-store binding; full-world save/startup integration remains Step 36. See DURABLE_ACTION_RECOVERY.md. |
| D068 | Versioned private world saves | Persist starter geographic pose/fuel and stable ownership IDs in versioned current/previous SQLite checkpoints, with native backup. Recover spatial state without rewinding the durable economy. Default Play and menu-entered starter handling use one local development world; autosave at 10 seconds and normal departure, restore stationary/neutral. Unrecoverable/unsupported saves fail closed, full-backup rollback requires later explicit recovery. See LOCAL_PERSISTENCE.md. |
| D069 | Private save migration | Upgrade world schema 1 to 2 with explicit cargo identity/neutral restart policy, native pre-upgrade backup and one atomic checkpoint/header transaction. Advance generation to fence stale spatial writers; leave all economic rows/receipts unchanged. Missing or unsupported content/versions block with an actionable menu message, preserving progress and separate preferences. See SAVE_MIGRATION.md. |
| D070 | Local recovery interface | Three fixed private development slots; create only in empty slots. Confirm backup-time rollback and copy/validate into an empty destination with a pending marker; never overwrite the source or silently initialize an interrupted copy. Slot selection lasts for the application run and clears prior continuation. No deletion or public-profile imports. See SAVE_SLOTS.md. |
| D071 | Same-host reconnect | Protocol 5 binds a loopback-only session credential to one retained guest record. Park disconnected hull/payload without physics; rebind the same entity on return. Retain per-entity durable fixture money/receipts, reset transient control streams, and reject replacement ownership without the credential. Host departure ends the session; no host migration or automatic host-world restart recovery. Authenticated admission/durable identity remain next gates. See RECONNECT_LIFECYCLE.md. |

| D072 | Authenticated admission feasibility | Keycloak 26.8.1 authorization-code/PKCE S256 with validated RS256 issuer/subject identity; scoped expiring single-use PostgreSQL tickets and hashed private guest credentials. Configure ENetConnection DTLS before connect, then attach the verified connection as the client's sole server peer; ordinary server authority remains. Memory-only client secrets until OS storage is proven. Separate provider, registry and editor/export RPC proofs pass; system-browser UI, integrated service admission, gameplay fencing and leases remain Steps 40–41 plus the pre-42 integration gate. See AUTHENTICATED_ADMISSION_PROOF.md. |

| D073 | Private durable identity/control | Private protocol 6 uses explicit certificate-pinned invitations and verified ENet DTLS before credentials. Stable SQLite world/member/ship IDs and hashed 256-bit guest credentials survive host restart; generation-tagged commands and atomic generation-checked spatial writes fence replaced bindings. One active guest helm; valid reconnect replaces itself, unknown credentials cannot seize progress. Client credentials remain memory-only; per-member fixture economy receipts persist. Step 40 selects this private path; public service admission, leases and handoff remain Step 41 and the pre-42 gate. See PRIVATE_SESSION_IDENTITY.md. |

| D074 | Public profile/lease/handoff adapter | PostgreSQL locks one lease per account and checks backend-clock expiry, server approval, epoch and connection generation in the profile/receipt transaction. Scoped protocol-7 tickets admit or claim; quiesce/seal fences the source, destination claim advances epoch once, expired/abandoned transfers recover canonical state. Payment receipts survive transfer; late claim retries return current profile state without renewing the lease. Real HTTPS adapter workers and process/database crashes pass Step 41's fixture option. Integrated OIDC/Godot simulation fencing and public deployment remain separate gates. See PUBLIC_PROFILE_HANDOFF.md. |

| D075 | Public Godot ownership adapter | Validate OIDC access tokens at the HTTPS ticket service against operator-pinned issuer/audience/signing keys, map enrolled issuer/subject accounts, and give Godot only scoped server credentials/tickets. A monotonic lease deadline and ten-second renewals fence live hull physics/collisions/input; departure commits actual fuel/geographic position before seal. Fresh acquisition restores canonical identity at neutral. The operator courier is a test boundary: public DTLS peer admission, player login UI, world/cargo integration and deployment remain open. See PUBLIC_GODOT_OWNERSHIP.md. |

| D076 | Public authenticated peer transport | Protocol-7 tickets are redeemed after pinned DTLS verification using a server-generated per-connection challenge and actual certificate-file fingerprint. Transport sender plus server-installed ship/epoch/generation gates reliable sequenced helm orders; 5 Hz owner snapshots use a separate unreliable channel. Replacement/disconnect/outage fence live hulls. Two accounts and the normal headless configuration entry are proven; isolated charts, public UI, shared cargo/world placement and pacing remain explicit gates. See PUBLIC_PEER_ADMISSION.md. |

| D077 | Public nearby boat presentation | Send complete 5 Hz nearby rosters only to authenticated owners, map scalar geographic addresses into each recipient chart, and instantiate inert smoothed hull replicas. Bound to eight peers and 1 km relevance; remove stale/departed/replaced boats. Separate server physics charts remain until safe shared placement/collision integration; public UI and capacity gate stay open. See PUBLIC_NEARBY_BOATS.md. |

| D078 | Public nearby shared physics | Group canonical hulls within 250 m into shared World3D charts, split/merge before physics, and rebase after 500 m while preserving pose/velocity/fuel. Lock public hull vertical translation; refuse occupied saved spawns and release the lease without teleporting or checkpointing. Eight-peer development cap, existing kinematic collision model, and public UI/capacity gates remain. See PUBLIC_SHARED_PHYSICS.md. |

| D079 | Playable public client scene | Compose authenticated replicas with the existing ocean, orbit camera, opaque HUD and saved input controls. Send sequenced throttle/rudder at 10 Hz only with fresh owner/roster state; neutralize on menu, focus loss, stale state or disconnect. Expose challenge/ticket hooks for future browser sign-in without adding password storage or fake admission. Main-menu entry and public gameplay/capacity gates remain open. See PUBLIC_CLIENT_SCENE.md. |

| D080 | Native browser sign-in and server selection | Use an operator-provided public server allowlist and native Godot authorization-code/PKCE S256 with a loopback callback. Only the HTTPS authority validates token identity and enrollment; game-server DTLS verification precedes nonce-bound ticket issuance. Cancel/timeout clear transient state, redirects are disabled for credential requests, and access/refresh tokens are not persisted. Servers opens the entry screen; configured Play uses it, otherwise local development Play remains. Live deployment/enrollment and capacity gates remain open. See PUBLIC_SIGN_IN.md. |

| D081 | Persistent local online development | Package the pinned provider, PostgreSQL, HTTPS authority and normal Godot dedicated runtime under a loopback-only supervisor. Keep generated development accounts/data in a protected output directory and use a separate client APPDATA profile. Preserve issuer/subject/account/ship identity on restart; fixed separated fixture starts are not general berth allocation. Do not alter browser/OS trust or deploy publicly. See LOCAL_ONLINE.md. |

| D082 | Public sailing checkpoints and operator drain | Attempt a coherent position/heading/fuel save every 10 seconds while sailing; revision/lease checks remain authoritative. Serialize final departure/transfer saves against periodic work. Operator-owned stop files request a bounded 20-second drain; only confirmed final saves/releases report success. LocalOnline waits before stopping backends. Crashes/outages/replacement fencing recover committed state and may report incomplete final saves. See PUBLIC_DURABILITY.md. |

| D083 | Compact eight-peer snapshots and latest-input pacing | Keep the current eight-peer cap. Use complete 32+40N-byte binary frames at 10 Hz with validated UUID/generation/local pose and owner fuel/speed/acknowledgement; bound serialized arguments to 1,200 bytes. Send sequenced helm orders unreliable-ordered using monotonic 100 ms deadlines without catch-up bursts. Full frames recover without delta history. Measure this bounded path; retain latency/loss/rendered and capacity gates. See PUBLIC_NETWORK_PACING.md. |

| D084 | Controlled encrypted network impairment evidence | Test the actual DTLS player path through a bounded loopback UDP delay/loss/reordering/duplication relay, then a brief blackout. Assert monotonic state, missing-input neutralization, recovery without duplicate admission and durable departure. Rendered testing uses a hidden 60 fps-capped client; it is not visual acceptance or WAN certification. Production behavior is unchanged. See PUBLIC_NETWORK_IMPAIRMENT.md. |

| D085 | Public lateral helm and command/motion indicator | Carry finite bounded thruster intent through existing authenticated input fencing. Game wire protocol 8 and snapshot version 2 add authoritative signed forward speed (36+40N bytes). Share an opaque read-only reverse/neutral/forward indicator across local/public helm views, separately displaying actual movement/coasting. Preserve accepted handling and deferred stopping/pickup repairs. See PUBLIC_HELM.md and FOUNDATION_ACCEPTANCE.md. |

| D086 | Retained public admission failures | Send allowlisted refusal codes reliably before a bounded three-second rejected-peer timeout. No hull/control is granted; client cleanup preserves the explanation and a new browser sign-in clears the old attempt. Occupied spawns preserve the canonical save and retry after clearance. Game protocol 9, HTTPS ticket protocol unchanged. See PUBLIC_JOIN_FEEDBACK.md. |

| D087 | Foundation gate and stable authority I/O lifetime | Accept Step 42 for bounded local development after combined two-player sailing/collision/save/restart, existing cargo/receipt checks and a one-minute eight-player workload. Keep authority HTTPRequest nodes under the stable scene-tree root so owner regrouping/departure cannot cancel awaited saves. Preserve truthful drain failure and explicit WAN/browser/soak limits. Proceed to two test ports; see PUBLIC_FOUNDATION.md. |

| D088 | Two independent test ports | Author Brindle Quay and Slatewater Works as separate scenes/resources with distinct port/berth IDs, local spawn/approach anchors, envelopes and planned service/cargo capabilities. Keep static shore content separate from economy and compose a disposable Port Test from existing boat/water controls. Runtime clearance/recovery belongs to Step 44; no hidden shallow water. See TWO_TEST_PORTS.md. |

## D089 — Port spawn allocation uses explicit safe anchors

Step 44 uses a synchronous allocator with padded hull physics queries, explicit
cargo envelopes and conservative reservation volumes. Primary then authored
recovery order is deterministic; fully occupied ports refuse with retry feedback.
No hidden shallows. Public saved-spawn relocation waits for geographic port/world
integration, preserving canonical saves. See SPAWN_CLEARANCE.md.

## D090 — Berth readiness is explicit and read-only

Eligibility uses whole-hull containment, all-direction speed, heading, requested
service/cargo compatibility and physical clearance. Berth data owns tolerances;
invalid values fail closed. Ready feedback alone cannot dock or authorize a cargo
transaction. Step 46 must recheck under authority and handle reservations/state.
No depth/grounding rule. See BERTH_ELIGIBILITY.md.

## D091 — User-requested low-speed neutral comfort assistance

Capture near-zero throttle at 4%; once engine output is neutral, assist deceleration
below 2 knots to exact rest. Active side thrust/throttle overrides; normal coasting
above the threshold remains. Apply on authoritative shared handling, with the same
input adjustment across clients. This does not declare a boat docked. Historical
physics baselines remain isolated from the separately tested comfort features.

## D092 — Docking reserves before securing and never teleports

One authority serializes berth acquisition after live eligibility. Securing holds
position and disables propulsion; failed/cancelled docking releases. Cancelled
undocking retains its reservation. Disconnect/body/port teardown cleans holds;
old callbacks cannot unregister a replacement body. Public peer identity binding
must happen on the server when ports enter that world. See DOCKING_STATE.md.

## D093 — Cargo batches retain provenance and independent quantity pools

Per-ship runtime manifests use bounded integer quantities in explicit units and
capacity pools. Validate complete candidate manifests before publishing; no partial
mutations on failure. Keep separate batch IDs for separate jobs. Existing saved
inventory is unchanged until a versioned persistence adapter; job reference ownership
belongs to future operation authority. See CARGO_MANIFEST.md.

## D094 — Cargo operations separate progress from authoritative effects

Reserve per ship, advance explicitly without animation callbacks, validate again
before synchronous atomic completion, retain terminal results and release once.
Cargo adapters own family rules. Restore pending state into a fresh authority;
crash-safe receipt/effect persistence remains Step 51. Explicit interruption hooks
avoid treating physics-world reparenting as disconnect. See CARGO_OPERATIONS.md.

## D095 — Exclusive offers freeze quoted terms at acceptance

Designed container fixtures quote 250 credits per unit and expire if unaccepted
after 600 active preview seconds. Accepted terms remain fixed and reserve ship
capacity; retries cannot duplicate jobs or transfer them to another ship. Offers
are session scoped; production IDs, saves and loading commitment conversion must
be connected explicitly. No acceptance-time payment. See CONTAINER_OFFERS.md.

## D096 — Manual heavy pickup clearance and atomic local port loading

Inset the deck collision surface 0.15 m to avoid flush contact with the floating
payload during stern-first pickup; retain solid payload/hull collision and add a
regression reproducing the original blockage. Loading uses authority-owned progress
and commits manifest plus offer status synchronously. Cancellation creates no partial
cargo and releases the job. Completed preview cargo survives port switching; crash
persistence and public network wiring remain explicit follow-ups. See PORT_LOADING.md.

## D097 — Dock-first services and non-expiring jobs by ship family

User direction: show CARGO / REFUEL / REPAIR after docking; multiple compatible
jobs without expiry. Containers go port-to-port; heavy cargo appears nearby after
acceptance and is physically dropped at a random ocean point. Test services and
rewards are temporary; persistent authority comes later. No peer transfers. Remove
docking water markings and use grey/colored Dock. Exclude the heavy loader's own
floating payload from camera obstruction checks. See DOCK_SERVICES_REDESIGN.md.

## D098 — One voyage job and usable docking controls

User requires one active job, with container acceptance starting loading at once.
Keep manual nearby heavy pickup/ocean drop. Fix HUD focus trapping without weakening
menu or lost-window input gates. Widen berth approach tolerance while retaining hull
clearance. Temporary container visuals stay in Step 52; include the requested simple
minimap in Step 56 navigation usability. See DOCKING_USABILITY.md.

## D099 — Forgiving heavy pickup and atomic local voyage checkpoints

User replaces tight heavy heading/position matching with platform-under-load pickup.
Raise attaches and aligns the load to its deck slot; Lower at its ocean destination
releases it. No separate Secure button in gameplay. Preserve stopped/clearance checks.
Save accepted quotes, manifest, operation receipt and local reward in one SQLite
transaction. Resume saved loading and deck travel, restart propulsion neutral, and
refuse inconsistent saves without overwriting them. Public authority RPC integration
remains separate. See IN_FLIGHT_PERSISTENCE.md.

## D100 — Cargo visuals are derived presentation

Represent actual manifest quantities with fixed authored slots and lightweight
instances beneath the hull visual root. No cargo physics, saved meshes or independent
visual authority. Do not show containers for unfinished loading or industrial heavy
jobs. Keep geometry temporary. Andy explicitly has not play-tested Step 51 yet;
automated checks do not imply user acceptance. See CONTAINER_VISUALS.md.

## D101 — Save container settlement before acknowledging it

Prepare delivery on copies, validate the authoritative dock/ship and exact accepted
cargo, then persist removal and quoted payout together before applying live state.
Refuse unsafe saves and preserve cargo; reconstruct receipts from delivered job terms.
One active job remains the gameplay rule. Steps 51–53 are not yet user play-tested.
See DELIVERY_PAYOUT.md.

## D102 — Preserve rigid ship transforms while turning

Normalize the proposed hull rotation before clearance queries/application to prevent
floating-point scale accumulation from tripping save and berth validation. Do not
weaken validators or remove the failed-save safeguard. User save was copied for
reproduction, not modified. Cargo-loading animation is deferred presentation work
and must remain subordinate to authoritative loading. See SAILING_SAVE_FIX.md.

## D103 — Larger docking envelope and contact at the quay

Allow ships to moor directly alongside solid quays by separating actual shore overlap
from the padded other-boat/cargo clearance query. Enlarge both berth envelopes without
changing speed/heading checks or physical collision. Later rope animations follow
confirmed docking/undocking state, not a separate gameplay lock. See ALONGSIDE_DOCKING.md.

## D104 — Explicit voyage cancellation and loss policy

Unfinished jobs release without payment. Loaded container abandonment requires a
second click and forfeits cargo, retaining a terminal record. Save before applying
live changes. Heavy cargo cannot be cancelled while attached. Prevent ship changes
with active jobs. Repair only verified unpaid empty-manifest orphan loading; never
infer missing cargo, undo receipts or mask unexplained money. Future sinking callers
must honor the tested removal hook; no sinking system introduced by this step.
See VOYAGE_LIFECYCLE.md.

## D105 — Voyage HUD reads accepted job and live cargo state

Keep the voyage panel read-only. Show promised cargo separately from cargo aboard,
quoted payment separately from wallet/last paid receipt, and use the accepted job's
destination through arrival. Show pending loading and save-block states explicitly.
Use opaque panels and non-focusable controls; preserve throttle/neutral behavior.
Step 56 adds geographic navigation; this step does not add a minimap or network
port-service settlement. See VOYAGE_INTERFACE.md.

## D106 — Read-only local chart and stable service selection

Map the local helm frame (+Z north, -X east) to a north-up auto-fit chart. Targets
derive from accepted jobs and actual heavy attachment; never choose a destination
based on the nearest port. Direct dashed guide is not pathfinding. Preserve selected
job IDs and expose disabled-action reasons. No world-space docking marks. Local
service refresh must not submit commands; public network timeout/reconciliation
wiring remains a separate integration obligation. See LOCAL_NAVIGATION.md.

## D107 — Hold first voyage gate for actual multiplayer cargo integration

Separate local voyage evidence from public sailing/economy foundation evidence.
Two consecutive local settlements and restart pass but cannot certify two players
using ports, jobs and delivery together. Keep Step 57 open and prioritize that
integration before Step 58 or additional cargo families. Preserve the existing
public single-profile / private development-slot separation. See FIRST_VOYAGE_GATE.md.

## D108 — Canonical public voyage transactions precede peer-facing ports

Use the existing account lease/revision/receipt transaction for container contracts.
The backend owns offer terms and loading readiness; the trusted game server must
validate physical docking before asserting a port ID. No unrestricted player RPC.
Keep local saves separate. Loading can become ready while offline, but cargo is
created only by a validated completion request. Retain request IDs across unknown
outcomes, and distinguish old receipts from current canonical state. Gate remains
open until physical two-peer voyages pass. See PUBLIC_VOYAGE_CONTRACTS.md.

## D109 — Stable online ports and server-wide berth ownership

Place the two prototype ports in canonical geography and project their geometry
into nearby server charts and inert client views. Store berth ownership outside
temporary chart nodes. Bind docking to authenticated peer-owned hulls, enforce
physical eligibility, and clear reservations on departure/authority loss. Keep
uncertain commands pending with explicit recovery instead of automatic replay.
No persistent berth claim across reconnect. Protocol 10 requires matching game
builds. See PUBLIC_PORTS.md.

## D110 — Bind online cargo commands to actual server docking

Derive account, job and port from authenticated server ownership and docked state.
Serialize voyage mutations with saves/departure; reconcile current canonical state
after known results and fence uncertain outcomes. Never auto-resubmit an uncertain
payment. Publish bounded own-job state and nearby cargo counts for presentation.
Loading locks undocking; reconnect requires redocking without losing the job.
Protocol 11. Full navigated two-peer voyage gate remains open despite passing
fixture-approach cargo UI/reconnect/settlement checks. See PUBLIC_CARGO_SERVICES.md.


## D111 — Deferred globe, presentation and single-local-save direction

Andy requests a globe minimap, visible Earth-like curvature, slightly softened
distant objects, Wind Waker-style art, improved bow water effects, angled docking
cutscenes and turning roll, with waves considered later. Use the exact placements
and reference shortlist in DEFERRED_PLAYER_REQUESTS.md. One local save with
Restart Progress supersedes the three private development slots as intended
player-facing UX; preserve/migrate existing progress safely when implemented.
This does not authorize resetting the online profile or deleting saves now.
Step 57 remains the immediate priority. No runtime behavior changed here.

## D112 — Separate complete voyage evidence from fixtures and manual acceptance

Use ordinary authenticated helm/docking/cargo commands for full travel validation;
retain fixture approaches only in separately labelled commit-interruption cases.
Wait real lease expiry after uncertain ownership and preserve historical failed-save
shutdown warnings. Do not rebuild exports while test processes use their resources.
Windows full-voyage and crash-recovery checks pass; online user feedback remains
separate and pending. No handling change was needed. See PUBLIC_VOYAGE_VALIDATION.md.


## D113 — Paid online propulsion fuel and deferred manual feedback

Proceed with Step 58 after automated Step 57 evidence while Andy tests later.
Keep that user acceptance explicitly pending. Online refueling sells whole liters
at a provisional 25 minor credits/L, separate from cargo fuel. Bind quotes to the
actual dock/live fuel/wallet, consume once, checkpoint fuel burned before buying,
and commit tank/payment/receipt together. Never automatically retry an uncertain
purchase; reacquire canonical state on reconnect. Both port and berth must support
the service. No profile reset or migration. The isolated local Port Test retains
its labelled free fixture services. See PUBLIC_REFUELING.md.


## D114 — Recoverable online hull damage without free starter recovery

Use actual server collision closing speed, a configurable harmless threshold and
bounded per-contact damage. No hidden shallow areas. Save an impact before reporting
sinking; freeze/fence uncertain ownership rather than applying an unsaved penalty.
Each sinking charges 250 credits provisionally, retaining the full unpaid amount as
recovery debt. Half of future earnings repays it; the player keeps the rest. Paid
recovery includes hull restoration and a minimum 100 L propulsion reserve, preserving
ship identity. Cargo and active jobs are lost, not restored by reconnect. The fee
is not waived for the starter. Reserve and recheck safe return positions, and
reconcile pending impacts across connection replacement. Maintain the local fixture
boundary; future online ships must participate in paid recovery. See PUBLIC_RECOVERY.md.


## D115 — One boat condition, no machinery degradation

Andy explicitly replaces separate component wear with a single condition reduced
by collisions and gradual active use. Use unlabeled aesthetic engine/fuel gauges
with lowering fill. Never degrade heavy-loader lifting machinery. Initial wear is
1% per active propulsion hour, no offline/docked/paused/neutral-idle wear, and a
10% wear-only floor. Low condition mildly reduces main propulsion only. Step 61
must follow the single-meter design, and Step 62 will repair it. PUBLIC_CONDITION.md
documents persistence, tuning, scope and tests. Synced source roadmap stays read-only.


## D116 — Shared gauges and Windows hosting follow-up

Gauges belong to all active gameplay, including local Port Test, both hull types and
local/online multiplayer. Use an independent read-only overlay so dock services and
throttle-panel visibility do not hide it. Keep icons unlabeled. Step 61 uses single
condition/fuel feedback with configurable visual-only low thresholds; no separate
machinery wear or damage/wear meters. Optional hull rust deferred to the art pass.
Andy requests Windows LAN/internet hosting and secure sign-in; PUBLIC access must
pass the security work recorded in WINDOWS_HOSTING_PLAN.md. Welcome email deferred.


## D117 — Portable Windows invited-player host, honest public-access gate

Deliver the same runtime for LAN/hostname routes and include a server-PC ChatGPT
handoff. Preserve one stable login issuer when switching game connection addresses.
DuckDNS requires actual DNS/router configuration; local sign-in may need split DNS.
Never expose canonical mutation APIs or DB ports. Bundled test accounts are temporary;
Google sign-up and password-reset email are not claimed complete. Require public TLS
lifecycle, production identity storage and abuse/security tests before unrestricted
public rollout. Keep generated private data out of distributable archives and client
exports. Scope first validation to what was actually tested on this PC.


## D118 — Friends-only menu and portable public connection files

Andy's friends receive Servers, Settings and Quit; developer fixtures/local save
controls stay out of this menu. Keep the existing authenticated server protocol.
Client packaging must use the actual server's public config/certificate, never a
made-up hostname, private key, copied account database or development credentials.
An unconfigured template is explicitly identified and cannot silently fall back to
another user:// server. Preserve the existing server and progress; deployment is
not confirmed until a real off-LAN client connects. Welcome email stays deferred.


## D119 — Full paid restoration of the single condition meter

Step 62 follows D115: one repair quote for restoring missing boat condition to
100%, with no separate components, machinery wear or player-to-player transfers.
Use shared per-definition full-scale prices in repair_costs.json; initial starter
price is 250 credits per 100 percentage points, provisional pending Andy's economy
feedback. Round the proportional total upward once to integer minor credits.
Full condition cannot charge; successful restoration clears fractional wear.
Settle pending simulated wear before purchase and require accepted condition/price
to match canonical state. Use existing lease/revision/receipt/journal transactions
and uncertain-outcome fencing. No schema migration or save reset. New repair RPC
requires game protocol 14; ticket protocol 7 and Godot 4.7.2 stay unchanged.
See PUBLIC_REPAIRS.md. Implementation is draft pending PostgreSQL/Windows/visual
acceptance, not evidence of deployment or an accepted Step 62 gate.


## D120 — Earned-credit catalog and separate stored ship ownership

Step 63 adds starter/coastal/swift small container definitions at provisional
500/900/1,200 earned credits; no new starter-money grant. Coastal uses 20% less
full-output propulsion fuel; Swift has 20% stronger forward acceleration and higher
fuel use. All retain six container slots, existing placeholder hull art and 1,000 L
tanks. New purchases start stored, at full single condition with empty tanks.
Pacing remains provisional pending Step 67 and Andy's feedback (U014).

Preserve the active profile.ship and all existing IDs. Add stored_ships only on
purchase, bounded to 100 records. Shared definitions contain no owned state. Bind
confirmation to a server quote, consume before I/O, settle live state, and use the
existing atomic profile/wallet/treasury/receipt/journal transaction. Account/action
UUIDs distinguish deliberate purchases; duplicate intent returns the original ID.
No player transfers, fleet switching, resale or new condition model. Game protocol
15, ticket protocol 7, Godot 4.7.2. PUBLIC_SHIP_PURCHASE.md records semantics and
pending real PostgreSQL/Windows/Keycloak/visual gates separately from Linux doubles.


## D121 — Read-only fleet comparison with explicit cargo units

Step 64 (`fleet-inspection-and-comparison`) compares catalog definitions and the
owner's active/stored instances in online dock services. Derive cargo compatibility
and total capacity from cargo IDs, capacity pools and quantity units, never hull
geometry, DWT, hold count or propulsion tank volume. Current content defines six
container slots or one heavy-module slot; DWT and hold count are unspecified and
must remain visibly unknown. Bulk/gas/oil/cargo-fuel capability is not inferred.
Heavy-lifter capability is a local prototype, explicitly unavailable for online
purchase/jobs. Existing purchase quotes remain the authority for price and funds.

Read names if present, otherwise show Unnamed ship; do not add rename mutations.
Show owned IDs separately from shared class names, the live active single condition
and fuel, and canonical stored condition/fuel/location. Project only those bounded
fields to the authenticated owner while docked (active plus at most 100 stored).
Use isolated visual scenes for previews; never instantiate runtime hull authority
or modify shared resources. Stored activation, resale and customization stay later
steps. No save migration, economy changes, new RPC, game/ticket protocol bump or
Godot upgrade; the existing voyage dictionary gains an additive fleet field.


## D122 — Dock-only atomic fleet exchange with retained owned state

Step 65 resolves the switching/despawn portion of U015; resale/valuation remains
Step 66. One active ship, same storage port only, no cargo or unfinished job on
switch, no independent gameplay despawn button. Empty damaged afloat ships may be
stored without healing; pending damage or sinking recovery blocks exchange. Save
live fuel, fractional wear and geographic transform before moving the entire owned
record between active/stored slots. Return previously active ships to their exact
saved transform; use authored service-berth slots only for never-activated purchases.
Keep berth ownership so an empty purchased tank can receive paid fuel. Reserve and
recheck clearance; on occupied saved location retain the active ship without a
teleport fallback. Unknown commits fence and reconnect restores canonical ownership.

Use existing atomic revision/lease/receipt/journal persistence; no new save version,
no grants/transfers/resale. Activate the three existing catalog classes with their
own handling, existing six-slot cargo support, paid fuel and provisional equal
250-credit full-scale condition repair. Game protocol 16, ticket 7, Godot 4.7.2.
See FLEET_LIFECYCLE.md and PROGRESS.md for evidence and outstanding platform gates.


## D123 — Stored-only resale and explicit cash-basis voyage receipts

Step 66 resolves U015 resale: retain the active hull and reject cargo/unfinished
jobs, wrong-port storage and pending recovery. Sell an empty stored ship only at
its current service port, with explicit quote review/confirm/cancel. Preserve an
afloat supported active ship with fuel or funds for at least 1 L; never mint a
replacement or free fuel. Provisional valuation is 60% of the lower of acquisition
cost/current catalog price, scaled by the single stored condition and floored once.
Configure basis points per definition; legacy ships use catalog fallback without
rewriting saves. Fuel is not reimbursed. Existing recovery debt repayment applies
to proceeds; show gross, debt repayment and wallet credit separately.

Report cash from job acceptance to delivery/cancel/sinking: gross revenue,
acquisition purchases during the window, paid fuel, repairs, recovery and net cash.
Prepaid fuel/ships and future repairs are explicitly excluded, not called profit;
legacy active jobs have a marked partial window. Net reconciles to start/end wallet
inside the same atomic receipt transaction; replay never adds costs/revenue twice.
Only additive profile/receipt data; preserve IDs/save version/UIDs, Godot 4.7.2 and
ticket 7. New resale RPC requires game protocol 17. PUBLIC_RESALE_ACCOUNTING.md
records the cash boundary and pending platform gates. No Step 67 economy tuning,
player transfers, cargo expiry, hidden shallows, machinery wear or deferred work.


## D124 — Measured small progression and a fueled first-upgrade target

Step 67 (`economy-gate`) targets 10–15 minutes from the existing public new-player
terms to a purchased, activated Coastal ship with 250 L paid fuel when taking the
large first contract. Target 25–35 minutes for smaller contracts or one halfway
sinking. These are human acceptance targets; the fixed-input benchmark measures
9.12 / 28.99 / 26.96 simulated minutes respectively, with explicit scope/allowances
and unrun playtest gates in ECONOMY_GATE.md.

Tune only Coastal price from 900 to 800 credits. Existing 500/1,200 alternatives,
250/500/750 cargo rewards, fuel/repair/recovery rates and resale formula remain.
Keep starting 200 credits/800 L, empty new-purchase tanks, stable IDs and acquired
cost records. A formerly 900-credit Coastal is now capped to current 800-credit
basis for resale (480 maximum), without a refund or save rewrite. No new currency
source, offer regeneration, expanded catalog, save/protocol migration or player
transfers. Godot 4.7.2, game protocol 17 and ticket protocol 7 remain unchanged.

Gate economics include replacing consumed prepaid fuel, repairing wear and funding
the upgrade tank; gross rewards alone are not profit. Benchmark both directions
and a failed half-voyage, including recovery debt repayment. Production dispatch
with SQL doubles and serialized reloads verifies replay/cycle behavior; it does
not replace real PostgreSQL/Keycloak/crash or collision-safe human voyage gates.
Six finite nonexpiring seed offers are sufficient for this milestone; longer-term
content/progression and deferred single-local-save UX remain separate work.


## D125 — Explicit bulk grams and one commodity per authored hold

Step 68 (`bulk-capacity-model`) defines grain, coal, ore and limestone as catalog
resources using integer grams. Holds have stable IDs, independent positive mass
capacities and explicit allowed commodity IDs. Author `single_commodity_per_hold`:
same-commodity batches may share a hold; different commodities need separate holds.
Reject unsupported policies, unknown/unassigned holds and per-hold overfill; do not
silently split or relocate cargo. Emptying a hold clears its commodity assignment,
with no cleaning or machinery mechanic. Preserve per-batch provenance.

DWT is separately authored informational tonnes (zero unspecified), never inferred
from hold count or used as the cargo capacity budget. The data-only two-hold fixture
has 400/600 t capacities and a separate 1,500 t DWT rating. Container counts and other
capacity pools stay independent; no existing ship gains bulk capacity or new limits.
No online purchase/activation, payout, save/protocol migration or bulk service UI.
Bulk earnings and settlement/partial-discharge policy remain Steps 69–70. See
BULK_CAPACITY.md for units, bounds, data scope and validation.


## D126 — Frozen direct-distance bulk gross quote and cumulative partial rounding

Step 69 (`bulk-earnings`) uses authoritative geographic port separation on the
existing world radius, rounded to nearest metre once at quote publication.
Nonexpiring quotes freeze direct metres, commodity rate and both configurable
port basis-point modifiers. Every earnings modifier is included in the displayed
gross quote; fuel/repair/recovery are separate costs, not hidden quote deductions.
Reject same-port/zero-distance routes and missing terms. Sailing detours, elapsed
time and later content changes never increase the accepted payout.

Load one explicitly allocated bulk batch in full; allow destination discharge in
positive integer grams. Pay the floor of cumulative exact earnings in minor credits
minus prior payments, preserving fractional progress across partials. Final payout
is floored once; fragmenting cannot change it. Keep the job active until all cargo
is discharged. Preserve manifest provenance and reject mismatch/over-discharge.
Replay returns the original receipt with zero additional award; conflicting intent
fails. No player transfers, machinery wear, condition changes or cargo expiry.

Reuse the container offer registry and one-job guard. Step 69 supplies an in-memory
bulk authority model and quote/receipt formatters using Step 68's data-only hull;
no playable hull acquisition, public RPC/wallet integration or save migration.
Step 70 remains responsible for service presentation and durable recovery. Do not
mistake process-local replay coverage for crash/restart/SQL guarantees. The worked
123.456789 t / 1 NM / 1 credit / 1.10 / 0.90 example pays 49.50 + 72.72 = 122.22
credits, matching the quote. See BULK_EARNINGS.md for bounds and exact arithmetic.

## D127 — Bulk service authority commits before visual publication

Step 70 (`bulk-service-presentation-and-recovery`) connects the existing bulk model
to the shared timed operation service, a commodity/hold panel and a separate local
bulk voyage fixture. Keep the two-hold prototype out of the public purchasable fleet;
reuse the starter presentation without giving existing ships bulk capacity.
Choose a finite authored commodity/hold quote, load in full, and unload positive
integer grams at its destination. Five seconds per service is provisional fixture
pacing, independent of grams; neither the crane nor UI completion calls settlement.

Persist frozen origin/destination/quote inputs, allocation, cumulative partials,
receipts, wallet and operation state as one private SQLite checkpoint before
publishing success. Validate bounded history by replay into isolated objects.
Existing voyage schema/codecs remain defaults; use a new explicit private bulk
realm/version 1 without migrating/resetting container/heavy saves. Preserve Godot
4.7.2, game protocol 17, ticket 7, existing UIDs and online single-condition rules.

On interruption resume the last durable progress, with no offline advance; restore
sailing in neutral. Cancel/berth loss releases pending loading or stops pending
unloading without removing previously loaded cargo or prior partial receipts.
Failed/uncertain commits and stale revisions fence until reopen. No receipt eviction,
automatic reset, new public RPC or PostgreSQL bulk wallet is implied. See
BULK_SERVICE_RECOVERY.md for lifecycle boundaries and PROGRESS.md for evidence.
Step 71 and all deferred player requests remain out of scope.

## D128 — Explicit launch gas set, segregated cubic-meter tanks and pipelines

Step 71 (`gas-capacity-and-terminal-compatibility`) selects LNG, nitrogen, oxygen
and argon as our launch definitions, resolving U027's research five/seven/six-list
conflict through an authored subset. LNG represents methane-based cargo; no separate
methane duplicate. Helium/hydrogen require future containment definitions. This is
a game design choice, not a verified current source-game catalog.

Use bounded positive integer cubic meters (1 m³ precision), stable per-tank IDs and
explicit commodity allowlists. One commodity per tank; same-commodity batches may
share remaining space, and emptying releases assignment. Separate LNG and industrial
cryogenic pipeline interfaces; terminals explicitly allow loading/unloading per
pipeline. Reject malformed, unsupported and mismatched definitions/combinations.
No pressure/temperature simulation, cleaning, machinery wear or gas oil market.

Container counts, bulk grams, propulsion fuel and DWT remain independent. Fixtures
are data-only and grant no existing ship/port new capabilities. Step 72 owns quotes,
physical service integration, timed transfers, save/lifecycle rules and settlement;
whole-m3 precision is the current contract and must be deliberately revised before
fractional gas quantities are introduced. GAS_CAPACITY.md documents the validation
API and its authority boundary. Godot 4.7.2, game protocol 17 and ticket 7 remain.

## D129 — Gas uses the shared delivery authority with whole-m³ settlement

Step 72 (`gas-delivery-and-persistence`) reuses bulk's quote, cumulative settlement,
timed service, UI and atomic SQLite checkpoint engine. Keep D128's integer m³
precision and segregated tanks. Gas rates are minor credits per m³ per NM, with
both explicit port modifiers frozen in the gross quote; no oil market or cargo
purchase/resale. Whole batch loading and positive whole-m³ partial unloading each
use provisional five-second service. Revalidate authored gas pipeline direction /
commodity / tank compatibility at admission and completion.

Preserve tank, acquisition and origin/destination records, cumulative volume/payment
and durable operation receipts. Exact replay has zero new reward; conflicts and
incompatible deliveries fail. Cancel stops only unfinished service; loaded remainder
and prior payments persist. Resume last committed progress with no offline advance,
restore sailing in neutral, and fence failed/uncertain/stale saves until reopen.

Use a separate developer-menu private gas fixture and version-1 realm; existing
bulk/container/heavy saves and public IDs/protocols remain unchanged. Public gas
RPC/PostgreSQL/authenticated handoff/sinking integration is not implied by private
SQLite proof. GAS_DELIVERY_PERSISTENCE.md defines the lifecycle boundaries, finite
fixture rates and worked 98.62-credit voyage. No Step 73 or deferred player work.

## D130 — Fixed-price whole-barrel oil lots before market simulation

Step 73 (`liquid-trading-inventory`) introduces an isolated private inventory API,
using whole barrels and a separate authored capacity pool. Use one unsold lot at a
time, explicit lot selection for partial sales, and retain acquisition ID, quantity,
unit/total cost and cumulative sold cost/proceeds/profit. Exact integer allocation
makes fragmentation neutral. Charge purchase once; sale credits proceeds without
charging the already-paid cost again. Reject rather than clamp excess quantities.

The first fixture buys at Brindle Quay for 125 minor credits/barrel and sells at
Slatewater Works for 175, with 20,000 starting minor credits and 200-barrel capacity.
These version-1 fixture constants are not production balancing or a market model.
Commit wallet/manifest/lots/history/receipts through the existing SQLite checkpoint
before success; exact action replay has zero delta, conflicting replay fails, and
stale/uncertain commits fence until reopen. A separate private realm preserves all
existing saves. Full history reconstruction validates the derived state.

No playable oil hull/UI/public endpoint, shared market, price expiry or variable
pricing is introduced. These remain Steps 74–76; no Step 74 work is started.
LIQUID_TRADING_INVENTORY.md records the API, example and lifecycle boundaries.

## D131 — Bounded oil model and explicit quote lifetime before service wiring

Step 74 (`oil-market-simulation`) adds a dependency-free Python model at the
existing Python authority boundary. A single public owner supplies all public
views; private hosts instantiate distinct markets through the same model contract.
Missing public authority fails closed. Port offsets, cadence-based signed supply
recovery, bounded quantity/supply effects and hard price limits are configurable.
Use whole barrels and integer minor credits; trusted authority time only.

Quotes freeze terms until the explicit exclusive expiry boundary, even across
market updates. Expired quotes require a new request; no silent repricing. Consumed,
changed or foreign quotes cannot change pressure again. This is simulation only:
Step 75 owns durable centralized transport, quote/account binding, idempotent
settlement and cross-process evidence. Preserve Step 73's historical fixed-price
save codec until that deliberate adapter exists. No public market endpoint or
private inventory price substitution is enabled by this model. Step 75 unstarted.
OIL_MARKET_SIMULATION.md records formulas, defaults, failures and scope. Existing
cargo offers/jobs do not expire; no feed, real-money or player-transfer dependency.

## D132 — Oil market and account settlement share one durable transaction

Step 75 (`shared-public-oil-market-service`) places the Step 74 market owner in
the existing public authority PostgreSQL database. Serialize public updates with
one market-row lock, after the account lease/profile locks; commit market history,
quote consumption, canonical cargo, wallet/treasury, revision, receipt and journal
atomically. Separate durable sequence from model price version. Never coordinate
market acceptance and wallet settlement through independent commits.

Bind quotes to account and active ship, retain frozen terms until expiry, and use
the existing account/action ledger for exact retry recovery across rebind/handoff.
Missing state, unavailable storage and uncertain replies never seed local public
prices. Private hosts use the same settlement contract with isolated SQLite state;
no public/private quote or account import. Preserve Step 73's historical save codec.
The authored oil prototype remains fixture-only; no existing public hull gains
capacity, no new player UI/RPC or Step 76 work. SHARED_PUBLIC_OIL_MARKET.md records
migration, transport, trusted-server docking attestation and platform gates.

## D133 — Explicit oil quote review and cumulative lot-cost presentation

Step 76 (`oil-market-interface-and-lot-accounting`) retains D130/D132's one current
purchased lot and explicit partial-sale selection. Allocate cumulative acquisition
cost as `floor(original_cost * cumulative_sold / original_barrels)`; each sale
uses the difference from prior allocation, with remaining cost as the complement.
Show gross proceeds, allocated cost, realized profit, debt repayment and wallet
change separately. Final sale retains its receipt after the aboard lot empties.
Persist through the existing atomic adapters, with no historical save migration.

Reference prices carry per-port authority observation timestamps and are readable
underway. Executable quotes require separate request/review and explicit acceptance
of the displayed identity/version/port/revision. Selection changes invalidate;
refresh never replaces accepted terms. Expiry and stale responses require new
review. Unknown outcomes retain the same action/quote for retry, never auto-reprice.
The countdown is advisory monotonic time; authority time decides expiry.

Add a reusable Godot panel and explicitly provisioned private oil sailing fixture
against Step 75 SQLite. Keep the oil hull fixture-only; no new public Godot RPC,
public fleet capability, old save conversion, refinery work or deferred features.
OIL_MARKET_INTERFACE.md defines the lifecycle, bridge trust boundary and remaining
full-voyage/public/visual gates. Godot 4.7.2 and protocols 17/7 remain unchanged.

## D134 — Private refinery uses exact fractional carry and atomic crude custody

Step 77 (`refinery-processing`) adds one private fixture refinery, stable ID
`refinery_slatewater_01`, at Slatewater Works. Use integer millibarrels (1000 per
barrel) and an immutable saved rational yield. Proposed fixture defaults are 7/10,
1000 millibarrels/active second, 200000 input and 1000000 output millibarrels;
these are configurable prototype values, not accepted pricing/balance targets.
No submission fee, refund, expiry or withdrawal. Step 78 owns shared public stock
and withdrawal transactions; Step 79 owns cargo-fuel transport/sale. Cargo fuel
never fills the propulsion tank.

One processing slot reserves its entire output before accepting crude. Consume
owned crude, allocate its cost, save the job and record its idempotent action in
one SQLite transaction. Output is credited only at completion in another atomic
transaction. Carry `divmod(input * numerator + prior_remainder, denominator)` per
account/facility, including zero-output submissions; never round each fraction up.
Configuration is frozen with the save. No cancellation after custody transfer.
Exact replay returns the original submission without another debit or credit;
changed intent conflicts. Bound retained jobs/receipt identities; reject new work
when full rather than evicting deduplication history.

Only the trusted private host advances active monotonic time. Persist integer
elapsed milliseconds; restart resumes the durable checkpoint with no offline
catch-up. UI progress, panel visibility, timestamps and client requests cannot
advance work. Unknown clock/storage outcomes fence the running fixture until
reopen. Validate conservation by reconstructing saved stock/remainders from jobs;
missing/incompatible data fails closed without reset or migration.

Retain whole-barrel oil trading with additive refined quantity/cost fields. Derive
exact remaining millibarrels; market sales may take only the whole-barrel portion.
Allocate cost cumulatively over sold plus refined quantity, so remaining cost,
sold cost and refined cost always reconcile. Residual fractions remain aboard for
refining. Existing lots without refinery fields retain their historical behavior.
Enable only via the operator's `--refinery` fixture flag and a new isolated save;
no public refinery RPC, deployment, playable fleet or old-save migration.

## D135 — Public refinery row ownership, deadline clock and atomic withdrawal custody

Step 78 (`shared-refinery-stock`) persists one public refinery inventory per stable
physical ID in the same PostgreSQL database as canonical profiles and receipts.
Keep account-owned subbalances from D134, visible consistently across servers;
no account can withdraw another's output. Scene unload, server shutdown and lease
handoff do not own or delete inventory. Private files remain separate and cannot
be imported or used as a public fallback. Additive initialization preserves data
and fails on missing/corrupt established state.

Lock account then refinery then treasury. Submission consumes owned crude and
records its job/receipt atomically. A saved database-time deadline completes the
job/stock/fraction once, including public downtime; clamp backward clock changes
to durable high water. Never add independent game-server elapsed ticks. Private
hosts retain active-time-only processing. No client time/credit/import endpoints.

Withdraw only owned stock with a frozen account/ship/port/quantity quote. Quotes
are nonexpiring and do not reserve stock; acceptance rechecks funds, stock and
revision. Proposed handling fee: 1 minor credit per barrel, ceiling once per
withdrawal; no submission fee or second crude purchase. Pricing remains prototype
tuning for Andy's review. Commit stock removal, wallet/treasury, consumed quote,
collection allocation, receipt and journal together. Changed action reuse conflicts;
replay survives reconnect/handoff without applying the receipt again.

The durable `awaiting_loading` collection allocation is still refinery custody,
not aboard or saleable cargo. Step 79 must consume it atomically when loading is
implemented. No transport, sale, propulsion refill, transfer/gift or public playable
oil hull in Step 78. Bounded retained jobs/quotes/withdrawals reject at exhaustion
without erasing replay history. SHARED_REFINERY_STOCK.md records the API, clock,
rounding, lifecycle and remaining integration boundaries.

## D136 — Cargo fuel custody and fractional pipeline sales (Step 79)

Consume Step 78 collections atomically into canonical `cargo_fuel` aboard lots.
The prototype oil hull has 200000 millibarrels of cargo capacity, separate from
its propulsion tank. One aboard commodity lot, no mixing or active cargo job.
Partial loading leaves the remainder in refinery custody; loading is free after
the quoted withdrawal fee. Bind collection loading to its quoted account/ship.
Slatewater loads; Brindle Quay buys cargo fuel through its fixture pipeline.
Prototype sale price is 220 minor credits/barrel, frozen in the acquisition record;
this is tuning for review, not a dynamic oil quote or propulsion refuel price.

Each load records refinery/collection origin, quantity and cumulative allocated
handling fee. Crude acquisition cost remains in the processing ledger: do not
mislabel the handling fee as total production cost or claim net production profit.
Sales allocate handling cost and gross proceeds cumulatively with integer floors;
partial sales conserve the full-lot proceeds. Existing recovery debt policy applies.
Transaction receipts, account revision and stock/cargo/wallet commit together.
Identical retries recover receipts even after berth loss/handoff; changed intent
conflicts. Close/pause does not sell or cancel. Restart retains collections/lots.
No refunds, player transfers, automatic consumption as engine fuel or old-save reset.
Public service uses existing trusted-server docking attestation/fencing. The playable
interface remains an explicitly provisioned private fixture; public Godot hull,
full public navigation/handoff and rendering acceptance remain separate gates.

The private Step 79 fixture also checkpoints position/yaw, propulsion quantity and
condition each active second and before a new refinery operation. Restart restores
the durable position in neutral, stopped and undocked; re-dock to trade. No offline
motion. Checkpoints are trusted private-host state, not public client-supplied
position authority. A failed/corrupt resume fences play rather than respawning a
loaded voyage at the default port. Economic changes still use the atomic refinery
transaction; a crash may restore an older navigation checkpoint, never older money.
Retain at most 10000 cargo-fuel mutations per facility; exhaustion fails closed
without pruning replay receipts. Snapshot shows the first 32 waiting collections;
fully loading one exposes the next. No existing file is reset or converted.

## D137 — Private-world heavy claims and atomic rewards (Step 80)

Resolve U030's initial job scope as one durable private world, one simple block
payload and the existing heavy-lifter type. Multiple lifter instances share one
payload authority/database. Claims never expire or move on disconnect. Reserve
both stable offshore zones through the carrying state. Cancel only before pickup,
release both reservations without payment, and retain the cancelled attempt's
identity. A delivered payload cannot be offered again. No player transfer/gift.

Use the existing Python private profile/wallet contract with a new explicitly
provisioned HeavyStore. Atomically commit claims, canonical jobs, reservations,
wallet/debt and durable exact-intent receipts. Reconnect reads state; it does not
apply receipts. Keep at most 10000 action identities and reject new work at the
bound, never prune deduplication evidence. Definition/realm changes fail closed.
Initial gross reward 70000 minor credits and 100000 kg block are prototype tuning.
Apply existing recovery-debt allocation; cargo never alters propulsion fuel.

Host-only pickup/delivery attestation is an internal integration boundary, not a
client position proof. Step 81 owns controls/alignment, Step 82 owns physical
attachment, release, sinking/despawn recovery and voyage integration, Step 83 owns
presentation/variants. Historical Port Test and saves remain unchanged. No public
endpoint, new public hull or global offshore stock in this step. See
HEAVY_LOAD_JOBS.md for the explicit lifecycle, API and remaining gates.

## D138 — Stationary, local-frame lifter pickup controls (Step 81)

Build on the existing test lifter's moving deck and controlled cargo mount. A
pickup requires the deck fully lowered and idle, an unpaused simulation, speed
below 0.05 m/s, absolute yaw rate below 0.001 rad/s, and neutral throttle/thruster
orders (absolute values below 0.01). Retain centre-over-platform tolerances of
9 m lateral, 24 m longitudinal and 2 m vertical, inclusive, in the carrier frame.
Heading remains unrestricted: crooked placement is deliberately accepted. These
are prototype tolerances, not a requirement to fit the entire block footprint.

When a staged payload exists, Raise from the lower stop attempts validated pickup
at every distance. Rejection provides alignment feedback and leaves the deck
target, visual parent and collision ownership unchanged. It no longer silently
starts an empty raise when the staged load is far away. An absent/inactive payload
still permits an empty raise, including after historical Port Test delivery.
Successful pickup retains the fixed cargo-anchor child and one carrier collision
shape, with the floating body's collision disabled; no stacked rigid bodies.
Deck travel retains swept obstacle checks, pauses with simulation, and ignores
nonpositive/nonfinite time deltas. Existing visible buttons remain the controls.

This is test-lifter control validation, not the Step 80 HeavyStore physical bridge.
Durable attachment, mass/draft effects, sinking/despawn reconciliation, public
transport and full heavy voyage persistence remain Step 82. No machinery wear,
new player hull, protocol/save migration or deferred feature is introduced.

## D139 — Durable private heavy transport and failure tombstones (Step 82)

Connect the Step 80 private HeavyStore to the Step 81 lifter through an explicitly
provisioned owned-process fixture, with no public endpoint or Port Test migration.
Commit custody/navigation before applying attachment or release. Reconnect uses
canonical snapshots, not receipt deltas. Checkpoint revision guards prevent stale
navigation from undoing a transition. Persist the same payload/job IDs and deck
state; resume stopped and neutral. Unknown outcomes fence the ship for exact retry.

A carried 100000 kg block scales acceleration against 1000000 kg prototype empty
displacement and adds 0.5 m visual hull draft. Keep fixed cargo mount/carrier-only
collision, no free payload physics, depth rules or machinery wear. These values
are explicit prototype tuning, pending Andy's handling/visual acceptance.

Delivery needs the lowered, stopped cargo anchor within 30 m horizontally of the
immutable offshore destination; reward and release commit once. Requested despawn
rejects active jobs. Scene teardown/disconnect preserves the last committed voyage.
Hull destruction at zero condition permanently fails/consumes that job/payload,
releases reservations and pays nothing. Preserve zero-condition hull ownership;
no implicit repair/replacement or free recovery. A failed tombstone never reoffers
the block. This resolves payload recovery only; public hull admission/paid recovery
integration stays outside the private fixture. See HEAVY_TRANSPORT_LIFECYCLE.md.

## D140 — Definition-driven heavy payloads and derived guidance (Step 83)

Add two payload variants (60 t module, 150 t girder) beside the block as authority
definitions: frozen economic terms plus label/envelope. Claim, evidence, attachment,
release, destruction and payout take the job's own terms; no per-payload code path.
Each payload has its own two zones. One active nonexpiring job per account remains.

Lifter load limits: 200000 kg and the 14 x 8 x 32 m envelope already proven for
deck travel and chart transitions; loaded draft therefore stays within 1.0 m.
Definitions are verified at import and on claim, and fail closed. New zones must
fit the measured +/-1000 m local chart. The inherited block drop-off at Z -1800 is
an explicit recorded exception, kept for saved-world compatibility, not a pass.
All limits, masses, positions and rewards are prototype tuning pending Andy's review.

New worlds store the full definition set. Step 80-82 single-block worlds stay
readable and offer only the block; there is no migration. Snapshot fields are
additive. Variants reuse the existing payload model scaled to the envelope as
placeholder presentation. Waypoint ring/pointer, alignment offsets, load readout,
state cues and next-step text are derived from the canonical snapshot and never
feed evidence or reward. No public heavy support, audio, new art, machinery wear,
expiry or player transfer. See HEAVY_JOB_PRESENTATION.md.

## D141 — Cargo matrix as tests; family row rules leave shared code (Step 84)

The compatibility matrix is regression coverage, not a new runtime table. Each
family keeps its own authority and its own definition of a valid hull. Service-side
families (oil, cargo fuel, heavy) are exercised together in one isolated SQLite
world through a test-only combined store; no production class combines them.
GDScript families (containers, bulk, gas, oil lots, heavy slots) are exercised by
one probe. A wrong hull, another family's unfinished cargo, an over-quantity or a
repeated action must be refused with no durable change.

`cargo_manifest.gd` keeps shared batch, unit and pooled-capacity rules only. Bulk
hold rules move to `bulk_rules.gd`; gas tank rules and the gas terminal/pipeline
check move to `GasRules`. Check order and messages are unchanged.

The remaining gas branches in the shared bulk/gas service, earnings, panel and
fixture stay: they configure units, stored key names, labels and fixtures for one
settlement engine. Revisit only with the bulk/gas recovery runners available,
because those key names are part of saved checkpoints. No protocol, save, price,
capacity or one-active-job rule changes.

## D142 — Content is added by record; world placement stays code (Step 85)

A commodity in an existing family, a container ship and a port are added by
records plus one `PrototypeCatalog.RECORDS` line and export entry; an online ship
also needs its three service JSON rows. New records are appended, never inserted.

Code must not switch on a literal content ID for names, allow-lists or dressing.
Online hull eligibility follows `ship_catalog.json`; bulk/gas commodity lists
follow cargo records; names come from `PrototypeCatalog`.

Which ports exist in a world, their addresses, seeded offers and rates remain
code, because saves and the protocol validate against them. Cinder Point is
therefore defined but unplaced until the Step 88 world layout decision. Salt has
no seeded job. Fixture identities (oil/refinery ports, heavy-lifter mode, the
container unit rule in `record_contract.gd`) are recorded exceptions, not fixed.

The harbor ship is on sale online with placeholder price and handling pending
Andy's review and an economy gate run. No protocol or save version changes.

## D143 — Priority cargo roles and starter access (Step 86)

Containers stay the starter family: no cargo capital, starter hull, unchanged
rewards. Bulk is the next step and gas the specialist above it, so their fixture
rates rise (bulk ×8, gas ×10) to pay more per trip than a full container load on
the same route. Cargo fuel sells at 320 minor credits per barrel (was 220) so that refining and hauling fuel back beats selling the crude.
Heavy rewards are unchanged until a lifter voyage is measured.

Oil and cargo fuel remain far below the contract families because the prototype
tanker carries only 200 barrels. The remedy is a joint capacity/trade-limit/wallet
scale-up, not a price change; it is deferred to a decision with Andy at Step 88.

Starter access: a new profile plays containers only. Every other family needs its
dedicated hull, none of which is sold online yet; until then each stays reachable
through its developer fixture. Hull prices are set when the hulls go online.

Existing saves keep frozen quotes and frozen cargo-fuel prices. No protocol, save
format, condition, expiry, transfer or one-active-job change. Values are
provisional pending Andy's Step 87 playtest. See CARGO_BALANCE.md.

## D144 — Brindle Reach layout and traversal budget (Step 88)

The launch region is planned as lanes and budgets before scenery, in
`features/world/world_layout.json`. The 100 km navigation radius, 1 m scene unit
and 1:1 time scale are kept, so there is no save, protocol or address migration.
Brindle Quay and Slatewater Works keep their anchors.

Seven ports within about 17.5 × 11.3 km: the two existing ports, Cinder Point at
2.0° S, 2.0° E, and four planned names (Tallow Reach, Gannet Light, Orrin Deep,
Farrow Bank). Starter-hull targets, berth to berth at 80% of top speed plus a
150 s port allowance: starter 8–12, short 12–15, medium 15–24, long 24–36 minutes.
One-way fuel must stay within 80% of a tank and no leg exceeds 40 minutes; fuel
range, not time, bounds the region.

Size limits are visible beam limits only: Needle Gut (40 m, class S) and Skerry
Gate (70 m, classes S and M), each with an open alternative. No depth limits and
no air-draft limit until Step 94 measures loaded heights.

Cinder Point's address is decided; wiring it into the public world and Port Test
is deferred to Step 89, because it changes the protocol, save validation and
service port lists and could not be tested on this runner. The four new ports are
not catalog records. No offers, rates, hulls or online families are added. The
D143 oil and tanker scale decision stays open. Names and targets are provisional
pending Andy's review. See WORLD_LAYOUT.md.
