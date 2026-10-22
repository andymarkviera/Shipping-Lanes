# Public peer admission and dedicated runtime

This checkpoint connects the existing OIDC/HTTPS ownership service to real Godot
DTLS peers. A client can authenticate, control its assigned starter hull, and
receive movement snapshots from a separate headless server. This is a tested
network integration, not the finished public multiplayer game.

## Connection and control

1. The client verifies the registered game server's pinned self-signed certificate
   and hostname before sending a credential. Game-server certificates are separate
   from the HTTPS authority's CA/leaf certificates. The current pin is SHA-256 of
   the exact PEM file bytes; distribute the same file without reformatting it.
2. The server generates a fresh 256-bit nonce for that transport. The identity
   service issues a single-use protocol-7 ticket for the signed-in account, server,
   registered certificate and nonce. The player cannot choose an account ID.
3. The server redeems the ticket using its own scoped credential, the challenge
   stored for that peer, and the fingerprint of its actual certificate file. A
   registration mismatch, wrong connection, or unverified identity fails closed.
4. Only the transport sender's installed ship/epoch/generation can accept helm
   orders. There is no client RPC for arbitrary backend requests, wallets, saves,
   cargo imports, or player-to-player transfers.

Helm commands use a separate reliable ordered channel with explicit sequence,
finite/range validation and a 30 ms acceptance interval. Commands older than the
last accepted sequence cannot reapply. Missing input neutralizes the order after
one second. Owner snapshots are unreliable ordered on a different channel at
5 Hz. Reliability was selected after the initial unreliable DTLS input experiment
lost control orders; traffic/pacing still needs measurement in the pre-42 gate.
This is not a latency, congestion, or 100-player capacity claim.

A fresh authenticated replacement parks/removes the old helm before activating
its replacement. Disconnect immediately removes peer authority and parks the hull,
then checkpoints pose/fuel and releases its backend lease when authority is still
valid. Outage/expiry disconnects control and cannot automatically re-admit it.
A crash or active replacement restores the last committed profile; periodic
spatial checkpoints and richer recovery UX are still pending.

The transport is bounded to eight connections including pending admissions; a
pending ticket has 30 seconds. Two distinct enrolled accounts are tested. Each
hull currently lives in its own World3D/local chart, so boats do not yet see or
collide with one another. Shared geographic placement, cargo bodies/jobs/actions,
rendered client presentation and server-switch UX remain integration work.

## Dedicated launch entry point

`tools/StartDedicatedServer.ps1` starts the headless runtime with a private JSON
configuration. It reports the process ID and stdout/error log paths. A launch
report says Starting; the log's PUBLIC_SERVER_LISTENING marker confirms the socket
started, not backend availability or internet reachability.

```powershell
./tools/StartDedicatedServer.ps1 -Config ./secrets/server.json -Runtime Release
```

The configuration shape is in
`services/public_authority/server-config.example.json`. It contains placeholders,
not working credentials. Use absolute certificate/key paths. The server ID,
scoped secret and certificate pin must correspond to an approved registration
in a running authority service. Use one running instance per registration.
The current disposable harness provisions these automatically for tests only;
a persistent identity/backend deployment and enrollment workflow are not yet
packaged. No port forwarding or paid hosting was configured by this checkpoint.

The normal executable uses `--headless -- --public-server-config=<absolute path>`.
The wrapper hides the process window and keeps credentials out of its command
line. Keep real configurations under the ignored secrets directory. This launch
path is tested with a real authenticated client, separately from the operator
file-courier test scene. Shutdown currently terminates the process; graceful
operator shutdown/checkpoint controls remain follow-up work.

The main menu still uses the existing private/local flow. System-browser sign-in,
public server discovery, and a player-facing join screen are not wired in yet.
The integration test's synthetic browser drives real Keycloak PKCE sign-in and
hands the returned ticket to the client test driver; the actual ticket redemption,
helm orders, peer replacement and state snapshots travel over DTLS.

## Verification

```powershell
./tools/CheckPublicPeer.ps1 -Python <managed-python.exe> -Runtime Editor
./tools/CheckPublicPeer.ps1 -Python <managed-python.exe> -Runtime Release
```

Build Release first. Tests use disposable local services/accounts and owned child
processes. The second-account isolation case seeds a second fixture identity via
the administrator; the primary account exercises real OIDC sign-in. The
`--adapter-only` Python option skips OIDC for diagnostics and is labelled as such
in its summary. It must not be reported as a complete sign-in result.

Checks cover incorrect hostnames/registration, per-connection ticket binding,
unauthenticated and cross-account command attempts, duplicate/stale input,
actual motion/snapshots, two accounts, replacement, disconnect persistence,
automatic outage fencing, and the normal dedicated-server configuration entry.
Full project checking remains 31 stages plus the opt-in public service runners.

## Verified evidence — October 22, 2026

48 integration checks plus 16 provider checks pass in each runtime, with three
PostgreSQL setup checks per run. Both summaries explicitly have adapter_only=false:

- Editor: `../output/handoff/ccbaecb9/peer-summary.json`.
- Release: `../output/handoff/c8a6a644/peer-summary.json`.
- Existing backend regression: 86 checks at `../output/handoff/d67d8ef7/summary.json`.

All 98 scripts compile; Release export and ordinary startup pass. The real
StartDedicatedServer.ps1 wrapper separately reached its listening marker on
loopback with a dummy credential and was then stopped. That wrapper smoke test
proves launch/log handling only; the main integration tests prove actual joining
through the normal dedicated configuration entry point with valid credentials.

Recovery tag: `public-peer-admission`.
Backup: `../output/checkpoints/public-peer-admission-2026-10-22.zip`.
