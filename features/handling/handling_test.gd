extends Node3D
const Ship = preload("res://features/handling/handling_ship.gd")
var ship: HandlingShip
var controls: PlayerControls
var camera: Camera3D
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
	box(ship, Vector3(13, 4, 64), Vector3(0, 1, 0), Color("435762"))
	box(ship, Vector3(10, 5, 8), Vector3(0, 5, -22), Color("e7ede7"))
	box(ship, Vector3(4, 0.2, 6), Vector3(0, 3.1, 25), Color("d5ac6c"))
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(13, 4, 64)
	collision.shape = shape
	collision.position.y = 1.0
	ship.add_child(collision)
	box(self, Vector3(4000, 0.2, 4000), Vector3(0, -1.1, 0), Color("8eaeb7"))
	# Stationary lane markers make coasting visible without animated water.
	for index: int in range(-20, 81):
		for side: int in [-1, 1]:
			box(self, Vector3(2, 3, 2), Vector3(side * 40, 0, index * 25), Color("76695b"))
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("b9cbd0")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce5e5")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	camera = Camera3D.new()
	camera.far = 3000.0
	add_child(camera)
	camera.current = true
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
	if not controls.input_allowed() or controls.action_strength("ship_throttle_zero") > 0.0:
		ship.zero_throttle()
	else:
		ship.adjust_command(controls.action_strength("ship_throttle_up") - controls.action_strength("ship_throttle_down"), delta)

func _process(_delta: float) -> void:
	camera.position = ship.position + Vector3(85, 65, -110)
	camera.look_at(ship.position + Vector3(0, 0, 12), Vector3.UP)
	var forward_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_throttle_up"])
	var reverse_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_throttle_down"])
	var zero_key: String = OS.get_keycode_string(controls.preferences.bindings["ship_throttle_zero"])
	readout.text = "BOAT HANDLING TEST\nHold %s / %s: raise / lower throttle\nRelease: hold setting  |  %s: zero throttle\nEscape: main menu  |  Steering comes in step 18\n\nCommand  %+.0f%%   |   Engine  %+.0f%%\nSpeed  %+.2f m/s   |   Distance  %.1f m" % [forward_key, reverse_key, zero_key, ship.commanded_throttle * 100.0, ship.actual_throttle * 100.0, ship.velocity.z, ship.distance_m]
	overlay.set_snapshot({"role": "Local handling fixture", "ship_id": "box_prototype", "speed_mps": ship.velocity.z, "throttle": ship.actual_throttle, "position_m": ship.position})
