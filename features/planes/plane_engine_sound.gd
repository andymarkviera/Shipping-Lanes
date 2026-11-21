extends Node3D
## Patch 4.0.5 item 3: plane engine sounds, synthesized in code (like
## PlaneLook.sound and JettyFx; no recordings, see features/audio/CREDITS.md).
## One sound per engine family in PlaneCatalog ("engines"):
## - "prop1" (Bush prop): a piston engine's firing buzz with a propeller beat;
## - "prop2" (Regional turboprop): propeller blade hum with a turbine whine;
## - "fan2" (Cargo jet): the turbofan's buzz-saw fan tone, whine and roar;
## - "afterburner" (Fighter jet): turbine whine and jet roar, and over
##   AFTERBURNER_LEVER the afterburner's deep rumble and crackle.
## Each family is two or three seamless one-second loops ("core", "air",
## "burner"), made once per run and shared. `update` pitches the core by the
## engine's RPM (the plane's `engine`, which follows the lever) and lifts the
## roar with the throttle. Your own plane plays flat (no position); another
## captain's plays from its plane, with a doppler shift worked out from the
## two velocities (`doppler`), so a passing plane drops in pitch.
const RATE: int = 22050
const LOOP_SAMPLES: int = 22050
const SOUND_MPS: float = 343.0
const AFTERBURNER_LEVER: float = 0.85
const FAMILIES: Array[String] = ["prop1", "prop2", "fan2", "afterburner"]
## Per family: core pitch at idle and its rise to full RPM, core dB idle/full,
## air dB idle/full.
const MIX: Dictionary = {
	"prop1": {"pitch": 0.55, "span": 0.85, "core_db": [-20.0, -7.0], "air_db": [-42.0, -22.0]},
	"prop2": {"pitch": 0.72, "span": 0.5, "core_db": [-20.0, -8.0], "air_db": [-36.0, -16.0]},
	"fan2": {"pitch": 0.45, "span": 0.9, "core_db": [-24.0, -12.0], "air_db": [-34.0, -7.0]},
	"afterburner": {"pitch": 0.5, "span": 0.95, "core_db": [-22.0, -9.0], "air_db": [-32.0, -6.0]},
}
static var loops: Dictionary = {}

var family: String = "prop1"
## False: your own plane (flat). True: another captain's (from its position).
var positional: bool = false
var players: Dictionary = {}
var last_mix: Dictionary = {}
var doppler_factor: float = 1.0

static func family_of(kind: String) -> String:
	var entry: Dictionary = preload("res://features/planes/plane_catalog.gd").PLANES.get(kind, {})
	var engines: String = str(entry.get("engines", "prop1"))
	return engines if engines in FAMILIES else "prop1"

static func make(kind: String, from_position: bool) -> Node3D:
	var sound: Node3D = preload("res://features/planes/plane_engine_sound.gd").new()
	sound.name = "EngineSound"
	sound.family = family_of(kind)
	sound.positional = from_position
	return sound

func layers() -> Array[String]:
	return ["core", "air", "burner"] if family == "afterburner" else ["core", "air"]

func _ready() -> void:
	for layer: String in layers():
		var player: Node
		if positional:
			var spatial: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			spatial.unit_size = 60.0
			spatial.max_distance = 3500.0
			spatial.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			player = spatial
		else:
			player = AudioStreamPlayer.new()
		player.name = layer.capitalize()
		player.set("stream", loop(family, layer))
		player.set("volume_db", -80.0)
		add_child(player)
		players[layer] = player

## The sound settings for an engine at `rpm` (0..1) and lever `throttle` (0..1).
static func mix(engine_family: String, rpm: float, throttle: float) -> Dictionary:
	var m: Dictionary = MIX.get(engine_family, MIX.prop1)
	var r: float = clampf(rpm, 0.0, 1.0)
	var burner: float = 0.0
	if engine_family == "afterburner":
		burner = clampf((throttle - AFTERBURNER_LEVER) / (1.0 - AFTERBURNER_LEVER), 0.0, 1.0) * clampf((r - 0.7) / 0.3, 0.0, 1.0)
	return {"core_pitch": float(m.pitch) + float(m.span) * r,
		"core_db": lerpf(m.core_db[0], m.core_db[1], r),
		"air_pitch": 0.8 + 0.35 * r,
		"air_db": lerpf(m.air_db[0], m.air_db[1], pow(r, 1.5)),
		"burner_pitch": 0.85 + 0.2 * burner,
		"burner_db": lerpf(-60.0, -3.0, burner) if burner > 0.0 else -80.0,
		"burner": burner}

