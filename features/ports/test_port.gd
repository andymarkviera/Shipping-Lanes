extends Node3D
## Reusable static port content only. No wallets, jobs, ownership or transactions.
@export var definition: PortDefinition
@export var berth: BerthDefinition
@export var quay_side: int = -1
@export var quay_length_m: float = 140.0
var spawn_allocator = preload("res://features/ports/spawn_clearance.gd").new()
var recovery_anchors: Array[Marker3D] = []
var spawn_anchor: Marker3D
var approach_anchor: Marker3D
var berth_anchor: Marker3D

func marker(label: String, at: Vector3, heading: float) -> Marker3D:
	var node: Marker3D = Marker3D.new()
	node.name = label
	node.position = at
	node.rotation.y = -deg_to_rad(heading)
	add_child(node)
	return node

func block(label: String, at: Vector3, size_: Vector3, color: Color, solid: bool = true) -> void:
	var parent: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.name = label
	parent.position = at
	add_child(parent)
	if solid:
		parent.collision_layer = CollisionRules.SHORE
		parent.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
		var collider: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size_
		collider.shape = shape
		parent.add_child(collider)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size_
	mesh.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	parent.add_child(mesh)

func _ready() -> void:
	assert(definition != null and berth != null and berth.port_id == definition.id)
	spawn_anchor = marker("Spawn", definition.spawn_position_m, definition.spawn_heading_degrees)
	for i: int in definition.recovery_positions_m.size():
		recovery_anchors.append(marker("Recovery%d" % i, definition.recovery_positions_m[i], definition.spawn_heading_degrees))
	approach_anchor = marker("Approach", definition.approach_position_m, definition.spawn_heading_degrees)
	berth_anchor = marker("Berth", berth.position_m, berth.heading_degrees)
	# Non-solid berth guide: never turns open water into an obstacle.
	var guide: Node3D = Node3D.new()
	guide.name = "BerthGuide"
	add_child(guide)
	guide.transform = berth_anchor.transform
	for side: int in [-1, 1]:
		for end: int in [-1, 1]:
			var line: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(4, .15, .4)
			line.mesh = mesh
			line.position = Vector3(side * (berth.envelope_m.x / 2 - 2), .7, end * berth.envelope_m.z / 2)
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_color = Color("f1d486")
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			line.material_override = material
			guide.add_child(line)
	var bow_label: Label3D = Label3D.new()
	bow_label.text = "BERTH — BOW THIS WAY"
	bow_label.position = Vector3(0, 5, berth.envelope_m.z / 2 + 5)
	bow_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bow_label.font_size = 40
	bow_label.pixel_size = .035
	guide.add_child(bow_label)
	# The inner quay face is x=+/-20. The approach and berth centerline are x=0.
	block("Quay", Vector3(quay_side * 60, 1, quay_length_m / 2), Vector3(80, 6, quay_length_m), Color("76695b"))
	block("QuayEdge", Vector3(quay_side * 20.5, 4.1, quay_length_m / 2), Vector3(1, .2, quay_length_m - 4), Color("e2d6ad"), false)
	block("Warehouse", Vector3(quay_side * 72, 15, quay_length_m * .7), Vector3(42, 22, 45), Color("566b70"))
	block("WarehouseRoof", Vector3(quay_side * 72, 26.5, quay_length_m * .7), Vector3(46, 1, 49), Color("c5c0ad"), false)
	for i: int in 3:
		block("Container%d" % i, Vector3(quay_side * 46, 7, 24 + i * 16), Vector3(12, 6, 6), Color("b56749") if i % 2 == 0 else Color("799c9c"))
	if definition.service_ids.has("refuel"):
		block("FuelStore", Vector3(quay_side * 83, 10, 25), Vector3(20, 12, 20), Color("d2b579"))
	else:
		block("GantryLegA", Vector3(quay_side * 34, 19, 35), Vector3(4, 30, 4), Color("ccad6a"))
		block("GantryLegB", Vector3(quay_side * 84, 19, 35), Vector3(4, 30, 4), Color("ccad6a"))
		block("GantryBeam", Vector3(quay_side * 59, 35, 35), Vector3(54, 3, 5), Color("ccad6a"))
	for i: int in 3:
		for side: int in [-1, 1]:
			block("ApproachMarker%d_%d" % [i, side], Vector3(side * 42, 1, -70 - i * 40), Vector3(3, 4, 3), Color("dfb879"))
	var sign: Label3D = Label3D.new()
	sign.text = definition.display_name
	sign.position = Vector3(quay_side * 60, 40, quay_length_m / 2)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 64
	sign.pixel_size = .09
	add_child(sign)

func service_view() -> Dictionary:
	return {"id": definition.id, "name": definition.display_name,
		"services": definition.service_ids.duplicate(), "berth_id": berth.id,
		"cargo_types": berth.cargo_type_ids.duplicate(), "berth_services": berth.service_ids.duplicate()}

func reserve_spawn(size: Vector3, cargo: Array[AABB] = []) -> Dictionary:
	var candidates: Array[Transform3D] = [spawn_anchor.global_transform]
	for anchor: Marker3D in recovery_anchors: candidates.append(anchor.global_transform)
	return spawn_allocator.reserve(get_world_3d().direct_space_state, candidates, size, Vector3(0, 1, 0), cargo)

func berth_readiness(body: HandlingShip, service: String, cargo_id: String) -> Dictionary:
	var excluded: Array[RID] = [body.get_rid()]
	return preload("res://features/ports/berth_eligibility.gd").evaluate(berth, berth_anchor.global_transform, body.definition, body.global_transform, body.velocity, service, cargo_id, get_world_3d().direct_space_state, excluded)
