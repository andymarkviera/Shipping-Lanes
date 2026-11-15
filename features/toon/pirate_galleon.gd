extends RefCounted
## Patch 2.9.1 item 1: the pirate galleon, built in code like the other chunky
## ships. A 112 x 24 m three-master: carved stern castle with lit cabin windows
## and lanterns, quarter galleries, beakhead and gold figurehead, two gun decks
## and deck guns (62 cannons), full rigging with ratlines, a crow's nest, a
## ship's wheel, set sails, a big black Jolly Roger and pennants that flap.
## Looks only: the collider, wake and rules come from the ship record.
##
## Frame time: the whole ship is nine meshes (hull, structure, detail, rigging,
## sails, glow, flags, two outline passes shared), built once and cached. The
## small detail and the rigging stop drawing past DETAIL_RANGE_M / RIGGING_RANGE_M.
const TOON_SHADER: Shader = preload("res://features/toon/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://features/toon/toon_outline_custom.gdshader")
const FLAG_SHADER: Shader = preload("res://features/toon/pirate_flag.gdshader")

## The hull the model is drawn for; the record (pirate_galleon_ship.tres) matches.
const SIZE_M: Vector3 = Vector3(24, 6, 112)
const STERN_Z: float = -52.0
const STEM_Z: float = 44.0
const HALF_BEAM: float = 11.6
const BULWARK: float = 1.5
## Where the decks step: poop | quarterdeck | waist | forecastle.
const BREAKS: Array[float] = [-36.0, -18.0, 20.0]
## Past these distances from the camera the small parts are not drawn.
const DETAIL_RANGE_M: float = 700.0
const RIGGING_RANGE_M: float = 520.0
## Nothing may stand taller than this: the bridges clear 70 m.
const AIR_DRAFT_M: float = 67.0

const WOOD: Color = Color("8a5a33")
const DARK_WOOD: Color = Color("5a3a24")
const PLANK: Color = Color("cfa56a")
const OCHRE: Color = Color("e0a83c")
const RED: Color = Color("b8322a")
const NAVY: Color = Color("2c5d73")
const GOLD: Color = Color("f2b632")
const BLACK: Color = Color("2b2622")
const IRON: Color = Color("3a3f4b")
const CREAM: Color = Color("efe2c2")
const SAIL: Color = Color("f4ead0")
const SAIL_SEAM: Color = Color("ecdfbd")
const ROPE: Color = Color("4a3b2e")
const LAMP: Color = Color("ffd56b")
const FLAG_BLACK: Color = Color("1c1b22")
const BONE: Color = Color("f6f1e3")

## The Jolly Roger, one character per cell of cloth.
const JOLLY_ROGER: Array[String] = [
	".....................",
	"..#...............#..",
	".###....#####....###.",
	"..###..#######..###..",
	"...##.#########.##...",
	"......##..#..##......",
	"......##..#..##......",
	"......#########......",
	".......###.###.......",
	"...##..#######..##...",
	"..###...#.#.#...###..",
	".###.....###.....###.",
	"..#...............#..",
	".....................",
]

## Lower mast head (the top), crosstrees and truck heights, and each yard as
## [height, width]. The mizzen also carries the lateen yard.
const MASTS = {
	"Fore": {"z": 26.0, "r": 0.85, "top": 28.0, "cross": 42.0, "truck": 53.0, "yards": [[25.5, 23.5], [39.5, 18.5], [49.5, 13.0]], "foot": 17.0},
	"Main": {"z": -2.0, "r": 0.95, "top": 31.0, "cross": 47.0, "truck": 60.0, "yards": [[28.0, 27.0], [44.5, 21.0], [55.5, 15.0]], "foot": 13.5},
	"Mizzen": {"z": -30.0, "r": 0.7, "top": 27.5, "cross": 39.5, "truck": 47.0, "yards": [[26.0, 15.0], [37.5, 11.5]], "foot": 0.0},
}

static var _meshes: Dictionary = {}

## Many parts merged into one mesh: vertex colours, flat or round normals, and
## the outline push of each vertex (see toon_outline_custom.gdshader).
class Batch extends RefCounted:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colours: PackedColorArray = PackedColorArray()
	var pushes: PackedFloat32Array = PackedFloat32Array()
	## Outline width of the parts added next, as a share of the full ink line.
	var ink: float = 1.0
	var tint: Color = Color.WHITE

	func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, pa: Vector3, pb: Vector3, pc: Vector3) -> void:
		# Godot's front faces wind clockwise: (c - a) x (b - a) faces the viewer.
		if (c - a).cross(b - a).dot(na + nb + nc) < 0.0:
			tri(a, c, b, na, nc, nb, pa, pc, pb)
			return
		vertices.append(a); vertices.append(b); vertices.append(c)
		normals.append(na); normals.append(nb); normals.append(nc)
		colours.append(tint); colours.append(tint); colours.append(tint)
		for push: Vector3 in [pa, pb, pc]:
			pushes.append(push.x * ink); pushes.append(push.y * ink); pushes.append(push.z * ink)

	## A box of any size and turn; xform places its centre.
	func box(xform: Transform3D, size: Vector3, colour: Color) -> void:
		tint = colour.srgb_to_linear()
		var basis: Basis = xform.basis.orthonormalized()
		for axis: int in 3:
			for way: float in [-1.0, 1.0]:
				var normal: Vector3 = basis[axis] * way
				var corners: Array[Vector3] = []
				var push: Array[Vector3] = []
				for step: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var unit: Vector3 = Vector3.ZERO
					unit[axis] = way
					unit[(axis + 1) % 3] = step.x
					unit[(axis + 2) % 3] = step.y
					corners.append(xform * (unit * size * 0.5))
					push.append(basis * unit)
				tri(corners[0], corners[1], corners[2], normal, normal, normal, push[0], push[1], push[2])
				tri(corners[0], corners[2], corners[3], normal, normal, normal, push[0], push[2], push[3])

	## An upright box by its centre.
	func block(at: Vector3, size: Vector3, colour: Color) -> void:
		box(Transform3D(Basis.IDENTITY, at), size, colour)

	## A round or tapered spar from a to b.
	func rod(a: Vector3, b: Vector3, ra: float, rb: float, colour: Color, sides: int = 8, caps: bool = true) -> void:
		tint = colour.srgb_to_linear()
		var axis: Vector3 = (b - a).normalized()
		var u: Vector3 = axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.UP).normalized()
		var v: Vector3 = axis.cross(u)
		var end: Vector3 = axis if caps else Vector3.ZERO
		for index: int in sides:
			var first: float = TAU * index / sides
			var second: float = TAU * (index + 1) / sides
			var d0: Vector3 = u * cos(first) + v * sin(first)
			var d1: Vector3 = u * cos(second) + v * sin(second)
			var a0: Vector3 = a + d0 * ra
			var a1: Vector3 = a + d1 * ra
			var b0: Vector3 = b + d0 * rb
			var b1: Vector3 = b + d1 * rb
			tri(a0, b0, b1, d0, d0, d1, d0 - end, d0 + end, d1 + end)
			tri(a0, b1, a1, d0, d1, d1, d0 - end, d1 + end, d1 - end)
			if caps:
				if ra > 0.02: tri(a, a0, a1, -axis, -axis, -axis, -axis, d0 - axis, d1 - axis)
				if rb > 0.02: tri(b, b0, b1, axis, axis, axis, axis, d0 + axis, d1 + axis)

	func ball(at: Vector3, radii: Vector3, colour: Color, around: int = 8, rings: int = 5) -> void:
		tint = colour.srgb_to_linear()
		for ring: int in rings:
			for index: int in around:
				var corners: Array[Vector3] = []
				for step: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var tilt: float = PI * (ring + step.y) / rings
					var turn: float = TAU * (index + step.x) / around
					corners.append(Vector3(sin(tilt) * cos(turn), cos(tilt), sin(tilt) * sin(turn)))
				var points: Array[Vector3] = []
				for corner: Vector3 in corners: points.append(at + corner * radii)
				if ring > 0: tri(points[0], points[1], points[2], corners[0], corners[1], corners[2], corners[0], corners[1], corners[2])
				if ring < rings - 1: tri(points[0], points[2], points[3], corners[0], corners[2], corners[3], corners[0], corners[2], corners[3])

	func mesh(material: Material) -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_CUSTOM0] = pushes
		var out: ArrayMesh = ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		out.surface_set_material(0, material)
		return out

