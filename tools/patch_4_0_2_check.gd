extends SceneTree
## Patch 4.0.2 headless checks (issue #224). First the scene-free ones
## (patch_4_0_2_logic.gd, also run by check_catalog.gd in the Checks job),
## then, in the real game scene with an isolated save: the port card's
## Planes button opens the planes hangar, which lists every plane with its
## price, fuel, speed and capacity, buys one and flies it; the minimap and the
## globe show the plane, not the boat; G toggles the gear in the air only;
## near a runway, low, descending and gear up, the HUD shows "Press G — Gear
## down"; a belly landing bills the repair (no crash, no explosion, the cargo
## kept); then a debug session: the Debug Menu shows the boat controls while
## sailing and the plane controls (picker, spawn, refuel, repair, gear,
## readout) while flying; and the blaster-boosted Jetty stops at a thin wall.
## Run: godot --headless --path . --script res://tools/patch_4_0_2_check.gd
const Logic = preload("res://tools/patch_4_0_2_logic.gd")
const Progression = preload("res://features/game/progression.gd")
const Airports = preload("res://features/planes/airports.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Minimap = preload("res://features/game/globe_minimap.gd")
const DebugGame = preload("res://features/debug/debug_game.gd")
const FOLDER: String = "user://patch_4_0_2_check"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("PATCH 4.0.2 FAILED: " + label)
	return condition

func settle() -> void:
	for frame: int in 3:
		await process_frame
		await physics_frame

func wait_for(test: Callable) -> Node:
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and test.call(scene): return scene
	return null

func run() -> void:
	var logic: RefCounted = Logic.new()
	for part: String in Logic.PARTS: logic.call(part)
	checks += logic.checks
	for label: String in logic.failures:
		failures.append(label)
		print("PATCH 4.0.2 FAILED: " + label)
	await boost_wall()
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = await wait_for(func(scene: Node) -> bool: return scene.get("persistence") != null and is_instance_valid(scene.persistence) and scene.persistence.ready_to_save)
	if not expect(game != null and is_instance_valid(game.get("aviation")), "the game opened with its planes"): return finish()
	await settle()
	var air: Node = game.aviation
	expect(await dock_anywhere(game), "the boat docks at a port")
	expect(Minimap.own_icon(game) == "boat", "sailing, the minimap shows the boat")
	# Item 7: Planes opens the planes hangar.
	game.reward_minor += 400000000
	air.refresh_ui()
	air.port_buttons.planes.pressed.emit()
	await settle()
	var hangar: CanvasLayer = air.hangar
	expect(is_instance_valid(hangar) and hangar.is_open() and not air.menu.visible, "the Planes button opens the planes hangar")
	expect(hangar.title_label.text == "PLANE HANGAR" and hangar.kinds == Planes.ORDER, "it is the plane hangar, with every plane")
	expect(hangar.name_label.get_theme_font("font") == game.hangar.name_label.get_theme_font("font") and hangar.action_button.get_theme_font("font") == game.hangar.action_button.get_theme_font("font"), "in the boat hangar's fonts")
	var shown: Dictionary = {}
	for step: int in Planes.ORDER.size():
		var kind: String = hangar.current()
		shown[kind] = true
		var model: Node3D = hangar.models.get(kind)
		expect(model != null and model.visible and model.is_inside_tree(), "%s turns on the turntable" % kind)
		expect(hangar.stats_label.text.contains("Top speed") and hangar.stats_label.text.contains("Fuel") and hangar.stats_label.text.contains("Carries"), "%s: speed, fuel and capacity shown" % kind)
		expect(hangar.family_label.text.contains("Price"), "%s: the price is shown" % kind)
		hangar.step(1)
	expect(shown.size() == Planes.ORDER.size(), "the arrows cycle through every plane")
	while hangar.current() != "plane_prop": hangar.step(1)
	var wallet: int = game.reward_minor
	hangar.last_action_ms = -100000
	hangar.press_action()
	expect(air.planes.has("plane_prop") and game.reward_minor == wallet - int(Planes.PLANES.plane_prop.price_minor), "Buy in the hangar buys the plane")
	hangar.refresh()
	expect(hangar.name_label.text.contains("ACTIVE") and hangar.sell_button.visible and hangar.sell_button.text == "Fly" and not hangar.sell_button.disabled, "an owned plane offers Fly")
	hangar.last_action_ms = -100000
	hangar.press_fly()
	await settle()
	expect(game.flying() and air.plane_kind == "plane_prop" and not hangar.is_open(), "Fly takes the plane up from the hangar")
	if not game.flying(): return finish()
	# Item 2: the plane on the minimap and the globe.
	expect(Minimap.own_icon(game) == "plane", "flying, the minimap shows a plane")
	var entries: Array[Dictionary] = game.globe_map.ship_entries()
	expect(not entries.is_empty() and entries[0].kind == "plane_prop", "and the globe shows the plane model")
	# Item 6: G in the air only; the gear starts down on the runway.
	expect(air.model.gear_down and not air.toggle_gear() and air.model.gear_down, "on the ground G leaves the gear down")
	var entry: Dictionary = Airports.all()[air.airport]
	var axis: Vector3 = Vector3(sin(entry.heading), 0, cos(entry.heading))
	var near_end: Vector3 = entry.at - axis * float(entry.length) * 0.5
	place(air, near_end - axis * 1500.0 + Vector3(0, 200.0, 0), axis, -4.0)
	air.tick(1.0 / 30.0)
	expect(air.toggle_gear() and float(air.order.gear) == 0.0, "G raises the gear (the lever)")
	air.tick(1.0 / 30.0)
	expect(not air.model.gear_down, "the gear comes up")
	air.refresh_ui()
	expect(air.gear_nudge() and air.nudge_label.visible and air.nudge_label.text == "Press G — Gear down", "near the runway, low, descending, gear up: \"Press G — Gear down\"")
	expect(air.nudge_chimed, "with one chime")
	place(air, near_end - axis * 1500.0 + Vector3(0, 450.0, 0), axis, -4.0)
	air.tick(1.0 / 30.0)
	air.refresh_ui()
	expect(not air.gear_nudge() and not air.nudge_label.visible, "no nudge up high")
	place(air, near_end - axis * 1500.0 + Vector3(0, 200.0, 0), axis, 3.0)
	air.tick(1.0 / 30.0)
	expect(not air.gear_nudge(), "no nudge climbing away")
	expect(air.toggle_gear() and float(air.order.gear) == 1.0, "G lowers the gear")
	air.tick(1.0 / 30.0)
	place(air, near_end - axis * 1500.0 + Vector3(0, 200.0, 0), axis, -4.0)
	air.tick(1.0 / 30.0)
	air.refresh_ui()
	expect(air.model.gear_down and not air.gear_nudge() and not air.nudge_label.visible, "gear down: no nudge")
	# Item 6: a belly landing bills the repair, keeps the cargo, no crash.
	air.start_plane(air.airport)
	var board: Array[Dictionary] = Jobs.board(air.airport, air.plane_entry())
	expect(not board.is_empty() and air.accept(str(board[0].id)), "a plane job is aboard")
	var job: String = air.job_id
	place(air, entry.at - axis * float(entry.length) * 0.3 + Vector3(0, 8.0 + air.model.gear_height_m, 0), axis, -2.0)
	air.model.velocity = axis * Planes.stall_speed(air.plane_kind) * 1.15 + Vector3(0, -2.0, 0)
	air.gear_order = 0.0
	air.order = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "gear": 0.0}
	air.model.gear_down = false
	air.model.gear_lever = 0.0
	wallet = game.reward_minor
	var crashes: int = air.crashes
	for frame: int in 30 * 30:
		air.order = {"throttle": -0.6 if air.model.on_ground else 0.0, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "gear": air.gear_order}
		air.tick(1.0 / 30.0)
		if air.belly_landings > 0 and air.model.airspeed() < 0.5: break
	expect(air.belly_landings == 1 and air.crashes == crashes, "a gear-up landing is a belly landing, not a crash")
	expect(game.reward_minor == wallet - Planes.repair_minor(air.plane_kind, air.BELLY_REPAIR_PERCENT), "it bills the repair (%s credits)" % air.credits(Planes.repair_minor(air.plane_kind, air.BELLY_REPAIR_PERCENT)))
	expect(air.job_id == job and not air.in_crash_view(), "the cargo stays aboard and nothing explodes")
	var explosion: bool = false
	for child: Node in game.get_children(): explosion = explosion or child.name.begins_with("Explosion")
	expect(not explosion, "no explosion")
	expect(air.model.on_ground and air.model.gear_down and air.stopped_at() >= 0, "it stops on the airfield, back on its wheels")
	air.job_id = ""
	await settle()
	expect(air.switch_to_boat() and not game.flying(), "Switch to Boat at the airport")
	game.leave()
	await wait_for(func(scene: Node) -> bool: return scene.name == "Main")
	await debug_session()
	finish()

