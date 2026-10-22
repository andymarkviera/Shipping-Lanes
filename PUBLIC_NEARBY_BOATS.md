# Public nearby boat presentation

This checkpoint adds observer replication to the public authority integration gate.
It is not completion of the shared-physics or playable public-login flow.

The authenticated server sends a complete nearby roster at 5 Hz on the existing
unreliable ordered snapshot channel. Each recipient sees boats within 1,000 metres
on the experimental 100 km sphere, capped by the current eight-member admission
limit. Rows contain stable ship identity, ownership generation, relative position
and heading; other players' account, fuel, cargo and credentials are omitted.
Only the installed server and matching recipient ship/epoch/generation can update
that client's view. Sequence checks reject old rosters. A complete roster removes
missing boats, generation replacement rebuilds a replica, disconnect clears all
replicas, and 1.5 seconds without snapshots removes stale visual boats.

The server converts each simulated hull to a canonical scalar geographic address
using the same mapping as departure saves. It maps nearby ships into a chart
centred on the recipient's current address, including transported heading. The
recipient's boat stays at the visual origin; future scenery/camera integration
must use this same moving chart. Hull meshes interpolate toward authoritative
poses; replicas disable processing and collision layers/masks and grant no helm.
No prediction or extrapolation is claimed.

Simulation remains in separate per-owner physics worlds. Ships can overlap and
cannot yet collide with one another. Public terrain/cargo/wakes, safe shared
spawn placement, shared physics, camera/control scene, browser sign-in and server
selection still require integration. Main-menu Play is unchanged. Eight peers and
5 Hz snapshots are a bounded development configuration, not a capacity result;
packet budgeting and client pacing remain required before Step 42.

Validation extends the real DTLS/OIDC peer suite with two-client roster creation,
geographic spacing, inert replicas, departure removal and disconnect cleanup.
Headless tests verify scene nodes and transport, not visual appearance on screen.

Follow-up: PUBLIC_SHARED_PHYSICS.md supersedes the isolated-server-physics limitation above. Player-facing scene/login integration remains open.
