extends Node3D
const PORTS: Array[PackedScene] = [preload("res://features/ports/brindle_quay.tscn"), preload("res://features/ports/slatewater_works.tscn")]
var port: Node3D
var ship: HandlingShip
var controls: PlayerControls
var helm: ShipHelm
var camera: OrbitCameraRig
var ocean: OceanPresentation
var wake: ShipWake
var details: Label

func _ready() -> void:
	controls = PlayerControls.new()
	add_child(controls)
	controls.set_ship_context(true)
	ocean = OceanPresentation.new()
	ocean.quality = controls.preferences.water_quality
	add_child(ocean)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a0dce9")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .7
	add_child(environment)
	camera = OrbitCameraRig.new()
	add_child(camera)
	camera.bind_controls(controls)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(20, 20)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("243642")
	for edge: String in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	panel.add_child(stack)
	details = Label.new()
	stack.add_child(details)
	var buttons: HBoxContainer = HBoxContainer.new()
	stack.add_child(buttons)
	for i: int in 2:
		var button: Button = Button.new()
		button.text = "Brindle Quay" if i == 0 else "Slatewater Works"
		buttons.add_child(button)
		button.pressed.connect(func(): button.release_focus(); select_port(i))
	var back: Button = Button.new()
	back.text = "Main menu"
	buttons.add_child(back)
	back.pressed.connect(leave)
	select_port(0)

func select_port(index: int) -> void:
	if helm != null: remove_child(helm); helm.queue_free()
	if wake != null: remove_child(wake); wake.queue_free()
	if ship != null: remove_child(ship); ship.queue_free()
	if port != null: remove_child(port); port.queue_free()
	port = PORTS[index].instantiate()
	add_child(port)
	ship = preload("res://features/ships/starter_container_01/starter_runtime.tscn").instantiate()
	var allocation: Dictionary = port.reserve_spawn(ship.definition.hull_size_m)
	if not allocation.ok:
		ship.free()
		ship = null
		helm = null
		wake = null
		details.text = "All spawn locations are occupied. Select the port again to retry."
		return
	ship.transform = allocation.transform
	add_child(ship)
	# Keep this preview hold until its port is freed; no same-frame spawn race.
	helm = ShipHelm.new()
	add_child(helm)
	helm.configure(ship, controls, ship.assembly.feedback)
	helm.menu_requested.connect(leave)
	wake = ship.assembly.create_wake(ocean)
	camera.set_focus(ship.assembly.focus)
	controls.wait_for_release = true
	var services: PackedStringArray = []
	for service: String in port.definition.service_ids: services.append(service.replace("_", " ").capitalize())
	details.text = "%s — PORT TEST\nPlanned services: %s\nNo loading or saving · RMB orbit · Wheel zoom · Esc menu" % [port.definition.display_name, ", ".join(services)]

func leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://features/main/main.tscn")
