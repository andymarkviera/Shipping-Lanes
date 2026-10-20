class_name HandlingFeedback
extends Node
## Read-only presentation of a handling body; never writes navigation state.
var engine: AudioStreamPlayer
var thruster: AudioStreamPlayer
var horn: AudioStreamPlayer
var snapshot: Dictionary = {}
var engine_level: float = -60.0
var thruster_level: float = -60.0

static func tone(kind: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration: float = 1.2 if kind == "horn" else 1.0
	var count: int = int(duration * stream.mix_rate)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(count * 2)
	for index: int in range(count):
		var t: float = float(index) / stream.mix_rate
		var wave: float
		if kind == "horn":
			var envelope: float = minf(1.0, minf(t / 0.08, (duration - t) / 0.2))
			wave = (sin(TAU * 110 * t) * 0.5 + sin(TAU * 138.6 * t) * 0.3 + sin(TAU * 220 * t) * 0.1) * envelope
		elif kind == "thruster":
			wave = (sin(TAU * 90 * t) * 0.4 + sin(TAU * 270 * t) * 0.2) * (0.8 + 0.2 * sin(TAU * 7 * t))
		else:
			wave = sin(TAU * 40 * t) * 0.5 + sin(TAU * 80 * t) * 0.25 + sin(TAU * 120 * t) * 0.1
		samples.encode_s16(index * 2, int(clampf(wave, -1.0, 1.0) * 24000))
	stream.data = samples
	if kind != "horn":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream

func player(kind: String) -> AudioStreamPlayer:
	var result: AudioStreamPlayer = AudioStreamPlayer.new()
	result.stream = tone(kind)
	result.volume_db = -60.0
	add_child(result)
	return result

func _ready() -> void:
	engine = player("engine")
	thruster = player("thruster")
	horn = player("horn")
	horn.volume_db = -18.0

static func instruments(ship: HandlingShip) -> Dictionary:
	var ahead: float = ship.forward_speed()
	var side: float = -ship.lateral_speed()
	var power: float = ship.lateral_order * clampf(1.0 - absf(ahead) / ship.definition.thruster_cutoff_speed_mps, 0.0, 1.0)
	if ship.state.fuel_liters <= 0 or ship.docked or ship.simulation_paused: power = 0
	var direction: String = "STOPPED"
	if ahead > 0.03: direction = "AHEAD"
	elif ahead < -0.03: direction = "ASTERN"
	elif absf(side) > 0.03: direction = "LATERAL"
	return {"speed_knots": ship.velocity.length() * 3600.0 / 1852.0, "direction": direction,
		"heading_degrees": fposmod(-rad_to_deg(ship.rotation.y), 360.0),
		"command": ship.commanded_throttle, "engine": ship.actual_throttle,
		"thruster": power, "side_knots": side * 3600.0 / 1852.0,
		"turn_degrees": -rad_to_deg(ship.yaw_rate), "fuel_liters": ship.state.fuel_liters}

func sound_horn(allowed: bool) -> void:
	if allowed and not horn.playing: horn.play()

func update(ship: HandlingShip, allowed: bool, delta: float) -> void:
	snapshot = instruments(ship)
	if not allowed:
		engine.stop()
		thruster.stop()
		horn.stop()
		engine_level = -60.0
		thruster_level = -60.0
		return
	var engine_power: float = absf(snapshot.engine)
	var thruster_power: float = absf(snapshot.thruster)
	engine_level = move_toward(engine_level, lerpf(-42.0, -25.0, engine_power) if engine_power > 0.005 else -60.0, delta * 45.0)
	thruster_level = move_toward(thruster_level, lerpf(-38.0, -27.0, thruster_power) if thruster_power > 0.005 else -60.0, delta * 45.0)
	engine.volume_db = engine_level
	thruster.volume_db = thruster_level
	engine.pitch_scale = lerpf(0.8, 1.4, engine_power)
	thruster.pitch_scale = lerpf(0.9, 1.2, thruster_power)
	if engine_level > -59.0 and not engine.playing: engine.play()
	if engine_level <= -59.0: engine.stop()
	if thruster_level > -59.0 and not thruster.playing: thruster.play()
	if thruster_level <= -59.0: thruster.stop()
