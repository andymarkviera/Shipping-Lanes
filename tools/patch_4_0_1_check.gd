extends SceneTree
## Patch 4.0.1 headless checks (issue #222). First the scene-free ones
## (patch_4_0_1_logic.gd, also run by check_catalog.gd in the Checks job),
## then, in the real game scene with an isolated save: a level-1 captain buys
## and flies a plane; the Fighter jet is bought, flown and offered no jobs; a
## crash keeps the rules (cargo lost, bill charged, the plane parked at the
## nearest airport by the authority at once) while the view stays on the
## wreck for about 4 s with the controls held at idle, then shows the plane
## at the airport; the airport card shows on the airfield.
## Run: godot --headless --path . --script res://tools/patch_4_0_1_check.gd
const Logic = preload("res://tools/patch_4_0_1_logic.gd")
const Levels = preload("res://features/game/levels.gd")
const Airports = preload("res://features/planes/airports.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Progression = preload("res://features/game/progression.gd")
const FOLDER: String = "user://patch_4_0_1_check"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("PATCH 4.0.1 FAILED: " + label)
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
	for part: String in ["version", "auto_level", "sloppy_landing", "crash_view", "fighter", "turbofans", "gate", "airfields", "saves"]: logic.call(part)
	checks += logic.checks
	for label: String in logic.failures:
		failures.append(label)
		print("PATCH 4.0.1 FAILED: " + label)
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
	# Item 6: a level-1 captain buys and flies a plane.
	expect(game.xp == 0 and air.level() == 1 and air.unlocked(), "a new level-1 captain may fly planes")
	game.reward_minor += 400000000
	var wallet: int = game.reward_minor
	expect(air.buy("plane_prop") and game.reward_minor == wallet - int(Planes.PLANES.plane_prop.price_minor), "a level-1 captain buys the bush prop")
	expect(air.buy("plane_fighter") and air.planes.has("plane_fighter"), "and the Fighter jet (3,000,000.00)")
	expect(air.plane_kind == "plane_prop", "the first plane bought is the active one")
	air.refresh_menu()
	expect(not air.menu_rows.plane_fighter.words.text.is_empty() and air.menu_rows.plane_fighter.words.text.contains("no cargo"), "the Planes menu lists the Fighter jet as recreation")
	expect(air.switch_reason().is_empty(), "Switch to Plane is open at level 1 (%s)" % air.switch_reason())
	if not expect(air.switch_to_plane() and game.flying(), "a level-1 captain switches to the plane"): return finish()
	await settle()
	expect(air.stopped_at() == air.airport, "the plane waits on the airfield at %s" % Airports.all()[air.airport].name)
	# It flies: full throttle and a pull lifts it off.
	# (The scripted pilot's inputs go straight to the authority's model, as the
	# server does with a client's; headless there is no keyboard or mouse.)
	for frame: int in 30 * 25:
		air.model.step({"throttle": 1.0, "pitch": 0.5 if air.model.airspeed() > float(Planes.PLANES.plane_prop.rotate_mps) else 0.0}, 1.0 / 30.0)
		air.follow_boat()
		if air.model.crashed or (not air.model.on_ground and air.model.agl_m > 30.0): break
	expect(not air.model.crashed and not air.model.on_ground and air.crashes == 0, "the level-1 captain's plane takes off")
	# A plane job, then a crash: the rules as before, the view on the wreck.
	air.start_plane(air.airport)
	var board: Array[Dictionary] = Jobs.board(air.airport, air.plane_entry())
	expect(not board.is_empty() and air.accept(str(board[0].id)), "a plane job is accepted")
	var sea: Vector3 = Progression.gate(2)
	air.model.position = Vector3(sea.x, 5.0, sea.z)
	air.model.on_ground = false
	air.model.basis = Basis(Vector3(1, 0, 0), deg_to_rad(25.0))
	air.model.velocity = air.model.basis.z * 50.0
	wallet = game.reward_minor
	var home: int = Airports.nearest(air.model.position)
	for frame: int in 30:
		air.tick(1.0 / 30.0)
		if air.crashes > 0: break
	var wreck: Vector3 = air.last_crash_at
	expect(air.crashes == 1 and air.job_id.is_empty() and game.reward_minor == wallet - Planes.repair_minor("plane_prop", Planes.CRASH_REPAIR_PERCENT), "a crash: cargo lost, repair bill charged")
	expect(air.flying() and air.airport == home and Airports.airfield_at(air.model.position) == home, "the authority parks the plane at the nearest airport at once")
	expect(air.in_crash_view() and absf(air.crash_view_left - air.CRASH_VIEW_S) < 0.01, "the view stays on the wreck for %.1f s" % air.CRASH_VIEW_S)
	var explosion: bool = false
	for child: Node in game.get_children(): explosion = explosion or child.name.begins_with("Explosion")
	expect(explosion, "the wreck explodes: fireball, smoke and debris")
	var parked: Vector3 = air.model.position
	var seconds: float = 0.0
	var on_wreck: bool = true
	var hidden: bool = true
	var orbit_start: Vector3 = Vector3.ZERO
	while air.in_crash_view() and seconds < 10.0:
		air.tick(1.0 / 30.0)
		air.present(1.0 / 30.0)
		seconds += 1.0 / 30.0
		if orbit_start == Vector3.ZERO: orbit_start = air.chase.global_position
		if not air.in_crash_view(): break
		on_wreck = on_wreck and Vector2(game.ship.global_position.x - wreck.x, game.ship.global_position.z - wreck.z).length() < 1.0
		hidden = hidden and (not is_instance_valid(air.plane_node) or not air.plane_node.visible)
	expect(absf(seconds - air.CRASH_VIEW_S) < 0.1, "the respawn is shown after about 4 s (%.2f s)" % seconds)
	expect(on_wreck, "meanwhile the world (the laid-up boat, the sea) stays at the wreck")
	expect(hidden, "meanwhile the respawned plane is not shown")
	expect(air.model.position.distance_to(parked) < 0.5 and float(air.order.throttle) == 0.0, "meanwhile the controls are held at idle")
	expect(air.chase.global_position.distance_to(orbit_start) > 5.0, "the crash camera moves round the wreck")
	air.present(1.0 / 30.0)
	expect(Vector2(game.ship.global_position.x - air.model.position.x, game.ship.global_position.z - air.model.position.z).length() < 1.0, "then the view joins the plane at the airport")
	expect(is_instance_valid(air.plane_node) and air.plane_node.visible, "and the plane is shown again")
	# The Fighter jet: active, flies, no jobs.
	expect(air.select("plane_fighter") and air.plane_kind == "plane_fighter", "the Fighter jet is selected at the airport")
	var fighter_board: Array[Dictionary] = Jobs.board(air.airport, air.plane_entry())
	expect(fighter_board.is_empty() and not air.accept_reason("air_%d_%d_pkg_4" % [air.airport, (air.airport + 1) % Airports.count()]).is_empty(), "the Fighter jet takes no jobs")
	air.present(1.0 / 30.0)
	expect(is_instance_valid(air.plane_node) and air.plane_node.find_child("JetFlame", true, false) != null, "the Fighter jet is drawn with its afterburner")
	air.start_plane(air.airport)
	await settle()
	expect(air.switch_to_boat() and not game.flying(), "Switch to Boat at the airport")
	game.leave()
	await wait_for(func(scene: Node) -> bool: return scene.name == "Main")
	finish()

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
	if failures.is_empty(): print("PATCH_4_0_1_CHECK_PASS (%d checks)" % checks)
	else: print("PATCH_4_0_1_CHECK_FAIL (%d of %d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
