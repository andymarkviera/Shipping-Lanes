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
	check_manifest()
	check_operations()
	check_offers()
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
	await check_docking(preview)
	check_loading(preview)
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

func check_docking(preview: Node3D) -> void:
	var authority = preview.docking
	authority.set_physics_process(false)
	var body: HandlingShip = preview.ship
	var position_before: Vector3 = body.global_position
	body.velocity = Vector3(0, 0, 1)
	verify(not authority.request_dock(1, "container_transfer", "cargo_test_container").ok and authority.reservations.is_empty(), "Fast approach does not reserve berth")
	body.velocity = Vector3.ZERO
	authority.advance(.01)
	verify(authority.state(1) == "approaching", "Near berth transitions to approaching")
	verify(authority.request_dock(1, "container_transfer", "cargo_test_container").ok, "Valid request reserves berth")
	verify(authority.state(1) == "docking" and body.docked, "Docking disables helm immediately")
	var other: HandlingShip = HandlingShip.new()
	other.position = Vector3(600, 0, 0)
	add_child(other)
	authority.register(2, other, preview.port)
	verify(not authority.request_dock(2, "container_transfer", "cargo_test_container").ok and authority.reservations.size() == 1, "Competing owner cannot acquire single-capacity berth")
	verify(not authority.request_dock(1, "container_transfer", "cargo_test_container").ok, "Repeated request cannot duplicate reservation")
	authority.advance(1.1)
	verify(authority.state(1) == "docked", "Securing completes to docked")
	body.command_throttle(1)
	body.maneuver(1, 1)
	body.velocity = Vector3(0, 0, 1)
	body.advance_motion(.1)
	verify(body.velocity == Vector3.ZERO and body.actual_throttle == 0, "Docked hull rejects propulsion and residual motion")
	verify(authority.request_undock(1) and authority.state(1) == "undocking", "Undocking starts while reservation is retained")
	verify(authority.cancel(1) and authority.state(1) == "docked" and authority.reservations.size() == 1, "Cancel undocking keeps berth safely held")
	authority.request_undock(1)
	authority.advance(.6)
	verify(authority.state(1) == "underway" and not body.docked and authority.reservations.is_empty() and body.global_position == position_before, "Undocking releases berth without teleporting hull")
	authority.request_dock(1, "container_transfer", "cargo_test_container")
	verify(authority.cancel(1) and not body.docked and authority.reservations.is_empty(), "Cancelled docking releases reservation and helm")
	authority.request_dock(1, "container_transfer", "cargo_test_container")
	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.collision_layer = CollisionRules.SHORE
	obstacle.transform = body.global_transform
	CollisionRules.add_box_hull(obstacle)
	add_child(obstacle)
	await get_tree().physics_frame
	await get_tree().physics_frame
	authority.advance(.1)
	verify(authority.state(1) == "underway" and authority.reservations.is_empty() and not body.docked, "New obstruction cancels docking and releases reservation")
	obstacle.free()
	await get_tree().physics_frame
	authority.request_dock(1, "container_transfer", "cargo_test_container")
	authority.disconnect_owner(1)
	verify(authority.reservations.is_empty() and not body.docked and not authority.members.has(1), "Disconnect releases held berth and ship")
	authority.disconnect_owner(2)
	other.free()
	authority.register(1, body, preview.port)
	authority.set_physics_process(true)

