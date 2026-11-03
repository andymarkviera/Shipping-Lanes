# Step 67 — Economy gate

Task ID: `economy-gate`. D124. November 2, 2026. Scope: the existing public
starter/container progression through a first **purchased, activated and fueled**
Coastal ship. No new cargo families, research-price import or local-save UX work.

## Target and tuning

Target **10–15 minutes** from a fresh 200-credit/800 L profile to the first useful
upgrade when choosing the three-container outbound contract. The fixed-input
benchmark is 9.12 simulated minutes, leaving time for service menus and navigation.
Smaller contracts target **25–35 minutes**; one halfway sinking targets **25–35
minutes** including a declared recovery/reposition allowance. These are design
acceptance targets for Andy's playtest, not measured human playtime.

Change only Coastal's catalog price: **900 → 800 credits**. Retain starter 500,
Swift 1,200, rewards 250/500/750, fuel 0.25/L, repair 250 per full condition scale,
250 recovery fee and 60% condition-scaled resale. Do not grant money or fuel.
New purchases still have empty tanks. Reserve/pay for 250 L after activation,
enough for either measured Coastal route, without selling the starter.

At the old price the large contract left 908.65 credits after fuel replacement and
wear repair: enough to buy the hull but insufficient for the 62.50-credit fuel
reserve. Under the same policy it took two deliveries / 20.29 minutes. At 800,
one delivery pays for the hull, fuel and 46.15 credits left over. This is a small
useful progression; Coastal cuts measured route fuel by about 19.4% (idle burn
is unchanged). It is an efficiency choice, not a promise to recoup its purchase
within the six seed contracts. Swift's stronger acceleration remains a later
choice; no catalog expansion or hull-stat change.

Existing acquisition costs/IDs are preserved. Resale already caps the basis to
min(actual acquisition cost, current catalog price): a previously purchased
900-credit Coastal now has a maximum full-condition sale quote of 480 credits,
not 540. Legacy cost-less records use current price. No automatic refund or save
rewrite. Restart matching backend/game-server builds for shared catalog changes;
no live deployment is performed by this PR.

## Repeatable measurements

Godot `4.7.2.stable.official.ed1daf0bf`. Fixed 1/60 s input simulation calls actual
HandlingShip.advance_motion and PropulsionFuel, integrating resulting velocity.
Uses both waypoint corridors from the existing navigated voyage fixture, starts
stopped at the berth coordinate, steers/approaches/stops, and fails at 1,800 s or
empty fuel. No visual hull, collision space, physical berth admission, networking
or human input is exercised. Fuel/handling are production code; movement integration
and the controller are a benchmark. Routes measure actual traveled distance,
not the 1,500 m port separation. Two independent runs produced identical metrics.

| Hull | Outbound time | Return time | Outbound fuel | Return fuel |
|---|---:|---:|---:|---:|
| Starter | 530.18 s | 653.22 s | 163.58 L | 214.42 L |
| Coastal | 530.18 s | 653.22 s | 131.93 L | 172.84 L |
| Swift | 509.20 s | 626.33 s | 164.90 L | 215.70 L |

Starter distance is 3,068.27 / 4,059.16 m. Outbound operating cost is 41.00 credits
for 164 L replacement plus 0.35 repair; return is 53.75 for 215 L plus 0.45 repair.
Whole-liter replacement and upward minor-credit repair rounding are included.
Condition wear accrues only during propulsion; no machinery wear is introduced.

The Python scenario starts with the existing new-player terms in local_online.py
(no fixture-delivery test job), runs production authority receipt dispatch against
an explicit MemoryDB SQL double, and advances a controlled clock through actual
5 s/container loading deadlines. It adds 2 s/leg for docking/undocking. Movement
fuel/wear checkpoints are modeled from the Godot measurements, not sent through
the real lease/checkpoint service. Each delivery replaces consumed fuel and repairs
wear even when the original fuel was prepaid. Upgrade funding therefore does not
mistake gross revenue for net earnings. Menus/login/service network latency are
excluded. Backend operations still require trusted-server port attestation.

