extends Node3D
const Preview = preload("res://features/ports/port_test.tscn")
const Ports = preload("res://features/ports/port_test.gd")
const DockingAuthorityScript = preload("res://features/ports/docking_authority.gd")
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
	check_delivery_rules()
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
	await check_berth_detection()
	var preview: Node3D = Preview.instantiate()
	# Never open the player's voyage save from a probe, with or without --ports-check.
	preview.save_enabled = false
	add_child(preview)
	verify(preview.port.definition.id == ids[0], "Preview opens first port")
	preview.ship.command_throttle(1)
	preview.select_port(1)
	await get_tree().process_frame
	verify(preview.port.definition.id == ids[1] and preview.ship.commanded_throttle == 0, "Switching ports resets only disposable test boat")
	verify(preview.ship.global_position.distance_to(preview.port.spawn_anchor.global_position) < .1, "Preview starts at data-defined anchor")
	check_restart(preview)
	check_container_visuals(preview)
	preview.ship.global_transform = preview.port.berth_anchor.global_transform
	preview.ship.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	verify(preview.port.berth_readiness(preview.ship, "container_transfer", "cargo_test_container").eligible, "Actual preview ship is eligible without self-blocking")
	verify(preview.readiness.text.begins_with("Berth: Ready to dock"), "Live readiness feedback reaches ready state")
	await check_docking(preview)
	await check_berths(preview)
	check_loading(preview)
	await check_services(preview)
	var capture: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--port-capture="): capture = arg.trim_prefix("--port-capture=")
	if not capture.is_empty():
		for i: int in 2:
			preview.select_port(i)
			preview.ship.global_transform = preview.port.berth_anchor.global_transform
			preview.docking.request_dock(1, "container_transfer", "cargo_test_container")
			preview.docking.advance(1.1)
			preview.jobs_panel.show()
			preview.refresh_jobs()
			preview.camera.set_process(false)
			preview.camera.set_physics_process(false)
			preview.camera.camera.global_position = preview.port.global_position + Vector3(220, 190, -250)
			preview.camera.camera.look_at(preview.port.global_position + Vector3(0, 0, 35))
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			verify(get_viewport().get_texture().get_image().save_png(capture + "-" + str(i) + ".png") == OK, "Port overview captured")
		preview.accept_selected()
		preview.loading.advance(2)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		verify(get_viewport().get_texture().get_image().save_png(capture + "-voyage-loading.png") == OK, "Pending voyage HUD captured")
		preview.loading.advance(20)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		verify(get_viewport().get_texture().get_image().save_png(capture + "-voyage-loaded.png") == OK, "Loaded voyage HUD captured")
		preview.end_current_job(true)
		preview.heavy_mode = true
		preview.select_port(1)
		await get_tree().physics_frame
		await get_tree().physics_frame
		preview.ship.global_transform = preview.port.berth_anchor.global_transform
		preview.docking.request_dock(1, "heavy_transfer", "cargo_test_industrial")
		preview.docking.advance(1.1)
		preview.jobs_panel.show()
		preview.refresh_jobs()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		verify(get_viewport().get_texture().get_image().save_png(capture + "-heavy-services.png") == OK, "Heavy service menu captured")
		await capture_containers(preview, capture)
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

