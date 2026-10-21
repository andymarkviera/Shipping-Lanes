class_name PrivateSaveSlots
extends RefCounted
## Three isolated local development slots. Never replaces a progression database.
const IDS: Array[String] = ["private_development", "private_slot_2", "private_slot_3"]
var base: String = "user://worlds"
var message: String = ""

func folder(index: int) -> String:
	return base + "/" + IDS[index] if index >= 0 and index < IDS.size() else ""

func occupied(index: int) -> bool:
	var path: String = folder(index)
	return DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path)

func status(index: int) -> String:
	var path: String = folder(index)
	if path.is_empty(): return "Invalid slot"
	if FileAccess.file_exists(path + "/recovery.pending"): return "Recovery incomplete - original slot preserved"
	if not occupied(index): return "New — empty slot"
	if not FileAccess.file_exists(path + "/world.db"):
		return "Recovery available — main save missing" if FileAccess.file_exists(path + "/world.backup.db") else "Unavailable — folder has no main save"
	var db: SQLite = SQLite.new()
	db.path = path + "/world.db"
	db.verbosity_level = 0
	if not db.open_db(): return "Unreadable — progress preserved"
	var result: String = "Unreadable — progress preserved"
	db.query("PRAGMA query_only=ON")
	if not db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='world_meta'") or db.query_result.is_empty():
		db.close_db()
		return "Recovery required - world header missing"
	if db.query("SELECT version FROM world_meta WHERE id=1") and db.query_result.size() == 1:
		var version: int = db.query_result[0].version
		if version not in [1, LocalWorldSave.VERSION]:
			result = "Incompatible — use a matching build"
		else:
			var probe: LocalWorldSave = LocalWorldSave.new()
			probe.realm = LocalWorldSave.DEFAULT_REALM
			probe.economy = DurableEconomy.new()
			probe.economy.db = db
			var record: Dictionary = probe.read_slot(1, version)
			result = "Existing — ready to load" if not record.is_empty() else "Recovery required — checkpoint damaged"
			if version == 1 and not record.is_empty(): result = "Existing — upgrade available"
			if probe.incompatible: result = "Incompatible — " + probe.incompatibility
	db.close_db()
	if FileAccess.file_exists(path + "/world.backup.db"): result += "\nBackup available"
	return result

func create_new(index: int) -> bool:
	if FileAccess.file_exists(base):
		message = "Cannot create save folder. No new game was saved."
		return false
	if folder(index).is_empty() or occupied(index):
		message = "Choose an empty slot. Existing progress will not be replaced."
		return false
	var world: LocalWorldSave = LocalWorldSave.new()
	var ok: bool = world.open_world(folder(index))
	message = "New local game created." if ok else world.message
	world.close_world()
	return ok

func recover(source: int, destination: int) -> bool:
	if folder(source).is_empty() or folder(destination).is_empty() or occupied(destination):
		message = "Recovery needs an empty destination slot. Existing saves are preserved."
		return false
	var backup: String = folder(source) + "/world.backup.db"
	if not FileAccess.file_exists(backup):
		message = "No checkpoint backup is available for this slot."
		return false
	if DirAccess.make_dir_recursive_absolute(folder(destination)) != OK:
		message = "Cannot create recovery destination. No save was restored."
		return false
	var marker: FileAccess = FileAccess.open(folder(destination) + "/recovery.pending", FileAccess.WRITE)
	if marker == null:
		message = "Cannot write recovery marker. No save was restored."
		return false
	marker.store_string("Copy must validate before use.")
	marker.close()
	var db: SQLite = SQLite.new()
	db.path = backup
	db.verbosity_level = 0
	var copied: bool = db.open_db() and db.query("PRAGMA query_only=ON") and db.backup_to(folder(destination) + "/world.db")
	db.close_db()
	if not copied:
		message = "Backup could not be copied. Original progress is preserved."
		return false
	var world: LocalWorldSave = LocalWorldSave.new()
	world.validating_recovery = true
	var ok: bool = world.open_world(folder(destination))
	message = "Backup restored into a separate slot. Progress is from that backup's time." if ok else "Copied backup cannot load: " + world.message
	world.close_world()
	if ok and DirAccess.remove_absolute(folder(destination) + "/recovery.pending") != OK:
		message = "Recovery validated but could not be finalized. Original progress is preserved."
		return false
	return ok
