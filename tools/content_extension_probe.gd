extends SceneTree
## Step 85 content extension rehearsal. The added commodity, ship and port load,
## validate, pass the save-record contract and work through existing authorities.
## Authority level only: no physics, network or live save.
## Run: godot --headless --path . --script tools/content_extension_probe.gd
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const Bulk = preload("res://features/cargo/bulk_earnings.gd")
const Offers = preload("res://features/cargo/container_offers.gd")
const Contract = preload("res://features/contracts/record_contract.gd")
const Inspection = preload("res://features/catalog/fleet_inspection.gd")
const Geo = preload("res://features/geography/geographic_address.gd")
const BULK_SHIP: ShipDefinition = preload("res://features/catalog/records/bulk_ship.tres")
const SALT: String = "cargo_bulk_salt"
const SHIP: String = "ship_harbor_container_01"
const PORT: String = "port_cinder_point"
const BRINDLE: String = "port_brindle_quay"
var checks: int = 0
var failures: int = 0
var registry: DefinitionRegistry = DefinitionRegistry.new()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var errors: PackedStringArray = registry.load_definitions(PrototypeCatalog.RECORDS)
	check(errors.is_empty(), "catalog with the new records validates: " + ", ".join(errors))
	check(registry.get_definition(SALT) is CargoDefinition and registry.get_definition(SHIP) is ShipDefinition, "new commodity and ship resolve by ID")
	check(registry.get_definition(PORT) is PortDefinition and registry.get_definition("berth_cinder_point_01") is BerthDefinition, "new port and berth resolve by ID")
	saves()
	commodity()
	ship()
	port()
	print("CONTENT_EXTENSION_PASS checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

## Versioned save records accept the new IDs and still reject unknown ones.
func saves() -> void:
	var ship_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://features/contracts/fixtures/ship.json"))
	ship_record.data.definition_id = SHIP
	check(Contract.decode(JSON.stringify(ship_record), registry).ok, "ship save record accepts the new ship")
	ship_record.data.definition_id = "ship_not_in_catalog"
	check(not Contract.decode(JSON.stringify(ship_record), registry).ok, "ship save record rejects an unknown ship")
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://features/contracts/fixtures/job.json"))
	job.data.cargo_id = SALT
	job.data.unit = "gram"
	job.data.origin_port_id = BRINDLE
	job.data.destination_port_id = PORT
	var decoded: Dictionary = Contract.decode(JSON.stringify(job), registry)
	check(decoded.ok, "job save record accepts the new commodity and port: " + str(decoded.errors))
	check(decoded.ok and Contract.decode(JSON.stringify(decoded.record), registry).ok, "new-content job record round trips")

## Salt is quoted, loaded, part-discharged and settled by the unchanged bulk engine.
func commodity() -> void:
	check(PrototypeCatalog.cargo_ids("bulk_holds").has(SALT) and PrototypeCatalog.cargo_ids("gas_tanks").size() == 4, "commodity lists come from cargo records")
	var bulk = Bulk.new()
	bulk._offers.clear()
	var manifest = Manifest.new(BULK_SHIP, PrototypeCatalog.RECORDS)
	var locations: Dictionary = {BRINDLE: Geo.normalized(0, 0), PORT: Geo.normalized(0, 0.5)}
	var modifiers: Dictionary = {BRINDLE: 10000, PORT: 10000}
	check(not bulk.publish("sand", "cargo_bulk_sand", 1, "hold_aft", BRINDLE, PORT, locations, {"cargo_bulk_sand": 90}, modifiers).ok, "a commodity without a record is still refused")
	var quote: Dictionary = bulk.publish("salt_run", SALT, 250000000, "hold_aft", BRINDLE, PORT, locations, {SALT: 90}, modifiers)
	check(quote.ok and quote.offer.reward_minor > 0, "salt quoted to the new port: " + str(quote.get("message", "")))
	if not quote.ok: return
	check(bulk.accept("salt_run", "captain", "ship_a", BRINDLE, manifest).ok, "salt job accepted")
	check(bulk.load_at("salt_run", "captain", "ship_a", BRINDLE, manifest, true).ok and manifest.hold_usage() == {"hold_aft": 250000000}, "salt loaded into its hold")
	var grain: Dictionary = manifest.lines()[0].duplicate(true)
	grain.batch_id = "grain"; grain.cargo_id = "cargo_bulk_grain"; grain.quantity = 1; grain.job_id = ""
	check(not manifest.add(grain).ok, "salt obeys the one-commodity-per-hold rule")
	var first: Dictionary = bulk.discharge("d1", "salt_run", "captain", "ship_a", PORT, manifest, 100000000, true)
	var replay: Dictionary = bulk.discharge("d1", "salt_run", "captain", "ship_a", PORT, manifest, 100000000, true)
	var second: Dictionary = bulk.discharge("d2", "salt_run", "captain", "ship_a", PORT, manifest, 150000000, true)
	check(first.ok and replay.ok and replay.reward_minor == 0 and second.ok, "partial salt discharge settles once per action")
	check(first.ok and second.ok and first.reward_minor + second.reward_minor == quote.offer.reward_minor and manifest.lines().is_empty(), "salt paid exactly its quote and left the ship")

## The new hull is an ordinary online container ship defined by data alone.
func ship() -> void:
	var definition: ShipDefinition = Inspection.definition(SHIP)
	check(definition != null and Inspection.purchasable(SHIP) and not Inspection.purchasable("ship_heavy_lifter_01"), "online hull list follows the ship catalog")
	if definition == null: return
	check(Inspection.family_capacity(definition, "Containers").begins_with("6 "), "inspection reads capacity from the definition")
	var state: ShipState = ShipState.new("owned_harbor", SHIP, definition.fuel_capacity_liters)
	check(state.definition_id == SHIP and state.fuel_liters == definition.fuel_capacity_liters, "ship state holds the new definition")
	var offers = Offers.new()
	var manifest = Manifest.new(definition, PrototypeCatalog.RECORDS)
	var id: String = "container_seed_v1_0_2"
	check(offers.accept(id, "captain", "owned_harbor", BRINDLE, manifest).ok and offers.complete_loading(id, "captain", "owned_harbor", BRINDLE, manifest).ok, "new ship accepts and loads a container job")
	var paid: Dictionary = offers.deliver_at("captain", "owned_harbor", "port_slatewater_works", manifest, true)
	check(paid.ok and paid.reward_minor == offers.view(id).reward_minor and manifest.lines().is_empty(), "new ship delivers and is paid the quote")

## The port scene builds from its records; names and dressing use no literal IDs.
func port() -> void:
	check(PrototypeCatalog.display_name(PORT) == "Cinder Point" and PrototypeCatalog.short_name("port_slatewater_works") == "Slatewater", "port names come from records")
	check(PrototypeCatalog.display_name("port_gone", "Unknown port") == "Unknown port", "unknown port falls back")
	var definition: PortDefinition = registry.get_definition(PORT)
	var dressing: Dictionary = {PORT: true, BRINDLE: true, "port_slatewater_works": false}
	for id: String in dressing:
		var place: Node3D = (load((registry.get_definition(id) as PortDefinition).scene_path) as PackedScene).instantiate()
		root.add_child(place)
		check(place.has_node("FuelStore") == dressing[id] and place.has_node("GantryBeam") != dressing[id], id + " keeps its authored landmark")
		if id == PORT:
			var view: Dictionary = place.service_view()
			check(view.id == PORT and view.name == "Cinder Point" and view.services == definition.service_ids and view.berth_id == "berth_cinder_point_01", "port scene reports its record's services")
			check(place.berth_anchor.position == place.berth.position_m and place.recovery_anchors.size() == definition.recovery_positions_m.size(), "port anchors follow the record")
		place.free()