## The pitch factor a listener hears from a moving source (the doppler
## effect): above 1 while they close, below 1 while they part. Clamped to
## 0.5..2 (a fighter can pass at more than half the speed of sound).
static func doppler(source: Vector3, source_velocity: Vector3, listener: Vector3, listener_velocity: Vector3) -> float:
	var toward: Vector3 = listener - source
	if toward.length_squared() < 1.0: return 1.0
	toward = toward.normalized()
	var listener_closing: float = -listener_velocity.dot(toward)
	var source_closing: float = source_velocity.dot(toward)
	var factor: float = (SOUND_MPS + listener_closing) / maxf(SOUND_MPS * 0.25, SOUND_MPS - source_closing)
	return clampf(factor, 0.5, 2.0)

## Sets pitch and volume. `shift` is the doppler factor (1 for your plane).
func update(rpm: float, throttle: float, shift: float = 1.0) -> void:
	last_mix = mix(family, rpm, throttle)
	doppler_factor = shift
	for layer: String in players:
		var player: Node = players[layer]
		var db: float = float(last_mix[layer + "_db"])
		player.set("pitch_scale", clampf(float(last_mix[layer + "_pitch"]) * shift, 0.1, 4.0))
		player.set("volume_db", db)
		var on: bool = db > -70.0 and is_inside_tree()
		if on and not player.get("playing"): player.call("play")
		elif not on and player.get("playing"): player.call("stop")

func silence() -> void:
	for player: Node in players.values():
		if player.get("playing"): player.call("stop")

# --- Synthesis -----------------------------------------------------------------

## One family's loop, made on first use and kept.
static func loop(engine_family: String, layer: String) -> AudioStreamWAV:
	var key: String = engine_family + "/" + layer
	if not loops.has(key):
		var stream: AudioStreamWAV = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = RATE
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = LOOP_SAMPLES
		stream.data = encode(samples(engine_family, layer))
		loops[key] = stream
	return loops[key]

static func encode(wave: PackedFloat32Array) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(wave.size() * 2)
	for index: int in wave.size():
		bytes.encode_s16(index * 2, int(clampf(wave[index], -1.0, 1.0) * 30000.0))
	return bytes

## The raw loop, -1..1, LOOP_SAMPLES long. Every tone is a whole number of
## cycles in the loop (so it joins without a click); noise is filtered
## round the loop, so it joins too.
static func samples(engine_family: String, layer: String) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(engine_family + layer) & 0x7fffffff
	var wave: PackedFloat32Array = PackedFloat32Array()
	wave.resize(LOOP_SAMPLES)
	match engine_family + "/" + layer:
		"prop1/core":
			# A four-cylinder piston buzz (42 Hz, rich in harmonics), its firing
			# roughness, and the propeller's beat.
			add_cycle(wave, cycle(525, 26, 0.85, rng), 1.0)
			add_tone(wave, 84.0, 0.18, 0.0)
			modulate(wave, 7.0, 0.22)
			add_noise(wave, rng, 0.08, 0.35)
		"prop2/core":
			# Turboprop: four-blade propeller hum (70 Hz) and the turbine's whine.
			add_cycle(wave, cycle(315, 14, 1.25, rng), 1.0)
			add_tone(wave, 1470.0, 0.09, 3.0)
			add_tone(wave, 2205.0, 0.05, 2.0)
			modulate(wave, 4.0, 0.12)
			add_noise(wave, rng, 0.08, 0.2)
		"fan2/core":
			# Turbofan: the fan's buzz-saw tone (175 Hz) and its high whine.
			add_cycle(wave, cycle(126, 30, 1.0, rng), 0.45)
			add_tone(wave, 2625.0, 0.22, 2.0)
			add_tone(wave, 3850.0, 0.1, 3.0)
			add_noise(wave, rng, 0.15, 0.5)
		"afterburner/core":
			# Fighter: a hard turbine whine over a low buzz (90 Hz).
			add_cycle(wave, cycle(245, 18, 1.1, rng), 0.55)
			add_tone(wave, 1800.0, 0.2, 4.0)
			add_tone(wave, 3600.0, 0.08, 5.0)
			add_noise(wave, rng, 0.22, 0.45)
		"afterburner/burner":
			# Afterburner: deep rumble and the crackle of the flame.
			add_noise(wave, rng, 1.0, 0.035)
			add_noise(wave, rng, 0.35, 0.12)
			add_crackle(wave, rng, 260, 0.9)
		_:
			# "air": the airflow and jet roar, low-passed noise (darker for props).
			add_noise(wave, rng, 1.0, 0.06 if engine_family.begins_with("prop") else 0.1)
			add_noise(wave, rng, 0.25, 0.3)
	normalize(wave, 0.9)
	return wave

