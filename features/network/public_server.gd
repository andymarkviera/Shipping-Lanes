extends Node
const Session = preload("res://features/network/public_peer_session.gd")
var session: Node

func _ready() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--public-server-config="): path = arg.trim_prefix("--public-server-config=")
	if path.is_empty() or not FileAccess.file_exists(path): fail("Server configuration is missing"); return
	var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not settings is Dictionary: fail("Server configuration is invalid"); return
	for field: String in ["certificate", "key", "fingerprint", "endpoint", "server", "credential", "ca"]:
		if not settings.get(field) is String or settings[field].is_empty(): fail("Server configuration is incomplete"); return
	if not (settings.get("port") is int or settings.get("port") is float) or settings.port < 1024 or settings.port > 65535 or floor(settings.port) != settings.port:
		fail("Server port must be between 1024 and 65535"); return
	var client: Node = preload("res://features/network/public_authority_client.gd").new()
	var valid: bool = client.configure(settings)
	client.free()
	if not valid: fail("Authority HTTPS configuration is invalid"); return
	session = Session.new()
	session.name = "Session"
	add_child(session)
	if session.start_server(settings) != OK: fail("Server certificate or listening port could not be initialized"); return
	print("PUBLIC_SERVER_LISTENING port=", int(settings.port), " capacity=8")

func fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
