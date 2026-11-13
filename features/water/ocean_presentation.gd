class_name OceanPresentation
extends MeshInstance3D
const OCEAN_SHADER: Shader = preload("res://features/water/stylized_ocean.gdshader")
@export var palette: WaterPalette = preload("res://features/water/bright_ocean.tres")
var quality: int = 1
var elapsed: float = 0.0
var ocean_material: ShaderMaterial

## Rolling swell height in metres above the still water. The ocean and foam
## shaders repeat these numbers, so a hull that reads this rides the drawn water.
static func swell_height(x: float, z: float, time: float, tier: int) -> float:
	if tier <= 0: return 0.0
	var height: float = 0.55 * sin(x * 0.040 + z * 0.026 + time * 0.55)
	height += 0.28 * sin(z * 0.070 - x * 0.018 - time * 0.80)
	if tier > 1: height += 0.10 * sin(x * 0.11 - z * 0.08 + time * 1.1)
	return height

func _ready() -> void:
	ocean_material = ShaderMaterial.new()
	ocean_material.shader = OCEAN_SHADER
	material_override = ocean_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 0.5
	apply_palette(palette)
	set_quality(quality)

func apply_palette(value: WaterPalette) -> void:
	palette = value
	if ocean_material == null: return
	ocean_material.set_shader_parameter("deep_color", palette.deep_color)
	ocean_material.set_shader_parameter("surface_color", palette.surface_color)
	ocean_material.set_shader_parameter("foam_color", palette.foam_color)

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	if ocean_material == null: return
	var surface: PlaneMesh = PlaneMesh.new()
	surface.size = Vector2(4000, 4000)
	var divisions: int = [0, 256, 384][quality]
	surface.subdivide_width = divisions
	surface.subdivide_depth = divisions
	mesh = surface
	ocean_material.set_shader_parameter("quality", quality)

func _process(delta: float) -> void:
	elapsed += delta
	ocean_material.set_shader_parameter("water_time", elapsed)
