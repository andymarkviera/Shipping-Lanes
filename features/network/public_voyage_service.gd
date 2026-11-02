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
	if owner.voyage_busy or owner.checkpoint_busy or owner.damage_pending or owner.recovery_placing or owner.authority.busy: return {"ok": false, "code": "BUSY"}
	if owner.recovery_required(): return {"ok": false, "code": "RECOVERY_REQUIRED"}
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
		if previous.state == "delivered": receipt = {"quantity": int(previous.quantity), "destination": previous.destination, "amount": int(previous.get("paid_minor", previous.reward_minor)), "repaid": int(previous.get("recovery_repaid_minor", 0))}
	for offer: Dictionary in preload("res://features/cargo/container_offers.gd").new().list_at(port):
		if not closed.has(offer.id): rows.append({"id": offer.id, "quantity": offer.quantity, "destination": offer.destination_port_id, "reward": offer.reward_minor})
	var remaining: int = maxi(0, int(job.get("ready_ms", 0)) - int(Time.get_unix_time_from_system() * 1000)) if job.get("state") == "loading" else 0
	return {"fuel_capacity": owner.ship.definition.fuel_capacity_liters, "condition_bp": int(owner.public_profile.ship.get("condition_bp", 10000)), "recovery": owner.public_profile.get("recovery", {}), "recovery_debt_minor": int(owner.public_profile.get("recovery_debt_minor", 0)), "damage_pending": owner.damage_pending, "recovery_placing": owner.recovery_placing, "refuel": fuel_quote(peer), "repair": repair_quote(peer), "ship_catalog": ship_quotes(peer), "stored_ship_count": owner.public_profile.get("stored_ships", []).size(), "fleet": preload("res://features/catalog/fleet_inspection.gd").fleet(owner) if not port.is_empty() else [], "job": job, "offers": rows, "wallet": owner.wallet_minor, "cargo": count(owner), "remaining_ms": remaining, "busy": owner.voyage_busy or owner.damage_pending or owner.recovery_placing, "port": port, "receipt": receipt, "ack": record.voyage_sequence, "message": record.voyage_notice}

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
		var wrecks: Array = []
		for other: Dictionary in session.members.values():
			if session.Nav.separation(owner.current_address(), other.hull.current_address()) <= session.Nav.LOCAL_RANGE_M:
				counts[other.ship] = count(other.hull)
				if other.hull.recovery_required() or other.hull.recovery_placing: wrecks.append(other.ship)
		var data: Dictionary = view(peer)
		data.wrecks = wrecks
		session.voyage_update.rpc_id(peer, record.ship, record.epoch, record.generation, data, counts)

func complete_load(peer: int) -> void:
	var record: Dictionary = session.members.get(peer, {})
	var result: Dictionary = await execute(peer, "load")
	if session.members.get(peer) == record and result.get("code") not in ["BUSY", "LOADING_PENDING"]:
		session.members[peer].voyage_notice = message(result.get("code", "OUTCOME_UNKNOWN"))

static func message(code: String) -> String:
	match code:
		"RECOVERY_REQUIRED": return "Ship sunk. Recover before using port services."
		"SHIP_RECOVERED": return "Recovery saved. Returning to clear water near Brindle Quay."
		"NO_RECOVERY": return "No pending recovery. No additional fee charged."
		"RECOVERY_SPACE_BUSY": return "Recovery area occupied. Wait for space, then try again; no new charge."
		"JOB_ACCEPTED": return "Job accepted. Loading cargo…"
		"CARGO_LOADED": return "Cargo loaded. You can undock."
		"VOYAGE_DELIVERED": return "Delivery paid and saved."
		"JOB_CLOSED": return "Job closed. No payment."
		"DOCK_FIRST": return "Dock before using port services."
		"REFUELED": return "Propulsion fuel purchased and saved."
		"SHIP_PURCHASED": return "Ship purchased and saved in storage."
		"FLEET_LIMIT": return "Ship storage is full (100 ships). No charge."
		"REPAIRED": return "Boat condition restored and payment saved."
		"NO_REPAIR_NEEDED": return "Boat condition is already full. No charge."
		"NO_REPAIR_SERVICE": return "Repair is unavailable at this berth or while loading."
		"QUOTE_CHANGED": return "Service quote changed. Review the new quote and try again."
		"TANK_SPACE": return "Not enough space in the propulsion tank."
		"INSUFFICIENT_FUNDS": return "Not enough credits for this service."
		"BAD_QUANTITY": return "Choose a whole number of liters within tank space."
		"NO_REFUEL_SERVICE": return "Refueling is unavailable at this berth."
		"BUSY", "LOCAL_BUSY": return "Saving or processing a request. Wait, then try again."
		"WRONG_PORT": return "This job belongs at the other port."
		"JOB_ALREADY_ACTIVE": return "Finish or cancel your current job first."
		"JOB_NOT_ACTIVE": return "No active job."
		"CONFIRM_ABANDON": return "Confirm abandonment to remove loaded cargo without payment."
		"LOADING_PENDING": return "Loading is still in progress."
		"HOLD_FULL": return "The ship does not have enough cargo space."
		"OFFER_CLOSED": return "This job is already closed. Choose another."
	return "Request not completed (" + code + "). Reconnect if your save could not be confirmed."

