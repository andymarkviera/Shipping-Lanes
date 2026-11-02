# Step 62 — Paid online repairs

Dock at Brindle Quay or Slatewater Works and open **REPAIR**. The quote shows
current condition, percentage restored and total earned-credit cost. Accepting it
restores D115's single boat condition to 10,000 basis points (100%). Damage and
active-use wear share this meter. There is no component maintenance, machinery
wear, player transfer or free online repair. Local Port Test keeps its free fixture.

## Price and quote rules

`services/public_authority/repair_costs.json` maps ship definition IDs to the minor
credit cost of restoring 100 percentage points. Both the trusted Godot server and
Python backend read this same file; it is explicitly included in the game export.
The starter's provisional full-scale price is 25,000 minor credits (250 credits).
Only the starter currently supports online play. Adding a price does not enable
another ship online. Restart backend and server after changing prices.

Charge `ceil(missing_basis_points * full_scale_price_minor / 10000)`, using integer
arithmetic and rounding the total once. Example: 75.55% → 100% restores 24.45%
and costs 61.13 credits. Full condition cannot be purchased; a sunk ship must use
paid recovery. Successful full repair also clears fractional wear. Full condition
with only a fractional wear remainder needs no paid repair yet.

Quotes last 30 seconds and bind to the peer's actual dock, definition, projected
condition including unsettled wear, fractional wear, operating time, wallet and
price. Both port and berth must advertise repair. Loading, recovery, authority
loss and overlapping mutations block repair. The client sends only the quote ID
and existing ownership/sequence binding; it cannot select a port, price, account,
condition delta or recipient. Changed/expired/consumed quotes require review again.

## Authority and persistence

Acceptance consumes the quote before I/O and holds the existing voyage lock,
blocking undocking and competing checkpoints/economic commands. It checkpoints
live fuel, pose and unsettled simulated wear before buying against that revision.
The backend independently recomputes the price and condition, rejecting mismatched
accepted terms rather than charging a changed amount. The existing lease/revision,
receipt fingerprint, profile, treasury and journal transaction commits the repair
and debit together. No database schema or profile reset is required. The canonical
condition is installed into the hull/HUD only after the backend refresh.

Unknown outcomes retain existing authority fencing. No timeout, UI refresh or
reconnect automatically purchases again. Reconnect loads canonical state. Receipt
replay with the same intent returns the original result; changed intent is rejected.
This implementation reuses the existing atomic transaction path; the new real
PostgreSQL crash/replay gate still needs execution before acceptance.

Game protocol **14** replaces 13 because the new repair RPC changes Godot's RPC
table. Ticket protocol remains **7**. Update client, game server and backend together;
Godot stays **4.7.2**. Existing `.gd.uid` files remain unchanged.

## Reproducible checks and pending acceptance

Portable repair checks from the repository root:

```sh
python -m unittest discover -s tools/public_handoff -p test_repairs.py -v
/path/to/Godot-4.7.2 --headless --path . --script res://tools/repair_probe.gd
```

The Python schema check needs the existing backend `psycopg` dependency; without
it that check explicitly skips. Linux ran all 11 tests with the dependency installed,
including all 9,999 damaged integer condition values. The Godot probe passes 20
checks through the actual service and panel using an explicitly in-memory authority
double. It is not proof of PostgreSQL, HTTPS or real authenticated repair peers.

On the configured Windows test stack, run:

```powershell
python tools/public_handoff/repair_probe.py
pwsh -NoProfile -File tools/Godot.ps1 -Mode Check -Headless
```

The new backend probe covers real HTTPS/SQL concurrent replay, changed intent,
stale ownership/revision, restart, journal debit and process death after profile
write/before COMMIT/after COMMIT. It is committed but **not run here**: its shared
fixture runner requires Windows PostgreSQL binaries/process flags. Windows exports,
Keycloak authentication, real two-client repair/reconnect tests and visual acceptance
remain pending. The broad Linux results and known baseline failures are recorded
in PROGRESS.md; do not interpret this draft as a completed acceptance gate.

Andy should test with isolated accounts and matching protocol-14 client/server:

1. Damage or wear the starter, dock, select Repair and compare the displayed missing
   condition and total. Buy once; verify one debit, full gauge and unchanged cargo/fuel.
2. Try full condition, insufficient funds, loading, undocked use and a stale quote.
   None should charge. Double-click should not buy twice.
3. Disconnect/reconnect and restart the test stack after purchase; check condition
   and wallet persist. Interrupt an in-flight repair on isolated data and verify
   canonical recovery without another charge. Run the SQL crash probe as well.
4. Confirm readable Repair UI, gauge update and that local Port Test stays a fixture.

Next: close these Step 62 acceptance gates, then Step 63 ship catalog and purchase.
