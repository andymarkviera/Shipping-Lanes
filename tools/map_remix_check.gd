extends SceneTree
## Patch 3.0 B: every port's scenery uses a captain-relative horizon, including
## the skyline, lights and ink passes. Other ports remain fully beyond it from
## all berths/spawns, even if the camera is zoomed toward them. No simulation
## or map node is hidden. Run with software GL too for MultiMesh bounds.
const Progression = preload("res://features/game/progression.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("MAP REMIX FAILED: " + label)

func scenery(root_node: Node, found: Array[GeometryInstance3D]) -> void:
	if root_node is MeshInstance3D or root_node is MultiMeshInstance3D:
		found.append(root_node as GeometryInstance3D)
	for child: Node in root_node.get_children(): scenery(child, found)

func faded(paint: Material) -> bool:
	if not paint is ShaderMaterial: return false
	return bool((paint as ShaderMaterial).get_shader_parameter("port_distance_fade")) and (paint.next_pass == null or faded(paint.next_pass))

func run() -> void:
	set_meta("game_save_path", "user://map_remix_check/voyage.json")
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node
	for frame: int in 1200:
		await process_frame
		if current_scene != null and current_scene.is_node_ready() and current_scene.get("ship") != null:
			game = current_scene
			break
	if game == null:
		expect(false, "game opened")
		quit(1)
		return
	await physics_frame
	var groups: Array = []
	for port: Node3D in game.world_ports:
		var meshes: Array[GeometryInstance3D] = []
		scenery(port, meshes)
		if port.definition.id == "port_slatewater_works": scenery(game.get_node("CityLand"), meshes)
		groups.append(meshes)
		for mesh: GeometryInstance3D in meshes:
			if not mesh.is_visible_in_tree(): continue
			if mesh.material_override != null:
				expect(faded(mesh.material_override), "%s horizon paint" % mesh.get_path())
			elif mesh is MeshInstance3D:
				for surface: int in (mesh as MeshInstance3D).mesh.get_surface_count():
					expect(faded((mesh as MeshInstance3D).get_active_material(surface)), "%s surface horizon" % mesh.get_path())
			else: expect(false, "%s MultiMesh horizon" % mesh.get_path())
	var nearest: float = INF
	for origin: int in game.world_ports.size():
		var port: Node3D = game.world_ports[origin]
		var anchors: Array = port.berth_anchors.duplicate()
		anchors.append(port.spawn_anchor)
		anchors.append_array(port.recovery_anchors)
		for target: int in groups.size():
			if target == origin: continue
			var pair_gap: float = INF
			for anchor: Node3D in anchors:
				for mesh: GeometryInstance3D in groups[target]:
					if not mesh.is_visible_in_tree(): continue
					# Dummy renderer cannot read back a MultiMesh's GPU bounds.
					if mesh is MultiMeshInstance3D and DisplayServer.get_name() == "headless": continue
					var bounds: AABB = mesh.global_transform * mesh.get_aabb()
					var offset: Vector3 = Progression.short_way(bounds.get_center() - anchor.global_position)
					var gap: Vector2 = Vector2(maxf(0.0, absf(offset.x) - bounds.size.x / 2 - 100), maxf(0.0, absf(offset.z) - bounds.size.z / 2))
					pair_gap = minf(pair_gap, gap.length())
			nearest = minf(nearest, pair_gap)
			expect(pair_gap >= 2200.0, "%s -> %s scenery %.0f m away" % [port.definition.id, game.world_ports[target].definition.id, pair_gap])
	print("MAP REMIX nearest foreign scenery %.0f m" % nearest)
	expect(not paused and game.ship.is_physics_processing(), "world and ship keep running")
	expect(game.world_ports.size() == 6 and game.cranes.ports.size() == 6, "all ports and crane banks retained")
	# Material copying must not disconnect day/night rain control or affect boats.
	for paint: ShaderMaterial in game.city_paint:
		expect(game.rain.windows.has(paint) and faded(paint), "rain drives the faded skyline material")
	if DisplayServer.get_name() != "headless" and "--capture-remix" in OS.get_cmdline_user_args():
		game.globe_map.toggle()
		for frame: int in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/remix_globe.png")
	print("MAP REMIX CHECK: %d checks, %d failed" % [checks, failures])
	quit(1 if failures else 0)
