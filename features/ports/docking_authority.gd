extends Node
## Server/local authority only. Caller must resolve peer identity and owned body.
## No client-writable reservations or client-supplied eligibility decisions.
## Patch 2.0 easy docking: after Dock the authority slides and turns the ship
## into the berth by itself. The slide lasts 1 to MAX_SLIDE_SECONDS.
## Patch 2.1 item 4 (multiplayer-safe docking): a port has several berths, each
## holds one ship. Dock takes the nearest free berth, skipping taken ones, and
## says the port is full when none is free. Berth claims live in `claims`, which
## a future server can own. While a ship slides in, sits at or leaves a berth,
## its collision with other ships is off; it comes back once the ship is out of
## the berth and clear of every other ship.
const MAX_SLIDE_SECONDS: float = 3.0
const SLIDE_MPS: float = 20.0
const SLIDE_TURN_RADPS: float = PI / 2
const PORT_FULL: String = "Port full — every berth is taken."
## How long Undock holds the ship in the berth before the helm is back. The
## game (Patch 2.4 item 4) raises it so the mooring lines are reeled in first.
var undock_seconds: float = 0.5
var members: Dictionary = {}
## Dedicated clients keep read-only presentation entries, never berth holds.
var presentation_only: bool = false
var claims = preload("res://features/ports/berth_claims.gd").new()
## Who holds which berth ("port_id/berth_id" -> owner). Read-only view of claims.
var reservations: Dictionary:
	get: return claims.holders

func state(owner: int) -> String:
	return members[owner].state if members.has(owner) else "underway"

func register(owner: int, body: HandlingShip, port: Node3D) -> bool:
	if owner <= 0 or members.has(owner) or not is_instance_valid(body) or not is_instance_valid(port): return false
	members[owner] = {"body": body, "port": port, "state": "underway", "remaining": 0.0, "hold": 0, "berth_id": port.berth.id, "berth_index": -1, "ghost": false}
	body.tree_exiting.connect(func():
		if members.has(owner) and members[owner].body == body: disconnect_owner(owner), CONNECT_ONE_SHOT)
	port.tree_exiting.connect(func():
		if members.has(owner) and members[owner].port == port: disconnect_owner(owner), CONNECT_ONE_SHOT)
	return true

func berth_key(port: Node3D, index: int) -> String:
	return claims.key(port.definition.id, port.berth_id(index))

## The berth Dock would use now: nearest first, a berth held by another ship or
## filled by one is skipped. {"index": -1} with the reason when none will do.
func pick_berth(owner: int, service: String, cargo: String) -> Dictionary:
	var entry: Dictionary = members[owner]
	var port: Node3D = entry.port
	var order: Array = range(port.berth_anchors.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return entry.body.global_position.distance_squared_to(port.berth_anchors[a].global_position) < entry.body.global_position.distance_squared_to(port.berth_anchors[b].global_position))
	var reason: Dictionary = {}
	for index: int in order:
		if claims.holder(berth_key(port, index)) not in [0, owner]: continue
		var readiness: Dictionary = port.dock_readiness(entry.body, service, cargo, index)
		if readiness.eligible: return {"index": index, "readiness": readiness}
		if readiness.code != "BLOCKED" and reason.is_empty(): reason = readiness
	if reason.is_empty(): reason = {"eligible": false, "code": "FULL", "message": PORT_FULL}
	return {"index": -1, "readiness": reason}

## What the Dock button shows: ready, what to do, or that the port is full.
func readiness(owner: int, service: String, cargo: String) -> Dictionary:
	if not members.has(owner): return {"eligible": false, "code": "INVALID_DATA", "message": "Ship unavailable."}
	return pick_berth(owner, service, cargo).readiness

