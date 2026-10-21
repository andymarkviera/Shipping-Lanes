class_name ShipReplication
extends Node
## Host physics only. Client hulls are buffered presentation, never predictions.
const SEND_INTERVAL: float = 0.05
const INPUT_TIMEOUT_MS: int = 500
const BUFFER_SECONDS: float = 0.15
var world: Node3D
var session: LocalShipSession
var orders: Dictionary = {}
var samples: Dictionary = {}
var latest: Dictionary = {}
var sequence: int = 0
var state_sequence: int = 0
var received_sequence: int = -1
var elapsed: float = 0.0
var send_elapsed: float = 0.0
var clock_offset: float = INF
var rejected_inputs: int = 0
var accepted_inputs: int = 0
var snapshot_count: int = 0
var rtt_ms: float = 0.0
var last_ack_ms: int = 0
var input_enabled: bool = true
var impairment: bool = false
var packets: int = 0
var dropped: int = 0
var pending: Array[Dictionary] = []
var last_cargo_due: int = 0

func configure(owner_world: Node3D, source: LocalShipSession) -> void:
	world = owner_world
	session = source
	process_physics_priority = -10
	set_multiplayer_authority(1)
	session.changed.connect(reconcile)

func reconcile() -> void:
	for id: String in orders.keys():
		if not session.roster.has(id): orders.erase(id)
	for id: String in samples.keys():
		if not session.roster.has(id):
			samples.erase(id)
			latest.erase(id)
	if session.roster.is_empty():
		pending.clear()
		last_cargo_due = 0
		sequence = 0
		state_sequence = 0
		received_sequence = -1
		clock_offset = INF
		rtt_ms = 0
		last_ack_ms = 0

func local_entity() -> String:
	for id: String in session.roster:
		if session.roster[id].peer_id == multiplayer.get_unique_id(): return id
	return ""

func submit(throttle: float, rudder: float, lateral: float) -> void:
	if not input_enabled: return
	var id: String = local_entity()
	if id.is_empty(): return
	sequence += 1
	var arguments: Array = [session.epoch, id, sequence, throttle, rudder, lateral, Time.get_ticks_msec()]
	if session.hosting:
		accept_input(1, arguments)
	else:
		queue_packet("input", arguments)

func queue_packet(kind: String, arguments: Array) -> void:
	packets += 1
	if impairment and kind != "cargo" and packets % 10 == 0:
		dropped += 1
		return
	if pending.size() >= 128: return
	var delay: int = 100 + [-20, 0, 20, 0][packets % 4] if impairment else 0
	var due: int = Time.get_ticks_msec() + delay
	if kind == "cargo":
		due = maxi(due, last_cargo_due + 1)
		last_cargo_due = due
	pending.append({"due": due, "kind": kind, "args": arguments})

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	pending.sort_custom(func(a: Dictionary, b: Dictionary): return a.due < b.due)
	while not pending.is_empty() and pending[0].due <= now:
		var packet: Dictionary = pending.pop_front()
		if session.transport == null: continue
		var args: Array = packet.args
		if packet.kind == "input" and not session.connecting:
			request_input.rpc_id(1, args[0], args[1], args[2], args[3], args[4], args[5], args[6])
		elif packet.kind == "cargo" and not session.connecting:
			world.cargo_sync.request_action.rpc_id(1, args[0], args[1], args[2], args[3])
		elif packet.kind == "state" and session.hosting:
			for peer: int in multiplayer.get_peers():
				receive_state.rpc_id(peer, args[0], args[1], args[2], args[3], args[4])
	if not session.hosting: interpolate()

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func request_input(session_epoch: String, id: String, seq: int, throttle: float, rudder: float, lateral: float, sent_ms: int) -> void:
	if not session.hosting: return
	accept_input(multiplayer.get_remote_sender_id(), [session_epoch, id, seq, throttle, rudder, lateral, sent_ms])

func accept_input(sender: int, args: Array) -> bool:
	if args.size() != 7 or not args[0] is String or not args[1] is String or not args[2] is int or not args[6] is int:
		rejected_inputs += 1
		return false
	var request: Dictionary = ShipActions.make_request(args[0], sender, args[1], "helm", args[2],
		{"throttle": args[3], "rudder": args[4], "lateral": args[5], "sent_ms": args[6]})
	var response: Dictionary = world.actions.execute(sender, request)
	if response.applied:
		accepted_inputs += 1
		return true
	rejected_inputs += 1
	return false

