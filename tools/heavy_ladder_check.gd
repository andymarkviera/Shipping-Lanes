extends SceneTree
## Patch 2.2 item 3: heavy-lift ships 1-5. Checks the ladder data (speed, size,
## price), the tier jobs and their loads, old save IDs, and in the real game
## scene that every ship spawns, wears its own model, docks at every port with
## no hull in the quay, sees a job board it can carry, gets its load staged at
## every port, lifts it, delivers it at sea and saves it. Isolated save folder.
## Run: godot --headless --path . --script res://tools/heavy_ladder_check.gd

const FOLDER: String = "user://heavy_ladder_check"
const Progression = preload("res://features/game/progression.gd")
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
const HeavyJobs = preload("res://features/cargo/heavy_ocean_job.gd")
## Ship 1 keeps the current heavy lifter (about 20.6 kn); ships 2-5 follow the plan.
const KNOTS: Array[float] = [20.62, 29.0, 32.0, 35.0, 38.0]
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("LADDER FAILED: " + label)
	return condition

func wipe() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)

func check_data() -> void:
	var last: ShipDefinition = null
	for tier: int in range(1, 6):
		var kind: String = Progression.HEAVY_KINDS[tier - 1]
		var ship: ShipDefinition = Progression.definition(kind)
		expect(ship != null and ship.handling_error().is_empty(), "%s record is valid" % kind)
		var knots: float = ship.forward_acceleration_mps2 / ship.linear_drag_per_second / 0.514444
		expect(absf(knots - KNOTS[tier - 1]) < 0.05, "%s tops out at %.1f kn (got %.2f)" % [kind, KNOTS[tier - 1], knots])
		expect(ship.forward_acceleration_mps2 / ship.linear_drag_per_second <= CollisionRules.SUPPORTED_SPEED_MPS, "%s is within the collision speed cap" % kind)
		expect(PrototypeCatalog.RECORDS.has(ship) or tier == 1, "%s is in the catalog" % kind)
		expect(Progression.ladder_kind(ship.id) == kind and Progression.heavy_tier(kind) == tier and Progression.bulk_tier(kind) == 0 and Progression.container_tier(kind) == 0, "%s record ID maps to its kind" % kind)
		expect(ship.runtime_scene_path.ends_with("heavy_runtime.tscn") and ship.cargo_type_ids == ["cargo_test_industrial"] and ship.cargo_anchor_m.distance_to(Vector3(0, 2.6, -8.0 * ship.hull_size_m.z / 90.0)) < 0.01, "%s is a heavy lifter with its deck centred" % kind)
		if last != null:
			expect(ship.hull_size_m.z > last.hull_size_m.z and ship.hull_size_m.x >= last.hull_size_m.x, "%s is bigger than the ship before" % kind)
			expect(ship.linear_drag_per_second < last.linear_drag_per_second, "%s takes longer to reach full speed" % kind)
			expect(ship.max_turn_rate_degrees < last.max_turn_rate_degrees and ship.reverse_acceleration_mps2 < last.reverse_acceleration_mps2, "%s turns wider and stops slower" % kind)
			expect(int(Progression.SHIPS[kind].price_minor) > int(Progression.SHIPS[Progression.HEAVY_KINDS[tier - 2]].price_minor) * 2, "%s costs far more" % kind)
			expect(ship.fuel_full_output_lps > last.fuel_full_output_lps and ship.camera_distance_m > last.camera_distance_m and ship.wake_half_length_m > last.wake_half_length_m, "%s burns more and has a bigger camera and wake" % kind)
			expect(HeavyJobs.load_of(tier, 2).mass_kg > HeavyJobs.load_of(tier - 1, 2).mass_kg, "%s lifts heavier pieces" % kind)
		expect(ship.hull_size_m.x / 2.0 < 20.0, "%s clears the quay face" % kind)
		last = ship
	expect(int(Progression.SHIPS.heavy.price_minor) == 300000 and Progression.definition("heavy").id == "ship_heavy_lifter_01", "Heavy ship 1 is the current heavy lifter at its old price")
	expect(Progression.definition("heavy_5").hull_size_m.z >= 3.0 * 90.0, "Ship 5 is several times ship 1")
	var biggest: Vector3 = Progression.definition("heavy_5").hull_size_m
	for scene: PackedScene in preload("res://features/ports/port_test.gd").GAME_PORTS:
		var state: SceneState = scene.get_state()
		for index: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, index) == "berth":
				var berth: BerthDefinition = state.get_node_property_value(0, index)
				expect(biggest.z + 2.0 * berth.clearance_margin_m <= berth.envelope_m.z and biggest.x + 2.0 * berth.clearance_margin_m <= berth.envelope_m.x, berth.id + " fits heavy ship 5")

