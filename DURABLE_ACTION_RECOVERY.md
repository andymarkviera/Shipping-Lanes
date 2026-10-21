# Step 35 — Durable action recovery

Task ID: `durable-action-recovery`. Complete for the bounded private authority
economy, October 21, 2026. Public transactional adapter prerequisite passed in
PUBLIC_STORAGE_PROOF.md; real public identity/leases remain later gates.

## What persists

`DurableEconomy` extends the existing game-owned `EconomyLedger` rules. A private
SQLite database contains a private realm/rules context, the minimal authoritative
money/inventory/revision snapshot, and ordered requests with their original
terminal outcomes. Replaying validated receipts rebuilds the balanced journal
and must exactly reproduce the snapshot before the authority becomes usable.
No object-enabled deserialization or scripts are loaded from the store.

`SessionAuthority.open_economy_recovery(path, private_realm)` explicitly binds the
existing purchase/delivery/fee flow to this store. Its view comes from recovered
authoritative balances. Failed recovery disables economic writes; it never
falls back to a fresh wallet. Private realm identity is checked before replay;
public realm names are rejected. This bounded version retains the existing
single synthetic player/ship IDs and test prices, not real account admission.

Default Play remains the disposable test session until Step 36 binds full world
save identity and startup/load policy. Ship position, fuel, timers, physical cargo,
network guest ownership and complete world state are not saved by this step.
The recovery probes exercise the same SessionAuthority purchase path, not a
separate arithmetic implementation. Hosted/local authority can use this adapter;
network reconnect and account handoff integration remain scheduled work.

## Atomic commit and failure policy

The pinned SQLite binding uses WAL and synchronous=FULL. `BEGIN IMMEDIATE`
serializes writers. Under that lock, each request reloads current committed
state/receipts, validates through EconomyLedger and prepares a candidate copy.
Snapshot and receipt are written in one transaction. Only after COMMIT succeeds
does the authority publish its candidate in memory or return success. A failure
cannot publish a partial wallet/cargo change. An exact retry returns the original
receipt; changed contents under the same ID return id_conflict. Ownership is
checked before receipt lookup. Two connections cannot charge using stale cached
balances: the second loads the committed revision while holding its write lock.

Opening creates a schema only for a truly empty, version-zero database. Unknown
versions, wrong realms, receipt gaps, altered results or snapshot/replay mismatch
fail closed without resetting records. SQL/commit failures return a storage error;
uncertain outcomes must be reconciled after reopening, using the same request ID.
There is no fallback to in-memory success or a replacement empty database.

Diagnostic callbacks mark snapshot-written, receipt-written/pre-commit, and
post-commit/pre-reply boundaries. Only trusted test code can install them; they
are not request fields or a gameplay option. The harness kills only its own child.

## Retention, retry and compatibility

- Retain every committed or valid rejected receipt for the lifetime of this
  private economy. No time-based expiry, eviction or pruning is allowed.
- The inherited prototype bound is 1,024 outcomes. At capacity, new intents are
  refused without effects; retained IDs remain retryable. Production retention,
  indexed lookup and archival must replace bounded full-log replay before scale.
- The caller retains the exact operation ID and semantic payload until a terminal
  response is known. On timeout/disconnect/storage uncertainty, resend that intent.
  Never generate a new payment ID to resolve an unknown outcome. A new intentional
  purchase uses a new ID/current revision; a known failed intent remains failed.
- The existing `request_test_load(revision)` convenience wrapper retains its stale
  revision UI behavior. Explicit retry/reconciliation uses `request_economy` with
  the original request. Pending UI/outbox and full startup restore belong to the
  subsequent save/operation integrations; this step does not promise auto-resubmit.
- Schema 1 / rules 1 pins the original test seed, prices and arithmetic. Changes
  require an explicit migration or retained old-rule reader, never silently
  replaying old receipts under newly balanced prices. Existing DBs are preserved
  on incompatibility. Do not overwrite money with an older movement checkpoint.

Request JSON is canonical authority-written text, limited to 2,048 characters;
restoration validates integer bounds/types, schema, ID, sequence and results.
SQLite reads at most 1,025 receipts to detect over-capacity stores. Integrity
checks detect inconsistency, not malicious editing by a private host who owns
the file. Public/private economies remain isolated.

## Verification

`tools/Godot.ps1 -Mode RecoveryCheck` runs eight fresh-process phases. It forcibly
terminates around three boundaries: after snapshot write, before commit with
receipt written, and after commit before the reply. Restart proves all-or-none
resources/receipts and exactly-once retry effects. It also checks fresh session
restoration, retained failures, cross-connection stale requests, changed payloads,
ownership, realm separation and refusal of four damaged/incompatible copies.
Copies use the SQLite backup API; live database files are not copied arbitrarily.

107 assertions in completed phases plus three verified forced-termination
boundaries pass in both editor and Windows Release. Evidence:

- `output/recovery-checks/Editor-f2997bc9467c49eaa7aecde066ac773c`
- `output/recovery-checks/Release-657fb85dcf3f45aaabde414b639f32e8`

82-script compilation, 21 session checks, 82 economy checks, 22 clock checks,
application flow, Release export and startup pass. Release economy also passes.
Unchanged network/physics suites were not rerun. Full now includes RecoveryCheck
as stage 28. Exported recovery command:

```powershell
./tools/CheckRecovery.ps1 -Runtime Release
```

This proves process-crash recovery, not power-loss hardware durability, disk-full
recovery UX, complete save backups or remote database failover. Step 36 implements
versioned full local persistence; Steps 37–38 address later save/recovery behavior.
No manual playtest is required for this step.
