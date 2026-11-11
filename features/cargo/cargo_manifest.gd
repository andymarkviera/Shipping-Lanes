extends RefCounted
## Authority-owned per-ship batches. No money, transfer, loading or save side effects.
signal changed

const BulkRules = preload("res://features/cargo/bulk_rules.gd")
const LIMIT: int = 1000000000
const FIELDS: Array[String] = ["batch_id", "cargo_id", "quantity", "unit", "origin_port_id", "destination_port_id", "acquisition_id", "job_id"]
var _ship: ShipDefinition
var _definitions: Dictionary = {}
var _lines: Array[Dictionary] = []

func _init(ship: ShipDefinition, definitions: Array[ContentDefinition]) -> void:
	_ship = ship.duplicate(true)
	for item: ContentDefinition in definitions:
		if item is CargoDefinition or item is PortDefinition: _definitions[item.id] = item.duplicate(true)

func lines() -> Array[Dictionary]:
	return _lines.duplicate(true)

func usage() -> Dictionary:
	var totals: Dictionary = {}
	for row: Dictionary in _lines:
		var pool: String = _definitions[row.cargo_id].capacity_pool
		totals[pool] = totals.get(pool, 0) + row.quantity
	return totals

func hold_usage() -> Dictionary:
	var totals: Dictionary = {}
	for row: Dictionary in _lines:
		if row.has("hold_id"): totals[row.hold_id] = totals.get(row.hold_id, 0) + row.quantity
	return totals

func tank_usage() -> Dictionary:
	var totals: Dictionary = {}
	for row: Dictionary in _lines:
		if row.has("tank_id"): totals[row.tank_id] = totals.get(row.tank_id, 0) + row.quantity
	return totals

func validate(candidate: Array[Dictionary]) -> String:
	if not _ship.bulk_capacity_error().is_empty() or not GasRules.ship_error(_ship).is_empty(): return "Invalid ship capacity definition."
	if candidate.size() > 256: return "Too many cargo batches."
	var units: Dictionary = {}
	var ids: Dictionary = {}
	var totals: Dictionary = {}
	var hold_commodities: Dictionary = {}
	var hold_totals: Dictionary = {}
	var tank_commodities: Dictionary = {}
	var tank_totals: Dictionary = {}
	for row: Dictionary in candidate:
		if row.size() != FIELDS.size() + (1 if row.has("hold_id") else 0) + (1 if row.has("tank_id") else 0): return "Incomplete cargo batch."
		for field: String in FIELDS:
			if not row.has(field): return "Incomplete cargo batch."
			if field != "quantity" and (not row[field] is String or row[field].length() > 128): return "Invalid cargo reference."
		if row.batch_id.strip_edges().is_empty() or ids.has(row.batch_id): return "Missing or repeated cargo batch ID."
		ids[row.batch_id] = true
		if row.acquisition_id.strip_edges().is_empty() and row.job_id.strip_edges().is_empty(): return "Cargo needs an acquisition or job reference."
		if not row.quantity is int or row.quantity <= 0 or row.quantity > LIMIT: return "Quantity must be a positive bounded integer."
		var cargo: ContentDefinition = _definitions.get(row.cargo_id)
		if not cargo is CargoDefinition or not _ship.cargo_type_ids.has(row.cargo_id): return "Cargo is incompatible with this ship."
		if row.unit != cargo.quantity_unit: return "Cargo quantity uses the wrong unit."
		if not _definitions.get(row.origin_port_id) is PortDefinition or not _definitions.get(row.destination_port_id) is PortDefinition: return "Unknown origin or destination."
		if not GasRules.cargo_error(cargo).is_empty(): return "Invalid gas commodity definition."
		# Compartment families own their row rules; this file keeps shared pools only.
		if cargo.capacity_pool == "gas_tanks":
			var gas_error: String = GasRules.manifest_row_error(_ship, cargo, row, tank_commodities, tank_totals)
			if not gas_error.is_empty(): return gas_error
			continue
		if row.has("tank_id"): return "Only gas cargo can specify a tank."
		if cargo.capacity_pool == "bulk_holds":
			var bulk_error: String = BulkRules.manifest_row_error(_ship, cargo, row, hold_commodities, hold_totals)
			if not bulk_error.is_empty(): return bulk_error
			continue
		if row.has("hold_id"): return "Only bulk cargo can specify a hold."
		var capacity: Variant = _ship.cargo_capacities.get(cargo.capacity_pool)
		if not capacity is int or capacity < 0 or capacity > LIMIT: return "Ship has no valid capacity for this cargo."
		if units.has(cargo.capacity_pool) and units[cargo.capacity_pool] != row.unit: return "Capacity pool mixes incompatible units."
		units[cargo.capacity_pool] = row.unit
		var used: int = totals.get(cargo.capacity_pool, 0)
		if row.quantity > capacity - used: return "Cargo exceeds available capacity."
		totals[cargo.capacity_pool] = used + row.quantity
	return ""

func add(batch: Dictionary) -> Dictionary:
	var candidate: Array[Dictionary] = lines()
	candidate.append(batch.duplicate(true))
	return replace(candidate)

func replace(candidate: Array[Dictionary]) -> Dictionary:
	var error: String = validate(candidate)
	if not error.is_empty(): return {"ok": false, "message": error}
	if _lines == candidate: return {"ok": true, "message": "Cargo manifest unchanged."}
	_lines = candidate.duplicate(true)
	changed.emit()
	return {"ok": true, "message": "Cargo manifest updated."}

func remove(batch_id: String, quantity: int) -> Dictionary:
	var candidate: Array[Dictionary] = lines()
	for i: int in candidate.size():
		if candidate[i].batch_id != batch_id: continue
		if quantity <= 0 or quantity > candidate[i].quantity: return {"ok": false, "message": "Invalid removal quantity."}
		candidate[i].quantity -= quantity
		if candidate[i].quantity == 0: candidate.remove_at(i)
		return replace(candidate)
	return {"ok": false, "message": "Cargo batch not found."}
