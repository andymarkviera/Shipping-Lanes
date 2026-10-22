extends Node3D
## Player presentation only. Helm orders cross the authenticated server session.
var session: Node
var controls: PlayerControls
var camera_rig: OrbitCameraRig
var ocean: OceanPresentation
var readout: Label
var pause_panel: PanelContainer
var controls_enabled: bool = true
var throttle_order: float = 0.0
var sequence: int = 0
var send_elapsed: float = 0.0
var installed: Dictionary = {}
var ready_to_drive: bool = false

func configure(value: Node) -> void:
	session = value

func _ready() -> void:
	controls = PlayerControls.new()
	add_child(controls)
	controls.command_requested.connect(func(action: StringName):
		if action == &"ship_throttle_zero": throttle_order = 0.0
		if action == &"pause": set_menu(true))
	ocean = OceanPresentation.new()
	add_child(ocean)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -25, 0)
	add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a0dce9")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	camera_rig = OrbitCameraRig.new()
	add_child(camera_rig)
	camera_rig.bind_controls(controls)
	camera_rig.camera.position = Vector3(0, 70, -120)
	camera_rig.camera.look_at(Vector3.ZERO)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = make_panel(layer, Vector2(20, 20))
	readout = Label.new()
	readout.custom_minimum_size.x = 350
	readout.add_theme_font_size_override("font_size", 18)
	var hud_stack: VBoxContainer = VBoxContainer.new()
	panel.add_child(hud_stack)
	hud_stack.add_child(readout)
	var menu_button: Button = Button.new()
	menu_button.text = "Menu"
	hud_stack.add_child(menu_button)
	menu_button.pressed.connect(func(): menu_button.release_focus(); set_menu(true))
	pause_panel = make_panel(layer, Vector2(20, 220))
	var stack: VBoxContainer = VBoxContainer.new()
	pause_panel.add_child(stack)
	var label: Label = Label.new()
	label.text = "Menu open - the server keeps running."
	stack.add_child(label)
	for caption: String in ["Resume", "Disconnect", "Main menu"]:
		var button: Button = Button.new()
		button.text = caption
		stack.add_child(button)
		button.pressed.connect(func():
			button.release_focus()
			if caption == "Resume": set_menu(false)
			elif caption == "Disconnect": session.close_client(); set_menu(false)
			else:
				session.close_client()
				get_tree().change_scene_to_file("res://features/main/main.tscn"))
	pause_panel.hide()

func make_panel(parent: Node, at: Vector2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = at
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("243642")
	for edge: String in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 14)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func set_menu(open: bool) -> void:
	controls.set_menu_open(open)
	pause_panel.visible = open
	throttle_order = 0.0
	camera_rig.release_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if controls.menu_open and event.is_action_pressed("pause"):
		set_menu(false)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if session == null: return
	if installed != session.binding:
		installed = session.binding.duplicate()
		throttle_order = 0.0
		sequence = 0
		send_elapsed = 0.0
	var mine: String = str(installed.get("ship", ""))
	var fresh: bool = not session.last_snapshot.is_empty() and Time.get_ticks_msec() - int(session.last_snapshot.get("received_at", 0)) < 1000
	ready_to_drive = not mine.is_empty() and fresh and session.world_view.replicas.has(mine) and Time.get_ticks_msec() - session.world_view.received_at < 1000
	if controls.ship_context_active != ready_to_drive: controls.set_ship_context(ready_to_drive)
	if ready_to_drive:
		var ship: HandlingShip = session.world_view.replicas[mine].node
		if camera_rig.focus != ship.assembly.focus: camera_rig.set_focus(ship.assembly.focus)
	else:
		throttle_order = 0.0
		camera_rig.focus = null
		camera_rig.release_mouse()
	var text: String = "CONTAINER SHIP SIM\n%s" % session.notice
	if ready_to_drive:
		text += "\nSpeed %.1f kn | Fuel %.1f L\nThrottle order %+.0f%%" % [session.last_snapshot.speed * 3600.0 / 1852.0, session.last_snapshot.fuel, throttle_order * 100.0]
		text += "\nSaved steering controls | RMB orbit\nWheel zoom | Esc menu"
	elif not installed.is_empty(): text += "\nWaiting for fresh boat updates..."
	else: text += "\nConnect through sign-in to take the helm."
	readout.text = text

func _physics_process(delta: float) -> void:
	if session == null or not controls_enabled or installed.is_empty(): return
	var rudder: float = 0.0
	if ready_to_drive and controls.input_allowed() and session.last_snapshot.get("fuel", 0) > 0:
		var ship: HandlingShip = session.world_view.replicas[installed.ship].node
		if controls.action_strength("ship_throttle_zero") > 0: throttle_order = 0.0
		else: throttle_order = clampf(throttle_order + (controls.action_strength("ship_throttle_up") - controls.action_strength("ship_throttle_down")) * ship.definition.command_rate_per_second * delta, -ship.definition.reverse_throttle_limit, ship.definition.forward_throttle_limit)
		rudder = controls.steering_axis()
	else: throttle_order = 0.0
	send_elapsed += delta
	if send_elapsed >= 0.1:
		send_elapsed = fmod(send_elapsed, 0.1)
		sequence += 1
		session.send_helm(sequence, throttle_order, rudder)

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
