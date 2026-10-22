# Public Godot ownership integration

This checkpoint connects a real OIDC provider, the HTTPS ticket endpoint,
PostgreSQL ownership, and actual headless Godot starter hulls. It is the server
adapter portion of the pre-Step-42 integration gate, not public internet play.

## Implemented boundary

- `/v1/ticket` accepts a signed RS256 access token for the operator-pinned issuer,
  service audience and signing keys. It maps issuer plus subject to an existing
  enrolled public account. The caller cannot select an account, supply a private
  save, create a funded profile, or authorize peer transfers.
- Tickets retain the Step 41 single-use, server/certificate/nonce/protocol binding.
  Identity tokens stay at the identity service; the Godot owner receives a ticket
  and only its scoped server credential, never database credentials.
- The Godot adapter verifies HTTPS, renews every ten seconds and uses a monotonic
  deadline shortened by request duration and a 500 ms margin. A failed or stale
  authority response parks the actual hull: no physics, collision, visibility,
  throttle, or accepted helm orders. A successful late renewal cannot revive it.
- Departure freezes the hull, checkpoints actual fuel and scalar geographic
  position, then quiesces/seals the profile. The destination loads canonical ship
  identity, fuel, cargo records and geographic anchor at neutral. The experiment
  uses the existing 100 km navigation profile, not an invented world scale.
- Crashed destinations recover with fresh epochs; explicit authenticated recovery
  advances generation. Old commands and duplicate purchases remain fenced.

The identity endpoint is disabled unless the operator supplies its identity
configuration. Unknown signing keys fail closed; refreshed configuration and a
service restart are currently required for provider key rotation. Enrollment is
operator/fixture-owned; there is no public registration route or automatic wallet
creation. Configurations and command couriers containing credentials are removed
by the runner. Logs never include bearer tokens or server secrets.

## Run locally

Use the existing pinned Python, PostgreSQL, Keycloak, Java and cryptography tools.
No new downloads, accounts, hosting payments, or router changes are required.

```powershell
./tools/CheckPublicOwner.ps1 -Python <managed-python.exe> -Runtime Editor
./tools/CheckPublicOwner.ps1 -Python <managed-python.exe> -Runtime Release
```

Export Release first with `tools/Godot.ps1 -Mode Export -Configuration Release`.
Each run owns disposable loopback-only services and several real Godot processes.
The sign-in harness drives the real provider login form with a synthetic account.
Evidence is written to `../output/handoff/<run>/godot-summary.json`.
`CheckHandoff.ps1` retains the independent 86-check backend crash/transaction suite.
The full project runner remains 31 stages; these service proofs are opt-in.

## Remaining integration before public gameplay

The operator file courier is test infrastructure, not a player transport. Wire
protocol-7 tickets into the existing verified DTLS connection path and derive the
account binding from the authenticated peer; never expose the adapter's arbitrary
request method as a client RPC. Then add system-browser sign-in, server discovery,
connection errors, and an operator launch configuration. Real certificate identity
must come from the selected registered game server, not this fixture's labels.

Cargo is preserved as authoritative records here; this scene does not yet build
networked cargo bodies or jobs. Its local origin represents the saved geographic
anchor; shared world placement/streaming, periodic spatial checkpoints, and public
cargo/action adapters remain to be connected. A crash recovers the last committed
snapshot. Explicit transfer cancellation leaves the hull parked until fresh
admission, avoiding accidental revival after an uncertain operation.

Keep the public authority gate open until those transport/gameplay connections
are tested together. Bounded replication/client pacing also remains due before
Step 42. This checkpoint makes no capacity or production availability claim.

## Verified evidence — October 22, 2026

40 integration checks and 16 real-provider checks pass in each runtime:

- Editor: `../output/handoff/d04d1341/godot-summary.json`.
- Release: `../output/handoff/de4d472e/godot-summary.json`.
- Backend regression: 86 checks at `../output/handoff/76271b4e/summary.json`.

The runner deliberately expires backend leases using its disposable administrator
connection; production clients cannot do that. The destination Godot executable
is actually killed, and PostgreSQL is actually stopped for outage recovery.
All 95 scripts compile, Release exports, and ordinary game startup passes.

Recovery tag: `public-godot-ownership-adapter`.
Backup: `../output/checkpoints/public-godot-ownership-adapter-2026-10-22.zip`.

Follow-through: public DTLS peer admission and a normal headless configuration
entry point are now tested in PUBLIC_PEER_ADMISSION.md. That later checkpoint
supersedes the transport portion of the remaining-work list above. Shared
world/cargo/action integration, browser UI, provisioning and pacing remain open.
