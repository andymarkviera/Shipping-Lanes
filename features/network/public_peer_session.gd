extends Node
## Protocol 17 DTLS admission and peer-bound helm. No arbitrary authority RPC.
const SnapshotCodec = preload("res://features/network/public_snapshot_codec.gd")
const OwnerScene = preload("res://features/network/public_ship_owner.gd")
const PhysicsWorld = preload("res://features/network/public_physics_world.gd")
var physics_world: Node
var pending_impacts: Dictionary = {}
var port_authority = preload("res://features/network/public_port_authority.gd").new()
var fleet = preload("res://features/network/public_fleet_service.gd").new()
var recovery = preload("res://features/network/public_recovery_service.gd").new()
var voyages = preload("res://features/network/public_voyage_service.gd").new()
var voyage_snapshot: Dictionary = {}
var voyage_sequence: int = 0
var voyage_received_ms: int = 0
var dock_snapshot: Dictionary = {}
var dock_notice: String = ""
var dock_sequence: int = 0
var dock_ack: int = 0
var port_tick: int = -1
var port_received_ms: int = 0
const View = preload("res://features/network/public_world_view.gd")
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")
var world_view: Node3D
var view_sequence: int = 0
signal challenged(nonce: String)
signal admitted
var hosting: bool = false
var transport: ENetMultiplayerPeer
var connection: ENetConnection
var config: Dictionary = {}
var pending: Dictionary = {}
var members: Dictionary = {}
var accounts: Dictionary = {}
var joining: bool = false
var draining: bool = false
var departures: int = 0
var departure_failures: int = 0
var client_id: int
var client_deadline: int
var nonce: String = ""
var binding: Dictionary = {}
var last_snapshot: Dictionary = {}
var join_failure: String = ""
var notice: String = "Disconnected"
var snapshot_at: int = 0
var accepted_commands: int = 0
var rejected_commands: int = 0
var ticket_sent: bool = false
var snapshot_work_us: Array[int] = []
var physics_work_us: Array[int] = []
var snapshot_bytes_sent: int = 0
var snapshot_packets_sent: int = 0
var max_snapshot_bytes: int = 0

func _ready() -> void:
	physics_world = PhysicsWorld.new()
	add_child(physics_world)
	port_authority.world = physics_world
	add_child(port_authority)
	fleet.session = self
	add_child(fleet)
	recovery.session = self
	add_child(recovery)
	voyages.session = self
	add_child(voyages)
	process_physics_priority = -100
	world_view = View.new()
	add_child(world_view)
	multiplayer.server_relay = false
	multiplayer.peer_connected.connect(connected)
	multiplayer.peer_disconnected.connect(disconnected)

func live_owners() -> Array:
	var result: Array = []
	for record: Dictionary in members.values(): result.append(record.hull)
	return result

func _physics_process(_delta: float) -> void:
	if hosting:
		var started: int = Time.get_ticks_usec()
		physics_world.sync(live_owners())
		port_authority.advance(_delta)
		physics_work_us.append(Time.get_ticks_usec() - started)
		if physics_work_us.size() > 600: physics_work_us.pop_front()

func start_server(settings: Dictionary) -> Error:
	config = settings.duplicate(true)
	var leaf: X509Certificate = X509Certificate.new()
	var key: CryptoKey = CryptoKey.new()
	if leaf.load(config.get("certificate", "")) != OK or key.load(config.get("key", "")) != OK: return ERR_INVALID_DATA
	if FileAccess.get_sha256(config.certificate) != config.get("fingerprint", ""): return ERR_UNAUTHORIZED
	transport = ENetMultiplayerPeer.new()
	transport.set_bind_ip(config.get("bind_ip", "127.0.0.1"))
	if transport.create_server(int(config.get("port", 0)), 8, 3) != OK: return ERR_CANT_CREATE
	if transport.host.dtls_server_setup(TLSOptions.server(key, leaf)) != OK:
		transport.close()
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = transport
	hosting = true
	notice = "Listening"
	return OK

