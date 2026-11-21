extends SceneTree
## Patch 4.0.6 headless checks (issue #232), in the real game scene with an
## isolated save. First the scene-free parts (patch_4_0_6_logic.gd and
## save_migration_logic.gd, also run by check_catalog.gd), then a real storm:
## - a ship sails into a storm: it is slower than in calm water at the same
##   throttle, its hull wears a little, and never below the floor;
## - the look: the sky darkens (darker at night than by day), rain falls, the
##   swell is bigger, a bolt flashes and its thunder plays after the delay;
## - the globe (M) and the minimap show the storms;
## - a plane flown into the storm meets turbulence.
## Run: godot --headless --path . --script res://tools/patch_4_0_6_check.gd
const Logic = preload("res://tools/patch_4_0_6_logic.gd")
const Migration = preload("res://tools/save_migration_logic.gd")
const Storms = preload("res://features/sky/storms.gd")
const DayNight = preload("res://features/sky/day_night.gd")
const Progression = preload("res://features/game/progression.gd")
const FOLDER: String = "user://patch_4_0_6_check"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("PATCH 4.0.6 FAILED: " + label)
	return condition

func frames(count: int = 3) -> void:
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
	for suite_script: GDScript in [Logic, Migration]:
		var suite: RefCounted = suite_script.new()
		for part: String in suite_script.PARTS: suite.call_part(part)
		checks += suite.checks
		for label: String in suite.failures:
			failures.append(label)
			print("PATCH 4.0.6 FAILED: " + label)
	Storms.configure(Storms.DEFAULT_SEED, true)
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = await wait_for(func(scene: Node) -> bool: return scene.get("persistence") != null and is_instance_valid(scene.persistence) and scene.persistence.ready_to_save)
	if not expect(game != null and is_instance_valid(game.get("storm_look")), "the game opened with its storm look"): return finish()
	await frames()
	await undock(game)
	var stormy: Vector3 = sea_spot(true)
	var calm: Vector3 = sea_spot(false)
	if expect(stormy != Vector3.INF and calm != Vector3.INF, "open sea in a storm and in calm water (%s, %s)" % [stormy, calm]):
		await sail(game, calm, stormy)
		await look(game)
		await globe(game)
		await fly(game, stormy)
	game.leave()
	await wait_for(func(scene: Node) -> bool: return scene.name == "Main")
	await old_saves()
	finish()

## Item 2 in the real game: each generated old local save opens, the voyage
## is restored, and the game's next checkpoint writes the current version.
func old_saves() -> void:
	for kind: String in Migration.LOCAL:
		var old: Dictionary = Migration.local_fixture(kind)
		var path: String = Migration.local_path("game_" + kind)
		if not expect(Migration.write_local(path, old).is_empty(), "old save %s written" % kind): continue
		var expected: Dictionary = old.duplicate(true)
		Migration.Codec.valid(expected)
		set_meta("game_save_path", path)
		change_scene_to_file("res://features/game/game.tscn")
		var game: Node = await wait_for(func(scene: Node) -> bool: return scene.get("persistence") != null and is_instance_valid(scene.persistence) and (scene.persistence.ready_to_save or scene.persistence.blocked))
		if not expect(game != null and game.persistence.ready_to_save and not game.persistence.blocked, "old save %s opens in the game" % kind): continue
		await frames(4)
		var ship: String = str(expected.get("ship", "container"))
		expect(game.ship_kind == ship and game.reward_minor == int(expected.credits), "old save %s: the ship (%s) and the wallet (%d) are restored" % [kind, game.ship_kind, game.reward_minor])
		expect(is_equal_approx(game.ship.state.condition, float(expected.condition)), "old save %s: the hull (%.2f)" % [kind, game.ship.state.condition])
		expect(game.persistence.checkpoint() and game.persistence.store.current.get("version") == 5, "old save %s: the game saves it as version 5" % kind)
		game.leave()
		await wait_for(func(scene: Node) -> bool: return scene.name == "Main")

