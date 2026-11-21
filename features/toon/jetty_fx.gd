extends Node3D
## Patch 4.0.2 (Andy's follow-up on #224): the Jetty's hover and blaster looks.
## Built by chunky_look's _dress_jetty next to the rear thruster, which stays
## exactly as it was (the nozzle, its ring and JetFlame).
##
## Hover: "Downwash" is spray blown out flat over the water under the hull,
## "RoosterTail" is a plume thrown up behind the stern that grows with speed,
## and "Glow" is a teal light pool on the water under the hull (with
## "GlowLight"). They sit on the water level, below the hovering hull
## (ShipVisualMotion lifts the hull; the body stays on the water plane).
##
## Blaster boost (features/ships/jetty_boost.gd, Shift): during the charge a
## "ChargeOrb" grows at the nozzle and a rising whine plays; on the blast a huge
## "BoostFlame" in fast-cycling RGB bands roars out of the nozzle, a "BlastRing"
## shock wave bursts off the stern and the beam-cannon blast plays. Both sounds
## are synthesised here from sine, saw and noise (no recorded audio).
##
## Looks and sound only: it never changes the hull's speed or state. Online,
## the presentation hull runs no physics, so this node moves its boost clock.
const JETTY_BOOST = preload("res://features/ships/jetty_boost.gd")
const SPRAY: Color = Color(0.93, 0.98, 1.0, 0.85)
const GLOW: Color = Color("5ff2e0")
const FLAME_LENGTH_M: float = 22.0
const FLAME_RADIUS_M: float = 1.35
const FLAME_BANDS: Array = [1.0, 0.72, 0.42]
## Hue turns per second of the blaster flame (fast RGB).
const HUE_RATE: float = 3.2
const RING_S: float = 0.55
const MIX_RATE: int = 22050
static var _charge_sound: AudioStreamWAV
static var _blast_sound: AudioStreamWAV

## Where the nozzle is in the model (set by _dress_jetty before _ready).
var nozzle: Vector3 = Vector3(0, 1.2, -6.9)
var length_m: float = 12.0
var beam_m: float = 3.0
var ship: Node
var motion: Node3D
var downwash: CPUParticles3D
var rooster: CPUParticles3D
var glow: MeshInstance3D
var glow_paint: StandardMaterial3D
var glow_light: OmniLight3D
var flame: Node3D
var flame_cones: Array[MeshInstance3D] = []
var flame_paints: Array[StandardMaterial3D] = []
var orb: MeshInstance3D
var orb_paint: StandardMaterial3D
var ring: MeshInstance3D
var ring_paint: StandardMaterial3D
var voice: AudioStreamPlayer
var clock: float = 0.0
var last_phase: String = "ready"
var ring_age: float = RING_S
## Counters for the checks.
var charges_heard: int = 0
var blasts_heard: int = 0

func _ready() -> void:
	var node: Node = get_parent()
	while node != null:
		if motion == null and node.has_method("hovering"): motion = node as Node3D
		if ship == null and node.get("boost") is RefCounted and node.get("actual_throttle") != null: ship = node
		node = node.get_parent()
	build()
	update_fx(0.0)

func unshaded(colour: Color, additive: bool = false) -> StandardMaterial3D:
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = colour
	if colour.a < 1.0 or additive: paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive: paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	return paint

func spray(label: String, amount: int, life: float) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.name = label
	particles.amount = amount
	particles.lifetime = life
	particles.local_coords = true
	var blob: QuadMesh = QuadMesh.new()
	blob.size = Vector2(0.7, 0.7)
	var paint: StandardMaterial3D = unshaded(SPRAY)
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	paint.vertex_color_use_as_albedo = true
	blob.material = paint
	particles.mesh = blob
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.95))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	particles.color_ramp = fade
	particles.color = SPRAY
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.6
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles

