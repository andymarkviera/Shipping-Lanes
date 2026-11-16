extends SceneTree
## Patch 2.9.1 item 4: the cosmetic cannon salute and the Other boats rules.
## Both pirate ships carry guns that fire a broadside from one reused set of
## puffs and boom players, with a cooldown, splashes only over open water, and
## nothing in the game changed by it. Then the real game scene in debug mode:
## the salute key fires the active pirate ship's guns, a cargo ship has none,
## the ship, fleet and credits are untouched, and the hangar and debug list
## still hold both pirate ships with no cargo jobs.
## Run: godot --headless --path . --script res://tools/cannon_salute_check.gd
const Progression = preload("res://features/game/progression.gd")
const Hangar = preload("res://features/game/boat_hangar.gd")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
const CANNONS = preload("res://features/toon/pirate_cannons.gd")
const DebugGame = preload("res://features/debug/debug_game.gd")
const GUNS: Dictionary = {"small_galleon": 62, "small_brigantine": 18}
const STEP: float = 1.0 / 60.0
var checks: int = 0
var failures: int = 0

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await process_frame
	check_keys()
	for kind: String in Progression.PIRATE_KINDS: check_guns(kind)
	await check_game()
	print("CANNON_SALUTE_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func check_keys() -> void:
	var fresh: InputPreferences = InputPreferences.new()
	expect(fresh.bindings.get("cannon_salute") == KEY_G and fresh.validation_error() == "", "The salute has its own key (G) and the defaults are valid")
	# Settings saved before this patch: every chosen key kept, the new one added.
	var old: Dictionary = fresh.to_data()
	old.bindings.erase("cannon_salute")
	old.bindings["horn"] = KEY_G
	var loaded: InputPreferences = InputPreferences.from_data(old)
	expect(loaded != null and loaded.bindings.horn == KEY_G and loaded.bindings.has("cannon_salute") and loaded.bindings.cannon_salute != KEY_G and loaded.validation_error() == "",
		"Older saved settings load with their keys kept and a free key for the salute")

func check_guns(kind: String) -> void:
	var definition: ShipDefinition = Progression.definition(kind)
	var model: Node3D = CHUNKY_LOOK.model(kind, definition)
	root.add_child(model)
	# Off the land grid: open sea on every side.
	model.global_position = Vector3(-9000.0, 0.0, -9000.0)
	var cannons: Node = model.get_node_or_null("Cannons")
	if not expect(cannons != null and cannons.get_script() == CANNONS, "%s has cannons" % kind): return
	var muzzles: PackedVector3Array = cannons.muzzles
	var left: int = 0
	var outside: bool = true
	for muzzle: Vector3 in muzzles:
		if muzzle.x < 0.0: left += 1
		outside = outside and absf(muzzle.x) > definition.hull_size_m.x * 0.3 and absf(muzzle.z) < definition.hull_size_m.z * 0.5 and muzzle.y > 0.5
	expect(muzzles.size() == GUNS[kind] and left * 2 == muzzles.size() and outside, "%s: %d broadside guns, half a side, muzzles at the hull's sides (got %d)" % [kind, GUNS[kind], muzzles.size()])
	var ordered: bool = true
	for index: int in range(1, cannons.delays.size()): ordered = ordered and cannons.delays[index] >= cannons.delays[index - 1]
	expect(ordered and cannons.delays[0] < 0.1 and cannons.delays[cannons.delays.size() - 1] <= CANNONS.RIPPLE_S + 0.1 and muzzles[0].z > muzzles[muzzles.size() - 1].z, "%s: the broadside ripples from bow to stern in about a second" % kind)
	expect(not cannons.is_processing() and cannons.cloud == null and cannons.get_child_count() == 0, "%s: nothing is built or run before the first salute" % kind)
	expect(cannons.fire() and cannons.is_processing() and cannons.salutes == 1, "%s fires" % kind)
	var made: int = cannons.get_child_count()
	var size: int = cannons.cloud.instance_count
	expect(made == 1 + CANNONS.BOOM_VOICES and size == muzzles.size() * CANNONS.LUMPS_PER_GUN and size <= CANNONS.MAX_LUMPS, "%s: one puff cloud of %d lumps and %d boom players" % [kind, size, CANNONS.BOOM_VOICES])
	expect(not cannons.fire() and cannons.salutes == 1, "%s cannot fire again at once" % kind)
	var most: int = 0
	var playing: bool = false
	var clock: float = 0.0
	while clock < 1.4:
		cannons.advance(STEP)
		clock += STEP
		most = maxi(most, cannons.live)
		for voice: AudioStreamPlayer in cannons.voices: playing = playing or voice.playing
	expect(cannons.shots == muzzles.size() and cannons.splashes == muzzles.size(), "%s: every gun fired once, each with a splash out at sea" % kind)
	expect(most > muzzles.size() * 4 and most <= size and cannons.live > 0, "%s: flashes, smoke and splashes are drawn (%d lumps at most)" % [kind, most])
	expect(playing or DisplayServer.get_name() == "headless" and AudioServer.get_driver_name() == "Dummy", "%s: the booms play" % kind)
	var far: bool = true
	for index: int in size:
		if cannons.lump_kind[index] == CANNONS.SPLASH:
			var reach: float = Vector2(cannons.lump_position[index].x, cannons.lump_position[index].z).distance_to(Vector2(-9000.0, -9000.0))
			far = far and reach > CANNONS.SPLASH_NEAR_M - 30.0 and reach < CANNONS.SPLASH_FAR_M + 80.0
	expect(far, "%s: the splashes fall well clear of the ship" % kind)
	while clock < CANNONS.COOLDOWN_S + 0.2:
		cannons.advance(STEP)
		clock += STEP
	expect(cannons.live == 0 and cannons.ready_to_fire(), "%s: all smoke gone and ready again after %.0f s" % [kind, CANNONS.COOLDOWN_S])
	cannons._process(STEP)
	expect(not cannons.is_processing(), "%s: the guns cost nothing between salutes" % kind)
	expect(cannons.fire() and cannons.get_child_count() == made and cannons.cloud.instance_count == size, "%s: a second salute reuses the same puffs and players" % kind)
	# Beside land: no splash on or near the shore.
	var land: Vector2 = Vector2.INF
	var grid: Dictionary = Progression.natural_land()
	if not grid.is_empty():
		for j: int in grid.count.y:
			for i: int in grid.count.x:
				if land == Vector2.INF and grid.depth[j * grid.count.x + i] > 220.0: land = grid.origin + Vector2(i, j) * grid.cell
	if expect(land != Vector2.INF, "found a spot deep inland for the shore test"):
		model.global_position = Vector3(land.x, 0.0, land.y)
		var before: int = cannons.splashes
		for tick: int in 90: cannons.advance(STEP)
		expect(cannons.shots == muzzles.size() * 2 and cannons.splashes == before, "%s: no splash ever lands on land" % kind)
	model.free()

func key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code as Key
	event.physical_keycode = code as Key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func check_game() -> void:
	root.set_meta(DebugGame.META, true)
	set_meta(DebugGame.META, true)
	var game: Node = load("res://features/game/game.tscn").instantiate()
	root.add_child(game)
	for tick: int in 30: await physics_frame
	for frame: int in 5: await process_frame
	if not expect(game.debug != null and game.hangar != null, "The real game scene runs in debug mode"): return
	expect(Hangar.FAMILIES.has(["Other boats", "small"]) and not str(Hangar.FAMILIES).contains("Small boats") and Hangar.FAMILY_NAMES.small == "Other boats", "The hangar filter is named Other boats (family ID unchanged)")
	for kind: String in Progression.PIRATE_KINDS:
		expect(Hangar.ladder().has(kind) and game.fleet.has(kind) and Hangar.family_of(kind) == "small" and Hangar.capacity_text(kind) == "none, just for fun", "Debug mode owns the %s, in Other boats, with no cargo" % kind)
	expect(not game.fire_salute(), "A cargo ship has no guns: the salute does nothing")
	for kind: String in Progression.PIRATE_KINDS:
		game.hangar.open()
		game.hangar.set_family("small")
		while game.hangar.current() != kind: game.hangar.step(1)
		game.hangar.press_action()
		game.hangar.close()
		for tick: int in 20: await physics_frame
		for frame: int in 5: await process_frame
		if not expect(game.ship_kind == kind, "Debug mode sails the %s" % kind): continue
		expect(game.small_mode() and game.job_cards.is_empty(), "The %s is offered no cargo jobs" % kind)
		var cannons: Node = game.ship.find_child("Cannons", true, false)
		if not expect(cannons != null and cannons.motion != null, "The sailing %s has her guns" % kind): continue
		var ship: HandlingShip = game.ship
		var was: Array = [ship.state.condition if "condition" in ship.state else 0, ship.state.fuel_liters, game.reward_minor, game.fleet.duplicate(true), ship.global_position, ship.velocity, ship.collision_layer, game.get_child_count()]
		expect(game.controls.input_allowed(), "The helm takes keys before the salute")
		var code: int = game.controls.preferences.bindings["cannon_salute"]
		key(code, true)
		await process_frame
		key(code, false)
		await process_frame
		expect(cannons.salutes == 1 and cannons.is_processing(), "The salute key fires the %s's broadside" % kind)
		key(code, true)
		await process_frame
		key(code, false)
		expect(cannons.salutes == 1 and not game.fire_salute(), "The key does nothing during the cooldown")
		var waited: int = 0
		while cannons.next_gun < cannons.muzzles.size() and waited < 100000:
			waited += 1
			await process_frame
		expect(cannons.shots == cannons.muzzles.size(), "Every gun of the %s fired in the game" % kind)
		var now: Array = [ship.state.condition if "condition" in ship.state else 0, ship.state.fuel_liters, game.reward_minor, game.fleet.duplicate(true), ship.global_position, ship.velocity, ship.collision_layer, game.get_child_count()]
		expect(was[0] == now[0] and was[2] == now[2] and was[3] == now[3] and was[6] == now[6] and was[7] == now[7], "Cosmetic: condition, credits, fleet and the world's nodes are unchanged by the %s's salute" % kind)
		expect(was[4].distance_to(now[4]) < 0.5 and now[5].length() < 0.5 and is_equal_approx(was[1], now[1]), "Cosmetic: the %s is not moved and burns no fuel" % kind)
		var bodies: int = 0
		for node: Node in cannons.get_children():
			if node is CollisionObject3D or node is Area3D: bodies += 1
		expect(bodies == 0, "The salute has no collision bodies: nothing can be hit")
	var listed: Array = []
	for row: Node in game.game_menu.controls_grid.get_children():
		if row is Label: listed.append((row as Label).text)
	game.game_menu.open_controls()
	await process_frame
	listed.clear()
	for row: Node in game.game_menu.controls_grid.get_children():
		if row is Label: listed.append((row as Label).text)
	expect(listed.has("Cannon salute (pirate ships)") and listed.has("G"), "The Controls screen lists the salute key")
	game.queue_free()
	await process_frame
