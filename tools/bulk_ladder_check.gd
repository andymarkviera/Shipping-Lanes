extends SceneTree
## Patch 2.2 item 2: bulk ships 1-5. Checks the ladder data (speed, size,
## tonnage, price), the tier jobs, old save IDs, and in the real game scene
## that every ship spawns, wears its own model, docks at every port with no
## hull in the quay and sees a job board it can carry. Isolated save folder.
## Run: godot --headless --path . --script res://tools/bulk_ladder_check.gd

const FOLDER: String = "user://bulk_ladder_check"
const Progression = preload("res://features/game/progression.gd")
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
const KNOTS: Array[float] = [28.0, 31.0, 34.0, 37.0, 40.0]
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

## Full-speed, full-rudder turning radius: top speed over max yaw rate.
func turn_radius_m(ship: ShipDefinition) -> float:
	return ship.forward_acceleration_mps2 / ship.linear_drag_per_second / deg_to_rad(ship.max_turn_rate_degrees)

func check_data() -> void:
	var last: ShipDefinition = null
	for tier: int in range(1, 6):
		var kind: String = Progression.BULK_KINDS[tier - 1]
		var ship: ShipDefinition = Progression.definition(kind)
		expect(ship != null and ship.handling_error().is_empty(), "%s record is valid" % kind)
		var knots: float = ship.forward_acceleration_mps2 / ship.linear_drag_per_second / 0.514444
		expect(absf(knots - KNOTS[tier - 1]) < 0.05, "%s tops out at %.0f kn (got %.2f)" % [kind, KNOTS[tier - 1], knots])
		expect(ship.forward_acceleration_mps2 / ship.linear_drag_per_second <= CollisionRules.SUPPORTED_SPEED_MPS, "%s is within the collision speed cap" % kind)
		expect(PrototypeCatalog.RECORDS.has(ship), "%s is in the catalog" % kind)
		expect(Progression.ladder_kind(ship.id) == kind and Progression.bulk_tier(kind) == tier and Progression.container_tier(kind) == 0, "%s record ID maps to its kind" % kind)
		expect(ship.container_layout == null and ship.cargo_type_ids.has("cargo_bulk_ore"), "%s carries bulk, not containers" % kind)
		if last != null:
			expect(ship.hull_size_m.z > last.hull_size_m.z and ship.hull_size_m.x >= last.hull_size_m.x, "%s is bigger than the ship before" % kind)
			expect(ship.linear_drag_per_second < last.linear_drag_per_second, "%s takes longer to reach full speed" % kind)
			expect(ship.max_turn_rate_degrees < last.max_turn_rate_degrees and ship.reverse_acceleration_mps2 < last.reverse_acceleration_mps2, "%s turns wider and stops slower" % kind)
			expect(turn_radius_m(ship) > turn_radius_m(last), "%s turning circle is wider than the ship before" % kind)
			expect(Progression.bulk_capacity(tier) > Progression.bulk_capacity(tier - 1), "%s carries more" % kind)
			expect(int(Progression.SHIPS[kind].price_minor) > int(Progression.SHIPS[Progression.BULK_KINDS[tier - 2]].price_minor) * 2, "%s costs far more" % kind)
			expect(ship.fuel_full_output_lps > last.fuel_full_output_lps and ship.camera_distance_m > last.camera_distance_m and ship.wake_half_length_m > last.wake_half_length_m, "%s burns more and has a bigger camera and wake" % kind)
		expect(ship.hull_size_m.x / 2.0 < 20.0, "%s clears the quay face" % kind)
		# Patch 2.4 item 2: no ship feels like a slog (full-speed, full-rudder radius).
		expect(turn_radius_m(ship) <= 460.0, "%s turns within 460 m at full speed (got %.0f m)" % [kind, turn_radius_m(ship)])
		last = ship
	expect(int(Progression.SHIPS.bulk.price_minor) == 120000, "Bulk ship 1 keeps the old bulk price")
	expect(Progression.definition("bulk_5").hull_size_m.z >= 4.0 * 64.0, "Ship 5 is several times the starter")
	var biggest: Vector3 = Progression.definition("bulk_5").hull_size_m
	for scene: PackedScene in preload("res://features/ports/port_test.gd").GAME_PORTS:
		var state: SceneState = scene.get_state()
		for index: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, index) == "berth":
				var berth: BerthDefinition = state.get_node_property_value(0, index)
				expect(biggest.z + 2.0 * berth.clearance_margin_m <= berth.envelope_m.z and biggest.x + 2.0 * berth.clearance_margin_m <= berth.envelope_m.x, berth.id + " fits bulk ship 5")

