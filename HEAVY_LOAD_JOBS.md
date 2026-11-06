# Heavy-load jobs — Step 80

Task `heavy-load-jobs`. This is the durable private-world job authority, not the
Step 81 controls, Step 82 physical voyage integration or Step 83 presentation.
`services/heavy_load/private.py` uses the existing private SQLite profile/wallet
contract. The historical Port Test heavy-job implementation and its saves are
unchanged; they do not yet call this new authority. No public endpoint or playable
public lifter is enabled. Do not use this adapter as a fallback for public state.

## Definition and scope

One simple block, `payload_offshore_block_01`, 100000 kg, allowed lifter type
`ship_heavy_lifter_01`. Multiple instances of that type contend for the **same**
world payload. World identity is the saved `private:` realm; all host adapters
for that world must open the same database. Different private worlds intentionally
have separate payloads. Public globally shared offshore stock is not implied.

The immutable definition contains two stable offshore zone IDs, positions in the
fixture's local meter frame, 30 m radii and a fixed 70000 minor-credit gross reward.
Positions, mass and payout are prototype defaults for review, not accepted balance
or global geography. No offer expiry, randomized destination, claim TTL or respawn.
Both zones are reserved from acceptance until cancellation or delivery. Holding
both is deliberately conservative. Delivered payloads remain consumed permanently;
cancelled attempts retain their IDs but release the same payload for a new claim.

## Trusted host API

Explicit `HeavyStore(path, realm).initialize()` creates a **new** isolated world;
existing files are never overwritten or migrated. `provision()` is inherited
operator-only account enrollment. Never expose it as a player request. A profile
has the existing `ship`, `cargo`, `jobs`, `delivered` fields. The active ship must
be an owned, usable eligible lifter with no other active job or cargo.

`heavy(authenticated_account, intent, evidence=host_evidence)` accepts exactly:

- `op`: `claim`, `pickup`, `cancel`, or `deliver`;
- `realm`, `ship_id`, `payload_id`;
- `action_id`, `job_id`, `expected_revision`.

For claim, `job_id` equals the action ID. The returned job ID is an unambiguous
account-qualified JSON pair; retain it verbatim for later transitions. Every new
mutation needs a fresh action ID and current profile revision. Reusing an action
with changed intent returns `ID_CONFLICT`. Identical retries return the original
receipt even when revision or physical eligibility has since changed.

Pickup/delivery additionally require a **separate trusted-host argument** containing
job, ship, payload, zone and `validated: True`. This is an internal attestation,
not cryptographic proof and not client-authorized location. The future simulation
adapter must validate the actual payload/zone/alignment before calling it. Never
copy evidence supplied by an untrusted client. Step 81 owns control/alignment;
Step 82 owns physical attachment/release and their durable reconciliation. The
job authority does not implement those checks or claim a playable voyage.

`snapshot(account)` reads current terms, availability, own jobs, zone reservations,
wallet and revision in one read transaction. Reconnect uses this view; it never
adds receipt money to a client wallet or auto-accepts a prior available offer.

`BEGIN IMMEDIATE` serializes writers across connections/processes. Unique payload,
account, ship and zone constraints provide additional exclusivity. The job row,
canonical profile job, reservations, wallet/debt and exact-intent receipt commit
together. Delivery applies the existing half-gross recovery-debt repayment policy
before crediting the wallet. It never changes propulsion fuel or condition.
Unknown storage outcomes return `HEAVY_UNAVAILABLE` with `uncertain: True`: reopen
and retry the **same** request, never invent a replacement action. Definitions and
realm must match saved metadata. At 10000 retained actions, new mutations reject;
existing retries remain recoverable. No receipt pruning, live reset or migration.

## Lifecycle contract

| Event | Step 80 outcome |
| --- | --- |
| Acquire | Reserve payload and both zones; bind account/active ship; no fee. |
| Partial load | Indivisible block; no partial quantities or partial rewards. |
| Pickup | Host-validated transition to carrying; reservations retained. |
| Complete | Consume job/payload and credit net reward once; release zones. |
| Cancel/abandon | Pickup only: release reservations, no refund or reward. Carrying cancellation rejects. A stale cancellation cannot release a later claim. |
| Berth loss/menu close/pause/focus | No effect; jobs are offshore and nonexpiring. |
| Disconnect/quit/crash/reconnect | Retain the last committed claim/state/receipt; no timeout reassignment. |
| Switch/resale/despawn | Canonical active job remains a lock. No transfer to another ship. Physical despawn integration is Step 82, not implemented here. |
| Collision/sinking/recovery | No new policy mutates this ledger automatically. Keep claim quarantined until Step 82's explicit physical failure/recovery integration. No reward for destruction. |
| Scenery teardown | Persistent IDs/reservations outlive presentation; no scene-owned reward. Physical placement is still Step 82. |
| Public handoff | Unsupported; no public import/fallback. Private reconnect reopens the same world file. |
| Missing definitions/corrupt storage/world change | Fail closed; preserve the file for diagnosis. No silent reset. |
| Backup restoration | Operator must fence all prior writers; do not run divergent restored copies as one world. Production restore tooling remains a gate. |

## Reproduction

From repository root, with Python 3:

```sh
python -m unittest services.heavy_load.test_private -v
```

Tests create temporary private files, multiple lifter profiles and independent
connections; no live data. They cover 32 competing claims, 12 competing host
processes, zone contention,
32 delivery retries, cancellation/reclaim/stale requests, reconnect, frozen terms,
wrong ship/account/realm, payload/revision validation, debt and propulsion
preservation, rollback, bounded history, and eight owned subprocess exits before
and after claim/cancel/pickup/delivery commits. PROGRESS.md records the broader
Linux run and Windows/PostgreSQL/Keycloak/visual gates.
