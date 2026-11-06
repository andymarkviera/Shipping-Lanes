# Oil market interface and lot accounting — Step 76

Task ID: `oil-market-interface-and-lot-accounting`. Builds on Step 75's durable
settlement without adding refinery processing or a purchasable oil hull.

## Player interface

`features/cargo/oil_market_panel.gd` is a transport-independent Godot panel. Its
trusted host supplies a request callable and current docking/port context. It
shows both authored ports while underway, each reference price's authority
observation timestamp (UTC), current wallet, the explicitly identified current
lot, custom positive whole-barrel quantity, exact quoted terms and last receipt.
Reference prices are indicative: quantity changes the executable unit price.

Request quote and Accept displayed quote are distinct actions. The quote shows
port, side, quantity, unit price, total, identity/version, issue and expiry times.
Changing selection invalidates it. A response for a changed selection is discarded.
Refreshing the price board does not overwrite a displayed quote or its captured
account revision. Acceptance submits that quote's ID/version/port/revision, never
requests another quote first. Only the authority decides settlement/expiry.

The countdown uses monotonic elapsed time and authority time, conservatively
including request latency. At expiry acceptance disables and requests explicit
review of new terms. An authoritative expiry/stale-revision rejection never
retries with a new quote. Loss of docking prevents new quote/accept requests.
An uncertain acceptance retains its complete original action/quote/revision;
new trades and refreshes are blocked until explicit retry resolves the outcome.
Receipt replay remains valid after quote expiry or berth loss and never adds the
amount to a local wallet. UI uses the next canonical snapshot instead.

The panel supports keyboard focus and scrolling. Opening it suppresses helm
input while the world continues; closing it restores the existing input-release
guard. Visibility, animation and local clock changes never settle a trade.
Rendered readability, scaling, real sailing/docking and Andy's acceptance remain
separate visual gates.

## Lot policy and receipt

Retain D130/D132: one unsold purchased lot at a time, explicitly selected for a
partial sale, rather than silently changing to FIFO or average-cost accounting.
For original acquisition cost `C`, original barrels `Q`, cumulative sold barrels
`S` and previously allocated cost `A`:

- cumulative allocated cost = `floor(C * S / Q)`;
- this sale's cost = cumulative allocated cost minus `A`;
- remaining cost = `C` minus cumulative allocated cost;
- realized trade profit = gross proceeds minus this sale's cost.

All arithmetic is integer minor credits. Whole-barrel unit prices currently make
allocation exact; the cumulative rule also defines fractional allocation without
fragmentation gains (cost 10 over 3 barrels allocates 3, 3, 4). Acquisition cost is
paid once at purchase, never debited again on sale. Recovery-debt repayment is
shown separately from trading profit and wallet change.

The receipt shows accepted quantity/unit price/gross, allocated acquisition cost,
realized profit, debt repayment, wallet delta, remaining barrels and cost. The
lot retains original acquisition quote/port/cost and cumulative sales. Final sale
removes the aboard lot but retains its durable receipt with zero remaining cost.
Snapshot adds account-scoped `lots`, `money`, `revision`, `last_receipt` and
`server_time`; each market port adds `observed_at`. Receipt fields are additive;
older receipts remain readable by deriving costs from their existing lot fields.
No stored market/profile schema, old receipt, save, ID, protocol or UID is rewritten.

PostgreSQL and private SQLite retrieve only the calling account's latest oil
receipt. Both still commit wallet, cargo, market and receipt atomically. Timestamp
changes describe observations, not changed prices or new authority.

## Runnable private sailing fixture

The operator-only `tools/oil_market_fixture.py` launches the actual oil port scene
against Step 75's private SQLite adapter. It requires Python 3 and exact Godot 4.7.2.
The placeholder oil ship reuses existing starter visuals/handling and two copied
berths with oil eligibility; existing ships/ports are untouched. It is separate
from normal/friends menus and public credentials are never passed to the panel.

```sh
python3 tools/oil_market_fixture.py --godot /path/to/godot-4.7.2 \
  --db /path/to/new-isolated-oil.sqlite --create
# Later launches: same command without --create. Existing files are never reset.
```

The launcher binds only loopback, requires an ephemeral bearer credential passed
to its child process, accepts bounded requests and stops its own service on exit.
The local Godot scene is the trusted private host and attests its docking context;
this bridge must never be exposed as a public player RPC. Its server-side account
and realm are fixed, not player-selectable. Missing/invalid files fail closed.
No local public pricing fallback is provided.

This fixture persists the market, wallet, lots and receipts through the Step 75
adapter. It does **not** migrate the Step 73 fixed-price save or container/bulk/gas
saves. Sailing pose/fuel are test-scene state and restart at the fixture spawn;
loaded lots still belong to the same canonical oil ship. This is not full oil
voyage/sinking/scene-handoff persistence. Public Godot oil peer routing, playable
fleet acquisition and full cargo-family integration remain unimplemented gates.

## Lifecycle

| Event | Behavior |
| --- | --- |
| Underway | Price inspection works; new quotes/acceptance require docking at the selected port. |
| Partial/final sale | Atomic cost allocation, wallet and receipt; remainder persists or final lot empties. |
| Close panel / focus loss | No trade, refund or cancellation; existing input guards apply; quote time continues. |
| Berth loss | New acceptance blocked; only an already committed receipt may replay without docking. |
| Backend outage / lost reply | No replacement price or action; retain pending intent for explicit retry. |
| Quit / crash / restart | Last committed inventory/receipt restored by snapshot; no auto-accept or auto-reset. Pending UI quote is discarded. |
| Ship switch / resale / transfer | Not exposed by the fixture; existing public cargo/fleet guards remain. No player transfers. |
| Sinking / public handoff | Existing Step 75 canonical cargo rules remain; new Godot oil integration is not claimed. |
| History / content mismatch | Preserve incompatible storage and fail; do not reset or import another realm. |

## Checks

```sh
python3 -m unittest services.oil_market.test_model services.oil_market.test_settlement services.oil_market.test_interface -v
python3 tools/oil_market_fixture.py --godot /path/to/godot-4.7.2 \
  --db /path/to/new-probe.sqlite --create --probe
python3 tools/check_oil_market.py --postgres-bin /path/to/postgresql/bin --work /path/to/scratch
```

Use isolated XDG/APPDATA folders for checks. The scene probe invokes the real
panel/HTTP/SQLite path and actual docking authority. It injects a lost reply only
after real settlement, checks identical retry, rejects expired/changed selections,
and reconciles partial/final cost and receipts. PostgreSQL runner also verifies
account-specific restored display fields after actual service/database restarts.
See PROGRESS.md for executed evidence and remaining gates.