func check_manifest() -> void:
	var manifest_script = preload("res://features/cargo/cargo_manifest.gd")
	var ship: ShipDefinition = preload("res://features/catalog/records/starter_ship.tres").duplicate(true)
	var manifest = manifest_script.new(ship, PrototypeCatalog.RECORDS)
	var row: Dictionary = {"batch_id": "lot_1", "cargo_id": "cargo_test_container", "quantity": 4, "unit": "count", "origin_port_id": "port_brindle_quay", "destination_port_id": "port_slatewater_works", "acquisition_id": "purchase_1", "job_id": ""}
	verify(manifest.add(row).ok, "Compatible cargo batch accepted")
	row.quantity = 999
	verify(manifest.lines()[0].quantity == 4, "Caller cannot mutate accepted batch")
	var view: Array[Dictionary] = manifest.lines()
	view[0].quantity = 0
	verify(manifest.lines()[0].quantity == 4, "Manifest read is defensive")
	var second: Dictionary = manifest.lines()[0].duplicate(true)
	second.batch_id = "lot_2"
	second.quantity = 2
	second.job_id = "job_2"
	second.acquisition_id = ""
	verify(manifest.add(second).ok and manifest.usage().container_slots == 6, "Multiple jobs share aggregate capacity and exact limit is allowed")
	var original: Array[Dictionary] = manifest.lines()
	for change: Dictionary in [{"quantity": 1, "batch_id": "overflow"}, {"cargo_id": "cargo_test_industrial", "batch_id": "wrong_ship"}, {"quantity": 0}, {"quantity": -1}, {"quantity": 1.5}, {"quantity": 1000000001}, {"unit": "gram"}, {"origin_port_id": "missing"}, {"destination_port_id": "missing"}, {"acquisition_id": "", "job_id": ""}, {"batch_id": "lot_1"}]:
		var bad: Dictionary = second.duplicate(true)
		bad.merge(change, true)
		verify(not manifest.add(bad).ok and manifest.lines() == original, "Invalid/oversized addition leaves all cargo unchanged")
	verify(not manifest.remove("lot_1", 99).ok and manifest.lines() == original, "Excessive removal is atomic")
	verify(manifest.remove("lot_1", 2).ok and manifest.lines()[0].quantity == 2 and manifest.lines()[0].acquisition_id == "purchase_1", "Partial removal retains batch provenance")
	verify(manifest.remove("lot_2", 2).ok and manifest.lines().size() == 1, "Full removal clears only selected job batch")
	var other = manifest_script.new(ship, PrototypeCatalog.RECORDS)
	verify(other.lines().is_empty(), "Manifest instances isolated per ship")
	var heavy = manifest_script.new(preload("res://features/catalog/records/heavy_lifter.tres"), PrototypeCatalog.RECORDS)
	var module: Dictionary = second.duplicate(true)
	module.cargo_id = "cargo_test_industrial"
	module.quantity = 1
	verify(heavy.add(module).ok and heavy.usage().heavy_slots == 1, "Heavy module uses its own capacity pool")
	var definitions: Array[ContentDefinition] = PrototypeCatalog.RECORDS.duplicate()
	var liquid: CargoDefinition = CargoDefinition.new()
	liquid.id = "cargo_liquid_fixture"
	liquid.quantity_unit = "milliliter"
	liquid.capacity_pool = "tank_ml"
	definitions.append(liquid)
	ship.cargo_type_ids.append(liquid.id)
	ship.cargo_capacities.tank_ml = 5000
	var mixed = manifest_script.new(ship, definitions)
	var container: Dictionary = second.duplicate(true)
	container.quantity = 6
	container.batch_id = "containers"
	var tank: Dictionary = second.duplicate(true)
	tank.batch_id = "tank"
	tank.cargo_id = liquid.id
	tank.unit = "milliliter"
	tank.quantity = 5000
	verify(mixed.add(container).ok and mixed.add(tank).ok, "Counts and liquid volume have independent budgets")
	tank.batch_id = "tank_overflow"
	tank.quantity = 1
	verify(not mixed.add(tank).ok and mixed.usage().tank_ml == 5000, "Liquid overcapacity leaves container and liquid amounts unchanged")