## Patch 2.4 item 3: every port fits three of the biggest ships, and each docked
## hull lies a fender gap off the quay that grows with its beam.
func check_port_size(port: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var rule = preload("res://features/ports/berth_eligibility.gd")
	var name_: String = port.definition.display_name
	var biggest: float = 0.0
	var last_gap: float = 0.0
	var last_beam: float = 0.0
	var hulls: Array[ShipDefinition] = []
	for path: String in ["starter_ship", "bulk_01_ship", "container_02_ship", "heavy_lifter", "container_03_ship", "heavy_03_ship", "container_04_ship", "bulk_05_ship", "container_05_ship", "heavy_05_ship"]:
		hulls.append(load("res://features/catalog/records/%s.tres" % path))
	hulls.sort_custom(func(a: ShipDefinition, b: ShipDefinition) -> bool: return a.hull_size_m.x < b.hull_size_m.x)
	for hull: ShipDefinition in hulls:
		biggest = maxf(biggest, hull.hull_size_m.z)
		var offset: float = port.quay_offset_m(hull)
		var gap: float = port.QUAY_FACE_M - (port.quay_side * offset + hull.hull_size_m.x / 2)
		verify(gap >= 1.2 - .001 and gap <= 3.0 + .001 and (hull.hull_size_m.x <= last_beam or gap >= last_gap - .001), "%s: %s docks %.1f m off the quay" % [name_, hull.id, gap])
		last_gap = gap
		last_beam = hull.hull_size_m.x
		for index: int in port.berth_anchors.size():
			var target: Transform3D = rule.berth_pose(port.berth_anchors[index].global_transform, port.berth_anchors[index].global_transform, offset)
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = hull.hull_size_m
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = target.translated_local(Vector3(0, 1, 0))
			query.collision_mask = CollisionRules.SHORE
			query.margin = 0
			verify(space.intersect_shape(query, 1).is_empty(), "%s berth %d: %s docks clear of the quay" % [name_, index + 1, hull.id])
	verify(port.BERTH_SPACING_M >= biggest + 2 * port.berth.clearance_margin_m + 5 and port.berth.envelope_m.z >= biggest + 2 * port.berth.clearance_margin_m, "%s: three of the biggest ships (%.0f m) fit end to end" % [name_, biggest])
	var quay_end: float = maxf(port.quay_length_m, port.berth_anchors[-1].position.z + 140.0)
	verify(quay_end >= port.berth_anchors[-1].position.z + biggest / 2, "%s: the quay runs the length of the last berth" % name_)

## Patch 3.1.1: every berth of every port detects a docked or arriving ship of
## every hull size. The berth box covers the whole mooring footprint, the berth
## counts as nearest, the ship reads "approaching", and Dock picks that berth.
func check_berth_detection() -> void:
	var rule = preload("res://features/ports/berth_eligibility.gd")
	var hulls: Array[ShipDefinition] = preload("res://features/catalog/fleet_inspection.gd").definitions()
	verify(hulls.size() >= 10, "Every hull in the catalog is checked (%d)" % hulls.size())
	var scenes: Array[PackedScene] = []
	scenes.append_array(Ports.PORTS)
	scenes.append_array(Ports.GAME_PORTS)
	var place: int = 0
	for scene: PackedScene in scenes:
		place += 1
		var port: Node3D = scene.instantiate()
		port.position = Vector3(4000 * place, 0, -3000)
		port.rotation.y = .4 * place
		add_child(port)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var name_: String = port.definition.display_name
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var service: String = port.berth.service_ids[0]
		var zone: AABB = AABB(-port.berth.envelope_m / 2, port.berth.envelope_m)
		for index: int in port.berth_anchors.size():
			var anchor: Transform3D = port.berth_anchors[index].global_transform
			var covered: bool = true
			var nearest: bool = true
			var arriving_ok: bool = true
			var failed: Array[String] = []
			for hull: ShipDefinition in hulls:
				var moored: Transform3D = rule.berth_pose(anchor, anchor, port.quay_offset_m(hull))
				var size: Vector3 = hull.hull_size_m + Vector3.ONE * port.berth.clearance_margin_m * 2
				var footprint: AABB = (anchor.affine_inverse() * moored.translated_local(Vector3(0, 1, 0))) * AABB(-size / 2, size)
				if not zone.encloses(footprint):
					covered = false
					failed.append(hull.id + " footprint")
				if port.nearest_berth(moored.origin) != index or port.berth_distance(moored.origin) >= DockingAuthorityScript.APPROACH_M:
					nearest = false
					failed.append(hull.id + " moored")
				# Arriving: off the quay and short of the berth, still slow.
				var arriving: Transform3D = anchor.translated_local(Vector3(-port.quay_side * (hull.hull_size_m.x + 25), 0, -40))
				var ready: Dictionary = rule.evaluate_easy(port.berth, anchor, hull, arriving, Vector3(0, 0, 1), service, "", space, [], port.quay_offset_m(hull))
				if port.nearest_berth(arriving.origin) != index or port.berth_distance(arriving.origin) >= DockingAuthorityScript.APPROACH_M or not ready.eligible:
					arriving_ok = false
					failed.append("%s arriving (%s)" % [hull.id, ready.code])
			verify(covered, "%s berth %d: the berth box covers every hull's mooring footprint %s" % [name_, index + 1, failed])
			verify(nearest, "%s berth %d: a moored ship of every hull is detected at this berth %s" % [name_, index + 1, failed])
			verify(arriving_ok, "%s berth %d: an arriving ship of every hull is detected and may dock %s" % [name_, index + 1, failed])
			# The authority itself: approaching, Dock takes this berth, docked here.
			var authority = DockingAuthorityScript.new()
			authority.set_physics_process(false)
			add_child(authority)
			var body: HandlingShip = HandlingShip.new()
			CollisionRules.add_box_hull(body, body.definition.hull_size_m)
			add_child(body)
			body.simulation_paused = true
			body.global_transform = anchor.translated_local(Vector3(-port.quay_side * 45, 0, -60))
			body.velocity = Vector3.ZERO
			await get_tree().physics_frame
			authority.register(1, body, port)
			authority.advance(.01)
			var pick: Dictionary = authority.pick_berth(1, service, "")
			verify(authority.state(1) == "approaching" and pick.index == index, "%s berth %d: the docking authority sees the ship approaching this berth (%s, picked %d)" % [name_, index + 1, authority.state(1), pick.index])
			verify(authority.request_dock(1, service, "").ok, "%s berth %d: Dock works" % [name_, index + 1])
			authority.advance(authority.MAX_SLIDE_SECONDS + .1)
			verify(authority.state(1) == "docked" and authority.members[1].berth_index == index and port.nearest_berth(body.global_position) == index, "%s berth %d: the ship docks and stays detected at this berth" % [name_, index + 1])
			authority.disconnect_owner(1)
			authority.free()
			body.free()
		port.queue_free()
		await get_tree().process_frame

func check_berth(port: Node3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
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
	var outside: Transform3D = pose.translated_local(Vector3(40, 0, 0))
	verify(rule.evaluate(port.berth, pose, definition, outside, Vector3.ZERO, "container_transfer", "cargo_test_container", space).code == "POSITION", "Nearby center insufficient when whole hull does not fit")
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "unknown_service", "", space).code == "SERVICE", "Unsupported service rejected")
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "container_transfer", "cargo_test_industrial", space).code == "CARGO", "Ship cargo compatibility enforced")
	var heavy: ShipDefinition = preload("res://features/catalog/records/heavy_lifter.tres")
	var heavy_result: Dictionary = rule.evaluate(port.berth, pose, heavy, pose, Vector3.ZERO, "heavy_transfer", "cargo_test_industrial", space)
	verify(heavy_result.eligible, "Both service ports support heavy-loader work")
	var forgiving: Transform3D = pose.translated_local(Vector3(-port.quay_side * 3, 0, 0))
	verify(rule.evaluate(port.berth, pose, heavy, forgiving, Vector3.ZERO, "heavy_transfer", "cargo_test_industrial", space).eligible, "Heavy loader docks three metres off centre")
	forgiving = pose * Transform3D(Basis(Vector3.UP, deg_to_rad(5)), Vector3.ZERO)
	verify(rule.evaluate(port.berth, pose, heavy, forgiving, Vector3.ZERO, "heavy_transfer", "cargo_test_industrial", space).eligible, "Heavy loader docks five degrees off heading")
	for hull: ShipDefinition in [definition, heavy]:
		var service: String = "heavy_transfer" if hull == heavy else "container_transfer"
		var cargo: String = "cargo_test_industrial" if hull == heavy else "cargo_test_container"
		var contact_x: float = port.quay_side * (20 - hull.hull_size_m.x / 2)
		var contact: Transform3D = pose.translated_local(Vector3(contact_x, 0, 0))
		verify(rule.evaluate(port.berth, pose, hull, contact, Vector3.ZERO, service, cargo, space).eligible, "Hull can dock at the quay surface: " + hull.id)
		contact.origin += pose.basis.x * port.quay_side * .25
		verify(rule.evaluate(port.berth, pose, hull, contact, Vector3.ZERO, service, cargo, space).code == "BLOCKED", "Hull penetrating the quay remains blocked: " + hull.id)
		var wide: Transform3D = pose.translated_local(Vector3(-port.quay_side * 15, 0, 35))
		verify(rule.evaluate(port.berth, pose, hull, wide, Vector3.ZERO, service, cargo, space).eligible, "Wider side and length approach is eligible: " + hull.id)
	# Patch 2.0 easy docking: near + slow, no angle rule, plain messages.
	var args: Array = ["container_transfer", "cargo_test_container", space]
	verify(rule.evaluate_easy(port.berth, pose, definition, backwards, Vector3.ZERO, args[0], args[1], args[2]).eligible, "Easy: backward facing hull can dock")
	var crooked: Transform3D = pose.translated_local(Vector3(-port.quay_side * 60, 0, -120)) * Transform3D(Basis(Vector3.UP, deg_to_rad(70)), Vector3.ZERO)
	verify(rule.evaluate_easy(port.berth, pose, definition, crooked, Vector3(0, 0, 2.5), args[0], args[1], args[2]).eligible, "Easy: crooked, off-centre and still moving slowly can dock")
	var in_quay: Transform3D = pose.translated_local(Vector3(port.quay_side * 16, 0, 0))
	verify(rule.evaluate_easy(port.berth, pose, definition, in_quay, Vector3.ZERO, args[0], args[1], args[2]).eligible, "Easy: a hull pressed on the quay can dock")
	var fast: Dictionary = rule.evaluate_easy(port.berth, pose, definition, pose, Vector3(0, 0, 3.5), args[0], args[1], args[2])
	verify(fast.code == "SPEED" and fast.message == "Slow down to dock.", "Easy: too fast says only what to do")
	var far: Dictionary = rule.evaluate_easy(port.berth, pose, definition, pose.translated_local(Vector3(-port.quay_side * 90, 0, 0)), Vector3.ZERO, args[0], args[1], args[2])
	verify(far.code == "POSITION" and far.message == "Sail closer to the berth to dock.", "Easy: too far says only what to do")
	verify(rule.evaluate_easy(port.berth, pose, definition, pose, Vector3.ZERO, "unknown_service", "", space).code == "SERVICE", "Easy: unsupported service rejected")
	var landing: Transform3D = rule.berth_pose(pose, crooked.translated(Vector3(0, 2, 0)))
	verify(landing.basis.is_equal_approx(pose.basis) and landing.origin.is_equal_approx(pose.origin + Vector3(0, 2, 0)), "Easy: slide ends on the berth centre and heading at the ship's height")
	check_port_size(port, space)
	definition.hull_size_m.x = 70
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
	verify(rule.evaluate_easy(port.berth, pose, definition, crooked, Vector3.ZERO, "container_transfer", "", space).code == "BLOCKED", "Easy: another hull in the berth prevents docking")
	body.collision_layer = CollisionRules.CARGO_VISUAL
	await get_tree().physics_frame
	verify(rule.evaluate(port.berth, pose, definition, pose, Vector3.ZERO, "container_transfer", "", space).code == "BLOCKED", "Cargo obstruction prevents docking")
	body.free()

