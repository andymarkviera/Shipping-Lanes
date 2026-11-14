extends SceneTree
## Patch 2.2 item 1: container ships 1-5. Checks the ladder data (speed, size,
## capacity, price), the tier jobs, old save IDs, and in the real game scene
## that every ship spawns, wears its own model and docks at every port with
## no hull in the quay. Isolated save folder; never the player's save.
## Run: godot --headless --path . --script res://tools/container_ladder_check.gd

const FOLDER: String = "user://container_ladder_check"
const Progression = preload("res://features/game/progression.gd")
const Offers = preload("res://features/cargo/container_offers.gd")
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const KNOTS: Array[float] = [30.0, 33.0, 36.0, 39.0, 42.0]
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
		var kind: String = Progression.CONTAINER_KINDS[tier - 1]
		var ship: ShipDefinition = Progression.definition(kind)
		expect(ship != null and ship.handling_error().is_empty(), "%s record is valid" % kind)
		var knots: float = ship.forward_acceleration_mps2 / ship.linear_drag_per_second / 0.514444
		expect(absf(knots - KNOTS[tier - 1]) < 0.05, "%s tops out at %.0f kn (got %.2f)" % [kind, KNOTS[tier - 1], knots])
		var capacity: int = Progression.container_capacity(tier)
		expect(ship.container_layout != null and ship.container_layout.valid() and ship.container_layout.centres.size() >= capacity, "%s layout shows every container" % kind)
		expect(PrototypeCatalog.RECORDS.has(ship) or tier == 1, "%s is in the catalog" % kind)
		expect(Progression.ladder_kind(ship.id) == kind and Progression.container_tier(kind) == tier, "%s record ID maps to its kind" % kind)
		if last != null:
			expect(ship.hull_size_m.z > last.hull_size_m.z and ship.hull_size_m.x >= last.hull_size_m.x, "%s is bigger than the ship before" % kind)
			expect(ship.linear_drag_per_second < last.linear_drag_per_second, "%s takes longer to reach full speed" % kind)
			expect(ship.max_turn_rate_degrees < last.max_turn_rate_degrees and ship.reverse_acceleration_mps2 < last.reverse_acceleration_mps2, "%s turns wider and stops slower" % kind)
			expect(turn_radius_m(ship) > turn_radius_m(last), "%s turning circle is wider than the ship before" % kind)
			expect(capacity > Progression.container_capacity(tier - 1), "%s carries more" % kind)
			expect(int(Progression.SHIPS[kind].price_minor) > int(Progression.SHIPS[Progression.CONTAINER_KINDS[tier - 2]].price_minor) * 2, "%s costs far more" % kind)
			expect(ship.fuel_full_output_lps > last.fuel_full_output_lps and ship.camera_distance_m > last.camera_distance_m and ship.wake_half_length_m > last.wake_half_length_m, "%s burns more and has a bigger camera and wake" % kind)
		# Fits on the berth centreline without touching the quay face at x = 20.
		expect(ship.hull_size_m.x / 2.0 < 20.0, "%s clears the quay face" % kind)
		var full: Manifest = Manifest.new(ship, PrototypeCatalog.RECORDS)
		var line: Dictionary = {"batch_id": "b", "cargo_id": "cargo_test_container", "quantity": capacity, "unit": "count", "origin_port_id": "port_brindle_quay", "destination_port_id": "port_slatewater_works", "acquisition_id": "", "job_id": "j"}
		expect(full.validate([line]).is_empty(), "%s holds a full load of %d" % [kind, capacity])
		# Patch 2.4 item 2: no ship feels like a slog (full-speed, full-rudder radius).
		expect(turn_radius_m(ship) <= 460.0, "%s turns within 460 m at full speed (got %.0f m)" % [kind, turn_radius_m(ship)])
		last = ship
	expect(abs(KNOTS[4] - 42.0) < 0.01 and Progression.definition("container_5").hull_size_m.z >= 4.0 * 64.0, "Ship 5 is several times the starter")
	# Every berth fits ship 5.
	var biggest: Vector3 = Progression.definition("container_5").hull_size_m
	for scene: PackedScene in preload("res://features/ports/port_test.gd").PORTS + preload("res://features/ports/port_test.gd").GAME_PORTS:
		var state: SceneState = scene.get_state()
		for index: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, index) == "berth":
				var berth: BerthDefinition = state.get_node_property_value(0, index)
				expect(biggest.z + 2.0 * berth.clearance_margin_m <= berth.envelope_m.z and biggest.x + 2.0 * berth.clearance_margin_m <= berth.envelope_m.x, berth.id + " fits ship 5")

