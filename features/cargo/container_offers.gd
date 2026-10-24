extends RefCounted
## Disposable seeded authority source. Identity, ship and clock come from authority.
var _now_ms: int = 0
var _offers: Dictionary = {}

func _init() -> void:
	for route: int in 2:
		var origin: String = "port_brindle_quay" if route == 0 else "port_slatewater_works"
		var destination: String = "port_slatewater_works" if route == 0 else "port_brindle_quay"
		for index: int in 3:
			var id: String = "container_seed_v1_%d_%d" % [route, index]
			_offers[id] = {"id": id, "cargo_id": "cargo_test_container", "unit": "count", "quantity": index + 1, "origin_port_id": origin, "destination_port_id": destination, "reward_minor": (index + 1) * 25000, "expires_ms": 600000, "state": "available", "owner_id": "", "ship_id": "", "accepted_ms": -1}

func advance_to(world_ms: int) -> bool:
	if world_ms < _now_ms or world_ms > 9000000000000: return false
	_now_ms = world_ms
	for offer: Dictionary in _offers.values():
		if offer.state == "available" and _now_ms >= offer.expires_ms: offer.state = "expired"
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

func accept(id: String, owner: String, ship_id: String, port_id: String, manifest: RefCounted) -> Dictionary:
	if owner.strip_edges().is_empty() or ship_id.strip_edges().is_empty() or manifest == null or not _offers.has(id): return {"ok": false, "message": "Invalid offer or ship."}
	var offer: Dictionary = _offers[id]
	if offer.state == "accepted":
		if offer.owner_id == owner and offer.ship_id == ship_id: return {"ok": true, "message": "Already accepted.", "offer": view(id)}
		return {"ok": false, "message": "Another captain accepted this offer."}
	if offer.state != "available" or _now_ms >= offer.expires_ms: return {"ok": false, "message": "Offer expired."}
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
	return {"ok": true, "message": "Accepted — loading comes next.", "offer": view(id)}
