extends SceneTree
## Patch 4.0.7 headless checks (issue #234). First the scene-free part
## (patch_4_0_7_logic.gd, also run by check_catalog.gd), then the real game
## scene (a debug captain, isolated save):
## - item 4: the Jetty crosses an island from beach to beach under its own
##   power (real physics, real land bodies): it rides up over the hill on the
##   shared terrain, never under the ground, and reaches the water beyond;
##   a speedboat sent the same way is still stopped by the coast; the
##   volcano still blocks the Jetty; docking from land is refused; a save
##   made over land keeps the sea-level pose (and still validates);
## - item 5: the effects run in the game (spray on the water, dust on land);
## - item 2: the planes hangar and the flying plane have the real props;
## - item 1: in the game, D held through the real controls turns a plane at
##   cruise 90 degrees in at most 5 s, holding its altitude within 20 m.
## Run: godot --headless --path . --script res://tools/patch_4_0_7_check.gd
const Logic = preload("res://tools/patch_4_0_7_logic.gd")
const DebugGame = preload("res://features/debug/debug_game.gd")
const JettyLand = preload("res://features/ships/jetty_land.gd")
const SaveSnapshot = preload("res://features/cargo/voyage_snapshot.gd")
const Progression = preload("res://features/game/progression.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const FOLDER: String = "user://patch_4_0_7_check"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("PATCH 4.0.7 FAILED: " + label)
	return condition

func settle(count: int = 3) -> void:
	for frame: int in count:
		await process_frame
		await physics_frame

func wait_for(test: Callable) -> Node:
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and test.call(scene): return scene
	return null

func run() -> void:
	root.size = Vector2i(1280, 720)
	var logic: RefCounted = Logic.new()
	for part: String in Logic.PARTS: logic.call_part(part)
	checks += logic.checks
	for label: String in logic.failures:
		failures.append(label)
		print("PATCH 4.0.7 FAILED: " + label)
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	set_meta("game_save_path", FOLDER + "/voyage.db")
	set_meta(DebugGame.META, true)
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = await wait_for(func(scene: Node) -> bool: return is_instance_valid(scene.get("debug")))
	if not expect(game != null, "a debug game opened"): return finish()
	await settle()
	var crossing: Dictionary = Logic.island_crossing()
	if expect(not crossing.is_empty(), "an island to cross"):
		await jetty_crosses(game, crossing)
		await speedboat_stops(game, crossing)
	await plane_turns(game)
	set_meta(DebugGame.META, false)
	finish()

func undock(game: Node) -> void:
	if game.docking.state(game.owner_id) == "docked":
		game.docking.request_undock(game.owner_id)
		for frame: int in 400:
			await physics_frame
			if game.docking.state(game.owner_id) != "docked" and game.ship.helm_available(): break

func swap_to(game: Node, kind: String) -> bool:
	await undock(game)
	if game.ship_kind != kind: game.debug.swap(kind)
	await settle()
	return game.ship_kind == kind

## Puts the ship at `at`, bow along `dir`, stopped.
func place(game: Node, at: Vector3, dir: Vector3) -> void:
	var ship: HandlingShip = game.ship
	ship.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), Vector3(at.x, JettyLand.ground_height(at), at.z))
	ship.velocity = Vector3.ZERO
	ship.actual_throttle = 0.0
	ship.zero_throttle()
	await settle(2)

## Item 4: beach to beach, with the real hull, land bodies and physics.
func jetty_crosses(game: Node, crossing: Dictionary) -> void:
	if not expect(await swap_to(game, "small_jetty"), "the debug captain sails the Jetty"): return
	var ship: HandlingShip = game.ship
	var dir: Vector3 = crossing.dir
	var from: Vector3 = crossing.from
	var to: Vector3 = crossing.to
	await place(game, from, dir)
	expect(ship.hover_land and not ship.passable_rids.is_empty(), "the Jetty passes over the land bodies (%d)" % ship.passable_rids.size())
	var length: float = from.distance_to(to)
	var top: float = 0.0
	var under: bool = false
	var floated: float = 0.0
	var blocked: String = ""
	var saw_dust: bool = false
	var saw_spray: bool = false
	var fx: Node = ship.find_child("JettyFx", true, false)
	var dock_tried: bool = false
	for frame: int in 60 * 30:
		ship.command_throttle(0.25)
		await physics_frame
		var at: Vector3 = ship.global_position
		var along: float = Vector3(at.x - from.x, 0, at.z - from.z).dot(dir)
		var ground: float = JettyLand.ground_height(at)
		top = maxf(top, at.y)
		if ground > JettyLand.LAND_M:
			under = under or at.y < ground - 0.05
			floated = maxf(floated, at.y - ground)
		if not ship.land_block.is_empty(): blocked = ship.land_block
		if fx != null and frame % 10 == 0:
			saw_dust = saw_dust or (fx.dust.emitting and ground > 1.0)
			saw_spray = saw_spray or (fx.rooster.emitting and ground <= 0.0)
		if not dock_tried and ground > 5.0:
			# Item 4: no docking from land.
			dock_tried = true
			var asked: Dictionary = game.docking.request_dock(game.owner_id, game.service_id(), game.cargo_id())
			expect(not asked.ok and str(asked.message).contains("water"), "docking from land is refused (%s)" % str(asked.message))
			var saved: Dictionary = SaveSnapshot.capture(game)
			expect(at.y > 1.0 and absf(saved.pose.origin.y) < 0.001, "a save over land keeps the sea-level pose (%.1f m up)" % at.y)
			# (The save's own pose rule: a rigid pose on the sea plane.)
			expect(SaveSnapshot.pose_valid(saved.pose), "and its pose still validates")
			var store: Variant = game.get("persistence")
			if store != null and is_instance_valid(store) and store.ready_to_save: expect(store.checkpoint(), "the game saves over land")
		if along > length: break
	var end: Vector3 = ship.global_position
	var past: float = Vector3(end.x - from.x, 0, end.z - from.z).dot(dir)
	expect(blocked.is_empty(), "nothing stopped the Jetty on the way (%s)" % blocked)
	expect(past > length and JettyLand.surface(end) == "water", "the Jetty crossed the island from beach to beach (%.0f of %.0f m, now over %s)" % [past, length, JettyLand.surface(end)])
	expect(top > float(crossing.top) * 0.8, "riding up over its hill (%.1f m, the hill %.1f m)" % [top, float(crossing.top)])
	expect(not under and floated < 6.0, "never under the ground, never far above it (%.1f m at most)" % floated)
	expect(saw_spray and saw_dust, "spray on the water, dust on the land (%s, %s)" % [saw_spray, saw_dust])
	expect(ship.state.condition > 0.99, "and the hull took no knock (%.2f)" % ship.state.condition)
	for frame: int in 120:
		ship.zero_throttle()
		await physics_frame
	expect(absf(ship.global_position.y) < 0.3, "back on the water it settles to the sea (%.2f m)" % ship.global_position.y)
	# The volcano's cone still stops it.
	var volcano: Vector3 = Vector3(Progression.VOLCANO.at.x, 0, Progression.VOLCANO.at.y)
	var foot: Vector3 = volcano + Vector3(float(Progression.VOLCANO.base_m) * 1.6, 0, 0)
	await place(game, foot, Vector3(-1, 0, 0))
	var closest: float = INF
	for frame: int in 60 * 8:
		ship.command_throttle(0.15)
		await physics_frame
		closest = minf(closest, Vector2(ship.global_position.x - volcano.x, ship.global_position.z - volcano.z).length())
	expect(closest > float(Progression.VOLCANO.base_m) * 0.45, "the volcano still blocks it (closest %.0f m from the crater)" % closest)

