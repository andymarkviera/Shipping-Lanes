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
## Land as flat rectangles: Rect2(x, z, width, depth) in metres. Each berth
## keeps open water straight ahead and astern, and the heavy pickup and drop
## areas are clear. Patch 2.5 item 1: real-feeling geography round the strait
## the first four ports share: two continents, big islands, three straits and a
## canal (LANDMASSES and STRAITS name them). All land stays at least 2 km inside
## the world's edges, so the wrap never tears a coast; the oceans between the
## continents run across the edges. Every port's quay backs onto land.
const LAND = [
	# Hearthland: the continent behind Brindle Quay and Cinder Point, with the
	# South Pole on its southern tip and Gannet Narrows' western cape.
	Rect2(-1500, -3700, 1000, 3300), Rect2(-1500, -400, 1400, 1100),
	Rect2(-1500, 700, 1100, 1000), Rect2(-1500, 1700, 1200, 1300),
	Rect2(-3300, -2950, 1800, 1900), Rect2(-3500, -1050, 2000, 1700),
	Rect2(-3150, 650, 1650, 1350), Rect2(-3400, 2000, 1900, 1000),
	Rect2(-2200, -3860, 700, 910), Rect2(-1500, -4150, 2850, 450),
	# The Northern Neck at the head of the strait, cut by Needle Gut.
	Rect2(-1500, 3000, 2080, 400), Rect2(780, 3000, 2220, 400),
	# Ironreach: the continent behind Slatewater Works and Gannet Light, cut by
	# the Ironreach Canal, with Gannet Narrows' eastern cape.
	Rect2(1800, -3000, 1200, 1500), Rect2(1900, -1500, 1100, 600),
	Rect2(1900, -760, 1100, 360), Rect2(1600, -400, 1400, 1100),
	Rect2(1750, 700, 1250, 2300), Rect2(1900, -4150, 1900, 1150),
	Rect2(3000, -3000, 800, 2100), Rect2(3000, -760, 800, 3160),
	# Kelp Isle, across Kelp Strait from Ironreach.
	Rect2(4050, -2600, 900, 4000),
	# Gull Isle, in the northern sea.
	Rect2(-1000, 3700, 1000, 400),
	# The two islets in the strait.
	Rect2(880, 1320, 240, 360), Rect2(450, -2050, 300, 300),
	# Patch 2.5 item 5: the Palm Isles, three small islands in the tropical
	# southern strait west of Gannet Light, clear of every lane and approach.
	Rect2(-260, -2900, 240, 220), Rect2(120, -3380, 220, 200), Rect2(-330, -1950, 200, 200),
	# Patch 2.5 item 7: Ember Isle, the volcano island (VOLCANO), alone in the
	# south-eastern sea, over 1.2 km off every sea-lane leg and 3 km off every port.
	Rect2(4270, -4305, 420, 370),
]
## Patch 2.5 item 1: the named landmasses, as [name, first LAND index, end index).
const LANDMASSES = [
	["Hearthland", 0, 10], ["Northern Neck", 10, 12], ["Ironreach", 12, 20],
	["Kelp Isle", 20, 21], ["Gull Isle", 21, 22], ["Strait islets", 22, 24],
	["Palm Isles", 24, 27], ["Ember Isle", 27, 28],
]
## Patch 2.5 item 7: the one volcano. Chosen once and fixed here, so it is the
## same every run (and online later): a toon cone on Ember Isle (LAND index
## `land`), `base_m` round at the foot and `peak_m` to the crater.
const VOLCANO = {"id": "ember_isle_volcano", "name": "Ember Isle", "land": 27, "at": Vector2(4480, -4120), "base_m": 140.0, "peak_m": 170.0}
## Patch 2.1 item 3: snowy ice shelves beside the two polar quays, solid like
## land. Patch 2.5 item 1: each runs on to its quay, so the poles sit on a coast.
const ICE_SHELVES = [Rect2(3050, 3700, 450, 460), Rect2(-2100, -4360, 450, 500), Rect2(3500, 3700, 100, 460), Rect2(-2200, -4360, 100, 500)]
## Patch 2.5 item 1: the narrow ways through the land, like real ones. Each is
## a straight cut from `from` to `to` (X, Z), `width_m` clear water across. The
## sea lanes run down the middle; the narrowest still takes 2.5 beams of the
## biggest ship.
const STRAITS = [
	{"id": "needle_gut", "name": "Needle Gut", "like": "Bosphorus", "from": Vector2(680, 2850), "to": Vector2(680, 3550), "width_m": 200.0},
	{"id": "gannet_narrows", "name": "Gannet Narrows", "like": "Gibraltar", "from": Vector2(1625, -3550), "to": Vector2(1625, -4350), "width_m": 550.0},
	{"id": "kelp_strait", "name": "Kelp Strait", "like": "Malacca", "from": Vector2(3925, -2800), "to": Vector2(3925, 1600), "width_m": 250.0},
	{"id": "ironreach_canal", "name": "Ironreach Canal", "like": "Panama", "from": Vector2(1750, -830), "to": Vector2(3925, -830), "width_m": 140.0},
]
## Patch 2.5 item 2: toon bridges across the straits, crossing each at `at`
## (X, Z). Every tower and pier stands on land, out of the channel, and the
## deck's underside is BRIDGE_CLEARANCE_M above the sea: the tallest ship in any
## family (the Valemax bulker, about 49 m) passes under with room to spare.
const BRIDGES = [
	{"id": "gannet_narrows_bridge", "name": "Gannet Narrows Bridge", "strait": "gannet_narrows", "style": "suspension", "at": Vector2(1625, -3950)},
	{"id": "needle_gut_bridge", "name": "Needle Gut Bridge", "strait": "needle_gut", "style": "arch", "at": Vector2(680, 3200)},
	{"id": "kelp_strait_bridge", "name": "Kelp Strait Bridge", "strait": "kelp_strait", "style": "cable_stayed", "at": Vector2(3925, -2000)},
	{"id": "ironreach_canal_bridge", "name": "Ironreach Canal Bridge", "strait": "ironreach_canal", "style": "truss", "at": Vector2(2500, -830)},
]
const BRIDGE_CLEARANCE_M: float = 70.0

