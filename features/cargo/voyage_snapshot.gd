extends RefCounted
## Bounded, object-free authority checkpoint. Restoring never executes saved code.
const Offers = preload("res://features/cargo/container_offers.gd")
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const Operations = preload("res://features/cargo/cargo_operation.gd")
const HeavyJobs = preload("res://features/cargo/heavy_ocean_job.gd")
const Heavy = preload("res://features/handling/heavy_lifter.gd")
const PORT_IDS = ["port_brindle_quay", "port_slatewater_works"]

static func capture(view: Node3D) -> Dictionary:
	var body: HandlingShip = view.ship
	var operations: Dictionary = body.state.operations.snapshot()
	for record: Dictionary in operations.records.values(): record.ship_id = view.ship_key()
	var heavy: Dictionary = {}
	if view.heavy_mode:
		heavy = {"active": view.heavy_jobs.active.duplicate(true), "completed": view.heavy_jobs.completed.duplicate(true), "attached": body.attached, "height": body.deck_height, "target": body.deck_target, "payload_pose": body.payload_body.global_transform}
	return {"version": 1, "realm": "private_port_voyage_v1", "owner": "preview_captain", "heavy_mode": view.heavy_mode,
		"port": view.world_ports.find(view.port), "pose": body.global_transform, "fuel": body.state.fuel_liters, "condition": body.state.condition,
		"offers": view.offers._offers.duplicate(true), "clock": view.offers._now_ms, "manifest": body.state.manifest.lines(),
		"operations": operations, "loading": view.loading.operation, "loading_offer": view.loading.offer_id, "sequence": view.loading.sequence,
		"docked": view.docking.state(1) == "docked", "heavy": heavy, "heavy_completed": view.heavy_jobs.completed.duplicate(true), "credits": view.reward_minor}

