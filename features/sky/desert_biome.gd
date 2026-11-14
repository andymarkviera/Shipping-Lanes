extends Node
## Patch 2.5 item 4: the Desert biome round Cinder Point, on Hearthland's
## northern half. Looks only. Sailing in blends in a warm, hazy, dry look: warm
## sun and ambient light, sandy haze, a pale warm horizon with few clouds, and a
## dry warm grade. The land there is sand, with dunes and mesas on it, and
## Cinder Point gets adobe dressing. No colliders change: the land blocks were
## already solid, and the dunes and mesas sit inside them.
## The look sits under the polar one (polar_biome.gd): it writes the polar
## biome's starting values, so the two never fight where they meet.
const Progression = preload("res://features/game/progression.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
## The desert's middle (X, Z). Fully desert within FULL_M (Cinder Point is),
## none beyond CLEAR_M (Brindle Quay, Needle Gut and Gull Isle are clear).
const CENTRE := Vector3(-1500, 0, 2000)
const FULL_M: float = 1400.0
const CLEAR_M: float = 2100.0
const EASE_SECONDS: float = 1.5

const FOG := Color(0.96, 0.85, 0.66)
const AMBIENT := Color(1.0, 0.89, 0.74)
const SUN := Color(1.0, 0.87, 0.64)
const SKY_TOP := Color(0.24, 0.52, 0.86)
const SKY_HORIZON := Color(0.98, 0.87, 0.68)
const CLOUD_SHADE := Color(0.97, 0.88, 0.76)
const DEEP := Color(0.07, 0.40, 0.58)
const SURFACE := Color(0.38, 0.78, 0.78)
## Dry warm grade: a touch less colour, warm shadows and highlights.
const GRADE_LOW := Color(0.06, 0.03, 0.0)
const GRADE_HIGH := Color(1.0, 0.95, 0.84)

const SAND := Color("e8c98a")
const DUNE := Color("e3b56f")
const MESA := Color("c26a3f")
const MESA_BAND := Color("9e4a30")
const MESA_CAP := Color("dd9a5a")
const ADOBE := Color("e6c08a")
const ADOBE_DARK := Color("d39a62")
const TERRACOTTA := Color("c4643a")
const DOOR := Color("6b4a35")
const CACTUS := Color("5f9a4a")
const TEAL := Color("2f9a8f")

var polar: Node
## The polar biome's own starting values, before the desert warms them.
var temperate: Dictionary = {}
var blend: float = -1.0
var applied: float = -1.0

## Where the desert look is, 0..1, for a world position (any copy across the wrap).
static func weight(at: Vector3) -> float:
	var away: Vector3 = Progression.short_way(at - CENTRE)
	return smoothstep(CLEAR_M, FULL_M, Vector2(away.x, away.z).length())

## A land block is desert (sand on top, dunes and mesas) when its middle is.
static func desert_land(rect: Rect2) -> bool:
	var middle: Vector2 = rect.get_center()
	return weight(Vector3(middle.x, 0, middle.y)) >= 0.5

func setup(under: Node) -> void:
	polar = under
	temperate = polar.base.duplicate()

## The ship's position this frame. Eases the blend and repaints only on change.
func update(at: Vector3, delta: float) -> void:
	var target: float = weight(at)
	blend = target if blend < 0.0 else move_toward(blend, target, delta / EASE_SECONDS)
	if absf(blend - applied) > 0.002 or (blend != applied and blend in [0.0, 1.0]): apply(blend)

func apply(value: float) -> void:
	applied = value
	var mixed: Dictionary = temperate.duplicate()
	mixed.fog = (temperate.fog as Color).lerp(FOG, value)
	mixed.fog_begin = lerpf(temperate.fog_begin, 220.0, value)
	mixed.fog_end = lerpf(temperate.fog_end, 2400.0, value)
	mixed.ambient = (temperate.ambient as Color).lerp(AMBIENT, value)
	mixed.ambient_energy = lerpf(temperate.ambient_energy, 0.78, value)
	mixed.sun = (temperate.sun as Color).lerp(SUN, value)
	mixed.sun_energy = lerpf(temperate.sun_energy, temperate.sun_energy * 1.12, value)
	if temperate.has("top_color"):
		mixed.top_color = (temperate.top_color as Color).lerp(SKY_TOP, value)
		mixed.horizon_color = (temperate.horizon_color as Color).lerp(SKY_HORIZON, value)
		mixed.cloud_shade_color = (temperate.cloud_shade_color as Color).lerp(CLOUD_SHADE, value)
		mixed.cloud_cover = lerpf(temperate.cloud_cover, 0.3, value)
	if temperate.has("deep"):
		mixed.deep = (temperate.deep as Color).lerp(DEEP, value)
		mixed.surface = (temperate.surface as Color).lerp(SURFACE, value)
	mixed.graded = value > 0.0
	mixed.saturation = lerpf(1.0, 0.9, value)
	mixed.contrast = lerpf(1.0, 1.04, value)
	mixed.brightness = lerpf(1.0, 1.02, value)
	mixed.grade_low = Color.BLACK.lerp(GRADE_LOW, value)
	mixed.grade_high = Color.WHITE.lerp(GRADE_HIGH, value)
	polar.base = mixed
	# The polar look repaints over the new start (once it has painted at all).
	if polar.applied >= 0.0: polar.apply(polar.applied)

## Dunes and mesas on the desert land, as four baked meshes (a handful of
## draw calls for the lot). Fixed seed: the same desert every run. They sit
## on the hilltop, clear of the coast, the ports and the bridges.
static func build_dressing() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "DesertDressing"
	var places: Array = placements()
	var dunes: Array[Transform3D] = places[0]
	var mesas: Array[Transform3D] = places[1]
	var dune: SphereMesh = SphereMesh.new()
	dune.radius = 1.0
	dune.height = 2.0
	dune.is_hemisphere = true
	dune.radial_segments = 9
	dune.rings = 3
	root.add_child(_many("Dunes", dune, DUNE, dunes))
	# A mesa: a steep red drum, a darker band and a pale overhanging cap.
	root.add_child(_many("Mesas", _drum(1.0, 0.82, 1.0, 0.0), MESA, mesas))
	root.add_child(_many("MesaBands", _drum(0.93, 0.92, 0.06, 0.47), MESA_BAND, mesas))
	root.add_child(_many("MesaCaps", _drum(0.86, 0.86, 0.08, 0.92), MESA_CAP, mesas))
	return root

## Where the dunes and mesas stand: [dune transforms, mesa transforms]. A mesa
## is a unit drum scaled to its radius and height, standing on the hilltop.
static func placements() -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2504
	var dunes: Array[Transform3D] = []
	var mesas: Array[Transform3D] = []
	for rect: Rect2 in Progression.LAND:
		if not desert_land(rect): continue
		var inner: Rect2 = rect.grow(-160.0)
		var x: float = inner.position.x
		while x < inner.end.x:
			var z: float = inner.position.y
			while z < inner.end.y:
				var at: Vector3 = Vector3(x + rng.randf_range(0, 120), TOON_COAST.HILL_TOP_Y, z + rng.randf_range(0, 120))
				var yaw: float = rng.randf_range(-0.5, 0.5) + 0.6
				var tall: bool = rng.randf() < 0.12
				z += 140.0
				if not inner.has_point(Vector2(at.x, at.z)) or weight(at) < 0.35 or near_works(at): continue
				if tall:
					var radius: float = rng.randf_range(40, 75)
					var height: float = rng.randf_range(30, 60)
					mesas.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(radius, height, radius * 0.8)), at))
				else:
					var size: Vector3 = Vector3(rng.randf_range(40, 70), rng.randf_range(7, 15), rng.randf_range(22, 38))
					dunes.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), at - Vector3(0, 0.5, 0)))
			x += 140.0
	return [dunes, mesas]

