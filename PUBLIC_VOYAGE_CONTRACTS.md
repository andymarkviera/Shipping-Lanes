# Step 57 integration — Durable public container contracts

October 25, 2026. First integration component complete; full first-voyage gate OPEN.

The authenticated server-to-authority HTTPS API now accepts voyage_accept,
voyage_load, voyage_deliver and voyage_cancel. Account, lease epoch/generation,
server credentials and expected revision fence every mutation. Request IDs bind
immutable intents; repeated requests return the committed receipt, changed intent
under the same ID is refused. All terminal outcomes, including known rejections,
are recorded. After a known LOADING_PENDING rejection, a later deliberate attempt
uses a new ID; an unknown outcome is reconciled with the original request/receipt.
Never blindly generate a new ID after a timeout.

Six versioned container offers mirror the local seed routes: 1–3 containers,
25,000 minor credits per container, 5 seconds loading per container. Requests choose
only an offer ID; they cannot supply quantities, payment or arbitrary profile data.
One active container contract per account; six-slot hold including other cargo.
Loaded/delivered job and cargo IDs remain stable across server handoff. Legacy
fixture delivery cannot consume contract cargo and bypass destination checks.

Jobs live in the existing canonical profile jobs array with kind
container_voyage_v1. Existing fixture jobs stay intact. Cargo uses the canonical
cargo array and linked job ID; account-scoped receipts and journal use existing
SQL tables. No schema reset/migration, no private progress import, no save slot
changes. Cancel pending loading releases the job; loaded abandonment requires an
explicit boolean confirmation and gives no reward. Delivered/abandoned seed offers
stay closed, matching the current local seed policy. Cancelled loading can be
accepted again. History is bounded at 1,000 contracts per account.

Loading readiness uses persisted database-clock timestamps. Offline time may make
the timer ready, but does not itself grant cargo: a trusted server must request
completion after verifying the actual ship is docked at the origin. Payment removes
the exact cargo batch, closes the job, debits game treasury and credits wallet in
one transaction. Receipt/journal commit in that same transaction.

## Required boundary before playable online use

The supplied port_id is an assertion from the authenticated game server. This
backend cannot inspect physical docking. No peer-facing voyage RPC was added.
Do not forward client port/ship/account eligibility blindly. Next integration must
resolve the peer's owned hull, physical berth, stopped state and berth reservation,
then construct these requests itself. The player UI must reconcile uncertain
outcomes and inspect current canonical state rather than applying an old receipt's
job snapshot after later operations. Godot authority adapter now fences voyage_*
mutations when locally inactive. World anchors, docking RPC, client service menu,
manifest replication and full two-peer cargo voyage remain unfinished.

## Verification

134-script/startup check and updated Windows Release export pass. Python modules
compile. `tools/public_handoff/voyage_probe.py` passes 99 checks through real HTTPS
and isolated PostgreSQL: separate accounts, duplicate/conflicting requests, early
loading, service restart, exact payout, wrong destination, legacy bypass refusal,
abandonment, loaded handoff and old-owner fencing. Six real authority process kills
cover loading and payout after profile write, before COMMIT and after COMMIT.
Each retry yields exactly one batch/payment. Evidence:
../output/handoff/775a0cc8/voyage-contract-summary.json.
Existing admission/core authority regression passes 41 checks:
../output/handoff/10aa0c9a/voyage-existing-authority-regression.json.
These are trusted-server contract tests, not two players physically using ports.

Recovery tag public-voyage-contracts; source backup:
../output/checkpoints/public-voyage-contracts-2026-10-25.zip.
