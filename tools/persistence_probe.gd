extends Node
var root_path: String
var phase: String
var save: LocalWorldSave
var ship: HandlingShip
var checks: int = 0
var failures: int = 0
const REALM: String = "private_persistence_test"

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func pose(position: Vector3, yaw: float, fuel_ml: int) -> void:
	ship.position = position
	ship.rotation.y = yaw
	ship.state.fuel_liters = float(fuel_ml) / 1000.0

func restored(position: Vector3, yaw: float, fuel_ml: int, wallet: int, cargo: int) -> void:
	expect(save.restore_ship(ship), "Restore physical ship")
	expect(ship.position.distance_to(position) < 0.005, "Same position in fresh process")
	expect(absf(angle_difference(ship.rotation.y, yaw)) < 0.00001, "Same heading")
	expect(absf(ship.state.fuel_liters * 1000 - fuel_ml) < 0.001, "Same fuel")
	expect(ship.state.instance_id == SessionAuthority.SHIP_ID, "Stable ship ID")
	expect(ship.commanded_throttle == 0 and ship.velocity == Vector3.ZERO, "Safe neutral restart")
	var state: Dictionary = save.authority.view()
	expect(state.player.wallet_minor == wallet, "Authoritative wallet retained")
	expect(state.inventory.cargo.cargo_test_container == cargo, "Authoritative cargo retained")
	expect(state.ship.owner_id == state.player.id, "Ownership retained")

func crash(stage: String) -> void:
	if stage != ("before_commit" if phase == "pending" else "after_commit"): return
	var file: FileAccess = FileAccess.open(root_path + "/" + phase + ".ready", FileAccess.WRITE)
	file.store_string(stage)
	file.close()
	while true: OS.delay_msec(50)

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--persistence-root="): root_path = arg.trim_prefix("--persistence-root=")
		if arg.begins_with("--persistence-phase="): phase = arg.trim_prefix("--persistence-phase=")
	var pattern: RegEx = RegEx.new()
	pattern.compile("^user://persistence-proof/[a-f0-9]{32}$")
	if pattern.search(root_path) == null or phase not in ["init", "pending", "recover", "committed", "verify", "fallback", "ui"]:
		get_tree().quit(1)
		return
	save = LocalWorldSave.new()
	expect(save.open_world(root_path, REALM), "Open versioned world: " + save.message)
	if not save.usable:
		get_tree().quit(1)
		return
	ship = HandlingShip.new()
	add_child(ship)
	ship.set_physics_process(false)
	match phase:
		"init":
			restored(Vector3.ZERO, 0, 1000000, 20000, 0)
			pose(Vector3(50, 0, 120), 0.7, 345678)
			expect(save.save_ship(ship), "Save full starter state")
			expect(FileAccess.file_exists(root_path + "/world.backup.db"), "SQLite backup retained")
			var before: int = save.generation
			expect(not save.save(GeographicAddress.normalized(0, 0), -1), "Invalid fuel rejected")
			expect(save.generation == before, "Malformed input leaves prior checkpoint")
		"pending":
			restored(Vector3(50, 0, 120), 0.7, 345678, 20000, 0)
			pose(Vector3(75, 0, 150), -1.2, 234567)
			save.fault_hook = crash
			save.save_ship(ship)
		"recover":
			restored(Vector3(50, 0, 120), 0.7, 345678, 20000, 0)
			expect(save.generation == 2, "Uncommitted generation rolled back")
			var result: Dictionary = save.authority.request_economy(SessionAuthority.PLAYER_ID, SessionAuthority.SHIP_ID, EconomyLedger.request("persist_purchase", "purchase_container", 1, 0))
			expect(result.ok, "Purchase committed independently of movement checkpoint")
			pose(Vector3(75, 0, 150), -1.2, 234567)
			expect(save.save_ship(ship), "Save second pose")
		"committed":
			restored(Vector3(75, 0, 150), -1.2, 234567, 10000, 1)
			pose(Vector3(90, 0, 180), 2.4, 123456)
			save.fault_hook = crash
			save.save_ship(ship)
		"verify":
			restored(Vector3(90, 0, 180), 2.4, 123456, 10000, 1)
			expect(save.generation == 4, "Committed generation survives lost reply")
			expect(save.authority.request_economy(SessionAuthority.PLAYER_ID, SessionAuthority.SHIP_ID, EconomyLedger.request("persist_purchase", "purchase_container", 1, 0)).receipt.duplicate, "Saved purchase cannot repeat")
			# Corrupt only the spatial record; its checksum must reject it next process.
			expect(save.economy.run("UPDATE world_checkpoints SET payload='malformed' WHERE slot=1"), "Create malformed checkpoint fixture")
		"fallback":
			expect(save.message.begins_with("Recovered"), "Recovery is reported explicitly")
			restored(Vector3(75, 0, 150), -1.2, 234567, 10000, 1)
			var other: LocalWorldSave = LocalWorldSave.new()
			expect(other.open_world(root_path, REALM), "Second host handle opens")
			expect(save.save_ship(ship), "Repair checkpoint from known-good pose")
			expect(not other.save(other.current.location, other.current.fuel_ml), "Stale host cannot overwrite save")
			other.close_world()
			var wrong: LocalWorldSave = LocalWorldSave.new()
			expect(not wrong.open_world(root_path, "private_other"), "Other private realm cannot import progress")
			wrong.close_world()
			var backup: LocalWorldSave = LocalWorldSave.new()
			var backup_folder: String = root_path + "/b"
			DirAccess.make_dir_recursive_absolute(backup_folder)
			expect(save.economy.db.backup_to(backup_folder + "/world.db"), "Database-safe test copy")
			expect(backup.open_world(backup_folder, REALM), "Backup copy restores")
			expect(backup.authority.view().player.wallet_minor == 10000, "Backup includes wallet")
			backup.close_world()
			guard_copy("v", "UPDATE world_meta SET version=99", "unsupported")
			guard_copy("c", "UPDATE world_checkpoints SET payload='broken'", "No valid")
			var missing: String = root_path + "/m"
			DirAccess.make_dir_recursive_absolute(missing)
			expect(save.economy.db.backup_to(missing + "/world.backup.db"), "Prepare missing-main fixture")
			var missing_world: LocalWorldSave = LocalWorldSave.new()
			expect(not missing_world.open_world(missing, REALM), "Missing main plus backup never starts fresh")
			expect(not FileAccess.file_exists(missing + "/world.db"), "No replacement wallet created")
			missing_world.close_world()
		"ui":
			await ui_checks()
	save.close_world()
	if failures == 0: print("PERSISTENCE_PHASE_PASS ", phase, " (", checks, " checks)")
	get_tree().quit(0 if failures == 0 else 1)

