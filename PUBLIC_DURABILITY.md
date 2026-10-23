# Public sailing saves and orderly shutdown

Public boat owners attempt a spatial/fuel checkpoint every 10 seconds while
active. Each checkpoint reads the current canonical revision, then captures
geographic position, heading and fuel together and submits an authority-fenced
update. Sailing continues during ordinary saves. Money/cargo/job receipts remain
owned by their existing transactions; this task does not add economic operations.

Ten seconds is the scheduling interval, not a guaranteed maximum crash rollback.
Service latency, a busy renewal and a save in flight add delay. A crash restores
the latest committed snapshot. Failed/uncertain checkpoints fence the live hull
and require fresh admission; they do not silently fall back to local progress.
Capacity tuning and a measured end-to-end durability budget remain later work.

A per-hull save guard prevents overlapping checkpoints. Disconnect, transfer and
replacement cleanup wait for pending work before a final snapshot or freeing the
owner. Lease expiry/stale generations still reject writes. The snapshot is captured
after the revision read so position and fuel describe the same simulation instant.

## Operator stop

The dedicated server accepts an optional absolute stop_file path in its local
configuration. Creating that file starts a drain: refuse new admission, park the
connected hulls, finish pending saves, checkpoint each final pose/fuel and release
its lease. An in-flight admission is also awaited; replacement cleanup rechecks
shutdown/disconnect after any wait. The file is not a network command.

Use tools/StopDedicatedServer.ps1 -Config <server-config.json>. The request itself
is not proof of completion. PUBLIC_SERVER_DRAINED and exit code 0 confirm drain;
PUBLIC_SERVER_DRAIN_FAILED and exit code 2 indicate incomplete final persistence.
A replacement admission that has already revoked an older connection can cause
that older final save to be rejected; shutdown reports failure conservatively and
recovery uses committed state. It must not revive the old generation to force a save.
The drain waits at most 20 seconds. An unreachable backend cannot guarantee a
final save; previously committed snapshots and backend lease expiry remain the
recovery boundary. Check failures instead of treating process exit as success.
The standalone launcher refuses an existing stop marker so a restarted server
cannot silently exit immediately. Remove that marker only after the prior process
has stopped. Each server needs its own operator-owned control path.

LocalOnline Stop now creates its server stop marker and waits up to 25 seconds
before shutting down the authority, identity provider and database. It reports
failure if the server exits unsuccessfully or times out, then cleans up owned
processes. The controlled development supervisor still has no orphan adoption after
its own forced termination. OS kills/power loss bypass orderly shutdown.

## Verification

Run tools/public_handoff/durability_probe.py --runtime editor or release after
exporting the final build. It uses isolated PostgreSQL/HTTPS services, fixture-issued
connection tickets and real DTLS peers with the ordinary dedicated server. This
is a durability test, not a new OIDC/browser proof.

Cases cover periodic commits while driving, abrupt server kill, actual lease
expiry and restart, preserved canonical snapshots, final checkpoint and release
with a connected player, immediate reconnect, replacement login versus shutdown,
and backend outage producing failure rather than a false success. Existing peer
regressions cover stale/replaced commands and two-account isolation. Browser trust,
general spawn allocation and bounded network capacity remain separate open items.
