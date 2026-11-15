extends Node3D
var checks: int = 0
var failures: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func hull(size: Vector3, at: Vector3) -> CameraFocus:
	var body: StaticBody3D = StaticBody3D.new()
	add_child(body)
	body.position = at
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var focus: CameraFocus = CameraFocus.new()
	body.add_child(focus)
	focus.position.y = size.y / 2.0 + 2.0
	focus.hull_radius = size.z / 2.0
	focus.collision_body = body
	return focus

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var small: CameraFocus = hull(Vector3(8, 4, 16), Vector3.ZERO)
	var large: CameraFocus = hull(Vector3(20, 8, 80), Vector3(100, 0, 0))
	var controls: PlayerControls = PlayerControls.new()
	add_child(controls)
	controls.set_ship_context(true)
	var rig: OrbitCameraRig = OrbitCameraRig.new()
	add_child(rig)
	rig.bind_controls(controls)
	rig.set_focus(small)
	await get_tree().create_timer(0.15).timeout
	check(rig.camera.global_position.is_finite(), "Small hull camera initialized")
	for index: int in range(100): rig.zoom(-1)
	check(is_equal_approx(rig.distance_order, rig.minimum_distance()), "Near zoom limit")
	for index: int in range(100): rig.zoom(1)
	check(is_equal_approx(rig.distance_order, rig.maximum_distance()), "Far zoom limit")
	var before: Vector3 = rig.camera.global_position
	rig.set_focus(large)
	check(rig.camera.global_position == before, "Target switch does not teleport camera")
	await get_tree().physics_frame
	await get_tree().process_frame
	check(rig.camera.global_position.distance_to(before) < 30.0, "Target switch blends first step")
	await get_tree().create_timer(1.2).timeout
	check(rig.pivot.distance_to(large.global_position) < 1.0, "Large hull focus converges")
	check(rig.minimum_distance() == 52.0, "Larger hull has appropriate minimum distance")
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await get_tree().process_frame
	check(rig.orbiting, "RMB starts orbit")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(80, 30)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	check(absf(rig.orbit_offset) > 0.01 and rig.pitch_order > 0.45, "Mouse motion orbits through preference boundary")
	rig.orbit(Vector2(0, 10000))
	check(rig.pitch_order == rig.MAX_PITCH, "Upper pitch limit")
	rig.orbit(Vector2(0, -10000))
	check(rig.pitch_order == rig.MIN_PITCH, "Lower pitch limit")
	mouse = mouse.duplicate()
	mouse.pressed = false
	Input.parse_input_event(mouse)
	await get_tree().process_frame
	check(not rig.orbiting, "RMB release ends capture")
	controls.command_requested.emit(&"camera_recenter")
	check(rig.orbit_offset == 0.0 and rig.pitch_order == 0.45, "Recenter requests aft view")
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var prior_distance: float = rig.distance_order
	Input.parse_input_event(wheel)
	await get_tree().process_frame
	check(rig.distance_order < prior_distance, "Mouse wheel zooms")
	wheel = wheel.duplicate()
	wheel.pressed = false
	Input.parse_input_event(wheel)
	rig.command(&"camera_orbit")
	rig.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not rig.orbiting, "Focus loss releases mouse")
	controls.set_menu_open(true)
	rig.command(&"camera_orbit")
	check(not rig.orbiting, "Menu blocks orbit capture")
	controls.set_menu_open(false)
	await get_tree().create_timer(0.1).timeout
	# Tall pier spans the desired camera ray. A sphere sweep must shorten it.
	rig.set_focus(small)
	await get_tree().create_timer(1.5).timeout
	var pier: StaticBody3D = StaticBody3D.new()
	add_child(pier)
	pier.position = Vector3(0, 10, -25)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(200, 80, 4)
	collider.shape = shape
	pier.add_child(collider)
	await get_tree().create_timer(0.15).timeout
	check(rig.camera.global_position.z > -22.3, "Pier sweep keeps camera in front of obstruction")
	check(rig.camera.global_position.distance_to(rig.pivot) < rig.distance_order, "Obstruction shortens view without changing zoom order")
	remove_child(pier)
	pier.queue_free()
	await get_tree().create_timer(0.15).timeout
	check(rig.camera.global_position.distance_to(rig.pivot) > 40.0, "View recovers when pier clears")
	large.get_parent().queue_free()
	rig.set_focus(null)
	before = rig.camera.global_position
	await get_tree().create_timer(0.1).timeout
	check(rig.camera.global_position == before, "Missing focus holds stable view")
	# Patch 2.9 item 4: the view keeps up with the 200 kn offshore racer (102.9
	# m/s): the lag stays near what a 42 kn ship gets instead of 20 m.
	var racer: CameraFocus = hull(Vector3(2.8, 2, 13), Vector3(0, 0, -2000))
	rig.set_focus(racer)
	await get_tree().create_timer(0.5).timeout
	var body: Node3D = racer.get_parent()
	var worst: float = 0.0
	for tick: int in range(120):
		body.position.z += 102.9 / Engine.physics_ticks_per_second
		await get_tree().physics_frame
		if tick > 60: worst = maxf(worst, rig.pivot.distance_to(racer.global_position))
	check(worst > 0.5 and worst < 6.0, "Camera keeps up with the racer at 200 kn (lag %.1f m)" % worst)
	print("CAMERA_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
