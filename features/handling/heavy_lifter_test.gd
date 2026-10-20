extends Node3D
const Heavy = preload("res://features/handling/heavy_lifter.gd")
var ship: Heavy
var controls: PlayerControls
var camera: OrbitCameraRig
var readout: Label
var feedback: HandlingFeedback
var buttons: Array[Button] = []

func _ready() -> void:
	controls = PlayerControls.new()
	add_child(controls)
	controls.set_ship_context(true)
	ship = Heavy.new()
	add_child(ship)
	feedback = HandlingFeedback.new()
	add_child(feedback)
	controls.command_requested.connect(func(action: StringName) -> void:
		if action == &"ship_throttle_zero": ship.zero_throttle()
		if action == &"horn": feedback.sound_horn(controls.input_allowed())
		if action == &"pause": get_tree().change_scene_to_file("res://features/main/main.tscn"))
	var ocean: OceanPresentation = OceanPresentation.new()
	ocean.quality = controls.preferences.water_quality
	add_child(ocean)
	var wake: ShipWake = ShipWake.new()
	wake.ship = ship
	wake.ocean = ocean
	wake.half_length = 41
	wake.half_width = 12
	add_child(wake)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a0dce9")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce5e5")
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	add_child(light)
	var focus: CameraFocus = CameraFocus.new()
	focus.position.y = 5
	focus.hull_radius = 50
	focus.collision_body = ship
	ship.add_child(focus)
	camera = OrbitCameraRig.new()
	add_child(camera)
	camera.set_focus(focus)
	camera.distance_order = 155
	camera.orbit_offset = 0.65
	camera.pitch_order = 0.65
	camera.bind_controls(controls)
	var ui: CanvasLayer = CanvasLayer.new()
	add_child(ui)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(20, 20)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("243642")
	for edge: String in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 14.0)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	panel.add_child(stack)
	readout = Label.new()
	readout.custom_minimum_size.x = 350
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readout.add_theme_font_size_override("font_size", 17)
	stack.add_child(readout)
	for entry: Array in [["1. Lower deck", func(): ship.request_height(Heavy.LOWERED)], ["2. Align test payload", func(): ship.align_test_payload()], ["3. Secure payload", func(): ship.attach_payload()], ["4. Raise deck", func(): ship.request_height(Heavy.RAISED)], ["Release payload (deck lowered)", func(): ship.detach_payload()]]:
		var button: Button = Button.new()
		button.text = entry[0]
		button.pressed.connect(func():
			entry[1].call()
			button.release_focus()
			controls.wait_for_release = true)
		stack.add_child(button)
		buttons.append(button)

func _physics_process(delta: float) -> void:
	if not controls.input_allowed() or ship.operating():
		ship.zero_throttle()
		ship.maneuver(0, 0)
		return
	ship.adjust_command(controls.action_strength("ship_throttle_up") - controls.action_strength("ship_throttle_down"), delta)
	ship.maneuver(controls.steering_axis(), controls.action_strength("ship_thruster_right") - controls.action_strength("ship_thruster_left"))

func _process(delta: float) -> void:
	feedback.update(ship, controls.input_allowed(), delta)
	readout.text = "HEAVY-LIFTER TEST\nUse your saved boat controls to sail.\nRMB orbit · Wheel zoom · Esc menu\n\nSpeed %.1f kn · Deck %.1f m\nPayload: %s\n\n%s" % [ship.velocity.length() * 3600 / 1852, ship.deck_height, "SECURED" if ship.attached else "FLOATING", ship.notice]
