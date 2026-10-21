# Step 37 — Migration and missing content

Completed October 21, 2026 for the private starter world. This extends the local
save foundation; it does not enable public accounts or internet servers.

## Upgrade contract

World schema 2 makes the implicit starter cargo definition and stationary/neutral
restart policy explicit: `cargo_definition_id` and `restart_policy=neutral_v1`.
Economic schema and rules remain version 1. The upgrade preserves stored pose,
integer fuel, ownership, wallet, cargo quantities, and all successful/failed
payment receipts. A retry of an old payment still returns its retained outcome.

Before upgrading a version 1 world, SQLite's native backup API writes `pre1.db`.
The source is rechecked under an immediate transaction. Both checkpoint records
and the header change in one commit. The current generation advances once to
invalidate an already-open version 1 spatial writer; the previous checkpoint's
generation stays unchanged. Reopening version 2 does not migrate again. An
interruption before commit leaves the complete old version; after commit it leaves
the complete new version. No economic table is rewritten by migration.

The backup is a point-in-time pre-upgrade copy, not an automatic economy rollback.
A concurrent economic transaction can occur between backup and the migration lock;
the upgrade always reads the current locked source. Restoring an entire backup
needs the explicit recovery policy/UI in Step 38. Public account storage remains
separate, and authenticated single-server authority remains a later gate.

## Compatibility behavior

Loaded ship IDs must resolve to a ShipDefinition with an available runtime scene.
Cargo IDs must resolve to a CargoDefinition. Only the implemented starter/cargo
pair is supported in this local world. Missing IDs, known but unsupported hulls or
cargo, incompatible map revisions, and newer checkpoint/header versions stop load
with a compatible-content/build message. They do not silently select another ship,
reset the wallet, award cargo, or fall back past a missing-content condition.
Play shows the reason in the existing menu notice and starts no replacement
session. Restoring compatible content allows another load attempt.

Migration requires two valid version 1 checkpoints; damaged old checkpoints need
recovery before upgrade. Ordinary version 2 malformed-spatial fallback retains the
Step 36 behavior and never rewinds the latest economic ledger. Preferences stay
in their separate file and remain byte-identical through upgrade/failure tests.

## Verification

Run `tools/Godot.ps1 -Mode MigrationCheck` or, after export,
`tools/CheckMigration.ps1 -Runtime Release`. Each run uses isolated APPDATA and a
literal version 1 fixture independent of the current record builder. It never
opens the player's save. Eight process phases provide 190 completed-phase checks
and three forced process terminations: after the first checkpoint write, after
both records/header but before commit, and immediately after commit.

Checks cover rollback/reopen, exact stored position/fuel, ownership, economic
fingerprints and old receipt retries, idempotent reopening, pre-upgrade backup,
missing ship/cargo/catalog entries, future versions, incompatible old saves, and
the actual menu's visible failure path with all progress preserved. Position is
compared against the serialized legacy fixture, avoiding a false mismatch between
an in-memory double and its original JSON representation.

Accepted evidence under `../output/`:

- `migration-checks/Editor-a24ed6a98102417d9260d659631cb467`
- `migration-checks/Release-5072eda280e74aa698b42bdc2486d400`

The existing 79-check/two-crash persistence suite also passes in both runtimes.
All 85 GDScripts compile; application flow, Release export and normal startup pass.
Full now offers 30 stages. Unchanged motion/network tests were not rerun; no new
network performance or online-readiness claim follows from these save checks.
