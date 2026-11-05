extends "res://features/cargo/container_offers.gd"
## Trusted local/server authority model. Never expose offer authoring or prices as RPCs.
## Bulk and gas share the container registry/one-job guard and cumulative settlement.
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")
const DENOMINATOR: int = 185200000000000000 # grams/tonne * metres/NM * basis points squared
const MAX_MONEY: int = 9000000000000
# One settlement engine; gas changes units/allocations, never the transaction rules.
var family: String = "bulk"
var allocation_key: String = "hold_id"
var cumulative_key: String = "discharged_grams"
var rate_key: String = "rate_minor_per_tonne_nm"
var unit: String = "gram"
var commodities: Array[String] = ["cargo_bulk_grain", "cargo_bulk_coal", "cargo_bulk_ore", "cargo_bulk_limestone"]

func _init(cargo_family: String = "bulk") -> void:
	super()
	family = cargo_family
	if family == "gas":
		allocation_key = "tank_id"
		cumulative_key = "discharged_cubic_meters"
		rate_key = "rate_minor_per_cubic_meter_nm"
		unit = "cubic_meter"
		commodities = ["cargo_gas_lng", "cargo_gas_nitrogen", "cargo_gas_oxygen", "cargo_gas_argon"]

func calculate(quantity: int, terms: Dictionary) -> int:
	var normalized: Dictionary = terms.duplicate()
	normalized.rate_minor_per_tonne_nm = terms[rate_key]
	return earnings(quantity, normalized, 185200000000 if family == "gas" else DENOMINATOR)

var _settlements: Dictionary = {}
var _settling: bool = false

# Exact floor of a product/divisor without overflowing int64 intermediate products.
# Quotient is bounded to the money contract; remainder is always below DENOMINATOR.
static func earnings(grams: int, terms: Dictionary, divisor: int = DENOMINATOR) -> int:
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
				if extra_r >= divisor:
					extra_r -= divisor
					extra_q += 1
			bits >>= 1
			if bits > 0:
				part_q *= 2
				part_r *= 2
				if part_r >= divisor:
					part_r -= divisor
					part_q += 1
		if extra_q > MAX_MONEY or (multiplier > 0 and q > (MAX_MONEY - extra_q) / multiplier): return -1
		q = q * multiplier + extra_q
		r = extra_r
	return q

# Authored endpoints, not current ship position, odometer, waypoints or sailed route.
# Quotes are nonexpiring and immutable once published, including before acceptance.
func publish(id: String, cargo: String, grams: Variant, hold: String, origin: String, destination: String, locations: Dictionary, rates: Dictionary, modifiers: Dictionary) -> Dictionary:
	if id.is_empty() or id.length() > 64 or _offers.has(id) or _offers.size() >= 4096: return failure("Invalid or reused offer ID.")
	if not grams is int or grams <= 0 or grams > 1000000000: return failure("Invalid cargo quantity.")
	if cargo not in commodities: return failure("Unknown cargo commodity.")
	if hold.is_empty() or hold.length() > 128 or origin == destination: return failure("Invalid allocation or same-port route.")
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
	var terms: Dictionary = {"direct_distance_m": distance, rate_key: rate, "origin_modifier_bp": origin_bp, "destination_modifier_bp": destination_bp}
	var total: int = calculate(grams, terms)
	if total < 0: return failure("Quote exceeds money limit.")
	_offers[id] = {"id": id, "cargo_id": cargo, "quantity": grams, "unit": unit, allocation_key: hold,
		"origin_port_id": origin, "destination_port_id": destination, "reward_minor": total,
		"terms": terms, cumulative_key: 0, "paid_minor": 0, "expires_ms": -1,
		"state": "available", "owner_id": "", "ship_id": "", "accepted_ms": -1}
	return {"ok": true, "offer": view(id), "message": format_quote(view(id))}

func batch(offer: Dictionary) -> Dictionary:
	var row: Dictionary = super.batch(offer)
	if offer.has("terms"):
		row[allocation_key] = offer[allocation_key]
		row.quantity = offer.quantity - offer[cumulative_key]
		if family == "gas": row.acquisition_id = "gas_quote_" + offer.id
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
	return discharge("full_" + job.id, job.id, owner, ship_id, port_id, manifest, job.quantity - job[cumulative_key], docked)

