# Local network session — Step 29

The main menu's Local Multiplayer Test opens an isolated two-player loopback
fixture. Open two game instances; choose Host locally in one, Join locally in
the other. Both show the same two starter hulls and entity IDs. Disconnect
removes the departing player's hull. Main menu closes the session.

Ships intentionally remain stationary: Step 30 adds authoritative helm input,
movement replication and smoothing. Existing solo handling tests are unchanged.
This scene does not share the earlier menu/economy fixture or its wallet.

## Authority and lifecycle

LocalShipSession uses ENet/UDP on 127.0.0.1, default port 28429, with one host
player and one client. Host binding is loopback-only; the client address is
fixed to loopback. This is not LAN or internet support.

Peer 1 is the explicit lifecycle/simulation authority, including on client
runtime nodes. A member's transport peer ID identifies its current controller,
not a saved account or public/private guest identity.

The host creates IDs from a random session epoch plus a monotonic spawn serial.
The host entity survives client departures. Repeated hello requests for an
existing peer resend the roster without spawning a second entity. A newly
connected guest receives a fresh ID; authenticated reconnection/save ownership
is later work.

The reliable hello RPC checks server role, transport-derived sender and protocol
version. The host publishes a complete revisioned roster after spawn/despawn.
The authority-only receiver also checks remote sender 1, epoch, increasing
revision, bounded record count, unique IDs/peers, known ship definition,
authority and spawn slot before replacing client state. Client-authored records
are never a spawning instruction for the host.

Each scene maintains an entity-to-node map. Reconciliation adds only missing
nodes and removes departed nodes; each ShipState instance ID matches the roster.
Simulation/fuel are paused in this lifecycle fixture on both peers.

Disconnect and host-loss cleanup close the transport and clear all entities.
Connection attempts expire after eight seconds. A failed host bind reports
the occupied/unavailable port. Disconnecting permits another host/join attempt.

## Scope and trust

This developer loopback fixture carries no credentials, account data, money,
inventory or saves. It is intentionally not DTLS-authenticated. The selected
authenticated transport and identity rules in ONLINE_ARCHITECTURE.md remain
requirements before any internet credentials or production state are used.
No firewall, router, system networking settings or public services are changed.
No tested player capacity beyond these two processes is claimed.

## Verification

`tools/Godot.ps1 -Mode NetworkCheck` runs CheckNetwork.ps1 with two independent
Godot processes. `tools/CheckNetwork.ps1 -Runtime Release` tests the packaged
Windows executable. Each run selects a free loopback UDP port and records logs
and machine-readable results under `../output/network-checks/`.

Host: 21 checks. Client: 26 checks. The runner additionally compares all three
rounds' complete entity-ID lists across processes. Checks cover unique runtime
hulls and authority, host identity continuity, repeated hello requests, ignored
client-authored snapshot calls, disconnect cleanup, reconnect with fresh guest
identity, host shutdown and unavailable-host timeout.

Both editor and Windows Release passed. Initial sandboxed runs could bind/start
but could not exchange local traffic; the same tests passed outside the
network-restricted execution sandbox. Run the suite with localhost networking
available; do not treat that sandbox timeout as an internet test.

Full checks now include NetworkCheck (21 stages / 67 scripts).
Native main menu and local-host scene captures were inspected. The title menu
spacing was tightened so all buttons fit the supported minimum window height.
