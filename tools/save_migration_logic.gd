extends RefCounted
## Patch 4.0.6 item 2: the save-migration check. Every save schema the game
## has written since 3.0, plus the older local ones it still reads, is
## generated here in code (no real save is committed), written to an isolated
## user:// folder in its own old format, and opened by the real stores:
## - local game saves (features/cargo/voyage_store.gd, voyage.db): voyage
##   version 3 (M2), version 4 (M3: ship, fleet, delivered bulk jobs), version
##   5 (M4 to now: the bank), and a 3.2 version 5 that sails the retired
##   fishing boat (refunded at its full price on load);
## - dedicated server saves (features/network/server_save_store.gd,
##   world.json): schema 0 (pre-release 3.0 "captains"), schema 1 (3.0-3.2),
##   schema 2 (4.0 on, with levels and planes).
## Each must open, validate, keep wallet = earned - spent, land on the current
## format and stay there when saved again; a future or damaged save is refused
## and preserved. check_catalog.gd runs this; patch_4_0_6_check.gd also loads
## the local saves in the real game scene.
const Codec = preload("res://features/cargo/voyage_snapshot.gd")
const Store = preload("res://features/cargo/voyage_store.gd")
const ServerStore = preload("res://features/network/server_save_store.gd")
const Offers = preload("res://features/cargo/container_offers.gd")
const Progression = preload("res://features/game/progression.gd")
const Levels = preload("res://features/game/levels.gd")
const FOLDER: String = "user://save_migration_logic"
const PARTS: Array[String] = ["local_saves", "local_refusals", "dedicated_saves", "dedicated_refusals", "frozen_fixtures"]
const LOCAL: Array[String] = ["v3", "v4", "v5", "v5_fishing"]
const POSE: Vector3 = Vector3(-3590, 0, -680)
var failures: Array[String] = []
var checks: int = 0

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

static func run_all() -> PackedStringArray:
	var suite: RefCounted = new()
	for part: String in PARTS: suite.call_part(part)
	return suite.failures

func call_part(part: String) -> void:
	call(part)

## A folder emptied (files and sub-folders) for one fixture.
static func clean(path: String) -> String:
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute): ServerStore.remove_folder(absolute)
	if DirAccess.dir_exists_absolute(absolute + ".lock"): DirAccess.remove_absolute(absolute + ".lock")
	DirAccess.make_dir_recursive_absolute(absolute)
	return path

## One offer delivered by the captain, its pay in the wallet.
static func deliver_one(offers: Dictionary) -> int:
	var id: String = offers.keys()[0]
	var row: Dictionary = offers[id]
	row.state = "delivered"
	row.owner_id = "preview_captain"
	row.ship_id = "preview_ship"
	row.accepted_ms = 1000
	return int(row.reward_minor)

## A local voyage as the game wrote it at `kind` (see LOCAL).
static func local_fixture(kind: String) -> Dictionary:
	var game: bool = kind.begins_with("v5")
	var source: RefCounted = Offers.new()
	if game:
		source._offers.clear()
		source.restock()
	var offers: Dictionary = source._offers.duplicate(true)
	var paid: int = deliver_one(offers)
	var d: Dictionary = {"version": 2, "realm": "private_port_voyage_v1", "owner": "preview_captain", "heavy_mode": false,
		"port": 0, "pose": Transform3D(Basis.IDENTITY, POSE), "fuel": 40.0, "condition": 0.82,
		"offers": offers, "clock": 600000, "manifest": [], "operations": {"version": 1, "records": {}},
		"loading": "", "loading_offer": "", "sequence": 3, "docked": false, "heavy": {}, "heavy_completed": {}, "credits": paid}
	if kind == "v3":
		d.version = 3
		d.spent = 1500
		d.credits = paid - d.spent
		return d
	d.version = 4
	d.spent = 2500
	d.ship = "container_2"
	d.fleet = {"container": {"fuel": 1.0, "condition": 1.0}, "container_2": {"fuel": 0.5, "condition": 0.82}}
	d.fuel = 0.5 * Progression.definition("container_2").fuel_capacity_liters
	if kind == "v4":
		# M3 listed the bulk jobs delivered; their pay is in the wallet.
		d.bulk = {"active": "", "done": ["bulk_0_grain", "bulk_1_coal"]}
		d.credits = paid + int(Progression.BULK_V4.bulk_0_grain) + int(Progression.BULK_V4.bulk_1_coal) - d.spent
		return d
	d.version = 5
	d.bulk = {"active": "", "done": []}
	d.banked = 765432
	d.credits = paid + d.banked - d.spent
	if kind == "v5_fishing":
		var price: int = int(Progression.SHIPS.small_fishing.price_minor)
		d.fleet.small_fishing = {"fuel": 0.5, "condition": 0.9}
		d.ship = "small_fishing"
		d.fuel = 0.5 * Progression.definition("small_fishing").fuel_capacity_liters
		d.spent += price
		d.credits -= price
	return d

