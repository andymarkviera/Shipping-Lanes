class_name BowSplash
extends Node3D
## Presentation only; never writes to the navigation body. The 3D splash at the
## bow (Patch 2.1): two raised white crests peeling off the stem, and chunks of
## spray that kick up, arc out and fall back into the water. All of it grows
## with speed and is gone when the ship stops. Works in world space.
const SPLASH_SHADER = preload("res://features/water/bow_splash.gdshader")
const MAX_CHUNKS: int = 96
## Fraction of full foam strength below which there is no splash at all.
const START_STRENGTH: float = 0.1
const GRAVITY: float = 16.0
const CREST_PARTS: int = 8
var wake: ShipWake
## 0 when stopped or creeping, 1 at full foam strength.
var power: float = 0.0
var chunks: Array[Dictionary] = []
var owed: float = 0.0
var random: RandomNumberGenerator = RandomNumberGenerator.new()
var material: ShaderMaterial
var cloud: MultiMesh = MultiMesh.new()
var crest: ImmediateMesh = ImmediateMesh.new()
var crest_peak_m: float = 0.0
## Patch 2.4 item 8: 1 for every ladder ship; small boats throw a smaller splash
## (their wake half-width over ship 1's 6.5 m, at least 0.35).
var spray_scale: float = 1.0

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	material = ShaderMaterial.new()
	material.shader = SPLASH_SHADER
	var lump: SphereMesh = SphereMesh.new()
	lump.radius = 0.5
	lump.height = 1.0
	lump.radial_segments = 6
	lump.rings = 3
	cloud.transform_format = MultiMesh.TRANSFORM_3D
	cloud.mesh = lump
	cloud.instance_count = MAX_CHUNKS
	cloud.visible_instance_count = 0
	var chunk_node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	chunk_node.name = "Chunks"
	chunk_node.multimesh = cloud
	var crest_node: MeshInstance3D = MeshInstance3D.new()
	crest_node.name = "Crest"
	crest_node.mesh = crest
	for part: GeometryInstance3D in [chunk_node, crest_node]:
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.extra_cull_margin = 8.0
		add_child(part)

func water_height(x: float, z: float) -> float:
	var ocean: OceanPresentation = wake.ocean
	return ocean.global_position.y + OceanPresentation.swell_height(x, z, ocean.elapsed, ocean.quality)

## The end of the hull that meets the water, so reversing splashes at the stern.
func heading() -> Vector3:
	return wake.ship.global_basis.z * wake.travel_sign()

func update(delta: float) -> void:
	var ocean: OceanPresentation = wake.ocean
	spray_scale = clampf(wake.half_width / 6.5, 0.35, 1.0)
	power = smoothstep(START_STRENGTH, 1.0, wake.strength)
	# Patch 2.4 item 8: no bow spray while a jumping hull is in the air.
	if is_instance_valid(wake.visual) and wake.visual.airborne: power = 0.0
	material.set_shader_parameter("foam_color", ocean.palette.foam_color)
	material.set_shader_parameter("shade_color", ocean.palette.foam_color.lerp(ocean.palette.surface_color, 0.28))
	if power > 0.0:
		var rate: float = (14.0 + 44.0 * power) * (0.5 if ocean.quality == 0 else 1.0)
		owed += maxf(delta, 0.0) * rate
		while owed >= 1.0:
			owed -= 1.0
			throw_chunk()
	else:
		owed = 0.0
	move_chunks(maxf(delta, 0.0))
	draw_chunks()
	draw_crest()

## One lump of water thrown up and outward from the side of the bow.
func throw_chunk() -> void:
	if chunks.size() >= MAX_CHUNKS: return
	var ship: CharacterBody3D = wake.ship
	var bow: Vector3 = heading()
	var across: Vector3 = ship.global_basis.x
	var side: float = 1.0 if random.randf() < 0.5 else -1.0
	# Further back from the stem the hull is wider, so the chunk starts further out.
	var back: float = random.randf()
	var start: Vector3 = ship.global_position + bow * (wake.half_length - back * wake.half_length * 0.3) + across * side * wake.half_width * (0.15 + 0.75 * sqrt(back))
	start.y = water_height(start.x, start.z) + 0.2
	var velocity: Vector3 = across * side * (1.5 + 5.5 * power) * random.randf_range(0.4, 1.0) * sqrt(spray_scale)
	velocity += Vector3.UP * (4.0 + 8.5 * power) * random.randf_range(0.55, 1.0) * sqrt(spray_scale)
	# Carried along with the ship for a moment, then left behind along the hull.
	# (Fractions raised with the 30 kn top speed so the spray falls behind the bow
	# at the same rate as it did at the old 10 m/s top speed.)
	velocity += Vector3(ship.velocity.x, 0, ship.velocity.z) * random.randf_range(0.58, 0.87)
	chunks.append({
		"position": start,
		"velocity": velocity,
		"size": (0.6 + 1.7 * power) * random.randf_range(0.55, 1.2) * spray_scale,
		"age": 0.0,
		"axis": Vector3(random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0)).normalized(),
		"spin": random.randf_range(-5.0, 5.0),
	})

