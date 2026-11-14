extends SceneTree
## Patch 2.5 item 4: the Desert biome in the real game scene. Cinder Point is
## fully desert, every other port not at all; the blend is smooth; the desert
## land is sand with dunes and mesas on the hilltop, clear of ports, bridges
## and water; Cinder Point has its desert dressing with the berth untouched;
## sailing in warms the fog, sky, sea and grade, sailing out restores the
## temperate look exactly, and the polar look still wins in the polar sea.
## Isolated save folder.
## Run: godot --headless --path . --script res://tools/desert_biome_check.gd

const FOLDER: String = "user://desert_biome_check"
const Progression = preload("res://features/game/progression.gd")
const Desert = preload("res://features/sky/desert_biome.gd")
const Polar = preload("res://features/sky/polar_biome.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
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
	# The region: Cinder Point in, every other port out, smooth, no wrap seam.
	for entry: Dictionary in Progression.WORLD:
		expect(is_equal_approx(Desert.weight(entry.at), 1.0 if entry.id == "port_cinder_point" else 0.0), "%s desert weight" % entry.id)
	for bridge: Dictionary in Progression.BRIDGES:
		expect(Desert.weight(Vector3(bridge.at.x, 0, bridge.at.y)) == 0.0, "%s is outside the desert" % bridge.id)
	var steepest: float = 0.0
	for step: int in 800:
		var x: float = -1500.0 + step * 10.0
		steepest = maxf(steepest, absf(Desert.weight(Vector3(x + 10.0, 0, 2000)) - Desert.weight(Vector3(x, 0, 2000))))
	expect(steepest < 0.03, "the edge fades over hundreds of metres (max %.3f per 10 m)" % steepest)
	expect(Desert.weight(Desert.CENTRE + Vector3(Progression.WRAP_M, 0, 0)) == 1.0, "the desert repeats across the wrap")
	var sandy: int = 0
	for rect: Rect2 in Progression.LAND: if Desert.desert_land(rect): sandy += 1
	expect(sandy >= 3, "several land blocks are desert (%d)" % sandy)
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
	if not expect(desert != null and desert.get_parent() == game and polar != null, "the game has the desert biome"): return finish()
	# Dunes and mesas: four baked meshes, every piece on desert hilltop.
	var dressing: Node3D = game.get_node_or_null("DesertDressing") as Node3D
	if not expect(dressing != null, "the desert land is dressed"): return finish()
	for label: String in ["Dunes", "Mesas", "MesaBands", "MesaCaps"]:
		var part: MeshInstance3D = dressing.get_node_or_null(label) as MeshInstance3D
		if not expect(part != null and part.mesh != null and int(part.get_meta("pieces", 0)) > 0, "%s are there" % label): continue
		expect(part.get_active_material(0) is ShaderMaterial and (part.get_active_material(0) as ShaderMaterial).next_pass != null, "%s are toon shaded and inked" % label)
	var places: Array = Desert.placements()
	var dunes: Array[Transform3D] = places[0]
	var mesas: Array[Transform3D] = places[1]
	expect(int(dressing.get_node("Dunes").get_meta("pieces")) == dunes.size() and int(dressing.get_node("Mesas").get_meta("pieces")) == mesas.size(), "the meshes hold every placement")
	expect(dunes.size() >= 60 and mesas.size() >= 5, "plenty of dunes (%d) and some mesas (%d)" % [dunes.size(), mesas.size()])
	expect(dressing.get_child_count() == 4, "the whole desert is four draw groups")
	var misplaced: int = 0
	for group: Array[Transform3D] in [dunes, mesas]:
		for place: Transform3D in group:
			var at: Vector3 = place.origin
			var on_land: bool = false
			for rect: Rect2 in Progression.LAND:
				if Desert.desert_land(rect) and rect.grow(-TOON_COAST.HILL_TOP_M).has_point(Vector2(at.x, at.z)): on_land = true
			if not on_land or Desert.near_works(at) or absf(at.y - TOON_COAST.HILL_TOP_Y) > 1.0: misplaced += 1
	expect(misplaced == 0, "every dune and mesa sits on the desert hilltop, clear of ports and bridges (%d not)" % misplaced)
	# Sand land in the desert, green land elsewhere.
	var paint: Dictionary = game.get("land_paint")
	expect(paint.has("desert1") and paint.has("land1") and (paint.desert1 as Material) != (paint.land1 as Material), "desert land has its own sandy top")
	# Cinder Point: desert dressing, same berth.
	var cinder: Node3D = game.world_ports[Progression.port_index("port_cinder_point")]
	var town: Node3D = cinder.get_node_or_null("DesertPort") as Node3D
	expect(town != null and town.get_child_count() > 20, "Cinder Point has its desert dressing")
	expect(cinder.definition.id == "port_cinder_point" and cinder.berth.port_id == "port_cinder_point", "Cinder Point keeps its ID and berth")
	var solid: int = 0
	for node: Node in town.find_children("*", "CollisionObject3D", true, false): solid += 1
	expect(solid == 0, "the desert dressing adds no colliders")
	var on_quay: int = 0
	for node: Node in town.get_children():
		if absf((node as Node3D).position.x) < 100.0: on_quay += 1
	expect(on_quay == 0, "the dressing keeps off the quay and its cranes")
	for index: int in game.world_ports.size():
		if index != Progression.port_index("port_cinder_point"):
			expect(game.world_ports[index].get_node_or_null("DesertPort") == null, "%s has no desert dressing" % Progression.WORLD[index].id)
	# The look.
	var environment: Environment = polar.environment
	await process_frame
	expect(desert.applied == 0.0 and polar.applied == 0.0 and not environment.adjustment_enabled, "a temperate start shows no desert look")
	var before: Dictionary = {"fog": environment.fog_light_color, "end": environment.fog_depth_end, "sun": polar.sun.light_color,
		"horizon": polar.sky_material.get_shader_parameter("horizon_color"), "deep": polar.ocean.ocean_material.get_shader_parameter("deep_color"),
		"cover": polar.sky_material.get_shader_parameter("cloud_cover")}
	var cinder_at: Vector3 = Progression.WORLD[Progression.port_index("port_cinder_point")].at
	desert.update(cinder_at, 0.25)
	expect(desert.applied > 0.1 and desert.applied < 0.3, "a jump into the desert fades in over time (%.2f)" % desert.applied)
	for frame: int in 12: desert.update(cinder_at, 0.25)
	polar.update(cinder_at, 0.25)
	expect(is_equal_approx(desert.applied, 1.0) and polar.applied == 0.0, "fully desert at Cinder Point")
	var fog: Color = environment.fog_light_color
	expect(fog.r > fog.b + 0.2 and environment.fog_depth_end < before.end, "a warm haze")
	expect(polar.sun.light_color.r >= polar.sun.light_color.b + 0.2, "warm sunlight")
	var horizon: Color = polar.sky_material.get_shader_parameter("horizon_color")
	expect(horizon.r > horizon.b and horizon.r > (before.horizon as Color).r - 0.01, "a warm pale horizon")
	expect(float(polar.sky_material.get_shader_parameter("cloud_cover")) < float(before.cover), "fewer clouds")
	expect(environment.adjustment_enabled and environment.adjustment_saturation < 1.0 and environment.adjustment_saturation > 0.82, "a dry warm grade")
	var ramp: Gradient = (environment.adjustment_color_correction as GradientTexture1D).gradient
	expect(ramp.get_color(1).b < ramp.get_color(1).r and ramp.get_color(0).r > 0.0, "the grade is warm")
	expect(not polar.snow.emitting, "no snow in the desert")
	# The polar look still wins on top of it (they meet near the north edge).
	polar.update(Progression.WORLD[Progression.port_index("port_north_pole")].at, 10.0)
	expect(is_equal_approx(polar.applied, 1.0) and environment.fog_light_color.is_equal_approx(Polar.POLAR_FOG), "the polar look covers the desert one")
	expect(is_equal_approx(environment.adjustment_saturation, 0.82), "polar grading over the desert")
	polar.update(cinder_at, 10.0)
	expect(environment.fog_light_color.is_equal_approx(fog), "the desert shows again under a faded polar look")
	# Back out: the temperate look returns exactly.
	var home: Vector3 = Progression.WORLD[0].at
	for frame: int in 16: desert.update(home, 0.25)
	polar.update(home, 0.25)
	expect(desert.applied == 0.0 and not environment.adjustment_enabled, "the desert look fades out")
	expect(environment.fog_light_color.is_equal_approx(before.fog) and is_equal_approx(environment.fog_depth_end, before.end), "fog restored")
	expect(polar.sun.light_color.is_equal_approx(before.sun), "sun restored")
	expect((polar.sky_material.get_shader_parameter("horizon_color") as Color).is_equal_approx(before.horizon), "sky restored")
	expect((polar.ocean.ocean_material.get_shader_parameter("deep_color") as Color).is_equal_approx(before.deep), "sea restored")
	finish()

func finish() -> void:
	print("DESERT BIOME CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