## The four merged part sets a build fills.
class Parts extends RefCounted:
	## Big shapes, full ink outline, always drawn.
	var structure: Batch = Batch.new()
	## Small parts, thin outline, not drawn far away.
	var detail: Batch = Batch.new()
	## Ropes: no outline, not drawn far away.
	var rigging: Batch = Batch.new()
	## Lit windows and lantern glass: unshaded, so they glow at night.
	var glow: Batch = Batch.new()

# --- Hull shape -------------------------------------------------------------

## Hull width along the length as a share of the beam: a narrower transom, a
## full middle and a bluff rounded bow.
static func plan(z: float) -> float:
	var t: float = clampf((z - STERN_Z) / (STEM_Z - STERN_Z), 0.0, 1.0)
	var bow: float = clampf((t - 0.66) / 0.34, 0.0, 1.0)
	return maxf(lerpf(0.72, 1.0, smoothstep(0.0, 0.32, t)) * sqrt(maxf(0.0, 1.0 - pow(bow, 2.4))), 0.03)

## The decks and wales rise gently toward both ends.
static func sheer(z: float) -> float:
	return 1.6 * pow((z + 4.0) / 48.0, 2.0)

static func deck_at(z: float) -> float:
	var base: float = 12.5
	if z < BREAKS[0]: base = 17.0
	elif z < BREAKS[1]: base = 13.0
	elif z < BREAKS[2]: base = 9.0
	return base + sheer(z)

static func rail_at(z: float) -> float:
	return deck_at(z) + BULWARK

## Half the hull section at z, from the deck edge up the inside of the bulwark,
## over the rail and down the outside to the bilge: (half width, height).
static func profile(z: float) -> PackedVector2Array:
	var w: float = HALF_BEAM * plan(z)
	var s: float = sheer(z)
	var deck: float = deck_at(z)
	var top: float = deck + BULWARK
	var t: float = clampf((z - STERN_Z) / (STEM_Z - STERN_Z), 0.0, 1.0)
	var run: float = lerpf(0.45, 1.0, smoothstep(0.0, 0.3, t)) * lerpf(1.0, 0.5, smoothstep(0.7, 1.0, t))
	var wale: float = 7.8 + 0.8 * s
	var inner: float = maxf(0.8 * w - 0.5, 0.02)
	var band: float = maxf(top - 2.6, wale + 0.05)
	# Tumblehome: the sides lean in from the upper wale to the rail.
	var cap_x: float = lerpf(0.9, 0.8, (top - 0.5 - wale) / (top - wale)) * w
	var band_x: float = lerpf(0.9, 0.8, (band - wale) / (top - wale)) * w
	return PackedVector2Array([
		Vector2(inner, deck), Vector2(inner, top), Vector2(0.8 * w, top), Vector2(cap_x, top - 0.5),
		Vector2(band_x, band), Vector2(0.9 * w, wale), Vector2(0.92 * w, wale - 0.6),
		Vector2(w, 5.0 + 0.6 * s), Vector2(w, 4.4 + 0.6 * s), Vector2(w, 1.2 + 0.3 * s), Vector2(0.99 * w, 0.6 + 0.3 * s),
		Vector2(0.95 * w, -1.0), Vector2(0.55 * w * run, -4.4)])

## Half width of the outside of the hull at z and height y.
static func side_x(z: float, y: float) -> float:
	var section: PackedVector2Array = profile(z)
	if y >= section[2].y: return section[2].x
	for index: int in range(2, section.size() - 1):
		if y >= section[index + 1].y:
			return lerpf(section[index + 1].x, section[index].x, (y - section[index + 1].y) / maxf(section[index].y - section[index + 1].y, 0.001))
	return section[section.size() - 1].x

## Half width of the open deck inside the bulwark.
static func deck_half(z: float) -> float:
	return maxf(0.8 * HALF_BEAM * plan(z) - 0.5, 0.02)

static func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	var flip: bool = (c - a).cross(b - a).dot(want) < 0.0
	surface.add_vertex(a)
	surface.add_vertex(c if flip else b)
	surface.add_vertex(b if flip else c)

## One smooth surface, like chunky_look's hulls, so the ink outline has no gaps.
static func hull_mesh() -> ArrayMesh:
	var stations: Array[float] = []
	var z: float = STERN_Z
	while z <= STEM_Z + 0.001:
		stations.append(z)
		z += 2.0 if z < 34.0 else 1.0
	for step: float in BREAKS:
		stations.erase(step)
		stations.append(step - 0.01)
		stations.append(step + 0.01)
	stations.sort()
	var bands: Array[Color] = [DARK_WOOD, GOLD, GOLD, RED, NAVY, BLACK, OCHRE, BLACK, WOOD, BLACK, CREAM, CREAM, CREAM]
	var rings: Array[PackedVector3Array] = []
	for at: float in stations:
		var section: PackedVector2Array = profile(at)
		var ring: PackedVector3Array = PackedVector3Array()
		for point: Vector2 in section: ring.append(Vector3(-point.x, point.y, at))
		for back: int in range(section.size() - 1, -1, -1): ring.append(Vector3(section[back].x, section[back].y, at))
		rings.append(ring)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = rings[0].size()
	for index: int in rings.size() - 1:
		var a: PackedVector3Array = rings[index]
		var b: PackedVector3Array = rings[index + 1]
		surface.set_smooth_group(0)
		for side: int in count - 1:
			surface.set_color(bands[side if side <= 12 else count - 2 - side].srgb_to_linear())
			for corner: Vector3 in [a[side], b[side], b[side + 1], a[side], b[side + 1], a[side + 1]]:
				surface.add_vertex(corner)
		# The deck, and at each break the bulkhead between two decks.
		var wall: bool = stations[index + 1] - stations[index] < 0.1
		surface.set_smooth_group(2 if wall else 1)
		surface.set_color((WOOD if wall else PLANK).srgb_to_linear())
		for corner: Vector3 in [a[0], a[count - 1], b[count - 1], a[0], b[count - 1], b[0]]:
			surface.add_vertex(corner)
	# Flat transom in level strips (its own flat-lit panel), and the stem.
	var transom: Array[Color] = [GOLD, RED, NAVY, NAVY, NAVY, DARK_WOOD, WOOD, BLACK, CREAM, CREAM]
	var stern: PackedVector3Array = rings[0]
	surface.set_smooth_group(3)
	for side: int in range(2, 12):
		surface.set_color(transom[side - 2].srgb_to_linear())
		_face(surface, stern[side], stern[side + 1], stern[count - 2 - side], Vector3.FORWARD)
		_face(surface, stern[side], stern[count - 2 - side], stern[count - 1 - side], Vector3.FORWARD)
	surface.set_smooth_group(0)
	var stem: PackedVector3Array = rings[rings.size() - 1]
	surface.set_color(DARK_WOOD.srgb_to_linear())
	for side: int in count:
		_face(surface, Vector3(0, 6.0, STEM_Z), stem[side], stem[(side + 1) % count], Vector3.BACK)
	surface.generate_normals()
	surface.index()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	surface.set_material(material)
	return surface.commit()

