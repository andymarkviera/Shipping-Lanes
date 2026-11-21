extends SceneTree
var failures: PackedStringArray = []
func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var registry: DefinitionRegistry = DefinitionRegistry.new()
	expect(registry.load_definitions(PrototypeCatalog.RECORDS).is_empty(), "Valid prototype catalog")
	var initial: Dictionary = {"cargo_test_container": {"count": 2}}
	var first: ShipState = ShipState.new("test_ship_a", "ship_starter_container_01", 40.0, initial)
	var second: ShipState = ShipState.new("test_ship_b", first.definition_id, 75.0, initial)
	first.fuel_liters = 12.0
	first.cargo.cargo_test_container.count = 5
	expect(second.fuel_liters == 75.0 and second.cargo.cargo_test_container.count == 2, "Ship state is independent")
	expect(initial.cargo_test_container.count == 2, "Caller cargo is not aliased")
	var original: ShipDefinition = PrototypeCatalog.RECORDS[0] as ShipDefinition
	var copy: ShipDefinition = registry.get_definition(first.definition_id) as ShipDefinition
	copy.display_name = "Changed by caller"
	copy.cargo_type_ids.append("cargo_bad")
	expect(registry.get_definition(second.definition_id).display_name == original.display_name, "Lookup copy protects registry")
	expect(original.cargo_type_ids.size() == 1 and original.get("fuel_liters") == null and original.get("cargo") == null, "Source has no mutable ship state")
	var candidates: Array[ContentDefinition] = PrototypeCatalog.RECORDS.duplicate()
	candidates.append(original)
	expect(not registry.load_definitions(candidates).is_empty(), "Duplicate ID rejected")
	var bad_ship: ShipDefinition = original.duplicate(true)
	bad_ship.cargo_type_ids = ["missing_cargo"]
	candidates = PrototypeCatalog.RECORDS.duplicate()
	candidates[0] = bad_ship
	expect(not registry.load_definitions(candidates).is_empty(), "Missing cargo rejected")
	bad_ship.cargo_type_ids = ["port_test_harbor"]
	expect(not registry.load_definitions(candidates).is_empty(), "Wrong-type reference rejected")
	bad_ship.cargo_type_ids = []
	expect(not registry.load_definitions(candidates).is_empty(), "Empty required references rejected")
	bad_ship.cargo_type_ids = original.cargo_type_ids
	bad_ship.scene_path = "res://missing.tscn"
	expect(not registry.load_definitions(candidates).is_empty(), "Missing scene rejected")
	var bad_berth: BerthDefinition = PrototypeCatalog.RECORDS[3].duplicate(true)
	bad_berth.port_id = "missing_port"
	candidates = PrototypeCatalog.RECORDS.duplicate()
	candidates[3] = bad_berth
	expect(not registry.load_definitions(candidates).is_empty(), "Missing berth port rejected")
	var wrong_port: PortDefinition = PrototypeCatalog.RECORDS[2].duplicate(true)
	wrong_port.id = "port_other"
	candidates.append(wrong_port)
	bad_berth.port_id = wrong_port.id
	expect(not registry.load_definitions(candidates).is_empty(), "Mismatched port/berth pair rejected")
	expect(not registry.load_definitions([]).is_empty(), "Empty catalog rejected")
	expect(not registry.load_definitions([null]).is_empty(), "Null record rejected")
	bad_ship.id = "Not a stable ID"
	expect(not registry.load_definitions([bad_ship]).is_empty(), "Invalid ID rejected")
	expect(registry.get_definition(first.definition_id) != null, "Failed replacement preserves valid catalog")
	expect(registry.get_definition("unknown") == null, "Unknown lookup is explicit")
	var scene: PackedScene = load(original.scene_path)
	var hull: Node = scene.instantiate()
	expect(hull.get_meta("ship_definition_id") == original.id, "Existing asset ID preserved")
	hull.free()
	# Patch 4.0: the scene-free checks (boat lineup and refund, levels, airports,
	# plane jobs, flight model, old saves) run in the Checks job from here.
	# tools/patch_4_0_check.gd runs them too, plus the game-scene checks.
	for failure: String in load("res://tools/patch_4_0_logic.gd").run_all():
		failures.append("Patch 4.0: " + failure)
	# Patch 4.0.1: auto-level, sloppy landings, the crash view, the Fighter jet,
	# turbofans, the level-1 gate, flat airfields, old saves, VERSION
	# (tools/patch_4_0_1_check.gd runs them too, plus the game-scene checks).
	for failure: String in load("res://tools/patch_4_0_1_logic.gd").run_all():
		failures.append("Patch 4.0.1: " + failure)
	# Patch 4.0.2: polar relief, plane icons, runways above the grass, no
	# decoration on airfields, the bank limit and barrel rolls, the manual
	# gear (auto-retract, belly landings, the folding legs), the boats' stats,
	# old saves, VERSION (tools/patch_4_0_2_check.gd adds the game scene).
	for failure: String in load("res://tools/patch_4_0_2_logic.gd").run_all():
		failures.append("Patch 4.0.2: " + failure)
	# Patch 4.0.3: the keyboard flight (altitude hold, bank limit, brakes),
	# every class's berth, the plane trips, the throttle widget, Point Nemo,
	# the polar runways, VERSION (tools/patch_4_0_3_check.gd adds the scene).
	for failure: String in load("res://tools/patch_4_0_3_logic.gd").run_all():
		failures.append("Patch 4.0.3: " + failure)
	# Patch 4.0.4: the HDG compass, the blaster's use count (replicated), the
	# cached plane parts, VERSION (tools/patch_4_0_4_check.gd adds the scene).
	for failure: String in load("res://tools/patch_4_0_4_logic.gd").run_all():
		failures.append("Patch 4.0.4: " + failure)
	# Patch 4.0.5: the controller layout and glyphs, error and crash reports
	# (scrubbing, caps, the server's rate limits and rotating log), the plane
	# engine sounds and doppler, VERSION (tools/patch_4_0_5_check.gd adds the
	# game scene; check_dedicated_split.py --errors a real server).
	for failure: String in load("res://tools/patch_4_0_5_logic.gd").run_all():
		failures.append("Patch 4.0.5: " + failure)
	for failure: String in failures:
		push_error(failure)
	print("CATALOG_CHECK_PASS" if failures.is_empty() else "CATALOG_CHECK_FAILED")
	quit(0 if failures.is_empty() else 1)
