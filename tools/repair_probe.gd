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
		assert(args.condition_bp == snapshot.profile.ship.condition_bp)
		snapshot.profile.ship.condition_bp = 10000
		snapshot.profile.ship.wear_fraction_bp = 0.0
		snapshot.money -= args.cost_minor
		snapshot.revision += 1
		return {"ok": true, "code": "REPAIRED"}

class SessionDouble extends Node:
	var members: Dictionary = {}
	var binding: Dictionary = {"ship": "fixture"}
	var voyage_snapshot: Dictionary = {}
	var voyage_received_ms: int = 0
	var voyage_sequence: int = 0
	var dock_snapshot: Dictionary = {"state": "docked"}
	var sent_quote: String = ""
	func send_repair(quote: String) -> void:
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
	var definition: Dictionary = {"service_ids": ["repair"]}
	var berth: Dictionary = {"service_ids": ["repair"]}

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
	authority.snapshot = {"ok": true, "revision": 1, "money": 20000, "profile": {"ship": {"id": "fixture", "definition": "ship_starter_container_01", "condition_bp": 7555, "wear_fraction_bp": 0.75, "fuel_liters": 800.0, "position": {"latitude": 0.0, "longitude": 0.0, "heading": 0.0}}, "cargo": [], "jobs": []}}
	owner.restore_grant(authority.snapshot)
	owner.ship.set_physics_process(false)
	owner.ship.docked = true
	owner.operating_seconds = 36.0
	session.members[2] = {"hull": owner}
	ports.entries[2] = {"owner": owner, "state": "docked", "port_id": "port_brindle_quay"}
	var quote: Dictionary = service.repair_quote(2)
	check(quote.condition_bp == 7554 and quote.cost_minor == 6115, "quote includes pending wear and rounded total")
	check(service.repair_quote(2).id == quote.id, "stable quote between polls")
	port.berth.service_ids = []
	check(service.repair_quote(2).is_empty(), "berth must support repairs")
	port.berth.service_ids = ["repair"]
	port.definition.service_ids = []
	check(service.repair_quote(2).is_empty(), "port must support repairs")
	port.definition.service_ids = ["repair"]
	owner.public_profile.jobs = [{"kind": "container_voyage_v1", "state": "loading"}]
	check(service.repair_quote(2).is_empty(), "loading blocks repair")
	owner.public_profile.jobs = []
	owner.ship.docked = false
	check((await service.repair(2, quote.id)).code == "DOCK_FIRST", "undocked command rejected")
	owner.ship.docked = true
	quote = service.repair_quote(2)
	session.members[2].repair_quote.until = 0
	check((await service.repair(2, quote.id)).code == "QUOTE_CHANGED", "expired quote rejected")
	quote = service.repair_quote(2)
	owner.wallet_minor = 1
	check((await service.repair(2, quote.id)).code == "QUOTE_CHANGED", "wallet changes invalidate quote")
	quote = service.repair_quote(2)
	check((await service.repair(2, quote.id)).code == "INSUFFICIENT_FUNDS", "insufficient funds rejected before I/O")
	owner.wallet_minor = 20000
	quote = service.repair_quote(2)
	var panel = preload("res://features/network/public_cargo_panel.gd").new()
	panel.session = session
	session.add_child(panel)
	panel.set_process(false)
	session.voyage_snapshot = {"repair": quote, "wallet": 20000}
	session.voyage_received_ms = Time.get_ticks_msec()
	panel._process(0.0)
	check(not panel.repair_buy.disabled and "61.15" in panel.repair_buy.text, "actual Repair button displays accepted total")
	panel.buy_repair()
	check(session.sent_quote == quote.id and session.voyage_sequence == 1, "actual Repair button sends only quote intent")
	panel.buy_repair()
	check(session.voyage_sequence == 1, "UI pending state blocks double click")
	panel.queue_free()
	var result: Dictionary = await service.repair(2, quote.id)
	check(result.code == "REPAIRED", "accepted quote executes repair")
	check(authority.calls == ["inspect", "checkpoint", "repair", "inspect"], "checkpoint before purchase and canonical refresh after")
	check(owner.wallet_minor == 13885 and owner.ship.state.condition == 1.0, "canonical money and condition installed")
	check(owner.operating_seconds == 0.0 and owner.public_profile.ship.wear_fraction_bp == 0.0, "settled wear not charged again")
	check((await service.repair(2, quote.id)).code == "QUOTE_CHANGED", "consumed quote cannot replay")
	quote = service.repair_quote(2)
	check((await service.repair(2, quote.id)).code == "NO_REPAIR_NEEDED", "full condition cannot be purchased again")
	owner.public_profile.ship.condition_bp = 9000
	authority.snapshot.profile.ship.condition_bp = 9000
	authority.unknown = true
	quote = service.repair_quote(2)
	result = await service.repair(2, quote.id)
	check(result.code == "OUTCOME_UNKNOWN" and not authority.active, "uncertain outcome retains authority fencing")
	check((await service.repair(2, quote.id)).code == "DISCONNECTED", "fenced owner cannot retry payment")
	print("REPAIR_RUNTIME_PASS ", checks)
	session.free()
	quit(1 if failures else 0)
