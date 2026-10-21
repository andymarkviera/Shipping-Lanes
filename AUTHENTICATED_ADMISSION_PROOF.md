# Authenticated admission feasibility

Supplemental prerequisite after Step 39, before Step 40. October 21, 2026.
This is a disposable component proof, not a public account service or an enabled
login feature. Existing Play/local multiplayer remains the Step 39 implementation.

## Proven boundaries

- Real isolated Keycloak HTTPS discovery, authorization code and PKCE S256 token
  exchange. The native protocol binds a loopback callback before authorization,
  checks unpredictable state, limits its lifetime and consumes it once. RS256
  signature, issuer, audience, expiry and ID-token nonce are checked before using
  issuer plus subject as identity. Wrong verifier, replay, mismatched claims,
  expired token/callback and modified token are rejected.
- The test browser is an HTTP user agent that submits a synthetic user's form
  to Keycloak and follows its redirect. This exercises the actual provider and
  native callback, but does not validate system-browser launching or a Godot login
  menu. Production must launch the system browser; the game must never collect
  passwords. No password grant or client secret is used.
- A real PostgreSQL registry maps issuer/subject to an internal account and
  stores only ticket/server-credential hashes. A ticket is bound to server,
  certificate identity at issuance, connection nonce and protocol; it expires
  after 30 seconds and commits consumption once under a row lock. Eight concurrent
  attempts yield exactly one success. Wrong bindings, expiry, replay, revoked
  server, expired server credential and certificate rotation are rejected.
- Registry methods run directly inside the Python service-side fixture, using
  its disposable database. They are not yet exposed through an authenticated
  HTTPS admission API or connected to Godot ticket RPCs. Account creation accepts
  already-validated claims; an untrusted HTTP caller must never supply those claims.
- Actual Godot high-level RPC travels over ENet DTLS in editor and Release.
  Valid CA/hostname succeeds; wrong CA, wrong hostname and plaintext fail before
  any application credential is sent. The credential in this transport fixture
  is a fixed synthetic sentinel, not an account token or registry ticket.
- Real SQLite private guest records retain only hashes, scoped to world and
  certificate. Reopening the store preserves identity and increments the connection
  generation; the old generation is rejected. This is a registry fencing predicate,
  not yet an atomic gameplay-write fence or a public gameplay ownership lease.

## Transport decision

The pinned engine's high-level create_client connects immediately, before a DTLS
setup call could take effect. Create ENetConnection, configure verified DTLS,
connect, then attach that established connection to a mesh client with only the
authoritative server peer. The server remains an ordinary ENet server, configured
for DTLS before polling. No peer-to-peer topology or gameplay authority is added.
Step 40 must integrate and retest this adapter with real session ownership.

References: [Godot ENet API](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html),
[pinned engine implementation](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/modules/enet/enet_multiplayer_peer.cpp),
[Keycloak TLS configuration](https://www.keycloak.org/server/enabletls).

## Dependencies and credential policy

`tools/auth_proof/dependencies.json` pins archive hashes for Keycloak 26.8.1 and
Temurin JDK 25.0.4.1+1-LTS, plus cryptography 50.0.2. Reuses the previously pinned
PostgreSQL 17.11 and psycopg 3.2.10 fixture. Java archive contents are checked against
the extracted runtime; Keycloak is freshly extracted into each run. Keycloak uses
local cache, a disposable database, HTTPS only and loopback binding. System Java
and system certificate trust are not changed. Dependencies remain development
tools outside the game export; their upstream notices remain in their archives.

Access/refresh tokens, PKCE verifier, raw tickets and reconnect credentials are
memory-only. Until an OS credential store is implemented and tested, application
restart requires fresh public sign-in; private persistent reconnect UX remains
Step 40 work. Do not put secrets in Godot preferences, saves, command lines or
diagnostic logs. Test output contains disposable TLS keys and synthetic databases;
do not publish output folders. Imported synthetic plaintext password file is
removed after provider startup and on failure. No real user accounts are enrolled.

## Reproduction and evidence

First install the existing public-storage fixture with CheckPublicStorage.ps1.
Use a Python runtime containing cryptography 50.0.2. Build Windows Release, then:

```powershell
./tools/CheckAuth.ps1 -Python <python.exe> -Install -Runtime both
```

`-Install` downloads only missing pinned Java/Keycloak archives to workspace
`output/tools/auth`; no global packages or services are installed. Subsequent
runs omit it. Local TCP/UDP process access is required. Each run owns and stops
its subprocesses and writes sanitized results under `../output/auth/`.

Acceptance evidence: `../output/auth/47d219f6/summary.json` plus eight DTLS
server/client result pairs. Godot compilation covers 88 scripts; Windows Release
export and ordinary main-menu startup are checked separately.

Remaining gates: player-facing native browser flow, OS secret storage/private
invite trust UX, session integration (40), durable ownership leases/handoff (41),
two-server authenticated service integration and bounded replication/pacing before
42. Internet hosting, account enrollment and operational hardening remain later.
