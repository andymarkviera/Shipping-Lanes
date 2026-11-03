extends "res://features/cargo/container_offers.gd"
## Trusted local/server authority model. Never expose offer authoring or prices as RPCs.
## Uses the same registry/one-job guard as containers; bulk presentation is Step 70.
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")
const DENOMINATOR: int = 185200000000000000 # grams/tonne * metres/NM * basis points squared
const MAX_MONEY: int = 9000000000000
var _settlements: Dictionary = {}
var _settling: bool = false

# Exact floor of a product/divisor without overflowing int64 intermediate products.
# Quotient is bounded to the money contract; remainder is always below DENOMINATOR.
static func earnings(grams: int, terms: Dictionary) -> int:
	var q: int = 0
	var r: int = grams
	for multiplier: int in [terms.direct_distance_m, terms.rate_minor_per_tonne_nm, terms.origin_modifier_bp, terms.destination_modifier_bp]:
		var extra_q: int = 0
		var extra_r: int = 0
		var part_q: int = 0
		var part_r: int = r
		var bits: int = multiplier
		while bits > 0:
			if bits & 1:
				extra_q += part_q
				extra_r += part_r
				if extra_r >= DENOMINATOR:
					extra_r -= DENOMINATOR
					extra_q += 1
			bits >>= 1
			if bits > 0:
				part_q *= 2
				part_r *= 2
				if part_r >= DENOMINATOR:
					part_r -= DENOMINATOR
					part_q += 1
		if extra_q > MAX_MONEY or (multiplier > 0 and q > (MAX_MONEY - extra_q) / multiplier): return -1
		q = q * multiplier + extra_q
		r = extra_r
	return q

# Authored endpoints, not current ship position, odometer, waypoints or sailed route.
# Quotes are nonexpiring and immutable once published, including before acceptance.
func publish(id: String, cargo: String, grams: Variant, hold: String, origin: String, destination: String, locations: Dictionary, rates: Dictionary, modifiers: Dictionary) -> Dictionary:
	if id.is_empty() or id.length() > 64 or _offers.has(id) or _offers.size() >= 4096: return failure("Invalid or reused offer ID.")
	if not grams is int or grams <= 0 or grams > 1000000000: return failure("Invalid bulk quantity.")
	if cargo not in ["cargo_bulk_grain", "cargo_bulk_coal", "cargo_bulk_ore", "cargo_bulk_limestone"]: return failure("Unknown bulk commodity.")
	if hold.is_empty() or hold.length() > 128 or origin == destination: return failure("Invalid hold or same-port route.")
	var a: Dictionary = Geo.decode(locations.get(origin, {}))
	var b: Dictionary = Geo.decode(locations.get(destination, {}))
	if a.is_empty() or b.is_empty(): return failure("Missing geographic port address.")
	var rate: Variant = rates.get(cargo)
	var origin_bp: Variant = modifiers.get(origin)
	var destination_bp: Variant = modifiers.get(destination)
	if not rate is int or rate < 1 or rate > 1000000: return failure("Invalid commodity rate.")
	for modifier: Variant in [origin_bp, destination_bp]:
		if not modifier is int or modifier < 0 or modifier > 20000: return failure("Invalid port modifier.")
	var distance: int = roundi(Geo.angular_separation(a, b) * Nav.RADIUS_M)
	if distance <= 0: return failure("Route has no payable direct distance.")
	var terms: Dictionary = {"direct_distance_m": distance, "rate_minor_per_tonne_nm": rate, "origin_modifier_bp": origin_bp, "destination_modifier_bp": destination_bp}
	var total: int = earnings(grams, terms)
	if total < 0: return failure("Quote exceeds money limit.")
	_offers[id] = {"id": id, "cargo_id": cargo, "quantity": grams, "unit": "gram", "hold_id": hold,
		"origin_port_id": origin, "destination_port_id": destination, "reward_minor": total,
		"terms": terms, "discharged_grams": 0, "paid_minor": 0, "expires_ms": -1,
		"state": "available", "owner_id": "", "ship_id": "", "accepted_ms": -1}
	return {"ok": true, "offer": view(id), "message": quote_text(view(id))}

func batch(offer: Dictionary) -> Dictionary:
	var row: Dictionary = super.batch(offer)
	if offer.has("terms"):
		row.hold_id = offer.hold_id
		row.quantity = offer.quantity - offer.discharged_grams
	return row

# Dock status and owner/ship/port must come from authority, never client assertions.
func load_at(id: String, owner: String, ship_id: String, port_id: String, manifest: RefCounted, docked: bool) -> Dictionary:
	if not docked or _settling: return failure("Dock at the origin before loading.")
	_settling = true
	var result: Dictionary = complete_loading(id, owner, ship_id, port_id, manifest)
	_settling = false
	return result

func accept(id: String, owner: String, ship_id: String, port_id: String, manifest: RefCounted) -> Dictionary:
	if _settling: return failure("Cargo service busy.")
	return super.accept(id, owner, ship_id, port_id, manifest)