func check_operations() -> void:
	var service_script = preload("res://features/cargo/cargo_operation.gd")
	var manifest = preload("res://features/cargo/cargo_manifest.gd").new(preload("res://features/catalog/records/starter_ship.tres"), PrototypeCatalog.RECORDS)
	var rule = preload("res://features/cargo/manifest_operation_rule.gd").new("ship_a", manifest)
	var service = service_script.new()
	service.register_rule("containers", rule)
	var batch: Dictionary = {"batch_id": "op_batch", "cargo_id": "cargo_test_container", "quantity": 2, "unit": "count", "origin_port_id": "port_brindle_quay", "destination_port_id": "port_slatewater_works", "acquisition_id": "offer_1", "job_id": ""}
	var payload: Dictionary = {"action": "load", "batch": batch}
	verify(not service.start("missing") and not service.commit("missing").ok, "Missing operation cannot advance")
	verify(service.reserve("load_1", "ship_a", "containers", payload, 2).ok, "Loading reserves ship operation")
	verify(not service.reserve("load_2", "ship_a", "containers", payload, 2).ok, "Competing operation cannot reserve same ship")
	verify(not service.progress("load_1", 1) and not service.commit("load_1").ok and manifest.lines().is_empty(), "No progress or commit before start")
	verify(service.start("load_1") and not service.start("load_1"), "Start only once")
	verify(not service.progress("load_1", NAN) and not service.progress("load_1", -1), "Invalid time rejected")
	service.progress("load_1", .75)
	verify(not service.commit("load_1").ok and manifest.lines().is_empty(), "Partial progress has no cargo effect")
	var snapshot: Dictionary = bytes_to_var(var_to_bytes(service.snapshot()))
	var recovered = service_script.new()
	recovered.register_rule("containers", rule)
	verify(recovered.restore(snapshot) and recovered.record("load_1").elapsed == .75, "Pending operation reconstructed from data")
	snapshot.records.load_1.elapsed = 0
	verify(recovered.record("load_1").elapsed == .75, "Recovered record isolated from caller mutation")
	verify(not recovered.reserve("competitor", "ship_a", "containers", payload, 1).ok, "Restore reconstructs reservation")
	recovered.progress("load_1", 1.25)
	verify(recovered.record("load_1").state == "ready" and manifest.lines().is_empty(), "Progress reaches ready without animation or auto mutation")
	verify(recovered.commit("load_1").ok and manifest.lines()[0].quantity == 2, "Commit applies validated cargo exactly once")
	verify(recovered.commit("load_1").ok and recovered.releases == 1 and manifest.lines()[0].quantity == 2, "Commit retry returns receipt without duplicate effect/release")
	verify(not recovered.cancel("load_1"), "Terminal operation cannot cancel")
	var unload: Dictionary = {"action": "unload", "batch_id": "op_batch", "quantity": 1}
	verify(recovered.reserve("unload_1", "ship_a", "containers", unload, 1).ok, "Released reservation permits unload")
	recovered.start("unload_1")
	verify(recovered.cancel("unload_1") and not recovered.cancel("unload_1") and recovered.releases == 2 and manifest.lines()[0].quantity == 2, "Cancellation releases once without cargo effect")
	recovered.reserve("unload_2", "ship_a", "containers", unload, 1)
	recovered.start("unload_2")
	recovered.interrupt_ship("ship_a")
	verify(recovered.record("unload_2").state == "interrupted" and recovered.releases == 3, "Disconnect interruption releases operation")
	recovered.reserve("unload_3", "ship_a", "containers", unload, 1)
	recovered.start("unload_3")
	recovered.progress("unload_3", 1)
	manifest.remove("op_batch", 2)
	verify(not recovered.commit("unload_3").ok and recovered.record("unload_3").state == "failed" and recovered.releases == 4, "Completion revalidation rejects changed cargo and releases")
	var corrupt: Dictionary = service.snapshot()
	corrupt.records.load_1.elapsed = -1
	var fresh = service_script.new()
	fresh.register_rule("containers", rule)
	verify(not fresh.restore(corrupt) and fresh.snapshot().records.is_empty(), "Malformed recovery fails atomically")
	verify(not fresh.reserve("wrong", "ship_b", "containers", payload, 1).ok, "Manifest adapter rejects wrong ship")
	verify(fresh.reserve("final_load", "ship_a", "containers", payload, 1).ok, "New operation after failures remains usable")
	fresh.start("final_load")
	fresh.progress("final_load", 1)
	fresh.commit("final_load")
	fresh.reserve("final_unload", "ship_a", "containers", unload, 1)
	fresh.start("final_unload")
	fresh.progress("final_unload", 1)
	verify(fresh.commit("final_unload").ok and manifest.lines()[0].quantity == 1, "Successful unloading removes only requested quantity")