## Patch 2.4 item 8: a ring of spray thrown out round the hull when a jumping
## boat lands. impact is 0 to 1; a soft touch-down throws little or nothing.
func burst(impact: float) -> void:
	if not is_finite(impact) or impact < 0.08 or not is_instance_valid(wake.ship): return
	var ship: CharacterBody3D = wake.ship
	var count: int = int(round(10.0 + 26.0 * impact))
	for index: int in count:
		if chunks.size() >= MAX_CHUNKS: return
		var angle: float = random.randf() * TAU
		var out: Vector3 = (ship.global_basis.x * cos(angle) + ship.global_basis.z * sin(angle) * 0.6).normalized()
		var start: Vector3 = ship.global_position + ship.global_basis.z * sin(angle) * wake.half_length * 0.6 + ship.global_basis.x * cos(angle) * wake.half_width
		start.y = water_height(start.x, start.z) + 0.1
		var velocity: Vector3 = out * (2.0 + 5.0 * impact) * random.randf_range(0.5, 1.0) + Vector3.UP * (3.0 + 7.0 * impact) * random.randf_range(0.5, 1.0)
		velocity += Vector3(ship.velocity.x, 0, ship.velocity.z) * random.randf_range(0.5, 0.8)
		chunks.append({
			"position": start,
			"velocity": velocity,
			"size": (0.5 + 0.9 * impact) * random.randf_range(0.6, 1.2),
			"age": 0.0,
			"axis": Vector3(random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0)).normalized(),
			"spin": random.randf_range(-5.0, 5.0),
		})

## Chunks fly on a simple arc and are gone once they sink back under the surface.
func move_chunks(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for chunk: Dictionary in chunks:
		chunk.age += delta
		chunk.velocity.y -= GRAVITY * delta
		chunk.position += chunk.velocity * delta
		var point: Vector3 = chunk.position
		var sunk: bool = chunk.velocity.y < 0.0 and point.y < water_height(point.x, point.z) - chunk.size * 0.5
		if not sunk and chunk.age < 4.0: kept.append(chunk)
	chunks = kept

func draw_chunks() -> void:
	cloud.visible_instance_count = chunks.size()
	for index: int in chunks.size():
		var chunk: Dictionary = chunks[index]
		# Pops out of the water quickly and thins a little while it flies.
		var size: float = chunk.size * minf(chunk.age / 0.1, 1.0) * (1.0 - 0.3 * minf(chunk.age / 1.5, 1.0))
		var shape: Basis = Basis(chunk.axis, chunk.spin * chunk.age).scaled_local(Vector3(size, size * 0.75, size * 1.15))
		cloud.set_instance_transform(index, Transform3D(shape, chunk.position))

## Height of the raised crest at a point t along it (0 at the stem, 1 at the tail).
func crest_height(t: float, side: float) -> float:
	var ragged: float = 0.72 + 0.28 * sin(t * 9.0 - wake.ocean.elapsed * 7.0 + side * 1.3)
	return power * (1.0 + 2.8 * power) * sin(PI * pow(t, 0.6)) * ragged * spray_scale

## Two sheets of water standing up off the bow and sweeping back along the hull.
func draw_crest() -> void:
	crest.clear_surfaces()
	crest_peak_m = 0.0
	if power <= 0.0: return
	var ship: CharacterBody3D = wake.ship
	var strength: float = wake.strength
	var bow: Vector3 = heading()
	var across: Vector3 = ship.global_basis.x
	var tip: Vector3 = ship.global_position + bow * (wake.half_length + 1.0 + strength * 1.5)
	crest.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var previous: Array[Vector3] = []
		for part: int in range(CREST_PARTS + 1):
			var t: float = float(part) / float(CREST_PARTS)
			var point: Vector3 = tip + across * side * t * (wake.half_width * 1.5 + strength * 5.0) - bow * t * t * wake.half_length * (0.45 + strength * 0.35)
			point.y = water_height(point.x, point.z) + 0.1
			# Outward from the hull, square to the line the crest follows.
			var outward: Vector3 = (across * side * (wake.half_length * (0.9 + strength * 0.7) * t) + bow * (wake.half_width * 1.5 + strength * 5.0)).normalized()
			var half: float = (0.4 + (1.0 - t) * (0.5 + strength * 1.4)) * spray_scale
			var height: float = crest_height(t, side)
			crest_peak_m = maxf(crest_peak_m, height)
			var section: Array[Vector3] = [point - outward * half, point + outward * half * 0.9 + Vector3.UP * height, point + outward * half * 1.6]
			if not previous.is_empty():
				for face: int in range(2):
					for corner: Vector3 in [previous[face], previous[face + 1], section[face + 1], previous[face], section[face + 1], section[face]]:
						crest.surface_add_vertex(corner)
			previous = section
	crest.surface_end()
