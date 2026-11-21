extends RefCounted
## Patch 2.5 item 5: the tropics' dressing. Looks only: nothing here is solid,
## so the land's colliders, the navigation and every berth stay as they were.
## Palms line the beaches and crowd the green hill tops of the tropical land
## (the Palm Isles, the strait islet and the coast behind Gannet Light), with
## lush bushes between them, as a few MultiMeshes (one draw call per kind).
## The islands sit in turquoise lagoon rings: paint riding the swell on the
## water, not shallows, so a ship sails over them as over any open sea. The
## port in the tropics gets a whitewashed quay, pastel sheds under thatch,
## stilt huts and palms. Placement is seeded, so it is the same every run.
const Chunky = preload("res://features/toon/chunky_look.gd")
const Coast = preload("res://features/toon/toon_coast.gd")
const Tropical = preload("res://features/sky/tropical_biome.gd")
const Progression = preload("res://features/game/progression.gd")
## Patch 4.0.2 item 4: no palm or bush on an airfield.
const Airports = preload("res://features/planes/airports.gd")
## A palm's crown reaches about this far from its foot.
const PALM_REACH_M: float = 12.0
const SEED: int = 2505
## The flat sand between the beach slope and the hill (toon_coast.gd).
const BEACH_Y: float = 3.9
const BEACH_IN_M: float = 42.0
const HILL_Y: float = 18.0
const BEACH_PALM_M: float = 28.0
const GROVE_M: float = 55.0
## Palms keep this far from any port.
const PORT_CLEAR_M: float = 450.0
## Lagoon rings: how far out from an island the turquoise reaches, the grid
## step of its mesh, and its distance cull (like the surf's).
const LAGOON_M: float = 90.0
const LAGOON_STEP_M: float = 10.0
const LAGOON_RANGE_M: float = 1800.0
const LUSH_TOP := Color("4fb04a")
const TRUNK := Color("a77b4f")
const FROND := Color("2f9a3c")
const BUSH := Color("3f8f3a")
const WHITEWASH := Color("efe6cf")
const THATCH := Color("c9a25a")
const PASTELS: Array[Color] = [Color("5fc8c0"), Color("f08a6c"), Color("f2d06a")]
const LAGOON_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 lagoon_color : source_color = vec4(0.24, 0.82, 0.82, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.55, 0.93, 0.88, 1.0);
uniform float water_time = 0.0;
uniform int quality = 1;
uniform float reach = 90.0;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Same swell as OceanPresentation.swell_height (and the surf), a hair
	// above the sea and under the surf, so it rides the water like paint.
	float swell = 0.0;
	if (quality > 0) {
		swell += 0.55 * sin(world.x * 0.040 + world.z * 0.026 + water_time * 0.55);
		swell += 0.28 * sin(world.z * 0.070 - world.x * 0.018 - water_time * 0.80);
		if (quality > 1) swell += 0.10 * sin(world.x * 0.11 - world.z * 0.08 + water_time * 1.1);
	}
	VERTEX.y += swell + 0.08;
}
void fragment() {
	// UV.x is the distance out from the island's shore, in metres. Two toon
	// bands with wavy edges: pale near the beach, turquoise further out.
	float wobble = sin(world.x * 0.045 + world.z * 0.031 + water_time * 0.5) + 0.6 * sin(world.z * 0.083 - world.x * 0.027 - water_time * 0.7);
	float outer = reach * 0.82 + 8.0 * wobble;
	float inner = reach * 0.36 + 5.0 * wobble;
	ALBEDO = UV.x < inner ? shallow_color.rgb : lagoon_color.rgb;
	ALPHA = step(UV.x, outer);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

## True for a land block that belongs to the tropics.
static func is_tropical(rect: Rect2) -> bool:
	return Tropical.weight(Vector3(rect.get_center().x, 0, rect.get_center().y)) >= 0.5

## A tropical block with sea on every side: an island the lagoon rings.
static func is_island(rect: Rect2, blocks: Array) -> bool:
	return is_tropical(rect) and not Coast.sea_sides(rect, blocks).has(false)

## Patch 2.9 item 6A: the natural isles are many blocks each, so a lagoon
## rings each small tropical coast (its bounds, ISLAND_MAX_M across at most).
const ISLAND_MAX_M: float = 1200.0
static func islands() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for entry: Dictionary in Progression.natural_land().get("outlines", []):
		var ring: PackedVector2Array = entry.outline
		if ring.is_empty(): continue
		var bounds: Rect2 = Rect2(ring[0], Vector2.ZERO)
		for spot: Vector2 in ring: bounds = bounds.expand(spot)
		if maxf(bounds.size.x, bounds.size.y) <= ISLAND_MAX_M and is_tropical(bounds): out.append(bounds)
	return out

static func _clear_of_ports(at: Vector2, ports: Array[Vector2]) -> bool:
	for place: Vector2 in ports:
		# A port's quay runs a kilometre north (+Z) of its berth origin.
		var nearest: Vector2 = Vector2(place.x, clampf(at.y, place.y, place.y + 1000.0))
		if at.distance_to(nearest) < PORT_CLEAR_M: return false
	return true

static func _spot_ok(at: Vector2, ports: Array[Vector2]) -> bool:
	return Progression.land_depth(at) >= 34.0 and _clear_of_ports(at, ports) and Tropical.weight(Vector3(at.x, 0, at.y)) >= 0.5

## A palm at `at` (x, z) on ground `y`: a leaning trunk and a crown at its top.
static func _palm(rng: RandomNumberGenerator, at: Vector2, y: float, trunks: Array[Transform3D], crowns: Array[Transform3D]) -> void:
	var tall: float = rng.randf_range(10, 17)
	var lean: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis(Vector3.RIGHT, rng.randf_range(0.08, 0.26))
	var base: Vector3 = Vector3(at.x, y - 0.5, at.y)
	var up: Vector3 = lean * Vector3.UP
	trunks.append(Transform3D(lean * Basis.from_scale(Vector3(1.0, tall, 1.0)), base + up * tall / 2.0))
	var crown: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis.from_scale(Vector3.ONE * rng.randf_range(6.5, 9.0))
	crowns.append(Transform3D(crown, base + up * tall))

## Where the palms and bushes go over the tropical blocks of `blocks`:
## {"trunks": [Transform3D], "crowns": [Transform3D], "bushes": [Transform3D]},
## or {} when no block is tropical.
static func placements(blocks: Array, ports: Array[Vector2]) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var any: bool = false
	for rect: Rect2 in blocks:
		if is_tropical(rect): any = true
	if not any: return {}
	# Patch 2.9 item 6A: a row of palms on the sand flat all round the natural
	# coast (not by the harbour walls), and groves on the hill tops.
	for at: Vector2 in Progression.coast_ring(BEACH_IN_M, BEACH_PALM_M):
		var jitter: Vector2 = Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
		if Coast.harbour_weight(at, ports) > 0.0 or not _spot_ok(at + jitter, ports): continue
		# Patch 4.0.2 item 4: none on an airfield (after the draws, so the rest stay put).
		var beach_palm: Array[Transform3D] = []
		var beach_crown: Array[Transform3D] = []
		_palm(rng, at + jitter, BEACH_Y, beach_palm, beach_crown)
		if not Airports.clear_of_airfields(at + jitter, PALM_REACH_M): continue
		trunks.append_array(beach_palm)
		crowns.append_array(beach_crown)
	for at: Vector2 in Progression.inland_spots(GROVE_M, Coast.HILL_TOP_M + 8.0, rng, 18.0):
		var palm: bool = rng.randf() < 0.65
		var wide: float = rng.randf_range(7, 13)
		if not _spot_ok(at, ports) or not Airports.clear_of_airfields(at, maxf(wide, PALM_REACH_M)): continue
		if palm: _palm(rng, at, HILL_Y, trunks, crowns)
		else: bushes.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis.from_scale(Vector3(wide, wide * 0.6, wide * rng.randf_range(0.8, 1.3))), Vector3(at.x, HILL_Y - 0.5, at.y)))
	if not any: return {}
	return {"trunks": trunks, "crowns": crowns, "bushes": bushes}

