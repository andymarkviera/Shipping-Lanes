extends Node
## OAuth authorization code + PKCE. Identity is validated by the ticket service.
signal token_ready(access_token: String)
signal failed(message: String)
var settings: Dictionary = {}
var listener: TCPServer
var peers: Array = []
var request: HTTPRequest
var state: String = ""
var verifier: String = ""
var redirect: String = ""
var authorization_url: String = ""
var deadline: int = 0
var phase: String = "idle"
var attempt: int = 0
var response_result: int = -1
var response_status: int = -1

static func form(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in values: parts.append(key.uri_encode() + "=" + str(values[key]).uri_encode())
	return "&".join(parts)

func begin(config: Dictionary, launch_browser: bool = true) -> bool:
	cancel()
	settings = config.duplicate(true)
	var issuer: String = str(settings.get("issuer", ""))
	if not issuer.begins_with("https://") or "?" in issuer or "#" in issuer: return fail("Sign-in service is not configured.")
	for key: String in ["authorization_endpoint", "token_endpoint"]:
		if not str(settings.get(key, "")).begins_with(issuer + "/") or "?" in str(settings[key]) or "#" in str(settings[key]): return fail("Sign-in endpoints are invalid.")
	if str(settings.get("client_id", "")).is_empty(): return fail("Sign-in client is not configured.")
	var port: int = int(settings.get("callback_port", 0))
	if port < 1024 or port > 65535: return fail("Sign-in callback port is invalid.")
	listener = TCPServer.new()
	if listener.listen(port, "127.0.0.1") != OK: return fail("Sign-in return port is busy. Close the other sign-in attempt and retry.")
	state = Crypto.new().generate_random_bytes(32).hex_encode()
	verifier = Crypto.new().generate_random_bytes(32).hex_encode()
	var challenge: String = Marshalls.raw_to_base64(verifier.sha256_buffer()).replace("+", "-").replace("/", "_").replace("=", "")
	redirect = "http://127.0.0.1:%d/callback" % port
	authorization_url = settings.authorization_endpoint + "?" + form({"client_id": settings.client_id, "response_type": "code", "redirect_uri": redirect, "scope": "openid", "state": state, "nonce": Crypto.new().generate_random_bytes(32).hex_encode(), "code_challenge": challenge, "code_challenge_method": "S256"})
	deadline = Time.get_ticks_msec() + 180000
	phase = "browser"
	if launch_browser and OS.shell_open(authorization_url) != OK: return fail("Could not open your browser. Please retry.")
	return true

func _process(_delta: float) -> void:
	if phase != "browser": return
	if Time.get_ticks_msec() >= deadline: fail("Sign-in timed out. Please retry."); return
	if listener.is_connection_available():
		var peer: StreamPeerTCP = listener.take_connection()
		if peers.size() >= 8: peer.disconnect_from_host()
		else: peers.append({"peer": peer, "buffer": "", "deadline": Time.get_ticks_msec() + 5000})
	for record: Dictionary in peers.duplicate():
		var peer: StreamPeerTCP = record.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() > record.deadline:
			peer.disconnect_from_host(); peers.erase(record); continue
		var available: int = peer.get_available_bytes()
		if available > 0:
			var data: Array = peer.get_data(mini(available, 8193))
			if data[0] != OK: peer.disconnect_from_host(); peers.erase(record); continue
			record.buffer += data[1].get_string_from_utf8()
		if record.buffer.length() > 8192: peer.disconnect_from_host(); peers.erase(record); continue
		if not "\r\n\r\n" in record.buffer: continue
		var code: String = callback_code(record.buffer)
		var message: String = "Return to Container Ship Sim." if not code.is_empty() else "Sign-in callback rejected. Return to the game and retry."
		peer.put_data(("HTTP/1.1 " + ("200 OK" if not code.is_empty() else "400 Bad Request") + "\r\nContent-Type: text/plain\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: %d\r\n\r\n" % message.length() + message).to_utf8_buffer())
		peer.disconnect_from_host()
		peers.erase(record)
		if not code.is_empty(): exchange(code); return

func callback_code(header: String) -> String:
	if phase != "browser" or Time.get_ticks_msec() >= deadline: return ""
	var first: PackedStringArray = header.get_slice("\r\n", 0).split(" ")
	if first.size() != 3 or first[0] != "GET" or not first[1].begins_with("/callback?") or first[2] != "HTTP/1.1": return ""
	var values: Dictionary = {}
	for item: String in first[1].trim_prefix("/callback?").split("&"):
		var pair: PackedStringArray = item.split("=", true, 1)
		if pair.size() != 2: return ""
		var key: String = pair[0].uri_decode()
		if values.has(key): return ""
		values[key] = pair[1].uri_decode()
	if values.get("state") != state or values.has("error"): return ""
	var code: String = str(values.get("code", ""))
	return code if code.length() > 0 and code.length() <= 4096 else ""

func exchange(code: String) -> void:
	phase = "exchange"
	stop_listener()
	authorization_url = ""
	request = HTTPRequest.new()
	add_child(request)
	request.timeout = 12
	request.max_redirects = 0
	request.body_size_limit = 65536
	if not str(settings.get("ca", "")).is_empty():
		var ca: X509Certificate = X509Certificate.new()
		if ca.load(settings.ca) != OK: fail("Sign-in certificate is unavailable."); return
		request.set_tls_options(TLSOptions.client(ca))
	var current: int = attempt
	request.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray):
		if current == attempt: token_response(result, status, body))
	var body: String = form({"grant_type": "authorization_code", "client_id": settings.client_id, "redirect_uri": redirect, "code": code, "code_verifier": verifier})
	verifier = ""
	state = ""
	if request.request(settings.token_endpoint, ["Content-Type: application/x-www-form-urlencoded"], HTTPClient.METHOD_POST, body) != OK: fail("Sign-in service could not be reached.")

func token_response(result: int, status: int, body: PackedByteArray) -> void:
	response_result = result
	response_status = status
	if result != HTTPRequest.RESULT_SUCCESS or status != 200: fail("Sign-in could not be completed. Please retry."); return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("access_token") is String or not parsed.get("token_type") is String or parsed.token_type.to_lower() != "bearer": fail("Sign-in returned an invalid response."); return
	var access: String = parsed.access_token
	if access.is_empty() or access.length() > 32768 or "\r" in access or "\n" in access: fail("Sign-in returned an invalid token."); return
	# Never read identity claims from ID/access tokens here. The HTTPS service validates them.
	cancel()
	token_ready.emit(access)

func stop_listener() -> void:
	if listener != null: listener.stop()
	listener = null
	for record: Dictionary in peers: record.peer.disconnect_from_host()
	peers.clear()

func cancel() -> void:
	attempt += 1
	stop_listener()
	if is_instance_valid(request): request.cancel_request(); request.queue_free()
	request = null
	state = ""
	verifier = ""
	authorization_url = ""
	phase = "idle"

func fail(message: String) -> bool:
	cancel()
	failed.emit(message)
	return false

func _exit_tree() -> void:
	cancel()
