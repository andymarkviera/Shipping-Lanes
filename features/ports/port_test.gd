extends Node3D
const PORTS: Array[PackedScene] = [preload("res://features/ports/brindle_quay.tscn"), preload("res://features/ports/slatewater_works.tscn")]
## M4, the game only: two more ports, and (Patch 2.1 item 3) the two polar
## ports. Positions come from Progression.WORLD.
const GAME_PORTS: Array[PackedScene] = [preload("res://features/ports/cinder_point.tscn"), preload("res://features/ports/gannet_light.tscn"), preload("res://features/ports/north_pole.tscn"), preload("res://features/ports/south_pole.tscn")]
const Heavy = preload("res://features/handling/heavy_lifter.gd")
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const SKY_LOOK = preload("res://features/sky/sky_look.gd")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
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
## Patch 2.0: the game's Esc menu (Resume, Settings, Main Menu, Quit). Null in test scenes.
var game_menu: CanvasLayer
## Patch 2.2 item 4: the full-screen boat hangar behind SHIPS.
var hangar: CanvasLayer
var camera: OrbitCameraRig
var ocean: OceanPresentation
var wake: ShipWake
var docking = preload("res://features/ports/docking_authority.gd").new()
var loading = preload("res://features/cargo/port_loading.gd").new()
## Patch 2.4 item 4, the game only: mooring lines on the docked ship.
var mooring: Node3D
## Patch 2.4 item 5, the game only: quay cranes move containers one at a time.
var cranes: Node3D
var offers = preload("res://features/cargo/container_offers.gd").new()
var heavy_jobs = preload("res://features/cargo/heavy_ocean_job.gd").new()
var delivery = preload("res://features/cargo/delivery_service.gd").new()
var voyage_hud = preload("res://features/ports/voyage_hud.gd").new()
var minimap = preload("res://features/ports/local_minimap.gd").new()
## Patch 2.0 item 5, the game only: the simplified HUD (helm bar, hint, notice,
## job cards). The old top-left panel is kept as the port card it arranges.
var game_hud: Control
var port_panel: PanelContainer
var dock_status: Dictionary = {}
## What refresh_jobs last listed, one entry per offer, for the game's job cards.
var job_cards: Array[Dictionary] = []
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
## Patch 2.2 item 1: container job cards shown at a port, biggest first.
const JOB_BOARD_SIZE: int = 6
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
## Patch 2.1 item 3, the game only: the solid icebergs, in Progression.ICEBERGS order.
var icebergs: Array[StaticBody3D] = []
## Patch 2.3 debug: the temporary debug layer (features/debug). Null in a normal game.
const DEBUG_GAME = preload("res://features/debug/debug_game.gd")
var debug: CanvasLayer

func play_sound(kind: String) -> void:
	if sfx.has(kind): sfx[kind].play()