func start_client(settings: Dictionary) -> Error:
	close_client()
	join_failure = ""
	nonce = ""
	ticket_sent = false
	config = settings.duplicate(true)
	var cert: X509Certificate = X509Certificate.new()
	if cert.load(config.get("certificate", "")) != OK: return ERR_INVALID_DATA
	if FileAccess.get_sha256(config.certificate) != config.get("fingerprint", ""): return ERR_UNAUTHORIZED
	connection = ENetConnection.new()
	if connection.create_host(1, 0) != OK: return ERR_CANT_CREATE
	if connection.dtls_client_setup(config.get("hostname", "localhost"), TLSOptions.client(cert)) != OK: return ERR_CANT_CONNECT
	client_id = 2 + int(Crypto.new().generate_random_bytes(4).decode_u32(0) % 2147483645)
	connection.connect_to_host(config.get("host", "127.0.0.1"), int(config.get("port", 0)), 5, client_id)
	client_deadline = Time.get_ticks_msec() + 8000
	notice = "Verifying server"
	return OK

func connected(id: int) -> void:
	if not hosting: return
	if draining: transport.disconnect_peer(id); return
	var challenge: String = Crypto.new().generate_random_bytes(32).hex_encode()
	pending[id] = {"nonce": challenge, "deadline": Time.get_ticks_msec() + 30000, "busy": false}
	connection_challenge.rpc_id(id, challenge, str(config.server))

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if not hosting and connection != null and transport == null:
		var event: Array = connection.service(0)
		if event[0] == ENetConnection.EVENT_CONNECT:
			transport = ENetMultiplayerPeer.new()
			if transport.create_mesh(client_id) != OK: return
			multiplayer.multiplayer_peer = transport
			if transport.add_mesh_peer(1, connection) != OK: close_client(); return
			notice = "Awaiting sign-in ticket"
		if now >= client_deadline and transport == null: close_client()
	if not hosting: return
	for id: int in pending.keys():
		if now >= pending[id].deadline:
			pending.erase(id)
			transport.disconnect_peer(id)
	for id: int in members.keys():
		var record: Dictionary = members[id]
		if record.hull.recovery_placing and Engine.get_physics_frames() >= record.hull.placement_frame and physics_world.changed_frame != Engine.get_physics_frames() and physics_world.can_place(record.hull, live_owners()):
			record.hull.recovery_placing = false
			record.hull.ship.collision_layer = CollisionRules.HULL
			record.hull.ship.collision_mask = CollisionRules.SOLID_WATERCRAFT
			record.hull.ship.simulation_paused = false
		if not record.hull.authority.active:
			transport.disconnect_peer(id)
			disconnected(id)
		elif now - record.input_at > 1000:
			record.hull.ship.command_throttle(0)
			record.hull.ship.maneuver(0, 0)
	if now >= snapshot_at:
		var started: int = Time.get_ticks_usec()
		snapshot_at = now + 100
		view_sequence += 1
		for id: int in members:
			var record: Dictionary = members[id]
			var origin: Dictionary = record.hull.current_address()
			var rows: Array = []
			for other: Dictionary in members.values():
				var address: Dictionary = other.hull.current_address()
				if Nav.separation(origin, address) > Nav.LOCAL_RANGE_M: continue
				var position_: Vector3 = Nav.local_position(origin, address)
				var yaw: float = -deg_to_rad(address.heading_deg) - Nav.transport_rotation(origin, address)
				rows.append({"ship": other.ship, "generation": other.generation, "position": position_, "yaw": yaw})
			var hull: HandlingShip = record.hull.ship
			var packet: PackedByteArray = SnapshotCodec.encode(rows, record.sequence, hull.state.fuel_liters, hull.velocity.length(), hull.position.length(), hull.forward_speed())
			if packet.is_empty(): continue
			# Count serialized arguments, excluding ENet/DTLS/IP overhead.
			var size: int = var_to_bytes([record.ship, record.epoch, record.generation, view_sequence, [packet]]).size()
			if size > 1200: continue
			max_snapshot_bytes = maxi(max_snapshot_bytes, size)
			snapshot_bytes_sent += size
			snapshot_packets_sent += 1
			world_update.rpc_id(id, record.ship, record.epoch, record.generation, view_sequence, [packet])
			var ports: Array = []
			for port_id: String in physics_world.Ports.IDS:
				if Nav.separation(origin, physics_world.Ports.address(port_id)) > 2200: continue
				var pose: Transform3D = physics_world.Ports.pose(origin, port_id)
				ports.append({"id": port_id, "position": pose.origin, "yaw": pose.basis.get_euler().y})
			var status: Dictionary = port_authority.status(id)
			if status.state == "underway" and record.dock_notice == "Releasing ship…": record.dock_notice = ""
			var port_bytes: int = var_to_bytes([record.ship, record.epoch, record.generation, view_sequence, ports, status, record.dock_sequence, record.dock_notice]).size()
			max_snapshot_bytes = maxi(max_snapshot_bytes, port_bytes)
			snapshot_bytes_sent += port_bytes
			snapshot_packets_sent += 1
			port_update.rpc_id(id, record.ship, record.epoch, record.generation, view_sequence, ports, status, record.dock_sequence, record.dock_notice)
		snapshot_work_us.append(Time.get_ticks_usec() - started)
		if snapshot_work_us.size() > 256: snapshot_work_us.pop_front()

