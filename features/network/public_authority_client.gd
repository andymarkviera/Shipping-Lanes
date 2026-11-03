extends Node
## One account's server-side lease. No database credentials or private-save imports.
## The caller owns transport authentication; this adapter is never an RPC endpoint.
signal fenced
var endpoint: String
var server_id: String
var credential: String
var trust: X509Certificate
var binding: Dictionary = {}
var canonical: Dictionary = {}
var active: bool = false
var busy: bool = false
var deadline_ms: int = 0
var renew_at_ms: int = 0
var phase: String = "VACANT"

func configure(config: Dictionary) -> bool:
	endpoint = config.get("endpoint", "")
	server_id = config.get("server", "")
	credential = config.get("credential", "")
	trust = X509Certificate.new()
	return endpoint.begins_with("https://") and not server_id.is_empty() and not credential.is_empty() and trust.load(config.get("ca", "")) == OK

func quiesce() -> void:
	active = false
	fenced.emit()

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if active and now >= deadline_ms: quiesce()
	if active and not busy and now >= renew_at_ms:
		request(owned("renew"))

func owned(operation: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = binding.duplicate()
	result.merge({"realm": "public", "op": operation})
	result.merge(extra)
	return result

func permits(candidate: Dictionary) -> bool:
	return active and Time.get_ticks_msec() < deadline_ms and candidate == binding

func request(data: Dictionary) -> Dictionary:
	if busy: return {"ok": false, "code": "LOCAL_BUSY"}
	var operation: String = data.get("op", "")
	if operation not in ["admit", "claim"]:
		if binding.is_empty() or Time.get_ticks_msec() >= deadline_ms: return {"ok": false, "code": "LOCAL_QUIESCED"}
		for field: String in ["account", "epoch", "generation"]:
			if data.get(field) != binding.get(field): return {"ok": false, "code": "LOCAL_QUIESCED"}
		if (operation in ["purchase", "ship_purchase", "ship_resale", "fleet_switch", "deliver", "refuel", "repair", "impact", "recover", "checkpoint", "begin"] or operation.begins_with("voyage_")) and not active:
			return {"ok": false, "code": "LOCAL_QUIESCED"}
	# A new admission must not leave the previous hull live while ownership changes.
	if operation in ["admit", "claim", "begin", "seal", "release"]: quiesce()
	busy = true
	var start: int = Time.get_ticks_msec()
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 6.0
	http.body_size_limit = 262144
	http.max_redirects = 0
	# Hull owners move between physics viewports and the session during departure.
	# HTTPRequest cancels on tree exit: keep in-flight I/O under the stable root,
	# not inside the reparented hull subtree. Lifecycle callers await busy before free.
	get_tree().root.add_child(http)
	http.set_tls_options(TLSOptions.client(trust))
	var error: Error = http.request(endpoint + "/v1/authority", PackedStringArray(["Content-Type: application/json", "X-Server-Id: " + server_id, "Authorization: Bearer " + credential]), HTTPClient.METHOD_POST, JSON.stringify(data))
	var result: Dictionary = {"ok": false, "code": "OUTCOME_UNKNOWN"}
	if error == OK:
		var response: Array = await http.request_completed
		result["transport_result"] = response[0]
		result["http_status"] = response[1]
		if response[0] == HTTPRequest.RESULT_SUCCESS:
			var parsed: Variant = JSON.parse_string(response[3].get_string_from_utf8())
			if parsed is Dictionary and parsed.get("ok") is bool and parsed.get("code") is String:
				result = parsed
			if response[1] != 200: quiesce()
	http.queue_free()
	busy = false
	if result.get("ok", false):
		if operation in ["admit", "claim"]:
			if not valid_grant(result):
				quiesce()
				return {"ok": false, "code": "INVALID_PROFILE"}
			binding = {"account": result.account, "epoch": int(result.epoch), "generation": int(result.generation)}
			canonical = result.duplicate(true)
			phase = "ACTIVE"
			deadline_ms = start + int(result.lease_ms) - 500
			renew_at_ms = start + 10000
			active = Time.get_ticks_msec() < deadline_ms
		elif operation == "renew":
			deadline_ms = start + int(result.get("lease_ms", 0)) - 500
			renew_at_ms = start + 10000
			# A late renewal cannot undo local fencing or transfer quiescence.
			if result.code != "ACTIVE" or Time.get_ticks_msec() >= deadline_ms: quiesce()
		elif operation == "begin": phase = "QUIESCING"
		elif operation == "seal": phase = "SEALED"
		elif operation == "release": phase = "VACANT"
		elif operation == "cancel":
			phase = "ACTIVE"
			# Explicit reacquisition is required to resume after any uncertainty.
	else:
		if result.code in ["OUTCOME_UNKNOWN", "STALE_AUTHORITY", "UNTRUSTED_SERVER", "BACKEND_UNAVAILABLE", "STALE_OUTCOME"]: quiesce()
	return result

func valid_grant(value: Dictionary) -> bool:
	for field: String in ["epoch", "generation", "lease_ms", "revision", "money"]:
		if not (value.get(field) is float or value.get(field) is int): return false
		if not is_finite(value[field]) or value[field] < 0 or value[field] > 9000000000000 or value[field] != floor(value[field]): return false
	if value.epoch < 1 or value.generation < 1 or value.lease_ms > 30000 or not value.get("account") is String: return false
	if not value.get("profile") is Dictionary: return false
	var profile: Dictionary = value.profile
	if profile.get("version") != 1 or not profile.get("ship") is Dictionary or not profile.get("cargo") is Array or not profile.get("jobs") is Array: return false
	var ship: Dictionary = profile.ship
	if ship.get("definition") not in ["ship_starter_container_01", "ship_coastal_container_01", "ship_swift_container_01"] or not ship.get("id") is String or ship.id.is_empty(): return false
	if not (ship.get("fuel_liters") is float or ship.get("fuel_liters") is int): return false
	if not is_finite(ship.fuel_liters) or ship.fuel_liters < 0 or ship.fuel_liters > 1000: return false
	if not ship.get("position") is Dictionary: return false
	for field: String in ["latitude", "longitude", "heading"]:
		var number: Variant = ship.position.get(field)
		if not (number is float or number is int) or not is_finite(number): return false
	return absf(ship.position.latitude) <= 90 and absf(ship.position.longitude) <= 180 and absf(ship.position.heading) <= 360