## Item 8: the debug panel follows the vehicle.
func debug_session() -> void:
	set_meta(DebugGame.META, true)
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = await wait_for(func(scene: Node) -> bool: return is_instance_valid(scene.get("debug")))
	if not expect(game != null, "a debug game opened"):
		set_meta(DebugGame.META, false)
		return
	await settle()
	var debug: CanvasLayer = game.debug
	debug.toggle()
	await settle()
	expect(debug.panel_mode() == "boat" and debug.boat_box.visible and not debug.plane_box.visible, "sailing, the Debug Menu shows the boat controls")
	await jetty_in_game(game, debug)
	expect(await dock_anywhere(game), "the debug boat docks")
	var air: Node = game.aviation
	if not expect(air.switch_to_plane() and game.flying(), "the debug captain flies a plane"):
		set_meta(DebugGame.META, false)
		return
	await settle()
	expect(debug.panel_mode() == "plane" and debug.plane_box.visible and not debug.boat_box.visible, "flying, it shows the plane controls")
	expect(debug.plane_readout.text.contains(" m up") and debug.plane_readout.text.contains("kn") and debug.plane_readout.text.contains("Gear"), "with an altitude, speed and gear readout")
	debug.pick_plane("plane_fighter")
	expect(air.plane_kind == "plane_fighter" and game.flying(), "the plane picker swaps the plane")
	var far: int = (air.airport + 2) % Airports.count()
	debug.spawn_at(far)
	expect(air.airport == far and Airports.airfield_at(air.model.position) == far, "spawn at another airport")
	air.model.fuel_l = 1.0
	debug.plane_refuel()
	expect(is_equal_approx(air.model.fuel_l, float(air.plane_entry().fuel_l)), "refuel fills the tank")
	air.planes[air.plane_kind].condition = 0.4
	debug.plane_repair()
	expect(is_equal_approx(air.condition(), 1.0), "repair restores the condition")
	place(air, Airports.all()[0].at + Vector3(4000, 900, 0), Vector3(0, 0, 1), 0.0)
	air.tick(1.0 / 30.0)
	var was: bool = air.model.gear_down
	debug.plane_gear()
	air.tick(1.0 / 30.0)
	expect(air.model.gear_down != was, "toggle gear works in the air")
	debug.nearest_airport()
	expect(air.model.on_ground and air.stopped_at() == Airports.nearest(air.model.position), "teleport to the nearest airport")
	await settle()
	set_meta(DebugGame.META, false)
	game.leave()
	await wait_for(func(scene: Node) -> bool: return scene.name == "Main")

