extends RefCounted
## Patch 2.9.1 item 2: the pirate brigantine, built in code from the galleon's
## pieces (merged batches, custom outline, flag shader). A 64 x 14 m two-master:
## a low black hull with a red wale and a raised quarterdeck, lit stern windows,
## deck guns behind the bulwarks, swivel guns, a skull figurehead, a square-rigged
## foremast and a gaff-rigged mainmast under red sails, a ship's wheel, an
## upturned longboat, lanterns, and its own flag (a skull over crossed cutlasses).
## Looks only: the collider, wake and rules come from the ship record.
##
## Frame time: seven meshes like the galleon, built once and cached; the small
## detail and the rigging stop drawing past DETAIL_RANGE_M / RIGGING_RANGE_M.
const GALLEON = preload("res://features/toon/pirate_galleon.gd")

## The hull the model is drawn for; the record (pirate_brigantine_ship.tres) matches.
const SIZE_M: Vector3 = Vector3(14, 5, 64)
const STERN_Z: float = -30.0
const STEM_Z: float = 24.0
const HALF_BEAM: float = 6.6
const BULWARK: float = 1.2
## Where the quarterdeck steps down to the main deck.
const BREAK_Z: float = -14.0
const DETAIL_RANGE_M: float = 500.0
const RIGGING_RANGE_M: float = 380.0
## Nothing may stand taller than this (the galleon's 55 m already clears the bridges).
const AIR_DRAFT_M: float = 42.0

const WOOD: Color = GALLEON.WOOD
const DARK_WOOD: Color = GALLEON.DARK_WOOD
const PLANK: Color = GALLEON.PLANK
const GOLD: Color = GALLEON.GOLD
const IRON: Color = GALLEON.IRON
const ROPE: Color = GALLEON.ROPE
const BONE: Color = GALLEON.BONE
const BLACK: Color = Color("2b2a33")
const CRIMSON: Color = Color("c23a2e")
const VERDIGRIS: Color = Color("4f9c8a")
const SAIL: Color = Color("cf4a3a")
const SAIL_SEAM: Color = Color("bd3f33")
const FLAG_BLACK: Color = Color("1c1b22")

## The brigantine's own flag: a skull over crossed cutlasses.
const FLAG: Array[String] = [
	".....................",
	".......#######.......",
	"......#########......",
	"......##..#..##......",
	"......##..#..##......",
	"......#########......",
	".......###.###.......",
	"........#.#.#........",
	".##...............##.",
	"...###.........###...",
	"......#########......",
	"...###.........###...",
	".##...............##.",
	".....................",
]

## Lower mast head (the top), crosstrees and truck heights, and each yard as
## [height, width]. The foremast is square-rigged; the mainmast carries the
## gaff mainsail and its topsail.
const MASTS = {
	"Fore": {"z": 9.0, "r": 0.55, "top": 18.5, "cross": 27.0, "truck": 34.0, "yards": [[17.2, 17.0], [25.6, 13.0], [32.2, 9.0]], "foot": 9.6},
	"Main": {"z": -10.0, "r": 0.6, "top": 20.5, "cross": 30.0, "truck": 37.5, "yards": [], "foot": 0.0},
}
## The gaff mainsail's corners, in the ship's centre plane.
const GAFF_TACK: Vector3 = Vector3(0, 13.0, -10.9)
const GAFF_THROAT: Vector3 = Vector3(0, 21.2, -10.9)
const GAFF_PEAK: Vector3 = Vector3(0, 28.9, -23.8)
const GAFF_CLEW: Vector3 = Vector3(0, 13.3, -28.6)
const JIBBOOM_END: Vector3 = Vector3(0, 12.6, 31.4)

static var _meshes: Dictionary = {}

# --- Hull shape -------------------------------------------------------------

## Hull width along the length as a share of the beam: a narrow transom, a
## full middle and a long fine bow.
static func plan(z: float) -> float:
	var t: float = clampf((z - STERN_Z) / (STEM_Z - STERN_Z), 0.0, 1.0)
	var bow: float = clampf((t - 0.55) / 0.45, 0.0, 1.0)
	return maxf(lerpf(0.62, 1.0, smoothstep(0.0, 0.4, t)) * sqrt(maxf(0.0, 1.0 - pow(bow, 2.0))), 0.03)

static func sheer(z: float) -> float:
	return 0.9 * pow((z + 3.0) / 27.0, 2.0)

static func deck_at(z: float) -> float:
	return (7.6 if z < BREAK_Z else 5.0) + sheer(z)

static func rail_at(z: float) -> float:
	return deck_at(z) + BULWARK

## Half the hull section at z, from the deck edge up the inside of the bulwark,
## over the rail and down the outside to the keel: (half width, height).
static func profile(z: float) -> PackedVector2Array:
	var w: float = HALF_BEAM * plan(z)
	var s: float = sheer(z)
	var deck: float = deck_at(z)
	var top: float = deck + BULWARK
	var t: float = clampf((z - STERN_Z) / (STEM_Z - STERN_Z), 0.0, 1.0)
	var run: float = lerpf(0.4, 1.0, smoothstep(0.0, 0.3, t)) * lerpf(1.0, 0.4, smoothstep(0.65, 1.0, t))
	var wale: float = 4.0 + 0.8 * s
	var inner: float = maxf(0.88 * w - 0.4, 0.02)
	return PackedVector2Array([
		Vector2(inner, deck), Vector2(inner, top), Vector2(0.88 * w, top), Vector2(0.9 * w, top - 0.35),
		Vector2(0.94 * w, wale), Vector2(0.96 * w, wale - 0.5), Vector2(w, 2.6 + 0.6 * s), Vector2(w, 0.9 + 0.3 * s),
		Vector2(0.99 * w, 0.35 + 0.3 * s), Vector2(0.9 * w, -0.9), Vector2(0.4 * w * run, -3.2)])

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
	return maxf(0.88 * HALF_BEAM * plan(z) - 0.4, 0.02)