func build() -> void:
	# Downwash: flat spray blown out from under the whole hull.
	downwash = spray("Downwash", 72, 0.8)
	downwash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	downwash.emission_box_extents = Vector3(beam_m * 0.5, 0.05, length_m * 0.45)
	downwash.direction = Vector3(0, 0.25, 0)
	downwash.spread = 88.0
	downwash.flatness = 0.85
	downwash.initial_velocity_min = 4.0
	downwash.initial_velocity_max = 9.0
	downwash.gravity = Vector3(0, -6.0, 0)
	downwash.damping_min = 2.0
	downwash.damping_max = 4.0
	# Rooster tail: a plume up and back behind the stern.
	rooster = spray("RoosterTail", 110, 1.1)
	rooster.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	rooster.emission_sphere_radius = 0.45
	rooster.direction = Vector3(0, 0.75, -1.0)
	rooster.spread = 12.0
	rooster.gravity = Vector3(0, -14.0, 0)
	rooster.scale_amount_min = 0.9
	rooster.scale_amount_max = 2.4
	# Glow: a teal pool of light on the water under the hull.
	var pool: PlaneMesh = PlaneMesh.new()
	pool.size = Vector2(beam_m * 1.9, length_m * 1.05)
	glow_paint = unshaded(Color(GLOW, 0.5), true)
	glow = MeshInstance3D.new()
	glow.name = "Glow"
	glow.mesh = pool
	glow.material_override = glow_paint
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	glow_light = OmniLight3D.new()
	glow_light.name = "GlowLight"
	glow_light.light_color = GLOW
	glow_light.omni_range = maxf(length_m * 0.8, 6.0)
	glow_light.shadow_enabled = false
	add_child(glow_light)
	# The blaster flame: three nested cones, fast RGB, out of the nozzle.
	flame = Node3D.new()
	flame.name = "BoostFlame"
	flame.position = nozzle
	add_child(flame)
	for band: float in FLAME_BANDS:
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = FLAME_RADIUS_M * band
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.rings = 1
		var paint: StandardMaterial3D = unshaded(Color.WHITE)
		var cone: MeshInstance3D = MeshInstance3D.new()
		cone.mesh = mesh
		cone.material_override = paint
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation.x = -PI / 2.0
		flame.add_child(cone)
		flame_cones.append(cone)
		flame_paints.append(paint)
	# The charge: an orb that swells at the nozzle.
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	orb_paint = unshaded(Color(1, 1, 1, 0.9), true)
	orb = MeshInstance3D.new()
	orb.name = "ChargeOrb"
	orb.mesh = ball
	orb.material_override = orb_paint
	orb.position = nozzle + Vector3(0, 0, -0.3)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	# The blast: a shock ring bursting off the stern.
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	ring_paint = unshaded(Color(1, 1, 1, 0.9), true)
	ring = MeshInstance3D.new()
	ring.name = "BlastRing"
	ring.mesh = torus
	ring.material_override = ring_paint
	ring.position = nozzle + Vector3(0, 0, -0.6)
	ring.rotation.x = PI / 2.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	voice = AudioStreamPlayer.new()
	voice.name = "BoostSound"
	voice.volume_db = -8.0
	add_child(voice)

## The boost this hull carries (null in the hangar).
func boost() -> JETTY_BOOST:
	if is_instance_valid(ship): return ship.get("boost") as JETTY_BOOST
	return null

## 0..1 share of top speed (0.35 in the hangar so the plume shows).
func pace() -> float:
	if not is_instance_valid(ship) or not ship is CharacterBody3D: return 0.35
	var body: CharacterBody3D = ship as CharacterBody3D
	var definition: Resource = body.get("definition") as Resource
	var top: float = 1.0
	if definition != null: top = maxf(float(definition.get("forward_acceleration_mps2")) / maxf(float(definition.get("linear_drag_per_second")), 0.001), 1.0)
	return clampf(Vector2(body.velocity.x, body.velocity.z).length() / top, 0.0, 1.6)

## The water level in this node's space: below the hull by the hover lift.
func water_y() -> float:
	if is_instance_valid(motion): return -motion.position.y
	return -2.0

static func rgb(hue: float, value: float = 1.0) -> Color:
	return Color.from_hsv(fposmod(hue, 1.0), 0.85, value)

func _process(delta: float) -> void:
	update_fx(delta)