func request_dock(owner: int, service: String, cargo: String) -> Dictionary:
	if not members.has(owner): return {"ok": false, "message": "Ship unavailable."}
	var entry: Dictionary = members[owner]
	if entry.state not in ["underway", "approaching"]: return {"ok": false, "message": "Docking action already in progress."}
	var pick: Dictionary = pick_berth(owner, service, cargo)
	if pick.index < 0: return {"ok": false, "message": pick.readiness.message}
	# No awaits between validation and claim: simultaneous requests serialize.
	if not claims.claim(berth_key(entry.port, pick.index), owner): return {"ok": false, "message": PORT_FULL}
	entry.berth_index = pick.index
	entry.berth_id = entry.port.berth_id(pick.index)
	entry.port.spawn_allocator.release(entry.hold)
	entry.hold = entry.port.spawn_allocator.hold_volume(entry.port.berth_bounds(pick.index))
	entry.service = service
	entry.cargo = cargo
	entry.state = "docking"
	entry.from = entry.body.global_transform.orthonormalized()
	entry.to = entry.port.dock_pose(entry.body, pick.index)
	var turn: float = entry.from.basis.get_rotation_quaternion().angle_to(entry.to.basis.get_rotation_quaternion())
	entry.duration = clampf(maxf(entry.from.origin.distance_to(entry.to.origin) / SLIDE_MPS, turn / SLIDE_TURN_RADPS), 1.0, MAX_SLIDE_SECONDS)
	entry.remaining = entry.duration
	ghost(entry, true)
	freeze(entry.body)
	return {"ok": true, "message": "Docking…"}

## Ship collision off (true) or back on (false). The shore still stops the hull.
func ghost(entry: Dictionary, on: bool) -> void:
	entry.ghost = on
	if not is_instance_valid(entry.body): return
	entry.body.collision_layer = CollisionRules.DOCKED_HULL if on else CollisionRules.HULL
	entry.body.collision_mask = CollisionRules.SHORE if on else CollisionRules.SOLID_WATERCRAFT

## Out of the berth box and not overlapping any other ship, docked or not.
func clear_of_berth(entry: Dictionary) -> bool:
	var body: HandlingShip = entry.body
	if entry.berth_index >= 0 and entry.berth_index < entry.port.berth_anchors.size():
		var anchor: Transform3D = entry.port.berth_anchors[entry.berth_index].global_transform
		var local: Vector3 = anchor.affine_inverse() * body.global_position
		var half: Vector3 = entry.port.berth.envelope_m / 2
		if absf(local.x) < half.x and absf(local.z) < half.z: return false
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = body.definition.hull_size_m + Vector3.ONE * 2
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = body.global_transform.translated_local(Vector3(0, 1, 0))
	query.collision_mask = CollisionRules.HULL | CollisionRules.DOCKED_HULL
	query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func freeze(body: HandlingShip) -> void:
	body.docked = true
	body.zero_throttle()
	body.actual_throttle = 0
	body.velocity = Vector3.ZERO
	body.yaw_rate = 0
	body.maneuver(0, 0)

## Gives up the berth. The ship stays a ghost until clear_of_berth(); the berth
## check sees ghost hulls, so nobody can slide in on top of it meanwhile.
func release(entry: Dictionary, owner: int) -> void:
	claims.release_owner(owner)
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
	members[owner].remaining = undock_seconds
	return true

func disconnect_owner(owner: int) -> void:
	if not members.has(owner): return
	if presentation_only:
		members.erase(owner)
		return
	release(members[owner], owner)
	ghost(members[owner], false)
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
			if entry.ghost and clear_of_berth(entry): ghost(entry, false)
			entry.state = "approaching" if entry.body.global_position.distance_to(entry.port.berth_anchor.global_position) < 150 else "underway"
			continue
		freeze(entry.body)
		if entry.state == "docked": continue
		if entry.state == "docking":
			var ready: Dictionary = entry.port.dock_readiness(entry.body, entry.service, entry.cargo, entry.berth_index)
			# The claim holder (a future server) may also take the berth back.
			if not ready.eligible or claims.holder(berth_key(entry.port, entry.berth_index)) != owner:
				release(entry, owner)
				continue
		entry.remaining -= delta
		if entry.state == "docking":
			# Ease in and out; the last step lands exactly on the berth pose.
			var t: float = smoothstep(0.0, 1.0, clampf(1.0 - entry.remaining / entry.duration, 0.0, 1.0))
			entry.body.global_transform = entry.from.interpolate_with(entry.to, t)
		if entry.remaining <= 0:
			if entry.state == "docking": entry.state = "docked"
			else: release(entry, owner)

func _exit_tree() -> void:
	for owner: int in members.keys(): disconnect_owner(owner)
