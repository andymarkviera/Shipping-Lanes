# Public shared boat physics

Nearby authenticated server hulls now share a Godot World3D and collide through
the existing CharacterBody3D handling. Public hulls lock vertical body translation
so collision recovery cannot push one boat underneath another. Cosmetic bobbing
remains on the visual assembly. Collision response is the existing kinematic
stopping/sliding model; it is not a mass/impulse or damage simulation.

Before hull physics, public_physics_world.gd captures all canonical geographic
positions and groups hulls connected by distances up to 250 metres. Each group
uses a local chart and its own World3D. Approaching/separating groups merge/split;
a group rebases when its leading hull moves more than 500 metres from its origin.
These distances select simulation spaces, not gameplay boundaries or shallows.
At the current eight-peer cap a connected chain spans at most 1,750 metres before
rebase offset. This uses the existing experimental 100 km sphere, not a final
world-scale or capacity guarantee. Threshold churn/performance remains unmeasured.

Reframing preserves geographic position, transported heading, velocity direction,
fuel and stable ship identity. All hulls in a changed group are mapped before the
next hull physics step. Departure detaches the parked owner before obsolete
physics spaces are freed, allowing its asynchronous save/release to finish.
Observer replication and saves use the same geographic mapping.

A newly admitted hull starts paused. A conservative horizontal circumscribed-radius
clearance check refuses occupied saved spawns, releases the acquired lease and
leaves canonical position/fuel unchanged. The rejected connection is closed; it
can retry after the area clears. No automatic teleport or funded replacement is
created. Port/berth allocation and a player-facing occupied-spawn message remain
future join-flow work. Two distinct new profiles at the same default position
cannot both spawn until an appropriate starting-position policy is provided.

Tests: public_physics_probe covers seam/polar chart merge, split and rebase,
heading/velocity/fuel preservation, spawn clearance, two moving maximum-speed
head-on hulls and authority-fenced collision removal. public_handoff/physics_probe.py
runs the same fixture in editor/Release and checks exit status and log errors.
The real OIDC/DTLS peer suite additionally verifies shared physics identity,
occupied-spawn lease release with unchanged save, and geographic persistence on
departure. Headless tests do not establish graphical presentation quality.

Next: playable public camera/control scene and login/server selection, followed
by public cargo/actions, periodic saves and bounded replication/client pacing.
The full public integration gate and Step 42 remain open. Main-menu Play is
unchanged; no external hosting or production service configuration was performed.