func check_docking(preview: Node3D) -> void:
	var authority = preview.docking
	authority.set_physics_process(false)
	var body: HandlingShip = preview.ship
	var position_before: Vector3 = body.global_position
	body.velocity = Vector3(0, 0, 4)
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
	# Patch 2.4 item 3: docking moves the hull to its fender gap; undocking must not move it again.
	position_before = body.global_position
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
	# Keep the fixture still so physics depenetration cannot move it clear first.
	body.set_physics_process(false)
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
	body.set_physics_process(true)
	await get_tree().physics_frame
	authority.request_dock(1, "container_transfer", "cargo_test_container")
	authority.disconnect_owner(1)
	verify(authority.reservations.is_empty() and not body.docked and not authority.members.has(1), "Disconnect releases held berth and ship")
	authority.disconnect_owner(2)
	other.free()
	authority.register(1, body, preview.port)
	var old_pose: Transform3D = body.global_transform
	body.global_transform = preview.port.berth_anchor.global_transform.translated_local(Vector3(preview.port.quay_side * (20 - body.definition.hull_size_m.x / 2 - .03), 0, 0))
	verify(authority.request_dock(1, "container_transfer", "cargo_test_container").ok, "Actual ship can request docking right alongside quay")
	authority.advance(1.1)
	verify(authority.state(1) == "docked", "Alongside docking completes without an obstruction cancellation")
	authority.request_undock(1)
	authority.advance(.6)
	verify(body.helm_available(), "Alongside undocking restores helm")
	# Easy docking: Dock from a crooked, off-centre, slowly moving approach; the
	# authority slides and turns the ship into the berth by itself.
	# Patch 2.4 item 3: the slide ends a hull-scaled fender gap off the quay.
	var berth_pose: Transform3D = preview.port.berth_anchor.global_transform.translated_local(Vector3(preview.port.quay_offset_m(body.definition), 0, 0))
	var start: Transform3D = preview.port.berth_anchor.global_transform.translated_local(Vector3(-preview.port.quay_side * 55, 0, -100)) * Transform3D(Basis(Vector3.UP, deg_to_rad(120)), Vector3.ZERO)
	body.global_transform = start
	body.velocity = start.basis.z * 2.0
	verify(preview.port.dock_readiness(body, "container_transfer", "cargo_test_container").eligible and not preview.port.berth_readiness(body, "container_transfer", "cargo_test_container").eligible, "Easy rule accepts an approach the old strict rule refused")
	verify(authority.request_dock(1, "container_transfer", "cargo_test_container").ok and body.docked and body.velocity == Vector3.ZERO, "Dock from a crooked slow approach takes the helm")
	var last: float = start.origin.distance_to(berth_pose.origin)
	var smooth: bool = true
	var ticks: int = 0
	while authority.state(1) == "docking" and ticks < 600:
		authority.advance(1.0 / 60)
		ticks += 1
		var now: float = body.global_position.distance_to(berth_pose.origin)
		if now > last + .001 or last - now > 2.0: smooth = false
		last = now
	verify(smooth and ticks > 60 and ticks <= int(authority.MAX_SLIDE_SECONDS * 60) + 2, "Slide moves steadily toward the berth, no jump (%d ticks)" % ticks)
	verify(authority.state(1) == "docked" and body.global_position.distance_to(berth_pose.origin) < .01 and body.global_transform.basis.z.dot(berth_pose.basis.z) > .9999, "Slide ends docked on the berth centre and heading")
	authority.request_undock(1)
	authority.advance(.6)
	verify(body.helm_available() and body.global_position.distance_to(berth_pose.origin) < .01, "Undock after a slide restores helm in the berth")
	body.global_transform = start
	authority.request_dock(1, "container_transfer", "cargo_test_container")
	authority.advance(.5)
	verify(authority.cancel(1) and body.helm_available() and authority.reservations.is_empty(), "Cancel during the slide returns the helm")
	body.global_transform = old_pose
	authority.set_physics_process(true)