func open_sea(at: Vector3) -> bool:
	var flat: Vector2 = Vector2(at.x, at.z)
	if Progression.land_depth(flat) > -160.0 or Progression.ice_depth(flat) > -160.0: return false
	for berg: Vector3 in Progression.ICEBERGS:
		if Vector2(Progression.short_way(Vector3(berg.x, 0, berg.z) - at).x, Progression.short_way(Vector3(berg.x, 0, berg.z) - at).z).length() < 300.0: return false
	return true

## Open sea where a storm rages now (stormy) or where it is calm. If no storm
## has open sea in its core this minute, the shared clock is moved on.
func sea_spot(stormy: bool) -> Vector3:
	for minute: int in 60:
		for storm: Dictionary in Storms.cells():
			if stormy and storm.strength < 0.7: continue
			for ring: int in 4:
				for step: int in 12:
					var angle: float = step * TAU / 12.0
					var spot: Vector3 = Progression.wrapped(storm.center + Vector3(sin(angle), 0, cos(angle)) * storm.radius * (0.12 * ring if stormy else 1.6 + 0.3 * ring))
					var strong: float = Storms.intensity_at(spot)
					if not open_sea(spot): continue
					if stormy and strong >= 0.6: return spot
					if not stormy and strong == 0.0 and Storms.shelter(spot) >= 1.0: return spot
		DayNight.clock_offset += 60.0
	return Vector3.INF

func undock(game: Node) -> void:
	if game.docking.state(game.owner_id) == "docked":
		game.docking.request_undock(game.owner_id)
		for frame: int in 400:
			await physics_frame
			if game.docking.state(game.owner_id) != "docked" and game.ship.helm_available(): break

## Full ahead from a stop for a few seconds, at a spot; the speed reached.
func run_at(game: Node, at: Vector3, seconds: float) -> float:
	var ship: HandlingShip = game.ship
	ship.global_position = at
	ship.velocity = Vector3.ZERO
	ship.actual_throttle = 0.0
	ship.command_throttle(1.0)
	await frames(2)
	for frame: int in roundi(seconds * 60.0):
		ship.command_throttle(1.0)
		await physics_frame
	return ship.forward_speed()

func sail(game: Node, calm: Vector3, stormy: Vector3) -> void:
	var ship: HandlingShip = game.ship
	expect(ship.weather, "the game's ship feels the weather")
	ship.state.condition = 1.0
	var calm_speed: float = await run_at(game, calm, 6.0)
	expect(ship.storm == 0.0 and is_equal_approx(ship.state.condition, 1.0), "in calm water: no storm, no wear (%.2f, %.3f)" % [ship.storm, ship.state.condition])
	var storm_speed: float = await run_at(game, stormy, 6.0)
	expect(ship.storm >= 0.5, "out in the storm the ship feels it (%.2f)" % ship.storm)
	expect(storm_speed < calm_speed * 0.9 and storm_speed > 0.5, "the storm slows the ship (%.1f m/s calm, %.1f m/s in the storm)" % [calm_speed, storm_speed])
	expect(ship.state.condition < 1.0 and ship.state.condition > 0.9, "the hull wears a little (%.3f)" % ship.state.condition)
	ship.state.condition = Storms.WEAR_FLOOR + 0.002
	await frames(120)
	expect(ship.state.condition >= Storms.WEAR_FLOOR - 0.0001, "never below the floor (%.3f)" % ship.state.condition)
	expect(game.sink_seconds <= 0.0 and not ship.simulation_paused, "a storm does not sink the ship")
	ship.state.condition = 1.0
	ship.zero_throttle()

