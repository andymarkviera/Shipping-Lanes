extends Node3D
const PORTS: Array[PackedScene] = [preload("res://features/ports/brindle_quay.tscn"), preload("res://features/ports/slatewater_works.tscn")]
## M4, the game only: two more ports, and (Patch 2.1 item 3) the two polar
## ports. Positions come from Progression.WORLD.
## Patch 4.0.3 item 7: and Point Nemo, out in the big empty ocean.
const GAME_PORTS: Array[PackedScene] = [preload("res://features/ports/cinder_point.tscn"), preload("res://features/ports/gannet_light.tscn"), preload("res://features/ports/north_pole.tscn"), preload("res://features/ports/south_pole.tscn"), preload("res://features/ports/point_nemo.tscn")]
const Heavy = preload("res://features/handling/heavy_lifter.gd")
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
const TOON_BRIDGE = preload("res://features/toon/toon_bridge.gd")
const SKY_LOOK = preload("res://features/sky/sky_look.gd")
const POLAR_BIOME = preload("res://features/sky/polar_biome.gd")
const DAY_NIGHT = preload("res://features/sky/day_night.gd")
const POLAR_ICE = preload("res://features/toon/polar_ice.gd")
const DESERT_BIOME = preload("res://features/sky/desert_biome.gd")
const DESERT_LOOK = preload("res://features/toon/desert_look.gd")
const TROPICAL_BIOME = preload("res://features/sky/tropical_biome.gd")
const TROPICAL_LOOK = preload("res://features/toon/tropical_look.gd")
const RAIN_BIOME = preload("res://features/sky/rain_biome.gd")
const CITY_LOOK = preload("res://features/toon/city_look.gd")
const VOLCANO_LOOK = preload("res://features/toon/volcano_look.gd")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const DISPLAY = preload("res://features/ui/display_fonts.gd")
## Patch 3.0 item 1: explicit runtime roles; ordinary/debug play remains local.
## The server's player contexts share one physical world, never duplicate ports.
var runtime_role: String = "local"
var shared_world: Node3D
var owner_id: int = 1
var network_runtime: Node
var other_ships: Array[Dictionary] = []
var network_crane_remaining: int = 0

func network_action(kind: String, value: String = "") -> bool:
	if runtime_role != "client": return false
	if is_instance_valid(network_runtime): network_runtime.send_gameplay(kind, value)
	return true

@export var save_enabled: bool = true
@export var save_path: String = "user://worlds/private_port_voyage/voyage.db"
## True in features/game/game.tscn: the real game (REBUILD_PLAN.md M1). False: Port Test.
@export var game_mode: bool = false
var persistence: Node
## Patch 2.7 item 4: the fade back to the main menu has started.
var leaving: bool = false
var world_ports: Array[Node3D] = []
var port: Node3D
var ship: HandlingShip
var controls: PlayerControls
var helm: ShipHelm
## Patch 2.0: the game's Esc menu (Resume, Settings, Main Menu, Quit). Null in test scenes.
var game_menu: CanvasLayer
## Patch 2.2 item 4: the full-screen boat hangar behind SHIPS.
var hangar: CanvasLayer
## Patch 2.4 item 7: the big 3D globe map behind M. The game only.
var globe_map: CanvasLayer
var camera: OrbitCameraRig
var ocean: OceanPresentation
var wake: ShipWake
var docking = preload("res://features/ports/docking_authority.gd").new()
var loading = preload("res://features/cargo/port_loading.gd").new()
## Patch 2.4 item 4, the game only: mooring lines on the docked ship.
var mooring: Node3D
## Patch 2.4 item 5, the game only: quay cranes move containers one at a time.
var cranes: Node3D
## Patch 2.5 item 2: the bridges over the straits, under one node.
var bridges: Node3D
## Patch 2.5 item 3: the North Pole biome (game only).
var polar: Node
## Patch 3.1: the day/night cycle (game only).
var day_night: Node
## Patch 2.5 item 4: the desert biome, painted over the polar look (game only).
var desert: Node
## Patch 2.5 item 5: the tropical biome, painted over the polar and desert looks
## (game only), and the shared paint of its lagoon rings.
var tropical: Node
var lagoon_paint: ShaderMaterial
## Patch 2.5 item 6: the rainy city biome, painted over the others (game only),
## and the shared wall paint of its lit windows.
var rain: Node
## Patch 2.5 item 7: the volcano on Ember Isle (game only).
var volcano: Node3D
var city_paint: Array[ShaderMaterial] = []
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
## Patch 4.0.3 item 4: the heavy lifter's platform button (Lift / Drop).
var lift_button: Button
var cancel_pickup_button: Button
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
## Patch 2.9.1 item 6, the game only: the polar ice cap (POLAR_ICE), in chunks.
var polar_ice: Node3D
## Patch 2.3 debug: the temporary debug layer (features/debug). Null in a normal game.
const DEBUG_GAME = preload("res://features/debug/debug_game.gd")
var debug: CanvasLayer
## Patch 4.0 item 5: the captain's XP (Levels). Server-owned online: only the
## server's player simulation adds to it (award_delivery); clients show it.
const Levels = preload("res://features/game/levels.gd")
var xp: int = 0
## Patch 4.0 items 8-13: the captain's planes and flights (the game only).
const AVIATION = preload("res://features/planes/aviation.gd")
var aviation: Node

