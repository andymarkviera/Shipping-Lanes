extends RefCounted
## Patch 2.5 item 4: the desert's dressing. Looks only: nothing here is solid,
## so the land's colliders, the navigation and every berth stay as they were.
## Dunes and mesas stand on the desert's land, away from the ports, as a few
## MultiMeshes (one draw call per kind); the ports in the desert get sandstone
## quays, adobe sheds with terracotta roofs, flat-roofed houses, a domed tower
## and cacti. Placement is seeded, so it is the same every run.
const Chunky = preload("res://features/toon/chunky_look.gd")
const Desert = preload("res://features/sky/desert_biome.gd")
const SEED: int = 2504
## Hill tops are 18 m above the sea (toon_coast.gd HILL_TOP_Y).
const GROUND_Y: float = 18.0
## Dunes and mesas keep this far from the sea and from any port.
const COAST_CLEAR_M: float = 110.0
const PORT_CLEAR_M: float = 450.0
const DUNE_SPACING_M: float = 120.0
const MESA_SPACING_M: float = 420.0
const SAND_TOP := Color("e2ac62")
const DUNE := Color("efc27a")
const MESA_BANDS: Array[Color] = [Color("b8532f"), Color("d9844f"), Color("c8643c")]
const MESA_CAP := Color("e8a464")
const SANDSTONE := Color("d9b98a")
const ADOBE := Color("e8c49a")
const TERRACOTTA := Color("c66a3d")
const CACTUS := Color("5f9a4a")

## True for a land block that belongs to the desert.
static func is_desert(rect: Rect2) -> bool:
	return Desert.weight(Vector3(rect.get_center().x, 0, rect.get_center().y)) >= 0.5

static func _clear_of_ports(at: Vector2, ports: Array[Vector2]) -> bool:
	for place: Vector2 in ports:
		# A port's quay runs a kilometre north (+Z) of its berth origin.
		var nearest: Vector2 = Vector2(place.x, clampf(at.y, place.y, place.y + 1000.0))
		if at.distance_to(nearest) < PORT_CLEAR_M: return false
	return true

static func _multi(mesh: PrimitiveMesh, transforms: Array[Transform3D], colour: Color, label: String) -> MultiMeshInstance3D:
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index: int in transforms.size(): multi.set_instance_transform(index, transforms[index])
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.95
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	# On the mesh, so the toon pass (toon_look.gd) turns it into toon + ink.
	mesh.material = material
	# Far beyond the 3 km far plane anyway; dunes are small, so they go first.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if label == "Dunes" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return node

## Where the dunes and the mesa bands go over the desert blocks of `blocks`:
## {"dunes": [Transform3D], "mesas": [[Transform3D] per band]}, or {} when no
## block is desert.
static func placements(blocks: Array, ports: Array[Vector2]) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var dunes: Array[Transform3D] = []
	var mesas: Array[Array] = [[], [], [], []]
	var desert_blocks: Array[Rect2] = []
	for rect: Rect2 in blocks:
		if is_desert(rect): desert_blocks.append(rect)
	if desert_blocks.is_empty(): return {}
	for rect: Rect2 in desert_blocks:
		var inner: Rect2 = rect.grow(-COAST_CLEAR_M)
		if inner.size.x <= 0.0 or inner.size.y <= 0.0: continue
		# Dunes: long, low, wind-combed crests, all leaning the same way.
		for gx: int in int(inner.size.x / DUNE_SPACING_M) + 1:
			for gz: int in int(inner.size.y / DUNE_SPACING_M) + 1:
				var at: Vector2 = inner.position + Vector2(gx, gz) * DUNE_SPACING_M + Vector2(rng.randf_range(-35, 35), rng.randf_range(-35, 35))
				var wide: float = rng.randf_range(26, 46)
				var tall: float = rng.randf_range(5, 12)
				if not inner.has_point(at) or not _clear_of_ports(at, ports) or Desert.weight(Vector3(at.x, 0, at.y)) < 0.5: continue
				var basis: Basis = Basis(Vector3.UP, 0.6 + rng.randf_range(-0.25, 0.25)).scaled(Vector3(wide, tall, wide * rng.randf_range(1.8, 2.6)))
				dunes.append(Transform3D(basis, Vector3(at.x, GROUND_Y - 1.0, at.y)))
		# Mesas: flat-topped buttes in banded red rock, few and far between.
		for gx: int in int(inner.size.x / MESA_SPACING_M) + 1:
			for gz: int in int(inner.size.y / MESA_SPACING_M) + 1:
				var at: Vector2 = inner.position + Vector2(gx + 0.5, gz + 0.5) * MESA_SPACING_M + Vector2(rng.randf_range(-90, 90), rng.randf_range(-90, 90))
				var radius: float = rng.randf_range(45, 90)
				var height: float = rng.randf_range(40, 85)
				if not inner.grow(-radius).has_point(at) or not _clear_of_ports(at, ports) or Desert.weight(Vector3(at.x, 0, at.y)) < 0.5: continue
				var turn: float = rng.randf_range(0, TAU)
				var stretch: float = rng.randf_range(1.0, 1.5)
				var y: float = GROUND_Y - 2.0
				# Three bands, each a little narrower, then a pale cap.
				for band: int in 4:
					var share: float = [0.42, 0.33, 0.25, 0.04][band]
					var r: float = radius * [1.0, 0.92, 0.85, 0.83][band]
					var h: float = height * share
					var shape: Basis = Basis(Vector3.UP, turn).scaled(Vector3(r, h, r * stretch))
					mesas[band].append(Transform3D(shape, Vector3(at.x, y + h / 2.0, at.y)))
					y += h
	return {"dunes": dunes, "mesas": mesas}

