extends Node
## Run on local/server authority, not on a remote presentation client.
var rule = preload("res://features/cargo/port_loading_rule.gd").new()
var operation: String = ""
var offer_id: String = ""
var sequence: int = 0
var notice: String = "Dock to load accepted cargo."

func bind(body: HandlingShip, port: Node3D, docking: Node, offers: RefCounted, peer: int, owner: String, ship_key: String) -> void:
	rule.body = body
	rule.port = port
	rule.docking = docking
	rule.offers = offers
	rule.peer = peer
	rule.owner = owner
	rule.ship_key = ship_key
	body.state.operations.register_rule("port_loading", rule)

func busy() -> bool:
	return not operation.is_empty()

func start(id: String) -> bool:
	if busy() or not is_instance_valid(rule.body): return false
	var offer: Dictionary = rule.offers.view(id)
	if offer.is_empty(): return false
	sequence += 1
	var next: String = "load_%s_%d" % [id, sequence]
	var service: RefCounted = rule.body.state.operations
	var result: Dictionary = service.reserve(next, rule.body.state.instance_id, "port_loading", {"offer_id": id}, offer.quantity * 5.0)
	notice = result.message
	if not result.ok: return false
	operation = next
	offer_id = id
	service.start(operation)
	notice = "Loading cargo…"
	return true

func cancel(interrupted: bool = false) -> void:
	if not busy(): return
	if is_instance_valid(rule.body): rule.body.state.operations.cancel(operation, interrupted)
	rule.offers.release_job(offer_id, rule.owner, rule.ship_key)
	operation = ""
	offer_id = ""
	notice = "Loading interrupted; job released." if interrupted else "Loading cancelled; job released."

func disconnect_ship() -> void:
	cancel(true)
	if rule.offers != null: rule.offers.release_pending(rule.owner, rule.ship_key)

func advance(delta: float) -> void:
	if not busy(): return
	if not is_instance_valid(rule.body):
		cancel(true)
		return
	var service: RefCounted = rule.body.state.operations
	if not rule.validate(service.record(operation)).is_empty():
		cancel(true)
		return
	service.progress(operation, delta)
	var record: Dictionary = service.record(operation)
	if record.state == "ready":
		var result: Dictionary = service.commit(operation)
		if not result.ok: rule.offers.release_job(offer_id, rule.owner, rule.ship_key)
		notice = "Cargo loaded." if result.ok else result.message
		operation = ""
		offer_id = ""

func progress_percent() -> float:
	if not busy() or not is_instance_valid(rule.body): return 0
	var record: Dictionary = rule.body.state.operations.record(operation)
	return record.elapsed / record.duration * 100.0

func _physics_process(delta: float) -> void:
	advance(delta)

func _exit_tree() -> void:
	disconnect_ship()