## Patch 4.0 item 5: XP for a completed delivery that paid `pay_minor`. The
## authority only (server simulation, local play); a client view never awards.
func award_delivery(pay_minor: int) -> int:
	if runtime_role == "client" or not game_mode: return 0
	var gained: int = Levels.xp_for_pay(pay_minor)
	xp = Levels.award(xp, gained, "delivery")
	return gained

func flying() -> bool:
	return is_instance_valid(aviation) and aviation.flying()

func play_sound(kind: String) -> void:
	if sfx.has(kind): sfx[kind].play()

func button(parent: Node, title: String, action: Callable) -> Button:
	var node: Button = Button.new()
	node.text = title
	# Sailing HUD actions must never retain keyboard focus (including Tab/cancelled clicks).
	node.focus_mode = Control.FOCUS_NONE
	# Patch 3.2: every game button shares one plain UI font, size and casing.
	if game_mode: DISPLAY.style_button(node)
	parent.add_child(node)
	node.pressed.connect(func():
		if runtime_role in ["server", "world"]: return
		if is_instance_valid(persistence) and not persistence.ready_to_save and title != "Main menu": return
		node.release_focus()
		action.call()
		controls.wait_for_release = true)
	return node

func _ready() -> void:
	if runtime_role != "local": save_enabled = false
	if runtime_role == "server":
		# Simulation-only player: no per-player world, menus, camera or audio.
		world_ports = shared_world.world_ports
		add_child(docking)
		add_child(loading)
		offers._offers.clear()
		offers.restock()
		voyage_hud.free()
		minimap.free()
		select_port(0)
		aviation = AVIATION.new()
		aviation.name = "Aviation"
		aviation.view = self
		add_child(aviation)
		return
	# A check may point the game at an isolated save. Players never set this.
	if game_mode: save_path = str(get_tree().get_meta("game_save_path", save_path))
	# Patch 2.3 debug: a throwaway world. No persistence, so no save is opened.
	if runtime_role == "local" and game_mode and DEBUG_GAME.active(get_tree()): save_enabled = false
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
	if game_mode:
		polar = POLAR_BIOME.new()
		polar.name = "PolarBiome"
		add_child(polar)
		polar.setup(environment.environment, light, ocean, camera.camera)
		desert = DESERT_BIOME.new()
		desert.name = "DesertBiome"
		add_child(desert)
		desert.setup(polar)
		tropical = TROPICAL_BIOME.new()
		tropical.name = "TropicalBiome"
		add_child(tropical)
		tropical.setup(polar)
		rain = RAIN_BIOME.new()
		rain.name = "RainBiome"
		add_child(rain)
		rain.setup(polar)
		city_paint = CITY_LOOK.window_materials()
		rain.windows = city_paint
		# Patch 3.1: day, sunset and night, painted last over every biome.
		day_night = DAY_NIGHT.new()
		day_night.name = "DayNight"
		add_child(day_night)
		day_night.setup(polar)
	var scenes: Array = PORTS.duplicate()
	if game_mode:
		scenes.append_array(GAME_PORTS)
		add_natural_land()
		var port_spots: Array[Vector2] = []
		for place: Dictionary in Progression.WORLD: port_spots.append(Vector2(place.at.x, place.at.z))
		var desert_land: Node3D = DESERT_LOOK.build_land(Progression.LAND, port_spots)
		if desert_land != null: add_child(desert_land)
		var tropical_land: Node3D = TROPICAL_LOOK.build_land(Progression.LAND, port_spots)
		if tropical_land != null: add_child(tropical_land)
		lagoon_paint = TROPICAL_LOOK.lagoon_material()
		var lagoons: Node3D = TROPICAL_LOOK.build_lagoons(Progression.LAND, lagoon_paint)
		if lagoons != null: add_child(lagoons)
		var city_land: Node3D = CITY_LOOK.build_land(Progression.LAND, port_spots, city_paint)
		if city_land != null: add_child(city_land)
		volcano = VOLCANO_LOOK.new()
		add_child(volcano)
		# Patch 2.9.1 item 6: the polar ice cap, where the square shelves were.
		var polar_ports: Array[Vector2] = []
		for place: Dictionary in Progression.WORLD:
			if String(place.id).ends_with("_pole"): polar_ports.append(Vector2(place.at.x, place.at.z))
		polar_ice = POLAR_ICE.build(polar_ports, surf_paint)
		add_child(polar_ice)
		for index: int in Progression.ICEBERGS.size(): add_iceberg(index)
		bridges = Node3D.new()
		bridges.name = "Bridges"
		add_child(bridges)
		for index: int in Progression.BRIDGES.size(): bridges.add_child(TOON_BRIDGE.build(index))
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
		# Patch 2.9 item 6B: the quay faces the side the seed gave the port.
		place.quay_side = -int(Progression.WORLD[i].drop_side)
		add_child(place)
		world_ports.append(place)
		# Aesthetics 4: chunky port dressing. The game only; test scenes keep the blocks.
		if game_mode: CHUNKY_LOOK.dress_port(place)
		if game_mode and DESERT_BIOME.weight(place.position) >= 0.5: DESERT_LOOK.dress_port(place)
		if game_mode and TROPICAL_BIOME.weight(place.position) >= 0.5: TROPICAL_LOOK.dress_port(place)
		if game_mode and RAIN_BIOME.weight(place.position) >= 0.5: CITY_LOOK.dress_port(place, city_paint, Progression.LAND)
		if cranes != null: cranes.add_port(place)
	# Aesthetics 2: toon shading and ink outlines on the ports and land.
	TOON_LOOK.apply(self)
	if game_mode:
		var horizon_paints: Dictionary = {}
		for place: Node3D in world_ports: TOON_LOOK.port_horizon(place, horizon_paints)
		if has_node("CityLand"): TOON_LOOK.port_horizon(get_node("CityLand"), horizon_paints)
		# Rain keeps driving the same window materials now used by the skyline.
		for index: int in city_paint.size():
			city_paint[index] = horizon_paints.get(city_paint[index], city_paint[index])
	if runtime_role == "world": return
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
		if network_action("dock"): return
		if docking.state(owner_id) == "docked": docking.request_undock(owner_id); jobs_panel.hide()
		else: offer_notice = docking.request_dock(owner_id, service_id(), cargo_id()).message)
	cancel_button = button(buttons, "Cancel", func():
		if not network_action("cancel_dock"): docking.cancel(owner_id))
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
		# Patch 2.4 item 7: M opens the big globe map over the running world.
		globe_map = preload("res://features/game/globe_map.gd").new()
		globe_map.view = self
		add_child(globe_map)
		controls.command_requested.connect(func(action: StringName) -> void:
			if action == &"map_toggle": globe_map.toggle()
			# Patch 4.0.2 item 6: while flying, G is the landing gear (Aviation.on_command).
			if action == &"cannon_salute" and runtime_role == "local" and not flying(): fire_salute()
			# Patch 4.0.2: Shift fires the Jetty's blaster boost (online: dedicated_runtime).
			if action == PlayerControls.BOOST_COMMAND and runtime_role == "local": fire_boost())
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
		button(tabs, "Ships", func(): ships_panel.hide(); hangar.open())
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
			if not Progression.buyable(kind): continue
			var row: HBoxContainer = HBoxContainer.new()
			ships_panel.add_child(row)
			ship_buttons[kind] = [button(row, "", ship_action.bind(kind)), button(row, "", sell_ship.bind(kind))]
	loading_text = Label.new()
	stack.add_child(loading_text)
	receipt_label = Label.new()
	stack.add_child(receipt_label)
	heavy_controls = HBoxContainer.new()
	stack.add_child(heavy_controls)
	# Patch 4.0.3 item 4: one platform button, Drop (lower the deck) or Lift
	# (raise it), shown whenever a heavy lifter is docked or on a job. Online
	# it sends the same "lower" / "raise" actions as before.
	lift_button = button(heavy_controls, "Drop", lift_or_drop)
	cancel_pickup_button = button(heavy_controls, "Cancel pickup", func(): end_current_job(false))
	if game_mode:
		game_hud = preload("res://features/game/game_hud.gd").new()
		layer.add_child(game_hud)
		game_hud.setup(self)
	select_port(0)
	if game_mode:
		aviation = AVIATION.new()
		aviation.name = "Aviation"
		aviation.view = self
		add_child(aviation)
		aviation.setup_presentation()
	if game_mode and runtime_role != "server":
		var ambience: Node = preload("res://features/audio/game_ambience.gd").new()
		ambience.name = "GameAmbience"
		ambience.view = self
		add_child(ambience)
		var music: Node = preload("res://features/audio/game_music.gd").new()
		music.name = "GameMusic"
		music.view = self
		add_child(music)
	if runtime_role == "local" and game_mode and DEBUG_GAME.active(get_tree()):
		debug = DEBUG_GAME.new()
		debug.view = self
		add_child(debug)
	if save_enabled and not OS.get_cmdline_user_args().has("--ports-check") and not OS.get_cmdline_user_args().has("--voyage-check"):
		persistence = preload("res://features/cargo/voyage_persistence.gd").new()
		add_child(persistence)
		get_tree().auto_accept_quit = false

