# Step 88 — World layout and traversal budget

Task ID: `world-layout-and-traversal-budget`. D144. November 11, 2026. **Draft,
UNVERIFIED:** the cloud runner denied Python and has no Godot, so every number
below was worked by hand. `tools/world_layout/traversal_budget.py` recomputes
them and has not yet run. If the script disagrees, trust the script and correct
this document.

This is a plan of lanes, ports and budgets made before scenery. Nothing here is
loaded by the game yet. The data is `features/world/world_layout.json`.

## Scale and time

| Value | Choice | Agrees with |
|---|---|---|
| Navigation radius | 100,000 m | `Nav.RADIUS_M`; saved spatial snapshots validate it |
| Length | 1 scene unit = 1 m = 1 navigation metre | UNITS_AND_TIME.md |
| Time | 1 game second per real second | UNITS_AND_TIME.md |
| Top speed | forward acceleration ÷ linear drag, per ship record | `handling_ship.gd` |

The radius and both scales are kept, so no save, protocol or address migration.
One degree is 1,745.33 m. The region spans about 10° × 6.5° (17.5 × 11.3 km);
the globe's circumference is 628.3 km, a 17.5 hour circuit at 10 m/s.

Curvature (deferred player request): at this radius a 40 m camera sees the
waterline horizon at about 2.8 km, and a 30 m landmark drops below it at about
5.3 km. Every port outside the starter pair is 4.8 km or more from its nearest
neighbour, so most destinations rise over the horizon during the approach. That
is the intended look for Steps 89–90; it is a consequence of the kept radius.

## Budget model

A leg, berth to berth, at the planning pace:

- time = length ÷ (0.8 × top speed) + 150 s
- fuel = (cruise seconds × 0.8 + 22 s) × full-output litres per second

The planning pace is 80% throttle, the pace of the Step 67 benchmark controller.
The 150 s and 22 s allowances cover unberthing, turns, the approach and stopping.
Both were fitted to the two measured Step 67 legs and reproduce them:

| Measured leg | Measured | Model | Difference |
|---|---:|---:|---:|
| Starter, 3,068.27 m, time | 530.18 s | 533.53 s | +0.6% |
| Starter, 4,059.16 m, time | 653.22 s | 657.40 s | +0.6% |
| Starter, 3,068.27 m, fuel | 163.58 L | 164.41 L | +0.5% |
| Starter, 4,059.16 m, fuel | 214.42 L | 213.96 L | −0.2% |
| Coastal, 3,068.27 m, fuel | 131.93 L | 131.53 L | −0.3% |
| Coastal, 4,059.16 m, fuel | 172.84 L | 171.17 L | −1.0% |

The check allows 2%. The model is fitted on 3–4 km legs and extrapolated to
14 km; no longer voyage has been sailed. Swift and Harbor were benchmarked at the
same 8 m/s target, so their own planning pace is unmeasured, as is the lifter's.

Rules every permitted hull must meet on every route: one-way fuel at most 80% of
its tank (800 L for the 1,000 L hulls, which is also a new profile's starting
fuel), and no leg over 40 minutes. Every port sells fuel and repairs.

## Travel-time targets

Starter hull at the planning pace, berth to berth:

| Tier | Target | Use |
|---|---|---|
| Starter | 8–12 min | The existing Brindle Quay ↔ Slatewater Works pair |
| Short | 12–15 min | First trips to a new port |
| Medium | 15–24 min | Regional runs |
| Long | 24–36 min | Crossings; the best pay per trip |

## Ports

Positions are latitude, longitude in degrees. East and south are metres from
Brindle Quay, rounded.

| Port | Lat, lon | East, south | Largest class | Cargo services | Role |
|---|---|---|---|---|---|
| Brindle Quay | 0, 0 | 0, 0 | L | containers, heavy, bulk, gas, oil market; shipyard | Starter home; grain, salt and LNG consumer |
| Slatewater Works | 0, −0.8594 | −1,500, 0 | L | containers, heavy, bulk, gas, oil market, refinery; shipyard | Heavy industry; ore, coal, limestone and industrial gas consumer |
| **Cinder Point** | −2.0, 2.0 | 3,490, 3,490 | L | containers | First new destination; hub at the west mouth of Needle Gut |
| Tallow Reach | −3.0, −3.5 | −6,100, 5,240 | M | containers, bulk, heavy | Grain, salt and limestone source; quarry-block lifts |
| Gannet Light | −3.0, 4.6 | 8,020, 5,240 | L | containers, gas | LNG and industrial gas source |
| Orrin Deep | −1.0, 6.5 | 11,340, 1,750 | L | containers, bulk | Ore and coal source |
| Farrow Bank | −6.5, 0.5 | 870, 11,340 | L | containers, oil market | Offshore crude source |

