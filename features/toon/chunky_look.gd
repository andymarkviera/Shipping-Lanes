extends RefCounted
## Aesthetics 4: chunky ship and port shapes built in code, in bold flat colours.
## Looks only: no collider, anchor or size used by the rules is changed. Call
## before toon_look.gd `apply`, which gives every part its toon shading and outline.
const WHITE: Color = Color("f6f1e3")
const GLASS: Color = Color("24405e")
const INK: Color = Color("2b2f3a")
const CREAM: Color = Color("f2d58a")
const RUST: Color = Color("b8402f")
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
	var colours: Array = SHIP_COLOURS.get(kind, SHIP_COLOURS["container"])
	var main: Color = colours[0]
	var trim: Color = colours[1]
	var cache: Dictionary = {}
	var root: Node3D = Node3D.new()
	root.name = "ChunkyShip"
	assembly.visual.add_child(root)
	var size: Vector3 = ship.definition.hull_size_m
	var hull: MeshInstance3D = MeshInstance3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	if kind == "heavy":
		# Low float, two side walls, an open stern and a tower at the bow. The
		# lifting deck and the load keep their own models.
		hull.mesh = hull_mesh(size.z, size.x, -4.5, -2.0, -1.6, 0.0, main, Color("8f9aa3"))
		for side: float in [-1.0, 1.0]:
			_box(root, Vector3(3, 5, 74), Vector3(side * 10.5, 0.5, -5), main, cache)
			_box(root, Vector3(3.3, 0.6, 74.3), Vector3(side * 10.5, 3.2, -5), WHITE, cache)
			_funnel(root, Vector3(side * 6.5, 15.2, 37), 1.7, 6.0, trim, cache)
		_house(root, Vector3(0, -2, 32), Vector3(20, 13, 17), trim, cache)
		_house(root, Vector3(0, 11.7, 30), Vector3(14, 3.5, 9), trim, cache)
		_drum(root, 0.3, 0.3, 5.0, Vector3(0, 18.4, 30), WHITE, cache)
		_ball(root, 0.8, 1.6, Vector3(0, 21.2, 30), RUST, cache)
		return
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
	# Fat bollards and a dark timber face along the berth.
	_box(root, Vector3(1.0, 3.0, length - 2.0), Vector3(side * 19.6, 2.3, length / 2.0), Color("6b4a35"), cache)
	for index: int in int(length / 20.0):
		var z: float = 10.0 + index * 20.0
		_drum(root, 0.9, 0.9, 1.6, Vector3(side * 23.5, 4.8, z), INK, cache)
		_drum(root, 1.3, 1.3, 0.5, Vector3(side * 23.5, 5.8, z), INK, cache)
	# Warehouse: bright walls, a pitched red roof and big doors facing the water.
	_tint(port, "Warehouse", Color("e9dcb8"))
	var flat_roof: MeshInstance3D = _mesh_of(port, "WarehouseRoof")
	if flat_roof != null: flat_roof.hide()
	var shed: Vector3 = Vector3(side * 72, 26, length * 0.7)
	var roof: PrismMesh = PrismMesh.new()
	roof.size = Vector3(50, 10, 49)
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
		# Crane: bright frame, a boom out over the berth, a cab and a hook block.
		for label: String in ["GantryLegA", "GantryLegB", "GantryBeam"]:
			_tint(port, label, Color("f0a326"))
		for x: float in [34.0, 84.0]:
			_box(root, Vector3(8, 2, 12), Vector3(side * x, 5, 35), INK, cache)
		_box(root, Vector3(40, 2.4, 4), Vector3(side * 13, 35.3, 35), Color("f0a326"), cache)
		_box(root, Vector3(7, 5, 7), Vector3(side * 30, 31.3, 35), WHITE, cache)
		_box(root, Vector3(7.3, 1.8, 7.3), Vector3(side * 30, 31.8, 35), GLASS, cache)
		_box(root, Vector3(0.5, 6, 0.5), Vector3(side * 4, 31, 35), INK, cache)
		_box(root, Vector3(4, 1.2, 3), Vector3(side * 4, 27.6, 35), RUST, cache)
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
	_tint(port, "Warehouse", Color("9cc7d9"))
	# A thick snow cap over the pitched roof.
	var cap: PrismMesh = PrismMesh.new()
	cap.size = Vector3(27, 5.2, 50.5)
	_part(root, cap, Vector3(side * 72, 33.5, length * 0.7), SNOW, cache)
	# Snow on top of the stacked containers and the fuel tank or crane.
	for index: int in 3:
		var top: float = 16.45 if index < 2 else 10.45
		_box(root, Vector3(12.4, 0.9, 6.4), Vector3(side * 46, top, (32 if index < 2 else 24) + index * 16), SNOW, cache)
	if port.get_node_or_null("FuelStore") != null: _ball(root, 8.5, 5, Vector3(side * 83, 18.4, 25), SNOW, cache)
	if port.get_node_or_null("GantryBeam") != null: _box(root, Vector3(54.4, 1, 5.4), Vector3(side * 59, 37, 35), SNOW, cache)
	# Snow drifts on the open quay and icicles hanging off the berth edge.
	for index: int in int(length / 30.0):
		var z: float = 15.0 + index * 30.0
		_ball(root, 5.0 + (index % 2) * 2.0, 3.0, Vector3(side * (30.0 + (index % 2) * 4.0), 4.2, z), SNOW, cache)
		var icicle: CylinderMesh = CylinderMesh.new()
		icicle.top_radius = 0.7
		icicle.bottom_radius = 0.05
		icicle.height = 2.4
		icicle.radial_segments = 6
		icicle.rings = 1
		_part(root, icicle, Vector3(side * 19.0, 2.0, z + 6.0), ICE, cache)
