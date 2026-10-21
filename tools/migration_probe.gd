extends Node
var root_path: String
var phase: String
var checks: int = 0
var failures: int = 0
const REALM: String = "private_migration_test"
const CARGO: String = "cargo_test_container"

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func open_db(path: String) -> SQLite:
	var db: SQLite = SQLite.new()
	db.path = path
	db.verbosity_level = 0
	expect(db.open_db(), "Database opens")
	return db

func fingerprint(db: SQLite, tables: Array[String]) -> String:
	var records: Array = []
	for table: String in tables:
		expect(db.query("SELECT * FROM " + table + " ORDER BY 1"), "Read " + table)
		records.append(db.query_result.duplicate(true))
	return JSON.stringify(records).sha256_text()

func economic_hash(db: SQLite) -> String:
	return fingerprint(db, ["context", "snapshot", "receipts"])

func text_file(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func old_record(generation: int, fuel: int) -> Dictionary:
	# Literal Step 36 schema, independent of the new record() implementation.
	return {"version":1, "generation":generation, "realm":REALM,
		"player_id":"player_test", "ship_id":"ship_test", "owner_id":"player_test",
		"definition_id":"ship_starter_container_01", "inventory_id":"inventory_test",
		"fuel_ml":fuel, "location":GeographicAddress.normalized(10.5, -20.25, 67.89)}

func write_payload(db: SQLite, slot: int, data: Dictionary) -> void:
	var payload: String = JSON.stringify(data)
	expect(db.query_with_bindings("INSERT OR REPLACE INTO world_checkpoints VALUES(?,?,?)", [slot, payload, payload.sha256_text()]), "Write fixture payload")

func crash(stage: String) -> void:
	var selected: String = {"partial":"migration_partial", "prepared":"migration_prepared", "committed":"migration_committed"}.get(phase, "")
	if stage != selected: return
	text_file(root_path + "/" + phase + ".ready", stage)
	while true: OS.delay_msec(50)

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--migration-root="): root_path = arg.trim_prefix("--migration-root=")
		if arg.begins_with("--migration-phase="): phase = arg.trim_prefix("--migration-phase=")
	var pattern: RegEx = RegEx.new()
	pattern.compile("^user://migration-proof/[a-f0-9]{32}$")
	if pattern.search(root_path) == null or phase not in ["init", "partial", "rolledback", "prepared", "rolledback2", "committed", "verify", "compatibility"]:
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(root_path)
	match phase:
		"init":
			var economy: DurableEconomy = DurableEconomy.new()
			expect(economy.open_store(root_path + "/world.db", REALM), "Create legacy economic fixture")
			expect(economy.execute("player_test", EconomyLedger.request("paid", "purchase_container", 1, 0)).ok, "Legacy payment")
			expect(economy.execute("player_test", EconomyLedger.request("denied", "purchase_container", 2, 1)).code == "insufficient_funds", "Legacy retained failure")
			expect(economy.run("BEGIN IMMEDIATE"), "Legacy schema transaction")
			expect(economy.run("CREATE TABLE world_meta(id INTEGER PRIMARY KEY CHECK(id=1),version INTEGER NOT NULL,generation INTEGER NOT NULL)"), "Legacy header")
			expect(economy.run("INSERT INTO world_meta VALUES(1,1,7)"), "Legacy version one")
			expect(economy.run("CREATE TABLE world_checkpoints(slot INTEGER PRIMARY KEY CHECK(slot IN (1,2)),payload TEXT NOT NULL,digest TEXT NOT NULL)"), "Legacy checkpoint table")
			write_payload(economy.db, 1, old_record(7, 123456))
			write_payload(economy.db, 2, old_record(6, 234567))
			expect(economy.run("COMMIT"), "Legacy source committed")
			text_file(root_path + "/economic.sha", economic_hash(economy.db))
			economy.close_store()
			var preferences: InputPreferences = InputPreferences.new()
			preferences.master_volume = 0.37
			preferences.camera_sensitivity = 1.7
			text_file("user://preferences.json", JSON.stringify(preferences.to_data()))
			text_file(root_path + "/preferences.sha", FileAccess.get_sha256("user://preferences.json"))
		"partial", "prepared", "committed":
			var world: LocalWorldSave = LocalWorldSave.new()
			world.fault_hook = crash
			world.open_world(root_path, REALM)
			expect(false, "Expected harness termination at migration boundary")
		"rolledback", "rolledback2":
			var db: SQLite = open_db(root_path + "/world.db")
			expect(db.query("SELECT version,generation FROM world_meta"), "Read rollback header")
			expect(db.query_result[0].version == 1 and db.query_result[0].generation == 7, "Header remains entirely v1")
			expect(db.query("SELECT payload FROM world_checkpoints ORDER BY slot"), "Read both rollback records")
			for row: Dictionary in db.query_result:
				var record: Dictionary = JSON.parse_string(row.payload)
				expect(record.version == 1 and record.size() == 10, "No partial migrated fields")
			expect(economic_hash(db) == FileAccess.get_file_as_string(root_path + "/economic.sha"), "Economy untouched after interruption")
			db.close_db()
		"verify":
			var world: LocalWorldSave = LocalWorldSave.new()
			expect(world.open_world(root_path, REALM), "Migrated world opens")
			expect(world.current.version == 2 and world.generation == 8, "Version and generation advance once")
			expect(world.current.cargo_definition_id == CARGO and world.current.restart_policy == "neutral_v1", "Explicit cargo and restart policy")
			var stored_legacy: Dictionary = JSON.parse_string(JSON.stringify(old_record(7, 123456)))
			expect(world.current.fuel_ml == 123456 and world.current.location == stored_legacy.location, "Stored pose and fuel preserved exactly")
			expect(world.current.ship_id == "ship_test" and world.current.owner_id == "player_test", "Stable ownership preserved")
			expect(economic_hash(world.economy.db) == FileAccess.get_file_as_string(root_path + "/economic.sha"), "All money cargo and receipts unchanged")
			expect(world.authority.request_economy("player_test", "ship_test", EconomyLedger.request("paid", "purchase_container", 1, 0)).receipt.duplicate, "Old successful receipt remains idempotent")
			expect(world.authority.request_economy("player_test", "ship_test", EconomyLedger.request("denied", "purchase_container", 2, 1)).code == "insufficient_funds", "Old failure remains terminal")
			world.close_world()
			var again: LocalWorldSave = LocalWorldSave.new()
			expect(again.open_world(root_path, REALM) and again.generation == 8, "Reopening does not migrate again")
			again.close_world()
			var backup: SQLite = open_db(root_path + "/pre1.db")
			expect(backup.query("SELECT version FROM world_meta") and backup.query_result[0].version == 1, "Pre-upgrade backup keeps old schema")
			expect(economic_hash(backup) == FileAccess.get_file_as_string(root_path + "/economic.sha"), "Backup preserves original economy")
			backup.close_db()
		"compatibility":
			compatibility_checks()
			await ui_checks()
	expect(FileAccess.get_sha256("user://preferences.json") == FileAccess.get_file_as_string(root_path + "/preferences.sha"), "Preferences remain byte-identical")
	if failures == 0: print("MIGRATION_PHASE_PASS ", phase, " (", checks, " checks)")
	get_tree().quit(0 if failures == 0 else 1)

func compatibility_checks() -> void:
	var source: SQLite = open_db(root_path + "/world.db")
	for case: String in ["ship", "cargo", "pack", "future", "record", "legacy"]:
		var folder: String = root_path + "/" + case.left(1)
		DirAccess.make_dir_recursive_absolute(folder)
		expect(source.backup_to(folder + "/world.db"), "Copy compatibility fixture")
		var db: SQLite = open_db(folder + "/world.db")
		expect(db.query("SELECT payload FROM world_checkpoints WHERE slot=1"), "Read content fixture")
		var data: Dictionary = JSON.parse_string(db.query_result[0].payload)
		var expected: String = ""
		match case:
			"ship":
				data.definition_id = "ship_missing"
				expected = "ship_missing"
			"cargo":
				data.cargo_definition_id = "cargo_missing"
				expected = "cargo_missing"
			"pack": expected = CARGO
			"future":
				expect(db.query("UPDATE world_meta SET version=99"), "Newer header")
				expected = "unsupported"
			"record":
				data.version = 99
				expected = "Unsupported"
			"legacy":
				expect(db.query("UPDATE world_meta SET version=1,generation=7"), "Legacy header for missing content")
				data = old_record(7, 123456)
				data.definition_id = "ship_missing"
				write_payload(db, 2, old_record(6, 234567))
				expected = "ship_missing"
		write_payload(db, 1, data)
		var before: String = fingerprint(db, ["world_meta", "world_checkpoints", "context", "snapshot", "receipts"])
		db.close_db()
		var blocked: LocalWorldSave = LocalWorldSave.new()
		if case == "pack": blocked.catalog._records.erase(CARGO)
		expect(not blocked.open_world(folder, REALM), "Missing/unsupported content blocks " + case)
		expect(expected in blocked.message, "Actionable message names ID/version " + case)
		expect(not blocked.authority._ledger.usable, "No invented replacement wallet")
		blocked.close_world()
		expect(db.open_db(), "Reinspect blocked save")
		expect(fingerprint(db, ["world_meta", "world_checkpoints", "context", "snapshot", "receipts"]) == before, "Every progress record preserved " + case)
		db.close_db()
	source.close_db()

func ui_checks() -> void:
	# Real menu/default slot, inside the harness's isolated APPDATA only.
	var fixture: LocalWorldSave = LocalWorldSave.new()
	expect(fixture.open_world(), "Create isolated menu fixture")
	var data: Dictionary = fixture.current.duplicate(true)
	data.cargo_definition_id = "cargo_missing"
	write_payload(fixture.economy.db, 1, data)
	var before: String = fingerprint(fixture.economy.db, ["world_meta", "world_checkpoints", "context", "snapshot", "receipts"])
	fixture.close_world()
	var app: Node = load("res://features/main/main.tscn").instantiate()
	add_child(app)
	app.navigate("play")
	expect(app.session == null, "Invalid save never launches a replacement session")
	expect(app.menu.save_notice.is_visible_in_tree() and "cargo_missing" in app.menu.save_notice.text, "Menu visibly explains missing cargo")
	app.queue_free()
	await get_tree().process_frame
	var db: SQLite = open_db(LocalWorldSave.DEFAULT_ROOT + "/world.db")
	expect(fingerprint(db, ["world_meta", "world_checkpoints", "context", "snapshot", "receipts"]) == before, "Menu failure preserves all progress")
	db.close_db()
