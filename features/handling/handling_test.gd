extends Node3D
const Ship = preload("res://features/handling/handling_ship.gd")
var ship: HandlingShip
var ocean: OceanPresentation
var visual_root: ShipVisualMotion
var controls: PlayerControls
var camera: OrbitCameraRig
var readout: Label
var overlay: DeveloperOverlay

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
	readout = Label.new()
	readout.add_theme_font_size_override("font_size", 18)
	panel.add_child(readout)
	overlay = DeveloperOverlay.new()
	add_child(overlay)

func _physics_process(delta: float) -> void:
	ship.maneuver(controls.steering_axis(), controls.action_strength("ship_thruster_right") - controls.action_strength("ship_thruster_left"))
	if not controls.input_allowed() or controls.action_strength("ship_throttle_zero") > 0.0:
		ship.zero_throttle()
	else:
		ship.adjust_command(controls.action_strength("ship_throttle_up") - controls.action_strength("ship_throttle_down"), delta)

func _process(_delta: float) -> void:
	var forward_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_throttle_up"])
	var reverse_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_throttle_down"])
	var left_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_steer_left"])
	var right_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_steer_right"])
	var port_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_thruster_left"])
	var starboard_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_thruster_right"])
	var zero_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_throttle_zero"])
	readout.text = "MANEUVERING TEST\n%s / %s: throttle  |  %s: zero  |  Escape: menu\n%s / %s: rudder  |  %s / %s: lateral thrusters\nRMB drag: orbit  |  Wheel: zoom  |  %s: recenter\n\nCommand %+.0f%%  |  Engine %+.0f%%\nAhead %+.2f m/s  |  Sideways %+.2f m/s\nTurn %+.1f°/s  |  Thrusters fade from 0 to 4 m/s" % [forward_key, reverse_key, zero_key, left_key, right_key, port_key, starboard_key, OS.get_keycode_string(controls.preferences.bindings["camera_recenter"]), ship.commanded_throttle * 100.0, ship.actual_throttle * 100.0, ship.forward_speed(), -ship.lateral_speed(), rad_to_deg(ship.yaw_rate)]
	overlay.set_snapshot({"role": "Local handling fixture", "ship_id": "box_prototype", "speed_mps": ship.forward_speed(), "throttle": ship.actual_throttle, "position_m": ship.position})
