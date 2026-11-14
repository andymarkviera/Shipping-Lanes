extends Node
## Patch 2.5 item 3: the North Pole biome. Looks only. Sailing into the polar
## sea blends in a colder look: cooler grading, a paler sky and sea, a little
## fog and light snow falling round the camera. The world wraps north-south,
## so the polar band runs across the north/south edge and both polar seas (and
## their icebergs and ports) share it; there is no seam at the edge.
## The blend follows the ship's distance to that edge, over a FADE band, and is
## eased in time too, so a debug quick travel fades rather than snaps.
const Progression = preload("res://features/game/progression.gd")
## Fully polar this close to the north/south edge (both polar ports inside),
## no polar look beyond CLEAR_EDGE_M. Metres.
const FULL_EDGE_M: float = 2350.0
const CLEAR_EDGE_M: float = 2950.0
## A whole fade takes at least this long, even after a jump.
const EASE_SECONDS: float = 1.5

const POLAR_FOG := Color(0.84, 0.91, 0.96)
const POLAR_AMBIENT := Color(0.74, 0.84, 1.0)
const POLAR_SUN := Color(0.93, 0.96, 1.0)
const POLAR_SKY_TOP := Color(0.42, 0.62, 0.86)
const POLAR_SKY_HORIZON := Color(0.88, 0.94, 0.98)
const POLAR_CLOUD_SHADE := Color(0.82, 0.88, 0.95)
const POLAR_DEEP := Color(0.26, 0.50, 0.68)
const POLAR_SURFACE := Color(0.62, 0.84, 0.92)
## Cool grade: shadows a touch blue, highlights a touch less warm.
const POLAR_GRADE_LOW := Color(0.0, 0.02, 0.05)
const POLAR_GRADE_HIGH := Color(0.92, 0.97, 1.0)
const SNOW_FLAKES: int = 900
## toon_sky.gdshader's own defaults, for parameters the sky look leaves unset.
const SKY_DEFAULTS = {"top_color": Color(0.05, 0.33, 0.87), "horizon_color": Color(0.70, 0.93, 0.98), "cloud_shade_color": Color(0.76, 0.88, 0.99), "cloud_cover": 0.6}

var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var ocean: OceanPresentation
var view_camera: Camera3D
## The one snow emitter, made once and reused (never spawned per flake).
var snow: GPUParticles3D
var grade: Gradient
## 0 = temperate, 1 = fully polar. `applied` is what is on screen now.
var blend: float = -1.0
var applied: float = -1.0
var base: Dictionary = {}

## Where the polar look is, 0..1, for a world position (any copy across the wrap).
static func weight(at: Vector3) -> float:
	var edge: float = Progression.WRAP_M / 2.0 - absf(Progression.short_way(at - Progression.WRAP_CENTRE).z)
	return smoothstep(CLEAR_EDGE_M, FULL_EDGE_M, edge)

func setup(world: Environment, light: DirectionalLight3D, sea: OceanPresentation, eye: Camera3D) -> void:
	environment = world
	sun = light
	ocean = sea
	view_camera = eye
	if environment.sky != null: sky_material = environment.sky.sky_material as ShaderMaterial
	base = {
		"fog": environment.fog_light_color, "fog_begin": environment.fog_depth_begin, "fog_end": environment.fog_depth_end,
		"ambient": environment.ambient_light_color, "ambient_energy": environment.ambient_light_energy,
		"sun": sun.light_color, "sun_energy": sun.light_energy,
	}
	if sky_material != null:
		for key: String in ["top_color", "horizon_color", "cloud_shade_color", "cloud_cover"]: base[key] = sky_param(key)
	if ocean != null and ocean.palette != null:
		base["deep"] = ocean.palette.deep_color
		base["surface"] = ocean.palette.surface_color
	grade = Gradient.new()
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = grade
	environment.adjustment_color_correction = ramp
	build_snow()

func sky_param(key: String) -> Variant:
	var value: Variant = sky_material.get_shader_parameter(key)
	if value == null: value = RenderingServer.shader_get_parameter_default(sky_material.shader.get_rid(), key)
	# vec3 colours come back as Vector3; a headless run may give no default.
	if value is Vector3: value = Color(value.x, value.y, value.z)
	if value == null: value = SKY_DEFAULTS[key]
	return value

