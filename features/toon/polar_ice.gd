extends RefCounted
## Patch 2.9.1 item 6: the polar ice cap. The baked depth grid
## (Progression.polar_ice) becomes 20 chunks, ten along the north side of the
## world's north/south edge and ten along the south side. Each chunk holds its
## solid boxes (Progression.ICE_SHELVES, as land has), and two bands of toon
## coast: blue ice cliffs straight out of the sea, here tall and there a low
## shelf, a snow field rising to a flat plateau, surf at the foot, and a few
## snow peaks inland. By a polar port the ice is a wall at quay height, as the
## land is by the other ports.
## The cliff is a wall dropped from the CLIFF_M depth contour to a foot FACE_M
## out to sea, so it runs as smoothly as the contour does.
## The cap lies across the edges of the world, so each chunk sits at its copy
## nearest the ship (`place`), as the icebergs do; a move only ever happens
## half a world away. Far bands are culled past RANGE_M, surf sooner.
const Progression = preload("res://features/game/progression.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
const BANDS: int = 2
const CLIFF_M: float = 9.0
const FACE_M: float = 9.0
const SNOW_FROM_M: float = 21.0
const SURF_SEAWARD_M: float = 8.0
const SURF_INLAND_M: float = 4.0
const ICE_UNDER_M: float = 62.0
const PLATEAU_FROM_M: float = 250.0
const PLATEAU_Y: float = 46.0
const RANGE_M: float = 4000.0
const SURF_RANGE_M: float = 1900.0
const PEAK_INLAND_M: float = 130.0
const PEAK_PORT_M: float = 450.0
const ICE: Color = Color("9ed5ea")
const SNOW: Color = Color("f7fbfd")
const PEAK: Color = Color("e6f2f8")
## One turn per trip round the world, so heights meet across every edge.
const TURN: float = TAU / Progression.WRAP_M
## Patch 4.0.2 item 1: the cap's relief. Icy ridges (sharp crests that wind
## across the cap), rolling snow hills between them and a few big massifs,
## rising from RELIEF_FROM_M in from the coast to full height on the
## plateau (the baked depth tops out near 254 m, the plateau). Pure maths
## (every frequency a whole number of turns round the world, so it meets
## itself across every edge): the ice mesh, the planes' terrain
## (features/planes/terrain.gd) and the M-map globe all use relief(), so the
## client and the server see the same ice. The ships' ice colliders
## (ICE_SHELVES) are unchanged.
const RELIEF_FROM_M: float = 150.0
const RELIEF_FULL_M: float = 250.0
const RIDGE_M: float = 74.0
const HILL_M: float = 16.0
## A ridge face steeper than this (normal Y) is drawn as blue glacier ice.
const STEEP_NORMAL_Y: float = 0.8
const GLACIER: Color = Color("bfe3f1")

## Height of the cliff's top at `at` (X, Z): low shelves and tall cliffs.
static func cliff_top(at: Vector2) -> float:
	var wave: float = 0.5 + 0.3 * sin(at.x * TURN * 9.0 + at.y * TURN * 4.0) + 0.2 * sin(at.y * TURN * 15.0 - at.x * TURN * 6.0 + 1.7)
	return lerpf(8.0, 30.0, clampf(wave, 0.0, 1.0))

## Ice `depth` metres in from the coast; `harbour` 1 by a port's quay: the
## cliff's foot under the sea, its face, then its flat top.
static func ice_height(depth: float, at: Vector2, harbour: float) -> float:
	var top: float = lerpf(cliff_top(at), TOON_COAST.SAND_TOP_Y, harbour)
	return lerpf(TOON_COAST.SAND_FOOT_Y, top, clampf((depth - CLIFF_M + FACE_M) / FACE_M, 0.0, 1.0))

## The snow on top: from the cliff's edge up to the plateau, with drifts.
static func snow_height(depth: float, at: Vector2, harbour: float) -> float:
	var rise: float = smoothstep(SNOW_FROM_M, PLATEAU_FROM_M, depth)
	var drift: float = 4.0 * sin(at.x * TURN * 31.0 + at.y * TURN * 12.0) * sin(at.y * TURN * 27.0 - at.x * TURN * 8.0)
	var open: float = lerpf(cliff_top(at) + 0.6, PLATEAU_Y, rise) + sin(PI * rise) * drift + relief(at, depth)
	if harbour <= 0.0: return open
	var hill: float = TOON_COAST.hill_height(depth)
	if depth > TOON_COAST.HILL_TOP_M: hill = lerpf(TOON_COAST.HILL_TOP_Y, PLATEAU_Y, smoothstep(TOON_COAST.HILL_TOP_M, PLATEAU_FROM_M, depth))
	return lerpf(open, hill, harbour)

## Patch 4.0.2 item 1: metres of ridge and hill above the snow at `at`,
## `depth` metres in from the ice's coast (0 near the coast and the ports).
static func relief(at: Vector2, depth: float) -> float:
	var fade: float = smoothstep(RELIEF_FROM_M, RELIEF_FULL_M, depth)
	if fade <= 0.0: return 0.0
	var a: float = 1.0 - absf(sin(at.x * TURN * 23.0 + at.y * TURN * 9.0 + 1.3 * sin(at.y * TURN * 5.0)))
	var b: float = 1.0 - absf(sin(at.y * TURN * 19.0 - at.x * TURN * 14.0 + 0.7 + 1.1 * sin(at.x * TURN * 6.0)))
	var ridge: float = pow(maxf(a, b), 3.0)
	var hills: float = 0.5 + 0.5 * sin(at.x * TURN * 57.0 + at.y * TURN * 21.0) * sin(at.y * TURN * 49.0 - at.x * TURN * 17.0 + 2.1)
	var massif: float = 0.6 + 0.4 * sin(at.x * TURN * 4.0 + 0.4) * sin(at.y * TURN * 3.0 + 1.0)
	return fade * (ridge * RIDGE_M * massif + hills * HILL_M)

## TOON_COAST.harbour_weight, asked only near a port.
static func harbour_at(at: Vector2, ports: Array[Vector2]) -> float:
	for port: Vector2 in ports:
		if absf(at.x - port.x) < 520.0 and at.y > port.y - 560.0 and at.y < port.y + 1500.0: return TOON_COAST.harbour_weight(at, ports)
	return 0.0

static func paint(colour: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material

## The whole cap: "PolarIce" with one "IceChunk<n>" per Progression.ICE_CHUNKS
## entry. `ports` are the polar ports (X, Z); `surf` is the shared surf paint.
static func build(ports: Array[Vector2], surf: Material) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PolarIce"
	var grid: Dictionary = Progression.polar_ice()
	if grid.is_empty(): return root
	var ice: StandardMaterial3D = paint(ICE)
	var snow: StandardMaterial3D = paint(SNOW)
	var glacier: StandardMaterial3D = paint(GLACIER)
	var peak: CylinderMesh = CylinderMesh.new()
	peak.bottom_radius = 1.0
	peak.top_radius = 0.12
	peak.height = 1.0
	peak.radial_segments = 5
	peak.rings = 1
	peak.material = paint(PEAK)
	var rows: int = ceili(grid.half / float(BANDS))
	for index: int in Progression.ICE_CHUNKS.size():
		var chunk: Node3D = Node3D.new()
		chunk.name = "IceChunk%d" % index
		root.add_child(chunk)
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Ice"
		body.position = Vector3(0, -2, 0)
		body.collision_layer = CollisionRules.SHORE
		body.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
		chunk.add_child(body)
		for block: int in range(Progression.ICE_CHUNKS[index][0], Progression.ICE_CHUNKS[index][1]):
			var rect: Rect2 = Progression.ICE_SHELVES[block]
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = Vector3(rect.size.x, 12, rect.size.y)
			var collider: CollisionShape3D = CollisionShape3D.new()
			collider.shape = shape
			collider.position = Vector3(rect.get_center().x, 0, rect.get_center().y)
			body.add_child(collider)
		var south: bool = index >= Progression.ICE_COLUMNS
		var first: int = grid.half if south else 0
		for band: int in BANDS:
			var from: int = first + band * rows
			var part: Dictionary = band_meshes(index % Progression.ICE_COLUMNS, from, mini(from + rows, mini(first + grid.half, grid.count.y - 1)), south, ports, ice, snow, glacier)
			if part.coast != null:
				var coast: MeshInstance3D = MeshInstance3D.new()
				coast.name = "Coast%d" % band
				coast.mesh = part.coast
				coast.visibility_range_end = RANGE_M
				chunk.add_child(coast)
			if part.surf != null:
				var foam: MeshInstance3D = MeshInstance3D.new()
				foam.name = "Surf%d" % band
				foam.mesh = part.surf
				foam.material_override = surf
				foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				foam.visibility_range_end = SURF_RANGE_M
				chunk.add_child(foam)
			var spots: Array[Transform3D] = peaks(index, band, part.area, ports)
			if spots.is_empty(): continue
			var many: MultiMesh = MultiMesh.new()
			many.transform_format = MultiMesh.TRANSFORM_3D
			many.mesh = peak
			many.instance_count = spots.size()
			for spot: int in spots.size(): many.set_instance_transform(spot, spots[spot])
			var range_node: MultiMeshInstance3D = MultiMeshInstance3D.new()
			range_node.name = "Peaks%d" % band
			range_node.multimesh = many
			range_node.visibility_range_end = RANGE_M
			chunk.add_child(range_node)
	return root

## Each chunk at its copy nearest the ship.
static func place(root: Node3D, ship: Vector3) -> void:
	for index: int in root.get_child_count():
		var centre: Vector3 = Progression.ice_chunk_centre(index)
		var at: Vector3 = Progression.nearest(centre, ship) - centre
		at.y = 0.0
		var chunk: Node3D = root.get_child(index)
		if chunk.position.distance_to(at) > 1.0: chunk.position = at

## Seeded snow peaks on one band's deep ice, as MultiMesh transforms.
static func peaks(index: int, band: int, area: Rect2, ports: Array[Vector2]) -> Array[Transform3D]:
	var spots: Array[Transform3D] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2916 + index * 17 + band * 131
	for attempt: int in 9:
		var at: Vector2 = area.position + Vector2(rng.randf(), rng.randf()) * area.size
		var count: int = rng.randi_range(1, 3)
		for step: int in count:
			var spot: Vector2 = at + Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70)) * float(step)
			var wide: float = rng.randf_range(38.0, 80.0) / (1.0 + step * 0.35)
			var tall: float = rng.randf_range(30.0, 72.0) / (1.0 + step * 0.3)
			if Progression.ice_depth(spot) < PEAK_INLAND_M: continue
			if ports.any(func(port: Vector2) -> bool: return Vector2(port.x, clampf(spot.y, port.y - 60.0, port.y + 1000.0)).distance_to(spot) < PEAK_PORT_M): continue
			# Patch 4.0.2 item 1: standing on the relief, not sunk in it.
			var lift: float = relief(spot, Progression.ice_depth(spot))
			spots.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(wide, tall, wide)), Vector3(spot.x, 24.0 + lift + tall / 2, spot.y)))
	return spots

