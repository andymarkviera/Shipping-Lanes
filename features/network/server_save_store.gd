extends RefCounted
## Dedicated saves only. Frozen 3.0 envelope; append migrations, never replace
## earlier steps. Variant bytes contain values only (objects are never decoded).
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
const SCHEMA_VERSION: int = 1 # Patch 3.0 baseline. Keep every 3.x fixture forever.
const MAX_BYTES: int = 64000000
var folder: String
var players: Dictionary = {}
var error: String = ""
var worker: Thread
var locked: bool = false

static func key_valid(key: String) -> bool:
	return key.length() == 64 and key.is_valid_hex_number(false)

static func migrate(data: Dictionary) -> Dictionary:
	if not data.get("schema_version") is int or data.schema_version < 0 or data.schema_version > SCHEMA_VERSION: return {}
	var result: Dictionary = data.duplicate(true)
	while result.schema_version < SCHEMA_VERSION:
		match result.schema_version:
			0: # Pre-release 3.0 fixture: captains became player records.
				if not result.get("captains") is Dictionary: return {}
				result.players = result.captains
				result.erase("captains")
				result.schema_version = 1
			_: return {} # Missing migration: refuse to boot, never initialize over it.
	return result

static func valid(data: Dictionary) -> bool:
	if data.size() != 2 or data.get("schema_version") != SCHEMA_VERSION or not data.get("players") is Dictionary: return false
	for key: Variant in data.players:
		if not key is String or not key_valid(key): return false
		var row: Variant = data.players[key]
		if not row is Dictionary or row.size() != 2 or not row.get("captain") is String or not row.get("voyage") is Dictionary: return false
		if not Snapshot.valid(row.voyage): return false
	return true

func open_store(path: String) -> bool:
	folder = ProjectSettings.globalize_path(path).simplify_path()
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return fail("Cannot create dedicated saves folder.")
	# Atomic directory creation excludes a second server. A crash leaves this
	# guard for the operator to inspect/remove; never guess that another writer died.
	if DirAccess.make_dir_absolute(folder + ".lock") != OK: return fail("Dedicated saves locked; inspect the stopped server before removing saves.lock.")
	locked = true
	var file: String = folder.path_join("world.json")
	if not FileAccess.file_exists(file):
		if not list_files(folder).is_empty() or not list_directories(folder).is_empty(): return fail("Unrecognized/interrupted save folder preserved; refusing a fresh world.")
		return write_document({"schema_version": SCHEMA_VERSION, "players": {}})
	var handle: FileAccess = FileAccess.open(file, FileAccess.READ)
	if handle == null or handle.get_length() > MAX_BYTES: return fail("Cannot read dedicated save; preserved.")
	var json: JSON = JSON.new()
	var parsed: Error = json.parse(handle.get_as_text())
	handle.close()
	if parsed != OK: return fail("Damaged dedicated save JSON; preserved, no reset.")
	var envelope: Variant = json.data
	if not envelope is Dictionary or not envelope.get("payload") is String or not envelope.get("sha256") is String or envelope.payload.sha256_text() != envelope.sha256: return fail("Damaged dedicated save; preserved, no reset.")
	var decoded: Variant = bytes_to_var(Marshalls.base64_to_raw(envelope.payload))
	if not decoded is Dictionary or decoded.get("schema_version") != envelope.get("schema_version"): return fail("Invalid dedicated schema; preserved.")
	var data: Dictionary = migrate(decoded)
	if not valid(data): return fail("Unsupported or inconsistent dedicated save; preserved, no reset.")
	if decoded.schema_version != SCHEMA_VERSION:
		if not backup(int(decoded.schema_version)) or not write_document(data): return false
	players = data.players
	return true

func fail(message: String) -> bool:
	error = message
	return false

