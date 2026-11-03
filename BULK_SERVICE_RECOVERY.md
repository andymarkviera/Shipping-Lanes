# Step 70 — Bulk service presentation and recovery

Task ID: `bulk-service-presentation-and-recovery`. Implements Step 70 only; D127.

The developer menu's **BULK PORT TEST** opens a separate private voyage using the
existing starter hull presentation/handling with Step 68's two bulk holds. This
is explicitly a prototype fixture, not a newly purchasable public ship. Its two
local ports have copied bulk-compatible berth definitions; existing container and
heavy-loader ports, saves and hulls are unchanged. Friends-client navigation still
excludes development fixtures. No gas or Step 71 content is introduced.

Dock using the existing docking authority, then choose grain, coal, ore or limestone
and the forward (400 t) or aft (600 t) hold. Each choice selects a finite, authored,
nonexpiring 123.456789 t quote. Only one job may be active. Quotes show every frozen
rate/modifier and distinguish gross earnings from fuel/repair/recovery costs.
These fixture quotes use the two ports' direct 1,500 m separation, not sailed
odometer distance. There is no implicit hold splitting or player transfer.

Loading and partial unloading both reserve/start/progress/commit through the existing
`cargo_operation.gd`. The authority uses a provisional five-second service duration.
Loading commits the full accepted batch. Destination unloading accepts positive
integer grams and uses Step 69's cumulative rounding/receipt semantics. The sample
50 t discharge pays 40.09 credits; finishing the 73.456789 t remainder brings the
total to the original 98.99-credit grain quote. Hold allocation and acquisition
origin remain in the batch/job, and receipts retain all quote inputs.

The panel emits intent only. Its decorative crane is drawn from committed progress
samples; rendering, panel visibility, repeated refresh and visual completion never
advance the authority clock or grant cargo/payment. The panel scrolls at smaller
window sizes. Service controls suppress helm input while visible without stopping
the world clock. Motion/layout/accessibility still require a rendered playtest.

## Persistence boundary

`bulk_service.gd` stages each operation in a fresh, validated candidate. The existing
SQLite voyage store saves the entire candidate in one FULL-synchronous WAL transaction
with revision compare-and-swap. Only after COMMIT does the service publish the new
manifest, wallet, receipts and operation state. A failed or unknown commit fences
the fixture; reopen to recover the canonical checkpoint. No public/local fallback.

The store now accepts an optional validator/reconciler; its default container/heavy
codec, schema version, reconciliation and save path are unchanged. Bulk has a new
private realm `private_bulk_voyage_v1`, snapshot version 1, at
`user://worlds/private_bulk_voyage/voyage.db`. This does not migrate or reset an
existing player save. No real save was used in testing.

Snapshots contain frozen offer seeds, an ordered bounded history, manifest, wallet,
shared operation records, sequence, port/docked state, pose, fuel and single condition.
Loading/discharge history references stable operation IDs. Restore replays the
history into isolated objects and checks every resulting manifest, wallet and
terminal operation before publishing it. It reconstructs settlement receipts and
rejects mismatched quantities, holds, quote totals, histories or unsupported content.
Object-free binary encoding retains integer grams and money. Bounds are 64 offers,
4,096 events/operations, the existing money limit and 4 MB encoded checkpoints;
no receipt eviction or automatic destructive reset when a bound is reached.

## Lifecycle rules

| Event | Outcome |
| --- | --- |
| Accept/start | Freeze authored quote and explicit hold, reserve one shared operation; dock and capacity required. |
| Partial load | No physical cargo until the full loading operation commits. |
| Partial discharge | Commit remaining cargo, cumulative grams, receipt and wallet together; keep the job active. |
| Final discharge | Remove batch, close job; replay/repeated completion cannot award again. |
| Cancel/berth loss | Cancel only unfinished service. Release accepted loading; retain already loaded/partially discharged cargo and prior payment. |
| Hide panel/focus loss | Presentation only; authoritative local service continues. |
| Quit/crash/restart | Resume from last committed operation progress, with no offline time advance; restore sailing pose/fuel/condition in neutral. |
| Crash before COMMIT | Previous complete state remains; no cargo/payment half-state. |
| Crash after COMMIT/lost reply | Restore committed state and original receipts; repeated action has zero new reward. |
| Concurrent local writer/storage outage | Revision mismatch/failure fences the stale writer before publication; preserve database. |
| Ship switch/resale | No bulk fixture switching or public purchase/resale integration; existing fleet rules unchanged. |
| Sinking/public handoff/authenticated reconnect | Not introduced by this local fixture; public bulk authority integration is not implemented or claimed. |
| Unknown realm/content/corrupt save | Fail closed and preserve the file; no wipe or guessed migration. |

## Repeatable Linux/Windows-capable recovery probe

After import with pinned Godot 4.7.2:

```sh
python tools/check_bulk_service.py --godot /path/to/pinned/godot --work /path/to/scratch
```

The runner creates unique isolated XDG/APPDATA namespaces, checks the real panel and
scene, reopens partial voyages, and kills only its own children at before/after
SQLite COMMIT markers. It tests loading and unloading crashes and repeated final
reopen. Generated databases/logs remain outside the repository. This portable
runner has been executed on Linux only; it is not a claim of Windows validation.

Public bulk RPC, PostgreSQL wallet/checkpoint transactions, Keycloak reconnect and
native/exported client integration are absent, not silently substituted by these
private SQLite results. See PROGRESS.md for actual checks and unrun gates.
