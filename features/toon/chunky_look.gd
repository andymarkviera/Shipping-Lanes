extends RefCounted
## Aesthetics 4: chunky ship and port shapes built in code, in bold flat colours.
## Looks only: no collider, anchor or size used by the rules is changed. Call
## before toon_look.gd `apply`, which gives every part its toon shading and outline.
const WHITE: Color = Color("f6f1e3")
const GLASS: Color = Color("24405e")
const INK: Color = Color("2b2f3a")
const CREAM: Color = Color("f2d58a")
const RUST: Color = Color("b8402f")
const PIRATE_GALLEON = preload("res://features/toon/pirate_galleon.gd")
const PIRATE_BRIGANTINE = preload("res://features/toon/pirate_brigantine.gd")
## Hull and trim colour for each kind of ship in the game.
const SHIP_COLOURS = {
	"container": [Color("d8452f"), Color("f2b632")],
	"bulk": [Color("2f72b8"), Color("f08a2c")],
	"heavy": [Color("f0a326"), Color("2f72b8")],
}

static func _material(colour: Color, cache: Dictionary) -> StandardMaterial3D:
	if not cache.has(colour):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.9
		cache[colour] = material
	return cache[colour] as StandardMaterial3D

static func _part(parent: Node3D, mesh: Mesh, at: Vector3, colour: Color, cache: Dictionary) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = _material(colour, cache)
	parent.add_child(node)
	return node

static func _box(parent: Node3D, size: Vector3, at: Vector3, colour: Color, cache: Dictionary) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _part(parent, mesh, at, colour, cache)

static func _drum(parent: Node3D, bottom_radius: float, top_radius: float, height: float, at: Vector3, colour: Color, cache: Dictionary) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return _part(parent, mesh, at, colour, cache)

static func _ball(parent: Node3D, radius: float, height: float, at: Vector3, colour: Color, cache: Dictionary) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	return _part(parent, mesh, at, colour, cache)

## A fat rounded hull: blunt bow at +Z, flat stern, raised bow rail, a rust-red
## bottom, a white rail and a flat deck set inside the rail. One smooth surface
## so the ink outline has no gaps.
static func hull_mesh(length: float, beam: float, bottom: float, deck: float, rail: float, sheer: float, colour: Color, deck_colour: Color) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bands: Array[Color] = [WHITE, WHITE, colour, RUST, RUST, RUST, RUST, RUST, colour, WHITE, WHITE]
	var rings: Array[PackedVector3Array] = []
	var stations: int = 28
	for index: int in stations + 1:
		var t: float = float(index) / stations
		var bow: float = clampf((t - 0.7) / 0.3, 0.0, 1.0)
		var width: float = beam / 2.0 * (sqrt(maxf(0.0, 1.0 - bow * bow)) if bow > 0.0 else lerpf(0.82, 1.0, clampf(t / 0.1, 0.0, 1.0)))
		width = maxf(width, 0.05)
		var inner: float = maxf(width - 0.6, width * 0.5)
		var top: float = rail + sheer * bow * bow
		var low: float = bottom * (1.0 - 0.55 * bow * bow) * lerpf(0.7, 1.0, clampf(t / 0.15, 0.0, 1.0))
		var z: float = (t - 0.5) * length
		var ring: PackedVector3Array = PackedVector3Array()
		for point: Vector2 in [Vector2(inner, deck), Vector2(inner, top), Vector2(width, top), Vector2(width, deck - 0.8), Vector2(width, 0.5), Vector2(width * 0.6, low)]:
			ring.append(Vector3(-point.x, point.y, z))
		for back: int in 6:
			var mirror: Vector3 = ring[5 - back]
			ring.append(Vector3(-mirror.x, mirror.y, z))
		rings.append(ring)
	for index: int in stations:
		var a: PackedVector3Array = rings[index]
		var b: PackedVector3Array = rings[index + 1]
		for side: int in 11:
			surface.set_color(bands[side].srgb_to_linear())
			for corner: Vector3 in [a[side], b[side], b[side + 1], a[side], b[side + 1], a[side + 1]]:
				surface.add_vertex(corner)
		# Deck: its own smooth group keeps it flat-lit inside the rail.
		surface.set_smooth_group(1)
		surface.set_color(deck_colour.srgb_to_linear())
		for corner: Vector3 in [a[0], a[11], b[11], a[0], b[11], b[0]]:
			surface.add_vertex(corner)
		surface.set_smooth_group(0)
	# Flat stern.
	var stern: PackedVector3Array = rings[0]
	for side: int in range(2, 9):
		surface.set_color(bands[side].srgb_to_linear())
		for corner: Vector3 in [Vector3(0, deck, stern[0].z), stern[side], stern[side + 1]]:
			surface.add_vertex(corner)
	surface.generate_normals()
	surface.index()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	surface.set_material(material)
	return surface.commit()

static func _funnel(parent: Node3D, at: Vector3, radius: float, height: float, colour: Color, cache: Dictionary) -> void:
	_drum(parent, radius, radius * 0.9, height * 0.6, at + Vector3(0, height * 0.3, 0), colour, cache)
	_drum(parent, radius * 0.93, radius * 0.88, height * 0.2, at + Vector3(0, height * 0.7, 0), CREAM, cache)
	_drum(parent, radius * 0.9, radius * 0.86, height * 0.2, at + Vector3(0, height * 0.9, 0), INK, cache)

## Wheelhouse: a fat white house, a dark window band and a coloured roof.
static func _house(parent: Node3D, base: Vector3, size: Vector3, roof: Color, cache: Dictionary) -> void:
	_box(parent, size, base + Vector3(0, size.y / 2.0, 0), WHITE, cache)
	_box(parent, Vector3(size.x + 0.3, minf(2.0, size.y * 0.3), size.z + 0.3), base + Vector3(0, size.y * 0.68, 0), GLASS, cache)
	_box(parent, Vector3(size.x + 1.2, 0.7, size.z + 1.2), base + Vector3(0, size.y + 0.35, 0), roof, cache)