## One smooth surface, like the galleon's hull, so the ink outline has no gaps.
static func hull_mesh() -> ArrayMesh:
	var stations: Array[float] = []
	var z: float = STERN_Z
	while z <= STEM_Z + 0.001:
		stations.append(z)
		z += 1.5 if z < 16.0 else 0.75
	stations.append(BREAK_Z - 0.01)
	stations.append(BREAK_Z + 0.01)
	stations.sort()
	# Inside of the bulwark, rail, cap, upper side, wale, side, side, boot top, bottom, bottom, keel.
	var bands: Array[Color] = [CRIMSON, BONE, BONE, BLACK, CRIMSON, BLACK, BLACK, BONE, VERDIGRIS, VERDIGRIS, VERDIGRIS]
	var points: int = bands.size()
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
			surface.set_color(bands[side if side < points else count - 2 - side].srgb_to_linear())
			for corner: Vector3 in [a[side], b[side], b[side + 1], a[side], b[side + 1], a[side + 1]]:
				surface.add_vertex(corner)
		# The deck, and at the break the bulkhead under the quarterdeck.
		var wall: bool = stations[index + 1] - stations[index] < 0.1
		surface.set_smooth_group(2 if wall else 1)
		surface.set_color((WOOD if wall else PLANK).srgb_to_linear())
		for corner: Vector3 in [a[0], a[count - 1], b[count - 1], a[0], b[count - 1], b[0]]:
			surface.add_vertex(corner)
	# Flat transom in level strips, and the stem.
	var transom: Array[Color] = [BONE, BLACK, CRIMSON, BLACK, BLACK, BONE, VERDIGRIS, VERDIGRIS]
	var stern: PackedVector3Array = rings[0]
	surface.set_smooth_group(3)
	for side: int in range(2, points - 1):
		surface.set_color(transom[side - 2].srgb_to_linear())
		GALLEON._face(surface, stern[side], stern[side + 1], stern[count - 2 - side], Vector3.FORWARD)
		GALLEON._face(surface, stern[side], stern[count - 2 - side], stern[count - 1 - side], Vector3.FORWARD)
	surface.set_smooth_group(0)
	var stem: PackedVector3Array = rings[rings.size() - 1]
	surface.set_color(BLACK.srgb_to_linear())
	for side: int in count:
		GALLEON._face(surface, Vector3(0, 3.5, STEM_Z), stem[side], stem[(side + 1) % count], Vector3.BACK)
	surface.generate_normals()
	surface.index()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	surface.set_material(material)
	return surface.commit()

# --- Sails and flags --------------------------------------------------------

## The four-cornered gaff sail, bellied to one side. A thin closed shell like
## the galleon's sails so the toon outline can wrap it.
static func _gaff_sail(surface: SurfaceTool, tack: Vector3, throat: Vector3, peak: Vector3, clew: Vector3, belly: Vector3) -> void:
	var cuts: int = 7
	var want: Vector3 = belly.normalized()
	var thick: Vector3 = want * 0.25
	var grid: Array = []
	var order: float = GALLEON._next_sail()
	for row: int in cuts + 1:
		var v: float = float(row) / cuts
		var line: PackedVector3Array = PackedVector3Array()
		for column: int in cuts + 1:
			var u: float = float(column) / cuts
			var out: Vector3 = belly * pow(16.0 * u * (1.0 - u) * v * (1.0 - v), 0.7)
			line.append(throat.lerp(peak, u).lerp(tack.lerp(clew, u), v) + out)
			# Item 3: furled, it is brailed up in a roll under the gaff.
			GALLEON._pin(line[column], thick, GALLEON._roll(throat.lerp(peak, u), v, want), out, order)
		grid.append(line)
	for row: int in cuts:
		for column: int in cuts:
			var a: Vector3 = grid[row][column]
			var b: Vector3 = grid[row][column + 1]
			var c: Vector3 = grid[row + 1][column + 1]
			var d: Vector3 = grid[row + 1][column]
			surface.set_color((SAIL if column % 2 == 0 else SAIL_SEAM).srgb_to_linear())
			surface.set_smooth_group(0)
			GALLEON._face(surface, a, b, c, want)
			GALLEON._face(surface, a, c, d, want)
			surface.set_smooth_group(1)
			GALLEON._face(surface, a - thick, b - thick, c - thick, -want)
			GALLEON._face(surface, a - thick, c - thick, d - thick, -want)
	surface.set_smooth_group(2)
	surface.set_color(SAIL_SEAM.srgb_to_linear())
	var middle: Vector3 = (tack + throat + peak + clew) / 4.0
	var rim: PackedVector3Array = PackedVector3Array()
	for column: int in cuts + 1: rim.append(grid[0][column])
	for row: int in range(1, cuts + 1): rim.append(grid[row][cuts])
	for column: int in range(cuts - 1, -1, -1): rim.append(grid[cuts][column])
	for row: int in range(cuts - 1, 0, -1): rim.append(grid[row][0])
	for index: int in rim.size():
		var a: Vector3 = rim[index]
		var b: Vector3 = rim[(index + 1) % rim.size()]
		var out: Vector3 = (a + b) * 0.5 - middle
		out.x = 0.0
		GALLEON._face(surface, a, b, b - thick, out)
		GALLEON._face(surface, a, b - thick, a - thick, out)

