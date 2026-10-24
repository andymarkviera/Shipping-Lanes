extends RefCounted
## Session authority for physical heavy cargo. No expiry or player transfers.
var active: Dictionary = {}
var completed: Dictionary = {}
var reward_pending: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func list_at(port_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i: int in 3:
		var id: String = "%s_heavy_%d" % [port_id, i]
		rows.append({"id": id, "title": ["Platform module", "Research module", "Equipment module"][i], "reward_minor": 70000 + i * 15000, "state": "completed" if completed.has(id) else ("accepted" if active.get("id", "") == id else "available")})
	return rows

func accept(id: String, body: HandlingShip, port: Node3D, docked: bool) -> bool:
	if not docked or not body.docked or not body.has_method("attach_payload") or not active.is_empty() or body.attached: return false
	var job: Dictionary = {}
	for row: Dictionary in list_at(port.definition.id):
		if row.id == id and row.state == "available": job = row
	if job.is_empty(): return false
	var pickup: Vector3 = port.to_global(Vector3(-port.quay_side * 95, -1, -80))
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = body.payload_shape.shape
	query.transform = Transform3D(port.global_basis, pickup + Vector3(0, 4, 0))
	query.collision_mask = CollisionRules.HULL | CollisionRules.SHORE | CollisionRules.CARGO_VISUAL
	query.exclude = [body.payload_body.get_rid()]
	if not port.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return false
	var destination: Vector3 = port.to_global(Vector3(-port.quay_side * rng.randf_range(450, 850), 0, rng.randf_range(-1200, -800)))
	active = {"id": id, "state": "pickup", "origin": port.definition.id, "drop": destination, "reward_minor": job.reward_minor}
	body.payload_body.global_transform = Transform3D(port.global_basis, pickup)
	body.payload_body.visible = true
	body.payload_body.collision_layer = CollisionRules.HULL
	body.release_guard = func(): return can_release(body)
	return true

func can_release(body: HandlingShip) -> bool:
	if active.is_empty(): return true
	return active.state == "carrying" and body.cargo_mount.global_position.distance_to(active.drop) <= 30

func update(body: HandlingShip) -> void:
	if active.is_empty(): return
	if active.state == "pickup" and body.attached:
		# Ocean destination is geographic data on this job, not a fabricated port ID.
		active.state = "carrying"
	if active.state == "carrying" and not body.attached and body.payload_body.global_position.distance_to(active.drop) <= 30:
		completed[active.id] = active.duplicate(true)
		reward_pending += active.reward_minor
		active.clear()
		body.release_guard = Callable()
		body.payload_body.collision_layer = 0
		body.payload_body.hide()

func cancel_pickup(body: HandlingShip) -> bool:
	if active.is_empty() or active.state != "pickup" or body.attached: return false
	active.clear()
	body.release_guard = Callable()
	body.payload_body.collision_layer = 0
	body.payload_body.hide()
	return true
