# Step 41 — Public profile and server-switch handoff

Task ID: `public-profile-and-server-switch-handoff`. October 22, 2026.
Completed through the roadmap's selected-storage integration-fixture option.
This implements PostgreSQL authority and real HTTPS server adapters, not a public
deployment or a playable Godot dedicated-server launcher. The game export remains
the Step 40 private multiplayer build.

## Authority and portable profile

`services/public_authority/` contains a versioned PostgreSQL schema, transactional
adapter and loopback HTTPS service. Only the service has database credentials.
Scoped game-server credentials are stored hashed, checked for approval/expiry,
and held under a shared lock while a transaction runs. The service database role
has access only to this schema, with no DDL or unrelated fixture-schema access.

Public accounts use an internal UUID plus unique issuer/subject. The prototype
canonical profile holds version, wallet, revision, one stable starter ship with
fuel/geographic position, cargo IDs and lifecycle state, job IDs/state, delivered
cargo tombstones, and durable operation receipts. Fixture jobs preserve identity
and status only; job gameplay, production fleet expansion and schema migration
remain their later work. Private worlds cannot upload or overwrite this namespace.

Only approved operators/fixtures can create accounts, register servers or issue
tickets in this implementation. These are Python administration methods, never
HTTP endpoints. Synthetic identities are explicitly seeded by the test harness.
The existing OIDC proof still needs to be connected to ticket issuance before
real public admission. No real accounts or production secrets are used.

Each admission ticket is random, hashed at rest, expires after 30 seconds and is
bound to account, server, certificate identity, nonce and public protocol 7.
Ticket consumption and ownership acquisition share the same transaction.
A second server cannot take an active account. A fresh same-server ticket replaces
the connection generation without changing the server epoch.

## Lease and transaction rules

One locked lease row owns each public account. Its server, epoch, connection
generation, phase and backend-clock expiry fence every profile mutation. Leases
last 30 seconds. Renewal is accepted only before expiry; acquisition after expiry
advances the epoch. Time is read after row-lock acquisition, and expiry is checked
again before commit, so a request blocked on a lock cannot revive stale authority.

Checkpoint requests contain only permitted simulation fields and an expected
revision. They cannot submit balances, ownership or cargo lists. Fixture purchases
and deliveries use server-owned prices, integer money, stable cargo IDs, an atomic
game-stock/wallet update, journal and immutable receipt. The receipt fingerprint
excludes server epoch and connection identity, allowing the current owner to
reconcile the same operation after handoff. Old owners cannot replay mutations.
There is no player-to-player transfer operation.

## Durable departure and arrival

1. Begin preflights an approved destination and changes the source to QUIESCING.
   All previously locked mutations complete before that transition; later writes
   are rejected. Repeated begin uses the same transfer record.
2. Seal saves the exact canonical profile/revision into the transfer and fences
   source ownership. Source renewal and post-seal cancellation cannot reactivate it.
3. The named destination presents a fresh scoped ticket. Claim verifies the saved
   revision, consumes the ticket, advances the owner epoch/generation and stores
   its outcome atomically. Stable ship/cargo/job IDs and receipts remain unchanged.
4. A retry of the exact claim retains its saved binding and returns the current
   canonical profile without renewing/acquiring
   again, and only while that exact binding is still current. A stale outcome
   cannot restart expired ownership. Seal retries also reconcile lost replies.
5. Before seal, cancellation may resume a still-valid source. An expired source
   lease or abandoned sealed transfer recovers through a fresh ticket and epoch.
   A pending sealed transfer blocks unrelated admission until its transfer timeout.

This schema has no asynchronous accepted operation queue: every accepted mutation
is committed before response. Later long-running cargo/jobs must integrate their
own durable intents and reservations before they can cross this boundary.

## Separate server-process fixture

`tools/public_handoff/server_worker.py` is a headless Python adapter client with
only its server credential and TLS trust material. It is not a Godot game server.
It tracks a conservative monotonic deadline from request start, stops writes before
departure and on uncertain authority/backend failure, and requires fresh admission
after an outage. A restored backend does not silently resume a stale binding.
Fixture control input is local stdin, not a player-facing network endpoint.

The runner starts distinct source/destination/recovery processes. It terminates
the actual destination process and proves a new instance can recover its canonical
profile after expiry. Deterministic expiry tests advance persisted deadlines using
the fixture's admin connection; there is no time-changing HTTP endpoint. Five real
authority-service crashes and two immediate PostgreSQL stops also exercise WAL,
transaction rollback and lost-response recovery. No in-memory database substitutes
for PostgreSQL in acceptance testing.

## Reproduction and evidence

Use the same Python runtime/dependencies as the earlier storage/authentication
proofs: PostgreSQL 17.11, psycopg 3.2.10 and cryptography 50.0.2.

```powershell
./tools/CheckHandoff.ps1 -Python <python.exe>
```

The harness owns and cleans up its service/database/worker processes, isolates
all data under workspace output, removes temporary credential configs and never
connects to an external database. Output certificates/keys and synthetic databases
are test artifacts and are excluded from source backups.

Acceptance: 86 assertions plus three PostgreSQL setup checks pass.
Evidence: `../output/handoff/020fddf3/summary.json` and local service/worker logs.
Tests cover concurrent admission and payments/claims, replay/expiry/wrong-server
tickets, certificate rotation, private isolation, scoped database access, old
connection/epoch rejection, quiesce/seal/cancel/claim, wrong destination, preserved
ship/cargo/job identity, receipts after handoff, timeout/recovery, revoked servers,
renewal blocked behind an expiry race, five service crashes, database restarts,
actual destination-process death and local worker fencing after an outage.

No Godot code changed in this step. Existing game tests/export remain the prior
checkpoint; Full stays at 31 stages plus explicit identity/auth/handoff runners.

## Remaining integration and usability work

Before Step 42, connect validated OIDC admission to this service and connect two
headless Godot instances to leases, renewal, live helm/physics/collision quiescing
and canonical spawn/recovery. Prove the combined route with actual game objects,
then complete bounded replication/client pacing. These remain explicit gates;
the Python worker's active flag alone is not proof of Godot simulation fencing.

Dedicated-server usability target: a documented launch command/configuration,
actionable startup/connection errors, and a player join flow that does not expose
database credentials or require manual profile handling. Implement and test that
alongside the real Godot adapter and subsequent directory/deployment work. Internet
hosting, TLS renewal, production identity setup, operator monitoring and capacity
validation remain later rollout requirements. No hosting purchase is needed now.