## Patch 2.9.1 item 4: the pirate ships' broadside. Looks and sound only; ships
## without guns do nothing. False when nothing fired (no guns, or cooling down).
## Patch 4.0.2: the Jetty's Shift blaster boost. False when not on the Jetty,
## flying, docked, the helm is not free or the blaster is charging or cooling.
## Patch 4.0.3 item 4: "Drop" while the deck is up (or rising), "Lift" while
## it is down (or lowering).
func lift_label() -> String:
	if not is_instance_valid(ship) or not ship.has_method("request_height"): return "Drop"
	return "Drop" if float(ship.get("deck_target")) > 0.0 else "Lift"

## Patch 4.0.3 item 4: the platform button. Online: the existing "lower" /
## "raise" gameplay actions (the server moves the deck).
func lift_or_drop() -> bool:
	if not is_instance_valid(ship) or not ship.has_method("request_height"): return false
	var drop: bool = lift_label() == "Drop"
	if network_action("lower" if drop else "raise"): return true
	return ship.request_height(Heavy.LOWERED if drop else Heavy.RAISED)

func fire_boost() -> bool:
	if not is_instance_valid(ship) or flying(): return false
	return ship.request_boost()

func fire_salute() -> bool:
	if not is_instance_valid(ship): return false
	var cannons: Node = ship.find_child("Cannons", true, false)
	var fired: bool = cannons != null and cannons.has_method("fire") and cannons.fire()
	if fired and game_mode and is_instance_valid(game_hud): game_hud.show_salute()
	return fired

