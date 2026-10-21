class_name LocalShipSession
extends Node
## Development-only loopback transport. Session-only reconnect; no public account authentication.
signal changed
const PROTOCOL: int = 5
var ship_definition_id: String = "ship_starter_container_01"
const DEFAULT_PORT: int = 28429
var roster: Dictionary = {}
var revision: int = 0
var epoch: String = ""
var notice: String = "Disconnected"
var hosting: bool = false
var connecting: bool = false
var transport: ENetMultiplayerPeer
var serial: int = 0
var deadline_ms: int = 0
var endpoint: int = DEFAULT_PORT
var guest_record: Dictionary = {}
var guest_token_hash: String = ""
var economies: Dictionary = {}

func reconnect_token() -> String:
	return str(get_tree().get_meta("local_reconnect_" + str(endpoint), ""))

func retained(id: String) -> bool:
	return hosting and guest_record.get("entity_id", "") == id


func _ready() -> void:
	set_multiplayer_authority(1)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): stop("Connection failed"))
	multiplayer.server_disconnected.connect(func(): stop("Host disconnected"))
	multiplayer.peer_disconnected.connect(_left)

func host_session(port: int = DEFAULT_PORT) -> Error:
	stop()
	endpoint = port
	transport = ENetMultiplayerPeer.new()
	transport.set_bind_ip("127.0.0.1")
	var error: Error = transport.create_server(port, 1, 3)
	if error != OK:
		stop("Cannot host: local port unavailable")
		return error
	multiplayer.multiplayer_peer = transport
	hosting = true
	epoch = Crypto.new().generate_random_bytes(8).hex_encode()
	if not _add_member(1):
		stop("Cannot open host recovery store")
		return ERR_CANT_CREATE
	notice = "Hosting on this computer · port %d" % port
	changed.emit()
	return OK

func join_session(port: int = DEFAULT_PORT) -> Error:
	stop()
	endpoint = port
	transport = ENetMultiplayerPeer.new()
	var error: Error = transport.create_client("127.0.0.1", port, 3)
	if error != OK:
		stop("Could not start local connection")
		return error
	multiplayer.multiplayer_peer = transport
	connecting = true
	deadline_ms = Time.get_ticks_msec() + 8000
	notice = "Connecting to this computer..."
	changed.emit()
	return OK

func stop(message: String = "Disconnected") -> void:
	for ledger: DurableEconomy in economies.values(): ledger.close_store()
	economies.clear()
	guest_record = {}
	guest_token_hash = ""
	hosting = false
	connecting = false
	if transport != null: transport.close()
	transport = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster.clear()
	revision = 0
	epoch = ""
	serial = 0
	notice = message
	changed.emit()

func _exit_tree() -> void:
	set_block_signals(true)
	stop()

func _process(_delta: float) -> void:
	if connecting and Time.get_ticks_msec() >= deadline_ms:
		stop("Local connection timed out")

func _connected() -> void:
	hello.rpc_id(1, PROTOCOL, reconnect_token())

@rpc("any_peer", "call_remote", "reliable")
func hello(version: int, token: String = "") -> void:
	if not hosting or not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1 or not multiplayer.get_peers().has(sender): return
	if version != PROTOCOL:
		transport.disconnect_peer(sender)
		return
	for record: Dictionary in roster.values():
		if record.peer_id == sender:
			_send_snapshot(sender)
			return
	if roster.size() >= 2:
		transport.disconnect_peer(sender)
		return
	if not guest_record.is_empty():
		if token.length() != 64 or token.sha256_text() != guest_token_hash:
			transport.disconnect_peer(sender)
			return
		var restored: Dictionary = guest_record.duplicate(true)
		restored.peer_id = sender
		roster[restored.entity_id] = restored
		revision += 1
		changed.emit()
	else:
		# Unknown credentials cannot silently create replacement progress.
		if not token.is_empty() or not _add_member(sender):
			transport.disconnect_peer(sender)
			return
		var issued: String = Crypto.new().generate_random_bytes(32).hex_encode()
		guest_token_hash = issued.sha256_text()
		grant_reconnect.rpc_id(sender, issued)
	_publish()

func _add_member(peer_id: int) -> bool:
	serial += 1
	var entity_id: String = "ship_" + epoch + "_" + str(serial)
	var folder: String = "user://n/" + epoch
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return false
	var ledger: DurableEconomy = DurableEconomy.new()
	if not ledger.open_store(folder + ("/h.db" if peer_id == 1 else "/g.db"), "private_" + epoch):
		ledger.close_store()
		return false
	economies[entity_id] = ledger
	roster[entity_id] = {"entity_id": entity_id, "peer_id": peer_id,
		"definition_id": ship_definition_id, "authority": 1,
		"slot": 0 if peer_id == 1 else 1}
	if peer_id != 1: guest_record = roster[entity_id].duplicate(true)
	revision += 1
	changed.emit()
	return true

@rpc("authority", "call_remote", "reliable")
func grant_reconnect(token: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or token.length() != 64 or not token.is_valid_hex_number(): return
	get_tree().set_meta("local_reconnect_" + str(endpoint), token)

func _left(peer_id: int) -> void:
	if not hosting: return
	for entity_id: String in roster.keys():
		if roster[entity_id].peer_id == peer_id:
			roster.erase(entity_id)
			revision += 1
			changed.emit()
			_publish()
			return

func _publish() -> void:
	for record: Dictionary in roster.values():
		if record.peer_id != 1: _send_snapshot(record.peer_id)

func _send_snapshot(peer_id: int) -> void:
	receive_roster.rpc_id(peer_id, epoch, revision, roster.values())

@rpc("authority", "call_remote", "reliable")
func receive_roster(session_epoch: String, sequence: int, records: Array) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1: return
	if sequence <= revision or session_epoch.is_empty() or (not epoch.is_empty() and session_epoch != epoch): return
	if records.size() < 1 or records.size() > 2: return
	var next: Dictionary = {}
	var peers: Array[int] = []
	for entry: Variant in records:
		if not entry is Dictionary: return
		if not entry.get("entity_id") is String or not entry.get("peer_id") is int: return
		var id: String = entry.entity_id
		var peer: int = entry.peer_id
		if not id.begins_with("ship_" + session_epoch + "_") or next.has(id) or peers.has(peer) or peer <= 0: return
		if entry.get("authority") != 1 or entry.get("definition_id") not in ["ship_starter_container_01", "ship_heavy_lifter_01"]: return
		if entry.get("slot") != (0 if peer == 1 else 1): return
		next[id] = entry.duplicate(true)
		peers.append(peer)
	if not peers.has(1) or not peers.has(multiplayer.get_unique_id()): return
	roster = next
	epoch = session_epoch
	revision = sequence
	connecting = false
	notice = "Connected locally · host controls ship lifecycle"
	changed.emit()