## Patch 2.1 item 4: one ship per berth. An AI ship holds berth 1 the way a
## future server would hand it out; the captain is sent to berth 2, a third
## ship is told the port is full, and docked ships pass through each other.
func check_berths(preview: Node3D) -> void:
	var authority = preview.docking
	authority.set_physics_process(false)
	var port: Node3D = preview.port
	var body: HandlingShip = preview.ship
	var old_pose: Transform3D = body.global_transform
	verify(port.berth_anchors.size() == port.BERTH_COUNT and port.BERTH_COUNT >= 3 and port.berth_id(0) != port.berth_id(1) and port.berth_id(1) != port.berth_id(2) and port.berth_anchors[1].global_position.distance_to(port.berth_anchor.global_position) >= body.definition.hull_size_m.z + 20, "Port has three berths in a row, a hull length apart")
	var berth_one: Transform3D = port.berth_anchors[0].global_transform
	var ai: HandlingShip = HandlingShip.new()
	CollisionRules.add_box_hull(ai, ai.definition.hull_size_m)
	add_child(ai)
	ai.global_transform = berth_one
	body.global_transform = berth_one.translated_local(Vector3(-port.quay_side * 40, 0, port.BERTH_SPACING_M * .6))
	body.velocity = Vector3.ZERO
	await get_tree().physics_frame
	verify(authority.register(2, ai, port) and authority.request_dock(2, "container_transfer", "cargo_test_container").ok and authority.members[2].berth_index == 0, "AI ship claims berth 1")
	authority.advance(authority.MAX_SLIDE_SECONDS + .1)
	verify(authority.state(2) == "docked" and authority.claims.holder(authority.berth_key(port, 0)) == 2, "AI ship holds berth 1")
	verify(ai.collision_layer == CollisionRules.DOCKED_HULL and ai.collision_mask & CollisionRules.HULL == 0, "Docked ship collision with other ships is off")
	await get_tree().physics_frame
	verify(authority.readiness(1, "container_transfer", "cargo_test_container").eligible, "Taken berth 1 is skipped; berth 2 is ready")
	verify(authority.request_dock(1, "container_transfer", "cargo_test_container").ok and authority.members[1].berth_index == 1 and authority.reservations.size() == 2, "Captain is sent to the next free berth")
	verify(body.collision_layer == CollisionRules.DOCKED_HULL, "Collision is off while sliding into a berth")
	authority.advance(authority.MAX_SLIDE_SECONDS + .1)
	verify(authority.state(1) == "docked" and body.global_position.distance_to(port.berth_anchors[1].global_transform.translated_local(Vector3(port.quay_offset_m(body.definition), 0, 0)).origin) < .01, "Captain docks at berth 2, a fender gap off the quay")
	var gap: float = absf((berth_one.affine_inverse() * body.global_position).z) - body.definition.hull_size_m.z / 2 - ai.definition.hull_size_m.z / 2
	verify(gap > 10, "Ships at a port never overlap (%.0f m apart)" % gap)
	# Patch 2.4 item 3: a second AI ship holds berth 3, so the port is full.
	var ai_two: HandlingShip = HandlingShip.new()
	CollisionRules.add_box_hull(ai_two, ai_two.definition.hull_size_m)
	add_child(ai_two)
	ai_two.global_transform = port.berth_anchors[2].global_transform
	await get_tree().physics_frame
	verify(authority.register(4, ai_two, port) and authority.request_dock(4, "container_transfer", "cargo_test_container").ok and authority.members[4].berth_index == 2, "Second AI ship claims berth 3")
	authority.advance(authority.MAX_SLIDE_SECONDS + .1)
	var third: HandlingShip = HandlingShip.new()
	CollisionRules.add_box_hull(third, third.definition.hull_size_m)
	add_child(third)
	third.global_transform = berth_one.translated_local(Vector3(-port.quay_side * 60, 0, port.BERTH_SPACING_M * .6))
	await get_tree().physics_frame
	authority.register(3, third, port)
	var full: Dictionary = authority.request_dock(3, "container_transfer", "cargo_test_container")
	verify(not full.ok and full.message == authority.PORT_FULL and authority.readiness(3, "container_transfer", "cargo_test_container").code == "FULL", "No free berth: Dock says the port is full")
	authority.request_undock(1)
	authority.advance(.6)
	await get_tree().physics_frame
	verify(authority.state(1) == "underway" and body.helm_available() and authority.claims.holder(authority.berth_key(port, 1)) == 0, "Undock gives the berth up")
	verify(body.collision_layer == CollisionRules.DOCKED_HULL and authority.request_dock(3, "container_transfer", "cargo_test_container").message == authority.PORT_FULL, "Still in the berth: collision stays off and nobody slides in on top")
	body.global_transform = third.global_transform.translated_local(Vector3(0, 0, 10))
	await get_tree().physics_frame
	authority.advance(.01)
	verify(body.collision_layer == CollisionRules.DOCKED_HULL, "Collision stays off while overlapping another ship")
	third.global_position += Vector3(0, 0, -400)
	await get_tree().physics_frame
	authority.advance(.01)
	verify(body.collision_layer == CollisionRules.HULL and body.collision_mask == CollisionRules.SOLID_WATERCRAFT, "Collision comes back once out of the berth and clear of ships")
	authority.disconnect_owner(2)
	authority.disconnect_owner(3)
	authority.disconnect_owner(4)
	verify(authority.reservations.is_empty() and ai.collision_layer == CollisionRules.HULL, "Leaving the port frees every claim")
	ai.free()
	ai_two.free()
	third.free()
	body.global_transform = old_pose
	await get_tree().physics_frame
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
	second.quantity = 20
	second.job_id = "job_2"
	second.acquisition_id = ""
	verify(manifest.add(second).ok and manifest.usage().container_slots == 24, "Multiple jobs share aggregate capacity and exact limit is allowed")
	var original: Array[Dictionary] = manifest.lines()
	for change: Dictionary in [{"quantity": 1, "batch_id": "overflow"}, {"cargo_id": "cargo_test_industrial", "batch_id": "wrong_ship"}, {"quantity": 0}, {"quantity": -1}, {"quantity": 1.5}, {"quantity": 1000000001}, {"unit": "gram"}, {"origin_port_id": "missing"}, {"destination_port_id": "missing"}, {"acquisition_id": "", "job_id": ""}, {"batch_id": "lot_1"}]:
		var bad: Dictionary = second.duplicate(true)
		bad.merge(change, true)
		verify(not manifest.add(bad).ok and manifest.lines() == original, "Invalid/oversized addition leaves all cargo unchanged")
	verify(not manifest.remove("lot_1", 99).ok and manifest.lines() == original, "Excessive removal is atomic")
	verify(manifest.remove("lot_1", 2).ok and manifest.lines()[0].quantity == 2 and manifest.lines()[0].acquisition_id == "purchase_1", "Partial removal retains batch provenance")
	verify(manifest.remove("lot_2", 20).ok and manifest.lines().size() == 1, "Full removal clears only selected job batch")
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
	verify(not source.accept(rows[1].id, "captain_a", "ship_a", "port_brindle_quay", manifest).ok and not source.accept(rows[2].id, "captain_a", "other_ship", "port_brindle_quay", manifest).ok, "One active job per captain even across ships")
	var return_offer: String = source.list_at("port_slatewater_works")[0].id
	verify(not source.accept(return_offer, "captain_a", "ship_a", "port_slatewater_works", manifest).ok and source.view(return_offer).state == "available", "Capacity commitments reject excess acceptance atomically")
	verify(source.advance_to(600000) and source.view(return_offer).state == "available", "Jobs remain available without expiry")
	verify(source.view(id) == accepted.offer and source.accept(id, "captain_a", "ship_a", "port_brindle_quay", manifest).ok, "Accepted quote remains unchanged as time advances")
	verify(not source.advance_to(1), "Authority simulation clock cannot rewind")
	verify(source.accept(return_offer, "captain_b", "ship_b", "port_slatewater_works", manifest).ok, "Jobs remain acceptable after former expiry deadline")

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
	loading.advance(1)
	loading.disconnect_ship()
	verify(not loading.busy() and source.view(id).state == "available" and body.state.manifest.lines().is_empty(), "Disconnect releases incomplete job without cargo")
	source.accept(id, "preview_captain", "preview_ship", port_id, body.state.manifest)
	loading.start(id)
	dock.request_undock(1)
	loading.advance(.1)
	verify(not loading.busy() and source.view(id).state == "available", "Loss of docked authority interrupts loading")
	dock.cancel(1)
	preview.selected_offer = id
	preview.accept_selected()
	verify(loading.busy(), "Accept button starts loading automatically")
	preview.loading_text.hide()
	loading.advance(5)
	verify(not loading.busy() and source.view(id).state == "loaded" and body.state.manifest.lines()[0].quantity == 1, "Authority completes with presentation hidden")
	preview.loading_text.show()
	verify(not loading.start(id) and body.state.manifest.lines().size() == 1, "Loaded offer cannot create duplicate cargo")
	var second: String = source.list_at(port_id)[1].id
	verify(not source.accept(second, "preview_captain", "preview_ship", port_id, body.state.manifest).ok, "Loaded job prevents another acceptance until delivery")
	loading.set_physics_process(true)
	dock.set_physics_process(true)