func write_document(data: Dictionary) -> bool:
	if not valid(data): return fail("Refusing invalid server checkpoint; last save preserved.")
	var payload: String = Marshalls.raw_to_base64(var_to_bytes(data))
	var text: String = JSON.stringify({"schema_version": SCHEMA_VERSION, "payload": payload, "sha256": payload.sha256_text()})
	if text.length() > MAX_BYTES: return fail("Server checkpoint exceeds size limit; last save preserved.")
	var target: String = folder.path_join("world.json")
	var temporary: String = target + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return fail("Cannot write server checkpoint; last save preserved.")
	file.store_string(text)
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(temporary, target) != OK: return fail("Cannot commit server checkpoint; last save preserved.")
	return true

func backup(version: int) -> bool:
	var base: String = folder.path_join("backups")
	if FileAccess.file_exists(base): return fail("Backup path is a file; original save preserved.")
	var name: String = "%d-%s-%020d" % [version, Time.get_datetime_string_from_system().replace(":", "-"), int(Time.get_unix_time_from_system() * 1000000)]
	var destination: String = base.path_join(name)
	if not copy_folder(folder, destination): return fail("Backup failed; original save preserved and migration/write refused.")
	# Only prune after the complete copy is durable. Incomplete copies are never
	# counted as a backup, and arbitrary operator folders are never removed.
	var marker: FileAccess = FileAccess.open(destination.path_join(".complete"), FileAccess.WRITE)
	if marker == null: return fail("Cannot finish server backup.")
	marker.store_string("Shipping Lanes server save backup")
	marker.flush()
	var marker_error: Error = marker.get_error()
	marker.close()
	if marker_error != OK: return fail("Cannot finish server backup.")
	var names: PackedStringArray = list_directories(base)
	names.sort()
	var complete: Array[String] = []
	for entry: String in names:
		if entry.get_slice("-", 0).is_valid_int() and FileAccess.file_exists(base.path_join(entry).path_join(".complete")) and FileAccess.get_file_as_string(base.path_join(entry).path_join(".complete")) == "Shipping Lanes server save backup": complete.append(entry)
	complete.sort_custom(func(a: String, b: String) -> bool: return a.substr(a.find("-") + 1) < b.substr(b.find("-") + 1))
	while complete.size() > 5:
		if not remove_folder(base.path_join(complete.pop_front())): return fail("Cannot prune old server backup.")
	return true

static func copy_folder(source: String, target: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(target) != OK: return false
	for name: String in list_files(source):
		if DirAccess.copy_absolute(source.path_join(name), target.path_join(name)) != OK: return false
	for name: String in list_directories(source):
		if name == "backups": continue
		if not copy_folder(source.path_join(name), target.path_join(name)): return false
	return true

static func remove_folder(path: String) -> bool:
	for name: String in list_files(path):
		if DirAccess.remove_absolute(path.path_join(name)) != OK: return false
	for name: String in list_directories(path):
		if not remove_folder(path.path_join(name)): return false
	return DirAccess.remove_absolute(path) == OK

func write_checkpoint(data: Dictionary) -> bool:
	return backup(SCHEMA_VERSION) and write_document(data)

func checkpoint() -> bool:
	if not finish(false) or not locked: return false
	if worker != null: return true # Bounded: at most one immutable checkpoint in flight.
	var data: Dictionary = {"schema_version": SCHEMA_VERSION, "players": players.duplicate(true)}
	worker = Thread.new()
	if worker.start(write_checkpoint.bind(data)) != OK:
		worker = null
		return fail("Cannot start server save worker.")
	return true

func finish(wait: bool = true) -> bool:
	if worker != null and (wait or not worker.is_alive()):
		var ok: bool = worker.wait_to_finish()
		worker = null
		if not ok: return false
	return error.is_empty()

func close() -> void:
	finish()
	if locked:
		DirAccess.remove_absolute(folder + ".lock")
		locked = false

static func list_files(path: String) -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null: return PackedStringArray()
	dir.include_hidden = true
	return dir.get_files()

static func list_directories(path: String) -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null: return PackedStringArray()
	dir.include_hidden = true
	return dir.get_directories()
