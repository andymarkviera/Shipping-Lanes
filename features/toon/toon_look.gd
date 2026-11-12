extends RefCounted
## Aesthetics 2: swaps the plain materials under a node for the toon shader with
## an ink outline. Looks only. Transparent, unshaded and custom shader materials
## are left alone.
const TOON_SHADER: Shader = preload("res://features/toon/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://features/toon/toon_outline.gdshader")

static func outline(box_corners: bool) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("box_corners", 1.0 if box_corners else 0.0)
	return material

## Returns null when the source should keep its own look.
static func toon_from(source: Material, box_corners: bool) -> ShaderMaterial:
	var base: BaseMaterial3D = source as BaseMaterial3D
	if base == null or base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return null
	if base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: return null
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = TOON_SHADER
	material.set_shader_parameter("albedo", base.albedo_color)
	material.set_shader_parameter("albedo_texture", base.albedo_texture)
	material.set_shader_parameter("use_vertex_color", base.vertex_color_use_as_albedo)
	material.next_pass = outline(box_corners)
	return material

static func apply(root: Node) -> void:
	_walk(root, {})

static func _cached(source: Material, box_corners: bool, done: Dictionary) -> ShaderMaterial:
	if source == null: return null
	var key: Array = [source, box_corners]
	if not done.has(key): done[key] = toon_from(source, box_corners)
	return done[key] as ShaderMaterial

static func _walk(node: Node, done: Dictionary) -> void:
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	var multi_node: MultiMeshInstance3D = node as MultiMeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		var box: bool = mesh_node.mesh is BoxMesh
		if mesh_node.material_override != null:
			var replaced: ShaderMaterial = _cached(mesh_node.material_override, box, done)
			if replaced != null: mesh_node.material_override = replaced
		else:
			for surface: int in mesh_node.mesh.get_surface_count():
				var toon: ShaderMaterial = _cached(mesh_node.get_active_material(surface), box, done)
				if toon != null: mesh_node.set_surface_override_material(surface, toon)
	elif multi_node != null and multi_node.material_override == null and multi_node.multimesh != null and multi_node.multimesh.mesh != null:
		var shared: ShaderMaterial = _cached(multi_node.multimesh.mesh.surface_get_material(0), false, done)
		if shared != null: multi_node.material_override = shared
	for child: Node in node.get_children():
		_walk(child, done)