## M4 coastline: a solid sand slab level with the quays, with a green block on top.
## Land is sand with a green top; an ice shelf (polar ports) is pale ice with snow.
## Patch 2.5 item 1: the blocks of a landmass share their materials (so the toon
## pass makes few shaders, not one per block) and only sides that face the sea
## get a coast, so a continent has no seams across it. Land past the camera's
## far plane (3 km) is culled.
## Part B: toon coasts (TOON_COAST): a sloped beach, a green hill, surf at the
## waterline and a harbour wall by each port. The SHORE box is unchanged.
var land_paint: Dictionary = {}
var surf_paint: ShaderMaterial
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
	# Patch 2.5 item 4: desert blocks keep the beach but get a dry sand top.
	# Item 5: tropical blocks get a lush green one. Item 6: city blocks a wet dark one.
	var top_key: String = "ice1" if ice else ("desert1" if DESERT_LOOK.is_desert(rect) else ("tropic1" if TROPICAL_LOOK.is_tropical(rect) else ("city1" if CITY_LOOK.is_city(rect) else "land1")))
	for key: String in ["ice0" if ice else "land0", top_key]:
		if not land_paint.has(key):
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_color = {"ice0": Color("bfe3ef"), "ice1": Color("f7fbfd"), "land0": Color("e0cc93"), "land1": Color("7fa368"), "desert1": DESERT_LOOK.SAND_TOP, "tropic1": TROPICAL_LOOK.LUSH_TOP, "city1": CITY_LOOK.WET_TOP}[key]
			material.roughness = 0.9
			land_paint[key] = material
	var ports: Array[Vector2] = []
	for place: Dictionary in Progression.WORLD: ports.append(Vector2(place.at.x, place.at.z))
	var sea: Array[bool] = TOON_COAST.sea_sides(rect, Progression.ICE_SHELVES if ice else Progression.LAND)
	var harbour: Array[bool] = TOON_COAST.harbour_sides(rect, ports)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "Coast"
	mesh.mesh = TOON_COAST.land_mesh(rect, sea, harbour, ice, land_paint[("ice" if ice else "land") + "0"], land_paint[top_key])
	mesh.position.y = 2
	body.add_child(mesh)
	var surf: ArrayMesh = TOON_COAST.surf_mesh(rect, sea, harbour)
	if surf == null: return
	if surf_paint == null: surf_paint = TOON_COAST.surf_material()
	var foam: MeshInstance3D = MeshInstance3D.new()
	foam.name = "Surf"
	foam.mesh = surf
	foam.material_override = surf_paint
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Cheap distance cull: far surf is a few pixels wide.
	foam.visibility_range_end = TOON_COAST.SURF_RANGE_M
	foam.position.y = 2
	body.add_child(foam)