static func pose_valid(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and value.origin.length() < 100000 and value.basis.is_equal_approx(value.basis.orthonormalized()) and value.basis.y.is_equal_approx(Vector3.UP) and value.basis.determinant() > .99

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(value) and value >= low and value <= high

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 19: return false
	var d: Dictionary = value
	if d.get("version") != 1 or d.get("realm") != "private_port_voyage_v1" or d.get("owner") != "preview_captain": return false
	for key: String in ["offers", "operations", "heavy", "heavy_completed"]:
		if not d.get(key) is Dictionary: return false
	for key: String in ["heavy_mode", "docked"]:
		if not d.get(key) is bool: return false
	for key: String in ["clock", "sequence", "credits", "port"]:
		if not d.get(key) is int or d[key] < 0: return false
	for key: String in ["loading", "loading_offer"]:
		if not d.get(key) is String: return false
	if d.port > 1 or d.clock > 9000000000000 or d.sequence > 1000000000 or not pose_valid(d.get("pose")) or absf(d.pose.origin.y) > .01: return false
	var definition: ShipDefinition = Heavy.DEFINITION if d.heavy_mode else preload("res://features/catalog/records/starter_ship.tres")
	if not number(d.get("fuel"), 0, definition.fuel_capacity_liters) or not number(d.get("condition"), 0, 1) or not d.get("manifest") is Array: return false
	var manifest = Manifest.new(definition, PrototypeCatalog.RECORDS)
	var lines: Array[Dictionary] = []
	for row: Variant in d.manifest:
		if not row is Dictionary: return false
		lines.append(row)
	if not manifest.validate(lines).is_empty(): return false
	var seeded = Offers.new()
	if d.offers.size() != seeded._offers.size(): return false
	var expected_lines: Array[Dictionary] = []
	var active_count: int = 0
	var credits: int = 0
	var ship_key: String = "preview_heavy" if d.heavy_mode else "preview_ship"
	for id: String in seeded._offers:
		var row: Variant = d.offers.get(id)
		if not row is Dictionary or row.size() != seeded._offers[id].size(): return false
		for key: String in seeded._offers[id]:
			if key not in ["state", "owner_id", "ship_id", "accepted_ms"] and row.get(key) != seeded._offers[id][key]: return false
		if row.get("state") not in ["available", "accepted", "loaded", "delivered"] or not row.get("accepted_ms") is int: return false
		if row.state == "available":
			if row.get("owner_id") != "" or row.get("ship_id") != "" or row.accepted_ms != -1: return false
		else:
			if row.get("owner_id") != d.owner or row.get("ship_id") != "preview_ship" or row.accepted_ms < 0 or row.accepted_ms > d.clock: return false
		if row.state in ["accepted", "loaded"]:
			active_count += 1
			if d.heavy_mode: return false
		if row.state == "loaded": expected_lines.append(seeded.batch(row))
		if row.state == "delivered": credits += row.reward_minor
		if row.state == "accepted" and (d.loading_offer != id or not d.docked or row.origin_port_id != PORT_IDS[d.port]): return false
	if active_count > 1 or lines != expected_lines: return false
	if d.operations.get("version") != 1 or not d.operations.get("records") is Dictionary or d.operations.records.size() > 10000: return false
	var live: int = 0
	var committed_offers: Array[String] = []
	for id: Variant in d.operations.records:
		var e: Variant = d.operations.records[id]
		if not id is String or not e is Dictionary or e.size() != 8 or e.get("id") != id or e.get("ship_id") != ship_key or e.get("rule_id") != "port_loading" or not e.get("payload") is Dictionary or not e.get("message") is String: return false
		var offer: Variant = d.offers.get(e.payload.get("offer_id"))
		if not offer is Dictionary or not number(e.get("duration"), .001, 86400) or e.duration != offer.quantity * 5.0 or not number(e.get("elapsed"), 0, e.duration): return false
		if e.get("state") not in ["reserved", "running", "ready", "committed", "cancelled", "interrupted", "failed"]: return false
		if e.state == "reserved" and e.elapsed != 0: return false
		if e.state in ["ready", "committed"] and e.elapsed != e.duration: return false
		if e.state == "running" and e.elapsed >= e.duration: return false
		if e.state == "committed":
			if offer.state not in ["loaded", "delivered"] or committed_offers.has(offer.id): return false
			committed_offers.append(offer.id)
		if e.state not in Operations.TERMINAL:
			live += 1
			if d.loading != id or d.loading_offer != offer.id or offer.state != "accepted" or not d.docked: return false
	if live > 1 or (live == 0 and (not d.loading.is_empty() or not d.loading_offer.is_empty())): return false
	for row: Dictionary in d.offers.values():
		if row.state == "accepted" and live != 1: return false
		if row.state == "loaded" and not committed_offers.has(row.id): return false
	var jobs = HeavyJobs.new()
	var possible: Dictionary = {}
	for port: String in PORT_IDS:
		for row: Dictionary in jobs.list_at(port): possible[row.id] = row
	if d.heavy_completed.size() > 6: return false
	for id: Variant in d.heavy_completed:
		if not heavy_job_valid(d.heavy_completed[id], possible) or d.heavy_completed[id].id != id or d.heavy_completed[id].state != "carrying": return false
		credits += possible[id].reward_minor
	if d.credits != credits: return false
	if not d.heavy_mode: return d.heavy.is_empty()
	var h: Dictionary = d.heavy
	if h.size() != 6 or not h.get("active") is Dictionary or h.get("completed") != d.heavy_completed or not h.get("attached") is bool: return false
	if not number(h.get("height"), Heavy.LOWERED, Heavy.RAISED) or not number(h.get("target"), Heavy.LOWERED, Heavy.RAISED) or not pose_valid(h.get("payload_pose")): return false
	if h.active.is_empty(): return not h.attached
	if active_count > 0 or not heavy_job_valid(h.active, possible) or d.heavy_completed.has(h.active.id): return false
	return h.attached == (h.active.state == "carrying")

static func heavy_job_valid(job: Variant, possible: Dictionary) -> bool:
	if not job is Dictionary or job.size() != 5 or not possible.has(job.get("id")): return false
	if job.get("state") not in ["pickup", "carrying"] or job.get("origin") not in PORT_IDS or job.get("reward_minor") != possible[job.id].reward_minor: return false
	if not job.id.begins_with(job.origin + "_heavy_") or not job.get("drop") is Vector3 or not job.drop.is_finite(): return false
	var origin_x: float = 0 if job.origin == PORT_IDS[0] else 1500
	var side: float = 1 if job.origin == PORT_IDS[0] else -1
	return absf(job.drop.y) < .01 and job.drop.z >= -1200 and job.drop.z <= -800 and (job.drop.x - origin_x) * side >= 450 and (job.drop.x - origin_x) * side <= 850

static func restore(view: Node3D, data: Dictionary) -> bool:
	if not valid(data): return false
	view.heavy_mode = data.heavy_mode
	view.select_port(data.port)
	await view.get_tree().physics_frame # Deferred floating-body creation must finish.
	if not is_instance_valid(view.ship): return false
	var body: HandlingShip = view.ship
	body.global_transform = data.pose
	body.zero_throttle()
	body.actual_throttle = 0
	body.velocity = Vector3.ZERO
	body.state.fuel_liters = data.fuel
	body.state.condition = data.condition
	view.offers._offers = data.offers.duplicate(true)
	view.offers._now_ms = data.clock
	view.offer_time = data.clock / 1000.0
	var lines: Array[Dictionary] = []
	for row: Dictionary in data.manifest: lines.append(row)
	if not body.state.manifest.replace(lines).ok: return false
	view.reward_minor = data.credits
	view.heavy_jobs.completed = data.heavy_completed.duplicate(true)
	if data.heavy_mode:
		var h: Dictionary = data.heavy
		body.deck_height = h.height
		body.deck_target = h.target
		body.deck_visual.position.y = h.height - Heavy.RAISED
		body.deck_shape.position.y = h.height - .45
		body.cargo_mount.position.y = h.height
		body.payload_shape.position.y = h.height + 4
		body.payload_body.global_transform = h.payload_pose
		body.attached = h.attached
		view.heavy_jobs.active = h.active.duplicate(true)
		if h.attached:
			body.payload_visual.reparent(body.cargo_mount, false)
			body.payload_visual.transform = Transform3D.IDENTITY
			body.payload_shape.disabled = false
		body.payload_body.collision_layer = CollisionRules.HULL if not h.attached and not h.active.is_empty() else 0
		body.payload_body.visible = not h.active.is_empty()
		if not h.active.is_empty(): body.release_guard = func(): return view.heavy_jobs.can_release(body)
	if data.docked:
		if not view.docking.request_dock(1, view.service_id(), view.cargo_id()).ok: return false
		view.docking.advance(1.1)
		if view.docking.state(1) != "docked": return false
	var operations: Dictionary = data.operations.duplicate(true)
	for record: Dictionary in operations.records.values(): record.ship_id = body.state.instance_id
	if not body.state.operations.restore(operations): return false
	if not data.loading.is_empty() and body.state.operations.record(data.loading).state == "reserved": body.state.operations.start(data.loading)
	view.loading.sequence = data.sequence
	view.loading.operation = data.loading
	view.loading.offer_id = data.loading_offer
	view.refresh_jobs()
	view.controls.wait_for_release = true
	return true
