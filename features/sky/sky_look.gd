extends RefCounted
## Aesthetics 3: sky and lighting for the game scene. Looks only.
## apply() sets the cartoon sky, a warm sun with shadows, soft blue ambient
## light and a light haze that fades far water into the horizon.
const SKY_SHADER: Shader = preload("res://features/sky/toon_sky.gdshader")
const HORIZON := Color(0.70, 0.93, 0.98)
const SUN := Color(1.0, 0.94, 0.80)
const AMBIENT := Color(0.62, 0.78, 1.0)

static func apply(sun: DirectionalLight3D, environment: Environment) -> void:
	sun.light_color = SUN
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_blur = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 500.0
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("horizon_color", HORIZON)
	var sky: Sky = Sky.new()
	sky.sky_material = material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	# Flat colour ambient and no sky reflections: cheap, and it suits the toon bands.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT
	environment.ambient_light_energy = 0.6
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = HORIZON
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.0
	environment.fog_density = 0.9
	environment.fog_depth_begin = 500.0
	environment.fog_depth_end = 2800.0
	environment.fog_depth_curve = 1.6
	environment.fog_sky_affect = 0.0
	environment.fog_aerial_perspective = 0.0
