# Public storage adapter proof

Supplemental task `public-storage-adapter-proof`, after Step 34 and before 35.
October 21, 2026. Isolated synthetic-account experiment; no public deployment.
Status: complete for the bounded adapter gate.

98 harness checks pass independently with editor and Windows Release clients;
each includes the Godot client's four HTTP commit/retry/conflict assertions.
All 80 GDScripts compile, Release export and normal startup pass. Unchanged
physics/network suites were not rerun. Accepted sanitized reports are tracked in
`tools/baselines/public-storage-proof.json`; full logs/databases remain in output.
Editor run: `c2b315d8-2302-41c7-8dc9-01153f144573`.
Release run: `1eabbab7-4c1c-478f-ac1e-0a03bdf9b80f`.

## Boundary and pinned dependencies

`tools/public_storage/service.py` is a separate Python process using PostgreSQL
17.11 (EDB Windows x64 build 3) and psycopg/psycopg-binary 3.2.10. The tested host
runtime is CPython 3.12.14. `requirements.txt` pins all four wheel versions and
SHA-256 hashes for Windows x64 / CPython 3.12. Python packages and PostgreSQL live
under workspace `output/tools`, outside the Godot project and exported game.
The portable archive SHA-256 is
`4B8DB0930C38F6EF845DB919551DEDDA3B6B845AEB0927B3D79A6E8E9E4537CF`.
This is a locally recorded reproducibility hash, not a publisher signature.
The runner verifies the archive and its extracted bin/lib/share files.

PostgreSQL uses the PostgreSQL License; psycopg uses LGPL-3.0. The downloaded
distributions retain their license notices. No database installation, Windows
service, firewall rule, production account or external hosting is created.
The wrapper requires an explicit Python path and `-Install` to fetch dependencies.

Each run creates a fresh UUID-named cluster under `output/public-storage`, bound
only to 127.0.0.1 with SCRAM passwords and fsync, synchronous_commit and
full_page_writes enabled. The service has a separate non-superuser role and binds
only to 127.0.0.1 on an ephemeral port. It requires explicit fixture mode and the
test database name. Two random, per-run bearer tokens map to synthetic Alice/Bob.
Private credentials and private realm requests cannot access public receipts.

The HTTP fixture intentionally has no TLS or OIDC and admits no real profiles.
Production still requires the selected HTTPS/OIDC/server-lease admission gate.
The Python orchestrator owns database setup, audit and fault injection. The Godot
client receives only a loopback port, synthetic service token and expected
revision; it gets no database credential or service configuration path.

## Transaction semantics

The exact request fields are version, realm, action_id, operation, quantity and
expected_revision. Only `public_fixture` and fixed game-owned purchase, delivery
and service-fee operations are accepted. There is no client price, recipient or
peer-trading operation. Integer types/bounds match Step 34; booleans, floats,
numeric strings, duplicate JSON keys, nonfinite values and oversized bodies fail.
The service hashes canonical ASCII JSON with sorted keys, compact separators and
exact integer encoding. Whitespace/key order do not alter semantic identity.

Within one transaction, affected account rows are locked in stable lexical order
before receipt lookup. The shared game row deliberately serializes this small
proof; it is not a measured production market architecture. The receipt primary
key is (realm, authenticated actor, action_id). Same key/hash returns the saved
result; a different hash returns id_conflict. A new owned intent validates current
revision, funds, stock and overflow, then changes both wallets/inventories and
inserts the receipt and balanced journal in one synchronous commit. Valid business
rejections retain their original failure receipt without changing economic state.
Receipts are never pruned; the service role cannot update or delete them.

Delivery is a synthetic game-owned resale that returns test inventory to game
stock, unlike Step 34's separate delivered counter. This proves generic transfer
atomicity, not a cargo-job lifecycle or agreed game pricing. The old menu ledger
remains in memory; none of its balances are silently migrated to this database.

Transport/database errors return an unknown-outcome response. The caller must
retry the same intent ID, never invent a fresh payment ID after a lost reply.
Full request/receipt retention is required through the later retry/archival policy;
this proof does not establish a production storage quota or safe pruning window.

## Fault and isolation checks

The harness exercises twelve simultaneous identical requests and eight competing
intents at one expected revision. It verifies one charge/receipt for duplicates
and one winner plus seven retained stale outcomes for competing intents.
Identical IDs on different authenticated actors have independent receipts.

It abruptly terminates the service after the first account write, after all
writes/receipt but before commit, and after commit but before the HTTP reply.
Each case also immediately stops and restarts the same PostgreSQL cluster,
checks committed-or-not state, retries twice, and verifies exactly one charge,
revision and receipt. A separate database crash occurs with an open partially
written transaction. Server logs must show WAL recovery. Database outage returns
a retryable result, and old success/failure receipts survive all restarts.

The role is denied access to a separate private schema. A private SQLite sentinel
file remains byte-identical. Total money/cargo is conserved and the committed
journal reconstructs every account balance and inventory. These are process-crash
proofs on this PC, not power-loss, disk-corruption, remote failover or backup tests.

## Reproduction and remaining gates

```powershell
./tools/CheckPublicStorage.ps1 -Python <absolute-python-3.12-path> -Install -Runtime editor
./tools/Godot.ps1 -Mode Export -Configuration Release
./tools/CheckPublicStorage.ps1 -Python <absolute-python-3.12-path> -Runtime release
```

Use `-Runtime none` for the service/database-only check. The separate storage
command is not added to ordinary Full checks because it creates disposable
database processes and requires the pinned external runtime. It closes its own
processes, removes transient service credential files and preserves database/log
evidence in the run folder. Generated databases are disposable, not game saves.
No player testing is required and no gameplay or water/ship behavior changes.

Step 35 still needs durable action recovery integrated with game state. Real
identity, fenced ownership, cross-server handoff, production scale, TLS, durable
job eligibility, schema migrations, backup/restore and operational deployment
remain their scheduled gates. Passing this experiment does not make Play online
or persist the current playable prototype.

Sources: [official Windows binary route](https://www.postgresql.org/download/windows/),
[EDB portable distribution](https://www.enterprisedb.com/download-postgresql-binaries),
[row-lock semantics](https://www.postgresql.org/docs/17/explicit-locking.html),
[commit durability](https://www.postgresql.org/docs/17/wal-async-commit.html).
