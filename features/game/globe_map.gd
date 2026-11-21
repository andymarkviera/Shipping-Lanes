extends CanvasLayer
const DISPLAY = preload("res://features/ui/display_fonts.gd")
## Patch 2.4 item 7: M opens a big 3D globe of the whole world in the middle of
## the screen. Drag turns it freely (round and over the poles), the wheel zooms,
## M or Esc closes. The world keeps running; the helm keeps the keyboard and the
## small minimap stays. Read-only: it draws, it owns nothing.
## The world wraps east-west and north-south; the globe lays it out like an
## atlas page wrapped on a ball: the east-west edge meets itself, and the
## north and south edges are the poles.
const Navigation = preload("res://features/ports/local_navigation.gd")
const Progression = preload("res://features/game/progression.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
const Airports = preload("res://features/planes/airports.gd")
## Patch 4.0.2 item 1: the polar cap's relief (the same as in the world).
const POLAR_ICE = preload("res://features/toon/polar_ice.gd")
## Patch 4.0.2 item 2: planes on the globe are small plane models.
const Planes = preload("res://features/planes/plane_catalog.gd")
const DRAG_RADIANS_PER_PIXEL: float = 0.006
const ZOOM_NEAR: float = 1.6
const ZOOM_FAR: float = 4.2
const ZOOM_STEP: float = 1.12
const MAP_SIZE: Vector2i = Vector2i(1024, 512)
## Patch 2.5 item 1B: the dotted course along the sea route, like the minimap.
const COURSE_DOT_SPACING: float = 0.012
const COURSE_DOT_SIZE: float = 0.007
## Patch 2.9.1 item 5: a starter-size hull is this long on the unit globe.
const BOAT_LENGTH: float = 0.1
const MAX_BOATS: int = 64
## Patch 4.0 item D14: the land stands up off the globe in toon relief, like
## the 3D glaciers in the world: a beach rim, green hills, ridged mountains
## with snowy tops and Ember Isle's cone. One shell mesh over the land, built
## once from the baked land grid and fixed-seed noise, sampled every
## RELIEF_STEP_CELLS grid cells. Heights are in globe units (the sea is 1.0)
## and much exaggerated so the hills read at globe size.
const RELIEF_STEP_CELLS: int = 2
const RELIEF_SEA: float = -0.003
const RELIEF_SHORE: float = 0.0015
const RELIEF_HILL: float = 0.004
const RELIEF_ROLL: float = 0.003
const RELIEF_MOUNTAIN: float = 0.018
const RELIEF_VOLCANO: float = 0.024
const RELIEF_SEED: int = 4014
## Mountains fade out round each airport, like the level airfield in the world.
const AIRFIELD_FLAT_M: Vector2 = Vector2(650.0, 1200.0)
## Ports, airports and their tags sit this far above the land under them.
const MARKER_LIFT: float = 0.008
const SAND_COLOUR: Color = Color("f1dfa4")
const FOREST: Color = Color("4fae3f")
const ROCK: Color = Color("8f7f6a")
const SNOW: Color = Color("f7fbfd")
const ASH: Color = Color("5a4a46")
const LAVA: Color = Color("ff7a2e")
const RUNWAY: Color = Color("3d4452")
## Patch 4.0.3 item 3: the port icon's pier deck and crane.
const PIER: Color = Color("f4ead2")
const CRANE: Color = Color("e8504a")
const RELIEF_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back;
varying vec3 up_view;
void vertex() { up_view = (MODELVIEW_MATRIX * vec4(normalize(VERTEX), 0.0)).xyz; }
void fragment() {
	// The globe's toon light, then the hills' own: slopes facing the light
	// are lit, slopes facing away take a shade band, flat land neither.
	vec3 sun = normalize(vec3(-0.5, 0.6, 0.65));
	float globe = dot(normalize(up_view), sun);
	float slope = dot(NORMAL, sun) - globe;
	float relief = slope > 0.1 ? 1.12 : (slope < -0.1 ? 0.76 : (slope < -0.03 ? 0.9 : 1.0));
	ALBEDO = COLOR.rgb * (globe > 0.05 ? 1.0 : 0.72) * relief;
}
"""
const BOAT_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 colour : source_color;
void fragment() {
	// The globe's own toon light: lit, then one shade band.
	float light = dot(NORMAL, normalize(vec3(-0.5, 0.6, 0.65)));
	ALBEDO = colour * (light > 0.05 ? 1.0 : 0.72);
}
"""
const SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D map : filter_linear_mipmap, repeat_enable;
varying vec3 spot;
void vertex() { spot = VERTEX; }
void fragment() {
	vec3 p = normalize(spot);
	vec2 uv = vec2(atan(p.x, p.z + (abs(p.x) + abs(p.z) < 1e-6 ? 1e-6 : 0.0)) / 6.2831853 + 0.5, 0.5 - asin(clamp(p.y, -1.0, 1.0)) / 3.1415927);
	// Patch 3.2: sample the mipmaps, so the rows that crowd into each pole
	// average out instead of fanning into streaks. The slopes come from a
	// copy of u without the date-line jump, so that line shows no seam.
	vec2 turned = vec2(fract(uv.x + 0.5), uv.y);
	vec2 across = dFdx(uv);
	vec2 down = dFdy(uv);
	vec2 across_turned = dFdx(turned);
	vec2 down_turned = dFdy(turned);
	if (abs(across_turned.x) < abs(across.x)) across.x = across_turned.x;
	if (abs(down_turned.x) < abs(down.x)) down.x = down_turned.x;
	vec3 colour = textureGrad(map, uv, across, down).rgb;
	// Toon light from the upper left, like the minimap: lit, then one shade band.
	float light = dot(NORMAL, normalize(vec3(-0.5, 0.6, 0.65)));
	colour *= light > 0.05 ? 1.0 : 0.72;
	ALBEDO = colour;
}
"""
var view: Node3D
var screen: Control
var frame: SubViewportContainer
var touch: Control
var camera: Camera3D
var spin: Node3D
## Patch 2.9.1 item 5: the boats on the globe are small toon 3D models drawn
## from a list of ship entries, each {kind, position, heading}: kind is the
## Progression ship kind, position a world position, heading radians from north
## (+Z) towards +X. Today the list is the player's own boat; Patch 3.0 adds the
## other players' boats to `other_ships` and they are drawn the same way.
var other_ships: Array[Dictionary] = []
## Pooled models, one per entry drawn; rebuilt only when an entry's kind changes.
var boats: Array[Node3D] = []
var boat_paints: Dictionary = {}
var boat_ink: StandardMaterial3D
var goal_marker: MeshInstance3D
var course_line: MeshInstance3D
var course_dots: int = 0
## Patch 4.0.3 item 3: each port is a small pier with a crane (a Node3D
## holder); port_paint[index] is its deck paint, sun yellow for the port the
## ship is at.
var port_markers: Array[Node3D] = []
var port_paint: Array[StandardMaterial3D] = []
## Patch 4.0 item D14: the land relief shell and one marker per airport.
var relief: MeshInstance3D
var airport_markers: Array[Node3D] = []
var zoom: float = 3.2
var clock: float = 0.0

## (east, north) radians of a world position: longitude -PI..PI, latitude
## -PI/2..PI/2. Matches the minimap: east is -X, north is +Z.
static func lon_lat(world: Vector3) -> Vector2:
	var step: Vector3 = Progression.short_way(world - Progression.WRAP_CENTRE)
	return Vector2(-step.x / Progression.WRAP_M * TAU, clampf(step.z / Progression.WRAP_M * PI, -PI / 2, PI / 2))

## A world position on the unit globe.
static func on_globe(world: Vector3) -> Vector3:
	var at: Vector2 = lon_lat(world)
	return Vector3(cos(at.y) * sin(at.x), sin(at.y), cos(at.y) * cos(at.x))

## The globe turned so `world` faces the viewer with north up.
static func facing(world: Vector3) -> Basis:
	var at: Vector2 = lon_lat(world)
	return Basis(Vector3.RIGHT, at.y) * Basis(Vector3.UP, -at.x)

## Pixel of the atlas page for a world X/Z.
static func page_pixel(x: float, z: float) -> Vector2:
	var at: Vector2 = lon_lat(Vector3(x, 0, z))
	return Vector2((at.x / TAU + 0.5) * MAP_SIZE.x, (0.5 - at.y / PI) * MAP_SIZE.y)

## The atlas page: sea, a soft grid, green land, the white ice cap. Built once.
static func atlas() -> ImageTexture:
	var page: Image = Image.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGB8)
	page.fill(Color("1aa0d8"))
	for line: int in 12:
		page.fill_rect(Rect2i(line * MAP_SIZE.x / 12, 0, 2, MAP_SIZE.y), Color("3fb4e2"))
	for line: int in range(1, 6):
		page.fill_rect(Rect2i(0, line * MAP_SIZE.y / 6, MAP_SIZE.x, 2), Color("3fb4e2"))
	# Patch 2.9.1 item 6: the polar ice cap, pixel by pixel from its depth grid:
	# white ice, an ink line along its coast. Its rows lie at the page's top
	# and bottom, where the globe's poles are.
	var ice: Dictionary = Progression.polar_ice()
	if not ice.is_empty():
		var ice_count: Vector2i = ice.count
		var ice_depth: PackedFloat32Array = ice.depth
		for py: int in MAP_SIZE.y:
			var north: float = (py + 0.5) / MAP_SIZE.y * Progression.WRAP_M
			var row: int = floori((-north if north < Progression.WRAP_M / 2 else Progression.WRAP_M - north) / ice.cell) + ice.half
			if row < 0 or row >= ice_count.y: continue
			for px: int in MAP_SIZE.x:
				var d: float = ice_depth[row * ice_count.x + posmod(floori((1.0 - (px + 0.5) / MAP_SIZE.x) * Progression.WRAP_M / ice.cell), ice_count.x)]
				if d > 0.0: page.set_pixel(px, py, Color("8fc3d6") if d < 20.0 else Color("f7fbfd"))
	# Patch 2.9 item 6A: the natural land, pixel by pixel from the coast depth
	# grid (nearest sample): green inland, an ink line along the coast.
	var grid: Dictionary = Progression.natural_land()
	if grid.is_empty():
		page.generate_mipmaps()
		return ImageTexture.create_from_image(page)
	var count: Vector2i = grid.count
	var depth: PackedFloat32Array = grid.depth
	var cell: float = grid.cell
	var origin: Vector2 = grid.origin
	var corner_a: Vector2 = page_pixel(origin.x, origin.y)
	var corner_b: Vector2 = page_pixel(origin.x + count.x * cell, origin.y + count.y * cell)
	var from: Vector2i = Vector2i(corner_a.min(corner_b).floor()).clamp(Vector2i.ZERO, MAP_SIZE - Vector2i.ONE)
	var to: Vector2i = Vector2i(corner_a.max(corner_b).ceil()).clamp(Vector2i.ZERO, MAP_SIZE - Vector2i.ONE)
	var ink: Color = Color("2f7a33")
	for py: int in range(from.y, to.y + 1):
		var z: float = Progression.WRAP_CENTRE.z + (0.5 - (py + 0.5) / MAP_SIZE.y) * Progression.WRAP_M
		var j: int = roundi((z - origin.y) / cell)
		if j < 0 or j >= count.y: continue
		for px: int in range(from.x, to.x + 1):
			var x: float = Progression.WRAP_CENTRE.x + (0.5 - (px + 0.5) / MAP_SIZE.x) * Progression.WRAP_M
			var i: int = roundi((x - origin.x) / cell)
			if i < 0 or i >= count.x: continue
			var d: float = depth[j * count.x + i]
			if d > 0.0: page.set_pixel(px, py, ink if d < 20.0 else PLAYFUL.LEAF)
	# Patch 3.2: mipmapped (see SHADER), so the poles read as a cap, not a fan.
	page.generate_mipmaps()
	return ImageTexture.create_from_image(page)

static func flat(colour: Color) -> StandardMaterial3D:
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = colour
	return paint

static var _noises: Array[FastNoiseLite] = []
static var _relief: ArrayMesh

## [ridges, rolling hills]: fixed-seed noise, so every run builds the same land.
static func noises() -> Array[FastNoiseLite]:
	if _noises.is_empty():
		var ridges: FastNoiseLite = FastNoiseLite.new()
		ridges.seed = RELIEF_SEED
		ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		ridges.frequency = 1.0 / 1400.0
		ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		ridges.fractal_octaves = 4
		var rolls: FastNoiseLite = FastNoiseLite.new()
		rolls.seed = RELIEF_SEED + 1
		rolls.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		rolls.frequency = 1.0 / 600.0
		rolls.fractal_octaves = 2
		_noises = [ridges, rolls]
	return _noises

## Patch 4.0 item D14: the relief at a world X/Z that is `depth` metres inland:
## (height above the sea in globe units, below 0 at sea; how much of it is
## mountain, 0..1; how much is Ember Isle's cone, 0..1).
static func relief_at(at: Vector2, depth: float) -> Vector3:
	if depth <= 0.0: return Vector3(RELIEF_SEA, 0, 0)
	var height: float = lerpf(RELIEF_SEA, RELIEF_SHORE, smoothstep(0.0, 40.0, depth))
	height += (TOON_COAST.hill_height(depth) - TOON_COAST.HILL_FOOT_Y) / (TOON_COAST.HILL_TOP_Y - TOON_COAST.HILL_FOOT_Y) * RELIEF_HILL
	var noise: Array[FastNoiseLite] = noises()
	height += smoothstep(60.0, 240.0, depth) * RELIEF_ROLL * (noise[1].get_noise_2d(at.x, at.y) * 0.5 + 0.5)
	var flat_field: float = 1.0
	for airport: Dictionary in Airports.all():
		flat_field = minf(flat_field, smoothstep(AIRFIELD_FLAT_M.x, AIRFIELD_FLAT_M.y, at.distance_to(Vector2(airport.at.x, airport.at.z))))
	var ridge: float = clampf((noise[0].get_noise_2d(at.x, at.y) + 0.35) / 1.2, 0.0, 1.0)
	var mountain: float = smoothstep(110.0, 250.0, depth) * flat_field * ridge * ridge
	height += mountain * RELIEF_MOUNTAIN
	var volcano: Vector2 = Progression.VOLCANO.at
	var cone: float = clampf(1.0 - at.distance_to(volcano) / (float(Progression.VOLCANO.base_m) * 2.0), 0.0, 1.0)
	if cone > 0.0:
		# A cone with a small crater dip at the top.
		height = maxf(height, RELIEF_SHORE + cone * RELIEF_VOLCANO - smoothstep(0.85, 1.0, cone) * RELIEF_VOLCANO * 0.25)
		mountain *= 1.0 - cone
	return Vector3(height, mountain, cone)

## The radius of the globe's surface under a world position: 1 at sea, more on
## raised land. Markers stand on it.
static func ground(world: Vector3) -> float:
	var at: Vector2 = Vector2(world.x, world.z)
	return 1.0 + maxf(0.0, relief_at(at, Progression.land_depth(at)).x)

## The toon colour of a relief sample: beach, meadow, forest, rock, snow, ash.
static func relief_colour(sample: Vector3, depth: float) -> Color:
	var colour: Color = SAND_COLOUR.lerp(PLAYFUL.LEAF, smoothstep(30.0, 60.0, depth))
	colour = colour.lerp(FOREST, smoothstep(70.0, 160.0, depth) * 0.6)
	colour = colour.lerp(ROCK, smoothstep(0.25, 0.45, sample.y))
	colour = colour.lerp(SNOW, smoothstep(0.62, 0.75, sample.y))
	colour = colour.lerp(ASH, smoothstep(0.0, 0.35, sample.z))
	return colour.lerp(LAVA, smoothstep(0.86, 0.95, sample.z))

## Patch 4.0 item D14: the land relief shell. Every grid cell with land at a
## corner becomes two triangles; corners at sea dip just under the ball, so
## the shell rises out of the sea along the atlas's coast line. Vertex normals
## carry the slopes for RELIEF_SHADER; colours are linear. Built once.
static func relief_mesh() -> ArrayMesh:
	if _relief != null: return _relief
	_relief = ArrayMesh.new()
	var grid: Dictionary = Progression.natural_land()
	if grid.is_empty(): return _relief
	var count: Vector2i = grid.count
	var depth: PackedFloat32Array = grid.depth
	var cell: float = grid.cell
	var origin: Vector2 = grid.origin
	var columns: int = (count.x - 1) / RELIEF_STEP_CELLS + 1
	var rows: int = (count.y - 1) / RELIEF_STEP_CELLS + 1
	var slot: PackedInt32Array = PackedInt32Array()
	slot.resize(columns * rows)
	slot.fill(-1)
	var verts: PackedVector3Array = PackedVector3Array()
	var colours: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for row: int in rows - 1:
		for column: int in columns - 1:
			var corners: Array[int] = [row * columns + column, row * columns + column + 1, (row + 1) * columns + column + 1, (row + 1) * columns + column]
			var land: bool = false
			for corner: int in corners:
				land = land or depth[(corner / columns) * RELIEF_STEP_CELLS * count.x + (corner % columns) * RELIEF_STEP_CELLS] > 0.0
			if not land: continue
			for corner: int in corners:
				if slot[corner] >= 0: continue
				var i: int = (corner % columns) * RELIEF_STEP_CELLS
				var j: int = (corner / columns) * RELIEF_STEP_CELLS
				var d: float = depth[j * count.x + i]
				var at: Vector2 = origin + Vector2(i, j) * cell
				var sample: Vector3 = relief_at(at, d)
				slot[corner] = verts.size()
				verts.append(on_globe(Vector3(at.x, 0, at.y)) * (1.0 + sample.x))
				colours.append(relief_colour(sample, d).srgb_to_linear())
			for triangle: PackedInt32Array in [PackedInt32Array([corners[0], corners[1], corners[2]]), PackedInt32Array([corners[0], corners[2], corners[3]])]:
				var a: int = slot[triangle[0]]
				var b: int = slot[triangle[1]]
				var c: int = slot[triangle[2]]
				# Godot's front faces wind so this cross points into the globe.
				if (verts[b] - verts[a]).cross(verts[c] - verts[a]).dot(verts[a]) > 0.0:
					var swap: int = b
					b = c
					c = swap
				indices.append_array([a, b, c])
	polar_relief(verts, colours, indices)
	if indices.is_empty(): return _relief
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(verts.size())
	for index: int in range(0, indices.size(), 3):
		var a: int = indices[index]
		var b: int = indices[index + 1]
		var c: int = indices[index + 2]
		var outward: Vector3 = (verts[c] - verts[a]).cross(verts[b] - verts[a])
		normals[a] += outward
		normals[b] += outward
		normals[c] += outward
	for index: int in normals.size(): normals[index] = normals[index].normalized() if normals[index].length() > 0.0 else verts[index].normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	_relief.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _relief

## Patch 4.0.2 item 1: the polar ice cap's relief on the globe (it was flat
## white paint): every RELIEF_STEP_CELLS-th sample of the ice grid, raised
## by the cliff, the snow rise and PolarIce.relief's ridges and hills, in
## ice blue at the coast, snow on top and glacier blue on the ridges.
## Appended to the land relief's arrays.
## The globe's polar samples: every POLAR_STEP_CELLS-th of the ice grid.
const POLAR_STEP_CELLS: int = 4

static func polar_height(at: Vector2, depth: float) -> float:
	# The ridges shrink towards the pole as the globe's meridians close in,
	# so they keep their shape, and right at the pole the cap is level (no
	# spike or pit where every meridian meets).
	var shrink: float = absf(cos(lon_lat(Vector3(at.x, 0, at.y)).y))
	var height: float = RELIEF_SEA
	if depth > 0.0:
		height = lerpf(RELIEF_SEA, RELIEF_SHORE + RELIEF_HILL, smoothstep(0.0, 30.0, depth))
		height += smoothstep(30.0, POLAR_ICE.PLATEAU_FROM_M, depth) * RELIEF_HILL
		height += POLAR_ICE.relief(at, depth) / POLAR_ICE.RIDGE_M * RELIEF_MOUNTAIN * shrink
	return lerpf(RELIEF_SHORE + RELIEF_HILL * 2.0, height, clampf(shrink * 6.0, 0.0, 1.0))

static func polar_colour(at: Vector2, depth: float) -> Color:
	var colour: Color = Color("9ed5ea").lerp(SNOW, smoothstep(10.0, 40.0, depth))
	return colour.lerp(POLAR_ICE.GLACIER, smoothstep(0.35, 0.75, POLAR_ICE.relief(at, depth) / POLAR_ICE.RIDGE_M) * 0.8)

## World X/Z of polar ice grid sample (i, j) (as PolarIce.band_meshes).
static func polar_spot(i: int, j: int) -> Vector2:
	var grid: Dictionary = Progression.polar_ice()
	var cell: float = grid.cell
	var edge: float = Progression.WRAP_CENTRE.z + (0.5 if j < int(grid.half) else -0.5) * Progression.WRAP_M
	return Vector2(Progression.WRAP_CENTRE.x - Progression.WRAP_M / 2 + (i + 0.5) * cell, edge + (j - int(grid.half) + 0.5) * cell)

static func polar_relief(verts: PackedVector3Array, colours: PackedColorArray, indices: PackedInt32Array) -> void:
	var grid: Dictionary = Progression.polar_ice()
	if grid.is_empty(): return
	var count: Vector2i = grid.count
	var depth: PackedFloat32Array = grid.depth
	var half: int = int(grid.half)
	var columns: int = count.x / POLAR_STEP_CELLS
	var slot: Dictionary = {}
	# Rows from each half's own edge-side end, so neither skips its pole row.
	var rows: Array[int] = []
	for j: int in range(half - 1, -1, -POLAR_STEP_CELLS): rows.push_front(j)
	var south_rows: Array[int] = []
	for j: int in range(half, count.y, POLAR_STEP_CELLS): south_rows.append(j)
	for pass_rows: Array[int] in [rows, south_rows]:
		for row: int in pass_rows.size() - 1:
			polar_row(pass_rows[row], pass_rows[row + 1], columns, slot, verts, colours, indices)

static func polar_row(j: int, k: int, columns: int, slot: Dictionary, verts: PackedVector3Array, colours: PackedColorArray, indices: PackedInt32Array) -> void:
	var grid: Dictionary = Progression.polar_ice()
	var count: Vector2i = grid.count
	var depth: PackedFloat32Array = grid.depth
	for column: int in columns:
		var cells: Array[Vector2i] = [Vector2i(column, j), Vector2i((column + 1) % columns, j), Vector2i((column + 1) % columns, k), Vector2i(column, k)]
		var land: bool = false
		for corner: Vector2i in cells: land = land or depth[corner.y * count.x + corner.x * POLAR_STEP_CELLS] > 0.0
		if not land: continue
		var ids: Array[int] = []
		for corner: Vector2i in cells:
			if not slot.has(corner):
				var d: float = depth[corner.y * count.x + corner.x * POLAR_STEP_CELLS]
				var at: Vector2 = polar_spot(corner.x * POLAR_STEP_CELLS, corner.y)
				slot[corner] = verts.size()
				verts.append(on_globe(Vector3(at.x, 0, at.y)) * (1.0 + polar_height(at, d)))
				colours.append(polar_colour(at, d).srgb_to_linear())
			ids.append(int(slot[corner]))
		for triangle: Array in [[ids[0], ids[1], ids[2]], [ids[0], ids[2], ids[3]]]:
			var a: int = triangle[0]
			var b: int = triangle[1]
			var c: int = triangle[2]
			if (verts[b] - verts[a]).cross(verts[c] - verts[a]).dot(verts[a]) > 0.0:
				var swap: int = b
				b = c
				c = swap
			indices.append_array([a, b, c])

func _ready() -> void:
	layer = 8
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(PLAYFUL.INK, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dim)
	frame = SubViewportContainer.new()
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(frame)
	var port_view: SubViewport = SubViewport.new()
	port_view.own_world_3d = true
	port_view.transparent_bg = true
	port_view.msaa_3d = Viewport.MSAA_4X
	frame.add_child(port_view)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.position = Vector3(0, 0, zoom)
	port_view.add_child(camera)
	spin = Node3D.new()
	port_view.add_child(spin)
	var ball: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radial_segments = 96
	sphere.rings = 48
	ball.mesh = sphere
	sphere.radius = 1.0
	sphere.height = 2.0
	var shader: Shader = Shader.new()
	shader.code = SHADER
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("map", atlas())
	ball.material_override = paint
	spin.add_child(ball)
	# Ink outline: a slightly bigger ball seen from inside.
	var rim: MeshInstance3D = MeshInstance3D.new()
	var rim_mesh: SphereMesh = SphereMesh.new()
	rim_mesh.radius = 1.025
	rim_mesh.height = 2.05
	rim.mesh = rim_mesh
	var ink: StandardMaterial3D = flat(PLAYFUL.INK)
	ink.cull_mode = BaseMaterial3D.CULL_FRONT
	rim.material_override = ink
	port_view.add_child(rim)
	for berg: Vector3 in Progression.ICEBERGS:
		var dot: MeshInstance3D = marker(SphereMesh.new(), Color.WHITE, 0.012 + berg.y / 6000.0)
		dot.position = on_globe(Vector3(berg.x, 0, berg.z)) * 1.004
	touch = Control.new()
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(on_touch)
	screen.add_child(touch)
	var hint: Label = Label.new()
	DISPLAY.apply(hint)
	hint.text = "WORLD MAP"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", PLAYFUL.CREAM)
	hint.add_theme_color_override("font_outline_color", PLAYFUL.INK)
	hint.add_theme_constant_override("outline_size", 8)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.offset_top = 24
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(hint)
	screen.hide()

## Patch 4.0 item D14: the land relief shell on the globe, built on first open.
func build_relief() -> void:
	relief = MeshInstance3D.new()
	relief.mesh = relief_mesh()
	var shader: Shader = Shader.new()
	shader.code = RELIEF_SHADER
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = shader
	relief.material_override = paint
	spin.add_child(relief)

## Patch 4.0 item D14: every airport as a small runway along its heading
## and its name, unlike the ports. Each stands on the land relief, lifted
## clear of it. Patch 4.0.3 item 3: just the runway (the red plane is gone).
func build_airports() -> void:
	var tarmac: StandardMaterial3D = flat(RUNWAY)
	var stripe: StandardMaterial3D = flat(Color.WHITE)
	var parts: Array = [[Vector3(0.024, 0.004, 0.1), Vector3.ZERO, tarmac], [Vector3(0.004, 0.005, 0.08), Vector3.ZERO, stripe]]
	for airport: Dictionary in Airports.all():
		var world: Vector3 = airport.at
		var up: Vector3 = on_globe(world)
		var at: Vector2 = lon_lat(world)
		var east: Vector3 = Vector3(cos(at.x), 0, -sin(at.x))
		var north: Vector3 = up.cross(east).normalized()
		var along: Vector3 = (east * -sin(airport.heading) + north * cos(airport.heading)).normalized()
		var holder: Node3D = Node3D.new()
		holder.basis = Basis(up.cross(along), up, along)
		holder.position = up * (ground(world) + MARKER_LIFT)
		spin.add_child(holder)
		for part: Array in parts:
			var piece: MeshInstance3D = MeshInstance3D.new()
			piece.mesh = box(part[0])
			piece.position = part[1]
			piece.material_override = part[2]
			holder.add_child(piece)
		var name_tag: Label3D = Label3D.new()
		name_tag.text = str(airport.name)
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.font_size = 36
		name_tag.font = DISPLAY.font()
		name_tag.modulate = Color("ffd2cf")
		name_tag.outline_size = 0
		name_tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		name_tag.pixel_size = 0.001
		name_tag.position = holder.position * 1.03 + Vector3(0, 0.04, 0)
		spin.add_child(name_tag)
		airport_markers.append(holder)

## Patch 4.0.3 item 3: a port's globe icon at a berth: a pale pier deck
## along the quay (which runs north from the berth), a red crane (tower and
## a boom out over the water) and two bollards, at the airport runway's
## scale. Its deck paint is port_paint's last entry.
func port_icon(berth: Vector3) -> Node3D:
	var up: Vector3 = on_globe(berth)
	var at: Vector2 = lon_lat(berth)
	var east: Vector3 = Vector3(cos(at.x), 0, -sin(at.x))
	var north: Vector3 = up.cross(east).normalized()
	var holder: Node3D = Node3D.new()
	holder.name = "PortIcon"
	holder.basis = Basis(east, up, north)
	holder.position = up * maxf(1.01, ground(berth) + MARKER_LIFT)
	spin.add_child(holder)
	var deck: StandardMaterial3D = flat(PIER)
	var crane: StandardMaterial3D = flat(CRANE)
	var ink: StandardMaterial3D = flat(PLAYFUL.INK)
	# [size, position, paint]: the deck and its dark edge, the crane's legs,
	# tower and boom, two bollards.
	var parts: Array = [[Vector3(0.03, 0.005, 0.07), Vector3.ZERO, deck], [Vector3(0.034, 0.003, 0.074), Vector3(0, -0.002, 0), ink],
		[Vector3(0.016, 0.004, 0.006), Vector3(0, 0.005, -0.008), crane], [Vector3(0.005, 0.034, 0.005), Vector3(0.004, 0.02, -0.008), crane],
		[Vector3(0.038, 0.004, 0.004), Vector3(-0.006, 0.037, -0.008), crane], [Vector3(0.003, 0.004, 0.003), Vector3(-0.012, 0.005, 0.018), ink],
		[Vector3(0.003, 0.004, 0.003), Vector3(-0.012, 0.005, 0.03), ink]]
	for part: Array in parts:
		var piece: MeshInstance3D = MeshInstance3D.new()
		piece.mesh = box(part[0])
		piece.position = part[1]
		piece.material_override = part[2]
		holder.add_child(piece)
	port_paint.append(deck)
	return holder

## A small toon marker stuck to the globe.
func marker(mesh: Mesh, colour: Color, size: float) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = flat(colour)
	node.scale = Vector3.ONE * size
	spin.add_child(node)
	return node

func is_open() -> bool:
	return screen.visible

func toggle() -> void:
	if is_open(): close()
	else: open()

## Opens on the ship, north up.
func open() -> void:
	if is_open() or not is_instance_valid(view) or not is_instance_valid(view.ship): return
	if port_markers.is_empty():
		build_relief()
		for port: Node3D in view.world_ports:
			# Patch 4.0.3 item 3: a small pier with a crane, the runway's size.
			var berth: Vector3 = port.berth_anchor.global_position
			var dot: Node3D = port_icon(berth)
			# Lifted clear of the raised land under it (Patch 4.0 item D14).
			var name_tag: Label3D = Label3D.new()
			name_tag.text = port.definition.display_name
			name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			name_tag.font_size = 48
			name_tag.font = DISPLAY.font()
			name_tag.modulate = Color.WHITE
			name_tag.outline_size = 0
			name_tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			name_tag.outline_modulate = PLAYFUL.INK
			name_tag.pixel_size = 0.0012
			name_tag.position = dot.position * 1.04 + Vector3(0, 0.05, 0)
			spin.add_child(name_tag)
			port_markers.append(dot)
		build_airports()
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.8
		ring.outer_radius = 1.0
		goal_marker = marker(ring, PLAYFUL.SUN, 0.06)
		course_line = marker(ImmediateMesh.new(), PLAYFUL.SUN, 1.0)
		course_line.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	spin.basis = facing(view.ship.global_position)
	zoom = 3.2
	place()
	screen.show()

func close() -> void:
	screen.hide()

func on_touch(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		turn(event.relative)
		touch.accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(ZOOM_NEAR, zoom / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(ZOOM_FAR, zoom * ZOOM_STEP)
		touch.accept_event()
	elif event is InputEventPanGesture:
		# Mac trackpad two-finger scroll: up/down zooms like the wheel, sideways spins.
		if absf(event.delta.y) >= absf(event.delta.x): zoom = clampf(zoom * pow(ZOOM_STEP, event.delta.y * 0.35), ZOOM_NEAR, ZOOM_FAR)
		else: turn(Vector2(event.delta.x * -40.0, 0.0))
		touch.accept_event()
	elif event is InputEventMagnifyGesture and event.factor > 0.0:
		zoom = clampf(zoom / event.factor, ZOOM_NEAR, ZOOM_FAR)
		touch.accept_event()

## Turns the globe about the screen's own axes, so it rolls freely every way,
## over the poles too: the surface follows the mouse.
func turn(by: Vector2) -> void:
	spin.basis = (Basis(Vector3.UP, by.x * DRAG_RADIANS_PER_PIXEL) * Basis(Vector3.RIGHT, by.y * DRAG_RADIANS_PER_PIXEL) * spin.basis).orthonormalized()

## M and Esc close it before the helm or the Esc menu see them.
func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed or event.echo: return
	var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if code == KEY_ESCAPE or event.is_action("ui_cancel") or (InputMap.has_action("map_toggle") and event.is_action("map_toggle")):
		close()
		get_viewport().set_input_as_handled()

## The globe sits in the middle, a square most of the screen high.
func place() -> void:
	var room: Vector2 = screen.get_viewport_rect().size
	var side: float = minf(room.x, room.y) * 0.82
	var box: Rect2 = Rect2((room - Vector2(side, side)) / 2, Vector2(side, side))
	frame.position = box.position
	frame.size = box.size
	touch.position = box.position
	touch.size = box.size
	camera.position.z = lerpf(camera.position.z, zoom, 0.25)

func _process(delta: float) -> void:
	if not is_open(): return
	# Another screen took over (hangar, Esc menu) or the ship went away.
	if not is_instance_valid(view) or not is_instance_valid(view.ship) \
			or (view.get("hangar") != null and view.hangar.is_open()) \
			or (view.get("game_menu") != null and view.game_menu.is_open()):
		close()
		return
	clock += delta
	place()
	show_ships(ship_entries())
	for index: int in port_markers.size():
		port_paint[index].albedo_color = PLAYFUL.SUN if view.world_ports[index] == view.port else PIER
	var destination: Dictionary = Navigation.target(view)
	goal_marker.visible = not destination.is_empty()
	if goal_marker.visible:
		var goal_up: Vector3 = on_globe(destination.position)
		var side: Vector3 = goal_up.cross(Vector3.FORWARD if absf(goal_up.y) > 0.9 else Vector3.UP).normalized()
		goal_marker.basis = Basis(side, goal_up, side.cross(goal_up)) * (0.06 + 0.012 * sin(clock * 4.0))
		goal_marker.position = goal_up * 1.012
	draw_course(destination)

## The dotted course on the globe: from the ship along the sea route to the
## destination, each leg the short way round the world.
func draw_course(destination: Dictionary) -> void:
	var line: ImmediateMesh = course_line.mesh as ImmediateMesh
	line.clear_surfaces()
	course_dots = 0
	if destination.is_empty(): return
	var corners: Array = destination.get("route", [])
	if corners.is_empty(): corners = [destination.position]
	line.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var from: Vector3 = view.ship.global_position
	for corner: Vector3 in corners:
		var step: Vector3 = Progression.short_way(corner - from)
		var across: float = on_globe(from).distance_to(on_globe(from + step))
		var dots: int = clampi(roundi(across / COURSE_DOT_SPACING), 1, 200)
		for index: int in range(1, dots + 1):
			var up: Vector3 = on_globe(from + step * (index / float(dots)))
			var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.y) > 0.9 else Vector3.UP).normalized() * COURSE_DOT_SIZE
			var other: Vector3 = up.cross(side)
			var middle: Vector3 = up * 1.006
			for point: Vector3 in [middle + side, middle + other, middle - side, middle + side, middle - side, middle - other]:
				line.surface_add_vertex(point)
			course_dots += 1
		from += step
	line.surface_end()

## Patch 2.9.1 item 5: every boat the map shows, the player's own first.
func ship_entries() -> Array[Dictionary]:
	var bow: Vector3 = view.ship.global_basis.z
	# Patch 4.0.2 item 2: flying, the own marker is the plane, not the laid-up boat.
	var own: String = str(view.get("ship_kind"))
	if view.has_method("flying") and view.flying(): own = str(view.aviation.plane_kind)
	var entries: Array[Dictionary] = [{"kind": own, "position": view.ship.global_position, "heading": atan2(bow.x, bow.z)}]
	entries.append_array(other_ships)
	entries.append_array(view.other_ships)
	return entries

## "pirate", "small", "bulk", "heavy" or "container" (also any unknown kind).
static func boat_family(kind: String) -> String:
	if Progression.PIRATE_KINDS.has(kind): return "pirate"
	var family: String = kind.get_slice("_", 0)
	return family if family in ["small", "bulk", "heavy"] else "container"

## Hull size in metres of a kind; the starter's for a kind this build lacks.
static func boat_size(kind: String) -> Vector3:
	return Progression.definition(kind).hull_size_m

func boat_part(model: Node3D, mesh: PrimitiveMesh, colour: Color, at: Vector3) -> MeshInstance3D:
	if not boat_paints.has(colour):
		if boat_ink == null:
			# One shared ink outline: the same shape, a little fatter, seen from inside.
			boat_ink = flat(PLAYFUL.INK)
			boat_ink.cull_mode = BaseMaterial3D.CULL_FRONT
			boat_ink.grow = true
			boat_ink.grow_amount = 0.022
		var shader: Shader = boat_paints.get("shader")
		if shader == null:
			shader = Shader.new()
			shader.code = BOAT_SHADER
			boat_paints["shader"] = shader
		var paint: ShaderMaterial = ShaderMaterial.new()
		paint.shader = shader
		paint.set_shader_parameter("colour", colour)
		paint.next_pass = boat_ink
		boat_paints[colour] = paint
	var part: MeshInstance3D = MeshInstance3D.new()
	mesh.material = boat_paints[colour]
	part.mesh = mesh
	part.position = at
	model.add_child(part)
	return part

static func box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh

static func pole(radius: float, height: float) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh

## A small toon model of a kind's hull, built into `model`: one unit long, bow
## along +Z, keel at Y 0. A few boxes each, so a full list stays cheap.
func build_boat(model: Node3D, kind: String) -> void:
	for old: Node in model.get_children():
		model.remove_child(old)
		old.free()
	if Planes.PLANES.has(kind):
		build_plane(model, kind)
		return
	var size: Vector3 = boat_size(kind)
	var family: String = boat_family(kind)
	var beam: float = clampf(size.x / size.z * 1.5, 0.2, 0.36)
	var brig: bool = kind == "small_brigantine"
	var hull: Color = {"pirate": Color("2c2a33") if brig else Color("7a4a25"), "small": Color.WHITE, "bulk": PLAYFUL.RUST, "heavy": PLAYFUL.SUN_DARK, "container": PLAYFUL.NAVY}[family]
	boat_part(model, box(Vector3(beam, 0.12, 0.72)), hull, Vector3(0, 0.06, -0.14))
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(beam, 0.28, 0.12)
	boat_part(model, prism, hull, Vector3(0, 0.06, 0.36)).basis = Basis(Vector3.RIGHT, PI / 2)
	match family:
		"pirate":
			boat_part(model, box(Vector3(beam, 0.1, 0.2)), hull, Vector3(0, 0.17, -0.4))
			var masts: Array = [-0.1, 0.2] if brig else [-0.24, 0.0, 0.24]
			for index: int in masts.size():
				var tall: float = 0.42 if brig else [0.4, 0.52, 0.42][index]
				boat_part(model, pole(0.014, tall), Color("4a2f1a"), Vector3(0, 0.12 + tall / 2, masts[index]))
				boat_part(model, box(Vector3(beam * 1.5, tall * 0.6, 0.02)), Color("c8372d") if brig else PLAYFUL.CREAM, Vector3(0, 0.14 + tall * 0.55, masts[index] + 0.02))
			boat_part(model, box(Vector3(0.012, 0.06, 0.1)), PLAYFUL.INK, Vector3(0, 0.71 if not brig else 0.6, masts[masts.size() - 2] - 0.06))
		"small":
			boat_part(model, box(Vector3(beam * 0.7, 0.1, 0.26)), PLAYFUL.SUN if kind != "small_fishing" else PLAYFUL.NAVY, Vector3(0, 0.17, -0.12 if kind != "small_fishing" else 0.05))
		"bulk":
			for hatch: int in 4: boat_part(model, box(Vector3(beam * 0.7, 0.035, 0.11)), Color("e9d8a6"), Vector3(0, 0.135, -0.2 + hatch * 0.14))
			boat_part(model, box(Vector3(beam * 0.85, 0.16, 0.1)), Color.WHITE, Vector3(0, 0.2, -0.4))
		"heavy":
			boat_part(model, box(Vector3(beam * 0.85, 0.16, 0.1)), Color.WHITE, Vector3(0, 0.2, 0.14))
			boat_part(model, box(Vector3(beam * 0.8, 0.02, 0.5)), PLAYFUL.DEEP, Vector3(0, 0.13, -0.2))
			boat_part(model, pole(0.02, 0.26), PLAYFUL.SUN, Vector3(beam * 0.35, 0.25, -0.05))
			boat_part(model, box(Vector3(0.025, 0.025, 0.3)), PLAYFUL.SUN, Vector3(beam * 0.35, 0.38, -0.18))
		_:
			var stacks: Array[Color] = [PLAYFUL.RUST, PLAYFUL.SUN, PLAYFUL.LEAF, PLAYFUL.CREAM]
			for stack: int in 4: boat_part(model, box(Vector3(beam * 0.85, 0.07 + 0.03 * (stack % 2), 0.12)), stacks[stack], Vector3(0, 0.155 + 0.015 * (stack % 2), -0.24 + stack * 0.135))
			boat_part(model, box(Vector3(beam * 0.85, 0.2, 0.08)), Color.WHITE, Vector3(0, 0.22, -0.42))
	model.set_meta("kind", kind)
	# Bigger hulls draw bigger, between 0.6 and 2 times the starter's.
	model.set_meta("length", BOAT_LENGTH * clampf(sqrt(size.z / 64.0), 0.6, 2.0))

## Patch 4.0.2 item 2: a plane on the globe (own or another captain's): a
## small top-down plane, one unit long like the boats, nose along +Z, in the
## plane's colour with a sun-yellow wing tip trim, lifted a little off the
## globe so it reads as flying.
func build_plane(model: Node3D, kind: String) -> void:
	var colour: Color = Color(str(Planes.PLANES[kind].colour))
	var fighter: bool = str(Planes.PLANES[kind].engines) == "afterburner"
	boat_part(model, box(Vector3(0.12, 0.1, 0.9)), colour, Vector3(0, 0.12, 0))
	boat_part(model, box(Vector3(0.9 if not fighter else 0.62, 0.05, 0.18 if not fighter else 0.3)), colour, Vector3(0, 0.12, 0.06 if not fighter else -0.08))
	boat_part(model, box(Vector3(0.36, 0.04, 0.1)), colour, Vector3(0, 0.14, -0.4))
	boat_part(model, box(Vector3(0.04, 0.16, 0.12)), PLAYFUL.SUN, Vector3(0, 0.22, -0.4))
	for side: float in [-1.0, 1.0]:
		boat_part(model, box(Vector3(0.1, 0.06, 0.12)), PLAYFUL.SUN, Vector3(side * (0.42 if not fighter else 0.3), 0.13, 0.06 if not fighter else -0.16))
	model.set_meta("kind", kind)
	model.set_meta("length", BOAT_LENGTH * 1.3)

static func is_plane(kind: String) -> bool:
	return Planes.PLANES.has(kind)

## Draws the entries: each a model of its own kind, sitting on the globe at its
## position with the bow along its heading. Models are pooled; spares and boats
## round the back of the globe are hidden.
func show_ships(entries: Array[Dictionary]) -> void:
	var shown: int = mini(entries.size(), MAX_BOATS)
	for index: int in shown:
		var entry: Dictionary = entries[index]
		if index == boats.size():
			var fresh: Node3D = Node3D.new()
			spin.add_child(fresh)
			boats.append(fresh)
		var model: Node3D = boats[index]
		var world: Vector3 = entry.position
		var up: Vector3 = on_globe(world)
		model.visible = (spin.basis * up).z > -0.15
		if not model.visible: continue
		if model.get_meta("kind", "") != entry.kind: build_boat(model, entry.kind)
		var at: Vector2 = lon_lat(world)
		var east: Vector3 = Vector3(cos(at.x), 0, -sin(at.x))
		var north: Vector3 = up.cross(east).normalized()
		# World east is -X and north is +Z; a boat on the pole itself still gets a bow.
		var bow: Vector3 = east * -sin(entry.heading) + north * cos(entry.heading)
		bow = bow.normalized() if bow.length() > 0.0001 else north
		model.basis = Basis(up.cross(bow), up, bow) * float(model.get_meta("length"))
		model.position = up * 1.012
	for index: int in range(shown, boats.size()): boats[index].visible = false
