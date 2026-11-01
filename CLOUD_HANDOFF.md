# Cloud development handoff — November 1, 2026

## Start here

Private repository: https://github.com/andymarkviera/Shipping-Lanes
This publication preserves 93 existing commits and adds this handoff, original
reference snapshots and the current working project.godot. The developer PC's
working checkout was not reset or modified by publishing. The original game title
is Shipping Lanes; the visible title is Container Ship Sim.

This is a source repository, not a configured Codex cloud environment or a game
server deployment. Begin cloud setup by inspecting dependencies and validating a
headless import/test workflow. Do not start the next gameplay step until the
required checks can run or their platform limits are explicitly recorded.

## Current implementation

Godot 4.7.2, typed GDScript, Compatibility/OpenGL renderer. Local Port Test supports
container and heavy-loader voyages, docking, cargo, fuel and repair fixtures.
Authenticated online play currently supports the starter container ship: browser
PKCE sign-in, server-authoritative movement, ports, cargo jobs/deliveries, refueling,
collision/recovery, one condition meter with gradual propulsion wear, canonical
saves and restart recovery. Heavy-loader online integration is still future work.

Step 61 is complete. Step 62 paid online repairs is the next numbered gameplay
step, but hosting and cloud migration were explicitly requested before proceeding.
Read PROGRESS.md, DECISIONS.md, FEATURE_INVENTORY.md, DEFERRED_PLAYER_REQUESTS.md,
GAME_SPEC.md and the relevant PUBLIC_*.md docs. Older introductory docs may describe
historical milestones: use dated progress and subsequent decisions for status.

Friends client has Servers, Settings and Quit, enabled by Game/friends-client.flag
or --friends-client. It reads public internet.json/certificate beside Game; optional
--lan selects lan.json. Its Windows release passed menu/configuration tests and
27 login/drive/save/restart/gateway checks against the original dedicated bundle.
Game protocol is 13; ticket protocol is 7. No protocol migration was introduced.
Port Test was discussed for the friends client but was NOT added or confirmed.

## Platform/dependency work needed for cloud

- engine-baseline.json pins the Windows engine build/commit; export-templates.json
  and sqlite-dependency.json record the corresponding runtime dependencies.
- tools/Godot.ps1 uses PowerShell 7.4+, Windows paths and a cached engine outside
  this repository. No cached engines, template ZIPs or server runtime bundles are
  included here. Follow existing pinned dependency records, not absolute paths
  from the original developer PC.
- addons/godot-sqlite/gdsqlite.gdextension declares ONLY Windows x86_64 libraries.
  If the cloud runtime is Linux, obtain/build a matching licensed SQLite extension
  and add its platform declarations before claiming Godot import/startup passes.
  Do not silently remove persistence or switch to an unrelated engine version.
- Several Python integration runners use CREATE_NO_WINDOW, icacls and .exe paths.
  Port these deliberately for the chosen environment. Install isolated PostgreSQL,
  Java/Keycloak and Python dependencies for backend tests. Existing dependency
  acquisition code is in tools/auth_proof and tools/public_handoff.
- Art sources are in art_sources (including both .blend files). Runtime assets
  are explicit .glb files under features/ships; Godot need not import .blend files.
- First prove headless Godot import/startup, then the relevant runtime/backend
  checks. Keep final Windows client/server verification and visual playtests as
  separate gates. Current Windows check command, once dependencies are available:
  pwsh -NoProfile -File tools/Godot.ps1 -Mode Check -Headless

## Dedicated host status reported by Andy

The separate server PC runs C:\ShippingLanes-Windows-Host and reported HOST_READY.
Its reported LAN IPv4 is SERVER_LAN_IP. Setup was not rerun; existing identities,
certificates and saves were preserved. No remote access to that PC is implied.
Home gameplay and internet access are NOT verified. DuckDNS and outbound IPs were
reported inconsistent; the router/WAN path and final hostname remain unresolved.
Do not replace these with guessed values. Follow tools/hosting/CHATGPT-SERVER-HANDOFF.md.
Default exposed ports are HTTPS TCP 8443 and game UDP 24560; internal services must
stay loopback-only. Current preview has two test accounts, no Google signup or
open registration, and private certificate trust requirements. Production provider
storage, public certificate lifecycle and enrollment/security work remain pending.
Welcome email is explicitly deferred. No real server credentials or saves belong
in the repo or in the public friends client.

## Player requirements to retain

No player-to-player economic transfers, trades or gifts. One active nonexpiring
cargo job selected from dock services (Cargo/Refuel/Repair). No hidden shallow areas.
Heavy-loader pickup tolerates crooked placement when the platform is underneath;
raise/lower interaction, with no machinery/equipment degradation. Keep neutral snap
and low-speed neutral stopping assist. Gauges are unlabeled engine/fuel silhouettes
visible throughout active gameplay. Condition combines collision damage and wear.
Bright stylized blue water with muted coastal regions; original cartoon art inspired
by Wind Waker, not copied game assets. Improved wakes/foam, globe minimap, visible
curvature, docking rope/camera animation, cargo animation and turn roll are deferred
at their recorded steps. One local save/restart-progress migration is also deferred.

## Working process

Use branches/PRs for cloud work. Keep the repository private. Push reviewed source
changes back through Git; changing this repo does not update the running dedicated
server automatically. Never delete/reinitialize a live save for setup convenience.
The working source ZIP excludes .git but GitHub retains the development history.
Historical evidence/output archives remain on the developer PC, not in GitHub.