@rpc("authority", "call_remote", "reliable")
func connection_challenge(value: String, server: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or server != config.get("server") or not nonce.is_empty(): return
	if value.length() != 64 or not value.is_valid_hex_number(): return
	nonce = value
	challenged.emit(nonce)

func submit_ticket(ticket: String) -> void:
	if hosting or transport == null or nonce.is_empty() or ticket_sent: return
	ticket_sent = true
	join_public.rpc_id(1, 17, ticket)

@rpc("any_peer", "call_remote", "reliable")
func join_public(version: int, ticket: String) -> void:
	if not hosting or draining: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not pending.has(sender) or pending[sender].busy: return
	if version != 17:
		reject_join(sender, "BUILD_MISMATCH")
		return
	if ticket.length() < 20 or ticket.length() > 128:
		reject_join(sender, "SIGN_IN_AGAIN")
		return
	if joining:
		reject_join(sender, "SERVER_BUSY")
		return
	joining = true
	pending[sender].busy = true
	var hull: Node3D = OwnerScene.new()
	add_child(hull)
	if not hull.authority.configure(config):
		joining = false
		hull.queue_free()
		reject_join(sender, "SERVICE_UNAVAILABLE")
		return
	var result: Dictionary = await hull.authority.request({"realm": "public", "op": "admit", "ticket": ticket, "nonce": pending[sender].nonce, "fingerprint": config.fingerprint})
	if not result.get("ok", false) or not hull.authority.active or draining or not pending.has(sender) or not multiplayer.get_peers().has(sender):
		if result.get("ok", false) and hull.authority.active:
			await hull.authority.request(hull.authority.owned("release"))
		hull.authority.quiesce()
		hull.queue_free()
		pending.erase(sender)
		if multiplayer.get_peers().has(sender):
			var code: String = str(result.get("code", ""))
			var reason: String = "SERVICE_UNAVAILABLE"
			if code in ["INVALID_TICKET", "EXPIRED_OR_USED_TICKET"]: reason = "SIGN_IN_AGAIN"
			elif code in ["ACCOUNT_BUSY", "TRANSFER_PENDING"]: reason = "ACCOUNT_BUSY"
			reject_join(sender, reason)
		joining = false
		return
	var account: String = hull.authority.binding.account
	if accounts.has(account):
		var previous: int = accounts[account]
		if members.has(previous):
			# Park and remove the old helm before activating the replacement hull.
			var old: Dictionary = members[previous]
			old.hull.authority.quiesce()
			port_authority.remove(previous)
			members.erase(previous)
			old.hull.reparent(self, false)
			old.hull.departing = true
			while old.hull.checkpoint_busy or old.hull.voyage_busy or old.hull.damage_pending or old.hull.authority.busy: await get_tree().process_frame
			old.hull.queue_free()
			transport.disconnect_peer(previous)
	# Replacement cleanup can await a save; shutdown/disconnect may occur meanwhile.
	if draining or not pending.has(sender) or not multiplayer.get_peers().has(sender):
		await hull.authority.request(hull.authority.owned("release"))
		hull.authority.quiesce()
		hull.queue_free()
		pending.erase(sender)
		accounts.erase(account)
		joining = false
		return
	# A replacement admission must reconcile an already observed impact, even if
	# its old connection was fenced or removed during the authority response.
	if pending_impacts.has(account):
		var intent: Dictionary = pending_impacts[account]
		while not intent.finished: await get_tree().process_frame
		if pending_impacts.has(account):
			var impact_request: Dictionary = intent.duplicate(true)
			impact_request.erase("finished")
			if int(impact_request.expected_revision) < 0: impact_request.expected_revision = int(result.revision)
			var impact_result: Dictionary = await hull.authority.request(hull.authority.owned("impact", impact_request))
			if not impact_result.get("ok", false):
				hull.authority.quiesce()
				hull.queue_free()
				joining = false
				reject_join(sender, "SERVICE_UNAVAILABLE")
				return
			var fresh: Dictionary = await hull.authority.request(hull.authority.owned("inspect"))
			if not fresh.get("ok", false):
				hull.authority.quiesce()
				hull.queue_free()
				joining = false
				reject_join(sender, "SERVICE_UNAVAILABLE")
				return
			result.merge(fresh, true)
			pending_impacts.erase(account)
	if draining or not pending.has(sender) or not multiplayer.get_peers().has(sender):
		await hull.authority.request(hull.authority.owned("release"))
		hull.authority.quiesce()
		hull.queue_free()
		pending.erase(sender)
		accounts.erase(account)
		joining = false
		return
	hull.host_session = self
	hull.restore_grant(result, false)
	if not physics_world.can_place(hull, live_owners()):
		# Do not teleport or checkpoint a blocked saved spawn.
		hull.park()
		await hull.authority.request(hull.authority.owned("release"))
		hull.authority.quiesce()
		hull.queue_free()
		pending.erase(sender)
		accounts.erase(account)
		joining = false
		if multiplayer.get_peers().has(sender): reject_join(sender, "SPAWN_OCCUPIED")
		return
	members[sender] = {"hull": hull, "account": account, "ship": hull.ship.state.instance_id, "epoch": int(result.epoch), "generation": int(result.generation), "sequence": -1, "input_at": Time.get_ticks_msec(), "rate_at": 0, "dock_sequence": 0, "dock_at": 0, "dock_notice": "", "voyage_sequence": 0, "voyage_at": 0, "voyage_notice": ""}
	port_authority.register(sender, hull)
	physics_world.sync(live_owners())
	hull.ship.simulation_paused = hull.recovery_required()
	joining = false
	accounts[account] = sender
	pending.erase(sender)
	join_accepted.rpc_id(sender, hull.ship.state.instance_id, int(result.epoch), int(result.generation))

# Keep the rejected peer briefly so reliable delivery is not discarded by an
# immediate disconnect. It has no hull/authority and cannot retry this ticket.
func reject_join(id: int, reason: String) -> void:
	if not hosting or not multiplayer.get_peers().has(id): return
	pending[id] = {"nonce": "", "busy": true, "deadline": Time.get_ticks_msec() + 3000}
	join_rejected.rpc_id(id, reason)

@rpc("authority", "call_remote", "reliable")
func join_rejected(reason: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or not binding.is_empty() or nonce.is_empty(): return
	if reason not in ["SPAWN_OCCUPIED", "BUILD_MISMATCH", "SIGN_IN_AGAIN", "SERVER_BUSY", "SERVICE_UNAVAILABLE", "ACCOUNT_BUSY"]: return
	join_failure = reason
	# Close outside the RPC poll; a new connection must not be closed by old work.
	close_rejected.call_deferred(nonce)

func close_rejected(attempt_nonce: String) -> void:
	if nonce == attempt_nonce and not join_failure.is_empty(): close_client()

static func failure_message(reason: String) -> String:
	match reason:
		"SPAWN_OCCUPIED": return "A boat or dock structure is too close to your saved position. Your saved position has not changed. Wait for the area to clear, then sign in and join again."
		"BUILD_MISMATCH": return "This server needs a different game version. Use the matching game build, then try again."
		"SIGN_IN_AGAIN": return "Your join permission expired or could not be verified. Sign in again to get a fresh connection."
		"SERVER_BUSY": return "The server is admitting another player. Wait a moment, then sign in and join again."
		"ACCOUNT_BUSY": return "Your boat is active on another server or is transferring. Leave that session or wait for it to finish, then sign in again."
		"SERVICE_UNAVAILABLE": return "The server could not confirm your online save. Wait a moment, then sign in and join again."
	return "Could not connect to the server. Check that it is running and reachable, then sign in and try again."

@rpc("authority", "call_remote", "reliable")
func join_accepted(ship: String, epoch: int, generation: int, snapshot_floor: int = -1) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or ship.is_empty() or epoch <= 0 or generation <= 0: return
	if not binding.is_empty() and binding.ship != ship:
		world_view.clear()
		world_view.tick = snapshot_floor
		port_tick = maxi(port_tick, snapshot_floor)
		voyage_snapshot.clear()
		dock_snapshot.clear()
		last_snapshot.clear()
	binding = {"ship": ship, "epoch": epoch, "generation": generation}
	notice = "Joined"
	admitted.emit()

func send_helm(sequence: int, throttle: float, rudder: float, candidate: Dictionary = {}, lateral: float = 0.0) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	helm_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), sequence, throttle, rudder, lateral)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func helm_order(ship: String, epoch: int, generation: int, sequence: int, throttle: float, rudder: float, lateral: float) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not members.has(sender): rejected_commands += 1; return
	var record: Dictionary = members[sender]
	var now: int = Time.get_ticks_msec()
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.sequence or sequence > 2147483647 or not is_finite(throttle) or not is_finite(rudder) or absf(throttle) > 1 or absf(rudder) > 1 or not is_finite(lateral) or absf(lateral) > 1 or now - record.rate_at < 30:
		rejected_commands += 1
		return
	if not record.hull.helm(record.hull.authority.binding, throttle, rudder, lateral): rejected_commands += 1; return
	record.sequence = sequence
	record.input_at = now
	record.rate_at = now
	accepted_commands += 1

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func state_update(ship: String, epoch: int, generation: int, position_: Vector3, yaw: float, velocity_: Vector3, fuel: float, sequence: int) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or binding != {"ship": ship, "epoch": epoch, "generation": generation}: return
	if not position_.is_finite() or not velocity_.is_finite() or not is_finite(yaw) or not is_finite(fuel): return
	last_snapshot = {"ship": ship, "distance": position_.length(), "speed": velocity_.length(), "fuel": fuel, "sequence": sequence, "received_at": Time.get_ticks_msec()}

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func world_update(ship: String, epoch: int, generation: int, tick: int, rows: Array) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or binding != {"ship": ship, "epoch": epoch, "generation": generation}: return
	if tick <= world_view.tick or rows.size() != 1 or not rows[0] is PackedByteArray: return
	var decoded: Dictionary = SnapshotCodec.decode(rows[0])
	if decoded.is_empty(): return
	var own_present: bool = false
	for row: Dictionary in decoded.rows:
		if row.ship == ship and row.generation == generation: own_present = true
	if not own_present: return
	world_view.receive(tick, decoded.rows)
	last_snapshot = {"ship": ship, "distance": decoded.distance, "speed": decoded.speed, "forward_speed": decoded.forward_speed, "fuel": decoded.fuel, "sequence": decoded.sequence, "received_at": Time.get_ticks_msec()}

