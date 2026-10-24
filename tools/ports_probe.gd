extends Node3D
const Preview = preload("res://features/ports/port_test.tscn")
const Ports = preload("res://features/ports/port_test.gd")
var checks: int = 0
var failures: int = 0

func verify(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _ready() -> void:
	var registry: DefinitionRegistry = DefinitionRegistry.new()
	verify(registry.load_definitions(PrototypeCatalog.RECORDS).is_empty(), "Both ports publish with valid cargo/berth references")
	var ids: Array[String] = []
	for scene: PackedScene in Ports.PORTS:
		var port: Node3D = scene.instantiate()
		add_child(port)
		await get_tree().physics_frame
		await get_tree().physics_frame
		verify(not ids.has(port.definition.id), "Port IDs distinct")
		ids.append(port.definition.id)
		verify(port.berth.port_id == port.definition.id and port.definition.berth_ids == [port.berth.id], "Berth ownership consistent")
		verify(port.service_view().services.size() >= 2, "Services inspectable without economy")
		var view: Dictionary = port.service_view()
		view.services.clear()
		verify(port.definition.service_ids.size() >= 2, "Service view cannot mutate authored resource")
		verify(port.spawn_anchor.position == port.definition.spawn_position_m and port.berth_anchor.position == port.berth.position_m, "Anchors materialize from data")
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(13, 4, 64)
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = CollisionRules.SHORE
		var clear: bool = true
		for sample: int in 31:
			query.transform = Transform3D(Basis.IDENTITY, port.definition.spawn_position_m.lerp(port.berth.position_m, sample / 30.0) + Vector3(0, 1, 0))
			if not get_world_3d().direct_space_state.intersect_shape(query).is_empty(): clear = false
		verify(clear, "Starter envelope has an unobstructed spawn-to-berth approach")
		query.transform = Transform3D(Basis.IDENTITY, Vector3(port.quay_side * 60, 1, port.quay_length_m / 2))
		verify(not get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "Visible quay is solid")
		port.queue_free()
		await get_tree().process_frame
	var preview: Node3D = Preview.instantiate()
	add_child(preview)
	verify(preview.port.definition.id == ids[0], "Preview opens first port")
	preview.ship.command_throttle(1)
	preview.select_port(1)
	await get_tree().process_frame
	verify(preview.port.definition.id == ids[1] and preview.ship.commanded_throttle == 0, "Switching ports resets only disposable test boat")
	verify(preview.ship.position.distance_to(preview.port.definition.spawn_position_m) < .1, "Preview starts at data-defined anchor")
	var capture: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--port-capture="): capture = arg.trim_prefix("--port-capture=")
	if not capture.is_empty():
		for i: int in 2:
			preview.select_port(i)
			preview.camera.set_process(false)
			preview.camera.set_physics_process(false)
			preview.camera.camera.global_position = Vector3(220, 190, -250)
			preview.camera.camera.look_at(Vector3(0, 0, 35))
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			verify(get_viewport().get_texture().get_image().save_png(capture + "-" + str(i) + ".png") == OK, "Port overview captured")
		preview.queue_free()
		await get_tree().process_frame
		var layer: CanvasLayer = CanvasLayer.new()
		add_child(layer)
		var menu: ApplicationMenu = ApplicationMenu.new()
		layer.add_child(menu)
		menu.show_page("title", false)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		verify(get_viewport().get_texture().get_image().save_png(capture + "-menu.png") == OK, "Menu captured")
	print("PORTS_%s checks=%d" % ["PASS" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
