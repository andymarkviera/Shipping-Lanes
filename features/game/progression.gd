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
const SHIPS = {
	"container": {"name": "Container ship", "price_minor": 80000},
	"bulk": {"name": "Bulk carrier", "price_minor": 120000},
	"heavy": {"name": "Heavy lifter", "price_minor": 300000},
}
## A sold ship pays back half its price.
const RESALE_PERCENT: int = 50
## Bulk cargo: name, title, pay per 100 m sailed. Every port always has one job of
## each cargo, one for each other port. A delivered job is on offer again at once.
const BULK_CARGO = [["grain", "Grain, 4,000 t", 6000], ["coal", "Coal, 5,000 t", 8000], ["ore", "Iron ore, 6,000 t", 10000]]
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

## A bulk job from its ID, "bulk_<origin port>_<cargo>". Empty if there is none.
static func bulk_job(id: String) -> Dictionary:
	var parts: PackedStringArray = id.split("_")
	if parts.size() != 3 or parts[0] != "bulk" or not parts[1].is_valid_int(): return {}
	var origin: int = int(parts[1])
	if origin < 0 or origin >= WORLD.size() or parts[1] != str(origin): return {}
	for index: int in BULK_CARGO.size():
		if BULK_CARGO[index][0] != parts[2]: continue
		var destination: int = others(origin)[index]
		return {"title": BULK_CARGO[index][1], "origin": origin, "destination": destination, "reward_minor": int(BULK_CARGO[index][2]) * leg_units(origin, destination)}
	return {}

static func bulk_ids(origin: int) -> Array[String]:
	var result: Array[String] = []
	for cargo: Array in BULK_CARGO: result.append("bulk_%d_%s" % [origin, cargo[0]])
	return result

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
	if not d.get("ship") is String or not SHIPS.has(d.ship) or d.get("heavy_mode") != (d.ship == "heavy"): return false
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
	if not bulk.active.is_empty() and (d.ship != "bulk" or bulk_job(bulk.active).is_empty() or seen.has(bulk.active)): return false
	return true

## Pay from bulk and heavy jobs that are not listed one by one in the save.
## Call only after save_valid.
static func earned(d: Dictionary) -> int:
	var total: int = int(d.get("banked", 0))
	for id: String in d.bulk.done: total += int(BULK_V4[id])
	return total
