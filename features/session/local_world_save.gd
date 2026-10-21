class_name LocalWorldSave
extends RefCounted
## Versioned private starter world. Economic receipts are never rolled back by a pose load.
const Nav = preload("res://features/geography/navigation_experiment.gd")
const DEFINITION = preload("res://features/catalog/records/starter_ship.tres")
const DEFAULT_ROOT: String = "user://worlds/private_development"
const DEFAULT_REALM: String = "private_development"
var authority: SessionAuthority = SessionAuthority.new()
var economy: DurableEconomy
var current: Dictionary = {}
var generation: int = 0
var message: String = ""
var usable: bool = false
var root_path: String
var realm: String
var fault_hook: Callable
var incompatible: bool = false

func open_world(folder: String = DEFAULT_ROOT, world: String = DEFAULT_REALM) -> bool:
	root_path = folder
	realm = world
	if not folder.begins_with("user://") or folder.contains(".."):
		return reject("Invalid save location.")
	if not FileAccess.file_exists(folder + "/world.db") and FileAccess.file_exists(folder + "/world.backup.db"):
		return reject("The main save is missing. A backup is available; recovery is required.")
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return reject("Cannot create save folder.")
	if not authority.open_economy_recovery(folder + "/world.db", world):
		return reject("Save could not be opened. Existing progress has been preserved.")
	economy = authority._ledger as DurableEconomy
	if not economy.run("BEGIN IMMEDIATE"): return reject("Save is busy. Try again.")
	if not economy.run("SELECT name FROM sqlite_master WHERE type='table' AND name='world_meta'"):
		return rollback("Cannot read save schema.")
	if economy.db.query_result.is_empty():
		if not economy.run("CREATE TABLE world_meta(id INTEGER PRIMARY KEY CHECK(id=1), version INTEGER NOT NULL, generation INTEGER NOT NULL)") or not economy.run("INSERT INTO world_meta VALUES(1,1,1)"):
			return rollback("Cannot initialize world schema.")
		if not economy.run("CREATE TABLE world_checkpoints(slot INTEGER PRIMARY KEY CHECK(slot IN (1,2)), payload TEXT NOT NULL, digest TEXT NOT NULL)"):
			return rollback("Cannot initialize checkpoints.")
		var initial: Dictionary = record(GeographicAddress.normalized(0, 0), 1000000, 1)
		if not write_slot(1, initial) or not write_slot(2, initial): return rollback("Cannot initialize checkpoint.")
	if not economy.run("SELECT version,generation FROM world_meta WHERE id=1") or economy.db.query_result.size() != 1:
		return rollback("Invalid world header. Progress preserved.")
	var header: Dictionary = economy.db.query_result[0].duplicate()
	if header.version != 1: return rollback("This save version is unsupported. Progress preserved.")
	if not GameUnits.valid_integer(header.generation) or header.generation < 1: return rollback("Invalid checkpoint generation.")
	generation = header.generation
	var primary: Dictionary = read_slot(1)
	if incompatible: return rollback("This checkpoint needs a different content or save version. Progress preserved.")
	if not primary.is_empty() and primary.generation == generation:
		current = primary
		message = "Local progress loaded."
	else:
		current = read_slot(2)
		if incompatible: return rollback("The backup checkpoint requires a different version. Progress preserved.")
		if current.is_empty() or current.generation > generation: return rollback("No valid ship checkpoint. Progress preserved; recovery required.")
		message = "Recovered the previous ship checkpoint. Latest payments and cargo are preserved."
	if not economy.run("COMMIT"): return rollback("Save read could not finish.")
	apply_metadata()
	usable = true
	return true

func record(address: Dictionary, fuel_ml: int, revision: int) -> Dictionary:
	return {"version":1, "generation":revision, "realm":realm,
		"player_id":SessionAuthority.PLAYER_ID, "ship_id":SessionAuthority.SHIP_ID,
		"owner_id":SessionAuthority.PLAYER_ID, "definition_id":DEFINITION.id,
		"inventory_id":"inventory_test", "fuel_ml":fuel_ml, "location":address.duplicate(true)}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 10: return false
	for key: String in ["version", "generation", "realm", "player_id", "ship_id", "owner_id", "definition_id", "inventory_id", "fuel_ml", "location"]:
		if not data.has(key): return false
	for key: String in ["version", "generation", "fuel_ml"]:
		if not GameUnits.valid_integer(data.get(key)): return false
	if data.version != 1 or data.generation < 1 or data.realm != realm: return false
	if data.player_id != SessionAuthority.PLAYER_ID or data.ship_id != SessionAuthority.SHIP_ID or data.owner_id != data.player_id: return false
	if data.definition_id != DEFINITION.id or data.inventory_id != "inventory_test" or data.fuel_ml > int(DEFINITION.fuel_capacity_liters * 1000): return false
	var address: Dictionary = GeographicAddress.decode(data.location)
	if address.is_empty() or absf(address.altitude_m) > 1000: return false
	var position: Vector3 = Nav.local_position(GeographicAddress.normalized(0, 0), address)
	return position.is_finite() and Vector2(position.x, position.z).length() <= 100000.0

