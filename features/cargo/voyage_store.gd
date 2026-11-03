extends RefCounted
## Local Port Test authority only. One atomic record; no public economy credentials.
const Codec = preload("res://features/cargo/voyage_snapshot.gd")
var db: SQLite
var current: Dictionary = {}
var recovery_notice: String = ""
var revision: int = 0
var error: String = ""
var fault_hook: Callable
# Optional bounded codec for a separate private cargo realm; legacy defaults unchanged.
var validator: Callable = Codec.valid
var reconciler: Callable = preload("res://features/cargo/voyage_lifecycle.gd").reconcile

func open_store(path: String) -> bool:
	if not path.begins_with("user://") or path.contains(".."): return fail("Invalid save path.")
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return fail("Cannot create voyage save folder.")
	db = SQLite.new()
	db.path = path
	db.verbosity_level = 0
	if not db.open_db(): return fail("Cannot open voyage save. Existing progress preserved.")
	if not db.query("PRAGMA busy_timeout=1000") or not db.query("PRAGMA journal_mode=WAL") or db.query_result[0].values()[0] != "wal" or not db.query("PRAGMA synchronous=FULL"): return fail("Cannot configure durable voyage saving.")
	if not db.query("PRAGMA user_version"): return fail("Cannot read voyage save version.")
	var version: int = int(db.query_result[0].values()[0])
	if version == 0:
		if not db.query("SELECT count(*) AS total FROM sqlite_master WHERE type='table'") or db.query_result[0].total != 0: return fail("Unrecognized voyage save. Preserved.")
		if not db.query("BEGIN IMMEDIATE"): return fail("Voyage save is busy.")
		if not db.query("CREATE TABLE voyage(id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL, payload TEXT NOT NULL, digest TEXT NOT NULL)") or not db.query("PRAGMA user_version=1") or not db.query("COMMIT"):
			db.query("ROLLBACK")
			return fail("Cannot initialize voyage save.")
	elif version != 1: return fail("Voyage save needs a compatible game version. Preserved.")
	if not db.query("SELECT revision,payload,digest FROM voyage WHERE id=1"): return fail("Cannot read voyage checkpoint.")
	if db.query_result.is_empty(): return true
	var row: Dictionary = db.query_result[0]
	if not row.payload is String or row.payload.length() > 4000000 or row.payload.sha256_text() != row.digest: return fail("Voyage checkpoint is damaged. Preserved; no reset performed.")
	var decoded: Variant = bytes_to_var(Marshalls.base64_to_raw(row.payload))
	var recovery: Dictionary = reconciler.call(decoded)
	if not recovery.ok: return fail("Voyage checkpoint is incompatible or inconsistent. Preserved.")
	current = recovery.data
	if recovery.changed: recovery_notice = "Interrupted unfinished job released safely. No cargo or payment was created."
	revision = int(row.revision)
	return revision > 0

func save(data: Dictionary) -> bool:
	if db == null or not error.is_empty(): return false
	if not validator.call(data): return fail("Voyage state could not be saved safely. Last checkpoint preserved.")
	var payload: String = Marshalls.raw_to_base64(var_to_bytes(data))
	if payload.length() > 4000000: return fail("Voyage checkpoint is too large. Last checkpoint preserved.")
	if not db.query("BEGIN IMMEDIATE"): return fail("Voyage save is busy. Last checkpoint preserved.")
	# Compare-and-swap rejects a stale second game process rather than overwriting it.
	if not db.query("SELECT revision FROM voyage WHERE id=1"):
		db.query("ROLLBACK")
		return fail("Cannot read current voyage revision.")
	var stored: int = 0 if db.query_result.is_empty() else int(db.query_result[0].revision)
	if stored != revision:
		db.query("ROLLBACK")
		return fail("Another game session changed this voyage. Reopen to load it.")
	if not db.query_with_bindings("INSERT OR REPLACE INTO voyage VALUES(1,?,?,?)", [revision + 1, payload, payload.sha256_text()]):
		db.query("ROLLBACK")
		return fail("Voyage write failed. Last checkpoint preserved.")
	if fault_hook.is_valid(): fault_hook.call("before_commit")
	if not db.query("COMMIT"):
		db.query("ROLLBACK")
		return fail("Voyage commit could not be confirmed. Reopen before playing.")
	revision += 1
	current = data.duplicate(true)
	if fault_hook.is_valid(): fault_hook.call("after_commit")
	return true

func fail(message: String) -> bool:
	error = message
	return false

func close() -> void:
	if db != null: db.close_db()
	db = null
