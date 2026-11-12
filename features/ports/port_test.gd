extends Node3D
const PORTS: Array[PackedScene] = [preload("res://features/ports/brindle_quay.tscn"), preload("res://features/ports/slatewater_works.tscn")]
## M4, the game only: two more ports. Positions come from Progression.WORLD.
const GAME_PORTS: Array[PackedScene] = [preload("res://features/ports/cinder_point.tscn"), preload("res://features/ports/gannet_light.tscn")]
const Heavy = preload("res://features/handling/heavy_lifter.gd")
@export var save_enabled: bool = true
@export var save_path: String = "user://worlds/private_port_voyage/voyage.db"
## True in features/game/game.tscn: the real game (REBUILD_PLAN.md M1). False: Port Test.
@export var game_mode: bool = false
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
var delivery = preload("res://features/cargo/delivery_service.gd").new()
var voyage_hud = preload("res://features/ports/voyage_hud.gd").new()
var minimap = preload("res://features/ports/local_minimap.gd").new()
var action_reason: Label
var refuel_button: Button
var repair_button: Button
var receipt_label: Label
var abandon_button: Button
var abandon_job_id: String = ""
var abandon_deadline: int = 0
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
## M2 prices in hundredths of a credit. The game only; Port Test stays free.
const FUEL_MINOR_PER_LITER: int = 50
const REPAIR_MINOR_PER_PERCENT: int = 500
const RECOVERY_FEE_MINOR: int = 20000
## Money spent so far. The save checks wallet = earned - spent.
var spent_minor: int = 0
var sink_seconds: float = 0.0
## M3, the game only: the ship being sailed, the ships owned (each with its stored
## fuel and hull as 0..1) and the bulk jobs. Port Test never changes these.
const Progression = preload("res://features/game/progression.gd")
var ship_kind: String = "container"
var fleet: Dictionary = {"container": {"fuel": 1.0, "condition": 1.0}}
var bulk_active: String = ""
## M4: pay from bulk and heavy jobs. They repeat, so the save keeps the total.
var banked_minor: int = 0
var ships_panel: VBoxContainer
var ship_buttons: Dictionary = {}
var sell_kind: String = ""
var sell_deadline: int = 0
## M5, the game only: one-shot sounds by name ("chime" when paid, "thud" on a hit).
var sfx: Dictionary = {}

func play_sound(kind: String) -> void:
	if sfx.has(kind): sfx[kind].play()