func read_slot(slot: int) -> Dictionary:
	if not economy.bound("SELECT payload,digest FROM world_checkpoints WHERE slot=?", [slot]) or economy.db.query_result.size() != 1: return {}
	var row: Dictionary = economy.db.query_result[0]
	if not row.payload is String or row.payload.length() > 8192 or row.payload.sha256_text() != row.digest: return {}
	var data: Variant = JSON.parse_string(row.payload)
	if not data is Dictionary: return {}
	if (data.has("version") and data.version != 1) or (data.has("definition_id") and data.definition_id != DEFINITION.id):
		incompatible = true
		return {}
	if data.get("location") is Dictionary:
		if data.location.get("world_id") != GeographicAddress.WORLD_ID or data.location.get("content_revision") != GeographicAddress.CONTENT_REVISION:
			incompatible = true
			return {}
	for key: String in ["version", "generation", "fuel_ml"]:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(value) or value < 0 or value > GameUnits.MAX_INTEGER or value != floor(value): return {}
		data[key] = int(value)
	return data if valid(data) else {}

func write_slot(slot: int, data: Dictionary) -> bool:
	var payload: String = JSON.stringify(data)
	return economy.bound("INSERT OR REPLACE INTO world_checkpoints VALUES(?,?,?)", [slot, payload, payload.sha256_text()])

func save(address: Dictionary, fuel_ml: int) -> bool:
	if not usable: return false
	if generation >= GameUnits.MAX_INTEGER: return reject("Save generation limit reached.")
	var next: Dictionary = record(address, fuel_ml, generation + 1)
	if not valid(next):
		message = "Ship state was not saved because it is invalid. The previous save is intact."
		return false
	if not economy.run("BEGIN IMMEDIATE"):
		message = "Save is busy. Try again."
		return false
	if not economy.run("SELECT generation FROM world_meta WHERE id=1") or economy.db.query_result.size() != 1 or economy.db.query_result[0].generation != generation:
		return rollback("Another host changed this save. Reopen it before saving.")
	if not write_slot(2, current) or not write_slot(1, next): return rollback("Checkpoint write failed. Previous save preserved.")
	if not economy.bound("UPDATE world_meta SET generation=? WHERE id=1", [next.generation]): return rollback("Checkpoint header write failed.")
	if fault_hook.is_valid(): fault_hook.call("before_commit")
	if not economy.run("COMMIT"): return rollback("Save outcome is uncertain. Reopen to recover.")
	if fault_hook.is_valid(): fault_hook.call("after_commit")
	current = next
	generation = next.generation
	apply_metadata()
	# SQLite's backup API commits the destination transaction; never copy/replace a live DB.
	if economy.db.backup_to(root_path + "/world.backup.db"):
		message = "Local progress saved."
	else:
		message = "Progress saved in the main database; the backup could not be updated."
	return true

func apply_metadata() -> void:
	authority._state.ship.fuel_ml = current.fuel_ml
	authority._state.ship.location = current.location.duplicate(true)

func save_ship(ship: HandlingShip) -> bool:
	if ship.definition.id != DEFINITION.id or not ship.position.is_finite() or not is_finite(ship.state.fuel_liters) or ship.state.fuel_liters < 0 or ship.state.fuel_liters > DEFINITION.fuel_capacity_liters:
		message = "Invalid ship state. The previous save is intact."
		return false
	var origin: Dictionary = GeographicAddress.normalized(0, 0)
	var distance: float = Vector2(ship.position.x, ship.position.z).length()
	var directed: Dictionary = GeographicAddress.normalized(0, 0, rad_to_deg(atan2(-ship.position.x, ship.position.z)))
	var address: Dictionary = Nav.travel(directed, distance)
	if address.is_empty(): return false
	address.altitude_m = ship.position.y
	address.heading_deg = GeographicAddress.wrap_scalar(-rad_to_deg(ship.rotation.y + Nav.transport_rotation(origin, address)), 0, 360)
	# Round down once at a checkpoint, never per simulation tick or upward to grant fuel.
	return save(address, int(floor(ship.state.fuel_liters * 1000.0)))

func restore_ship(ship: HandlingShip) -> bool:
	if not usable or ship.definition.id != current.definition_id: return false
	var origin: Dictionary = GeographicAddress.normalized(0, 0)
	ship.position = Nav.local_position(origin, current.location)
	ship.rotation = Vector3(0, -deg_to_rad(current.location.heading_deg) - Nav.transport_rotation(origin, current.location), 0)
	ship.state.instance_id = current.ship_id
	ship.state.fuel_liters = float(current.fuel_ml) / 1000.0
	ship.velocity = Vector3.ZERO
	ship.commanded_throttle = 0
	ship.actual_throttle = 0
	ship.yaw_rate = 0
	ship.maneuver(0, 0)
	return true

func rollback(reason: String) -> bool:
	economy.run("ROLLBACK")
	return reject(reason)

func reject(reason: String) -> bool:
	message = reason
	usable = false
	authority._ledger.usable = false
	return false

func close_world() -> void:
	usable = false
	authority.close_economy_recovery()