## Patch 2.9 item 6A: the natural land from the seed. One solid body per
## landmass, its blocks (Progression.LAND) as boxes like the old land, and the
## toon coast in 1 km chunks (TOON_COAST.natural_chunk), each culled past
## LAND_RANGE_M and its surf past SURF_RANGE_M, so far land costs nothing.
var natural_land: Node3D
## Patch 4.0.3 item 7: Point Nemo's islets (collision and coast).
var nemo_root: Node3D
## Point Nemo's middle, the point its copies are placed by.
const NEMO_ANCHOR: Vector3 = Vector3(6400, 0, -1300)
func add_natural_land() -> void:
	for mass: Array in Progression.LANDMASSES:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Land" + String(mass[0]).to_pascal_case()
		body.position = Vector3(0, -2, 0)
		body.collision_layer = CollisionRules.SHORE
		body.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
		add_child(body)
		for index: int in range(mass[1], mass[2]):
			var rect: Rect2 = Progression.LAND[index]
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = Vector3(rect.size.x, 12, rect.size.y)
			var collider: CollisionShape3D = CollisionShape3D.new()
			collider.shape = shape
			collider.position = Vector3(rect.get_center().x, 0, rect.get_center().y)
			body.add_child(collider)
	# Patch 4.0.3 item 7: Point Nemo's islets, solid the same way, under one
	# "PointNemo" root that (like the icebergs) sits at its copy nearest the
	# ship (place_nemo): it lies near the world's east-west edge.
	nemo_root = Node3D.new()
	nemo_root.name = "PointNemo"
	add_child(nemo_root)
	if not Progression.NEMO_LAND.is_empty():
		var nemo_body: StaticBody3D = StaticBody3D.new()
		nemo_body.name = "LandPointNemo"
		nemo_body.position = Vector3(0, -2, 0)
		nemo_body.collision_layer = CollisionRules.SHORE
		nemo_body.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
		nemo_root.add_child(nemo_body)
		for rect: Rect2 in Progression.NEMO_LAND:
			var nemo_shape: BoxShape3D = BoxShape3D.new()
			nemo_shape.size = Vector3(rect.size.x, 12, rect.size.y)
			var nemo_collider: CollisionShape3D = CollisionShape3D.new()
			nemo_collider.shape = nemo_shape
			nemo_collider.position = Vector3(rect.get_center().x, 0, rect.get_center().y)
			nemo_body.add_child(nemo_collider)
	for key: String in ["land0", "land1", "desert1", "tropic1", "city1"]:
		if land_paint.has(key): continue
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = {"land0": Color("e0cc93"), "land1": Color("7fa368"), "desert1": DESERT_LOOK.SAND_TOP, "tropic1": TROPICAL_LOOK.LUSH_TOP, "city1": CITY_LOOK.WET_TOP}[key]
		material.roughness = 0.9
		land_paint[key] = material
	if surf_paint == null: surf_paint = TOON_COAST.surf_material()
	var ports: Array[Vector2] = []
	for place: Dictionary in Progression.WORLD: ports.append(Vector2(place.at.x, place.at.z))
	# Hill tops take their biome's colour, as the old blocks did.
	var top_paint: Callable = func(at: Vector2) -> Material:
		var spot: Rect2 = Rect2(at - Vector2(1, 1), Vector2(2, 2))
		return land_paint["desert1" if DESERT_LOOK.is_desert(spot) else ("tropic1" if TROPICAL_LOOK.is_tropical(spot) else ("city1" if CITY_LOOK.is_city(spot) else "land1"))]
	# The sea-lane links are worked out now, at load, not on the first course
	# the minimap asks for mid-voyage (hundreds of blocks to test).
	Progression.sea_route(Progression.gate(0), Progression.gate(1))
	natural_land = Node3D.new()
	natural_land.name = "NaturalLand"
	add_child(natural_land)
	# Patch 4.0.3 item 7: the natural land's chunks, then Point Nemo's ("Nemo").
	for grid: Dictionary in Progression.land_grids():
		add_land_chunks(grid, ports, top_paint, "" if grid == Progression.natural_land() else "Nemo")

## The toon coast of one land grid in 1 km chunks (names prefixed `tag`;
## Point Nemo's go under its root).
func add_land_chunks(grid: Dictionary, ports: Array[Vector2], top_paint: Callable, tag: String) -> void:
	var holder: Node3D = nemo_root if not tag.is_empty() and nemo_root != null else natural_land
	var chunks: Vector2i = Vector2i(ceili((grid.count.x - 1) / float(TOON_COAST.CHUNK_CELLS)), ceili((grid.count.y - 1) / float(TOON_COAST.CHUNK_CELLS)))
	for cj: int in chunks.y:
		for ci: int in chunks.x:
			var part: Dictionary = TOON_COAST.natural_chunk(ci, cj, ports, land_paint.land0, top_paint, grid)
			if part.coast != null:
				var coast: MeshInstance3D = MeshInstance3D.new()
				coast.name = "%sCoast%d_%d" % [tag, ci, cj]
				coast.mesh = part.coast
				coast.visibility_range_end = TOON_COAST.LAND_RANGE_M
				holder.add_child(coast)
			if part.surf != null:
				var foam: MeshInstance3D = MeshInstance3D.new()
				foam.name = "%sSurf%d_%d" % [tag, ci, cj]
				foam.mesh = part.surf
				foam.material_override = surf_paint
				foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				foam.visibility_range_end = TOON_COAST.SURF_RANGE_M
				holder.add_child(foam)

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
## world away from the ship, far out of sight. Patch 2.9.1 item 6: the ice
## cap's chunks follow the ship the same way.
func place_icebergs() -> void:
	if polar_ice != null: POLAR_ICE.place(polar_ice, ship.global_position)
	place_nemo()
	for index: int in icebergs.size():
		var entry: Vector3 = Progression.ICEBERGS[index]
		var at: Vector3 = Progression.nearest(Vector3(entry.x, 0, entry.z), ship.global_position)
		at.y = 0.0
		if icebergs[index].position.distance_to(at) > 1.0: icebergs[index].position = at

## Patch 4.0.3 item 7: Point Nemo lies a few hundred metres from the world's
## east-west edge, so (like the icebergs and the polar ice) its islets and
## its port sit at their copy nearest the ship: a ship that crosses the edge
## beside it still sees it, and touches it. The copy only changes as the
## ship crosses the edge, far from the quay. The server never moves it (its
## ships are always inside the world's edges, where Point Nemo is).
func place_nemo() -> void:
	if nemo_root == null or runtime_role == "server": return
	var shift: Vector3 = Progression.nearest(NEMO_ANCHOR, ship.global_position) - NEMO_ANCHOR
	shift.y = 0.0
	if nemo_root.position.distance_to(shift) > 1.0: nemo_root.position = shift
	var index: int = Progression.port_index("port_point_nemo")
	if index >= 0 and index < world_ports.size():
		var at: Vector3 = Progression.WORLD[index].at + shift
		if world_ports[index].position.distance_to(at) > 1.0: world_ports[index].position = at

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
	if network_action("recover"): return
	var sunk: bool = ship.state.condition <= 0.0
	var fee: int = mini(RECOVERY_FEE_MINOR, reward_minor)
	docking.cancel(owner_id)
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
	if controls != null: controls.wait_for_release = true

