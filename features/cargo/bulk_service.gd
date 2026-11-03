extends RefCounted
## Private authority. Candidate state is committed to SQLite before publication.
const Bulk = preload("res://features/cargo/bulk_earnings.gd")
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const Operations = preload("res://features/cargo/cargo_operation.gd")
const Ship = preload("res://features/catalog/records/bulk_ship.tres")
const Geo = preload("res://features/geography/geographic_address.gd")
const PORTS = ["port_brindle_quay", "port_slatewater_works"]
const OWNER = "bulk_preview_captain"
const SHIP = "bulk_preview_ship"
const LIMIT = 4096
var offers = Bulk.new()
var manifest = Manifest.new(Ship, PrototypeCatalog.RECORDS)
var operations = Operations.new()
var seeds: Dictionary = {}
var events: Array[Dictionary] = []
var credits: int = 0
var sequence: int = 0
var active: String = ""
var port: String = PORTS[0]
var docked: bool = false
var pose: Transform3D = Transform3D.IDENTITY
var fuel: float = 800.0
var condition: float = 1.0
var store: RefCounted
var blocked: bool = false
var notice: String = "Dock to select a commodity and hold."

class Rule extends RefCounted:
	var authority: WeakRef
	func validate(entry: Dictionary) -> String:
		return authority.get_ref().operation_error(entry)
	func complete(entry: Dictionary) -> Dictionary:
		return authority.get_ref().complete_operation(entry)

func _init() -> void:
	offers._offers.clear()
	var rule = Rule.new()
	rule.authority = weakref(self)
	operations.register_rule("bulk_service", rule)

func seed_offers() -> void:
	var locations: Dictionary = {PORTS[0]: Geo.normalized(0, 0), PORTS[1]: Geo.normalized(0, rad_to_deg(1500.0 / 100000.0))}
	var rates: Dictionary = {"cargo_bulk_grain": 100, "cargo_bulk_coal": 120, "cargo_bulk_ore": 150, "cargo_bulk_limestone": 80}
	for origin: String in PORTS:
		for cargo: String in rates:
			for hold: String in Ship.bulk_holds:
				var id: String = "bulk_%d_%s_%s" % [PORTS.find(origin), cargo.trim_prefix("cargo_bulk_"), hold.trim_prefix("hold_")]
				offers.publish(id, cargo, 123456789, hold, origin, PORTS[1 - PORTS.find(origin)], locations, rates, {PORTS[0]: 11000, PORTS[1]: 9000})
	seeds = offers._offers.duplicate(true)

func capture() -> Dictionary:
	return {"version": 1, "realm": "private_bulk_voyage_v1", "seeds": seeds.duplicate(true), "events": events.duplicate(true),
		"manifest": manifest.lines(), "credits": credits, "operations": operations.snapshot(), "sequence": sequence,
		"active": active, "port": port, "docked": docked, "pose": pose, "fuel": fuel, "condition": condition}

static func valid(data: Variant) -> bool:
	return load("res://features/cargo/bulk_service.gd").new().restore(data)

static func reconcile(data: Variant) -> Dictionary:
	return {"ok": valid(data), "changed": false, "data": data}

func open(path: String) -> bool:
	store = preload("res://features/cargo/voyage_store.gd").new()
	store.validator = valid
	store.reconciler = reconcile
	if not store.open_store(path): return stop(store.error)
	if store.current.is_empty():
		seed_offers()
		return checkpoint()
	if not restore(store.current): return stop("Bulk save is inconsistent. Preserved; no reset performed.")
	notice = "Bulk voyage restored; accepted terms and partial receipts retained."
	return true

func stop(message: String) -> bool:
	blocked = true
	notice = message
	return false

func checkpoint() -> bool:
	if blocked or store == null: return false
	if not store.save(capture()): return stop(store.error)
	return true