func disconnected(id: int) -> void:
	if not hosting:
		if id == 1: close_client()
		return
	pending.erase(id)
	if not members.has(id): return
	var record: Dictionary = members[id]
	departures += 1
	port_authority.remove(id)
	members.erase(id)
	if accounts.get(record.account) == id: accounts.erase(record.account)
	record.hull.reparent(self, false)
	record.hull.departing = true
	record.hull.park()
	record.hull.authority.set_process(false)
	# Await any in-flight renewal before persisting/releasing the same binding.
	while is_instance_valid(record.hull) and (record.hull.authority.busy or record.hull.checkpoint_busy or record.hull.voyage_busy or record.hull.damage_pending):
		await get_tree().process_frame
	if not is_instance_valid(record.hull):
		departures -= 1
		departure_failures += 1
		return
	var completed: bool = false
	if record.hull.authority.active:
		var saved: Dictionary = await record.hull.checkpoint_current()
		if saved.get("ok", false):
			var released: Dictionary = await record.hull.authority.request(record.hull.authority.owned("release"))
			completed = released.get("ok", false)
	record.hull.authority.quiesce()
	record.hull.queue_free()
	departures -= 1
	if not completed: departure_failures += 1

func drain() -> bool:
	draining = true
	var deadline: int = Time.get_ticks_msec() + 20000
	for id: int in pending.keys():
		transport.disconnect_peer(id)
	pending.clear()
	for id: int in members.keys():
		disconnected(id)
		transport.disconnect_peer(id)
	while departures > 0 or joining:
		if Time.get_ticks_msec() >= deadline:
			print("PUBLIC_DRAIN_TIMEOUT departures=", departures, " joining=", joining)
			return false
		await get_tree().process_frame
	return departure_failures == 0