func check_jobs() -> void:
	var jobs = HeavyJobs.new()
	var old: Array[Dictionary] = jobs.list_at("port_brindle_quay")
	expect(old.size() == 3 and old[0].id == "port_brindle_quay_heavy_0" and old[0].title == "Platform module" and old[2].reward_minor == 100000, "Ship 1 heavy jobs unchanged")
	expect(HeavyJobs.load_for("port_brindle_quay_heavy_1").size == Vector3(14, 8, 32), "Ship 1 keeps the prototype load")
	for tier: int in range(2, 6):
		var rows: Array[Dictionary] = jobs.list_at("port_north_pole", tier)
		expect(rows.size() == 3 and rows[0].id == "port_north_pole_heavy_t%d_0" % tier and HeavyJobs.tier_of(rows[0].id) == tier, "Tier %d has three jobs with tier IDs" % tier)
		expect(rows[2].reward_minor == 100000 * HeavyJobs.TIER_PAY[tier - 1], "Tier %d pays its multiple" % tier)
	var trip: int = jobs.list_at("port_brindle_quay", 5)[2].reward_minor
	expect(trip * 40 > int(Progression.SHIPS.heavy_5.price_minor) and trip * 4 < int(Progression.SHIPS.heavy_5.price_minor), "Ship 5 pays for itself in tens of trips, not a handful (%d)" % trip)
	expect(jobs.list_all("port_brindle_quay").size() == 15, "Fifteen heavy jobs per port across the ladder")
	for bad: String in ["port_brindle_quay_heavy_t6_0", "port_brindle_quay_heavy_t1_0", "port_brindle_quay_heavy_tx_0"]:
		expect(HeavyJobs.tier_of(bad) == 1, bad + " is not a tier 2-5 ID")

func clear_of(ship: HandlingShip, mask: int) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = ship.definition.hull_size_m - Vector3.ONE * 0.05
	query.shape = shape
	query.transform = ship.global_transform.translated_local(Vector3(0, 1, 0))
	query.collision_mask = mask
	query.exclude = [ship.get_rid()]
	return ship.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

var saved_carrying: Dictionary = {}