func check_services(preview: Node3D) -> void:
	var body: HandlingShip = preview.ship
	var dock = preview.docking
	# Existing loading test leaves one container aboard at its origin.
	var origin: String = preview.port.definition.id
	var before: Array[Dictionary] = body.state.manifest.lines()
	preview.deliver()
	verify(body.state.manifest.lines() == before, "Wrong-port delivery cannot remove cargo or pay")
	var target_index: int = 0 if origin == "port_slatewater_works" else 1
	dock.request_undock(1)
	dock.advance(1)
	body.global_transform = preview.world_ports[target_index].berth_anchor.global_transform
	body.velocity = Vector3(0, 0, 2)
	preview._physics_process(.01)
	verify(body.velocity.z == 2, "Changing nearby-port context preserves underway motion")
	body.velocity = Vector3.ZERO
	verify(preview.port == preview.world_ports[target_index] and preview.ship == body, "Sailing to the other port changes active berth without replacing ship")
	dock.request_dock(1, "container_transfer", "cargo_test_container")
	dock.advance(1.1)
	preview.deliver()
	verify(body.state.manifest.lines().is_empty() and preview.reward_minor == 25000, "Container delivery at destination clears batch and awards test credits once")
	preview.deliver()
	verify(preview.reward_minor == 25000, "Repeated delivery cannot duplicate test payout")
	body.state.fuel_liters = 10
	body.state.condition = .4
	preview.refuel()
	preview.repair()
	verify(body.state.fuel_liters == body.definition.fuel_capacity_liters and body.state.condition == 1, "Docked refuel and repair service effects apply")
	dock.request_undock(1)
	dock.advance(1)
	body.state.fuel_liters = 10
	body.state.condition = .4
	preview.refuel()
	preview.repair()
	verify(body.state.fuel_liters == 10 and body.state.condition == .4, "Services cannot be invoked while underway")
	preview.heavy_mode = true
	preview.select_port(target_index)
	await get_tree().physics_frame
	await get_tree().physics_frame
	body = preview.ship
	verify(body.has_method("attach_payload") and body.payload_body.collision_layer == 0, "Heavy test starts without free job cargo")
	body.global_transform = preview.port.berth_anchor.global_transform
	preview.docking.request_dock(1, "heavy_transfer", "cargo_test_industrial")
	preview.docking.advance(1.1)
	preview.refresh_jobs()
	verify(preview.jobs_list.item_count == 3, "Heavy loader gets multiple suitable jobs")
	var selected: String = preview.selected_offer
	preview.accept_selected()
	verify(not preview.heavy_jobs.active.is_empty() and body.payload_body.collision_layer == CollisionRules.HULL, "Accepting docked heavy job spawns nearby physical load")
	verify(not preview.heavy_jobs.accept(selected, body, preview.port, true), "Second heavy acceptance cannot spawn duplicate load")
	var destination: Vector3 = preview.heavy_jobs.active.drop
	verify(destination.distance_to(preview.port.global_position) > 800, "Heavy destination lies out in open ocean")
	preview.docking.request_undock(1)
	preview.docking.advance(1)
	check_restart(preview)
	body.request_height(-1.0)
	for step: int in 240: body.advance_deck(1.0 / 60)
	# Place the ship, not the cargo, under its spawned job for authority-rule tests.
	body.global_transform = body.payload_body.global_transform.translated_local(Vector3(0, 1, 8))
	verify(body.attach_payload(), "Accepted physical job load can be picked up")
	preview.heavy_jobs.update(body)
	verify(not body.detach_payload(), "Job cargo cannot be dropped at an arbitrary location")
	body.global_position = destination + Vector3(0, 0, 8)
	verify(body.detach_payload(), "Stopped lowered heavy cargo can be dropped at its ocean destination")
	preview.heavy_jobs.update(body)
	verify(preview.heavy_jobs.active.is_empty() and preview.heavy_jobs.reward_pending > 0, "Ocean drop-off completes the heavy job")
	var reward: int = preview.heavy_jobs.reward_pending
	preview.heavy_jobs.update(body)
	verify(preview.heavy_jobs.reward_pending == reward, "Repeated update cannot duplicate ocean delivery")
	preview.heavy_mode = false
	preview.select_port(0)