## Hides the imported model on the ship and puts the chunky one in its place,
## under the same bobbing node. The hull size comes from the ship's own record.
static func dress_ship(ship: Node3D, kind: String) -> void:
	var assembly: ShipAssembly = ship.get("assembly") as ShipAssembly
	if assembly == null or assembly.visual == null or assembly.visual.get_child_count() == 0: return
	(assembly.visual.get_child(0) as Node3D).hide()
	assembly.visual.add_child(model(kind, ship.definition))

## Patch 2.2 item 4: the toon model of one ladder kind on its own, for the boat
## hangar. dress_ship uses the same build, so the hangar shows the sailing look.
static func model(kind: String, definition: ShipDefinition) -> Node3D:
	var colours: Array = SHIP_COLOURS.get(kind.get_slice("_", 0), SHIP_COLOURS["container"])
	var main: Color = colours[0]
	var trim: Color = colours[1]
	var cache: Dictionary = {}
	var root: Node3D = Node3D.new()
	root.name = "ChunkyShip"
	var size: Vector3 = definition.hull_size_m
	var hull: MeshInstance3D = MeshInstance3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	if kind.begins_with("container_"):
		_dress_box_ship(root, hull, definition, int(kind.trim_prefix("container_")), main, trim, cache)
		_mooring_bitts(root, kind, definition, cache)
		return root
	if kind == "bulk" or kind.begins_with("bulk_"):
		_dress_bulker(root, hull, definition, 1 if kind == "bulk" else int(kind.trim_prefix("bulk_")), main, trim, cache)
		_mooring_bitts(root, kind, definition, cache)
		return root
	if kind == "heavy" or kind.begins_with("heavy_"):
		_dress_heavy(root, hull, definition, 1 if kind == "heavy" else int(kind.trim_prefix("heavy_")), main, trim, cache)
		_mooring_bitts(root, kind, definition, cache)
		return root
	if kind == "small_galleon":
		# Patch 2.9.1 item 1: the pirate galleon builds itself (mooring markers included).
		PIRATE_GALLEON.dress(root, hull, definition)
		return root
	if kind == "small_brigantine":
		# Patch 2.9.1 item 2: the pirate brigantine, built from the galleon's pieces.
		PIRATE_BRIGANTINE.dress(root, hull, definition)
		return root
	if kind.begins_with("small_"):
		_dress_small(root, hull, definition, kind, cache)
		_mooring_bitts(root, kind, definition, cache)
		return root
	var deck: float = 2.6
	hull.mesh = hull_mesh(size.z, size.x, -3.2, deck, 3.5, 1.6, main, Color("c9b48a"))
	# Stern house, bridge with wings, funnel and mast.
	var aft: float = -size.z / 2.0
	_house(root, Vector3(0, deck, aft + 10.5), Vector3(size.x - 2.6, 5.5, 11), main, cache)
	_house(root, Vector3(0, deck + 6.2, aft + 12), Vector3(size.x - 0.6, 3.6, 6.5), main, cache)
	_funnel(root, Vector3(0, deck + 6.2, aft + 6.5), 2.0, 6.5, main, cache)
	_drum(root, 0.25, 0.25, 4.0, Vector3(0, deck + 12.5, aft + 12), WHITE, cache)
	_ball(root, 0.7, 1.4, Vector3(0, deck + 14.8, aft + 12), trim, cache)
	# Bow: winch block and a stubby post.
	_box(root, Vector3(4, 1.4, 3), Vector3(0, deck + 0.7, size.z / 2.0 - 8), INK, cache)
	_drum(root, 0.45, 0.45, 4.5, Vector3(0, deck + 2.25, size.z / 2.0 - 5), WHITE, cache)
	_ball(root, 0.8, 1.6, Vector3(0, deck + 4.9, size.z / 2.0 - 5), trim, cache)
	# Hatch covers. The bulk carrier is covered end to end; the container ship
	# keeps its container spaces clear.
	var hatches: Array = [-10.0, 0.0, 10.5, 19.5] if kind == "bulk" else [-10.0, 0.0]
	for z: float in hatches:
		_box(root, Vector3(size.x - 4.4, 0.9, 8.0), Vector3(0, deck + 0.45, z), trim, cache)
		_box(root, Vector3(size.x - 5.4, 0.4, 7.0), Vector3(0, deck + 1.0, z), WHITE.lerp(trim, 0.35), cache)
	_mooring_bitts(root, kind, definition, cache)
	return root

## Patch 2.4 item 4: mooring bitts at the bow and the stern on both sides, each
## with a fairlead on the rail. The marker on each fairlead ("MooringBowL",
## "MooringBowR", "MooringSternL", "MooringSternR") is where the mooring lines
## (features/ports/mooring_lines.gd) leave the ship. Looks only, not solid.
static func _mooring_bitts(root: Node3D, kind: String, definition: ShipDefinition, cache: Dictionary) -> void:
	var size: Vector3 = definition.hull_size_m
	var s: float = size.y / 4.0
	# Rail height and half-beam at each end follow hull_mesh(): the bow end sits
	# where the bow just starts to narrow, the stern end just ahead of the transom.
	var rail: float = 3.5 * s
	var deck: float = 2.6 * s
	var ends: Dictionary = {"Bow": [size.z * 0.25, size.x / 2.0 * 0.98], "Stern": [-size.z / 2.0 + 3.0 * s, size.x / 2.0 * 0.9]}
	var inboard: float = 1.4 * s
	if kind == "heavy" or kind.begins_with("heavy_"):
		# The heavy lifter's deck is low; its bitts stand on the side walls.
		s = 1.0
		rail = 3.5
		deck = 3.5
		ends = {"Bow": [20.0 * size.z / 90.0, 12.0 * size.x / 24.0], "Stern": [-38.0 * size.z / 90.0, 12.0 * size.x / 24.0]}
		inboard = 1.5 * size.x / 24.0
	elif kind == "small_racer":
		# Patch 2.9 item 5: small flush cleats on the racer's low, narrow deck.
		s = 0.22
		deck = 2.6 * size.y / 4.0 + 0.1
		rail = deck
		ends = {"Bow": [size.z * 0.08, size.x / 2.0 * 0.95], "Stern": [-size.z / 2.0 + 1.5, size.x / 2.0 * 0.92]}
		inboard = 0.35
	for end: String in ends:
		var z: float = float(ends[end][0])
		var half: float = float(ends[end][1])
		for side: float in [-1.0, 1.0]:
			var lead: Vector3 = Vector3(side * half, rail, z)
			_box(root, Vector3(0.6, 0.5, 1.4) * s, lead + Vector3(-side * 0.2 * s, 0.25 * s, 0), INK, cache)
			for offset: float in [-0.75, 0.75]:
				var at: Vector3 = Vector3(side * (half - inboard), deck, z + offset * s)
				_drum(root, 0.32 * s, 0.32 * s, 1.3 * s, at + Vector3(0, 0.65 * s, 0), INK, cache)
				_drum(root, 0.46 * s, 0.46 * s, 0.22 * s, at + Vector3(0, 1.3 * s, 0), INK, cache)
			var marker: Marker3D = Marker3D.new()
			marker.name = "Mooring%s%s" % [end, "L" if side < 0.0 else "R"]
			marker.position = lead + Vector3(0, 0.35 * s, 0)
			root.add_child(marker)