## A bridge's strait entry.
static func bridge_strait(index: int) -> Dictionary:
	for strait: Dictionary in STRAITS:
		if strait.id == BRIDGES[index].strait: return strait
	return {}

## Patch 2.5 item 1: sea-lane points (X, Z). Navigation finds the shortest way
## between them that keeps LANE_MARGIN_M off all land, ice, icebergs and quays.
## The first eight are the straits' mouths; the rest mark the open sea.
const SEA_LANES: Array[Vector2] = [
	Vector2(680, 2850), Vector2(680, 3550), Vector2(1625, -3550), Vector2(1625, -4350),
	Vector2(1750, -830), Vector2(3925, -830), Vector2(3925, -2800), Vector2(3925, 1600),
	Vector2(5500, -830), Vector2(5500, 3000), Vector2(5500, -3500), Vector2(-2600, -4800),
	Vector2(-4200, -2000), Vector2(-4200, 1500), Vector2(-2500, 3550), Vector2(250, 3550),
	Vector2(2400, 3550), Vector2(250, -4500), Vector2(3000, -4500), Vector2(1000, 4300),
	Vector2(500, 900), Vector2(500, -900), Vector2(450, 2400),
]
const LANE_MARGIN_M: float = 60.0
## Ships leave and reach every port through its gate, this far south of it.
const GATE_M: float = 450.0
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

## Patch 2.5 item 1: sea navigation round the land. Read-only helpers for the
## minimap's course and the checks; no ship is steered by them.
static var _obstacles: Array[Rect2] = []
static var _links: Array = []
static var _route_key: Array = []
static var _route: Array[Vector3] = []

## A port's quay and berths, kept clear by the sea lanes like land.
static func harbour(index: int) -> Rect2:
	var at: Vector3 = WORLD[index].at
	var quay_side: float = -float(WORLD[index].drop_side)
	return Rect2(minf(at.x - quay_side * 25, at.x + quay_side * 110), at.z - 60, 135, 1000)

## Where ships leave and reach a port: open water straight astern of its berths.
static func gate(index: int) -> Vector3:
	return WORLD[index].at + Vector3(0, 0, -GATE_M)

## Land, ice shelves, icebergs (as squares) and quays: everything a lane avoids.
static func obstacles() -> Array[Rect2]:
	if _obstacles.is_empty():
		for block: Rect2 in LAND + ICE_SHELVES: _obstacles.append(block)
		for index: int in WORLD.size(): _obstacles.append(harbour(index))
		for berg: Vector3 in ICEBERGS: _obstacles.append(Rect2(berg.x - berg.y, berg.z - berg.y, berg.y * 2, berg.y * 2))
	return _obstacles