## One cycle, `period` samples long: harmonics 1..count at 1/n^tilt, random phases.
static func cycle(period: int, count: int, tilt: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var shape: PackedFloat32Array = PackedFloat32Array()
	shape.resize(period)
	for harmonic: int in range(1, count + 1):
		var phase: float = rng.randf() * TAU
		var amplitude: float = 1.0 / pow(float(harmonic), tilt)
		for index: int in period:
			shape[index] += sin(TAU * float(harmonic * index) / float(period) + phase) * amplitude
	return shape

static func add_cycle(wave: PackedFloat32Array, shape: PackedFloat32Array, gain: float) -> void:
	var peak: float = 0.0001
	for value: float in shape: peak = maxf(peak, absf(value))
	for index: int in wave.size():
		wave[index] += shape[index % shape.size()] / peak * gain

## A whole-cycles tone with a slow wobble of `wobble` Hz (also whole).
static func add_tone(wave: PackedFloat32Array, hz: float, gain: float, wobble: float) -> void:
	for index: int in wave.size():
		var t: float = float(index) / RATE
		var swell: float = 1.0 + (0.25 * sin(TAU * wobble * t) if wobble > 0.0 else 0.0)
		wave[index] += sin(TAU * hz * t) * gain * swell

static func modulate(wave: PackedFloat32Array, hz: float, depth: float) -> void:
	for index: int in wave.size():
		wave[index] *= 1.0 + depth * sin(TAU * hz * float(index) / RATE)

## White noise through a one-pole low-pass (`smooth` 0..1, lower is darker),
## run twice round the loop so the end flows into the start.
static func add_noise(wave: PackedFloat32Array, rng: RandomNumberGenerator, gain: float, smooth: float) -> void:
	var white: PackedFloat32Array = PackedFloat32Array()
	white.resize(wave.size())
	for index: int in white.size(): white[index] = rng.randf_range(-1.0, 1.0)
	var low: float = 0.0
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(wave.size())
	for lap: int in 2:
		for index: int in white.size():
			low += (white[index] - low) * smooth
			if lap == 1: out[index] = low
	var peak: float = 0.0001
	for value: float in out: peak = maxf(peak, absf(value))
	for index: int in wave.size(): wave[index] += out[index] / peak * gain

## Short sharp pops scattered round the loop (each decays, wrapping the end).
static func add_crackle(wave: PackedFloat32Array, rng: RandomNumberGenerator, count: int, gain: float) -> void:
	for pop: int in count:
		var at: int = rng.randi_range(0, wave.size() - 1)
		var size: float = rng.randf_range(0.3, 1.0) * gain
		var length: int = rng.randi_range(40, 220)
		for step: int in length:
			wave[(at + step) % wave.size()] += rng.randf_range(-1.0, 1.0) * size * exp(-float(step) / (float(length) * 0.25))

static func normalize(wave: PackedFloat32Array, peak_to: float) -> void:
	var peak: float = 0.0001
	for value: float in wave: peak = maxf(peak, absf(value))
	for index: int in wave.size(): wave[index] *= peak_to / peak