# Never publish candidate mutations, callbacks, wallet changes or success before COMMIT.
func transact(action: Callable) -> bool:
	if blocked: return false
	var candidate = get_script().new()
	if not candidate.restore(capture()): return stop("Bulk state could not be verified.")
	var result: Dictionary = action.call(candidate)
	if not result.ok:
		notice = result.message
		return false
	var data: Dictionary = candidate.capture()
	if store != null and not store.save(data): return stop(store.error)
	if not restore(data): return stop("Committed bulk state needs recovery. Reopen the voyage.")
	notice = result.message
	return true

func start_loading(id: String) -> bool:
	return transact(func(candidate: RefCounted) -> Dictionary:
		if not candidate.active.is_empty() or not candidate.docked: return Bulk.failure("Dock and finish the current operation first.")
		var result: Dictionary = candidate.offers.accept(id, OWNER, SHIP, candidate.port, candidate.manifest)
		if not result.ok: return result
		candidate.events.append({"kind": "accept", "id": id})
		return candidate.begin("load", id, candidate.offers.view(id).quantity))

func start_discharge(grams: int) -> bool:
	return transact(func(candidate: RefCounted) -> Dictionary:
		var job: Dictionary = candidate.offers.active_job(OWNER)
		if job.is_empty(): return Bulk.failure("No loaded bulk job.")
		return candidate.begin("discharge", job.id, grams))

func begin(kind: String, id: String, grams: int) -> Dictionary:
	if not active.is_empty() or sequence >= LIMIT or events.size() >= LIMIT: return Bulk.failure("Operation busy or history full.")
	sequence += 1
	var next: String = "bulk_operation_%d" % sequence
	var result: Dictionary = operations.reserve(next, SHIP, "bulk_service", {"kind": kind, "id": id, "grams": grams}, 5.0)
	if not result.ok: return result
	operations.start(next)
	active = next
	return {"ok": true, "message": "Loading bulk…" if kind == "load" else "Unloading bulk…"}

func operation_error(entry: Dictionary) -> String:
	var p: Dictionary = entry.get("payload", {})
	if entry.get("ship_id") != SHIP or not docked: return "Dock before bulk service."
	if p.size() != 3 or p.get("kind") not in ["load", "discharge"] or not p.get("id") is String or not p.get("grams") is int or p.grams <= 0: return "Invalid bulk operation."
	var job: Dictionary = offers.view(p.id)
	if not job.has("terms"): return "Unknown bulk job."
	if p.kind == "load":
		if p.grams != job.quantity: return "Loading must use the accepted quantity."
		return offers.loading_error(p.id, OWNER, SHIP, port, manifest)
	if job.state != "loaded" or job.owner_id != OWNER or job.ship_id != SHIP or job.destination_port_id != port or p.grams > job.quantity - job.discharged_grams: return "No matching cargo at this destination."
	if manifest.lines() != [offers.batch(job)]: return "Cargo provenance mismatch."
	return ""

func complete_operation(entry: Dictionary) -> Dictionary:
	var error: String = operation_error(entry)
	if not error.is_empty(): return Bulk.failure(error)
	var p: Dictionary = entry.payload
	var result: Dictionary = apply_event({"kind": p.kind, "id": p.id, "grams": p.grams, "operation": entry.id})
	return result

func apply_event(event: Dictionary) -> Dictionary:
	var result: Dictionary
	match event.kind:
		"accept": result = offers.accept(event.id, OWNER, SHIP, offers.view(event.id).origin_port_id, manifest)
		"release": result = {"ok": offers.release_job(event.id, OWNER, SHIP), "message": "Loading released; no cargo or payment."}
		"load": result = offers.load_at(event.id, OWNER, SHIP, offers.view(event.id).origin_port_id, manifest, true)
		"discharge":
			var job: Dictionary = offers.view(event.id)
			if event.grams <= 0 or event.grams > job.quantity - job.discharged_grams: return Bulk.failure("Invalid discharge quantity.")
			var payment: int = Bulk.earnings(job.discharged_grams + event.grams, job.terms) - job.paid_minor
			if payment > Bulk.MAX_MONEY - credits: return Bulk.failure("Bulk wallet limit reached.")
			result = offers.discharge(event.operation, event.id, OWNER, SHIP, offers.view(event.id).destination_port_id, manifest, event.grams, true)
			if result.ok: credits += result.reward_minor
		_: return Bulk.failure("Unknown bulk history event.")
	if result.ok: events.append(event.duplicate(true))
	return result

