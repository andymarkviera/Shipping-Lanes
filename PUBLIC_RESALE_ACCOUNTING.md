# Step 66 — Resale and voyage accounting

Task ID: `resale-and-voyage-accounting`. D123. Online game-shop resale and
cash-basis voyage reporting. Step 67 tuning and measured gates are recorded in
ECONOMY_GATE.md; deferred requests remain separate. Godot 4.7.2, ticket protocol 7, game protocol **17** (new resale RPC).
Deploy matching client/server/backend builds together; no live deployment here.

## Resale policy

Use Fleet / Compare's left selection, Review sale, then Confirm sale. Cancel sale
review or close without committing. Confirmation binds to a short-lived server
valuation quote, not a client price or recipient. Cargo offers remain nonexpiring.

- Sell only an owned stored ship at the current service port. Activate another
  ship through Step 65 before selling a formerly active ship. Never sell the active
  or last ship, automatically switch hulls, or spawn a replacement during a sale.
- Refuse all profile cargo and unfinished jobs (including loading and unknown job
  states), plus any nested cargo/jobs on the target. No implicit cancellation,
  transfer, forfeiture or deletion of manifests. Completed job history keeps IDs.
- Require a live docked owner, service berth, no pending checkpoint/service/damage
  or recovery. Keep the supported active hull afloat and with either at least 1 L
  fuel or enough post-sale money to buy 1 L at the existing fuel price. No grants.
- Stored damage is allowed and lowers value; zero/invalid condition is unavailable.
  Fuel has no resale value. Never change condition, fuel or fractional wear for free.
- `resale_values.json` configures per-definition basis points, provisionally 6000
  (60%). Floor once: `min(actual acquisition cost, current catalog price) × rate ×
  condition_bp / 100000000`. Rates outside 0–10000 fail closed. New purchases retain
  actual acquisition cost; legacy records without it use current catalog price,
  without rewriting saves or inventing historical costs. Prices remain provisional.
- Existing recovery debt repayment applies: half of positive sale proceeds, bounded
  by the debt (existing one-minor-unit minimum). The review and durable receipt show
  gross value, repayment and actual wallet credit. The treasury must cover the gross.

The trusted server consumes the quote before I/O, checkpoints live pose/fuel/wear,
then uses the existing lease/profile revision lock and atomic PostgreSQL transaction
for profile removal, wallet/treasury movement, receipt and journal. A replay returns
the original receipt; a changed intent under the same action ID fails. An uncertain
result fences authority without an automatic new sale. Canonical refresh restores
fleet, wallet and last receipt. No player-to-player economic path is introduced.

## Voyage report contract

A cash window begins at container-job acceptance and closes on delivery, cancellation,
abandonment or sinking. The profile holds the current report and most recent closed
report; action receipts preserve reports at each settlement. No new save version.
An existing active legacy voyage begins a **partial** window at its first successful
economic operation; costs before that boundary are explicitly unavailable.

| Report field | Meaning |
| --- | --- |
| Gross revenue | Full job payout before debt repayment; also includes legacy fixture cargo delivery if used during the window. |
| Acquisition cost | Actual ship/cargo purchases debited during the window. Current container contracts themselves have zero cargo acquisition charge. |
| Fuel / repair | Actual paid propulsion-fuel and condition-repair debits during the window. |
| Recovery paid / debt repaid | Cash recovery fee at sinking, and withheld debt repayments, shown separately. Unpaid debt remains in the existing debt balance, not a fictional cash debit. |
| Other cash | Other authoritative cash changes within the window; resale normally cannot occur until the job closes. |
| Net cash | Gross − acquisition − fuel − repair − recovery paid − debt repaid + other cash. Equals ending wallet minus starting wallet. |

This is cash reporting, not accrual profit: prepaid fuel, prior ship purchases,
remaining fuel inventory and future repairs are not allocated or amortized. The UI
states the acceptance-to-close boundary and exclusions. Reports never label gross
revenue as profit. Every successful economic path participates once, within its
receipt transaction; rejected/replayed operations add nothing. Reconciliation
failure aborts rather than publishing an inconsistent report. Checkpoints and fleet
storage preserve the additive fields; no client can submit accounting values.

## Verification and remaining gates

`tools/public_handoff/test_resale_accounting.py` exercises production transitions
and receipt dispatch using an explicit in-memory SQL adapter; it is not PostgreSQL
atomicity proof. `tools/resale_probe.gd` exercises actual quote/service/panel code
with an authority double. See PROGRESS.md for actual Linux results.

Before release run Windows pinned-engine checks and Debug/Release client/server
exports with JSON inclusion/UID/save compatibility; real PostgreSQL HTTPS concurrent
sales and deliveries, replay, restart and process termination before/after commit;
Keycloak/native login and authenticated two-account ownership/privacy, interrupted
sale/rebind/reconnect; rendered sale review/cancel, report scrolling/readability,
focus/scaling and Andy's loaded/empty/damaged/fuel-poor account playtest. Use isolated
fixtures, never reset live accounts or deploy this branch merely to run a test.
