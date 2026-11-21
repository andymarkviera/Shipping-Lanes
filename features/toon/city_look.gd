extends RefCounted
## Patch 2.5 item 6: the rainy city port's dressing. Looks only: nothing here
## is solid, so the land's colliders, the navigation and every berth stay as
## they were. A skyline of towers with lit windows stands on the city land
## behind Slatewater Works as a few MultiMeshes (one draw call per kind), with
## tower cranes between them and red lights on the tallest roofs. The port
## gets a wet slate quay, brick sheds, lit brick blocks behind the quay and
## street lamps. Windows are a shader pattern on the walls (no textures, no
## extra meshes); they glow brighter in the rain (rain_biome.gd sets "glow").
## Placement is seeded, so it is the same every run.
const Chunky = preload("res://features/toon/chunky_look.gd")
const Coast = preload("res://features/toon/toon_coast.gd")
const ToonLook = preload("res://features/toon/toon_look.gd")
const Rain = preload("res://features/sky/rain_biome.gd")
const Progression = preload("res://features/game/progression.gd")
const SEED: int = 2506
const HILL_Y: float = 18.0
const BLOCK_M: float = 48.0
## Towers keep this far from any port's quay (its own lit blocks stand nearer).
const PORT_CLEAR_M: float = 200.0
const MAX_CRANES: int = 4
## Wall colours for the towers and the port's blocks: slate, brick, concrete.
const WALLS: Array[Color] = [Color("5f6b78"), Color("8c4a3c"), Color("a9a59a")]
const ROOF := Color("3a3f47")
## The city land's top: wet, dark green-grey.
const WET_TOP := Color("5f7466")
const SLATE := Color("5d646b")
const BRICK := Color("9a4b3c")
const CRANE := Color("f2b632")
const WARNING := Color(1.0, 0.18, 0.12)
const LAMP := Color(1.0, 0.86, 0.52)
const WINDOW_SHADER: String = """
shader_type spatial;
render_mode cull_back, specular_disabled;
// A toon wall (same bands as toon.gdshader) with a grid of windows, some lit.
uniform vec4 albedo : source_color = vec4(0.4, 0.45, 0.5, 1.0);
uniform vec4 glass : source_color = vec4(0.13, 0.17, 0.24, 1.0);
uniform vec4 window_light : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float lit_share = 0.42;
uniform float glow = 0.7;
uniform float floor_m = 4.0;
uniform float column_m = 4.5;
varying vec3 world;
varying vec3 world_normal;
float hash(vec2 cell) { return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
#include "res://features/toon/port_horizon.gdshaderinc"
void fragment() {
	port_horizon_clip(world, FRAGCOORD.xy);
	vec3 wall = albedo.rgb;
	vec3 shine = vec3(0.0);
	if (abs(world_normal.y) < 0.5) {
		float along = abs(world_normal.x) > 0.5 ? world.z : world.x;
		vec2 grid = vec2(along / column_m, world.y / floor_m);
		vec2 cell = floor(grid);
		vec2 inside = fract(grid);
		float pane = step(0.22, inside.x) * step(inside.x, 0.78) * step(0.28, inside.y) * step(inside.y, 0.72);
		float lit = step(hash(cell + floor(world_normal.xz * 3.0) * 91.0), lit_share);
		// Far walls blend to their average so the grid cannot shimmer.
		float detail = 1.0 - smoothstep(0.25, 0.6, max(fwidth(grid.x), fwidth(grid.y)));
		vec3 near_wall = mix(wall, glass.rgb, pane);
		wall = mix(mix(wall, glass.rgb, 0.31), near_wall, detail);
		shine = window_light.rgb * glow * mix(0.31 * lit_share, pane * lit, detail);
	}
	ALBEDO = wall;
	EMISSION = shine;
	ROUGHNESS = 1.0;
}
void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = 0.55 * smoothstep(0.105, 0.135, lit) + 0.45 * smoothstep(0.535, 0.565, lit);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
"""

## True for a land block that belongs to the rainy city.
static func is_city(rect: Rect2) -> bool:
	return Rain.weight(Vector3(rect.get_center().x, 0, rect.get_center().y)) >= 0.5

## The wall paint, one per WALLS colour, each with an ink outline.
static func window_materials() -> Array[ShaderMaterial]:
	var shader: Shader = Shader.new()
	shader.code = WINDOW_SHADER
	var paints: Array[ShaderMaterial] = []
	for colour: Color in WALLS:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("albedo", colour)
		material.set_shader_parameter("glow", Rain.GLOW_DRY)
		material.next_pass = ToonLook.outline(true)
		paints.append(material)
	return paints

