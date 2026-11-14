extends Node
## Patch 2.5 item 5: the tropical biome. Looks only. The southern strait round
## Gannet Light and the Palm Isles is tropical: a bright saturated grade, clear
## air, a vivid sky and a turquoise sea, and (features/toon/tropical_look.gd)
## palms, lush green coasts, turquoise lagoon rings and a tropical port. The
## lagoons are paint on the water, not shallows: nothing there slows, grounds
## or blocks a ship. The blend follows the ship's distance to the region's
## centre over a FADE band and is eased in time, like the desert. It is painted
## on top of the polar look (polar_biome.gd calls paint() after every repaint),
## after the desert, so the biomes never fight over the sky, sea or fog.
const Progression = preload("res://features/game/progression.gd")
const Polar = preload("res://features/sky/polar_biome.gd")
## The region's centre (x, z), metres: the southern strait, west of Gannet Light.
const CENTRE := Vector2(1000, -2300)
## Fully tropical within FULL_M of the centre (Gannet Light inside), none past CLEAR_M.
const FULL_M: float = 1250.0
const CLEAR_M: float = 1900.0
const EASE_SECONDS: float = 1.5

const HAZE := Color(0.70, 0.94, 0.96)
const AMBIENT := Color(0.84, 0.97, 1.0)
const SUN := Color(1.0, 0.97, 0.86)
const SKY_TOP := Color(0.02, 0.40, 0.95)
const SKY_HORIZON := Color(0.60, 0.96, 0.98)
const CLOUD_SHADE := Color(0.86, 0.95, 1.0)
const DEEP := Color(0.0, 0.50, 0.66)
const SURFACE := Color(0.10, 0.84, 0.84)
## Bright grade: shadows a touch teal, highlights a touch sunny.
const GRADE_LOW := Color(0.0, 0.03, 0.035)
const GRADE_HIGH := Color(1.0, 1.0, 0.94)

## The polar biome it paints over (it owns the base look and the grade ramp).
var polar: Node
## 0 = not tropical, 1 = fully tropical. `applied` is what is on screen now.
var blend: float = -1.0
var applied: float = -1.0

## Where the tropical look is, 0..1, for a world position (any copy across the
## wrap). Never inside the polar sea.
static func weight(at: Vector3) -> float:
	var way: Vector3 = Progression.short_way(at - Vector3(CENTRE.x, 0, CENTRE.y))
	return smoothstep(CLEAR_M, FULL_M, Vector2(way.x, way.z).length()) * (1.0 - Polar.weight(at))

func setup(under: Node) -> void:
	polar = under
	polar.overlays.append(self)

## The ship's position this frame. Eases the blend and repaints only on change.
func update(at: Vector3, delta: float) -> void:
	var target: float = weight(at)
	blend = target if blend < 0.0 else move_toward(blend, target, delta / EASE_SECONDS)
	if absf(blend - applied) > 0.002 or (blend != applied and blend in [0.0, 1.0]):
		applied = blend
		# The polar look repaints from its base and then calls paint().
		if polar.applied >= 0.0: polar.apply(polar.applied)

## Lerps what the looks under it just wrote toward the tropics. At 0 it changes nothing.
func paint() -> void:
	var value: float = applied
	if value <= 0.0: return
	var environment: Environment = polar.environment
	environment.fog_light_color = environment.fog_light_color.lerp(HAZE, value)
	environment.fog_depth_begin = lerpf(environment.fog_depth_begin, 420.0, value)
	environment.fog_depth_end = lerpf(environment.fog_depth_end, 3400.0, value)
	environment.ambient_light_color = environment.ambient_light_color.lerp(AMBIENT, value)
	environment.ambient_light_energy = lerpf(environment.ambient_light_energy, 0.8, value)
	polar.sun.light_color = polar.sun.light_color.lerp(SUN, value)
	polar.sun.light_energy = lerpf(polar.sun.light_energy, 1.25, value)
	var sky: ShaderMaterial = polar.sky_material
	if sky != null:
		sky.set_shader_parameter("top_color", (polar.sky_param("top_color") as Color).lerp(SKY_TOP, value))
		sky.set_shader_parameter("horizon_color", (polar.sky_param("horizon_color") as Color).lerp(SKY_HORIZON, value))
		sky.set_shader_parameter("cloud_shade_color", (polar.sky_param("cloud_shade_color") as Color).lerp(CLOUD_SHADE, value))
		sky.set_shader_parameter("cloud_cover", lerpf(float(polar.sky_param("cloud_cover")), 0.45, value))
	var ocean: OceanPresentation = polar.ocean
	if ocean != null and ocean.ocean_material != null and polar.base.has("deep"):
		var deep: Variant = ocean.ocean_material.get_shader_parameter("deep_color")
		var surface: Variant = ocean.ocean_material.get_shader_parameter("surface_color")
		if deep is Color: ocean.ocean_material.set_shader_parameter("deep_color", (deep as Color).lerp(DEEP, value))
		if surface is Color: ocean.ocean_material.set_shader_parameter("surface_color", (surface as Color).lerp(SURFACE, value))
	# Bright, saturated and sunny. Grading on only while it shows.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = lerpf(environment.adjustment_saturation, 1.18, value)
	environment.adjustment_contrast = lerpf(environment.adjustment_contrast, 1.04, value)
	environment.adjustment_brightness = lerpf(environment.adjustment_brightness, 1.03, value)
	var grade: Gradient = polar.grade
	grade.set_color(0, grade.get_color(0).lerp(GRADE_LOW, value))
	grade.set_color(1, grade.get_color(1).lerp(GRADE_HIGH, value))
