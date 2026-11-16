extends Node
## One fixed player per layer, shared by all ports. Baked loops only; no runtime
## synthesis, loading, node churn or per-port mixer voices. Silent layers stop.
const Progression = preload("res://features/game/progression.gd")
const Polar = preload("res://features/sky/polar_biome.gd")
const Desert = preload("res://features/sky/desert_biome.gd")
const Tropical = preload("res://features/sky/tropical_biome.gd")
const Rain = preload("res://features/sky/rain_biome.gd")
const STREAMS = [
	preload("res://features/audio/menu_surf.wav"),
	preload("res://features/audio/game_wash.wav"),
	preload("res://features/audio/game_wind.wav"),
	preload("res://features/audio/game_harbour.wav"),
	preload("res://features/audio/menu_surf.wav"),
	preload("res://features/audio/menu_gulls.wav"),
	preload("res://features/audio/game_ice.wav"),
	preload("res://features/audio/game_rain.wav"),
	preload("res://features/audio/game_desert.wav"),
]
const RANGE_M: float = 1500.0
const FULL_M: float = 350.0
var view: Node
var players: Array[AudioStreamPlayer] = []
var targets := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
var levels := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
var ports: Array[Dictionary] = []
var scan_in: float = 0.0
var wanted_gain: float = 0.7
var gain: float = 0.0
var playback_enabled: bool = DisplayServer.get_name() != "headless" or OS.get_cmdline_user_args().has("--game-audio-check")

func _ready() -> void:
	add_to_group("game_ambience")
	for stream: AudioStream in STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_linear = 0.0
		add_child(player)
		players.append(player)
	if view != null:
		set_volume(view.controls.preferences.ambience_volume)
		for port: Node3D in view.world_ports:
			var at: Vector3 = port.global_position
			ports.append({"at": at, "container": port.definition.service_ids.has("container_transfer"),
				"polar": Polar.weight(at), "tropical": Tropical.weight(at),
				"rain": Rain.weight(at), "desert": Desert.weight(at)})

func set_volume(value: float) -> void:
	wanted_gain = clampf(value, 0.0, 1.0)

## Wrap-aware, sampled at 5 Hz. Layers accumulate by max, so nearby ports never
## double the loudness. Profiles use existing services and biome geography, no IDs.
func sample(at: Vector3, speed_mps: float) -> void:
	targets.fill(0.0)
	targets[0] = 0.35
	targets[1] = lerpf(0.12, 0.65, clampf(absf(speed_mps) / 20.0, 0.0, 1.0))
	targets[2] = lerpf(0.08, 0.8, clampf(absf(speed_mps) / 35.0, 0.0, 1.0))
	for port: Dictionary in ports:
		var offset: Vector3 = Progression.short_way(at - port.at)
		var distance: float = Vector2(offset.x, offset.z).length()
		if distance >= RANGE_M: continue
		var near: float = 1.0 - smoothstep(FULL_M, RANGE_M, distance)
		var ice: float = port.polar
		targets[3] = maxf(targets[3], near * (1.0 - ice) * 0.55 if port.container else 0.0)
		targets[4] = maxf(targets[4], near * port.tropical * 0.5)
		targets[5] = maxf(targets[5], near * port.tropical * 0.8)
		targets[6] = maxf(targets[6], near * ice * 0.75)
		targets[7] = maxf(targets[7], near * port.rain * 0.65)
		targets[8] = maxf(targets[8], near * port.desert * 0.65)

func _process(delta: float) -> void:
	# Follow the existing screen fade on Main Menu; never delay or pause the world.
	if is_instance_valid(view) and view.leaving: wanted_gain = 0.0
	if is_instance_valid(view) and is_instance_valid(view.ship):
		scan_in -= delta
		if scan_in <= 0.0:
			scan_in = 0.2
			sample(view.ship.global_position, view.ship.ground_speed_mps)
	# Limit large frame gaps: debug travel and background recovery never snap gain.
	var step: float = minf(delta, 1.0 / 30.0)
	gain = move_toward(gain, wanted_gain, step / 0.2)
	for i: int in players.size():
		levels[i] = move_toward(levels[i], targets[i], step / 1.5)
		var volume: float = smoothstep(0.0, 1.0, levels[i]) * gain
		var player: AudioStreamPlayer = players[i]
		player.volume_linear = volume
		if volume > 0.00001 and playback_enabled:
			if not player.playing: player.play()
		elif player.playing:
			player.stop()

func _exit_tree() -> void:
	for player: AudioStreamPlayer in players:
		player.stop()
		player.stream = null