| Scenario | Delivered quantities | Time to fueled upgrade | Fuel + repair | Recovery incl. repaid debt | Wallet after upgrade/fuel |
|---|---|---:|---:|---:|---:|
| Large contract | 3 | 9.12 min | 41.35 | 0 | 46.15 |
| Smaller contracts | 1, 1, 2 | 28.99 min | 136.88 | 0 | 200.62 |
| Halfway sinking, retry | 3, 3 | 26.96 min | 116.03 | 250.00 | 471.47 |

All money above is credits. The sinking scenario loses its first load, pays the
200-credit wallet and adds 50 debt. It retains the owned ship, recovers once, retries
the failed nonexpiring offer, and repays all debt from subsequent delivery income.
Fuel lost on the failed half-voyage is included in replacement costs. The scenario
adds **120 s assumed** recovery-to-service time, then starts the route benchmark at
the berth; it does not simulate that recovery approach. Repeated sinking is costly
and can accumulate debt; this is not a guarantee of recovery after arbitrary losses.

The six seed offers are finite (3,000 gross credits altogether). Successful and
abandoned offers stay closed; cancelled loading can retry without payment; failed
cargo can retry but only a delivered load earns money. Exhausting content does not
regenerate offers. Larger sustainable-content progression remains later roadmap work.

## Reproduce

Use the exact pinned Linux engine and isolated writable XDG data/config/cache
folders outside Git. With `GODOT` pointing to that executable and `WORK` to a new
scratch directory, from the repository root:

```sh
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . --script tools/economy_gate_probe.gd -- --metrics="$WORK/routes.json"
python tools/public_handoff/economy_gate.py --metrics "$WORK/routes.json" --output "$WORK/progression.json"
python -m unittest discover -s tools/public_handoff -p 'test_*.py'
```

Python requires the existing psycopg 3.2.10 dependency in an isolated venv; no DB
connection is opened. Rerun the metrics and scenario commands and compare JSON.
The scenario also reports the old 900-credit price for comparison, reverting its
in-process catalog override in finally; it never edits the catalog or a real save.

Every scenario request is replayed and checked for unchanged profile, wallet,
treasury and journal. The three scenarios also run with JSON reload and a fresh
Authority after every operation and movement checkpoint; results must match exactly.
Balances conserve wallet + treasury; the final wallet reconciles to gross earnings
minus fuel, repairs, recovery, acquisition and upgrade fueling. This is serialized
state/receipt reload evidence, not real PostgreSQL process-crash evidence.

Exploit regression coverage: 24 purchase/resale cycles across all three classes
must lose money; 150,000 condition/cost-basis valuations cannot exceed acquisition
or catalog price; repeated recovery adds charges/debt without duplicating ships;
repeated cancellation earns nothing; duplicate/new-ID deliveries and sold IDs cannot
pay again; six closed offers stay closed across reload; conflicting action payloads
reject. Existing stale-revision, lost-reply, unusable-account, cargo/job, authority
fencing and receipt tests remain. No unlimited-money loop was found in this tested
surface. Real transactional race/crash proof remains an explicit gate below.

## Remaining acceptance gates

- **Windows:** pinned PowerShell checks, Debug/Release client/server exports,
  exported shared price/UI consistency and save/UID compatibility.
- **PostgreSQL/HTTPS:** actual transactions under concurrent delivery/purchase/sale,
  repeated requests, before/after-commit crashes, checkpoint/reload and server restart.
  No PostgreSQL server/client or configured integration stack is available here.
- **Keycloak/authenticated peers:** native login, two-account isolation, lease fencing,
  reconnect/rebind and public progression after restart. Java alone is installed;
  no configured identity stack or accounts were used.
- **Visual/Andy playtest:** actual collision-safe navigation, docking and recovery
  placement; 10–15 minute first-upgrade target; cautious and sinking scenarios;
  finding/selecting the largest contract; review/confirm/fuel UI, scaling/focus and
  class feel. No display/Xvfb or manual playtest was run.

Known Linux regressions remain: lateral collision and two composition contact
assertions fail; ports emits two out-of-tree transform errors despite 261 checks;
gauge/wear probes wait for rendered frames after 3/10 passing assertions. They are
not clean gates and are not hidden by the new economy benchmark. See PROGRESS.md
for the full run record. No deployment or completed human/production acceptance.