func discharge(action_id: String, id: String, owner: String, ship_id: String, port_id: String, manifest: RefCounted, grams: Variant, docked: bool) -> Dictionary:
	if _settling: return failure("Cargo service busy.")
	if action_id.is_empty() or action_id.length() > 128 or not grams is int or grams <= 0 or grams > 1000000000: return failure("Invalid discharge request.")
	var intent: Dictionary = {"id": id, "owner": owner, "ship": ship_id, "port": port_id, ("cubic_meters" if family == "gas" else "grams"): grams}
	var key: String = JSON.stringify([owner, action_id])
	if _settlements.has(key):
		if _settlements[key].intent != intent: return failure("Discharge ID conflict.")
		# Return historical receipt, but no new wallet delta on replay.
		return {"ok": true, "duplicate": true, "reward_minor": 0, "receipt": _settlements[key].receipt.duplicate(true)}
	if _settlements.size() >= 4096: return failure("Settlement capacity reached.")
	var job: Dictionary = view(id)
	if not docked or not job.has("terms") or job.state != "loaded" or job.owner_id != owner or job.ship_id != ship_id or job.destination_port_id != port_id: return failure("No matching loaded cargo job at this dock.")
	if grams > job.quantity - job[cumulative_key]: return failure("Discharge exceeds remaining cargo.")
	var candidate: Array[Dictionary] = manifest.lines()
	var index: int = -1
	for i: int in candidate.size():
		if candidate[i].batch_id == "batch_" + id: index = i; break
	if index < 0 or candidate[index] != batch(job): return failure("Cargo does not match its recorded job.")
	candidate[index].quantity -= grams
	if candidate[index].quantity == 0: candidate.remove_at(index)
	var error: String = manifest.validate(candidate)
	if not error.is_empty(): return failure(error)
	var cumulative: int = job[cumulative_key] + grams
	var earned: int = calculate(cumulative, job.terms)
	var delta: int = earned - job.paid_minor
	var receipt: Dictionary = {"action_id": action_id, "job_id": id, "cargo_id": job.cargo_id,
		"origin_port_id": job.origin_port_id, "destination_port_id": job.destination_port_id,
		("quantity_cubic_meters" if family == "gas" else "quantity_grams"): grams, ("cumulative_cubic_meters" if family == "gas" else "cumulative_grams"): cumulative, ("remaining_cubic_meters" if family == "gas" else "remaining_grams"): job.quantity - cumulative,
		"reward_minor": delta, "cumulative_reward_minor": earned, "quote_minor": job.reward_minor,
		"terms": job.terms.duplicate(true)}
	if family == "gas":
		receipt.tank_id = job.tank_id
		receipt.acquisition_id = "gas_quote_" + id
	# Publish ledger/job before manifest's changed signal; reentrant mutations blocked.
	# This is an in-memory authority transaction. Durable adapters belong to Step 70.
	_settling = true
	job[cumulative_key] = cumulative
	job.paid_minor = earned
	if cumulative == job.quantity: job.state = "delivered"
	_offers[id] = job
	_settlements[key] = {"intent": intent, "receipt": receipt}
	manifest.replace(candidate)
	_settling = false
	return {"ok": true, "duplicate": false, "reward_minor": delta, "receipt": receipt.duplicate(true), "message": format_receipt(receipt)}

static func failure(message: String) -> Dictionary:
	return {"ok": false, "message": message, "reward_minor": 0}

static func quote_text(job: Dictionary) -> String:
	var t: Dictionary = job.terms
	return "Bulk gross quote: %.2f credits for %.6f t\nDirect distance: %d m; rate: %.2f credits/t/NM\nOrigin: %d bp; destination: %d bp — both included.\nPartial discharge pays cumulative earnings rounded down to 0.01 credit, less prior payments. Fuel, repairs and recovery are separate costs." % [job.reward_minor / 100.0, job.quantity / 1000000.0, t.direct_distance_m, t.rate_minor_per_tonne_nm / 100.0, t.origin_modifier_bp, t.destination_modifier_bp]

static func receipt_text(receipt: Dictionary) -> String:
	return "BULK DELIVERY RECEIPT\nDischarged %.6f t; remaining %.6f t\nPaid %.2f credits; cumulative %.2f / quoted %.2f credits\nDirect distance %d m; rate %.2f credits/t/NM; origin %d bp; destination %d bp" % [receipt.quantity_grams / 1000000.0, receipt.remaining_grams / 1000000.0, receipt.reward_minor / 100.0, receipt.cumulative_reward_minor / 100.0, receipt.quote_minor / 100.0, receipt.terms.direct_distance_m, receipt.terms.rate_minor_per_tonne_nm / 100.0, receipt.terms.origin_modifier_bp, receipt.terms.destination_modifier_bp]

func format_quote(job: Dictionary) -> String:
	if family != "gas": return quote_text(job)
	var t: Dictionary = job.terms
	return "Gas gross quote: %.2f credits for %d m³\nDirect distance: %d m; rate: %.2f credits/m³/NM\nOrigin: %d bp; destination: %d bp — both included.\nWhole-m³ partials pay cumulative earnings rounded down to 0.01 credit, less prior payments. Fuel, repairs and recovery are separate costs." % [job.reward_minor / 100.0, job.quantity, t.direct_distance_m, t[rate_key] / 100.0, t.origin_modifier_bp, t.destination_modifier_bp]

func format_receipt(receipt: Dictionary) -> String:
	if family != "gas": return receipt_text(receipt)
	return "GAS DELIVERY RECEIPT\nDischarged %d m³; remaining %d m³\nPaid %.2f credits; cumulative %.2f / quoted %.2f credits\nOrigin %s → %s\nDirect distance %d m; rate %.2f credits/m³/NM; origin %d bp; destination %d bp" % [receipt.quantity_cubic_meters, receipt.remaining_cubic_meters, receipt.reward_minor / 100.0, receipt.cumulative_reward_minor / 100.0, receipt.quote_minor / 100.0, receipt.origin_port_id, receipt.destination_port_id, receipt.terms.direct_distance_m, receipt.terms[rate_key] / 100.0, receipt.terms.origin_modifier_bp, receipt.terms.destination_modifier_bp]