# Quotes are bound to this peer's current dock, live tank and wallet. Consuming a
# quote before awaiting prevents a second click/new sequence from purchasing twice.
const FUEL_PRICE_MINOR: int = 25
func fuel_quote(peer: int) -> Dictionary:
	var record: Dictionary = session.members[peer]
	var owner: Node3D = record.hull
	var port_id: String = docked_port(peer)
	var port: Node3D = session.physics_world.port_for(owner, port_id) if not port_id.is_empty() else null
	if owner.recovery_required() or owner.damage_pending or owner.recovery_placing or port == null or not port.definition.service_ids.has("refuel") or not port.berth.service_ids.has("refuel") or active(owner).get("state") == "loading":
		record.erase("fuel_quote")
		return {}
	var fuel: float = owner.ship.state.fuel_liters
	var capacity: float = owner.ship.definition.fuel_capacity_liters
	var key: Array = [port_id, fuel, owner.wallet_minor]
	var quote: Dictionary = record.get("fuel_quote", {})
	if quote.get("key") != key or Time.get_ticks_msec() >= int(quote.get("until", 0)):
		quote = {"id": Crypto.new().generate_random_bytes(16).hex_encode(), "key": key, "until": Time.get_ticks_msec() + 30000, "fuel": fuel, "capacity": capacity, "max_liters": maxi(0, floori(capacity - fuel)), "unit_price_minor": FUEL_PRICE_MINOR}
		record.fuel_quote = quote
	var public_quote: Dictionary = quote.duplicate(true)
	public_quote.erase("key")
	public_quote.erase("until")
	return public_quote

func refuel(peer: int, quote_id: String, liters: int) -> Dictionary:
	if not session.members.has(peer): return {"ok": false, "code": "DISCONNECTED"}
	var record: Dictionary = session.members[peer]
	var owner: Node3D = record.hull
	if owner.departing or not owner.authority.active: return {"ok": false, "code": "DISCONNECTED"}
	if owner.voyage_busy or owner.checkpoint_busy or owner.damage_pending or owner.recovery_placing or owner.authority.busy: return {"ok": false, "code": "BUSY"}
	var port: String = docked_port(peer)
	if port.is_empty(): return {"ok": false, "code": "DOCK_FIRST"}
	var quote: Dictionary = fuel_quote(peer)
	if quote.is_empty(): return {"ok": false, "code": "NO_REFUEL_SERVICE"}
	if quote.get("id") != quote_id: return {"ok": false, "code": "QUOTE_CHANGED"}
	if liters < 1 or liters > 1000: return {"ok": false, "code": "BAD_QUANTITY"}
	if liters > int(quote.max_liters): return {"ok": false, "code": "TANK_SPACE"}
	if liters * FUEL_PRICE_MINOR > owner.wallet_minor: return {"ok": false, "code": "INSUFFICIENT_FUNDS"}
	owner.voyage_busy = true
	record.erase("fuel_quote")
	# Save actual fuel burned since the last sailing checkpoint before purchasing.
	var current: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
	if not current.get("ok", false):
		owner.authority.quiesce()
		owner.voyage_busy = false
		return current
	var address: Dictionary = owner.current_address()
	var saved: Dictionary = await owner.authority.request(owner.authority.owned("checkpoint", {"expected_revision": int(current.revision), "position": {"latitude": address.latitude_deg, "longitude": address.longitude_deg, "heading": address.heading_deg}, "fuel_liters": owner.ship.state.fuel_liters}))
	if not saved.get("ok", false):
		owner.authority.quiesce()
		owner.voyage_busy = false
		return saved
	if owner.departing or not owner.authority.active or docked_port(peer) != port:
		owner.voyage_busy = false
		return {"ok": false, "code": "DISCONNECTED"}
	var result: Dictionary = await owner.authority.request(owner.authority.owned("refuel", {"action_id": "fuel_" + quote_id, "expected_revision": int(saved.revision), "port_id": port, "liters": liters, "unit_price_minor": FUEL_PRICE_MINOR}))
	if owner.authority.active:
		var fresh: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
		if fresh.get("ok", false):
			owner.install_profile(fresh)
			if result.get("ok", false): owner.ship.state.fuel_liters = float(fresh.profile.ship.fuel_liters)
		else: owner.authority.quiesce()
	# Invalidate any quote formed by snapshot polling during the transaction.
	record.erase("fuel_quote")
	owner.voyage_busy = false
	return result

