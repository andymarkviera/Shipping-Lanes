extends Node3D
const SHIP = preload("res://features/ships/starter_container_01/starter_runtime.tscn")
const HEAVY_SHIP = preload("res://features/ships/heavy_lifter_01/heavy_runtime.tscn")
var cargo_sync: CargoReplication
var actions: ShipActions
var cargo_buttons: HBoxContainer
var session: LocalShipSession
var ships: Dictionary = {}
var readout: Label
var replication: ShipReplication
var controls: PlayerControls
var follow_camera: OrbitCameraRig
var ocean: OceanPresentation
var wakes: Dictionary = {}
var throttle_order: float = 0.0
var send_elapsed: float = 0.0
var automated_input: bool = false

func _ready() -> void:
	session = LocalShipSession.new()
	session.name = "Session"
	add_child(session)
	session.changed.connect(refresh)
	replication = ShipReplication.new()
	replication.name = "Replication"
	add_child(replication)
	replication.configure(self, session)
	actions = ShipActions.new()
	actions.name = "Actions"
	add_child(actions)
	actions.configure(self, session)
	cargo_sync = CargoReplication.new()
	cargo_sync.name = "CargoSync"
	add_child(cargo_sync)
	cargo_sync.configure(self, session)
	controls = PlayerControls.new()
	add_child(controls)
	controls.set_ship_context(true)
	controls.command_requested.connect(func(action: StringName):
		if action == &"ship_throttle_zero": throttle_order = 0
		if action == &"pause": get_tree().change_scene_to_file("res://features/main/main.tscn"))
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
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(150, 150, -190)
	add_child(camera)
	camera.look_at(Vector3(35, 0, 0))
	follow_camera = OrbitCameraRig.new()
	add_child(follow_camera)
	follow_camera.bind_controls(controls)
	camera.current = true
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(20, 20)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("243642")
	for edge: String in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 14)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	panel.add_child(stack)
	readout = Label.new()
	readout.custom_minimum_size.x = 400
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readout.add_theme_font_size_override("font_size", 17)
	stack.add_child(readout)
	var row: HBoxContainer = HBoxContainer.new()
	stack.add_child(row)
	for caption: String in ["Host locally", "Host heavy locally", "Join locally", "Disconnect", "Main menu"]:
		if caption == "Disconnect":
			row = HBoxContainer.new()
			stack.add_child(row)
		var button: Button = Button.new()
		button.text = caption
		row.add_child(button)
		button.pressed.connect(func():
			match caption:
				"Host locally":
					session.ship_definition_id = "ship_starter_container_01"
					session.host_session()
				"Host heavy locally":
					session.ship_definition_id = "ship_heavy_lifter_01"
					session.host_session()
				"Join locally": session.join_session()
				"Disconnect": session.stop()
				"Main menu": get_tree().change_scene_to_file("res://features/main/main.tscn")
			button.release_focus())
	cargo_buttons = HBoxContainer.new()
	stack.add_child(cargo_buttons)
	for action: String in ["lower", "align", "secure", "raise", "release"]:
		var button: Button = Button.new()
		button.text = action.capitalize() + (" (test)" if action == "align" else "")
		button.pressed.connect(func():
			cargo_sync.submit(action)
			button.release_focus()
			controls.wait_for_release = true)
		cargo_buttons.add_child(button)
	refresh()

func refresh() -> void:
	for id: String in ships.keys():
		if not session.roster.has(id):
			var old: Node = ships[id]
			remove_child(old)
			old.queue_free()
			ships.erase(id)
			if wakes.has(id):
				wakes[id].set_process(false)
				wakes[id].queue_free()
				wakes.erase(id)
	for id: String in session.roster:
		if ships.has(id): continue
		var record: Dictionary = session.roster[id]
		var ship: HandlingShip = (HEAVY_SHIP if record.definition_id == "ship_heavy_lifter_01" else SHIP).instantiate()
		ship.name = id
		ship.position.x = record.slot * (110 if record.definition_id == "ship_heavy_lifter_01" else 75)
		ship.set_multiplayer_authority(1)
		add_child(ship)
		ship.state.instance_id = id
		ship.simulation_paused = not session.hosting
		ship.set_physics_process(session.hosting)
		if not session.hosting:
			ship.collision_layer = 0
			ship.collision_mask = 0
			if ship is CargoReplication.Heavy:
				ship.payload_body.collision_layer = 0
		ships[id] = ship
		wakes[id] = ship.assembly.create_wake(ocean)
		if record.peer_id == multiplayer.get_unique_id():
			throttle_order = 0
			follow_camera.set_focus(ship.assembly.focus)
			follow_camera.camera.current = true
	update_readout()

func update_readout() -> void:
	if readout == null: return
	var text: String = "LOCAL MULTIPLAYER TEST · STEP 31\nSaved boat controls · RMB orbit · Wheel zoom\nTwo windows on this computer only · Esc menu\n\n%s\nShips: %d / 2" % [session.notice, ships.size()]
	for id: String in session.roster:
		var record: Dictionary = session.roster[id]
		text += "\n%s · %s" % [id, "YOU" if record.peer_id == multiplayer.get_unique_id() else "OTHER PLAYER"]
	var mine: String = replication.local_entity()
	if ships.has(mine):
		var ship: HandlingShip = ships[mine]
		text += "\nSpeed %.1f kn · Fuel %.1f L\nOrder %+.0f%% · Engine %+.0f%%" % [ship.velocity.length() * 3600 / 1852, ship.state.fuel_liters, throttle_order * 100, ship.actual_throttle * 100]
	if cargo_buttons != null:
		cargo_buttons.visible = ships.has(mine) and ships[mine] is CargoReplication.Heavy
		if cargo_buttons.visible: text += "\nDeck %.1f m · Payload %s\n%s" % [ships[mine].deck_height, "SECURED" if ships[mine].attached else "FLOATING", ships[mine].notice]
	readout.text = text

func _physics_process(delta: float) -> void:
	if automated_input: return
	var mine: String = replication.local_entity()
	if not ships.has(mine): return
	var ship: HandlingShip = ships[mine]
	var steering: float = 0
	var lateral: float = 0
	if controls.input_allowed():
		if controls.action_strength("ship_throttle_zero") > 0: throttle_order = 0
		else: throttle_order = clampf(throttle_order + (controls.action_strength("ship_throttle_up") - controls.action_strength("ship_throttle_down")) * ship.definition.command_rate_per_second * delta, -ship.definition.reverse_throttle_limit, ship.definition.forward_throttle_limit)
		steering = controls.steering_axis()
		lateral = controls.action_strength("ship_thruster_right") - controls.action_strength("ship_thruster_left")
	else: throttle_order = 0
	if ship.state.fuel_liters <= 0: throttle_order = 0
	send_elapsed += delta
	if send_elapsed >= ShipReplication.SEND_INTERVAL:
		send_elapsed = fmod(send_elapsed, ShipReplication.SEND_INTERVAL)
		replication.submit(throttle_order, steering, lateral)

func _process(_delta: float) -> void:
	update_readout()
