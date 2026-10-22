extends Node
## Protocol 7 DTLS admission and peer-bound helm. No arbitrary authority RPC.
const OwnerScene = preload("res://features/network/public_ship_owner.gd")
const PhysicsWorld = preload("res://features/network/public_physics_world.gd")
var physics_world: Node
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
var client_id: int
var client_deadline: int
var nonce: String = ""
var binding: Dictionary = {}
var last_snapshot: Dictionary = {}
var notice: String = "Disconnected"
var snapshot_at: int = 0
var accepted_commands: int = 0
var rejected_commands: int = 0
var ticket_sent: bool = false

func _ready() -> void:
	physics_world = PhysicsWorld.new()
	add_child(physics_world)
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
	if hosting: physics_world.sync(live_owners())

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
		if not record.hull.authority.active:
			transport.disconnect_peer(id)
			disconnected(id)
		elif now - record.input_at > 1000:
			record.hull.ship.command_throttle(0)
			record.hull.ship.maneuver(0, 0)
	if now >= snapshot_at:
		snapshot_at = now + 200
		for id: int in members:
			var record: Dictionary = members[id]
			var ship: HandlingShip = record.hull.ship
			state_update.rpc_id(id, record.ship, record.epoch, record.generation, ship.position, ship.rotation.y, ship.velocity, ship.state.fuel_liters, record.sequence)
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
			world_update.rpc_id(id, record.ship, record.epoch, record.generation, view_sequence, rows)

@rpc("authority", "call_remote", "reliable")
func connection_challenge(value: String, server: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or server != config.get("server") or not nonce.is_empty(): return
	if value.length() != 64 or not value.is_valid_hex_number(): return
	nonce = value
	challenged.emit(nonce)

func submit_ticket(ticket: String) -> void:
	if hosting or transport == null or nonce.is_empty() or ticket_sent: return
	ticket_sent = true
	join_public.rpc_id(1, 7, ticket)

@rpc("any_peer", "call_remote", "reliable")
func join_public(version: int, ticket: String) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not pending.has(sender) or pending[sender].busy: return
	if version != 7 or ticket.length() < 20 or ticket.length() > 128 or joining:
		transport.disconnect_peer(sender)
		pending.erase(sender)
		return
	joining = true
	pending[sender].busy = true
	var hull: Node3D = OwnerScene.new()
	add_child(hull)
	if not hull.authority.configure(config):
		joining = false
		hull.queue_free()
		transport.disconnect_peer(sender)
		return
	var result: Dictionary = await hull.authority.request({"realm": "public", "op": "admit", "ticket": ticket, "nonce": pending[sender].nonce, "fingerprint": config.fingerprint})
	if not result.get("ok", false) or not hull.authority.active or not pending.has(sender) or not multiplayer.get_peers().has(sender):
		joining = false
		hull.authority.quiesce()
		hull.queue_free()
		pending.erase(sender)
		if multiplayer.get_peers().has(sender): transport.disconnect_peer(sender)
		return
	var account: String = hull.authority.binding.account
	if accounts.has(account):
		var previous: int = accounts[account]
		if members.has(previous):
			# Park and remove the old helm before activating the replacement hull.
			var old: Dictionary = members[previous]
			old.hull.authority.quiesce()
			members.erase(previous)
			old.hull.reparent(self, false)
			old.hull.queue_free()
			transport.disconnect_peer(previous)
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
		if multiplayer.get_peers().has(sender): transport.disconnect_peer(sender)
		return
	members[sender] = {"hull": hull, "account": account, "ship": hull.ship.state.instance_id, "epoch": int(result.epoch), "generation": int(result.generation), "sequence": -1, "input_at": Time.get_ticks_msec(), "rate_at": 0}
	physics_world.sync(live_owners())
	hull.ship.simulation_paused = false
	joining = false
	accounts[account] = sender
	pending.erase(sender)
	join_accepted.rpc_id(sender, hull.ship.state.instance_id, int(result.epoch), int(result.generation))

@rpc("authority", "call_remote", "reliable")
func join_accepted(ship: String, epoch: int, generation: int) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or ship.is_empty() or epoch <= 0 or generation <= 0: return
	binding = {"ship": ship, "epoch": epoch, "generation": generation}
	notice = "Joined"
	admitted.emit()

func send_helm(sequence: int, throttle: float, rudder: float, candidate: Dictionary = {}) -> void:
	var value: Dictionary = binding if candidate.is_empty() else candidate
	if hosting or transport == null or value.is_empty(): return
	helm_order.rpc_id(1, str(value.ship), int(value.epoch), int(value.generation), sequence, throttle, rudder)

@rpc("any_peer", "call_remote", "reliable", 1)
func helm_order(ship: String, epoch: int, generation: int, sequence: int, throttle: float, rudder: float) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not members.has(sender): rejected_commands += 1; return
	var record: Dictionary = members[sender]
	var now: int = Time.get_ticks_msec()
	if ship != record.ship or epoch != record.epoch or generation != record.generation or sequence <= record.sequence or sequence > 2147483647 or not is_finite(throttle) or not is_finite(rudder) or absf(throttle) > 1 or absf(rudder) > 1 or now - record.rate_at < 30:
		rejected_commands += 1
		return
	if not record.hull.helm(record.hull.authority.binding, throttle, rudder): rejected_commands += 1; return
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
	world_view.receive(tick, rows)

func disconnected(id: int) -> void:
	if not hosting:
		if id == 1: close_client()
		return
	pending.erase(id)
	if not members.has(id): return
	var record: Dictionary = members[id]
	members.erase(id)
	if accounts.get(record.account) == id: accounts.erase(record.account)
	record.hull.reparent(self, false)
	record.hull.departing = true
	record.hull.park()
	record.hull.authority.set_process(false)
	# Await any in-flight renewal before persisting/releasing the same binding.
	while is_instance_valid(record.hull) and record.hull.authority.busy:
		await get_tree().process_frame
	if not is_instance_valid(record.hull): return
	if record.hull.authority.active:
		var saved: Dictionary = await record.hull.checkpoint_current()
		if saved.get("ok", false): await record.hull.authority.request(record.hull.authority.owned("release"))
	record.hull.authority.quiesce()
	record.hull.queue_free()

func close_client() -> void:
	# Once attached, the multiplayer peer owns and closes the ENet host.
	if transport != null: transport.close()
	elif connection != null: connection.destroy()
	transport = null
	connection = null
	if world_view != null: world_view.clear()
	binding.clear()
	last_snapshot.clear()
	notice = "Disconnected"
