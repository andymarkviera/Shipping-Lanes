# Step 33 — Action validation

Status: complete — October 20, 2026.

Step 39 keeps transient helm/test-pulse streams connection-scoped while reconnect
reclaims the same ship. Old sender requests fail ownership checks; durable economy
receipts remain separate and survive reconnect. Protocol is now 5. See
RECONNECT_LIFECYCLE.md; fresh-entity reconnect assumptions below are historical.

`ShipActions` is a fixed, session-scoped authority path for `helm` and the harmless
`test_pulse` action. The latter increments only an in-memory test counter. It is
not money, a cargo operation, a reward or a generic scripting dispatcher.

## Request/result contract

A request has exactly eight fields:

| Field | Meaning |
| --- | --- |
| version | Integer 1 |
| epoch | Current host-issued session epoch |
| player | Current controller peer ID, checked against the transport sender |
| entity | A live ship owned by that controller in the authoritative roster |
| kind | `helm` or `test_pulse` |
| sequence | Integer 1 through 2,147,483,647, increasing per entity/action kind |
| action_id | Exactly `kind:sequence`; prevents recycling an evicted ID with a new sequence |
| payload | Empty for pulse; throttle/rudder/lateral numbers and integer sent_ms for helm |

The wire sender is read from Godot's RPC context; a claimed player field never
overrides it. Finite controls, ship-specific throttle bounds and rudder/thruster
bounds are checked before committing intent. Extra/missing payload fields and
wrong types are rejected. String header lengths and receipt storage are bounded.

A result contains version, current epoch, action_id, code, ok, applied, duplicate
and value. `OK` means the intent was accepted, not that the boat has already
reached the requested speed. A duplicate successful request is `ok=true`,
`applied=false`, `duplicate=true` and returns the original value.

Error codes: `NOT_AUTHORITY`, `BAD_REQUEST`, `STALE_SESSION`, `NOT_OWNER`,
`UNKNOWN_ENTITY`, `UNKNOWN_ACTION`, `BAD_ACTION_ID`, `BAD_PAYLOAD`, `NONFINITE`,
`OUT_OF_RANGE`, `ID_CONFLICT`, `STALE_ACTION`, `RATE_LIMITED`.

## Retry and sequencing rules

Store up to 128 receipts per active ship, including a deep copy of the request
and its result. Check ownership before looking up a receipt. An exact retry
returns that receipt without applying any effect. Reusing a retained ID with
different valid contents returns `ID_CONFLICT`. Malformed or out-of-bounds
requests are rejected before entering the receipt store.

After receipt eviction, per-kind high-water sequence numbers remain. Older
actions return `STALE_ACTION`; they never run again. The receipt value is no
longer available after eviction, which is distinct from permission to reapply.
Canonical action IDs also prevent reuse of an old ID with a newer sequence.

Owned, structurally valid helm attempts consume their sequence even if the 10 ms
rate guard rejects them. The cached rejection remains a rejection on later retry;
a new intent needs a new sequence. Failed schema/ownership validation does not
advance sequence state. High sequence values from an invalid control cannot
starve subsequent legitimate controls.

Departure removes that temporary entity's receipts, high-water marks and test
counter. Returning guests receive a new entity, not authority over the departed
one. Session restart changes the epoch. Existing host receipts survive other
players joining/leaving. Public account identity and durable idempotency are
separate later gates; these in-memory receipts cannot protect economic effects
across a server crash.

## Integration and boundaries

The live `ShipReplication.accept_input` path constructs the same typed helm
request and delegates to ShipActions. Existing 20 Hz unreliable ordered helm
delivery retains its snapshot acknowledgement, 500 ms missing-input neutral,
host physics and interpolation. A retry does not refresh that timeout. The
explicit reliable request/result RPC supports discrete calls and diagnostics;
its results are emitted through a signal for callers. There is no extra reliable
reply for every streaming helm packet.

The local session protocol is now 4 so mismatched builds cannot silently join.
Cargo retains its existing Step 31 owner/sequence checks and loading rules; it
has not been converted into an economic receipt or repaired by this step.
The Step 32 capacity fixture uses its own experimental load protocol, so its
numbers must not be claimed as measurements of this receipt path at 100 players.
No production accounts, money changes, input retuning or new menu controls were
added. The recorded cargo pickup/sticking and neutral usability work is open.

## Verification

`tools/Godot.ps1 -Mode ActionCheck` starts two real local processes. It checks
typed errors, ownership and forged player claims, replay after discarded reply,
same-ID payload mismatch, cache eviction/recycled IDs, failed-command retry after
the rate interval, separate action sequences, stale session/entity rejection,
reconnect isolation and helm timeout. It also rejects malformed legacy ingress
without indexing missing fields.

Exported verification: `tools/CheckNetwork.ps1 -Runtime Release -Actions`.
Full project checks include ActionCheck as stage 26. The reliable lost-reply case
deliberately discards an already-received result and retries the same request;
it is not a claim of a network disconnect during a durable transaction.

49 action assertions pass in editor and Windows Release (22 host, 27 client;
11 results returned over the reliable wire). The full 26-stage / 77-script suite
passes, including normal/impaired motion and cargo, world transitions and the
capacity smoke check. Exported impaired movement and standard startup also pass.
