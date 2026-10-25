extends Node3D
const PORTS: Array[PackedScene] = [preload("res://features/ports/brindle_quay.tscn"), preload("res://features/ports/slatewater_works.tscn")]
const Heavy = preload("res://features/handling/heavy_lifter.gd")
@export var save_enabled: bool = true
@export var save_path: String = "user://worlds/private_port_voyage/voyage.db"
var persistence: Node
var world_ports: Array[Node3D] = []
var port: Node3D
var ship: HandlingShip
var controls: PlayerControls
var helm: ShipHelm
var camera: OrbitCameraRig
var ocean: OceanPresentation
var wake: ShipWake
var docking = preload("res://features/ports/docking_authority.gd").new()
var loading = preload("res://features/cargo/port_loading.gd").new()
var offers = preload("res://features/cargo/container_offers.gd").new()
var heavy_jobs = preload("res://features/cargo/heavy_ocean_job.gd").new()
var heavy_mode: bool = false
var offer_time: float = 0
var offer_notice: String = ""
var selected_offer: String = ""
var reward_minor: int = 0
var spawn_ticket: int = 0
var dock_button: Button
var cancel_button: Button
var cancel_load_button: Button
var accept_button: Button
var deliver_button: Button
var switch_button: Button
var loading_text: Label
var offer_text: Label
var readiness: Label
var details: Label
var navigation: Label
var services: VBoxContainer
var jobs_panel: VBoxContainer
var jobs_list: ItemList
var heavy_controls: HBoxContainer
var waypoint: Label3D

func button(parent: Node, title: String, action: Callable) -> Button:
	var node: Button = Button.new()
	node.text = title
	# Sailing HUD actions must never retain keyboard focus (including Tab/cancelled clicks).
	node.focus_mode = Control.FOCUS_NONE
	parent.add_child(node)
	node.pressed.connect(func():
		if is_instance_valid(persistence) and not persistence.ready_to_save and title != "Main menu": return
		node.release_focus()
		action.call()
		controls.wait_for_release = true)
	return node

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
	for i: int in 2:
		var place: Node3D = PORTS[i].instantiate()
		place.position = Vector3(i * 1500, 0, 0)
		add_child(place)
		world_ports.append(place)
	waypoint = Label3D.new()
	waypoint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waypoint.font_size = 48
	waypoint.pixel_size = .06
	add_child(waypoint)
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
	dock_button = button(buttons, "Dock", func():
		if docking.state(1) == "docked": docking.request_undock(1); jobs_panel.hide()
		else: docking.request_dock(1, service_id(), cargo_id()))
	cancel_button = button(buttons, "Cancel", func(): docking.cancel(1))
	button(buttons, "Main menu", leave)
	switch_button = button(buttons, "Test heavy loader", func():
		if not can_switch(): return
		heavy_mode = not heavy_mode
		select_port(world_ports.find(port)))
	navigation = Label.new()
	stack.add_child(navigation)
	services = VBoxContainer.new()
	stack.add_child(services)
	var tabs: HBoxContainer = HBoxContainer.new()
	services.add_child(tabs)
	button(tabs, "CARGO", func(): jobs_panel.visible = not jobs_panel.visible; refresh_jobs())
	button(tabs, "REFUEL", refuel)
	button(tabs, "REPAIR", repair)
	button(tabs, "Close services", func(): jobs_panel.hide())
	jobs_panel = VBoxContainer.new()
	services.add_child(jobs_panel)
	offer_text = Label.new()
	jobs_panel.add_child(offer_text)
	jobs_list = ItemList.new()
	jobs_list.focus_mode = Control.FOCUS_NONE
	jobs_list.custom_minimum_size = Vector2(430, 100)
	jobs_panel.add_child(jobs_list)
	for child: Node in jobs_list.get_children(true):
		if child is ScrollBar: child.focus_mode = Control.FOCUS_NONE
	jobs_list.item_selected.connect(func(index: int): selected_offer = jobs_list.get_item_metadata(index); jobs_list.release_focus())
	accept_button = button(jobs_panel, "Accept selected job", accept_selected)
	deliver_button = button(jobs_panel, "Deliver cargo at this port", deliver)
	cancel_load_button = button(jobs_panel, "Cancel loading (release job)", func(): loading.cancel(); refresh_jobs())
	loading_text = Label.new()
	stack.add_child(loading_text)
	heavy_controls = HBoxContainer.new()
	stack.add_child(heavy_controls)
	button(heavy_controls, "Lower", func(): ship.request_height(Heavy.LOWERED))
	button(heavy_controls, "Raise", func(): ship.request_height(Heavy.RAISED))
	button(heavy_controls, "Cancel pickup", func(): heavy_jobs.cancel_pickup(ship); refresh_jobs())
	select_port(0)
	if save_enabled and not OS.get_cmdline_user_args().has("--ports-check") and not OS.get_cmdline_user_args().has("--voyage-check"):
		persistence = preload("res://features/cargo/voyage_persistence.gd").new()
		add_child(persistence)
		get_tree().auto_accept_quit = false

