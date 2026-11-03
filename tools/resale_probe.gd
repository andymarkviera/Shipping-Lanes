extends SceneTree
## Real service/UI code with an explicitly in-memory authority double, not SQL proof.
const Service = preload("res://features/network/public_voyage_service.gd")
const Owner = preload("res://features/network/public_ship_owner.gd")
var checks: int = 0
var failures: int = 0

class AuthorityDouble extends Node:
	var active: bool = true
	var busy: bool = false
	var snapshot: Dictionary
	var calls: Array[String] = []
	var unknown: bool = false
	func owned(op: String, args: Dictionary = {}) -> Dictionary:
		return dict_with_op(op, args)
	func dict_with_op(op: String, args: Dictionary) -> Dictionary:
		var result: Dictionary = args.duplicate(true)
		result.op = op
		return result
	func quiesce() -> void: active = false
	func request(args: Dictionary) -> Dictionary:
		calls.append(args.op)
		if args.op == "inspect": return snapshot.duplicate(true)
		if args.op == "checkpoint":
			var ship: Dictionary = snapshot.profile.ship
			var fraction: float = ship.wear_fraction_bp + args.operating_seconds * 100.0 / 3600.0
			ship.condition_bp = maxi(mini(ship.condition_bp, 1000), ship.condition_bp - int(fraction))
			ship.wear_fraction_bp = fraction - int(fraction)
			snapshot.revision += 1
			return {"ok": true, "revision": snapshot.revision, "condition_bp": ship.condition_bp}
		if unknown:
			active = false
			return {"ok": false, "code": "OUTCOME_UNKNOWN"}
		var stored: Array = snapshot.profile.stored_ships
		stored.pop_front()
		snapshot.money += args.value_minor
		snapshot.revision += 1
		return {"ok": true, "code": "SHIP_SOLD"}

class SessionDouble extends Node:
	var members: Dictionary = {}
	var binding: Dictionary = {"ship": "fixture"}
	var voyage_snapshot: Dictionary = {}
	var voyage_received_ms: int = 0
	var voyage_sequence: int = 0
	var dock_snapshot: Dictionary = {"state": "docked"}
	var sent_quote: String = ""
	func send_ship_resale(quote: String) -> void:
		sent_quote = quote
		voyage_sequence += 1
	var port_authority: Node
	var physics_world: Node
class PortsDouble extends Node:
	var entries: Dictionary = {}
class WorldDouble extends Node:
	var port: Node3D
	func port_for(_owner: Node3D, _id: String) -> Node3D: return port