## One flat-shaded triangle facing `outward`.
static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.dot(outward) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	tool.set_normal(normal.normalized())
	for point: Vector3 in [a, b, c]: tool.add_vertex(point)

## A palm crown one metre across: six drooping, closed fronds (so the ink
## outline has no gaps) round a little cap.
static func crown_mesh() -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var thick: Vector3 = Vector3(0, 0.05, 0)
	for frond: int in 6:
		var way: Vector3 = Vector3(cos(frond * TAU / 6.0), 0, sin(frond * TAU / 6.0))
		var side: Vector3 = way.cross(Vector3.UP) * 0.13
		var root: Vector3 = way * 0.04 + Vector3(0, 0.06, 0)
		var mid: Vector3 = way * 0.42 + Vector3(0, 0.16, 0)
		var tip: Vector3 = way * 0.95 - Vector3(0, 0.40, 0)
		var outline: Array[Vector3] = [root, mid + side, tip, mid - side]
		_triangle(tool, outline[0], outline[1], outline[2], Vector3.UP)
		_triangle(tool, outline[0], outline[2], outline[3], Vector3.UP)
		_triangle(tool, outline[0] - thick, outline[1] - thick, outline[2] - thick, Vector3.DOWN)
		_triangle(tool, outline[0] - thick, outline[2] - thick, outline[3] - thick, Vector3.DOWN)
		var centre: Vector3 = (root + mid + tip) / 3.0
		for edge: int in 4:
			var a: Vector3 = outline[edge]
			var b: Vector3 = outline[(edge + 1) % 4]
			var out: Vector3 = (a + b) / 2.0 - centre
			_triangle(tool, a, b, b - thick, out)
			_triangle(tool, a, b - thick, a - thick, out)
	var mesh: ArrayMesh = tool.commit()
	return mesh

