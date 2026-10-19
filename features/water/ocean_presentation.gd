class_name OceanPresentation
extends MeshInstance3D
const OCEAN_SHADER: Shader = preload("res://features/water/stylized_ocean.gdshader")
@export var palette: WaterPalette = preload("res://features/water/bright_ocean.tres")
var quality: int = 1
var elapsed: float = 0.0
var ocean_material: ShaderMaterial

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
