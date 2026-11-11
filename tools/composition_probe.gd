extends Node3D
const STARTER = preload("res://features/ships/starter_container_01/starter_runtime.tscn")
const HEAVY = preload("res://features/ships/heavy_lifter_01/heavy_runtime.tscn")
var fixtures: Array[Dictionary] = []
var checks: int = 0
var failures: int = 0
var ticks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	for scene: PackedScene in [STARTER, HEAVY]:
		for kind: String in ["forward", "reverse", "side", "turn"]:
			make_fixture(scene, kind)
	var first: HandlingShip = fixtures[0].ship
	var second: HandlingShip = fixtures[1].ship
	var original: float = second.definition.forward_acceleration_mps2
	first.definition.forward_acceleration_mps2 = 0.01
	check(second.definition.forward_acceleration_mps2 == original, "Instances own independent tuning resources")
	first.definition.forward_acceleration_mps2 = original
	check(first.assembly.feedback != second.assembly.feedback and first.assembly.cargo_anchor != second.assembly.cargo_anchor, "Sound and cargo anchors are per-instance")
	check(fixtures[4].ship.definition.id == "ship_heavy_lifter_01", "Second hull has its own definition")
	check(fixtures[4].ship.definition.forward_acceleration_mps2 < original, "Heavy hull has different handling without a copied controller")

func make_fixture(scene: PackedScene, kind: String) -> void:
	var container: Node3D = Node3D.new()
	container.name = "ArbitraryParent%d" % fixtures.size()
	container.position = Vector3(fixtures.size() * 250, 0, 400)
	container.rotation.y = 0.35
	add_child(container)
	var ship: HandlingShip = scene.instantiate()
	container.add_child(ship)
	check(ship.assembly.visual.get_child_count() > 0, "Scene instances its own Blender visual")
	check(ship.assembly.focus.collision_body == ship, "Camera anchor resolves its own body")
	check(ship.assembly.cargo_anchor.position == ship.definition.cargo_anchor_m, "Definition locates cargo anchor")
	check(ship.assembly.focus.hull_radius == ship.definition.camera_radius_m, "Definition sizes camera clearance")
	var radius: float = ship.definition.hull_size_m.z * 0.5
	var limit: float = radius + 3
	if kind == "turn":
		ship.velocity = ship.global_basis.z * 4
		ship.maneuver(1, 0)
	else:
		var wall: StaticBody3D = StaticBody3D.new()
		wall.collision_layer = CollisionRules.SHORE
		var collider: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(150, 30, 0.1)
		wall.position.z = limit if kind == "forward" else -limit
		ship.velocity = ship.global_basis.z * (20 if kind == "forward" else -10)
		if kind == "side":
			limit = ship.definition.hull_size_m.x * 0.5 + 1.2
			box.size = Vector3(0.1, 30, 160)
			wall.position = Vector3(limit, 0, 0)
			ship.velocity = ship.global_basis.x
			# The neutral stopping assist halts a 1 m/s coast before the wall; hold the thruster.
			ship.maneuver(0, -1)
		collider.shape = box
		wall.add_child(collider)
		container.add_child(wall)
	fixtures.append({"ship": ship, "parent": container, "kind": kind, "limit": limit, "contact": false})

func _physics_process(_delta: float) -> void:
	ticks += 1
	for item: Dictionary in fixtures:
		item.contact = item.contact or item.ship.get_slide_collision_count() > 0
	if ticks != 241: return
	for item: Dictionary in fixtures:
		var ship: HandlingShip = item.ship
		var local: Vector3 = ship.position
		check(local.is_finite() and absf(local.y) < 0.001 and ship.velocity.length() <= 20.001, "Composed hull stays planar and bounded")
		if item.kind == "turn":
			check(local.x < -0.05 and ship.rotation.y < -0.02, "Composed hull passes turning leg")
		else:
			check(item.contact, "Composed hull contacts " + item.kind + " course boundary")
			var extent: float = ship.definition.hull_size_m.x * 0.5 if item.kind == "side" else ship.definition.hull_size_m.z * 0.5
			var position_axis: float = local.x if item.kind == "side" else absf(local.z)
			check(position_axis + extent < item.limit, "Composed hull cannot penetrate " + item.kind + " boundary")
	check(absf(fixtures[7].ship.rotation.y) < absf(fixtures[3].ship.rotation.y), "Heavy profile turns more gently on identical input")
	set_physics_process(false)
	finish.call_deferred()

func finish() -> void:
	var carrier: HandlingShip = fixtures[4].ship
	var floating: StaticBody3D = carrier.payload_body
	var instance_id: int = floating.get_instance_id()
	carrier.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_id_valid(instance_id), "Removing carrier cleans up its staged test cargo")
	print("COMPOSITION_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
