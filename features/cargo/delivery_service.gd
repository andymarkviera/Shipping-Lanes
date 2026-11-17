extends RefCounted
## Trusted local authority boundary. Never accept a client view/snapshot/price.
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
const Offers = preload("res://features/cargo/container_offers.gd")
const Manifest = preload("res://features/cargo/cargo_manifest.gd")

func reason(view: Node3D) -> String:
	if view.heavy_mode: return "Heavy cargo is delivered at its ocean destination."
	if view.loading.busy(): return "Wait for loading to finish."
	if is_instance_valid(view.persistence) and not view.persistence.ready_to_save: return "Voyage saving is unavailable."
	var entry: Dictionary = view.docking.members.get(view.owner_id, {})
	if entry.get("body") != view.ship or entry.get("port") != view.port or entry.get("state") != "docked" or not view.ship.docked: return "Dock at the destination first."
	var job: Dictionary = view.offers.active_job("preview_captain")
	if job.is_empty() or job.state != "loaded" or job.ship_id != view.ship_key(): return "No loaded job to deliver."
	if job.destination_port_id != view.port.definition.id: return "This cargo belongs at " + port_name(job.destination_port_id) + "."
	return ""

func deliver(view: Node3D) -> Dictionary:
	var error: String = reason(view)
	if not error.is_empty(): return {"ok": false, "message": error}
	# Prepare on copies. A failed or unconfirmed commit cannot consume live cargo.
	var offers = Offers.new()
	offers._offers = view.offers._offers.duplicate(true)
	var manifest = Manifest.new(view.ship.definition, PrototypeCatalog.RECORDS)
	if not manifest.replace(view.ship.state.manifest.lines()).ok: return {"ok": false, "message": "Cargo could not be verified."}
	var result: Dictionary = offers.deliver_at("preview_captain", view.ship_key(), view.port.definition.id, manifest, true)
	if not result.ok: return result
	var candidate: Dictionary = Snapshot.capture(view)
	candidate.offers = offers._offers.duplicate(true)
	candidate.manifest = manifest.lines()
	candidate.credits += result.reward_minor
	if not Snapshot.valid(candidate): return {"ok": false, "message": "Delivery could not be verified; cargo unchanged."}
	if is_instance_valid(view.persistence) and not view.persistence.commit_snapshot(candidate):
		return {"ok": false, "message": "Delivery was not confirmed. Reopen the voyage to recover safely."}
	# No awaits between durable commit and applying its authoritative result.
	view.offers._offers = candidate.offers.duplicate(true)
	view.reward_minor = candidate.credits
	view.ship.state.manifest.replace(manifest.lines())
	return {"ok": true, "message": "Delivery complete — paid %.2f credits." % (result.reward_minor / 100.0)}

static func port_name(id: String) -> String:
	return PrototypeCatalog.display_name(id)

static func receipts(offers: RefCounted, owner: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for job: Dictionary in offers._offers.values():
		if job.state != "delivered" or job.owner_id != owner: continue
		rows.append({"id": "delivery_" + job.id, "job_id": job.id, "origin": job.origin_port_id, "destination": job.destination_port_id, "quantity": job.quantity, "reward_minor": job.reward_minor, "accepted_ms": job.accepted_ms})
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return a.accepted_ms < b.accepted_ms if a.accepted_ms != b.accepted_ms else a.id < b.id)
	return rows

static func receipt_text(offers: RefCounted) -> String:
	var rows: Array[Dictionary] = receipts(offers, "preview_captain")
	if rows.is_empty(): return ""
	var row: Dictionary = rows.back()
	return "DELIVERY RECEIPT\n%d container%s delivered to %s\nPaid %.2f credits" % [row.quantity, "" if row.quantity == 1 else "s", port_name(row.destination), row.reward_minor / 100.0]