## Eight set sails: fore course, topsail and topgallant, the gaff mainsail and
## its topsail, the main staysail and two jibs.
static func sails_mesh() -> ArrayMesh:
	var surface: SurfaceTool = GALLEON.sail_surface()
	var fore: Dictionary = MASTS.Fore
	var yards: Array = fore.yards
	var z: float = float(fore.z) + float(fore.r) + 0.5
	for index: int in yards.size():
		var head_y: float = float(yards[index][0]) - 0.35
		var head_w: float = float(yards[index][1]) - 0.8
		if index == 0:
			GALLEON._square_sail(surface, z, head_y, float(fore.foot), head_w, head_w - 0.8, 1.6, SAIL, SAIL_SEAM)
		else:
			GALLEON._square_sail(surface, z, head_y, float(yards[index - 1][0]) + 0.8, head_w, float(yards[index - 1][1]) - 1.6, 1.7 - 0.3 * index, SAIL, SAIL_SEAM)
	_gaff_sail(surface, GAFF_TACK, GAFF_THROAT, GAFF_PEAK, GAFF_CLEW, Vector3(0.9, 0, 0))
	GALLEON._triangle_sail(surface, Vector3(0, 22.2, -10.9), Vector3(0, 36.3, -10.5), Vector3(0, 29.5, -23.2), Vector3(0.6, 0, 0), SAIL, SAIL_SEAM)
	GALLEON._triangle_sail(surface, Vector3(0, 19.5, -9.2), Vector3(0, 9.4, 7.6), Vector3(0, 9.8, -7.5), Vector3(0.6, 0, 0), SAIL, SAIL_SEAM)
	# Inner and outer jib, set on either side of the stays so they never touch.
	GALLEON._triangle_sail(surface, Vector3(-0.5, 26.0, 10.6), Vector3(-0.5, 10.7, 26.6), Vector3(-0.5, 10.4, 15.0), Vector3(0.6, 0, 0), SAIL, SAIL_SEAM)
	GALLEON._triangle_sail(surface, Vector3(0.45, 33.0, 10.2), Vector3(0.45, 12.6, 31.0), Vector3(0.45, 11.6, 18.5), Vector3(0.8, 0, 0), SAIL, SAIL_SEAM)
	return GALLEON.sail_commit(surface)

## The skull-and-cutlasses flag at the main truck, a smaller one at the gaff
## peak and a long white pennant on the foremast; the galleon's shader waves them.
static func flags_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray()
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
	var none: Array[String] = []
	GALLEON._flag(arrays, Vector3(0, float(MASTS.Main.truck) + 3.7, float(MASTS.Main.z) - 0.2), 5.6, 3.7, FLAG, FLAG_BLACK, 0.6, 0.7)
	GALLEON._flag(arrays, GAFF_PEAK + Vector3(0, 0.9, -0.7), 4.2, 2.8, FLAG, FLAG_BLACK, 2.7, 0.5)
	GALLEON._flag(arrays, Vector3(0, float(MASTS.Fore.truck) + 1.9, float(MASTS.Fore.z) - 0.2), 8.0, 1.1, none, BONE, 1.6, 0.6)
	var out: ArrayMesh = ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GALLEON.FLAG_SHADER
	out.surface_set_material(0, material)
	return out

# --- Fittings ---------------------------------------------------------------

## One deck gun: its port in the bulwark, the barrel run out and the carriage.
static func _cannon(parts: GALLEON.Parts, side: float, z: float) -> void:
	var d: GALLEON.Batch = parts.detail
	var y: float = deck_at(z) + 0.7
	var x: float = side_x(z, y)
	var inboard: float = deck_half(z)
	d.block(Vector3(side * x, y, z), Vector3(0.22, 0.9, 1.1), BLACK)
	d.rod(Vector3(side * (inboard - 1.8), y, z), Vector3(side * (inboard + 0.2), y, z), 0.34, 0.28, IRON, 6)
	d.rod(Vector3(side * (x - 0.3), y, z), Vector3(side * (x + 1.1), y, z), 0.26, 0.2, IRON, 6)
	d.rod(Vector3(side * (x + 1.1), y, z), Vector3(side * (x + 1.3), y, z), 0.27, 0.27, IRON, 6)
	d.block(Vector3(side * (inboard - 1.0), deck_at(z) + 0.25, z), Vector3(1.7, 0.5, 1.0), DARK_WOOD)

