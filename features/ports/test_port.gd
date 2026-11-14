extends Node3D
## Reusable static port content only. No wallets, jobs, ownership or transactions.
@export var definition: PortDefinition
@export var berth: BerthDefinition
@export var quay_side: int = -1
@export var quay_length_m: float = 140.0
## Authored per scene so the dressing never depends on a port ID.
@export_enum("gantry", "fuel_store") var landmark: String = "gantry"
## Patch 2.1 item 3: the polar ports. The game dresses them with snow and ice.
@export var icy: bool = false
var spawn_allocator = preload("res://features/ports/spawn_clearance.gd").new()
var recovery_anchors: Array[Marker3D] = []
var spawn_anchor: Marker3D
var approach_anchor: Marker3D
var berth_anchor: Marker3D
## Patch 2.1 item 4: each port has BERTH_COUNT berths in a row along its quay,
## BERTH_SPACING_M apart. Berth 1 is the authored one (berth_anchor); the
## others share its rules. Each berth holds one ship at a time.
## Patch 2.4 item 3: three berths, each long enough for a ship 5 (276 m), so
## three of the biggest ships fit at every port at once.
const BERTH_COUNT: int = 3
const BERTH_SPACING_M: float = 285.0
## Patch 2.4 item 3: the quay's timber face (see chunky_look.gd) is this far
## from the berth centreline. A docked ship lies off it by quay_gap_m().
const QUAY_FACE_M: float = 19.1
## Patch 2.4 item 4: the quay bollards (see chunky_look.gd), BOLLARD_STEP_M
## apart along the quay, BOLLARD_X_M from the berth centreline.
const BOLLARD_X_M: float = 23.5
const BOLLARD_STEP_M: float = 20.0
var berth_anchors: Array[Marker3D] = []

## Warehouses along the quay, as fractions of its length. Patch 2.4 item 3
## added more for the longer quays; the first is the original one.
const WAREHOUSES: Array[float] = [.7, .4, .9]

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
	berth_anchors = [berth_anchor]
	for i: int in range(1, BERTH_COUNT):
		berth_anchors.append(marker("Berth%d" % (i + 1), berth.position_m + Basis(Vector3.UP, -deg_to_rad(berth.heading_degrees)) * Vector3(0, 0, BERTH_SPACING_M * i), berth.heading_degrees))
	# The inner quay face is x=+/-20. The approach and berth centerline are x=0.
	block("Quay", Vector3(quay_side * 60, 1, quay_length_m / 2), Vector3(80, 6, quay_length_m), Color("76695b"))
	block("QuayEdge", Vector3(quay_side * 20.5, 4.1, quay_length_m / 2), Vector3(1, .2, quay_length_m - 4), Color("e2d6ad"), false)
	# The quay runs on past the last berth (half a ship 5 and a bit).
	var quay_end: float = berth_anchors[-1].position.z + 140.0
	if quay_end > quay_length_m:
		block("QuayExtension", Vector3(quay_side * 60, 1, (quay_length_m + quay_end) / 2), Vector3(80, 6, quay_end - quay_length_m), Color("76695b"))
		block("QuayExtensionEdge", Vector3(quay_side * 20.5, 4.1, (quay_length_m + quay_end) / 2), Vector3(1, .2, quay_end - quay_length_m - 2), Color("e2d6ad"), false)
	for shed: int in WAREHOUSES.size():
		var suffix: String = "" if shed == 0 else str(shed + 1)
		block("Warehouse" + suffix, Vector3(quay_side * 72, 15, quay_length_m * WAREHOUSES[shed]), Vector3(42, 22, 45), Color("566b70"))
		block("WarehouseRoof" + suffix, Vector3(quay_side * 72, 26.5, quay_length_m * WAREHOUSES[shed]), Vector3(46, 1, 49), Color("c5c0ad"), false)
	for i: int in 3:
		block("Container%d" % i, Vector3(quay_side * 46, 7, 24 + i * 16), Vector3(12, 6, 6), Color("b56749") if i % 2 == 0 else Color("799c9c"))
	if landmark == "fuel_store":
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

## Patch 2.0 easy docking (single-player): near + slow. berth_readiness above is
## the older strict rule, still used by the frozen online code.
## index picks the berth (0 is berth 1); claims are the docking authority's job.
func dock_readiness(body: HandlingShip, service: String, cargo_id: String, index: int = 0) -> Dictionary:
	var excluded: Array[RID] = [body.get_rid()]
	return preload("res://features/ports/berth_eligibility.gd").evaluate_easy(berth, berth_anchors[index].global_transform, body.definition, body.global_transform, body.velocity, service, cargo_id, get_world_3d().direct_space_state, excluded, quay_offset_m(body.definition))

func dock_pose(body: HandlingShip, index: int = 0) -> Transform3D:
	return preload("res://features/ports/berth_eligibility.gd").berth_pose(berth_anchors[index].global_transform, body.global_transform, quay_offset_m(body.definition))

## Patch 2.4 item 3: the fender gap between a docked hull and the quay face.
## About 8% of the beam: 1.2 m for small ships, up to 3 m for the biggest.
static func quay_gap_m(ship: ShipDefinition) -> float:
	return clampf(ship.hull_size_m.x * .08, 1.2, 3.0)

## Sideways offset of a docked ship's centre from the berth centreline, so its
## quay-side edge lies quay_gap_m() off the quay face (big hulls move outward).
func quay_offset_m(ship: ShipDefinition) -> float:
	return quay_side * (QUAY_FACE_M - ship.hull_size_m.x / 2 - quay_gap_m(ship))

## Patch 2.4 item 4: port-local tie points on the head of every quay bollard.
## Mooring lines (mooring_lines.gd) make fast to the nearest suitable one.
func bollard_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index: int in int(quay_length_m / BOLLARD_STEP_M):
		points.append(Vector3(quay_side * BOLLARD_X_M, 5.3, 10.0 + index * BOLLARD_STEP_M))
	return points

func berth_id(index: int) -> String:
	return berth.id if index == 0 else "%s_%02d" % [berth.id.trim_suffix("_01"), index + 1]

## The berth box in world space, as held clear of spawns while it is in use.
func berth_bounds(index: int) -> AABB:
	return berth_anchors[index].global_transform * AABB(-berth.envelope_m / 2, berth.envelope_m)