# --- Sails ------------------------------------------------------------------

## A square sail between its yard (head) and its foot, bellied forward. A thin
## closed shell so the toon outline can wrap it.
static func _square_sail(surface: SurfaceTool, z: float, head_y: float, foot_y: float, head_w: float, foot_w: float, belly: float) -> void:
	var across: int = 8
	var down: int = 6
	var grid: Array = []
	for row: int in down + 1:
		var v: float = float(row) / down
		var line: PackedVector3Array = PackedVector3Array()
		for column: int in across + 1:
			var u: float = float(column) / across
			var y: float = lerpf(head_y, foot_y, v) + 0.07 * (head_y - foot_y) * sin(PI * u) * v * v
			line.append(Vector3(lerpf(head_w, foot_w, v) * (u - 0.5), y, z + belly * pow(sin(PI * v), 0.8) * (0.35 + 0.65 * sin(PI * u))))
		grid.append(line)
	var thick: Vector3 = Vector3(0, 0, 0.25)
	for row: int in down:
		for column: int in across:
			var a: Vector3 = grid[row][column]
			var b: Vector3 = grid[row][column + 1]
			var c: Vector3 = grid[row + 1][column + 1]
			var d: Vector3 = grid[row + 1][column]
			surface.set_color((SAIL if column % 2 == 0 else SAIL_SEAM).srgb_to_linear())
			surface.set_smooth_group(0)
			_face(surface, a, b, c, Vector3.BACK)
			_face(surface, a, c, d, Vector3.BACK)
			surface.set_smooth_group(1)
			_face(surface, a - thick, b - thick, c - thick, Vector3.FORWARD)
			_face(surface, a - thick, c - thick, d - thick, Vector3.FORWARD)
	surface.set_smooth_group(2)
	surface.set_color(SAIL_SEAM.srgb_to_linear())
	var middle: Vector3 = Vector3(0, (head_y + foot_y) * 0.5, z)
	var rim: PackedVector3Array = PackedVector3Array()
	for column: int in across + 1: rim.append(grid[0][column])
	for row: int in range(1, down + 1): rim.append(grid[row][across])
	for column: int in range(across - 1, -1, -1): rim.append(grid[down][column])
	for row: int in range(down - 1, 0, -1): rim.append(grid[row][0])
	for index: int in rim.size():
		var a: Vector3 = rim[index]
		var b: Vector3 = rim[(index + 1) % rim.size()]
		var out: Vector3 = (a + b) * 0.5 - middle
		out.z = 0.0
		_face(surface, a, b, b - thick, out)
		_face(surface, a, b - thick, a - thick, out)

## A three-cornered sail (the lateen and the jib), bellied to one side.
static func _triangle_sail(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, belly: Vector3) -> void:
	var cuts: int = 6
	var want: Vector3 = belly.normalized()
	var thick: Vector3 = want * 0.25
	var point: Callable = func(i: int, j: int) -> Vector3:
		var la: float = float(i) / cuts
		var lb: float = float(j) / cuts
		var lc: float = 1.0 - la - lb
		return a * la + b * lb + c * lc + belly * 27.0 * la * lb * lc
	for i: int in cuts:
		for j: int in cuts - i:
			var cells: Array = [[point.call(i, j), point.call(i + 1, j), point.call(i, j + 1)]]
			if i + j < cuts - 1: cells.append([point.call(i + 1, j), point.call(i + 1, j + 1), point.call(i, j + 1)])
			surface.set_color((SAIL if j % 2 == 0 else SAIL_SEAM).srgb_to_linear())
			for cell: Array in cells:
				surface.set_smooth_group(0)
				_face(surface, cell[0], cell[1], cell[2], want)
				surface.set_smooth_group(1)
				_face(surface, cell[0] - thick, cell[1] - thick, cell[2] - thick, -want)
	surface.set_smooth_group(2)
	surface.set_color(SAIL_SEAM.srgb_to_linear())
	var middle: Vector3 = (a + b + c) / 3.0
	for edge: Array in [[a, b], [b, c], [c, a]]:
		var out: Vector3 = (edge[0] + edge[1]) * 0.5 - middle
		_face(surface, edge[0], edge[1], edge[1] - thick, out)
		_face(surface, edge[0], edge[1] - thick, edge[0] - thick, out)

static func sails_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for label: String in MASTS:
		var mast: Dictionary = MASTS[label]
		var yards: Array = mast.yards
		var z: float = float(mast.z) + float(mast.r) + 0.6
		for index: int in yards.size():
			var head_y: float = float(yards[index][0]) - 0.4
			var head_w: float = float(yards[index][1]) - 1.0
			if index == 0:
				# The mizzen's lowest yard only spreads the foot of its topsail.
				if float(mast.foot) > 0.0: _square_sail(surface, z, head_y, float(mast.foot), head_w, head_w - 1.0, 2.6)
			else:
				_square_sail(surface, z, head_y, float(yards[index - 1][0]) + 1.0, head_w, float(yards[index - 1][1]) - 2.0, 2.0 - 0.3 * index)
	# Lateen on the mizzen, jib from the fore topmast to the bowsprit.
	_triangle_sail(surface, Vector3(1.1, 18.9, -24.0), Vector3(1.1, 36.5, -46.5), Vector3(1.1, 21.5, -50.0), Vector3(0.9, 0, 0))
	_triangle_sail(surface, Vector3(0, 41.0, 26.9), Vector3(0, 22.3, 55.0), Vector3(0, 18.5, 33.0), Vector3(0.8, 0, 0))
	surface.generate_normals()
	surface.index()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	surface.set_material(material)
	return surface.commit()

# --- Flags ------------------------------------------------------------------

## One mesh for every flag: cells of cloth from the hoist aft. pirate_flag.gdshader
## waves them. cells: rows of '#' (bone) and '.' (cloth); an empty list makes a
## plain pennant that tapers to a point.
static func _flag(arrays: Array, hoist: Vector3, length: float, height: float, cells: Array[String], cloth: Color, phase: float, reach: float) -> void:
	var columns: int = cells[0].length() if not cells.is_empty() else 14
	var rows: int = cells.size() if not cells.is_empty() else 1
	for row: int in rows:
		for column: int in columns:
			var colour: Color = (BONE if not cells.is_empty() and cells[row][column] == "#" else cloth).srgb_to_linear()
			var corners: Array[Vector2] = []
			for step: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
				corners.append(Vector2((column + step.x) / columns, (row + step.y) / rows))
			for corner: Vector2 in corners:
				# A pennant narrows toward its fly.
				var drop: float = corner.y * height if not cells.is_empty() else lerpf(corner.y, 0.5, corner.x * 0.92) * height
				arrays[Mesh.ARRAY_VERTEX].append(hoist + Vector3(0, -drop, -corner.x * length))
				arrays[Mesh.ARRAY_NORMAL].append(Vector3.RIGHT)
				arrays[Mesh.ARRAY_COLOR].append(colour)
				arrays[Mesh.ARRAY_TEX_UV].append(corner)
				arrays[Mesh.ARRAY_TEX_UV2].append(Vector2(phase, reach))