## M5 first-voyage hint: the helm keys as they are bound in Settings.
func controls_hint() -> String:
	var keys: Dictionary = {}
	for action: String in controls.preferences.bindings: keys[action] = OS.get_keycode_string(controls.preferences.bindings[action])
	return "%s / %s throttle · %s / %s steer · %s / %s side thrusters\n%s engine to zero · %s horn · Right mouse look · Wheel zoom\nEsc opens the menu. Keys can be changed there, in Settings." % [
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
	# Patch 2.3 debug: a throwaway world. No persistence, so no save is opened.
	if game_mode and DEBUG_GAME.active(get_tree()): save_enabled = false
	add_child(docking)
	add_child(loading)
	if game_mode:
		mooring = preload("res://features/ports/mooring_lines.gd").new()
		mooring.name = "MooringLines"
		mooring.docking = docking
		docking.undock_seconds = mooring.LET_GO_SECONDS
		add_child(mooring)
		cranes = preload("res://features/ports/container_cranes.gd").new()
		cranes.name = "QuayCranes"
		cranes.docking = docking
		cranes.loading_preview = crane_preview
		add_child(cranes)
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
	# Aesthetics 3: cartoon sky, warm sun with shadows, blue ambient light, haze.
	SKY_LOOK.apply(light, environment.environment)
	add_child(environment)
	camera = OrbitCameraRig.new()
	add_child(camera)
	camera.bind_controls(controls)
	var scenes: Array = PORTS.duplicate()
	if game_mode:
		scenes.append_array(GAME_PORTS)
		for rect: Rect2 in Progression.LAND: add_land(rect)
		for rect: Rect2 in Progression.ICE_SHELVES: add_land(rect, true)
		for index: int in Progression.ICEBERGS.size(): add_iceberg(index)
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
		# Aesthetics 4: chunky port dressing. The game only; test scenes keep the blocks.
		if game_mode: CHUNKY_LOOK.dress_port(place)
		if game_mode: cranes.add_port(place)
	# Aesthetics 2: toon shading and ink outlines on the ports and land.
	TOON_LOOK.apply(self)
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
	port_panel = panel
	layer.add_child(voyage_hud)
	# Patch 2.0 item 5: the game's minimap is a globe. Test scenes keep the chart.
	if game_mode:
		minimap.free()
		minimap = preload("res://features/game/globe_minimap.gd").new()
	minimap.view = self
	layer.add_child(minimap)
	# Aesthetics 5: playful HUD. The game only; test scenes keep the plain panels.
	if game_mode:
		PLAYFUL.dress(panel)
		PLAYFUL.dress(voyage_hud)
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
	if game_mode:
		# Patch 2.0: Esc opens a menu over the running world instead of leaving.
		game_menu = preload("res://features/game/game_menu.gd").new()
		game_menu.controls = controls
		add_child(game_menu)
		game_menu.main_menu_requested.connect(leave)
		game_menu.quit_requested.connect(quit_game)
		hangar = preload("res://features/game/boat_hangar.gd").new()
		hangar.view = self
		add_child(hangar)
	navigation = Label.new()
	stack.add_child(navigation)
	services = VBoxContainer.new()
	services.visible = not game_mode
	stack.add_child(services)
	var tabs: HBoxContainer = HBoxContainer.new()
	services.add_child(tabs)
	button(tabs, "CARGO", func(): jobs_panel.visible = not jobs_panel.visible; ships_panel.hide(); refresh_jobs())
	refuel_button = button(tabs, "REFUEL", refuel)
	repair_button = button(tabs, "REPAIR", repair)
	if game_mode:
		# Patch 2.2 item 4: SHIPS opens the boat hangar. The old row list stays
		# built (hidden) because refresh_ships still keeps its buttons current.
		button(tabs, "SHIPS", func(): ships_panel.hide(); hangar.open())
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
	if game_mode:
		game_hud = preload("res://features/game/game_hud.gd").new()
		layer.add_child(game_hud)
		game_hud.setup(self)
	select_port(0)
	if game_mode and DEBUG_GAME.active(get_tree()):
		debug = DEBUG_GAME.new()
		debug.view = self
		add_child(debug)
	if save_enabled and not OS.get_cmdline_user_args().has("--ports-check") and not OS.get_cmdline_user_args().has("--voyage-check"):
		persistence = preload("res://features/cargo/voyage_persistence.gd").new()
		add_child(persistence)
		get_tree().auto_accept_quit = false

## M4 coastline: a solid sand slab level with the quays, with a green block on top.
## Land is sand with a green top; an ice shelf (polar ports) is pale ice with snow.
func add_land(rect: Rect2, ice: bool = false) -> void:
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
		material.albedo_color = (Color("bfe3ef") if level == 0 else Color("f7fbfd")) if ice else (Color("d6c692") if level == 0 else Color("7fa368"))
		material.roughness = 0.9
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = material
		mesh.position.y = level * 13
		body.add_child(mesh)

## Patch 2.1 item 3: a chunky toon iceberg, solid like land. A pale ice band at
## the waterline, a white body and one or two white peaks, each a few-sided
## drum so the toon outline reads as cut ice.
func add_iceberg(index: int) -> void:
	var entry: Vector3 = Progression.ICEBERGS[index]
	var radius: float = entry.y
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Iceberg%d" % index
	body.position = Vector3(entry.x, 0, entry.z)
	body.rotation.y = index * 1.7
	body.collision_layer = CollisionRules.SHORE
	body.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
	add_child(body)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = 16.0
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var tall: float = radius * (0.45 + 0.1 * (index % 3))
	# [bottom radius, top radius, height, centre y, centre x, colour]
	var parts: Array = [
		[radius, radius * 0.97, 3.0, -0.5, 0.0, Color("8fd0e3")],
		[radius * 0.95, radius * 0.78, tall * 0.45, 1.0 + tall * 0.225, 0.0, Color("f2f8fb")],
		[radius * 0.62, radius * 0.18, tall * 0.65, 1.0 + tall * 0.45 + tall * 0.325, radius * 0.12, Color("f7fbfd")],
	]
	if index % 2 == 0: parts.append([radius * 0.38, radius * 0.08, tall * 0.5, 1.0 + tall * 0.45 + tall * 0.25, -radius * 0.45, Color("e3f1f7")])
	for part: Array in parts:
		var drum: CylinderMesh = CylinderMesh.new()
		drum.bottom_radius = part[0]
		drum.top_radius = part[1]
		drum.height = part[2]
		drum.radial_segments = 6 + index % 3
		drum.rings = 1
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = part[5]
		material.roughness = 0.9
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = drum
		mesh.material_override = material
		mesh.position = Vector3(part[4], part[3], 0)
		body.add_child(mesh)
	icebergs.append(body)

## Each iceberg sits at its copy nearest the ship, so icebergs near an edge of
## the world are there on both sides of it. A move only ever happens half a
## world away from the ship, far out of sight.
func place_icebergs() -> void:
	for index: int in icebergs.size():
		var entry: Vector3 = Progression.ICEBERGS[index]
		var at: Vector3 = Progression.nearest(Vector3(entry.x, 0, entry.z), ship.global_position)
		at.y = 0.0
		if icebergs[index].position.distance_to(at) > 1.0: icebergs[index].position = at

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
	# Patch 2.2 item 2: a bulk ship docks for its abstract bulk jobs; no container check.
	if bulk_mode(): return ""
	return "cargo_test_industrial" if heavy_mode else "cargo_test_container"

func ship_key() -> String:
	return "preview_heavy" if heavy_mode else "preview_ship"

func bulk_mode() -> bool:
	return game_mode and Progression.bulk_tier(ship_kind) > 0

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
	# Patch 2.3 debug: Select away from a berth swaps on the spot.
	if is_instance_valid(debug) and debug.swap(kind): return
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
	heavy_mode = Progression.heavy_tier(kind) > 0
	if not select_port(world_ports.find(port)):
		ship_kind = previous
		heavy_mode = Progression.heavy_tier(previous) > 0
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
	if heavy_mode:
		var lifter: HandlingShip = preload("res://features/ships/heavy_lifter_01/heavy_runtime.tscn").instantiate()
		# Patch 2.2 item 3: heavy-lift ships 2-5 sail the same runtime with their own record.
		if game_mode and Progression.heavy_tier(ship_kind) > 0: lifter.definition = Progression.definition(ship_kind)
		return lifter
	var body: HandlingShip = preload("res://features/ships/starter_container_01/starter_runtime.tscn").instantiate()
	# Patch 2.2 item 1: container ships 2-5 sail the same runtime with their own record.
	if game_mode: body.definition = Progression.definition(ship_kind)
	return body

func select_port(index: int, restoring: bool = false) -> bool:
	if index < 0 or index >= world_ports.size(): return false
	if is_instance_valid(ship) and not restoring and not can_switch():
		heavy_mode = ship.has_method("attach_payload")
		offer_notice = "Finish or cancel your current job before changing ships."
		return false
	var next_port: Node3D = world_ports[index]
	var next_ship: HandlingShip = create_ship()
	# Patch 2.2 item 4: switching ships at the same port. The ship being replaced
	# (its hull and its own spawn hold) must not block its bigger successor; both
	# come back if the reservation still fails.
	var outgoing: Dictionary = {}
	if is_instance_valid(ship) and next_port == port and not restoring:
		outgoing = {"layer": ship.collision_layer, "hold": port.spawn_allocator.holds.get(spawn_ticket)}
		ship.collision_layer = 0
		port.spawn_allocator.holds.erase(spawn_ticket)
	var allocation: Dictionary = next_port.reserve_spawn(next_ship.definition.hull_size_m)
	if not allocation.ok and not outgoing.is_empty():
		ship.collision_layer = outgoing.layer
		if outgoing.hold != null: port.spawn_allocator.holds[spawn_ticket] = outgoing.hold
	if not allocation.ok:
		next_ship.free()
		if is_instance_valid(ship): heavy_mode = ship.has_method("attach_payload")
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
	# Aesthetics 4: chunky ship in place of the imported model. The game only.
	if game_mode: CHUNKY_LOOK.dress_ship(ship, ship_kind)
	TOON_LOOK.apply(ship)
	if game_mode: ship.validated_impact.connect(take_damage)
	if heavy_mode:
		ship.payload_body.collision_layer = 0
		ship.payload_body.hide()
	bind_port()
	helm = ShipHelm.new()
	add_child(helm)
	helm.configure(ship, controls, ship.assembly.feedback)
	helm.notice.hints = helm_hints()
	if game_mode:
		# Patch 2.0 item 5: the game's helm bar (game_hud) replaces the throttle panel.
		helm.throttle_display.hide()
		PLAYFUL.dress(helm.notice.panel, true)
		PLAYFUL.dress(helm.gauge_display.panel)
	helm.keep_sailing = game_mode
	helm.menu_requested.connect(game_menu.open if game_mode else leave)
	wake = ship.assembly.create_wake(ocean)
	camera.distance_order = ship.definition.camera_distance_m
	camera.set_focus(ship.assembly.focus)
	controls.wait_for_release = true
	return true

## Patch 2.4 item 5: how far the loading timer has got, for the quay cranes:
## (containers of the job reached so far, job quantity), or zero.
func crane_preview(_owner: int) -> Vector2i:
	if not loading.busy(): return Vector2i.ZERO
	var quantity: int = int(offers.view(loading.offer_id).get("quantity", 0))
	return Vector2i(clampi(ceili(loading.progress_percent() / 100.0 * quantity), 0, quantity), quantity)

func cranes_busy() -> bool:
	return cranes != null and cranes.busy(1)

## Wording for the helm notice: how to get out of each state in this scene.
func helm_hints() -> Dictionary:
	var hints: Dictionary = {"leave": "Click \"Main menu\"", "docked": "Wait for docking to finish, then click \"Undock\" to sail.",
		"empty": "Dock and click REFUEL. Out of reach of a berth? Use the free test fuel below.", "rescue": true}
	if game_mode:
		hints.empty = "Call a tow back to port. It costs %.2f credits, or what you have if less." % (RECOVERY_FEE_MINOR / 100.0)
		hints.rescue_text = "Call a tow to port"
		hints.rescue_action = recover
		hints.leave = "Press Esc, then Main Menu"
		hints.panel = ""
		hints.docked = ""
		hints.unfocused = "The ship holds its course. Click the game window to steer."
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
	job_cards.clear()
	selected_offer = ""
	if game_mode: offers.restock()
	if bulk_mode():
		# Patch 2.2 item 2: this ship's own tier first, then smaller loads, never
		# more than it carries, at most JOB_BOARD_SIZE cards.
		var bulk_rows: Array[String] = []
		for tier: int in range(Progression.bulk_tier(ship_kind), 0, -1): bulk_rows.append_array(Progression.bulk_ids(world_ports.find(port), tier))
		for id: String in bulk_rows.slice(0, JOB_BOARD_SIZE):
			var bulk_job: Dictionary = Progression.bulk_job(id)
			if id == bulk_active: continue
			jobs_list.add_item("%s → %s · %.2f credits" % [bulk_job.title, world_ports[int(bulk_job.destination)].definition.display_name, bulk_job.reward_minor / 100.0])
			jobs_list.set_item_metadata(jobs_list.item_count - 1, id)
			job_cards.append({"id": id, "kind": "bulk", "count": 1, "what": bulk_job.title, "to": world_ports[int(bulk_job.destination)].definition.display_name, "pay": bulk_job.reward_minor})
	var rows: Array[Dictionary] = offers.list_at(port.definition.id)
	if heavy_mode:
		# Patch 2.2 item 3: this ship's own tier first, then smaller loads, never a
		# bigger one, at most JOB_BOARD_SIZE cards.
		rows = []
		for tier: int in range(maxi(1, Progression.heavy_tier(ship_kind) if game_mode else 1), 0, -1): rows.append_array(heavy_jobs.list_at(port.definition.id, tier))
		rows.assign(rows.filter(func(row: Dictionary) -> bool: return row.state == "available"))
		rows.resize(mini(rows.size(), JOB_BOARD_SIZE))
	# Patch 2.2 item 1: never list a container job bigger than this ship. Jobs
	# sized for the biggest tier that fits come first, so a big ship sees its
	# own jobs on top; within a tier the order is as before. The board keeps to
	# JOB_BOARD_SIZE cards.
	if game_mode and not heavy_mode and is_instance_valid(ship):
		var room: int = int(ship.definition.cargo_capacities.get("container_slots", 0))
		rows.assign(rows.filter(func(row: Dictionary) -> bool: return row.state == "available" and int(row.quantity) <= room))
		var order: Dictionary = {}
		for index: int in rows.size(): order[rows[index].id] = index
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var tier_a: int = offers.job_tier(a.id)
			var tier_b: int = offers.job_tier(b.id)
			return tier_a > tier_b or (tier_a == tier_b and int(order[a.id]) < int(order[b.id])))
		rows.resize(mini(rows.size(), JOB_BOARD_SIZE))
	for row: Dictionary in rows:
		if row.state != "available" or bulk_mode(): continue
		var title: String = row.title + " → open ocean" if heavy_mode else "%d container%s → %s" % [row.quantity, "" if row.quantity == 1 else "s", PrototypeCatalog.display_name(row.destination_port_id)]
		jobs_list.add_item("%s · %.2f credits" % [title, row.reward_minor / 100.0])
		jobs_list.set_item_metadata(jobs_list.item_count - 1, row.id)
		job_cards.append({"id": row.id, "kind": "heavy" if heavy_mode else "container", "count": 1 if heavy_mode else int(row.quantity), "what": title.get_slice(" → ", 0), "to": "Open ocean" if heavy_mode else PrototypeCatalog.display_name(row.destination_port_id), "pay": row.reward_minor})
	if jobs_list.item_count > 0:
		var selected: int = 0
		for index: int in jobs_list.item_count:
			if jobs_list.get_item_metadata(index) == previous: selected = index
		jobs_list.select(selected)
		selected_offer = jobs_list.get_item_metadata(selected)
	if is_instance_valid(game_hud): game_hud.rebuild_cards()

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
		var picked: Dictionary = Progression.bulk_job(selected_offer)
		if picked.get("origin", -1) == world_ports.find(port) and int(picked.get("tier", 9)) <= Progression.bulk_tier(ship_kind):
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

