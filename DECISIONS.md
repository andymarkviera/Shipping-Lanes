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