func update_fx(delta: float) -> void:
	var step: float = clampf(delta, 0.0, 0.1)
	clock += step
	var power: JETTY_BOOST = boost()
	# Online the presentation hull runs no physics: move its boost clock here.
	if power != null and is_instance_valid(ship) and not (ship as Node).is_physics_processing(): power.advance(step)
	var phase: String = power.phase if power != null else "ready"
	if phase != last_phase:
		if phase == "charge":
			play(charge_sound())
			charges_heard += 1
		if phase == "blast":
			play(blast_sound())
			blasts_heard += 1
			ring_age = 0.0
		last_phase = phase
	var charge: float = power.charge() if power != null and phase == "charge" else 0.0
	var blast: float = power.blast() if power != null else 0.0
	var speed: float = pace()
	var water: float = water_y() + 0.08
	# Hover: downwash, rooster tail and glow on the water under the hull.
	downwash.position = Vector3(0, water, 0)
	downwash.initial_velocity_max = 9.0 + 6.0 * blast
	rooster.position = Vector3(0, water, -length_m * 0.5 - 0.6)
	rooster.emitting = speed > 0.04 or blast > 0.0
	rooster.initial_velocity_min = 6.0 + 14.0 * minf(speed, 1.0) + 10.0 * blast
	rooster.initial_velocity_max = rooster.initial_velocity_min * 1.5
	var pulse: float = 0.5 + 0.5 * sin(clock * 3.1)
	var hot: float = maxf(charge, blast)
	glow.position = Vector3(0, water + 0.02, 0)
	var glow_colour: Color = GLOW.lerp(rgb(clock * HUE_RATE), hot)
	glow_paint.albedo_color = Color(glow_colour, 0.32 + 0.14 * pulse + 0.4 * hot)
	glow_light.position = Vector3(0, water + 0.6, 0)
	glow_light.light_color = glow_colour
	glow_light.light_energy = 1.2 + 0.5 * pulse + 3.0 * hot
	# Charge: the orb swells and spins through the colours.
	orb.visible = charge > 0.0
	if orb.visible:
		var size: float = 0.3 + 1.6 * charge * charge + 0.12 * sin(clock * 47.0)
		orb.scale = Vector3.ONE * size
		orb_paint.albedo_color = Color(rgb(clock * HUE_RATE * 2.0).lerp(Color.WHITE, 0.4 * charge), 0.6 + 0.4 * charge)
	# Blast: the huge RGB flame and the shock ring.
	flame.visible = blast > 0.01
	if flame.visible:
		for index: int in flame_cones.size():
			var band: float = float(FLAME_BANDS[index])
			var flicker: float = 1.0 + 0.1 * sin(clock * (37.0 + index * 9.0)) + 0.06 * sin(clock * 61.0 + index)
			var cone_length: float = FLAME_LENGTH_M * band * flicker * (0.35 + 0.65 * blast)
			var cone: MeshInstance3D = flame_cones[index]
			cone.scale = Vector3(0.5 + 0.5 * blast, cone_length, 0.5 + 0.5 * blast)
			cone.position = Vector3(0, 0, -cone_length * 0.5)
			# Outer band fastest round the wheel, the core nearly white.
			flame_paints[index].albedo_color = rgb(clock * HUE_RATE + index * 0.33).lerp(Color.WHITE, 0.2 + 0.3 * index)
	ring_age += step
	ring.visible = ring_age < RING_S
	if ring.visible:
		var t: float = ring_age / RING_S
		ring.scale = Vector3.ONE * (0.8 + 7.0 * t)
		ring.position = nozzle + Vector3(0, 0, -0.6 - 5.0 * t)
		ring_paint.albedo_color = Color(rgb(clock * HUE_RATE + 0.5), 0.9 * (1.0 - t))

func play(stream: AudioStream) -> void:
	if voice == null or not voice.is_inside_tree(): return
	voice.stream = stream
	voice.play()

static func write(samples: PackedByteArray, index: int, value: float) -> void:
	samples.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 30000.0))

static func wav(seconds: float) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(int(seconds * MIX_RATE) * 2)
	stream.data = samples
	return stream

