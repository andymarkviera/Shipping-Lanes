# Persistent local online development

This checkpoint packages the existing Keycloak, PostgreSQL, HTTPS authority and
Godot dedicated server into a repeatable loopback-only development setup. It is
not public hosting or a production account system. No firewall, router, OS trust
store, ordinary save profile or internet service is changed.

From ShippingLanes in PowerShell 7:

```powershell
./tools/LocalOnline.ps1 -Action Start
# Wait for LOCAL_ONLINE_READY in the returned log, then:
./tools/LocalOnline.ps1 -Action Play
# Saves connected boats before stopping the services:
./tools/LocalOnline.ps1 -Action Stop
```

Start creates a new setup only when none exists, then starts a hidden supervisor.
Setup can be run explicitly with -Action Setup. Editor is the default runtime;
-Runtime Release uses the existing exported game. -Python overrides the local
managed Python path. The pinned Java/Keycloak/PostgreSQL packages and Python
packages from earlier development proofs must already exist; no downloads occur.
Use the same -Name on every command to return to the same setup. Re-running Setup
refuses to overwrite data. Concurrent supervisors for one setup are rejected.

Data lives outside the Git repository in ../output/local-online/<name>/.
The directory ACL is restricted to the creating Windows identity and SYSTEM.
login-info.txt holds two generated development usernames/passwords; these are not
real personal accounts. Do not share private.json, key files or the data folder.
Only public-services.json and the public certificate are client configuration.
The supplied test funds are fixtures, not a chosen launch economy. New fixture
accounts have no invented jobs and start at two distinct fixed positions. Existing
profiles, money, IDs, fuel and positions are never reset on a normal restart.
This is not a general safe-berth allocator: an occupied saved position may still
be refused by the existing collision check.

Play launches an isolated client APPDATA profile with the public configuration.
The ordinary editor/Play profile remains unchanged. Accounts are enrolled only
by this local setup, with stable provider subject IDs and public account mapping.
There is no arbitrary-account creation HTTP endpoint. Godot collects no password;
the configured provider does browser authentication.

## Local browser certificate acceptance remains required

The local self-signed development certificate is pinned explicitly in Godot and
Python; validation is enabled. A normal browser does not automatically trust it.
Browser trust/interactive acceptance must be configured deliberately by the user
before an ordinary browser login can be considered ready. This tool does not
install a trusted certificate, bypass browser warnings or disable TLS checks.
The headless test browser trusts only this setup's certificate for the test.
The certificate lasts 90 days; certificate rotation is not automated here. Do not
delete a persistent setup to renew it: preserve data and implement rotation first.

## Lifecycle boundaries

The supervisor starts PostgreSQL, the persistent provider, the restricted-role
HTTPS service and then the ordinary dedicated runtime. It checks provider HTTPS,
authority readiness and the Godot listening marker. Public readiness is only
written after these checks; logs never print passwords/tokens. Runtime authority
and server credential files are removed on orderly shutdown. Server approval is
renewed by the local supervisor every ten minutes with a one-hour expiry. This is
local operator behavior, not a remotely callable credential renewal API.

On failure, owned children are stopped in reverse order and PostgreSQL is stopped
using pg_ctl. Provider data and the database survive. If the supervisor itself is
forcibly killed, inspect the owned service logs/processes before restarting; there
is no automatic orphan-process adoption or arbitrary PID termination.

LocalOnline Stop now requests a final save-and-release drain and waits for the
server result before stopping backend services. Failures are reported explicitly.
Periodic sailing checkpoints run every ten seconds; a crash still restores only
the last committed snapshot. See PUBLIC_DURABILITY.md for timing and failure limits. Browser visual acceptance,
remote access, port-conflict reassignment, general account administration, provider
backup/rotation operations and production capacity are not completed here.

## Verification

Run the managed Python executable with tools/public_handoff/local_online_check.py.
It creates a separately named protected setup, starts the actual services, checks
duplicate-supervisor rejection, signs both identities into the native Godot entry,
drives and disconnects, then restarts the entire stack and repeats. It compares
canonical account/ship IDs, money, revision, fuel and position across the restart.
The browser navigation is automated HTTP; Godot performs callback, PKCE exchange,
ticket request and DTLS gameplay. It leaves data for evidence and stops its owned
processes. No ordinary save or production account is used.


## Delivery and refueling in this setup

Use Play from this launcher, then SERVERS -> Local development server -> SIGN IN &
JOIN. Use an account in the protected login-info.txt file. Dock, open CARGO, accept
one container job and deliver at its named port. REFUEL now offers paid propulsion
fuel in a custom whole-liter amount; review the total before Buy. Price is a
provisional 0.25 credits/L. This belongs to authenticated online play, not the
separate LOCAL MULTIPLAYER TEST or free Port Test services. Game protocol 12 needs
matching client/server code: stop the stack gracefully and reopen clients after
updates. Development data and accounts persist across restarts.
