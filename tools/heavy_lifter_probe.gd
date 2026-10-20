extends Node3D
const Heavy = preload("res://features/handling/heavy_lifter.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var ship: Heavy = Heavy.new()
	add_child(ship)
	ship.set_physics_process(false)
	await get_tree().physics_frame
	check(ship.get_child(0) is Node3D and ship.deck_visual.get_child_count() > 0, "Blender hull and separate moving deck imported")
	check(not ship.attach_payload(), "Raised deck rejects attachment")
	check(not ship.detach_payload(), "Cannot release missing load")
	ship.velocity.z = 1
	check(not ship.request_height(Heavy.LOWERED), "Moving ship rejects deck operation")
	ship.velocity = Vector3.ZERO
	check(ship.request_height(Heavy.LOWERED), "Stopped ship lowers deck")
	for tick: int in range(240): ship.advance_deck(1.0 / 60.0)
	check(is_equal_approx(ship.deck_height, Heavy.LOWERED), "Deck reaches exact lower stop")
	check(not ship.attach_payload(), "Off-center load rejected")
	check(ship.align_test_payload(), "Fixture stages load in clear loading space")
	await get_tree().physics_frame
	ship.payload_body.rotation.y = 0.2
	check(not ship.attach_payload(), "Misaligned heading rejected")
	ship.payload_body.rotation.y = 0
	check(ship.attach_payload(), "Aligned load attaches")
	check(not ship.attach_payload(), "Duplicate attachment rejected")
	check(ship.payload_body.collision_layer == 0 and not ship.payload_shape.disabled, "Exactly one active cargo collision owner")
	check(ship.payload_visual.get_parent() == ship.cargo_mount, "Cargo becomes a fixed transform child")
	var obstruction: StaticBody3D = StaticBody3D.new()
	obstruction.position = Vector3(0, 9, -8)
	obstruction.collision_layer = CollisionRules.SHORE
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(12, 0.5, 30)
	shape.shape = box
	obstruction.add_child(shape)
	add_child(obstruction)
	await get_tree().physics_frame
	ship.request_height(Heavy.RAISED)
	for tick: int in range(240): ship.advance_deck(1.0 / 60.0)
	check(ship.deck_height < Heavy.RAISED and ship.notice.contains("blocked"), "Payload cannot lift through overhead solid")
	remove_child(obstruction)
	obstruction.queue_free()
	await get_tree().physics_frame
	check(ship.request_height(Heavy.RAISED), "Lift can resume after obstruction removed")
	for tick: int in range(240): ship.advance_deck(1.0 / 60.0)
	check(is_equal_approx(ship.deck_height, Heavy.RAISED), "Loaded deck reaches raised stop")
	check(is_equal_approx(ship.payload_visual.global_position.y, Heavy.RAISED), "Load rises with deck without relative slipping")
	check(not ship.detach_payload(), "Raised deck cannot drop cargo")
	var relative: Transform3D = ship.global_transform.affine_inverse() * ship.payload_visual.global_transform
	ship.command_throttle(1)
	ship.maneuver(1, 0)
	ship.set_physics_process(true)
	for tick: int in range(360):
		await get_tree().physics_frame
	ship.set_physics_process(false)
	check(ship.position.length() > 5 and absf(ship.rotation.y) > 0.03, "Loaded carrier sails and turns with existing controller")
	var after: Transform3D = ship.global_transform.affine_inverse() * ship.payload_visual.global_transform
	check(after.origin.distance_to(relative.origin) < 0.001 and after.basis.is_equal_approx(relative.basis), "Cargo remains attached through real physics turning")
	check(absf(ship.position.y) < 0.001 and ship.velocity.length() < 20.001, "No stacked-body vertical instability or overspeed")
	# Verify the cargo's high envelope participates in an actual body sweep.
	var rail: StaticBody3D = StaticBody3D.new()
	rail.global_transform = ship.global_transform
	rail.position = ship.to_global(Vector3(12, 8, -8))
	rail.collision_layer = CollisionRules.SHORE
	var rail_shape: CollisionShape3D = CollisionShape3D.new()
	var rail_box: BoxShape3D = BoxShape3D.new()
	rail_box.size = Vector3(0.5, 1, 20)
	rail_shape.shape = rail_box
	rail.add_child(rail_shape)
	add_child(rail)
	await get_tree().physics_frame
	check(ship.test_move(ship.global_transform, ship.global_basis.x * 10), "Cargo envelope blocks a high obstacle missed by empty deck")
	ship.payload_shape.disabled = true
	check(not ship.test_move(ship.global_transform, ship.global_basis.x * 10), "Empty hull clears the same high obstacle")
	ship.payload_shape.disabled = false
	remove_child(rail)
	rail.queue_free()
	ship.velocity = Vector3.ZERO
	ship.zero_throttle()
	ship.actual_throttle = 0
	ship.maneuver(0, 0)
	ship.request_height(Heavy.LOWERED)
	for tick: int in range(240): ship.advance_deck(1.0 / 60.0)
	var release_pose: Transform3D = ship.payload_visual.global_transform
	check(ship.detach_payload(), "Lowered load releases")
	check(ship.payload_visual.global_transform.is_equal_approx(release_pose), "Release preserves world pose")
	check(ship.payload_body.collision_layer == CollisionRules.HULL and ship.payload_shape.disabled, "Detached load regains sole collision ownership")
	ship.request_height(Heavy.RAISED)
	ship.advance_deck(1.0 / 60.0)
	check(ship.deck_height == Heavy.LOWERED, "Unsecured load cannot be raised through")
	check(ship.attach_payload(), "Same payload can be loaded again")
	ship.payload_body.queue_free()
	ship.queue_free()
	await get_tree().process_frame
	var scene: Node3D = load("res://features/handling/heavy_lifter_test.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	check(scene.ship != null and scene.camera.focus.collision_body == scene.ship, "Playable test uses size-aware camera and heavy carrier")
	scene.buttons[0].pressed.emit()
	check(scene.ship.deck_target == Heavy.LOWERED, "Visible lower button targets the deck")
	scene.ship.set_physics_process(false)
	for tick: int in range(240): scene.ship.advance_deck(1.0 / 60.0)
	scene.buttons[1].pressed.emit()
	await get_tree().physics_frame
	scene.buttons[2].pressed.emit()
	check(scene.ship.attached, "Visible align and secure controls attach the test load")
	scene.buttons[3].pressed.emit()
	check(scene.ship.deck_target == Heavy.RAISED, "Visible raise button targets the deck")
	scene.queue_free()
	print("HEAVY_LIFTER_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
