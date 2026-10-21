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
