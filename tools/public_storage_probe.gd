extends Node
## Disposable HTTP client. Receives only a loopback port and synthetic service token.
var request: HTTPRequest
var failures: int = 0

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	var port: int = int(OS.get_environment("SHIPPING_STORAGE_PORT"))
	var token: String = OS.get_environment("SHIPPING_STORAGE_TOKEN")
	if port < 1 or port > 65535 or token.is_empty():
		push_error("Missing isolated storage fixture configuration")
		get_tree().quit(1)
		return
	var body: Dictionary = {
		"version": 1, "realm": "public_fixture", "action_id": "godot_http",
		"operation": "service_fee", "quantity": 1,
		"expected_revision": int(OS.get_environment("SHIPPING_STORAGE_REVISION"))
	}
	var first: Dictionary = await send(port, token, body)
	verify(first.get("ok", false) and not first.get("duplicate", true), "first commit")
	var repeated: Dictionary = await send(port, token, body)
	verify(repeated.get("ok", false) and repeated.get("duplicate", false), "retry receipt")
	verify(first.get("revision") == repeated.get("revision"), "original revision")
	body.quantity = 2
	body.operation = "purchase_container"
	var conflict: Dictionary = await send(port, token, body)
	verify(conflict.get("code") == "id_conflict", "payload conflict")
	if failures == 0:
		print("PUBLIC_STORAGE_GODOT_PASS (4 checks)")
	get_tree().quit(0 if failures == 0 else 1)

func send(port: int, token: String, body: Dictionary) -> Dictionary:
	var error: Error = request.request("http://127.0.0.1:%d/v1/operation" % port,
		PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + token]),
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		return {}
	var response: Array = await request.request_completed
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		return {}
	var decoded: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	return decoded if decoded is Dictionary else {}

func verify(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Public storage HTTP: " + label)