static func _clear_of_ports(at: Vector2, ports: Array[Vector2]) -> bool:
	for place: Vector2 in ports:
		# A port's quay runs a kilometre north (+Z) of its berth origin.
		var nearest: Vector2 = Vector2(place.x, clampf(at.y, place.y, place.y + 1000.0))
		if at.distance_to(nearest) < PORT_CLEAR_M: return false
	return true

## Patch 2.9 item 6A: `margin` metres or more inland on the natural land
## (`blocks` is kept for callers; the coast depth grid decides).
static func _on_land(at: Vector2, blocks: Array, margin: float) -> bool:
	return Progression.land_depth(at) >= margin

## Where the towers and cranes go over the city blocks of `blocks`:
## {"towers": [[Transform3D]] (one list per WALLS colour), "roofs": [Transform3D],
## "beacons": [Transform3D], "cranes": [Transform3D]}, or {} when no block is city.
static func placements(blocks: Array, ports: Array[Vector2]) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var towers: Array = [[], [], []]
	var roofs: Array[Transform3D] = []
	var beacons: Array[Transform3D] = []
	var cranes: Array[Transform3D] = []
	var any: bool = false
	for rect: Rect2 in blocks:
		if is_city(rect): any = true
	if not any: return {}
	# Patch 2.9 item 6A: the city fills the natural land's hill tops.
	for at: Vector2 in Progression.inland_spots(BLOCK_M, Coast.HILL_TOP_M + 8.0, rng, 6.0):
		var pick: float = rng.randf()
		var wide: float = rng.randf_range(20, 32)
		var deep: float = rng.randf_range(20, 32)
		var tall: float = 22.0 + pow(rng.randf(), 2.2) * 130.0
		var colour: int = rng.randi_range(0, WALLS.size() - 1)
		if not _clear_of_ports(at, ports) or not _on_land(at, blocks, 30.0): continue
		# Patch 4.0.2 item 4: no tower on an airfield.
		# (Loaded here: airports.gd preloads this script for its city test.)
		if not load("res://features/planes/airports.gd").clear_of_airfields(at, maxf(wide, deep)): continue
		if Rain.weight(Vector3(at.x, 0, at.y)) < 0.5: continue
		if pick < 0.06 and cranes.size() < MAX_CRANES:
			cranes.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), Vector3(at.x, 0, at.y)))
			continue
		# A few open squares between the blocks.
		if pick < 0.12: continue
		# The box rises from under the hill so its foot never shows.
		var height: float = HILL_Y + tall
		towers[colour].append(Transform3D(Basis.from_scale(Vector3(wide, height, deep)), Vector3(at.x, height / 2.0, at.y)))
		roofs.append(Transform3D(Basis.from_scale(Vector3(wide + 1.5, 1.6, deep + 1.5)), Vector3(at.x, height + 0.4, at.y)))
		if tall > 95.0: beacons.append(Transform3D(Basis.from_scale(Vector3.ONE * 1.6), Vector3(at.x, height + 2.4, at.y)))
	if not any: return {}
	return {"towers": towers, "roofs": roofs, "beacons": beacons, "cranes": cranes}

static func _multi(mesh: Mesh, transforms: Array, label: String) -> MultiMeshInstance3D:
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index: int in transforms.size(): multi.set_instance_transform(index, transforms[index])
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	return node

static func _glow(colour: Color) -> StandardMaterial3D:
	# Unshaded, so the toon pass leaves it lit in the gloom.
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material

## A yellow tower crane at the origin of `parent`, its jib along +Z.
static func _tower_crane(parent: Node3D, tall: float, cache: Dictionary) -> void:
	Chunky._box(parent, Vector3(3, tall, 3), Vector3(0, tall / 2.0, 0), CRANE, cache)
	Chunky._box(parent, Vector3(2.4, 2.4, 64), Vector3(0, tall + 1.2, 22), CRANE, cache)
	Chunky._box(parent, Vector3(4.5, 3.5, 4.5), Vector3(0, tall - 1.0, 2.5), Chunky.WHITE, cache)
	Chunky._box(parent, Vector3(5, 4, 6), Vector3(0, tall + 0.5, -15), Color("6b737c"), cache)
	Chunky._box(parent, Vector3(1.2, 7, 1.2), Vector3(0, tall + 5.5, 0), CRANE, cache)
	# The hook line hangs from the trolley part-way out.
	Chunky._box(parent, Vector3(0.3, 26, 0.3), Vector3(0, tall - 13.0, 36), Chunky.INK, cache)
	Chunky._box(parent, Vector3(2.4, 1.6, 2.4), Vector3(0, tall - 26.5, 36), Chunky.INK, cache)
	var light: MeshInstance3D = MeshInstance3D.new()
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = 0.9
	bulb.height = 1.8
	light.mesh = bulb
	light.material_override = _glow(WARNING)
	light.position = Vector3(0, tall + 9.5, 0)
	parent.add_child(light)