func check_restart(preview: Node3D) -> void:
	# Tab navigation and cancelled pointer clicks used to leave HUD focus behind,
	# making PlayerControls reject all sailing input indefinitely.
	var focusable: int = 0
	for node: Node in preview.find_children("*", "Control", true, false):
		if node.focus_mode != Control.FOCUS_NONE:
			focusable += 1
	verify(focusable == 0, "Sailing HUD has no controls that can trap keyboard focus")
	var body: HandlingShip = preview.ship
	body.zero_throttle()
	body.actual_throttle = 0
	body.velocity = Vector3.ZERO
	preview.controls._process(0)
	Input.action_press("ship_throttle_up")
	preview.helm._physics_process(.25)
	body.advance_motion(.25)
	verify(body.commanded_throttle > 0 and body.forward_speed() > 0, "Stopped ship resumes forward propulsion through real input boundary")
	Input.action_release("ship_throttle_up")
	body.zero_throttle()
	body.actual_throttle = 0
	body.velocity = Vector3.ZERO
	Input.action_press("ship_throttle_down")
	preview.helm._physics_process(.25)
	body.advance_motion(.25)
	verify(body.commanded_throttle < 0 and body.forward_speed() < 0, "Stopped ship resumes reverse propulsion through real input boundary")
	Input.action_release("ship_throttle_down")
	body.zero_throttle()
	body.actual_throttle = 0
	body.velocity = Vector3.ZERO