## Writes `data` as it is (old format, no checks) into a fresh voyage.db.
static func write_local(path: String, data: Dictionary) -> String:
	var store: RefCounted = Store.new()
	store.validator = func(_any: Dictionary) -> bool: return true
	if not store.open_store(path): return store.error
	var ok: bool = store.save(data)
	store.close()
	return "" if ok else store.error

static func local_path(kind: String) -> String:
	return clean(FOLDER.path_join("local_" + kind)).path_join("voyage.db")

func local_saves() -> void:
	for kind: String in LOCAL:
		var old: Dictionary = local_fixture(kind)
		var version: int = old.version
		expect(Codec.valid(old.duplicate(true)), "local %s: the generated fixture is a save the game wrote" % kind)
		var path: String = local_path(kind)
		var wrote: String = write_local(path, old)
		if not expect(wrote.is_empty(), "local %s: written in its old format (%s)" % [kind, wrote]): continue
		var store: RefCounted = Store.new()
		var opened: bool = store.open_store(path)
		expect(opened and store.error.is_empty() and store.current.get("version") == version, "local %s: the real store opens it (%s)" % [kind, store.error])
		var loaded: Dictionary = store.current.duplicate(true)
		if not expect(Codec.valid(loaded), "local %s: it validates (and migrates)" % kind):
			store.close()
			continue
		var spent: int = int(loaded.get("spent", 0))
		var earned: int = 0
		for row: Dictionary in loaded.offers.values():
			if row.state == "delivered": earned += int(row.reward_minor)
		if version >= 4: earned += Progression.earned(loaded)
		expect(loaded.credits == earned - spent, "local %s: wallet = earned - spent (%d = %d - %d)" % [kind, loaded.credits, earned, spent])
		if version >= 4:
			expect(not loaded.fleet.has("small_fishing") and loaded.ship != "small_fishing", "local %s: no retired boat left" % kind)
			expect(Progression.SHIPS.has(loaded.ship) and loaded.fleet.has(loaded.ship), "local %s: sails a ship it owns (%s)" % [kind, loaded.ship])
		if kind == "v5_fishing":
			var price: int = int(Progression.SHIPS.small_fishing.price_minor)
			expect(loaded.credits == old.credits + price, "local %s: the fishing boat is refunded at its full price (%d)" % [kind, loaded.credits - old.credits])
			expect(loaded.ship == "container" and is_equal_approx(loaded.condition, float(loaded.fleet.container.condition)), "local %s: the captain moves to their first other ship (%s)" % [kind, loaded.ship])
		if kind == "v4":
			expect(Progression.earned(loaded) == 210000, "local v4: the delivered bulk jobs' pay is kept")
		# Saved again by the store (the game's next checkpoint) and reopened.
		expect(store.save(loaded), "local %s: the migrated save is written back (%s)" % [kind, store.error])
		store.close()
		var again: RefCounted = Store.new()
		expect(again.open_store(path) and Codec.valid(again.current.duplicate(true)) and again.revision == 2, "local %s: and opens again, unchanged in meaning" % kind)
		again.close()

func local_refusals() -> void:
	var future: Dictionary = local_fixture("v5")
	future.version = 6
	expect(not Codec.valid(future), "a save from a newer game (version 6) is refused")
	var path: String = local_path("damaged")
	expect(write_local(path, local_fixture("v5")).is_empty(), "a save to damage")
	var db: SQLite = SQLite.new()
	db.path = path
	db.verbosity_level = 0
	db.open_db()
	db.query("UPDATE voyage SET digest='0000' WHERE id=1")
	db.close_db()
	var store: RefCounted = Store.new()
	expect(not store.open_store(path) and (store.error.contains("Preserved") or store.error.contains("preserved")), "a damaged save is refused and preserved (%s)" % store.error)
	store.close()
	expect(FileAccess.file_exists(path), "the damaged save is still there")

## A captain's key (64 hex) from a name.
static func key(name: String) -> String:
	return name.sha256_text()

## A dedicated world as the server wrote it at `schema`.
static func dedicated_fixture(schema: int) -> Dictionary:
	var rows: Dictionary = {}
	for index: int in 2:
		var voyage: Dictionary = local_fixture("v5_fishing" if index == 1 else "v5")
		var row: Dictionary = {"captain": "Synthetic %d" % index, "voyage": voyage}
		if schema >= 2:
			var progress: Dictionary = Levels.fresh_progress()
			progress.xp = 1234 * (index + 1)
			row.progress = progress
			# Schema 2 is written after 4.0 retired the fishing boat.
			if index == 1: Progression.retire_ships(voyage)
		rows[key("captain-%d" % index)] = row
	if schema == 0: return {"schema_version": 0, "captains": rows}
	return {"schema_version": schema, "players": rows}