## Eighteen broadside guns, two stern chasers and four swivel guns on the rail.
static func _guns(parts: GALLEON.Parts) -> void:
	var d: GALLEON.Batch = parts.detail
	for side: float in [-1.0, 1.0]:
		for z: float in [-25.0, -20.0, -11.0, -7.0, -3.0, 1.0, 5.0, 9.0, 13.0]:
			_cannon(parts, side, z)
		for z: float in [-27.5, 17.0]:
			var post: Vector3 = Vector3(side * (side_x(z, rail_at(z)) - 0.2), rail_at(z), z)
			d.rod(post, post + Vector3(0, 0.6, 0), 0.1, 0.08, IRON, 5)
			d.rod(post + Vector3(-side * 0.5, 0.75, 0), post + Vector3(side * 0.9, 0.55, 0), 0.16, 0.11, GOLD, 5)
		d.block(Vector3(side * 1.7, 4.7, STERN_Z), Vector3(1.0, 0.9, 0.22), BLACK)
		d.rod(Vector3(side * 1.7, 4.7, STERN_Z + 0.4), Vector3(side * 1.7, 4.7, STERN_Z - 1.1), 0.26, 0.2, IRON, 6)

## The stern: lit cabin windows, gold mouldings, a crested taffrail with a
## skull boss, three lanterns, quarter windows and the rudder.
static func _stern(parts: GALLEON.Parts) -> void:
	var s: GALLEON.Batch = parts.structure
	var d: GALLEON.Batch = parts.detail
	var z: float = STERN_Z
	var top: float = rail_at(z)
	s.block(Vector3(0, 0.6, z - 0.6), Vector3(0.45, 6.4, 1.5), DARK_WOOD)
	s.block(Vector3(0, deck_at(z) + BULWARK * 0.5 - 0.05, z + 0.3), Vector3(deck_half(z) * 2.0 + 0.5, BULWARK, 0.45), CRIMSON)
	for x: float in [-2.4, -0.8, 0.8, 2.4]:
		GALLEON._window(parts, Vector3(x, 6.8, z - 0.06), Vector3.FORWARD, 1.1, 1.3)
	s.ink = 0.5
	s.block(Vector3(0, 5.6, z - 0.15), Vector3(8.0, 0.32, 0.35), GOLD)
	s.block(Vector3(0, 8.0, z - 0.15), Vector3(7.8, 0.32, 0.35), GOLD)
	s.block(Vector3(0, top + 0.15, z - 0.1), Vector3(7.6, 0.5, 0.5), GOLD)
	s.block(Vector3(0, top + 0.75, z - 0.1), Vector3(3.2, 0.8, 0.4), CRIMSON)
	s.block(Vector3(0, top + 1.25, z - 0.1), Vector3(3.6, 0.25, 0.5), GOLD)
	s.ball(Vector3(0, top + 0.75, z - 0.35), Vector3(0.48, 0.5, 0.25), BONE)
	s.ink = 1.0
	for index: int in 3:
		var x: float = (index - 1) * 2.9
		var lift: float = 1.5 if index == 1 else 0.5
		d.rod(Vector3(x, top + 0.3, z - 0.3), Vector3(x, top + 0.4 + lift, z - 0.8), 0.11, 0.1, IRON, 5)
		GALLEON._lantern(parts, Vector3(x, top + 0.4 + lift, z - 0.8), 0.85 if index == 1 else 0.65)
	for side: float in [-1.0, 1.0]:
		d.ball(Vector3(side * 3.6, top + 0.7, z - 0.1), Vector3.ONE * 0.32, GOLD, 6, 4)
		for at: float in [-26.6, -22.6, -17.0]:
			GALLEON._window(parts, Vector3(side * (side_x(at, 6.8) + 0.02), 6.8 + sheer(at) * 0.5, at), Vector3(side, 0, 0), 1.1, 1.2)

## The quarterdeck break: rail and balusters, stairs on both sides, the cabin
## door with lit windows, and a lantern at each end of the rail.
static func _break(parts: GALLEON.Parts) -> void:
	var s: GALLEON.Batch = parts.structure
	var d: GALLEON.Batch = parts.detail
	var high: float = deck_at(BREAK_Z - 0.1)
	var low: float = deck_at(BREAK_Z + 0.1)
	var half: float = deck_half(BREAK_Z - 0.3)
	var rail_half: float = half - 1.9
	var rail_z: float = BREAK_Z - 0.25
	s.ink = 0.5
	s.block(Vector3(0, high + 1.1, rail_z), Vector3(rail_half * 2.0, 0.22, 0.35), GOLD)
	s.ink = 1.0
	var count: int = int(rail_half * 2.0 / 0.8)
	for index: int in count + 1:
		var x: float = lerpf(-rail_half + 0.2, rail_half - 0.2, float(index) / count)
		d.rod(Vector3(x, high, rail_z), Vector3(x, high + 1.05, rail_z), 0.14, 0.09, BONE, 5)
	var treads: int = 6
	for side: float in [-1.0, 1.0]:
		for index: int in treads:
			var t: float = (index + 0.5) / treads
			d.block(Vector3(side * (half - 1.0), lerpf(high, low, t) - 0.1, BREAK_Z + 0.3 + t * 3.0), Vector3(1.6, 0.2, 0.55), PLANK)
		var slope: Transform3D = Transform3D(Basis(Vector3.RIGHT, atan2(high - low, 3.0)), Vector3(side * (half - 1.85), (high + low) * 0.5 - 0.25, BREAK_Z + 1.8))
		d.box(slope, Vector3(0.15, 0.4, sqrt(pow(high - low, 2.0) + 9.0)), DARK_WOOD)
		GALLEON._window(parts, Vector3(side * 2.0, low + 1.5, BREAK_Z + 0.07), Vector3.BACK, 0.9, 0.9)
		d.rod(Vector3(side * (rail_half - 0.1), high + 1.15, rail_z), Vector3(side * (rail_half - 0.1), high + 1.7, rail_z), 0.08, 0.08, IRON, 5)
		GALLEON._lantern(parts, Vector3(side * (rail_half - 0.1), high + 1.7, rail_z), 0.5)
	d.block(Vector3(0, low + 1.05, BREAK_Z + 0.06), Vector3(1.4, 2.1, 0.2), DARK_WOOD)
	d.block(Vector3(0.4, low + 1.1, BREAK_Z + 0.18), Vector3(0.14, 0.14, 0.14), GOLD)

