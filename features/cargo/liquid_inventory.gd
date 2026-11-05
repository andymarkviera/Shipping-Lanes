extends RefCounted
## Private authority only: intent in, atomic wallet/lot/receipt checkpoint out.
## Caller supplies authoritative docking context, never a peer-reported location.
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const Ship = preload("res://features/catalog/records/oil_ship.tres")
const OWNER = "oil_preview_captain"
const SHIP = "oil_preview_ship"
const BUY_PORT = "port_brindle_quay"
const SELL_PORT = "port_slatewater_works"
const BUY_MINOR = 125
const SELL_MINOR = 175
const START_MINOR = 20000
const MAX_MONEY = 1000000000000
const LIMIT = 4096
var _credits: int = START_MINOR
var _lots: Dictionary = {}
var _events: Array[Dictionary] = []
var _receipts: Dictionary = {}
var _manifest = Manifest.new(Ship, PrototypeCatalog.RECORDS)
var _store: RefCounted
var blocked: bool = false
var notice: String = ""

func capture() -> Dictionary:
	return {"version": 1, "realm": "private_liquid_inventory_v1", "credits": _credits,
		"lots": _lots.duplicate(true), "events": _events.duplicate(true),
		"receipts": _receipts.duplicate(true), "manifest": _manifest.lines()}

static func valid(data: Variant) -> bool:
	return load("res://features/cargo/liquid_inventory.gd").new().restore(data)

static func reconcile(data: Variant) -> Dictionary:
	return {"ok": valid(data), "changed": false, "data": data}

func open(path: String) -> bool:
	if _store != null: return false
	_store = preload("res://features/cargo/voyage_store.gd").new()
	_store.validator = valid
	_store.reconciler = reconcile
	if not _store.open_store(path): return stop(_store.error)
	if _store.current.is_empty():
		if not _store.save(capture()): return stop(_store.error)
	elif not restore(_store.current): return stop("Oil inventory is inconsistent; preserved.")
	return true

func close() -> void:
	if _store != null: _store.close()
	_store = null
	blocked = true

func stop(message: String) -> bool:
	blocked = true
	notice = message
	return false

static func failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func transact(request: Dictionary, authority_port: String, docked: bool) -> Dictionary:
	if blocked or _store == null: return failure("Open an available private inventory first.")
	var error: String = request_error(request)
	if not error.is_empty(): return failure(error)
	if _receipts.has(request.id):
		if _events_for(request.id) != request: return failure("Action ID conflicts with prior intent.")
		return {"ok": true, "replayed": true, "wallet_delta_minor": 0, "receipt": _receipts[request.id].duplicate(true)}
	if not docked or authority_port != request.port: return failure("Dock at the requested oil terminal.")
	var candidate = get_script().new()
	if not candidate.restore(capture()):
		stop("Oil inventory needs recovery.")
		return failure(notice)
	var result: Dictionary = candidate._apply(request)
	if not result.ok: return result
	var data: Dictionary = candidate.capture()
	if not _store.save(data):
		stop(_store.error)
		return failure(notice)
	if not restore(data):
		stop("Committed inventory needs reopen.")
		return failure(notice)
	return result

func _events_for(id: String) -> Dictionary:
	for event: Dictionary in _events:
		if event.id == id: return event.duplicate(true)
	return {}

static func request_error(r: Dictionary) -> String:
	if r.size() != 7: return "Invalid oil intent."
	for key: String in ["id", "kind", "lot", "owner", "ship", "port"]:
		if not r.get(key) is String or r[key].is_empty() or r[key].length() > 128: return "Invalid oil reference."
	if r.owner != OWNER or r.ship != SHIP: return "Oil inventory ownership mismatch."
	if not r.get("barrels") is int or r.barrels <= 0 or r.barrels > 1000000000: return "Use positive whole barrels."
	if r.kind not in ["buy", "sell"]: return "Unknown oil action."
	if r.port != (BUY_PORT if r.kind == "buy" else SELL_PORT): return "This terminal does not support that oil action."
	return ""

# Only called on an isolated candidate or during bounded history validation.
func _apply(r: Dictionary) -> Dictionary:
	var error: String = request_error(r)
	if not error.is_empty(): return failure(error)
	if _events.size() >= LIMIT or _receipts.has(r.id): return failure("History full or repeated action.")
	var cost: int = r.barrels * BUY_MINOR
	var proceeds: int = 0
	var delta: int
	if r.kind == "buy":
		if _lots.has(r.lot): return failure("Acquisition lot already exists.")
		if not _manifest.lines().is_empty(): return failure("Finish the active oil lot first.")
		if cost > _credits: return failure("Insufficient cash for requested barrels.")
		var batch: Dictionary = {"batch_id": r.lot, "cargo_id": "cargo_oil", "quantity": r.barrels,
			"unit": "barrel", "origin_port_id": BUY_PORT, "destination_port_id": SELL_PORT,
			"acquisition_id": r.id, "job_id": ""}
		var added: Dictionary = _manifest.add(batch)
		if not added.ok: return added
		_lots[r.lot] = {"acquisition_id": r.id, "owner": OWNER, "ship": SHIP,
			"origin_port_id": BUY_PORT, "barrels": r.barrels, "remaining_barrels": r.barrels,
			"unit_cost_minor": BUY_MINOR, "acquisition_cost_minor": cost,
			"sold_cost_minor": 0, "proceeds_minor": 0, "realized_profit_minor": 0}
		delta = -cost
	else:
		if not _lots.has(r.lot) or r.barrels > _lots[r.lot].remaining_barrels: return failure("No matching unsold barrels.")
		proceeds = r.barrels * SELL_MINOR
		if proceeds > MAX_MONEY - _credits: return failure("Wallet limit reached.")
		var removed: Dictionary = _manifest.remove(r.lot, r.barrels)
		if not removed.ok: return removed
		var lot: Dictionary = _lots[r.lot]
		cost = r.barrels * lot.unit_cost_minor
		lot.remaining_barrels -= r.barrels
		lot.sold_cost_minor += cost
		lot.proceeds_minor += proceeds
		lot.realized_profit_minor = lot.proceeds_minor - lot.sold_cost_minor
		delta = proceeds
	_credits += delta
	var receipt: Dictionary = {"action_id": r.id, "lot_id": r.lot, "kind": r.kind,
		"barrels": r.barrels, "cost_basis_minor": cost, "proceeds_minor": proceeds,
		"realized_profit_minor": proceeds - cost if r.kind == "sell" else 0,
		"wallet_delta_minor": delta, "balance_minor": _credits}
	_events.append(r.duplicate(true))
	_receipts[r.id] = receipt.duplicate(true)
	return {"ok": true, "replayed": false, "wallet_delta_minor": delta, "receipt": receipt}

func restore(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 7 or data.get("version") != 1 or data.get("realm") != "private_liquid_inventory_v1": return false
	if not data.get("version") is int or not data.get("credits") is int: return false
	if not data.get("events") is Array or data.events.size() > LIMIT: return false
	var replay = get_script().new()
	for event: Variant in data.events:
		if not event is Dictionary or not replay._apply(event).ok: return false
	if replay.capture() != data: return false
	_credits = replay._credits
	_lots = replay._lots
	_events = replay._events
	_receipts = replay._receipts
	_manifest = replay._manifest
	return true
