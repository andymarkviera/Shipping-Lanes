extends RefCounted
## Disposable seeded authority source. Identity, ship and clock come from authority.
var _now_ms: int = 0
var _offers: Dictionary = {}

const Progression = preload("res://features/game/progression.gd")

func _init() -> void:
	for route: int in 2:
		for index: int in 3:
			var id: String = "container_seed_v1_%d_%d" % [route, index]
			_offers[id] = fresh(id)

static func blank(id: String, quantity: int, origin: String, destination: String, reward_minor: int) -> Dictionary:
	return {"id": id, "cargo_id": "cargo_test_container", "unit": "count", "quantity": quantity, "origin_port_id": origin, "destination_port_id": destination, "reward_minor": reward_minor, "expires_ms": -1, "state": "available", "owner_id": "", "ship_id": "", "accepted_ms": -1}

## Patch 2.0 (bigger loads). The game's container ship carries 24 containers
## (starter_ship.tres; ports_probe checks the two agree). Pay is per container
## per 100 m sailed, in hundredths of a credit: 45.00 a container on the 1.5 km hop.
const GAME_CAPACITY: int = 24
const PAY_PER_CONTAINER_100M: int = 300

## Seconds at the berth to load a job: 5 s a container for the first three (as
## before), then half a second each, so a full deck takes about 25 s.
static func loading_seconds(quantity: int) -> float:
	return quantity * 5.0 if quantity <= 3 else 15.0 + (quantity - 3) * 0.5

## Containers in a game job. Slot 0 is a handful (4, 6 or 8), slot 1 a part
## load (10 to 16), slot 2 a full ship. The size changes each turn of a slot.
static func game_quantity(port: int, slot: int, turn: int) -> int:
	if slot == 0: return 4 + 2 * ((port + turn) % 3)
	if slot == 1: return 10 + 2 * ((port + turn) % 4)
	return GAME_CAPACITY

## An untouched offer, rebuilt from its ID alone. Empty for an unknown ID.
## "container_seed_v1_<route>_<index>": the six Port Test jobs.
## "container_load_<port>_<slot>_<turn>" (the game only): three slots per port.
## Each turn of a slot goes to the next port along and pays by load and distance.
## "container_game_<port>_<slot>_<turn>": the 1, 2 and 3 container jobs from
## before Patch 2.0. Still read so older saves load; no longer put on offer.
static func fresh(id: String, game: bool = false) -> Dictionary:
	var parts: PackedStringArray = id.split("_")
	if parts.size() != 5 or parts[0] != "container": return {}
	# The numbers must be plain: no sign, no padding. Seeds carry "v1" in place of a port.
	for part: String in ["0" if parts[1] == "seed" else parts[2], parts[3], parts[4]]:
		if not part.is_valid_int() or part != str(int(part)) or int(part) < 0 or int(part) > 100000: return {}
	if parts[1] == "seed" and parts[2] == "v1" and int(parts[3]) < 2 and int(parts[4]) < 3:
		var route: int = int(parts[3])
		return blank(id,int(parts[4]) + 1, Progression.WORLD[route].id, Progression.WORLD[1 - route].id, (int(parts[4]) + 1) * 25000)
	if not game or parts[1] not in ["game", "load"] or int(parts[2]) >= Progression.WORLD.size() or int(parts[3]) > 2: return {}
	var origin: int = int(parts[2])
	var destination: int = Progression.others(origin)[(int(parts[3]) + int(parts[4])) % (Progression.WORLD.size() - 1)]
	if parts[1] == "load":
		var quantity: int = game_quantity(origin, int(parts[3]), int(parts[4]))
		return blank(id, quantity, Progression.WORLD[origin].id, Progression.WORLD[destination].id, quantity * Progression.leg_units(origin, destination) * PAY_PER_CONTAINER_100M)
	# 250.00 credits per container on the 1.5 km hop, more on longer legs.
	var per_container: int = Progression.leg_units(origin, destination) * 5000 / 3 / 1000 * 1000
	return blank(id,int(parts[3]) + 1, Progression.WORLD[origin].id, Progression.WORLD[destination].id, (int(parts[3]) + 1) * per_container)

## The game only: keep three open jobs at every port. When a job is delivered or
## abandoned, the next one for that slot is added. Offers never expire. Untaken
## small jobs from before Patch 2.0 are withdrawn; taken or finished ones stay.
func restock() -> void:
	var latest: Dictionary = {}
	for id: String in _offers.keys():
		var parts: PackedStringArray = id.split("_")
		if parts[1] == "game" and _offers[id].state == "available": _offers.erase(id)
		if parts[1] != "load": continue
		var slot: String = parts[2] + "_" + parts[3]
		latest[slot] = maxi(int(latest.get(slot, -1)), int(parts[4]))
	for port: int in Progression.WORLD.size():
		for index: int in 3:
			var slot: String = "%d_%d" % [port, index]
			var turn: int = int(latest.get(slot, -1))
			if turn >= 0 and _offers["container_load_%s_%d" % [slot, turn]].state not in ["delivered", "abandoned"]: continue
			var id: String = "container_load_%s_%d" % [slot, turn + 1]
			_offers[id] = fresh(id, true)

func advance_to(world_ms: int) -> bool:
	if world_ms < _now_ms or world_ms > 9000000000000: return false
	_now_ms = world_ms
	return true

