extends Node3D
## A shared authority cannot move ice to one viewer's nearest copy. Keep
## collision-only edge copies, built once, and a small pool for crossing hulls.
const Progression = preload("res://features/game/progression.gd")
var hulls: Dictionary = {}
var offsets: Array[Vector3] = []
var bounds: AABB
var static_shapes: int = 0

func setup(world: Node3D) -> void:
	var padding: float = 0.0
	for kind: String in Progression.SHIPS:
		padding = maxf(padding, Progression.definition(kind).hull_size_m.length() * 0.5 + 10.0)
	bounds = AABB(Progression.WRAP_CENTRE - Vector3(Progression.WRAP_M / 2, 200, Progression.WRAP_M / 2), Vector3(Progression.WRAP_M, 400, Progression.WRAP_M)).grow(padding)
	for x: int in [-1, 0, 1]:
		for z: int in [-1, 0, 1]:
			if x != 0 or z != 0: offsets.append(Vector3(x, 0, z) * Progression.WRAP_M)
	var shapes: Array[CollisionShape3D] = []
	collect_shapes(world, shapes)
	for offset: Vector3 in offsets:
		var copy: StaticBody3D = StaticBody3D.new()
		copy.collision_layer = CollisionRules.SHORE
		copy.collision_mask = CollisionRules.HULL
		add_child(copy)
		for source: CollisionShape3D in shapes:
			var pose: Transform3D = source.global_transform
			pose.origin += offset
			if not bounds.intersects(pose * source.shape.get_debug_mesh().get_aabb()): continue
			var shape: CollisionShape3D = CollisionShape3D.new()
			shape.shape = source.shape
			shape.transform = pose
			copy.add_child(shape)
			static_shapes += 1

static func collect_shapes(node: Node, result: Array[CollisionShape3D]) -> void:
	if node is CollisionShape3D and node.get_parent() is StaticBody3D and not node.disabled and node.shape != null:
		result.append(node)
	for child: Node in node.get_children(): collect_shapes(child, result)

func add_hull(id: String, ship: HandlingShip) -> void:
	var copies: Array[StaticBody3D] = []
	for offset: Vector3 in offsets:
		var copy: StaticBody3D = StaticBody3D.new()
		copy.collision_layer = 0
		copy.collision_mask = 0
		add_child(copy)
		for source: Node in ship.get_children():
			if source is CollisionShape3D:
				var shape: CollisionShape3D = CollisionShape3D.new()
				shape.shape = source.shape
				shape.transform = source.transform
				copy.add_child(shape)
		copies.append(copy)
		# A hull must never collide with its own periodic image.
		ship.add_collision_exception_with(copy)
	hulls[id] = copies

func sync(ships: Dictionary) -> void:
	for id: String in ships:
		var ship: HandlingShip = ships[id]
		for index: int in offsets.size():
			var copy: StaticBody3D = hulls[id][index]
			var pose: Transform3D = ship.global_transform
			pose.origin += offsets[index]
			copy.global_transform = pose
			copy.collision_layer = ship.collision_layer if bounds.has_point(pose.origin) else 0
			copy.constant_linear_velocity = ship.velocity

func remove_hull(id: String) -> void:
	for copy: StaticBody3D in hulls.get(id, []):
		copy.collision_layer = 0
		copy.queue_free()
	hulls.erase(id)