func close_client() -> void:
	# Once attached, the multiplayer peer owns and closes the ENet host.
	if transport != null: transport.close()
	elif connection != null: connection.destroy()
	transport = null
	connection = null
	if world_view != null: world_view.clear()
	binding.clear()
	last_snapshot.clear()
	dock_snapshot.clear()
	voyage_snapshot.clear()
	voyage_sequence = 0
	dock_notice = ""
	dock_sequence = 0
	dock_ack = 0
	port_tick = -1
	notice = "Disconnected"

func send_dock(action: String, port_id: String, candidate: Dictionary = {}) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	dock_sequence += 1
	dock_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), dock_sequence, action, port_id)

@rpc("any_peer", "call_remote", "reliable")
func dock_order(ship: String, epoch: int, generation: int, sequence: int, action: String, port_id: String) -> void:
	if not hosting or draining: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not members.has(sender): return
	var record: Dictionary = members[sender]
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.dock_sequence or sequence > 2147483647: return
	if action not in ["dock", "undock"] or not physics_world.Ports.IDS.has(port_id): return
	var now: int = Time.get_ticks_msec()
	if now - record.dock_at < 250: return
	record.dock_at = now
	record.dock_sequence = sequence
	record.dock_notice = port_authority.request(sender, action, port_id).message

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func port_update(ship: String, epoch: int, generation: int, tick: int, rows: Array, status: Dictionary, ack: int, message: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or binding != {"ship": ship, "epoch": epoch, "generation": generation} or tick <= port_tick: return
	if rows.size() > 2 or status.get("state") not in ["unavailable", "underway", "docking", "docked", "undocking"] or not status.get("eligible") is bool or not status.get("port_id") is String or not status.get("message") is String or message.length() > 256: return
	if not world_view.receive_ports(rows): return
	port_tick = tick
	port_received_ms = Time.get_ticks_msec()
	dock_snapshot = status.duplicate(true)
	dock_ack = ack
	dock_notice = message

func send_voyage(action: String, offer: String = "", abandon: bool = false, candidate: Dictionary = {}) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	voyage_sequence += 1
	voyage_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), voyage_sequence, action, offer, abandon)

