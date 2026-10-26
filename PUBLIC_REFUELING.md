# Step 58 — Online propulsion refueling

Dock at Brindle Quay or Slatewater Works, open REFUEL, choose a whole number of
liters, and review the total on Buy. The current development price is 0.25 credits
per liter, not a final economy balance. The starter tank holds 1,000 L. Fuel is
propulsion inventory, never a cargo batch or tradeable cargo fuel.

The server derives the account, ship and actual dock from the authenticated peer.
Both port and berth must advertise refueling. Quotes last 30 seconds and bind to
the current port, live tank and wallet. Loading blocks refueling. Full tanks,
insufficient funds, stale quotes and invalid quantities cannot debit money.
The UI shows whole-liter space; fractional tank headroom is not sold.

Purchasing consumes the quote before awaiting I/O. The existing voyage lock also
blocks undocking, sailing checkpoints, cargo mutations and departure races while
the request runs. The server first saves actual remaining propulsion fuel and
position, then purchases against that canonical revision. It never adds fuel to
an older sailing snapshot. PostgreSQL commits fuel, balance, game treasury,
receipt and journal together. Repeated transaction IDs return the original result;
changing their arguments is rejected. A peer cannot reuse a consumed quote even
with a new sequence number. No UI refresh or timeout automatically buys again.
An unknown outcome fences the ship; reconnect restores the canonical outcome.

Game protocol is 12; authority ticket protocol remains 7. Client, dedicated server
and authority service must be restarted together after updating. Existing profiles
need no migration, reset or new account. The local Port Test remains its explicitly
labelled free refuel/repair fixture; paid services here belong to authenticated
online play. Online heavy ships and repair are separate future integration work.

## Validation

- Godot 4.7.2: 138-script/startup check and Windows Release export.
- Real HTTPS/PostgreSQL: 58 checks, including invalid amounts, insufficient funds,
  exact full tank, concurrent replay, changed intent, stale ownership/revision,
  service restart and process death after profile write/before COMMIT/after COMMIT.
  Evidence: ../output/handoff/4f3553a9/refuel-summary.json.
- Two actual clients: 28 checks in editor (6a0860f3) and Release (2b9c4b71), covering
  actual Buy button quantity, dock eligibility, cross-account rejection, consumed
  quote replay, capacity, loading exclusion and purchased live fuel after restart.
  Rendered refueling panel inspected: readable opaque UI and visible total.
- Existing Release cargo UI/reconnect/delivery regression: 38 checks (905f5fe6).
- Final Release refueling verification: 28 checks (b833a384).
- Final Release peer interruption/reconnect: 25 checks (94baeedb), before and after
  COMMIT; old quotes cannot debit again and final saves cannot overwrite purchased
  fuel. Historical uncertain-save drain warnings remain explicit.

The development stack was drained and restarted without resetting data. Its game
window was refreshed. A stale isolated shader cache produced startup errors; the
cache was moved to shader_cache-before-refueling, then rebuilt on launch. The
reopened game and server logs are clean. Account data and local saves untouched.

All accounts and saves used for validation are isolated fixtures. These tests use
fixture approaches, not a new full-voyage benchmark. User online delivery/refueling
feedback is still pending. No claim of public-internet hosting or manual acceptance.