## On deck: the ship's wheel and binnacle, a hatch grating, the upturned
## longboat on its chocks, capstan, barrels, crates, the bell and the anchors.
static func _deck(parts: GALLEON.Parts) -> void:
	var s: GALLEON.Batch = parts.structure
	var d: GALLEON.Batch = parts.detail
	# Ship's wheel on the quarterdeck, with the binnacle ahead of it.
	var helm: float = deck_at(-20.0)
	var wheel: Vector3 = Vector3(0, helm + 1.45, -20.0)
	d.block(Vector3(0, helm + 0.7, -20.0), Vector3(0.45, 1.4, 0.7), DARK_WOOD)
	d.rod(wheel - Vector3(0, 0, 0.45), wheel + Vector3(0, 0, 0.45), 0.2, 0.2, GOLD, 6)
	for index: int in 10:
		var first: float = TAU * index / 10.0
		var second: float = TAU * (index + 1) / 10.0
		d.rod(wheel + Vector3(cos(first), sin(first), 0.4), wheel + Vector3(cos(second), sin(second), 0.4), 0.1, 0.1, WOOD, 5)
		if index % 2 == 0:
			d.rod(wheel + Vector3(0, 0, 0.4), wheel + Vector3(cos(first) * 1.35, sin(first) * 1.35, 0.4), 0.07, 0.055, GOLD, 4)
	d.block(Vector3(0, helm + 0.5, -18.4), Vector3(0.7, 1.0, 0.6), WOOD)
	parts.glow.block(Vector3(0, helm + 1.1, -18.4), Vector3(0.4, 0.25, 0.4), GALLEON.LAMP)
	d.ball(Vector3(0, helm + 1.3, -18.4), Vector3.ONE * 0.26, GOLD, 6, 4)
	# Hatch grating abaft the longboat.
	var hatch: float = deck_at(-5.8)
	s.block(Vector3(0, hatch + 0.2, -5.8), Vector3(3.0, 0.4, 3.0), DARK_WOOD)
	for index: int in 4:
		d.block(Vector3(-1.05 + index * 0.7, hatch + 0.43, -5.8), Vector3(0.24, 0.08, 2.4), GALLEON.OCHRE)
	# The longboat, keel up on two chocks amidships.
	var boat: float = deck_at(1.0)
	for at: float in [-1.0, 3.0]:
		d.block(Vector3(0, boat + 0.3, at), Vector3(2.4, 0.6, 0.35), DARK_WOOD)
	s.ball(Vector3(0, boat + 0.75, 1.0), Vector3(1.15, 0.95, 3.5), BONE, 8, 5)
	d.block(Vector3(0, boat + 1.68, 1.0), Vector3(0.14, 0.14, 5.6), CRIMSON)
	d.block(Vector3(0, boat + 0.9, 1.0), Vector3(2.36, 0.14, 5.9), CRIMSON)
	# Capstan on the foredeck.
	var capstan: float = deck_at(14.5)
	s.rod(Vector3(0, capstan, 14.5), Vector3(0, capstan + 1.1, 14.5), 0.75, 0.55, WOOD, 8)
	s.rod(Vector3(0, capstan + 1.1, 14.5), Vector3(0, capstan + 1.4, 14.5), 0.82, 0.82, GOLD, 8)
	for index: int in 6:
		var turn: float = TAU * index / 6.0
		d.rod(Vector3(0, capstan + 1.25, 14.5), Vector3(cos(turn) * 2.0, capstan + 1.25, 14.5 + sin(turn) * 2.0), 0.09, 0.07, DARK_WOOD, 4)
	for barrel: Vector3 in [Vector3(2.5, 0, -27.6), Vector3(1.6, 0, -28.4), Vector3(-2.4, 0, -28.0), Vector3(-1.7, 0, 11.4), Vector3(1.8, 0, 6.2), Vector3(-2.6, 0, -9.0)]:
		var y: float = deck_at(barrel.z)
		d.rod(Vector3(barrel.x, y, barrel.z), Vector3(barrel.x, y + 0.6, barrel.z), 0.4, 0.5, WOOD, 7)
		d.rod(Vector3(barrel.x, y + 0.6, barrel.z), Vector3(barrel.x, y + 1.2, barrel.z), 0.5, 0.4, WOOD, 7)
		d.rod(Vector3(barrel.x, y + 0.52, barrel.z), Vector3(barrel.x, y + 0.68, barrel.z), 0.53, 0.53, IRON, 7, false)
	d.block(Vector3(2.6, deck_at(-8.6) + 0.5, -8.6), Vector3(1.3, 1.0, 1.3), GALLEON.OCHRE)
	d.block(Vector3(2.5, deck_at(-7.0) + 0.35, -7.0), Vector3(1.0, 0.7, 1.1), WOOD)
	# The bell, between two posts at the bow.
	var bell: float = deck_at(18.5)
	for side: float in [-1.0, 1.0]:
		d.block(Vector3(side * 0.6, bell + 0.85, 18.5), Vector3(0.2, 1.7, 0.2), CRIMSON)
	d.block(Vector3(0, bell + 1.8, 18.5), Vector3(1.7, 0.25, 0.4), CRIMSON)
	d.rod(Vector3(0, bell + 1.0, 18.5), Vector3(0, bell + 1.65, 18.5), 0.4, 0.16, GOLD, 6)
	# Catheads and anchors.
	for side: float in [-1.0, 1.0]:
		var top: float = rail_at(19.5)
		var x: float = side_x(19.5, top)
		s.block(Vector3(side * (x + 0.4), top - 0.1, 19.5), Vector3(2.2, 0.42, 0.42), DARK_WOOD)
		var ring: Vector3 = Vector3(side * (x + 1.3), top - 0.5, 19.5)
		var crown: Vector3 = Vector3(side * (x + 1.0), top - 4.4, 19.0)
		d.rod(ring, crown, 0.15, 0.18, IRON, 5)
		d.block(ring - Vector3(0, 0.4, 0), Vector3(0.24, 0.24, 2.3), DARK_WOOD)
		for arm: float in [-1.0, 1.0]:
			var fluke: Vector3 = crown + Vector3(0, 0.95, arm * 1.25)
			d.rod(crown, fluke, 0.17, 0.11, IRON, 5)
			d.block(fluke, Vector3(0.16, 0.6, 0.5), IRON)

