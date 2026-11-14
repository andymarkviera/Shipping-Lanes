extends RefCounted
## Data for the game: the world (M4), the ships a captain can own and the bulk
## jobs (M3). Prices and pay are in hundredths of a credit. No state lives here.
## The world: four ports on the two shores of a strait. Brindle Quay and Slatewater
## Works stay where Port Test and older saves have them. "drop_side" is the open
## side of the berth (+1 is +X), where heavy loads are picked up and dropped.
const WORLD = [
	{"id": "port_brindle_quay", "at": Vector3(0, 0, 0), "drop_side": 1.0},
	{"id": "port_slatewater_works", "at": Vector3(1500, 0, 0), "drop_side": -1.0},
	{"id": "port_cinder_point", "at": Vector3(-200, 0, 2200), "drop_side": 1.0},
	{"id": "port_gannet_light", "at": Vector3(1700, 0, -2200), "drop_side": -1.0},
	# Patch 2.1 item 3: the two polar ports, far north (+Z) and far south.
	{"id": "port_north_pole", "at": Vector3(3700, 0, 4000), "drop_side": 1.0},
	{"id": "port_south_pole", "at": Vector3(-2300, 0, -4100), "drop_side": -1.0},
]
## The four strait ports come first. Their container jobs keep the destinations
## they had before the polar ports, so saved jobs still match their IDs.
const STRAIT_PORTS: int = 4
## Land as flat rectangles: Rect2(x, z, width, depth) in metres. Two shores, the
## head of the strait and two islands. Each berth keeps open water straight ahead
## and astern, and the heavy pickup and drop areas are clear.
const LAND = [
	Rect2(-1500, -3600, 1000, 3200), Rect2(-1500, -400, 1400, 1100),
	Rect2(-1500, 700, 1100, 1000), Rect2(-1500, 1700, 1200, 1300),
	Rect2(1800, -3000, 1200, 1500), Rect2(1900, -1500, 1100, 1100),
	Rect2(1600, -400, 1400, 1100), Rect2(1750, 700, 1250, 2300),
	Rect2(-1500, 3000, 4500, 400),
	Rect2(880, 1320, 240, 360), Rect2(450, -2050, 300, 300),
]
## Patch 2.1 item 3: snowy ice shelves beside the two polar quays, solid like land.
const ICE_SHELVES = [Rect2(3050, 3700, 450, 460), Rect2(-2100, -4360, 450, 500)]
## Patch 2.1 item 3: icebergs in the polar seas, solid like land. Vector3(x,
## radius, z) in metres. They keep clear of the polar quays, their approaches
## and their heavy-load drop areas.
const ICEBERGS = [
	Vector3(3000, 45, 4750), Vector3(4300, 60, 4800), Vector3(5200, 50, 4300), Vector3(2200, 70, 5000),
	Vector3(3500, 55, 5400), Vector3(5000, 65, 5600), Vector3(1200, 50, 5500), Vector3(2700, 40, 5900),
	Vector3(-300, 60, 5200), Vector3(6200, 45, 5000),
	Vector3(-1500, 55, -4750), Vector3(-3800, 60, -4400), Vector3(-2000, 50, -6000), Vector3(-700, 70, -5100),
	Vector3(-4400, 45, -5600), Vector3(200, 50, -4600), Vector3(-3300, 60, -6100), Vector3(1400, 55, -5600),
	Vector3(-5200, 50, -4700), Vector3(2600, 45, -5000),
]
## Patch 2.1 item 3: the world repeats every WRAP_M metres east-west and
## north-south, so a ship that sails off one edge carries on from the opposite
## one. 4000 pi metres is a whole number of every swell and tone wave in the
## ocean shader, so the water looks the same on both sides of the edge. The
## land sits in the middle with at least 2.5 km of open sea to every edge.
const WRAP_M: float = 4000.0 * PI
const WRAP_CENTRE: Vector3 = Vector3(750, 0, -100)
## Patch 2.2 item 1: container ships 1-5 (REBUILD_PLAN.md section 7). Ship 1
## keeps the save ID "container"; ships 2-5 name their own records. Bigger is
## faster but heavier: slower to speed up, stop and turn.
const SHIPS = {
	"container": {"name": "Container ship", "price_minor": 80000},
	"container_2": {"name": "Coastal feeder", "price_minor": 1200000, "record": "res://features/catalog/records/container_02_ship.tres"},
	"container_3": {"name": "Panamax box ship", "price_minor": 4500000, "record": "res://features/catalog/records/container_03_ship.tres"},
	"container_4": {"name": "Neo-Panamax box ship", "price_minor": 12000000, "record": "res://features/catalog/records/container_04_ship.tres"},
	"container_5": {"name": "Ultra-large box ship", "price_minor": 30000000, "record": "res://features/catalog/records/container_05_ship.tres"},
	"bulk": {"name": "Handysize bulker", "price_minor": 120000, "record": "res://features/catalog/records/bulk_01_ship.tres"},
	"bulk_2": {"name": "Supramax bulker", "price_minor": 1800000, "record": "res://features/catalog/records/bulk_02_ship.tres"},
	"bulk_3": {"name": "Panamax bulker", "price_minor": 6750000, "record": "res://features/catalog/records/bulk_03_ship.tres"},
	"bulk_4": {"name": "Capesize bulker", "price_minor": 18000000, "record": "res://features/catalog/records/bulk_04_ship.tres"},
	"bulk_5": {"name": "Valemax ore carrier", "price_minor": 45000000, "record": "res://features/catalog/records/bulk_05_ship.tres"},
	"heavy": {"name": "Heavy lifter", "price_minor": 300000},
	"heavy_2": {"name": "Twin-crane project ship", "price_minor": 4500000, "record": "res://features/catalog/records/heavy_02_ship.tres"},
	"heavy_3": {"name": "Twin-crane heavy lifter", "price_minor": 15000000, "record": "res://features/catalog/records/heavy_03_ship.tres"},
	"heavy_4": {"name": "Semi-submersible heavy ship", "price_minor": 40000000, "record": "res://features/catalog/records/heavy_04_ship.tres"},
	"heavy_5": {"name": "Giant semi-submersible", "price_minor": 90000000, "record": "res://features/catalog/records/heavy_05_ship.tres"},
	# Patch 2.4 item 8: the small boats. Cheap, just for fun, no cargo jobs.
	"small_fishing": {"name": "Fishing boat", "price_minor": 20000, "record": "res://features/catalog/records/small_fishing_ship.tres"},
	"small_speedboat": {"name": "Speedboat", "price_minor": 40000, "record": "res://features/catalog/records/small_speedboat_ship.tres"},
	"small_racer": {"name": "Offshore racer", "price_minor": 60000, "record": "res://features/catalog/records/small_racer_ship.tres"},
}
## The container ladder, smallest first. Tier 1 is "container".
const CONTAINER_KINDS: Array[String] = ["container", "container_2", "container_3", "container_4", "container_5"]
## Pay per container grows a little with the tier (percent), so each step up
## earns more per trip than the containers alone.
const CONTAINER_PAY_PERCENT: Array[int] = [100, 110, 120, 130, 140]
## Patch 2.2 item 2: the bulk ladder, smallest first. Tier 1 keeps the save ID
## "bulk" (the old prototype). Tonnage comes from each record's dwt_tonnes.
const BULK_KINDS: Array[String] = ["bulk", "bulk_2", "bulk_3", "bulk_4", "bulk_5"]
const BULK_PAY_PERCENT: Array[int] = [100, 110, 120, 130, 140]
## Patch 2.2 item 3: the heavy-lift ladder, smallest first. Tier 1 keeps the
## save ID "heavy" and the current heavy lifter's record. Every heavy kind sails
## in heavy mode (lifting deck, one ocean load at a time).
const HEAVY_KINDS: Array[String] = ["heavy", "heavy_2", "heavy_3", "heavy_4", "heavy_5"]
## Patch 2.4 item 8: the small boats family, cheapest first. They carry no
## cargo and take no jobs; the planing ones jump the waves (ShipVisualMotion).
const SMALL_KINDS: Array[String] = ["small_fishing", "small_speedboat", "small_racer"]
## Ship record IDs and the ladder kind each one is saved as. The old container
## variants all had the starter's 24-slot hull: the starter and the slower
## harbor ship are ship 1; the coastal and the faster swift ship are ship 2,
## the coastal feeder. A save naming one of them keeps the ship.
const LADDER_IDS = {
	"ship_starter_container_01": "container", "ship_harbor_container_01": "container",
	"ship_coastal_container_01": "container_2", "ship_swift_container_01": "container_2",
	"ship_container_feeder_02": "container_2", "ship_container_panamax_03": "container_3",
	"ship_container_neopanamax_04": "container_4", "ship_container_ultra_05": "container_5",
	"ship_heavy_lifter_01": "heavy", "ship_heavy_project_02": "heavy_2", "ship_heavy_twin_crane_03": "heavy_3",
	"ship_heavy_semisub_04": "heavy_4", "ship_heavy_semisub_05": "heavy_5",
	"ship_bulk_prototype_01": "bulk", "ship_bulk_handysize_01": "bulk",
	"ship_bulk_supramax_02": "bulk_2", "ship_bulk_panamax_03": "bulk_3",
	"ship_bulk_capesize_04": "bulk_4", "ship_bulk_valemax_05": "bulk_5",
	"ship_small_fishing_01": "small_fishing", "ship_small_speedboat_02": "small_speedboat", "ship_small_racer_03": "small_racer",
}
## A sold ship pays back half its price.
const RESALE_PERCENT: int = 50
## Bulk cargo: name, label, pay per 100 m sailed and tonnes for ship 1. Every
## port always has one job of each cargo per bulk tier, one for each other port.
## A delivered job is on offer again at once. Bigger tiers carry tonnage in
## step with their deadweight and earn a little more per tonne.
const BULK_CARGO = [["grain", "Grain", 6000, 4000], ["coal", "Coal", 8000, 5000], ["ore", "Iron ore", 10000, 6000]]
## Pay of the six M3 bulk jobs, to read a version 4 save that lists delivered ones.
const BULK_V4 = {"bulk_0_grain": 90000, "bulk_0_coal": 120000, "bulk_0_ore": 150000, "bulk_1_grain": 90000, "bulk_1_coal": 120000, "bulk_1_ore": 150000}