func view(id: String) -> Dictionary:
	return _offers.get(id, {}).duplicate(true)

func list_at(port_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offer: Dictionary in _offers.values():
		if offer.origin_port_id == port_id: result.append(offer.duplicate(true))
	return result

func batch(offer: Dictionary) -> Dictionary:
	return {"batch_id": "batch_" + offer.id, "cargo_id": offer.cargo_id, "quantity": offer.quantity, "unit": offer.unit, "origin_port_id": offer.origin_port_id, "destination_port_id": offer.destination_port_id, "acquisition_id": "", "job_id": "job_" + offer.id}

func active_job(owner: String) -> Dictionary:
	for offer: Dictionary in _offers.values():
		if offer.owner_id == owner and offer.state in ["accepted", "loaded"]: return offer.duplicate(true)
	return {}

func accept(id: String, owner: String, ship_id: String, port_id: String, manifest: RefCounted) -> Dictionary:
	if owner.strip_edges().is_empty() or ship_id.strip_edges().is_empty() or manifest == null or not _offers.has(id): return {"ok": false, "message": "Invalid offer or ship."}
	var offer: Dictionary = _offers[id]
	if offer.state in ["accepted", "loaded"]:
		if offer.owner_id == owner and offer.ship_id == ship_id: return {"ok": true, "message": "Already accepted.", "offer": view(id)}
		return {"ok": false, "message": "Another captain accepted this offer."}
	if not active_job(owner).is_empty(): return {"ok": false, "message": "Deliver or cancel your current job before accepting another."}
	if offer.state != "available": return {"ok": false, "message": "Job is not available."}
	if port_id != offer.origin_port_id: return {"ok": false, "message": "Accept this offer at its origin port."}
	var candidate: Array[Dictionary] = manifest.lines()
	# Pending jobs reserve capacity as well as physical cargo. Loading integration
	# must mark jobs loaded before replacing these commitments with actual batches.
	for prior: Dictionary in _offers.values():
		if prior.state == "accepted" and prior.ship_id == ship_id: candidate.append(batch(prior))
	candidate.append(batch(offer))
	var error: String = manifest.validate(candidate)
	if not error.is_empty(): return {"ok": false, "message": error}
	# No yield between eligibility and exclusive assignment.
	offer.state = "accepted"
	offer.owner_id = owner
	offer.ship_id = ship_id
	offer.accepted_ms = _now_ms
	return {"ok": true, "message": "Accepted — dock at the origin to load.", "offer": view(id)}

func loading_error(id: String, owner: String, ship_id: String, port_id: String, manifest: RefCounted) -> String:
	var offer: Dictionary = view(id)
	if offer.is_empty() or offer.state != "accepted" or offer.owner_id != owner or offer.ship_id != ship_id or offer.origin_port_id != port_id: return "No matching accepted job at this port."
	var candidate: Array[Dictionary] = manifest.lines()
	for pending: Dictionary in _offers.values():
		if pending.state == "accepted" and pending.ship_id == ship_id: candidate.append(batch(pending))
	return manifest.validate(candidate)

func complete_loading(id: String, owner: String, ship_id: String, port_id: String, manifest: RefCounted) -> Dictionary:
	var error: String = loading_error(id, owner, ship_id, port_id, manifest)
	if not error.is_empty(): return {"ok": false, "message": error}
	var result: Dictionary = manifest.add(batch(_offers[id]))
	if result.ok: _offers[id].state = "loaded"
	return result

func release_job(id: String, owner: String, ship_id: String) -> bool:
	if not _offers.has(id): return false
	var offer: Dictionary = _offers[id]
	if offer.state != "accepted" or offer.owner_id != owner or offer.ship_id != ship_id: return false
	offer.state = "available"
	offer.owner_id = ""
	offer.ship_id = ""
	offer.accepted_ms = -1
	return true

func release_pending(owner: String, ship_id: String) -> void:
	for id: String in _offers: release_job(id, owner, ship_id)

func deliver_at(owner: String, ship_id: String, port_id: String, manifest: RefCounted, docked: bool) -> Dictionary:
	if not docked: return {"ok": false, "message": "Dock at the destination first.", "reward_minor": 0}
	var candidate: Array[Dictionary] = manifest.lines()
	var delivered: Array[Dictionary] = []
	var reward: int = 0
	for offer: Dictionary in _offers.values():
		if offer.state != "loaded" or offer.owner_id != owner or offer.ship_id != ship_id or offer.destination_port_id != port_id: continue
		var index: int = -1
		for i: int in candidate.size():
			if candidate[i].batch_id == "batch_" + offer.id: index = i; break
		if index < 0 or candidate[index] != batch(offer): return {"ok": false, "message": "Job cargo does not match its accepted terms.", "reward_minor": 0}
		candidate.remove_at(index)
		delivered.append(offer)
		reward += offer.reward_minor
	if delivered.is_empty(): return {"ok": false, "message": "No cargo for this port.", "reward_minor": 0}
	var result: Dictionary = manifest.replace(candidate)
	if not result.ok: return {"ok": false, "message": result.message, "reward_minor": 0}
	for offer: Dictionary in delivered: offer.state = "delivered"
	return {"ok": true, "message": "Delivery complete.", "reward_minor": reward}
