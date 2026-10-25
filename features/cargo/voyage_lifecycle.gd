extends RefCounted
## Trusted authority transitions. No client-supplied snapshot, identity or reward.
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
const Offers = preload("res://features/cargo/container_offers.gd")
const Operations = preload("res://features/cargo/cargo_operation.gd")

static func end_job(view: Node3D, abandon_loaded: bool = false) -> Dictionary:
	if is_instance_valid(view.persistence) and not view.persistence.ready_to_save: return outcome(false, "Saving is unavailable; job unchanged.")
	var data: Dictionary = Snapshot.capture(view)
	if not Snapshot.valid(data): return outcome(false, "Job state could not be verified; unchanged.")
	var job: Dictionary = view.offers.active_job("preview_captain")
	if view.heavy_mode:
		if view.heavy_jobs.active.is_empty(): return outcome(false, "No pickup to cancel.")
		if view.ship.attached or view.heavy_jobs.active.state != "pickup": return outcome(false, "Deliver the heavy load before ending its job.")
		data.heavy.active = {}
	else:
		if job.is_empty(): return outcome(false, "No active job.")
		if job.ship_id != view.ship_key(): return outcome(false, "Job belongs to another ship.")
		if job.state == "loaded":
			if not abandon_loaded: return outcome(false, "Cargo is already loaded. Use Abandon cargo to forfeit it without payment.")
			data.offers[job.id].state = "abandoned"
			data.manifest.clear()
		else:
			data.offers[job.id] = Offers.new().view(job.id)
			for record: Dictionary in data.operations.records.values():
				if record.payload.get("offer_id") == job.id and record.state in ["reserved", "running", "ready"]:
					record.state = "cancelled"
					record.message = "Cancelled by captain; no cargo or payment."
			data.loading = ""
			data.loading_offer = ""
	if not Snapshot.valid(data): return outcome(false, "Cannot end this job safely; unchanged.")
	var records: Dictionary = data.operations.duplicate(true)
	for record: Dictionary in records.records.values(): record.ship_id = view.ship.state.instance_id
	var operations = Operations.new()
	operations.register_rule("port_loading", view.loading.rule)
	operations.register_rule("manifest", preload("res://features/cargo/manifest_operation_rule.gd").new(view.ship.state.instance_id, view.ship.state.manifest))
	if not operations.restore(records): return outcome(false, "Cannot release this job's operation safely.")
	if is_instance_valid(view.persistence) and not view.persistence.commit_snapshot(data): return outcome(false, "Job change was not confirmed. Reopen to recover safely.")
	view.offers._offers = data.offers.duplicate(true)
	view.ship.state.operations = operations
	view.loading.operation = data.loading
	view.loading.offer_id = data.loading_offer
	var lines: Array[Dictionary] = []
	for line: Dictionary in data.manifest: lines.append(line)
	view.ship.state.manifest.replace(lines)
	if view.heavy_mode:
		view.heavy_jobs.active.clear()
		view.ship.release_guard = Callable()
		view.ship.payload_body.collision_layer = 0
		view.ship.payload_body.hide()
	return outcome(true, "Cargo abandoned — no payment. Job closed." if job.get("state") == "loaded" else "Job cancelled — no cargo or payment.")

static func outcome(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

static func reconcile(value: Variant) -> Dictionary:
	# Repair only provably unfinished orphan commitments. Never infer lost cargo,
	# undo a receipt, alter credits, or erase malformed paid/loaded state.
	if Snapshot.valid(value): return {"ok": true, "changed": false, "data": value}
	if not value is Dictionary: return {"ok": false}
	var d: Dictionary = value.duplicate(true)
	if not d.get("manifest") is Array or not d.manifest.is_empty() or not d.get("offers") is Dictionary or not d.get("operations") is Dictionary or not d.operations.get("records") is Dictionary: return {"ok": false}
	var seeded = Offers.new()
	var repaired: bool = false
	var accepted_count: int = 0
	for row: Variant in d.offers.values():
		if row is Dictionary and row.get("state") == "accepted": accepted_count += 1
	if accepted_count != 1: return {"ok": false}
	for id: Variant in d.offers:
		var job: Variant = d.offers[id]
		if not job is Dictionary or job.get("state") != "accepted": continue
		if not seeded._offers.has(id) or job.get("owner_id") != "preview_captain" or job.get("ship_id") != "preview_ship" or not job.get("accepted_ms") is int or not d.get("clock") is int or job.accepted_ms < 0 or job.accepted_ms > d.clock: return {"ok": false}
		if job.size() != seeded._offers[id].size(): return {"ok": false}
		for key: String in seeded._offers[id]:
			if key not in ["state", "owner_id", "ship_id", "accepted_ms"] and job.get(key) != seeded._offers[id][key]: return {"ok": false}
		var live_ids: Array[String] = []
		for operation_id: Variant in d.operations.records:
			var record: Variant = d.operations.records[operation_id]
			if not operation_id is String or not record is Dictionary or not record.get("payload") is Dictionary: return {"ok": false}
			if record.payload.get("offer_id") != id: continue
			if record.get("state") in ["committed", "committing"]: return {"ok": false}
			if record.get("state") in ["reserved", "running", "ready"]: live_ids.append(operation_id)
		var intact: bool = live_ids.size() == 1 and d.get("loading") == live_ids[0] and d.get("loading_offer") == id and d.get("docked") == true and d.get("port") is int and d.get("port") in [0, 1] and job.origin_port_id == Snapshot.PORT_IDS[d.port]
		if intact: continue # Some other inconsistency is not ours to repair.
		for operation_id: String in live_ids:
			d.operations.records[operation_id].state = "interrupted"
			d.operations.records[operation_id].message = "Orphan loading released during recovery; no cargo or payment."
		d.offers[id] = seeded.view(id)
		# Refuse unrelated/malformed operation pointers instead of erasing them.
		if d.get("loading_offer") not in ["", id] or not d.get("loading") is String or (not d.loading.is_empty() and not live_ids.has(d.loading)): return {"ok": false}
		d.loading = ""
		d.loading_offer = ""
		repaired = true
	if not repaired or not Snapshot.valid(d): return {"ok": false}
	return {"ok": true, "changed": true, "data": d}

static func before_ship_removal(view: Node3D) -> Dictionary:
	# Future sinking/despawn callers must honor ok before removing the ship.
	if is_instance_valid(view.persistence) and not view.persistence.ready_to_save:
		return outcome(false, "Saving is unavailable; keep the ship for recovery.")
	if not view.heavy_jobs.active.is_empty() or not view.offers.active_job("preview_captain").is_empty():
		return end_job(view, true)
	return outcome(Snapshot.valid(Snapshot.capture(view)), "No active voyage cargo to release.")