## The same step taken the short way round the world.
static func short_way(step: Vector3) -> Vector3:
	return Vector3(wrapf(step.x, -WRAP_M / 2, WRAP_M / 2), step.y, wrapf(step.z, -WRAP_M / 2, WRAP_M / 2))

## A position brought back inside the world's edges.
static func wrapped(at: Vector3) -> Vector3:
	return WRAP_CENTRE + short_way(at - WRAP_CENTRE)

## The copy of `point` that is closest to `from`, which may be across an edge.
static func nearest(point: Vector3, from: Vector3) -> Vector3:
	return from + short_way(point - from)

static func port_index(id: Variant) -> int:
	for index: int in WORLD.size():
		if WORLD[index].id == id: return index
	return -1

## The other ports, in world order.
static func others(origin: int) -> Array[int]:
	var result: Array[int] = []
	for index: int in WORLD.size():
		if index != origin: result.append(index)
	return result

## Length of a leg in units of 100 m, the short way round the world. Pay grows
## with it. The strait legs are all shorter than half the world, so they are
## unchanged; the leg between the poles goes over the edge.
static func leg_units(a: int, b: int) -> int:
	var from: Vector3 = WORLD[a].at
	var to: Vector3 = WORLD[b].at
	return roundi(short_way(to - from).length() / 100.0)