# Shared per-definition full-restoration prices; also loaded by the backend.
var repair_costs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://services/public_authority/repair_costs.json"))

func repair_quote(peer: int) -> Dictionary:
	var record: Dictionary = session.members[peer]
	var owner: Node3D = record.hull
	var port_id: String = docked_port(peer)
	var port: Node3D = session.physics_world.port_for(owner, port_id) if not port_id.is_empty() else null
	var definition: String = str(owner.public_profile.ship.definition)
	if owner.departing or not owner.authority.active or owner.voyage_busy or owner.checkpoint_busy or owner.authority.busy or owner.recovery_required() or owner.damage_pending or owner.recovery_placing or port == null or not port.definition.service_ids.has("repair") or not port.berth.service_ids.has("repair") or active(owner).get("state") == "loading" or not repair_costs.has(definition):
		record.erase("repair_quote")
		return {}
	# Include unsettled simulated wear in the quote. Acceptance checkpoints it first.
	var condition: int = int(owner.public_profile.ship.get("condition_bp", 10000))
	var fraction: float = float(owner.public_profile.ship.get("wear_fraction_bp", 0.0))
	var elapsed: float = owner.operating_seconds
	condition = maxi(mini(condition, 1000), condition - int(fraction + elapsed * 100.0 / 3600.0))
	if condition <= 0 or condition > 10000: return {}
	var full_cost: int = int(repair_costs[definition])
	if full_cost <= 0 or full_cost > 900000000: return {}
	@warning_ignore("integer_division")
	var cost: int = ((10000 - condition) * full_cost + 9999) / 10000
	var key: Array = [port_id, definition, condition, fraction, elapsed, owner.wallet_minor, full_cost]
	var quote: Dictionary = record.get("repair_quote", {})
	if quote.get("key") != key or Time.get_ticks_msec() >= int(quote.get("until", 0)):
		quote = {"id": Crypto.new().generate_random_bytes(16).hex_encode(), "key": key, "until": Time.get_ticks_msec() + 30000, "condition_bp": condition, "restored_bp": 10000 - condition, "cost_minor": cost}
		record.repair_quote = quote
	var public_quote: Dictionary = quote.duplicate(true)
	public_quote.erase("key")
	public_quote.erase("until")
	return public_quote

func repair(peer: int, quote_id: String) -> Dictionary:
	if not session.members.has(peer): return {"ok": false, "code": "DISCONNECTED"}
	var record: Dictionary = session.members[peer]
	var owner: Node3D = record.hull
	if owner.departing or not owner.authority.active: return {"ok": false, "code": "DISCONNECTED"}
	if owner.voyage_busy or owner.checkpoint_busy or owner.damage_pending or owner.recovery_placing or owner.authority.busy: return {"ok": false, "code": "BUSY"}
	var port: String = docked_port(peer)
	if port.is_empty(): return {"ok": false, "code": "DOCK_FIRST"}
	var quote: Dictionary = repair_quote(peer)
	if quote.is_empty(): return {"ok": false, "code": "NO_REPAIR_SERVICE"}
	if quote.id != quote_id: return {"ok": false, "code": "QUOTE_CHANGED"}
	if int(quote.restored_bp) == 0: return {"ok": false, "code": "NO_REPAIR_NEEDED"}
	if int(quote.cost_minor) > owner.wallet_minor: return {"ok": false, "code": "INSUFFICIENT_FUNDS"}
	owner.voyage_busy = true
	record.erase("repair_quote")
	var current: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
	if not current.get("ok", false):
		owner.authority.quiesce()
		owner.voyage_busy = false
		return current
	var address: Dictionary = owner.current_address()
	var elapsed: float = owner.operating_seconds
	var saved: Dictionary = await owner.authority.request(owner.authority.owned("checkpoint", {"operating_seconds": elapsed, "expected_revision": int(current.revision), "position": {"latitude": address.latitude_deg, "longitude": address.longitude_deg, "heading": address.heading_deg}, "fuel_liters": owner.ship.state.fuel_liters}))
	if not saved.get("ok", false):
		owner.authority.quiesce()
		owner.voyage_busy = false
		return saved
	owner.operating_seconds = maxf(0.0, owner.operating_seconds - elapsed)
	owner.public_profile.ship.condition_bp = int(saved.condition_bp)
	owner.ship.state.condition = int(saved.condition_bp) / 10000.0
	if owner.departing or not owner.authority.active or docked_port(peer) != port:
		owner.voyage_busy = false
		return {"ok": false, "code": "DISCONNECTED"}
	var result: Dictionary = await owner.authority.request(owner.authority.owned("repair", {"action_id": "repair_" + quote_id, "expected_revision": int(saved.revision), "port_id": port, "condition_bp": int(quote.condition_bp), "cost_minor": int(quote.cost_minor)}))
	if owner.authority.active:
		var fresh: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
		if fresh.get("ok", false): owner.install_profile(fresh)
		else: owner.authority.quiesce()
	record.erase("repair_quote")
	owner.voyage_busy = false
	return result