## The cutwater, gold head rails, the skull figurehead, bowsprit and jibboom.
static func _bow(parts: GALLEON.Parts) -> void:
	var s: GALLEON.Batch = parts.structure
	var d: GALLEON.Batch = parts.detail
	s.rod(Vector3(0, 1.5, STEM_Z - 0.4), Vector3(0, 7.4, 27.0), 0.8, 0.42, DARK_WOOD, 6)
	s.ink = 0.5
	for side: float in [-1.0, 1.0]:
		s.rod(Vector3(side * side_x(21.0, 6.6), 6.8, 21.0), Vector3(side * 0.4, 7.9, 27.2), 0.2, 0.14, GOLD, 5)
		s.rod(Vector3(side * side_x(21.5, 4.6), 4.7, 21.5), Vector3(side * 0.35, 6.6, 26.6), 0.18, 0.13, GOLD, 5)
	# Figurehead: a bone-white skull with a jaw and dark sockets.
	s.rod(Vector3(0, 7.0, 26.4), Vector3(0, 8.5, 27.8), 0.55, 0.42, CRIMSON, 7)
	s.ball(Vector3(0, 9.2, 28.3), Vector3(0.68, 0.72, 0.72), BONE, 8, 5)
	s.block(Vector3(0, 8.5, 28.6), Vector3(0.7, 0.4, 0.55), BONE)
	s.ink = 1.0
	for side: float in [-1.0, 1.0]:
		d.ball(Vector3(side * 0.27, 9.3, 28.92), Vector3(0.17, 0.2, 0.14), BLACK, 5, 3)
	s.rod(Vector3(0, 6.4, 18.5), Vector3(0, 10.9, 27.8), 0.5, 0.34, WOOD, 8)
	s.ink = 0.6
	s.rod(Vector3(0, 10.4, 26.2), JIBBOOM_END, 0.28, 0.15, WOOD, 6)
	s.ink = 1.0
	GALLEON._lantern(parts, Vector3(0, rail_at(22.6), 22.6), 0.5)
	for stay: Array in [[JIBBOOM_END, Vector3(0, 2.4, STEM_Z + 0.2)], [Vector3(0, 10.9, 27.8), Vector3(0, 1.4, STEM_Z + 0.1)]]:
		parts.rigging.rod(stay[0], stay[1], 0.07, 0.07, ROPE, 4, false)
	for side: float in [-1.0, 1.0]:
		parts.rigging.rod(JIBBOOM_END, Vector3(side * side_x(20.0, 5.5), 5.6, 20.0), 0.06, 0.06, ROPE, 4, false)