## M5 first-voyage hint: the helm keys as they are bound in Settings.
func controls_hint() -> String:
	var keys: Dictionary = {}
	for action: String in controls.preferences.bindings: keys[action] = OS.get_keycode_string(controls.preferences.bindings[action])
	return "%s / %s throttle · %s / %s steer · %s / %s side thrusters\n%s engine to zero · %s horn · Right mouse look · Wheel zoom\nEsc saves and opens the menu. Keys can be changed in Settings." % [
		keys.ship_throttle_up, keys.ship_throttle_down, keys.ship_steer_left, keys.ship_steer_right,
		keys.ship_thruster_left, keys.ship_thruster_right, keys.ship_throttle_zero, keys.horn]

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
	# A check may point the game at an isolated save. Players never set this.
	if game_mode: save_path = str(get_tree().get_meta("game_save_path", save_path))
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
	var scenes: Array = PORTS.duplicate()
	if game_mode:
		scenes.append_array(GAME_PORTS)
		for rect: Rect2 in Progression.LAND: add_land(rect)
		# The game's own container jobs: three per port, replaced as they are delivered.
		offers._offers.clear()
		offers.restock()
		for kind: String in ["chime", "thud"]:
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			player.stream = HandlingFeedback.tone(kind)
			player.volume_db = -14.0
			add_child(player)
			sfx[kind] = player
	for i: int in scenes.size():
		var place: Node3D = scenes[i].instantiate()
		place.position = Progression.WORLD[i].at
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
	layer.add_child(voyage_hud)
	minimap.view = self
	layer.add_child(minimap)
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
		else: offer_notice = docking.request_dock(1, service_id(), cargo_id()).message)
	cancel_button = button(buttons, "Cancel", func(): docking.cancel(1))
	button(buttons, "Main menu", leave)
	switch_button = button(buttons, "Test heavy loader", func():
		if not can_switch(): return
		heavy_mode = not heavy_mode
		select_port(world_ports.find(port)))
	switch_button.visible = not game_mode
	navigation = Label.new()
	stack.add_child(navigation)
	services = VBoxContainer.new()
	stack.add_child(services)
	var tabs: HBoxContainer = HBoxContainer.new()
	services.add_child(tabs)
	button(tabs, "CARGO", func(): jobs_panel.visible = not jobs_panel.visible; ships_panel.hide(); refresh_jobs())
	refuel_button = button(tabs, "REFUEL", refuel)
	repair_button = button(tabs, "REPAIR", repair)
	if game_mode:
		button(tabs, "SHIPS", func(): ships_panel.visible = not ships_panel.visible; jobs_panel.hide())
	button(tabs, "Close services", func(): jobs_panel.hide(); ships_panel.hide())
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
	cancel_load_button = button(jobs_panel, "Cancel loading (release job)", func(): end_current_job(false))
	abandon_button = button(jobs_panel, "Abandon cargo (no payment)", request_abandon)
	action_reason = Label.new()
	action_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jobs_panel.add_child(action_reason)
	# M3 shipyard: one row per ship, behind the SHIPS button.
	ships_panel = VBoxContainer.new()
	ships_panel.hide()
	services.add_child(ships_panel)
	if game_mode:
		for kind: String in Progression.SHIPS:
			var row: HBoxContainer = HBoxContainer.new()
			ships_panel.add_child(row)
			ship_buttons[kind] = [button(row, "", ship_action.bind(kind)), button(row, "", sell_ship.bind(kind))]
	loading_text = Label.new()
	stack.add_child(loading_text)
	receipt_label = Label.new()
	stack.add_child(receipt_label)
	heavy_controls = HBoxContainer.new()
	stack.add_child(heavy_controls)
	button(heavy_controls, "Lower", func(): ship.request_height(Heavy.LOWERED))
	button(heavy_controls, "Raise", func(): ship.request_height(Heavy.RAISED))
	button(heavy_controls, "Cancel pickup", func(): end_current_job(false))
	select_port(0)
	if save_enabled and not OS.get_cmdline_user_args().has("--ports-check") and not OS.get_cmdline_user_args().has("--voyage-check"):
		persistence = preload("res://features/cargo/voyage_persistence.gd").new()
		add_child(persistence)
		get_tree().auto_accept_quit = false

## M4 coastline: a solid sand slab level with the quays, with a green block on top.
func add_land(rect: Rect2) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(rect.get_center().x, -2, rect.get_center().y)
	body.collision_layer = CollisionRules.SHORE
	body.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
	add_child(body)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(rect.size.x, 12, rect.size.y)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	for level: int in 2:
		var box: BoxMesh = BoxMesh.new()
		box.size = shape.size if level == 0 else Vector3(rect.size.x - 120, 14, rect.size.y - 120)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color("d6c692") if level == 0 else Color("7fa368")
		material.roughness = 0.9
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = material
		mesh.position.y = level * 13
		body.add_child(mesh)

## Port Test services are free. The game charges (M2).
func free_note() -> String:
	return "Fuel %.2f credits per litre · Repair %.2f per 1%% hull" % [FUEL_MINOR_PER_LITER / 100.0, REPAIR_MINOR_PER_PERCENT / 100.0] if game_mode else "free test service"

func pay(cost_minor: int) -> void:
	spent_minor += cost_minor
	reward_minor -= cost_minor

## Litres the tank needs, limited by what the wallet can buy.
func fuel_offered() -> float:
	return minf(ship.definition.fuel_capacity_liters - ship.state.fuel_liters, float(reward_minor) / FUEL_MINOR_PER_LITER)

## Hull percent to repair, limited by what the wallet can buy.
func repair_offered() -> int:
	return mini(ceili((1.0 - ship.state.condition) * 100.0 - 0.001), floori(float(reward_minor) / REPAIR_MINOR_PER_PERCENT))

func take_damage(damage_bp: int) -> void:
	ship.state.condition = maxf(0.0, ship.state.condition - damage_bp / 10000.0)
	offer_notice = "Collision! Hull %.0f%%. Dock and click REPAIR." % (ship.state.condition * 100.0)
	play_sound("thud")

