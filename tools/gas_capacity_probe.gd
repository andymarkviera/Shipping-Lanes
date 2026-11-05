extends SceneTree
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const SHIP: ShipDefinition = preload("res://features/catalog/records/gas_ship.tres")
const BERTH: BerthDefinition = preload("res://features/catalog/records/gas_berth.tres")
const PORT: PortDefinition = preload("res://features/catalog/records/gas_port.tres")
const BULK: ShipDefinition = preload("res://features/catalog/records/bulk_ship.tres")
var checks: int = 0
var failures: int = 0
var records: Array[ContentDefinition] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func batch(id: String, gas: String, amount: Variant, tank: String = "tank_forward") -> Dictionary:
	return {"batch_id": id, "cargo_id": "cargo_gas_" + gas, "quantity": amount, "unit": "cubic_meter", "tank_id": tank, "origin_port_id": PORT.id, "destination_port_id": PORT.id, "acquisition_id": "proof", "job_id": ""}
func cargo(gas: String) -> CargoDefinition:
	return load("res://features/catalog/records/gas_" + gas + ".tres")
func rejected_definition(record: ContentDefinition) -> bool:
	var candidate: Array[ContentDefinition] = records.duplicate()
	for i: int in candidate.size():
		if candidate[i].id == record.id: candidate[i] = record
	var registry: DefinitionRegistry = DefinitionRegistry.new()
	if not registry.load_definitions(records).is_empty(): return false
	return not registry.load_definitions(candidate).is_empty() and registry.get_definition(SHIP.id).gas_tanks == SHIP.gas_tanks