## Item 4: only the Jetty: a speedboat is still stopped by the coast.
func speedboat_stops(game: Node, crossing: Dictionary) -> void:
	if not expect(await swap_to(game, "small_speedboat"), "the debug captain sails the speedboat"): return
	var ship: HandlingShip = game.ship
	await place(game, crossing.from, crossing.dir)
	var inland: float = 0.0
	for frame: int in 60 * 12:
		ship.command_throttle(1.0)
		await physics_frame
		inland = maxf(inland, JettyLand.ground_height(ship.global_position))
	expect(not ship.hover_land and inland < 4.5 and absf(ship.global_position.y) < 0.01, "a speedboat is stopped by the coast (%.1f m of ground under it at most)" % inland)
	ship.zero_throttle()

## Items 1 and 2 in the game: a plane with real props, turned by D held.
func plane_turns(game: Node) -> void:
	var air: Node = game.aviation
	await swap_to(game, "small_speedboat")
	var docked: bool = false
	for index: int in game.world_ports.size():
		if not game.select_port(index): continue
		await settle()
		game.ship.global_transform = game.port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
		game.ship.velocity = Vector3.ZERO
		await settle()
		var asked: Dictionary = game.docking.request_dock(game.owner_id, game.service_id(), game.cargo_id())
		if not asked.ok: continue
		for frame: int in 400:
			await physics_frame
			if game.docking.state(game.owner_id) == "docked": break
		docked = game.docking.state(game.owner_id) == "docked"
		if docked: break
	if not expect(docked, "the boat docks to switch to a plane"): return
	air.unlock_all()
	air.plane_kind = "plane_turboprop"
	if not expect(air.switch_to_plane() and game.flying(), "the captain switches to the turboprop"): return
	await settle(4)
	var props: Array[Node] = air.plane_node.find_children("Prop*", "", true, false)
	var blades: int = 0
	for hub: Node in props: blades += hub.find_children("Blade*", "", false, false).size()
	expect(props.size() >= 2 and blades == 8, "the flying turboprop has two four-blade props (%d hubs, %d blades)" % [props.size(), blades])
	var m: RefCounted = air.model
	m.on_ground = false
	m.gear_down = false
	m.position = m.position + Vector3(0, 1500, 0)
	m.velocity = m.basis.z * Planes.stall_speed(m.kind) * 2.0
	m.engine = 0.7
	air.lever = 0.7
	air.gear_order = 0.0
	game.controls.window_focused = true
	game.controls.wait_for_release = false
	for frame: int in 60: await physics_frame
	var heading: float = m.heading()
	var start_y: float = m.position.y
	var worst: float = 0.0
	var turned: float = 0.0
	var seconds: float = 0.0
	Input.action_press("ship_steer_right")
	while turned < PI * 0.5 and seconds < 8.0:
		var before: float = m.heading()
		await physics_frame
		seconds += 1.0 / Engine.physics_ticks_per_second
		turned += absf(angle_difference(before, m.heading()))
		worst = maxf(worst, absf(m.position.y - start_y))
	Input.action_release("ship_steer_right")
	expect(seconds <= 5.0 and angle_difference(heading, m.heading()) < 0.0, "in the game, D held turns the plane right 90 degrees in %.2f s (at most 5)" % seconds)
	expect(worst <= 20.0 and not m.crashed, "holding the altitude within %.1f m (at most 20)" % worst)

func finish() -> void:
	if failures.is_empty(): print("PATCH_4_0_7_CHECK_PASS (%d checks)" % checks)
	else: print("PATCH_4_0_7_CHECK_FAIL (%d of %d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