## Tow back to the current port: out of fuel (tow button) or sunk. The fee is
## capped by the wallet, so a broke captain is never stuck.
func recover() -> void:
	var sunk: bool = ship.state.condition <= 0.0
	var fee: int = mini(RECOVERY_FEE_MINOR, reward_minor)
	docking.cancel(1)
	port.spawn_allocator.release(spawn_ticket)
	spawn_ticket = 0
	var allocation: Dictionary = port.reserve_spawn(ship.definition.hull_size_m)
	if allocation.ok:
		spawn_ticket = allocation.ticket
		ship.global_transform = allocation.transform
	ship.velocity = Vector3.ZERO
	ship.yaw_rate = 0
	ship.zero_throttle()
	ship.actual_throttle = 0
	ship.simulation_paused = false
	sink_seconds = 0
	if sunk: ship.state.condition = 0.5
	ship.state.fuel_liters = maxf(ship.state.fuel_liters, ship.definition.fuel_capacity_liters * 0.25)
	pay(fee)
	offer_notice = "%s %s. Recovery fee paid: %.2f credits." % ["Ship raised, patched to 50% hull and towed to" if sunk else "Towed to", port.definition.display_name, fee / 100.0]
	controls.wait_for_release = true

## Simplify pass: the game has one status HUD (voyage_hud). The older panel line
## and the gauge panel repeat it, so in the game they need developer mode (F3).
func extras_visible() -> bool:
	return not game_mode or DevMode.enabled

func service_id() -> String:
	return "heavy_transfer" if heavy_mode else "container_transfer"

func cargo_id() -> String:
	return "cargo_test_industrial" if heavy_mode else "cargo_test_container"

func ship_key() -> String:
	return "preview_heavy" if heavy_mode else "preview_ship"

func bulk_mode() -> bool:
	return game_mode and ship_kind == "bulk"

func bulk_destination() -> Node3D:
	return world_ports[int(Progression.bulk_job(bulk_active).destination)]

func deliver_reason() -> String:
	if not bulk_mode(): return delivery.reason(self)
	if bulk_active.is_empty(): return "No loaded job to deliver."
	if docking.state(1) != "docked": return "Dock at the destination first."
	if port != bulk_destination(): return "This cargo belongs at " + bulk_destination().definition.display_name + "."
	return ""

## SHIPS panel, first button: buy a ship, or switch to one already owned.
func ship_action(kind: String) -> void:
	if kind == ship_kind or docking.state(1) != "docked": return
	var entry: Dictionary = Progression.SHIPS[kind]
	if not fleet.has(kind):
		if reward_minor < entry.price_minor:
			offer_notice = "Not enough money for the %s." % entry.name
			return
		pay(entry.price_minor)
		fleet[kind] = {"fuel": 1.0, "condition": 1.0}
		offer_notice = "Bought the %s for %.2f credits. Click Switch to sail it." % [entry.name, entry.price_minor / 100.0]
		return
	if not can_switch():
		offer_notice = "Finish or cancel your current job before changing ships."
		return
	# The ship left behind keeps its fuel and damage: switching is not a free refit.
	var previous: String = ship_kind
	var stored: Dictionary = {"fuel": clampf(ship.state.fuel_liters / maxf(1.0, ship.definition.fuel_capacity_liters), 0.0, 1.0), "condition": clampf(ship.state.condition, 0.0, 1.0)}
	ship_kind = kind
	heavy_mode = kind == "heavy"
	if not select_port(world_ports.find(port)):
		ship_kind = previous
		heavy_mode = previous == "heavy"
		return
	fleet[previous] = stored
	ship.state.fuel_liters = float(fleet[kind].fuel) * ship.definition.fuel_capacity_liters
	ship.state.condition = float(fleet[kind].condition)
	offer_notice = "Now sailing the %s. It is waiting off the quay; the %s stays at the yard." % [entry.name, Progression.SHIPS[previous].name]

## SHIPS panel, second button: sell a ship you are not sailing. Two clicks.
func sell_ship(kind: String) -> void:
	if kind == ship_kind or not fleet.has(kind) or docking.state(1) != "docked": return
	if sell_kind != kind or Time.get_ticks_msec() > sell_deadline:
		sell_kind = kind
		sell_deadline = Time.get_ticks_msec() + 5000
		offer_notice = "Sell the %s for %.2f credits? Click Confirm sale within 5 seconds." % [Progression.SHIPS[kind].name, Progression.resale_minor(kind) / 100.0]
		return
	sell_kind = ""
	fleet.erase(kind)
	pay(-Progression.resale_minor(kind))
	offer_notice = "Sold the %s for %.2f credits." % [Progression.SHIPS[kind].name, Progression.resale_minor(kind) / 100.0]