All seven offer refuel and repair. Brindle Quay, Slatewater Works and Cinder
Point are existing records and keep their recorded services; planned services are
additions only. The other four are names and positions, not catalog records.

**Cinder Point is placed at 2.0° S, 2.0° E**, 4.94 km from Brindle Quay, with open
water to the south-west. It sits on the west shore of Emberholm, the island that
divides the region. It is not yet wired into Port Test or the public world; see
Limits.

Brindle Quay and Slatewater Works keep their anchors, 1,500 m apart. Every other
pair is at least 4.4 km apart, so the existing rule that a client is shown at
most two ports within 2,200 m still holds everywhere.

## Lanes

Every route leaves and enters through a sea gate 440–520 m off the berth on the
open-water side. Lengths are great-circle metres along the lane.

| Route | Tier | Length km | Starter min | Starter fuel L | Largest class | Families |
|---|---|---:|---:|---:|---|---|
| Brindle Quay – Slatewater Works (measured) | starter | 3.07 / 4.06 | 8.9 / 11.0 | 164 / 214 | L | containers, bulk, gas, oil, heavy |
| Brindle Quay – Cinder Point | short | 5.59 | 14.1 | 290 | L | containers |
| Slatewater Works – Cinder Point | medium | 6.73 | 16.5 | 348 | L | containers |
| Cinder Point – Gannet Light, Needle Gut | short | 5.48 | 13.9 | 285 | **S** | containers |
| Cinder Point – Gannet Light, round the cape | medium | 9.97 | 23.3 | 509 | L | containers |
| Gannet Light – Orrin Deep | short | 5.56 | 14.1 | 289 | L | containers |
| Brindle Quay – Gannet Light | long | 11.11 | 25.6 | 566 | L | containers, gas |
| Slatewater Works – Gannet Light | long | 12.61 | 28.8 | 641 | L | containers, gas |
| Brindle Quay – Orrin Deep | long | 12.22 | 28.0 | 622 | L | containers, bulk |
| Slatewater Works – Orrin Deep | long | 13.72 | 31.1 | 697 | L | containers, bulk |
| Brindle Quay – Tallow Reach, Skerry Gate | medium | 8.44 | 20.1 | 433 | **M** | containers, bulk, heavy |
| Slatewater Works – Tallow Reach, Skerry Gate | medium | 7.27 | 17.6 | 374 | **M** | containers, bulk, heavy |
| Slatewater Works – Tallow Reach, outside the Skerries | medium | 9.46 | 22.2 | 484 | M | containers, bulk, heavy |
| Brindle Quay – Farrow Bank | long | 11.38 | 26.2 | 580 | L | containers, oil |
| Slatewater Works – Farrow Bank | long | 11.61 | 26.7 | 592 | L | containers, oil |
| Cinder Point – Farrow Bank | medium | 8.32 | 19.8 | 427 | L | containers |
| Tallow Reach – Farrow Bank | medium | 9.52 | 22.3 | 487 | M | containers |

The starter pair uses the measured Step 67 corridor lengths, which differ by
direction; its measured times are 8.8 and 10.9 minutes. Tallow Reach routes are
class M because its berth is.

## Shortcuts and ship-size constraints

Size classes, by hull beam and length:

| Class | Beam up to | Length up to | Hulls today |
|---|---:|---:|---|
| S | 14 m | 70 m | Starter, Coastal, Swift, Harbor, bulk, gas and oil prototypes (13 × 64 m) |
| M | 26 m | 100 m | Heavy lifter (24 × 90 m) |
| L | 40 m | 170 m | None yet |

A passage needs a clear width of at least 2.5 × the beam of the largest class it
admits. Open lanes are at least 120 m wide (class L needs 100 m).