func check_jobs() -> void:
	expect(Offers.loading_seconds(24) == 25.5 and Offers.loading_seconds(3) == 15.0, "Starter loading times unchanged")
	expect(Offers.loading_seconds(288) < 70.0 and Offers.loading_seconds(288) > Offers.loading_seconds(180), "Big loads are quicker per box but still longer")
	var offers = Offers.new()
	offers._offers.clear()
	offers.restock()
	for port: int in Progression.WORLD.size():
		var top: Array[int] = [0, 0, 0, 0, 0, 0]
		for row: Dictionary in offers.list_at(Progression.WORLD[port].id):
			var tier: int = Offers.job_tier(row.id)
			expect(tier >= 1 and int(row.quantity) <= Progression.container_capacity(tier), row.id + " fits the ship it was sized for")
			expect(Offers.fresh(row.id, true) == row, row.id + " rebuilds from its ID")
			top[tier] = maxi(top[tier], int(row.quantity))
		for tier: int in range(2, 6):
			expect(top[tier] == Progression.container_capacity(tier), "Port %d offers a full load for ship %d" % [port, tier])
	var big: Dictionary = Offers.fresh("container_t5_0_1_0", true)
	var small: Dictionary = Offers.fresh("container_load_0_2_0", true)
	var rate: Callable = func(job: Dictionary) -> float: return float(job.reward_minor) / job.quantity / Progression.leg_units(Progression.port_index(job.origin_port_id), Progression.port_index(job.destination_port_id))
	expect(rate.call(big) > rate.call(small) * 1.3, "A ship 5 job pays more per container and 100 m than a starter job")
	expect(Offers.fresh("container_t6_0_1_0", true).is_empty() and Offers.fresh("container_t5_0_2_0", true).is_empty(), "Unknown tier IDs are refused")

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

func dock_everywhere(game: Node) -> void:
	for tier: int in range(1, 6):
		var kind: String = Progression.CONTAINER_KINDS[tier - 1]
		game.ship_kind = kind
		game.fleet[kind] = {"fuel": 1.0, "condition": 1.0}
		for index: int in game.world_ports.size():
			if not expect(game.select_port(index), "%s spawns at port %d" % [kind, index]): continue
			var ship: HandlingShip = game.ship
			var port: Node3D = game.world_ports[index]
			expect(ship.definition.id == Progression.definition(kind).id, "%s sails its own record" % kind)
			expect(ship.assembly.visual.find_child("ChunkyShip", true, false) != null, "%s wears its toon model" % kind)
			expect(is_equal_approx(game.camera.distance_order, ship.definition.camera_distance_m) and game.wake.half_length == ship.definition.wake_half_length_m, "%s camera and wake fit the hull" % kind)
			for frame: int in 2: await physics_frame
			ship.global_transform = port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
			ship.velocity = Vector3.ZERO
			for frame: int in 2: await physics_frame
			var result: Dictionary = game.docking.request_dock(1, "container_transfer", "cargo_test_container")
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
		# The board at the last port: nothing too big, the ship's own jobs first.
		game.refresh_jobs()
		var room: int = Progression.container_capacity(tier)
		var full_load: bool = false
		for card: Dictionary in game.job_cards:
			expect(int(card.count) <= room, "%s is never offered %d containers" % [kind, card.count])
			full_load = full_load or int(card.count) == room
		expect(not game.job_cards.is_empty() and game.offers.job_tier(game.job_cards[0].id) == tier and full_load and game.job_cards.size() <= game.JOB_BOARD_SIZE, "%s sees its own jobs first, a full load among them" % kind)
		var data: Dictionary = Snapshot.capture(game)
		expect(data.ship == kind and Snapshot.valid(data), "%s save is valid" % kind)

func check_old_ids(game: Node) -> void:
	game.ship_kind = "container_2"
	game.fleet = {"container": {"fuel": 1.0, "condition": 1.0}, "container_2": {"fuel": 0.5, "condition": 0.9}}
	expect(game.select_port(0), "Coastal feeder spawns for the save check")
	var data: Dictionary = Snapshot.capture(game)
	data.ship = "ship_coastal_container_01"
	data.fleet = {"ship_starter_container_01": {"fuel": 1.0, "condition": 1.0}, "ship_coastal_container_01": {"fuel": 0.5, "condition": 0.9}}
	expect(Snapshot.valid(data) and data.ship == "container_2" and data.fleet.has("container") and data.fleet.container_2.fuel == 0.5, "Old record IDs load as ladder ships with their fuel and hull")
	data.ship = "ship_unknown_99"
	expect(not Snapshot.valid(data), "An unknown ship ID is still refused")

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
	print("LADDER_CHECK_PASS checks=%d" % checks if failures.is_empty() else "LADDER_CHECK_FAILED %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