func refresh_ships() -> void:
	for kind: String in ship_buttons:
		var entry: Dictionary = Progression.SHIPS[kind]
		var owned: bool = fleet.has(kind)
		var main: Button = ship_buttons[kind][0]
		var sell: Button = ship_buttons[kind][1]
		if kind == ship_kind: main.text = entry.name + " — sailing now"
		elif owned: main.text = "Switch to " + entry.name
		else: main.text = "Buy %s · %.2f" % [entry.name, entry.price_minor / 100.0]
		main.tooltip_text = ""
		if not owned and reward_minor < entry.price_minor: main.tooltip_text = "Not enough money yet."
		elif owned and kind != ship_kind and not can_switch(): main.tooltip_text = "Finish or cancel your current job first."
		main.disabled = kind == ship_kind or not main.tooltip_text.is_empty()
		sell.visible = owned and kind != ship_kind
		sell.text = "Confirm sale" if sell_kind == kind and Time.get_ticks_msec() <= sell_deadline else "Sell · +%.2f" % (Progression.resale_minor(kind) / 100.0)

func can_switch() -> bool:
	return bulk_active.is_empty() and not loading.busy() and offers.active_job("preview_captain").is_empty() and heavy_jobs.active.is_empty() and (not is_instance_valid(ship) or ship.state.manifest.lines().is_empty())

func create_ship() -> HandlingShip:
	return preload("res://features/ships/heavy_lifter_01/heavy_runtime.tscn").instantiate() if heavy_mode else preload("res://features/ships/starter_container_01/starter_runtime.tscn").instantiate()

func select_port(index: int, restoring: bool = false) -> bool:
	if index < 0 or index >= world_ports.size(): return false
	if is_instance_valid(ship) and not restoring and not can_switch():
		heavy_mode = ship.definition.id == "ship_heavy_lifter_01"
		offer_notice = "Finish or cancel your current job before changing ships."
		return false
	var next_port: Node3D = world_ports[index]
	var next_ship: HandlingShip = create_ship()
	var allocation: Dictionary = next_port.reserve_spawn(next_ship.definition.hull_size_m)
	if not allocation.ok:
		next_ship.free()
		if is_instance_valid(ship): heavy_mode = ship.definition.id == "ship_heavy_lifter_01"
		offer_notice = "Spawn occupied. Current ship and job preserved."
		return false
	loading.disconnect_ship()
	docking.disconnect_owner(1)
	if is_instance_valid(port): port.spawn_allocator.release(spawn_ticket)
	for node: Node in [helm, wake, ship]:
		if is_instance_valid(node): remove_child(node); node.queue_free()
	port = next_port
	ship = next_ship
	if restoring: heavy_jobs.active.clear()
	spawn_ticket = allocation.ticket
	ship.transform = allocation.transform
	add_child(ship)
	if game_mode: ship.validated_impact.connect(take_damage)
	if heavy_mode:
		ship.payload_body.collision_layer = 0
		ship.payload_body.hide()
	bind_port()
	helm = ShipHelm.new()
	add_child(helm)
	helm.configure(ship, controls, ship.assembly.feedback)
	helm.notice.hints = helm_hints()
	helm.menu_requested.connect(leave)
	wake = ship.assembly.create_wake(ocean)
	camera.distance_order = ship.definition.camera_distance_m
	camera.set_focus(ship.assembly.focus)
	controls.wait_for_release = true
	return true

## Wording for the helm notice: how to get out of each state in this scene.
func helm_hints() -> Dictionary:
	var hints: Dictionary = {"leave": "Click \"Main menu\"", "docked": "Wait for docking to finish, then click \"Undock\" to sail.",
		"empty": "Dock and click REFUEL. Out of reach of a berth? Use the free test fuel below.", "rescue": true}
	if game_mode:
		hints.empty = "Call a tow back to port. It costs %.2f credits, or what you have if less." % (RECOVERY_FEE_MINOR / 100.0)
		hints.rescue_text = "Call a tow to port"
		hints.rescue_action = recover
	return hints

func bind_port() -> void:
	offer_notice = ""
	docking.disconnect_owner(1)
	docking.register(1, ship, port)
	loading.bind(ship, port, docking, offers, 1, "preview_captain", ship_key())
	jobs_panel.hide()
	ships_panel.hide()
	refresh_jobs()