## Puts the active plane in the air at `at`, flying along `axis`, climbing at `vy`.
func place(air: Node, at: Vector3, axis: Vector3, vy: float) -> void:
	var m: RefCounted = air.model
	m.position = at
	m.basis = Basis(Vector3.UP, atan2(axis.x, axis.z))
	m.velocity = axis * Planes.stall_speed(air.plane_kind) * 1.4 + Vector3(0, vy, 0)
	m.on_ground = false
	m.on_belly = false
	m.climbing_out = false
	m.engine = 0.4
	air.order = {"throttle": 0.4, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "gear": air.gear_order}

## Docks at the first port that takes the ship (as patch_4_0_check does).
func dock_anywhere(game: Node) -> bool:
	for index: int in game.world_ports.size():
		if game.docking.state(game.owner_id) == "docked": return true
		if not game.select_port(index): continue
		await settle()
		game.ship.global_transform = game.port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
		game.ship.velocity = Vector3.ZERO
		await settle()
		var asked: Dictionary = game.docking.request_dock(game.owner_id, game.service_id(), game.cargo_id())
		if not asked.ok: continue
		for frame: int in 400:
			await physics_frame
			if game.docking.state(game.owner_id) == "docked": return true
	return game.docking.state(game.owner_id) == "docked"

func finish() -> void:
	if failures.is_empty(): print("PATCH_4_0_2_CHECK_PASS (%d checks)" % checks)
	else: print("PATCH_4_0_2_CHECK_FAIL (%d of %d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

## Follow-up: the blaster-boosted Jetty (about 823 m/s, 13.7 m a tick) still
## stops at a 0.1 m wall: move_and_slide sweeps the hull, nothing tunnels.
func boost_wall() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = CollisionRules.SHORE
	var plate: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 10, 0.1)
	plate.shape = box
	wall.add_child(plate)
	# (Patch 4.0.7: on open sea. The old spot is on the polar ice cap, where
	# the Jetty now meets the terrain before the wall.)
	wall.position = Vector3(-6000, 0, 1200)
	root.add_child(wall)
	var jet: HandlingShip = HandlingShip.new()
	jet.definition = Progression.definition("small_jetty")
	CollisionRules.add_box_hull(jet, jet.definition.hull_size_m)
	jet.position = Vector3(-6000, 0, 1000)
	root.add_child(jet)
	await physics_frame
	var top: float = jet.definition.forward_acceleration_mps2 / jet.definition.linear_drag_per_second
	jet.command_throttle(1.0)
	jet.actual_throttle = 1.0
	jet.request_boost()
	jet.boost.advance(HandlingShip.JETTY_BOOST.CHARGE_S + 0.3)
	jet.boost_applied = jet.boost.factor()
	jet.velocity = Vector3(0, 0, top * jet.boost_applied)
	var fastest: float = 0.0
	var touched: bool = false
	var front: float = 0.0
	for frame: int in 60:
		await physics_frame
		fastest = maxf(fastest, jet.velocity.length())
		touched = touched or jet.get_slide_collision_count() > 0
		front = maxf(front, jet.position.z + jet.definition.hull_size_m.z * 0.5)
	expect(jet.boost.phase == "blast" and touched, "the boosted Jetty met the thin wall")
	expect(front < 1200.0 - 0.04, "the boosted Jetty did not tunnel through a 0.1 m wall (bow %.2f m short)" % (1200.0 - front))
	jet.free()
	wall.free()