## Patch 2.4 item 8: the small boats, each in its own bright scheme. The offshore
## racer is a Cigarette-style powerboat (Patch 2.9 item 5, _dress_racer); the
## speedboat is short with a windscreen, seats and an outboard; the fishing boat
## is chunky and cosy with a wheelhouse, mast and boom, net drum and buoys.
static func _dress_small(root: Node3D, hull: MeshInstance3D, definition: ShipDefinition, kind: String, cache: Dictionary) -> void:
	var size: Vector3 = definition.hull_size_m
	var s: float = size.y / 4.0
	var deck: float = 2.6 * s
	var aft: float = -size.z / 2.0
	var bow: float = size.z / 2.0
	match kind:
		"small_racer":
			_dress_racer(root, hull, size, cache)
		"small_speedboat":
			var blue: Color = Color("2a9fd6")
			hull.mesh = hull_mesh(size.z, size.x, -2.6 * s, deck, 3.5 * s, 0.8 * s, blue, Color("e8d9b5"))
			# Windscreen, two seats, a stern bench and an outboard motor.
			var screen: MeshInstance3D = _box(root, Vector3(size.x * 0.82, 0.55, 0.12), Vector3(0, deck + 0.42, size.z * 0.12), GLASS, cache)
			screen.rotation.x = -0.5
			_box(root, Vector3(size.x * 0.86, 0.1, 0.5), Vector3(0, deck + 0.68, size.z * 0.1), WHITE, cache)
			for side: float in [-1.0, 1.0]:
				_box(root, Vector3(0.6, 0.45, 0.6), Vector3(side * size.x * 0.2, deck + 0.22, -size.z * 0.05), WHITE, cache)
				_box(root, Vector3(0.6, 0.6, 0.15), Vector3(side * size.x * 0.2, deck + 0.6, -size.z * 0.05 - 0.3), blue, cache)
			_box(root, Vector3(size.x * 0.8, 0.4, 0.7), Vector3(0, deck + 0.2, aft + 1.0), WHITE, cache)
			_box(root, Vector3(0.5, 0.9, 0.6), Vector3(0, deck + 0.35, aft - 0.15), INK, cache)
			_box(root, Vector3(0.18, 1.0, 0.25), Vector3(0, deck - 0.5, aft - 0.2), INK, cache)
			_box(root, Vector3(0.62, 0.2, 0.72), Vector3(0, deck + 0.85, aft - 0.15), WHITE, cache)
		_:
			# The fishing boat.
			var teal: Color = Color("2f8f83")
			var roof: Color = Color("f08a2c")
			hull.mesh = hull_mesh(size.z, size.x, -3.2 * s, deck, 3.5 * s, 1.4 * s, teal, Color("b88a5a"))
			_house(root, Vector3(0, deck, size.z * 0.12), Vector3(size.x * 0.62, 2.4, size.z * 0.22), roof, cache)
			_funnel(root, Vector3(0, deck + 2.75, size.z * 0.12 - 1.0), 0.3, 1.4, roof, cache)
			# Mast and boom behind the wheelhouse.
			var mast_z: float = -size.z * 0.06
			_drum(root, 0.12, 0.12, 6.0, Vector3(0, deck + 3.0, mast_z), WHITE, cache)
			_ball(root, 0.25, 0.5, Vector3(0, deck + 6.1, mast_z), roof, cache)
			var boom: MeshInstance3D = _drum(root, 0.09, 0.09, size.z * 0.36, Vector3(0, deck + 2.6, mast_z - size.z * 0.15), WHITE, cache)
			boom.rotation.x = PI / 2.0 - 0.35
			# Net drum and crates aft, buoys on the rail.
			var net: MeshInstance3D = _drum(root, 0.7, 0.7, size.x * 0.55, Vector3(0, deck + 0.75, aft + 1.8), Color("6b4f3a"), cache)
			net.rotation.z = PI / 2.0
			_box(root, Vector3(0.9, 0.6, 0.9), Vector3(size.x * 0.22, deck + 0.3, aft + 4.0), Color("c98a4b"), cache)
			_box(root, Vector3(0.9, 0.6, 0.9), Vector3(-size.x * 0.22, deck + 0.3, aft + 4.3), Color("c98a4b"), cache)
			for side: float in [-1.0, 1.0]:
				for z: float in [-size.z * 0.22, size.z * 0.28]:
					_ball(root, 0.28, 0.56, Vector3(side * size.x * 0.5, 3.5 * s - 0.15, z), roof, cache)