## True near a port or a bridge, where the desert keeps clear.
static func near_works(at: Vector3) -> bool:
	for place: Dictionary in Progression.WORLD:
		if Vector2(at.x - place.at.x, at.z - place.at.z).length() < 320.0: return true
	for bridge: Dictionary in Progression.BRIDGES:
		if Vector2(at.x, at.z).distance_to(bridge.at) < 350.0: return true
	return false

## A drum on the unit mesa: given radii and height, its bottom `bottom_y` up.
static func _drum(bottom: float, top: float, height: float, bottom_y: float) -> ArrayMesh:
	var drum: CylinderMesh = CylinderMesh.new()
	drum.bottom_radius = bottom
	drum.top_radius = top
	drum.height = height
	drum.radial_segments = 7
	drum.rings = 1
	# Bake the offset in, so each MultiMesh can share the mesa's transform.
	var tool: SurfaceTool = SurfaceTool.new()
	tool.append_from(drum, 0, Transform3D(Basis.IDENTITY, Vector3(0, bottom_y + height / 2.0, 0)))
	return tool.commit()

## One baked mesh per part for all the places: a draw call or two each. (A
## MultiMesh would stretch the ink outline with each instance's scale.)
static func _many(label: String, mesh: Mesh, colour: Color, places: Array[Transform3D]) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for place: Transform3D in places: tool.append_from(mesh, 0, place)
	tool.set_material(material)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	node.set_meta("pieces", places.size())
	return node

