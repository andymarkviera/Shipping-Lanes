extends SceneTree
## Patch 3.1: the day/night cycle and the time-of-day music, in the real game
## scene. Phase mapping, server clock sync, the look at day/sunset/night (day
## look unchanged at noon), and the music rules: 15 s of sailing, slow fade,
## fade out on a full stop, and fade out, 3 s silence, fade in on a change.
## Isolated save folder.
## Run: godot --headless --path . --script res://tools/day_night_check.gd
const FOLDER: String = "user://day_night_check"
const DayNight = preload("res://features/sky/day_night.gd")
const Music = preload("res://features/audio/game_music.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("DAY_NIGHT FAILED: " + label)
	return condition

## Puts the shared clock at `t` (0..1 through the cycle).
func set_time(t: float) -> void:
	DayNight.clock_offset = 0.0
	DayNight.clock_offset = (t - DayNight.now()) * DayNight.CYCLE_SECONDS

func run() -> void:
	DayNight.live = true
	expect(DayNight.song_at(0.3) == "day" and DayNight.song_at(0.6) == "sunset" and DayNight.song_at(0.8) == "night" and DayNight.song_at(0.95) == "day", "songs follow the time of day")
	expect(DayNight.sun_elevation(0.27) > 50.0 and DayNight.sun_elevation(0.8) < -10.0, "the sun is high at noon and down at night")
	var noon: Vector2 = DayNight.weights(0.3)
	expect(noon.x < 0.01 and noon.y < 0.01, "noon has no sunset or night tint")
	expect(DayNight.weights(0.64).x > 0.4, "the sunset is golden")
	expect(DayNight.weights(0.8).y > 0.99, "night is night")
	var server: float = Time.get_unix_time_from_system() + 777.0
	DayNight.clock_offset = 0.0
	DayNight.sync(server)
	expect(absf(DayNight.world_seconds() - server) < 1.0, "a client follows the server's clock")
	DayNight.sync(server + 0.2)
	expect(absf(DayNight.clock_offset - 777.0) < 0.5, "sub-second jitter is ignored")
	set_time(0.3)
	DayNight.skip_phase()
	expect(DayNight.song_at(DayNight.now()) == "sunset", "debug skip goes to the sunset")
	# Music rules, stepped directly (no playback headless).
	var music: Node = Music.new()
	root.add_child(music)
	music.set_process(false)
	for i: int in 140: music.step(0.1, 5.0, "day")
	expect(music.song.is_empty(), "no music before 15 s of sailing")
	for i: int in 20: music.step(0.1, 5.0, "day")
	expect(music.song == "day" and music.level > 0.0 and music.level < 0.2, "music starts after 15 s and fades in slowly")
	for i: int in 200: music.step(0.1, 5.0, "day")
	expect(is_equal_approx(music.level, 1.0), "the song reaches its quiet level")
	music.step(0.1, 0.0, "day")
	expect(music.song == "day" and music.level > 0.9, "a stop fades, never cuts")
	for i: int in 100: music.step(0.1, 0.0, "day")
	expect(music.song.is_empty() and music.level == 0.0, "a full stop fades music fully out")
	for i: int in 160: music.step(0.1, 5.0, "day")
	for i: int in 200: music.step(0.1, 5.0, "day")
	expect(music.song == "day" and music.level == 1.0, "music returns after 15 s of sailing")
	var heard_sunset: bool = false
	var silent_for: float = 0.0
	var crossfade: bool = false
	for i: int in 80:
		music.step(0.1, 5.0, "sunset")
		crossfade = crossfade or music.song == "sunset"
		if music.song.is_empty(): break
	expect(not crossfade, "no crossfade into the next song")
	expect(music.song.is_empty() and music.gap > 0.0, "a time-of-day change fades to a full stop, then waits")
	for i: int in 60:
		music.step(0.1, 5.0, "sunset")
		if music.song.is_empty(): silent_for += 0.1
		elif not heard_sunset: heard_sunset = true
	expect(heard_sunset and silent_for >= 2.9 and silent_for <= 3.2, "3 s of silence, then the next song (%.1f s)" % silent_for)
	music.free()
	# The real game scene at noon, sunset and night.
	set_time(0.3)
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = null
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and scene.get("persistence") != null and is_instance_valid(scene.persistence) and (scene.persistence.ready_to_save or scene.persistence.blocked):
			game = scene
			break
	if not expect(game != null, "Game scene opened"): return finish()
	var cycle: Node = game.get("day_night")
	expect(cycle != null and game.polar.overlays.back() == cycle, "day/night paints last over the biomes")
	expect(game.get_node_or_null("GameMusic") != null, "the game has the music player")
	if cycle == null: return finish()
	for frame: int in 20: await process_frame
	var sun: DirectionalLight3D = game.polar.sun
	var sky: ShaderMaterial = game.polar.sky_material
	var day_energy: float = sun.light_energy
	var day_top: Color = sky.get_shader_parameter("top_color")
	expect(day_energy > 0.9 and sun.global_transform.basis.z.y > 0.5, "noon sun is bright and high")
	set_time(0.64)
	for frame: int in 20: await process_frame
	expect(float(sky.get_shader_parameter("glow_amount")) > 0.3 and sun.light_color.b < 0.7, "sunset glows and the light turns gold")
	set_time(0.8)
	for frame: int in 20: await process_frame
	expect(float(sky.get_shader_parameter("night_amount")) > 0.99, "stars at night")
	expect(sun.light_energy < 0.4 and sun.light_energy > 0.1 and sun.global_transform.basis.z.y > 0.2, "the moon lights the night")
	expect((sky.get_shader_parameter("top_color") as Color).get_luminance() < day_top.get_luminance() * 0.3, "the night sky is dark")
	expect(game.volcano == null or game.volcano.darkness(sun) > 0.5, "the volcano sees the night")
	set_time(0.3)
	for frame: int in 20: await process_frame
	expect(absf(sun.light_energy - day_energy) < 0.01 and float(sky.get_shader_parameter("night_amount")) == 0.0, "day returns unchanged")
	DayNight.clock_offset = 0.0
	finish()

func finish() -> void:
	print("DAY_NIGHT CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
