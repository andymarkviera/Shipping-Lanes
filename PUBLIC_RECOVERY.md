# Step 59 — Online impact damage and paid recovery

Hard authoritative collisions damage the hull. Gentle docking and glancing contact
at or below 2 m/s closing speed do not. HandlingShip exports the harmless threshold
and damage scale: ceil((closing_mps - 2)^2 * 100) basis points, capped at 10,000.
One collider has a one-second cooldown; a physics tick emits the strongest hit.
The server observes real collision normals and relative velocity. Clients have no
damage, fee, fuel-restoration or arbitrary-position RPC. No hidden shallow-water
zones were introduced: shore/grounding contact uses existing solid geometry.

Hull damage is separate from future wear/performance curves (Step 60). During its
save the affected boat stops briefly. Confirmed zero condition hides the inert
wreck, removes cargo and fails active/loading/loaded jobs without payment. Ship
ownership and identity remain. The HUD shows the outcome and Recover ship button.
Sinking visuals/animation remain later presentation work; this is functional state.

## Provisional economy

Each sinking records a 250-credit fee, including on the starter. Available money
is charged immediately; the full unpaid remainder becomes recovery_debt_minor.
Recovery restores the owned hull and includes enough propulsion fuel to leave at
least 100 L in the tank, so an insolvent or empty-fuel player can resume earning.
It does not add cargo fuel. Half of subsequent delivery earnings (rounded down in
minor units, minimum one minor unit, never beyond remaining debt) repays the balance;
the rest is credited. Delivery receipts distinguish net pay and repayment. Repeated
sinking adds another full fee; there is no starter waiver or free recovery.
Price, damage and repayment tuning are development choices, not realism claims.

## Durability and placement

The existing account lease/revision lock serializes impact transactions with
services and departure saves. Condition, actual remaining fuel/pose, cargo loss,
failed jobs, fee, debt, receipt and journal commit together. A checkpoint cannot
move/refill a pending wreck. Recovery binds to the sunk incident and uses canonical
approved positions; repeating recovery or an old impact receipt cannot reapply it.
The server retains an unconfirmed impact intent across disconnect/replacement,
reconciling the same identity on the next admission. Unknown outcomes fence the old
owner. A server process lost before an impact transaction commits may restore the
last committed state; an unconfirmed collision is not reported as completed sinking.
Confirmed sinking/recovery survive a full server restart.

Eight candidate return spots south of Brindle Quay are checked against authored
solids and other ships. In-flight slot reservations prevent simultaneous selection.
After commit, a recovered hull stays inert until the physics chart has updated and
its position is clear; moving traffic cannot be overlapped. If all spots are busy,
recovery waits for another request without a new charge. A saved return spot that
becomes occupied before reconnect is subject to the normal safe-spawn refusal.

Old profiles default to full hull condition and no debt; no player save is reset.
Game protocol 13 requires matching client/server code; ticket protocol remains 7.
The online fleet currently exposes the starter container ship. Local Port Test and
heavy-loader fixtures are unchanged, including their free test repair/refuel.
Future online hulls must use this paid recovery boundary, not a fee exemption.

## Evidence

- 139-script/startup check; Windows Release export includes the recovery service.
- 109 real HTTPS/PostgreSQL checks: 628c74a7/recovery-summary.json. Includes
  nonlethal damage, repeat sinking, full/partial fee payment, debt repayment,
  minimum recovery fuel, intent replay, and six real process-kill cases spanning
  impact/recovery after profile write, before COMMIT and after COMMIT.
- 43 real-physics checks: editor 28dd24cb and Release 98d02da7 under
  ../output/shared-physics. Actual gentle/glancing contact is harmless; a hard hit
  emits one bounded event. Existing geographic/shared-space/docking checks pass.
- 34 actual-peer checks: editor 3f61e830, Release 57a7142d. Ordinary helm drives a
  low-health, loaded fixture into the quay. Cargo/fee/debt survive reconnect;
  another account cannot recover it; an occupied return spot is skipped; the
  recovered boat accepts acknowledged helm and survives a dedicated-server restart.
- 27 Release peer interruption checks: 740c81ad. Real collisions kill the authority
  before/after COMMIT; reconnect reconciles the pending impact exactly once.
- Existing Release cargo regression: 38 checks (d13ee13d); refuel: 28 (e876ddec).

Peer evidence is in ../output/handoff/<id>/recovery-peer-summary.json. All fixture
accounts/saves are isolated. The low-health setup accelerates testing; it does not
set ordinary player health. The rendered recovery HUD was visually inspected.
The initial movement assertion relied on one unreliable packet; the final test
requires sustained acknowledged helm. An initial export omitted the new service;
its manifest was fixed before the passing Release runs. Manual play-test remains
pending, and these checks do not establish public-internet capacity or deployment.
