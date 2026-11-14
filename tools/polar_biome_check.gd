extends SceneTree
## Patch 2.5 item 3: the North Pole biome in the real game scene. Both polar
## ports are fully polar, the four strait ports not at all; the blend is smooth
## across the region edge and seamless across the wrap; in the polar sea the
## fog, sky, sea, grading and snow change, and sailing back out restores the
## temperate look exactly. The snow is one pooled emitter. Isolated save folder.
## Run: godot --headless --path . --script res://tools/polar_biome_check.gd

const FOLDER: String = "user://polar_biome_check"
const Progression = preload("res://features/game/progression.gd")
const Polar = preload("res://features/sky/polar_biome.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("POLAR BIOME FAILED: " + label)
	return condition

func run() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	# The region: polar ports in, strait ports out, smooth, no seam at the wrap.
	for entry: Dictionary in Progression.WORLD:
		var polar_port: bool = String(entry.id).ends_with("_pole")
		expect(is_equal_approx(Polar.weight(entry.at), 1.0 if polar_port else 0.0), "%s polar weight" % entry.id)
	for berg: Vector3 in Progression.ICEBERGS: expect(Polar.weight(Vector3(berg.x, 0, berg.z)) > 0.5, "iceberg at %s is in the polar look" % berg)
	var steepest: float = 0.0
	for step: int in 1400:
		var z: float = -7000.0 + step * 10.0
		steepest = maxf(steepest, absf(Polar.weight(Vector3(0, 0, z + 10.0)) - Polar.weight(Vector3(0, 0, z))))
	expect(steepest < 0.03, "the edge fades over hundreds of metres (max %.3f per 10 m)" % steepest)
	var edge: float = Progression.WRAP_CENTRE.z + Progression.WRAP_M / 2.0
	expect(absf(Polar.weight(Vector3(0, 0, edge - 1)) - Polar.weight(Vector3(0, 0, edge + 1))) < 0.001, "no seam across the wrap")
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
	var polar: Node = game.get("polar")
	if not expect(polar != null and polar.get_parent() == game, "the game has the polar biome"): return finish()
	var environment: Environment = polar.environment
	await process_frame
	expect(polar.applied == 0.0 and not polar.snow.emitting and not environment.adjustment_enabled, "a temperate start shows no polar look")
	var before: Dictionary = {"fog": environment.fog_light_color, "end": environment.fog_depth_end, "sun": polar.sun.light_color,
		"horizon": polar.sky_material.get_shader_parameter("horizon_color"), "deep": polar.ocean.ocean_material.get_shader_parameter("deep_color")}
	# Into the polar sea: an eased fade, not a snap.
	var north: Vector3 = Progression.WORLD[Progression.port_index("port_north_pole")].at
	polar.update(north, 0.25)
	expect(polar.applied > 0.1 and polar.applied < 0.3, "a jump into the polar sea fades in over time (%.2f)" % polar.applied)
	for frame: int in 12: polar.update(north, 0.25)
	expect(is_equal_approx(polar.applied, 1.0), "fully polar at the North Pole")
	expect(environment.fog_depth_end < before.end and environment.fog_light_color != before.fog, "a little fog")
	expect(polar.sun.light_color.b >= before.sun.b and polar.sun.light_color.r <= before.sun.r, "cooler light")
	var horizon: Color = polar.sky_material.get_shader_parameter("horizon_color")
	expect(horizon.get_luminance() > (before.horizon as Color).get_luminance(), "paler sky")
	var deep: Color = polar.ocean.ocean_material.get_shader_parameter("deep_color")
	expect(deep.get_luminance() > (before.deep as Color).get_luminance(), "paler sea")
	expect(environment.adjustment_enabled and environment.adjustment_saturation < 1.0 and environment.adjustment_color_correction != null, "cooler grading")
	expect(polar.snow.emitting and is_equal_approx(polar.snow.amount_ratio, 1.0), "snow is falling")
	expect(polar.snow.amount <= 1000 and polar.snow.process_material is ParticleProcessMaterial, "the snow is one pooled emitter")
	await process_frame
	var camera: Camera3D = game.camera.camera
	expect(polar.snow.global_position.distance_to(camera.global_position) < 60.0, "the snow falls around the camera")
	# Across the wrap the snow comes along.
	var at: Vector3 = polar.snow.global_position
	polar.shift(Vector3(0, 0, -Progression.WRAP_M))
	expect(polar.snow.global_position.is_equal_approx(at + Vector3(0, 0, -Progression.WRAP_M)) and polar.snow.emitting, "the snow wraps with the ship")
	# Back out: the temperate look returns exactly.
	var home: Vector3 = Progression.WORLD[0].at
	for frame: int in 16: polar.update(home, 0.25)
	expect(polar.applied == 0.0 and not polar.snow.emitting and not environment.adjustment_enabled, "the polar look fades out")
	expect(environment.fog_light_color.is_equal_approx(before.fog) and is_equal_approx(environment.fog_depth_end, before.end), "fog restored")
	expect((polar.sky_material.get_shader_parameter("horizon_color") as Color).is_equal_approx(before.horizon), "sky restored")
	expect((polar.ocean.ocean_material.get_shader_parameter("deep_color") as Color).is_equal_approx(before.deep), "sea restored")
	finish()

func finish() -> void:
	print("POLAR BIOME CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
