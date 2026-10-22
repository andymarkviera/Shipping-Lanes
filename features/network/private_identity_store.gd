class_name PrivateIdentityStore
extends RefCounted
## Host-only private membership. Public accounts never enter this database.
var db: SQLite
var world_id: String
var fingerprint: String
var folder: String
var definition_id: String
var certificate: X509Certificate
var key: CryptoKey
var error: String = ""

func open_store(directory: String, definition: String) -> bool:
	folder = directory
	definition_id = definition
	if not folder.begins_with("user://") or DirAccess.make_dir_recursive_absolute(folder) != OK: return false
	var existing: bool = FileAccess.file_exists(folder + "/members.db")
	key = CryptoKey.new()
	certificate = X509Certificate.new()
	if existing:
		if key.load(folder + "/host.key") != OK or certificate.load(folder + "/host.crt") != OK: return false
	else:
		var crypto: Crypto = Crypto.new()
		key = crypto.generate_rsa(2048)
		certificate = crypto.generate_self_signed_certificate(key, "CN=localhost,O=Container Ship Sim,C=US", "20260101000000", "20300101000000")
		if key == null or certificate == null or key.save(folder + "/host.key") != OK or certificate.save(folder + "/host.crt") != OK: return false
	fingerprint = certificate.save_to_string().sha256_text()
	db = SQLite.new()
	db.path = folder + "/members.db"
	db.verbosity_level = 0
	if not db.open_db(): return false
	if not query("PRAGMA busy_timeout=1000") or not query("PRAGMA journal_mode=WAL") or not query("PRAGMA synchronous=FULL"): return false
	if not query("BEGIN IMMEDIATE"): return false
	if not query("PRAGMA user_version"): return abort()
	var version: int = int(db.query_result[0].values()[0])
	if version == 0 and not existing:
		world_id = Crypto.new().generate_random_bytes(16).hex_encode()
		if not query("CREATE TABLE context(world TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, definition TEXT NOT NULL)"): return abort()
		if not query("INSERT INTO context VALUES(?,?,?)", [world_id, fingerprint, definition]): return abort()
		if not query("CREATE TABLE members(player TEXT PRIMARY KEY, ship TEXT NOT NULL UNIQUE, token_hash TEXT NOT NULL UNIQUE, generation INTEGER NOT NULL, state TEXT)"): return abort()
		if not query("PRAGMA user_version=1"): return abort()
	elif version != 1: return abort()
	if not query("SELECT * FROM context") or db.query_result.size() != 1: return abort()
	var context: Dictionary = db.query_result[0]
	if context.fingerprint != fingerprint or context.definition != definition: return abort()
	world_id = context.world
	return query("COMMIT")

func query(sql: String, args: Array = []) -> bool:
	return db != null and db.query_with_bindings(sql, args)

func abort() -> bool:
	query("ROLLBACK")
	error = "Private identity store unavailable or incompatible"
	return false

func close_store() -> void:
	if db != null: db.close_db()
	db = null

func member_ship(token: String) -> String:
	if token.length() != 64 or not token.is_valid_hex_number(): return ""
	if not query("SELECT ship FROM members WHERE token_hash=?", [token.sha256_text()]) or db.query_result.size() != 1: return ""
	return str(db.query_result[0].ship)

func admit(token: String, host: bool = false) -> Dictionary:
	if not host and not token.is_empty() and (token.length() != 64 or not token.is_valid_hex_number()): return {}
	if not query("BEGIN IMMEDIATE"): return {}
	var hash_value: String = "host" if host else token.sha256_text()
	if not query("SELECT * FROM members WHERE token_hash=?", [hash_value]):
		abort()
		return {}
	var row: Dictionary = {}
	var issued: String = ""
	if db.query_result.size() == 1:
		row = db.query_result[0].duplicate(true)
		row.new_member = false
	elif host or token.is_empty():
		if not query("SELECT count(*) AS total FROM members") or db.query_result[0].total >= 64:
			abort()
			return {}
		var player: String = Crypto.new().generate_random_bytes(16).hex_encode()
		issued = "" if host else Crypto.new().generate_random_bytes(32).hex_encode()
		row = {"player": player, "ship": "ship_" + Crypto.new().generate_random_bytes(16).hex_encode(), "generation": 0, "state": null}
		row.new_member = true
		if not query("INSERT INTO members VALUES(?,?,?,?,NULL)", [player, row.ship, "host" if host else issued.sha256_text(), 0]):
			abort()
			return {}
	else:
		abort()
		return {}
	row.generation += 1
	if not query("UPDATE members SET generation=? WHERE player=?", [row.generation, row.player]) or not query("COMMIT"):
		abort()
		return {}
	row.erase("token_hash")
	row.issued = issued
	return row

func save_state(player: String, generation: int, state: Dictionary) -> bool:
	# Generation check and write share one statement/transaction.
	if not query("UPDATE members SET state=? WHERE player=? AND generation=?", [Marshalls.raw_to_base64(var_to_bytes(state)), player, generation]): return false
	return query("SELECT changes() AS count") and db.query_result[0].count == 1