@rpc("any_peer", "call_remote", "reliable")
func voyage_order(ship: String, epoch: int, generation: int, sequence: int, action: String, offer: String, abandon: bool) -> void:
	if not hosting or draining: return
	var peer: int = multiplayer.get_remote_sender_id()
	if not members.has(peer): return
	var record: Dictionary = members[peer]
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.voyage_sequence or sequence > 2147483647: return
	if action not in ["accept", "deliver", "cancel"] or offer.length() > 80: return
	if Time.get_ticks_msec() - record.voyage_at < 250: return
	record.voyage_at = Time.get_ticks_msec()
	record.voyage_sequence = sequence
	var result: Dictionary = await voyages.execute(peer, action, offer, abandon)
	if members.get(peer) == record: record.voyage_notice = voyages.message(result.get("code", "OUTCOME_UNKNOWN"))

@rpc("authority", "call_remote", "reliable")
func voyage_update(ship: String, epoch: int, generation: int, data: Dictionary, counts: Dictionary) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or binding != {"ship": ship, "epoch": epoch, "generation": generation}: return
	if not data.get("job") is Dictionary or not data.get("offers") is Array or data.offers.size() > 6 or counts.size() > 8: return
	voyage_snapshot = data.duplicate(true)
	voyage_received_ms = Time.get_ticks_msec()
	world_view.cargo_counts = counts.duplicate()
	world_view.wrecks = data.get("wrecks", []).duplicate()