## Patch 2.9 item 5: a long, narrow deep-V offshore hull in the Cigarette Racing
## style. Pointed bow at +Z, sharp chines, a step in the bottom just aft of
## amidships and a flat transom; bold racing bands that sweep up toward the
## stern. One smooth surface so the ink outline has no gaps. keel < 0 < deck.
static func racer_hull_mesh(length: float, beam: float, keel: float, deck: float, colours: Array[Color]) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Section: deck crown, gunwale, sheer, sweep line, chine, chine lip, keel;
	# then mirrored. colours: deck, gunwale, upper band, lower band, chine, bottom.
	var stations: Array[float] = []
	var steps: Array[float] = []
	for index: int in 33:
		var t: float = float(index) / 32.0
		stations.append(t)
		steps.append(0.0 if t < 0.4 else 1.0)
		if index == 13:
			# The step: the same station twice, the bottom ahead of it lower.
			stations.append(t)
			steps.append(1.0)
	var half: float = beam / 2.0
	var rings: Array[PackedVector3Array] = []
	for index: int in stations.size():
		var t: float = stations[index]
		var bow: float = clampf((t - 0.55) / 0.45, 0.0, 1.0)
		# Sharp entry: the width runs to a point at the stem with a finite angle.
		var width: float = maxf(half * (1.0 - pow(bow, 1.7)) * lerpf(0.9, 1.0, clampf(t / 0.25, 0.0, 1.0)), 0.02)
		var top: float = deck + 0.18 * bow * bow
		var chine: float = 0.05 + 0.35 * bow * bow
		var low: float = lerpf(keel, chine, pow(bow, 1.5)) - 0.08 * steps[index] * (1.0 - bow)
		var sweep: float = lerpf(top - 0.22, chine + 0.2, smoothstep(0.15, 0.85, t))
		var z: float = (t - 0.5) * length
		var ring: PackedVector3Array = PackedVector3Array()
		var section: Array[Vector2] = [Vector2(0.0, top + 0.12), Vector2(width * 0.86, top + 0.04), Vector2(width, top - 0.06), Vector2(width * 0.98, sweep), Vector2(width * 0.94, chine), Vector2(width * 0.84, chine - 0.06), Vector2(0.0, low)]
		for point: Vector2 in section:
			ring.append(Vector3(-point.x, point.y, z))
		for back: int in range(5, 0, -1):
			ring.append(Vector3(section[back].x, section[back].y, z))
		rings.append(ring)
	var count: int = rings[0].size()
	for index: int in rings.size() - 1:
		var a: PackedVector3Array = rings[index]
		var b: PackedVector3Array = rings[index + 1]
		for side: int in count:
			var next: int = (side + 1) % count
			var band: int = side if side < 6 else count - 1 - side
			surface.set_color(colours[band].srgb_to_linear())
			for corner: Vector3 in [a[side], b[side], b[next], a[side], b[next], a[next]]:
				surface.add_vertex(corner)
	# Flat transom.
	var stern: PackedVector3Array = rings[0]
	var middle: Vector3 = Vector3(0, (deck + keel) * 0.5, stern[0].z)
	for side: int in count:
		var band: int = side if side < 6 else count - 1 - side
		surface.set_color(colours[band].srgb_to_linear())
		for corner: Vector3 in [middle, stern[side], stern[(side + 1) % count]]:
			surface.add_vertex(corner)
	surface.generate_normals()
	surface.index()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	surface.set_material(material)
	return surface.commit()

## Patch 2.9 item 5: the offshore racer dressed as a Cigarette-style powerboat:
## long foredeck, low wraparound windscreen, open cockpit with bucket seats and
## four outboards on the transom, in yellow, red and black racing colours.
static func _dress_racer(root: Node3D, hull: MeshInstance3D, size: Vector3, cache: Dictionary) -> void:
	var yellow: Color = Color("ffc425")
	var red: Color = Color("e63946")
	var s: float = size.y / 4.0
	var deck: float = 2.6 * s
	var aft: float = -size.z / 2.0
	var beam: float = size.x
	var colours: Array[Color] = [yellow, INK, red, yellow, WHITE, INK]
	hull.mesh = racer_hull_mesh(size.z, beam, -2.6 * s, deck, colours)
	var top: float = deck + 0.12
	# Long foredeck: a black racing stripe down the middle and a white hatch.
	_box(root, Vector3(beam * 0.16, 0.06, size.z * 0.4), Vector3(0, top + 0.01, size.z * 0.22), INK, cache)
	_box(root, Vector3(beam * 0.3, 0.08, 0.7), Vector3(0, top, size.z * 0.12), WHITE, cache)
	# Open cockpit: a dark well with a white coaming round it.
	var cockpit_z: float = -size.z * 0.12
	var cockpit_len: float = size.z * 0.26
	_box(root, Vector3(beam * 0.62, 0.06, cockpit_len), Vector3(0, top + 0.01, cockpit_z), Color("3a3f4b"), cache)
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.1, 0.14, cockpit_len), Vector3(side * beam * 0.33, top + 0.06, cockpit_z), WHITE, cache)
	# Two bucket seats up front, a bench behind: white with red bolsters.
	var seat_z: float = cockpit_z + cockpit_len * 0.12
	for side: float in [-1.0, 1.0]:
		var x: float = side * beam * 0.15
		_box(root, Vector3(0.48, 0.18, 0.48), Vector3(x, top + 0.12, seat_z), WHITE, cache)
		_box(root, Vector3(0.48, 0.55, 0.14), Vector3(x, top + 0.38, seat_z - 0.26), WHITE, cache)
		for wing: float in [-1.0, 1.0]:
			_box(root, Vector3(0.08, 0.36, 0.42), Vector3(x + wing * 0.25, top + 0.3, seat_z - 0.04), red, cache)
	_box(root, Vector3(beam * 0.56, 0.2, 0.5), Vector3(0, top + 0.12, cockpit_z - cockpit_len * 0.36), WHITE, cache)
	_box(root, Vector3(beam * 0.56, 0.4, 0.12), Vector3(0, top + 0.3, cockpit_z - cockpit_len * 0.36 - 0.28), red, cache)
	# Dash and wheel ahead of the seats.
	_box(root, Vector3(beam * 0.5, 0.22, 0.3), Vector3(0, top + 0.13, cockpit_z + cockpit_len * 0.42), INK, cache)
	var wheel: MeshInstance3D = _drum(root, 0.16, 0.16, 0.05, Vector3(-beam * 0.15, top + 0.32, cockpit_z + cockpit_len * 0.36), INK, cache)
	wheel.rotation.x = PI / 2.0 - 0.4
	# Low wraparound windscreen: a raked centre pane and two swept side panes.
	var screen_z: float = cockpit_z + cockpit_len * 0.5 + 0.15
	var centre: MeshInstance3D = _box(root, Vector3(beam * 0.4, 0.34, 0.05), Vector3(0, top + 0.17, screen_z), GLASS, cache)
	centre.rotation.x = -0.75
	for side: float in [-1.0, 1.0]:
		var pane: MeshInstance3D = _box(root, Vector3(beam * 0.2, 0.3, 0.05), Vector3(side * beam * 0.27, top + 0.15, screen_z - 0.2), GLASS, cache)
		pane.rotation = Vector3(-0.6, side * 0.75, 0)
	# Engine deck behind the bench, then four outboards hung on the transom.
	_box(root, Vector3(beam * 0.7, 0.1, size.z * 0.14), Vector3(0, top + 0.03, aft + size.z * 0.1), INK, cache)
	for index: int in 4:
		var x: float = (float(index) - 1.5) * beam * 0.2
		_box(root, Vector3(0.42, 0.62, 0.62), Vector3(x, deck - 0.1, aft - 0.32), INK, cache)
		_box(root, Vector3(0.44, 0.12, 0.64), Vector3(x, deck + 0.15, aft - 0.32), red, cache)
		_box(root, Vector3(0.14, 1.4, 0.28), Vector3(x, deck - 1.0, aft - 0.36), INK, cache)
		_box(root, Vector3(0.1, 0.18, 0.5), Vector3(x, deck - 1.75, aft - 0.3), INK, cache)
	# Race number roundels on both sides of the bow.
	for side: float in [-1.0, 1.0]:
		var roundel: MeshInstance3D = _drum(root, 0.32, 0.32, 0.04, Vector3(side * beam * 0.49, deck - 0.35, size.z * 0.1), WHITE, cache)
		roundel.rotation.z = PI / 2.0
		roundel.rotation.y = side * 0.05

