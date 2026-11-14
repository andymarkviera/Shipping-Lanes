extends Node
## Patch 2.5 item 6: the rainy city port biome. Looks only. Ironreach's west
## coast round Slatewater Works is a big city port where it always rains: a wet,
## darker grade, low grey cloud, murky fog, rain falling round the camera from
## one pooled emitter, rain rings on the sea (a uniform in the ocean shader, off
## everywhere else) and (features/toon/city_look.gd) a skyline with lit windows
## and tower cranes. The blend follows the ship's distance to the region's
## centre over a FADE band and is eased in time, like the other biomes. It is
## painted on top of the polar look (polar_biome.gd calls paint() after every
## repaint), after the desert and the tropics; the regions never overlap.
const Progression = preload("res://features/game/progression.gd")
const Polar = preload("res://features/sky/polar_biome.gd")
## The region's centre (x, z), metres: Ironreach's west coast, behind Slatewater Works.
const CENTRE := Vector2(1650, 700)
## Fully rainy within FULL_M of the centre (Slatewater Works inside), none past
## CLEAR_M. Brindle Quay, the start, stays dry; the tropics begin past CLEAR_M.
const FULL_M: float = 740.0
const CLEAR_M: float = 1150.0
const EASE_SECONDS: float = 1.5
const DROPS: int = 1600

const HAZE := Color(0.53, 0.59, 0.65)
const AMBIENT := Color(0.62, 0.68, 0.78)
const SUN := Color(0.78, 0.82, 0.90)
const SKY_TOP := Color(0.30, 0.36, 0.44)
const SKY_HORIZON := Color(0.62, 0.67, 0.72)
const CLOUD_SHADE := Color(0.46, 0.50, 0.57)
const DEEP := Color(0.05, 0.20, 0.30)
const SURFACE := Color(0.20, 0.37, 0.45)
## Wet grade: shadows a touch blue, highlights a touch dimmer and cooler.
const GRADE_LOW := Color(0.0, 0.015, 0.04)
const GRADE_HIGH := Color(0.86, 0.92, 1.0)
## How bright the city's lit windows are, dry and in the rain.
const GLOW_DRY: float = 0.7
const GLOW_WET: float = 1.6

## The polar biome it paints over (it owns the base look and the grade ramp).
var polar: Node
## The one rain emitter, made once and reused (never spawned per drop).
var rain: GPUParticles3D
## The city's window paint (city_look.gd); it glows brighter in the rain.
var windows: Array[ShaderMaterial] = []
## 0 = dry, 1 = fully rainy. `applied` is what is on screen now.
var blend: float = -1.0
var applied: float = -1.0

## Where the rainy look is, 0..1, for a world position (any copy across the
## wrap). Never inside the polar sea.
static func weight(at: Vector3) -> float:
	var way: Vector3 = Progression.short_way(at - Vector3(CENTRE.x, 0, CENTRE.y))
	return smoothstep(CLEAR_M, FULL_M, Vector2(way.x, way.z).length()) * (1.0 - Polar.weight(at))

func setup(under: Node) -> void:
	polar = under
	polar.overlays.append(self)
	build_rain()

func build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "CityRain"
	rain.amount = DROPS
	rain.lifetime = 1.1
	# A restart (after the world wraps) starts with a full fall of rain.
	rain.preprocess = 1.1
	rain.local_coords = false
	rain.emitting = false
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.visibility_aabb = AABB(Vector3(-60, -50, -60), Vector3(120, 80, 120))
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(42, 2, 42)
	process.direction = Vector3(0.12, -1, 0.05)
	process.spread = 3.0
	process.initial_velocity_min = 28.0
	process.initial_velocity_max = 34.0
	process.gravity = Vector3(0, -4, 0)
	process.scale_min = 0.8
	process.scale_max = 1.2
	rain.process_material = process
	var streak: QuadMesh = QuadMesh.new()
	streak.size = Vector2(0.06, 1.5)
	var look: StandardMaterial3D = StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Upright streaks that turn to face the camera.
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	look.billboard_keep_scale = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.82, 0.88, 0.96, 0.45)
	streak.material = look
	rain.draw_pass_1 = streak
	add_child(rain)

