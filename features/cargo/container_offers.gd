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
			_offers[id] = {"id": id, "cargo_id": "cargo_test_container", "unit": "count", "quantity": index + 1, "origin_port_id": origin, "destination_port_id": destination, "reward_minor": (index + 1) * 25000, "expires_ms": -1, "state": "available", "owner_id": "", "ship_id": "", "accepted_ms": -1}

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
	var reward: int = 0
	for offer: Dictionary in _offers.values():
		if offer.state != "loaded" or offer.owner_id != owner or offer.ship_id != ship_id or offer.destination_port_id != port_id: continue
		var result: Dictionary = manifest.remove("batch_" + offer.id, offer.quantity)
		if result.ok:
			offer.state = "delivered"
			reward += offer.reward_minor
	return {"ok": reward > 0, "message": "Delivery complete." if reward > 0 else "No cargo for this port.", "reward_minor": reward}
