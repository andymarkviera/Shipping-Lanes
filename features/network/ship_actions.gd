class_name ShipActions
extends Node
## Fixed session-scoped request/result contract, not durable economic receipts.
signal result_received(result: Dictionary)
const RECEIPT_LIMIT: int = 128
const KINDS: Array[String] = ["helm", "test_pulse"]
var world: Node3D
var session: LocalShipSession
var receipts: Dictionary = {}
var high_water: Dictionary = {}
var pulses: Dictionary = {}
var received_results: int = 0

func configure(owner_world: Node3D, source: LocalShipSession) -> void:
	world = owner_world
	session = source
	set_multiplayer_authority(1)
	session.changed.connect(reconcile)

func reconcile() -> void:
	for id: String in receipts.keys():
		if not session.roster.has(id):
			receipts.erase(id)
			high_water.erase(id)
			pulses.erase(id)

static func make_request(epoch: String, player: int, entity: String, kind: String, sequence: int, payload: Dictionary, binding: int = 0) -> Dictionary:
	var request: Dictionary = {"version": 1, "epoch": epoch, "player": player, "entity": entity,
		"kind": kind, "sequence": sequence, "action_id": kind + ":" + str(sequence), "payload": payload}
	if binding != 0:
		request.version = 2
		request.generation = binding
	return request

func result(id: String, code: String, value: int = 0, applied: bool = false) -> Dictionary:
	return {"version": 1, "epoch": session.epoch, "action_id": id, "code": code,
		"ok": code == "OK", "applied": applied, "duplicate": false, "value": value}

func execute(sender: int, data: Variant) -> Dictionary:
	if not session.hosting: return result("", "NOT_AUTHORITY")
	if not data is Dictionary or data.size() not in [8, 9]: return result("", "BAD_REQUEST")
	for key: String in ["epoch", "entity", "kind", "action_id"]:
		if not data.get(key) is String or data[key].length() > 128: return result("", "BAD_REQUEST")
	var action_id: String = data.action_id
	if data.get("version") not in [1, 2] or not data.get("version") is int or not data.get("player") is int or not data.get("sequence") is int or not data.get("payload") is Dictionary:
		return result(action_id, "BAD_REQUEST")
	if data.epoch != session.epoch: return result(action_id, "STALE_SESSION")
	if data.player != sender or sender <= 0: return result(action_id, "NOT_OWNER")
	if not session.roster.has(data.entity) or not world.ships.has(data.entity): return result(action_id, "UNKNOWN_ENTITY")
	if data.version == 2 and (data.size() != 9 or not data.get("generation") is int): return result(action_id, "BAD_REQUEST")
	if data.version == 1 and data.size() != 8: return result(action_id, "BAD_REQUEST")
	if not session.permitted(sender, data.entity, int(data.get("generation", 0))): return result(action_id, "NOT_OWNER")
	var gameplay: bool = world.has_method("gameplay_payload_error") and data.kind == "gameplay"
	if data.kind not in KINDS and not gameplay: return result(action_id, "UNKNOWN_ACTION")
	if data.sequence < 1 or data.sequence > 2147483647 or action_id != data.kind + ":" + str(data.sequence): return result(action_id, "BAD_ACTION_ID")
	var ship: HandlingShip = world.ships[data.entity]
	var payload: Dictionary = data.payload
	if gameplay:
		var error: String = world.gameplay_payload_error(payload)
		if not error.is_empty(): return result(action_id, error)
	elif data.kind == "test_pulse":
		if not payload.is_empty(): return result(action_id, "BAD_PAYLOAD")
	else:
		if payload.size() != 4 or not payload.get("sent_ms") is int or payload.sent_ms < 0: return result(action_id, "BAD_PAYLOAD")
		for key: String in ["throttle", "rudder", "lateral"]:
			if not (payload.get(key) is float or payload.get(key) is int): return result(action_id, "BAD_PAYLOAD")
			if not is_finite(payload[key]): return result(action_id, "NONFINITE")
		if payload.throttle < -ship.definition.reverse_throttle_limit or payload.throttle > ship.definition.forward_throttle_limit or absf(payload.rudder) > 1 or absf(payload.lateral) > 1:
			return result(action_id, "OUT_OF_RANGE")
	var id: String = data.entity
	if not receipts.has(id):
		receipts[id] = {}
		high_water[id] = {}
	var cache: Dictionary = receipts[id]
	if cache.has(action_id):
		if cache[action_id].request != data: return result(action_id, "ID_CONFLICT")
		var replay: Dictionary = cache[action_id].result.duplicate(true)
		replay.applied = false
		replay.duplicate = true
		return replay
	if data.sequence <= high_water[id].get(data.kind, 0): return result(action_id, "STALE_ACTION")
	high_water[id][data.kind] = data.sequence
	var response: Dictionary
	if gameplay:
		response = result(action_id, world.execute_gameplay(sender, payload), 0, true)
		response.applied = response.ok
	elif data.kind == "test_pulse":
		pulses[id] = pulses.get(id, 0) + 1
		response = result(action_id, "OK", pulses[id], true)
	else:
		var now: int = Time.get_ticks_msec()
		var previous: Dictionary = world.replication.orders.get(id, {})
		if not previous.is_empty() and now - previous.at < 10:
			response = result(action_id, "RATE_LIMITED")
		else:
			world.replication.orders[id] = {"seq": data.sequence, "throttle": float(payload.throttle),
				"rudder": float(payload.rudder), "lateral": float(payload.lateral), "sent": payload.sent_ms, "at": now}
			response = result(action_id, "OK", 0, true)
	cache[action_id] = {"request": data.duplicate(true), "result": response.duplicate(true)}
	while cache.size() > RECEIPT_LIMIT: cache.erase(cache.keys()[0])
	return response

func submit(data: Dictionary) -> void:
	if session.hosting: result_received.emit(execute(1, data))
	elif session.transport != null and not session.connecting: request_action.rpc_id(1, data)

@rpc("any_peer", "call_remote", "reliable", 0)
func request_action(data: Dictionary) -> void:
	if not session.hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	var response: Dictionary = execute(sender, data)
	receive_result.rpc_id(sender, response)

@rpc("authority", "call_remote", "reliable", 0)
func receive_result(response: Dictionary) -> void:
	if session.hosting or multiplayer.get_remote_sender_id() != 1: return
	if response.size() != 8 or response.get("version") != 1 or response.get("epoch") != session.epoch: return
	if not response.get("action_id") is String or not response.get("code") is String or not response.get("value") is int: return
	for key: String in ["ok", "applied", "duplicate"]:
		if not response.get(key) is bool: return
	received_results += 1
	result_received.emit(response.duplicate(true))
