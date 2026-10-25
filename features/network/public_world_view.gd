extends Node3D
## Read-only presentation replicas. Never grant helm, simulate fuel, or collide.
const Hull = preload("res://features/ships/starter_container_01/starter_runtime.tscn")
const Ports = preload("res://features/network/public_port_catalog.gd")
var ports: Dictionary = {}
var cargo_counts: Dictionary = {}
var replicas: Dictionary = {}
var tick: int = -1
var received_at: int = 0

func receive(next_tick: int, rows: Array) -> void:
	if next_tick <= tick or rows.size() > 8: return
	var incoming: Dictionary = {}
	for row: Variant in rows:
		if not row is Dictionary: return
		if not row.get("ship") is String or row.ship.is_empty() or incoming.has(row.ship): return
		if not row.get("generation") is int or row.generation <= 0: return
		if not row.get("position") is Vector3 or not row.position.is_finite() or row.position.length() > 1001: return
		if not (row.get("yaw") is float or row.get("yaw") is int) or not is_finite(row.yaw): return
		incoming[row.ship] = row
	tick = next_tick
	received_at = Time.get_ticks_msec()
	for id: String in replicas.keys():
		if not incoming.has(id) or replicas[id].generation != incoming[id].generation:
			replicas[id].node.queue_free()
			replicas.erase(id)
	for id: String in incoming:
		var row: Dictionary = incoming[id]
		if not replicas.has(id):
			var hull: HandlingShip = Hull.instantiate()
			hull.simulation_paused = true
			add_child(hull)
			hull.process_mode = Node.PROCESS_MODE_DISABLED
			hull.collision_layer = 0
			hull.collision_mask = 0
			hull.position = row.position
			hull.rotation.y = row.yaw
			replicas[id] = {"node": hull, "generation": row.generation}
		replicas[id].target = row.position
		replicas[id].yaw = row.yaw

func _process(delta: float) -> void:
	for port: Node3D in ports.values(): port.visible = Time.get_ticks_msec() - received_at <= 1500
	if Time.get_ticks_msec() - received_at > 1500:
		# Keep tick so delayed packets cannot revive an old roster.
		for record: Dictionary in replicas.values(): record.node.queue_free()
		replicas.clear()
		return
	for id: String in replicas:
		var record: Dictionary = replicas[id]
		var count: int = clampi(int(cargo_counts.get(id, 0)), 0, 6)
		var visuals: Node3D = record.node.assembly.container_visuals
		if visuals.instances != null:
			visuals.shown_count = count
			visuals.instances.multimesh.visible_instance_count = count
		record.node.position = record.node.position.lerp(record.target, 1.0 - exp(-15.0 * delta))
		record.node.rotation.y = lerp_angle(record.node.rotation.y, record.yaw, 1.0 - exp(-15.0 * delta))

func clear() -> void:
	cargo_counts.clear()
	for port: Node3D in ports.values(): port.queue_free()
	ports.clear()
	for record: Dictionary in replicas.values(): record.node.queue_free()
	replicas.clear()
	tick = -1

func inert(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child: Node in node.get_children(): inert(child)

func receive_ports(rows: Array) -> bool:
	var ids: Array[String] = []
	for row: Variant in rows:
		if not row is Dictionary or not Ports.IDS.has(row.get("id")) or ids.has(row.id) or not row.get("position") is Vector3 or not row.position.is_finite() or row.position.length() > 2500 or not (row.get("yaw") is float or row.get("yaw") is int) or not is_finite(row.yaw): return false
		ids.append(row.id)
	for id: String in ports.keys():
		if not ids.has(id):
			ports[id].queue_free()
			ports.erase(id)
	for row: Dictionary in rows:
		if not ports.has(row.id):
			var port: Node3D = Ports.SCENES[Ports.IDS.find(row.id)].instantiate()
			add_child(port)
			inert(port)
			ports[row.id] = port
		ports[row.id].position = row.position
		ports[row.id].rotation.y = row.yaw
	return true
