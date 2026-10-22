class_name PrivateShipSession
extends LocalShipSession
## Authenticated loopback private world. No public-account credentials accepted.
const PRIVATE_PROTOCOL: int = 6
var store: PrivateIdentityStore
var invitation: Dictionary = {}
var retained_records: Dictionary = {}
var restored_states: Dictionary = {}
var connection: ENetConnection
var mesh_id: int
var pending_peers: Dictionary = {}
var checkpoint_elapsed: float = 0
var world_folder: String = ""

func _ready() -> void:
	super._ready()
	multiplayer.server_relay = false
	multiplayer.peer_connected.connect(func(peer_id: int):
		if hosting: pending_peers[peer_id] = Time.get_ticks_msec() + 8000)

func generation(id: String) -> int:
	return int(roster.get(id, {}).get("generation", -1))

func permitted(sender: int, id: String, binding: int = 0) -> bool:
	return roster.has(id) and roster[id].peer_id == sender and binding > 0 and roster[id].generation == binding

func credential_key() -> String:
	return "private_identity_" + str(invitation.get("world", "")) + "_" + str(invitation.get("fingerprint", ""))

func reconnect_token() -> String:
	return str(get_tree().get_meta(credential_key(), ""))

func retained(id: String) -> bool:
	return hosting and retained_records.has(id)

func host_session(port: int = DEFAULT_PORT) -> Error:
	stop()
	endpoint = port
	store = PrivateIdentityStore.new()
	var directory: String = world_folder if not world_folder.is_empty() else "user://private_net/" + ship_definition_id
	if not store.open_store(directory, ship_definition_id):
		stop("Private world could not be opened; files preserved")
		return ERR_CANT_OPEN
	invitation = {"version": PRIVATE_PROTOCOL, "world": store.world_id, "fingerprint": store.fingerprint,
		"certificate": store.certificate.save_to_string(), "port": port, "definition": ship_definition_id}
	transport = ENetMultiplayerPeer.new()
	transport.set_bind_ip("127.0.0.1")
	# Two extra transport slots allow authenticated replacement before eviction.
	if transport.create_server(port, 3, 3) != OK or transport.host.dtls_server_setup(TLSOptions.server(store.key, store.certificate)) != OK:
		stop("Cannot host secure local world")
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = transport
	hosting = true
	epoch = Crypto.new().generate_random_bytes(16).hex_encode()
	var member: Dictionary = store.admit("", true)
	if member.is_empty() or not install_member(1, member):
		stop("Host identity could not be restored")
		return ERR_CANT_OPEN
	notice = "Private world resumed · copy its invitation to another local window"
	changed.emit()
	return OK

func trust_invitation(text: String) -> bool:
	if text.length() > 8192: return false
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or data.size() != 6 or data.get("version") != PRIVATE_PROTOCOL: return false
	for field: String in ["world", "fingerprint", "certificate", "definition"]:
		if not data.get(field) is String: return false
	if data.world.length() != 32 or not data.world.is_valid_hex_number() or data.fingerprint != data.certificate.sha256_text(): return false
	if not (data.get("port") is float or data.get("port") is int) or data.port < 1024 or data.port > 65535 or floor(data.port) != data.port: return false
	if data.definition not in ["ship_starter_container_01", "ship_heavy_lifter_01"]: return false
	var cert: X509Certificate = X509Certificate.new()
	if cert.load_from_string(data.certificate) != OK: return false
	invitation = data
	return true

func join_session(_port: int = DEFAULT_PORT) -> Error:
	stop()
	if invitation.is_empty():
		notice = "Paste the host's invitation first"
		changed.emit()
		return ERR_UNAUTHORIZED
	endpoint = int(invitation.port)
	var cert: X509Certificate = X509Certificate.new()
	if cert.load_from_string(invitation.certificate) != OK: return ERR_INVALID_DATA
	connection = ENetConnection.new()
	if connection.create_host(1, 0) != OK or connection.dtls_client_setup("localhost", TLSOptions.client(cert)) != OK:
		stop("Secure connection could not start")
		return ERR_CANT_CONNECT
	mesh_id = 2 + int(Crypto.new().generate_random_bytes(4).decode_u32(0) % 2147483645)
	connection.connect_to_host("127.0.0.1", endpoint, 5, mesh_id)
	connecting = true
	deadline_ms = Time.get_ticks_msec() + 8000
	notice = "Verifying the invited host..."
	changed.emit()
	return OK

func _process(delta: float) -> void:
	super._process(delta)
	if connecting and connection != null and transport == null:
		var event: Array = connection.service(0)
		if event[0] == ENetConnection.EVENT_CONNECT:
			transport = ENetMultiplayerPeer.new()
			if transport.create_mesh(mesh_id) != OK:
				stop("Connection setup failed")
				return
			multiplayer.multiplayer_peer = transport
			if transport.add_mesh_peer(1, connection) != OK:
				stop("Connection setup failed")
				return
			_connected()
	if hosting:
		for peer_id: int in pending_peers.keys():
			if Time.get_ticks_msec() >= pending_peers[peer_id]:
				pending_peers.erase(peer_id)
				transport.disconnect_peer(peer_id)
		checkpoint_elapsed += delta
		if checkpoint_elapsed >= 10:
			checkpoint_elapsed = 0
			if not checkpoint(): stop("Private save failed; control stopped")

func _connected() -> void:
	if connecting and transport != null:
		private_join.rpc_id(1, PRIVATE_PROTOCOL, str(invitation.world), reconnect_token())

@rpc("any_peer", "call_remote", "reliable")
func hello(_version: int, _token: String = "") -> void:
	pass # The legacy unauthenticated fixture admission is disabled here.

