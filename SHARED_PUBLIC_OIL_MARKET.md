# Shared public oil market service — Step 75

Task ID: `shared-public-oil-market-service`. The existing HTTPS public authority
now exposes `oil_snapshot`, `oil_quote` and `oil_accept` through `/v1/authority`.
The service owns time, prices, capacity, cargo and settlement. No feed, real money,
player transfers or local public-price fallback is introduced.

## Durable authority

Run the existing operator `Authority.initialize()` before starting an upgraded
service. Its additive migration creates `public_authority.oil_market` (one durable
public owner) and `oil_history` without changing account/schema version 1 or
existing saves. An advisory transaction lock serializes this migration. Repeated
initialization preserves the market identity; a missing singleton in an existing
table fails rather than reseeding. Initialization is not an HTTP operation.

Every public service replica uses the **same PostgreSQL database**, including the
existing profiles, leases, game treasury, receipts and journal. There is no remote
market call inside a separate wallet transaction. Lock order is server, account
lease, profile, market, then game treasury. The market row lock serializes different
accounts/servers. Account locks serialize receipts and revisions. Existing owner,
generation, phase and expiry fencing applies before dispatch and expiry is checked
again before commit. Lock/statement timeouts fail the transaction.

The Step 74 model is restored from a versioned JSON envelope per transaction.
Configuration, identity, pressure, time high-water, model version and bounded open
quote bindings survive restart. Database time is read after obtaining the market
lock, with rollback of the wall clock clamped to the saved high-water. Successful
snapshot/quote/accept operations append one contiguous durable sequence. Model
versions separately count cadence ticks and accepted pressure changes; intervening
updates do not reprice a frozen quote. Invalid operations roll back all changes.

Acceptance commits cargo, wallet, recovery-debt repayment, treasury, profile
revision, consumed quote, market state, history, receipt and journal together.
The existing account/action receipt key prevents duplicates across service crashes,
lost replies, disconnect/rebind and server handoff. Replay verifies the complete
intent (including quote ID/version, port and expected revision) before returning
the original receipt with `duplicate=true`. Epoch/generation may change on rebind;
they authorize the call but do not change its economic identity. Replays must not
apply the receipt amount again. Changed reuse returns `ID_CONFLICT`.

## Server-facing contract

All requests include `realm: public`, `account`, `epoch`, `generation`, and `op`.
They require an approved server credential and that account's current lease:

| Operation | Additional fields | Result |
| --- | --- | --- |
| `oil_snapshot` | none | Current ports, model version, market ID, durable sequence |
| `oil_quote` | `port_id`, `side` (`buy`/`sell`), positive whole `barrels`, `lot_id` (empty for buys) | Frozen terms, quote ID/version, issue/expiry time |
| `oil_accept` | `action_id`, `expected_revision`, `quote_id`, `quote_version`, `port_id` | Original accepted terms, lot, amount, revision, market version/sequence |

The trusted game server must attest current docking/service eligibility, as with
existing public dock services; player input must not choose the account, capacity
or settlement terms. Acceptance rechecks the bound account/ship, port, funds,
capacity, lot ownership and revision. Quote IDs alone confer no account authority.
Expiry is exclusive (`now >= expires_at` rejects); clients must explicitly request
new terms. A consumed quote cannot settle under another action ID. Pruning may
make an old, unconsumed quote unknown; neither expiry nor unknown quotes reprice.

`services/oil_market/client.py` supplies a verified-HTTPS public-server transport.
Timeout, connection loss, invalid response, or backend failure returns
`MARKET_UNAVAILABLE`, with `uncertain=true` for acceptance. Keep the original
intent and action ID, reacquire valid ownership if needed, then retry/inspect.
There is no automatic new quote, new action ID, cached executable price or local
market creation. Raw authority database errors remain HTTP 503
`BACKEND_UNAVAILABLE`; the market client maps that response to market unavailable.

Only the authored `ship_oil_prototype_01` has the 200-barrel service capacity.
Existing playable/public catalog ships gain no oil capacity. The prototype is
operator-fixture-only, not a new purchasable hull or player menu. Canonical oil
cargo retains acquisition terms, quantity, cumulative allocated cost and proceeds;
partial sales preserve Step 73's integer allocation rule. Cargo resides in the
existing manifest, so loaded-fleet restrictions and sinking removal still apply.
Generic fixture delivery cannot redeem an oil lot. No new Godot RPC, presentation,
Step 76 interface, or migration of the historical fixed-price private save codec
is included.

## Private hosts and packaging

`PrivateStore(path, 'private:<host>')` implements the identical transaction/request
contract in an explicitly provisioned isolated SQLite file. `BEGIN IMMEDIATE`
serializes writers, and profile, game balance, market, history and receipts share
one transaction. Host authentication binds the account argument. A new file gets
a distinct market identity even for the same host label; foreign quotes fail.
Missing files open with `mode=rw` and fail closed. Public realms are rejected.
Enrollment/provisioning remains trusted host administration, never client input.
This adapter does not import or modify Step 73's version-1 Godot fixture saves.

The Windows host builder includes `services/oil_market` alongside
`services/public_authority`. The new Python/SQL files are backend resources, not
Godot PCK resources; `export_presets.cfg` needs no new game resource entries.

## Repeatable checks

```sh
python -m unittest services.oil_market.test_model services.oil_market.test_settlement -v
python tools/check_oil_market.py --postgres-bin /path/to/postgresql/bin --work /path/to/scratch
```

The integration runner requires psycopg, cryptography, OpenSSL and PostgreSQL. It
creates its own UTF-8 cluster, certificate, two HTTPS authority processes, two
public-server worker processes and fixture accounts under a unique scratch folder.
It never accepts an existing database target. Only its owned services/cluster are
stopped. Generated keys/configuration/databases/logs must remain outside Git.

Coverage includes concurrent different-account trades and same-account acceptance,
ordered history, foreign quote rejection, stale fencing, disconnect/rebind/handoff,
crashes after profile write, market write, before commit and after commit, service
and database outages/restarts, atomic balance conservation and missing-state refusal.
See PROGRESS.md for actual Linux results and Windows, production PostgreSQL,
Keycloak, Godot peer integration and visual gates still unrun.