func look(game: Node) -> void:
	var view: Node = game.storm_look
	for frame: int in 400:
		await process_frame
		if view.applied > 0.5: break
	expect(view.applied > 0.5, "the storm look fades in round the camera (%.2f)" % view.applied)
	expect(view.rain.emitting and view.rain.amount_ratio > 0.4, "rain falls")
	expect(Storms.swell > 1.5 and float(game.ocean.ocean_material.get_shader_parameter("swell_scale")) > 1.5, "the swell is bigger (%.2f)" % Storms.swell)
	var sky: ShaderMaterial = game.polar.sky_material
	var stormy_noon: Color = sky.get_shader_parameter("top_color")
	# The same storm at night: the hour is painted first, then the storm.
	var live_was: bool = DayNight.live
	var offset_was: float = DayNight.clock_offset
	DayNight.live = true
	var t: float = DayNight.cycle_at(DayNight.world_seconds())
	var night_mid: float = (DayNight.NIGHT_AT + DayNight.DAWN_AT) / 2.0
	DayNight.clock_offset += fposmod(night_mid - t, 1.0) * DayNight.CYCLE_SECONDS
	game.polar.apply(game.polar.applied)
	var stormy_night: Color = sky.get_shader_parameter("top_color")
	DayNight.clock_offset = offset_was
	DayNight.live = live_was
	game.polar.apply(game.polar.applied)
	expect(stormy_noon.get_luminance() < 0.45, "a storm darkens the noon sky (%.2f)" % stormy_noon.get_luminance())
	expect(stormy_night.get_luminance() < stormy_noon.get_luminance() * 0.6, "and at night it is darker still (%.2f)" % stormy_night.get_luminance())
	# A bolt 250 m off: drawn, a flash, then the thunder after the sound's travel.
	var played: int = view.thunder_played
	var ship_at: Vector3 = game.ship.global_position
	view.strike_at(ship_at + Vector3(250, 0, 0), Storms.now(), 250.0)
	await frames(2)
	expect(view.bolt.visible and view.flash_light.visible and view.flash > 0.5, "lightning: a bolt and a flash")
	expect(view.thunder_played == played, "the thunder is not heard at once")
	for frame: int in 240:
		await process_frame
		if view.thunder_played > played: break
	expect(view.thunder_played > played and view.thunder[0].stream is AudioStreamWAV, "then the thunder rolls")
	await frames(30)
	expect(not view.bolt.visible, "the bolt is gone")
	# The seeded lightning reaches the look: a minute of the storm's bolts.
	var seen: int = view.bolts_seen
	view.last_clock = Storms.now() - 4.9
	await frames(2)
	expect(view.bolts_seen >= seen, "the storms' own bolts are drawn (%d)" % (view.bolts_seen - seen))

func globe(game: Node) -> void:
	expect(game.minimap.has_method("draw_storms"), "the minimap draws the storms")
	game.globe_map.open()
	await frames(4)
	var shown: int = 0
	for cloud: MeshInstance3D in game.globe_map.storm_markers:
		if cloud.visible: shown += 1
	var raging: int = 0
	for storm: Dictionary in Storms.cells():
		if storm.strength > 0.02: raging += 1
	expect(shown > 0 and shown == raging, "the globe shows each storm (%d of %d)" % [shown, raging])
	game.globe_map.close()

func fly(game: Node, stormy: Vector3) -> void:
	var air: Node = game.aviation
	game.ship.global_transform = game.port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
	game.ship.velocity = Vector3.ZERO
	game.ship.zero_throttle()
	await frames(2)
	var asked: Dictionary = game.docking.request_dock(game.owner_id, game.service_id(), game.cargo_id())
	for frame: int in 400:
		await physics_frame
		if game.docking.state(game.owner_id) == "docked": break
	if not expect(asked.ok and game.docking.state(game.owner_id) == "docked", "the ship docks to switch to a plane"): return
	air.unlock_all()
	air.plane_kind = "plane_turboprop"
	if not expect(air.switch_to_plane() and game.flying(), "the captain switches to a plane"): return
	await frames(4)
	# Out over the storm at 900 m, cruising (as if flown there).
	var m: RefCounted = air.model
	m.on_ground = false
	m.gear_down = false
	m.position = stormy + Vector3(0, 900, 0)
	m.velocity = m.basis.z * 75.0
	m.engine = 0.8
	air.lever = 0.8
	var most: float = 0.0
	for frame: int in 90:
		await physics_frame
		most = maxf(most, m.turbulence)
	expect(most > 0.3 and not m.crashed, "the plane meets turbulence in the storm (%.2f)" % most)

func finish() -> void:
	if failures.is_empty(): print("PATCH_4_0_6_CHECK_PASS (%d checks)" % checks)
	else: print("PATCH_4_0_6_CHECK_FAIL (%d of %d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