# Authority simulation only. A panel/crane receives presentation(), never this clock.
func advance(delta: float) -> bool:
	if active.is_empty(): return true
	return transact(func(candidate: RefCounted) -> Dictionary:
		var entry: Dictionary = candidate.operations.record(candidate.active)
		if not candidate.operation_error(entry).is_empty(): return candidate.cancel_pending(true)
		if entry.state == "reserved": candidate.operations.start(candidate.active)
		if entry.state != "ready" and not candidate.operations.progress(candidate.active, delta): return Bulk.failure("Invalid authority time step.")
		if candidate.operations.record(candidate.active).state != "ready": return {"ok": true, "message": "Bulk service in progress…"}
		var result: Dictionary = candidate.operations.commit(candidate.active)
		candidate.active = ""
		return result)

func cancel_pending(interrupted: bool = false) -> Dictionary:
	if active.is_empty(): return Bulk.failure("No bulk operation to cancel.")
	var entry: Dictionary = operations.record(active)
	if not operations.cancel(active, interrupted): return Bulk.failure("Operation cannot be cancelled.")
	if entry.payload.kind == "load": apply_event({"kind": "release", "id": entry.payload.id})
	active = ""
	return {"ok": true, "message": "Bulk service interrupted; completed discharges retained." if interrupted else "Bulk service cancelled; completed discharges retained."}

func cancel() -> bool:
	return transact(func(candidate: RefCounted) -> Dictionary: return candidate.cancel_pending())

func presentation() -> Dictionary:
	var entry: Dictionary = operations.record(active)
	var job: Dictionary = offers.active_job(OWNER)
	return {"operation": active, "kind": entry.get("payload", {}).get("kind", ""),
		"progress": entry.get("elapsed", 0.0) / entry.get("duration", 1.0), "job": job,
		"credits": credits, "notice": notice, "blocked": blocked,
		"receipt": {} if offers._settlements.is_empty() else offers._settlements.values().back().receipt.duplicate(true)}