func guard_copy(label: String, mutation: String, reason: String) -> void:
	var folder: String = root_path + "/" + label
	DirAccess.make_dir_recursive_absolute(folder)
	expect(save.economy.db.backup_to(folder + "/world.db"), "Create recovery guard fixture")
	var db: SQLite = SQLite.new()
	db.path = folder + "/world.db"
	db.verbosity_level = 0
	expect(db.open_db() and db.query(mutation), "Prepare invalid world")
	db.close_db()
	var invalid: LocalWorldSave = LocalWorldSave.new()
	expect(not invalid.open_world(folder, REALM) and reason in invalid.message, "Recovery blocks safely: " + reason)
	expect(not invalid.authority._ledger.usable, "Blocked recovery cannot spend fresh money")
	invalid.close_world()
	expect(db.open_db() and db.query("SELECT player_minor FROM snapshot") and db.query_result[0].player_minor == 10000, "Blocked recovery preserves committed economy")
	db.close_db()

func ui_checks() -> void:
	# Harness APPDATA is isolated, so the real default menu slot is disposable here.
	var app: Node = load("res://features/main/main.tscn").instantiate()
	add_child(app)
	app.navigate("play")
	expect(app.persistent_world != null and app.persistent_world.usable, "Play opens persistent local authority")
	app.request_test_load()
	expect(app.session.state_view().player.wallet_minor == 10000, "Menu purchase persists")
	app.queue_free()
	await get_tree().process_frame
	var fresh: LocalWorldSave = LocalWorldSave.new()
	expect(fresh.open_world(), "Menu world reopens")
	expect(fresh.authority.view().inventory.cargo.cargo_test_container == 1, "Menu cargo survives close")
	fresh.close_world()
	get_tree().set_meta("local_save_requested", true)
	var handling: Node = load("res://features/handling/handling_test.tscn").instantiate()
	add_child(handling)
	handling.ship.set_physics_process(false)
	handling.set_process(false)
	handling.ship.position = Vector3(40, 0, 80)
	handling.ship.state.fuel_liters = 543.21
	expect(handling.save_progress(), "Playable boat checkpoint")
	handling.queue_free()
	await get_tree().process_frame
	get_tree().set_meta("local_save_requested", true)
	handling = load("res://features/handling/handling_test.tscn").instantiate()
	add_child(handling)
	handling.ship.set_physics_process(false)
	expect(handling.ship.position.distance_to(Vector3(40, 0, 80)) < 0.005, "Playable scene restores position")
	expect(absf(handling.ship.state.fuel_liters - 543.21) < 0.0011, "Playable scene restores fuel")
	handling.queue_free()
	await get_tree().process_frame
