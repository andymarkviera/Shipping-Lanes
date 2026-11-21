extends Node
## Patch 4.0.6 item 1: how a storm looks and sounds. Looks only: the storm
## itself (where, how strong, its bolts) is storms.gd, from the shared seed and
## clock, so every captain sees the same storm and the same lightning.
## - a darker, greyer sky, sea and haze, painted last over every biome and the
##   day/night (polar_biome.gd calls paint() after day_night.gd), so a storm
##   at noon is slate grey and a storm at night is near black, lit by the bolts;
## - rain round the camera from one pooled emitter (never spawned per drop);
## - lightning: a jagged bolt where storms.gd strikes, a flash of light, and
##   thunder synthesized in code, late by the sound's travel time;
## - a bigger swell (Storms.swell: the drawn sea, the hulls'
##   bob and the splashes all ride it).
## The blend follows the camera (a plane in a storm sees it too) and is eased.
const Storms = preload("res://features/sky/storms.gd")
const DayNight = preload("res://features/sky/day_night.gd")
const Progression = preload("res://features/game/progression.gd")
const EASE_SECONDS: float = 3.0
const DROPS: int = 2400
## Bolts further than this are not drawn (they are past the haze anyway).
const VISIBLE_M: float = 6000.0
const BOLT_SECONDS: float = 0.22
const BOLT_TOP_M: float = 520.0
const FLASH_SECONDS: float = 0.35
const SOUND_MPS: float = 343.0
const THUNDER_SECONDS: float = 3.6

## Storm tones by day and by night; the paint mixes them by DayNight.weights.
const DAY_TOP := Color(0.27, 0.30, 0.36)
const DAY_HORIZON := Color(0.48, 0.52, 0.57)
const DAY_CLOUD := Color(0.58, 0.61, 0.66)
const DAY_CLOUD_SHADE := Color(0.34, 0.37, 0.43)
const DAY_HAZE := Color(0.44, 0.48, 0.53)
const DAY_DEEP := Color(0.06, 0.16, 0.23)
const DAY_SURFACE := Color(0.20, 0.30, 0.36)
const NIGHT_TOP := Color(0.01, 0.02, 0.06)
const NIGHT_HORIZON := Color(0.06, 0.08, 0.14)
const NIGHT_CLOUD := Color(0.14, 0.16, 0.22)
const NIGHT_CLOUD_SHADE := Color(0.07, 0.08, 0.13)
const NIGHT_HAZE := Color(0.05, 0.07, 0.12)
const NIGHT_DEEP := Color(0.01, 0.04, 0.09)
const NIGHT_SURFACE := Color(0.05, 0.11, 0.18)
const BOLT_COLOR := Color(0.86, 0.92, 1.0)

var polar: Node
var day_night: Node
var rain: GPUParticles3D
var bolt: MeshInstance3D
var flash_light: DirectionalLight3D
var thunder: Array[AudioStreamPlayer] = []
var thunder_stream: AudioStreamWAV
## 0 = calm, 1 = full storm. `applied` is what is on screen now.
var blend: float = -1.0
var applied: float = -1.0
var eye: Vector3 = Vector3.ZERO
var bolt_left: float = 0.0
var flash: float = 0.0
## The ambient light the paint left, for the flash to add to.
var painted_ambient: float = -1.0
## Thunder still on its way: [{left, volume_db, pitch}].
var pending_thunder: Array[Dictionary] = []
var last_clock: float = NAN
## Counters the checks read.
var bolts_seen: int = 0
var thunder_played: int = 0
var last_bolt_at: Vector3 = Vector3.INF

func setup(biome: Node, cycle: Node) -> void:
	polar = biome
	day_night = cycle
	# Painted after the day/night, so a storm darkens the hour as it is.
	polar.overlays.append(self)
	build_rain()
	bolt = MeshInstance3D.new()
	bolt.name = "LightningBolt"
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.mesh = ImmediateMesh.new()
	var look: StandardMaterial3D = StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	look.albedo_color = BOLT_COLOR
	bolt.material_override = look
	bolt.visible = false
	add_child(bolt)
	flash_light = DirectionalLight3D.new()
	flash_light.name = "LightningFlash"
	flash_light.rotation_degrees = Vector3(-80, 0, 0)
	flash_light.light_color = BOLT_COLOR
	flash_light.light_energy = 0.0
	flash_light.visible = false
	add_child(flash_light)
	thunder_stream = thunder_sound()
	for index: int in 2:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = thunder_stream
		player.name = "Thunder%d" % index
		add_child(player)
		thunder.append(player)

