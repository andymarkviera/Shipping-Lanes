extends Node
## One server-wide berth owner, independent of temporary physics-space membership.
var world: Node
var entries: Dictionary = {}
var reservations: Dictionary = {}

func register(peer: int, owner: Node3D) -> void:
	entries[peer] = {"owner": owner, "port_id": "", "state": "underway", "remaining": 0.0}

func release(peer: int) -> void:
	if not entries.has(peer): return
	var entry: Dictionary = entries[peer]
	if reservations.get(entry.port_id) == peer: reservations.erase(entry.port_id)
	if is_instance_valid(entry.owner) and is_instance_valid(entry.owner.ship):
		entry.owner.ship.docked = false
	entry.state = "underway"
	entry.port_id = ""

func remove(peer: int) -> void:
	release(peer)
	entries.erase(peer)

func status(peer: int) -> Dictionary:
	if not entries.has(peer): return {"port_id": "", "state": "unavailable", "eligible": false, "message": "Ship unavailable."}
	var entry: Dictionary = entries[peer]
	if entry.owner.recovery_required() or entry.owner.damage_pending or entry.owner.recovery_placing: return {"port_id": "", "state": "unavailable", "eligible": false, "message": "Hull recovery or damage save in progress."}
	var port: Node3D = world.port_for(entry.owner, entry.port_id) if not entry.port_id.is_empty() else world.nearest_port(entry.owner)
	if port == null: return {"port_id": "", "state": entry.state, "eligible": false, "message": "Sail toward a port to dock."}
	if world.changed_frame == Engine.get_physics_frames(): return {"port_id": port.definition.id, "state": entry.state, "eligible": false, "message": "Updating port position…"}
	var readiness: Dictionary = port.berth_readiness(entry.owner.ship, "container_transfer", "cargo_test_container")
	if reservations.has(port.definition.id) and reservations[port.definition.id] != peer:
		readiness = {"eligible": false, "message": "Berth occupied. Wait for the other ship to undock."}
	return {"port_id": port.definition.id, "state": entry.state, "eligible": readiness.eligible, "message": readiness.message if entry.state == "underway" else entry.state.capitalize()}

func request(peer: int, action: String, port_id: String) -> Dictionary:
	if not entries.has(peer): return {"ok": false, "message": "Ship unavailable."}
	var entry: Dictionary = entries[peer]
	if not entry.owner.authority.active or entry.owner.departing: return {"ok": false, "message": "Connection is no longer active."}
	if action == "undock":
		if entry.owner.voyage_busy or preload("res://features/network/public_voyage_service.gd").active(entry.owner).get("state") == "loading": return {"ok": false, "message": "Wait for loading to finish or cancel the job."}
		if entry.state != "docked" or entry.port_id != port_id: return {"ok": false, "message": "Ship is not docked here."}
		entry.state = "undocking"
		entry.remaining = .5
		return {"ok": true, "message": "Releasing ship…"}
	if action != "dock" or entry.state != "underway": return {"ok": false, "message": "Wait for the current docking action."}
	var ready: Dictionary = status(peer)
	if ready.port_id != port_id or not ready.eligible: return {"ok": false, "message": ready.message}
	reservations[port_id] = peer
	entry.port_id = port_id
	entry.state = "docking"
	entry.remaining = 1.0
	freeze(entry.owner.ship)
	return {"ok": true, "message": "Securing ship…"}

func freeze(ship: HandlingShip) -> void:
	ship.docked = true
	ship.zero_throttle()
	ship.actual_throttle = 0
	ship.velocity = Vector3.ZERO
	ship.yaw_rate = 0
	ship.maneuver(0, 0)

func advance(delta: float) -> void:
	for peer: int in entries.keys():
		var entry: Dictionary = entries[peer]
		if not is_instance_valid(entry.owner) or not entry.owner.authority.active or entry.owner.departing:
			remove(peer)
			continue
		if entry.owner.recovery_required():
			release(peer)
			continue
		if entry.state == "underway": continue
		var port: Node3D = world.port_for(entry.owner, entry.port_id)
		if port == null:
			release(peer)
			continue
		freeze(entry.owner.ship)
		if world.changed_frame == Engine.get_physics_frames(): continue
		if entry.state == "docking" and not port.berth_readiness(entry.owner.ship, "container_transfer", "cargo_test_container").eligible:
			release(peer)
			continue
		if entry.state == "docked": continue
		entry.remaining -= delta
		if entry.remaining <= 0:
			if entry.state == "docking": entry.state = "docked"
			else: release(peer)