func check_jobs() -> void:
	# The M3 job IDs, titles and pay are unchanged.
	var old: Dictionary = Progression.bulk_job("bulk_0_grain")
	expect(old.title == "Grain, 4,000 t" and old.reward_minor == 6000 * Progression.leg_units(0, old.destination) and old.tier == 1, "Ship 1 grain job unchanged")
	expect(Progression.bulk_job("bulk_1_ore").title == "Iron ore, 6,000 t" and Progression.bulk_job("bulk_2_coal").title == "Coal, 5,000 t", "Ship 1 titles unchanged")
	for port: int in Progression.WORLD.size():
		for index: int in Progression.BULK_CARGO.size():
			var job: Dictionary = Progression.bulk_job(Progression.bulk_ids(port)[index])
			expect(job.reward_minor == int(Progression.BULK_CARGO[index][2]) * Progression.leg_units(port, job.destination), "Ship 1 pay unchanged at port %d" % port)
	for port: int in Progression.WORLD.size():
		for tier: int in range(1, 6):
			var ids: Array[String] = Progression.bulk_ids(port, tier)
			expect(ids.size() == 3, "Port %d has three tier %d jobs" % [port, tier])
			var top: int = 0
			for id: String in ids:
				var job: Dictionary = Progression.bulk_job(id)
				expect(not job.is_empty() and job.tier == tier and job.origin == port and job.tonnes <= Progression.bulk_capacity(tier) and job.reward_minor > 0, id + " fits the ship it was sized for")
				top = maxi(top, int(job.tonnes))
			expect(top == Progression.bulk_capacity(tier), "Port %d offers a full load for bulk ship %d" % [port, tier])
	var rate: Callable = func(id: String) -> float:
		var job: Dictionary = Progression.bulk_job(id)
		return float(job.reward_minor) / job.tonnes / Progression.leg_units(job.origin, job.destination)
	expect(rate.call("bulk_t5_0_ore") > rate.call("bulk_0_ore") * 1.3, "A ship 5 job pays more per tonne and 100 m than a ship 1 job")
	var trip: int = Progression.bulk_job("bulk_t5_0_ore").reward_minor
	expect(trip * 40 > int(Progression.SHIPS.bulk_5.price_minor) and trip * 4 < int(Progression.SHIPS.bulk_5.price_minor), "Ship 5 pays for itself in tens of trips, not a handful (%d)" % trip)
	for bad: String in ["bulk_t1_0_ore", "bulk_t6_0_ore", "bulk_t5_9_ore", "bulk_t5_0_sand", "bulk_t50_0_ore", "bulk_x5_0_ore"]:
		expect(Progression.bulk_job(bad).is_empty(), bad + " is refused")

func dock_everywhere(game: Node) -> void:
	for tier: int in range(1, 6):
		var kind: String = Progression.BULK_KINDS[tier - 1]
		game.ship_kind = kind
		game.heavy_mode = false
		game.fleet[kind] = {"fuel": 1.0, "condition": 1.0}
		for index: int in game.world_ports.size():
			if not expect(game.select_port(index), "%s spawns at port %d" % [kind, index]): continue
			var ship: HandlingShip = game.ship
			var port: Node3D = game.world_ports[index]
			expect(game.bulk_mode() and ship.definition.id == Progression.definition(kind).id, "%s sails its own record in bulk mode" % kind)
			expect(ship.assembly.visual.find_child("ChunkyShip", true, false) != null, "%s wears its toon model" % kind)
			expect(is_equal_approx(game.camera.distance_order, ship.definition.camera_distance_m) and game.wake.half_length == ship.definition.wake_half_length_m, "%s camera and wake fit the hull" % kind)
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
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = ship.definition.hull_size_m - Vector3.ONE * 0.05
			query.shape = shape
			query.transform = ship.global_transform.translated_local(Vector3(0, 1, 0))
			query.collision_mask = CollisionRules.SHORE
			expect(ship.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "%s docked at %s is clear of the quay" % [kind, port.definition.id])
		game.refresh_jobs()
		var full_load: bool = false
		for card: Dictionary in game.job_cards:
			var job: Dictionary = Progression.bulk_job(card.id)
			expect(card.kind == "bulk" and not job.is_empty() and int(job.tier) <= tier, "%s is never offered %s" % [kind, card.id])
			full_load = full_load or int(job.get("tonnes", 0)) == Progression.bulk_capacity(tier)
		expect(not game.job_cards.is_empty() and Progression.bulk_job(game.job_cards[0].id).tier == tier and full_load and game.job_cards.size() <= game.JOB_BOARD_SIZE, "%s sees its own jobs first, a full load among them" % kind)
		# Take the top job, save it, and check the save carries it.
		var top_id: String = game.job_cards[0].id
		game.selected_offer = top_id
		game.accept_selected()
		expect(game.bulk_active == top_id, "%s takes its own tier's job (%s)" % [kind, game.offer_notice])
		var data: Dictionary = Snapshot.capture(game)
		expect(data.ship == kind and Snapshot.valid(data), "%s save with a job aboard is valid" % kind)
		if tier > 1:
			data.ship = Progression.BULK_KINDS[tier - 2]
			data.fleet[data.ship] = {"fuel": 1.0, "condition": 1.0}
			expect(not Progression.save_valid(data), "A smaller ship cannot hold %s's job in a save" % kind)
		game.bulk_active = ""

func check_old_ids(game: Node) -> void:
	game.ship_kind = "bulk"
	game.bulk_active = ""
	game.fleet = {"container": {"fuel": 1.0, "condition": 1.0}, "bulk": {"fuel": 0.5, "condition": 0.9}}
	expect(game.select_port(0), "Bulk ship 1 spawns for the save check")
	var data: Dictionary = Snapshot.capture(game)
	data.ship = "ship_bulk_prototype_01"
	data.fleet = {"ship_starter_container_01": {"fuel": 1.0, "condition": 1.0}, "ship_bulk_prototype_01": {"fuel": 0.5, "condition": 0.9}}
	data.bulk = {"active": "bulk_0_grain", "done": []}
	expect(Snapshot.valid(data) and data.ship == "bulk" and data.fleet.has("container") and data.fleet.bulk.fuel == 0.5, "The old bulk prototype ID loads as bulk ship 1 with its fuel, hull and job")
	data.ship = "ship_unknown_99"
	expect(not Snapshot.valid(data), "An unknown ship ID is still refused")

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
	if current_scene != null:
		current_scene.queue_free()
		for frame: int in 3: await process_frame
	wipe()
	for failure: String in failures: push_error(failure)
	print("BULK_LADDER_CHECK_PASS checks=%d" % checks if failures.is_empty() else "BULK_LADDER_CHECK_FAILED %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
