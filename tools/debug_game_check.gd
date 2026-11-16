extends SceneTree
## Patch 2.3 item 1: the temporary debug game mode. A normal game first writes
## a real save (isolated folder); then a debug session runs in the real game
## scene: no persistence, the DEBUG tag, all 15 ladder ships owned, credits
## topped up, the hangar opens and swaps ships away from a berth (same place),
## quick travel reaches every port (polar included) and the readout shows the
## ship. MAIN MENU ends it, and the real save files are byte-for-byte unchanged.
## Run: godot --headless --path . --script res://tools/debug_game_check.gd

const FOLDER: String = "user://debug_game_check"
const DEFAULT_SAVE: String = "user://worlds/game/voyage.db"
const DebugGame = preload("res://features/debug/debug_game.gd")
const Hangar = preload("res://features/game/boat_hangar.gd")
const Progression = preload("res://features/game/progression.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("DEBUG GAME FAILED: " + label)
	return condition

func settle() -> void:
	for frame: int in 3:
		await process_frame
		await physics_frame

## Every file in the save folder with its MD5.
func fingerprint() -> Dictionary:
	var prints: Dictionary = {}
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir == null: return prints
	for file: String in dir.get_files(): prints[file] = FileAccess.get_md5(FOLDER + "/" + file)
	return prints

func wait_for(test: Callable) -> Node:
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and test.call(scene): return scene
	return null

func run() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	var default_existed: bool = FileAccess.file_exists(DEFAULT_SAVE)
	set_meta("game_save_path", FOLDER + "/voyage.db")
	# 1. A normal game writes the real save.
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = await wait_for(func(scene: Node) -> bool: return scene.get("persistence") != null and is_instance_valid(scene.persistence) and scene.persistence.ready_to_save)
	if not expect(game != null, "normal game opened with its save"): return finish()
	expect(game.debug == null, "normal game has no debug layer")
	game.leave()
	expect(await wait_for(func(scene: Node) -> bool: return scene.name == "Main") != null, "normal game returned to the title")
	var before: Dictionary = fingerprint()
	expect(before.has("voyage.db"), "the real save exists before the debug session")
	# 2. The debug session.
	set_meta(DebugGame.META, true)
	change_scene_to_file("res://features/game/game.tscn")
	game = await wait_for(func(scene: Node) -> bool: return is_instance_valid(scene.get("debug")))
	if not expect(game != null, "debug game opened"): return finish()
	await settle()
	expect(game.persistence == null, "debug world has no persistence (no save opened)")
	expect(game.debug.tag.visible and game.debug.tag.text == "DEBUG", "DEBUG tag shown")
	for kind: String in Hangar.ladder(): expect(game.fleet.has(kind), "owns " + kind)
	expect(Hangar.ladder().size() == 20, "20 ladder ships (small boats and the two pirate ships included)")
	game.reward_minor = 0
	await settle()
	expect(game.reward_minor >= DebugGame.CREDITS_MINOR / 2, "credits topped up")
	expect(game.docking.state(1) == "underway", "starts underway")
	# Hangar anywhere: Select swaps on the spot.
	game.hangar.open()
	expect(game.hangar.is_open(), "hangar opens away from a berth")
	game.hangar.set_family("")
	game.hangar.index = game.hangar.kinds.find("container_5")
	expect(game.hangar.action_reason("container_5").is_empty(), "Select allowed undocked")
	var at: Vector3 = game.ship.global_position
	game.hangar.press_action()
	await settle()
	expect(game.ship_kind == "container_5", "hangar Select swapped to container_5")
	expect(not game.hangar.is_open(), "hangar closed after Select")
	expect(Vector2(game.ship.global_position.x - at.x, game.ship.global_position.z - at.z).length() < 5.0, "swap kept the position")
	# Every ladder ship sails, swapped where it is.
	for kind: String in Hangar.ladder():
		if kind == game.ship_kind: continue
		game.ship_action(kind)
		await settle()
		expect(game.ship_kind == kind and Progression.SHIPS.has(kind), "swapped to " + kind)
		expect(game.debug.readout.text.begins_with(str(Progression.SHIPS[kind].name)) and game.debug.readout.text.contains("kn"), "readout for " + kind)
		if Progression.PIRATE_KINDS.has(kind):
			# Patch 2.9.1 item 3: in the real game the rig is live and the wake is the hull's own.
			var rig: Node = game.ship.find_child("Rig", true, false)
			expect(rig != null and rig.is_processing() and rig.motion == game.ship.assembly.visual and rig.sail_set < 0.5, "living rig, sails furled at rest, on " + kind)
			expect(game.ship.definition.wake_full_speed_mps > 0.0 and is_equal_approx(game.wake.full_speed_mps, game.ship.definition.wake_full_speed_mps), "own wake speed for " + kind)
	expect(DebugGame.seconds_to_full(Progression.definition("container")) > 15.0 and DebugGame.seconds_to_full(Progression.definition("container")) < 25.0, "starter reaches full speed in 15-25 s")
	# Quick travel to every port, with the biggest ship.
	game.ship_action("container_5")
	await settle()
	for index: int in game.world_ports.size():
		game.debug.travel(index)
		await settle()
		var target: Node3D = game.world_ports[index]
		expect(game.port == target and game.ship.global_position.distance_to(target.berth_anchor.global_position) < 1500.0, "quick travel to " + target.definition.display_name)
	expect(game.world_ports.size() == 6, "six ports listed (polar included)")
	# 3. MAIN MENU throws the world away; the real save is unchanged.
	game.leave()
	expect(await wait_for(func(scene: Node) -> bool: return scene.name == "Main") != null, "debug game returned to the title")
	expect(not has_meta(DebugGame.META), "title ended the debug session")
	expect(fingerprint() == before, "real save files unchanged by the debug session")
	expect(FileAccess.file_exists(DEFAULT_SAVE) == default_existed, "default save path untouched")
	finish()

func finish() -> void:
	if failures.is_empty(): print("DEBUG_GAME_CHECK_PASS (%d checks)" % checks)
	else: print("DEBUG_GAME_CHECK_FAIL (%d of %d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