static func flags_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray()
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
	var none: Array[String] = []
	# The big Jolly Roger at the main truck, a second one on the ensign staff,
	# and long red pennants at the fore and mizzen trucks.
	_flag(arrays, Vector3(0, 66.3, float(MASTS.Main.z) - 0.3), 10.5, 7.0, JOLLY_ROGER, FLAG_BLACK, 0.0, 0.9)
	_flag(arrays, Vector3(0, 30.6, -54.9), 7.5, 5.0, JOLLY_ROGER, FLAG_BLACK, 2.1, 0.7)
	_flag(arrays, Vector3(0, float(MASTS.Fore.truck) + 2.3, float(MASTS.Fore.z) - 0.2), 12.0, 1.6, none, RED, 1.3, 0.8)
	_flag(arrays, Vector3(0, float(MASTS.Mizzen.truck) + 2.3, float(MASTS.Mizzen.z) - 0.2), 10.0, 1.4, none, RED, 3.7, 0.7)
	var out: ArrayMesh = ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = FLAG_SHADER
	out.surface_set_material(0, material)
	return out

# --- Fittings ---------------------------------------------------------------

## A lit window facing `out`: gold frame, glowing glass, dark glazing bars.
static func _window(parts: Parts, at: Vector3, out: Vector3, width: float, height: float) -> void:
	var xform: Transform3D = Transform3D(Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out), at)
	parts.detail.box(xform, Vector3(width + 0.4, height + 0.4, 0.16), GOLD)
	parts.glow.box(xform, Vector3(width, height, 0.26), LAMP)
	parts.detail.box(xform, Vector3(0.12, height, 0.32), DARK_WOOD)
	parts.detail.box(xform, Vector3(width, 0.12, 0.32), DARK_WOOD)

## A ship's lantern standing on `at`: gold base and cap, glowing glass.
static func _lantern(parts: Parts, at: Vector3, k: float) -> void:
	parts.detail.rod(at, at + Vector3(0, 0.3 * k, 0), 0.5 * k, 0.62 * k, GOLD, 6)
	parts.glow.rod(at + Vector3(0, 0.3 * k, 0), at + Vector3(0, 1.4 * k, 0), 0.5 * k, 0.55 * k, LAMP, 6)
	parts.detail.rod(at + Vector3(0, 1.4 * k, 0), at + Vector3(0, 2.0 * k, 0), 0.72 * k, 0.1 * k, GOLD, 6)
	parts.detail.ball(at + Vector3(0, 2.1 * k, 0), Vector3.ONE * 0.18 * k, GOLD, 6, 4)

## One gun: a dark port, its lid swung up, and the barrel run out.
static func _cannon(parts: Parts, side: float, z: float, y: float, lid: bool) -> void:
	var x: float = side_x(z, y)
	parts.detail.block(Vector3(side * x, y, z), Vector3(0.24, 1.15, 1.35), BLACK)
	if lid:
		var hinge: Transform3D = Transform3D(Basis(Vector3.BACK, -side * 1.15), Vector3(side * (x + 0.5), y + 0.85, z))
		parts.detail.box(hinge, Vector3(0.14, 1.1, 1.35), RED)
	parts.detail.rod(Vector3(side * (x - 0.5), y, z), Vector3(side * (x + 1.5), y, z), 0.32, 0.25, IRON, 6)
	parts.detail.rod(Vector3(side * (x + 1.5), y, z), Vector3(side * (x + 1.75), y, z), 0.33, 0.33, IRON, 6)

static func _guns(parts: Parts) -> void:
	for side: float in [-1.0, 1.0]:
		# Lower and upper gun decks, staggered, then the deck guns in the waist.
		for index: int in 13:
			var z: float = -42.0 + 6.0 * index
			_cannon(parts, side, z, 2.8 + 0.3 * sheer(z), true)
		for index: int in 12:
			var z: float = -39.0 + 6.0 * index
			_cannon(parts, side, z, 6.2 + 0.6 * sheer(z), true)
		for index: int in 6:
			var z: float = -14.0 + 6.0 * index
			var y: float = deck_at(z) + 0.85
			_cannon(parts, side, z, y, false)
			# The carriage on deck behind the bulwark.
			var inboard: float = deck_half(z)
			parts.detail.block(Vector3(side * (inboard - 1.3), deck_at(z) + 0.3, z), Vector3(2.2, 0.6, 1.2), DARK_WOOD)
			parts.detail.rod(Vector3(side * (inboard - 2.3), y, z), Vector3(side * (inboard + 0.2), y, z), 0.42, 0.34, IRON, 6)
	# Two stern chasers below the gallery.
	for side: float in [-1.0, 1.0]:
		parts.detail.block(Vector3(side * 2.4, 6.4, STERN_Z), Vector3(1.3, 1.15, 0.24), BLACK)
		parts.detail.rod(Vector3(side * 2.4, 6.4, STERN_Z + 0.5), Vector3(side * 2.4, 6.4, STERN_Z - 1.4), 0.32, 0.25, IRON, 6)