## True when the straight run from `a` to `b`, the short way round the world,
## stays `margin` metres off every obstacle. An obstacle whose margin already
## holds an end (a ship near a coast or in a harbour) only has to be missed
## itself, and a harbour that holds an end is left out.
static func clear_line(a: Vector2, b: Vector2, margin: float = LANE_MARGIN_M) -> bool:
	var step: Vector3 = short_way(Vector3(b.x - a.x, 0, b.y - a.y))
	var to: Vector2 = a + Vector2(step.x, step.z)
	var span: Rect2 = Rect2(a, Vector2.ZERO).expand(to)
	var blocks: Array[Rect2] = obstacles()
	for index: int in blocks.size():
		for shift: Vector2 in [Vector2.ZERO, Vector2(WRAP_M, 0), Vector2(-WRAP_M, 0), Vector2(0, WRAP_M), Vector2(0, -WRAP_M), Vector2(WRAP_M, WRAP_M), Vector2(WRAP_M, -WRAP_M), Vector2(-WRAP_M, WRAP_M), Vector2(-WRAP_M, -WRAP_M)]:
			var block: Rect2 = Rect2(blocks[index].position + shift, blocks[index].size)
			var grown: Rect2 = block.grow(margin)
			if not grown.intersects(span.grow(1.0)): continue
			if grown.has_point(a) or grown.has_point(to):
				if block.has_point(a) or block.has_point(to): continue
				grown = block
			if _segment_hits(a, to, grown): return false
	return true

## Liang-Barsky: does the segment a-b touch the rectangle?
static func _segment_hits(a: Vector2, b: Vector2, box: Rect2) -> bool:
	var low: float = 0.0
	var high: float = 1.0
	var d: Vector2 = b - a
	for pair: Vector2 in [Vector2(-d.x, a.x - box.position.x), Vector2(d.x, box.end.x - a.x), Vector2(-d.y, a.y - box.position.y), Vector2(d.y, box.end.y - a.y)]:
		if is_zero_approx(pair.x):
			if pair.y < 0: return false
			continue
		var t: float = pair.y / pair.x
		if pair.x < 0: low = maxf(low, t)
		else: high = minf(high, t)
		if low > high: return false
	return true

static func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)

static func _apart(a: Vector2, b: Vector2) -> float:
	var step: Vector3 = short_way(Vector3(b.x - a.x, 0, b.y - a.y))
	return Vector2(step.x, step.z).length()

## The shortest way by sea from `from` to `to` through the lane points: the
## turning points after `from`, ending with `to`. Empty when there is none.
static func sea_route(from: Vector3, to: Vector3) -> Array[Vector3]:
	if _links.is_empty():
		for i: int in SEA_LANES.size():
			var row: PackedFloat32Array = PackedFloat32Array()
			for j: int in SEA_LANES.size():
				row.append(_apart(SEA_LANES[i], SEA_LANES[j]) if i != j and clear_line(SEA_LANES[i], SEA_LANES[j]) else INF)
			_links.append(row)
	var start: Vector2 = _flat(from)
	var goal: Vector2 = _flat(to)
	if clear_line(start, goal): return [to]
	var count: int = SEA_LANES.size()
	var to_goal: PackedFloat32Array = PackedFloat32Array()
	var best: PackedFloat32Array = PackedFloat32Array()
	var before: PackedInt32Array = PackedInt32Array()
	var done: PackedByteArray = PackedByteArray()
	for i: int in count:
		to_goal.append(_apart(SEA_LANES[i], goal) if clear_line(SEA_LANES[i], goal) else INF)
		best.append(_apart(start, SEA_LANES[i]) if clear_line(start, SEA_LANES[i]) else INF)
		before.append(-1)
		done.append(0)
	var finish: float = INF
	var last: int = -1
	while true:
		var next: int = -1
		for i: int in count:
			if done[i] == 0 and best[i] < INF and (next < 0 or best[i] < best[next]): next = i
		if next < 0 or best[next] >= finish: break
		done[next] = 1
		if best[next] + to_goal[next] < finish:
			finish = best[next] + to_goal[next]
			last = next
		for j: int in count:
			if done[j] == 0 and best[next] + _links[next][j] < best[j]:
				best[j] = best[next] + _links[next][j]
				before[j] = next
	var route: Array[Vector3] = []
	if last < 0: return route
	route.append(to)
	while last >= 0:
		route.push_front(Vector3(SEA_LANES[last].x, 0, SEA_LANES[last].y))
		last = before[last]
	return route

## The way by sea to a port's berth (`index` >= 0: through its gate, unless the
## ship is already in the port's own approach) or to an open-water point
## (`index` -1). Kept until the ship or the target moves 50 m.
static func course(from: Vector3, to: Vector3, index: int = -1) -> Array[Vector3]:
	var key: Array = [Vector2i(roundi(from.x / 50.0), roundi(from.z / 50.0)), Vector2i(roundi(to.x / 50.0), roundi(to.z / 50.0)), index]
	if key == _route_key: return _route
	var route: Array[Vector3] = []
	var local: Vector3 = short_way(from - WORLD[index].at) if index >= 0 else Vector3.ZERO
	if index < 0: route = sea_route(from, to)
	elif absf(local.x) < 400 and local.z > -GATE_M - 150 and local.z < 1000: route = [to]
	else:
		route = sea_route(from, gate(index))
		if not route.is_empty(): route.append(to)
	_route_key = key
	_route = route
	return route