func build_snow() -> void:
	snow = GPUParticles3D.new()
	snow.name = "PolarSnow"
	snow.amount = SNOW_FLAKES
	snow.lifetime = 7.0
	# A restart (after the world wraps) starts with a full fall of snow.
	snow.preprocess = 7.0
	snow.local_coords = false
	snow.emitting = false
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow.visibility_aabb = AABB(Vector3(-80, -60, -80), Vector3(160, 90, 160))
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(36, 2, 36)
	process.direction = Vector3(0.25, -1, 0.1)
	process.spread = 12.0
	process.initial_velocity_min = 2.5
	process.initial_velocity_max = 4.0
	process.gravity = Vector3(0, -0.8, 0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	snow.process_material = process
	var flake: QuadMesh = QuadMesh.new()
	flake.size = Vector2(0.3, 0.3)
	var look: StandardMaterial3D = StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	look.alpha_scissor_threshold = 0.5
	var dot: GradientTexture2D = GradientTexture2D.new()
	dot.width = 16
	dot.height = 16
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = fade
	look.albedo_texture = dot
	look.albedo_color = Color(0.97, 0.99, 1.0)
	flake.material = look
	snow.draw_pass_1 = flake
	add_child(snow)

## The ship's position this frame. Eases the blend and repaints only on change.
func update(at: Vector3, delta: float) -> void:
	var target: float = weight(at)
	blend = target if blend < 0.0 else move_toward(blend, target, delta / EASE_SECONDS)
	if absf(blend - applied) > 0.002 or (blend != applied and blend in [0.0, 1.0]): apply(blend)
	if snow.emitting and view_camera != null:
		# New flakes start above and a little ahead of the camera.
		var ahead: Vector3 = -view_camera.global_basis.z
		ahead.y = 0.0
		snow.global_position = view_camera.global_position + Vector3(0, 22, 0) + ahead.normalized() * 14.0

## The world wrapped: carry the falling snow over with the ship.
func shift(by: Vector3) -> void:
	if snow == null or not snow.emitting: return
	snow.global_position += by
	snow.restart()

func apply(value: float) -> void:
	applied = value
	environment.fog_light_color = (base.fog as Color).lerp(POLAR_FOG, value)
	environment.fog_depth_begin = lerpf(base.fog_begin, 160.0, value)
	environment.fog_depth_end = lerpf(base.fog_end, 1900.0, value)
	environment.ambient_light_color = (base.ambient as Color).lerp(POLAR_AMBIENT, value)
	environment.ambient_light_energy = lerpf(base.ambient_energy, 0.7, value)
	sun.light_color = (base.sun as Color).lerp(POLAR_SUN, value)
	sun.light_energy = lerpf(base.sun_energy, 1.0, value)
	if sky_material != null:
		sky_material.set_shader_parameter("top_color", (base.top_color as Color).lerp(POLAR_SKY_TOP, value))
		sky_material.set_shader_parameter("horizon_color", (base.horizon_color as Color).lerp(POLAR_SKY_HORIZON, value))
		sky_material.set_shader_parameter("cloud_shade_color", (base.cloud_shade_color as Color).lerp(POLAR_CLOUD_SHADE, value))
		sky_material.set_shader_parameter("cloud_cover", lerpf(base.cloud_cover, 0.8, value))
	if ocean != null and ocean.ocean_material != null and base.has("deep"):
		ocean.ocean_material.set_shader_parameter("deep_color", (base.deep as Color).lerp(POLAR_DEEP, value))
		ocean.ocean_material.set_shader_parameter("surface_color", (base.surface as Color).lerp(POLAR_SURFACE, value))
	# Colour grading only while it shows, so the temperate world costs nothing.
	environment.adjustment_enabled = value > 0.0
	environment.adjustment_saturation = lerpf(1.0, 0.82, value)
	environment.adjustment_contrast = lerpf(1.0, 0.96, value)
	environment.adjustment_brightness = lerpf(1.0, 1.03, value)
	grade.set_color(0, Color.BLACK.lerp(POLAR_GRADE_LOW, value))
	grade.set_color(1, Color.WHITE.lerp(POLAR_GRADE_HIGH, value))
	snow.amount_ratio = value
	var falling: bool = value > 0.01
	if falling != snow.emitting:
		if falling and view_camera != null: snow.global_position = view_camera.global_position + Vector3(0, 22, 0)
		snow.emitting = falling
