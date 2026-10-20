extends Node3D
const Ship = preload("res://features/handling/handling_ship.gd")
var ship: HandlingShip
var ocean: OceanPresentation
var wake: ShipWake
var visual_root: ShipVisualMotion
var controls: PlayerControls
var camera: OrbitCameraRig
var readout: Label
var overlay: DeveloperOverlay
var feedback: HandlingFeedback
var load_preview: Button
var load_preview_index: int = 0

func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.position = at

func _ready() -> void:
	controls = PlayerControls.new()
	add_child(controls)
	controls.set_ship_context(true)
	controls.command_requested.connect(func(action: StringName) -> void:
		if action == &"ship_throttle_zero": ship.zero_throttle()
		if action == &"horn": feedback.sound_horn(controls.input_allowed())
		if action == &"pause": get_tree().change_scene_to_file("res://features/main/main.tscn"))
	ship = Ship.new()
	ship.name = "BoxShip"
	add_child(ship)
	visual_root = ShipVisualMotion.new()
	visual_root.name = "VisualRoot"
	ship.add_child(visual_root)
	visual_root.quality = controls.preferences.water_quality
	box(visual_root, Vector3(13, 4, 64), Vector3(0, 1, 0), Color("435762"))
	box(visual_root, Vector3(10, 5, 8), Vector3(0, 5, -22), Color("e7ede7"))
	box(visual_root, Vector3(4, 0.2, 6), Vector3(0, 3.1, 25), Color("d5ac6c"))
	CollisionRules.add_box_hull(ship)
	ocean = OceanPresentation.new()
	ocean.quality = controls.preferences.water_quality
	add_child(ocean)
	ocean.position.y = -1.0
	wake = ShipWake.new()
	wake.ship = ship
	wake.ocean = ocean
	add_child(wake)
	# Stationary lane markers make coasting visible without animated water.
	for index: int in range(-20, 81):
		for side: int in [-1, 1]:
			box(self, Vector3(2, 3, 2), Vector3(side * 40, 0, index * 25), Color("76695b"))
	# Starboard berth, solid quay with a pale approach strip; no mooring logic yet.
	var quay: StaticBody3D = StaticBody3D.new()
	quay.name = "PracticeBerth"
	quay.collision_layer = CollisionRules.SHORE
	quay.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
	quay.position = Vector3(-32, 0, 0)
	box(quay, Vector3(8, 4, 100), Vector3.ZERO, Color("76695b"))
	box(quay, Vector3(0.5, 0.2, 90), Vector3(4.1, 2.1, 0), Color("e7ede7"))
	var quay_collision: CollisionShape3D = CollisionShape3D.new()
	var quay_shape: BoxShape3D = BoxShape3D.new()
	quay_shape.size = Vector3(8, 4, 100)
	quay_collision.shape = quay_shape
	quay.add_child(quay_collision)
	add_child(quay)
	for waypoint: Vector3 in [Vector3(0, 0, 100), Vector3(-80, 0, 200), Vector3(-160, 0, 100)]:
		box(self, Vector3(4, 6, 4), waypoint, Color("d5ac6c"))
	var course: CollisionCourse = CollisionCourse.new()
	add_child(course)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a0dce9")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce5e5")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var focus: CameraFocus = CameraFocus.new()
	ship.add_child(focus)
	focus.position = Vector3(0, 5, 0)
	focus.hull_radius = 34.0
	focus.collision_body = ship
	camera = OrbitCameraRig.new()
	add_child(camera)
	camera.set_focus(focus)
	camera.bind_controls(controls)
	var ui: CanvasLayer = CanvasLayer.new()
	add_child(ui)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("243642")
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var hud_stack: VBoxContainer = VBoxContainer.new()
	panel.add_child(hud_stack)
	readout = Label.new()
	readout.add_theme_font_size_override("font_size", 18)
	hud_stack.add_child(readout)
	load_preview = Button.new()
	load_preview.text = "Cargo preview: Empty — click to change"
	load_preview.pressed.connect(cycle_load_preview)
	hud_stack.add_child(load_preview)
	var water_notice: Label = Label.new()
	water_notice.text = "All open water is navigable. Avoid visible land, rocks and docks."
	water_notice.add_theme_font_size_override("font_size", 15)
	hud_stack.add_child(water_notice)
	feedback = HandlingFeedback.new()
	add_child(feedback)
	overlay = DeveloperOverlay.new()
	add_child(overlay)

func cycle_load_preview() -> void:
	load_preview_index = (load_preview_index + 1) % 3
	visual_root.set_visual_load(float(load_preview_index) * 0.5)
	load_preview.text = "Cargo preview: %s — click to change" % ["Empty", "Half load", "Full load"][load_preview_index]
	load_preview.release_focus()
	controls.wait_for_release = true

func _physics_process(delta: float) -> void:
	ship.maneuver(controls.steering_axis(), controls.action_strength("ship_thruster_right") - controls.action_strength("ship_thruster_left"))
	if not controls.input_allowed() or controls.action_strength("ship_throttle_zero") > 0.0:
		ship.zero_throttle()
	else:
		ship.adjust_command(controls.action_strength("ship_throttle_up") - controls.action_strength("ship_throttle_down"), delta)

func _process(delta: float) -> void:
	feedback.update(ship, controls.input_allowed(), delta)
	var forward_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_throttle_up"])
	var reverse_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_throttle_down"])
	var left_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_steer_left"])
	var right_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_steer_right"])
	var port_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_thruster_left"])
	var starboard_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_thruster_right"])
	var zero_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_throttle_zero"])
	var data: Dictionary = feedback.snapshot
	var thruster_text: String = "IDLE"
	if absf(data.thruster) > 0.005: thruster_text = "%s %.0f%%" % ["STARBOARD" if data.thruster > 0.0 else "PORT", absf(data.thruster) * 100.0]
	elif absf(ship.lateral_order) > 0.0: thruster_text = "TOO FAST"
	readout.text = "HANDLING BASELINE\n%s / %s throttle  |  %s neutral  |  %s horn\n%s / %s rudder  |  %s / %s thrusters  |  Esc menu\nRMB orbit  |  Wheel zoom  |  %s recenter\n\nSpeed %.1f kn %s  |  Heading %03d°\nOrder %+.0f%%  |  Engine %+.0f%%  %s\nThruster %s  |  Fuel — not connected\nSide drift %+.1f kn  |  Turn %+.1f°/s" % [forward_key, reverse_key, zero_key, OS.get_keycode_string(controls.preferences.bindings["horn"]), left_key, right_key, port_key, starboard_key, OS.get_keycode_string(controls.preferences.bindings["camera_recenter"]), data.speed_knots, data.direction, int(round(data.heading_degrees)) % 360, data.command * 100.0, data.engine * 100.0, "HORN" if feedback.horn.playing else "", thruster_text, data.side_knots, data.turn_degrees]
	overlay.set_snapshot({"role": "Local handling fixture", "ship_id": "box_prototype", "speed_mps": ship.forward_speed(), "throttle": ship.actual_throttle, "position_m": ship.position})