func service_id() -> String:
	return "heavy_transfer" if heavy_mode else "container_transfer"

func cargo_id() -> String:
	return "cargo_test_industrial" if heavy_mode else "cargo_test_container"

func ship_key() -> String:
	return "preview_heavy" if heavy_mode else "preview_ship"

func can_switch() -> bool:
	return not loading.busy() and offers.active_job("preview_captain").is_empty() and heavy_jobs.active.is_empty() and (not is_instance_valid(ship) or ship.state.manifest.lines().is_empty())

func select_port(index: int) -> void:
	if not heavy_jobs.active.is_empty(): return
	var carried: Array[Dictionary] = []
	if is_instance_valid(ship): carried = ship.state.manifest.lines()
	loading.disconnect_ship()
	docking.disconnect_owner(1)
	if is_instance_valid(port): port.spawn_allocator.release(spawn_ticket)
	for node: Node in [helm, wake, ship]:
		if is_instance_valid(node): remove_child(node); node.queue_free()
	port = world_ports[index]
	ship = preload("res://features/ships/heavy_lifter_01/heavy_runtime.tscn").instantiate() if heavy_mode else preload("res://features/ships/starter_container_01/starter_runtime.tscn").instantiate()
	var allocation: Dictionary = port.reserve_spawn(ship.definition.hull_size_m)
	if not allocation.ok:
		ship.free(); ship = null; helm = null; wake = null
		details.text = "Spawn occupied. Return to the menu and retry."
		return
	spawn_ticket = allocation.ticket
	ship.transform = allocation.transform
	add_child(ship)
	if heavy_mode:
		ship.payload_body.collision_layer = 0
		ship.payload_body.hide()
	ship.state.manifest.replace(carried)
	bind_port()
	helm = ShipHelm.new()
	add_child(helm)
	helm.configure(ship, controls, ship.assembly.feedback)
	helm.menu_requested.connect(leave)
	wake = ship.assembly.create_wake(ocean)
	camera.distance_order = ship.definition.camera_distance_m
	camera.set_focus(ship.assembly.focus)
	controls.wait_for_release = true

func bind_port() -> void:
	offer_notice = ""
	docking.disconnect_owner(1)
	docking.register(1, ship, port)
	loading.bind(ship, port, docking, offers, 1, "preview_captain", ship_key())
	jobs_panel.hide()
	refresh_jobs()

func refresh_jobs() -> void:
	if jobs_list == null or not is_instance_valid(port): return
	jobs_list.clear()
	selected_offer = ""
	var rows: Array[Dictionary] = heavy_jobs.list_at(port.definition.id) if heavy_mode else offers.list_at(port.definition.id)
	for row: Dictionary in rows:
		if row.state != "available": continue
		var title: String = row.title + " → open ocean" if heavy_mode else "%d container%s → %s" % [row.quantity, "" if row.quantity == 1 else "s", "Slatewater Works" if row.destination_port_id == "port_slatewater_works" else "Brindle Quay"]
		jobs_list.add_item("%s · %.2f credits" % [title, row.reward_minor / 100.0])
		jobs_list.set_item_metadata(jobs_list.item_count - 1, row.id)
	if jobs_list.item_count > 0:
		jobs_list.select(0)
		selected_offer = jobs_list.get_item_metadata(0)

func accept_selected() -> void:
	if docking.state(1) != "docked" or selected_offer.is_empty() or loading.busy(): return
	if not heavy_jobs.active.is_empty() or not offers.active_job("preview_captain").is_empty():
		offer_notice = "Finish your current job before accepting another."
		return
	if heavy_mode:
		offer_notice = "Load ready nearby. Undock and collect it." if heavy_jobs.accept(selected_offer, ship, port, true) else "Cannot accept this job yet."
	else:
		var result: Dictionary = offers.accept(selected_offer, "preview_captain", ship_key(), port.definition.id, ship.state.manifest)
		offer_notice = result.message
		if result.ok:
			if loading.start(selected_offer): offer_notice = "Accepted — loading your cargo."
			else:
				offers.release_job(selected_offer, "preview_captain", ship_key())
				offer_notice = "Loading could not start. Job released; try again while docked."
	refresh_jobs()