# Immutable catalog data shared with the canonical backend. Purchases remain stored;
# activating/switching hulls belongs to Step 65.
var ship_catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://services/public_authority/ship_catalog.json"))

func ship_quotes(peer: int) -> Array:
	var record: Dictionary = session.members[peer]
	var owner: Node3D = record.hull
	var port_id: String = docked_port(peer)
	var port: Node3D = session.physics_world.port_for(owner, port_id) if not port_id.is_empty() else null
	if owner.departing or not owner.authority.active or owner.voyage_busy or owner.checkpoint_busy or owner.authority.busy or owner.recovery_required() or owner.damage_pending or owner.recovery_placing or port == null or not port.definition.service_ids.has("ship_catalog") or not port.berth.service_ids.has("ship_catalog") or active(owner).get("state") == "loading":
		record.erase("ship_quotes")
		return []
	var key: Array = [port_id, owner.wallet_minor, ship_catalog]
	var cached: Dictionary = record.get("ship_quotes", {})
	if cached.get("key") != key or Time.get_ticks_msec() >= int(cached.get("until", 0)):
		var rows: Array = ship_catalog.duplicate(true)
		for row: Dictionary in rows:
			row.id = Crypto.new().generate_random_bytes(16).hex_encode()
		cached = {"key": key.duplicate(true), "until": Time.get_ticks_msec() + 30000, "rows": rows}
		record.ship_quotes = cached
	return cached.rows.duplicate(true)

func purchase_ship(peer: int, quote_id: String) -> Dictionary:
	if not session.members.has(peer): return {"ok": false, "code": "DISCONNECTED"}
	var record: Dictionary = session.members[peer]
	var owner: Node3D = record.hull
	if owner.departing or not owner.authority.active: return {"ok": false, "code": "DISCONNECTED"}
	if owner.voyage_busy or owner.checkpoint_busy or owner.damage_pending or owner.recovery_placing or owner.authority.busy: return {"ok": false, "code": "BUSY"}
	var port: String = docked_port(peer)
	if port.is_empty(): return {"ok": false, "code": "DOCK_FIRST"}
	var quote: Dictionary = {}
	for row: Dictionary in ship_quotes(peer):
		if row.id == quote_id: quote = row
	if quote.is_empty(): return {"ok": false, "code": "QUOTE_CHANGED"}
	if int(quote.cost_minor) > owner.wallet_minor: return {"ok": false, "code": "INSUFFICIENT_FUNDS"}
	owner.voyage_busy = true
	record.erase("ship_quotes")
	# Preserve all unsettled live state before installing the canonical purchase.
	var current: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
	if not current.get("ok", false):
		owner.authority.quiesce()
		owner.voyage_busy = false
		return current
	var address: Dictionary = owner.current_address()
	var elapsed: float = owner.operating_seconds
	var saved: Dictionary = await owner.authority.request(owner.authority.owned("checkpoint", {"operating_seconds": elapsed, "expected_revision": int(current.revision), "position": {"latitude": address.latitude_deg, "longitude": address.longitude_deg, "heading": address.heading_deg}, "fuel_liters": owner.ship.state.fuel_liters}))
	if not saved.get("ok", false):
		owner.authority.quiesce()
		owner.voyage_busy = false
		return saved
	owner.operating_seconds = maxf(0.0, owner.operating_seconds - elapsed)
	owner.public_profile.ship.condition_bp = int(saved.condition_bp)
	owner.ship.state.condition = int(saved.condition_bp) / 10000.0
	if owner.departing or not owner.authority.active or docked_port(peer) != port:
		owner.voyage_busy = false
		return {"ok": false, "code": "DISCONNECTED"}
	var result: Dictionary = await owner.authority.request(owner.authority.owned("ship_purchase", {"action_id": "ship_" + quote_id, "expected_revision": int(saved.revision), "port_id": port, "definition_id": str(quote.definition), "cost_minor": int(quote.cost_minor)}))
	if owner.authority.active:
		var fresh: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
		if fresh.get("ok", false): owner.install_profile(fresh)
		else: owner.authority.quiesce()
	record.erase("ship_quotes")
	owner.voyage_busy = false
	return result
