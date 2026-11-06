# Oil market simulation — Step 74

Step 75 now supplies the durable service described in
[SHARED_PUBLIC_OIL_MARKET.md](SHARED_PUBLIC_OIL_MARKET.md). The scope and evidence
below describe the original Step 74 model milestone.

Task ID: `oil-market-simulation`. `services/oil_market/model.py` is the pure
Python authority model for the existing Python service boundary. It has no feed,
real-money, account, database, Godot export or third-party package dependency.
Run its contract tests from the repository root:

```sh
python3 -m unittest services.oil_market.test_model -v
```

## Authority contract and scope

Create one `Market('public', config)` in the authority simulation. Every public
server view binds to that **same owner**, independent of server ID; port IDs alone
select local market state. `PublicView()` without an owner returns
`MARKET_UNAVAILABLE`, never creates a local market. It rejects a private owner.
A private host creates `Market('private:<host>', config)`; each instance has a
unique identity, separate pressure, versions and issued quotes, even when host
labels match. Public/private quotes cannot cross this boundary.

These are in-process contract fixtures, not a deployed shared market service.
Step 75 must supply the single durable centralized owner and transport for actual
public server processes. Do not create one public model per game server. No runtime
public oil route is enabled here. Cross-process consistency, restart durability,
account authorization and atomic inventory/wallet/market settlement are **not**
claimed by the thread-safe fixture. No Step 75 adapter, schema, RPC, retry ledger or
account settlement is implemented.

`record_simulated_trade(quote, now)` consumes an issued quote and updates market
pressure only. It is a trusted simulation API, not a player transaction endpoint
or evidence that any inventory was bought/sold. Public views expose only snapshot
and quote requests. Step 75 must place the validated market transition in the same
durable boundary as account settlement, preserve replay receipts, and fail closed
on outage. It must never call this method and then separately attempt payment.

Step 73's fixed-price version-1 SQLite inventory remains unchanged; its replay
codec reconstructs historical prices from constants. Wiring variable prices into
that history without a deliberate schema/settlement adapter would break old saves.
Private Godot inventory wiring also awaits that adapter through the same contract.
The oil UI/lot presentation is Step 76. No playable oil feature is implied here.

## Configurable integer rules

`Config` is frozen and copies its port mapping. Reject invalid integers (including
booleans/floats), empty/oversized port maps and inverted price bounds. Defaults are
provisional tuning values, not production balance:

| Parameter | Default |
| --- | --- |
| Update cadence / quote lifetime | 60 / 20 seconds |
| Base / minimum / maximum minor credits per barrel | 150 / 25 / 500 |
| Brindle Quay / Slatewater Works offset | -25 / +25 |
| Signed pressure limit | 10,000 barrels per port |
| Recovery toward neutral | 100 barrels per tick |
| Maximum supply / quantity price effect | 40 / 10 minor credits |
| Maximum trade / outstanding quotes | 200 barrels / 4,096 |

A captain buying adds pressure; selling subtracts it. Clamp pressure symmetrically
to the configured limit. At each cadence boundary, pressure decays toward zero
without overshoot. Catch-up uses elapsed ticks in constant time, so sparse requests
and regular polling produce the same state. Trades change pressure immediately;
cadence governs recovery. No randomness or client frame rate enters pricing.

Supply effect is `sign(pressure) * floor(abs(pressure) * effect / limit)`.
Quantity effect is `floor(barrels * volume_effect / max_trade_barrels)`; add it
for buys and subtract it for sells. Clamp base + port offset + supply + signed
quantity effect to the configured price bounds. Total is integer unit price times
whole barrels. The snapshot reference price excludes quantity effect; executable
quotes include it. This spread discourages immediate round-trip volume effects,
but these provisional values are not a full economy/exploit balance acceptance.

Time is nondecreasing integer authority seconds, never a client timestamp. A
market starts at a supplied epoch; cadence boundaries are epoch-aligned. Each
elapsed tick and accepted simulation trade increments the ordered model version.
Snapshot dictionaries are copies; callers cannot change authority state.

## Quote lifecycle

Quotes freeze market identity, version, port, side, quantity, unit/total price,
issue time and expiry. The owner retains a bounded issued-quote set; altered or
unknown quotes fail `UNKNOWN_OR_CHANGED_QUOTE`. Identical serialized terms are
accepted as the same issued quote, so a future adapter must bind authenticated
account/intent; this model does not implement account security. UUIDs identify
instances/quotes, never drive prices or represent economic credentials.

A valid quote keeps its price through intervening ticks/trades. Acceptance is
valid only while `now < expires_at`; equality or later returns `QUOTE_EXPIRED`
with no trade pressure change. Request a fresh quote explicitly; never silently
reprice. Expired entries are pruned and quote admission fails `QUOTE_LIMIT` at the
configured bound. An accepted quote is removed; repeat consumption fails without
another effect. Historical durable retry success is Step 75, not this behavior.

Clock advancement may perform scheduled recovery even when accepting an expired
quote fails; that is elapsed simulation time, not a trade effect. An invalid or
backward clock fails before any advancement. Cargo offers and active jobs remain
nonexpiring; only executable oil price quotes expire.

## Acceptance evidence boundary

Unit coverage compares two public views of one owner, port differences, ordered
threaded updates, independent private hosts, cross-market rejection, unavailable
public authority, bounds, cadence catch-up, exact expiry, frozen terms, changed
quotes, repeated consumption, copied data and invalid inputs. These tests are not
two networked public servers, a PostgreSQL concurrency test or a live deployment.
See PROGRESS.md for actual Linux checks and unrun platform gates.
