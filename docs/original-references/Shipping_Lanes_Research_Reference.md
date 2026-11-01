# Shipping Lanes — mechanics research reference

Research date: **October 18, 2026**. Second pass: current wiki, complete available changelog, individual ship/port records, and gameplay captions. Prepared for Andy's future Godot game. **Research only; no build plan or implementation decisions.**

## 1. Scope, evidence, and completion status

This revision replaces the first pass as the working reference. The browser could read the replacement wiki even though the search reader returned HTTP 403. The second pass inspected **90 individual ship pages, all 19 individual port pages, and the mechanics/changelog pages: 143 distinct replacement-wiki URLs in total**. The fleet includes ordinary, limited, legacy, staff, and retired records; 90 is not a count of ships currently for sale.

Ten video caption tracks were retrieved. Nine contained usable narration; one contained essentially music only. Further videos were private, removed, or lacked captions. **Video frames remained buffering in this browser. Accordingly, video findings below are caption/narration evidence, not claims that the visuals were watched or measured.** No live Roblox session was played, no original source code was inspected, and no messages were sent to anyone.

Evidence labels: **Current wiki** = replacement page read directly; **Changelog** = version-specific reported change; **Video narration** = timestamped creator account, possibly historical or early access; **Historical** = older behavior; **Derived** = our calculation; **Unresolved** = inaccessible, contradictory, or undocumented.

**The public-source research pass is substantially expanded and consolidated. Exact live-game parity is still not proven.** Where a source provides a rule, it is recorded. Hidden algorithms, exact tolerances, and absent UI details remain explicitly unmeasured. A newer wiki page can still contain old text, placeholders, or errors.

## 2. Current-version corrections that matter

The wiki's [full update history](https://wiki.shippinglanes.net/wiki/Updates) reports:

- **3.5.0, October 18:** Colossus added; Halloween theme and pumpkin heavy loads; container loading capped at **one minute**.
- **3.4.5, September 18:** Extremely Large Crude Carrier and direct ship packs added.
- **3.4.2, August 26:** component maintenance, visible rust, and performance penalties added. Subsequent repair balancing uses earning ability.
- **3.3.0, August 6:** Pine Island and Liberty Bulker added.
- **3.2.6, May 6:** Mighty and limited Voyager added.
- **3.2.2, March 31:** Premium perks removed; the speed pass changed from 120% to **125%**.
- **3.2.1:** fixed ships moving during rocket launches. **3.2.5:** fixed launching rockets across different maps.
- Earlier entries explicitly document throttle-based fuel consumption, cargo weight lowering ships, freecam, furniture permissions/snapping, and cargo reconnect saving.

These changes supersede the older reference's 18-port inventory, Premium stacking advice, and incomplete maintenance/fleet coverage. Version notes are public documentation, not an independent live deployment check.

## 3. Player flow, controls, and navigation