## One band of one column: sample rows `from` to `to` (the squares between
## them and the next row). {"coast": ArrayMesh or null, "surf": ArrayMesh or
## null, "area": Rect2}, in the chunk's own baked place.
static func band_meshes(column: int, from: int, to: int, south: bool, ports: Array[Vector2], ice: Material, snow: Material, glacier: Material = null) -> Dictionary:
	var grid: Dictionary = Progression.polar_ice()
	var count: Vector2i = grid.count
	var depth: PackedFloat32Array = grid.depth
	var cell: float = grid.cell
	var wide: int = count.x / Progression.ICE_COLUMNS
	var edge: float = Progression.WRAP_CENTRE.z + (-0.5 if south else 0.5) * Progression.WRAP_M
	var origin: Vector2 = Vector2(Progression.WRAP_CENTRE.x - Progression.WRAP_M / 2 + 0.5 * cell, edge + (0.5 - grid.half) * cell)
	var ice_points: PackedVector3Array = PackedVector3Array()
	var snow_points: PackedVector3Array = PackedVector3Array()
	var surf_points: PackedVector3Array = PackedVector3Array()
	var surf_uvs: PackedVector2Array = PackedVector2Array()
	var row_end: int = (column + 1) * wide
	for j: int in range(from, to):
		# Patch 4.0.2 item 1: the plateau is no longer one flat quad per run;
		# every square carries the relief (ridges, hills), like the slopes.
		for i: int in range(column * wide, row_end):
			var i0: int = j * count.x + i
			var i1: int = j * count.x + (i + 1) % count.x
			var v: Array[float] = [depth[i0], depth[i1], depth[i1 + count.x], depth[i0 + count.x]]
			var high: float = maxf(maxf(v[0], v[1]), maxf(v[2], v[3]))
			if high <= CLIFF_M: continue
			var low: float = minf(minf(v[0], v[1]), minf(v[2], v[3]))
			var base: Vector2 = origin + Vector2(i, j) * cell
			if high > SNOW_FROM_M: _fan(snow_points, TOON_COAST._cell_cut(v, SNOW_FROM_M), base, cell, ports, true)
			if low >= ICE_UNDER_M: continue
			var top: Array = TOON_COAST._cell_cut(v, CLIFF_M)
			_fan(ice_points, top, base, cell, ports, false)
			if low >= CLIFF_M: continue
			# The cliff: from the contour's two ends in this square down to the
			# foot, each end leaning the way the ice falls there, so the wall
			# has no gaps from one square to the next. Surf rides its foot.
			var rim: Array[Vector2] = []
			for index: int in top[1].size():
				if top[1][index] == CLIFF_M: rim.append(base + top[0][index] * cell)
			if rim.size() != 2: continue
			var out_a: Vector2 = seaward(rim[0])
			var out_b: Vector2 = seaward(rim[1])
			var harbour_a: float = harbour_at(rim[0], ports)
			var harbour_b: float = harbour_at(rim[1], ports)
			var foot_a: Vector2 = rim[0] + out_a * FACE_M
			var foot_b: Vector2 = rim[1] + out_b * FACE_M
			var wall: Array[Vector3] = [Vector3(rim[0].x, ice_height(CLIFF_M, rim[0], harbour_a), rim[0].y), Vector3(rim[1].x, ice_height(CLIFF_M, rim[1], harbour_b), rim[1].y),
				Vector3(foot_b.x, TOON_COAST.SAND_FOOT_Y, foot_b.y), Vector3(foot_a.x, TOON_COAST.SAND_FOOT_Y, foot_a.y)]
			# Wound to face the sea (Godot fronts are clockwise).
			var facing: Vector3 = Vector3(out_a.x + out_b.x, 0.2, out_a.y + out_b.y)
			for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
				var flip: bool = (wall[triangle[2]] - wall[triangle[0]]).cross(wall[triangle[1]] - wall[triangle[0]]).dot(facing) < 0.0
				for index: int in ([triangle[0], triangle[2], triangle[1]] if flip else triangle): ice_points.append(wall[index])
			if harbour_a >= 0.5 or harbour_b >= 0.5: continue
			var corners: Array[Vector2] = [foot_a + out_a * SURF_SEAWARD_M, foot_b + out_b * SURF_SEAWARD_M, foot_b - out_b * SURF_INLAND_M, foot_a - out_a * SURF_INLAND_M]
			var uvs: Array[float] = [0.0, 0.0, 1.0, 1.0]
			for index: int in [0, 1, 2, 0, 2, 3]:
				surf_points.append(Vector3(corners[index].x, 0, corners[index].y))
				surf_uvs.append(Vector2(0, uvs[index]))
	var result: Dictionary = {"coast": null, "surf": null, "area": Rect2(origin + Vector2(column * wide, from) * cell, Vector2(wide, to - from) * cell)}
	if not ice_points.is_empty() or not snow_points.is_empty():
		var mesh: ArrayMesh = ArrayMesh.new()
		if not ice_points.is_empty(): TOON_COAST._add_surface(mesh, ice_points, ice)
		if not snow_points.is_empty():
			# Steep ridge faces in blue glacier ice, the rest in snow.
			var parts: Array[PackedVector3Array] = split_steep(snow_points)
			if not parts[0].is_empty(): TOON_COAST._add_surface(mesh, parts[0], snow)
			if not parts[1].is_empty(): TOON_COAST._add_surface(mesh, parts[1], glacier if glacier != null else ice)
		result.coast = mesh
	if not surf_points.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surf_points
		var normals: PackedVector3Array = PackedVector3Array()
		normals.resize(surf_points.size())
		normals.fill(Vector3.UP)
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = surf_uvs
		var surf: ArrayMesh = ArrayMesh.new()
		surf.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surf = surf
	return result