static func _material(colour: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.95
	return material

static func _multi(mesh: Mesh, transforms: Array[Transform3D], colour: Color, label: String, shadows: bool) -> MultiMeshInstance3D:
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index: int in transforms.size(): multi.set_instance_transform(index, transforms[index])
	# On the mesh, so the toon pass (toon_look.gd) turns it into toon + ink.
	if mesh is PrimitiveMesh: (mesh as PrimitiveMesh).material = _material(colour)
	else: (mesh as ArrayMesh).surface_set_material(0, _material(colour))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## Palms and bushes over the tropical blocks of `blocks`. Returns the node, or
## null when no block is tropical.
static func build_land(blocks: Array, ports: Array[Vector2]) -> Node3D:
	var spots: Dictionary = placements(blocks, ports)
	if spots.is_empty(): return null
	var root: Node3D = Node3D.new()
	root.name = "TropicalLand"
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.bottom_radius = 0.55
	trunk.top_radius = 0.35
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var bush: SphereMesh = SphereMesh.new()
	bush.radius = 0.5
	bush.height = 1.0
	bush.radial_segments = 8
	bush.rings = 4
	bush.is_hemisphere = true
	var trunks: Array[Transform3D] = spots.trunks
	var crowns: Array[Transform3D] = spots.crowns
	var bushes: Array[Transform3D] = spots.bushes
	# Thin trunks cast no shadow; the crowns' shade is enough.
	root.add_child(_multi(trunk, trunks, TRUNK, "PalmTrunks", false))
	root.add_child(_multi(crown_mesh(), crowns, FROND, "PalmCrowns", true))
	root.add_child(_multi(bush, bushes, BUSH, "Bushes", false))
	return root

static func lagoon_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = LAGOON_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("reach", LAGOON_M)
	return material

## Metres from `at` out to the coast (0 or less on land). Patch 2.9 item 6A:
## measured from the natural coast, so the ring follows the island's shape.
static func _out(rect: Rect2, at: Vector2) -> float:
	return maxf(-Progression.land_depth(at), 0.0) if rect.grow(LAGOON_M).has_point(at) else LAGOON_M + 1.0

## One island's lagoon ring: a flat grid round it, each vertex carrying its
## distance from the shore in UV.x. World coordinates, so place it at the origin.
static func lagoon_mesh(rect: Rect2) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var area: Rect2 = rect.grow(LAGOON_M)
	var cells: Vector2i = Vector2i(ceili(area.size.x / LAGOON_STEP_M), ceili(area.size.y / LAGOON_STEP_M))
	for cx: int in cells.x:
		for cz: int in cells.y:
			var corners: Array[Vector2] = []
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				corners.append(area.position + (Vector2(cx, cz) + corner) * LAGOON_STEP_M)
			var reach: Array[float] = []
			for corner: Vector2 in corners: reach.append(_out(rect, corner))
			# Under the island, or past the wavy outer edge: no quad.
			if reach.max() <= 0.0 or reach.min() > LAGOON_M: continue
			for index: int in [0, 1, 2, 0, 2, 3]:
				tool.set_uv(Vector2(reach[index], 0))
				tool.add_vertex(Vector3(corners[index].x, 0, corners[index].y))
	return tool.commit()

## Lagoon rings round the tropical islands of `blocks`, sharing `paint`.
## Returns the node, or null when there are none.
static func build_lagoons(blocks: Array, paint: ShaderMaterial) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Lagoons"
	for rect: Rect2 in islands():
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "Lagoon%d" % root.get_child_count()
		ring.mesh = lagoon_mesh(rect)
		ring.material_override = paint
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The swell lifts it a metre or so; far lagoons are a few pixels wide.
		ring.extra_cull_margin = 2.0
		ring.visibility_range_end = LAGOON_RANGE_M
		root.add_child(ring)
	if root.get_child_count() == 0:
		root.free()
		return null
	return root

## A port palm: a leaning trunk of three drums and a crown.
static func _port_palm(parent: Node3D, at: Vector3, tall: float, crown: ArrayMesh, cache: Dictionary) -> void:
	var lean: Vector3 = Vector3(0.9, 0, 0.5)
	for piece: int in 3:
		var share: float = (piece + 0.5) / 3.0
		Chunky._drum(parent, 0.6 - piece * 0.08, 0.52 - piece * 0.08, tall / 3.0, at + Vector3(0, tall * share, 0) + lean * share * share * 2.0, Chunky.INK.lerp(TRUNK, 0.85), cache)
	var top: MeshInstance3D = Chunky._part(parent, crown, at + Vector3(0, tall, 0) + lean * 2.0, FROND, cache)
	top.scale = Vector3.ONE * 7.0
	top.rotation.y = at.z * 0.37

## Tropical dressing on a port already given its chunky look (Chunky.dress_port).
static func dress_port(port: Node3D) -> void:
	var root: Node3D = port.get_node_or_null("ChunkyPort") as Node3D
	if root == null: return
	var side: float = float(port.quay_side)
	var length: float = float(port.quay_length_m)
	var cache: Dictionary = {}
	var tropics: Node3D = Node3D.new()
	tropics.name = "TropicalPort"
	port.add_child(tropics)
	for label: String in ["Quay", "QuayExtension"]: Chunky._tint(port, label, WHITEWASH)
	# Pastel sheds under thatch.
	var thatch: StandardMaterial3D = _material(THATCH)
	var shed: int = 0
	for suffix: String in ["", "2", "3", "4"]:
		if port.get_node_or_null("Warehouse" + suffix) == null: continue
		Chunky._tint(port, "Warehouse" + suffix, PASTELS[shed % PASTELS.size()])
		shed += 1
	for child: Node in root.get_children():
		var part: MeshInstance3D = child as MeshInstance3D
		if part != null and part.mesh is PrismMesh: part.material_override = thatch
	var hut_roof: PrismMesh = PrismMesh.new()
	hut_roof.size = Vector3(14, 5, 14)
	var crown: ArrayMesh = crown_mesh()
	# Stilt huts on the sand behind the quay, with palms between them.
	var index: int = 0
	var z: float = 40.0
	while z < length - 30.0:
		var x: float = side * (118.0 + (index % 2) * 16.0)
		var wall: Color = PASTELS[index % PASTELS.size()]
		for corner: Vector2 in [Vector2(-4.5, -4.5), Vector2(4.5, -4.5), Vector2(4.5, 4.5), Vector2(-4.5, 4.5)]:
			Chunky._drum(tropics, 0.45, 0.45, 4.0, Vector3(x + corner.x, 6.0, z + corner.y), TRUNK, cache)
		Chunky._box(tropics, Vector3(11, 0.8, 11), Vector3(x, 8.2, z), TRUNK, cache)
		Chunky._box(tropics, Vector3(10, 6, 10), Vector3(x, 11.6, z), wall, cache)
		Chunky._part(tropics, hut_roof, Vector3(x, 17.1, z), THATCH, cache)
		Chunky._box(tropics, Vector3(0.6, 3.6, 2.6), Vector3(x - side * 5.1, 10.4, z), Chunky.INK, cache)
		_port_palm(tropics, Vector3(side * 104.0, 4.0, z + 24.0), 12.0 + (index % 3) * 2.0, crown, cache)
		index += 1
		z += 58.0
	# A tall thatched lookout at the middle of the quay's village, seen from the sea.
	var tower: Vector3 = Vector3(side * 156.0, 4.0, length * 0.5 + 29.0)
	for corner: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]:
		Chunky._drum(tropics, 0.7, 0.55, 22.0, tower + Vector3(corner.x, 11.0, corner.y), TRUNK, cache)
	Chunky._box(tropics, Vector3(12, 1.0, 12), tower + Vector3(0, 22.5, 0), TRUNK, cache)
	Chunky._box(tropics, Vector3(9, 4, 9), tower + Vector3(0, 25.0, 0), PASTELS[0], cache)
	var cap: PrismMesh = PrismMesh.new()
	cap.size = Vector3(15, 7, 15)
	Chunky._part(tropics, cap, tower + Vector3(0, 30.5, 0), THATCH, cache)