## Simplify pass: the game has one status HUD (voyage_hud). The older panel line
## and the gauge panel repeat it, so in the game they need developer mode (F3).
func extras_visible() -> bool:
	return not game_mode or DevMode.enabled

func service_id() -> String:
	return "heavy_transfer" if heavy_mode else "container_transfer"

func cargo_id() -> String:
	# Patch 2.2 item 2: a bulk ship docks for its abstract bulk jobs; no container check.
	# Patch 2.4 item 8: a small boat carries nothing; it docks to refuel and switch.
	if bulk_mode() or small_mode(): return ""
	return "cargo_test_industrial" if heavy_mode else "cargo_test_container"

func ship_key() -> String:
	return "preview_heavy" if heavy_mode else "preview_ship"

func bulk_mode() -> bool:
	return game_mode and Progression.bulk_tier(ship_kind) > 0

## Patch 2.4 item 8: a small boat (no cargo, no jobs).
func small_mode() -> bool:
	return game_mode and Progression.small_tier(ship_kind) > 0

func bulk_destination() -> Node3D:
	return world_ports[int(Progression.bulk_job(bulk_active).destination)]

func deliver_reason() -> String:
	if not bulk_mode(): return delivery.reason(self)
	if bulk_active.is_empty(): return "No loaded job to deliver."
	if docking.state(owner_id) != "docked": return "Dock at the destination first."
	if port != bulk_destination(): return "This cargo belongs at " + bulk_destination().definition.display_name + "."
	return ""

## SHIPS panel, first button: buy a ship, or switch to one already owned.
func ship_action(kind: String) -> void:
	if network_action("ship", kind): return
	if not Progression.SHIPS.has(kind): return
	# Patch 2.3 debug: Select away from a berth swaps on the spot.
	if is_instance_valid(debug) and debug.swap(kind): return
	if kind == ship_kind or docking.state(owner_id) != "docked": return
	var entry: Dictionary = Progression.SHIPS[kind]
	if not fleet.has(kind):
		# Patch 4.0 item 1: a retired boat (the fishing boat) is no longer sold.
		if not Progression.buyable(kind):
			offer_notice = "The %s is no longer sold." % entry.name
			return
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
	if network_action("sell", kind): return
	if kind == ship_kind or not fleet.has(kind) or docking.state(owner_id) != "docked": return
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
	docking.disconnect_owner(owner_id)
	if is_instance_valid(port): port.spawn_allocator.release(spawn_ticket)
	for node: Node in [helm, wake, ship]:
		if is_instance_valid(node): remove_child(node); node.queue_free()
	port = next_port
	ship = next_ship
	if restoring: heavy_jobs.active.clear()
	spawn_ticket = allocation.ticket
	ship.transform = allocation.transform
	add_child(ship)
	if runtime_role == "server":
		ship.validated_impact.connect(take_damage)
		bind_port()
		return true
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
		DISPLAY.plain(helm.notice.label, Color("ff8a7a"))
		PLAYFUL.dress(helm.gauge_display.panel)
	helm.keep_sailing = game_mode
	helm.menu_requested.connect(game_menu.open if game_mode else leave)
	wake = ship.assembly.create_wake(ocean)
	camera.distance_order = ship.definition.camera_distance_m
	camera.set_focus(ship.assembly.focus)
	if controls != null: controls.wait_for_release = true
	return true

## Patch 2.4 item 5: how far the loading timer has got, for the quay cranes:
## (containers of the job reached so far, job quantity), or zero.
func crane_preview(_owner: int) -> Vector2i:
	if not loading.busy(): return Vector2i.ZERO
	var quantity: int = int(offers.view(loading.offer_id).get("quantity", 0))
	return Vector2i(clampi(ceili(loading.progress_percent() / 100.0 * quantity), 0, quantity), quantity)

func cranes_busy() -> bool:
	if runtime_role == "client": return network_crane_remaining > 0
	return cranes != null and cranes.busy(owner_id)

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
		hints.paused = "PAUSED — one moment while the voyage saves or loads.\nStill paused? Press Esc, then Main Menu, and play again."
		hints.switched_off = "SHIP UNAVAILABLE — this voyage could not be loaded.\nPress Esc, then Main Menu, and play again."
	return hints

func bind_port() -> void:
	offer_notice = ""
	docking.disconnect_owner(owner_id)
	docking.register(owner_id, ship, port)
	loading.bind(ship, port, docking, offers, owner_id, "preview_captain", ship_key())
	if runtime_role == "server": return
	jobs_panel.hide()
	ships_panel.hide()
	refresh_jobs()

