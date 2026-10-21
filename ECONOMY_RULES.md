# Step 34 — Money and transfer rules

Status: complete as an in-memory authority/atomicity proof — October 20, 2026.

## Confirmed scope

Andy excluded player-to-player economic transfers, gifts and trades. There is no
player recipient, player sale offer, donation endpoint, peer ship trade or peer
cargo handoff in this implementation. Steps 103–105 are not applicable; U037 is
resolved. Game-owned shops, service fees and earned payments remain required.
The source Library documents remain untouched; local scope records reflect the
new instruction.

## Authority and atomic updates

`EconomyLedger` owns the disposable fixture's player/system wallets, source,
player and delivered cargo quantities, revision, committed journal and receipts.
`SessionAuthority` routes the existing menu test purchase through it and derives
the wallet/inventory view from the ledger. Local and hosted test sessions use
the same path. Trusted session code supplies the actor; request fields cannot
choose another player or override ownership.

Fixed operations are `purchase_container`, `deliver_container` and `service_fee`.
The request contains exactly version 1, action_id, operation, quantity and
expected_revision. No client price, recipient or arbitrary debit/credit account
is accepted. A service request requires quantity 1 and moves no cargo. A purchase
moves source stock to the player while moving money to the system; delivery
moves player cargo to delivered stock while paying from the system.

Money uses bounded integer minor units and cargo uses whole container counts,
with the existing GameUnits limit of 9,000,000,000,000 per field. Float values,
fractions, negative/zero quantities, booleans, strings and nonfinite input are
rejected. Quantity-times-price is bounded before multiplication. Sufficient
funds/stock, destination capacity and revision capacity are checked before any
economic mutation. Overflow is checked on the receiving side before subtracting
from the sending side.

The authority prepares the entire next state, balanced journal entry and receipt
and publishes them by replacing one in-memory state reference. There are no
awaits, callbacks, signals or I/O inside the commit. Two intents based on the same
revision cannot both apply: after the first commits, the second is stale. This
proves serialized authority behavior, not database isolation across servers.

The fixture starts with player balance 20,000 minor units, system balance
1,000,000, stock 100 containers and player cargo zero. Purchase costs 10,000,
delivery pays 5,000 and service costs 1,000. These are test arithmetic values,
not approved production prices, starting balances, reward budgets or finite
public-market stock. Delivery here is a synthetic settlement test; real job
eligibility, docking, quotes, services and reward rates arrive in later steps.

## Receipts and failures

An exact repeated action returns its original outcome with `duplicate=true`.
The action ID with different valid contents returns `id_conflict`. Committed
receipts are never evicted. At the default 1,024-outcome bound, new requests fail
with `receipt_capacity`, while old receipts remain readable. Durable receipt
storage/retention policy must replace this fixture bound before production use.

Owned, schema-valid failures such as insufficient funds, insufficient stock,
stale revision or overflow retain their failure outcome. A later payout cannot
turn a retry of that failed intent into a charge; the caller must submit a new
action ID with the current revision. Failed actions leave wallets, inventories,
revision and committed journal unchanged; recording a rejection receipt is the
only internal change. Malformed/unowned/unsupported requests do not consume a
receipt. Actor ownership is checked before receipt access.

Results include code, action ID, original outcome revision, amount, quantity and
duplicate status. Views/audits/results are detached copies. The legacy menu
`request_test_load(revision)` wrapper retains its stale-revision UX; the explicit
`request_economy` path returns the original receipt for an exact retry. Neither
path can grant cargo or debit twice.

## Limits and verification

These records live only in memory. Continue retains the same session authority;
starting a new disposable test session resets it. Crash/restart recovery,
cross-server transactions, public/private persistence, quote validity and real
account authentication are not claimed. Next is the scheduled public-storage
adapter proof, then Step 35 durable action recovery. Step 33's temporary ship
action receipts are separate and are not used to protect money across crashes.

`tools/Godot.ps1 -Mode EconomyCheck` exercises successful purchases/delivery/fees,
balanced money and cargo movements, repeated success/failure, payload conflicts,
ownership, no peer/price override path, stale competing requests, funds/stock
failures, multiplication/receiver/revision overflow, exact zero/max limits,
receipt saturation, detached views and integration with SessionAuthority.
Release uses `-Mode RunExport -Configuration Release -EconomyProbe`.

82 economy assertions pass in editor and native Windows Release, as do the
21 session and 22 clock checks. Application flow, 79-script compilation, export
and normal startup pass. Full now includes EconomyCheck as stage 27; unrelated
physics/network suites were not rerun for this session-economy change.

The existing Play menu remains a disposable test fixture. The reported heavy
ship cargo pickup/sticking, neutral usability and water effects are unchanged.