## Two masts in three lengths, the fore top and the main crow's nest, the
## fore yards, the gaff and boom, and the standing and running rigging.
static func _masts(parts: GALLEON.Parts) -> void:
	var s: GALLEON.Batch = parts.structure
	var d: GALLEON.Batch = parts.detail
	var r: GALLEON.Batch = parts.rigging
	for label: String in MASTS:
		var mast: Dictionary = MASTS[label]
		var z: float = mast.z
		var radius: float = mast.r
		var deck: float = deck_at(z)
		var top: float = mast.top
		var cross: float = mast.cross
		var truck: float = mast.truck
		var main: bool = label == "Main"
		s.ink = 1.0
		s.rod(Vector3(0, deck - 0.5, z), Vector3(0, top + 1.2, z), radius, radius * 0.8, WOOD, 10)
		s.rod(Vector3(0, top - 0.8, z + radius), Vector3(0, cross + 1.0, z + radius * 0.4), radius * 0.62, radius * 0.46, WOOD, 8)
		s.ink = 0.6
		s.rod(Vector3(0, cross - 0.6, z + radius * 0.6), Vector3(0, truck, z + radius * 0.2), radius * 0.38, radius * 0.22, WOOD, 6)
		s.ball(Vector3(0, truck + 0.15, z + radius * 0.2), Vector3.ONE * 0.3, GOLD, 6, 4)
		s.rod(Vector3(0, truck, z + radius * 0.2 - 0.2), Vector3(0, truck + (3.8 if main else 2.0), z - 0.2), 0.1, 0.07, WOOD, 5)
		s.ink = 1.0
		for band: int in int((top - deck) / 4.5):
			d.rod(Vector3(0, deck + 2.5 + band * 4.5, z), Vector3(0, deck + 2.8 + band * 4.5, z), radius * 0.98 + 0.05, radius * 0.97 + 0.05, GOLD, 10, false)
		if main:
			# The crow's nest: a small tub with a white rim.
			s.rod(Vector3(0, top - 0.25, z), Vector3(0, top, z), 0.9, 1.7, DARK_WOOD, 10)
			s.rod(Vector3(0, top, z), Vector3(0, top + 1.2, z), 1.7, 1.9, WOOD, 10)
			s.ink = 0.5
			s.rod(Vector3(0, top + 1.2, z), Vector3(0, top + 1.42, z), 1.98, 1.98, BONE, 10)
			s.ink = 1.0
			GALLEON._lantern(parts, Vector3(0, top + 1.42, z - 1.75), 0.45)
		else:
			s.rod(Vector3(0, top - 0.15, z), Vector3(0, top + 0.15, z), 1.6, 1.6, DARK_WOOD, 10)
			for index: int in 8:
				var turn: float = TAU * index / 8.0
				var next: float = TAU * (index + 1) / 8.0
				d.rod(Vector3(cos(turn) * 1.5, top + 0.15, z + sin(turn) * 1.5), Vector3(cos(turn) * 1.5, top + 1.05, z + sin(turn) * 1.5), 0.07, 0.07, DARK_WOOD, 4)
				d.rod(Vector3(cos(turn) * 1.5, top + 1.05, z + sin(turn) * 1.5), Vector3(cos(next) * 1.5, top + 1.05, z + sin(next) * 1.5), 0.07, 0.07, GOLD, 4)
		s.block(Vector3(0, cross, z + radius * 0.5), Vector3(2.4, 0.24, 0.4), DARK_WOOD)
		s.block(Vector3(0, cross, z + radius * 0.5), Vector3(0.4, 0.24, 1.8), DARK_WOOD)
		# Yards with their lifts and braces (led aft to the mainmast).
		var yard_z: float = z + radius + 0.3
		for yard: Array in mast.yards:
			var y: float = yard[0]
			var half: float = float(yard[1]) / 2.0
			s.ink = 0.7
			for side: float in [-1.0, 1.0]:
				s.rod(Vector3(0, y, yard_z), Vector3(side * half, y, yard_z), 0.32, 0.15, DARK_WOOD, 6)
				r.rod(Vector3(side * half, y, yard_z), Vector3(0, y + half * 0.45, z + radius * 0.5), 0.05, 0.05, ROPE, 4, false)
				r.rod(Vector3(side * half, y, yard_z), Vector3(side * 0.7, y - 4.0, float(MASTS.Main.z) + 0.6), 0.05, 0.05, ROPE, 4, false)
			s.ink = 1.0
		# Sheets from the foot of the course down to the rail.
		if float(mast.foot) > 0.0:
			for side: float in [-1.0, 1.0]:
				var clew: Vector3 = Vector3(side * (float(mast.yards[0][1]) / 2.0 - 0.8), float(mast.foot), yard_z + 0.4)
				for at: float in [z - 6.5, z + 5.0]:
					r.rod(clew, Vector3(side * side_x(at, 30.0), rail_at(at), at), 0.06, 0.06, ROPE, 4, false)
		for side: float in [-1.0, 1.0]:
			# Channel on the hull side, deadeyes, and four shrouds up to the top.
			var feet: Array[Vector3] = []
			for index: int in 4:
				var foot_z: float = z + 0.6 - index * 1.3
				feet.append(Vector3(side * (side_x(foot_z, rail_at(foot_z)) + 0.45), rail_at(foot_z) - 0.2, foot_z))
			s.block((feet[0] + feet[3]) * 0.5 - Vector3(side * 0.15, 0.15, 0), Vector3(0.95, 0.2, 5.0), DARK_WOOD)
			var head: Vector3 = Vector3(side * (1.75 if main else 1.45), top - 0.15, z)
			for foot: Vector3 in feet:
				d.rod(foot - Vector3(0, 0.1, 0), foot + Vector3(0, 0.55, 0), 0.17, 0.17, BLACK, 5)
				r.rod(foot, head + Vector3(0, 0, (foot.z - z) * 0.2), 0.07, 0.07, ROPE, 4, false)
			GALLEON._ratlines(r, feet[0], head + Vector3(0, 0, (feet[0].z - z) * 0.2), feet[3], head + Vector3(0, 0, (feet[3].z - z) * 0.2))
			# Topmast shrouds from the rim of the top to the crosstrees.
			var rim: float = 1.85 if main else 1.55
			var upper: Vector3 = Vector3(side * 0.4, cross, z + radius * 0.5)
			for index: int in 3:
				r.rod(Vector3(side * rim, top + 0.25, z + 0.7 - index * 0.7), upper, 0.06, 0.06, ROPE, 4, false)
			GALLEON._ratlines(r, Vector3(side * rim, top + 0.25, z + 0.7), upper, Vector3(side * rim, top + 0.25, z - 0.7), upper)
			# Backstays from the crosstrees and the truck to the rail.
			for run: Array in [[cross, 6.0], [truck - 0.4, 8.5]]:
				var at: float = z - float(run[1])
				r.rod(Vector3(side * 0.25, run[0], z + radius * 0.3), Vector3(side * (side_x(at, rail_at(at)) + 0.25), rail_at(at), at), 0.06, 0.06, ROPE, 4, false)
	# Stays down the middle of the ship, mast to mast and out to the jibboom.
	var fore: Dictionary = MASTS.Fore
	var main_mast: Dictionary = MASTS.Main
	for stay: Array in [
			[Vector3(0, fore.top, fore.z), Vector3(0, 10.7, 27.4)], [Vector3(0, fore.cross, fore.z), Vector3(0, 11.6, 29.3)],
			[Vector3(0, float(fore.truck) - 0.4, fore.z), JIBBOOM_END],
			[Vector3(0, main_mast.top, main_mast.z), Vector3(0, deck_at(8.0) + 2.5, float(fore.z) - 0.6)],
			[Vector3(0, main_mast.cross, main_mast.z), Vector3(0, fore.top, fore.z)],
			[Vector3(0, float(main_mast.truck) - 0.4, main_mast.z), Vector3(0, fore.cross, fore.z)]]:
		r.rod(stay[0], stay[1], 0.08, 0.08, ROPE, 4, false)
	# The gaff and boom of the mainsail, with sheet, topping lift, halyard and vangs.
	var boom_end: Vector3 = Vector3(0, 12.9, -29.2)
	var gaff_end: Vector3 = GAFF_PEAK + Vector3(0, 0.7, -0.5)
	s.ink = 0.7
	s.rod(Vector3(0, 12.4, float(main_mast.z) - 0.6), boom_end, 0.3, 0.2, WOOD, 6)
	s.rod(Vector3(0, 21.7, float(main_mast.z) - 0.6), gaff_end, 0.26, 0.15, DARK_WOOD, 6)
	s.ink = 1.0
	r.rod(Vector3(0, 12.8, -26.5), Vector3(0, deck_at(-27.0) + 0.2, -27.0), 0.07, 0.07, ROPE, 4, false)
	r.rod(boom_end, Vector3(0, main_mast.cross, main_mast.z), 0.05, 0.05, ROPE, 4, false)
	r.rod(gaff_end, Vector3(0, float(main_mast.cross) + 2.5, main_mast.z), 0.05, 0.05, ROPE, 4, false)
	for side: float in [-1.0, 1.0]:
		r.rod(gaff_end, Vector3(side * 3.0, rail_at(-29.0), -29.0), 0.05, 0.05, ROPE, 4, false)

