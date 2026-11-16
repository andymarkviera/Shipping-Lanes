extends SceneTree
## Run with -- --game-audio-check to include mixer playback/culling.
const Ambience = preload("res://features/audio/game_ambience.gd")
const Progression = preload("res://features/game/progression.gd")
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func advance(node: Node, seconds: float) -> void:
	for frame: int in int(seconds * 60): node._process(1.0 / 60.0)

func run() -> void:
	set_meta(preload("res://features/debug/debug_game.gd").META, true)
	var game: Node = load("res://features/game/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var ambience: Node = game.get_node("GameAmbience")
	ambience.set_process(false)
	ambience.view = null
	var pool: Array = ambience.players.duplicate()
	check(pool.size() == 9 and ambience.ports.size() == 6, "Fixed pool and all existing ports")
	for stream: AudioStreamWAV in Ambience.STREAMS:
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and is_equal_approx(stream.get_length(), 32), "Baked streams loop on mixer")
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS, "PCM playback needs no compressed-stream decoding")
	for index: int in 6:
		var at: Vector3 = Progression.WORLD[index].at
		ambience.sample(at, 0)
		var layer: int = [3, 7, 8, 5, 6, 6][index]
		check(ambience.targets[layer] > 0.4, "Port profile " + str(index))
		var original: PackedFloat32Array = ambience.targets.duplicate()
		ambience.sample(at + Vector3(Progression.WRAP_M, 0, -Progression.WRAP_M), 0)
		check(original == ambience.targets, "Port profile survives both wrap axes")
		advance(ambience, 2)
		check(ambience.players[layer].playing == ambience.playback_enabled, "Nearby layer starts")
	var home: Vector3 = Progression.WORLD[0].at
	ambience.sample(home + Vector3(500, 0, 0), 0)
	var near_gain: float = ambience.targets[3]
	ambience.sample(home + Vector3(1000, 0, 0), 0)
	check(ambience.targets[3] > 0 and ambience.targets[3] < near_gain, "Approach attenuates continuously")
	ambience.ports[0].container = false
	ambience.sample(home, 0)
	check(ambience.targets[3] == 0, "Port services control crane/horn layer")
	ambience.ports[0].container = true
	var offshore := Vector3(6000, 0, 0)
	ambience.sample(offshore, 0)
	var calm: float = ambience.targets[2]
	ambience.sample(offshore, 100)
	check(ambience.targets[2] > calm and ambience.targets[2] <= 0.80001, "Wind grows with speed, bounded at 200 kn")
	var ahead: PackedFloat32Array = ambience.targets.duplicate()
	ambience.sample(offshore, -100)
	check(ahead == ambience.targets, "Astern wash/wind depend on speed magnitude")
	advance(ambience, 2)
	for i: int in range(3, 9): check(not ambience.players[i].playing and ambience.levels[i] == 0, "Distant source culled")
	ambience.sample(Progression.WORLD[4].at, 0)
	ambience._process(1.0 / 60)
	check(ambience.levels[6] > 0 and ambience.levels[6] < 0.02, "Teleport fades instead of snapping")
	advance(ambience, 2)
	game.game_menu.settings.open(game.controls)
	var settings: SettingsPanel = game.game_menu.settings
	settings.ambience_volume.value = 0.0
	advance(ambience, 0.5)
	for player: AudioStreamPlayer in pool: check(not player.playing and player.volume_linear == 0, "Live preview mutes and culls")
	settings.close()
	advance(ambience, 0.5)
	check(ambience.gain == game.controls.preferences.ambience_volume, "Cancel restores game volume")
	check(pool == ambience.players and ambience.get_child_count() == 9, "Pool unchanged across travels and mute")
	ambience.view = game
	game.select_port(3)
	ambience.scan_in = 0
	ambience._process(0.2)
	check(ambience.targets[5] > 0, "Replacement ship is followed")
	game.leaving = true
	advance(ambience, 0.3)
	check(ambience.gain == 0, "Main Menu screen fade also fades game audio")
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	check(get_nodes_in_group("game_ambience").is_empty(), "Game exit releases pool")
	print("GAME_AMBIENCE_CHECK_" + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
