# Gas delivery and persistence — Step 72

Task `gas-delivery-and-persistence`; decision D129. Builds on D128 and
[GAS_CAPACITY.md](GAS_CAPACITY.md). Step 73 is not implemented.

The developer menu's **GAS PORT TEST** opens a separate private voyage fixture.
It uses the starter presentation/handling with the authored gas hull's 400 m³ LNG
and two 600 m³ industrial tanks. The two fixture berths explicitly receive gas
pipelines. Existing playable/public ships and terminals gain no gas capability.
Friends-client navigation still excludes developer fixtures.

Gas reuses `bulk_earnings.gd`, `bulk_service.gd`, `bulk_service_panel.gd`, the existing
shared timed operation engine and SQLite voyage store. Trusted construction selects
`gas`; existing bulk callers default to their original units, IDs and save realm.
There is no separate gas market, purchase cost, oil price, propulsion-fuel conversion,
public gas RPC or PostgreSQL gas wallet. These private results do not establish
public authenticated gas play.

## Quote, origin and partial quantities

Finite, nonexpiring offers cover both directions and every compatible commodity/tank
pair (14 offers). LNG uses `pipe_lng`; nitrogen, oxygen and argon use
`pipe_industrial`. The panel selects commodity/tank and shows the required pipeline,
frozen gross quote, rate, both modifiers, origin/destination, remaining m³ and receipt.
Unsupported pairs have no selectable quote. Neither pipeline nor money comes from
UI input. Authority checks `GasRules.transfer_error` and manifest/job eligibility
at admission and completion; changed/removed live pipeline permission interrupts
unfinished service without granting cargo or payment.

Quantities remain positive integer **cubic meters**, minimum **1 m³**, maximum
1,000,000,000 per batch; fractions and coercible non-integer inputs are rejected.
One accepted batch loads in full after five seconds of authority time. Unloading
accepts any positive whole-m³ quantity up to the remaining batch, also taking five
seconds (provisional fixture pacing, independent of quantity). There is no gradual
physical partial loading before commit. A pipeline progress drawing is read-only;
panel refresh, hiding it or visually reaching 100% cannot settle an operation.

Frozen terms use shortest geographic endpoint separation rounded once to meters,
rate R in **minor credits/m³/NM**, and explicit origin O / destination T basis points:

```
earned_minor(Q) = floor(Q * direct_distance_m * R * O * T / 185200000000)
partial_payment = earned_minor(cumulative_m³) - previously_paid_minor
```

1 NM = 1,852 m; 1 credit = 100 minor credits; 10,000 bp = 1.0. Rate bounds remain
1–1,000,000; each modifier is 0–20,000 (explicit zero is allowed). The shared exact
integer algorithm rejects quotes exceeding 9,000,000,000,000 minor credits. No
intermediate monetary rounding; final fractions of a minor credit are unpaid.
Detours, elapsed/offline time and later rate settings cannot increase an accepted
quote. Fuel, repairs and recovery are separate costs, not deductions from the quote.

Fixture quantities are 123 m³. Rates in minor credits/m³/NM: LNG 100, nitrogen 120,
oxygen 150, argon 80. Brindle's modifier is 11,000 bp; Slatewater's is 9,000 bp.
Direct separation is 1,500 m. The LNG example pays **98.62 credits** total:
50 m³ pays **40.09**, then 73 m³ pays **58.53**. Delivering those remaining 73 m³
one at a time gives exactly the same total. These are fixture rates, not a balance
claim or a gas resale price.

Batches preserve tank, commodity, original origin/destination, stable job/batch ID
and `gas_quote_<offer ID>` acquisition record. Receipts preserve acquisition/tank,
origin/destination, frozen quote terms, cumulative volume, cumulative payment and
operation ID. One active nonexpiring job persists until final delivery. Exact receipt
replay returns its historical receipt with **zero new reward**; changed intent,
wrong owner/ship/port, over-discharge, mismatched provenance and repeat final delivery
are rejected. No player receives another player's goods or money.

## Save and lifecycle rules

Gas uses snapshot version 1, realm `private_gas_voyage_v1`, at
`user://worlds/private_gas_voyage/voyage.db`. Existing bulk/container/heavy schemas,
IDs and save paths are unchanged; no migration, wipe or reset occurs. Object-free
snapshots atomically persist frozen seeds, ordered history, operations, manifest,
wallet, sequence, port/docking state, pose, fuel and the single condition value.
Restore reconstructs receipts by bounded replay and verifies resulting cargo,
wallet and operations before publication. Limits remain 64 offers, 4,096 events /
operations and 4 MB checkpoints. No receipt eviction or silent reset at a limit.

| Event | Rule |
| --- | --- |
| Accept/start | Dock, validate tank/pipeline/direction/capacity, freeze one job and reserve a timed operation. |
| Partial/final unload | Commit remaining volume, receipt and money together; final unload removes batch and closes job. |
| Cancel/berth or pipeline loss | Cancel unfinished loading and release its reservation; cancel unfinished unloading while retaining onboard remainder and prior receipts. |
| Abandon loaded cargo | Not offered by this fixture. Cancel stops the current service, not the loaded job; deliver its remainder. |
| Hide menu/focus loss | Presentation only; local authority continues. No panel-owned clock or settlement callback. |
| Quit/crash/restart | Resume last committed progress with no offline advance. Restore sailing pose/fuel/condition in neutral. |
| Before COMMIT crash | Previous complete state survives; no partial cargo/wallet transaction. |
| After COMMIT/lost reply | Recover committed result and original receipts; retries do not pay again. |
| Outage/stale concurrent writer | Fence the writer before publishing candidate state; preserve DB and reopen for canonical state. No public/local fallback. |
| Missing definitions/unsupported realm/corruption | Reject and preserve; no guessed migration or destructive reset. Changed terminal definitions can prevent reopening until compatible again. |
| Backup restore | Existing store validation/revision rules apply; never copy an old live DB over a running writer. Gas receipts and wallet remain one checkpoint. |
| Switch/despawn/resale | Fixture switching is disabled. Leaving checkpoints the same ship/job; no public fleet purchase/resale integration. |
| Collision/damage/sinking/recovery | Existing local handling and single condition remain. This fixture has no public sinking/recovery authority; no cargo-loss/refund/recovery economy is introduced or claimed. |
| Scenery transition/public handoff/reconnect | Local scene reopen restores the same private realm. Public gas handoff/authenticated reconnect and region streaming are not implemented by this fixture. |

No machinery wear, extra condition meter, hidden shallows, cargo expiry, or
player-to-player trade/transfer/gift is introduced. Godot remains 4.7.2, game
protocol 17 and ticket protocol 7. Deferred requests remain deferred.

## Repeatable checks

After import with pinned Godot 4.7.2:

```sh
python tools/check_bulk_service.py --family gas --godot /path/to/godot --work /path/to/scratch
python tools/check_bulk_service.py --family bulk --godot /path/to/godot --work /path/to/scratch
```

The portable runner creates isolated XDG/APPDATA/cache directories, tests actual
panel/scene reopen, and kills only its own children at four load/unload COMMIT
boundaries. The shared probe includes independent exact gas arithmetic vectors,
compatibility changes at admission/completion, fragments, corrupt records, stale
writers, provenance, wrong owner/ship/port and replay. See PROGRESS.md for actual
results and the separate Windows/PostgreSQL/Keycloak/visual/playtest gates.
