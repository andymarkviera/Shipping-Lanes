extends Node3D
const SHIP = preload("res://features/ships/starter_container_01/starter_runtime.tscn")
var session: LocalShipSession
var ships: Dictionary = {}
var readout: Label

func _ready() -> void:
	session = LocalShipSession.new()
	session.name = "Session"
	add_child(session)
	session.changed.connect(refresh)
	var ocean: OceanPresentation = OceanPresentation.new()
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
	readout.add_theme_font_size_override("font_size", 17)
	stack.add_child(readout)
	var row: HBoxContainer = HBoxContainer.new()
	stack.add_child(row)
	for caption: String in ["Host locally", "Join locally", "Disconnect", "Main menu"]:
		var button: Button = Button.new()
		button.text = caption
		row.add_child(button)
		button.pressed.connect(func():
			match caption:
				"Host locally": session.host_session()
				"Join locally": session.join_session()
				"Disconnect": session.stop()
				"Main menu": get_tree().change_scene_to_file("res://features/main/main.tscn")
			button.release_focus())
	refresh()

func refresh() -> void:
	for id: String in ships.keys():
		if not session.roster.has(id):
			var old: Node = ships[id]
			remove_child(old)
			old.queue_free()
			ships.erase(id)
	for id: String in session.roster:
		if ships.has(id): continue
		var record: Dictionary = session.roster[id]
		var ship: HandlingShip = SHIP.instantiate()
		ship.name = id
		ship.position.x = record.slot * 75
		ship.set_multiplayer_authority(1)
		add_child(ship)
		ship.state.instance_id = id
		# Step 29 is lifecycle only; movement replication arrives in Step 30.
		ship.simulation_paused = true
		ship.set_physics_process(false)
		ships[id] = ship
	if readout == null: return
	var text: String = "LOCAL MULTIPLAYER TEST · STEP 29\nTwo game windows on this computer only.\nShip movement syncing comes next.\n\n%s\nShips: %d / 2" % [session.notice, ships.size()]
	for id: String in session.roster:
		var record: Dictionary = session.roster[id]
		text += "\n%s · %s" % [id, "YOU" if record.peer_id == multiplayer.get_unique_id() else "OTHER PLAYER"]
	readout.text = text