## Carved stern castle: two rows of lit cabin windows, a gallery with a
## balustrade, gold carving, the taffrail crest, three great lanterns, the
## quarter galleries, the rudder and the ensign staff.
static func _stern(parts: Parts) -> void:
	var s: Batch = parts.structure
	var d: Batch = parts.detail
	var z: float = STERN_Z
	var top: float = rail_at(z)
	s.block(Vector3(0, 1.0, z - 0.9), Vector3(0.6, 9.0, 2.2), DARK_WOOD)
	# The inside of the stern bulwark, seen from the poop deck.
	s.block(Vector3(0, deck_at(z) + BULWARK * 0.5 - 0.05, z + 0.32), Vector3(deck_half(z) * 2.0 + 0.6, BULWARK, 0.5), DARK_WOOD)
	for index: int in 5:
		var x: float = (index - 2) * 2.4
		_window(parts, Vector3(x, 10.6, z - 0.06), Vector3.FORWARD, 1.5, 1.7)
		_window(parts, Vector3(x * 0.95, 16.3, z - 0.06), Vector3.FORWARD, 1.4, 1.9)
	# The gallery: a balcony across the stern with turned balusters.
	s.block(Vector3(0, 13.4, z - 0.9), Vector3(14.0, 0.4, 1.9), DARK_WOOD)
	s.ink = 0.5
	s.block(Vector3(0, 14.7, z - 1.7), Vector3(14.0, 0.28, 0.3), GOLD)
	s.block(Vector3(0, 12.5, z - 0.2), Vector3(15.0, 0.5, 0.4), GOLD)
	s.block(Vector3(0, 18.3, z - 0.2), Vector3(14.2, 0.5, 0.4), GOLD)
	s.block(Vector3(0, 8.6, z - 0.2), Vector3(15.6, 0.45, 0.4), GOLD)
	for index: int in 15:
		d.rod(Vector3(-6.7 + index * 0.957, 13.6, z - 1.7), Vector3(-6.7 + index * 0.957, 14.6, z - 1.7), 0.16, 0.11, GOLD, 5)
	for side: float in [-1.0, 1.0]:
		var bracket: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.7), Vector3(side * 5.2, 12.7, z - 0.8))
		d.box(bracket, Vector3(0.4, 0.35, 2.0), GOLD)
	# Taffrail: a gold arch with a crest and finials above the poop rail.
	s.block(Vector3(0, top + 0.2, z - 0.1), Vector3(14.0, 0.7, 0.6), GOLD)
	s.block(Vector3(0, top + 1.0, z - 0.1), Vector3(6.0, 1.1, 0.5), RED)
	s.block(Vector3(0, top + 1.7, z - 0.1), Vector3(6.6, 0.35, 0.6), GOLD)
	s.ball(Vector3(0, top + 1.05, z - 0.4), Vector3(0.75, 0.75, 0.3), GOLD)
	s.ink = 1.0
	for side: float in [-1.0, 1.0]:
		d.ball(Vector3(side * 6.7, top + 0.95, z - 0.1), Vector3.ONE * 0.45, GOLD, 6, 4)
		# Scrolls stepping down from the crest.
		d.block(Vector3(side * 4.0, top + 0.85, z - 0.1), Vector3(1.6, 0.6, 0.5), GOLD)
		d.block(Vector3(side * 5.3, top + 0.7, z - 0.1), Vector3(1.0, 0.3, 0.5), GOLD)
	for index: int in 3:
		var x: float = (index - 1) * 4.6
		var lift: float = 2.0 if index == 1 else 0.6
		d.rod(Vector3(x, top + 0.3, z - 0.5), Vector3(x, top + 0.6 + lift, z - 1.0), 0.14, 0.12, IRON, 5)
		_lantern(parts, Vector3(x, top + 0.6 + lift, z - 1.0), 1.25 if index == 1 else 1.0)
	# Ensign staff, raked aft.
	s.ink = 0.5
	s.rod(Vector3(0, top - 0.5, z - 1.2), Vector3(0, 31.0, z - 2.9), 0.2, 0.12, WOOD, 6)
	s.ball(Vector3(0, 31.1, z - 2.9), Vector3.ONE * 0.28, GOLD, 6, 4)
	s.ink = 1.0
	# Quarter galleries: a windowed bay on each side of the stern.
	for side: float in [-1.0, 1.0]:
		var x: float = side_x(-46.5, 14.5) + 0.35
		s.block(Vector3(side * x, 14.6, -46.5), Vector3(1.8, 4.4, 9.0), NAVY)
		s.block(Vector3(side * (x - 0.1), 12.0, -46.5), Vector3(1.4, 0.9, 8.0), DARK_WOOD)
		s.ink = 0.5
		s.block(Vector3(side * x, 17.0, -46.5), Vector3(2.2, 0.4, 9.4), GOLD)
		s.block(Vector3(side * x, 12.5, -46.5), Vector3(2.1, 0.3, 9.3), GOLD)
		s.ink = 1.0
		d.rod(Vector3(side * x, 17.2, -46.5), Vector3(side * x, 18.2, -46.5), 0.9, 0.05, RED, 6)
		for index: int in 3:
			_window(parts, Vector3(side * (x + 0.88), 14.9, -49.3 + index * 2.8), Vector3(side, 0, 0), 1.4, 1.7)

## Rails, balusters and stairs at the three deck breaks, with a cabin door and
## lit windows in each bulkhead.
static func _breaks(parts: Parts) -> void:
	var s: Batch = parts.structure
	var d: Batch = parts.detail
	for step: float in BREAKS:
		# `high` is the side of the break with the higher deck.
		var aft_high: bool = deck_at(step - 0.1) > deck_at(step + 0.1)
		var way: float = 1.0 if aft_high else -1.0
		var high: float = deck_at(step - way * 0.1)
		var low: float = deck_at(step + way * 0.1)
		var half: float = deck_half(step - way * 0.3)
		var rail_half: float = half - 2.7
		var rail_z: float = step - way * 0.25
		s.ink = 0.5
		s.block(Vector3(0, high + 1.25, rail_z), Vector3(rail_half * 2.0, 0.25, 0.4), GOLD)
		s.ink = 1.0
		var count: int = int(rail_half * 2.0 / 0.9)
		for index: int in count + 1:
			var x: float = lerpf(-rail_half + 0.2, rail_half - 0.2, float(index) / count)
			d.rod(Vector3(x, high, rail_z), Vector3(x, high + 1.2, rail_z), 0.17, 0.11, CREAM, 5)
		# Stairs on both sides, running down onto the lower deck.
		var treads: int = 8
		for side: float in [-1.0, 1.0]:
			for index: int in treads:
				var t: float = (index + 0.5) / treads
				d.block(Vector3(side * (half - 1.4), lerpf(high, low, t) - 0.12, step + way * (0.3 + t * 4.4)), Vector3(2.2, 0.24, 0.7), PLANK)
			var slope: Transform3D = Transform3D(Basis(Vector3.RIGHT, way * atan2(high - low, 4.4)), Vector3(side * (half - 2.55), (high + low) * 0.5 - 0.3, step + way * 2.5))
			d.box(slope, Vector3(0.18, 0.5, sqrt(pow(high - low, 2.0) + 19.4)), DARK_WOOD)
		# Door and windows in the bulkhead, facing the lower deck.
		var out: Vector3 = Vector3(0, 0, way)
		d.block(Vector3(0, low + 1.25, step + way * 0.06), Vector3(1.7, 2.5, 0.2), DARK_WOOD)
		d.block(Vector3(0.5, low + 1.3, step + way * 0.18), Vector3(0.16, 0.16, 0.16), GOLD)
		for side: float in [-1.0, 1.0]:
			_window(parts, Vector3(side * 3.2, low + 1.8, step + way * 0.07), out, 1.2, 1.2)
		for side: float in [-1.0, 1.0]:
			d.rod(Vector3(side * (rail_half - 0.1), high + 1.3, rail_z), Vector3(side * (rail_half - 0.1), high + 2.0, rail_z), 0.1, 0.1, IRON, 5)
			_lantern(parts, Vector3(side * (rail_half - 0.1), high + 2.0, rail_z), 0.6)

