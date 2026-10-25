extends Node
## Authenticated game-server bridge. Client never supplies account, port, cargo or price.
var session: Node
var next_poll: int = 0

static func active(owner: Node3D) -> Dictionary:
	for job: Dictionary in owner.public_profile.get("jobs", []):
		if job.get("kind") == "container_voyage_v1" and job.get("state") in ["loading", "loaded"]: return job.duplicate(true)
	return {}

static func count(owner: Node3D) -> int:
	var total: int = 0
	for cargo: Dictionary in owner.cargo_records: total += int(cargo.get("quantity", 1))
	return clampi(total, 0, 6)

func docked_port(peer: int) -> String:
	if not session.port_authority.entries.has(peer): return ""
	var entry: Dictionary = session.port_authority.entries[peer]
	return entry.port_id if entry.state == "docked" and entry.owner.ship.docked else ""

func execute(peer: int, action: String, offer_id: String = "", abandon: bool = false) -> Dictionary:
	if not session.members.has(peer): return {"ok": false, "code": "DISCONNECTED"}
	var owner: Node3D = session.members[peer].hull
	if owner.departing or not owner.authority.active: return {"ok": false, "code": "DISCONNECTED"}
	if owner.voyage_busy or owner.checkpoint_busy or owner.authority.busy: return {"ok": false, "code": "BUSY"}
	var port_id: String = docked_port(peer)
	if port_id.is_empty(): return {"ok": false, "code": "DOCK_FIRST"}
	owner.voyage_busy = true
	var current: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
	if not current.get("ok", false):
		owner.authority.quiesce()
		owner.voyage_busy = false
		return current
	owner.install_profile(current)
	if owner.departing or not owner.authority.active or docked_port(peer) != port_id:
		owner.voyage_busy = false
		return {"ok": false, "code": "DISCONNECTED"}
	var job: Dictionary = active(owner)
	var args: Dictionary = {"action_id": "voyage_" + Crypto.new().generate_random_bytes(16).hex_encode(), "expected_revision": int(current.revision)}
	if action == "accept": args.merge({"offer_id": offer_id, "port_id": port_id})
	else:
		if job.is_empty():
			owner.voyage_busy = false
			return {"ok": false, "code": "JOB_NOT_ACTIVE"}
		args.job_id = job.id
		if action == "cancel": args.abandon = abandon
		else: args.port_id = port_id
	var result: Dictionary = await owner.authority.request(owner.authority.owned("voyage_" + action, args))
	# Ambiguous transport results fence the owner. Never manufacture a new retry ID.
	if owner.authority.active:
		var fresh: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
		if fresh.get("ok", false): owner.install_profile(fresh)
		else: owner.authority.quiesce()
	owner.voyage_busy = false
	return result

func view(peer: int) -> Dictionary:
	var record: Dictionary = session.members[peer]
	var owner: Node3D = record.hull
	var job: Dictionary = active(owner)
	var port: String = docked_port(peer)
	var rows: Array = []
	var closed: Array[String] = []
	var receipt: Dictionary = {}
	for previous: Dictionary in owner.public_profile.get("jobs", []):
		if previous.get("kind") != "container_voyage_v1": continue
		if previous.state in ["delivered", "abandoned"]: closed.append(previous.offer_id)
		if previous.state == "delivered": receipt = {"quantity": int(previous.quantity), "destination": previous.destination, "amount": int(previous.reward_minor)}
	for offer: Dictionary in preload("res://features/cargo/container_offers.gd").new().list_at(port):
		if not closed.has(offer.id): rows.append({"id": offer.id, "quantity": offer.quantity, "destination": offer.destination_port_id, "reward": offer.reward_minor})
	var remaining: int = maxi(0, int(job.get("ready_ms", 0)) - int(Time.get_unix_time_from_system() * 1000)) if job.get("state") == "loading" else 0
	return {"job": job, "offers": rows, "wallet": owner.wallet_minor, "cargo": count(owner), "remaining_ms": remaining, "busy": owner.voyage_busy, "port": port, "receipt": receipt, "ack": record.voyage_sequence, "message": record.voyage_notice}

func _process(_delta: float) -> void:
	if session == null or not session.hosting or session.draining: return
	var now: int = Time.get_ticks_msec()
	if now < next_poll: return
	next_poll = now + 500
	for peer: int in session.members.keys():
		var record: Dictionary = session.members[peer]
		var owner: Node3D = record.hull
		var job: Dictionary = active(owner)
		if job.get("state") == "loading" and docked_port(peer) == job.origin and not owner.voyage_busy and not owner.checkpoint_busy and not owner.authority.busy:
			if int(Time.get_unix_time_from_system() * 1000) >= int(job.ready_ms): complete_load(peer)
		var counts: Dictionary = {}
		for other: Dictionary in session.members.values():
			if session.Nav.separation(owner.current_address(), other.hull.current_address()) <= session.Nav.LOCAL_RANGE_M: counts[other.ship] = count(other.hull)
		session.voyage_update.rpc_id(peer, record.ship, record.epoch, record.generation, view(peer), counts)

func complete_load(peer: int) -> void:
	var record: Dictionary = session.members.get(peer, {})
	var result: Dictionary = await execute(peer, "load")
	if session.members.get(peer) == record and result.get("code") not in ["BUSY", "LOADING_PENDING"]:
		session.members[peer].voyage_notice = message(result.get("code", "OUTCOME_UNKNOWN"))

static func message(code: String) -> String:
	match code:
		"JOB_ACCEPTED": return "Job accepted. Loading cargo…"
		"CARGO_LOADED": return "Cargo loaded. You can undock."
		"VOYAGE_DELIVERED": return "Delivery paid and saved."
		"JOB_CLOSED": return "Job closed. No payment."
		"DOCK_FIRST": return "Dock before using cargo services."
		"BUSY", "LOCAL_BUSY": return "Saving or processing a request. Wait, then try again."
		"WRONG_PORT": return "This job belongs at the other port."
		"JOB_ALREADY_ACTIVE": return "Finish or cancel your current job first."
		"JOB_NOT_ACTIVE": return "No active job."
		"CONFIRM_ABANDON": return "Confirm abandonment to remove loaded cargo without payment."
		"LOADING_PENDING": return "Loading is still in progress."
		"HOLD_FULL": return "The ship does not have enough cargo space."
		"OFFER_CLOSED": return "This job is already closed. Choose another."
	return "Request not completed (" + code + "). Reconnect if your save could not be confirmed."
