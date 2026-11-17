extends Node
## Patch 2.5 item 4: the desert biome. Looks only. The north of Hearthland,
## round Cinder Point, is desert: a warm hazy grade, a dry palette, a sandy
## sky and sea, and (features/toon/desert_look.gd) dunes, mesas and a desert
## port. The blend follows the ship's distance to the desert's centre, over a
## FADE band, and is eased in time, so a debug quick travel fades, not snaps.
## It is painted on top of the polar look (polar_biome.gd calls paint() after
## every repaint), so the two biomes never fight over the sky, sea or fog.
const Progression = preload("res://features/game/progression.gd")
const Polar = preload("res://features/sky/polar_biome.gd")
## The desert's centre (x, z), metres: the dry heart of north Hearthland.
const CENTRE := Vector2(-1710, 1950)
## Fully desert within FULL_M of the centre (Cinder Point inside), none past CLEAR_M.
const FULL_M: float = 1600.0
const CLEAR_M: float = 2300.0
const EASE_SECONDS: float = 1.5

const HAZE := Color(0.96, 0.84, 0.64)
const AMBIENT := Color(1.0, 0.88, 0.72)
const SUN := Color(1.0, 0.88, 0.66)
const SKY_TOP := Color(0.30, 0.55, 0.84)
const SKY_HORIZON := Color(0.98, 0.86, 0.66)
const CLOUD_SHADE := Color(0.98, 0.88, 0.76)
const DEEP := Color(0.10, 0.40, 0.58)
const SURFACE := Color(0.44, 0.76, 0.78)
## Warm grade: shadows a touch amber, highlights a touch golden.
const GRADE_LOW := Color(0.05, 0.025, 0.0)
const GRADE_HIGH := Color(1.0, 0.95, 0.84)

## The polar biome it paints over (it owns the base look and the grade ramp).
var polar: Node
## 0 = not desert, 1 = fully desert. `applied` is what is on screen now.
var blend: float = -1.0
var applied: float = -1.0

## Where the desert look is, 0..1, for a world position (any copy across the
## wrap). Never inside the polar sea.
static func weight(at: Vector3) -> float:
	var way: Vector3 = Progression.short_way(at - Vector3(CENTRE.x, 0, CENTRE.y))
	return smoothstep(CLEAR_M, FULL_M, Vector2(way.x, way.z).length()) * (1.0 - Polar.weight(at))

func setup(under: Node) -> void:
	polar = under
	polar.overlay = self

## The ship's position this frame. Eases the blend and repaints only on change.
func update(at: Vector3, delta: float) -> void:
	var target: float = weight(at)
	blend = target if blend < 0.0 else move_toward(blend, target, delta / EASE_SECONDS)
	if absf(blend - applied) > 0.002 or (blend != applied and blend in [0.0, 1.0]):
		applied = blend
		# The polar look repaints from its base and then calls paint().
		if polar.applied >= 0.0: polar.apply(polar.applied)

## Lerps what the polar look just wrote toward the desert. At 0 it changes nothing.
func paint() -> void:
	var value: float = applied
	if value <= 0.0: return
	var environment: Environment = polar.environment
	environment.fog_light_color = environment.fog_light_color.lerp(HAZE, value)
	environment.fog_depth_begin = lerpf(environment.fog_depth_begin, 220.0, value)
	environment.fog_depth_end = lerpf(environment.fog_depth_end, 2300.0, value)
	environment.ambient_light_color = environment.ambient_light_color.lerp(AMBIENT, value)
	environment.ambient_light_energy = lerpf(environment.ambient_light_energy, 0.78, value)
	polar.sun.light_color = polar.sun.light_color.lerp(SUN, value)
	polar.sun.light_energy = lerpf(polar.sun.light_energy, 1.15, value)
	var sky: ShaderMaterial = polar.sky_material
	if sky != null:
		sky.set_shader_parameter("top_color", (polar.sky_param("top_color") as Color).lerp(SKY_TOP, value))
		sky.set_shader_parameter("horizon_color", (polar.sky_param("horizon_color") as Color).lerp(SKY_HORIZON, value))
		sky.set_shader_parameter("cloud_shade_color", (polar.sky_param("cloud_shade_color") as Color).lerp(CLOUD_SHADE, value))
		sky.set_shader_parameter("cloud_cover", lerpf(float(polar.sky_param("cloud_cover")), 0.3, value))
	var ocean: OceanPresentation = polar.ocean
	if ocean != null and ocean.ocean_material != null and polar.base.has("deep"):
		var deep: Variant = ocean.ocean_material.get_shader_parameter("deep_color")
		var surface: Variant = ocean.ocean_material.get_shader_parameter("surface_color")
		if deep is Color: ocean.ocean_material.set_shader_parameter("deep_color", (deep as Color).lerp(DEEP, value))
		if surface is Color: ocean.ocean_material.set_shader_parameter("surface_color", (surface as Color).lerp(SURFACE, value))
	# Dry, warm and a little hazy-bright. Grading on only while it shows.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = lerpf(environment.adjustment_saturation, 0.9, value)
	environment.adjustment_contrast = lerpf(environment.adjustment_contrast, 0.97, value)
	environment.adjustment_brightness = lerpf(environment.adjustment_brightness, 1.04, value)
	var grade: Gradient = polar.grade
	grade.set_color(0, grade.get_color(0).lerp(GRADE_LOW, value))
	grade.set_color(1, grade.get_color(1).lerp(GRADE_HIGH, value))
