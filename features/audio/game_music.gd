extends Node
## Patch 3.1: Andy Viera's songs by time of day (day, sunset, night). One player.
## Music starts only after 15 s of continuous sailing and fades in slowly to a
## quiet background level. The song loops straight through. A full stop fades
## it fully out (it returns after another 15 s of sailing). When the time of
## day changes: fade out to silence, 3 s of silence, then fade in the next song.
## No crossfade. Volume follows the Music/Ambience slider ("game_ambience").
const DayNight = preload("res://features/sky/day_night.gd")
const SONGS = {
	"day": preload("res://assets/audio/music/day_Neon_Buoy.mp3"),
	"sunset": preload("res://assets/audio/music/sunset_Sunlit_Current.mp3"),
	"night": preload("res://assets/audio/music/night_The_Blackwater_Passage.mp3"),
}
const SAIL_SECONDS: float = 15.0
const GAP_SECONDS: float = 3.0
const FADE_IN_SECONDS: float = 10.0
const STOP_FADE_SECONDS: float = 8.0
const CHANGE_FADE_SECONDS: float = 5.0
## Background level at full slider, linear.
const QUIET: float = 0.32
## Slower than this is a full stop, m/s.
const STOPPED_MPS: float = 0.25

var view: Node
var player: AudioStreamPlayer
var song: String = ""
var sailing: float = 0.0
var gap: float = 0.0
## 0..1 fade position of the playing song.
var level: float = 0.0
var changing: bool = false
var wanted_gain: float = 0.7
var gain: float = 0.0
var playback_enabled: bool = DisplayServer.get_name() != "headless" or OS.get_cmdline_user_args().has("--game-audio-check")

func _ready() -> void:
	add_to_group("game_ambience")
	player = AudioStreamPlayer.new()
	player.volume_linear = 0.0
	add_child(player)
	for stream: AudioStreamMP3 in SONGS.values(): stream.loop = true
	if view != null: set_volume(view.controls.preferences.ambience_volume)

func set_volume(value: float) -> void:
	wanted_gain = clampf(value, 0.0, 1.0)

## One step of the rules; `speed` in m/s, `wanted` the time of day's song.
func step(delta: float, speed: float, wanted: String) -> void:
	var moving: bool = absf(speed) > STOPPED_MPS
	sailing = sailing + delta if moving else 0.0
	gap = maxf(0.0, gap - delta)
	if not song.is_empty() and wanted != song: changing = true
	if song.is_empty():
		if moving and sailing >= SAIL_SECONDS and gap <= 0.0:
			song = wanted
			level = 0.0
			changing = false
			player.stream = SONGS[song]
			if playback_enabled: player.play()
		return
	if changing or not moving:
		level = move_toward(level, 0.0, delta / (CHANGE_FADE_SECONDS if changing else STOP_FADE_SECONDS))
		if level <= 0.0:
			player.stop()
			if changing: gap = GAP_SECONDS
			song = ""
			changing = false
	else:
		level = move_toward(level, 1.0, delta / FADE_IN_SECONDS)

func _process(delta: float) -> void:
	if is_instance_valid(view) and view.leaving: wanted_gain = 0.0
	# Large frame gaps (loading, debug travel) never snap a fade.
	var dt: float = minf(delta, 1.0 / 30.0)
	gain = move_toward(gain, wanted_gain, dt / 0.2)
	var speed: float = 0.0
	if is_instance_valid(view) and is_instance_valid(view.ship): speed = view.ship.ground_speed_mps
	step(dt, speed, DayNight.song_at(DayNight.now()))
	player.volume_linear = level * level * QUIET * gain

func _exit_tree() -> void:
	player.stop()
	player.stream = null
