extends RefCounted
## Read-only projection: no account data, saves, ownership or shared definitions mutated.
static var purchase_catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://services/public_authority/ship_catalog.json"))
const FAMILIES: Array[String] = ["Containers", "Heavy payloads", "Bulk", "Gas", "Oil", "Cargo fuel"]

static func definitions() -> Array[ShipDefinition]:
	var result: Array[ShipDefinition] = []
	for record: ContentDefinition in PrototypeCatalog.RECORDS:
		if record is ShipDefinition: result.append(record)
	return result

static func definition(id: String) -> ShipDefinition:
	for record: ShipDefinition in definitions():
		if record.id == id: return record
	return null

static func family_capacity(ship: ShipDefinition, family: String) -> String:
	if ship == null: return "Unknown definition; capacity unavailable"
	var pool: String = {"Containers": "container_slots", "Heavy payloads": "heavy_slots"}.get(family, "")
	if pool.is_empty(): return "Not supported by current definitions"
	for cargo: ContentDefinition in PrototypeCatalog.RECORDS:
		if cargo is CargoDefinition and cargo.capacity_pool == pool and ship.cargo_type_ids.has(cargo.id):
			var quantity: int = int(ship.cargo_capacities.get(pool, 0))
			if quantity > 0: return "%d %s%s (%s)" % [quantity, cargo.unit_label, "s" if quantity != 1 else "", "container slots" if pool == "container_slots" else "heavy payload slots"]
	return "Incompatible"

static func fleet(owner: Node3D) -> Array:
	var result: Array = []
	var records: Array = [owner.public_profile.ship]
	records.append_array(owner.public_profile.get("stored_ships", []).slice(0, 100))
	for index: int in range(records.size()):
		var record: Dictionary = records[index]
		result.append({"id": str(record.get("id", "")), "definition": str(record.get("definition", "")), "name": str(record.get("name", "Unnamed ship")).left(80), "active": index == 0, "condition_bp": roundi(owner.ship.state.condition * 10000.0) if index == 0 else int(record.get("condition_bp", 10000)), "fuel_liters": owner.ship.state.fuel_liters if index == 0 else float(record.get("fuel_liters", 0.0)), "storage_port_id": str(record.get("storage_port_id", ""))})
	return result

static func acquisition(id: String, data: Dictionary, available: bool) -> String:
	var sale: Dictionary = {}
	for row: Dictionary in purchase_catalog:
		if row.definition == id: sale = row; break
	if sale.is_empty(): return "UNAVAILABLE — prototype; no online purchase"
	if not available: return "UNAVAILABLE NOW — dock / wait for current server state"
	if int(data.get("stored_ship_count", 0)) >= 100: return "STORAGE FULL — 100 stored ships"
	var quoted: bool = false
	for row: Dictionary in data.get("ship_catalog", []):
		if row.definition == id: quoted = true; sale = row; break
	if not quoted: return "UNAVAILABLE NOW — loading or ship service unavailable"
	var price: String = "%.2f credits" % (int(sale.cost_minor) / 100.0)
	if int(data.get("wallet", 0)) < int(sale.cost_minor): return "INSUFFICIENT CREDITS — " + price
	return "PURCHASABLE — " + price + " (review in Ship Catalog)"

static func details(entry: Dictionary, family: String, data: Dictionary, available: bool) -> String:
	var ship: ShipDefinition = definition(str(entry.get("definition", "")))
	var owned: bool = entry.has("id")
	var lines: Array[String] = []
	if owned:
		lines.append("Name: " + str(entry.get("name", "Unnamed ship")))
		lines.append("Ownership: Yours · " + ("Active" if entry.get("active", false) else "Stored; activation unavailable"))
		lines.append("Owned ID: " + str(entry.id))
		lines.append("Condition: %.2f%% · Propulsion fuel: %.1f L" % [int(entry.get("condition_bp", 10000)) / 100.0, float(entry.get("fuel_liters", 0.0))])
		if not entry.get("active", false):
			lines.append("Storage: " + {"port_brindle_quay": "Brindle Quay", "port_slatewater_works": "Slatewater Works"}.get(str(entry.get("storage_port_id", "")), "Unknown port"))
	else:
		lines.append("Ownership: Catalog design; not an owned instance")
		lines.append(acquisition(str(entry.definition), data, available))
		lines.append("Purchase condition: 100% · Propulsion fuel: empty" if "prototype" not in acquisition(str(entry.definition), data, available) else "Purchase condition / fuel: not applicable")
	if ship == null:
		lines.append("Definition unavailable; saved identity retained. No capacity inferred.")
		return "\n".join(lines)
	lines.append("Class: " + ship.display_name)
	lines.append(family + ": " + family_capacity(ship, family))
	lines.append("Total capacity, not remaining space. Active cargo stays with the active ship.")
	lines.append("DWT: not specified · Hold count: not specified")
	lines.append("DWT is a mass rating; holds are compartments. Neither is cargo capacity.")
	lines.append("Propulsion tank: %.0f L (not cargo fuel)" % ship.fuel_capacity_liters)
	lines.append("Forward acceleration: %.2f m/s² · Turn limit: %.1f °/s" % [ship.forward_acceleration_mps2, ship.max_turn_rate_degrees])
	lines.append("Full-output propulsion burn: %.2f L/s" % ship.fuel_full_output_lps)
	lines.append("Preview: shared placeholder hull; capacity comes from definitions.")
	if family == "Heavy payloads" and ship.id == "ship_heavy_lifter_01": lines.append("Local prototype capability only; online heavy jobs unavailable.")
	return "\n".join(lines)