func dock_everywhere(game: Node) -> void:
	var home: int = 0
	for tier: int in range(1, 6):
		var kind: String = Progression.HEAVY_KINDS[tier - 1]
		game.ship_kind = kind
		game.heavy_mode = true
		game.bulk_active = ""
		game.fleet[kind] = {"fuel": 1.0, "condition": 1.0}
		for index: int in game.world_ports.size():
			if not expect(game.select_port(index), "%s spawns at port %d" % [kind, index]): continue
			var ship: HandlingShip = game.ship
			var port: Node3D = game.world_ports[index]
			expect(game.heavy_mode and not game.bulk_mode() and ship.definition.id == Progression.definition(kind).id and ship.has_method("attach_payload"), "%s sails its own record in heavy mode" % kind)
			expect(ship.assembly.visual.find_child("ChunkyShip", true, false) != null, "%s wears its toon model" % kind)
			expect(is_equal_approx(game.camera.distance_order, ship.definition.camera_distance_m) and game.wake.half_length == ship.definition.wake_half_length_m, "%s camera and wake fit the hull" % kind)
			expect(ship.k.is_equal_approx(Vector3(ship.definition.hull_size_m.x / 24.0, 1.0, ship.definition.hull_size_m.z / 90.0)) and ship.deck_visual.scale.is_equal_approx(ship.k), "%s deck and colliders scale with the hull" % kind)
			if not port.berth.service_ids.has("heavy_transfer"):
				expect(not game.docking.request_dock(1, game.service_id(), game.cargo_id()).ok, "%s is refused at %s, which has no heavy berth" % [kind, port.definition.id])
				continue
			for frame: int in 2: await physics_frame
			ship.global_transform = port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
			ship.velocity = Vector3.ZERO
			for frame: int in 2: await physics_frame
			var result: Dictionary = game.docking.request_dock(1, game.service_id(), game.cargo_id())
			if not expect(result.ok, "%s can dock at %s (%s)" % [kind, port.definition.id, result.message]): continue
			for frame: int in 300:
				await physics_frame
				if game.docking.state(1) == "docked": break
			expect(game.docking.state(1) == "docked", "%s finished docking at %s" % [kind, port.definition.id])
			expect(clear_of(ship, CollisionRules.SHORE), "%s docked at %s is clear of the quay" % [kind, port.definition.id])
			game.refresh_jobs()
			var own_first: bool = not game.job_cards.is_empty() and HeavyJobs.tier_of(game.job_cards[0].id) == tier
			for card: Dictionary in game.job_cards:
				expect(card.kind == "heavy" and HeavyJobs.tier_of(card.id) <= tier, "%s is never offered %s" % [kind, card.id])
			expect(own_first and game.job_cards.size() <= game.JOB_BOARD_SIZE, "%s sees its own jobs first at %s" % [kind, port.definition.id])
			# The biggest load of this tier is staged clear of the land and the quay.
			var job_id: String = "%s_heavy_%s2" % [port.definition.id, "" if tier == 1 else "t%d_" % tier]
			game.selected_offer = job_id
			game.accept_selected()
			if not expect(game.heavy_jobs.active.get("id", "") == job_id and ship.payload_body.visible, "%s load staged at %s (%s)" % [kind, port.definition.id, game.offer_notice]): continue
			expect(ship.payload_size.is_equal_approx(HeavyJobs.load_for(job_id).size), "%s load is sized for its tier" % kind)
			if index != home:
				expect(game.heavy_jobs.cancel_pickup(ship), "%s pickup cancels at %s" % [kind, port.definition.id])
				continue
			# Port 0: lift it, save it, deliver it at sea.
			var data: Dictionary = Snapshot.capture(game)
			expect(data.ship == kind and data.heavy_mode and Snapshot.valid(data), "%s save with a staged load is valid" % kind)
			if tier > 1:
				var smaller: Dictionary = data.duplicate(true)
				smaller.ship = Progression.HEAVY_KINDS[tier - 2]
				smaller.fleet[smaller.ship] = {"fuel": 1.0, "condition": 1.0}
				expect(not Snapshot.valid(smaller), "A smaller ship cannot hold %s's job in a save" % kind)
			ship.set_physics_process(false)
			game.helm.set_physics_process(false)
			game.docking.request_undock(1)
			game.docking.advance(1)
			expect(ship.request_height(ship.LOWERED), "%s lowers its deck" % kind)
			for i: int in 400: ship.advance_deck(1.0 / 60)
			ship.global_transform = ship.payload_body.global_transform * Transform3D(Basis(Vector3.UP, .2), Vector3(2, 1, -ship.deck_z() + 4))
			expect(ship.request_height(ship.RAISED) and ship.attached, "%s lifts its load (%s)" % [kind, ship.notice])
			for i: int in 400: ship.advance_deck(1.0 / 60)
			game.heavy_jobs.update(ship)
			expect(ship.deck_height == ship.RAISED and ship.helm_available() and game.heavy_jobs.active.state == "carrying", "%s sails with the load raised" % kind)
			expect(ship.payload_visual.get_parent() == ship.cargo_mount and (tier == 1 or ship.loaded_draft_m > 0.1) and ship.loaded_draft_m < 1.5, "%s sits a little lower when loaded (%.2f m)" % [kind, ship.loaded_draft_m])
			var carrying: Dictionary = Snapshot.capture(game)
			expect(Snapshot.valid(carrying.duplicate(true)), "%s save while carrying is valid" % kind)
			if tier == 5: saved_carrying = carrying
			var before: int = game.reward_minor
			ship.global_position = game.heavy_jobs.active.drop - ship.global_basis * Vector3(0, 0, ship.deck_z())
			expect(ship.request_height(ship.LOWERED), "%s lowers at the drop-off" % kind)
			for i: int in 400: ship.advance_deck(1.0 / 60)
			for frame: int in 4: await physics_frame
			expect(not ship.attached and game.heavy_jobs.active.is_empty(), "%s delivers its load at sea" % kind)
			expect(game.reward_minor - before == HeavyJobs.new().list_at(port.definition.id, tier)[2].reward_minor, "%s is paid its tier's pay (%d)" % [kind, game.reward_minor - before])
			expect(not game.persistence.blocked, "%s delivery saves" % kind)
			ship.request_height(ship.RAISED)
			for i: int in 400: ship.advance_deck(1.0 / 60)