func _initialize() -> void: run.call_deferred()
func run() -> void:
	records = PrototypeCatalog.RECORDS.duplicate()
	records.append_array([SHIP, BERTH, PORT])
	check(DefinitionRegistry.new().load_definitions(records).is_empty(), "Gas fixture catalog validates")
	for gas: String in ["lng", "nitrogen", "oxygen", "argon"]:
		var tank: String = "tank_lng" if gas == "lng" else "tank_forward"
		var pipe: String = "pipe_lng" if gas == "lng" else "pipe_industrial"
		var capacity: int = SHIP.gas_tanks[tank].capacity_cubic_meters
		var m: Manifest = Manifest.new(SHIP, records)
		check(m.add(batch("a", gas, capacity, tank)).ok, "Exact tank capacity accepted")
		check(m.tank_usage() == {tank: capacity} and m.usage() == {"gas_tanks": capacity}, "Usage is m3")
		check(not m.add(batch("overflow", gas, 1, tank)).ok and m.lines().size() == 1, "Overfill atomic")
		for direction: String in ["load", "unload"]:
			check(GasRules.transfer_error(SHIP, cargo(gas), tank, BERTH, pipe, direction).is_empty(), "Supported terminal direction")
			check(not GasRules.transfer_error(SHIP, cargo(gas), tank, BERTH, "missing", direction).is_empty(), "Unknown pipeline rejected")
			check(not GasRules.transfer_error(SHIP, cargo(gas), tank, BERTH, "pipe_industrial" if gas == "lng" else "pipe_lng", direction).is_empty(), "Wrong pipeline rejected")
			check(not GasRules.transfer_error(SHIP, cargo(gas), tank, PrototypeCatalog.RECORDS[3], pipe, direction).is_empty(), "Container berth cannot transfer gas")
	for first: String in ["nitrogen", "oxygen", "argon"]:
		for second: String in ["nitrogen", "oxygen", "argon"]:
			var m: Manifest = Manifest.new(SHIP, records)
			check(m.replace([batch("a", first, 600), batch("b", second, 600, "tank_aft"), batch("c", "lng", 400, "tank_lng")]).ok, "All segregated pairs coexist with LNG")
			check(m.usage() == {"gas_tanks": 1600}, "Three tank total")
	var m: Manifest = Manifest.new(SHIP, records)
	check(m.add(batch("a", "nitrogen", 1)).ok and m.add(batch("b", "nitrogen", 2)).ok, "Same gas batches share tank")
	var before: Array[Dictionary] = m.lines()
	check(not m.add(batch("mix", "oxygen", 1)).ok and before == m.lines(), "Mixed commodities fail atomically")
	check(m.remove("a", 1).ok and m.remove("b", 2).ok and m.add(batch("c", "oxygen", 1)).ok, "Emptied tank releases assignment")
	for amount: Variant in [0, -1, 1.5, true, "1", 1000000001]:
		check(not m.add(batch("bad", "oxygen", amount)).ok, "Invalid gas quantity")
	for gas: String in ["methane", "hydrogen", "helium", "oil", "unknown"]:
		check(not m.add(batch("bad", gas, 1)).ok, "Excluded/unknown cargo fails closed")
	check(not m.add(batch("bad", "lng", 1)).ok, "Tank allowlist enforced")
	for field: String in ["tank_id", "unit", "cargo_id"]:
		var bad: Dictionary = batch("bad", "oxygen", 1); bad[field] = "unknown"
		check(not m.add(bad).ok, "Invalid reference rejected")
	var bad: Dictionary = batch("bad", "oxygen", 1); bad.erase("tank_id")
	check(not m.add(bad).ok, "Tank required")
	bad = batch("bad", "oxygen", 1); bad.tank_id = 1
	check(not m.add(bad).ok, "Tank must be string")
	bad = batch("bad", "oxygen", 1); bad.hold_id = "hold_forward"
	check(not m.add(bad).ok, "Gas cannot specify bulk hold")
	for value: Variant in [0, -1, 1.5, true, 1000000001]:
		var ship: ShipDefinition = SHIP.duplicate(true); ship.gas_tanks.tank_forward.capacity_cubic_meters = value
		check(rejected_definition(ship), "Malformed capacity rejects catalog transaction")
	var ship: ShipDefinition = SHIP.duplicate(true); ship.gas_mixing_policy = "mixed"
	check(rejected_definition(ship), "Unsupported mixing policy")
	ship = SHIP.duplicate(true); ship.cargo_capacities.gas_tanks = 1600
	check(rejected_definition(ship), "Aggregate gas shortcut forbidden")
	ship = SHIP.duplicate(true); ship.gas_tanks.tank_forward.pipeline_type = "lng"
	check(rejected_definition(ship), "Tank/commodity interface mismatch")
	ship = SHIP.duplicate(true); ship.gas_tanks.tank_forward.cargo_type_ids = ["cargo_gas_nitrogen", "cargo_gas_nitrogen"]
	check(rejected_definition(ship), "Duplicate gas references")
	var gas_def: CargoDefinition = cargo("lng").duplicate(true); gas_def.quantity_unit = "milliliter"
	check(rejected_definition(gas_def), "Wrong gas units fail catalog")
	gas_def = cargo("lng").duplicate(true); gas_def.capacity_pool = "container_slots"
	check(rejected_definition(gas_def), "Gas cannot masquerade as containers")
	var berth: BerthDefinition = BERTH.duplicate(true); berth.gas_pipelines.pipe_industrial.can_load = false
	check(not GasRules.transfer_error(SHIP, cargo("oxygen"), "tank_forward", berth, "pipe_industrial", "load").is_empty(), "Unload-only terminal rejects loading")
	check(GasRules.transfer_error(SHIP, cargo("oxygen"), "tank_forward", berth, "pipe_industrial", "unload").is_empty(), "Unload-only terminal supports unload")
	berth.gas_pipelines.pipe_industrial.can_unload = false
	check(rejected_definition(berth), "Pipeline requires direction")
	berth = BERTH.duplicate(true); berth.gas_pipelines.pipe_industrial.can_load = 1
	check(rejected_definition(berth), "Direction requires boolean")
	berth = BERTH.duplicate(true); berth.gas_pipelines.pipe_industrial.pipeline_type = "lng"
	check(rejected_definition(berth), "Terminal/commodity interface mismatch")
	check(not GasRules.transfer_error(SHIP, cargo("lng"), "tank_lng", BERTH, "pipe_lng", "trade").is_empty(), "No trade direction")
	# Simultaneously fill all three independent pools, with deliberately colliding hold/tank IDs.
	ship = SHIP.duplicate(true); ship.bulk_holds = BULK.bulk_holds.duplicate(true)
	ship.cargo_type_ids.append_array(BULK.cargo_type_ids); ship.cargo_type_ids.append("cargo_test_container")
	ship.cargo_capacities = {"container_slots": 6}
	ship.gas_tanks["hold_forward"] = ship.gas_tanks.tank_forward; ship.gas_tanks.erase("tank_forward")
	var bulk: Dictionary = batch("bulk", "nitrogen", 400000000); bulk.erase("tank_id"); bulk.hold_id = "hold_forward"; bulk.cargo_id = "cargo_bulk_grain"; bulk.unit = "gram"
	var container: Dictionary = batch("container", "nitrogen", 6); container.erase("tank_id"); container.cargo_id = "cargo_test_container"; container.unit = "count"
	var mixed: Manifest = Manifest.new(ship, records)
	var mixed_result: Dictionary = mixed.replace([bulk, container, batch("gas", "nitrogen", 600, "hold_forward")])
	check(mixed_result.ok, "Full independent capacities accepted: " + mixed_result.message)
	if not mixed_result.ok: quit(1); return
	check(mixed.usage() == {"bulk_holds": 400000000, "container_slots": 6, "gas_tanks": 600}, "Units and budgets remain distinct")
	check(mixed.hold_usage() == {"hold_forward": 400000000} and mixed.tank_usage() == {"hold_forward": 600}, "Colliding allocation names remain independent")
	container.batch_id = "extra"; container.quantity = 1
	check(not mixed.add(container).ok, "Seventh container rejected")
	bulk.batch_id = "extra"; bulk.quantity = 1
	check(not mixed.add(bulk).ok, "Bulk overfill still rejected")
	check(not Manifest.new(PrototypeCatalog.RECORDS[0], records).add(batch("gas", "lng", 1, "tank_lng")).ok, "Existing ship gains no gas capability")
	var copy: Array[Dictionary] = mixed.lines(); copy[2].quantity = 1
	ship.gas_tanks.hold_forward.capacity_cubic_meters = 1
	check(mixed.lines()[2].quantity == 600 and mixed.validate(mixed.lines()).is_empty(), "Manifest and definitions own copies")
	print("GAS_CAPACITY_PASS ", checks, " failures=", failures)
	quit(1 if failures else 0)
