extends Node3D
const PORTS: Array[PackedScene] = [preload("res://features/ports/brindle_quay.tscn"), preload("res://features/ports/slatewater_works.tscn")]
var port: Node3D
var ship: HandlingShip
var controls: PlayerControls
var helm: ShipHelm
var camera: OrbitCameraRig
var ocean: OceanPresentation
var wake: ShipWake
var docking = preload("res://features/ports/docking_authority.gd").new()
var dock_button: Button
var cancel_button: Button
var loading = preload("res://features/cargo/port_loading.gd").new()
var load_button: Button
var cancel_load_button: Button
var loading_text: Label
var offers = preload("res://features/cargo/container_offers.gd").new()
var offer_time: float = 0.0
var offer_text: Label
var accept_button: Button
var selected_offer: String = ""
var offer_notice: String = ""
var readiness: Label
var details: Label

func _ready() -> void:
	add_child(docking)
	add_child(loading)
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
	readiness = Label.new()
	stack.add_child(readiness)
	var buttons: HBoxContainer = HBoxContainer.new()
	stack.add_child(buttons)
	dock_button = Button.new()
	dock_button.text = "Dock"
	buttons.add_child(dock_button)
	dock_button.pressed.connect(func():
		dock_button.release_focus()
		if docking.state(1) == "docked": docking.request_undock(1)
		else: docking.request_dock(1, "container_transfer", "cargo_test_container")
		controls.wait_for_release = true)
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	buttons.add_child(cancel_button)
	cancel_button.pressed.connect(func(): cancel_button.release_focus(); docking.cancel(1); controls.wait_for_release = true)
	for i: int in 2:
		var button: Button = Button.new()
		button.text = "Brindle Quay" if i == 0 else "Slatewater Works"
		buttons.add_child(button)
		button.pressed.connect(func(): button.release_focus(); select_port(i))
	var back: Button = Button.new()
	back.text = "Main menu"
	buttons.add_child(back)
	back.pressed.connect(leave)
	offer_text = Label.new()
	stack.add_child(offer_text)
	accept_button = Button.new()
	accept_button.text = "Accept offer"
	stack.add_child(accept_button)
	accept_button.pressed.connect(func():
		accept_button.release_focus()
		if is_instance_valid(ship):
			var result: Dictionary = offers.accept(selected_offer, "preview_captain", "preview_ship", port.definition.id, ship.state.manifest)
			offer_notice = result.message
		controls.wait_for_release = true)
	loading_text = Label.new()
	stack.add_child(loading_text)
	load_button = Button.new()
	load_button.text = "Load accepted cargo"
	stack.add_child(load_button)
	load_button.pressed.connect(func():
		load_button.release_focus()
		for offer: Dictionary in offers.list_at(port.definition.id):
			if offer.state == "accepted" and offer.owner_id == "preview_captain":
				loading.start(offer.id)
				break
		controls.wait_for_release = true)
	cancel_load_button = Button.new()
	cancel_load_button.text = "Cancel loading (releases job)"
	stack.add_child(cancel_load_button)
	cancel_load_button.pressed.connect(func(): cancel_load_button.release_focus(); loading.cancel(); controls.wait_for_release = true)
	select_port(0)

func select_port(index: int) -> void:
	var carried: Array[Dictionary] = []
	if is_instance_valid(ship): carried = ship.state.manifest.lines()
	loading.disconnect_ship()
	docking.disconnect_owner(1)
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
	docking.register(1, ship, port)
	ship.state.manifest.replace(carried)
	loading.bind(ship, port, docking, offers, 1, "preview_captain", "preview_ship")
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
	details.text = "%s — PORT TEST\nPlanned services: %s\nTemporary session · RMB orbit · Wheel zoom · Esc menu" % [port.definition.display_name, ", ".join(services)]

func leave() -> void:
	loading.disconnect_ship()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://features/main/main.tscn")

func _physics_process(_delta: float) -> void:
	offer_time += _delta
	offers.advance_to(int(offer_time * 1000))
	if not is_instance_valid(ship) or not is_instance_valid(port):
		if readiness != null: readiness.text = ""
		return
	var status: Dictionary = port.berth_readiness(ship, "container_transfer", "cargo_test_container")
	var current: String = docking.state(1)
	dock_button.text = "Undock" if current == "docked" else "Dock"
	dock_button.disabled = not (current == "docked" or (current in ["underway", "approaching"] and status.eligible))
	if loading.busy(): dock_button.disabled = true
	cancel_button.visible = current in ["docking", "undocking"]
	readiness.text = "Berth: " + (current.capitalize() if current in ["docking", "docked", "undocking"] else status.message)
	readiness.modulate = Color("a9e8bc") if status.eligible else Color("f2d6a2")

func _process(_delta: float) -> void:
	if not is_instance_valid(port) or not is_instance_valid(ship) or offer_text == null: return
	selected_offer = ""
	var accepted: int = 0
	for offer: Dictionary in offers.list_at(port.definition.id):
		if offer.state == "accepted": accepted += 1
		if selected_offer.is_empty() and offer.state == "available": selected_offer = offer.id
	accept_button.disabled = selected_offer.is_empty()
	load_button.disabled = loading.busy() or docking.state(1) != "docked" or accepted == 0
	cancel_load_button.visible = loading.busy()
	loading_text.text = ("Loading: %.0f%%" % loading.progress_percent() if loading.busy() else loading.notice) + " · Cargo batches: %d" % ship.state.manifest.lines().size()
	if selected_offer.is_empty():
		offer_text.text = "Container offers: none available · %d accepted
%s" % [accepted, offer_notice]
	else:
		var offer: Dictionary = offers.view(selected_offer)
		var destination: String = "Slatewater Works" if offer.destination_port_id == "port_slatewater_works" else "Brindle Quay"
		offer_text.text = "%d container(s) to %s · %.2f credits
Expires in %ds · %d accepted · %s" % [offer.quantity, destination, offer.reward_minor / 100.0, maxi(0, int(ceil((offer.expires_ms - offer_time * 1000) / 1000))), accepted, offer_notice]