func send_refuel(quote: String, liters: int, candidate: Dictionary = {}) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	voyage_sequence += 1
	refuel_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), voyage_sequence, quote, liters)

@rpc("any_peer", "call_remote", "reliable")
func refuel_order(ship: String, epoch: int, generation: int, sequence: int, quote: String, liters: int) -> void:
	if not hosting or draining: return
	var peer: int = multiplayer.get_remote_sender_id()
	if not members.has(peer): return
	var record: Dictionary = members[peer]
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.voyage_sequence or sequence > 2147483647: return
	if quote.length() > 80 or Time.get_ticks_msec() - record.voyage_at < 250: return
	record.voyage_at = Time.get_ticks_msec()
	record.voyage_sequence = sequence
	var result: Dictionary = await voyages.refuel(peer, quote, liters)
	if members.get(peer) == record: record.voyage_notice = voyages.message(result.get("code", "OUTCOME_UNKNOWN"))

func send_repair(quote: String, candidate: Dictionary = {}) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	voyage_sequence += 1
	repair_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), voyage_sequence, quote)

@rpc("any_peer", "call_remote", "reliable")
func repair_order(ship: String, epoch: int, generation: int, sequence: int, quote: String) -> void:
	if not hosting or draining: return
	var peer: int = multiplayer.get_remote_sender_id()
	if not members.has(peer): return
	var record: Dictionary = members[peer]
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.voyage_sequence or sequence > 2147483647: return
	if quote.length() > 80 or Time.get_ticks_msec() - record.voyage_at < 250: return
	record.voyage_at = Time.get_ticks_msec()
	record.voyage_sequence = sequence
	var result: Dictionary = await voyages.repair(peer, quote)
	if members.get(peer) == record: record.voyage_notice = voyages.message(result.get("code", "OUTCOME_UNKNOWN"))