## Patch 2.1 item 3: a ship past an edge of the world carries on from the
## opposite edge. The camera, the wake and the sea pattern move with it, so
## nothing on screen jumps.
func wrap_world() -> void:
	var shift: Vector3 = Progression.wrapped(ship.global_position) - ship.global_position
	if shift.length() < 1.0: return
	ship.global_position += shift
	if ship.get("attached") == true: ship.payload_body.global_position += shift
	camera.shift(shift)
	wake.shift(shift)
	ocean.shift(shift)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(ship): return
	if game_mode:
		wrap_world()
		place_icebergs()
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
	# Patch 2.1 item 4: the nearest free berth, or "port full".
	var status: Dictionary = docking.readiness(1, service_id(), cargo_id())
	var current: String = docking.state(1)
	dock_status = status
	# The game always shows Dock beside the throttle, greyed out with no berth in range.
	dock_button.visible = game_mode or ship.global_position.distance_to(port.berth_anchor.global_position) < 150 or current in ["docking", "docked", "undocking"]
	dock_button.text = "Undock" if current == "docked" else "Dock"
	dock_button.disabled = loading.busy() or cranes_busy() or sink_seconds > 0.0 or not (current == "docked" or (current in ["underway", "approaching"] and status.eligible))
	dock_button.modulate = Color.WHITE if dock_button.disabled else Color("9ee3b1")
	cancel_button.visible = current in ["docking", "undocking"]
	readiness.text = "Berth: " + (current.capitalize() + ("…" if current != "docked" else "") if current in ["docking", "docked", "undocking"] else status.message)
	# The game shows the job cards as soon as the ship is docked, so list them then.
	if game_mode and current == "docked" and not services.visible: refresh_jobs()
	services.visible = current == "docked"
	if is_instance_valid(helm): helm.throttle_display.visible = not services.visible and not game_mode
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
	if loading.busy(): loading_text.text = "Loading %.0f%% — please wait." % loading.progress_percent()
	elif cranes_busy(): loading_text.text = "The cranes are working: %d container%s to go." % [cranes.remaining(1), "" if cranes.remaining(1) == 1 else "s"]
	else: loading_text.text = offer_notice
	waypoint.visible = false
	if heavy_mode and not heavy_jobs.active.is_empty():
		var target: Vector3 = ship.payload_body.global_position if heavy_jobs.active.state == "pickup" else heavy_jobs.active.drop
		if game_mode: target = Progression.nearest(target, ship.global_position)
		waypoint.position = target + Vector3(0, 12, 0)
		waypoint.text = "PICKUP" if heavy_jobs.active.state == "pickup" else "OCEAN DROP-OFF"
		waypoint.visible = true
		navigation.text = "%s · %.0f m\n%s\n%s" % [waypoint.text, ship.global_position.distance_to(target), ship.alignment_hint() if not ship.attached else "At drop-off: stop, then Lower to deliver.", ship.notice]
	else:
		navigation.text = "RMB orbit · Wheel zoom · Esc menu"
		# The game: nothing here. The keys show briefly on the first voyage (game_hud).
		if game_mode: navigation.text = ""
	if services.visible and not game_mode: navigation.text += "\nRefuel / repair: " + free_note()
	if is_instance_valid(game_hud): game_hud.refresh(_delta)

## Save, then close the game. The window's close button and the Esc menu's Quit.
func quit_game() -> void:
	if is_instance_valid(persistence) and not persistence.blocked:
		if not persistence.checkpoint(): return
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = true