func build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "StormRain"
	rain.amount = DROPS
	rain.lifetime = 0.9
	rain.preprocess = 0.9
	rain.local_coords = false
	rain.emitting = false
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.visibility_aabb = AABB(Vector3(-70, -60, -70), Vector3(140, 90, 140))
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(48, 2, 48)
	# Wind-driven: slanted, and faster than the city's drizzle.
	process.direction = Vector3(0.35, -1, 0.12)
	process.spread = 4.0
	process.initial_velocity_min = 36.0
	process.initial_velocity_max = 44.0
	process.gravity = Vector3(0, -6, 0)
	process.scale_min = 0.9
	process.scale_max = 1.4
	rain.process_material = process
	var streak: QuadMesh = QuadMesh.new()
	streak.size = Vector2(0.07, 1.9)
	var look: StandardMaterial3D = StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	look.billboard_keep_scale = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.78, 0.84, 0.92, 0.5)
	streak.material = look
	rain.draw_pass_1 = streak
	add_child(rain)

## Low rumble with a crack at the front: filtered noise, made once.
static func thunder_sound() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count: int = int(THUNDER_SECONDS * stream.mix_rate)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(count * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4006
	var low: float = 0.0
	var lower: float = 0.0
	for index: int in count:
		var t: float = float(index) / stream.mix_rate
		var noise: float = rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.05
		lower += (low - lower) * 0.02
		var crack: float = noise * exp(-t * 18.0) * 0.5
		# Rolls: a few swells in the rumble as it dies away.
		var roll: float = 0.65 + 0.35 * sin(TAU * 1.3 * t + 2.0 * sin(TAU * 0.4 * t))
		var rumble: float = (lower * 9.0 + low * 1.6) * roll * minf(1.0, t / 0.06) * exp(-t * 0.9)
		var wave: float = clampf((crack + rumble) * minf(1.0, (THUNDER_SECONDS - t) / 0.3), -1.0, 1.0)
		samples.encode_s16(index * 2, int(wave * 26000))
	stream.data = samples
	return stream

## Each frame, with the camera's position.
func update(at: Vector3, delta: float) -> void:
	eye = at
	var target: float = Storms.intensity_at(Vector3(at.x, 0.0, at.z))
	blend = target if blend < 0.0 else move_toward(blend, target, delta / EASE_SECONDS)
	if absf(blend - applied) > 0.003 or (blend != applied and blend in [0.0, 1.0]):
		applied = blend
		if polar.applied >= 0.0: polar.apply(polar.applied)
	if rain.emitting and polar.view_camera != null:
		var ahead: Vector3 = -polar.view_camera.global_basis.z
		ahead.y = 0.0
		rain.global_position = polar.view_camera.global_position + Vector3(0, 28, 0) + ahead.normalized() * 18.0
	lightning(delta)

## The bolts storms.gd struck since the last frame, near enough to see.
func lightning(delta: float) -> void:
	var clock: float = Storms.now()
	if is_nan(last_clock) or clock < last_clock or clock - last_clock > 5.0: last_clock = clock
	for strike: Dictionary in Storms.strikes(last_clock, clock):
		var spot: Vector3 = Progression.nearest(strike.at, eye)
		var away: float = Vector2(spot.x - eye.x, spot.z - eye.z).length()
		if away > VISIBLE_M: continue
		strike_at(spot, float(strike.time), away)
	last_clock = clock
	bolt_left = maxf(0.0, bolt_left - delta)
	bolt.visible = bolt_left > 0.0
	flash = maxf(0.0, flash - delta / FLASH_SECONDS)
	flash_light.visible = flash > 0.0
	# Flicker: a bolt lights up two or three times as it fades.
	flash_light.light_energy = flash * flash * (2.2 if fmod(flash * 7.0, 1.0) > 0.35 else 0.9)
	if painted_ambient >= 0.0 and polar.environment != null:
		polar.environment.ambient_light_energy = painted_ambient + flash * 0.9
	for index: int in range(pending_thunder.size() - 1, -1, -1):
		var wait: Dictionary = pending_thunder[index]
		wait.left -= delta
		if wait.left > 0.0: continue
		pending_thunder.remove_at(index)
		var player: AudioStreamPlayer = thunder[thunder_played % thunder.size()]
		player.volume_db = wait.volume_db
		player.pitch_scale = wait.pitch
		player.play()
		thunder_played += 1

func strike_at(spot: Vector3, time: float, away: float) -> void:
	bolts_seen += 1
	last_bolt_at = spot
	draw_bolt(spot, time)
	bolt_left = BOLT_SECONDS
	flash = maxf(flash, clampf(1.0 - away / VISIBLE_M, 0.25, 1.0))
	# Closer is louder, deeper further off, and late by the sound's travel.
	pending_thunder.append({"left": away / SOUND_MPS, "volume_db": lerpf(-4.0, -24.0, clampf(away / VISIBLE_M, 0.0, 1.0)), "pitch": lerpf(1.05, 0.8, clampf(away / VISIBLE_M, 0.0, 1.0))})

## A jagged ribbon from the cloud to the sea, turned to face the camera.
func draw_bolt(spot: Vector3, time: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([Storms.storm_seed, time])
	var points: PackedVector3Array = PackedVector3Array()
	var steps: int = 12
	var drift: Vector3 = Vector3.ZERO
	for index: int in steps + 1:
		var share: float = float(index) / steps
		if index > 0 and index < steps: drift += Vector3(rng.randf_range(-22.0, 22.0), 0.0, rng.randf_range(-22.0, 22.0))
		points.append(spot + Vector3(0, BOLT_TOP_M * (1.0 - share), 0) + drift * (1.0 - share * 0.3))
	var mesh: ImmediateMesh = bolt.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var width: float = clampf(Vector2(spot.x - eye.x, spot.z - eye.z).length() / 400.0, 2.0, 9.0)
	for index: int in steps:
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var toward: Vector3 = (eye - (a + b) * 0.5).normalized()
		var side: Vector3 = (b - a).cross(toward).normalized() * width * (1.0 - float(index) / steps * 0.6)
		for corner: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]: mesh.surface_add_vertex(corner)
	mesh.surface_end()

## The world wrapped: carry the rain over with the camera.
func shift(by: Vector3) -> void:
	eye += by
	if rain == null or not rain.emitting: return
	rain.global_position += by
	rain.restart()

## Lerps what the looks under it (biomes, then the hour) wrote toward the storm.
func paint() -> void:
	var value: float = maxf(applied, 0.0)
	var swell: float = Storms.swell_scale(value)
	Storms.swell = swell
	var ocean: OceanPresentation = polar.ocean
	if ocean != null and ocean.ocean_material != null: ocean.ocean_material.set_shader_parameter("swell_scale", swell)
	if rain != null:
		rain.amount_ratio = value
		var falling: bool = value > 0.02
		if falling != rain.emitting:
			if falling and polar.view_camera != null: rain.global_position = polar.view_camera.global_position + Vector3(0, 28, 0)
			rain.emitting = falling
	var environment: Environment = polar.environment
	if value <= 0.0:
		painted_ambient = environment.ambient_light_energy if environment != null else -1.0
		return
	var night: float = DayNight.weights(DayNight.now()).y
	var mix: float = value * 0.9
	environment.fog_light_color = environment.fog_light_color.lerp(DAY_HAZE.lerp(NIGHT_HAZE, night), mix)
	environment.fog_depth_begin = lerpf(environment.fog_depth_begin, 60.0, value)
	environment.fog_depth_end = lerpf(environment.fog_depth_end, 1100.0, value)
	environment.ambient_light_energy = lerpf(environment.ambient_light_energy, lerpf(0.5, 0.3, night), value)
	painted_ambient = environment.ambient_light_energy
	polar.sun.light_energy *= lerpf(1.0, 0.3, value)
	var sky: ShaderMaterial = polar.sky_material
	if sky != null:
		darken(sky, "top_color", DAY_TOP, NIGHT_TOP, night, mix)
		darken(sky, "horizon_color", DAY_HORIZON, NIGHT_HORIZON, night, mix)
		darken(sky, "cloud_shade_color", DAY_CLOUD_SHADE, NIGHT_CLOUD_SHADE, night, mix)
		darken(sky, "cloud_color", DAY_CLOUD, NIGHT_CLOUD, night, mix)
		sky.set_shader_parameter("cloud_cover", lerpf(float(polar.sky_param("cloud_cover")), 1.0, value))
		sky.set_shader_parameter("glow_amount", float(sky.get_shader_parameter("glow_amount")) * (1.0 - value))
	if ocean != null and ocean.ocean_material != null:
		darken(ocean.ocean_material, "deep_color", DAY_DEEP, NIGHT_DEEP, night, mix)
		darken(ocean.ocean_material, "surface_color", DAY_SURFACE, NIGHT_SURFACE, night, mix)

func darken(material: ShaderMaterial, key: String, day: Color, dark: Color, night: float, amount: float) -> void:
	var value: Variant = material.get_shader_parameter(key)
	if not value is Color and material == polar.sky_material: value = polar.sky_param(key)
	if not value is Color: return
	material.set_shader_parameter(key, (value as Color).lerp(day.lerp(dark, night), amount))

func _exit_tree() -> void:
	Storms.swell = 1.0