## Patch 4.0.2 item 1: [gentle triangles, steep triangles] of a triangle list.
static func split_steep(points: PackedVector3Array) -> Array[PackedVector3Array]:
	var gentle: PackedVector3Array = PackedVector3Array()
	var steep: PackedVector3Array = PackedVector3Array()
	for index: int in range(0, points.size() - 2, 3):
		var normal: Vector3 = (points[index + 2] - points[index]).cross(points[index + 1] - points[index]).normalized()
		# (Packed arrays are values: append to the one meant, not a copy.)
		for corner: int in 3:
			if absf(normal.y) < STEEP_NORMAL_Y: steep.append(points[index + corner])
			else: gentle.append(points[index + corner])
	return [gentle, steep]

## The way out to sea at `at`: down the depth grid's slope.
static func seaward(at: Vector2) -> Vector2:
	var slope: Vector2 = Vector2(Progression.ice_depth(at + Vector2(6, 0)) - Progression.ice_depth(at - Vector2(6, 0)), Progression.ice_depth(at + Vector2(0, 6)) - Progression.ice_depth(at - Vector2(0, 6)))
	return -slope.normalized() if slope.length() > 0.001 else Vector2.ZERO

## A cut square as a triangle fan, each corner at its own ice or snow height.
static func _fan(out: PackedVector3Array, cut: Array, base: Vector2, cell: float, ports: Array[Vector2], snow: bool) -> void:
	var points: Array = cut[0]
	var depths: Array = cut[1]
	if points.size() < 3: return
	var at: Array[Vector3] = []
	for index: int in points.size():
		var spot: Vector2 = base + points[index] * cell
		var harbour: float = harbour_at(spot, ports)
		at.append(Vector3(spot.x, snow_height(depths[index], spot, harbour) if snow else ice_height(CLIFF_M, spot, harbour), spot.y))
	for index: int in range(1, points.size() - 1):
		out.append(at[0])
		out.append(at[index])
		out.append(at[index + 1])