The [tutorial](https://wiki.shippinglanes.net/wiki/Shipping_Lanes_Tutorial) identifies the **Small Bulk Carrier**, named **SS Starter Ship**, as the initial/tutorial vessel. Select a ship and permitted port/spawn position, sail to a compatible berth, stop, accept the dock prompt, open **Manage Cargo**, choose/load cargo, undock, and inspect **View Loads**. Arrival alone does not automatically accept a job.

| PC input | Documented function |
| --- | --- |
| W / S | Increase/decrease commanded throttle |
| X | Set commanded throttle to zero |
| A / D | Turn left/right |
| Q / E | Side thrust left/right |
| H | Horn |
| I / O | Zoom in/out |
| M | Map; documented in historical changelog |
| Shift + P | Freecam; enabled for everyone in the changelog |

Xbox documentation gives left stick movement, bumpers for thrusters, L3 horn, X map, Y dock. Touch uses a throttle lever, steering stick, and separate controls. The tutorial does not establish throttle increments, reverse cap, steering persistence, sensitivity, every camera binding, or PlayStation mapping.

The map supports waypoints. Version notes document hovering a ship to see speed/class, switching ship camera, and camera lock. Helm exit, walking aboard, and returning to the ship are documented, but detailed passenger/helm permissions remain incomplete.

The first wallet amount is still unverified: $5,000 comes from historical sources, not a directly observed new account. The free Small Container Ship remains separately listed; its page allows multiple purchases subject to the account data limit. A **1000 KB** ownership-data limit is documented; this is not a known fixed fleet-count cap.

## 4. Ship movement, fuel, docking, and damage

Ships retain momentum. Reverse throttle brakes faster than merely reducing the command to zero. Side thrust assists docking. Cargo affects waterline/draft, so an empty ship fitting a passage does not prove a loaded ship will fit. Nominal DWT restrictions and physical channel clearance are different checks.

The changelog explicitly says fuel consumption became based on **throttle rather than velocity**. The newer infoboxes specify fuel capacity and **endurance in minutes at 100% throttle**, whereas older pages mix consumption-per-NM values and stale ranges. Do not treat those historical burn figures as the current simulation model.

**Derived check:** nominal full-throttle fuel use per minute = tank / endurance. This is an average implied by reported values, not the exact tick algorithm. Fuel use at idle/reverse/thrusters, partial throttle, weather, and damage still needs measurement. Many current ranges imply an accelerated game distance/time scale; no exact universal constant has been verified. Real-world `distance / knots` alone is insufficient for a certified game ETA.

Docking requires stopping near an eligible berth. It has an animation/progress delay, and compatible services differ by berth. Exact speed/distance/angle tolerances and berth occupancy arbitration remain unmeasured. The update history prohibits docking while sinking and fixes throttle input while docked.

[Container cranes](https://wiki.shippinglanes.net/wiki/Container_Cranes) and [bulk cranes](https://wiki.shippinglanes.net/wiki/Bulk_Cranes) can serve both container and bulk vessels. Crane booms animate on docking; large vessels can trigger several. [Pipelines](https://wiki.shippinglanes.net/wiki/Pipeline) let container/bulk ships obtain refuel/repair services without loading their own cargo. A decorative structure count therefore does not completely describe functional service permissions.

Collision/grounding damage and gate collisions are documented. The current [damage article](https://wiki.shippinglanes.net/wiki/Damaging_Ships) still repeats old approximate throttle advice; it provides no trustworthy impact formula or health constants. A narrated zero-health experiment reports sinking and loss of movement (video V7 below). Damage health and long-term component maintenance should be recorded separately until their relationship is tested.

Fuel-exhaustion behavior remains unverified. The [Gauntlet page](https://wiki.shippinglanes.net/wiki/Gauntlet_Cargo_Liner) contains an ambiguous one-third-speed comparison involving pass conditions; it is insufficient to establish universal emergency propulsion. Its separate sails-only 17-knot claim does not resolve how ordinary ships behave without fuel.

## 5. Long-term ship maintenance

[Ship Maintenance](https://wiki.shippinglanes.net/wiki/Ship_Maintenance) documents three independently degrading components, introduced in 3.4.2:

| Component | Performance affected |
| --- | --- |
| Engine | Speed |
| Hull | Fuel consumption |
| Machinery | Maneuverability |

Performance penalties begin when component condition reaches approximately **50%**; the page describes at most a 50% adverse change and gives fuel draining **1.5×** faster as its example. Rust appears when hull condition falls below **80%**. Earlier 70% advice was superseded.

Repairs are accessed through **Manage Ships → ship card → Maintenance**. The page describes a per-percent price multiplied by the percentage restored. The current per-ship reported rates are tabulated later. The exact wear clock, stationary/offline wear, fractional rounding, penalty curve, and repair rounding remain unknown. Do not assume wear is distance-driven: the article itself marks that explanation as presumed.

The changelog says later repair balancing scales with earning ability; a simple universal percentage-of-purchase-price formula is not established. Rewarded repair/refuel advertisements and a paid repair-all product are also documented.

## 6. Cargo systems and transaction behavior

### Containers

[Containers](https://wiki.shippinglanes.net/wiki/Containers) have assigned destinations and a quoted payout. The UI shows available offers, destination, reward, remaining capacity, and a small route map. Multiple destinations can be carried together; unloading at a destination removes the corresponding containers. The load visually fills the ship. The page says crane turnaround differs by port; current update notes cap loading at one minute.

Offer generation/refresh, expiry, cancellation, HAZMAT catalog, reservations between players, modifier locking, and exact partial-load behavior are still unestablished. A creator saying to refresh by exiting the helm does not prove that every cargo menu shares that refresh rule.

### Bulk

[Bulk](https://wiki.shippinglanes.net/wiki/Bulk) includes grain, coal, iron ore, and limestone, held inside the ship. Revenue depends on direct separation of origin and discharge ports, not sailed distance. UI rates are profit per NM. Both origin and destination multipliers are documented by the tutorial; the [class formula](https://wiki.shippinglanes.net/wiki/Bulk_Carrier_Class) explicitly applies destination multiplier to its rate. Whether the displayed rate already includes origin remains a live numeric check.

Do not equate **hold count**, **DWT**, and **actual cargo capacity**. Current pages frequently give only holds and DWT, and some blur these concepts. Commodity-specific prices, mixing across holds, selectable partial quantities, partial discharge, and minimum-distance treatment remain unknown.

### Gas

[Gas](https://wiki.shippinglanes.net/wiki/Gas) uses m³, pipelines, direct origin/destination distance, and a per-NM rate. The [class page](https://wiki.shippinglanes.net/wiki/Gas_Tanker_Class) explicitly says the earlier buy/sell commodity system was replaced by bulk-like delivery. It still says five gas types while the general page lists seven: methane, helium, hydrogen, oxygen, argon, nitrogen, LNG. Individual vessel compatibility lists can differ again. Preserve the disagreement; there is no verified current per-port seven-gas catalog.

### Oil and cargo fuel

[Oil](https://wiki.shippinglanes.net/wiki/Oil) requires buying barrels with the player's wallet, then selling at a port's current price. Full and custom quantities are available. **Oil Prices** works underway; **Manage Loads** provides trading and a switch to the cargo-fuel menu. Prices vary with time and reported trading volume. The wiki/update history claims a real-world-price influence; the feed, update interval, port offsets, and volume formula are not disclosed.

Crude refines at a reported **10:7** yield into cargo fuel. Stock is public and server-local; others can take it and it does not travel to another server with its producer. Cargo fuel uses its separate loading menu; exact withdrawal charging remains unresolved. Cargo fuel barrels are distinct from propulsion fuel. The oil page contradicts itself about refinery locations; its later section lists Newhaven, Norfolk, Macquarie, Midway, Douglas. The changelog explicitly confirms Norfolk's addition despite older port prose denying it. Processing rates, queue capacity, restart persistence, rounding, and exact withdrawal charges remain unverified.

### Ro-Ro vehicles

[Vehicles](https://wiki.shippinglanes.net/wiki/Vehicles) documents **1–3 representative cars** driven per loading operation, depending on vessel size; nominal capacity is not the number manually driven. Reported vehicle speeds are **91 km/h forward / 28 km/h reverse**. Terminals exist at Stanley, Ocean Fall, Newhaven, Emerald, Norfolk, Macquarie, and all four northern ports.

Ramp accessibility matters beyond simply receiving a dock prompt. Most terminals require stern alignment; Stanley has its own pier/port-side arrangement. Video V4 narrates three cars loaded and three unloaded on a 7,855-capacity Mark V/Mover. It also cancels loading to reposition the ramp. Water-loss penalties, timer, representative-car scaling, and partial completion remain unknown.

### Mixed container / Ro-Ro

[Multi Class Freighter](https://wiki.shippinglanes.net/wiki/Multi_Class_Freighter) carries **1,650 containers plus 6,200 vehicles simultaneously**. Loading is separate by service; a nearby terminal can determine which loading UI takes priority. Current page price is **$395M**, with listed rates **$410k container + $340k vehicle per NM**, replacing the first pass's historical $225M/$670k figures. The same page still contains an old 31-NM range sentence while its infobox says 43.3 NM.

### Heavy lifting

[Heavy Loads](https://wiki.shippinglanes.net/wiki/Heavy_Loads) are intact offshore objects picked up from beneath by submerging a lifter's deck, aligning, and raising it. Delivery uses offshore zones rather than normal cargo berths. Ports remain necessary for ship services. The [class page](https://wiki.shippinglanes.net/wiki/Heavy_Lifter_Class) confirms waypoint pickup and delivery; the changelog documents cross-region support and saving fixes.

| Lifter | Documented load families |
| --- | --- |
| Prototype | Barges, canal locks, concrete blocks; seasonal presents |
| Striker | Boat hulls, bridge sections, pipes |
| Goliath | Cranes, damaged ship, Western Isles FPSO; seasonal pumpkins/presents |
| Leviathan | Cranes, damaged ship, Goliat FPSO, oil rig; seasonal pumpkins/presents |
| Megalodon | Astra rig, cranes, damaged ship, fish farm, Goliat FPSO, oil rig; seasonal loads |
| Behemoth | Astra rig, cranes, damaged ship, Goliat FPSO; seasonal presents |

V1 adds caption evidence for a stopped/aligned raising check and transporting an occupied player ship. This is physical transport, not transfer of ship ownership. Complete payload weights, spawn coordinates, alignment tolerances, release thresholds, and failure penalties remain unavailable.

### Rockets

[Rocket Launch Ships](https://wiki.shippinglanes.net/wiki/Rocket_Launch_Ships) load paid contracts at Long Island, Newhaven, or Midway and sail to assigned offshore launch zones. UI sequence: **Ready Tower → Launch Rocket → View Rocket**, with switch-view and emergency-abort controls. Launch and recovery payments are separate; recovery failure forfeits its bonus while successful launch payment can remain. Early abort can forfeit launch payment.

Individual ship pages name these rocket compatibility sets:

| Launcher | Rocket models documented |
| --- | --- |
| [Space Launch Platform](https://wiki.shippinglanes.net/wiki/Space_Launch_Platform) | SpaceY Class, Atom, Toilet |
| [Exploration Launcher](https://wiki.shippinglanes.net/wiki/Exploration_Launcher) | SpaceY Class, Atom, Antaris, Tri-Rocket |
| [Very Large Launcher](https://wiki.shippinglanes.net/wiki/Very_Large_Launcher) | Sputnik Class, Ultra Heavy, Voyager |

Models are not interchangeable with mission names: narrated contracts include interplanetary probe, asteroid mission, moon lander, communication satellite, space telescope, and station module. V2/V3 show narrated failure percentages and optional recovery bonuses. Their money examples are snapshots affected by distance and possibly passes, not a universal contract table. Every model/mission pairing, price, probability, radius, countdown, and reward formula is still missing. The early-access moving-launch defect is explicitly superseded by the next version's fix.

## 7. Economy, trading, ownership, and persistence

| Cargo | Publicly documented earning relationship |
| --- | --- |
| Containers | Quoted destination reward; destination multiplier applies |
| Bulk/gas | Direct origin–destination distance × rate; origin/destination modifiers apply, with UI inclusion unresolved |
| Ro-Ro | Distance-based delivery; destination multiplier |
| Oil/fuel | Sale proceeds minus purchase cost; no port delivery multiplier |
| Heavy loads | Offshore job payment; no normal port multiplier |
| Rockets | Contract launch reward plus eligible recovery bonus, less upfront contract cost |

Net voyage economics also include propulsion fuel, damage repairs, component maintenance, and applicable transaction fees. Sailing circles does not increase bulk/gas payout. A reported profit/NM number is not guaranteed net income or a ship's hourly earning rate.

[Ship Trading](https://wiki.shippinglanes.net/wiki/Ship_Trading) uses a main-menu Trade button and same-server requests. One request can be active. Offers contain cash and up to four ships; selected ships can be removed before completion. Ships currently being sailed cannot be traded. It describes a **5% fee based on combined offer value**, deducted from both balances; exact per-side arithmetic remains insufficiently demonstrated.

The general value constraint is **50%–200%** between offers. Limited exemptions are inconsistent between this page, individual pages, and the update history. Used ships record odometer and prior-owner history. The statement that used ships have no performance difference must now be qualified by component condition; persistence of that condition through a trade has not been tested.

The historical shop resale rule is **30% of listed value**, corroborated by V8's advice but still not a fresh numeric transaction test. The old oil video uses a different resale percentage and must not set today's rule. The current limited-sale system also supports finite stock and special prices, distinct from ordinary catalog purchases.

The changelog documents cargo restoration after quitting/rejoining, a later heavy-load-saving fix, and furniture saved when edited. An older oil entry describes refunding purchased oil at acquisition value on exit/menu. These entries may interact or supersede one another: an exact cargo-by-cargo quit/menu/crash/transfer matrix remains unverified. Public progress is account-based in Roblox; that does not determine how our future Godot saves should work.

## 8. Ports, regions, waterways, and distances

The [current port overview](https://wiki.shippinglanes.net/wiki/Ports) contains **19 ports**, including Pine Island, and four DWT-restricted ports. Two playable regions are joined by a teleport prompt rather than a continuous ordinary voyage: sail north of Ocean Fall to Northern Isles, south to return. The [Northern Isles page](https://wiki.shippinglanes.net/wiki/Northern_Isles_Maps) identifies Midway, Wilmington, Douglas, Albany and currently says 27-player servers. Other listings disagree; the live cap remains unresolved.

The following table uses each **individual port infobox** for equipment counts and multiplier, retaining source links. A question mark means that page does not supply the field. Counts do not override cargo permission rules. Bayview's zero-crane infobox and Woodside's no-pipeline description conflict with claimed services. Norfolk refinery existence is confirmed by the changelog despite stale port text. Macquarie's infobox now says 0.88× while other descriptions retain 0.87×.

| Port | Multiplier | Container cranes | Bulk cranes | Pipelines | Vehicle terminal | Rockets | DWT limit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [Long Island](https://wiki.shippinglanes.net/wiki/Long_Island) | 1.00x | 3 | 5 | 1 | No | Yes | No listed cap |
| [Newport](https://wiki.shippinglanes.net/wiki/Newport) | 1.0x | 3 | 4 | 1 | No | No | No listed cap |
| [Norfolk Port](https://wiki.shippinglanes.net/wiki/Norfolk_Port) | 0.95× (overview) | — | — | — | — | — | No listed cap |
| [Rockfall Port](https://wiki.shippinglanes.net/wiki/Rockfall_Port) | 1.0x | 4 | 4 | 2 | No | No | No listed cap |
| [Stanley Harbor](https://wiki.shippinglanes.net/wiki/Stanley_Harbor) | 1.0x | 5 | 4 | 2 | Yes | No | No listed cap |
| [Newhaven Harbor](https://wiki.shippinglanes.net/wiki/Newhaven_Harbor) | 0.95x | 7 | 5 | 3 | Yes | Yes | No listed cap |
| [Emerald Harbor](https://wiki.shippinglanes.net/wiki/Emerald_Harbor) | 1.0x | 3 | 5 | 3 | Yes | No | No listed cap |
| [Bayview Port](https://wiki.shippinglanes.net/wiki/Bayview_Port) | 1.3 | 0 | 0 | 2 | No | No | 51,000 |
| [Lakeview Docks](https://wiki.shippinglanes.net/wiki/Lakeview_Docks) | 1.2x | 2 | 3 | 0 | No | No | 157,000 |
| [Jamestown](https://wiki.shippinglanes.net/wiki/Jamestown) | 1.2x | 0 | 4 | 0 | No | No | 157,000 |
| [Ocean Fall Port](https://wiki.shippinglanes.net/wiki/Ocean_Fall_Port) | 0.87x | 4 | 3 | 2 | Yes | No | No listed cap |
| [Woodside Inlet](https://wiki.shippinglanes.net/wiki/Woodside_Inlet) | 1.3x | 0 | 3 | 0 | No | No | 50,000 / 51,000 disputed |
| [Russell Station](https://wiki.shippinglanes.net/wiki/Russell_Station) | 0.91x | 1 | 2 | 1 | No | No | No listed cap |
| [Macquarie Harbor](https://wiki.shippinglanes.net/wiki/Macquarie_Harbor) | 0.88x | 6 | 6 | 1 | Yes | No | No listed cap |
| [Midway Harbor](https://wiki.shippinglanes.net/wiki/Midway_Harbor) | 1.0x | 10 | 6 | 2 | Yes (2) | Yes | No listed cap |
| [Wilmington Cove](https://wiki.shippinglanes.net/wiki/Wilmington_Cove) | 1x | 4 | 4 | 1 | Yes | No | No listed cap |
| [Douglas Harbor](https://wiki.shippinglanes.net/wiki/Douglas_Harbor) | 0.87x | 5 | 5 | 1 | 1 | No | No listed cap |
| [Albany Cove](https://wiki.shippinglanes.net/wiki/Albany_Cove) | 0.87x | 5 | 6 | 2 | Yes | No | No listed cap |
| [Pine Island](https://wiki.shippinglanes.net/wiki/Pine_Island) | 1x | 2 | 5 | 0 (can still be loaded) | No | No | No listed cap |


### Waterways and layout

[Panama Canal](https://wiki.shippinglanes.net/wiki/Panama_Canal) describes three locks and an elevated lake serving Stanley, Lakeview, and Jamestown. Request a cycle; entry gate closes, water levels equalize, opposite gate opens. Exit repeats the process in reverse. Gate collision, multi-player congestion, and deliberate blocking are documented. Exact chamber dimensions, timers, arbitration, and anti-block thresholds are not given.

The desert/Suez passage restricts very large loaded vessels by draft and geometry, not just class labels. Newhaven was deepened and Emerald enlarged in dated updates; older footage therefore cannot establish current clearance.

[Island Maps](https://wiki.shippinglanes.net/wiki/Island_Maps) provides overall and island images, but even its region list incorrectly places Emerald in the Northern Isles. Map pictures do not establish depth, world coordinates, collider boundaries, or an exact combined-region projection. The research does not include copied game assets or a recovered terrain mesh.

### Distance records

These figures are reported port-page distances, not certified path lengths. Row-source links are the individual ports above. Opposite directions may differ; **neither direction is silently overwritten or averaged**. “—” means no compatible table entry was retrieved. Port distances sometimes count a different origin/destination reference or predate map changes. Do not confuse direct payout distance with the navigable route length.

Column key: LI = Long Island, NP = Newport, NF = Norfolk Port, RF = Rockfall Port, ST = Stanley Harbor, NH = Newhaven Harbor, EM = Emerald Harbor, BV = Bayview Port, LV = Lakeview Docks, JT = Jamestown, OF = Ocean Fall Port, WS = Woodside Inlet, RS = Russell Station, MQ = Macquarie Harbor, MW = Midway Harbor, WC = Wilmington Cove, DH = Douglas Harbor, AC = Albany Cove, PI = Pine Island.


| From / to | LI | NP | NF | RF | ST | NH | EM | BV | LV | JT | OF | WS | RS | MQ | MW | WC | DH | AC | PI |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Long Island](https://wiki.shippinglanes.net/wiki/Long_Island) | 0 | 2.5 | 4.7 | 4.0 | 3.1 | 8.1 | 5.1 | 2.7 | 1.6 | 4.7 | 10.2 | 10.2 | 14.8 | 17.9 | 18.5 | 25.8 | 33.5 | 33.8 | 7.3 |
| [Newport](https://wiki.shippinglanes.net/wiki/Newport) | 2.5 | 0 | 3.9 | 3.5 | 2.0 | 7.2 | 7.2 | 5.2 | 2.7 | 3.4 | 12.4 | 9.2 | 13.8 | 15.5 | 19.3 | 27.8 | 35.0 | 35.9 | 9.8 |
| [Norfolk Port](https://wiki.shippinglanes.net/wiki/Norfolk_Port) | 4.7 | 3.9 | 0 | 7.4 | 6.0 | 11.2 | 9.8 | 6.0 | 5.9 | 7.3 | 14.7 | 13.0 | 10.1 | 14.4 | 23.0 | 30.3 | 38.1 | 38.3 | 9.4 |
| [Rockfall Port](https://wiki.shippinglanes.net/wiki/Rockfall_Port) | 4.0 | 3.5 | 7.4 | 0 | 1.4 | 4.0 | 5.7 | 6.4 | 2.5 | 1.2 | 10.7 | 6.1 | 17.3 | 17.6 | 15.9 | 25.4 | 32.0 | 33.5 | 10.9 |
| [Stanley Harbor](https://wiki.shippinglanes.net/wiki/Stanley_Harbor) | 3.1 | 2.0 | 6.0 | 1.4 | 0 | 5.3 | 6.2 | 5.7 | 1.9 | 1.6 | 11.4 | 7.3 | 15.8 | 16.6 | 17.4 | 26.4 | 33.3 | 35.5 | 10.3 |
| [Newhaven Harbor](https://wiki.shippinglanes.net/wiki/Newhaven_Harbor) | 8.1 | 7.0 | 10.5 | 4.0 | 5.2 | 0 | 8.3 | 10.3 | 6.5 | 3.8 | 12.3 | 2.0 | 20.5 | 18.6 | 13.7 | 25.4 | 30.7 | 34.5 | 14.6 |
| [Emerald Harbor](https://wiki.shippinglanes.net/wiki/Emerald_Harbor) | 5.1 | 7.2 | 9.8 | 4.9 | 6.2 | 8.3 | 0 | 4.5 | 4.5 | 7.0 | 6.8 | 10.2 | 19.8 | 22.7 | 14.4 | 20.6 | 28.3 | 28.7 | 7.1 |
| [Bayview Port](https://wiki.shippinglanes.net/wiki/Bayview_Port) | 2.7 | 5.2 | 6 | 6.4 | 5.7 | 10.3 | 4.5 | 0 | 3.9 | 7.2 | 8.9 | 12.4 | 15.5 | 20.2 | 18.9 | 24.5 | 32.7 | 32.4 | 4.6 |
| [Lakeview Docks](https://wiki.shippinglanes.net/wiki/Lakeview_Docks) | 1.6 | 2.5 | 5 | 2.5 | 1.9 | 6.5 | 4.5 | 5.5 | 0 | 3.4 | 9.78 | 7 | 16.1 | 18.2 | 17.12 | 25.13 | 32.25 | 33.2 | 8.4 |
| [Jamestown](https://wiki.shippinglanes.net/wiki/Jamestown) | 4.7 | 3.4 | 7.3 | 1.2 | 1.6 | 3.8 | 7.0 | 7.2 | 3.4 | 0 | 12.0 | 5.8 | 16.8 | 16.5 | 16.6 | 26.6 | 32.9 | 34.7 | 11.8 |
| [Ocean Fall Port](https://wiki.shippinglanes.net/wiki/Ocean_Fall_Port) | 10.2 | 12.4 | 14.7 | 10.7 | 11.4 | 12.3 | 5.2 | 8.9 | 9.8 | 12 | 0 | 13.8 | 24.4 | 28 | 12.6 | 15.6 | 20 | 23.6 | 8.8 |
| [Woodside Inlet](https://wiki.shippinglanes.net/wiki/Woodside_Inlet) | 10.2 | 9.2 | 13 | 6.1 | 7.3 | 2 | 10.2 | 12.4 | 8.6 | 5.8 | 13.8 | 0 | 22 | 19.1 | 13.3 | 25.9 | 30.4 | 33.8 | 16.7 |
| [Russell Station](https://wiki.shippinglanes.net/wiki/Russell_Station) | 14.8 | 13.8 | 10.1 | 17.3 | 15.8 | 20.5 | 19.8 | 15.5 | 16.1 | 16.8 | 24.4 | 22 | 0 | 12.1 | 33.1 | 40 | 48.1 | 47.8 | 17.1 |
| [Macquarie Harbor](https://wiki.shippinglanes.net/wiki/Macquarie_Harbor) | 17.9 | 15.5 | 14.4 | 17.6 | 16.6 | 18.6 | 22.7 | 20.2 | 18.2 | 16.5 | 28 | 19.1 | 12.1 | 0 | 32.3 | 43.1 | 49.1 | 51.2 | 23.9 |
| [Midway Harbor](https://wiki.shippinglanes.net/wiki/Midway_Harbor) | 18.5 | 19.3 | 23.0 | 15.9 | 17.4 | 13.7 | 14.4 | 18.9 | 17.1 | 16.6 | 12.6 | 13.3 | 33.1 | 32.3 | 0 | 14.9 | 17.1 | 21.9 | 20.9 |
| [Wilmington Cove](https://wiki.shippinglanes.net/wiki/Wilmington_Cove) | 25.8 | 27.8 | 30.3 | 25.4 | 26.4 | 25.4 | 20.6 | 24.5 | 25.1 | 26.6 | 15.6 | 25.9 | 40 | 43.1 | 14.9 | 0 | 10.6 | 8.0 | 23.4 |
| [Douglas Harbor](https://wiki.shippinglanes.net/wiki/Douglas_Harbor) | 33.3 | 34.9 | 38.1 | 31.9 | 33.1 | 30.6 | 23.3 | 32.7 | 32.3 | 32.8 | 24.0 | 30.4 | 48.1 | 49.1 | 17.1 | 10.6 | 0 | 9.7 | 32,6 |
| [Albany Cove](https://wiki.shippinglanes.net/wiki/Albany_Cove) | 33.8 | 35.9 | 40.8 | 33.5 | 34.5 | 33.4 | 28.7 | 32.4 | 33.2 | 34.7 | 23.6 | 33.8 | 47.8 | 51.2 | 21.9 | 8 | 9.7 | 0 | 31 |
| [Pine Island](https://wiki.shippinglanes.net/wiki/Pine_Island) | 7.3 | 9.8 | 9.4 | 10.9 | 10.3 | 14.6 | 7.1 | 4.6 | 8.4 | 11.8 | 8.8 | 16.7 | 17.1 | 23.9 | 20.9 | 23.4 | 32.6 | 31 | 0 |


## 9. Customization, aircraft, social features, and rewards

[Furniture](https://wiki.shippinglanes.net/wiki/Furniture) supports functional helm seats, passenger seating, decor, lights, doors/walls/floors, utility props, regional map displays, distance leaderboards, and a Classic-game portal. Its 83-item count is explicitly dated February 2025; it is not a certified October total. The current catalog prices Integrated Bridge System at **$300,000**, disagreeing with the first pass's historical $5M. Replacing all controls with none causes the default chair to return.

Dated changelog entries establish recoloring, material choices, wall/console snapping, and an option letting other players edit a ship. A historical furniture limit of **600** is recorded; its current applicability and interaction with the 1000-KB account cap are untested. Rotation increments, placement bounds, undo/refund behavior, and edit-permission persistence remain unknown. Decorative kitchen/fire/ping-pong props are not evidence of cooking, firefighting, or a playable table-tennis system.

[Midway Class Carrier](https://wiki.shippinglanes.net/wiki/Midway_Class_Carrier) has no paying cargo. It spawns F-18 (580 knots) or C-2 Greyhound (200 knots, five passenger seats), one plane per player; spawning another removes the previous. Two blast deflectors, three lifts, interior gates, and a stern gate are documented. V6 adds narrated anchor/spawner toggles, engine/throttle, landing gear, and stall warnings, but not reliable key bindings. The staff carrier instead provides Hellcat/Spitfire aircraft. Public Liberty's firing turrets are cosmetic and do not inflict damage; staff Montana also has non-damaging firing weapons.

Gauntlet and Great Eastern combine engines with deployable sails. Sails avoid engine fuel use; documented sails-only speed is 17 knots and engine travel 23, but combined boost and wind dependence are not fully specified. Gauntlet direct acquisition is limited to one per account, with additional copies through trading. The quest's complete steps remain unverified because its video has no usable captions and visual playback failed.

[Badges](https://wiki.shippinglanes.net/wiki/Badges) lists 15, four unavailable. Active criteria include first join, tutorial, desert canal, 21,638 NM, meeting a developer, volcano event, Antarctic summit, launching and recovering a rocket, and Seawise/Quad-A ownership. Historical unavailable awards are Alpha Tester, Triple-E ownership, Maximus ownership, and Megalodon ownership. The page says traded ships can trigger applicable ownership badges after spawning. Exact current badge service state has not been independently checked.

Weather includes clear, cloudy, rain, storm, and fog states; a disable-weather option replaced disable-rain. Visual waves and storms exist, but current wind/current/sea-state physics are undocumented. The volcano has an event badge; old descriptions call its effects harmless. Day/night duration and weather transition probabilities remain unknown.

Historical [sound documentation](https://roblox-shipping-lanes.fandom.com/wiki/Sounds_Effects) reports 16 horns, 12 pass-gated, plus spatial engine/horn/collision audio, waves, weather, volcano, vehicle/aircraft engines and gear effects. That is not a verified current sound catalog; the electric ferry is a documented engine-audio exception.

Player companies/shared company liveries are **retired**, with removal documented in 2.6.4. Old videos showing company menus are historical. Ship trading, passengers, peer visibility, and optional editing are separate from a verified crew/shared-income feature. Chat permissions, voice availability, and exact player/ship replication rules are not established.

## 10. Store and Roblox-specific systems

The current [Robux Shop](https://wiki.shippinglanes.net/wiki/Robux_Shop) lists the following passes; prices are source snapshots and can change:

| Pass | Robux | Reported effect |
| --- | --- | --- |
| 125% Throttle | 699 | Increased speed and fuel use |
| 1.5× Money | 3,150 | Multiplies earnings and oil/fuel acquisition costs |
| Half Price Fuel | 149 | 50% propulsion refueling discount |
| Flags | 45 | Country flags through modification menu |
| Survival Gear | 39 | Firework launcher, flashlight, whistle, flare |
| Binoculars | 39 | Binocular tool |
| More Ship Horns | 299 | Expanded horn selection |
| No Rocket Failures | 299 | Advertised safe rocket launches; recovery scope untested |

Other documented categories are cash bundles, random ship crates, direct ship packs, repeat-use refuel, maintenance repair-all, rewarded repair/refuel ads, and finite-stock limited sales. Crate listings are unreliable: the 65-Robux probabilities sum to **85%**, and the 300-Robux list sums to **101%**. They cannot serve as complete probability distributions. Geographic eligibility, duplicates, exact award processing, and current crate contents require live confirmation. None of this is a monetization proposal for Godot.

## 11. Current ship statistics — individual-page snapshot

Each linked row is sourced to that ship's page. We preserve its reported **base speed**, endurance, fuel, range, DWT, rate, and price rather than deriving missing values. Parenthetical boosted speeds are omitted; the current pass generally multiplies base speed by 1.25. Historical or special exceptions need checking.

**Capacity field:** containers for container ships; **hold count** for bulk; barrels for oil; m³ for gas; vehicles for Ro-Ro; payload tons for heavy lifters. These units are deliberately not merged. DWT is a separate reported field. For missing infobox capacity only, a value from the aggregate row is tagged “list”. Blank means unavailable, not zero. Approximate profit/NM is not a complete payout algorithm. Limited prices are historical acquisition values, not a guarantee the ship is currently for sale.

Individual pages frequently conflict with aggregate tables. The conflict register identifies material cases; the table is a sourced candidate dataset, not a live-measured configuration.


### Container


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Small Container Ship](https://wiki.shippinglanes.net/wiki/Small_Container_Ship) | 8 | 23 | 24 | 3 | 20.8 | 500 | $200 / NM | $0 |
| [Long Trade Ship](https://wiki.shippinglanes.net/wiki/Long_Trade_Ship) | 16 | 22 | 26 | 6 | 22.1 | 1,500 | $380 / NM | $1,950 |
| [Inland Container Carrier](https://wiki.shippinglanes.net/wiki/Inland_Container_Carrier) | 24 | 22 | 26 | 6 | 22.1 | 1,500 | $400 / NM | $2,550 |
| [York Container Ship](https://wiki.shippinglanes.net/wiki/York_Container_Ship) | 50 | 32 | 30 | 10 | 37.1 | 1,000 | $690 / NM | $6,950 |
| [Perth Class](https://wiki.shippinglanes.net/wiki/Perth_Class) | 60 | 22 | 32 | 32 | 26.5 | 3,000 | $2,012 / NM | $25,000 |
| [Medium Container Ship](https://wiki.shippinglanes.net/wiki/Medium_Container_Ship) | 146 | 20 | 32 | 49 | 24.6 | 7,000 | $3,351 / NM | $55,268 |
| [Zenlift Container Ship](https://wiki.shippinglanes.net/wiki/Zenlift_Container_Ship) | 420 | 21 | 68 | 480 | 53.8 | 24,000 | $8,200 / NM | $180,000 |
| [Legacy Container Ship](https://wiki.shippinglanes.net/wiki/Legacy_Container_Ship) | 105 | 23 | 20 | 1,000 | 17.3 | 20,100 | $100,000 / NM | Alpha Tester Reward |
| [Legacy Explorer](https://wiki.shippinglanes.net/wiki/Legacy_Explorer) | 316 | 23 | 22 | 1,800 | 19.5 | 40,100 | $200,000 / NM | Alpha Tester Reward |
| [SL-7](https://wiki.shippinglanes.net/wiki/SL-7) | 576 | 30 | 20 | 1,800 | 22.6 | 50,100 | $140,000 / NM | $0* |
| [Panamax-Class Container Ship](https://wiki.shippinglanes.net/wiki/Panamax-Class_Container_Ship) | 1,022 | 22 | 52 | 1,600 | 43.1 | 61,500 | $89,000 / NM | $4,500,000 |
| [T2 Container Ship](https://wiki.shippinglanes.net/wiki/T2_Container_Ship) | 199 | 21 | 32 | 1,800 | 25.3 | 50,000 | $230,000 / NM | $51,000,000 |
| [Atlantic Class](https://wiki.shippinglanes.net/wiki/Atlantic_Class) | 3,936 | 20 | 35 | 7,000 | 26.4 | 196,000 | $582,500 / NM | $110,000,000 |
| [Container Boat](https://wiki.shippinglanes.net/wiki/Container_Boat) | 1 | 29 | 24 | 3 | 26.2 | 5 | $169,000 / NM | $125,000 |
| [Mighty Class](https://wiki.shippinglanes.net/wiki/Mighty_Class) | 3,722 | 26 | 40 | 7,000 | 39.2 | 158,200 | $690,000 / NM | $210,000,000 |
| [Voyager Container Ship](https://wiki.shippinglanes.net/wiki/Voyager_Container_Ship) | 1,466 | 38 | 60 | 12,000 | 85.9 | 53,634 | $500,000 / NM | $299,000,000 (Offsale) |
| [Quad-A Class](https://wiki.shippinglanes.net/wiki/Quad-A_Class) | 6,120 | 22 | 36 | 11,000 | 30.4 | 200,000 | $790,000 / NM | $310,000,000 |
| [Maximus Class](https://wiki.shippinglanes.net/wiki/Maximus_Class) | 6,752 | 22 | 37 | 7,000 | 31.4 | 225,000 | $905,000 / NM | $509,500,000 |
| [Colossus Class](https://wiki.shippinglanes.net/wiki/Colossus_Class) | 14,016 | 20 | 82 | 37,000 | 62 | 625,000 | $1,590,000 / NM | $1,500,000,000 |
| [Covered Container](https://wiki.shippinglanes.net/wiki/Covered_Container_Ship) | 25 (list) | 36 | 50 | 500 | 67.8 | 5,000 | $469,000 / NM | $30,000,000,000 |


### Bulk


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Small Bulk Carrier](https://wiki.shippinglanes.net/wiki/Small_Bulk_Carrier) | 1 holds | 23 | 24 | 3 | 20.8 | 600 | $400 / NM | $0 |
| [York Bulk Carrier](https://wiki.shippinglanes.net/wiki/York_Bulk_Carrier) | 5 holds | 32 | 30 | 10 | 37.1 | 2,000 | $690 / NM | $5,950 |
| [Mini Bulk Carrier](https://wiki.shippinglanes.net/wiki/Mini_Bulk_Carrier) | 1 holds | 26 | 26 | 20 | 26.1 | 9,000 | $1,015 / NM | $13,500 |
| [Handysize](https://wiki.shippinglanes.net/wiki/Handysize) | 5 holds | 23 | 30 | 150 | 26 | 35,000 | $7,351 / NM | $105,470 |
| [Lloyd-Class Ore Carrier](https://wiki.shippinglanes.net/wiki/Lloyd-Class_Ore_Carrier) | 4 holds | 23 | 20 | 310 | 17.9 | 50,000 | $23,351 / NM | $560,000 |
| [Handymax](https://wiki.shippinglanes.net/wiki/Handymax) | 5 holds | 21 | 24 | 300 | 19 | 45,000 | $28,840 / NM | $760,000 |
| [Supramax](https://wiki.shippinglanes.net/wiki/Supramax) | 5 holds | 20 | 26 | 600 | 19.7 | 60,000 | $46,000 / NM | $1,200,000 |
| [Panamax Bulk Carrier](https://wiki.shippinglanes.net/wiki/Panamax_Bulk_Carrier) | 7 holds | 19 | 32 | 1,600 | 23.3 | 75,000 | $75,500 / NM | $2,400,000 |
| [Stanley Class Freighter](https://wiki.shippinglanes.net/wiki/Stanley_Class_Freighter) | 15 holds | 23 | 35 | 3,200 | 30.8 | 80,000 | $97,500 / NM | $4,400,000 |
| [Hobart Class Freighter](https://wiki.shippinglanes.net/wiki/Hobart_Class_Freighter) | 13 holds | 23 | 38 | 4,200 | 33.1 | 88,000 | $160,000 / NM | $11,500,000 |
| [Transit Class Freighter](https://wiki.shippinglanes.net/wiki/Transit_Class_Freighter) | 1 holds | 22 | 45 | 5,200 | 37.5 | 94,000 | $200,000 / NM | $25,400,000 |
| [Capesize](https://wiki.shippinglanes.net/wiki/Capesize) | 9 holds | 19 | 51 | 4,200 | 37 | 156,000 | $340,000 / NM | $46,000,000 |
| [Very Large Ore Carrier](https://wiki.shippinglanes.net/wiki/Very_Large_Ore_Carrier) | 7 holds | 18 | 40 | 8,000 | 27.1 | 400,000 | $430,000 / NM | $75,406,000 |
| [Hull 1173](https://wiki.shippinglanes.net/wiki/Hull_1173) | 1 holds | 28 | 38 | 4,200 | 40.3 | 28,000 | $767,500 / NM | $125,000,000 (Offsale), 9,750,000,000 (limited sale) |
| [Liberty Bulker](https://wiki.shippinglanes.net/wiki/Liberty_Bulker) | 4 holds | 28 | 38 | 4,200 | 40.3 | 68,000 | $469,000 / NM | $135,409,000 |
| [Gauntlet Cargo Liner](https://wiki.shippinglanes.net/wiki/Gauntlet_Cargo_Liner) | 4 holds | 17 | 24 | 300 | 20.8 | 10,000 | $449,500 / NM | $150,000,000 |
| [Seamini Ore Carrier](https://wiki.shippinglanes.net/wiki/Seamini_Ore_Carrier) | 2 holds | 30 | 78 | 39,000 | 88.2 | 214,763 | $767,500 / NM | $445,000,000 (Offsale) |
| [Seamax Ore Carrier](https://wiki.shippinglanes.net/wiki/Seamax_Ore_Carrier) | 9 holds | 18 | 57 | 20,000 | 38.8 | 614,763 | $767,500 / NM | $245,000,000 |
| [Grand Ore Carrier](https://wiki.shippinglanes.net/wiki/Grand_Ore_Carrier) | 10 holds | 17 | 83 | 50,000 | 53.4 | 999,000 | $1,170,000 / NM | $716,000,000 |
| [S.S Great Eastern](https://wiki.shippinglanes.net/wiki/S.S_Great_Eastern) | 4 holds | 23 | 24 | 300 | 20.8 | 800 | $990,000 / NM | $1,700,000,000 |


### Oil


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [General Purpose](https://wiki.shippinglanes.net/wiki/General_Purpose) | 2,500 Barrels | 24 | 40 | 200 | 36.2 | 18,700 | — | $298,000 |
| [Aframax](https://wiki.shippinglanes.net/wiki/Aframax) | 6,000 Barrels | 22 | 33 | 1,000 | 27.6 | 90,000 | — | $999,500 |
| [T2 Oil Tanker](https://wiki.shippinglanes.net/wiki/T2_Oil_Tanker) | 12,000 Barrels | 20 | 34 | 2,400 | 25.8 | 55,000 | — | $3,000,000 |
| [Suezmax Tanker](https://wiki.shippinglanes.net/wiki/Suezmax_Tanker) | 13,000 Barrels | 20 | 30 | 2,000 | 23.2 | 125,000 | — | $4,000,000 |
| [Legacy Seawise Giant](https://wiki.shippinglanes.net/wiki/Legacy_Seawise_Giant) | 45,000 (list) | 20.5 | 40 | 4,000 | 30.9 | 170,500 | — | Alpha Tester Reward |
| [Very Large Crude Carrier](https://wiki.shippinglanes.net/wiki/Very_Large_Crude_Carrier) | 28,000 Barrels | 18 | 37 | 3,000 | 25.4 | 156,000 | — | $15,000,000 |
| [Ultra Large Crude Carrier](https://wiki.shippinglanes.net/wiki/Ultra_Large_Crude_Carrier) | 70,000 Barrels | 17 | 33 | 5,000 | 21.4 | 441,893 | — | $47,000,000 |
| [Seawise-Giant](https://wiki.shippinglanes.net/wiki/Seawise-Giant) | 130,000 Barrels | 16.5 | 48 | 12,000 | 29.8 | 564,763 | — | $190,000,000 |
| [Batillus Supertanker](https://wiki.shippinglanes.net/wiki/Batillus_Supertanker) | 193,500 Barrels | 20 | 64 | 16,000 | 48.2 | 630,962 | — | $250,000,000 |
| [Extremely Large Crude Carrier](https://wiki.shippinglanes.net/wiki/Extremely_Large_Crude_Carrier) | 395,000 Barrels | 16 | 66 | 40,000 | 40.2 | 995,900 | — | $1,294,500,000 |


### Gas


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Q-Mini LNG Carrier](https://wiki.shippinglanes.net/wiki/Q-Mini_LNG_Carrier) | 34,000 m³ | 25 | 20 | 1,500 | 18.8 | 17,800 | $145,000 / NM | $20,000,000 |
| [Conventional LNG Carrier](https://wiki.shippinglanes.net/wiki/Conventional_LNG_Carrier) | 147,835 m³ | 23 | 36 | 4,500 | 31.2 | 84,878 | $330,000 / NM | $55,548,000 |
| [Gem Class LNG Carrier](https://wiki.shippinglanes.net/wiki/Gem_Class_LNG_Carrier) | 195,000 m³ | 19 | 33 | 5,000 | 23.9 | 94,028 | $430,000 / NM | $76,700,000 |
| [Absolute LNG Carrier](https://wiki.shippinglanes.net/wiki/Absolute_LNG_Carrier) | 316,660 m³ | 20 | 34 | 6,000 | 25.8 | 163,922 | $580,000 / NM | $110,000,000 |
| [Prometheus Class](https://wiki.shippinglanes.net/wiki/Prometheus_Class) | 490,000 m³ | 22 | 53 | 16,000 | 44.2 | 463,522 | $790,000 / NM | $330,000,000 |


### Vehicle-Transport


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [High Speed Transporter](https://wiki.shippinglanes.net/wiki/High_Speed_Transporter) | 6 (list) | 50 | 40 | 200 | 75.4 | 1,000 | $7,800 / NM | $490,000 |
| [Electrified Ferry](https://wiki.shippinglanes.net/wiki/Electrified_Ferry) | 15 (list) | 32 | 40 | 200 | 48.2 | 2,000 | $97,500 / NM | $7,942,000 |
| [Trimaran Cargo Transporter](https://wiki.shippinglanes.net/wiki/Trimaran_Cargo_Transporter) | 50 (list) | 45 | 20 | 1,400 | 33.9 | 3,500 | $89,000 / NM | $9,942,000 |
| [Space Class Transporter](https://wiki.shippinglanes.net/wiki/Space_Class_Transporter) | 950 (list) | 23 | 37 | 3,000 | 32.5 | 21,820 | $220,000 / NM | $38,530,000 |
| [King Class Transporter](https://wiki.shippinglanes.net/wiki/King_Class_Transporter) | 3,453 (list) | 23 | 36 | 4,500 | 31.2 | 25,820 | $350,000 / NM | $55,000,000 |
| [Mover Class Transporter](https://wiki.shippinglanes.net/wiki/Mover_Class_Transporter) | 7,855 (list) | 20 | 25.8 | 6,000 | 34 | 41,820 | $670,000 / NM | $159,000,000 |


### Heavy Lifter


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Prototype Heavy Lifter](https://wiki.shippinglanes.net/wiki/Prototype_Heavy_Lifter) | 20,000 Tons | 24 | 47 | 4,000 | 42.6 | 41,820 | $290,000 / NM | $46,000,000 |
| [Striker Heavy Lifter](https://wiki.shippinglanes.net/wiki/Striker_Heavy_Lifter) | 300,000 Tons | 28 | 60 | 6,000 | 63.3 | 43,220 | $375,000 / NM | $90,000,000 |
| [Goliath Heavy Lifter](https://wiki.shippinglanes.net/wiki/Goliath_Heavy_Lifter) | 40,000 Tons | 22 | 47 | 8,000 | 39 | 81,490 | $695,000 / NM | $199,000,000 |
| [Leviathan Heavy Lifter](https://wiki.shippinglanes.net/wiki/Leviathan_Heavy_Lifter) | 60,000 Tons | 18 | 50 | 10,000 | 33.9 | 116,173 | $815,000 / NM | $400,000,000 |
| [Behemoth Heavy Lifter](https://wiki.shippinglanes.net/wiki/Behemoth_Heavy_Lifter) | 60,000 Tons | 25 | 80 | 10,000 | 75.4 | 116,173 | $1,000,000 / NM | $530,000,000 |
| [Megalodon Heavy Lifter](https://wiki.shippinglanes.net/wiki/Megalodon_Heavy_Lifter) | 60,000 Tons | 18 | 66 | 10,000 | 45.2 | 116,173 | $1,050,000 / NM | $630,000,000 |


### Con-Ro


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Multi Class Freighter](https://wiki.shippinglanes.net/wiki/Multi_Class_Freighter) | 1,650 | 23 | 50 | 10,000 | 43.3 | 100,430 | $410,000 (Containers), $340,000 (Vehicles) / NM | $395,000,000 |


### Rocket Launcher


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Space Launch Platform](https://wiki.shippinglanes.net/wiki/Space_Launch_Platform) | — | 19 | 55 | 5,000 | 39.8 | 25,000 | $592,500 / NM | $160,000,000 |
| [Exploration Launcher](https://wiki.shippinglanes.net/wiki/Exploration_Launcher) | — | 23 | 80 | 12,000 | 69.3 | 6,500 | $867,500 / NM | $321,000,000 |
| [Very Large Launcher](https://wiki.shippinglanes.net/wiki/Very_Large_Launcher) | — | 21 | 66 | 50,000 | 52.8 | 175,000 | $1,500,000 / NM | $929,253,000 |


### Misc


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Midway Class Carrier](https://wiki.shippinglanes.net/wiki/Midway_Class_Carrier) | — | 32 | 40 | 12,000 | 48.2 | 64,000 | — | $3,980,000,000 |


### Developer


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [HMAS Hobart](https://wiki.shippinglanes.net/wiki/HMAS_Hobart) | — | 38 | 37 | 4,500 | 53.7 | 15,000 | — | Not for Sale; Tradeable |
| [Noah's Ark](https://wiki.shippinglanes.net/wiki/Noah%27s_Ark) | — | 35 | 40 | 1,000 | 52.8 | 20,000 | — | Not for Sale; Tradeable |
| [Montana](https://wiki.shippinglanes.net/wiki/Montana) | — | 30 | 110 | 12,200 | 125.4 | 156,000 | — | Not for Sale; Not Tradeable |
| [Submarine Racer](https://wiki.shippinglanes.net/wiki/Submarine_Racer) | — | 1000 | 200 | 15,000 | 7536.1 | 600 | — | Not for Sale; Not Tradeable |
| [Carrier](https://wiki.shippinglanes.net/wiki/Carrier) | — | 36 | 40 | 6,000 | 54.3 | 45,000 | — | Not for Sale; Tradeable |
| [Virginia Class Submarine](https://wiki.shippinglanes.net/wiki/Virginia_Class_Submarine) | — | 50 | 122 | 12,200 | 229.9 | 15,000 | — | Not for Sale; Not Tradeable |
| [Baden-Wurttenberg](https://wiki.shippinglanes.net/wiki/Baden-Wurttenberg) | — | 40 | — | ∞ | — | — | — | Not for Sale; Not Tradeable |
| [Brick](https://wiki.shippinglanes.net/wiki/Brick) | — | 50 | 40 | 400 | 75.4 | 10,000 | — | Not for Sale; Tradeable |


### Retired


| Ship | Capacity / holds | Knots | Endurance min | Fuel tons | Range NM | DWT tons | Reported rate | Price / acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Long Container Ship (Retired)](https://wiki.shippinglanes.net/wiki/Long_Container_Ship_(Retired)) | 16 (list) | 22 | — | — | — | — | — | $$1,950 |
| [Short Trade Ship (Retired)](https://wiki.shippinglanes.net/wiki/Short_Trade_Ship_(Retired)) | 6 (list) | 32 | — | — | — | — | $10 - 15k / NM | $$18,000 |
| [Large Container Ship (Retired)](https://wiki.shippinglanes.net/wiki/Large_Container_Ship_(Retired)) | 105 (list) | 20 | — | — | — | — | $230k / NM | $$580,000 |
| [Explorer (Retired)](https://wiki.shippinglanes.net/wiki/Explorer_(Retired)) | 316 (list) | 21.5 | — | — | — | — | $$500,000/ NM / NM | $$3,800,000 |
| [E-Class](https://wiki.shippinglanes.net/wiki/E-Class) | 3,722 (list) | 23 | — | 7,000 | — | — | $$435,625 / NM | $$75,000,000 |
| [A-Class Container Ship](https://wiki.shippinglanes.net/wiki/A-Class_Container_Ship) | 382 (list) | 20 | — | 200 | — | — | $$13,351 / NM | $$283,000 |
| [Triple-E](https://wiki.shippinglanes.net/wiki/Triple-E) | 4,349 | 20 | — | 7,000 | — | — | $592,500 / NM | $110,000,000 |
| [B-Class](https://wiki.shippinglanes.net/wiki/B-Class) | 1,466 (list) | 32 | — | 2,000 | 14,50 Nm | — | $$190,000 / NM | $$39,000,000 |
| [Cape-Class Coast Guard Cutter (Retired)](https://wiki.shippinglanes.net/wiki/Cape-Class_Coast_Guard_Cutter_(Retired)) | 0 (list) | 50 | — | 1,500 | — | — | — | $Not for Sale; Tradeable |
| [Sailing Yacht (Retired)](https://wiki.shippinglanes.net/wiki/Sailing_Yacht_(Retired)) | 0 (list) | 25 | — | 1,000 | — | — | — | $Not for Sale; Tradeable |


## 12. Per-ship repair prices

Reported cost **per percentage point restored**, in game currency. These are individual-page rates, not calculated from purchase price. The documented maintenance menu selects components separately. A blank is unavailable. Outliers and possible typos are intentionally retained.


| Ship | Engine | Hull | Machinery |
| --- | --- | --- | --- |
| [Small Container Ship](https://wiki.shippinglanes.net/wiki/Small_Container_Ship) | $0 | $0 | $0 |
| [Long Trade Ship](https://wiki.shippinglanes.net/wiki/Long_Trade_Ship) | $2 | $7 | $1 |
| [Inland Container Carrier](https://wiki.shippinglanes.net/wiki/Inland_Container_Carrier) | $3 | $10 | $1 |
| [York Container Ship](https://wiki.shippinglanes.net/wiki/York_Container_Ship) | $10 | $17 | $3 |
| [Perth Class](https://wiki.shippinglanes.net/wiki/Perth_Class) | $37 | $100 | $12 |
| [Medium Container Ship](https://wiki.shippinglanes.net/wiki/Medium_Container_Ship) | $82 | $221 | $27 |
| [Zenlift Container Ship](https://wiki.shippinglanes.net/wiki/Zenlift_Container_Ship) | $270 | $720 | $90 |
| [Legacy Container Ship](https://wiki.shippinglanes.net/wiki/Legacy_Container_Ship) | $45,000 | $120,000 | $15,000 |
| [SL-7](https://wiki.shippinglanes.net/wiki/SL-7) | $63,000 | $168,000 | $21,000 |
| [Panamax-Class Container Ship](https://wiki.shippinglanes.net/wiki/Panamax-Class_Container_Ship) | $6,750 | $16,704 | $2,250 |
| [T2 Container Ship](https://wiki.shippinglanes.net/wiki/T2_Container_Ship) | $76,500 | $204,000 | $25,500 |
| [Atlantic Class](https://wiki.shippinglanes.net/wiki/Atlantic_Class) | $165,000 | $440,000 | $55,000 |
| [Container Boat](https://wiki.shippinglanes.net/wiki/Container_Boat) | $76,050 | $202,800 | $23,350 |
| [Mighty Class](https://wiki.shippinglanes.net/wiki/Mighty_Class) | $310,500 | $828,000 | $103,500 |
| [Voyager Container Ship](https://wiki.shippinglanes.net/wiki/Voyager_Container_Ship) | $225,000 | $600,000 | $75,000 |
| [Quad-A Class](https://wiki.shippinglanes.net/wiki/Quad-A_Class) | $335,500 | $948,000 | $118,500 |
| [Maximus Class](https://wiki.shippinglanes.net/wiki/Maximus_Class) | $407,250 | $1,086,000 | $135,750 |
| [Colossus Class](https://wiki.shippinglanes.net/wiki/Colossus_Class) | $715,500 | $1,908,000 | $238,500 |
| [Handysize](https://wiki.shippinglanes.net/wiki/Handysize) | $158 | $421 | $52 |
| [Handymax](https://wiki.shippinglanes.net/wiki/Handymax) | $1,140 | $3,040 | $380 |
| [Supramax](https://wiki.shippinglanes.net/wiki/Supramax) | $1,800 | $4,800 | $600 |
| [Panamax Bulk Carrier](https://wiki.shippinglanes.net/wiki/Panamax_Bulk_Carrier) | $3,600 | $9,600 | $1,200 |
| [Stanley Class Freighter](https://wiki.shippinglanes.net/wiki/Stanley_Class_Freighter) | $6,600 | $17,600 | $2,200 |
| [Hobart Class Freighter](https://wiki.shippinglanes.net/wiki/Hobart_Class_Freighter) | $17,250 | $46,000 | $5,750 |
| [Capesize](https://wiki.shippinglanes.net/wiki/Capesize) | $69,000 | $184,000 | $23,000 |
| [Very Large Ore Carrier](https://wiki.shippinglanes.net/wiki/Very_Large_Ore_Carrier) | $113,109 | $301,624 | $37,703 |
| [Hull 1173](https://wiki.shippinglanes.net/wiki/Hull_1173) | $345,375 | $921,000 | $115,125 |
| [Liberty Bulker](https://wiki.shippinglanes.net/wiki/Liberty_Bulker) | $203,113 | $541,636 | $67,704 |
| [Gauntlet Cargo Liner](https://wiki.shippinglanes.net/wiki/Gauntlet_Cargo_Liner) | $202,275 | $539,400 | $67,425 |
| [Seamini Ore Carrier](https://wiki.shippinglanes.net/wiki/Seamini_Ore_Carrier) | $345,375 | $921,000 | $115,125 |
| [Seamax Ore Carrier](https://wiki.shippinglanes.net/wiki/Seamax_Ore_Carrier) | $345,375 | $921,000 | $115,125 |
| [Grand Ore Carrier](https://wiki.shippinglanes.net/wiki/Grand_Ore_Carrier) | $526,500 | $1,404,000 | $175,500 |
| [S.S Great Eastern](https://wiki.shippinglanes.net/wiki/S.S_Great_Eastern) | $445,500 | $1,188,000 | $148,500 |
| [General Purpose](https://wiki.shippinglanes.net/wiki/General_Purpose) | $447 | $1,192 | $149 |
| [Aframax](https://wiki.shippinglanes.net/wiki/Aframax) | $1,499 | $3,998 | $499 |
| [T2 Oil Tanker](https://wiki.shippinglanes.net/wiki/T2_Oil_Tanker) | $4,500 | $12,000 | $1,500 |
| [Suezmax Tanker](https://wiki.shippinglanes.net/wiki/Suezmax_Tanker) | $5,850 | $15,600 | $1,950 |
| [Very Large Crude Carrier](https://wiki.shippinglanes.net/wiki/Very_Large_Crude_Carrier) | $12,600 | $33,600 | $4,200 |
| [Ultra Large Crude Carrier](https://wiki.shippinglanes.net/wiki/Ultra_Large_Crude_Carrier) | $31,500 | $84,000 | $10,500 |
| [Seawise-Giant](https://wiki.shippinglanes.net/wiki/Seawise-Giant) | $55,693 | $96,583 | $19,500 |
| [Batillus Supertanker](https://wiki.shippinglanes.net/wiki/Batillus_Supertanker) | $87,075 | $232,200 | $29,025 |
| [Extremely Large Crude Carrier](https://wiki.shippinglanes.net/wiki/Extremely_Large_Crude_Carrier) | $177,750 | $474,000 | $59,250 |
| [Q-Mini LNG Carrier](https://wiki.shippinglanes.net/wiki/Q-Mini_LNG_Carrier) | $30,000 | $80,000 | $10,000 |
| [Conventional LNG Carrier](https://wiki.shippinglanes.net/wiki/Conventional_LNG_Carrier) | $83,322 | $222,192 | $27,774 |
| [Gem Class LNG Carrier](https://wiki.shippinglanes.net/wiki/Gem_Class_LNG_Carrier) | $115,050 | $306,800 | $38,350 |
| [Absolute LNG Carrier](https://wiki.shippinglanes.net/wiki/Absolute_LNG_Carrier) | $165,000 | $440,000 | $55,000 |
| [Prometheus Class](https://wiki.shippinglanes.net/wiki/Prometheus_Class) | $355,500 | $948,000 | $118,500 |
| [High Speed Transporter](https://wiki.shippinglanes.net/wiki/High_Speed_Transporter) | $735 | $1,960 | $245 |
| [Electrified Ferry](https://wiki.shippinglanes.net/wiki/Electrified_Ferry) | 1,234$ | 1,313$ | 406$ |
| [Trimaran Cargo Transporter](https://wiki.shippinglanes.net/wiki/Trimaran_Cargo_Transporter) | 14,913$ | 20,700$ | 4,971$ |
| [Space Class Transporter](https://wiki.shippinglanes.net/wiki/Space_Class_Transporter) | $57,795 | $154,120 | $19,265 |
| [King Class Transporter](https://wiki.shippinglanes.net/wiki/King_Class_Transporter) | 82,500$ | 149,281$ | 27,500$ |
| [Mover Class Transporter](https://wiki.shippinglanes.net/wiki/Mover_Class_Transporter) | $238,500 | $636,000 | $79,500 |
| [Prototype Heavy Lifter](https://wiki.shippinglanes.net/wiki/Prototype_Heavy_Lifter) | $69,000 | $184,000 | $23,000 |
| [Goliath Heavy Lifter](https://wiki.shippinglanes.net/wiki/Goliath_Heavy_Lifter) | $298,500 | $796,000 | $99,500 |
| [Leviathan Heavy Lifter](https://wiki.shippinglanes.net/wiki/Leviathan_Heavy_Lifter) | $366,750 | $978,000 | $122,250 |
| [Behemoth Heavy Lifter](https://wiki.shippinglanes.net/wiki/Behemoth_Heavy_Lifter) | $450,000 | $1,200,000 | $150,000 |
| [Megalodon Heavy Lifter](https://wiki.shippinglanes.net/wiki/Megalodon_Heavy_Lifter) | $472,500 | $1,260,000 | $157,500 |
| [Multi Class Freighter](https://wiki.shippinglanes.net/wiki/Multi_Class_Freighter) | $184,500 | $492,000 | $61,500 |
| [Space Launch Platform](https://wiki.shippinglanes.net/wiki/Space_Launch_Platform) | $240,000 | $640,000 | $80,000 |
| [Exploration Launcher](https://wiki.shippinglanes.net/wiki/Exploration_Launcher) | $390,375 | $1,041,000 | $130,125 |
| [Very Large Launcher](https://wiki.shippinglanes.net/wiki/Very_Large_Launcher) | $675,500 | $1,800,000 | $225,000 |
| [Midway Class Carrier](https://wiki.shippinglanes.net/wiki/Midway_Class_Carrier) | $2,985,000 | $7,960,000 | $995,000 |
| [Brick](https://wiki.shippinglanes.net/wiki/Brick) | $37,500 | $72,618 | $12,500 |


## 13. Default paint region data

RGB triples from individual-page color tables, in **R/G/B** order. These are defaults, not a complete list of editable-region constraints or materials. No ship models or textures were extracted. The data exposes the recurring primary, secondary, deck, superstructure, and two funnel regions.


| Ship | Primary | Secondary | Deck | Superstructure | Funnel bottom | Funnel top |
| --- | --- | --- | --- | --- | --- | --- |
| [Small Container Ship](https://wiki.shippinglanes.net/wiki/Small_Container_Ship) | 100/96/99 | 152/0/0 | 100/96/99 | 249/249/249 | 100/96/99 | 197/40/28 |
| [Long Trade Ship](https://wiki.shippinglanes.net/wiki/Long_Trade_Ship) | 0/58/112 | 152/0/0 | 100/96/99 | 249/249/249 | 249/249/249 | 152/0/0 |
| [Inland Container Carrier](https://wiki.shippinglanes.net/wiki/Inland_Container_Carrier) | 71/71/71 | 118/0/0 | 51/88/131 | 249/249/249 | 249/249/249 | 152/0/0 |
| [York Container Ship](https://wiki.shippinglanes.net/wiki/York_Container_Ship) | 13/106/173 | 164/76/76 | 118/0/0 | 249/249/249 | 249/249/249 | 152/0/0 |
| [Perth Class](https://wiki.shippinglanes.net/wiki/Perth_Class) | 197/40/28 | 28/42/64 | 92/94/106 | 249/249/249 | 249/249/249 | 197/40/28 |
| [Medium Container Ship](https://wiki.shippinglanes.net/wiki/Medium_Container_Ship) | 197/40/28 | 118/0/0 | 135/141/154 | 249/249/249 | 135/141/154 | 152/0/0 |
| [Zenlift Container Ship](https://wiki.shippinglanes.net/wiki/Zenlift_Container_Ship) | 13/106/173 | 142/66/66 | 16/127/207 | 249/249/249 | 249/249/249 | 255/0/0 |
| [Legacy Container Ship](https://wiki.shippinglanes.net/wiki/Legacy_Container_Ship) | 249/249/249 | 152/0/0 | 152/0/0 | 249/249/249 | 152/0/0 | 13/106/173 |
| [Legacy Explorer](https://wiki.shippinglanes.net/wiki/Legacy_Explorer) | 5/175/237 | 152/0/0 | 152/0/0 | 249/249/249 | 28/42/54 | 5/175/237 |
| [SL-7](https://wiki.shippinglanes.net/wiki/SL-7) | 27/43/53 | 197/40/28 | 164/48/48 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Panamax-Class Container Ship](https://wiki.shippinglanes.net/wiki/Panamax-Class_Container_Ship) | 160/162/173 | 197/51/51 | 141/26/26 | 249/249/249 | 18/18/18 | 160/162/173 |
| [T2 Container Ship](https://wiki.shippinglanes.net/wiki/T2_Container_Ship) | 0/33/97 | 118/0/0 | 118/0/0 | 249/249/249 | 227/156/65 | 18/18/18 |
| [Atlantic Class](https://wiki.shippinglanes.net/wiki/Atlantic_Class) | 28/42/54 | 197/51/51 | 141/26/26 | 249/249/249 | 28/42/54 | 28/42/54 |
| [Container Boat](https://wiki.shippinglanes.net/wiki/Container_Boat) | 206/206/206 | 28/42/54 | 144/77/42 | 249/249/249 | 249/249/249 | 164/76/76 |
| [Mighty Class](https://wiki.shippinglanes.net/wiki/Mighty_Class) | 28/42/54 | 197/51/51 | 141/26/26 | 249/249/249 | 28/42/54 | 28/42/54 |
| [Voyager Container Ship](https://wiki.shippinglanes.net/wiki/Voyager_Container_Ship) | 28/42/54 | 197/51/51 | 141/26/26 | 249/249/249 | 28/42/54 | 28/42/54 |
| [Quad-A Class](https://wiki.shippinglanes.net/wiki/Quad-A_Class) | 26/167/89 | 197/51/51 | 101/158/94 | 249/249/249 | 164/163/166 | 249/1249/249 |
| [Maximus Class](https://wiki.shippinglanes.net/wiki/Maximus_Class) | 13/106/173 | 197/40/28 | 118/0/0 | 249/249/249 | 28/42/54 | 13/106/173 |
| [Colossus Class](https://wiki.shippinglanes.net/wiki/Colossus_Class) | 5/175/237 | 28/42/54 | 164/163/166 | 249/249/249 | 249/249/249 | 164/76/76 |
| [Covered Container](https://wiki.shippinglanes.net/wiki/Covered_Container_Ship) | 51/88/131 | 28/24/54 | 100/96/99 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Small Bulk Carrier](https://wiki.shippinglanes.net/wiki/Small_Bulk_Carrier) | 249/249/249 | 197/40/28 | 92/94/106 | 249/249/249 | 152/0/0 | 197/40/28 |
| [York Bulk Carrier](https://wiki.shippinglanes.net/wiki/York_Bulk_Carrier) | 13/106/173 | 164/76/76 | 118/0/0 | 249/249/249 | 249/249/249 | 13/106/173 |
| [Mini Bulk Carrier](https://wiki.shippinglanes.net/wiki/Mini_Bulk_Carrier) | 197/40/28 | 28/42/54 | 164/163/166 | 249/249/249 | 249/249/249 | 197/40/28 |
| [Handysize](https://wiki.shippinglanes.net/wiki/Handysize) | 0/58/112 | 118/0/0 | 164/163/166 | 249/249/249 | 249/249/249 | 0/58/112 |
| [Lloyd-Class Ore Carrier](https://wiki.shippinglanes.net/wiki/Lloyd-Class_Ore_Carrier) | 83/125/175 | 152/0/0 | 81/110/85 | 249/249/249 | 249/249/249 | 152/0/0 |
| [Handymax](https://wiki.shippinglanes.net/wiki/Handymax) | 28/42/54 | 164/76/76 | 164/163/166 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Supramax](https://wiki.shippinglanes.net/wiki/Supramax) | 28/42/54 | 164/76/76 | 164/163/166 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Panamax Bulk Carrier](https://wiki.shippinglanes.net/wiki/Panamax_Bulk_Carrier) | 0/58/112 | 163/58/18 | 164/163/166 | 249/249/249 | 0/33/97 | 0/33/97 |
| [Stanley Class Freighter](https://wiki.shippinglanes.net/wiki/Stanley_Class_Freighter) | 58/126/21 | 58/126/21 | 152/0/0 | 249/249/249 | 92/94/106 | 18/18/18 |
| [Hobart Class Freighter](https://wiki.shippinglanes.net/wiki/Hobart_Class_Freighter) | 58/126/21 | 58/126/21 | 152/0/0 | 249/249/249 | 92/94/106 | 18/18/18 |
| [Transit Class Freighter](https://wiki.shippinglanes.net/wiki/Transit_Class_Freighter) | 44/45/41 | 152/0/0 | 159/0/0 | 249/249/249 | 18/18/18 | 214/116/61 |
| [Capesize](https://wiki.shippinglanes.net/wiki/Capesize) | 28/42/54 | 162/57/57 | 164/163/166 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Very Large Ore Carrier](https://wiki.shippinglanes.net/wiki/Very_Large_Ore_Carrier) | 18/18/18 | 118/0/0 | 164/76/76 | 249/249/249 | 18/18/18 | 249/249/249 |
| [Hull 1173](https://wiki.shippinglanes.net/wiki/Hull_1173) | 134/5/7 | 134/5/7 | 136/3/12 | 249/249/249 | 0/0/0 | 255/255/255 |
| [Liberty Bulker](https://wiki.shippinglanes.net/wiki/Liberty_Bulker) | 0/33/97 | 137/62/62 | 125/157/108 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Gauntlet Cargo Liner](https://wiki.shippinglanes.net/wiki/Gauntlet_Cargo_Liner) | 28/42/54 | 152/0/0 | 109/89/76 | 249/249/249 | 109/89/76 | 109/89/76 |
| [Seamini Ore Carrier](https://wiki.shippinglanes.net/wiki/Seamini_Ore_Carrier) | 31/129/30 | 152/0/0 | 197/67/67 | 249/249/249 | 152/0/0 | 249/249/249 |
| [Seamax Ore Carrier](https://wiki.shippinglanes.net/wiki/Seamax_Ore_Carrier) | 31/129/30 | 152/0/0 | 197/67/67 | 249/249/249 | 152/0/0 | 249/249/249 |
| [Grand Ore Carrier](https://wiki.shippinglanes.net/wiki/Grand_Ore_Carrier) | 0/0/0 | 161/162/173 | 159/162/173 | 249/249/249 | 249/249/249 | 0/0/0 |
| [S.S Great Eastern](https://wiki.shippinglanes.net/wiki/S.S_Great_Eastern) | 28/42/54 | 152/0/0 | 109/89/76 | 109/89/76 | 109/89/76 | 109/89/76 |
| [General Purpose](https://wiki.shippinglanes.net/wiki/General_Purpose) | 13/106/173 | 197/40/28 | 141/26/26 | 249/249/249 | 197/40/28 | 13/106/173 |
| [Aframax](https://wiki.shippinglanes.net/wiki/Aframax) | 28/42/54 | 197/40/28 | 141/26/26 | 249/249/249 | 249/249/249 | 197/40/28 |
| [T2 Oil Tanker](https://wiki.shippinglanes.net/wiki/T2_Oil_Tanker) | 133/137/146 | 118/0/0 | 100/96/99 | 249/249/249 | 227/156/65 | 255/0/0 |
| [Suezmax Tanker](https://wiki.shippinglanes.net/wiki/Suezmax_Tanker) | 0/33/97 | 197/40/28 | 141/26/26 | 249/249/249 | 18/18/18 | 197/40/28 |
| [Legacy Seawise Giant](https://wiki.shippinglanes.net/wiki/Legacy_Seawise_Giant) | 152/0/0 | 28/42/54 | 100/96/99 | 249/249/249 | 197/40/28 | 28/42/54 |
| [Very Large Crude Carrier](https://wiki.shippinglanes.net/wiki/Very_Large_Crude_Carrier) | 13/106/173 | 197/40/28 | 141/26/26 | 249/249/249 | 197/40/28 | 13/106/173 |
| [Ultra Large Crude Carrier](https://wiki.shippinglanes.net/wiki/Ultra_Large_Crude_Carrier) | 249/249/249 | 197/40/28 | 160/162/173 | 249/249/249 | 197/40/28 | 249/249/249 |
| [Seawise-Giant](https://wiki.shippinglanes.net/wiki/Seawise-Giant) | 197/40/28 | 196/63/63 | 197/67/67 | 249/249/249 | 197/40/28 | 196/63/63 |
| [Batillus Supertanker](https://wiki.shippinglanes.net/wiki/Batillus_Supertanker) | 57/57/57 | 197/90/90 | 160/162/173 | 249/249/249 | 164/76/76 | 164/76/76 |
| [Extremely Large Crude Carrier](https://wiki.shippinglanes.net/wiki/Extremely_Large_Crude_Carrier) | 33/85/186 | 151/86/86 | 160/162/173 | 249/249/249 | 151/86/86 | 151/86/86 |
| [Q-Mini LNG Carrier](https://wiki.shippinglanes.net/wiki/Q-Mini_LNG_Carrier) | 197/40/28 | 94/0/0 | 197/40/28 | 249/249/249 | 18/18/18 | 255/0/0 |
| [Conventional LNG Carrier](https://wiki.shippinglanes.net/wiki/Conventional_LNG_Carrier) | 9/137/208 | 28/42/54 | 164/163/166 | 249/249/249 | 9/137/208 | 9/137/208 |
| [Gem Class LNG Carrier](https://wiki.shippinglanes.net/wiki/Gem_Class_LNG_Carrier) | 0/33/97 | 197/40/28 | 160/162/173 | 249/249/249 | 224/224/224 | 197/40/28 |
| [Absolute LNG Carrier](https://wiki.shippinglanes.net/wiki/Absolute_LNG_Carrier) | 0/46/141 | 197/40/28 | 160/162/173 | 249/249/249 | 224/224/223 | 197/40/28 |
| [Prometheus Class](https://wiki.shippinglanes.net/wiki/Prometheus_Class) | 8/77/141 | 142/42/30 | 160/162/173 | 249/249/249 | 224/224/223 | 8/77/141 |
| [High Speed Transporter](https://wiki.shippinglanes.net/wiki/High_Speed_Transporter) | 197/40/28 | 28/42/54 | 45/102/29 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Electrified Ferry](https://wiki.shippinglanes.net/wiki/Electrified_Ferry) | 41/128/71 | 255/0/0 | 45/102/29 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Trimaran Cargo Transporter](https://wiki.shippinglanes.net/wiki/Trimaran_Cargo_Transporter) | 152/0/0 | 28/42/54 | 100/96/99 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Space Class Transporter](https://wiki.shippinglanes.net/wiki/Space_Class_Transporter) | 51/88/131 | 152/0/0 | 45/102/29 | 249/249/249 | 249/249/249 | 51/88/131 |
| [King Class Transporter](https://wiki.shippinglanes.net/wiki/King_Class_Transporter) | 41/128/71 | 197/51/51 | 160/162/173 | 249/249/249 | 249/249/249 | 160/162/173 |
| [Mover Class Transporter](https://wiki.shippinglanes.net/wiki/Mover_Class_Transporter) | 13/91/119 | 118/0/0 | 51/88/131 | 249/249/249 | 236/236/236 | 92/94/106 |
| [Prototype Heavy Lifter](https://wiki.shippinglanes.net/wiki/Prototype_Heavy_Lifter) | 12/98/203 | 197/51/51 | 36/114/62 | 249/249/249 | 164/163/166 | 12/98/203 |
| [Striker Heavy Lifter](https://wiki.shippinglanes.net/wiki/Striker_Heavy_Lifter) | 0/33/97 | 197/40/28 | 41/128/71 | 249/249/249 | 249/249/249 | 249/249/249 |
| [Goliath Heavy Lifter](https://wiki.shippinglanes.net/wiki/Goliath_Heavy_Lifter) | 197/40/28 | 151/86/86 | 172/166/162 | 249/249/249 | 249/249/249 | 197/40/28 |
| [Leviathan Heavy Lifter](https://wiki.shippinglanes.net/wiki/Leviathan_Heavy_Lifter) | 197/40/28 | 18/18/18 | 160/162/173 | 249/249/249 | 249/249/249 | 197/40/28 |
| [Behemoth Heavy Lifter](https://wiki.shippinglanes.net/wiki/Behemoth_Heavy_Lifter) | 120/163/126 | 163/58/18 | 160/162/173 | 249/249/249 | 249/249/249 | 120/163/126 |
| [Megalodon Heavy Lifter](https://wiki.shippinglanes.net/wiki/Megalodon_Heavy_Lifter) | 31/129/30 | 197/40/28 | 160/162/173 | 249/249/249 | 249/249/249 | 0/33/97 |
| [Multi Class Freighter](https://wiki.shippinglanes.net/wiki/Multi_Class_Freighter) | 240/185/56 | 164/76/76 | 160/162/173 | 249/249/249 | 249/249/249 | 240/185/56 |
| [Space Launch Platform](https://wiki.shippinglanes.net/wiki/Space_Launch_Platform) | 62/62/62 | 62/62/62 | 100/96/99 | 249/249/249 | 249/249/249 | 125/157/108 |
| [Exploration Launcher](https://wiki.shippinglanes.net/wiki/Exploration_Launcher) | 67/110/187 | 162/59/18 | 232/231/235 | 249/249/249 | 67/110/187 | 249/249/249 |
| [Very Large Launcher](https://wiki.shippinglanes.net/wiki/Very_Large_Launcher) | 83/125/175 | 163/58/18 | 160/162/173 | 249/249/249 | 92/94/106 | 83/125/175 |
| [Midway Class Carrier](https://wiki.shippinglanes.net/wiki/Midway_Class_Carrier) | 160/162/173 | 152/0/0 | 160/162/173 | 160/162/173 | 249/249/249 | 249/249/249 |
| [HMAS Hobart](https://wiki.shippinglanes.net/wiki/HMAS_Hobart) | 171/171/171 | 95/95/95 | 95/95/95 | 249/249/249 | 241/241/241 | 241/241/241 |


## 14. Conflicts, corrections, and unreliable fields

This register separates resolved historical disagreements from still-disputed data. An updated infobox does not prove a live rule.

| Issue | Research outcome |
| --- | --- |
| Replacement wiki inaccessible in first pass | Browser successfully read current pages; first-pass access limitation resolved. |
| 18 ports | Superseded: Pine Island makes 19 documented ports. |
| Missing recent ships | Mighty, Voyager, Liberty, Seamini, Covered Container, ELCC, Colossus individually researched. |
| Missing maintenance | Engine/hull/machinery wear, rust, thresholds, menu and rates now documented. |
| Premium + 120% stacking | Historical. Changelog removes Premium perks and upgrades pass to 125%. |
| Moving launch in V2 | Historical early-access bug, fixed in 3.2.1. |
| Norfolk refinery denied by port prose | Dated update notes explicitly add it; port prose is stale. |
| Hull 1173: four holds, $125M, old earnings | Remodel/reissue explains one hold and $9.75B limited sale; current page says $767,500/NM. Earlier acquisition remains historical. |
| Mover / Multi prices and rates | Current individual pages report $159M/$670k and $395M/$750k combined respectively; old tables remain lower. |
| Great Eastern DWT 800 vs 10,000 | Current infobox says 800; aggregate says 10,000. Not equated to cargo payload. |
| Mover endurance/range | Infobox 25.8 min / 34 NM; aggregate 34 min / 25.8 NM. Apparent swapped fields, unresolved. |
| Exploration Launcher DWT | Individual 6,500 vs aggregate 65,000 tons. Unresolved. |
| Mighty range | Individual 39.2 vs aggregate 25 NM. |
| Voyager fuel/range | Individual 12,000 / 85.9; aggregate 22,000 / 68.75. |
| Rocket ranges | Individual Space 39.8, Exploration 69.3, VLL 52.8 differ from aggregate/class values. |
| Small Container / Long Trade / Inland “no fuel” | Fractional historical burn and finite current endurance conflict with prose. Exact idle/full burn unmeasured. |
| Seamax capacity / profit | Older capacity and hold arithmetic disagree; separate DWT, hold count and payload instead of inventing a correction. |
| Maximus capacity / range | Current individual-page values retained; aggregate/endgame tables differ historically. |
| Gas types | Class says five; general page seven; individual compatibility can list six. |
| Woodside services / DWT | No pipeline in individual page versus liquid/vehicle services in overview; 50,000 vs 51,000 DWT. |
| Bayview equipment | Individual infobox zero bulk/container cranes while prose/table supports those cargoes. |
| Jamestown / Lakeview liquid cargo | Cargo labels/overview disagree with zero pipeline counts; Jamestown crane count 3 vs 4. |
| Macquarie multiplier | Individual/latest overview table 0.88; other prose 0.87. |
| Douglas multiplier | Infobox 0.87; prose 0.8. |
| Newhaven multiplier | Individual 0.95; some overview prose 1.0. |
| Wilmington cranes | Four bulk cranes in infobox, contrary to some older prose. |
| Refinery catalog | Oil page says three, then five, and contradicts Macquarie within its own strategies. Five-site list plus dated Norfolk addition is strongest public lead, still not a live audit. |
| Full port distances | Several reverse directions differ; raw direction values retained in matrix. |
| Northern player cap | Older 25/30, current wiki 27, external main-place listing 23; may involve region/version differences. |
| Regional map table | Incorrect Emerald placement in Northern Isles; use individual regional descriptions. |
| Aggregate ship counts | Intro says 59 available / 9 staff / 5 legacy while its detailed rows disagree. Do not use intro counts as current inventory. |
| Con-Ro variants | Page still contains placeholder update X.X and hypothetical Mk II/XL. Excluded from confirmed fleet. |
| Heavy lifter count | Cargo page says five while listing six. Use named records. |
| Trading fee | General wording still does not establish exact per-side charge, rounding, and insufficient-balance behavior. |
| Limited trading valuation | Update history removes purchase-price tie, while general and individual trade pages retain older floors. Unresolved exceptions. |
| Crate distributions | Listed low tier totals 85%; 300-Robux tier 101%. Incomplete/incorrect as a probability specification. |
| Furniture count / price | 83 is dated February 2025; bridge system current page $300k vs historical $5M. |
| “Used ships never lose performance” | Current maintenance requires condition qualification; condition transfer unmeasured. |
| Save/refund rules | General reconnect cargo saving and older oil refund/menu rules need cargo-specific verification. |
| Recent-page modification timestamps | Templates can transclude content newer than the displayed page modification date. Neither timestamp alone certifies live version. |

## 15. Video evidence ledger

**Method:** read available auto-generated captions and page context; timestamps locate the narration. Frames did not render, so no frame-based measurements or visual UI transcription is claimed. Creator uncertainty, jokes, approximate arithmetic, edited travel, and historical names are not promoted to exact game rules.

| ID / video | Timestamped evidence | Confidence and limitation |
| --- | --- | --- |
| V1 — [Seniac: Transporting CARGO SHIPS](https://www.youtube.com/watch?v=IoPDV6A346E) | 3:23–4:04 submerging; 8:23–9:56 moving/misaligned raising rejection then pickup; 10:05–13:42 transport with occupant; 14:18–15:46 submerge/release | Historical 2023 narration. Establishes an occupied player ship can be carried in that version; not exact attachment tolerances or present permission rules. |
| V2 — [Seniac: ROCKET UPDATE](https://www.youtube.com/watch?v=qWlBIMAC1XY) | 1:08–1:19 declares early access; 4:10–5:52 model-dependent contract list, optional recovery, 12%/20% examples; 9:14–11:57 launch/recovery; 14:47–18:50 moving-launch failure and abort | Pre-release behavior. Moving defect is fixed in 3.2.1; spoken costs/payouts contain uncertainty and are not a current mission table. |
| V3 — [Seniac: MOST EXPENSIVE ROCKET](https://www.youtube.com/watch?v=qhx2x6qXae8) | 2:16–3:13 telescope contract, ~20 NM and 8% quoted risk; 6:37–6:52 launch map versus navigation map; 13:25–16:16 launch/recovery and payment | Supports separate launch/recovery and UI workflow. Spoken totals are approximate; cuts prevent voyage-speed measurement. |
| V4 — [Seniac: GLOBAL Car Shipping Company](https://www.youtube.com/watch?v=lWoQW_mKEAE) | 7:19 ramp opens; 8:10–8:29 cancel to reposition; 9:04–10:30 three cars load nominal 7,855; 16:36–18:43 three unload, reward follows | Historical Mark V/Mover run. Confirms representative-car minigame and ramp placement importance; does not establish timeout/water penalties. |
| V5 — [Seniac: OIL TANKER Doubles My Money](https://www.youtube.com/watch?v=FCWlLlPXXSY) | 9:31–10:07 wallet-limited custom amount; 12:10–15:06 changing prices before sale; 21:17–22:46 requesting lock cycle; 26:14–26:32 waiting for price before selling | Old oil example. Supports manual quantity and arrival-price risk. Old ship capacity/resale and casual “autopilot” language are not current authoritative facts. |
| V6 — [Seniac: NEW 4 BILLION AIRCRAFT CARRIER](https://www.youtube.com/watch?v=ezoUk7-_mLc) | 4:45–6:10 public planes/lifts/gates; 7:10–8:35 anchor/spawner controls; 8:38–11:00 engine/throttle, gear and stall warning; 12:42–12:53 no cargo income | Historical narrated feature tour, corroborated by current carrier article; complete flight keymap remains unknown. |
| V7 — [Robynila: What happens at 0 health?](https://www.youtube.com/watch?v=RlDq97n6Zi8) | 1:53 zero health; 2:00 sinking with movement disabled | Mid-2026 narrated test. No exact sinking duration, cargo loss or ownership consequence supplied. |
| V8 — [QuasKrank: Top 5 Mistakes](https://www.youtube.com/watch?v=L_Gshqwz8BY) | 3:21–3:38 thrusters/zero throttle; 3:58–4:08 reports 30% resale | Low-confidence supplementary advice: other sections repeat outdated Davenport/gas-commodity claims. Not independent proof of all its recommendations. |
| V9 — [Lord Anthill: Only New Ships By Trading](https://www.youtube.com/watch?v=euTPAG2ztFE) | 1:20–1:45 request/accept and acquired ship; 7:13–7:37 another trade completes | Caption coverage is sparse and mostly music. Confirms narrated trading activity, not exact fees, slots or confirmation behavior. |

Other checks: [Rocket Update Review](https://www.youtube.com/watch?v=oZblWGCL488) yielded music-only captions; no mechanics extracted. [Gauntlet guide](https://www.youtube.com/watch?v=CVPdk7oQhHQ) and [recent update review](https://www.youtube.com/watch?v=C1oMCmg3ebg) had no usable captions and non-rendering frames. [Complete tutorial](https://www.youtube.com/watch?v=u6CkWk6yVzA) was private; [rocket tutorial](https://www.youtube.com/watch?v=akAKC7a3u7c) belonged to a terminated account. These links are recorded as unsuccessful evidence retrieval, not watched sources.

## 16. What is still unverified — precise remaining research gaps

The second pass resolves missing public systems and greatly improves current content coverage. It cannot make undocumented internals observable. These are the outstanding evidence questions, **not a build plan**:

| Area | Established now | Still missing |
| --- | --- | --- |
| Version/content | Full available change history through reported 3.5.0; expanded fleet; 19 ports | Independent live deployment confirmation; limited stock currently remaining; resolving every numeric conflict |
| First session | Starter identity; tutorial cargo/docking flow | New wallet; exact tutorial state machine/rewards/skip/replay/failure |
| Ship handling | Momentum, reverse braking, side thrust, cargo draft | Thrust/drag/turn constants, collision meshes, mass/draft curve, empty/full comparisons, latency/frame-rate effects |
| Fuel | Throttle-based rule; per-ship endurance; maintenance affects consumption | Exact throttle curve, reverse/idle/thruster consumption, tick/rounding, pass economics, exhaustion limits |
| Docking | Stop/proximity/compatibility; DWT gates; crane cross-service | Numeric distance/speed/angle thresholds; equal-to-limit boundary; occupancy/queue; cancel state and dock invulnerability |
| Container offers | Assigned destination, quoted payment, capacity, current maximum loading time | Spawn/refresh/expiry algorithm; subtype catalog; partial load/unload and cancellation; reservation/payment locking |
| Bulk/gas | Direct separation; modifiers; per-NM UI | Exact commodity/quantity/rate calculations; modifier inclusion in displayed rate; mixing, partial discharge and same-port payout |
| Markets | Changing prices; player expenditure; arrival-price risk; claimed external influence | Feed/source, ticks/bounds, buy/sell spread, volume impact, server/global sharing, stock depletion, rounding |
| Refineries | 0.7 reported yield; shared server stock; five-site public lead | Processing rate/queue/batching; precise capacity, withdrawal cost, rounding and restart/offline persistence |
| Ro-Ro | 1–3 driven representatives; terminal/ramp placement; documented car speed | Exact per-vessel representative count, controls, water/crash/time penalties, cancellation refund and spectators |
| Heavy lifting | Payload families, offshore loop, player-ship transport, cross-region support | Full payload weights/coordinates; spawn timing; alignment/pickup/release thresholds; cargo/disconnect failure rules |
| Rockets | Eight named model families across launchers; contract UI; two reward stages; known historical fixes | Complete model–mission table, current costs/rewards/failure rates, RNG timing, launch radius/countdowns, abort timing and post-fix movement lock |
| Maintenance | Three components, 50% threshold, 80% rust, individual reported rates | Wear per time/use, offline/stationary behavior, penalty interpolation, fractional condition/price rounding, trading persistence |
| Sinking/recovery | Zero-health narrated sinking; can't dock while sinking | Health pool, impact damage/cooldowns, sinking time, cargo/investment loss, tow/refuel/rescue/reset/bankruptcy rules |
| Geometry | Maps, individual ports/distances, three locks, two regions | Exact coordinates/bathymetry, channel/lock clearance, full collider map, accurate distance/time/world-to-map transforms |
| Region transfers | Teleport boundaries, multiple cargo-saving/transfer fixes | Destination-server matching, passengers/aircraft/carried players, heading/position, race/failure/retry transaction behavior |
| Ownership/trading | Requests, cash/ships, previous owners, data cap, general valuation rule | Exact fees/rounding, limited exceptions, accept-reset behavior, duplicate requests and disconnect atomicity |
| Customization | Helm/decor catalogs; defaults; recolor/materials, snapping/edit permission | Full live catalog, current limits, placement transform increments, bounds/overlap, undo/refund/visitor rights |
| Aircraft/sails | Documented aircraft types, spawner limit, lifts; sails/engine choices | Full keymaps, physics, fuel/health/crashes, plane permissions/despawn/region transitions, combined sail speed/wind |
| Multiplayer | Peer ships/passengers, trading and optional editing | Region-specific live cap, concurrent ships/player, helm access, shared earnings/crew/party rules, synchronization behavior |
| Saving | Documented quit/reconnect cargo restoration and subsequent fixes | Autosave interval; per-cargo menu/quit/crash/transfer matrix; oil refund precedence; rollback/duplication recovery |
| Settings/world | Freecam, map, camera lock, weather toggle and five states | Every menu/state/toggle, day/night duration, weather odds, UI scaling/audio controls, current platform parity |
| Rewards/store | Badge criteria and current documented store categories | Live badge availability, odometer accumulation/anti-grind caps, reset timezone, crate correctness/duplicates, current ad/pass behavior |
| Quest | Gauntlet exists; direct acquisition one/account | Full NPC dialogue, exact clue sequence, purchase gating and failure/reset states |

A successful additional observation should record **game version, ship, condition, passes, region/server, starting state, player action, visible result, and relevant before/after balances or quantities**. A video cut or narrated guess is insufficient for an exact timing/formula. Source-level facts should remain distinct from design choices when Godot planning begins.

## 17. Sources and provenance

Primary experience entry: [Shipping Lanes on Roblox](https://www.roblox.com/games/245440965/Shipping-Lanes), experience ID 245440965, Shipping Studios. Shipping Empire is a separate sister game and its fishing/drydock/scrapyard systems are excluded.

Most detailed mechanics come from community documentation, not original game code. Every ship and port row links its individual source. Browser-read current pages supplement the older Fandom baseline, which stopped maintenance in April 2026. The current wiki is [Shipping Lanes Wiki](https://wiki.shippinglanes.net/wiki/Main_Page). Its pages identify their content as CC BY-SA 4.0; source links and factual transformations are retained here. Game models, textures, audio and private material were not extracted.

The failed video entries remain visible to prevent later treating a discovered title as an inspected source. Research snapshots and historical comparisons are not a claim that every current wiki field is correct. This document deliberately makes no Godot architecture, build order, server, scope, or monetization decision.
