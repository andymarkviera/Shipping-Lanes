# Save and protocol contracts — Step 11

October 19, 2026. Version 1 is a validated draft of plain records, not a gameplay
save implementation, live network protocol, authorization layer or final SQL schema.
Representative fixtures are under features/contracts/fixtures. Never load a save
as a Resource, PackedScene, script, object-enabled Variant or executable content.

## Envelope and identity

Each record has schema_version=1, protocol_version=1, kind, id, revision, realm_id
and data. Unknown fields are rejected. Versions are independently checked. IDs
are lowercase identifiers (letter then up to 63 letters/digits/underscores), not
scene paths, display names, network peer IDs or filesystem paths. Production
identity-provider IDs must map to internal IDs; this draft does not parse tokens.
The authoritative store allocates instance IDs unique within a realm and kind.
Definition IDs refer to the trusted registry; missing/wrong-type definitions fail.
Revision is a monotonic optimistic-concurrency number, never a local frame count.
Private realm IDs cannot be imported into the public economy. realm_id is a claim
requiring authority checks, not proof of membership or permission.

| Kind | Required data | Optional/default |
| --- | --- | --- |
| player | account_id, wallet_minor, debt_minor | None; missing balances fail |
| ship | owner_id, definition_id, fuel_ml, inventory_id, location | name defaults to empty string |
| job | owner_id, cargo_id, quantity, unit, origin_port_id, destination_port_id, status, expires_world_ms | None |
| inventory | owner_id, lines of cargo_id/quantity/unit | Empty lines are valid; duplicate cargo IDs fail |
| operation | actor_id, action, payload_sha256, expected_revision, status, result_code, committed_world_ms | None |
| world | content_world_id, content_revision, clock_ms, clock_policy, authority | None |

Examples are synthetic, not starting balances/fuel or a valid gameplay voyage.
The job reuses the one fixture port; schema acceptance does not authorize a job.
The only operation action is test_transfer, reserving the receipt structure
without inventing production transaction handlers. Job and operation enums are
explicit allowlists. Only ship name is optional; null is never a default request.

## Units and numeric bounds

All stored quantities, money, revisions and clock milliseconds are integral and
bounded 0..9,000,000,000,000, below JSON's exact integer range. Quantities are >0.
Booleans, numeric strings, fractions, negative values and excess bounds fail.
JSON numbers may parse as floating variants; validation verifies integrality
before future adapters cast them to int. Every arithmetic operation must check
its result for overflow before commit; this step does not implement arithmetic.

Money uses integer minor credits: 100 minor credits per displayed credit. Debt
is a separate nonnegative field, never an implicit negative wallet. Propulsion
fuel uses integer milliliters; container amounts use count. Future bulk/liquid
records use grams/milliliters with catalog-defined units. Current test containers
must use count in both inventory and job. Future cargo definitions require a
schema/content extension and validation before those units become operational.
Conversions and rounding belong to Step 12 and the authoritative family actions;
never silently round incoming saved quantities. Prices/capacities remain open.

Location reuses GEOGRAPHIC_CONTRACT.md: scalar degrees, altitude meters and an
explicit meridian tangent frame, world/content revision. The fixture world ID
is not the final world identity. It is not a durable scene transform. This step
also closes a geographic decoder edge case: boolean revision is rejected.

## Clock semantics

clock_ms is authoritative elapsed world simulation milliseconds, not machine UTC,
client time or OS tick count. The only implemented fixture policy is
active_session_only: a private world stops when its host stops, while local pause
menus do not stop a hosted session. No offline catch-up is implied. Step 14 must
implement and test the chosen global policy; shared public refinery/market clocks
require authoritative backend time and their own documented policy.

expires_world_ms=0 means no expiry; otherwise expiry occurs at world clock >=
expiry. committed_world_ms records authoritative completion (zero is legal at
world start); pending/rejected operations have zero and no committed outcome.
Monotonic local clocks are for transient timeouts only and are never restored
across processes. UTC audit timestamps, future lease expiry and public backend
clock semantics remain distinct fields when their protocols are implemented.

