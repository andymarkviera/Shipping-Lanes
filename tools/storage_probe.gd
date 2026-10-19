extends Node
## Disposable storage proof only. Never opens a gameplay save.
var db: SQLite
var root_path: String
var phase: String
var failures: int = 0

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func sql(statement: String) -> void:
	expect(db.query(statement), statement + ": " + db.error_message)

func scalar(statement: String) -> Variant:
	sql(statement)
	return db.query_result[0].values()[0] if not db.query_result.is_empty() else null

func pair(a: int, b: int) -> void:
	expect(scalar("SELECT value FROM fixture WHERE id=1") == a, "First record")
	expect(scalar("SELECT value FROM fixture WHERE id=2") == b, "Second record")

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--storage-root="):
			root_path = arg.trim_prefix("--storage-root=")
		if arg.begins_with("--storage-phase="):
			phase = arg.trim_prefix("--storage-phase=")
	var pattern: RegEx = RegEx.new()
	pattern.compile("^user://storage-proof/[a-f0-9]{32}$")
	if pattern.search(root_path) == null or not phase in ["init", "pending", "recover", "committed", "verify"]:
		push_error("Storage probe requires isolated root and known phase")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(root_path)
	db = SQLite.new()
	db.path = root_path + "/fixture.db"
	db.verbosity_level = 0
	expect(db.open_db(), "Database opens")
	expect(scalar("PRAGMA journal_mode=WAL") == "wal", "WAL enabled")
	sql("PRAGMA synchronous=FULL")
	expect(scalar("PRAGMA synchronous") == 2, "Full synchronization")
	sql("PRAGMA foreign_keys=ON")
	match phase:
		"init":
			print("SQLite version: ", scalar("SELECT sqlite_version()"))
			sql("CREATE TABLE fixture(id INTEGER PRIMARY KEY, value INTEGER NOT NULL, label TEXT NOT NULL)")
			sql("PRAGMA user_version=1")
			expect(db.query_with_bindings("INSERT INTO fixture VALUES(?,?,?),(?,?,?)", [1,10,"quoted ' text",2,20,"second"]), "Parameter binding")
			expect(scalar("SELECT label FROM fixture WHERE id=1") == "quoted ' text", "Bound text round trip")
			sql("BEGIN IMMEDIATE")
			sql("UPDATE fixture SET value=11 WHERE id=1")
			sql("UPDATE fixture SET value=19 WHERE id=2")
			sql("ROLLBACK")
			pair(10,20)
			sql("BEGIN IMMEDIATE")
			sql("UPDATE fixture SET value=12 WHERE id=1")
			sql("UPDATE fixture SET value=18 WHERE id=2")
			sql("COMMIT")
			pair(12,18)
			# Schema change and revision advance are a single atomic transaction.
			sql("BEGIN IMMEDIATE")
			sql("ALTER TABLE fixture ADD COLUMN note TEXT NOT NULL DEFAULT 'migrated'")
			sql("PRAGMA user_version=2")
			sql("ROLLBACK")
			expect(scalar("PRAGMA user_version") == 1, "Rolled-back migration revision")
			expect(scalar("SELECT count(*) FROM pragma_table_info('fixture') WHERE name='note'") == 0, "Rolled-back migration schema")
			sql("BEGIN IMMEDIATE")
			sql("ALTER TABLE fixture ADD COLUMN note TEXT NOT NULL DEFAULT 'migrated'")
			sql("PRAGMA user_version=2")
			sql("COMMIT")
			expect(scalar("PRAGMA user_version") == 2, "Migration revision")
			expect(scalar("SELECT note FROM fixture WHERE id=1") == "migrated", "Migration data preserved")
			expect(db.backup_to(root_path + "/backup.db"), "Online database backup")
			sql("UPDATE fixture SET value=99")
			expect(db.restore_from(root_path + "/backup.db"), "Database restore")
			pair(12,18)
		"pending":
			pair(12,18)
			sql("PRAGMA cache_size=10")
			sql("BEGIN IMMEDIATE")
			sql("UPDATE fixture SET value=999")
			sql("CREATE TABLE crash_payload(data BLOB)")
			sql("INSERT INTO crash_payload VALUES(zeroblob(1048576))")
			wait_for_kill()
			return
		"recover":
			pair(12,18)
			expect(scalar("SELECT count(*) FROM sqlite_master WHERE name='crash_payload'") == 0, "Uncommitted schema and payload rolled back")
		"committed":
			sql("BEGIN IMMEDIATE")
			sql("UPDATE fixture SET value=13 WHERE id=1")
			sql("UPDATE fixture SET value=17 WHERE id=2")
			sql("COMMIT")
			wait_for_kill()
			return
		"verify":
			pair(13,17)
	expect(scalar("PRAGMA integrity_check") == "ok", "Database integrity")
	expect(scalar("PRAGMA user_version") == 2, "Revision retained after reopen")
	expect(db.close_db(), "Database closes")
	print("STORAGE_PHASE_PASS " + phase if failures == 0 else "STORAGE_PHASE_FAILED " + phase)
	get_tree().quit(0 if failures == 0 else 1)

func wait_for_kill() -> void:
	if failures != 0:
		get_tree().quit(1)
		return
	var marker: FileAccess = FileAccess.open(root_path + "/" + phase + ".ready", FileAccess.WRITE)
	marker.store_string("Ready for owned-process termination")
	marker.flush()
	marker.close()
	# Remain alive with the connection open; external harness kills only this PID.
