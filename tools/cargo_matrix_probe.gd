extends SceneTree
## Step 84 cargo compatibility matrix for the GDScript cargo authorities.
## Manifest/authority level only: no scene, physics, network or live save. The oil
## voyage writes one new uniquely named file under user://cargo_matrix; run with
## isolated user-data directories. Oil market, cargo fuel and heavy job voyages
## are service-side: services/test_cargo_matrix.py.
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const Offers = preload("res://features/cargo/container_offers.gd")
const Service = preload("res://features/cargo/bulk_service.gd")
const Inventory = preload("res://features/cargo/liquid_inventory.gd")
const GAS_BERTH: BerthDefinition = preload("res://features/catalog/records/gas_berth.tres")
const QUAY_BERTH: BerthDefinition = preload("res://features/ports/brindle_quay_berth.tres")
const ORIGIN: String = "port_brindle_quay"
const DESTINATION: String = "port_slatewater_works"
# One representative hull and cargo per manifest family. full = whole capacity of
# the named pool/compartment; part = a partial quantity removed and put back.
var families: Array[Dictionary] = [
	{"name": "containers", "ship": "res://features/catalog/records/starter_ship.tres", "cargo": "cargo_test_container", "allocation": "", "full": 24, "part": 2},
	{"name": "heavy", "ship": "res://features/catalog/records/heavy_lifter.tres", "cargo": "cargo_test_industrial", "allocation": "", "full": 1, "part": 1},
	{"name": "bulk", "ship": "res://features/catalog/records/bulk_ship.tres", "cargo": "cargo_bulk_grain", "allocation": "hold_forward", "full": 400000000, "part": 123456789},
	{"name": "gas", "ship": "res://features/catalog/records/gas_ship.tres", "cargo": "cargo_gas_lng", "allocation": "tank_lng", "full": 400, "part": 123},
	{"name": "oil", "ship": "res://features/catalog/records/oil_ship.tres", "cargo": "cargo_oil", "allocation": "", "full": 200, "part": 67},
]
var checks: int = 0
var failures: int = 0
var records: Array[ContentDefinition] = []
var cargo_by_id: Dictionary = {}
var ships: Array[ShipDefinition] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func batch(id: String, cargo_id: String, amount: Variant, allocation: String = "") -> Dictionary:
	var cargo: CargoDefinition = cargo_by_id[cargo_id]
	var row: Dictionary = {"batch_id": id, "cargo_id": cargo_id, "quantity": amount, "unit": cargo.quantity_unit,
		"origin_port_id": ORIGIN, "destination_port_id": DESTINATION, "acquisition_id": "matrix", "job_id": ""}
	if cargo.capacity_pool == "bulk_holds": row["hold_id"] = allocation
	elif cargo.capacity_pool == "gas_tanks": row["tank_id"] = allocation
	return row

func _initialize() -> void: run.call_deferred()

