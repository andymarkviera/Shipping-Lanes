extends SceneTree
const Inspection = preload("res://features/catalog/fleet_inspection.gd")
const InspectionPanel = preload("res://features/catalog/fleet_inspection_panel.gd")
var checks: int = 0
var failures: int = 0
class OwnerDouble extends Node3D:
	var public_profile: Dictionary = {}
	var ship: Dictionary = {"state": {"condition": 0.42, "fuel_liters": 17.5}}
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var starter: ShipDefinition = Inspection.definition("ship_starter_container_01")
	var heavy: ShipDefinition = Inspection.definition("ship_heavy_lifter_01")
	check(Inspection.family_capacity(starter, "Containers") == "6 containers (container slots)", "container units are explicit")
	check(Inspection.family_capacity(heavy, "Heavy payloads") == "1 module (heavy payload slots)", "heavy capacity has payload units")
	check(Inspection.family_capacity(heavy, "Containers") == "Incompatible" and Inspection.family_capacity(starter, "Heavy payloads") == "Incompatible", "incompatible families do not inherit slots")
	for family: String in ["Bulk", "Gas", "Oil", "Cargo fuel"]:
		check("Not supported" in Inspection.family_capacity(starter, family), family + " is not inferred from propulsion tank or hull")
	var owner := OwnerDouble.new()
	root.add_child(owner)
	owner.public_profile = {"account": "private-account", "ship": {"id": "active", "definition": starter.id, "condition_bp": 9000, "fuel_liters": 900.0}, "jobs": [{"private": true}]}
	check(Inspection.fleet(owner).size() == 1, "legacy profile without stored_ships remains inspectable")
	owner.public_profile.stored_ships = [{"id": "stored-a", "definition": starter.id, "name": "Harbor Star", "condition_bp": 7300, "fuel_liters": 0.0, "storage_port_id": "port_brindle_quay"}, {"id": "stored-b", "definition": starter.id, "condition_bp": 10000, "fuel_liters": 0.0}]
	var before: String = JSON.stringify(owner.public_profile)
	var rows: Array = Inspection.fleet(owner)
	check(rows.size() == 3 and rows[1].id != rows[2].id, "duplicate definitions retain separate owned identities")
	check(rows[0].condition_bp == 4200 and rows[0].fuel_liters == 17.5, "active inspection reads live single meter and fuel")
	check(rows[1].condition_bp == 7300 and rows[1].name == "Harbor Star", "stored inspection reads canonical instance state and name")
	check(not "private-account" in JSON.stringify(rows) and not "private" in JSON.stringify(rows), "projection excludes account and job data")
	var data: Dictionary = {"fleet": rows, "wallet": 200000, "stored_ship_count": 2, "ship_catalog": [{"definition": starter.id, "cost_minor": 55000}]}
	check(Inspection.acquisition(starter.id, data, true).begins_with("PURCHASABLE"), "ordinary purchase is explicit")
	check("550.00 credits" in Inspection.acquisition(starter.id, data, true), "comparison price comes from current server quote")
	check(Inspection.acquisition(heavy.id, data, true).begins_with("UNAVAILABLE — prototype"), "prototype is distinct from a normal purchase")
	check(Inspection.acquisition(starter.id, data, false).begins_with("UNAVAILABLE NOW"), "stale or undocked acquisition is unavailable")
	data.wallet = 0
	check(Inspection.acquisition(starter.id, data, true).begins_with("INSUFFICIENT"), "unaffordable is distinct from unavailable")
	data.wallet = 200000; data.stored_ship_count = 100
	check(Inspection.acquisition(starter.id, data, true).begins_with("STORAGE FULL"), "full fleet is distinct")
	data.stored_ship_count = 2; data.ship_catalog = []
	check(Inspection.acquisition(starter.id, data, true).begins_with("UNAVAILABLE NOW"), "missing service quote never appears purchasable")
	var details: String = Inspection.details(rows[1], "Containers", data, true)
	check("Harbor Star" in details and "73.00%" in details and "Brindle Quay" in details and "Yours" in details, "owned identity condition storage and ownership readable")
	check("DWT: not specified · Hold count: not specified" in details and "6 containers" in details, "unknown DWT and holds separated from actual capacity")
	check("not cargo fuel" in details and "Total capacity, not remaining space" in details, "propulsion fuel and free cargo space not confused")
	check("Definition unavailable" in Inspection.details({"id": "saved", "definition": "removed"}, "Containers", data, true), "missing definition retains saved identity without invented stats")
	var panel := InspectionPanel.new()
	root.add_child(panel)
	panel.refresh(data, true)
	panel.open(starter.id)
	check(panel.visible and panel.selectors[1].get_item_metadata(panel.selectors[1].selected) == "active", "comparison opens against active owned ship")
	check(panel.models[0] != null and panel.models[0].process_mode == Node.PROCESS_MODE_DISABLED and panel.previews[0].own_world_3d, "preview is isolated visual scene with no runtime processing")
	panel.selectors[1].select(5)
	panel.refresh_details()
	check("Harbor Star" in panel.descriptions[1].text, "stored ship can be selected alongside catalog")
	rows[1].condition_bp = 6500
	panel.refresh(data, true)
	check("65.00%" in panel.descriptions[1].text and panel.selectors[1].get_item_metadata(panel.selectors[1].selected) == "stored-a", "condition refresh preserves owned selection")
	panel.family.select(1); panel.refresh_details()
	check("Incompatible" in panel.descriptions[0].text, "family selector updates both comparison columns")
	panel.open(heavy.id)
	check("Local prototype capability only" in panel.descriptions[0].text and panel.models[0] != null, "unavailable heavy prototype has preview and online limitation")
	panel.refresh({}, false)
	check(panel.choices.size() == 4 and not "Harbor Star" in panel.descriptions[1].text, "empty snapshot clears prior owner entries")
	check(before == JSON.stringify(owner.public_profile) and starter.cargo_capacities.container_slots == 6, "inspection never mutates saved state or definitions")
	for i: int in range(110): owner.public_profile.stored_ships.append({"id": str(i), "definition": starter.id})
	var bounded: Array = Inspection.fleet(owner)
	check(bounded.size() == 101, "fleet projection bounded to active plus 100 stored ships")
	print("FLEET_MAX_JSON_BYTES ", JSON.stringify(bounded).to_utf8_buffer().size())
	panel.free(); owner.free()
	print("FLEET_INSPECTION_PASS ", checks, " failures=", failures)
	quit(1 if failures else 0)
