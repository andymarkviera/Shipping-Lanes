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