## The ship's position this frame. Eases the blend and repaints only on change.
func update(at: Vector3, delta: float) -> void:
	var target: float = weight(at)
	blend = target if blend < 0.0 else move_toward(blend, target, delta / EASE_SECONDS)
	if absf(blend - applied) > 0.002 or (blend != applied and blend in [0.0, 1.0]):
		applied = blend
		# The polar look repaints from its base and then calls paint().
		if polar.applied >= 0.0: polar.apply(polar.applied)
	if rain.emitting and polar.view_camera != null:
		# New drops start above and a little ahead of the camera.
		var ahead: Vector3 = -polar.view_camera.global_basis.z
		ahead.y = 0.0
		rain.global_position = polar.view_camera.global_position + Vector3(0, 26, 0) + ahead.normalized() * 18.0

## The world wrapped: carry the falling rain over with the ship.
func shift(by: Vector3) -> void:
	if rain == null or not rain.emitting: return
	rain.global_position += by
	rain.restart()

## Lerps what the looks under it just wrote toward the rain. At 0 it changes
## nothing but switching the rain, the rings and the window glow off.
func paint() -> void:
	var value: float = maxf(applied, 0.0)
	var ocean: OceanPresentation = polar.ocean
	if ocean != null and ocean.ocean_material != null: ocean.ocean_material.set_shader_parameter("rain_amount", value)
	for paint_of: ShaderMaterial in windows: paint_of.set_shader_parameter("glow", lerpf(GLOW_DRY, GLOW_WET, value))
	if rain != null:
		rain.amount_ratio = value
		var falling: bool = value > 0.01
		if falling != rain.emitting:
			if falling and polar.view_camera != null: rain.global_position = polar.view_camera.global_position + Vector3(0, 26, 0)
			rain.emitting = falling
	if value <= 0.0: return
	var environment: Environment = polar.environment
	environment.fog_light_color = environment.fog_light_color.lerp(HAZE, value)
	environment.fog_depth_begin = lerpf(environment.fog_depth_begin, 90.0, value)
	environment.fog_depth_end = lerpf(environment.fog_depth_end, 1500.0, value)
	environment.ambient_light_color = environment.ambient_light_color.lerp(AMBIENT, value)
	environment.ambient_light_energy = lerpf(environment.ambient_light_energy, 0.62, value)
	polar.sun.light_color = polar.sun.light_color.lerp(SUN, value)
	polar.sun.light_energy = lerpf(polar.sun.light_energy, 0.55, value)
	var sky: ShaderMaterial = polar.sky_material
	if sky != null:
		sky.set_shader_parameter("top_color", (polar.sky_param("top_color") as Color).lerp(SKY_TOP, value))
		sky.set_shader_parameter("horizon_color", (polar.sky_param("horizon_color") as Color).lerp(SKY_HORIZON, value))
		sky.set_shader_parameter("cloud_shade_color", (polar.sky_param("cloud_shade_color") as Color).lerp(CLOUD_SHADE, value))
		sky.set_shader_parameter("cloud_cover", lerpf(float(polar.sky_param("cloud_cover")), 1.0, value))
	if ocean != null and ocean.ocean_material != null and polar.base.has("deep"):
		var deep: Variant = ocean.ocean_material.get_shader_parameter("deep_color")
		var surface: Variant = ocean.ocean_material.get_shader_parameter("surface_color")
		if deep is Color: ocean.ocean_material.set_shader_parameter("deep_color", (deep as Color).lerp(DEEP, value))
		if surface is Color: ocean.ocean_material.set_shader_parameter("surface_color", (surface as Color).lerp(SURFACE, value))
	# Wet: darker, a little desaturated, a touch more contrast. On only while it shows.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = lerpf(environment.adjustment_saturation, 0.78, value)
	environment.adjustment_contrast = lerpf(environment.adjustment_contrast, 1.06, value)
	environment.adjustment_brightness = lerpf(environment.adjustment_brightness, 0.86, value)
	var grade: Gradient = polar.grade
	grade.set_color(0, grade.get_color(0).lerp(GRADE_LOW, value))
	grade.set_color(1, grade.get_color(1).lerp(GRADE_HIGH, value))
