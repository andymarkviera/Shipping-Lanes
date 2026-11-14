extends RefCounted
## Patch 2.5 item 1 part B: toon coasts. Looks only: the solid SHORE box under
## each land block is unchanged. A block becomes a low sloped beach with a green
## hill on top, and a ring of surf rides the swell at the waterline. Sides that
## another block covers stay flat, so a continent has one coast round it and no
## seams across it. Sides by a port get a straight harbour wall instead of a
## beach, so every quay still backs onto land at deck height.
## Every land block shares three materials (sand, top, surf), so the toon pass
## makes two shaders and the surf one; surf past SURF_RANGE_M is not drawn.
const SAND_TOP_Y: float = 4.0
const SAND_FOOT_Y: float = -4.0
const HILL_FOOT_Y: float = 3.8
const HILL_TOP_Y: float = 18.0
const BEACH_M: float = 36.0
const ICE_CLIFF_M: float = 12.0
const HILL_FOOT_M: float = 48.0
const HILL_TOP_M: float = 84.0
const HARBOUR_M: float = 320.0
const SURF_INLAND_M: float = 28.0
const SURF_SEAWARD_M: float = 6.0
const SURF_STEP_M: float = 12.0
const SURF_RANGE_M: float = 1500.0
const SURF_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 foam_color : source_color = vec4(1.0);
uniform float water_time = 0.0;
uniform int quality = 1;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Same numbers as OceanPresentation.swell_height, a little above it. Where
	// the beach is higher than the sea the sand hides the surf, so the white
	// line follows the waterline up and down the beach.
	float swell = 0.0;
	if (quality > 0) {
		swell += 0.55 * sin(world.x * 0.040 + world.z * 0.026 + water_time * 0.55);
		swell += 0.28 * sin(world.z * 0.070 - world.x * 0.018 - water_time * 0.80);
		if (quality > 1) swell += 0.10 * sin(world.x * 0.11 - world.z * 0.08 + water_time * 1.1);
	}
	VERTEX.y += swell + 0.12;
}
void fragment() {
	// UV.y runs 0 at sea to 1 inland: a toon foam band with a wavy sea edge.
	float edge = 0.32 + 0.12 * sin(water_time * 1.3 + world.x * 0.045 + world.z * 0.037);
	ALBEDO = foam_color.rgb;
	ALPHA = step(edge, UV.y);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

## Which sides of `rect` face open water (west, east, south, north): not
## covered by another of `blocks`.
static func sea_sides(rect: Rect2, blocks: Array) -> Array[bool]:
	var sea: Array[bool] = []
	for side: int in 4:
		var covered: bool = true
		for step: int in 5:
			var along: float = (step + 0.5) / 5.0
			var probe: Vector2 = [Vector2(rect.position.x - 2, rect.position.y + rect.size.y * along), Vector2(rect.end.x + 2, rect.position.y + rect.size.y * along), Vector2(rect.position.x + rect.size.x * along, rect.position.y - 2), Vector2(rect.position.x + rect.size.x * along, rect.end.y + 2)][side]
			covered = covered and blocks.any(func(other: Rect2) -> bool: return other != rect and other.has_point(probe))
		sea.append(not covered)
	return sea

## The two ends of one side of `rect`.
static func side_ends(rect: Rect2, side: int) -> Array[Vector2]:
	match side:
		0: return [rect.position, Vector2(rect.position.x, rect.end.y)]
		1: return [Vector2(rect.end.x, rect.position.y), rect.end]
		2: return [rect.position, Vector2(rect.end.x, rect.position.y)]
	return [Vector2(rect.position.x, rect.end.y), rect.end]

## Sides with a port close by get a harbour wall, not a beach.
static func harbour_sides(rect: Rect2, ports: Array[Vector2]) -> Array[bool]:
	var harbour: Array[bool] = []
	for side: int in 4:
		var ends: Array[Vector2] = side_ends(rect, side)
		harbour.append(ports.any(func(port: Vector2) -> bool: return Geometry2D.get_closest_point_to_segment(port, ends[0], ends[1]).distance_to(port) < HARBOUR_M))
	return harbour

static func _inset(rect: Rect2, by: Array[float]) -> Rect2:
	return Rect2(rect.position + Vector2(by[0], by[2]), rect.size - Vector2(by[0] + by[1], by[2] + by[3]))

## One triangle, wound so it faces `outward` (Godot fronts are clockwise).
static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.dot(outward) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	tool.set_normal(normal.normalized())
	for point: Vector3 in [a, b, c]: tool.add_vertex(point)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_triangle(tool, a, b, c, outward)
	_triangle(tool, a, c, d, outward)

## A sloped block, flat-shaded: `bottom` at y0 rising to `top` at y1, in the
## body's local space. Only the sides in `open` are built.
static func _slope(tool: SurfaceTool, bottom: Rect2, top: Rect2, y0: float, y1: float, open: Array[bool]) -> void:
	var low: Array[Vector3] = [Vector3(bottom.position.x, y0, bottom.position.y), Vector3(bottom.end.x, y0, bottom.position.y), Vector3(bottom.end.x, y0, bottom.end.y), Vector3(bottom.position.x, y0, bottom.end.y)]
	var high: Array[Vector3] = [Vector3(top.position.x, y1, top.position.y), Vector3(top.end.x, y1, top.position.y), Vector3(top.end.x, y1, top.end.y), Vector3(top.position.x, y1, top.end.y)]
	_quad(tool, high[0], high[1], high[2], high[3], Vector3.UP)
	# [corner a, corner b, outward]
	var faces: Array = [[0, 3, Vector3.LEFT], [1, 2, Vector3.RIGHT], [0, 1, Vector3.FORWARD], [3, 2, Vector3.BACK]]
	for side: int in 4:
		if not open[side]: continue
		var face: Array = faces[side]
		_quad(tool, low[face[0]], low[face[1]], high[face[1]], high[face[0]], face[2] + Vector3.UP * 0.01)

## The coast mesh for one block, centred on the block, y measured from the sea.
## Surface 0 is the beach (or ice), surface 1 the hilltop (or snow), if any.
static func land_mesh(rect: Rect2, sea: Array[bool], harbour: Array[bool], ice: bool, sand: Material, top: Material) -> ArrayMesh:
	var local: Rect2 = Rect2(-rect.size / 2, rect.size)
	var beach: Array[float] = []
	var foot: Array[float] = []
	var crest: Array[float] = []
	var walls: Array[bool] = []
	for side: int in 4:
		var slope: bool = sea[side] and not harbour[side]
		beach.append((ICE_CLIFF_M if ice else BEACH_M) if slope else 0.0)
		foot.append(HILL_FOOT_M if sea[side] else 0.0)
		crest.append(HILL_TOP_M if sea[side] else 0.0)
		# Covered sides get a wall too: it sits inside the neighbour and closes
		# the corner where a beach meets the next block.
		walls.append(true)
	var mesh: ArrayMesh = ArrayMesh.new()
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_slope(tool, local, _inset(local, beach), SAND_FOOT_Y, SAND_TOP_Y, walls)
	tool.set_material(sand)
	tool.commit(mesh)
	var hill_top: Rect2 = _inset(local, crest)
	if minf(hill_top.size.x, hill_top.size.y) >= 20.0:
		tool.clear()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_slope(tool, _inset(local, foot), hill_top, HILL_FOOT_Y, HILL_TOP_Y, walls)
		tool.set_material(top)
		tool.commit(mesh)
	return mesh

## The surf round one block's beaches, centred on the block, or null when the
## block has no beach.
static func surf_mesh(rect: Rect2, sea: Array[bool], harbour: Array[bool]) -> ArrayMesh:
	var local: Rect2 = Rect2(-rect.size / 2, rect.size)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var built: bool = false
	var inward: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for side: int in 4:
		if not sea[side] or harbour[side]: continue
		built = true
		var ends: Array[Vector2] = side_ends(local, side)
		var along: Vector2 = (ends[1] - ends[0]).normalized()
		var start: Vector2 = ends[0] - along * SURF_INLAND_M
		var length: float = ends[0].distance_to(ends[1]) + SURF_INLAND_M * 2.0
		var steps: int = maxi(1, ceili(length / SURF_STEP_M))
		var sea_off: Vector2 = -inward[side] * SURF_SEAWARD_M
		var land_off: Vector2 = inward[side] * SURF_INLAND_M
		for step: int in steps:
			var a: Vector2 = start + along * (length * step / steps)
			var b: Vector2 = start + along * (length * (step + 1) / steps)
			var corners: Array[Vector2] = [a + sea_off, b + sea_off, b + land_off, a + land_off]
			var uvs: Array[float] = [0.0, 0.0, 1.0, 1.0]
			for index: int in [0, 1, 2, 0, 2, 3]:
				tool.set_uv(Vector2(0, uvs[index]))
				tool.set_normal(Vector3.UP)
				tool.add_vertex(Vector3(corners[index].x, 0, corners[index].y))
	if not built: return null
	var mesh: ArrayMesh = ArrayMesh.new()
	tool.commit(mesh)
	return mesh

static func surf_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = SURF_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material