func send_ship_purchase(quote: String, candidate: Dictionary = {}) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	voyage_sequence += 1
	ship_purchase_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), voyage_sequence, quote)

@rpc("any_peer", "call_remote", "reliable")
func ship_purchase_order(ship: String, epoch: int, generation: int, sequence: int, quote: String) -> void:
	if not hosting or draining: return
	var peer: int = multiplayer.get_remote_sender_id()
	if not members.has(peer): return
	var record: Dictionary = members[peer]
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.voyage_sequence or sequence > 2147483647: return
	if quote.length() > 80 or Time.get_ticks_msec() - record.voyage_at < 250: return
	record.voyage_at = Time.get_ticks_msec()
	record.voyage_sequence = sequence
	var result: Dictionary = await voyages.purchase_ship(peer, quote)
	if members.get(peer) == record: record.voyage_notice = voyages.message(result.get("code", "OUTCOME_UNKNOWN"))

func send_recover(incident: String, candidate: Dictionary = {}) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	voyage_sequence += 1
	recovery_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), voyage_sequence, incident)

@rpc("any_peer", "call_remote", "reliable")
func recovery_order(ship: String, epoch: int, generation: int, sequence: int, incident: String) -> void:
	if not hosting or draining: return
	var peer: int = multiplayer.get_remote_sender_id()
	if not members.has(peer): return
	var record: Dictionary = members[peer]
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.voyage_sequence or sequence > 2147483647: return
	if incident.length() > 80 or Time.get_ticks_msec() - record.voyage_at < 250: return
	record.voyage_at = Time.get_ticks_msec()
	record.voyage_sequence = sequence
	var result: Dictionary = await recovery.execute(peer, incident)
	if members.get(peer) == record: record.voyage_notice = voyages.message(result.get("code", "OUTCOME_UNKNOWN"))

func send_fleet_switch(owned_ship_id: String, candidate: Dictionary = {}) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	voyage_sequence += 1
	fleet_switch_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), voyage_sequence, owned_ship_id)

@rpc("any_peer", "call_remote", "reliable")
func fleet_switch_order(ship: String, epoch: int, generation: int, sequence: int, owned_ship_id: String) -> void:
	if not hosting or draining: return
	var peer: int = multiplayer.get_remote_sender_id()
	if not members.has(peer): return
	var record: Dictionary = members[peer]
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.voyage_sequence or sequence > 2147483647: return
	if owned_ship_id.length() > 80 or Time.get_ticks_msec() - record.voyage_at < 250: return
	record.voyage_at = Time.get_ticks_msec()
	record.voyage_sequence = sequence
	var result: Dictionary = await fleet.execute(peer, owned_ship_id)
	if members.get(peer) == record: record.voyage_notice = voyages.message(result.get("code", "OUTCOME_UNKNOWN"))


func fleet_changed(peer: int, record: Dictionary) -> void:
	join_accepted.rpc_id(peer, record.ship, record.epoch, record.generation, view_sequence)

func send_ship_resale(quote: String, candidate: Dictionary = {}) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	voyage_sequence += 1
	ship_resale_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), voyage_sequence, quote)

@rpc("any_peer", "call_remote", "reliable")
func ship_resale_order(ship: String, epoch: int, generation: int, sequence: int, quote: String) -> void:
	if not hosting or draining: return
	var peer: int = multiplayer.get_remote_sender_id()
	if not members.has(peer): return
	var record: Dictionary = members[peer]
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.voyage_sequence or sequence > 2147483647: return
	if quote.length() > 80 or Time.get_ticks_msec() - record.voyage_at < 250: return
	record.voyage_at = Time.get_ticks_msec()
	record.voyage_sequence = sequence
	var result: Dictionary = await voyages.sell_ship(peer, quote)
	if members.get(peer) == record: record.voyage_notice = voyages.message(result.get("code", "OUTCOME_UNKNOWN"))
