extends SceneTree
## Patch 2.5 item 7: the volcano island in the real game scene. Ember Isle is
## one fixed spot in the land data, an island of its own, far from every port
## and sea-lane leg and the icebergs; every port still reaches every other by
## sea. It stands in the cold southern sea (fire and ice), outside the desert,
## tropics and city. In the game it has a toon cone, one pooled smoke emitter, lava
## that glows brighter (and lights up) at night only, and it is solid. Far off,
## the plume and light switch off. Isolated save folder.
## Run: godot --headless --path . --script res://tools/volcano_check.gd

const FOLDER: String = "user://volcano_check"
const Progression = preload("res://features/game/progression.gd")
const Look = preload("res://features/toon/volcano_look.gd")
const Desert = preload("res://features/sky/desert_biome.gd")
const Tropical = preload("res://features/sky/tropical_biome.gd")
const Rain = preload("res://features/sky/rain_biome.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("VOLCANO FAILED: " + label)
	return condition

## Shortest distance from `p` to the leg a-b, the short way round the world.
func leg_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var step: Vector3 = Progression.short_way(Vector3(b.x - a.x, 0, b.y - a.y))
	var to: Vector2 = a + Vector2(step.x, step.z)
	var way: Vector3 = Progression.short_way(Vector3(p.x - a.x, 0, p.y - a.y))
	var near: Vector2 = a + Vector2(way.x, way.z)
	return Geometry2D.get_closest_point_to_segment(near, a, to).distance_to(near)

func run() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	# The layout: one fixed island of its own, away from ports and lanes.
	var spec: Dictionary = Progression.VOLCANO
	var at: Vector2 = spec.at
	# Patch 2.9 item 6A: Ember Isle is natural land, many blocks; `land` is its
	# first (biggest) block and the island is all of them.
	var mass: Array = []
	for entry: Array in Progression.LANDMASSES:
		if entry[0] == spec.name: mass = entry
	expect(mass.size() == 3 and mass[1] == spec.land and mass[2] > spec.land, "Ember Isle is its own landmass in the land data")
	if mass.size() != 3: return finish()
	var island: Rect2 = Progression.LAND[spec.land]
	for index: int in range(mass[1], mass[2]): island = island.merge(Progression.LAND[index])
	var on_isle: Callable = func(point: Vector2) -> bool:
		for index: int in range(mass[1], mass[2]):
			if Progression.LAND[index].has_point(point): return true
		return false
	expect(on_isle.call(at) and Progression.land_depth(at) >= spec.base_m * 0.62, "the volcano stands on Ember Isle")
	expect(on_isle.call(at + Vector2(spec.base_m * 0.62, 0)) and on_isle.call(at - Vector2(spec.base_m * 0.62, 0)) and on_isle.call(at + Vector2(0, spec.base_m * 0.62)) and on_isle.call(at - Vector2(0, spec.base_m * 0.62)), "the cone's solid foot is on the island")
	var alone: bool = true
	for index: int in Progression.LAND.size():
		if (index < mass[1] or index >= mass[2]) and Progression.LAND[index].intersects(island.grow(400)): alone = false
	for block: Rect2 in Progression.ICE_SHELVES:
		if block.intersects(island.grow(400)): alone = false
	expect(alone, "open sea all round Ember Isle")
	var port_gap: float = 1.0e9
	for entry: Dictionary in Progression.WORLD:
		var way: Vector3 = Progression.short_way(entry.at - Vector3(at.x, 0, at.y))
		port_gap = minf(port_gap, Vector2(way.x, way.z).length())
	expect(port_gap > 2500.0, "far from every port (%.0f m)" % port_gap)
	var lane_gap: float = 1.0e9
	for point: Vector2 in Progression.SEA_LANES: lane_gap = minf(lane_gap, at.distance_to(point))
	var reach: bool = true
	for a: int in Progression.WORLD.size():
		for b: int in Progression.WORLD.size():
			if a == b: continue
			var route: Array[Vector3] = Progression.sea_route(Progression.gate(a), Progression.gate(b))
			reach = reach and not route.is_empty()
			var from: Vector3 = Progression.gate(a)
			for corner: Vector3 in route:
				lane_gap = minf(lane_gap, leg_distance(at, Vector2(from.x, from.z), Vector2(corner.x, corner.z)))
				from = corner
	expect(reach, "every port still reaches every other by sea")
	expect(lane_gap > 1000.0, "well off every sea lane (%.0f m)" % lane_gap)
	var where: Vector3 = Vector3(at.x, 0, at.y)
	# Fire and ice: it stands in the cold southern sea, never in the desert,
	# tropics or city rain.
	expect(Desert.weight(where) == 0.0 and Tropical.weight(where) == 0.0 and Rain.weight(where) == 0.0, "outside the desert, tropics and city")
	var berg_gap: float = 1.0e9
	for berg: Vector3 in Progression.ICEBERGS: berg_gap = minf(berg_gap, at.distance_to(Vector2(berg.x, berg.z)) - berg.y)
	expect(berg_gap > 600.0, "clear of the icebergs (%.0f m)" % berg_gap)
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
	var volcano: Node3D = game.get("volcano")
	if not expect(volcano != null and volcano.get_parent() == game, "the game has the volcano"): return finish()
	expect(Vector2(volcano.global_position.x, volcano.global_position.z).is_equal_approx(at), "the volcano is at its fixed spot")
	expect(volcano.get_node_or_null("Cone") != null and volcano.get_node_or_null("Skirt") != null and volcano.get_node_or_null("Lava") != null, "a toon cone with a lava crater")
	var cone: MeshInstance3D = volcano.get_node("Cone")
	expect(cone.get_active_material(0) is ShaderMaterial, "the cone wears the toon paint")
	expect(volcano.find_children("*", "GPUParticles3D", true, false).size() == 1 and volcano.smoke.amount == Look.PUFFS, "one pooled smoke emitter")
	# Solid: a ray across the sea at the waterline hits the island's shore.
	for frame: int in 3: await physics_frame
	var space: PhysicsDirectSpaceState3D = (volcano as Node3D).get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(at.x - 600, 1, at.y), Vector3(at.x, 1, at.y), CollisionRules.SHORE)
	expect(not space.intersect_ray(query).is_empty(), "Ember Isle is solid at the waterline")
	query = PhysicsRayQueryParameters3D.create(Vector3(at.x - 600, 60, at.y), Vector3(at.x, 60, at.y), CollisionRules.SHORE)
	expect(not space.intersect_ray(query).is_empty(), "the cone is solid")
	var sun: DirectionalLight3D = game.polar.sun
	var camera: Camera3D = game.camera.camera
	var close: Vector3 = Vector3(at.x - 800, 30, at.y)
	# Day, close by: smoke rises, lava a soft glow, no glow light.
	volcano.update(close, sun)
	expect(volcano.night == 0.0 and volcano.smoke.emitting and not volcano.glow.visible, "by day: smoke, no glow light")
	expect(is_equal_approx(volcano.lava.emission_energy_multiplier, Look.GLOW_DAY), "by day the lava glows softly")
	# Night: the sun below the horizon.
	var day: Basis = sun.global_transform.basis
	sun.rotation_degrees = Vector3(10, -30, 0)
	volcano.update(close, sun)
	expect(is_equal_approx(volcano.night, 1.0) and volcano.glow.visible and volcano.glow.light_energy > 1.0, "at night the lava lights up")
	expect(is_equal_approx(volcano.lava.emission_energy_multiplier, Look.GLOW_NIGHT), "at night the lava glows bright")
	# Far away: the plume and light switch off.
	volcano.update(Progression.WORLD[0].at, sun)
	expect(not volcano.smoke.emitting and not volcano.smoke.visible and not volcano.glow.visible, "far off the plume and glow light are culled")
	sun.global_transform.basis = day
	volcano.update(close, sun)
	expect(volcano.night == 0.0 and volcano.smoke.emitting and not volcano.glow.visible, "back to day")
	# A frame of the real game loop with the volcano in it.
	await process_frame
	expect(camera != null, "the game camera is there")
	finish()

func finish() -> void:
	print("VOLCANO CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