func deliver_at(owner: String, ship_id: String, port_id: String, manifest: RefCounted, docked: bool) -> Dictionary:
	var job: Dictionary = active_job(owner)
	if not job.has("terms"): return super.deliver_at(owner, ship_id, port_id, manifest, docked)
	return discharge("full_" + job.id, job.id, owner, ship_id, port_id, manifest, job.quantity - job.discharged_grams, docked)

func discharge(action_id: String, id: String, owner: String, ship_id: String, port_id: String, manifest: RefCounted, grams: Variant, docked: bool) -> Dictionary:
	if _settling: return failure("Cargo service busy.")
	if action_id.is_empty() or action_id.length() > 128 or not grams is int or grams <= 0 or grams > 1000000000: return failure("Invalid discharge request.")
	var intent: Dictionary = {"id": id, "owner": owner, "ship": ship_id, "port": port_id, "grams": grams}
	var key: String = JSON.stringify([owner, action_id])
	if _settlements.has(key):
		if _settlements[key].intent != intent: return failure("Discharge ID conflict.")
		# Return historical receipt, but no new wallet delta on replay.
		return {"ok": true, "duplicate": true, "reward_minor": 0, "receipt": _settlements[key].receipt.duplicate(true)}
	if _settlements.size() >= 4096: return failure("Settlement capacity reached.")
	var job: Dictionary = view(id)
	if not docked or not job.has("terms") or job.state != "loaded" or job.owner_id != owner or job.ship_id != ship_id or job.destination_port_id != port_id: return failure("No matching loaded bulk job at this dock.")
	if grams > job.quantity - job.discharged_grams: return failure("Discharge exceeds remaining cargo.")
	var candidate: Array[Dictionary] = manifest.lines()
	var index: int = -1
	for i: int in candidate.size():
		if candidate[i].batch_id == "batch_" + id: index = i; break
	if index < 0 or candidate[index] != batch(job): return failure("Cargo does not match its recorded job.")
	candidate[index].quantity -= grams
	if candidate[index].quantity == 0: candidate.remove_at(index)
	var error: String = manifest.validate(candidate)
	if not error.is_empty(): return failure(error)
	var cumulative: int = job.discharged_grams + grams
	var earned: int = earnings(cumulative, job.terms)
	var delta: int = earned - job.paid_minor
	var receipt: Dictionary = {"action_id": action_id, "job_id": id, "cargo_id": job.cargo_id,
		"origin_port_id": job.origin_port_id, "destination_port_id": job.destination_port_id,
		"quantity_grams": grams, "cumulative_grams": cumulative, "remaining_grams": job.quantity - cumulative,
		"reward_minor": delta, "cumulative_reward_minor": earned, "quote_minor": job.reward_minor,
		"terms": job.terms.duplicate(true)}
	# Publish ledger/job before manifest's changed signal; reentrant mutations blocked.
	# This is an in-memory authority transaction. Durable adapters belong to Step 70.
	_settling = true
	job.discharged_grams = cumulative
	job.paid_minor = earned
	if cumulative == job.quantity: job.state = "delivered"
	_offers[id] = job
	_settlements[key] = {"intent": intent, "receipt": receipt}
	manifest.replace(candidate)
	_settling = false
	return {"ok": true, "duplicate": false, "reward_minor": delta, "receipt": receipt.duplicate(true), "message": receipt_text(receipt)}

static func failure(message: String) -> Dictionary:
	return {"ok": false, "message": message, "reward_minor": 0}

static func quote_text(job: Dictionary) -> String:
	var t: Dictionary = job.terms
	return "Bulk gross quote: %.2f credits for %.6f t\nDirect distance: %d m; rate: %.2f credits/t/NM\nOrigin: %d bp; destination: %d bp — both included.\nPartial discharge pays cumulative earnings rounded down to 0.01 credit, less prior payments. Fuel, repairs and recovery are separate costs." % [job.reward_minor / 100.0, job.quantity / 1000000.0, t.direct_distance_m, t.rate_minor_per_tonne_nm / 100.0, t.origin_modifier_bp, t.destination_modifier_bp]

static func receipt_text(receipt: Dictionary) -> String:
	return "BULK DELIVERY RECEIPT\nDischarged %.6f t; remaining %.6f t\nPaid %.2f credits; cumulative %.2f / quoted %.2f credits\nDirect distance %d m; rate %.2f credits/t/NM; origin %d bp; destination %d bp" % [receipt.quantity_grams / 1000000.0, receipt.remaining_grams / 1000000.0, receipt.reward_minor / 100.0, receipt.cumulative_reward_minor / 100.0, receipt.quote_minor / 100.0, receipt.terms.direct_distance_m, receipt.terms.rate_minor_per_tonne_nm / 100.0, receipt.terms.origin_modifier_bp, receipt.terms.destination_modifier_bp]
