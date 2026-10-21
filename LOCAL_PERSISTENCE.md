# Step 36 — Versioned local persistence

Task ID: `versioned-local-persistence`. Completed October 21, 2026 for the
starter private development world. This is local saving, not online account saves.

Step 37 now upgrades this original world schema 1 to schema 2. See
SAVE_MIGRATION.md for the current compatibility/upgrade behavior; the original
Step 36 schema description below is retained as migration reference.

## Player-facing behavior

Play now opens the same private local save instead of resetting test money on
each click. The existing menu purchase commits through the durable economy.
Boat Handling Test, entered from the main menu, restores the starter ship's
position, heading and fuel. It saves every ten seconds, on Escape back to the
menu, and on a normal window close. A restored ship starts stationary and neutral
so returning to the game cannot immediately drive it into an obstacle. Camera
focus is reset to the restored ship. Ship handling itself is unchanged.

The save is under `user://worlds/private_development/world.db`, with a separate
`world.backup.db` made using SQLite's online backup API. `user://` resolves within
Godot's current application data directory; diagnostic harnesses set a separate
APPDATA so they never open a player's save. Settings remain in their existing
separate preferences store. No source/Library files contain player progression.

The handling diagnostic scene launched directly without the menu's explicit save
flag remains disposable, so existing automated handling tests do not modify the
default world. Heavy-lifter and local-network test scenes remain independent
fixtures; persistent physical heavy cargo and authenticated multiplayer identity
are not added here. The current menu's test cargo quantity is retained in the
economy; the handling cargo-preview button is still a visual preview.

## Schema and authority

`LocalWorldSave` owns the private world checkpoint and an explicitly bound
SessionAuthority/DurableEconomy. Economic schema/rules version 1 remains unchanged;
the added `world_meta.version=1` identifies this first world checkpoint schema.
Each plain JSON checkpoint contains version, monotonic generation, realm,
player ID, owned ship ID, owner ID, definition ID, inventory ID, integer fuel in
milliliters, and the validated geographic location record. IDs are stable within
the private realm, not Godot instance IDs. The initial cargo ledger is empty.

The starter uses the selected geographic contract/world revision and the proved
100 km-radius chart mapping, with the handling course at the synthetic origin.
The save stores geographic latitude/longitude/altitude/heading, reconstructing
the planar transform on load; scene vectors are not persistent world identity.
This prototype accepts positions within 100 km of that fixed chart origin.
Production streaming and final map scale remain later work. Restarted motion,
throttle, yaw rate and thruster orders are explicitly reset, not serialized.
Fuel rounds down once at checkpoint precision (less than one ml); physics still
uses continuous liters and does not round each simulation tick.

Wallet and cargo quantities always come from the current committed economy
snapshot/receipts. They are deliberately not copied from an older ship checkpoint.
Thus recovering an older transform/fuel checkpoint cannot rewind a newer purchase.
All money/cargo side effects remain game-owned; no peer transfers are introduced.

In local play, the local authority writes. In a player-hosted session, the host
must be the sole checkpoint owner; clients never supply arbitrary saved balances
or write the host database. Generation checks refuse a stale second writer.
The current network fixture is not yet bound to this save; guest identity and
server fencing remain scheduled gates. Official online accounts use the separate
central PostgreSQL architecture, never import this local database.

## Atomic writes and recovery

An immediate SQLite transaction writes a new current checkpoint, retains the
previous validated checkpoint, and advances the generation together. Each record
has a SHA-256 checksum and strict shape, identity, content, fuel and geographic
validation. SQLite WAL/FULL supplies atomic database commit; this intentionally
replaces the roadmap's generic temporary-file/rename recipe. Live SQLite files
are never copied or replaced as ordinary files. The separate backup uses the
native transactional backup API after a successful checkpoint.

A kill before commit keeps the previous generation. A kill after commit keeps
the entire new record even if no confirmation appeared. A malformed current
checkpoint falls back to the validated prior checkpoint in the same database,
reports recovery, and retains the latest economic ledger. A successful subsequent
save repairs the spatial checkpoint from the known-good state.

If neither checkpoint validates, the world schema/content is unsupported, the
realm differs, or the main DB is missing while a backup exists, opening stops
without inventing a fresh wallet. The playable ship is frozen on failed load and
shows the recovery message. Failed saves retain prior progress and report the
problem; normal departure is blocked when an attempted save fails. No destructive
reset button or automatic overwrite is added. An unreadable entire database is
not automatically replaced by a potentially older full backup: that could rewind
committed payments. Explicit backup recovery UI/policy belongs to Step 38.

The current external backup is the last successful checkpoint backup; a later
economic transaction can be newer than it. Process-crash recovery uses the live
database WAL and retained receipt ledger, not a blind rollback to that file.
Full machine power loss, disk-full UX, corruption repair and cloud backup are not
claimed. The existing 1,024-outcome economy bound remains until retention scales.

## Verification

79 completed-phase assertions and two forced process terminations pass in editor
and Windows Release. The seven-phase harness covers fresh-process transform,
fuel, identity, owner, wallet/empty and nonempty inventory restoration; pre/post
commit interruption; preserved payment receipts during malformed spatial fallback;
stale-host writes; backup restore; unsupported schema/no-valid-checkpoint refusal;
and missing-main protection. It also runs the real Play purchase and handling
scene save/restore paths in isolated APPDATA. Existing session, clock, application
flow and Step 35 recovery checks pass; compilation covers 84 scripts. Unchanged
physics/network suites were not rerun. Full now offers 29 stages.

```powershell
./tools/Godot.ps1 -Mode PersistenceCheck
./tools/Godot.ps1 -Mode Export -Configuration Release
./tools/CheckPersistence.ps1 -Runtime Release
```

Accepted evidence:
- `output/persistence-checks/Editor-439a81dac8ea4cac9ab200c9138e7ee5`
- `output/persistence-checks/Release-be3cec507291425d966324e0f358c49d`

Next: Step 37 adds an actual migration and explicit missing-content fixtures.
Step 38 adds save slots and the recovery interface. Diagnostic timers, complete
fleet/physical cargo lifecycle and official online saves retain their later scope.