func run() -> void:
	records = PrototypeCatalog.RECORDS.duplicate()
	for record: ContentDefinition in records:
		if record is CargoDefinition: cargo_by_id[record.id] = record
	for family: Dictionary in families:
		ships.append(load(family.ship) as ShipDefinition)
	matrix()
	for i: int in families.size(): capacity(families[i], ships[i])
	containers()
	var bulk_state: Dictionary = service_voyage("bulk", "bulk_0_grain_forward", [1, 1, 41152263, 82304524])
	var gas_state: Dictionary = service_voyage("gas", "gas_0_lng_lng", [1, 1, 41, 80])
	check(Service.valid(bulk_state, "bulk") and Service.valid(gas_state, "gas"), "bulk and gas voyages both stay valid after the other family ran")
	check(not Service.valid(bulk_state, "gas") and not Service.valid(gas_state, "bulk"), "a finished bulk checkpoint is never accepted as gas, nor gas as bulk")
	services()
	oil()
	print("CARGO_MATRIX_PASS checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

## Every family hull against every family cargo: only its own cargo is accepted.
func matrix() -> void:
	for i: int in families.size():
		check(ships[i] != null, "%s ship definition loads" % families[i].name)
		if ships[i] == null: continue
		for j: int in families.size():
			var cargo: Dictionary = families[j]
			var label: String = "%s ship x %s cargo" % [families[i].name, cargo.name]
			var m = Manifest.new(ships[i], records)
			var result: Dictionary = m.add(batch("matrix", cargo.cargo, cargo.full, cargo.allocation))
			check(result.ok == (i == j), "%s: %s" % [label, result.message])
			check(m.lines().size() == (1 if i == j else 0), label + ": manifest holds only accepted cargo")
			if i != j: check(not m.add(batch("one", cargo.cargo, 1, cargo.allocation)).ok and m.usage().is_empty(), label + ": even one unit is refused")
	# The other purchasable container hulls carry containers and nothing else.
	for path: String in ["res://features/catalog/records/coastal_ship.tres", "res://features/catalog/records/swift_ship.tres"]:
		var hull: ShipDefinition = load(path)
		for cargo: Dictionary in families:
			var accepted: bool = Manifest.new(hull, records).add(batch("matrix", cargo.cargo, 1, cargo.allocation)).ok
			check(accepted == (cargo.name == "containers"), "%s x %s cargo" % [hull.id, cargo.name])

## Full capacity, partial quantities, duplicates and malformed rows for one family.
func capacity(family: Dictionary, ship: ShipDefinition) -> void:
	var title: String = family.name
	var pool: String = (cargo_by_id[family.cargo] as CargoDefinition).capacity_pool
	var m = Manifest.new(ship, records)
	check(m.add(batch("a", family.cargo, family.full, family.allocation)).ok, title + ": exact full capacity accepted")
	var before: Array[Dictionary] = m.lines()
	check(not m.add(batch("over", family.cargo, 1, family.allocation)).ok and m.lines() == before, title + ": one unit over capacity rejected atomically")
	check(not m.remove("a", 0).ok and not m.remove("a", family.full + 1).ok and not m.remove("missing", 1).ok and m.lines() == before, title + ": invalid removals change nothing")
	check(m.remove("a", family.part).ok and int(m.usage().get(pool, 0)) == family.full - family.part, title + ": partial removal leaves the exact remainder")
	check(m.add(batch("b", family.cargo, family.part, family.allocation)).ok and int(m.usage().get(pool, 0)) == family.full, title + ": freed quantity refills to exactly full")
	check(not m.add(batch("c", family.cargo, 1, family.allocation)).ok, title + ": refilled ship is full again")
	var one: Dictionary = batch("twice", family.cargo, 1, family.allocation)
	var twice: Array[Dictionary] = [one, one.duplicate(true)]
	check(not Manifest.new(ship, records).replace(twice).ok, title + ": repeated batch ID rejected")
	for amount: Variant in [0, -1, 1.5, true, "1", 1000000001]:
		check(not Manifest.new(ship, records).add(batch("bad", family.cargo, amount, family.allocation)).ok, title + ": invalid quantity rejected")
	var wrong: Dictionary = batch("unit", family.cargo, 1, family.allocation)
	wrong.unit = "milliliter"
	check(not Manifest.new(ship, records).add(wrong).ok, title + ": wrong unit rejected")
	# A row may not claim another family's compartment.
	for key: String in ["hold_id", "tank_id"]:
		var spoof: Dictionary = batch("spoof", family.cargo, 1, family.allocation)
		if spoof.has(key): continue
		spoof[key] = "hold_forward"
		check(not Manifest.new(ship, records).add(spoof).ok, "%s: cannot claim a %s" % [title, key])

## Container job voyage: wrong ship, interruption, duplicates and exact capacity.
func containers() -> void:
	var ship: ShipDefinition = ships[0]
	var id: String = "container_seed_v1_0_2" # three boxes, 75000 minor
	var offers = Offers.new()
	var m = Manifest.new(ship, records)
	var bulk_manifest = Manifest.new(ships[2], records)
	check(not offers.accept(id, "captain", "bulk", ORIGIN, bulk_manifest).ok and offers.view(id).state == "available", "containers: a bulk ship cannot accept a container job")
	check(not offers.accept(id, "captain", "ship", DESTINATION, m).ok, "containers: accept only at the origin")
	check(offers.accept(id, "captain", "ship", ORIGIN, m).ok, "containers: accept")
	check(offers.accept(id, "captain", "ship", ORIGIN, m).message == "Already accepted.", "containers: duplicate accept is idempotent")
	check(not offers.accept("container_seed_v1_0_0", "captain", "ship", ORIGIN, m).ok, "containers: one active job")
	check(offers.release_job(id, "captain", "ship") and offers.view(id).state == "available" and m.lines().is_empty(), "containers: interruption before loading releases the job without cargo")
	check(offers.accept(id, "captain", "ship", ORIGIN, m).ok and offers.complete_loading(id, "captain", "ship", ORIGIN, m).ok, "containers: released job is accepted and loaded later")
	check(m.usage() == {"container_slots": 3}, "containers: loaded quantity matches the job")
	check(not offers.complete_loading(id, "captain", "ship", ORIGIN, m).ok and m.usage() == {"container_slots": 3}, "containers: duplicate loading adds nothing")
	check(not offers.release_job(id, "captain", "ship"), "containers: loaded job cannot be released")
	check(not offers.deliver_at("captain", "ship", DESTINATION, m, false).ok, "containers: delivery needs a dock")
	check(not offers.deliver_at("captain", "ship", ORIGIN, m, true).ok and m.usage() == {"container_slots": 3}, "containers: wrong port keeps the cargo")
	var paid: Dictionary = offers.deliver_at("captain", "ship", DESTINATION, m, true)
	check(paid.ok and paid.reward_minor == 75000 and m.lines().is_empty(), "containers: delivery pays the quoted reward once")
	var again: Dictionary = offers.deliver_at("captain", "ship", DESTINATION, m, true)
	check(not again.ok and again.reward_minor == 0, "containers: duplicate delivery pays nothing")
	check(offers.view(id).state == "delivered" and not offers.accept(id, "captain", "ship", ORIGIN, m).ok, "containers: delivered job cannot be taken again")
	# 22 of 24 slots used: a three-box job is refused, a two-box job fills the ship exactly.
	var tight = Offers.new()
	var packed = Manifest.new(ship, records)
	check(packed.add(batch("held", "cargo_test_container", 22)).ok, "containers: prefill 22 slots")
	check(not tight.accept(id, "captain", "ship", ORIGIN, packed).ok and tight.view(id).state == "available", "containers: over-capacity job refused and left available")
	check(tight.accept("container_seed_v1_0_1", "captain", "ship", ORIGIN, packed).ok and tight.complete_loading("container_seed_v1_0_1", "captain", "ship", ORIGIN, packed).ok, "containers: exact-fit job accepted and loaded")
	check(packed.usage() == {"container_slots": 24}, "containers: ship is exactly full")

## One bulk or gas voyage through the shared service: interrupted load, partial
## discharges that sum to the frozen quote, duplicate settlement and over-discharge.
func service_voyage(family: String, id: String, parts: Array[int]) -> Dictionary:
	var full: int = 0
	for amount: int in parts: full += amount
	var s = Service.new(family)
	s.seed_offers()
	s.docked = true
	check(Service.valid(s.capture(), family), family + ": seeded state validates")
	check(s.offers.view(id).get("quantity", 0) == full, family + ": fixture quantity matches the seeded quote")
	check(s.start_loading(id) and not s.start_loading(id), family + ": double load request reserves one operation")
	check(s.advance(2.0) and s.manifest.lines().is_empty() and s.cancel(), family + ": interrupted loading leaves no cargo")
	check(s.offers.view(id).state == "available" and s.credits == 0, family + ": interrupted loading releases the job unpaid")
	check(s.start_loading(id) and s.advance(5.0), family + ": released job loads later")
	check(s.manifest.lines().size() == 1 and s.manifest.lines()[0].quantity == full, family + ": full accepted quantity aboard")
	check(not s.start_loading(id), family + ": loaded job cannot load twice")
	check(not s.start_discharge(1), family + ": no discharge at the origin")
	s.port = Service.PORTS[1]
	var terms: Dictionary = s.offers.view(id).terms
	var quote: int = s.offers.view(id).reward_minor
	var discharged: int = 0
	for amount: int in parts:
		check(not s.start_discharge(full - discharged + 1), family + ": over-discharge refused")
		check(s.start_discharge(amount) and s.advance(5.0), family + ": partial discharge commits")
		discharged += amount
		check(s.credits == s.offers.calculate(discharged, terms), family + ": cumulative payment is rounded down once, not per part")
		var replay: Dictionary = s.offers.discharge("%s_operation_%d" % [family, s.sequence], id, s.owner_id, s.ship_id, Service.PORTS[1], s.manifest, amount, true)
		check(replay.ok and replay.get("duplicate", false) and replay.reward_minor == 0, family + ": duplicate settlement pays nothing")
	check(s.credits == quote and s.manifest.lines().is_empty(), family + ": partial payments sum to the frozen quote")
	check(s.offers.view(id).state == "delivered" and not s.start_discharge(1) and not s.start_loading(id), family + ": finished job cannot pay or load again")
	check(Service.valid(s.capture(), family), family + ": completed voyage checkpoint validates")
	return s.capture()

## Valid and invalid terminals/services for the families that have a berth rule.
func services() -> void:
	var gas: ShipDefinition = ships[3]
	var lng: CargoDefinition = cargo_by_id["cargo_gas_lng"]
	var grain: CargoDefinition = cargo_by_id["cargo_bulk_grain"]
	for direction: String in ["load", "unload"]:
		check(GasRules.transfer_error(gas, lng, "tank_lng", GAS_BERTH, "pipe_lng", direction).is_empty(), "gas terminal serves the gas ship: " + direction)
		check(not GasRules.transfer_error(gas, lng, "tank_lng", QUAY_BERTH, "pipe_lng", direction).is_empty(), "container/heavy quay cannot transfer gas: " + direction)
		check(not GasRules.transfer_error(ships[2], lng, "tank_lng", GAS_BERTH, "pipe_lng", direction).is_empty(), "bulk ship cannot use the gas terminal: " + direction)
		check(not GasRules.transfer_error(gas, grain, "tank_lng", GAS_BERTH, "pipe_lng", direction).is_empty(), "gas terminal refuses a bulk commodity: " + direction)
	var terminal: BerthDefinition = GAS_BERTH.duplicate(true)
	terminal.port_id = ORIGIN
	var job: Dictionary = {"cargo_id": "cargo_gas_lng", "tank_id": "tank_lng"}
	check(GasRules.job_transfer_error(gas, records, job, terminal, ORIGIN, "load").is_empty(), "gas job accepted at its own terminal")
	check(GasRules.job_transfer_error(gas, records, job, terminal, DESTINATION, "load") == "Missing gas terminal or commodity.", "gas job refused at another port's terminal")
	check(GasRules.job_transfer_error(gas, records, job, null, ORIGIN, "load") == "Missing gas terminal or commodity.", "gas job refused without a terminal")
	check(GasRules.job_transfer_error(gas, records, {}, terminal, ORIGIN, "load") == "Unknown gas job.", "empty gas job refused")
	check(not GasRules.job_transfer_error(gas, records, {"cargo_id": "cargo_bulk_grain", "tank_id": "tank_lng"}, terminal, ORIGIN, "load").is_empty(), "bulk commodity refused as a gas job")
	check(not GasRules.job_transfer_error(gas, records, {"cargo_id": "cargo_gas_nitrogen", "tank_id": "tank_lng"}, terminal, ORIGIN, "load").is_empty(), "gas job refused for the wrong tank")
	check(not GasRules.job_transfer_error(gas, records, job, terminal, ORIGIN, "trade").is_empty(), "gas job has no trade direction")
	# The shared public quay offers container and heavy work only.
	for cargo_id: String in ["cargo_test_container", "cargo_test_industrial"]:
		check(QUAY_BERTH.cargo_type_ids.has(cargo_id), "quay handles " + cargo_id)
	for cargo_id: String in ["cargo_bulk_grain", "cargo_gas_lng", "cargo_oil"]:
		check(not QUAY_BERTH.cargo_type_ids.has(cargo_id), "quay does not handle " + cargo_id)
	check(QUAY_BERTH.service_ids.has("container_transfer") and QUAY_BERTH.service_ids.has("heavy_transfer"), "quay offers container and heavy services")
	check(not QUAY_BERTH.service_ids.has("bulk_transfer") and not QUAY_BERTH.service_ids.has("gas_transfer"), "quay offers no bulk or gas service")

func intent(id: String, kind: String, amount: Variant, lot: String = "lot_1") -> Dictionary:
	return {"id": id, "kind": kind, "barrels": amount, "lot": lot, "owner": Inventory.OWNER, "ship": Inventory.SHIP,
		"port": Inventory.BUY_PORT if kind == "buy" else Inventory.SELL_PORT}

## Oil lot voyage: undocked/over-cash refusals, duplicate intents, partial sales.
func oil() -> void:
	var s = Inventory.new()
	check(s.open("user://cargo_matrix/oil_%d_%d.sqlite" % [Time.get_ticks_usec(), randi()]), "oil: open a new isolated inventory")
	if s.blocked:
		return
	var before: Dictionary = s.capture()
	var first: Dictionary = intent("undocked", "buy", 1)
	check(not s.transact(first, first.port, false).ok and not s.transact(first, Inventory.SELL_PORT, true).ok and s.capture() == before, "oil: undocked or wrong-terminal purchase refused")
	var over: Dictionary = intent("over", "buy", 161)
	check(not s.transact(over, over.port, true).ok and s.capture() == before, "oil: purchase beyond cash refused")
	var buy: Dictionary = intent("buy", "buy", 160)
	var bought: Dictionary = s.transact(buy, buy.port, true)
	check(bought.ok and bought.wallet_delta_minor == -20000 and s.capture().credits == 0, "oil: purchase commits")
	var replayed: Dictionary = s.transact(buy, buy.port, true)
	check(replayed.ok and replayed.get("replayed", false) and replayed.wallet_delta_minor == 0 and s.capture().credits == 0, "oil: duplicate purchase has no second charge")
	var conflict: Dictionary = intent("buy", "buy", 159)
	check(not s.transact(conflict, conflict.port, true).ok, "oil: reused action ID with other terms refused")
	var sold: int = 0
	for amount: int in [1, 59, 100]:
		var oversell: Dictionary = intent("oversell_%d" % sold, "sell", 160 - sold + 1)
		check(not s.transact(oversell, oversell.port, true).ok, "oil: cannot sell more than remains")
		var sell: Dictionary = intent("sell_%d" % sold, "sell", amount)
		check(not s.transact(sell, sell.port, false).ok, "oil: undocked sale refused")
		check(s.transact(sell, sell.port, true).ok, "oil: partial sale commits")
		sold += amount
		check(s.capture().credits == sold * Inventory.SELL_MINOR and s.capture().lots.lot_1.remaining_barrels == 160 - sold, "oil: wallet and remaining barrels reconcile")
		check(s.transact(sell, sell.port, true).wallet_delta_minor == 0 and s.capture().credits == sold * Inventory.SELL_MINOR, "oil: duplicate sale pays nothing")
	check(s.capture().credits == 28000 and s.capture().manifest.is_empty() and s.capture().lots.lot_1.realized_profit_minor == 8000, "oil: final wallet, empty hold and realized profit")
	var empty: Dictionary = intent("empty", "sell", 1)
	check(not s.transact(empty, empty.port, true).ok, "oil: nothing left to sell")
	s.close()