## Dunes and mesas over the desert blocks of `blocks`. Returns the node, or
## null when no block is desert.
static func build_land(blocks: Array, ports: Array[Vector2]) -> Node3D:
	var spots: Dictionary = placements(blocks, ports)
	if spots.is_empty(): return null
	var dunes: Array[Transform3D] = spots.dunes
	var mesas: Array = spots.mesas
	var root: Node3D = Node3D.new()
	root.name = "DesertLand"
	var dune: SphereMesh = SphereMesh.new()
	dune.radius = 0.5
	dune.height = 1.0
	dune.radial_segments = 8
	dune.rings = 4
	dune.is_hemisphere = true
	root.add_child(_multi(dune, dunes, DUNE, "Dunes"))
	for band: int in 4:
		var drum: CylinderMesh = CylinderMesh.new()
		drum.bottom_radius = 1.0
		drum.top_radius = 0.97
		drum.height = 1.0
		drum.radial_segments = 7
		drum.rings = 1
		var typed: Array[Transform3D] = []
		typed.assign(mesas[band])
		root.add_child(_multi(drum, typed, MESA_CAP if band == 3 else MESA_BANDS[band], "Mesa%d" % band))
	return root

## Desert dressing on a port already given its chunky look (Chunky.dress_port).
static func dress_port(port: Node3D) -> void:
	var root: Node3D = port.get_node_or_null("ChunkyPort") as Node3D
	if root == null: return
	var side: float = float(port.quay_side)
	var length: float = float(port.quay_length_m)
	var cache: Dictionary = {}
	var desert: Node3D = Node3D.new()
	desert.name = "DesertPort"
	port.add_child(desert)
	for label: String in ["Quay", "QuayExtension"]: Chunky._tint(port, label, SANDSTONE)
	# Adobe sheds under terracotta roofs.
	var roof_look: StandardMaterial3D = StandardMaterial3D.new()
	roof_look.albedo_color = TERRACOTTA
	roof_look.roughness = 0.9
	for suffix: String in ["", "2", "3", "4"]:
		if port.get_node_or_null("Warehouse" + suffix) != null: Chunky._tint(port, "Warehouse" + suffix, ADOBE)
	for child: Node in root.get_children():
		var part: MeshInstance3D = child as MeshInstance3D
		if part != null and part.mesh is PrismMesh: part.material_override = roof_look
	# Flat-roofed adobe houses on the sand behind the quay, with dark doors.
	var index: int = 0
	var z: float = 40.0
	while z < length - 30.0:
		var wide: float = 12.0 + (index % 3) * 3.0
		var tall: float = 7.0 + (index % 2) * 5.0
		var x: float = side * (118.0 + (index % 2) * 18.0)
		Chunky._box(desert, Vector3(wide, tall, wide), Vector3(x, 4.0 + tall / 2.0, z), ADOBE if index % 2 == 0 else SANDSTONE, cache)
		Chunky._box(desert, Vector3(wide + 1.2, 1.0, wide + 1.2), Vector3(x, 4.5 + tall, z), TERRACOTTA, cache)
		Chunky._box(desert, Vector3(0.6, 4.0, 3.0), Vector3(x - side * (wide / 2.0 + 0.1), 6.0, z), Chunky.INK, cache)
		# A cactus or two between the houses.
		if index % 2 == 1:
			var at: Vector3 = Vector3(side * 106.0, 4.0, z + 22.0)
			Chunky._drum(desert, 1.4, 1.2, 9.0, at + Vector3(0, 4.5, 0), CACTUS, cache)
			Chunky._drum(desert, 0.8, 0.7, 4.0, at + Vector3(0, 6.5, 2.4), CACTUS, cache)
			Chunky._drum(desert, 0.8, 0.7, 3.0, at + Vector3(0, 5.5, -2.4), CACTUS, cache)
		index += 1
		z += 55.0
	# A domed watchtower at the middle of the quay's town, seen from the sea.
	var tower: Vector3 = Vector3(side * 156.0, 4.0, length * 0.5 + 27.0)
	Chunky._box(desert, Vector3(10, 26, 10), tower + Vector3(0, 13, 0), ADOBE, cache)
	Chunky._box(desert, Vector3(12, 1.2, 12), tower + Vector3(0, 26.6, 0), TERRACOTTA, cache)
	Chunky._ball(desert, 5.0, 7.0, tower + Vector3(0, 29.5, 0), Color("2f9a8f"), cache)