## On deck: the ship's wheel and binnacle, hatch gratings, capstan, barrels,
## crates, the belfry and the anchors on their catheads.
static func _deck(parts: Parts) -> void:
	var s: Batch = parts.structure
	var d: Batch = parts.detail
	# Ship's wheel on the quarterdeck, just behind its rail.
	var wheel: Vector3 = Vector3(0, deck_at(-21.0) + 1.9, -21.0)
	d.block(Vector3(0, deck_at(-21.0) + 0.95, -21.0), Vector3(0.6, 1.9, 0.9), DARK_WOOD)
	d.rod(wheel - Vector3(0, 0, 0.6), wheel + Vector3(0, 0, 0.6), 0.28, 0.28, GOLD, 6)
	for index: int in 12:
		var first: float = TAU * index / 12.0
		var second: float = TAU * (index + 1) / 12.0
		for z: float in [-0.5, 0.5]:
			d.rod(wheel + Vector3(cos(first) * 1.35, sin(first) * 1.35, z), wheel + Vector3(cos(second) * 1.35, sin(second) * 1.35, z), 0.13, 0.13, WOOD, 5)
		if index % 2 == 0: continue
		for z: float in [-0.5, 0.5]:
			d.rod(wheel + Vector3(0, 0, z), wheel + Vector3(cos(first) * 1.85, sin(first) * 1.85, z), 0.09, 0.07, GOLD, 4)
	d.block(Vector3(0, deck_at(-19.5) + 0.6, -19.4), Vector3(0.9, 1.2, 0.7), WOOD)
	d.ball(Vector3(0, deck_at(-19.5) + 1.3, -19.4), Vector3.ONE * 0.36, GOLD, 6, 4)
	# Hatch gratings and the capstan in the waist.
	for hatch: Array in [[7.0, 6.0, 8.0], [-10.0, 4.4, 5.0]]:
		var y: float = deck_at(hatch[0])
		s.block(Vector3(0, y + 0.25, hatch[0]), Vector3(hatch[1], 0.5, hatch[2]), DARK_WOOD)
		for index: int in int(hatch[1] / 0.8):
			d.block(Vector3(-hatch[1] / 2.0 + 0.6 + index * 0.8, y + 0.53, hatch[0]), Vector3(0.28, 0.1, hatch[2] - 0.8), OCHRE)
	var capstan: float = deck_at(15.0)
	s.rod(Vector3(0, capstan, 15.0), Vector3(0, capstan + 1.5, 15.0), 1.1, 0.8, WOOD, 8)
	s.rod(Vector3(0, capstan + 1.5, 15.0), Vector3(0, capstan + 1.9, 15.0), 1.2, 1.2, GOLD, 8)
	for index: int in 6:
		var turn: float = TAU * index / 6.0
		d.rod(Vector3(0, capstan + 1.7, 15.0), Vector3(cos(turn) * 3.0, capstan + 1.7, 15.0 + sin(turn) * 3.0), 0.12, 0.09, DARK_WOOD, 4)
	for barrel: Vector3 in [Vector3(6.4, 0, -14.6), Vector3(5.0, 0, -15.6), Vector3(6.5, 0, -16.2), Vector3(-6.3, 0, 12.5), Vector3(-5.2, 0, 11.4)]:
		var y: float = deck_at(barrel.z)
		d.rod(Vector3(barrel.x, y, barrel.z), Vector3(barrel.x, y + 0.75, barrel.z), 0.5, 0.62, WOOD, 7)
		d.rod(Vector3(barrel.x, y + 0.75, barrel.z), Vector3(barrel.x, y + 1.5, barrel.z), 0.62, 0.5, WOOD, 7)
		d.rod(Vector3(barrel.x, y + 0.66, barrel.z), Vector3(barrel.x, y + 0.84, barrel.z), 0.65, 0.65, IRON, 7, false)
	d.block(Vector3(-6.0, deck_at(-13.0) + 0.6, -13.0), Vector3(1.6, 1.2, 1.6), OCHRE)
	d.block(Vector3(-6.2, deck_at(-15.0) + 0.45, -15.0), Vector3(1.2, 0.9, 1.4), WOOD)
	# Belfry on the forecastle rail: two posts, a beam and a gold bell.
	var bell: float = deck_at(21.5)
	for side: float in [-1.0, 1.0]:
		d.block(Vector3(side * 0.8, bell + 1.1, 21.5), Vector3(0.25, 2.2, 0.25), RED)
	d.block(Vector3(0, bell + 2.3, 21.5), Vector3(2.2, 0.3, 0.5), RED)
	d.rod(Vector3(0, bell + 1.3, 21.5), Vector3(0, bell + 2.1, 21.5), 0.5, 0.2, GOLD, 6)
	# Catheads and anchors at the bow.
	for side: float in [-1.0, 1.0]:
		var x: float = side_x(37.0, rail_at(37.0))
		var top: float = rail_at(37.0)
		s.block(Vector3(side * (x + 0.6), top - 0.1, 37.0), Vector3(3.0, 0.55, 0.55), DARK_WOOD)
		var ring: Vector3 = Vector3(side * (x + 1.7), top - 0.6, 37.0)
		var crown: Vector3 = Vector3(side * (x + 1.3), top - 6.4, 36.2)
		d.rod(ring, crown, 0.2, 0.24, IRON, 5)
		d.block(ring - Vector3(0, 0.5, 0), Vector3(0.3, 0.3, 3.2), DARK_WOOD)
		for arm: float in [-1.0, 1.0]:
			var fluke: Vector3 = crown + Vector3(0, 1.3, arm * 1.7)
			d.rod(crown, fluke, 0.22, 0.14, IRON, 5)
			d.block(fluke, Vector3(0.2, 0.8, 0.7), IRON)
		_lantern(parts, Vector3(side * (deck_half(24.0) - 0.4), rail_at(24.0), 24.0), 0.6)

## Beakhead, head rails, the gold figurehead and the bowsprit with its yard.
static func _bow(parts: Parts) -> void:
	var s: Batch = parts.structure
	var d: Batch = parts.detail
	s.rod(Vector3(0, 4.0, STEM_Z - 0.6), Vector3(0, 12.2, 51.0), 1.2, 0.6, DARK_WOOD, 6)
	s.box(Transform3D(Basis(Vector3.RIGHT, -0.16), Vector3(0, 12.2, 47.0)), Vector3(3.0, 0.35, 7.5), PLANK)
	s.ink = 0.5
	for side: float in [-1.0, 1.0]:
		s.rod(Vector3(side * side_x(40.0, 13.0), 13.4, 40.0), Vector3(side * 0.7, 13.6, 51.2), 0.28, 0.2, GOLD, 5)
		s.rod(Vector3(side * side_x(41.0, 10.5), 10.6, 41.0), Vector3(side * 0.5, 12.0, 51.0), 0.26, 0.2, GOLD, 5)
		for index: int in 4:
			var t: float = (index + 0.5) / 4.0
			d.rod(Vector3(side * lerpf(side_x(41.0, 10.5), 0.5, t), lerpf(10.6, 12.0, t), lerpf(41.0, 51.0, t)), Vector3(side * lerpf(side_x(40.0, 13.0), 0.7, t), lerpf(13.4, 13.6, t), lerpf(40.0, 51.2, t)), 0.12, 0.12, RED, 4)
	# Figurehead: a gold figure leaning out over the sea, crowned, arms swept back.
	s.rod(Vector3(0, 11.6, 50.4), Vector3(0, 14.6, 52.6), 1.0, 0.7, GOLD, 7)
	s.ball(Vector3(0, 15.5, 53.1), Vector3(0.9, 0.95, 0.9), GOLD, 8, 5)
	s.rod(Vector3(0, 16.2, 53.0), Vector3(0, 16.9, 52.9), 0.55, 0.75, GOLD, 6)
	s.ball(Vector3(0, 11.2, 50.0), Vector3(0.9, 0.9, 0.9), GOLD, 7, 4)
	for side: float in [-1.0, 1.0]:
		s.rod(Vector3(side * 0.75, 14.3, 52.3), Vector3(side * 1.7, 12.6, 50.0), 0.3, 0.2, GOLD, 5)
		d.ball(Vector3(side * 0.34, 15.7, 53.9), Vector3.ONE * 0.16, BLACK, 5, 3)
	s.ink = 1.0
	# Bowsprit and the spritsail yard slung under it.
	s.rod(Vector3(0, 13.0, 39.0), Vector3(0, 23.0, 56.0), 0.75, 0.38, WOOD, 8)
	s.ink = 0.6
	for side: float in [-1.0, 1.0]:
		s.rod(Vector3(0, 18.6, 49.4), Vector3(side * 8.0, 18.6, 49.4), 0.32, 0.18, WOOD, 6)
	s.ink = 1.0
	for side: float in [-1.0, 1.0]:
		parts.rigging.rod(Vector3(side * 8.0, 18.6, 49.4), Vector3(0, 22.8, 55.6), 0.07, 0.07, ROPE, 4, false)
		parts.rigging.rod(Vector3(side * 8.0, 18.6, 49.4), Vector3(side * side_x(34.0, 14.0), rail_at(34.0), 34.0), 0.07, 0.07, ROPE, 4, false)

