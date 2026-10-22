# Step 40 — Session identity and control handoff

Task ID: `session-identity-and-control-handoff`. October 21, 2026.
Complete for the selected private-world path. Public accounts, service leases and
server-switch handoff remain Step 41 and the pre-42 integration gate. Nothing is
deployed, and connections remain restricted to this computer.

## Player-visible flow

The menu's local multiplayer test now opens the secure private-world scene.
Host/resume starter and Host/resume heavy keep separate private development worlds.
Copy invitation copies public world/certificate information, never the private
key or a player's credential. In another window, Join invitation shows an explicit
trust dialog. Paste the host's invitation and choose Trust invitation and join.
Reconnect uses the same trusted world and in-memory credential.

The invitation pins the exact certificate PEM SHA-256 digest, world, port and hull.
It is a local development invitation, not an internet directory or public account
credential. An invitation's authenticity comes from getting it from the intended
host, not from its self-reported hash. DTLS also verifies hostname and certificate
validity before sending any guest credential. The host key never leaves its save
folder. The development certificate expires in 2030; renewal/trust migration is
future deployment work, with no insecure fallback on expiry.

## Identity and control

- Private membership is keyed by a random world/player ID; ship IDs persist
  independently of ENet connection numbers. The host stores only the SHA-256 hash
  of a random 256-bit guest credential. Display names do not recover ownership.
- A valid reconnect increments a durable connection generation. The old roster
  binding is removed, orders/receipts are cleared and the hull parks neutral before
  the new connection gains control. The old transport is disconnected. A duplicate
  hello on the current connection cannot increment the generation or create a ship.
- Helm, generic actions and cargo requests carry the current generation. Both the
  transport sender and generation must match the authoritative roster; old packets
  cannot control the new binding. Requests from a previous host session also fail
  its random session epoch. Private protocol is 6; old loopback fixtures remain 5.
- Unauthenticated, wrong-world, forged-token and fresh-guest attempts cannot seize
  an active member. One host and one guest may play at a time. Extra transport slots
  permit authenticated replacement, not additional active ships. Pending joins
  expire after eight seconds; the prototype retains at most 64 members per world.
- Unknown nonempty credentials fail instead of silently opening new progress.
  Losing a credential permits a new guest when capacity is available, but never
  grants the old guest's ship. Public identity tokens and imported public saves are
  not accepted by this path.

Client credentials remain memory-only, scoped to world plus trusted certificate,
as selected in the authentication prerequisite. Closing the client application
loses its credential; OS-secured persistence/recovery UX is still future work.
The test courier used to simulate client restarts is not a production feature.

## Persistence and departure

Host data lives under `user://private_net/<ship definition>/`: `members.db`, the
host certificate/key and existing fixture ledgers keyed by stable private player
ID. No prior Step 39 session folders or Play save slots are overwritten or imported.
This retains the per-member fixture ledgers; shared private market/facility
transactions are not introduced by this step.

SQLite WAL/FULL stores world/certificate context, members, generations and typed
spatial snapshots. Generation comparison and spatial write use one SQL statement.
Pose/fuel and heavy-lifter deck/attached payload checkpoint every ten seconds,
before reconnect, and on normal departure. Money/receipts keep their existing
immediate durable transaction boundary. Host shutdown ends all connections, with
no host migration; a new process can reopen the same world and credentials.

Restoration starts neutral/stationary. Interrupted deck travel stops at its saved
height; it does not deliver or release cargo. Corrupt/incompatible identity/state,
missing certificates or missing existing ledgers stop admission and preserve files.
An absent ledger cannot silently become a fresh wallet. The certificate is validated
against stored context; a changed certificate is not silently trusted as the old world.

## Verification

```powershell
./tools/Godot.ps1 -Mode Export -Configuration Release
./tools/CheckIdentity.ps1 -Python <python.exe> -Runtime both
```

The runner owns all subprocesses, isolates user data and uses eight Godot processes
per hull/runtime run (including rejected clients and fresh recovery processes).
It deletes its disposable raw-credential courier in `finally`; logs contain no
credential. Generated private keys/databases remain in local test output, not Git.

70 starter and 74 heavy-lifter assertions pass in each runtime (288 total): live
helm RPC, impostor/wrong-world/full-world rejection, valid replacement, old-peer
and old-generation rejection, no host-ship seizure, stale spatial write rejection,
neutral recovery, stable money/receipt/cargo, host reopen, completely new-process
recovery, and fail-closed incomplete-ledger recovery.

Evidence under `../output/identity/`:

- Editor starter: `editor-starter-186e383d`
- Editor heavy: `editor-heavy-aee52e83`
- Release starter: `release-starter-4ae22882`
- Release heavy: `release-heavy-cb2ef56b`

Action (49) and cargo (34) regressions pass in editor and Release. Existing
reconnect lifecycle (72) and impaired replication (26) pass in editor. All 92
GDScripts compile; Release export and ordinary startup pass. Full remains 31
stages; the multi-process identity runner is an explicit additional check.

The component authentication proof remains in AUTHENTICATED_ADMISSION_PROOF.md.
Its public OIDC/ticket registry is not claimed to be connected to this private
session. Step 41 must implement public account service admission, lease fencing
and handoff; public authority integration and replication/pacing gates remain due
before Step 42. This does not establish internet or 100-player readiness.
