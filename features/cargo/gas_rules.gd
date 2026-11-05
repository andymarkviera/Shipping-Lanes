class_name GasRules
extends RefCounted
## Read-only definition/compatibility rules. No transfer, clock, price or save effects.
const LIMIT: int = 1000000000
const PIPELINE_TYPES: Array[String] = ["lng", "industrial_cryogenic"]

static func cargo_error(cargo: CargoDefinition) -> String:
	if cargo.capacity_pool != "gas_tanks":
		return "Gas fields require gas tank capacity" if cargo.quantity_unit == "cubic_meter" or not cargo.gas_pipeline_type.is_empty() else ""
	if cargo.quantity_unit != "cubic_meter": return "Gas quantities must use cubic meters"
	if not PIPELINE_TYPES.has(cargo.gas_pipeline_type): return "Unsupported gas pipeline type"
	return ""

static func ids_error(ids: Variant, allowed: Array[String]) -> String:
	if not ids is Array or ids.is_empty() or ids.size() > 256: return "Missing or excessive gas compatibility"
	var seen: Array[String] = []
	for id: Variant in ids:
		if not id is String or not allowed.has(id) or seen.has(id): return "Invalid gas compatibility"
		seen.append(id)
	return ""

static func key_valid(key: Variant) -> bool:
	return key is String and not key.strip_edges().is_empty() and key.length() <= 128

static func ship_error(ship: ShipDefinition) -> String:
	if ship.gas_mixing_policy != "single_commodity_per_tank": return "Unsupported gas mixing policy"
	if ship.cargo_capacities.has("gas_tanks"): return "Gas capacity must be authored per tank"
	if ship.gas_tanks.size() > 256: return "Too many gas tanks"
	for id: Variant in ship.gas_tanks:
		if not key_valid(id): return "Invalid gas tank ID"
		var tank: Variant = ship.gas_tanks[id]
		if not tank is Dictionary or tank.size() != 3 or not tank.has_all(["capacity_cubic_meters", "cargo_type_ids", "pipeline_type"]): return "Invalid gas tank"
		if not tank.capacity_cubic_meters is int or tank.capacity_cubic_meters <= 0 or tank.capacity_cubic_meters > LIMIT: return "Invalid gas tank capacity"
		if not tank.pipeline_type is String or not PIPELINE_TYPES.has(tank.pipeline_type): return "Invalid tank pipeline type"
		var error: String = ids_error(tank.cargo_type_ids, ship.cargo_type_ids)
		if not error.is_empty(): return error
	return ""

static func berth_error(berth: BerthDefinition) -> String:
	if berth.gas_pipelines.size() > 256: return "Too many gas pipelines"
	for id: Variant in berth.gas_pipelines:
		if not key_valid(id): return "Invalid gas pipeline ID"
		var pipe: Variant = berth.gas_pipelines[id]
		if not pipe is Dictionary or pipe.size() != 4 or not pipe.has_all(["cargo_type_ids", "pipeline_type", "can_load", "can_unload"]): return "Invalid gas pipeline"
		if not pipe.can_load is bool or not pipe.can_unload is bool or not (pipe.can_load or pipe.can_unload): return "Invalid gas pipeline directions"
		if not pipe.pipeline_type is String or not PIPELINE_TYPES.has(pipe.pipeline_type): return "Invalid terminal pipeline type"
		var error: String = ids_error(pipe.cargo_type_ids, berth.cargo_type_ids)
		if not error.is_empty(): return error
	return ""

static func tank_error(ship: ShipDefinition, cargo: CargoDefinition, tank_id: String) -> String:
	if ship == null or cargo == null: return "Missing gas definition"
	if not ship_error(ship).is_empty() or not cargo_error(cargo).is_empty(): return "Invalid gas definition"
	if cargo.capacity_pool != "gas_tanks" or not ship.cargo_type_ids.has(cargo.id) or not ship.gas_tanks.has(tank_id): return "Unsupported gas tank or commodity"
	var tank: Dictionary = ship.gas_tanks[tank_id]
	if not tank.cargo_type_ids.has(cargo.id) or tank.pipeline_type != cargo.gas_pipeline_type: return "Gas is incompatible with tank"
	return ""

static func transfer_error(ship: ShipDefinition, cargo: CargoDefinition, tank_id: String, berth: BerthDefinition, pipeline_id: String, direction: String) -> String:
	var error: String = tank_error(ship, cargo, tank_id)
	if not error.is_empty(): return error
	if berth == null or not berth.eligibility_error().is_empty(): return "Invalid gas terminal"
	if direction not in ["load", "unload"]: return "Unsupported gas transfer direction"
	if not berth.cargo_type_ids.has(cargo.id) or not berth.gas_pipelines.has(pipeline_id): return "Terminal has no compatible gas pipeline"
	var pipe: Dictionary = berth.gas_pipelines[pipeline_id]
	if not pipe.cargo_type_ids.has(cargo.id) or pipe.pipeline_type != cargo.gas_pipeline_type: return "Gas is incompatible with terminal pipeline"
	if not pipe["can_" + direction]: return "Pipeline does not support requested direction"
	return ""

static func validate_references(record: ContentDefinition, definitions: Dictionary, errors: PackedStringArray) -> void:
	var compartments: Dictionary = {}
	if record is CargoDefinition:
		var error: String = cargo_error(record)
		if not error.is_empty(): errors.append(record.id + ": " + error)
	elif record is ShipDefinition:
		if not ship_error(record).is_empty(): return # Structural errors reported by handling_error.
		compartments = record.gas_tanks
	elif record is BerthDefinition:
		if not berth_error(record).is_empty(): return
		compartments = record.gas_pipelines
	for compartment: Dictionary in compartments.values():
		for cargo_id: String in compartment.cargo_type_ids:
			var cargo: ContentDefinition = definitions.get(cargo_id)
			if not cargo is CargoDefinition or cargo.capacity_pool != "gas_tanks" or not cargo_error(cargo).is_empty() or cargo.gas_pipeline_type != compartment.pipeline_type:
				errors.append(record.id + ": Invalid gas commodity/pipeline: " + cargo_id)