## Desert dressing for a port in the desert (Cinder Point): sandy quay and
## walls, a row of adobe houses with awnings and cacti on the sand behind the
## quay, and a domed hall and a water tower on the terrace. Not solid, all on
## land behind the warehouses, so berths, cranes and drop areas are untouched.
static func dress_port(port: Node3D) -> void:
	if not ("quay_side" in port) or weight(port.position) < 0.5: return
	var side: float = float(port.quay_side)
	var length: float = float(port.quay_length_m)
	var cache: Dictionary = {}
	var root: Node3D = Node3D.new()
	root.name = "DesertPort"
	port.add_child(root)
	CHUNKY_LOOK._tint(port, "Quay", Color("d8c39a"))
	CHUNKY_LOOK._tint(port, "QuayExtension", Color("d8c39a"))
	for suffix: String in ["", "2", "3", "4"]: CHUNKY_LOOK._tint(port, "Warehouse" + suffix, Color("efd3a2"))
	var sand_y: float = TOON_COAST.SAND_TOP_Y
	var index: int = 0
	var z: float = 70.0
	while z < length - 40.0:
		var size: Vector3 = Vector3(14 + (index % 3) * 3, 7 + (index % 2) * 4, 16 + (index % 4) * 2)
		var at: Vector3 = Vector3(side * 126, sand_y, z)
		var wall: Color = ADOBE if index % 2 == 0 else ADOBE_DARK
		CHUNKY_LOOK._box(root, size, at + Vector3(0, size.y / 2.0, 0), wall, cache)
		# Flat roof with a parapet lip, and roof beams poking out.
		CHUNKY_LOOK._box(root, Vector3(size.x + 1.0, 0.8, size.z + 1.0), at + Vector3(0, size.y + 0.4, 0), ADOBE_DARK if index % 2 == 0 else ADOBE, cache)
		for beam: int in 3:
			CHUNKY_LOOK._box(root, Vector3(2.0, 0.6, 0.6), at + Vector3(-side * (size.x / 2.0 + 0.8), size.y - 1.2, (beam - 1) * size.z / 3.0), DOOR, cache)
		# Door and a striped awning, facing the water.
		CHUNKY_LOOK._box(root, Vector3(0.4, 4.0, 3.0), at + Vector3(-side * (size.x / 2.0 + 0.1), 2.0, 0), DOOR, cache)
		CHUNKY_LOOK._box(root, Vector3(3.5, 0.4, 7.0), at + Vector3(-side * (size.x / 2.0 + 1.6), 4.8, 0), CHUNKY_LOOK.CREAM if index % 2 == 0 else TERRACOTTA, cache)
		# A cactus beside every other house.
		if index % 2 == 1:
			var foot: Vector3 = at + Vector3(-side * (size.x / 2.0 + 3.0), 0, size.z / 2.0 + 4.0)
			CHUNKY_LOOK._drum(root, 1.1, 1.0, 7.0, foot + Vector3(0, 3.5, 0), CACTUS, cache)
			CHUNKY_LOOK._drum(root, 0.6, 0.6, 3.0, foot + Vector3(1.6, 4.5, 0), CACTUS, cache)
		index += 1
		z += 58.0 + (index % 3) * 8.0
	# On the terrace: a domed hall with a teal top, and a water tower.
	var terrace: float = TOON_COAST.HILL_TOP_Y
	var hall: Vector3 = Vector3(side * 225, terrace, length * 0.45)
	CHUNKY_LOOK._box(root, Vector3(30, 12, 30), hall + Vector3(0, 6, 0), ADOBE, cache)
	CHUNKY_LOOK._drum(root, 11, 11, 4, hall + Vector3(0, 14, 0), ADOBE_DARK, cache)
	CHUNKY_LOOK._ball(root, 11, 14, hall + Vector3(0, 16, 0), CHUNKY_LOOK.WHITE, cache)
	CHUNKY_LOOK._drum(root, 1.2, 0.2, 4, hall + Vector3(0, 24, 0), TEAL, cache)
	var tower: Vector3 = Vector3(side * 215, terrace, length * 0.8)
	for leg: Vector2 in [Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3)]:
		CHUNKY_LOOK._box(root, Vector3(0.8, 14, 0.8), tower + Vector3(leg.x, 7, leg.y), DOOR, cache)
	CHUNKY_LOOK._drum(root, 5, 5, 6, tower + Vector3(0, 17, 0), TERRACOTTA, cache)
	CHUNKY_LOOK._drum(root, 5.6, 0.4, 2.5, tower + Vector3(0, 21.2, 0), ADOBE_DARK, cache)
