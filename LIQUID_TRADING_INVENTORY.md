# Liquid trading inventory — Step 73

Task ID: `liquid-trading-inventory`. This is a private authority inventory and
transaction API, exercised by a runnable headless fixture. It does not add a
playable oil ship, trade UI, public endpoint or market simulation. Steps 74–76
remain separate: variable prices, centralized public market and player interface.

Oil uses positive whole **barrels**, a separate `oil_barrels` capacity pool and
`cargo_oil`. The data-only `ship_oil_prototype_01` has 200 barrels of capacity.
No existing hull gains capacity; DWT, gas m³, bulk grams and propulsion fuel are
unchanged. Existing catalog order, IDs, schemas and protocols are preserved.

## Fixed pair and intent contract

`features/cargo/liquid_inventory.gd` accepts `transact(request, authority_port,
docked)` only after `open` succeeds. It is a private authority API, not an RPC.
A future scene adapter must supply its own authoritative location/docking state;
never forward a client-reported location or use this fixture as a public fallback.

The fixed version-1 fixture starts with 20,000 minor credits. Brindle Quay sells
oil to the captain for 125 minor credits/barrel; Slatewater Works buys it for
175 minor credits/barrel. These are provisional fixture prices, not live market
quotes. No expiry, random price, update cadence, shared stock or external feed.

Intent has exactly seven fields: `id`, `kind` (`buy`/`sell`), `lot`, `barrels`,
`owner`, `ship`, `port`. Owner and ship must match the private fixture constants.
IDs are nonempty bounded strings; barrel quantities must be positive integers,
never floats, strings, booleans or silently clamped amounts. Purchase rejects the
whole request if either available cash or capacity is insufficient. Finish the
single unsold lot before buying another; historical lot IDs cannot be reused.
No new cargo jobs/offers are minted, and existing one-job policies are unchanged.

A buy stores the acquisition action ID, owner/ship, origin, original/remaining
barrels, unit and total acquisition cost. A sell names that lot explicitly.
The receipt records sold quantity, cost basis, proceeds, profit and resulting
wallet. Both request inputs and returned snapshots/receipts are deep copies.

## Atomicity and accounting

Each request is evaluated on an isolated candidate. The existing SQLite voyage
store commits wallet, manifest, lots, history and receipts in one checkpoint before
publishing success. There is no process-local success mode for trading. Revision
compare-and-swap fences stale writers. Exact durable action replay returns the
original receipt and **zero** new wallet delta; altered intent under that action
ID fails. Retrying after final sale cannot recreate the lot or repay the captain.

Whole-barrel fixed unit costs permit exact partial allocation without rounding:
`sold cost = barrels sold × lot.unit_cost_minor`; realized profit is sale proceeds
minus that cost. Acquisition cost is charged only at purchase, never again on sale.
For 123 barrels: buy cost 15,375; sell 50 for 8,750 with cost basis 6,250 and profit
2,500; sell remaining 73 for 12,775 with cost basis 9,125 and profit 3,650. Total
profit is 6,150 and final wallet 26,150 minor credits. Splitting sales cannot change
these totals. Remaining cost is original cost minus cumulative sold cost.

A separate `private_liquid_inventory_v1` realm uses the existing store's optional
codec hooks. Validation reconstructs bounded history (maximum 4,096 actions) and
compares every derived manifest/lot/wallet/receipt. It rejects inconsistent saves
without modifying live state. History is never evicted to make action IDs reusable.
Prices are version-1 constants: changing them requires explicit compatibility work.

## Lifecycle boundary

| Event | Current rule |
| --- | --- |
| Buy/sell | Instant atomic inventory transaction while docked at its fixed port. No unfinished transfer or reservation. |
| Partial sale | Explicit lot and whole barrels; original acquisition and prior receipts retained. |
| Cancel/abandon/berth loss | No pending operation to cancel/refund. Undocked new requests fail; committed goods remain. |
| Menu/pause/focus/offline time | No clock or UI callback affects inventory or prices. |
| Quit/crash/restart | Reopen last durable checkpoint. Before COMMIT rolls back; after COMMIT retains full trade. Lost reply replays with zero delta. |
| Backend outage/stale writer | Fail and fence until a fresh instance reopens. No half payment, local public fallback or automatic reset. |
| Ship switch/resale/sinking/recovery | Not wired to this isolated inventory fixture; no gameplay adapter may drop or transfer the lot implicitly. Integration remains a later cargo-family gate. |
| Handoff/scenery/player transfer | No public handoff or scene binding here. No trades, gifts or transfers between players. |
| Content removal/corruption/history limit | Reject incompatible state or new action and preserve the file; no automatic migration/reset. Backup rollback needs explicit reconciliation before production integration. |

Godot stays 4.7.2; game/ticket protocols stay 17/7. Single condition, no machinery
wear, no hidden shallows and nonexpiring jobs remain unchanged.

## Reproduce the portable recovery proof

Use exact Godot 4.7.2 and the existing matching SQLite extension:

```sh
python3 tools/check_liquid_inventory.py --godot /path/to/godot-4.7.2 --work /outside/repo/checks
```

The runner creates isolated data directories, tests validation/accounting/stale
writers, then kills only its own children before/after both buy and sell commits.
It verifies rollback, committed recovery, partial/final accounting and repeated
reopen/replay. See PROGRESS.md for actual results and remaining platform gates.
