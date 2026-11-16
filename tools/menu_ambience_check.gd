extends SceneTree
## Add -- --menu-audio-check to exercise real playback with the headless mixer.
const AMBIENCE = preload("res://features/audio/menu_ambience.gd")
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func advance(node: Node, seconds: float) -> void:
	for frame: int in int(ceil(seconds * 60.0)): node._process(1.0 / 60.0)

func run() -> void:
	var preferences: InputPreferences = InputPreferences.new()
	var legacy: Dictionary = preferences.to_data()
	legacy.erase("ambience_volume")
	check(InputPreferences.from_data(legacy).ambience_volume == 0.7, "Old preferences retain defaults")
	for invalid: Variant in [-1.0, 1.1, NAN, "loud"]:
		var data: Dictionary = preferences.to_data()
		data.ambience_volume = invalid
		check(InputPreferences.from_data(data) == null, "Invalid ambience rejected")
	var main: Node = load("res://features/main/main.tscn").instantiate()
	main.get_node("Controls").preferences_path = "user://ambience_check_preferences.json"
	root.add_child(main)
	await process_frame
	var ambience: Node = main.ambience
	check(ambience == AMBIENCE.acquire(self) and ambience.players.size() == 2, "A fixed pool is reused")
	for stream: AudioStreamWAV in AMBIENCE.STREAMS:
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Mixer must loop without restarts")
		check(is_equal_approx(stream.get_length(), 32.0), "Full 32-second loop imported")
	check(ambience.active and ambience.envelope < 0.2, "Title starts with fade-in")
	advance(ambience, 1.5)
	check(ambience.envelope == 1.0 and (ambience.players[0].playing == ambience.playback_enabled), "Fade-in completes")
	main.navigate("options")
	main.navigate("settings")
	var settings: SettingsPanel = main.get_node("UI/Settings")
	settings.ambience_volume.value = 0.0
	advance(ambience, 0.3)
	check(ambience.active and ambience.players[0].volume_linear == 0.0, "Settings preview mutes ambience")
	settings.close()
	advance(ambience, 0.3)
	check(ambience.gain > 0.0, "Cancel restores saved volume")
	main.navigate("settings")
	settings.ambience_volume.value = 0.25
	settings.save()
	main.controls.load_preferences()
	check(main.controls.preferences.ambience_volume == 0.25, "Volume survives disk reload")
	main.controls.preferences.master_volume = 0.0
	main.controls.apply_preferences()
	check(AudioServer.is_bus_mute(0), "Master mute still applies")
	var pool: Array = ambience.players.duplicate()
	# Simulate leaving the main scene: players survive it, finish the fade, stop.
	main.queue_free()
	await process_frame
	check(not ambience.active and ambience.envelope > 0.0, "Departure fades instead of cutting")
	advance(ambience, 1.5)
	check(not ambience.players[0].playing and not ambience.is_processing(), "Silent pool sleeps during gameplay")
	var returned: Node = load("res://features/main/main.tscn").instantiate()
	returned.get_node("Controls").preferences_path = "user://ambience_check_preferences.json"
	root.add_child(returned)
	await process_frame
	check(returned.ambience == ambience and ambience.players == pool and ambience.active, "Returning reuses players and fades in")
	returned.queue_free()
	await process_frame
	ambience.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	DirAccess.remove_absolute("user://ambience_check_preferences.json")
	print("MENU_AMBIENCE_CHECK %s" % ("passed" if failures == 0 else "failed"))
	quit(1 if failures else 0)
