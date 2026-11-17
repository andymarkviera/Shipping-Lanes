extends SceneTree
## Patch 2.5 item 5: the tropical biome in the real game scene. Gannet Light is
## fully tropical, every other port not at all; the blend is smooth, never in
## the polar sea and never overlaps the desert. The Palm Isles are solid land
## like any other block. In the tropics the sky, sea and grading turn bright,
## clear and turquoise; palms and bushes stand on the tropical land, clear of
## the sea and the ports and not solid; lagoon rings ring the tropical islands,
## ride the swell and are paint only (no collider, nothing in the navigation);
## Gannet Light keeps its ID, berth and colliders and gets tropical dressing;
## leaving restores the temperate look exactly, and the polar and desert looks
## still work with the tropics painted over them. Isolated save folder.
## Run: godot --headless --path . --script res://tools/tropical_biome_check.gd

const FOLDER: String = "user://tropical_biome_check"
const Progression = preload("res://features/game/progression.gd")
const Tropical = preload("res://features/sky/tropical_biome.gd")
const Desert = preload("res://features/sky/desert_biome.gd")
const Polar = preload("res://features/sky/polar_biome.gd")
const Look = preload("res://features/toon/tropical_look.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("TROPICAL BIOME FAILED: " + label)
	return condition

func solid(point: Vector2) -> bool:
	for block: Rect2 in Progression.LAND:
		if block.has_point(point): return true
	return false

func steps(game: Node, at: Vector3, count: int) -> void:
	for frame: int in count:
		game.polar.update(at, 0.25)
		game.desert.update(at, 0.25)
		game.tropical.update(at, 0.25)

func run() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	# The region: Gannet Light in, every other port out, smooth, never polar or desert.
	for entry: Dictionary in Progression.WORLD:
		var inside: bool = entry.id == "port_gannet_light"
		expect(is_equal_approx(Tropical.weight(entry.at), 1.0 if inside else 0.0), "%s tropical weight" % entry.id)
	var steepest: float = 0.0
	var polar_overlap: float = 0.0
	var desert_overlap: float = 0.0
	for gx: int in 140:
		for gz: int in 140:
			var at: Vector3 = Vector3(-5600.0 + gx * 80.0, 0, -5600.0 + gz * 80.0)
			steepest = maxf(steepest, absf(Tropical.weight(at + Vector3(10, 0, 0)) - Tropical.weight(at)))
			if Polar.weight(at) >= 0.95: polar_overlap = maxf(polar_overlap, Tropical.weight(at))
			desert_overlap = maxf(desert_overlap, minf(Desert.weight(at), Tropical.weight(at)))
	expect(steepest < 0.03, "the edge fades over hundreds of metres (max %.3f per 10 m)" % steepest)
	expect(polar_overlap < 0.06, "the tropics never show in the full polar sea (%.2f)" % polar_overlap)
	expect(desert_overlap == 0.0, "the tropics and the desert never overlap (%.2f)" % desert_overlap)
	# The Palm Isles: a landmass of small tropical islands, ringed by lagoons.
	var isles: Array = []
	for mass: Array in Progression.LANDMASSES:
		if mass[0] == "Palm Isles": isles = mass
	# Patch 2.9 item 6A: natural isles are many blocks each; three coasts.
	var isle_coasts: Array[Rect2] = []
	for entry: Dictionary in Progression.natural_land().outlines:
		if entry.name != "Palm Isles": continue
		var bounds: Rect2 = Rect2(entry.outline[0], Vector2.ZERO)
		for spot: Vector2 in entry.outline: bounds = bounds.expand(spot)
		isle_coasts.append(bounds)
	if expect(isles.size() == 3 and isles[2] - isles[1] >= 3 and isle_coasts.size() >= 3, "the Palm Isles are in the land data (%d isles)" % isle_coasts.size()):
		for bounds: Rect2 in isle_coasts:
			expect(Look.islands().has(bounds), "Palm Isle at %s is a tropical island" % bounds.get_center())
	# The game.
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = null
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and scene.get("persistence") != null and is_instance_valid(scene.persistence) and (scene.persistence.ready_to_save or scene.persistence.blocked):
			game = scene
			break
	if not expect(game != null, "Game scene opened"): return finish()
	var tropical: Node = game.get("tropical")
	var desert: Node = game.get("desert")
	var polar: Node = game.get("polar")
	if not expect(tropical != null and desert != null and polar != null and polar.overlay == desert and polar.overlays.has(tropical), "the game has the tropical biome over the polar and desert ones"): return finish()
	var environment: Environment = polar.environment
	await process_frame
	expect(tropical.applied == 0.0 and not environment.adjustment_enabled, "a temperate start shows no tropical look")
	var before: Dictionary = {"fog": environment.fog_light_color, "end": environment.fog_depth_end, "sun": polar.sun.light_color,
		"horizon": polar.sky_material.get_shader_parameter("horizon_color"), "deep": polar.ocean.ocean_material.get_shader_parameter("deep_color"),
		"surface": polar.ocean.ocean_material.get_shader_parameter("surface_color")}
	# Palms and bushes on the tropical land, clear of sea and ports, not solid.
	var land: Node3D = game.get_node_or_null("TropicalLand") as Node3D
	var ports: Array[Vector2] = []
	for entry: Dictionary in Progression.WORLD: ports.append(Vector2(entry.at.x, entry.at.z))
	if expect(land != null, "the tropical land dressing is in the game"):
		var trunks: MultiMeshInstance3D = land.get_node("PalmTrunks")
		var crowns: MultiMeshInstance3D = land.get_node("PalmCrowns")
		var bushes: MultiMeshInstance3D = land.get_node("Bushes")
		expect(trunks.multimesh.instance_count >= 60 and crowns.multimesh.instance_count == trunks.multimesh.instance_count, "palms (%d)" % trunks.multimesh.instance_count)
		expect(bushes.multimesh.instance_count >= 5, "bushes (%d)" % bushes.multimesh.instance_count)
		# The placements the dressing was built from (a headless run keeps no
		# MultiMesh transforms to read back).
		var spots: Dictionary = Look.placements(Progression.LAND, ports)
		expect(spots.trunks.size() == trunks.multimesh.instance_count and spots.bushes.size() == bushes.multimesh.instance_count, "the dressing matches its seeded placements")
		var stray: int = 0
		var on_isles: int = 0
		for group: Array in [spots.trunks, spots.bushes]:
			for spot: Transform3D in group:
				var at: Vector3 = spot.origin
				# Land all round it, 30 m out (blocks meet at seams inland).
				# Patch 2.9 item 6A: 30 m or more in from the natural coast.
				var on_land: bool = Progression.land_depth(Vector2(at.x, at.z)) >= 30.0 and solid(Vector2(at.x, at.z))
				for index: int in range(isles[1], isles[2]):
					if Progression.LAND[index].has_point(Vector2(at.x, at.z)): on_isles += 1
				var near_port: bool = false
				for entry: Dictionary in Progression.WORLD:
					if Vector2(at.x, at.z).distance_to(Vector2(entry.at.x, entry.at.z)) < 400: near_port = true
				if not on_land or near_port or Tropical.weight(at) < 0.5:
					stray += 1
					print("TROPICAL stray at %s depth %.0f" % [at, Progression.land_depth(Vector2(at.x, at.z))])
		expect(stray == 0, "every palm and bush is on tropical land, clear of the sea and ports (%d stray)" % stray)
		expect(on_isles >= 30, "the Palm Isles have their palms (%d)" % on_isles)
		expect(land.find_children("*", "CollisionObject3D", true, false).is_empty(), "the dressing is not solid")
		expect(crowns.material_override is ShaderMaterial and (crowns.material_override as ShaderMaterial).next_pass != null, "palm crowns have the toon look")
	# Lush green tops on the tropical land; the Palm Isles are solid like any block.
	var lush: int = 0
	var isle_bodies: int = 0
	# Patch 2.9 item 6A: the hill tops of the natural land's coast chunks.
	for chunk: Node in game.get_node("NaturalLand").get_children():
		if not String(chunk.name).begins_with("Coast"): continue
		var mesh: Mesh = (chunk as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var paint: Material = mesh.surface_get_material(surface)
			if paint is StandardMaterial3D and (paint as StandardMaterial3D).albedo_color.is_equal_approx(Look.LUSH_TOP): lush += 1
	var isle_body: StaticBody3D = game.get_node_or_null("LandPalmIsles") as StaticBody3D
	if isle_body != null and isle_body.collision_layer == CollisionRules.SHORE: isle_bodies = isle_body.get_child_count()
	expect(isle_bodies == isles[2] - isles[1], "every Palm Isle is solid shore (%d blocks)" % isle_bodies)
	# Lagoon rings: paint on the water round every tropical island, nothing solid.
	var lagoons: Node3D = game.get_node_or_null("Lagoons") as Node3D
	var islands: int = 0
	islands = Look.islands().size()
	if expect(lagoons != null and lagoons.get_child_count() == islands and islands >= 3, "a lagoon ring round each tropical island (%d)" % islands):
		var shared: bool = true
		for ring: Node in lagoons.get_children():
			shared = shared and (ring as MeshInstance3D).material_override == game.lagoon_paint and (ring as MeshInstance3D).visibility_range_end > 0.0
		expect(shared, "the lagoons share one paint and are distance culled")
		expect(lagoons.find_children("*", "CollisionObject3D", true, false).is_empty(), "the lagoons are not solid (no hidden shallows)")
	for frame: int in 2: await process_frame
	expect(game.lagoon_paint != null and absf(float(game.lagoon_paint.get_shader_parameter("water_time")) - game.ocean.elapsed) < 0.5, "the lagoons ride the sea's swell")
	# Gannet Light: same port, tropical dressing, colliders unchanged.
	var gannet: Node3D = null
	for place: Node3D in game.world_ports:
		if place.definition.id == "port_gannet_light": gannet = place
	if expect(gannet != null, "Gannet Light is still in the world"):
		expect(gannet.get_node_or_null("TropicalPort") != null and gannet.get_node("TropicalPort").get_child_count() >= 20, "Gannet Light has tropical dressing")
		expect(gannet.get_node("TropicalPort").find_children("*", "CollisionObject3D", true, false).is_empty(), "its dressing is not solid")
		expect(gannet.position.is_equal_approx(Progression.WORLD[Progression.port_index("port_gannet_light")].at), "Gannet Light has not moved")
	for place: Node3D in game.world_ports:
		if place != gannet: expect(place.get_node_or_null("TropicalPort") == null, "%s has no tropical dressing" % place.definition.id)
	# Into the tropics: an eased fade, not a snap.
	var gannet_at: Vector3 = Progression.WORLD[Progression.port_index("port_gannet_light")].at
	steps(game, gannet_at, 1)
	expect(tropical.applied > 0.1 and tropical.applied < 0.3, "a jump into the tropics fades in over time (%.2f)" % tropical.applied)
	steps(game, gannet_at, 12)
	expect(is_equal_approx(tropical.applied, 1.0) and polar.applied == 0.0 and desert.applied == 0.0, "fully tropical at Gannet Light, not polar or desert")
	expect(lush >= 1, "the tropical land has a lush green top (%d)" % lush)
	expect(environment.fog_depth_end > before.end, "clear tropical air")
	var horizon: Color = polar.sky_material.get_shader_parameter("horizon_color")
	expect(horizon.g > horizon.r and horizon.b > horizon.r, "a bright aqua horizon")
	var surface: Color = polar.ocean.ocean_material.get_shader_parameter("surface_color")
	expect(surface.is_equal_approx(Tropical.SURFACE) and not surface.is_equal_approx(before.surface), "a turquoise sea")
	expect(environment.adjustment_enabled and environment.adjustment_saturation > 1.0, "bright, saturated grading")
	expect(not polar.snow.emitting, "no snow in the tropics")
	# A ship sails freely over a lagoon: the navigation sees only the island.
	# A remix can put another real island south of the first lagoon. Probe
	# unobstructed sides instead of assuming one hard-coded southern approach.
	var lagoon_routes: int = 0
	for isle: Rect2 in isle_coasts:
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var edge: Vector2 = isle.get_center() + direction * isle.size / 2.0
			var target: Vector2 = edge + direction * Look.LAGOON_M * 0.8
			var from: Vector2 = target + direction * 300.0
			if not Progression.clear_line(from, target): continue
			var lagoon_spot: Vector3 = Vector3(target.x, 0, target.y)
			var straight: Array[Vector3] = Progression.course(Vector3(from.x, 0, from.y), lagoon_spot)
			expect(straight == [lagoon_spot], "clear lagoon approach remains navigable")
			lagoon_routes += 1
	expect(lagoon_routes >= 3, "at least three open lagoon approaches (%d)" % lagoon_routes)
	# On to the desert: the tropics out, the desert in, no fight between them.
	var cinder: Vector3 = Progression.WORLD[Progression.port_index("port_cinder_point")].at
	steps(game, cinder, 16)
	expect(tropical.applied == 0.0 and is_equal_approx(desert.applied, 1.0), "the desert takes over at Cinder Point")
	expect((polar.ocean.ocean_material.get_shader_parameter("surface_color") as Color).is_equal_approx(Desert.SURFACE), "the desert sea is untouched by the tropics")
	# And to the North Pole.
	var north: Vector3 = Progression.WORLD[Progression.port_index("port_north_pole")].at
	steps(game, north, 16)
	expect(tropical.applied == 0.0 and is_equal_approx(polar.applied, 1.0) and polar.snow.emitting, "the polar look takes over in the polar sea")
	expect((polar.sky_material.get_shader_parameter("horizon_color") as Color).is_equal_approx(Polar.POLAR_SKY_HORIZON), "the polar sky is untouched by the tropics")
	# Back home: the temperate look returns exactly.
	steps(game, Progression.WORLD[0].at, 16)
	expect(tropical.applied == 0.0 and desert.applied == 0.0 and polar.applied == 0.0 and not environment.adjustment_enabled, "every look fades out")
	expect(environment.fog_light_color.is_equal_approx(before.fog) and is_equal_approx(environment.fog_depth_end, before.end), "fog restored")
	expect((polar.sky_material.get_shader_parameter("horizon_color") as Color).is_equal_approx(before.horizon), "sky restored")
	expect((polar.ocean.ocean_material.get_shader_parameter("deep_color") as Color).is_equal_approx(before.deep), "sea restored")
	finish()

func finish() -> void:
	print("TROPICAL BIOME CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
