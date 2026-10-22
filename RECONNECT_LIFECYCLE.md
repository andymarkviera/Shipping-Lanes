# Step 39 — Reconnect and lifecycle

Completed October 21, 2026 for the two-player loopback development session.
Protocol 5 replaces fresh-entity-on-rejoin behavior. This is a same-running-host
reconnect gate, not internet authentication or persistent account identity.

## Lifecycle policy

| Event | Authoritative outcome |
|---|---|
| Guest disconnects or returns to menu | Remove guest from active roster, discard old input/orders and transient action streams, retain one guest ownership record and its economic ledger. Park the hull neutral/stationary with processing, collision and presentation disabled. Stop its wake. |
| Guest reconnects with its session credential | Rebind the retained entity to the new transport sender; reactivate the same host hull object, fuel, pose, deck and payload. Client rebuilds presentation from authority snapshots. No new wallet or ship is issued. |
| Wrong/missing credential after guest admission | Refuse admission; never replace the reserved record or seed another wallet. Reservation lasts until this host session ends. |
| Duplicate hello from the admitted peer | Return current roster; create no new ownership or economic state. |
| Input stops while connected | Existing 500 ms dead-man input timeout commands neutral. |
| Host disconnects, returns to menu or closes | End the session, close durable economic stores, remove active/parked hulls and payloads, clear client presentation. No host migration. |
| Host process crashes/restarts | Existing SQLite economic commits/receipts remain on disk. Automatic world/guest restoration is not implemented here; a new host session has a new epoch and rejects old reconnect credentials. |

Parked hulls remain hidden child nodes to retain heavy-ship payload relationships,
but are absent from the active roster, replication, collision and simulation.
They do not consume fuel or continue deck movement while parked. This avoids
reinitializing a boat or accidentally freeing its separate payload during a drop.
One reserved guest bounds retained memory and ownership in this two-player fixture.

## Identity and economy boundaries

On first admission the host issues 32 random bytes as a loopback-only reconnect
credential. The host keeps its SHA-256 hash; the client keeps the credential only
in SceneTree metadata keyed by local port. It survives menu/scene changes during
that client run, not application restart. It is never printed in test evidence.
Admission rebinds the transport sender; action ownership still uses that sender.
Unauthenticated/rejected peers receive no motion snapshots. Only one guest can
be admitted at a time. Public credentials, encryption and durable identity require
the next authenticated-admission proof and Step 40; do not expose this listener
beyond its enforced 127.0.0.1 binding.

Each authoritative entity gets a private DurableEconomy store under
`user://n/<session epoch>/h.db` or `g.db`, with a matching private realm. Economic
operations commit money/cargo/receipts atomically at their existing transaction
boundary. Disconnect does not close or replace that ledger; shutdown closes it
without resetting committed state. The probe performs a host-side purchase and
retries it after reconnect and disk reopen, proving at-most-once settlement.
No new economic RPC or public account import is added. This networking fixture
still does not share the solo Play/handling slots or present network shop UI.

Helm and harmless test-pulse receipts remain connection-scoped and reset on
disconnect; durable payment receipts do not. The old sender cannot reuse its
request after rebind. Cargo command sequencing resets for the new connection;
the authoritative attached cargo itself stays on the retained boat.

HOST NEW LOCALLY / HOST NEW HEAVY explicitly start a new development session.
JOIN / RECONNECT uses the retained credential. JOIN NEW SESSION confirms forgetting
that local credential for a newly started host; it does not erase or transfer
host progress. Guest process-restart recovery, durable host world restoration,
multi-server ownership fencing and real accounts remain upcoming identity gates.
The solo world's ten-second/departure saves remain unchanged.

## Verification

NetworkCheck now runs 72 assertions across two real processes (44 host, 28 guest),
three connection rounds, a wrong-credential attempt, host loss and an unavailable
host timeout. It verifies exact host hull identity, retained pose/fuel, neutral
return, disabled parked physics/presentation, single ownership/ledger, payment
receipt retries and a durable ledger reopen after shutdown. Each process receives
isolated APPDATA; test runs never open the player's local saves.

Accepted evidence under `../output/network-checks/`:

- Editor lifecycle: `Editor-normal-241a18958aca4b3797ce615f6e6d6849`
- Release lifecycle: `Release-normal-543314b2dca449219f229bdd4d415177`
- Editor action ownership: `Editor-normal-e46b4cdf05464b1c826362306879eaf1`
- Release action ownership: `Release-normal-93e6dee1d7e147089dffdd86fd6e81f5`
- Editor attached cargo: `Editor-normal-6718c7b673b540dbabfc0a82ad677e12`
- Release attached cargo: `Release-normal-7c0ec672711a46a0bb290c24235d6add`
- Editor impaired motion: `Editor-impaired-8db5b7780b814fb99d2c1ea4fb9745da`
- Editor connected-world transitions: `Editor-normal-953a18a6cb1b49f5871595761cd703de`

Action checks pass 49 assertions; cargo passes 34, now including the returning
guest's own secured payload. Impaired motion and connected-world regressions pass.
All 87 GDScripts compile; Windows Release export/startup pass. Full remains 31
stages because this extends existing NetworkCheck rather than adding another one.
These tests do not establish internet latency or 100-player capacity. The recorded
bandwidth/packet-size/client-pacing corrections are still required before Step 42.

Next: the authenticated-admission feasibility prerequisite before Step 40.

Step 40 update: the player-facing local test now uses PRIVATE_SESSION_IDENTITY.md.
This document's Step 39 fixture remains available for lifecycle regression tests.