## A fresh game scene restores the ship 5 carrying save with its load aboard.
func check_restore() -> void:
	if not expect(not saved_carrying.is_empty(), "A ship 5 carrying save was made"): return
	var game: Node = await open_game()
	if game == null: return
	expect(await Snapshot.restore(game, saved_carrying.duplicate(true)), "Ship 5 carrying save restores")
	var ship: HandlingShip = game.ship
	expect(game.ship_kind == "heavy_5" and ship.definition.id == "ship_heavy_semisub_05" and ship.attached and ship.payload_size.is_equal_approx(HeavyJobs.load_for(saved_carrying.heavy.active.id).size), "Ship 5 restores with its own load aboard")
	expect(ship.payload_visual.get_parent() == ship.cargo_mount and ship.payload_body.collision_layer == 0 and not ship.payload_shape.disabled, "Restored load has one collision owner")

func check_old_ids(game: Node) -> void:
	game.ship_kind = "heavy"
	game.heavy_mode = true
	game.heavy_jobs.active.clear()
	game.fleet = {"container": {"fuel": 1.0, "condition": 1.0}, "heavy": {"fuel": 0.5, "condition": 0.9}}
	expect(game.select_port(0, true), "Heavy ship 1 spawns for the save check")
	var data: Dictionary = Snapshot.capture(game)
	data.ship = "ship_heavy_lifter_01"
	data.fleet = {"ship_starter_container_01": {"fuel": 1.0, "condition": 1.0}, "ship_heavy_lifter_01": {"fuel": 0.5, "condition": 0.9}}
	expect(Snapshot.valid(data) and data.ship == "heavy" and data.fleet.has("container") and data.fleet.heavy.fuel == 0.5, "The old heavy lifter ID loads as heavy ship 1 with its fuel and hull")
	data = Snapshot.capture(game)
	data.ship = "ship_heavy_semisub_05"
	data.fleet["ship_heavy_semisub_05"] = {"fuel": 1.0, "condition": 1.0}
	expect(Snapshot.valid(data) and data.ship == "heavy_5", "A heavy ship 5 record ID loads as heavy_5")
	data = Snapshot.capture(game)
	data.heavy_mode = false
	expect(not Snapshot.valid(data), "A heavy ship saved outside heavy mode is refused")

func fast_forward() -> void:
	Engine.time_scale = 8
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	for frame: int in 3:
		await process_frame
		await physics_frame

func open_game() -> Node:
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and scene.get("persistence") != null and is_instance_valid(scene.persistence) and (scene.persistence.ready_to_save or scene.persistence.blocked):
			return scene
	expect(false, "Game scene opened")
	return null

func run() -> void:
	await process_frame
	wipe()
	check_data()
	check_jobs()
	await fast_forward()
	var game: Node = await open_game()
	if game != null and expect(not game.persistence.blocked, "Isolated save opens"):
		await dock_everywhere(game)
		check_old_ids(game)
		current_scene.queue_free()
		for frame: int in 3: await process_frame
		wipe()
		await check_restore()
	if current_scene != null:
		current_scene.queue_free()
		for frame: int in 3: await process_frame
	wipe()
	for failure: String in failures: push_error(failure)
	print("HEAVY_LADDER_CHECK_PASS checks=%d" % checks if failures.is_empty() else "HEAVY_LADDER_CHECK_FAILED %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