func refresh_jobs() -> void:
	if jobs_list == null or not is_instance_valid(port): return
	var previous: String = selected_offer
	jobs_list.clear()
	selected_offer = ""
	if game_mode: offers.restock()
	if bulk_mode():
		for id: String in Progression.bulk_ids(world_ports.find(port)):
			var bulk_job: Dictionary = Progression.bulk_job(id)
			if id == bulk_active: continue
			jobs_list.add_item("%s → %s · %.2f credits" % [bulk_job.title, world_ports[int(bulk_job.destination)].definition.display_name, bulk_job.reward_minor / 100.0])
			jobs_list.set_item_metadata(jobs_list.item_count - 1, id)
	var rows: Array[Dictionary] = heavy_jobs.list_at(port.definition.id) if heavy_mode else offers.list_at(port.definition.id)
	for row: Dictionary in rows:
		if row.state != "available" or bulk_mode(): continue
		var title: String = row.title + " → open ocean" if heavy_mode else "%d container%s → %s" % [row.quantity, "" if row.quantity == 1 else "s", PrototypeCatalog.display_name(row.destination_port_id)]
		jobs_list.add_item("%s · %.2f credits" % [title, row.reward_minor / 100.0])
		jobs_list.set_item_metadata(jobs_list.item_count - 1, row.id)
	if jobs_list.item_count > 0:
		var selected: int = 0
		for index: int in jobs_list.item_count:
			if jobs_list.get_item_metadata(index) == previous: selected = index
		jobs_list.select(selected)
		selected_offer = jobs_list.get_item_metadata(selected)

func accept_reason() -> String:
	if is_instance_valid(persistence) and not persistence.ready_to_save: return "Please wait for voyage saving/recovery."
	if docking.state(1) != "docked": return "Dock before accepting a job."
	if loading.busy(): return "Loading in progress — wait or cancel loading."
	if not bulk_active.is_empty() or not heavy_jobs.active.is_empty() or not offers.active_job("preview_captain").is_empty(): return "Finish or cancel your current job before accepting another."
	if selected_offer.is_empty(): return "No jobs available here for this ship."
	return ""

func accept_selected() -> void:
	var reason: String = accept_reason()
	if not reason.is_empty():
		offer_notice = reason
		return
	if not heavy_jobs.active.is_empty() or not offers.active_job("preview_captain").is_empty():
		offer_notice = "Finish your current job before accepting another."
		return
	if bulk_mode():
		# Bulk loads at once: no crane work to wait for.
		if Progression.bulk_job(selected_offer).get("origin", -1) == world_ports.find(port):
			bulk_active = selected_offer
			offer_notice = "Cargo loaded. Undock and sail to %s." % bulk_destination().definition.display_name
	elif heavy_mode:
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

func end_current_job(abandon: bool) -> void:
	var result: Dictionary = preload("res://features/cargo/voyage_lifecycle.gd").end_job(self, abandon)
	offer_notice = result.message
	abandon_job_id = ""
	refresh_jobs()

func request_abandon() -> void:
	if not bulk_active.is_empty():
		if abandon_job_id == bulk_active and Time.get_ticks_msec() <= abandon_deadline:
			bulk_active = ""
			abandon_job_id = ""
			offer_notice = "Cargo abandoned — no payment. The job is open again at its port."
			refresh_jobs()
		else:
			abandon_job_id = bulk_active
			abandon_deadline = Time.get_ticks_msec() + 5000
			offer_notice = "This removes the cargo with no payment. Press Confirm abandon within 5 seconds."
		return
	var job: Dictionary = offers.active_job("preview_captain")
	if job.is_empty() or job.state != "loaded": return
	if abandon_job_id == job.id and Time.get_ticks_msec() <= abandon_deadline:
		end_current_job(true)
	else:
		abandon_job_id = job.id
		abandon_deadline = Time.get_ticks_msec() + 5000
		offer_notice = "This removes the cargo with no payment. Press Confirm abandon within 5 seconds."

func refuel() -> void:
	if docking.state(1) != "docked" or loading.busy(): return
	if game_mode:
		if ship.definition.fuel_capacity_liters - ship.state.fuel_liters < 1.0: offer_notice = "The tank is full."
		elif fuel_offered() < 1.0: offer_notice = "Not enough money for fuel. Deliver a job first."
		else:
			var bought: float = ship.refuel(fuel_offered())
			var cost: int = mini(reward_minor, ceili(bought * FUEL_MINOR_PER_LITER))
			pay(cost)
			offer_notice = "Refueled %.0f L for %.2f credits." % [bought, cost / 100.0]
		return
	var amount: float = ship.refuel(ship.definition.fuel_capacity_liters)
	offer_notice = "Refueled %.0f L — %s." % [amount, free_note()]

