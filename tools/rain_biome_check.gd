extends SceneTree
## Patch 2.5 item 6: the rainy city biome in the real game scene. Slatewater
## Works is fully rainy, every other port not at all (Brindle Quay, the start,
## stays dry); the blend is smooth and never overlaps the polar, desert or
## tropical looks. In the city the grade turns wet and dark, the sky overcast,
## rain falls from one pooled emitter that follows the camera and rings show on
## the sea; the skyline (lit windows, tower cranes) stands on city land clear
## of the sea and the ports and is not solid; Slatewater keeps its ID, place,
## berth and jobs and gets city dressing; leaving stops the rain and restores
## the dry look exactly. Isolated save folder.
## Run: godot --headless --path . --script res://tools/rain_biome_check.gd

const FOLDER: String = "user://rain_biome_check"
const Progression = preload("res://features/game/progression.gd")
const Rain = preload("res://features/sky/rain_biome.gd")
const Tropical = preload("res://features/sky/tropical_biome.gd")
const Desert = preload("res://features/sky/desert_biome.gd")
const Polar = preload("res://features/sky/polar_biome.gd")
const Look = preload("res://features/toon/city_look.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("RAIN BIOME FAILED: " + label)
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
		game.rain.update(at, 0.25)

func run() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	# The region: Slatewater Works in, every other port out, smooth, alone.
	for entry: Dictionary in Progression.WORLD:
		var inside: bool = entry.id == "port_slatewater_works"
		expect(is_equal_approx(Rain.weight(entry.at), 1.0 if inside else 0.0), "%s rain weight" % entry.id)
	var steepest: float = 0.0
	var overlap: float = 0.0
	for gx: int in 140:
		for gz: int in 140:
			var at: Vector3 = Vector3(-5600.0 + gx * 80.0, 0, -5600.0 + gz * 80.0)
			steepest = maxf(steepest, absf(Rain.weight(at + Vector3(10, 0, 0)) - Rain.weight(at)))
			overlap = maxf(overlap, minf(Rain.weight(at), maxf(Polar.weight(at), maxf(Desert.weight(at), Tropical.weight(at)))))
	expect(steepest < 0.04, "the edge fades over hundreds of metres (max %.3f per 10 m)" % steepest)
	expect(overlap == 0.0, "the rain never overlaps the polar, desert or tropical looks (%.2f)" % overlap)
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
	var rain: Node = game.get("rain")
	var polar: Node = game.get("polar")
	if not expect(rain != null and polar != null and polar.overlays.has(rain) and polar.overlays.back() == rain, "the game has the rain biome painted last over the others"): return finish()
	var environment: Environment = polar.environment
	var sea: ShaderMaterial = polar.ocean.ocean_material
	await process_frame
	expect(rain.applied == 0.0 and not rain.rain.emitting and not environment.adjustment_enabled, "a dry start shows no rain")
	expect(float(sea.get_shader_parameter("rain_amount")) == 0.0, "no rain rings on a dry sea")
	expect(rain.rain.amount == Rain.DROPS and rain.find_children("*", "GPUParticles3D", true, false).size() == 1, "one pooled rain emitter")
	var before: Dictionary = {"fog": environment.fog_light_color, "end": environment.fog_depth_end, "sun": polar.sun.light_energy,
		"horizon": polar.sky_material.get_shader_parameter("horizon_color"), "deep": sea.get_shader_parameter("deep_color")}
	# The skyline: towers, roofs, beacons and cranes on city land, not solid.
	var land: Node3D = game.get_node_or_null("CityLand") as Node3D
	var ports: Array[Vector2] = []
	for entry: Dictionary in Progression.WORLD: ports.append(Vector2(entry.at.x, entry.at.z))
	if expect(land != null, "the skyline is in the game"):
		var spots: Dictionary = Look.placements(Progression.LAND, ports)
		var towers: int = 0
		var lit: bool = true
		for colour: int in Look.WALLS.size():
			var group: MultiMeshInstance3D = land.get_node("Towers%d" % colour)
			towers += group.multimesh.instance_count
			expect(group.multimesh.instance_count == spots.towers[colour].size(), "tower group %d matches its seeded placements" % colour)
			lit = lit and group.material_override == game.city_paint[colour] and (group.material_override as ShaderMaterial).next_pass != null
		expect(towers >= 80, "a city skyline (%d towers)" % towers)
		expect(lit, "the towers wear the lit-window paint with an ink outline")
		expect((land.get_node("Roofs") as MultiMeshInstance3D).multimesh.instance_count == towers, "every tower has a roof")
		expect((land.get_node("Beacons") as MultiMeshInstance3D).multimesh.instance_count >= 3, "red lights on the tallest roofs")
		expect(spots.cranes.size() >= 2 and land.get_node_or_null("TowerCrane0") != null, "tower cranes over the city (%d)" % spots.cranes.size())
		var stray: int = 0
		var spots_all: Array = []
		for group: Array in spots.towers: spots_all.append_array(group)
		spots_all.append_array(spots.cranes)
		for spot: Transform3D in spots_all:
			var at: Vector3 = spot.origin
			var on_land: bool = true
			for probe: Vector2 in [Vector2.ZERO, Vector2(30, 0), Vector2(-30, 0), Vector2(0, 30), Vector2(0, -30)]:
				on_land = on_land and solid(Vector2(at.x, at.z) + probe)
			var near_port: bool = false
			for entry: Dictionary in Progression.WORLD:
				if Vector2(at.x, at.z).distance_to(Vector2(entry.at.x, entry.at.z)) < 190: near_port = true
			if not on_land or near_port or Rain.weight(at) < 0.5: stray += 1
		expect(stray == 0, "every tower and crane is on city land, clear of the sea and ports (%d stray)" % stray)
		expect(land.find_children("*", "CollisionObject3D", true, false).is_empty(), "the skyline is not solid")
	# A wet dark top on the city land.
	var wet: int = 0
	for body: Node in game.get_children():
		var shore: StaticBody3D = body as StaticBody3D
		if shore == null or shore.get_node_or_null("Coast") == null: continue
		var mesh: Mesh = (shore.get_node("Coast") as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var paint: Material = mesh.surface_get_material(surface)
			if paint is StandardMaterial3D and (paint as StandardMaterial3D).albedo_color.is_equal_approx(Look.WET_TOP): wet += 1
	expect(wet >= 1, "the city land has a wet top (%d)" % wet)
	# Slatewater Works: same port, city dressing, colliders unchanged.
	var slate: Node3D = null
	for place: Node3D in game.world_ports:
		if place.definition.id == "port_slatewater_works": slate = place
	if expect(slate != null, "Slatewater Works is still in the world"):
		var dressing: Node3D = slate.get_node_or_null("CityPort") as Node3D
		expect(dressing != null and dressing.get_child_count() >= 20, "Slatewater Works has city dressing")
		if dressing != null: expect(dressing.find_children("*", "CollisionObject3D", true, false).is_empty(), "its dressing is not solid")
		expect(slate.position.is_equal_approx(Progression.WORLD[Progression.port_index("port_slatewater_works")].at), "Slatewater Works has not moved")
		expect(game.world_ports.find(slate) == 1, "Slatewater Works keeps its port slot (jobs and saves)")
	for place: Node3D in game.world_ports:
		if place != slate: expect(place.get_node_or_null("CityPort") == null, "%s has no city dressing" % place.definition.id)
	# Into the rain: an eased fade, not a snap.
	var slate_at: Vector3 = Progression.WORLD[Progression.port_index("port_slatewater_works")].at
	steps(game, slate_at, 1)
	expect(rain.applied > 0.1 and rain.applied < 0.3, "a jump into the city fades in over time (%.2f)" % rain.applied)
	steps(game, slate_at, 12)
	expect(is_equal_approx(rain.applied, 1.0) and polar.applied == 0.0 and game.desert.applied == 0.0 and game.tropical.applied == 0.0, "fully rainy at Slatewater Works, no other biome")
	expect(rain.rain.emitting and is_equal_approx(rain.rain.amount_ratio, 1.0), "it is raining")
	expect(rain.rain.global_position.distance_to(polar.view_camera.global_position) < 60.0, "the rain falls round the camera")
	expect(is_equal_approx(float(sea.get_shader_parameter("rain_amount")), 1.0), "rain rings on the sea")
	expect(environment.fog_depth_end < before.end and polar.sun.light_energy < before.sun, "murky, overcast air")
	expect(environment.adjustment_enabled and environment.adjustment_brightness < 1.0 and environment.adjustment_saturation < 1.0, "wet, darker grading")
	expect((polar.sky_material.get_shader_parameter("horizon_color") as Color).is_equal_approx(Rain.SKY_HORIZON), "a grey rain sky")
	expect((sea.get_shader_parameter("deep_color") as Color).is_equal_approx(Rain.DEEP), "a dark sea")
	expect(float(game.city_paint[0].get_shader_parameter("glow")) > Rain.GLOW_DRY, "the windows glow brighter in the rain")
	# The world wraps: the rain moves with it.
	var start: Vector3 = rain.rain.global_position
	rain.shift(Vector3(Progression.WRAP_M, 0, 0))
	expect(rain.rain.global_position.is_equal_approx(start + Vector3(Progression.WRAP_M, 0, 0)), "the rain carries over a world wrap")
	# On to the tropics, then home: the rain stops and the dry look returns exactly.
	var gannet: Vector3 = Progression.WORLD[Progression.port_index("port_gannet_light")].at
	steps(game, gannet, 16)
	expect(rain.applied == 0.0 and is_equal_approx(game.tropical.applied, 1.0) and not rain.rain.emitting, "the tropics take over at Gannet Light")
	expect((sea.get_shader_parameter("surface_color") as Color).is_equal_approx(Tropical.SURFACE), "the tropical sea is untouched by the rain")
	steps(game, Progression.WORLD[0].at, 16)
	expect(rain.applied == 0.0 and not rain.rain.emitting and not environment.adjustment_enabled, "the rain fades out at Brindle Quay")
	expect(float(sea.get_shader_parameter("rain_amount")) == 0.0, "the rain rings stop")
	expect(environment.fog_light_color.is_equal_approx(before.fog) and is_equal_approx(environment.fog_depth_end, before.end), "fog restored")
	expect((polar.sky_material.get_shader_parameter("horizon_color") as Color).is_equal_approx(before.horizon), "sky restored")
	expect((sea.get_shader_parameter("deep_color") as Color).is_equal_approx(before.deep), "sea restored")
	expect(is_equal_approx(polar.sun.light_energy, before.sun), "sun restored")
	finish()

func finish() -> void:
	print("RAIN BIOME CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
