# Step 63 — Ship catalog and purchase

Task ID: `ship-catalog-and-purchase`. In authenticated online play, dock at
Brindle Quay or Slatewater Works, open **SHIP CATALOG**, select a ship, review its
preview and price, then confirm purchase. Cancel returns to review without charging.
Insufficient earned credits disable confirmation; the backend also checks funds.
Purchases enter storage, leaving the active ship, cargo and job unchanged.
Fleet inspection/comparison, activation/switching and resale remain Steps 64–66.
Local Port Test and private fixture economies are unchanged.

## Provisional catalog

| Shared definition | Earned-credit price | Preview |
| --- | ---: | --- |
| `ship_starter_container_01` | 500 | Familiar starter; six container slots |
| `ship_coastal_container_01` | 800 | Six slots; 20% lower full-output propulsion fuel consumption |
| `ship_swift_container_01` | 1,200 | Six slots; 20% stronger forward acceleration, higher fuel consumption |

All three use the existing small starter hull as placeholder art, a 1,000 L tank,
and new condition of 100%. Stored purchases have empty tanks. No free fuel,
new artwork, DWT claims or inferred extra cargo capacity. The two new definitions
retain independent tuning and stable IDs. Activating them online is intentionally
unavailable until Step 65 integrates spawning, handling, services and recovery.
Shared catalog preview/prices are in `services/public_authority/ship_catalog.json`;
Godot ship definitions are in `features/catalog/records`. Tests check preview names,
tanks and container capacity against those definitions. Both new resources and the
JSON are included in exports. Restart matching backend/server after changing prices.

Prices are provisional earned-money targets, not a new starter grant: the existing
200-credit fixture wallet cannot immediately buy. Existing 250/500/750-credit cargo
rewards can fund the first purchase. Step 67 tunes Coastal to 800 credits; see ECONOMY_GATE.md for
measured first-upgrade scenarios and the remaining Andy playtest gate. No real-money currency or player transfers are introduced.

## Identity and transaction rules

The existing active `profile.ship` remains unchanged. An absent `stored_ships` field
means no stored purchases; a successful purchase adds an owned record to that array.
It contains a new ID, shared definition reference, single condition, fractional wear,
empty propulsion tank and storage port. Definitions never hold mutable ownership.
No migration/reset or replacement of existing ship IDs is needed. Storage is bounded
to 100 ships to keep canonical profile payloads bounded; full storage rejects without
charging. Only the stored count, not the entire fleet, is sent in voyage snapshots.

The server issues 30-second quotes bound to actual dock, wallet and catalog terms.
Both port and berth must advertise the service. Loading, recovery, overlapping saves
and lost authority block purchase. A client sends only its peer ownership binding,
sequence and quote token. It cannot choose account, recipient, price or owned ID.
Changing selection/quote or cancelling clears confirmation. These service quotes do
not change the nonexpiring cargo-offer policy.

Acceptance consumes the quote before any await, holds the voyage mutation lock,
checkpoints live pose/fuel/single-condition wear, then calls `ship_purchase` against
the saved revision. Backend validation recomputes price and eligibility. Under the
existing lease/profile locks, wallet debit, treasury credit, owned record, receipt
and journal entry commit atomically. Owned UUIDs derive from account plus the unique
purchase action ID; two deliberate purchases use different action IDs and therefore
different owned IDs. Duplicate requests return the original durable receipt; changed
intent under the same ID is rejected. Even failed receipts are final.

The Godot quote cannot be consumed twice, even with a fresh transport sequence.
Backend receipt replay survives later mutations and server restart. Unknown outcomes
fence ownership and require canonical reconnect; no automatic new purchase retry.
The new RPC requires game protocol **15** (was 14); ticket protocol remains **7**.
Godot remains **4.7.2**. Update client, game server and backend together.

## Checks and remaining gates

Portable commands, with exact Godot 4.7.2 and isolated XDG/user data:

```sh
python -m unittest discover -s tools/public_handoff -p 'test_*.py' -v
Godot-4.7.2 --headless --path . --script res://tools/ship_purchase_probe.gd
Godot-4.7.2 --headless --path . --script res://tools/repair_probe.gd
```

Python requires the existing `psycopg` backend dependency. The purchase tests exercise
production transition and receipt dispatch through an explicitly in-memory SQL
adapter. Godot tests exercise the real service and panel with an authority double.
They are not evidence of real PostgreSQL concurrency or authenticated peer traffic.
See PROGRESS.md for actual Linux results and limits.

`python tools/public_handoff/ship_purchase_probe.py` is the committed, syntax-checked
**pending** Windows fixture-stack gate: real HTTPS/PostgreSQL concurrent duplicate
requests, distinct purchases, changed intent, stale ownership/revision, exact journal
debits, restart and process death after profile write / before commit / after commit.
The existing fixture setup requires Windows PostgreSQL binaries and process flags;
no PostgreSQL/Keycloak stack is configured in this Linux session.

Also pending: Windows engine/export checks, matching authenticated clients with
Keycloak/native login, disconnect/reconnect/interruption acceptance, rendered catalog
layout/readability and Andy's playtest. Specifically verify confirmation/cancel,
insufficient funds, two separate stored IDs, one debit on double click, and retained
IDs/wallet after restart. No deployment or completed production acceptance is claimed.
