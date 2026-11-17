extends RefCounted
## Aesthetics 2: swaps the plain materials under a node for the toon shader with
## an ink outline. Looks only. Transparent, unshaded and custom shader materials
## are left alone.
const TOON_SHADER: Shader = preload("res://features/toon/toon.gdshader")
const PORT_LIGHT: Shader = preload("res://features/toon/port_light.gdshader")
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

## Patch 3.0 B: one cached material copy for port-only distance fading. Boats,
## terrain and hangar models keep their original materials. Called once at boot.
static func port_horizon(root: Node, paints: Dictionary) -> void:
	if root is MeshInstance3D:
		var mesh: MeshInstance3D = root as MeshInstance3D
		if mesh.material_override != null:
			mesh.material_override = _horizon_paint(mesh.material_override, paints)
		elif mesh.mesh != null:
			for surface: int in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, _horizon_paint(mesh.get_active_material(surface), paints))
	elif root is MultiMeshInstance3D:
		var multi: MultiMeshInstance3D = root as MultiMeshInstance3D
		if multi.material_override != null:
			multi.material_override = _horizon_paint(multi.material_override, paints)
		elif multi.multimesh != null and multi.multimesh.mesh != null:
			multi.material_override = _horizon_paint(multi.multimesh.mesh.surface_get_material(0), paints)
	for child: Node in root.get_children(): port_horizon(child, paints)

static func _horizon_paint(source: Material, paints: Dictionary) -> Material:
	if source == null: return source
	if paints.has(source): return paints[source]
	if source is BaseMaterial3D and (source as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		var bulb: ShaderMaterial = ShaderMaterial.new()
		bulb.shader = PORT_LIGHT
		bulb.set_shader_parameter("albedo", (source as BaseMaterial3D).albedo_color)
		bulb.set_shader_parameter("port_distance_fade", true)
		paints[source] = bulb
		return bulb
	if not source is ShaderMaterial: return source
	var original: ShaderMaterial = source as ShaderMaterial
	if original.shader == null or not original.shader.code.contains("port_horizon.gdshaderinc"): return source
	var copy: ShaderMaterial = original.duplicate() as ShaderMaterial
	paints[source] = copy
	copy.set_shader_parameter("port_distance_fade", true)
	copy.next_pass = _horizon_paint(original.next_pass, paints)
	return copy