func refresh_jobs() -> void:
	if jobs_list == null or not is_instance_valid(port): return
	var previous: String = selected_offer
	jobs_list.clear()
	job_cards.clear()
	selected_offer = ""
	if game_mode and runtime_role != "client": offers.restock()
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
	# Patch 2.4 item 8: small boats take no cargo jobs; the board stays empty.
	if small_mode(): rows = []
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
	if docking.state(owner_id) != "docked": return "Dock before accepting a job."
	if loading.busy(): return "Loading in progress — wait or cancel loading."
	if not bulk_active.is_empty() or not heavy_jobs.active.is_empty() or not offers.active_job("preview_captain").is_empty(): return "Finish or cancel your current job before accepting another."
	if small_mode(): return "%s take no cargo jobs. Just enjoy the ride!" % ("Pirate ships" if Progression.PIRATE_KINDS.has(ship_kind) else "Small boats")
	if selected_offer.is_empty(): return "No jobs available here for this ship."
	return ""

func accept_selected() -> void:
	if network_action("accept", selected_offer): return
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
	if network_action("abandon" if abandon else "cancel_load"): return
	var result: Dictionary = preload("res://features/cargo/voyage_lifecycle.gd").end_job(self, abandon)
	offer_notice = result.message
	abandon_job_id = ""
	refresh_jobs()

func request_abandon() -> void:
	if network_action("abandon"): return
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
	if network_action("refuel"): return
	if docking.state(owner_id) != "docked" or loading.busy(): return
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
	if network_action("repair"): return
	if docking.state(owner_id) != "docked" or loading.busy(): return
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
	if network_action("deliver"): return
	if bulk_mode():
		if not deliver_reason().is_empty(): return
		# Pay and job state change together; the autosave writes both on this tick.
		# The job is on offer again at its port: money is never finite.
		var pay_minor: int = Progression.bulk_job(bulk_active).reward_minor
		banked_minor += pay_minor
		bulk_active = ""
		reward_minor += pay_minor
		var gained: int = award_delivery(pay_minor)
		offer_notice = "Delivery complete — paid %.2f credits. +%d XP." % [pay_minor / 100.0, gained]
		play_sound("chime")
		refresh_jobs()
		return
	var before: int = reward_minor
	var result: Dictionary = delivery.deliver(self)
	offer_notice = result.message
	if result.ok:
		var gained: int = award_delivery(reward_minor - before)
		if gained > 0: offer_notice += " +%d XP." % gained
		play_sound("chime")
	refresh_jobs()

func leave() -> void:
	if leaving: return
	if is_instance_valid(persistence) and not persistence.blocked:
		if not persistence.checkpoint(): return
	# Patch 2.7 item 4: fade to the title sea's blue; the main menu then replays
	# the ship's arrival as the fade lifts. Headless checks leave at once.
	if DisplayServer.get_name() != "headless":
		leaving = true
		await ScreenFade.cover(get_tree(), 0.35).covered
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
	if runtime_role == "server": return
	shift_presentation(shift)

## The camera, the wake, the sea pattern and the biome dressings move with a
## jump of the viewer (a seam crossing; Patch 4.0: a plane over a pole).
func shift_presentation(shift: Vector3) -> void:
	if runtime_role == "server": return
	camera.shift(shift)
	wake.shift(shift)
	ocean.shift(shift)
	if polar != null: polar.shift(shift)
	if rain != null: rain.shift(shift)

func _physics_process(delta: float) -> void:
	if runtime_role in ["client", "world"]: return
	if not is_instance_valid(ship): return
	# Patch 4.0: a captain flying a plane; the plane wraps (and crosses the poles) itself.
	if is_instance_valid(aviation): aviation.tick(delta)
	if game_mode:
		if not flying(): wrap_world()
		if runtime_role != "server": place_icebergs()
	offer_time += delta
	offers.advance_to(int(offer_time * 1000))
	if docking.state(owner_id) in ["underway", "approaching"] and not loading.busy() and not flying():
		for other: Node3D in world_ports:
			# Patch 3.1.1: measured to the nearest berth, so arriving at berth 2 or 3 counts.
			if other != port and other.berth_distance(ship.global_position) < 250 and other.berth_distance(ship.global_position) < port.berth_distance(ship.global_position):
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
			var gained: int = award_delivery(int(done.reward_minor))
			offer_notice = "Heavy load delivered — paid %.2f credits. +%d XP." % [done.reward_minor / 100.0, gained]
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
	if runtime_role == "server": return
	# Patch 2.1 item 4: the nearest free berth, or "port full".
	var status: Dictionary = docking.readiness(owner_id, service_id(), cargo_id())
	var current: String = docking.state(owner_id)
	dock_status = status
	# The game always shows Dock beside the throttle, greyed out with no berth in range.
	dock_button.visible = (game_mode and not flying()) or port.berth_distance(ship.global_position) < docking.APPROACH_M or current in ["docking", "docked", "undocking"]
	dock_button.text = "Undock" if current == "docked" else "Dock"
	dock_button.disabled = loading.busy() or cranes_busy() or sink_seconds > 0.0 or not (current == "docked" or (current in ["underway", "approaching"] and status.eligible))
	dock_button.modulate = Color.WHITE if dock_button.disabled else Color("9ee3b1")
	cancel_button.visible = current in ["docking", "undocking"]
	readiness.text = "Berth: " + (current.capitalize() + ("…" if current != "docked" else "") if current in ["docking", "docked", "undocking"] else status.message)
	show_services(current)