## The charge: a whine rising three octaves with a quickening flutter, a rising
## hum under it and a fizz of sparks that thickens as it fills. Made once.
static func charge_sound() -> AudioStreamWAV:
	if _charge_sound != null: return _charge_sound
	var seconds: float = JETTY_BOOST.CHARGE_S + 0.04
	var stream: AudioStreamWAV = wav(seconds)
	var samples: PackedByteArray = stream.data
	var count: int = samples.size() >> 1
	var noise: RandomNumberGenerator = RandomNumberGenerator.new()
	noise.seed = 4022
	var whine: float = 0.0
	var hum: float = 0.0
	var flutter: float = 0.0
	var smooth: float = 0.0
	for index: int in count:
		var t: float = float(index) / MIX_RATE
		var fill: float = clampf(t / JETTY_BOOST.CHARGE_S, 0.0, 1.0)
		whine += TAU * 220.0 * pow(8.0, fill) / MIX_RATE
		hum += TAU * (55.0 + 55.0 * fill) / MIX_RATE
		flutter += TAU * (8.0 + 34.0 * fill * fill) / MIX_RATE
		var raw: float = noise.randf_range(-1.0, 1.0)
		smooth = lerpf(smooth, raw, 0.2)
		var tone: float = (sin(whine) + 0.35 * sin(whine * 2.003) + 0.15 * sin(whine * 3.01)) * (0.72 + 0.28 * sin(flutter))
		var wave: float = tone * (0.15 + 0.55 * fill * fill) + sin(hum) * 0.3 * fill + (raw - smooth) * 0.18 * fill
		wave *= minf(1.0, t / 0.01) * minf(1.0, (seconds - t) / 0.02)
		write(samples, index, tanh(wave * 1.3) * 0.85)
	stream.data = samples
	_charge_sound = stream
	return stream

## The blast: a deep falling boom, a bright saw zap diving from 1.8 kHz to
## 120 Hz (a detuned pair, so it beats), and a long roaring beam of filtered
## noise over a throbbing rumble, soft-clipped together. Made once.
static func blast_sound() -> AudioStreamWAV:
	if _blast_sound != null: return _blast_sound
	var seconds: float = 1.9
	var stream: AudioStreamWAV = wav(seconds)
	var samples: PackedByteArray = stream.data
	var count: int = samples.size() >> 1
	var noise: RandomNumberGenerator = RandomNumberGenerator.new()
	noise.seed = 4023
	var boom: float = 0.0
	var zap_a: float = 0.0
	var zap_b: float = 0.0
	var throb: float = 0.0
	var roar: float = 0.0
	var roar_low: float = 0.0
	for index: int in count:
		var t: float = float(index) / MIX_RATE
		boom += TAU * (40.0 + 100.0 * exp(-t * 7.0)) / MIX_RATE
		var dive: float = 120.0 + 1680.0 * exp(-t * 6.5)
		zap_a += TAU * dive / MIX_RATE
		zap_b += TAU * dive * 1.012 / MIX_RATE
		throb += TAU * 90.0 / MIX_RATE
		var raw: float = noise.randf_range(-1.0, 1.0)
		roar = lerpf(roar, raw, 0.35)
		roar_low = lerpf(roar_low, roar, 0.08)
		var saw: float = 0.0
		for harmonic: int in range(1, 5):
			saw += (sin(zap_a * harmonic) + sin(zap_b * harmonic)) / float(harmonic)
		var attack: float = minf(1.0, t / 0.003)
		var wave: float = sin(boom) * 0.9 * exp(-t * 3.5)
		wave += saw * 0.22 * exp(-t * 4.0)
		wave += (roar - roar_low) * 0.5 * (1.0 - exp(-t * 40.0)) * exp(-t * 1.3)
		wave += roar_low * 1.4 * exp(-t * 1.6) * (0.7 + 0.3 * sin(throb))
		wave *= attack * minf(1.0, (seconds - t) / 0.12)
		write(samples, index, tanh(wave * 1.4) * 0.9)
	stream.data = samples
	_blast_sound = stream
	return stream