func visual_batch(quantity: int) -> Dictionary:
	return {"batch_id": "visual_fixture", "cargo_id": "cargo_test_container", "quantity": quantity, "unit": "count", "origin_port_id": "port_brindle_quay", "destination_port_id": "port_slatewater_works", "acquisition_id": "fixture", "job_id": ""}

func check_container_visuals(preview: Node3D) -> void:
	var body: HandlingShip = preview.ship
	var display: Node3D = body.assembly.container_visuals
	verify(display.shown_count == 0, "Empty manifest displays an empty deck")
	verify(body.state.manifest.add(visual_batch(3)).ok and display.shown_count == 3, "Partial manifest immediately displays three containers")
	var bad: Array[Dictionary] = [visual_batch(25)]
	verify(not body.state.manifest.replace(bad).ok and display.shown_count == 3, "Rejected capacity mutation cannot change visuals")
	var full: Array[Dictionary] = [visual_batch(24)]
	body.state.manifest.replace(full)
	verify(display.shown_count == 24 and display.instances.multimesh.instance_count == 24, "Full capacity uses a bounded pool of 24 instances")
	# Patch 2.0 (bigger loads): the deck is two tiers of twelve, and the game's jobs
	# run from a handful to a full ship, paid per container.
	var offer_script = preload("res://features/cargo/container_offers.gd")
	# Read from the layout: headless Godot does not keep MultiMesh transforms.
	var centres: PackedVector3Array = body.definition.container_layout.centres
	var lower: int = 0
	for i: int in centres.size():
		if i < 12 and centres[i].y < 5.0 or i >= 12 and centres[i].y > 5.0: lower += 1
	verify(centres.size() == 24 and lower == 24, "A full ship shows a two-tier stack, lower tier first")
	verify(offer_script.GAME_CAPACITY == int(body.definition.cargo_capacities.container_slots), "Game offers are sized to the container ship's capacity")
	var smallest: int = 999
	var largest: int = 0
	var pay_scaled: bool = true
	for port_index: int in 4:
		for slot: int in 3:
			for turn: int in 6:
				var made: Dictionary = offer_script.fresh("container_load_%d_%d_%d" % [port_index, slot, turn], true)
				smallest = mini(smallest, int(made.quantity))
				largest = maxi(largest, int(made.quantity))
				pay_scaled = pay_scaled and made.reward_minor > 0 and made.reward_minor % made.quantity == 0 and made.reward_minor / made.quantity == offer_script.fresh("container_load_%d_2_%d" % [port_index, turn + slot + 1], true).reward_minor / 24
	verify(smallest == 4 and largest == 24 and pay_scaled, "Game jobs run from a handful (4) to a full ship (24) and pay per container (%d to %d)" % [smallest, largest])
	verify(offer_script.fresh("container_game_0_2_0", true).quantity == 3 and offer_script.fresh("container_load_0_0_0").is_empty(), "Older small game jobs still read from saves; game jobs stay out of Port Test")
	var stock = offer_script.new()
	stock._offers.clear()
	stock._offers["container_game_0_0_0"] = offer_script.fresh("container_game_0_0_0", true)
	stock._offers["container_game_0_1_0"] = offer_script.fresh("container_game_0_1_0", true)
	stock._offers["container_game_0_1_0"].state = "delivered"
	stock.restock()
	# Patch 2.1 item 3: four slots at each strait port (one to a pole), three at each pole.
	# Patch 2.2 item 1: plus two jobs for each of container ships 2-5 at every port.
	var tiered: int = offer_script.TIER_PREFIXES.size() * offer_script.TIER_SLOTS
	verify(stock._offers.size() == 23 + tiered * preload("res://features/game/progression.gd").WORLD.size() and not stock._offers.has("container_game_0_0_0") and stock.view("container_game_0_1_0").state == "delivered" and stock.list_at("port_brindle_quay").size() == 5 + tiered and stock.list_at("port_north_pole").size() == 3 + tiered, "Restock withdraws untaken old jobs, keeps finished ones and offers bigger jobs at every port, polar ports included")
	verify(offer_script.loading_seconds(1) == 5.0 and offer_script.loading_seconds(3) == 15.0 and offer_script.loading_seconds(24) == 25.5, "Loading time grows with the load but a full ship loads in under half a minute")
	verify(display.find_children("*", "CollisionObject3D", true, false).is_empty() and display.find_children("*", "CollisionShape3D", true, false).is_empty(), "Containers add no individual physics bodies or shapes")
	verify(display.get_parent() == body.assembly.visual, "Container visuals follow the same bobbing/roll root as the hull")
	var empty: Array[Dictionary] = []
	var transforms: Array[Transform3D] = []
	for i: int in 24: transforms.append(display.instances.multimesh.get_instance_transform(i))
	body.state.manifest.replace(full)
	verify(display.shown_count == 24 and display.get_child_count() == 1, "Repeated identical state cannot create duplicate visual nodes")
	var other: HandlingShip = preload("res://features/ships/starter_container_01/starter_runtime.tscn").instantiate()
	other.position = Vector3(3000, 0, 0)
	add_child(other)
	verify(other.assembly.container_visuals.shown_count == 0 and display.shown_count == 24, "Two ships have independent cargo visibility")
	other.queue_free()
	body.state.manifest.remove("visual_fixture", 4)
	verify(display.shown_count == 20, "Partial removal immediately updates visible count")
	body.state.manifest.replace(empty)
	verify(display.shown_count == 0, "Emptying manifest removes all container visuals")
	body.state.manifest.replace(full)
	var rebuilt: bool = true
	for i: int in 6:
		if display.instances.multimesh.get_instance_transform(i) != transforms[i]: rebuilt = false
	verify(rebuilt, "Reloading same manifest retains deterministic slot transforms")
	body.state.manifest.replace(empty)