func restore(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 14 or data.get("version") != 1 or data.get("realm") != "private_bulk_voyage_v1": return false
	if not data.get("seeds") is Dictionary or data.seeds.is_empty() or data.seeds.size() > 64 or not data.get("events") is Array or data.events.size() > LIMIT: return false
	if not data.get("sequence") is int or data.sequence < 0 or data.sequence > LIMIT or not data.get("credits") is int: return false
	if not data.get("active") is String or data.get("port") not in PORTS or not data.get("docked") is bool: return false
	if not preload("res://features/cargo/voyage_snapshot.gd").pose_valid(data.get("pose")) or absf(data.pose.origin.y) > .01: return false
	if not preload("res://features/cargo/voyage_snapshot.gd").number(data.get("fuel"), 0, 1000) or not preload("res://features/cargo/voyage_snapshot.gd").number(data.get("condition"), 0, 1): return false
	if not data.get("operations") is Dictionary or not data.operations.get("records") is Dictionary or data.operations.records.size() != data.sequence: return false
	# Build off to the side; reject malformed data without modifying a live authority.
	var replay = get_script().new()
	for id: Variant in data.seeds:
		var row: Variant = data.seeds[id]
		if not id is String or id.is_empty() or id.length() > 64 or not row is Dictionary or row.size() != 16 or row.get("id") != id: return false
		if row.get("origin_port_id") not in PORTS or row.get("destination_port_id") not in PORTS or row.origin_port_id == row.destination_port_id: return false
		if row.get("state") != "available" or row.get("owner_id") != "" or row.get("ship_id") != "" or row.get("accepted_ms") != -1 or row.get("expires_ms") != -1 or row.get("discharged_grams") != 0 or row.get("paid_minor") != 0: return false
		if not row.get("quantity") is int or row.quantity <= 0 or row.quantity > 1000000000 or not row.get("terms") is Dictionary or row.terms.size() != 4: return false
		for key: String in ["direct_distance_m", "rate_minor_per_tonne_nm", "origin_modifier_bp", "destination_modifier_bp"]:
			if not row.terms.get(key) is int: return false
		var t: Dictionary = row.terms
		if t.direct_distance_m <= 0 or t.direct_distance_m > 314160 or t.rate_minor_per_tonne_nm < 1 or t.rate_minor_per_tonne_nm > 1000000 or t.origin_modifier_bp < 0 or t.origin_modifier_bp > 20000 or t.destination_modifier_bp < 0 or t.destination_modifier_bp > 20000: return false
		if not row.get("reward_minor") is int or row.reward_minor < 0 or row.reward_minor != Bulk.earnings(row.quantity, t): return false
		if not row.get("hold_id") is String or not row.get("cargo_id") is String or row.get("unit") != "gram": return false
		var lines: Array[Dictionary] = [replay.offers.batch(row)]
		if not replay.manifest.validate(lines).is_empty(): return false
		replay.offers._offers[id] = row.duplicate(true)
	var completed: Dictionary = {}
	for event: Variant in data.events:
		if not event is Dictionary or not event.get("id") is String or not replay.offers._offers.has(event.id): return false
		if event.get("kind") in ["accept", "release"]:
			if event.size() != 2: return false
			if event.kind == "accept" and replay.offers.view(event.id).state != "available": return false
		elif event.get("kind") in ["load", "discharge"]:
			if event.size() != 4 or not event.get("grams") is int or not event.get("operation") is String or completed.has(event.operation): return false
			var entry: Variant = data.operations.records.get(event.operation)
			if not entry is Dictionary or entry.get("state") != "committed" or entry.get("payload") != {"kind": event.kind, "id": event.id, "grams": event.grams}: return false
			if event.kind == "load" and event.grams != replay.offers.view(event.id).quantity: return false
			completed[event.operation] = true
		else: return false
		if not replay.apply_event(event).ok: return false
	if data.get("manifest") != replay.manifest.lines() or data.credits != replay.credits: return false
	replay.port = data.port
	replay.docked = data.docked
	var live: Array[String] = []
	for i: int in data.sequence:
		var id: String = "bulk_operation_%d" % (i + 1)
		var entry: Variant = data.operations.records.get(id)
		if not entry is Dictionary or entry.size() != 8 or entry.get("ship_id") != SHIP or entry.get("rule_id") != "bulk_service" or entry.get("duration") != 5.0: return false
		if not entry.get("payload") is Dictionary or entry.payload.size() != 3 or entry.payload.get("kind") not in ["load", "discharge"] or not entry.payload.get("grams") is int or entry.payload.grams <= 0 or not replay.offers._offers.has(entry.payload.get("id")): return false
		if entry.get("state") == "committed" and not completed.has(id): return false
		if entry.get("state") not in Operations.TERMINAL: live.append(id)
	if live != ([] if data.active.is_empty() else [data.active]): return false
	if not replay.operations.restore(data.operations): return false
	var job: Dictionary = replay.offers.active_job(OWNER)
	if job.get("state") == "accepted" and (live.is_empty() or replay.operations.record(data.active).payload.kind != "load"): return false
	offers = replay.offers
	manifest = replay.manifest
	events = replay.events
	credits = replay.credits
	seeds = data.seeds.duplicate(true)
	sequence = data.sequence
	active = data.active
	port = data.port
	docked = data.docked
	pose = data.pose
	fuel = data.fuel
	condition = data.condition
	# Rebind rule to this authority, not the temporary replay object.
	operations = Operations.new()
	var rule = Rule.new()
	rule.authority = weakref(self)
	operations.register_rule("bulk_service", rule)
	return operations.restore(data.operations)
