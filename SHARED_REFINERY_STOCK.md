# Shared refinery stock — Step 78

Task ID: `shared-refinery-stock`. The public authority now owns refinery processing,
stock and withdrawals across approved servers. Step 79's loading, transport and
sale remain unimplemented. No cargo-fuel withdrawal fills a propulsion tank.

## Ownership and persistence

All public authority replicas must use the same PostgreSQL profile database.
`public_authority.refineries` stores a versioned row under the stable physical ID
`refinery_slatewater_01` at `port_slatewater_works`. There is no server, session,
scene or region foreign key, and teardown/release never deletes refinery state.
The inventory is shared across servers, with account-owned balances within it;
one account cannot withdraw another's output. This preserves Step 77 ownership
and the no-player-transfers rule; it is not a player-funded communal giveaway.

Run the existing operator-only `Authority.initialize()` before starting upgraded
services. The additive migration is serialized with an advisory transaction lock.
Only first creation seeds the empty refinery; repeated initialization validates
and retains it. Missing rows in an existing table, incompatible state or malformed
ledgers fail closed. No private or historical save import/reset is provided.
Godot remains 4.7.2, game/ticket protocols 17/7 and existing UIDs are unchanged.

Public lock order is server, account lease, profile, refinery row, game treasury.
The facility row is selected `FOR UPDATE`; the existing account lock serializes
receipt IDs/revisions. Crude consumption, allocated crude cost, job, profile revision
and submission receipt commit together. Completion credits stock and fractional
carry with the terminal job status. Withdrawal consumes owned stock and its quote,
debits wallet, credits treasury, increments revision and creates a collection
record, receipt and journal entry in that same database transaction. No network
call or scenery callback sits between two economic commits.

The collection record has `status: awaiting_loading`. It is an irrevocable
withdrawal allocation still in refinery custody, not aboard cargo, a generic
inventory grant, a sale receipt or a player-transfer instrument. It has no loading,
sale, refund or consumption endpoint in Step 78. Step 79 must atomically consume
this durable allocation when integrating physical loading; receipt replay itself
must never create goods. Snapshots expose the latest account collection for
inspection; the complete bounded collection history remains in durable storage.

## Clocks, fractions and quotes

Keep Step 77's exact integer millibarrels, saved rational yield (default 7/10),
per-account remainder and single processing slot. Reserve the entire output at
submission; available stock plus reserved output cannot exceed configured capacity.
Retain submitted crude's allocated acquisition cost in the job. No submission fee.

Public processing uses an absolute completion deadline from PostgreSQL time read
**after the refinery lock**, with a durable high-water mark clamping clock rollback.
A subsequent successful snapshot/quote/transaction materializes a due completion
once. No two game-server ticks can add progress. Public downtime counts toward the
saved deadline, including downtime of all game servers or the database; a forward
clock adjustment can finish the already accepted job but cannot create another.
No automatic queue, cancellation, refund, or output from UI progress exists.
Operators must maintain the database clock. Completion remains observable on the
next successful request; there is no background worker requirement.

Withdrawal quotes bind account, current ship, facility/port, positive integer
millibarrels and a frozen handling cost. They do not reserve stock and do not
expire; acceptance rechecks stock, funds, revision and ship. Prototype fee is
**1 minor credit per barrel, rounded up once per withdrawal**:
`ceil(millibarrels * fee_minor_per_barrel / 1000)`. This is a proposed handling fee,
not a second crude purchase or a final balance target. Splitting withdrawals can
cost more, never less. Original crude acquisition costs remain in processing jobs;
Step 79 owns cargo-fuel cost-basis/transport settlement. Configuration is saved and
immutable through requests. There is no client price, yield, time or credit field.

Jobs, quotes and withdrawals retain bounded history (10,000 each by default).
At exhaustion new work fails without evicting deduplication identities. All credits,
carry and withdrawals are reconstructed during validation; corrupt stock cannot
silently become a new starting balance. This bounded prototype favors correctness;
it is not a throughput or unlimited-history claim. Future archival needs an
explicit migration preserving receipts and conservation.

## Server-facing requests

Use the existing verified HTTPS `/v1/authority`, approved server credential and
current account lease. Every request includes `realm`, `account`, `epoch`,
`generation`, `op`, `refinery_id`. The trusted game server attests docking at the
refinery port, as for existing oil services; player input must not select that
authority context. This step does not add public Godot RPCs or a playable oil hull.

| Operation | Additional fields | Behavior |
| --- | --- | --- |
| `refinery_snapshot` | none | Current owner/aggregate stock, last job/collection, config, revision and time |
| `refinery_submit` | `action_id`, `expected_revision`, `lot_id`, `input_millibarrels`, `port_id` | Consume owned canonical crude and reserve processing output |
| `refinery_quote` | `millibarrels`, `port_id` | Frozen nonexpiring cost; no reservation/debit |
| `refinery_withdraw` | `action_id`, `expected_revision`, `quote_id`, `port_id` | Atomically withdraw stock into a durable collection allocation |

`services/refinery/client.py` preserves TLS verification and returns
`REFINERY_UNAVAILABLE` on transport/backend failure; submission/withdrawal failures
carry `uncertain=true`. Retain the identical intent/action ID, reacquire valid lease
ownership if needed, and retry. Exact replay precedes current stock/revision checks
and returns the original receipt with `duplicate=true`; changing intent conflicts.
Epoch/generation authorize each call but are excluded from its economic fingerprint,
so reconnect/handoff can recover receipts. Old server/generation requests are fenced
before accessing refinery data. No local public fallback or private realm is accepted.

## Private hosts and verification

The existing Step 77 private UI/SQLite fixture stays unchanged. New private stock
fixtures can explicitly create `SharedPrivateStore(path, 'private:host-id')`; it
uses the same stock transaction model with isolated profiles/treasury/receipts and
rejects public realm construction. Only its trusted host calls `advance(ms)`;
private downtime remains paused. No client tick/import operation exists and there
is no automatic migration from Step 77's schema. This adapter is an operator/test
boundary, not a new player-facing menu or public routing path.

```sh
python -m unittest services.refinery.test_shared services.refinery.test_processing
python tools/check_shared_refinery.py --postgres-bin /path/to/postgres/bin --work /isolated/work
```

The SQL runner creates its own cluster, TLS certificates and fixture identities;
it never connects to a live database. It exercises two HTTPS replicas, two server
processes, private isolation, competing withdrawals, six forced service deaths,
restart/offline completion, database outage/restart and account handoff/fencing.
See PROGRESS.md for actual Linux results and remaining Windows, deployment,
Keycloak and rendered acceptance gates. SQLite contract tests alone are not proof
of PostgreSQL locking; the real SQL runner is the separate boundary test.
