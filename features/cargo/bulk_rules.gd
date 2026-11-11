extends RefCounted
## Read-only bulk hold rules for one manifest row. No transfer, price or save effects.
## Split out of cargo_manifest.gd (Step 84); check order and messages are unchanged.

## commodities/totals are the caller's per-validation accumulators, keyed by hold ID.
static func manifest_row_error(ship: ShipDefinition, cargo: CargoDefinition, row: Dictionary, commodities: Dictionary, totals: Dictionary) -> String:
	if cargo.quantity_unit != "gram": return "Bulk quantities must use grams."
	if not row.get("hold_id") is String or not ship.bulk_holds.has(row.hold_id): return "Bulk cargo needs a valid hold."
	var hold: Dictionary = ship.bulk_holds[row.hold_id]
	if not hold.cargo_type_ids.has(row.cargo_id): return "Commodity is incompatible with this hold."
	if commodities.has(row.hold_id) and commodities[row.hold_id] != row.cargo_id: return "A bulk hold cannot mix commodities."
	commodities[row.hold_id] = row.cargo_id
	var used_grams: int = totals.get(row.hold_id, 0)
	if row.quantity > hold.capacity_grams - used_grams: return "Cargo exceeds bulk hold capacity."
	totals[row.hold_id] = used_grams + row.quantity
	return ""