## The port services (CARGO, REFUEL, REPAIR, SHIPS and the job cards) show while
## docked. Patch 3.1.1: an online client's view has no physics tick, so _process
## calls this there too; before, a docked online player saw an empty port card.
func show_services(current: String) -> void:
	# The game shows the job cards as soon as the ship is docked, so list them then.
	if game_mode and current == "docked" and not services.visible: refresh_jobs()
	services.visible = current == "docked"
	if is_instance_valid(helm): helm.throttle_display.visible = not services.visible and not game_mode
	if not services.visible: jobs_panel.hide(); ships_panel.hide()

func _process(_delta: float) -> void:
	if runtime_role in ["server", "world"]: return
	if not is_instance_valid(ship): return
	if runtime_role == "client": show_services(docking.state(owner_id))
	voyage_hud.refresh(self)
	# The sea is one 4 km sheet. In the game's larger world it follows the ship.
	if game_mode: RenderingServer.global_shader_parameter_set("port_viewer_world", ship.global_position)
	if game_mode: ocean.global_position = Vector3(snappedf(ship.global_position.x, 50), 0, snappedf(ship.global_position.z, 50))
	if polar != null: polar.update(ship.global_position, _delta)
	if desert != null: desert.update(ship.global_position, _delta)
	if tropical != null: tropical.update(ship.global_position, _delta)
	if rain != null: rain.update(ship.global_position, _delta)
	if day_night != null: day_night.update(_delta)
	if volcano != null: volcano.update(camera.camera.global_position, polar.sun)
	# Patch 2.5 item 1B: the coast surf rides the same swell as the sea.
	if surf_paint != null:
		surf_paint.set_shader_parameter("water_time", ocean.elapsed)
		surf_paint.set_shader_parameter("quality", ocean.quality)
		surf_paint.set_shader_parameter("foam_color", ocean.palette.foam_color)
	if lagoon_paint != null:
		lagoon_paint.set_shader_parameter("water_time", ocean.elapsed)
		lagoon_paint.set_shader_parameter("quality", ocean.quality)
	details.visible = extras_visible()
	if is_instance_valid(helm): helm.gauge_display.visible = extras_visible()
	minimap.queue_redraw()
	details.text = "%s · %s\n%s: %.2f credits" % [port.definition.display_name, "Heavy loader" if heavy_mode else "Container ship", "Wallet" if game_mode else "Voyage wallet", reward_minor / 100.0]
	# The game: the port name is the card's title, so just the ship and the wallet.
	if game_mode: details.text = "%s\nWallet: %.2f credits" % [Progression.SHIPS[ship_kind].name if Progression.SHIPS.has(ship_kind) else "", reward_minor / 100.0]
	switch_button.text = "Test container ship" if heavy_mode else "Test heavy loader"
	switch_button.disabled = not can_switch()
	offer_text.text = "Heavy-loader jobs" if heavy_mode else ("Bulk jobs" if bulk_mode() else "Container jobs")
	refresh_ships()
	accept_button.tooltip_text = accept_reason()
	accept_button.disabled = not accept_button.tooltip_text.is_empty()
	refuel_button.text = "Refuel" if game_mode else "REFUEL"
	repair_button.text = "Repair" if game_mode else "REPAIR"
	if game_mode:
		# The price of what the button will buy right now (Patch 3.2: "Refuel  4.10").
		if fuel_offered() >= 1.0: refuel_button.text = "Refuel  %.2f" % (ceili(fuel_offered() * FUEL_MINOR_PER_LITER) / 100.0)
		if repair_offered() > 0: repair_button.text = "Repair  %.2f" % (repair_offered() * REPAIR_MINOR_PER_PERCENT / 100.0)
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
	if game_mode: abandon_button.text = "Confirm Abandon (No Pay)" if abandon_button.text.begins_with("Confirm") else "Abandon Cargo"
	heavy_controls.visible = heavy_mode and (not heavy_jobs.active.is_empty() or docking.state(owner_id) == "docked") and is_instance_valid(ship) and ship.has_method("request_height")
	if heavy_controls.visible:
		lift_button.text = lift_label()
		cancel_pickup_button.visible = not heavy_jobs.active.is_empty()
	if not loading.busy() and offer_notice == "Accepted — loading your cargo.": offer_notice = loading.notice
	if loading.busy(): loading_text.text = "Loading %.0f%% — please wait." % loading.progress_percent()
	elif cranes_busy():
		var remaining: int = network_crane_remaining if runtime_role == "client" else cranes.remaining(owner_id)
		loading_text.text = "The cranes are working: %d container%s to go." % [remaining, "" if remaining == 1 else "s"]
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
		# The game: nothing here. The keys are listed in Esc > CONTROLS.
		if game_mode: navigation.text = ""
	if services.visible and not game_mode: navigation.text += "\nRefuel / repair: " + free_note()
	if is_instance_valid(aviation):
		aviation.present(_delta)
		aviation.refresh_ui()
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
