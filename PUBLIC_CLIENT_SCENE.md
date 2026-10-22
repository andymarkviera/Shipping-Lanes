# Public camera and helm scene

features/network/public_client.tscn is the player scene. Its root is PublicNetwork
and its authenticated child is Session, matching the dedicated server's RPC paths.
It composes the existing public session and nearby replicas with the bright blue
ocean, orbit/follow camera, opaque HUD and connection menu. The HUD reads speed
and fuel from authoritative owner snapshots; visual hulls remain inert replicas.

The player uses saved throttle/steering/neutral bindings, right-mouse orbit, wheel
zoom and camera recenter. Commands are sequenced and sent at 10 Hz through the
existing authenticated helm RPC. No client-side hull simulation or authority
credential is introduced. Public lateral thrusters, cargo, wakes and additional
ship types remain separate integrations; the current server helm accepts throttle
and rudder. The menu never pauses the shared server or promises an immediate stop:
zero throttle lets the authoritative hull coast according to handling physics.

Input requires a current binding, the matching visible hull, and owner/roster
updates less than one second old. Menu, lost focus, stale snapshots, empty fuel
or disconnect zero the requested throttle. Existing PlayerControls release gates
prevent held inputs from resuming through menus. Disconnect drops camera focus
and clears replicas. The always-visible Menu button also works before connection.

## Sign-in integration boundary

The future sign-in/server-selection flow loads this scene, connects ticket_required,
and calls connect_server(settings) with the selected approved server's public
host/port, server ID and trusted certificate/fingerprint. Only after verified DTLS
issues a per-connection challenge does ticket_required(nonce) fire. The sign-in
flow obtains a nonce-bound ticket from the authority HTTPS service and calls
submit_ticket(ticket). Tokens/passwords/server secrets are not stored by this scene.
There is no password form, account creation or auto-enrollment in this checkpoint.

Main-menu Play is unchanged until that entry flow is connected. The developer
--public-client-preview argument opens the actual scene disconnected; it does not
fake a login or spawn a controllable local boat. Integration fixtures drive this
same scene with real server tickets, rather than a second test-only presentation.

## Validation

The peer probe inherits the player scene and disables automatic input for the
existing transport/security tests. Against the normal dedicated entry point it
then enables the actual input controller and verifies camera focus, HUD fuel,
zoom, server movement from throttle input, menu/lost-focus neutralization, stale
snapshot handling and disconnect cleanup. Stale age is injected in the test
courier only, outside the public scene. Exported disconnected preview startup and
normal title startup are also checked. These checks are headless; visual polish,
network-delay feel and water-motion/wake integration remain unverified here.

Next: system-browser sign-in and server selection, approved account enrollment,
starting berth allocation/occupied-spawn feedback, then remaining public cargo,
periodic saves and replication/pacing capacity work. Step 42 remains gated.
