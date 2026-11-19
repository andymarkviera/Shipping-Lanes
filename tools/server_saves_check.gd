extends SceneTree
## Synthetic fixtures only. Never opens the default dedicated folder.
const Store = preload("res://features/network/server_save_store.gd")
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
var checks: int = 0
var failures: int = 0
var folder: String = "user://server-save-check-" + str(Time.get_ticks_usec())

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var store = Store.new()
	check(store.open_store(folder), "fresh isolated store")
	var second = Store.new()
	check(not second.open_store(folder), "second writer refused")
	check(not second.locked, "second writer does not own first lock")
	second.close()
	check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder) + ".lock"), "failed second open cannot unlock owner")
	store.close()
	# Every retained 3.x fixture is opened by the real startup migration path.
	var fixtures: int = 0
	for fixture: String in DirAccess.get_files_at("res://tools/fixtures/server_saves"):
		if not fixture.ends_with(".json"): continue
		fixtures += 1
		var path: String = folder.path_join(fixture.trim_suffix(".json"))
		DirAccess.make_dir_recursive_absolute(path)
		DirAccess.copy_absolute("res://tools/fixtures/server_saves/" + fixture, path.path_join("world.json"))
		var original: String = FileAccess.get_file_as_string(path.path_join("world.json"))
		var migrated = Store.new()
		check(migrated.open_store(path), "fixture opens: " + fixture)
		check(migrated.players.size() == 1, "fixture captain retained: " + fixture)
		if fixture.begins_with("pre"):
			var backups: PackedStringArray = DirAccess.get_directories_at(path.path_join("backups"))
			check(backups.size() == 1, "exactly one pre-migration backup")
			check(FileAccess.get_file_as_string(path.path_join("backups").path_join(backups[0]).path_join("world.json")) == original, "migration backup is byte-exact")
		var before: Dictionary = migrated.players.duplicate(true)
		for index: int in 7:
			check(migrated.checkpoint() and migrated.finish(), "worker checkpoint " + fixture)
		check(DirAccess.get_directories_at(path.path_join("backups")).size() == 5, "last five complete backups retained")
		migrated.close()
		var reopened = Store.new()
		check(reopened.open_store(path), "restart: " + fixture)
		check(reopened.players == before, "all cargo, fleet, money, pose and receipts retained")
		reopened.close()
		if fixture.begins_with("pre"):
			var raw: Dictionary = JSON.parse_string(original)
			check(raw.schema_version == 0, "ordered migration source fixture")
	check(fixtures >= 2, "frozen pre-release and baseline 3.0 fixtures present")
	# An unavailable backup destination must prevent migration and any rewrite.
	var blocked_path: String = folder.path_join("backup-blocked")
	DirAccess.make_dir_recursive_absolute(blocked_path)
	DirAccess.copy_absolute("res://tools/fixtures/server_saves/pre-3.0.json", blocked_path.path_join("world.json"))
	var original: String = FileAccess.get_file_as_string(blocked_path.path_join("world.json"))
	var blocker: FileAccess = FileAccess.open(blocked_path.path_join("backups"), FileAccess.WRITE)
	blocker.store_string("synthetic blocker")
	blocker.close()
	var blocked_store = Store.new()
	check(not blocked_store.open_store(blocked_path), "failed backup prevents migration")
	blocked_store.close()
	check(FileAccess.get_file_as_string(blocked_path.path_join("world.json")) == original, "backup failure leaves original untouched")
	var write_path: String = folder.path_join("write-blocked")
	DirAccess.make_dir_recursive_absolute(write_path)
	DirAccess.copy_absolute("res://tools/fixtures/server_saves/3.0.json", write_path.path_join("world.json"))
	var write_store = Store.new()
	check(write_store.open_store(write_path), "open worker failure fixture")
	var original_write: String = FileAccess.get_file_as_string(write_path.path_join("world.json"))
	DirAccess.make_dir_absolute(write_path.path_join("world.json.tmp"))
	check(write_store.checkpoint() and not write_store.finish(), "failed worker commit is reported")
	check(FileAccess.get_file_as_string(write_path.path_join("world.json")) == original_write, "failed commit preserves previous checkpoint")
	check(not write_store.checkpoint(), "failed writer refuses further checkpoints")
	write_store.close()
	# Refuse malformed/newer saves without rewriting one byte.
	for bad: String in ["{broken", "{}", JSON.stringify({"schema_version": 99, "payload": "", "sha256": "bad"})]:
		var path: String = folder.path_join("bad" + str(checks))
		DirAccess.make_dir_recursive_absolute(path)
		var file: FileAccess = FileAccess.open(path.path_join("world.json"), FileAccess.WRITE)
		file.store_string(bad)
		file.close()
		var broken = Store.new()
		check(not broken.open_store(path), "invalid save blocks boot")
		broken.close()
		check(FileAccess.get_file_as_string(path.path_join("world.json")) == bad, "invalid original untouched")
	var newer: Dictionary = {"schema_version": 99, "players": {}}
	check(Store.migrate(newer).is_empty(), "future schemas refused")
	check(Store.migrate({"schema_version": -1}).is_empty(), "negative schema refused")
	var interrupted: String = folder.path_join("interrupted")
	DirAccess.make_dir_recursive_absolute(interrupted)
	var temp: FileAccess = FileAccess.open(interrupted.path_join("world.json.tmp"), FileAccess.WRITE)
	temp.store_string("checkpoint in flight")
	temp.close()
	var orphan = Store.new()
	check(not orphan.open_store(interrupted), "interrupted initial commit cannot reset")
	orphan.close()
	print("SERVER_SAVES_PASS checks=%d" % checks if failures == 0 else "SERVER_SAVES_FAILED")
	quit(1 if failures else 0)