@rpc("any_peer", "call_remote", "reliable")
func private_join(version: int, world: String, token: String) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1 or not multiplayer.get_peers().has(sender): return
	if version != PRIVATE_PROTOCOL or world != store.world_id:
		transport.disconnect_peer(sender)
		return
	for record: Dictionary in roster.values():
		if record.peer_id == sender:
			_send_snapshot(sender)
			return
	# A new guest cannot displace an active guest. Valid reconnect can replace itself.
	if not checkpoint():
		stop("Private save failed; control stopped")
		return
	if roster.size() >= 2 and not roster.has(store.member_ship(token)):
		transport.disconnect_peer(sender)
		return
	var member: Dictionary = store.admit(token)
	if member.is_empty():
		transport.disconnect_peer(sender)
		return
	if roster.size() >= 2 and not roster.has(member.ship):
		transport.disconnect_peer(sender)
		return
	if roster.has(member.ship):
		var previous: int = roster[member.ship].peer_id
		roster.erase(member.ship)
		revision += 1
		changed.emit() # Clear orders/receipts and park neutral before rebinding.
		transport.disconnect_peer(previous)
	if not install_member(sender, member):
		stop("Private identity could not be restored")
		return
	pending_peers.erase(sender)
	if not member.issued.is_empty(): private_credential.rpc_id(sender, store.world_id, store.fingerprint, member.issued)
	_publish()

func install_member(peer_id: int, member: Dictionary) -> bool:
	if not member.get("player") is String or member.player.length() != 32 or not member.player.is_valid_hex_number(): return false
	if not member.get("ship") is String or member.ship.length() != 37 or not member.ship.begins_with("ship_") or not member.ship.trim_prefix("ship_").is_valid_hex_number(): return false
	if not member.get("generation") is int or member.generation <= 0: return false
	var id: String = member.ship
	if not economies.has(id):
		var ledger_path: String = store.folder + "/" + member.player + ".db"
		if not member.new_member and not FileAccess.file_exists(ledger_path): return false
		var ledger: DurableEconomy = DurableEconomy.new()
		if not ledger.open_store(ledger_path, "private_" + store.world_id):
			ledger.close_store()
			return false
		economies[id] = ledger
	if member.state is String:
		if member.state.length() > 8192: return false
		var state: Variant = bytes_to_var(Marshalls.base64_to_raw(member.state))
		if not state is Dictionary or not get_parent().valid_private_state(state): return false
		restored_states[id] = state
	elif member.state != null: return false
	roster[id] = {"entity_id": id, "player_id": member.player, "generation": member.generation,
		"peer_id": peer_id, "definition_id": ship_definition_id, "authority": 1, "slot": 0 if peer_id == 1 else 1}
	retained_records[id] = roster[id].duplicate(true)
	revision += 1
	changed.emit()
	return true

func checkpoint() -> bool:
	if not hosting or store == null: return true
	for id: String in retained_records:
		var record: Dictionary = retained_records[id]
		var state: Dictionary = get_parent().capture_private_state(id)
		if not state.is_empty() and not store.save_state(record.player_id, record.generation, state): return false
	return true

func _left(peer_id: int) -> void:
	pending_peers.erase(peer_id)
	if not hosting:
		if peer_id == 1: stop("Host disconnected")
		return
	if not checkpoint():
		stop("Private save failed; control stopped")
		return
	super._left(peer_id)

func stop(message: String = "Disconnected") -> void:
	var saved: bool = checkpoint()
	super.stop(message if saved else "Private save failed; files preserved")
	if store != null: store.close_store()
	store = null
	connection = null
	retained_records.clear()
	restored_states.clear()
	pending_peers.clear()
	checkpoint_elapsed = 0

@rpc("authority", "call_remote", "reliable")
func private_credential(world: String, identity: String, token: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or world != invitation.get("world") or identity != invitation.get("fingerprint") or token.length() != 64 or not token.is_valid_hex_number(): return
	get_tree().set_meta(credential_key(), token)

func _send_snapshot(peer_id: int) -> void:
	private_roster.rpc_id(peer_id, epoch, revision, roster.values())

@rpc("authority", "call_remote", "reliable")
func private_roster(session_epoch: String, sequence: int, records: Array) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or sequence <= revision or session_epoch.is_empty() or (not epoch.is_empty() and session_epoch != epoch): return
	if records.size() != 2: return
	var next: Dictionary = {}
	var peers: Array[int] = []
	var players: Array[String] = []
	for entry: Variant in records:
		if not entry is Dictionary or not entry.get("entity_id") is String or not entry.get("player_id") is String or not entry.get("peer_id") is int or not entry.get("generation") is int: return
		if entry.entity_id.length() != 37 or not entry.entity_id.begins_with("ship_") or not entry.entity_id.trim_prefix("ship_").is_valid_hex_number(): return
		if entry.player_id.length() != 32 or not entry.player_id.is_valid_hex_number() or entry.generation <= 0: return
		if next.has(entry.entity_id) or peers.has(entry.peer_id) or players.has(entry.player_id) or entry.peer_id <= 0 or entry.get("authority") != 1: return
		if entry.get("definition_id") != invitation.definition or entry.get("slot") != (0 if entry.peer_id == 1 else 1): return
		next[entry.entity_id] = entry.duplicate(true)
		peers.append(entry.peer_id)
		players.append(entry.player_id)
	if not peers.has(1) or not peers.has(multiplayer.get_unique_id()): return
	roster = next
	epoch = session_epoch
	revision = sequence
	connecting = false
	notice = "Connected securely · private ship ownership restored"
	changed.emit()