func _physics_process(delta: float) -> void:
	if session == null or not session.hosting: return
	elapsed += delta
	for id: String in world.ships:
		var ship: HandlingShip = world.ships[id]
		var order: Dictionary = orders.get(id, {})
		if order.is_empty() or Time.get_ticks_msec() - order.at > INPUT_TIMEOUT_MS:
			ship.zero_throttle()
			ship.maneuver(0, 0)
		else:
			ship.command_throttle(order.throttle)
			ship.maneuver(order.rudder, order.lateral)
	send_elapsed += delta
	if send_elapsed < SEND_INTERVAL: return
	send_elapsed = fmod(send_elapsed, SEND_INTERVAL)
	state_sequence += 1
	var records: Array = []
	for id: String in world.ships:
		var ship: HandlingShip = world.ships[id]
		records.append({"id": id, "position": ship.position, "yaw": ship.rotation.y, "velocity": ship.velocity,
			"command": ship.commanded_throttle, "engine": ship.actual_throttle, "fuel": ship.state.fuel_liters,
			"cargo": world.cargo_sync.snapshot(id, ship), "rudder": ship.rudder, "lateral": ship.lateral_order, "ack": orders.get(id, {}).get("sent", 0)})
	queue_packet("state", [session.epoch, session.revision, state_sequence, elapsed, records])

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_state(session_epoch: String, roster_revision: int, seq: int, stamp: float, records: Array) -> void:
	if session.hosting or multiplayer.get_remote_sender_id() != 1 or session_epoch != session.epoch or roster_revision != session.revision or seq <= received_sequence: return
	if not is_finite(stamp) or stamp < 0 or records.size() != session.roster.size(): return
	var seen: Dictionary = {}
	for record: Variant in records:
		if not record is Dictionary or not record.get("id") is String or not world.ships.has(record.id) or seen.has(record.id): return
		if not record.get("position") is Vector3 or not record.position.is_finite() or not record.get("velocity") is Vector3 or not record.velocity.is_finite(): return
		for key: String in ["yaw", "command", "engine", "fuel", "rudder", "lateral"]:
			if not record.get(key) is float or not is_finite(record[key]): return
		if not record.get("ack") is int or record.fuel < 0 or record.fuel > world.ships[record.id].definition.fuel_capacity_liters: return
		if not CargoReplication.valid(record.id, world.ships[record.id], record.get("cargo")): return
		seen[record.id] = true
	received_sequence = seq
	snapshot_count += 1
	clock_offset = minf(clock_offset, Time.get_ticks_msec() / 1000.0 - stamp)
	for record: Dictionary in records:
		var id: String = record.id
		latest[id] = record
		if not samples.has(id):
			samples[id] = []
			world.ships[id].position = record.position
			world.ships[id].rotation.y = record.yaw
		samples[id].append({"stamp": stamp, "record": record})
		while samples[id].size() > 16: samples[id].pop_front()
		if id == local_entity() and record.ack > last_ack_ms:
			last_ack_ms = record.ack
			rtt_ms = maxf(0, Time.get_ticks_msec() - record.ack)

func interpolate() -> void:
	if not is_finite(clock_offset): return
	var target: float = Time.get_ticks_msec() / 1000.0 - clock_offset - BUFFER_SECONDS
	for id: String in samples:
		if not world.ships.has(id): continue
		var buffer: Array = samples[id]
		while buffer.size() > 2 and buffer[1].stamp <= target: buffer.pop_front()
		var a: Dictionary = buffer[0]
		var b: Dictionary = buffer[mini(1, buffer.size() - 1)]
		var weight: float = clampf((target - a.stamp) / maxf(0.000001, b.stamp - a.stamp), 0, 1)
		var ship: HandlingShip = world.ships[id]
		ship.position = a.record.position.lerp(b.record.position, weight)
		ship.rotation.y = lerp_angle(a.record.yaw, b.record.yaw, weight)
		ship.velocity = a.record.velocity.lerp(b.record.velocity, weight)
		ship.commanded_throttle = b.record.command
		ship.actual_throttle = b.record.engine
		ship.state.fuel_liters = b.record.fuel
		ship.rudder = b.record.rudder
		ship.lateral_order = b.record.lateral
		CargoReplication.present(ship, a.record.cargo, b.record.cargo, weight)
