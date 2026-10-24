extends Node
## Server/local authority only. Caller must resolve peer identity and owned body.
## No client-writable reservations or client-supplied eligibility decisions.
var members: Dictionary = {}
var reservations: Dictionary = {}

func state(owner: int) -> String:
	return members[owner].state if members.has(owner) else "underway"

func register(owner: int, body: HandlingShip, port: Node3D) -> bool:
	if owner <= 0 or members.has(owner) or not is_instance_valid(body) or not is_instance_valid(port): return false
	members[owner] = {"body": body, "port": port, "state": "underway", "remaining": 0.0, "hold": 0, "berth_id": port.berth.id}
	body.tree_exiting.connect(func():
		if members.has(owner) and members[owner].body == body: disconnect_owner(owner), CONNECT_ONE_SHOT)
	port.tree_exiting.connect(func():
		if members.has(owner) and members[owner].port == port: disconnect_owner(owner), CONNECT_ONE_SHOT)
	return true

func request_dock(owner: int, service: String, cargo: String) -> Dictionary:
	if not members.has(owner): return {"ok": false, "message": "Ship unavailable."}
	var entry: Dictionary = members[owner]
	if entry.state not in ["underway", "approaching"]: return {"ok": false, "message": "Docking action already in progress."}
	var id: String = entry.port.berth.id
	if reservations.has(id): return {"ok": false, "message": "Berth occupied. Wait for it to clear."}
	var readiness: Dictionary = entry.port.berth_readiness(entry.body, service, cargo)
	if not readiness.eligible: return {"ok": false, "message": readiness.message}
	# No awaits between validation and reservation: simultaneous requests serialize.
	reservations[id] = owner
	var bounds: AABB = entry.port.berth_anchor.global_transform * AABB(-entry.port.berth.envelope_m / 2, entry.port.berth.envelope_m)
	entry.hold = entry.port.spawn_allocator.hold_volume(bounds)
	entry.service = service
	entry.cargo = cargo
	entry.state = "docking"
	entry.remaining = 1.0
	freeze(entry.body)
	return {"ok": true, "message": "Securing ship…"}

func freeze(body: HandlingShip) -> void:
	body.docked = true
	body.zero_throttle()
	body.actual_throttle = 0
	body.velocity = Vector3.ZERO
	body.yaw_rate = 0
	body.maneuver(0, 0)

func release(entry: Dictionary, owner: int) -> void:
	if reservations.get(entry.berth_id, 0) == owner: reservations.erase(entry.berth_id)
	if is_instance_valid(entry.port):
		entry.port.spawn_allocator.release(entry.hold)
	entry.hold = 0
	if is_instance_valid(entry.body) and entry.state in ["docking", "docked", "undocking"]:
		freeze(entry.body)
		entry.body.docked = false
	entry.state = "underway"

func cancel(owner: int) -> bool:
	if not members.has(owner) or members[owner].state not in ["docking", "undocking"]: return false
	var entry: Dictionary = members[owner]
	if entry.state == "undocking":
		entry.state = "docked"
		freeze(entry.body)
	else: release(entry, owner)
	return true

func request_undock(owner: int) -> bool:
	if state(owner) != "docked": return false
	members[owner].state = "undocking"
	members[owner].remaining = 0.5
	return true

func disconnect_owner(owner: int) -> void:
	if not members.has(owner): return
	release(members[owner], owner)
	members.erase(owner)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	for owner: int in members.keys():
		var entry: Dictionary = members[owner]
		if not is_instance_valid(entry.body) or not is_instance_valid(entry.port):
			disconnect_owner(owner)
			continue
		if entry.state in ["underway", "approaching"]:
			entry.state = "approaching" if entry.body.global_position.distance_to(entry.port.berth_anchor.global_position) < 150 else "underway"
			continue
		freeze(entry.body)
		if entry.state == "docked": continue
		if entry.state == "docking":
			var ready: Dictionary = entry.port.berth_readiness(entry.body, entry.service, entry.cargo)
			if not ready.eligible:
				release(entry, owner)
				continue
		entry.remaining -= delta
		if entry.remaining <= 0:
			if entry.state == "docking": entry.state = "docked"
			else: release(entry, owner)

func _exit_tree() -> void:
	for owner: int in members.keys(): disconnect_owner(owner)