## 1 to 5 for a bulk ship, 0 for any other kind.
static func bulk_tier(kind: String) -> int:
	return BULK_KINDS.find(kind) + 1

## 1 to 5 for a heavy-lift ship, 0 for any other kind.
static func heavy_tier(kind: String) -> int:
	return HEAVY_KINDS.find(kind) + 1

## 1 to 3 for a small boat, 0 for any other kind.
static func small_tier(kind: String) -> int:
	return SMALL_KINDS.find(kind) + 1

## Deadweight tonnes a bulk tier carries, from its record.
static func bulk_capacity(tier: int) -> int:
	return definition(BULK_KINDS[tier - 1]).dwt_tonnes

## "12,500" for 12500.
static func thousands(value: int) -> String:
	var text: String = str(value)
	for at: int in range(text.length() - 3, 0, -3): text = text.insert(at, ",")
	return text

## A bulk job from its ID: "bulk_<origin port>_<cargo>" for ship 1 (the M3 IDs)
## or "bulk_t<tier>_<origin port>_<cargo>" for ships 2-5. Empty if there is none.
static func bulk_job(id: String) -> Dictionary:
	var parts: PackedStringArray = id.split("_")
	var tier: int = 1
	if parts.size() == 4 and parts[0] == "bulk" and parts[1].length() == 2 and parts[1][0] == "t" and parts[1][1] in "2345":
		tier = int(parts[1][1])
		parts.remove_at(1)
	if parts.size() != 3 or parts[0] != "bulk" or not parts[1].is_valid_int(): return {}
	var origin: int = int(parts[1])
	if origin < 0 or origin >= WORLD.size() or parts[1] != str(origin): return {}
	for index: int in BULK_CARGO.size():
		if BULK_CARGO[index][0] != parts[2]: continue
		var destination: int = others(origin)[index]
		var base: int = int(BULK_CARGO[index][3])
		var tonnes: int = base if tier == 1 else roundi(float(base) * bulk_capacity(tier) / bulk_capacity(1) / 100.0) * 100
		var pay: int = int(BULK_CARGO[index][2]) * leg_units(origin, destination) * tonnes / base * BULK_PAY_PERCENT[tier - 1] / 100
		return {"title": "%s, %s t" % [BULK_CARGO[index][1], thousands(tonnes)], "origin": origin, "destination": destination, "reward_minor": pay, "tier": tier, "tonnes": tonnes}
	return {}