## Masts in three lengths, the tops (the main one a crow's nest), crosstrees,
## yards, and all the standing and running rigging with ratlines.
static func _masts(parts: Parts) -> void:
	var s: Batch = parts.structure
	var d: Batch = parts.detail
	var r: Batch = parts.rigging
	for label: String in MASTS:
		var mast: Dictionary = MASTS[label]
		var z: float = mast.z
		var radius: float = mast.r
		var deck: float = deck_at(z)
		var top: float = mast.top
		var cross: float = mast.cross
		var truck: float = mast.truck
		s.ink = 1.0
		s.rod(Vector3(0, deck - 0.5, z), Vector3(0, top + 1.6, z), radius, radius * 0.8, WOOD, 10)
		s.rod(Vector3(0, top - 1.0, z + radius), Vector3(0, cross + 1.2, z + radius * 0.4), radius * 0.6, radius * 0.45, WOOD, 8)
		s.ink = 0.6
		s.rod(Vector3(0, cross - 0.8, z + radius * 0.6), Vector3(0, truck, z + radius * 0.2), radius * 0.36, radius * 0.2, WOOD, 6)
		s.ball(Vector3(0, truck + 0.2, z + radius * 0.2), Vector3.ONE * 0.4, GOLD, 6, 4)
		# Pennant staff above the truck.
		s.rod(Vector3(0, truck, z + radius * 0.2 - 0.3), Vector3(0, truck + (6.5 if label == "Main" else 2.5), z - 0.3), 0.14, 0.09, WOOD, 5)
		s.ink = 1.0
		for band: int in int((top - deck) / 5.0):
			d.rod(Vector3(0, deck + 3.0 + band * 5.0, z), Vector3(0, deck + 3.4 + band * 5.0, z), radius * 0.98 + 0.06, radius * 0.97 + 0.06, GOLD, 10, false)
		if label == "Main":
			# The crow's nest: a tub with a gold rim round the main top.
			s.rod(Vector3(0, top - 0.3, z), Vector3(0, top, z), 1.4, 2.6, DARK_WOOD, 12)
			s.rod(Vector3(0, top, z), Vector3(0, top + 1.6, z), 2.6, 2.9, WOOD, 12)
			s.ink = 0.5
			s.rod(Vector3(0, top + 1.6, z), Vector3(0, top + 1.9, z), 3.0, 3.0, GOLD, 12)
			s.ink = 1.0
			_lantern(parts, Vector3(0, top + 1.9, z - 2.6), 0.55)
		else:
			s.rod(Vector3(0, top - 0.2, z), Vector3(0, top + 0.2, z), 2.3, 2.3, DARK_WOOD, 10)
			for index: int in 10:
				var turn: float = TAU * index / 10.0
				d.rod(Vector3(cos(turn) * 2.15, top + 0.2, z + sin(turn) * 2.15), Vector3(cos(turn) * 2.15, top + 1.3, z + sin(turn) * 2.15), 0.08, 0.08, DARK_WOOD, 4)
				var next: float = TAU * (index + 1) / 10.0
				d.rod(Vector3(cos(turn) * 2.15, top + 1.3, z + sin(turn) * 2.15), Vector3(cos(next) * 2.15, top + 1.3, z + sin(next) * 2.15), 0.08, 0.08, GOLD, 4)
		s.block(Vector3(0, cross, z + radius * 0.5), Vector3(3.2, 0.3, 0.5), DARK_WOOD)
		s.block(Vector3(0, cross, z + radius * 0.5), Vector3(0.5, 0.3, 2.4), DARK_WOOD)
		# Yards, their lifts and braces.
		var yard_z: float = z + radius + 0.35
		var aft_z: float = z - 26.0
		for yard: Array in mast.yards:
			var y: float = yard[0]
			var half: float = float(yard[1]) / 2.0
			s.ink = 0.7
			for side: float in [-1.0, 1.0]:
				s.rod(Vector3(0, y, yard_z), Vector3(side * half, y, yard_z), 0.42, 0.2, DARK_WOOD, 6)
				r.rod(Vector3(side * half, y, yard_z), Vector3(0, y + half * 0.45, z + radius * 0.5), 0.06, 0.06, ROPE, 4, false)
				var brace: Vector3 = Vector3(side * 1.0, y - 6.0, aft_z) if label != "Mizzen" else Vector3(side * 6.0, rail_at(-51.0), -51.0)
				if label == "Main" and y < 30.0: brace = Vector3(side * side_x(-40.0, 30.0), rail_at(-40.0), -40.0)
				r.rod(Vector3(side * half, y, yard_z), brace, 0.06, 0.06, ROPE, 4, false)
			s.ink = 1.0
		# Sheets from the foot of the course down to the rail.
		if float(mast.foot) > 0.0:
			for side: float in [-1.0, 1.0]:
				var clew: Vector3 = Vector3(side * (float(mast.yards[0][1]) / 2.0 - 1.0), float(mast.foot), yard_z + 0.4)
				r.rod(clew, Vector3(side * side_x(z - 9.0, 30.0), rail_at(z - 9.0), z - 9.0), 0.07, 0.07, ROPE, 4, false)
				r.rod(clew, Vector3(side * side_x(z + 7.0, 30.0), rail_at(z + 7.0), z + 7.0), 0.07, 0.07, ROPE, 4, false)
		for side: float in [-1.0, 1.0]:
			# Channel on the hull side, deadeyes, and five shrouds up to the top.
			var feet: Array[Vector3] = []
			for index: int in 5:
				var foot_z: float = z + 0.8 - index * 1.5
				feet.append(Vector3(side * (side_x(foot_z, rail_at(foot_z)) + 0.55), rail_at(foot_z) - 0.25, foot_z))
			s.block((feet[0] + feet[4]) * 0.5 - Vector3(side * 0.2, 0.2, 0), Vector3(1.2, 0.25, 7.6), DARK_WOOD)
			var head: Vector3 = Vector3(side * (2.3 if label == "Main" else 2.0), top - 0.2, z)
			for foot: Vector3 in feet:
				d.rod(foot - Vector3(0, 0.1, 0), foot + Vector3(0, 0.7, 0), 0.22, 0.22, BLACK, 5)
				r.rod(foot, head + Vector3(0, 0, (foot.z - z) * 0.2), 0.09, 0.09, ROPE, 4, false)
			_ratlines(r, feet[0], head + Vector3(0, 0, (feet[0].z - z) * 0.2), feet[4], head + Vector3(0, 0, (feet[4].z - z) * 0.2))
			# Topmast shrouds from the rim of the top to the crosstrees.
			var rim: float = 2.7 if label == "Main" else 2.2
			var upper: Vector3 = Vector3(side * 0.5, cross, z + radius * 0.5)
			for index: int in 3:
				r.rod(Vector3(side * rim, top + 0.3, z + 1.0 - index), upper, 0.07, 0.07, ROPE, 4, false)
			_ratlines(r, Vector3(side * rim, top + 0.3, z + 1.0), upper, Vector3(side * rim, top + 0.3, z - 1.0), upper)
			# Backstays from the crosstrees and the truck to the rail.
			for run: Array in [[cross, 8.0], [truck - 0.5, 11.0]]:
				var at: float = z - float(run[1])
				r.rod(Vector3(side * 0.3, run[0], z + radius * 0.3), Vector3(side * (side_x(at, rail_at(at)) + 0.3), rail_at(at), at), 0.07, 0.07, ROPE, 4, false)
	# Stays down the middle of the ship, mast to mast and out to the bowsprit.
	var fore: Dictionary = MASTS.Fore
	var main: Dictionary = MASTS.Main
	var mizzen: Dictionary = MASTS.Mizzen
	for stay: Array in [
			[Vector3(0, fore.top, fore.z), Vector3(0, 19.6, 50.0)], [Vector3(0, fore.cross, fore.z), Vector3(0, 22.6, 55.4)],
			[Vector3(0, fore.truck - 0.5, fore.z), Vector3(0, 23.0, 56.0)],
			[Vector3(0, main.top, main.z), Vector3(0, deck_at(fore.z - 1.5) + 2.5, fore.z - 1.0)], [Vector3(0, main.cross, main.z), Vector3(0, fore.top, fore.z)],
			[Vector3(0, main.truck - 0.5, main.z), Vector3(0, fore.cross, fore.z)],
			[Vector3(0, mizzen.top, mizzen.z), Vector3(0, deck_at(main.z - 1.5) + 8.0, main.z - 1.0)], [Vector3(0, mizzen.cross, mizzen.z), Vector3(0, main.top, main.z)],
			[Vector3(0, mizzen.truck - 0.5, mizzen.z), Vector3(0, main.cross, main.z)]]:
		r.rod(stay[0], stay[1], 0.1, 0.1, ROPE, 4, false)
	# The lateen yard slung across the mizzen, its sheet and its lift.
	s.ink = 0.7
	s.rod(Vector3(1.1, 18.2, -23.2), Vector3(1.1, 37.4, -47.6), 0.36, 0.2, DARK_WOOD, 6)
	s.ink = 1.0
	r.rod(Vector3(1.1, 37.4, -47.6), Vector3(0, mizzen.cross, mizzen.z), 0.06, 0.06, ROPE, 4, false)
	r.rod(Vector3(1.1, 21.5, -50.0), Vector3(3.0, rail_at(-51.5), -51.5), 0.07, 0.07, ROPE, 4, false)
	r.rod(Vector3(1.1, 18.2, -23.2), Vector3(4.0, deck_at(-21.0), -20.0), 0.07, 0.07, ROPE, 4, false)

