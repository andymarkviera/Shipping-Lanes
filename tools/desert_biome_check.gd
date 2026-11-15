extends SceneTree
## Patch 2.5 item 4: the desert biome in the real game scene. Cinder Point is
## fully desert, every other port not at all; the blend is smooth and never
## inside the polar sea. In the desert the fog, sky, sea and grading turn warm
## and hazy; dunes and mesas stand on the desert land, clear of the sea and the
## ports and not solid; Cinder Point keeps its ID, berth and colliders and gets
## its desert dressing; leaving restores the temperate look exactly, and the
## polar look still works with the desert painted over it. Isolated save folder.
## Run: godot --headless --path . --script res://tools/desert_biome_check.gd

const FOLDER: String = "user://desert_biome_check"
const Progression = preload("res://features/game/progression.gd")
const Desert = preload("res://features/sky/desert_biome.gd")
const Polar = preload("res://features/sky/polar_biome.gd")
const Look = preload("res://features/toon/desert_look.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("DESERT BIOME FAILED: " + label)
	return condition

func run() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	# The region: Cinder Point in, every other port out, smooth, never polar.
	for entry: Dictionary in Progression.WORLD:
		var inside: bool = entry.id == "port_cinder_point"
		expect(is_equal_approx(Desert.weight(entry.at), 1.0 if inside else 0.0), "%s desert weight" % entry.id)
	var steepest: float = 0.0
	var overlap: float = 0.0
	for gx: int in 140:
		for gz: int in 140:
			var at: Vector3 = Vector3(-5600.0 + gx * 80.0, 0, -5600.0 + gz * 80.0)
			steepest = maxf(steepest, absf(Desert.weight(at + Vector3(10, 0, 0)) - Desert.weight(at)))
			if Polar.weight(at) >= 0.95: overlap = maxf(overlap, Desert.weight(at))
	expect(steepest < 0.03, "the edge fades over hundreds of metres (max %.3f per 10 m)" % steepest)
	expect(overlap < 0.06, "the desert never shows in the full polar sea (%.2f)" % overlap)
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
	var desert: Node = game.get("desert")
	var polar: Node = game.get("polar")
	if not expect(desert != null and polar != null and polar.overlay == desert, "the game has the desert biome over the polar one"): return finish()
	var environment: Environment = polar.environment
	await process_frame
	expect(desert.applied == 0.0 and not environment.adjustment_enabled, "a temperate start shows no desert look")
	var before: Dictionary = {"fog": environment.fog_light_color, "end": environment.fog_depth_end, "sun": polar.sun.light_color,
		"horizon": polar.sky_material.get_shader_parameter("horizon_color"), "deep": polar.ocean.ocean_material.get_shader_parameter("deep_color")}
	# Dunes and mesas on the desert land, clear of sea and ports, not solid.
	var land: Node3D = game.get_node_or_null("DesertLand") as Node3D
	if expect(land != null, "the desert land dressing is in the game"):
		var dunes: MultiMeshInstance3D = land.get_node("Dunes")
		expect(dunes.multimesh.instance_count >= 40, "dunes (%d)" % dunes.multimesh.instance_count)
		var mesas: int = (land.get_node("Mesa0") as MultiMeshInstance3D).multimesh.instance_count
		expect(mesas >= 3, "mesas (%d)" % mesas)
		var stray: int = 0
		# The placements the dressing was built from (a headless run keeps no
		# MultiMesh transforms to read back).
		var ports: Array[Vector2] = []
		for entry: Dictionary in Progression.WORLD: ports.append(Vector2(entry.at.x, entry.at.z))
		var spots: Dictionary = Look.placements(Progression.LAND, ports)
		expect(spots.dunes.size() == dunes.multimesh.instance_count and spots.mesas[0].size() == mesas, "the dressing matches its seeded placements")
		for group: Array in [spots.dunes, spots.mesas[0]]:
			for spot: Transform3D in group:
				var at: Vector3 = spot.origin
				# Patch 2.9 item 6A: 80 m or more in from the natural coast.
				var on_land: bool = Progression.land_depth(Vector2(at.x, at.z)) >= 80.0
				var near_port: bool = false
				for entry: Dictionary in Progression.WORLD:
					if Vector2(at.x, at.z).distance_to(Vector2(entry.at.x, entry.at.z)) < 400: near_port = true
				if not on_land or near_port or Desert.weight(at) < 0.5: stray += 1
		expect(stray == 0, "every dune and mesa is on desert land, clear of the sea and ports (%d stray)" % stray)
		var solid: int = 0
		for child: Node in land.find_children("*", "CollisionObject3D", true, false): solid += 1
		expect(solid == 0, "the dressing is not solid")
		expect(dunes.material_override is ShaderMaterial and (dunes.material_override as ShaderMaterial).next_pass != null, "dunes have the toon look")
	# Cinder Point: same port, desert dressing, colliders unchanged.
	var cinder: Node3D = null
	for place: Node3D in game.world_ports:
		if place.definition.id == "port_cinder_point": cinder = place
	if expect(cinder != null, "Cinder Point is still in the world"):
		expect(cinder.get_node_or_null("DesertPort") != null and cinder.get_node("DesertPort").get_child_count() >= 20, "Cinder Point has desert dressing")
		expect(cinder.get_node("DesertPort").find_children("*", "CollisionObject3D", true, false).is_empty(), "its dressing is not solid")
		expect(cinder.position.is_equal_approx(Progression.WORLD[Progression.port_index("port_cinder_point")].at), "Cinder Point has not moved")
	for place: Node3D in game.world_ports:
		if place != cinder: expect(place.get_node_or_null("DesertPort") == null, "%s has no desert dressing" % place.definition.id)
	# Into the desert: an eased fade, not a snap.
	var cinder_at: Vector3 = Progression.WORLD[Progression.port_index("port_cinder_point")].at
	polar.update(cinder_at, 0.25)
	desert.update(cinder_at, 0.25)
	expect(desert.applied > 0.1 and desert.applied < 0.3, "a jump into the desert fades in over time (%.2f)" % desert.applied)
	for frame: int in 12:
		polar.update(cinder_at, 0.25)
		desert.update(cinder_at, 0.25)
	expect(is_equal_approx(desert.applied, 1.0) and polar.applied == 0.0, "fully desert at Cinder Point, not polar")
	expect(environment.fog_depth_end < before.end and environment.fog_light_color.r > environment.fog_light_color.b, "warm haze")
	expect(polar.sun.light_color.r >= polar.sun.light_color.b and polar.sun.light_color.b < (before.sun as Color).b + 0.001, "warm light")
	var horizon: Color = polar.sky_material.get_shader_parameter("horizon_color")
	expect(horizon.r > horizon.b, "a sandy horizon")
	expect(not (polar.ocean.ocean_material.get_shader_parameter("deep_color") as Color).is_equal_approx(before.deep), "a desert sea tone")
	expect(environment.adjustment_enabled and environment.adjustment_saturation < 1.0 and polar.grade.get_color(1).b < polar.grade.get_color(1).r, "dry, warm grading")
	expect(not polar.snow.emitting, "no snow in the desert")
	# Straight on to the North Pole: desert out, polar in, no fight between them.
	var north: Vector3 = Progression.WORLD[Progression.port_index("port_north_pole")].at
	for frame: int in 16:
		polar.update(north, 0.25)
		desert.update(north, 0.25)
	expect(desert.applied == 0.0 and is_equal_approx(polar.applied, 1.0) and polar.snow.emitting, "the polar look takes over in the polar sea")
	expect((polar.sky_material.get_shader_parameter("horizon_color") as Color).is_equal_approx(Polar.POLAR_SKY_HORIZON), "the polar sky is untouched by the desert")
	# Back home: the temperate look returns exactly.
	var home: Vector3 = Progression.WORLD[0].at
	for frame: int in 16:
		polar.update(home, 0.25)
		desert.update(home, 0.25)
	expect(desert.applied == 0.0 and polar.applied == 0.0 and not environment.adjustment_enabled, "both looks fade out")
	expect(environment.fog_light_color.is_equal_approx(before.fog) and is_equal_approx(environment.fog_depth_end, before.end), "fog restored")
	expect((polar.sky_material.get_shader_parameter("horizon_color") as Color).is_equal_approx(before.horizon), "sky restored")
	expect((polar.ocean.ocean_material.get_shader_parameter("deep_color") as Color).is_equal_approx(before.deep), "sea restored")
	finish()

func finish() -> void:
	print("DESERT BIOME CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