static func bulk_ids(origin: int, tier: int = 1) -> Array[String]:
	var result: Array[String] = []
	for cargo: Array in BULK_CARGO: result.append(("bulk_%d_%s" % [origin, cargo[0]]) if tier == 1 else ("bulk_t%d_%d_%s" % [tier, origin, cargo[0]]))
	return result

## The ship record a kind sails with.
static func definition(kind: String) -> ShipDefinition:
	if kind == "heavy": return load("res://features/catalog/records/heavy_lifter.tres") as ShipDefinition
	return load(str(SHIPS.get(kind, {}).get("record", "res://features/catalog/records/starter_ship.tres"))) as ShipDefinition

## 1 to 5 for a container ship, 0 for any other kind.
static func container_tier(kind: String) -> int:
	return CONTAINER_KINDS.find(kind) + 1

## Containers a tier carries, from its record.
static func container_capacity(tier: int) -> int:
	return int(definition(CONTAINER_KINDS[tier - 1]).cargo_capacities.get("container_slots", 0))

## A saved ship ID as a ladder kind. Kinds pass through; unknown IDs too, so
## save_valid still rejects them.
static func ladder_kind(id: String) -> String:
	return id if SHIPS.has(id) else str(LADDER_IDS.get(id, id))

## Patch 2.2: a version 4/5 save that names ships by record ID reads them as
## ladder kinds. Two IDs on one kind keep the first. Call before save_valid.
static func migrate(d: Dictionary) -> void:
	if d.get("ship") is String: d.ship = ladder_kind(d.ship)
	if not d.get("fleet") is Dictionary: return
	var fleet: Dictionary = {}
	for kind: Variant in d.fleet:
		var mapped: Variant = ladder_kind(kind) if kind is String else kind
		if not fleet.has(mapped): fleet[mapped] = d.fleet[kind]
	d.fleet = fleet

static func resale_minor(kind: String) -> int:
	return int(SHIPS[kind].price_minor) * RESALE_PERCENT / 100

static func fraction(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(value) and value >= 0 and value <= 1

## The game's save fields. Version 4 (M3): spent, ship, fleet, bulk. Version 5
## (M4) adds banked: pay from bulk and heavy jobs, which can be taken again.
static func save_valid(d: Dictionary) -> bool:
	var current: bool = d.get("version") == 5
	if not d.get("spent") is int or d.spent < 0: return false
	if current and (not d.get("banked") is int or d.banked < 0): return false
	if not d.get("ship") is String or not SHIPS.has(d.ship) or d.get("heavy_mode") != (heavy_tier(d.ship) > 0): return false
	if not d.get("fleet") is Dictionary or not d.fleet.has(d.ship): return false
	for kind: Variant in d.fleet:
		if not kind is String or not SHIPS.has(kind): return false
		var stored: Variant = d.fleet[kind]
		if not stored is Dictionary or stored.size() != 2 or not fraction(stored.get("fuel")) or not fraction(stored.get("condition")): return false
	var bulk: Variant = d.get("bulk")
	if not bulk is Dictionary or bulk.size() != 2 or not bulk.get("active") is String or not bulk.get("done") is Array: return false
	if bulk.done.size() > (0 if current else BULK_V4.size()): return false
	var seen: Dictionary = {}
	for id: Variant in bulk.done:
		if not id is String or not BULK_V4.has(id) or seen.has(id): return false
		seen[id] = true
	if not bulk.active.is_empty() and (bulk_tier(d.ship) < int(bulk_job(bulk.active).get("tier", 9)) or seen.has(bulk.active)): return false
	return true

## Pay from bulk and heavy jobs that are not listed one by one in the save.
## Call only after save_valid.
static func earned(d: Dictionary) -> int:
	var total: int = int(d.get("banked", 0))
	for id: String in d.bulk.done: total += int(BULK_V4[id])
	return total
