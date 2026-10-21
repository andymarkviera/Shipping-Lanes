extends Node
var peer: ENetMultiplayerPeer
var connection: ENetConnection
var role: String
var folder: String
var port: int
var mode: String
var sent: bool = false
var acknowledged: bool = false
var accepted: bool = false
var start_ms: int

func arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _ready() -> void:
	role = arg("--auth-role=")
	folder = arg("--auth-folder=")
	port = int(arg("--auth-port="))
	mode = arg("--auth-mode=")
	start_ms = Time.get_ticks_msec()
	var certificate: X509Certificate = X509Certificate.new()
	if certificate.load(folder + ("/wrong-ca.pem" if mode == "wrong_ca" else "/ca.pem")) != OK:
		get_tree().quit(1)
		return
	if role == "server":
		var key: CryptoKey = CryptoKey.new()
		var leaf: X509Certificate = X509Certificate.new()
		if key.load(folder + "/server-key.pem") != OK or leaf.load(folder + "/server.pem") != OK:
			get_tree().quit(1)
			return
		peer = ENetMultiplayerPeer.new()
		peer.set_bind_ip("127.0.0.1")
		if peer.create_server(port, 1, 3) != OK or peer.host.dtls_server_setup(TLSOptions.server(key, leaf)) != OK:
			get_tree().quit(1)
			return
		multiplayer.multiplayer_peer = peer
		var ready: FileAccess = FileAccess.open(folder + "/ready", FileAccess.WRITE)
		ready.store_string("ready")
		ready.close()
	else:
		connection = ENetConnection.new()
		if connection.create_host(1, 0) != OK:
			get_tree().quit(1)
			return
		if mode != "plaintext":
			var hostname: String = "incorrect.invalid" if mode == "wrong_name" else "localhost"
			if connection.dtls_client_setup(hostname, TLSOptions.client(certificate)) != OK:
				get_tree().quit(1)
				return
		connection.connect_to_host("127.0.0.1", port, 5, 12345)

func _process(_delta: float) -> void:
	if role == "client" and peer == null:
		var event: Array = connection.service(0)
		if event[0] == ENetConnection.EVENT_CONNECT:
			if mode != "valid":
				finish(false)
				return
			peer = ENetMultiplayerPeer.new()
			peer.create_mesh(12345)
			multiplayer.multiplayer_peer = peer
			if peer.add_mesh_peer(1, connection) != OK:
				get_tree().quit(1)
				return
			# Never send an application credential before verified DTLS completes.
			if mode == "valid":
				sent = true
				admit.rpc_id(1, "synthetic-credential")
		if Time.get_ticks_msec() - start_ms > 2500 and mode != "valid":
			finish(not sent and not acknowledged)
	if mode == "valid" and Time.get_ticks_msec() - start_ms > 7000: finish(false)
	if role == "server" and FileAccess.file_exists(folder + "/done"):
		finish(accepted if mode == "valid" else not accepted)

@rpc("any_peer", "call_remote", "reliable")
func admit(credential: String) -> void:
	if role != "server" or multiplayer.get_remote_sender_id() != 12345: return
	accepted = credential == "synthetic-credential"
	confirm.rpc_id(12345, accepted)

@rpc("authority", "call_remote", "reliable")
func confirm(ok: bool) -> void:
	if role != "client" or multiplayer.get_remote_sender_id() != 1: return
	acknowledged = ok
	finish(ok and sent)

func finish(ok: bool) -> void:
	set_process(false)
	var result: FileAccess = FileAccess.open(folder + "/" + role + ".json", FileAccess.WRITE)
	result.store_string(JSON.stringify({"ok":ok, "sent":sent, "accepted":accepted, "mode":mode}))
	result.close()
	if role == "client":
		var done: FileAccess = FileAccess.open(folder + "/done", FileAccess.WRITE)
		done.store_string("done")
		done.close()
	print("AUTH_TRANSPORT_", role.to_upper(), "_", "PASS" if ok else "FAIL", " ", mode)
	get_tree().quit(0 if ok else 1)