## The skyline over the city blocks of `blocks`, painted with `walls`
## (window_materials()). Returns the node, or null when no block is city.
static func build_land(blocks: Array, ports: Array[Vector2], walls: Array[ShaderMaterial]) -> Node3D:
	var spots: Dictionary = placements(blocks, ports)
	if spots.is_empty(): return null
	var root: Node3D = Node3D.new()
	root.name = "CityLand"
	var block: BoxMesh = BoxMesh.new()
	for colour: int in WALLS.size():
		var towers: MultiMeshInstance3D = _multi(block, spots.towers[colour], "Towers%d" % colour)
		towers.material_override = walls[colour]
		root.add_child(towers)
	var cap: BoxMesh = BoxMesh.new()
	var roof_look: StandardMaterial3D = StandardMaterial3D.new()
	roof_look.albedo_color = ROOF
	roof_look.roughness = 1.0
	# On the mesh, so the toon pass turns it into toon + ink.
	cap.material = roof_look
	var roofs: MultiMeshInstance3D = _multi(cap, spots.roofs, "Roofs")
	roofs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(roofs)
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = 0.5
	bulb.height = 1.0
	bulb.radial_segments = 8
	bulb.rings = 4
	bulb.material = _glow(WARNING)
	var beacons: MultiMeshInstance3D = _multi(bulb, spots.beacons, "Beacons")
	beacons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beacons)
	var cache: Dictionary = {}
	var index: int = 0
	for spot: Transform3D in spots.cranes:
		var crane: Node3D = Node3D.new()
		crane.name = "TowerCrane%d" % index
		crane.transform = spot
		root.add_child(crane)
		_tower_crane(crane, HILL_Y + 70.0 + (index % 2) * 18.0, cache)
		index += 1
	return root

## City dressing on a port already given its chunky look (Chunky.dress_port).
## `walls` is window_materials(); the port's blocks share it with the skyline.
static func dress_port(port: Node3D, walls: Array[ShaderMaterial], blocks: Array) -> void:
	var root: Node3D = port.get_node_or_null("ChunkyPort") as Node3D
	if root == null: return
	var side: float = float(port.quay_side)
	var length: float = float(port.quay_length_m)
	var cache: Dictionary = {}
	var city: Node3D = Node3D.new()
	city.name = "CityPort"
	port.add_child(city)
	for label: String in ["Quay", "QuayExtension"]: Chunky._tint(port, label, SLATE)
	for suffix: String in ["", "2", "3", "4"]:
		if port.get_node_or_null("Warehouse" + suffix) != null: Chunky._tint(port, "Warehouse" + suffix, BRICK)
	# Lit brick and stone blocks on the land behind the quay, flat dark roofs.
	var index: int = 0
	var z: float = 40.0
	var origin: Vector2 = Vector2(port.position.x, port.position.z)
	while z < length - 30.0:
		var wide: float = 24.0 + (index % 3) * 4.0
		var tall: float = 22.0 + ((index * 7) % 5) * 7.0
		var x: float = side * (130.0 + (index % 2) * 22.0)
		if _on_land(origin + Vector2(x, z), blocks, wide * 0.5 + 4.0):
			var body: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(wide, tall + 4.0, wide)
			body.mesh = mesh
			body.position = Vector3(x, 2.0 + tall / 2.0, z)
			body.material_override = walls[index % walls.size()]
			city.add_child(body)
			Chunky._box(city, Vector3(wide + 1.2, 1.2, wide + 1.2), Vector3(x, 4.6 + tall, z), ROOF, cache)
		index += 1
		z += 50.0
	# Street lamps along the back of the quay, glowing in the wet.
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.9
	head.height = 1.6
	var lamp_look: StandardMaterial3D = _glow(LAMP)
	z = 30.0
	while z < length - 10.0:
		Chunky._drum(city, 0.3, 0.25, 8.0, Vector3(side * 97.0, 8.0, z), Chunky.INK, cache)
		var bulb: MeshInstance3D = MeshInstance3D.new()
		bulb.mesh = head
		bulb.material_override = lamp_look
		bulb.position = Vector3(side * 97.0, 12.6, z)
		city.add_child(bulb)
		z += 45.0
