extends SceneTree
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const BULK: ShipDefinition = preload("res://features/catalog/records/bulk_ship.tres")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func batch(id: String, cargo: String, amount: Variant, hold: String = "hold_forward") -> Dictionary:
	return {"batch_id": id, "cargo_id": "cargo_bulk_" + cargo, "quantity": amount, "unit": "gram", "hold_id": hold, "origin_port_id": "port_test_harbor", "destination_port_id": "port_test_harbor", "acquisition_id": "proof", "job_id": ""}
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var records: Array[ContentDefinition] = PrototypeCatalog.RECORDS.duplicate()
	records.append(BULK)
	var registry := DefinitionRegistry.new()
	check(registry.load_definitions(records).is_empty(), "bulk catalog validates")
	for first: String in ["grain", "coal", "ore", "limestone"]:
		for second: String in ["grain", "coal", "ore", "limestone"]:
			var m = Manifest.new(BULK, records)
			check(m.replace([batch("a", first, 400000000), batch("b", second, 600000000, "hold_aft")]).ok, "all pairs supported across two full holds")
			check(m.hold_usage() == {"hold_forward": 400000000, "hold_aft": 600000000}, "per-hold accounting")
			check(m.usage().bulk_holds == 1000000000, "total grams, not holds or DWT")
			var before: Array[Dictionary] = m.lines()
			check(not m.add(batch("overflow", first, 1)).ok and m.lines() == before, "one gram over full hold rejects atomically")
	var m = Manifest.new(BULK, records)
	check(m.add(batch("a", "grain", 1)).ok, "single gram accepted")
	check(m.add(batch("b", "grain", 399999999)).ok, "same commodity batches share a hold")
	check(m.remove("a", 1).ok and m.remove("b", 399999999).ok, "empty hold released")
	check(m.add(batch("c", "coal", 1)).ok, "empty hold accepts another commodity without retained assignment")
	check(not m.add(batch("d", "ore", 1)).ok, "different commodity cannot mix even with space")
	for amount: Variant in [0, -1, 1.5, true, "1", 1000000001]:
		check(not m.add(batch("bad", "coal", amount)).ok, "invalid quantity rejected")
	check(not m.add(batch("bad", "coal", 1, "missing")).ok, "unknown hold rejected")
	check(not m.add(batch("bad", "unknown", 1)).ok, "unknown commodity rejected")
	var missing: Dictionary = batch("bad", "coal", 1); missing.erase("hold_id")
	check(not m.add(missing).ok, "bulk requires explicit hold")
	var wrong: Dictionary = batch("bad", "coal", 1); wrong.unit = "count"
	check(not m.add(wrong).ok, "wrong unit rejected")
	wrong = batch("bad", "coal", 1); wrong.extra = true
	check(not m.add(wrong).ok, "extra fields rejected")
	wrong = batch("bad", "coal", 1); wrong.hold_id = 1
	check(not m.add(wrong).ok, "nonstring hold rejected")
	check(not m.add(batch("c", "coal", 1)).ok, "duplicate batch rejected")
	var ship: ShipDefinition = BULK.duplicate(true)
	ship.bulk_holds.hold_forward.cargo_type_ids = ["cargo_bulk_grain"]
	var restricted = Manifest.new(ship, records)
	check(not restricted.add(batch("a", "coal", 1)).ok, "hold-specific compatibility enforced")
	check(restricted.add(batch("a", "coal", 1, "hold_aft")).ok, "other compatible hold remains usable")
	for dwt: int in [0, 1, 999999]:
		ship = BULK.duplicate(true); ship.dwt_tonnes = dwt
		check(Manifest.new(ship, records).replace([batch("a", "grain", 400000000), batch("b", "ore", 600000000, "hold_aft")]).ok, "DWT cannot create or remove capacity")
	ship = BULK.duplicate(true); ship.bulk_holds.erase("hold_aft")
	check(ship.dwt_tonnes == 1500 and not Manifest.new(ship, records).add(batch("a", "ore", 1, "hold_aft")).ok, "hold count independent of DWT")
	ship = BULK.duplicate(true); ship.bulk_holds.hold_forward.capacity_grams = 0
	check(not Manifest.new(ship, records).add(batch("a", "grain", 1)).ok, "malformed hold fails closed")
	var invalid: Array[ContentDefinition] = records.duplicate(); invalid[invalid.size()-1] = ship
	check(not registry.load_definitions(invalid).is_empty(), "registry rejects malformed hold")
	check(registry.get_definition(BULK.id).bulk_holds.hold_forward.capacity_grams == 400000000, "failed catalog leaves prior definition intact")
	ship = BULK.duplicate(true); ship.bulk_mixing_policy = "anything"
	check(not Manifest.new(ship, records).add(batch("a", "grain", 1)).ok, "unknown mixing policy fails closed")
	var container: Dictionary = batch("container", "grain", 6)
	container.erase("hold_id"); container.cargo_id = "cargo_test_container"; container.unit = "count"
	var containers = Manifest.new(PrototypeCatalog.RECORDS[0], records)
	check(containers.add(container).ok, "legacy six containers accepted without hold")
	container.batch_id = "extra"; container.quantity = 1
	check(not containers.add(container).ok, "seventh container rejected")
	check(not containers.add(batch("bulk", "grain", 1)).ok, "container ship cannot carry bulk")
	check(not m.add(container).ok, "bulk ship cannot carry containers")
	containers.remove("container", 6)
	container.hold_id = "hold_forward"
	check(not containers.add(container).ok, "container cannot spoof hold allocation")
	# Exercise independent pool and hold budgets on a synthetic mixed-capability ship.
	ship = BULK.duplicate(true); ship.cargo_type_ids.append("cargo_test_container"); ship.cargo_capacities = {"container_slots": 6}
	var mixed = Manifest.new(ship, records)
	container.erase("hold_id"); container.quantity = 6
	check(mixed.replace([container, batch("a", "grain", 400000000), batch("b", "coal", 600000000, "hold_aft")]).ok, "container pool independent of two bulk holds")
	check(mixed.usage() == {"container_slots": 6, "bulk_holds": 1000000000}, "usage keeps units in separate pools")
	var copy: Array[Dictionary] = mixed.lines(); copy[1].quantity = 1
	check(mixed.lines()[1].quantity == 400000000, "caller cannot mutate manifest")
	ship.bulk_holds.hold_forward.capacity_grams = 1
	check(mixed.validate(mixed.lines()).is_empty(), "manifest owns definition snapshot")
	print("BULK_CAPACITY_PASS ", checks, " failures=", failures)
	quit(1 if failures else 0)