func repair() -> void:
	if docking.state(1) != "docked" or loading.busy(): return
	if game_mode:
		var percent: int = repair_offered()
		if ship.state.condition >= 0.995: offer_notice = "No repairs needed."
		elif percent <= 0: offer_notice = "Not enough money for repairs. Deliver a job first."
		else:
			pay(percent * REPAIR_MINOR_PER_PERCENT)
			ship.state.condition = minf(1.0, ship.state.condition + percent / 100.0)
			offer_notice = "Repaired to %.0f%% hull for %.2f credits." % [ship.state.condition * 100.0, percent * REPAIR_MINOR_PER_PERCENT / 100.0]
		return
	offer_notice = "No repairs needed." if ship.state.condition >= 1 else "Repairs complete — %s." % free_note()
	ship.state.condition = 1.0

func deliver() -> void:
	if bulk_mode():
		if not deliver_reason().is_empty(): return
		# Pay and job state change together; the autosave writes both on this tick.
		# The job is on offer again at its port: money is never finite.
		var pay_minor: int = Progression.bulk_job(bulk_active).reward_minor
		banked_minor += pay_minor
		bulk_active = ""
		reward_minor += pay_minor
		offer_notice = "Delivery complete — paid %.2f credits." % (pay_minor / 100.0)
		play_sound("chime")
		refresh_jobs()
		return
	var result: Dictionary = delivery.deliver(self)
	offer_notice = result.message
	if result.ok: play_sound("chime")
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
	if game_mode and not heavy_jobs.completed.is_empty():
		# M4: a delivered heavy job is banked and offered again at its port.
		for done: Dictionary in heavy_jobs.completed.values():
			banked_minor += int(done.reward_minor)
			offer_notice = "Heavy load delivered — paid %.2f credits." % (done.reward_minor / 100.0)
		heavy_jobs.completed.clear()
		play_sound("chime")
		refresh_jobs()
	if game_mode and ship.state.condition <= 0.0:
		# Sunk: hold the ship for a moment under a banner, then recover it.
		if sink_seconds <= 0.0:
			sink_seconds = 4.0
			ship.simulation_paused = true
			ship.pause_reason = "YOUR SHIP SANK.\nA recovery crew is raising it and towing it to %s. Fee: %.2f credits." % [port.definition.display_name, mini(RECOVERY_FEE_MINOR, reward_minor) / 100.0]
		sink_seconds -= delta
		if sink_seconds <= 0.0: recover()
	var status: Dictionary = port.berth_readiness(ship, service_id(), cargo_id())
	var current: String = docking.state(1)
	dock_button.visible = ship.global_position.distance_to(port.berth_anchor.global_position) < 150 or current in ["docking", "docked", "undocking"]
	dock_button.text = "Undock" if current == "docked" else "Dock"
	dock_button.disabled = loading.busy() or sink_seconds > 0.0 or not (current == "docked" or (current in ["underway", "approaching"] and status.eligible))
	dock_button.modulate = Color.WHITE if dock_button.disabled else Color("9ee3b1")
	cancel_button.visible = current in ["docking", "undocking"]
	readiness.text = "Berth: " + (current.capitalize() + ("…" if current != "docked" else "") if current in ["docking", "docked", "undocking"] else status.message)
	services.visible = current == "docked"
	if is_instance_valid(helm): helm.throttle_display.visible = not services.visible
	if not services.visible: jobs_panel.hide(); ships_panel.hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(ship): return
	voyage_hud.refresh(self)
	# The sea is one 4 km sheet. In the game's larger world it follows the ship.
	if game_mode: ocean.global_position = Vector3(snappedf(ship.global_position.x, 50), 0, snappedf(ship.global_position.z, 50))
	details.visible = extras_visible()
	if is_instance_valid(helm): helm.gauge_display.visible = extras_visible()
	minimap.queue_redraw()
	details.text = "%s · %s\n%s: %.2f credits" % [port.definition.display_name, "Heavy loader" if heavy_mode else "Container ship", "Wallet" if game_mode else "Voyage wallet", reward_minor / 100.0]
	switch_button.text = "Test container ship" if heavy_mode else "Test heavy loader"
	switch_button.disabled = not can_switch()
	offer_text.text = "Heavy-loader jobs" if heavy_mode else ("Bulk jobs" if bulk_mode() else "Container jobs")
	refresh_ships()
	accept_button.tooltip_text = accept_reason()
	accept_button.disabled = not accept_button.tooltip_text.is_empty()
	refuel_button.text = "REFUEL"
	repair_button.text = "REPAIR"
	if game_mode:
		# The price of what the button will buy right now.
		if fuel_offered() >= 1.0: refuel_button.text = "REFUEL %.2f" % (ceili(fuel_offered() * FUEL_MINOR_PER_LITER) / 100.0)
		if repair_offered() > 0: repair_button.text = "REPAIR %.2f" % (repair_offered() * REPAIR_MINOR_PER_PERCENT / 100.0)
	# Full/no-damage remains a harmless action with explicit feedback; loading locks services.
	refuel_button.disabled = loading.busy()
	repair_button.disabled = loading.busy()
	refuel_button.tooltip_text = "Wait until loading finishes." if loading.busy() else "Fill to %.0f L capacity; %s." % [ship.definition.fuel_capacity_liters, free_note()]
	repair_button.tooltip_text = "Wait until loading finishes." if loading.busy() else "Restore condition to 100%; " + free_note() + "."
	action_reason.text = accept_button.tooltip_text
	if not bulk_active.is_empty() or (not heavy_mode and offers.active_job("preview_captain").get("state") == "loaded"): action_reason.text = deliver_reason()
	action_reason.visible = not action_reason.text.is_empty()
	deliver_button.visible = not heavy_mode
	deliver_button.tooltip_text = deliver_reason()
	deliver_button.disabled = not deliver_button.tooltip_text.is_empty()
	receipt_label.text = delivery.receipt_text(offers)
	if heavy_mode:
		receipt_label.text = ""
		if not heavy_jobs.completed.is_empty():
			var completed: Dictionary = heavy_jobs.completed.values().back()
			receipt_label.text = "DELIVERY RECEIPT\n1 industrial module delivered offshore\nPaid %.2f credits" % (completed.reward_minor / 100.0)
	receipt_label.text = receipt_label.text.replace("DELIVERY RECEIPT", "LAST DELIVERY RECEIPT")
	receipt_label.visible = not receipt_label.text.is_empty()
	cancel_load_button.visible = loading.busy()
	var active: Dictionary = offers.active_job("preview_captain")
	abandon_button.visible = not bulk_active.is_empty() or (not heavy_mode and active.get("state") == "loaded")
	abandon_button.text = "Confirm abandon — no payment" if not abandon_job_id.is_empty() and Time.get_ticks_msec() <= abandon_deadline else "Abandon cargo (no payment)"
	heavy_controls.visible = heavy_mode and not heavy_jobs.active.is_empty()
	if not loading.busy() and offer_notice == "Accepted — loading your cargo.": offer_notice = loading.notice
	loading_text.text = "Loading %.0f%% — please wait." % loading.progress_percent() if loading.busy() else offer_notice
	waypoint.visible = false
	if heavy_mode and not heavy_jobs.active.is_empty():
		var target: Vector3 = ship.payload_body.global_position if heavy_jobs.active.state == "pickup" else heavy_jobs.active.drop
		waypoint.position = target + Vector3(0, 12, 0)
		waypoint.text = "PICKUP" if heavy_jobs.active.state == "pickup" else "OCEAN DROP-OFF"
		waypoint.visible = true
		navigation.text = "%s · %.0f m\n%s\n%s" % [waypoint.text, ship.global_position.distance_to(target), ship.alignment_hint() if not ship.attached else "At drop-off: stop, then Lower to deliver.", ship.notice]
	else:
		navigation.text = "RMB orbit · Wheel zoom · Esc menu"
		# The game: the full key list until the first money is earned or spent.
		if game_mode: navigation.text = controls_hint() if reward_minor == 0 and spent_minor == 0 else "Right mouse look · Wheel zoom · Esc saves and opens the menu"
	if services.visible: navigation.text += "\n" + (free_note() if game_mode else "Refuel / repair: " + free_note())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(persistence) and not persistence.blocked:
			if not persistence.checkpoint(): return
		get_tree().quit()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = true