static func _tint(port: Node3D, label: String, colour: Color) -> void:
	var mesh: MeshInstance3D = _mesh_of(port, label)
	if mesh != null and mesh.material_override is StandardMaterial3D:
		(mesh.material_override as StandardMaterial3D).albedo_color = colour

static func _mesh_of(port: Node3D, label: String) -> MeshInstance3D:
	var node: Node = port.get_node_or_null(label)
	if node == null: return null
	for child: Node in node.get_children():
		if child is MeshInstance3D: return child as MeshInstance3D
	return null

## Adds chunky dressing to one port made by test_port.gd. Colliders, anchors and
## the berth stay as they are; new parts are not solid and sit on the quay or
## inside an existing solid block.
static func dress_port(port: Node3D) -> void:
	if not ("quay_side" in port) or port.get_node_or_null("Quay") == null: return
	var side: float = float(port.quay_side)
	var length: float = float(port.quay_length_m)
	var cache: Dictionary = {}
	var root: Node3D = Node3D.new()
	root.name = "ChunkyPort"
	port.add_child(root)
	_tint(port, "Quay", Color("b9a98c"))
	_tint(port, "QuayEdge", Color("f2b632"))
	_tint(port, "QuayExtension", Color("b9a98c"))
	_tint(port, "QuayExtensionEdge", Color("f2b632"))
	# Fat bollards and a dark timber face along the berth.
	_box(root, Vector3(1.0, 3.0, length - 2.0), Vector3(side * 19.6, 2.3, length / 2.0), Color("6b4a35"), cache)
	# Patch 2.4 item 4: the mooring lines tie to these (test_port.bollard_points()).
	for point: Vector3 in port.bollard_points():
		_drum(root, 0.9, 0.9, 1.6, Vector3(point.x, 4.8, point.z), INK, cache)
		_drum(root, 1.3, 1.3, 0.5, Vector3(point.x, 5.8, point.z), INK, cache)
	# Warehouses: bright walls, a pitched red roof and big doors facing the water.
	# Patch 2.4 item 3: the longer quays have several (Warehouse, Warehouse2, ...).
	var roof: PrismMesh = PrismMesh.new()
	roof.size = Vector3(50, 10, 49)
	for suffix: String in ["", "2", "3", "4"]:
		var walls: Node3D = port.get_node_or_null("Warehouse" + suffix) as Node3D
		if walls == null: continue
		_tint(port, "Warehouse" + suffix, Color("e9dcb8"))
		var flat_roof: MeshInstance3D = _mesh_of(port, "WarehouseRoof" + suffix)
		if flat_roof != null: flat_roof.hide()
		var shed: Vector3 = Vector3(side * 72, 26, walls.position.z)
		_part(root, roof, shed + Vector3(0, 5, 0), Color("c8452f"), cache)
		for offset: float in [-11.0, 11.0]:
			_box(root, Vector3(0.8, 13, 13), Vector3(shed.x - side * 21.2, 10.5, shed.z + offset), Color("2f72b8"), cache)
		_box(root, Vector3(0.6, 3, 40), Vector3(shed.x - side * 21.1, 21, shed.z), GLASS, cache)
	# Stacked containers in bold colours. The lower three are the solid ones.
	var bold: Array[Color] = [Color("d8452f"), Color("f2b632"), Color("2f9a8f")]
	for index: int in 3:
		_tint(port, "Container%d" % index, bold[index])
		if index < 2: _box(root, Vector3(12, 6, 6), Vector3(side * 46, 13, 32 + index * 16), bold[(index + 1) % 3].lerp(WHITE, 0.15), cache)
	var store: MeshInstance3D = _mesh_of(port, "FuelStore")
	if store != null:
		# Fuel store: one fat tank with a domed top, inside the old block.
		store.hide()
		var at: Vector3 = Vector3(side * 83, 4, 25)
		_drum(root, 10, 10, 9, at + Vector3(0, 4.5, 0), WHITE, cache)
		_drum(root, 10.15, 10.15, 2.2, at + Vector3(0, 5, 0), Color("d8452f"), cache)
		_ball(root, 10, 10, at + Vector3(0, 9, 0), WHITE, cache)
		_drum(root, 1.2, 1.2, 2.0, at + Vector3(0, 14.5, 0), INK, cache)
	if port.get_node_or_null("GantryBeam") != null:
		# Patch 2.4 item 5: the working quay cranes (container_cranes.gd) stand
		# on every berth now, so the old landmark gantry stands down.
		for label: String in ["GantryLegA", "GantryLegB", "GantryBeam"]:
			var part: MeshInstance3D = _mesh_of(port, label)
			if part != null: part.hide()
	# Harbour light at the far end of the quay: red and white bands, glass lantern.
	var light: Vector3 = Vector3(side * 30, 4, length - 9)
	_drum(root, 5.5, 5.5, 2, light + Vector3(0, 1, 0), Color("8f9aa3"), cache)
	for band: int in 4:
		var wide: float = 4.2 - band * 0.45
		_drum(root, wide, wide - 0.45, 5, light + Vector3(0, 4.5 + band * 5, 0), RUST if band % 2 == 0 else WHITE, cache)
	_drum(root, 3.6, 3.6, 0.8, light + Vector3(0, 22.4, 0), INK, cache)
	_drum(root, 2.2, 2.2, 3, light + Vector3(0, 24.3, 0), CREAM, cache)
	_drum(root, 3.0, 0.2, 3, light + Vector3(0, 27.3, 0), RUST, cache)
	# Channel buoys in place of the marker blocks: red to one side, green the other.
	for index: int in 3:
		for marker: int in [-1, 1]:
			var block: MeshInstance3D = _mesh_of(port, "ApproachMarker%d_%d" % [index, marker])
			if block == null: continue
			block.hide()
			var colour: Color = Color("d8452f") if marker < 0 else Color("2f9a5f")
			var at: Vector3 = Vector3(marker * 42, 0, -70 - index * 40)
			_drum(root, 1.6, 1.9, 2.4, at + Vector3(0, 0.6, 0), colour, cache)
			_drum(root, 1.5, 0.5, 3.2, at + Vector3(0, 3.4, 0), colour, cache)
			_ball(root, 0.8, 1.6, at + Vector3(0, 5.6, 0), CREAM, cache)
	if port.get("icy") == true: _dress_icy(port, root, side, length, cache)