func capture_containers(preview: Node3D, capture: String) -> void:
	preview.heavy_mode = false
	preview.select_port(0)
	preview.ship.set_physics_process(false)
	preview.ship.global_transform = preview.port.berth_anchor.global_transform
	preview.set_physics_process(false)
	for child: Node in preview.get_children():
		if child is CanvasLayer: child.hide()
	preview.helm.throttle_display.hide()
	preview.camera.camera.global_position = preview.ship.global_position + Vector3(46, 36, 66)
	preview.camera.camera.look_at(preview.ship.global_position + Vector3(0, 2, 0))
	for count: int in [0, 3, 6]:
		var lines: Array[Dictionary] = []
		if count > 0: lines.append(visual_batch(count))
		preview.ship.state.manifest.replace(lines)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		verify(get_viewport().get_texture().get_image().save_png(capture + "-containers-" + str(count) + ".png") == OK, "Container load captured: " + str(count))

func check_delivery_rules() -> void:
	var source = preload("res://features/cargo/container_offers.gd").new()
	var manifest = preload("res://features/cargo/cargo_manifest.gd").new(preload("res://features/catalog/records/starter_ship.tres"), PrototypeCatalog.RECORDS)
	var id: String = source.list_at("port_brindle_quay")[0].id
	source.accept(id, "captain", "ship", "port_brindle_quay", manifest)
	source.complete_loading(id, "captain", "ship", "port_brindle_quay", manifest)
	var before: Array[Dictionary] = manifest.lines()
	verify(not source.deliver_at("captain", "ship", "port_slatewater_works", manifest, false).ok and manifest.lines() == before, "Undocked delivery preserves all cargo")
	verify(not source.deliver_at("other", "ship", "port_slatewater_works", manifest, true).ok and not source.deliver_at("captain", "other", "port_slatewater_works", manifest, true).ok, "Wrong owner and ship cannot claim a job payout")
	var mismatched: Array[Dictionary] = manifest.lines()
	mismatched[0].origin_port_id = "port_slatewater_works"
	manifest.replace(mismatched)
	verify(not source.deliver_at("captain", "ship", "port_slatewater_works", manifest, true).ok and source.view(id).state == "loaded", "Matching batch ID alone is insufficient: accepted cargo terms must agree")
	manifest.replace(before)
	var unrelated: Dictionary = visual_batch(2)
	unrelated.destination_port_id = "port_brindle_quay"
	manifest.add(unrelated)
	var delivered: Dictionary = source.deliver_at("captain", "ship", "port_slatewater_works", manifest, true)
	verify(delivered.ok and delivered.reward_minor == 25000 and manifest.lines().size() == 1 and manifest.lines()[0] == unrelated, "Delivery preserves unrelated destinations and pays the exact accepted quote")
	verify(not source.deliver_at("captain", "ship", "port_slatewater_works", manifest, true).ok, "Repeating delivery cannot pay the same job twice")
	var receipt = preload("res://features/cargo/delivery_service.gd").receipts(source, "captain")
	verify(receipt.size() == 1 and receipt[0].quantity == 1 and receipt[0].reward_minor == 25000, "Receipt matches consumed quantity and credited reward")
	receipt[0].reward_minor = 1
	verify(source.view(id).reward_minor == 25000, "Receipt presentation cannot rewrite accepted terms")