## Writes `data` as world.json in its own schema (the frozen envelope).
static func write_world(folder: String, data: Dictionary) -> void:
	var payload: String = Marshalls.raw_to_base64(var_to_bytes(data))
	var file: FileAccess = FileAccess.open(folder.path_join("world.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": data.schema_version, "payload": payload, "sha256": payload.sha256_text()}))
	file.close()

func dedicated_saves() -> void:
	for schema: int in range(0, ServerStore.SCHEMA_VERSION + 1):
		var old: Dictionary = dedicated_fixture(schema)
		var migrated: Dictionary = ServerStore.migrate(old)
		expect(not migrated.is_empty() and ServerStore.valid(migrated), "dedicated schema %d: migrates and is valid" % schema)
		var folder: String = clean(FOLDER.path_join("dedicated_%d" % schema))
		write_world(ProjectSettings.globalize_path(folder), old)
		var store: RefCounted = ServerStore.new()
		var opened: bool = store.open_store(folder)
		expect(opened and store.error.is_empty(), "dedicated schema %d: the real store opens it (%s)" % [schema, store.error])
		expect(store.players.size() == 2, "dedicated schema %d: both captains are kept (%d)" % [schema, store.players.size()])
		for player: String in store.players:
			var row: Dictionary = store.players[player]
			expect(Codec.valid(row.voyage.duplicate(true)) and Levels.progress_valid(row.get("progress")), "dedicated schema %d: %s's voyage and progress are valid" % [schema, row.captain])
			expect(not row.voyage.fleet.has("small_fishing"), "dedicated schema %d: no retired boat" % schema)
			var xp: int = int(row.progress.xp)
			expect(xp == (0 if schema < 2 else (1234 if row.captain.ends_with("0") else 2468)), "dedicated schema %d: XP is %s (%d)" % [schema, "kept" if schema >= 2 else "fresh", xp])
		var absolute: String = store.folder
		var backups: PackedStringArray = ServerStore.list_directories(absolute.path_join("backups"))
		expect(backups.size() == (1 if schema < ServerStore.SCHEMA_VERSION else 0) and (backups.is_empty() or backups[0].begins_with("%d-" % schema)), "dedicated schema %d: %s" % [schema, "the old save is backed up first" if schema < ServerStore.SCHEMA_VERSION else "a current save is not re-written"])
		var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(absolute.path_join("world.json")))
		expect(envelope is Dictionary and int(envelope.get("schema_version", -1)) == ServerStore.SCHEMA_VERSION, "dedicated schema %d: world.json is now schema %d" % [schema, ServerStore.SCHEMA_VERSION])
		store.close()
		var again: RefCounted = ServerStore.new()
		expect(again.open_store(folder) and again.players.size() == 2 and ServerStore.list_directories(absolute.path_join("backups")).size() == backups.size(), "dedicated schema %d: reopens without migrating again" % schema)
		again.close()

func dedicated_refusals() -> void:
	var future: Dictionary = dedicated_fixture(ServerStore.SCHEMA_VERSION)
	future.schema_version = ServerStore.SCHEMA_VERSION + 1
	expect(ServerStore.migrate(future).is_empty(), "a server save from a newer game is refused")
	var folder: String = clean(FOLDER.path_join("dedicated_future"))
	write_world(ProjectSettings.globalize_path(folder), future)
	var before: String = FileAccess.get_file_as_string(folder.path_join("world.json"))
	var store: RefCounted = ServerStore.new()
	expect(not store.open_store(folder) and not store.error.is_empty(), "the store refuses to boot on it (%s)" % store.error)
	store.close()
	expect(FileAccess.get_file_as_string(folder.path_join("world.json")) == before, "and preserves it untouched")
	var broken: Dictionary = dedicated_fixture(1)
	broken.players.values()[0].voyage.credits += 1
	expect(ServerStore.migrate(broken).is_empty() or not ServerStore.valid(ServerStore.migrate(broken)), "a server save whose wallet does not add up is refused")

## The frozen 3.x fixtures in tools/fixtures/server_saves (synthetic, made by
## check_server_saves.py --generate-fixtures) still migrate.
func frozen_fixtures() -> void:
	for name: String in ["pre-3.0.json", "3.0.json", "3.2-fishing.json"]:
		var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/server_saves/" + name))
		if not expect(envelope is Dictionary and envelope.get("payload") is String, "%s is present" % name): continue
		var raw: Variant = bytes_to_var(Marshalls.base64_to_raw(str(envelope.payload)))
		var migrated: Dictionary = ServerStore.migrate(raw) if raw is Dictionary else {}
		expect(not migrated.is_empty() and ServerStore.valid(migrated), "%s migrates and is valid" % name)
