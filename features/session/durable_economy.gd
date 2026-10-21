class_name DurableEconomy
extends EconomyLedger
## Private authority store, schema/rules v1. Never accepts public account state.
var db: SQLite
var realm: String
var storage_error: String = ""
var fault_hook: Callable # Trusted diagnostic injection only; never a request field.
const COLUMNS: String = "revision,player_minor,system_minor,player_quantity,stock_quantity,delivered_quantity"
const KEYS: Array[String] = ["revision", "player_minor", "system_minor", "player_quantity", "stock_quantity", "delivered_quantity"]

func open_store(path: String, private_realm: String) -> bool:
	usable = false
	var pattern: RegEx = RegEx.new()
	pattern.compile("^private_[a-z0-9_]{1,48}$")
	if pattern.search(private_realm) == null or not path.begins_with("user://"):
		storage_error = "invalid_private_store"
		return false
	realm = private_realm
	db = SQLite.new()
	db.path = path
	db.verbosity_level = 0
	if not db.open_db(): return fail("open_failed")
	if not run("PRAGMA busy_timeout=1000") or not run("PRAGMA foreign_keys=ON"):
		return fail("configuration_failed")
	if not run("PRAGMA journal_mode=WAL") or db.query_result[0].values()[0] != "wal":
		return fail("wal_required")
	if not run("PRAGMA synchronous=FULL") or not run("BEGIN IMMEDIATE"):
		return fail("transaction_failed")
	if not run("PRAGMA user_version"): return abort("version_failed")
	var version: int = int(db.query_result[0].values()[0])
	if version == 0:
		if not run("SELECT count(*) AS total FROM sqlite_master WHERE type='table'") or db.query_result[0].total != 0:
			return abort("unknown_database")
		if not run("CREATE TABLE context(realm TEXT PRIMARY KEY, rules INTEGER NOT NULL CHECK(rules=1))"):
			return abort("schema_failed")
		if not bound("INSERT INTO context VALUES(?,1)", [realm]): return abort("schema_failed")
		if not run("CREATE TABLE snapshot(id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL,player_minor INTEGER NOT NULL,system_minor INTEGER NOT NULL,player_quantity INTEGER NOT NULL,stock_quantity INTEGER NOT NULL,delivered_quantity INTEGER NOT NULL)"):
			return abort("schema_failed")
		if not run("INSERT INTO snapshot VALUES(1,0,20000,1000000,0,100,0)"): return abort("schema_failed")
		if not run("CREATE TABLE receipts(sequence INTEGER PRIMARY KEY, action_id TEXT NOT NULL UNIQUE, request TEXT NOT NULL, code TEXT NOT NULL, revision INTEGER NOT NULL, amount INTEGER NOT NULL, quantity INTEGER NOT NULL)"):
			return abort("schema_failed")
		if not run("PRAGMA user_version=1"): return abort("schema_failed")
	elif version != 1:
		return abort("unsupported_schema")
	var restored: EconomyLedger = restore_ledger()
	if restored == null: return abort("invalid_recovery_record")
	if not run("COMMIT"): return abort("commit_unknown")
	_data = restored._data.duplicate(true)
	usable = true
	storage_error = ""
	return true

func close_store() -> void:
	usable = false
	if db != null:
		db.close_db()
		db = null

func run(statement: String) -> bool:
	return db != null and db.query(statement)

func bound(statement: String, parameters: Array) -> bool:
	return db != null and db.query_with_bindings(statement, parameters)

func fail(code: String) -> bool:
	storage_error = code
	usable = false
	return false

func abort(code: String) -> bool:
	run("ROLLBACK")
	return fail(code)

func restore_ledger() -> EconomyLedger:
	if not run("SELECT realm,rules FROM context LIMIT 2") or db.query_result.size() != 1:
		return null
	if db.query_result[0].realm != realm or db.query_result[0].rules != 1: return null
	if not run("SELECT " + COLUMNS + " FROM snapshot WHERE id=1") or db.query_result.size() != 1:
		return null
	var snapshot: Dictionary = db.query_result[0].duplicate(true)
	if not run("SELECT * FROM receipts ORDER BY sequence LIMIT 1025"): return null
	var records: Array = db.query_result.duplicate(true)
	if records.size() > LIMIT: return null
	var ledger: EconomyLedger = EconomyLedger.new()
	for index: int in records.size():
		var row: Dictionary = records[index]
		if row.sequence != index + 1 or not row.request is String or row.request.length() > 2048: return null
		var parsed: Variant = JSON.parse_string(row.request)
		if not parsed is Dictionary or parsed.size() != 5: return null
		for key: String in ["version", "quantity", "expected_revision"]:
			var number: Variant = parsed.get(key)
			if not (number is float or number is int): return null
			if not is_finite(float(number)) or float(number) < 0 or float(number) > GameUnits.MAX_INTEGER or floor(float(number)) != float(number): return null
			parsed[key] = int(number)
		# This exact canonical text was written by the authority; reject altered encodings.
		if JSON.stringify(parsed) != row.request or parsed.get("action_id") != row.action_id: return null
		var result: Dictionary = ledger.execute(PLAYER_ID, parsed)
		if ledger.audit().receipt_count != index + 1 or result.duplicate: return null
		if result.code != row.code or result.revision != row.revision or result.amount_minor != row.amount or result.quantity != row.quantity: return null
	if ledger.view() != snapshot: return null
	return ledger

func checkpoint(stage: String) -> void:
	if fault_hook.is_valid(): fault_hook.call(stage)

func execute(actor: String, data: Variant) -> Dictionary:
	if not usable: return response("storage_unavailable")
	if actor != PLAYER_ID: return response("not_owner")
	if not run("BEGIN IMMEDIATE"):
		return response("storage_retry_same_id")
	# Read current durable state under the write lock, not a stale cached balance.
	var candidate: EconomyLedger = restore_ledger()
	if candidate == null:
		abort("invalid_recovery_record")
		return response("storage_unavailable")
	var previous_count: int = candidate.audit().receipt_count
	var result: Dictionary = candidate.execute(actor, data)
	if candidate.audit().receipt_count == previous_count:
		run("ROLLBACK")
		_data = candidate._data.duplicate(true)
		return result
	var state: Dictionary = candidate.view()
	var values: Array = []
	for key: String in KEYS: values.append(state[key])
	if not bound("UPDATE snapshot SET revision=?,player_minor=?,system_minor=?,player_quantity=?,stock_quantity=?,delivered_quantity=? WHERE id=1", values):
		abort("write_failed")
		return response("storage_retry_same_id")
	checkpoint("snapshot_written")
	if not bound("INSERT INTO receipts VALUES(?,?,?,?,?,?,?)", [previous_count + 1, data.action_id, JSON.stringify(data), result.code, result.revision, result.amount_minor, result.quantity]):
		abort("receipt_failed")
		return response("storage_retry_same_id")
	checkpoint("before_commit")
	if not run("COMMIT"):
		abort("commit_unknown")
		return response("storage_retry_same_id")
	checkpoint("after_commit")
	_data = candidate._data.duplicate(true)
	return result
