extends Node
## Fixed two-player pool, retained across scenes. No runtime synthesis or loading
## in _process; sample loops run on the mixer, not frame timers.
const STREAMS = [preload("res://features/audio/menu_surf.wav"), preload("res://features/audio/menu_gulls.wav")]
const NODE_NAME: String = "MenuBeachAmbience"
const FADE_SECONDS: float = 1.2
var players: Array[AudioStreamPlayer] = []
## Headless runs have no listener; opt in only for the mixer lifecycle check.
var playback_enabled: bool = DisplayServer.get_name() != "headless" or OS.get_cmdline_user_args().has("--menu-audio-check")
var active: bool = false
var envelope: float = 0.0
var gain: float = 0.7
var wanted_gain: float = 0.7

static func acquire(tree: SceneTree) -> Node:
	var existing: Node = tree.root.get_node_or_null(NODE_NAME)
	if existing != null: return existing
	var ambience: Node = load("res://features/audio/menu_ambience.gd").new()
	ambience.name = NODE_NAME
	tree.root.add_child.call_deferred(ambience)
	return ambience

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for stream: AudioStream in STREAMS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		player.volume_linear = 0.0
		add_child(player)
		players.append(player)
	gain = wanted_gain
	set_active(active)

func set_active(value: bool) -> void:
	active = value
	if active and playback_enabled:
		for player: AudioStreamPlayer in players:
			if not player.playing: player.play()
	set_process(true)

func set_volume(value: float) -> void:
	wanted_gain = clampf(value, 0.0, 1.0)
	set_process(true)

func _process(delta: float) -> void:
	var step: float = minf(delta, 1.0 / 30.0)
	envelope = move_toward(envelope, 1.0 if active else 0.0, step / FADE_SECONDS)
	gain = move_toward(gain, wanted_gain, step / 0.15)
	for player: AudioStreamPlayer in players:
		player.volume_linear = smoothstep(0.0, 1.0, envelope) * gain
	if not active and envelope == 0.0:
		for player: AudioStreamPlayer in players: player.stop()
		set_process(false)
	elif envelope == 1.0 and gain == wanted_gain:
		set_process(false)

func _exit_tree() -> void:
	for player: AudioStreamPlayer in players:
		player.stop()
		player.stream = null