## Rope rungs every 1.5 m between two shrouds (a0 -> a1 and b0 -> b1).
static func _ratlines(rigging: Batch, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> void:
	var rungs: int = int((a1.y - a0.y) / 1.5)
	for index: int in range(1, rungs):
		var t: float = float(index) / rungs
		rigging.rod(a0.lerp(a1, t), b0.lerp(b1, t), 0.05, 0.05, ROPE, 4, false)

## Mooring bitts with the four markers the mooring lines leave from
## (features/ports/mooring_lines.gd), on the forecastle and the poop.
static func _mooring(root: Node3D, parts: Parts) -> void:
	for end: Array in [["Bow", 24.0], ["Stern", -46.0]]:
		var z: float = end[1]
		for side: float in [-1.0, 1.0]:
			var lead: Vector3 = Vector3(side * side_x(z, rail_at(z)), rail_at(z), z)
			parts.detail.block(lead + Vector3(-side * 0.3, 0.2, 0), Vector3(0.8, 0.5, 1.8), BLACK)
			for offset: float in [-1.0, 1.0]:
				var at: Vector3 = Vector3(side * (deck_half(z) - 1.6), deck_at(z), z + offset)
				parts.detail.rod(at, at + Vector3(0, 1.4, 0), 0.38, 0.38, BLACK, 6)
				parts.detail.rod(at + Vector3(0, 1.4, 0), at + Vector3(0, 1.65, 0), 0.55, 0.55, BLACK, 6)
			var marker: Marker3D = Marker3D.new()
			marker.name = "Mooring%s%s" % [end[0], "L" if side < 0.0 else "R"]
			marker.position = lead + Vector3(0, 0.5, 0)
			root.add_child(marker)

# --- Assembly ---------------------------------------------------------------

static func _toon(outline: bool) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = TOON_SHADER
	material.set_shader_parameter("use_vertex_color", true)
	if outline:
		var ink: ShaderMaterial = ShaderMaterial.new()
		ink.shader = OUTLINE_SHADER
		material.next_pass = ink
	return material

## Builds every mesh once; later ships (the hangar's and the one sailing) share them.
static func meshes() -> Dictionary:
	if not _meshes.is_empty(): return _meshes
	var parts: Parts = Parts.new()
	parts.detail.ink = 0.3
	_guns(parts)
	_stern(parts)
	_breaks(parts)
	_deck(parts)
	_bow(parts)
	_masts(parts)
	var holder: Node3D = Node3D.new()
	_mooring(holder, parts)
	var markers: Dictionary = {}
	for marker: Node in holder.get_children(): markers[String(marker.name)] = (marker as Marker3D).position
	holder.free()
	var outlined: ShaderMaterial = _toon(true)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	_meshes = {
		"Hull": hull_mesh(), "Structure": parts.structure.mesh(outlined), "Detail": parts.detail.mesh(outlined),
		"Rigging": parts.rigging.mesh(_toon(false)), "Sails": sails_mesh(), "Glow": parts.glow.mesh(glow),
		"Flags": flags_mesh(), "markers": markers,
	}
	return _meshes

## Fills chunky_look's model root: `hull` is its Hull node.
static func dress(root: Node3D, hull: MeshInstance3D, definition: ShipDefinition) -> void:
	var built: Dictionary = meshes()
	# The model is drawn for SIZE_M; a record of another size stretches it to fit.
	var fit: Vector3 = Vector3(definition.hull_size_m.x / SIZE_M.x, 1.0, definition.hull_size_m.z / SIZE_M.z)
	hull.mesh = built.Hull
	hull.scale = fit
	for label: String in ["Structure", "Detail", "Rigging", "Sails", "Glow", "Flags"]:
		var node: MeshInstance3D = MeshInstance3D.new()
		node.name = label
		node.mesh = built[label]
		node.scale = fit
		root.add_child(node)
		match label:
			"Detail": node.visibility_range_end = DETAIL_RANGE_M
			"Rigging":
				node.visibility_range_end = RIGGING_RANGE_M
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"Glow": node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# The shader moves the cloth sideways: keep it from being culled early.
			"Flags": node.extra_cull_margin = 3.0
	for label: String in built.markers:
		var marker: Marker3D = Marker3D.new()
		marker.name = label
		marker.position = built.markers[label] * fit
		root.add_child(marker)