| Passage | Clear width | Admits | Saves the starter hull |
|---|---:|---|---|
| Needle Gut, a straight 1.6 km cut through Emberholm | 40 m | S only (S needs 35 m, M needs 65 m) | 9.3 min: 13.9 instead of 23.3 round the north cape |
| Skerry Gate, between the mainland and the Skerries | 70 m | S and M (M needs 65 m, L needs 100 m) | 4.6 min: 17.6 instead of 22.2 outside the Skerries |

Both limits are visible gaps between rock. Neither is a depth limit: there are no
hidden shallows. Every size-limited route has an open alternative between the
same ports. No air-draft limit is planned here; bridge clearance needs measured
loaded heights and belongs to Step 94.

A class L berth must be at least 42 × 172 m. The three existing berth envelopes
(64 m wide, 180–230 m long) already are. Tallow Reach is planned at 34 × 110 m.

Per hull, on its longest permitted leg:

| Hull | Class | Top m/s | Planning m/s | Longest leg km | Time min | Fuel L | Fuel limit L |
|---|---|---:|---:|---:|---:|---:|---:|
| Starter | S | 10.000 | 8.00 | 13.72 | 31.1 | 697 | 800 |
| Coastal | S | 10.000 | 8.00 | 13.72 | 31.1 | 558 | 800 |
| Swift | S | 12.000 | 9.60 | 13.72 | 26.3 | 699 | 800 |
| Harbor | S | 9.000 | 7.20 | 13.72 | 34.3 | 696 | 800 |
| Bulk prototype | S | 10.000 | 8.00 | 13.72 | 31.1 | 697 | 800 |
| Gas prototype | S | 10.000 | 8.00 | 12.61 | 28.8 | 641 | 800 |
| Oil prototype | S | 10.000 | 8.00 | 11.61 | 26.7 | 592 | 800 |
| Heavy lifter | M | 6.875 | 5.50 | 9.46 | 31.2 | 1398 | 1600 |

Fuel, not time, sets the size of the region: the starter family's limit is about
15.8 km per leg and the lifter's about 10.8 km. Heavy work is therefore kept to
the three western ports.

## Progression

1. **Starter pair.** Containers between Brindle Quay and Slatewater Works, as now.
2. **Cinder Point.** The first voyage out of sight of home, 14 minutes.
3. **Bulk.** Tallow Reach grain, salt and limestone (17–20 min), then Orrin Deep
   ore and coal (28–31 min).
4. **Needle Gut.** Small hulls reach Gannet Light in two short legs through Cinder
   Point instead of one long one.
5. **Gas.** Gannet Light to Brindle Quay (LNG) or Slatewater Works (industrial).
6. **Oil.** Farrow Bank crude to the Slatewater refinery, a long leg.
7. **Heavy.** Occasional lifts among Brindle Quay, Slatewater Works and Tallow Reach.

This follows the D143 order. It plans where services go; it adds no offers,
rates, hulls or online families.

## Reproduce

```sh
python3 tools/world_layout/traversal_budget.py
python3 -m unittest discover -s tools/world_layout -p 'test_*.py'
```

Expect `WORLD_LAYOUT_PASS routes=17 failures=0`. The script checks the scale
against the game constants, each planned top speed and size class against its
ship record, port services and berth envelopes against their records, sea gates,
port spacing, the model against the measured legs, and every route's tier, fuel
range, leg cap, passage width and alternative.

## Limits

- **Nothing was executed.** All lengths and times are hand arithmetic.
- **Cinder Point is placed on the plan only.** Adding it to the public world
  changes the game protocol (three port poses instead of two), save validation by
  port index, `fleet_slots.json` and the service `PORTS` tuples (CONTENT_EXTENSION.md).
  That could not be tested here and belongs with Step 89 region loading.
- **No coastline exists.** Lanes are straight segments between waypoints; Step 91
  scenery must be built around them and keep the stated widths.
- **Payout balance will shift.** Bulk and gas pay by direct distance; containers
  pay a flat reward. Brindle Quay to Tallow Reach is about 4.3 NM against the
  fixture's 0.81 NM, so the same rate pays about five times as much for about
  twice the time. Rates need another pass once these routes are sailable.
- **The oil and tanker scale decision (D143) is still open.** Farrow Bank gives
  oil a long route; it does not fix the 200-barrel capacity.
- Four ports are plans without records, scenes or berths. Names are provisional.
- No playtest. Andy has not accepted the map, the targets or the names.
