# Cargo fuel transport and sale — Step 79

Task ID: `cargo-fuel-transport-and-sale`. Builds on Step 78 shared refinery custody.
The shared transaction model now supports cargo-fuel loading and sale in PostgreSQL
and private SQLite. The playable Godot interface remains an explicit private fixture,
not a new public hull or public game RPC. Engine 4.7.2 and game/ticket protocols 17/7
remain unchanged. Prototype prices/capacity are not final balance.

## Flow and arithmetic

Choose Crude oil market or Refined cargo fuel in the commodity menu. Buy crude at
Brindle, dock at Slatewater and submit it for processing. Refresh after processing,
review and accept a withdrawal quote, then load a positive integer millibarrel
quantity from the oldest waiting collection. Sail back to Brindle and sell all or
part of the aboard lot. The panel shows stock, capacity, aboard quantity, frozen sale
price, withdrawal fee, and sale gross/debt repayment/wallet change.

- `ship_oil_prototype_01` has 200000 millibarrels cargo capacity. One aboard lot;
  crude/other cargo or an active job blocks loading. Unsupported hulls cannot load/sell.
- `refinery_load` consumes only owned, ship-bound Step 78 collection quantity.
  Partial loading leaves the remainder at Slatewater. Loading itself costs zero:
  Step 78's withdrawal already charged the quoted handling fee.
- A load creates a canonical `cargo_fuel` acquisition record with refinery,
  collection, origin, ship, quantity, allocated handling fee and frozen sale price.
  Crude production cost remains in the processing ledger, not mislabeled as a
  handling cost or incorrectly displayed as net profit.
- `refinery_sell` takes only that ship's aboard cargo fuel at Brindle's pipeline.
  Prototype price is 220 minor credits/barrel. Gross is the difference between
  cumulative integer floors before/after the sale; handling cost uses the same
  cumulative allocation. Splitting a lot's sales cannot create rounding profit.
- Existing recovery debt policy applies to positive proceeds. The receipt separates
  gross, debt repayment and actual wallet credit. A final sale removes the aboard lot.
- Neither operation reads, consumes, fills or otherwise changes propulsion fuel.
  The service preserves the entire ship record. Game propulsion continues normally
  while sailing; selling cargo fuel does not act as a refueling service.

Example with a 130-credit/barrel crude quote: 20000 wallet, buy 100 barrels for
13000, refine 100000 millibarrels to 70000, pay 70 handling, sell for 15400. Final
wallet is **22330**, a **2330** increase. Actual market quotes can differ; the Godot
voyage checks its accepted purchase and saved post-fee balance rather than assuming
a particular current oil price.

## Authority and persistence

Both operations enter Step 78's fenced account/refinery/treasury transaction.
They validate request shape, revision, recovery state, port, ownership, capacity
and quantity. Receipt lookup precedes those mutable conditions so the identical
request can recover its committed result after berth loss or handoff. Changed
intent under an old action ID conflicts. Stock custody, profile, money, receipt and
public journal commit together. No public/private fallback or import path exists.

Collections keep a cumulative loaded quantity and terminal loaded status. Existing
Step 78 rows with no loaded quantity mean zero loaded; no reset/migration is needed.
Validate status/quantity conservation and aboard-lot accounting before mutation.
At most 10000 cargo-fuel actions are retained per refinery. Exhaustion rejects new
work (including further sales) rather than deleting exactly-once identities; replay
still works. This is a bounded prototype, not production long-history retention.
Snapshots bound the visible waiting collection queue to 32; consuming its head
reveals later allocations. Deploy compatible service versions together; older
Step 78 code cannot operate on terminal loaded collection state.

The operator fixture saves private navigation each second and before a new refinery
operation. Restart restores the last durable position/yaw/fuel/condition in neutral,
stopped and undocked. Re-dock before trading. Navigation and economy have separate
durable boundaries: position may roll back to the last checkpoint after a crash,
but committed cargo/payment cannot. Failed resume disables the fixture controls.
No offline motion; private processing retains Step 78 active-time clock semantics.

## Lifecycle outcomes

| Event | Rule / boundary |
| --- | --- |
| Acquire / load / partial sale | Frozen withdrawal terms and ship-bound collection; atomic loading; cumulative sale rounding; durable receipts. |
| Close / pause / focus / berth loss | No implicit transaction or cancellation. Host processing continues. New mutations require dock attestation; exact replay may recover after berth loss. |
| Abandon / cancel | No refund after withdrawal or loading; partial uncollected quantity stays owned at the refinery. No new abandon button. |
| Switch / resale / despawn | Existing canonical cargo locks apply; fixture disables switching. Collection stays bound to the originally quoted ship. No gifts/transfers. |
| Quit / crash / restart | Atomic last committed cargo/wallet; partial quantities persist. Private fixture restores saved position in neutral and rebuilds menu state. Unknown in-session replies retain identical request for explicit retry. |
| Public handoff / scene unload | Stable refinery/account records and receipts survive. Actual SQL lease fencing/replay tested; public Godot hull and rendered handoff integration remain unimplemented. |
| Damage / recovery | Pending recovery or zero condition rejects new fuel mutations. Canonical recovery clears aboard cargo through existing recovery rules; collections remain at the refinery. Full public fuel-hull sinking voyage is still a gate. |
| Outage / concurrent requests | No half load/sale or duplicate payout; unavailable service does not seed local goods/prices. |
| Definition removal / corrupt state / restore | Unsupported hull and malformed records fail closed, retaining saved data. Production migration/backup/restore needs its own acceptance gate. |

## Reproduce checks

Use an isolated **new** database for the private fixture:

```sh
python tools/oil_market_fixture.py --godot /path/to/godot-4.7.2 \
  --db /scratch/fuel.sqlite --create --cargo-fuel
```

Omit `--create` to resume. Existing Step 77 `--refinery` and Step 79 `--cargo-fuel`
formats are deliberately separate; never point either at a live save.
For the two-process headless voyage add `--cargo-fuel-probe` on both launches. First
launch loads and checkpoints; second resumes and sells with a lost-reply retry.
The probe positions the fixture at berth/underway boundaries; it is not a manual
sailing or visual acceptance claim.

```sh
python -m unittest services.refinery.test_cargo_fuel services.refinery.test_shared
python tools/check_cargo_fuel.py --postgres-bin /isolated/pgsql/bin --work /scratch/sql
```

The SQL runner creates its own cluster, two HTTPS services and fixture identities.
It forces four owned service deaths around load/sale COMMIT, checks identical
replay, money, propulsion isolation, database outage/restart and account handoff.
See PROGRESS.md for the complete Linux results and remaining Windows, production
PostgreSQL, Keycloak/public-peer and visual gates.