## Patch 2.1 item 3: the polar ports. Ice-white quay, frosty walls, snow on the
## roof, the containers and the quay, and a few icicles along the berth edge.
## Looks only, like the rest of the dressing.
const SNOW: Color = Color("f7fbfd")
const ICE: Color = Color("bfe3ef")
const FROST: Color = Color("d9edf4")

static func _dress_icy(port: Node3D, root: Node3D, side: float, length: float, cache: Dictionary) -> void:
	_tint(port, "Quay", FROST)
	_tint(port, "QuayEdge", ICE)
	_tint(port, "QuayExtension", FROST)
	_tint(port, "QuayExtensionEdge", ICE)
	# A thick snow cap over each pitched roof.
	var cap: PrismMesh = PrismMesh.new()
	cap.size = Vector3(27, 5.2, 50.5)
	for suffix: String in ["", "2", "3", "4"]:
		var walls: Node3D = port.get_node_or_null("Warehouse" + suffix) as Node3D
		if walls == null: continue
		_tint(port, "Warehouse" + suffix, Color("9cc7d9"))
		_part(root, cap, Vector3(side * 72, 33.5, walls.position.z), SNOW, cache)
	# Snow on top of the stacked containers and the fuel tank or crane.
	for index: int in 3:
		var top: float = 16.45 if index < 2 else 10.45
		_box(root, Vector3(12.4, 0.9, 6.4), Vector3(side * 46, top, (32 if index < 2 else 24) + index * 16), SNOW, cache)
	if port.get_node_or_null("FuelStore") != null: _ball(root, 8.5, 5, Vector3(side * 83, 18.4, 25), SNOW, cache)
	# Snow drifts on the open quay and icicles hanging off the berth edge.
	# Patch 2.4 item 5: landward of the quay crane rails, clear of the stacks.
	for index: int in int(length / 30.0):
		var z: float = 15.0 + index * 30.0
		if z < 62.0: continue
		_ball(root, 3.0 + (index % 2), 2.4, Vector3(side * (44.5 + (index % 2) * 1.5), 4.2, z), SNOW, cache)
		var icicle: CylinderMesh = CylinderMesh.new()
		icicle.top_radius = 0.7
		icicle.bottom_radius = 0.05
		icicle.height = 2.4
		icicle.radial_segments = 6
		icicle.rings = 1
		_part(root, icicle, Vector3(side * 19.0, 2.0, z + 6.0), ICE, cache)