## Follow-up, in the game scene: on the Jetty, the hull hovers with its
## effects, and Shift (through PlayerControls) charges and fires the blaster.
func jetty_in_game(game: Node, debug: CanvasLayer) -> void:
	var previous: String = game.ship_kind
	debug.swap("small_jetty")
	await settle()
	if not expect(game.ship_kind == "small_jetty", "the debug captain sails the Jetty"): return
	var ship: HandlingShip = game.ship
	expect(ship.assembly.visual.hovering() and ship.find_child("JettyFx", true, false) != null, "in the game the Jetty hovers with its effects")
	var heard: Array[StringName] = []
	var listen: Callable = func(action: StringName) -> void: heard.append(action)
	game.controls.command_requested.connect(listen)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.physical_keycode = KEY_SHIFT
	key.pressed = true
	game.controls.wait_for_release = false
	game.controls.window_focused = true
	game.controls._unhandled_input(key)
	game.controls.command_requested.disconnect(listen)
	expect(heard == [PlayerControls.BOOST_COMMAND], "Shift is the blaster command (%s)" % str(heard))
	expect(ship.boost.phase == "charge", "Shift on the Jetty starts the blaster's charge")
	await process_frame
	await process_frame
	expect(game.game_hud.blaster.visible and game.game_hud.blaster.text == "BLASTER CHARGING...", "the HUD says the blaster is charging (%s)" % game.game_hud.blaster.text)
	for frame: int in int((HandlingShip.JETTY_BOOST.CHARGE_S + 0.3) * Engine.physics_ticks_per_second):
		await physics_frame
	await process_frame
	var fx: Node = ship.find_child("JettyFx", true, false)
	expect(ship.boost.phase == "blast" and fx.flame.visible and fx.blasts_heard == 1, "then the blast fires in the game, flame and sound")
	expect(not game.fire_boost(), "Shift again does nothing until the cooldown is over")
	debug.swap(previous)
	await settle()
	expect(game.ship_kind == previous, "and back to the debug boat")