## Authority, retries and protocol boundary

Validated records are not accepted client state writes. Clients send commands;
server authority checks identity, realm membership, ownership, current lease epoch,
expected revisions, legal state transitions, content compatibility, quantities and
funds. Only then does one transaction update records and store its receipt.
Cross-record references (player/ship/inventory/job existence and ownership),
uniqueness and graph consistency must be verified within that authoritative
transaction. This validator checks individual shapes and trusted definition IDs.

The durable operation identity is (realm, actor, operation ID). Its SHA-256 field
represents canonical semantic request bytes. Canonical key order/number encoding
must be pinned and tested with the actual operation implementation; never hash raw
JSON formatting or an unverified client hash. Mutable server instance, lease epoch
and connection nonce belong to an authenticated transport envelope, outside the
semantic fingerprint. Authenticate/fence before lookup. Same key/same fingerprint
returns the original receipt; different fingerprint rejects. These are contracts,
not implemented replay handling. Retain receipts/tombstones until the retry window
and archival policy are explicitly proven before Step 35; no pruning is authorized.

Protocol v1 peers must agree before dispatch. Unknown versions fail closed; no
silent downgrade. Snapshot records never substitute for server command validation.
The offline fixture loader uses Godot JSON syntax/duplicate-key behavior; it is not
a canonical cryptographic JSON parser. A network transport must pin one decoder,
reject ambiguous encodings before hashing and apply packet/rate limits separately.

## Serialization and migration policy

RecordContract.decode accepts text only, caps UTF-8 size at 64 KiB and nesting at
16 before parsing, then validates exact fields, types, versions, ranges and IDs.
Inventory arrays cap at 128 lines; display text caps at 128 characters with no
control characters. Failure returns errors and an empty record, with no state
mutation, file access or content loading from input. Path-looking name text is
inert. Registry resources are trusted project content, not supplied by saves.

Version changes require an explicit deterministic N-to-N+1 migration, fixtures
for success/failure and a database-aware backup. Validate old input, migrate a
copy or use one SQLite transaction, validate the entire resulting graph, then
commit data and schema revision atomically. Never partially overwrite a save.
Future versions remain untouched and report incompatible version. Missing content
must halt restoration with IDs reported; never silently delete ships/cargo or
substitute starter content. Renamed IDs require a reviewed migration mapping.
No migrations are implemented yet: only v1 is accepted. Storage proof tested
transactional SQL migration mechanics, not gameplay migration correctness.

Checkpoint slots, checksum/backup selection, corruption recovery, autosave timing
and UI recovery are still Steps 35–38. Ordinary saves must preserve committed
resource operations and receipts; movement checkpoint frequency cannot roll back
already accepted economic outcomes. No actual disk save/loading is added here.

## Verification

66 checks pass in editor and Windows Release: all six representative records and
round trips, null required fields, numeric bounds/types, versions, unknown fields,
missing IDs, duplicate lines, unit mismatch, inconsistent receipts, invalid JSON,
oversize/deep inputs, inert path text and rejected resource syntax. Geographic
342-check suite also passes after the revision-type fix. Native release startup
passes. Run:

```powershell
./tools/Godot.ps1 -Mode ContractsCheck
./tools/Godot.ps1 -Mode RunExport -Configuration Release -Headless -ContractsProbe
```

No manual playtest is required; no visible gameplay has changed.

## Public adapter follow-up — October 21, 2026

PUBLIC_STORAGE_PROOF.md now proves the resource/receipt atomicity boundary in
real PostgreSQL through a separate synthetic service. Its strict decoder,
canonical request hash, ordered locks, retained success/failure receipts and
process-crash/retry behavior are implemented in tools/public_storage. The SQL is
a disposable test schema, not a production migration of the records above.
Real account admission, lease fencing, durable family actions and game save
integration remain later work. Private records still cannot enter the public
namespace. Player-to-player trading is excluded by D064.