## Patch 2.2 item 1: container ships 2-5. The starter's shapes grown with the
## record's hull (s scales heights), each with its own silhouette: the coastal
## feeder carries two deck cranes, the Panamax a tall stern house, the
## Neo-Panamax twin funnels, and the ultra-large ship its bridge well forward
## with the funnel aft. Hatch covers sit under each row of the container layout
## (tools/build_container_ladder.py keeps the rows clear of the houses).
static func _dress_box_ship(root: Node3D, hull: MeshInstance3D, definition: ShipDefinition, tier: int, main: Color, trim: Color, cache: Dictionary) -> void:
	var size: Vector3 = definition.hull_size_m
	var s: float = size.y / 4.0
	var deck: float = 2.6 * s
	hull.mesh = hull_mesh(size.z, size.x, -3.2 * s, deck, 3.5 * s, 1.6 * s, main, Color("c9b48a"))
	var aft: float = -size.z / 2.0
	if tier < 5:
		_house(root, Vector3(0, deck, aft + 10.5 * s), Vector3(size.x - 2.6 * s, (5.5 + tier) * s, 11 * s), main, cache)
		var top: float = deck + (6.2 + tier) * s
		_house(root, Vector3(0, top, aft + 12 * s), Vector3(size.x - 0.6, 3.6 * s, 6.5 * s), main, cache)
		for x: float in ([-size.x * 0.16, size.x * 0.16] if tier == 4 else [0.0]):
			_funnel(root, Vector3(x, top, aft + 6 * s), 2.0 * s, 6.5 * s, main, cache)
		_drum(root, 0.25 * s, 0.25 * s, 4.0 * s, Vector3(0, top + 6.3 * s, aft + 12 * s), WHITE, cache)
		_ball(root, 0.7 * s, 1.4 * s, Vector3(0, top + 8.6 * s, aft + 12 * s), trim, cache)
	else:
		# Engine house and funnel aft, a slim accommodation tower forward.
		_house(root, Vector3(0, deck, aft + 10.5 * s), Vector3(size.x * 0.55, 4.0 * s, 11 * s), main, cache)
		_funnel(root, Vector3(0, deck + 4.7 * s, aft + 9 * s), 2.4 * s, 7.0 * s, main, cache)
		var bridge: float = size.z * 0.2
		_house(root, Vector3(0, deck, bridge), Vector3(size.x * 0.4, 7.0 * s, 9 * s), main, cache)
		_house(root, Vector3(0, deck + 7.7 * s, bridge), Vector3(size.x - 0.6, 3.2 * s, 6 * s), main, cache)
		_drum(root, 0.25 * s, 0.25 * s, 4.0 * s, Vector3(0, deck + 13.5 * s, bridge), WHITE, cache)
		_ball(root, 0.7 * s, 1.4 * s, Vector3(0, deck + 15.8 * s, bridge), trim, cache)
	_box(root, Vector3(4 * s, 1.4 * s, 3 * s), Vector3(0, deck + 0.7 * s, size.z / 2.0 - 8 * s), INK, cache)
	_drum(root, 0.45 * s, 0.45 * s, 4.5 * s, Vector3(0, deck + 2.25 * s, size.z / 2.0 - 5 * s), WHITE, cache)
	_ball(root, 0.8 * s, 1.6 * s, Vector3(0, deck + 4.9 * s, size.z / 2.0 - 5 * s), trim, cache)
	var layout: ContainerLayout = definition.container_layout
	if layout == null or layout.centres.is_empty(): return
	var low: float = layout.centres[0].y
	var rows: Dictionary = {}
	var reach: float = 0.0
	for centre: Vector3 in layout.centres:
		low = minf(low, centre.y)
		reach = maxf(reach, absf(centre.x))
	for centre: Vector3 in layout.centres:
		if is_equal_approx(centre.y, low): rows[centre.z] = true
	var width: float = reach * 2.0 + layout.container_size_m.x + 0.6
	for z: float in rows:
		_box(root, Vector3(width, 0.5, layout.container_size_m.z + 0.4), Vector3(0, deck + 0.25, z), trim, cache)
	if tier == 2:
		# Two deck cranes on the port rail, between the rows.
		var keys: Array = rows.keys()
		keys.sort()
		for index: int in [1, keys.size() - 2]:
			var z: float = (float(keys[index]) + float(keys[index + 1 if index + 1 < keys.size() else index - 1])) / 2.0
			var x: float = -(size.x / 2.0 - 1.2)
			_drum(root, 0.7, 0.6, 9.0, Vector3(x, deck + 4.5, z), trim, cache)
			_box(root, Vector3(1.6, 1.6, 2.0), Vector3(x, deck + 9.4, z), WHITE, cache)
			var jib: MeshInstance3D = _box(root, Vector3(0.6, 0.6, 12.0), Vector3(x + 0.8, deck + 11.0, z + 5.0), trim, cache)
			jib.rotation.x = -0.35

