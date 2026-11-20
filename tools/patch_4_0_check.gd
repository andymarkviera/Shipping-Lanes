extends SceneTree
## Patch 4.0 headless checks. First the scene-free ones (patch_4_0_logic.gd:
## boat lineup and fishing-boat refund, levels, airports, plane jobs, flight
## model with a scripted take-off and landing per plane, old saves), then, in
## the real game scene with an isolated save: XP is awarded only by the
## authority (never by an online client), planes are open from level 1
## (Patch 4.0.1: Levels.PLANE_UNLOCK_LEVEL), Switch
## to Plane is refused with a load aboard and moves the captain to the nearest
## airport without one, the low-altitude fine, a crash (cargo lost, repair
## bill charged, respawn at the nearest airport) and Switch to Boat.
## Run: godot --headless --path . --script res://tools/patch_4_0_check.gd
const Logic = preload("res://tools/patch_4_0_logic.gd")
const Levels = preload("res://features/game/levels.gd")
const Airports = preload("res://features/planes/airports.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Progression = preload("res://features/game/progression.gd")
const FOLDER: String = "user://patch_4_0_check"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("PATCH 4.0 FAILED: " + label)
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
	for part: String in ["boats", "levels", "airports", "jobs", "flight", "saves"]: logic.call(part)
	checks += logic.checks
	for label: String in logic.failures:
		failures.append(label)
		print("PATCH 4.0 FAILED: " + label)
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
	expect(game.xp == 0 and air.level() == 1, "a new captain is level 1 with 0 XP")
	# XP: the authority awards it; an online client never does.
	game.runtime_role = "client"
	expect(game.award_delivery(500000) == 0 and game.xp == 0, "an online client cannot award itself XP")
	game.runtime_role = "local"
	expect(game.award_delivery(500000) == Levels.xp_for_pay(500000) and game.xp == Levels.xp_for_pay(500000), "a delivery awards XP by its pay")
	# The level gate (Patch 4.0.1 item 6: open from level 1 for now).
	game.reward_minor += 200000000
	game.xp = 0
	expect(Levels.PLANE_UNLOCK_LEVEL == 1 and air.level() == 1 and air.unlocked(), "planes are open at level 1 (PLANE_UNLOCK_LEVEL)")
	expect(not air.buy_reason("plane_prop").contains("level"), "no level gate on buying (%s)" % air.buy_reason("plane_prop"))
	expect(not air.switch_reason().contains("level"), "no level gate on Switch to Plane (%s)" % air.switch_reason())
	var wallet: int = game.reward_minor
	expect(air.buy("plane_prop") and air.planes.has("plane_prop") and game.reward_minor == wallet - int(Planes.PLANES.plane_prop.price_minor), "a level-1 captain buys the bush prop at a port")
	# Switch to Plane is refused while a load is aboard.
	game.bulk_active = "patch_4_0_check_load"
	expect(not game.can_switch() and air.switch_reason().contains("job"), "Switch to Plane is refused with a load aboard")
	expect(not air.switch_to_plane() and not game.flying(), "a captain with a load stays aboard")
	game.bulk_active = ""
	var from: Vector3 = game.ship.global_position
	expect(air.switch_reason().is_empty(), "Switch to Plane is allowed with no load (%s)" % air.switch_reason())
	if not expect(air.switch_to_plane() and game.flying(), "Switch to Plane takes off from the port"): return finish()
	await settle()
	expect(air.airport == Airports.nearest(from) and air.stopped_at() == air.airport, "the plane waits at the airport nearest the port")
	expect(not game.ship.visible, "the boat is laid up while flying")
	# A plane job, then a crash: cargo lost, bill paid, back at the nearest airport.
	var board: Array[Dictionary] = Jobs.board(air.airport, air.plane_entry())
	expect(not board.is_empty() and air.accept(str(board[0].id)), "a plane job is accepted at the airport")
	var sea: Vector3 = Progression.gate(2)
	air.model.position = Vector3(sea.x, 5.0, sea.z)
	air.model.on_ground = false
	air.model.basis = Basis(Vector3(1, 0, 0), deg_to_rad(25.0))
	air.model.velocity = air.model.basis.z * 50.0
	air.planes.plane_prop.condition = 0.6
	wallet = game.reward_minor
	var expected_home: int = Airports.nearest(air.model.position)
	for frame: int in 30:
		air.tick(1.0 / 30.0)
		if air.crashes > 0: break
	expect(air.crashes == 1, "flying into the sea is a crash")
	expect(air.job_id.is_empty(), "a crash loses the cargo")
	expect(game.reward_minor == wallet - Planes.repair_minor("plane_prop", Planes.CRASH_REPAIR_PERCENT), "a crash charges the repair bill")
	expect(air.flying() and air.airport == expected_home and air.stopped_at() == expected_home, "the plane is back at the nearest airport")
	expect(air.condition() == 1.0, "the bill pays for a rebuilt plane")
	# Low flying away from an airport: the warning, then a fine.
	var open_sea: Vector3 = far_sea()
	var fines: int = air.fines
	wallet = game.reward_minor
	var seconds: float = 0.0
	while seconds < grace_seconds() + 1.0 and air.crashes == 1:
		air.model.position = Vector3(open_sea.x, 90.0, open_sea.z)
		air.model.on_ground = false
		air.model.basis = Basis.IDENTITY
		air.model.velocity = Vector3(0, 0, 45.0)
		air.tick(1.0 / 30.0)
		seconds += 1.0 / 30.0
	expect(air.warning or air.fines > fines, "the low-altitude warning sounds below %d m" % int(air.SAFE_AGL_M))
	expect(air.fines == fines + 1 and game.reward_minor == wallet - air.LOW_FINE_MINOR, "staying low is fined")
	# Back to the boat from the airport.
	air.start_plane(air.airport)
	await settle()
	expect(air.boat_reason().is_empty() and air.switch_to_boat() and not game.flying(), "Switch to Boat at the airport")
	await settle()
	expect(game.ship.visible and game.ship.collision_layer != 0 and is_instance_valid(game.port), "the boat is back in the water at the nearest port")
	expect(game.xp == 0 and air.level() == 1, "the level survives the switches")
	game.leave()
	await wait_for(func(scene: Node) -> bool: return scene.name == "Main")
	finish()

## Docks at the first port that takes the ship (as hangar_check does).
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

func grace_seconds() -> float:
	return float(load("res://features/planes/aviation.gd").LOW_GRACE_S)

func finish() -> void:
	if failures.is_empty(): print("PATCH_4_0_CHECK_PASS (%d checks)" % checks)
	else: print("PATCH_4_0_CHECK_FAIL (%d of %d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

## The port approach (open sea) farthest from every airport.
func far_sea() -> Vector3:
	var best: Vector3 = Progression.gate(0)
	var best_distance: float = -1.0
	for index: int in Progression.WORLD.size():
		var spot: Vector3 = Progression.gate(index)
		var distance: float = Airports.distance_to(Airports.nearest(spot), spot)
		if distance > best_distance:
			best_distance = distance
			best = spot
	return best
