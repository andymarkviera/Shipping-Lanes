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
		await check_berth(port)
		var a: Dictionary = port.reserve_spawn(Vector3(13, 4, 64))
		var b: Dictionary = port.reserve_spawn(Vector3(13, 4, 64))
		var c: Dictionary = port.reserve_spawn(Vector3(13, 4, 64))
		verify(a.ok and a.index == 0 and b.ok and b.index == 1 and c.ok and c.index == 2, "Reservations allocate primary then ordered recovery spots without a physics tick")
		verify(not port.reserve_spawn(Vector3(13, 4, 64)).ok, "All held anchors refuse instead of overlapping")
		port.spawn_allocator.release(b.ticket)
		var retry: Dictionary = port.reserve_spawn(Vector3(13, 4, 64))
		verify(retry.ok and retry.index == 1, "Released slot reused deterministically")
		port.spawn_allocator.holds.clear()
		var cargo: Array[AABB] = [AABB(port.spawn_anchor.global_position - Vector3(15, 5, 40), Vector3(30, 20, 80))]
		var cargo_result: Dictionary = port.reserve_spawn(Vector3(13, 4, 64), cargo)
		verify(cargo_result.ok and cargo_result.index == 1, "Cargo envelope blocks primary even without a physics body")
		port.spawn_allocator.holds.clear()
		var berth_ticket: int = port.spawn_allocator.hold_volume(cargo[0])
		verify(berth_ticket > 0 and port.reserve_spawn(Vector3(13, 4, 64)).index == 1, "Reserved berth volume blocks overlapping spawn")
		port.spawn_allocator.holds.clear()
		var blocker: StaticBody3D = StaticBody3D.new()
		blocker.collision_layer = CollisionRules.HULL
		blocker.position = port.spawn_anchor.global_position
		CollisionRules.add_box_hull(blocker)
		add_child(blocker)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var hull_result: Dictionary = port.reserve_spawn(Vector3(13, 4, 64))
		verify(hull_result.ok and hull_result.index == 1, "Existing hull triggers recovery")
		port.spawn_allocator.holds.clear()
		blocker.collision_layer = CollisionRules.CARGO_VISUAL
		await get_tree().physics_frame
		verify(port.reserve_spawn(Vector3(13, 4, 64)).index == 1, "Physical cargo blocks spawn")
		port.spawn_allocator.holds.clear()
		blocker.free()
		var shore_pose: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(port.quay_side * 60, 1, 70))]
		verify(not port.spawn_allocator.reserve(get_world_3d().direct_space_state, shore_pose, Vector3(13, 4, 64)).ok, "Quay rejects spawn")
		verify(not port.reserve_spawn(Vector3(-1, 4, 64)).ok, "Invalid envelope fails closed")
		var far_pose: Array[Transform3D] = [Transform3D(Basis(Vector3.UP, PI / 2), Vector3(500, 0, -500))]
		verify(port.spawn_allocator.reserve(get_world_3d().direct_space_state, far_pose, Vector3(13, 4, 64)).ok, "Rotated hull accepted in open water without depth restrictions")
		port.spawn_allocator.holds.clear()
		port.position = Vector3(600, 0, 100)
		port.rotation.y = PI / 2
		await check_berth(port)
		var moved: Dictionary = port.reserve_spawn(Vector3(13, 4, 64))
		verify(moved.ok and moved.transform.origin.is_equal_approx(port.spawn_anchor.global_position), "Port transforms propagate to spawn candidates")
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
	preview.ship.global_transform = preview.port.berth_anchor.global_transform
	preview.ship.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	verify(preview.port.berth_readiness(preview.ship, "container_transfer", "cargo_test_container").eligible, "Actual preview ship is eligible without self-blocking")
	verify(preview.readiness.text.begins_with("Berth: Ready to dock"), "Live readiness feedback reaches ready state")
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

func check_berth(port: Node3D) -> void:
	var rule = preload("res://features/ports/berth_eligibility.gd")
	var definition: ShipDefinition = preload("res://features/catalog/records/starter_ship.tres").duplicate(true)
	var pose: Transform3D = port.berth_anchor.global_transform
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "container_transfer", "cargo_test_container", space).eligible, "Aligned stationary starter is eligible")
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3(0.16, 0, 0), "container_transfer", "cargo_test_container", space).code == "SPEED", "Sideways drift counts toward docking speed")
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3(0, 0, -0.16), "container_transfer", "cargo_test_container", space).code == "SPEED", "Reverse speed also prevents docking")
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3(0, 0, 0.15), "container_transfer", "cargo_test_container", space).eligible, "Speed threshold is inclusive")
	var backwards: Transform3D = pose * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	verify(rule.evaluate(port.berth, pose, definition, backwards, Vector3.ZERO, "container_transfer", "cargo_test_container", space).code == "HEADING", "Backward facing hull is not aligned")
	var angled: Transform3D = pose * Transform3D(Basis(Vector3.UP, deg_to_rad(9)), Vector3.ZERO)
	verify(rule.evaluate(port.berth, pose, definition, angled, Vector3.ZERO, "container_transfer", "cargo_test_container", space).eligible, "Small approach angle is tolerated")
	var outside: Transform3D = pose.translated_local(Vector3(10, 0, 0))
	verify(rule.evaluate(port.berth, pose, definition, outside, Vector3.ZERO, "container_transfer", "cargo_test_container", space).code == "POSITION", "Nearby center insufficient when whole hull does not fit")
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "unknown_service", "", space).code == "SERVICE", "Unsupported service rejected")
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "container_transfer", "cargo_test_industrial", space).code == "CARGO", "Ship cargo compatibility enforced")
	var heavy: ShipDefinition = preload("res://features/catalog/records/heavy_lifter.tres")
	var heavy_result: Dictionary = rule.evaluate(port.berth, pose, heavy, pose, Vector3.ZERO, "heavy_transfer", "cargo_test_industrial", space)
	verify(heavy_result.eligible == (port.definition.id == "port_slatewater_works"), "Heavy transfer only available at compatible port")
	definition.hull_size_m.x = 30
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "container_transfer", "", space).code == "SIZE", "Oversized hull rejected")
	definition.hull_size_m.x = 13
	var bad: BerthDefinition = port.berth.duplicate(true)
	bad.max_docking_speed_mps = NAN
	verify(rule.evaluate(bad, pose, definition, pose, Vector3.ZERO, "container_transfer", "", space).code == "INVALID_DATA", "Invalid threshold fails closed")
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = CollisionRules.HULL
	body.transform = pose
	CollisionRules.add_box_hull(body)
	add_child(body)
	await get_tree().physics_frame
	await get_tree().physics_frame
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "container_transfer", "", space).code == "BLOCKED", "Other hull prevents docking")
	var excluded: Array[RID] = [body.get_rid()]
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "container_transfer", "", space, excluded).eligible, "Own hull can be excluded from clearance query")
	body.collision_layer = CollisionRules.CARGO_VISUAL
	await get_tree().physics_frame
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "container_transfer", "", space).code == "BLOCKED", "Cargo obstruction prevents docking")
	body.free()