class PortDouble extends Node3D:
	var definition: Dictionary = {"service_ids": ["ship_catalog"]}
	var berth: Dictionary = {"service_ids": ["ship_catalog"]}

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
	checks += 1
	print("PASS ", message)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var session := SessionDouble.new()
	root.add_child(session)
	var ports := PortsDouble.new()
	var world := WorldDouble.new()
	var port := PortDouble.new()
	session.add_child(ports)
	session.add_child(world)
	session.add_child(port)
	world.port = port
	session.port_authority = ports
	session.physics_world = world
	var service := Service.new()
	session.add_child(service)
	service.set_process(false)
	service.session = session
	var owner := Owner.new()
	session.add_child(owner)
	owner.set_process(false)
	owner.set_physics_process(false)
	owner.authority.queue_free()
	var authority := AuthorityDouble.new()
	owner.add_child(authority)
	owner.authority = authority
	authority.snapshot = {"ok": true, "revision": 1, "money": 300000, "profile": {"ship": {"id": "fixture", "definition": "ship_starter_container_01", "condition_bp": 7555, "wear_fraction_bp": 0.75, "fuel_liters": 800.0, "position": {"latitude": 0.0, "longitude": 0.0, "heading": 0.0}}, "cargo": [], "jobs": []}}
	owner.restore_grant(authority.snapshot)
	owner.ship.set_physics_process(false)
	owner.ship.docked = true
	owner.operating_seconds = 36.0
	session.members[2] = {"hull": owner, "voyage_sequence": 0, "voyage_notice": ""}
	ports.entries[2] = {"owner": owner, "state": "docked", "port_id": "port_brindle_quay"}
	owner.public_profile.stored_ships = [{"id": "stored", "definition": "ship_coastal_container_01", "condition_bp": 5000, "fuel_liters": 123.0, "storage_port_id": "port_brindle_quay"}]
	authority.snapshot.profile.stored_ships = owner.public_profile.stored_ships.duplicate(true)
	var quote: Dictionary = service.resale_quotes(2)[0]
	check(int(quote.value_minor) == 27000, "condition-scaled legacy valuation")
	check(service.resale_quotes(2)[0].id == quote.id, "stable quotes")
	port.berth.service_ids = []
	check(service.resale_quotes(2).is_empty(), "service berth required")
	port.berth.service_ids = ["ship_catalog"]
	for state: String in ["loading", "loaded", "unknown"]:
		owner.public_profile.jobs = [{"state": state}]
		check(service.resale_quotes(2).is_empty(), "unfinished job blocks resale " + state)
	owner.public_profile.jobs = []
	owner.cargo_records = [{"id": "cargo"}]
	check(service.resale_quotes(2).is_empty(), "cargo blocks resale")
	owner.cargo_records = []
	owner.public_profile.stored_ships[0].storage_port_id = "port_slatewater_works"
	check(service.resale_quotes(2).is_empty(), "storage port required")
	owner.public_profile.stored_ships[0].storage_port_id = "port_brindle_quay"
	owner.public_profile.stored_ships[0].cargo = [{"id": "hidden"}]
	check(service.resale_quotes(2).is_empty(), "stored manifest blocks resale")
	owner.public_profile.stored_ships[0].erase("cargo")
	owner.ship.docked = false
	check((await service.sell_ship(2, quote.id)).code == "DOCK_FIRST", "undocked resale rejected")
	owner.ship.docked = true
	quote = service.resale_quotes(2)[0]
	session.members[2].resale_quotes.until = 0
	check((await service.sell_ship(2, quote.id)).code == "QUOTE_CHANGED", "expired valuation rejected")
	quote = service.resale_quotes(2)[0]
	owner.public_profile.stored_ships[0].condition_bp = 4000
	check((await service.sell_ship(2, quote.id)).code == "QUOTE_CHANGED", "condition change invalidates quote")
	owner.public_profile.stored_ships[0].condition_bp = 5000
	quote = service.resale_quotes(2)[0]
	var panel = preload("res://features/network/public_cargo_panel.gd").new()
	panel.session = session
	session.add_child(panel)
	panel.set_process(false)
	session.voyage_snapshot = service.view(2)
	session.voyage_received_ms = Time.get_ticks_msec()
	panel._process(0.0)
	panel.open_inspection()
	var inspection = panel.inspection
	inspection.selectors[0].select(5)
	inspection.refresh_details()
	check(not inspection.sell.disabled and "270.00" in inspection.sell.text, "actual fleet sale control shows quote")
	inspection.sell_selected()
	check(session.voyage_sequence == 0 and "Confirm" in inspection.sell.text, "review does not sell")
	inspection.sale_confirmation = ""
	inspection.sell_selected()
	check(session.voyage_sequence == 0, "cancel requires new review")
	inspection.sell_selected()
	check(session.sent_quote == quote.id and session.voyage_sequence == 1, "confirmation sends quote intent")
	panel.sell_ship(quote.id)
	check(session.voyage_sequence == 1, "pending UI blocks duplicate click")
	var report: Dictionary = {"gross_revenue_minor": 25000, "acquisition_cost_minor": 0, "fuel_minor": 2500, "repair_minor": 1000, "recovery_paid_minor": 0, "recovery_repaid_minor": 0, "other_cash_minor": 0, "net_minor": 21500, "wallet_start_minor": 300000, "wallet_end_minor": 321500}
	session.voyage_snapshot.voyage_report = report
	panel._process(0.0)
	check("Gross revenue 250.00" in panel.receipt.text and "Net cash +215.00" in panel.receipt.text, "receipt distinguishes revenue from net")
	panel.queue_free()
	var original_id: String = owner.public_profile.ship.id
	var result: Dictionary = await service.sell_ship(2, quote.id)
	check(result.code == "SHIP_SOLD", "accepted valuation sells")
	check(authority.calls == ["inspect", "checkpoint", "ship_resale", "inspect"], "checkpoint then sale then canonical reload")
	check(owner.wallet_minor == 327000 and owner.public_profile.ship.id == original_id, "wallet credit and retained active hull")
	check(owner.operating_seconds == 0.0 and owner.public_profile.ship.condition_bp == 7554, "pending wear retained")
	check(owner.public_profile.stored_ships.is_empty(), "stored ship removed")
	check((await service.sell_ship(2, quote.id)).code == "QUOTE_CHANGED", "consumed sale quote rejected")
	owner.public_profile.stored_ships = [{"id": "other", "definition": "ship_coastal_container_01", "condition_bp": 5000, "storage_port_id": "port_brindle_quay"}]
	authority.unknown = true
	quote = service.resale_quotes(2)[0]
	result = await service.sell_ship(2, quote.id)
	check(result.code == "OUTCOME_UNKNOWN" and not authority.active, "uncertain sale fences authority")
	check((await service.sell_ship(2, quote.id)).code == "DISCONNECTED", "no automatic retry after unknown outcome")
	print("RESALE_RUNTIME_PASS ", checks)
	session.free()
	quit(1 if failures else 0)
