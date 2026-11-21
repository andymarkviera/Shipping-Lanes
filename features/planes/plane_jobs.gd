extends RefCounted
## Patch 4.0 item 11: plane jobs, their own type: Passengers ("pax") and
## Packages ("pkg"), offered at every airport for every other airport, in
## a few fixed sizes. Like bulk jobs they are always on offer again once
## delivered, so a job is fully described by its ID:
## "air_<origin airport>_<destination airport>_<pax|pkg>_<quantity>".
## Planes earn more per trip than boats but carry little.
const Airports = preload("res://features/planes/airports.gd")
const Progression = preload("res://features/game/progression.gd")
const KINDS = {"pax": "Passengers", "pkg": "Packages"}
const SIZES = {"pax": [2, 4, 12, 24], "pkg": [4, 16, 24, 40]}
## Pay per passenger or parcel per km of the leg (hundredths of a credit),
## plus a flat fee per trip. A 4-seat hop of 5 km pays about 4,700 credits;
## a starter container ship earns about 2,900 for a leg that size.
const PAY_PER_UNIT_KM = {"pax": 22000, "pkg": 15000}
const TRIP_FEE_MINOR: int = 30000
## Patch 4.0: at most this many job cards at an airport.
const BOARD_SIZE: int = 6

static func make_id(origin: int, destination: int, kind: String, quantity: int) -> String:
	return "air_%d_%d_%s_%d" % [origin, destination, kind, quantity]

static func leg_km(origin: int, destination: int) -> float:
	var list: Array[Dictionary] = Airports.all()
	# Patch 4.0.3 item 8: the way a plane flies (never across the pole).
	return Airports.local_to(list[origin].at, list[destination].at).length() / 1000.0

## A job from its ID, or {} if there is none.
static func job(id: String) -> Dictionary:
	var parts: PackedStringArray = id.split("_")
	if parts.size() != 5 or parts[0] != "air" or not KINDS.has(parts[3]): return {}
	for index: int in [1, 2, 4]:
		if not parts[index].is_valid_int() or str(int(parts[index])) != parts[index]: return {}
	var origin: int = int(parts[1])
	var destination: int = int(parts[2])
	var quantity: int = int(parts[4])
	if origin < 0 or destination < 0 or origin >= Airports.count() or destination >= Airports.count() or origin == destination: return {}
	if not SIZES[parts[3]].has(quantity): return {}
	var pay: int = TRIP_FEE_MINOR + roundi(quantity * leg_km(origin, destination) * PAY_PER_UNIT_KM[parts[3]])
	var label: String = "%d passenger%s" % [quantity, "" if quantity == 1 else "s"] if parts[3] == "pax" else "%d package%s" % [quantity, "" if quantity == 1 else "s"]
	return {"id": id, "origin": origin, "destination": destination, "kind": parts[3], "quantity": quantity, "capacity": quantity, "reward_minor": pay, "title": label}

## The job board at an airport for a plane: what it can carry, biggest first,
## at most BOARD_SIZE cards, one per destination where it can.
static func board(origin: int, plane: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if plane.is_empty(): return rows
	var capacity: int = int(plane.capacity)
	for kind: String in plane.jobs:
		var sizes: Array = SIZES[kind].filter(func(q: int) -> bool: return q <= capacity)
		if sizes.is_empty(): continue
		for destination: int in Airports.count():
			if destination == origin: continue
			rows.append(job(make_id(origin, destination, kind, int(sizes.back()))))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.reward_minor > b.reward_minor if a.reward_minor != b.reward_minor else a.id < b.id)
	rows.resize(mini(rows.size(), BOARD_SIZE))
	return rows

## Patch 4.0.3 item 6: a job card's trip estimate for a plane: the leg in
## km, the minutes at cruise (CRUISE_SHARE of top speed) and the fuel that
## burns at full throttle for that long (litres, rounded up). {} when the
## job or plane is unknown.
const Planes = preload("res://features/planes/plane_catalog.gd")
const CRUISE_SHARE: float = 0.8

static func trip(id: String, kind: String) -> Dictionary:
	var picked: Dictionary = job(id)
	if picked.is_empty() or not Planes.PLANES.has(kind): return {}
	var km: float = leg_km(int(picked.origin), int(picked.destination))
	var seconds: float = km * 1000.0 / (Planes.top_speed(kind) * CRUISE_SHARE)
	return {"km": km, "minutes": maxi(1, ceili(seconds / 60.0)), "fuel_l": ceilf(seconds * float(Planes.PLANES[kind].burn_lps))}