## Mooring bitts with the four markers the mooring lines leave from
## (features/ports/mooring_lines.gd), at the bow and on the quarterdeck.
static func _mooring(parts: GALLEON.Parts) -> Dictionary:
	var markers: Dictionary = {}
	for end: Array in [["Bow", 16.5], ["Stern", -23.0]]:
		var z: float = end[1]
		for side: float in [-1.0, 1.0]:
			var lead: Vector3 = Vector3(side * side_x(z, rail_at(z)), rail_at(z), z)
			parts.detail.block(lead + Vector3(-side * 0.25, 0.15, 0), Vector3(0.6, 0.4, 1.4), BLACK)
			for offset: float in [-0.7, 0.7]:
				var at: Vector3 = Vector3(side * (deck_half(z) - 0.6), deck_at(z), z + offset)
				parts.detail.rod(at, at + Vector3(0, 0.9, 0), 0.24, 0.24, BLACK, 6)
				parts.detail.rod(at + Vector3(0, 0.9, 0), at + Vector3(0, 1.08, 0), 0.36, 0.36, BLACK, 6)
			markers["Mooring%s%s" % [end[0], "L" if side < 0.0 else "R"]] = lead + Vector3(0, 0.4, 0)
	return markers

# --- Assembly ---------------------------------------------------------------

## Builds every mesh once; later ships (the hangar's and the one sailing) share them.
static func meshes() -> Dictionary:
	if not _meshes.is_empty(): return _meshes
	var parts: GALLEON.Parts = GALLEON.Parts.new()
	parts.detail.ink = 0.3
	_guns(parts)
	_stern(parts)
	_break(parts)
	_deck(parts)
	_bow(parts)
	_masts(parts)
	_meshes = GALLEON.finish(parts, hull_mesh(), sails_mesh(), flags_mesh(), _mooring(parts))
	return _meshes

## Fills chunky_look's model root: `hull` is its Hull node.
static func dress(root: Node3D, hull: MeshInstance3D, definition: ShipDefinition) -> void:
	GALLEON.place(root, hull, definition, meshes(), SIZE_M, DETAIL_RANGE_M, RIGGING_RANGE_M)