func refuel() -> void:
	if docking.state(1) != "docked" or loading.busy(): return
	var amount: float = ship.refuel(ship.definition.fuel_capacity_liters)
	offer_notice = "Refueled %.0f L — free test service." % amount

func repair() -> void:
	if docking.state(1) != "docked" or loading.busy(): return
	offer_notice = "No repairs needed." if ship.state.condition >= 1 else "Repairs complete — free test service."
	ship.state.condition = 1.0

func deliver() -> void:
	if heavy_mode or loading.busy(): return
	var result: Dictionary = offers.deliver_at("preview_captain", ship_key(), port.definition.id, ship.state.manifest, docking.state(1) == "docked")
	reward_minor += result.reward_minor
	offer_notice = result.message
	refresh_jobs()

func leave() -> void:
	if is_instance_valid(persistence) and not persistence.blocked:
		if not persistence.checkpoint(): return
	loading.disconnect_ship()
	get_tree().auto_accept_quit = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://features/main/main.tscn")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(ship): return
	offer_time += delta
	offers.advance_to(int(offer_time * 1000))
	if docking.state(1) in ["underway", "approaching"] and not loading.busy():
		for other: Node3D in world_ports:
			if other != port and ship.global_position.distance_to(other.berth_anchor.global_position) < 250 and ship.global_position.distance_to(other.berth_anchor.global_position) < ship.global_position.distance_to(port.berth_anchor.global_position):
				port.spawn_allocator.release(spawn_ticket)
				spawn_ticket = 0
				port = other
				bind_port()
	if heavy_mode:
		heavy_jobs.update(ship)
		reward_minor += heavy_jobs.reward_pending
		heavy_jobs.reward_pending = 0
	var status: Dictionary = port.berth_readiness(ship, service_id(), cargo_id())
	var current: String = docking.state(1)
	dock_button.visible = ship.global_position.distance_to(port.berth_anchor.global_position) < 150 or current in ["docking", "docked", "undocking"]
	dock_button.text = "Undock" if current == "docked" else "Dock"
	dock_button.disabled = loading.busy() or not (current == "docked" or (current in ["underway", "approaching"] and status.eligible))
	dock_button.modulate = Color.WHITE if dock_button.disabled else Color("9ee3b1")
	cancel_button.visible = current in ["docking", "undocking"]
	readiness.text = "Berth: " + (current.capitalize() if current in ["docking", "docked", "undocking"] else status.message)
	services.visible = current == "docked"
	if is_instance_valid(helm): helm.throttle_display.visible = not services.visible
	if not services.visible: jobs_panel.hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(ship): return
	details.text = "%s · %s\nLocal test voyage · Earnings %.2f credits" % [port.definition.display_name, "Heavy loader" if heavy_mode else "Container ship", reward_minor / 100.0]
	switch_button.text = "Test container ship" if heavy_mode else "Test heavy loader"
	switch_button.disabled = not can_switch()
	offer_text.text = "Heavy-loader jobs" if heavy_mode else "Container jobs"
	accept_button.disabled = selected_offer.is_empty() or loading.busy() or not heavy_jobs.active.is_empty() or not offers.active_job("preview_captain").is_empty()
	deliver_button.visible = not heavy_mode
	cancel_load_button.visible = loading.busy()
	heavy_controls.visible = heavy_mode and not heavy_jobs.active.is_empty()
	loading_text.text = ("Loading %.0f%%" % loading.progress_percent() if loading.busy() else offer_notice) + "\nFuel %.0f / %.0f L · Condition %.0f%%" % [ship.state.fuel_liters, ship.definition.fuel_capacity_liters, ship.state.condition * 100]
	waypoint.visible = false
	if heavy_mode and not heavy_jobs.active.is_empty():
		var target: Vector3 = ship.payload_body.global_position if heavy_jobs.active.state == "pickup" else heavy_jobs.active.drop
		waypoint.position = target + Vector3(0, 12, 0)
		waypoint.text = "PICKUP" if heavy_jobs.active.state == "pickup" else "OCEAN DROP-OFF"
		waypoint.visible = true
		navigation.text = "%s · %.0f m\n%s\n%s" % [waypoint.text, ship.global_position.distance_to(target), ship.alignment_hint() if not ship.attached else "At drop-off: stop, then Lower to deliver.", ship.notice]
	else:
		var destination: Node3D = world_ports[1] if port == world_ports[0] else world_ports[0]
		navigation.text = "%s: %.0f m · RMB orbit · Wheel zoom · Esc menu" % [destination.definition.display_name, ship.global_position.distance_to(destination.berth_anchor.global_position)]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(persistence) and not persistence.blocked:
			if not persistence.checkpoint(): return
		get_tree().quit()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = true
