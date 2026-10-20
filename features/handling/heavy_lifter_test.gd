extends Node3D
const Heavy = preload("res://features/handling/heavy_lifter.gd")
const SHIP_SCENE = preload("res://features/ships/heavy_lifter_01/heavy_runtime.tscn")
var ship: Heavy
var helm: ShipHelm
var controls: PlayerControls
var camera: OrbitCameraRig
var readout: Label
var feedback: HandlingFeedback
var buttons: Array[Button] = []

func _ready() -> void:
	controls = PlayerControls.new()
	add_child(controls)
	controls.set_ship_context(true)
	ship = SHIP_SCENE.instantiate()
	add_child(ship)
	feedback = ship.assembly.feedback
	helm = ShipHelm.new()
	add_child(helm)
	helm.configure(ship, controls, feedback)
	helm.menu_requested.connect(func(): get_tree().change_scene_to_file("res://features/main/main.tscn"))
	var ocean: OceanPresentation = OceanPresentation.new()
	ocean.quality = controls.preferences.water_quality
	add_child(ocean)
	ship.assembly.create_wake(ocean)
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
	camera = ship.assembly.create_camera(self, controls)
	camera.orbit_offset = 0.65
	camera.pitch_order = 0.65
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
	var fuel_tools: FuelTestControls = FuelTestControls.new()
	stack.add_child(fuel_tools)
	fuel_tools.configure(ship, controls)
	for entry: Array in [["1. Lower deck", func(): ship.request_height(Heavy.LOWERED)], ["2. Align test payload", func(): ship.align_test_payload()], ["3. Secure payload", func(): ship.attach_payload()], ["4. Raise deck", func(): ship.request_height(Heavy.RAISED)], ["Release payload (deck lowered)", func(): ship.detach_payload()]]:
		var button: Button = Button.new()
		button.text = entry[0]
		button.pressed.connect(func():
			entry[1].call()
			button.release_focus()
			controls.wait_for_release = true)
		stack.add_child(button)
		buttons.append(button)

func _process(_delta: float) -> void:
	readout.text = "HEAVY-LIFTER TEST\nUse your saved boat controls to sail.\nRMB orbit · Wheel zoom · Esc menu\n\nSpeed %.1f kn · Deck %.1f m\nPayload: %s\n%s\n\n%s" % [ship.velocity.length() * 3600 / 1852, ship.deck_height, "SECURED" if ship.attached else "FLOATING", FuelTestControls.readout(ship), ship.notice]