func check_offers() -> void:
	var source_script = preload("res://features/cargo/container_offers.gd")
	var source = source_script.new()
	var second_source = source_script.new()
	var manifest_script = preload("res://features/cargo/cargo_manifest.gd")
	var manifest = manifest_script.new(preload("res://features/catalog/records/starter_ship.tres"), PrototypeCatalog.RECORDS)
	var rows: Array[Dictionary] = source.list_at("port_brindle_quay")
	verify(rows.size() == 3 and rows == second_source.list_at("port_brindle_quay"), "Seeded offer IDs and designed quotes repeat deterministically")
	var id: String = rows[0].id
	rows[0].reward_minor = 1
	verify(source.view(id).reward_minor == 25000, "Offer terms cannot be changed through a read")
	verify(not source.accept(id, "captain_a", "ship_a", "port_slatewater_works", manifest).ok and source.view(id).state == "available", "Wrong origin rejects without taking offer")
	var heavy = manifest_script.new(preload("res://features/catalog/records/heavy_lifter.tres"), PrototypeCatalog.RECORDS)
	verify(not source.accept(id, "captain_a", "heavy", "port_brindle_quay", heavy).ok and source.view(id).state == "available", "Incompatible ship cannot accept container job")
	var accepted: Dictionary = source.accept(id, "captain_a", "ship_a", "port_brindle_quay", manifest)
	verify(accepted.ok and manifest.lines().is_empty(), "Acceptance locks offer without loading or paying")
	verify(not source.accept(id, "captain_b", "ship_b", "port_brindle_quay", manifest).ok, "Competing captain cannot accept exclusive offer")
	verify(source.accept(id, "captain_a", "ship_a", "port_brindle_quay", manifest).offer == accepted.offer, "Same-owner retry returns identical accepted terms")
	verify(not source.accept(id, "captain_a", "ship_other", "port_brindle_quay", manifest).ok, "Accepted offer cannot transfer to another ship")
	rows = source.list_at("port_brindle_quay")
	verify(source.accept(rows[1].id, "captain_a", "ship_a", "port_brindle_quay", manifest).ok and source.accept(rows[2].id, "captain_a", "ship_a", "port_brindle_quay", manifest).ok, "Pending accepted jobs fit exactly in aggregate capacity")
	var return_offer: String = source.list_at("port_slatewater_works")[0].id
	verify(not source.accept(return_offer, "captain_a", "ship_a", "port_slatewater_works", manifest).ok and source.view(return_offer).state == "available", "Capacity commitments reject excess acceptance atomically")
	verify(source.advance_to(600000) and source.view(return_offer).state == "expired", "Unaccepted offer expires at exact deadline")
	verify(source.view(id) == accepted.offer and source.accept(id, "captain_a", "ship_a", "port_brindle_quay", manifest).ok, "Accepted quote does not expire or change after deadline")
	verify(not source.advance_to(1), "Authority clock cannot rewind expiry")
	verify(not source.accept(return_offer, "captain_b", "ship_b", "port_slatewater_works", manifest).ok, "Expired offers cannot be accepted")

func check_loading(preview: Node3D) -> void:
	var loading = preview.loading
	var dock = preview.docking
	var body: HandlingShip = preview.ship
	var source = preview.offers
	var port_id: String = preview.port.definition.id
	var id: String = source.list_at(port_id)[0].id
	loading.set_physics_process(false)
	dock.set_physics_process(false)
	verify(source.accept(id, "preview_captain", "preview_ship", port_id, body.state.manifest).ok, "Loading fixture accepts source offer")
	verify(not loading.start(id) and body.state.manifest.lines().is_empty(), "Undocked loading is rejected without cargo")
	dock.request_dock(1, "container_transfer", "cargo_test_container")
	dock.advance(1.1)
	verify(loading.start(id) and not loading.start(id), "Docked start reserves once despite double click")
	loading.advance(2)
	verify(loading.busy() and loading.progress_percent() == 40 and body.state.manifest.lines().is_empty(), "Partial progress produces no free cargo")
	loading.cancel()
	verify(not loading.busy() and source.view(id).state == "available" and body.state.manifest.lines().is_empty(), "Cancel releases job and capacity with no partial load")
	source.accept(id, "preview_captain", "preview_ship", port_id, body.state.manifest)
	loading.start(id)
	preview.loading_text.hide()
	loading.advance(5)
	verify(not loading.busy() and source.view(id).state == "loaded" and body.state.manifest.lines()[0].quantity == 1, "Authority completes with presentation hidden")
	preview.loading_text.show()
	verify(not loading.start(id) and body.state.manifest.lines().size() == 1, "Loaded offer cannot create duplicate cargo")
	var second: String = source.list_at(port_id)[1].id
	verify(source.accept(second, "preview_captain", "preview_ship", port_id, body.state.manifest).ok, "Loaded commitment converted to actual cargo without double counting")
	loading.start(second)
	loading.advance(1)
	loading.disconnect_ship()
	verify(not loading.busy() and source.view(second).state == "available" and body.state.manifest.lines().size() == 1, "Disconnect releases pending job without touching completed cargo")
	source.accept(second, "preview_captain", "preview_ship", port_id, body.state.manifest)
	loading.start(second)
	dock.request_undock(1)
	loading.advance(.1)
	verify(not loading.busy() and source.view(second).state == "available", "Loss of docked authority interrupts loading")
	dock.cancel(1)
	loading.set_physics_process(true)
	dock.set_physics_process(true)