## Patch 2.2 item 2: bulk ships 1-5, sized from the record. A row of hatch
## covers that grows with the tier and a stern house that rises with it. Ships
## 1-2 (Handysize, Supramax) carry deck cranes between the hatches; ships 3-5
## are gearless with a raised forecastle; ship 5 (Valemax) has twin funnels.
static func _dress_bulker(root: Node3D, hull: MeshInstance3D, definition: ShipDefinition, tier: int, main: Color, trim: Color, cache: Dictionary) -> void:
	var size: Vector3 = definition.hull_size_m
	var s: float = size.y / 4.0
	var deck: float = 2.6 * s
	hull.mesh = hull_mesh(size.z, size.x, -3.2 * s, deck, 3.5 * s, 1.6 * s, main, Color("b9a47a"))
	var aft: float = -size.z / 2.0
	var bow: float = size.z / 2.0
	_house(root, Vector3(0, deck, aft + 10.5 * s), Vector3(size.x - 2.6 * s, (5.0 + tier * 1.5) * s, 11 * s), main, cache)
	var top: float = deck + (5.7 + tier * 1.5) * s
	_house(root, Vector3(0, top, aft + 12 * s), Vector3(size.x - 0.6, 3.4 * s, 6.5 * s), main, cache)
	for x: float in ([-size.x * 0.15, size.x * 0.15] if tier == 5 else [0.0]):
		_funnel(root, Vector3(x, top, aft + 6 * s), 1.9 * s, 6.0 * s, trim, cache)
	_drum(root, 0.25 * s, 0.25 * s, 4.0 * s, Vector3(0, top + 6.1 * s, aft + 12 * s), WHITE, cache)
	_ball(root, 0.7 * s, 1.4 * s, Vector3(0, top + 8.4 * s, aft + 12 * s), trim, cache)
	if tier >= 3:
		_box(root, Vector3(size.x * 0.45, 2.2 * s, 8 * s), Vector3(0, deck + 1.1 * s, bow - 10 * s), WHITE, cache)
	_box(root, Vector3(4 * s, 1.4 * s, 3 * s), Vector3(0, deck + 0.7 * s, bow - 8 * s), INK, cache)
	_drum(root, 0.45 * s, 0.45 * s, 4.5 * s, Vector3(0, deck + 2.25 * s, bow - 5 * s), WHITE, cache)
	_ball(root, 0.8 * s, 1.6 * s, Vector3(0, deck + 4.9 * s, bow - 5 * s), trim, cache)
	# Hatch covers, evenly spaced between the house and the bow.
	var count: int = [4, 5, 7, 9, 11][tier - 1]
	var start: float = aft + 20.0 * s
	var pitch: float = (bow - 15.0 * s - start) / count
	for index: int in count:
		var z: float = start + pitch * (index + 0.5)
		_box(root, Vector3(size.x * 0.66, 0.9 * s, pitch * 0.74), Vector3(0, deck + 0.45 * s, z), trim, cache)
		_box(root, Vector3(size.x * 0.6, 0.4 * s, pitch * 0.64), Vector3(0, deck + 1.0 * s, z), WHITE.lerp(trim, 0.35), cache)
		if tier > 2 or index == 0: continue
		# A deck crane in the gap aft of this hatch, its jib resting over it.
		var gap: float = z - pitch * 0.5
		_drum(root, 0.9 * s, 0.9 * s, 3.5 * s, Vector3(0, deck + 1.75 * s, gap), trim, cache)
		_box(root, Vector3(2.4 * s, 2.0 * s, 2.4 * s), Vector3(0, deck + 4.5 * s, gap), WHITE, cache)
		var jib: MeshInstance3D = _box(root, Vector3(0.6 * s, 0.6 * s, pitch * 0.9), Vector3(0, deck + 5.0 * s + pitch * 0.12, gap + pitch * 0.43), trim, cache)
		jib.rotation.x = -0.28

## Patch 2.2 item 3: heavy-lift ships 1-5. Ship 1 is the current heavy lifter:
## a low float, two side walls, an open stern and a tower at the bow. Bigger
## ships stretch it by beam and length like their colliders (heavy_lifter.gd).
## Ships 2-3 add two deck cranes on the port wall (project cargo ships);
## ships 4-5 are semi-submersibles with buoyancy towers at the stern, and
## ship 5 a helideck on its bridge. The lifting deck and the load keep their
## own models.
static func _dress_heavy(root: Node3D, hull: MeshInstance3D, definition: ShipDefinition, tier: int, main: Color, trim: Color, cache: Dictionary) -> void:
	var size: Vector3 = definition.hull_size_m
	var k: Vector3 = Vector3(size.x / 24.0, 1.0, size.z / 90.0)
	hull.mesh = hull_mesh(size.z, size.x, -4.5, -2.0, -1.6, 0.0, main, Color("8f9aa3"))
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(3, 5, 74) * k, Vector3(side * 10.5, 0.5, -5) * k, main, cache)
		_box(root, Vector3(3.3 * k.x, 0.6, 74.3 * k.z), Vector3(side * 10.5 * k.x, 3.2, -5 * k.z), WHITE, cache)
		if tier <= 3: _funnel(root, Vector3(side * 6.5 * k.x, 15.2, 37 * k.z), 1.7 * k.x, 6.0, trim, cache)
		if tier >= 4:
			# Buoyancy towers on the stern ends of the walls.
			var stern: float = -42.0 * k.z + 7.0 * k.z
			_box(root, Vector3(3 * k.x, 9.0 + tier, 10 * k.z), Vector3(side * 10.5 * k.x, 3.0 + (9.0 + tier) / 2.0, stern), trim, cache)
			_box(root, Vector3(3.4 * k.x, 0.8, 10.4 * k.z), Vector3(side * 10.5 * k.x, 3.4 + 9.0 + tier, stern), WHITE, cache)
	_house(root, Vector3(0, -2, 32 * k.z), Vector3(20 * k.x, 13, 17 * k.z), trim, cache)
	var bridge: float = 11.7 + (tier - 1) * 1.2
	if tier > 1: _house(root, Vector3(0, 11.0, 30 * k.z), Vector3(16 * k.x, bridge - 11.0, 11 * k.z), trim, cache)
	_house(root, Vector3(0, bridge, 30 * k.z), Vector3(14 * k.x, 3.5, 9 * k.z), trim, cache)
	_drum(root, 0.3, 0.3, 5.0, Vector3(0, bridge + 6.7, 30 * k.z), WHITE, cache)
	_ball(root, 0.8, 1.6, Vector3(0, bridge + 9.5, 30 * k.z), RUST, cache)
	if tier >= 4: _funnel(root, Vector3(0, bridge + 3.5, 26 * k.z), 1.8 * k.x, 5.0, main, cache)
	if tier == 5: _drum(root, 9.0, 9.0, 0.6, Vector3(0, bridge + 3.8, 36 * k.z), WHITE.lerp(Color("4caf50"), 0.5), cache)
	if tier in [2, 3]:
		# Twin heavy cranes on the port wall, jibs resting astern over the deck.
		var reach: float = (18.0 + tier * 2.0) * k.z
		for z: float in [-20.0 * k.z, 4.0 * k.z]:
			var base: Vector3 = Vector3(10.5 * k.x, 3.0, z)
			_drum(root, 2.0 * k.x, 2.3 * k.x, 8.0, base + Vector3(0, 4.0, 0), trim, cache)
			_box(root, Vector3(5.0, 4.0, 5.0), base + Vector3(-0.5, 10.0, 0), WHITE, cache)
			var jib: MeshInstance3D = _box(root, Vector3(1.6, 1.6, reach), base + Vector3(-3.0, 12.0 + reach * 0.5 * sin(0.18), -reach * 0.5 * cos(0.18)), trim, cache)
			jib.rotation.x = 0.18
