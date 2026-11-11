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
		var stored: Array = snapshot.profile.get("stored_ships", [])
		stored.append({"id": "owned_" + str(stored.size()), "definition": args.definition_id, "condition_bp": 10000})
		snapshot.profile.stored_ships = stored
		snapshot.money -= args.cost_minor
		snapshot.revision += 1
		return {"ok": true, "code": "SHIP_PURCHASED"}

class SessionDouble extends Node:
	var members: Dictionary = {}
	var binding: Dictionary = {"ship": "fixture"}
	var voyage_snapshot: Dictionary = {}
	var voyage_received_ms: int = 0
	var voyage_sequence: int = 0
	var dock_snapshot: Dictionary = {"state": "docked"}
	var sent_quote: String = ""
	func send_ship_purchase(quote: String) -> void:
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
	var rows: Array = service.ship_quotes(2)
	check(rows.size() == 4, "four progression ships")
	var quote: Dictionary = rows[1]
	check(service.ship_quotes(2)[1].id == quote.id, "stable quotes between polls")
	var registry := DefinitionRegistry.new()
	check(registry.load_definitions(PrototypeCatalog.RECORDS).is_empty(), "catalog definitions valid")
	for row: Dictionary in rows:
		var definition: ShipDefinition = registry.get_definition(row.definition)
		check(definition != null and definition.display_name == row.name and definition.fuel_capacity_liters == row.fuel_capacity_liters and definition.cargo_capacities.container_slots == 6, "preview matches definition " + row.definition)
	port.berth.service_ids = []
	check(service.ship_quotes(2).is_empty(), "berth must support ship purchase")
	port.berth.service_ids = ["ship_catalog"]
	port.definition.service_ids = []
	check(service.ship_quotes(2).is_empty(), "port must support ship purchase")
	port.definition.service_ids = ["ship_catalog"]
	owner.public_profile.jobs = [{"kind": "container_voyage_v1", "state": "loading"}]
	check(service.ship_quotes(2).is_empty(), "loading blocks purchase")
	owner.public_profile.jobs = []
	owner.ship.docked = false
	check((await service.purchase_ship(2, quote.id)).code == "DOCK_FIRST", "undocked command rejected")
	owner.ship.docked = true
	quote = service.ship_quotes(2)[1]
	session.members[2].ship_quotes.until = 0
	check((await service.purchase_ship(2, quote.id)).code == "QUOTE_CHANGED", "expired quote rejected")
	quote = service.ship_quotes(2)[1]
	owner.wallet_minor = 1
	check((await service.purchase_ship(2, quote.id)).code == "QUOTE_CHANGED", "wallet change invalidates quote")
	quote = service.ship_quotes(2)[1]
	check((await service.purchase_ship(2, quote.id)).code == "INSUFFICIENT_FUNDS", "insufficient funds rejected before I/O")
	owner.wallet_minor = 300000
	quote = service.ship_quotes(2)[1]
	var panel = preload("res://features/network/public_cargo_panel.gd").new()
	panel.session = session
	session.add_child(panel)
	panel.set_process(false)
	session.voyage_snapshot = {"ship_catalog": service.ship_quotes(2), "wallet": 300000}
	session.voyage_received_ms = Time.get_ticks_msec()
	panel._process(0.0)
	panel.ship_selected = 1
	panel._process(0.0)
	check(not panel.ship_buy.disabled and "800.00" in panel.ship_buy.text, "actual catalog button shows accepted price")
	panel.buy_ship()
	check(session.voyage_sequence == 0, "review does not purchase")
	panel.ship_confirmation = ""
	panel.buy_ship()
	check(session.voyage_sequence == 0, "cancel requires a new review")
	panel.open_inspection()
	check(panel.inspection.visible and panel.ship_confirmation.is_empty() and session.voyage_sequence == 0, "opening comparison clears purchase confirmation without sending intent")
	session.voyage_received_ms = Time.get_ticks_msec() - 3000
	panel._process(0.0)
	check(not panel.inspection.visible, "stale voyage state closes inspection")
	session.voyage_received_ms = Time.get_ticks_msec()
	panel._process(0.0)
	panel.open_inspection()
	session.binding = {}
	panel._process(0.0)
	check(not panel.inspection.visible and panel.inspection.choices.size() == 4, "disconnect clears owned inspection choices")
	session.binding = {"ship": "fixture"}
	panel._process(0.0)
	panel.ship_rows[1].id = "changed_quote"
	panel.buy_ship()
	check(session.voyage_sequence == 0, "changed quote requires confirmation again")
	panel.ship_rows[1].id = quote.id
	panel.buy_ship()
	panel._process(0.0)
	check("Confirm" in panel.ship_buy.text, "explicit purchase confirmation")
	panel.buy_ship()
	check(session.sent_quote == quote.id and session.voyage_sequence == 1, "confirmation sends only quote intent")
	panel.buy_ship()
	check(session.voyage_sequence == 1, "pending UI blocks double click")
	panel.queue_free()
	var original_id: String = owner.public_profile.ship.id
	var result: Dictionary = await service.purchase_ship(2, quote.id)
	check(result.code == "SHIP_PURCHASED", "accepted quote executes purchase")
	check(authority.calls == ["inspect", "checkpoint", "ship_purchase", "inspect"], "live state checkpoint precedes purchase and canonical refresh")
	check(owner.wallet_minor == 220000 and owner.public_profile.ship.id == original_id, "canonical debit preserves active ship identity")
	check(owner.operating_seconds == 0.0 and owner.public_profile.ship.condition_bp == 7554, "purchase preserves settled single condition")
	check((await service.purchase_ship(2, quote.id)).code == "QUOTE_CHANGED", "consumed quote cannot replay with new sequence")
	quote = service.ship_quotes(2)[1]
	result = await service.purchase_ship(2, quote.id)
	check(result.code == "SHIP_PURCHASED" and owner.public_profile.stored_ships.size() == 2 and owner.wallet_minor == 140000, "second deliberate purchase has another stored instance")
	check(owner.public_profile.stored_ships[0].id != owner.public_profile.stored_ships[1].id, "two purchases have distinct owned IDs")
	var inspected: Dictionary = service.view(2)
	check(inspected.fleet.size() == 3 and inspected.fleet[0].id == original_id, "owner voyage snapshot contains active and both stored purchases")
	check(inspected.fleet[1].id != inspected.fleet[2].id, "inspection retains distinct same-definition owned IDs")
	owner.ship.docked = false
	check(service.view(2).fleet.is_empty(), "fleet is omitted outside dock services")
	owner.ship.docked = true
	authority.unknown = true
	quote = service.ship_quotes(2)[0]
	result = await service.purchase_ship(2, quote.id)
	check(result.code == "OUTCOME_UNKNOWN" and not authority.active, "uncertain outcome fences authority")
	check((await service.purchase_ship(2, quote.id)).code == "DISCONNECTED", "fenced owner cannot retry payment")
	print("SHIP_PURCHASE_RUNTIME_PASS ", checks)
	session.free()
	quit(1 if failures else 0)
