extends "res://features/network/public_client.gd"
const Login = preload("res://features/network/public_browser_login.gd")
var login: Node
var configuration: Dictionary = {}
var selected_server: Dictionary = {}
var access_token: String = ""
var ticket_request: HTTPRequest
var entry_layer: CanvasLayer
var picker: OptionButton
var join_button: Button
var status_label: Label
var busy: bool = false
var joined: bool = false
var notice: String = "Online services are not configured for this build. Local tests are still available."
var connection_deadline: int = 0
var attempt: int = 0

func _ready() -> void:
	super._ready()
	login = Login.new()
	add_child(login)
	login.failed.connect(show_failure)
	login.token_ready.connect(on_token)
	ticket_required.connect(on_challenge)
	session.admitted.connect(func():
		busy = false
		joined = true
		access_token = ""
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null: focused.release_focus()
		entry_layer.hide())
	entry_layer = CanvasLayer.new()
	entry_layer.layer = 10
	add_child(entry_layer)
	var background: ColorRect = ColorRect.new()
	background.color = Color("263b48")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entry_layer.add_child(background)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.position = Vector2(64, 110)
	stack.custom_minimum_size.x = 640
	stack.add_theme_constant_override("separation", 16)
	background.add_child(stack)
	var title: Label = Label.new()
	title.text = "CONTAINER SHIP SIM - SERVERS"
	title.add_theme_font_size_override("font_size", 28)
	stack.add_child(title)
	picker = OptionButton.new()
	picker.custom_minimum_size.y = 46
	stack.add_child(picker)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(640, 100)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(status_label)
	join_button = Button.new()
	join_button.text = "SIGN IN & JOIN"
	join_button.pressed.connect(func(): start_join(picker.selected))
	stack.add_child(join_button)
	var cancel_button: Button = Button.new()
	cancel_button.text = "CANCEL SIGN-IN / CONNECTION"
	cancel_button.pressed.connect(func(): cancel_join(); notice = "Cancelled. Choose a server to try again.")
	stack.add_child(cancel_button)
	var back: Button = Button.new()
	back.text = "BACK TO MAIN MENU"
	back.pressed.connect(func(): cancel_join(); get_tree().change_scene_to_file("res://features/main/main.tscn"))
	stack.add_child(back)
	back.grab_focus()
	if FileAccess.file_exists("user://public_services.json"):
		var file: FileAccess = FileAccess.open("user://public_services.json", FileAccess.READ)
		if file != null and file.get_length() <= 65536:
			var data: Variant = JSON.parse_string(file.get_as_text())
			if data is Dictionary: configure_services(data)

func configure_services(data: Dictionary) -> bool:
	cancel_join()
	configuration.clear()
	picker.clear()
	if not data.get("login") is Dictionary or not data.get("servers") is Array or data.servers.is_empty() or data.servers.size() > 32:
		notice = "Online configuration is incomplete. Local tests are still available."
		return false
	if not str(data.get("authority_endpoint", "")).begins_with("https://"):
		notice = "Online service address is invalid."
		return false
	notice = "An approved server entry is invalid. Check the build configuration."
	var ids: Dictionary = {}
	for server: Variant in data.servers:
		if not server is Dictionary: return false
		for key: String in ["name", "server", "host", "hostname", "certificate", "fingerprint"]:
			if not server.get(key) is String or server[key].is_empty(): return false
		if ids.has(server.server) or not (server.get("port") is int or server.get("port") is float) or server.port < 1024 or server.port > 65535 or server.port != floor(server.port): return false
		if server.fingerprint.length() != 64 or not server.fingerprint.is_valid_hex_number(): return false
		ids[server.server] = true
	configuration = data.duplicate(true)
	for server: Dictionary in configuration.servers: picker.add_item(server.name)
	notice = "Choose a server. Sign-in opens in your browser; the game never asks for your password. Server availability is checked when joining."
	return true

func start_join(index: int, launch_browser: bool = true) -> void:
	if busy or configuration.is_empty() or index < 0 or index >= configuration.servers.size(): return
	cancel_join()
	selected_server = configuration.servers[index].duplicate(true)
	busy = true
	notice = "Finish signing in in your browser, then return here."
	login.begin(configuration.login, launch_browser)

func on_token(token: String) -> void:
	if not busy: return
	access_token = token
	notice = "Verifying the selected server..."
	connection_deadline = Time.get_ticks_msec() + 25000
	if connect_server(selected_server) != OK: show_failure("The server certificate or connection could not be verified.")

func on_challenge(nonce: String) -> void:
	if not busy or access_token.is_empty(): return
	notice = "Checking your online account..."
	ticket_request = HTTPRequest.new()
	add_child(ticket_request)
	ticket_request.timeout = 10
	ticket_request.max_redirects = 0
	ticket_request.body_size_limit = 16384
	if not str(configuration.get("authority_ca", "")).is_empty():
		var ca: X509Certificate = X509Certificate.new()
		if ca.load(configuration.authority_ca) != OK: show_failure("Online service certificate is unavailable."); return
		ticket_request.set_tls_options(TLSOptions.client(ca))
	var current: int = attempt
	ticket_request.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray):
		if current == attempt: ticket_response(result, status, body))
	var headers: PackedStringArray = ["Content-Type: application/json", "Authorization: Bearer " + access_token]
	access_token = ""
	if ticket_request.request(configuration.authority_endpoint.trim_suffix("/") + "/v1/ticket", headers, HTTPClient.METHOD_POST, JSON.stringify({"server": selected_server.server, "nonce": nonce})) != OK: show_failure("Online service could not be reached.")

func ticket_response(result: int, status: int, body: PackedByteArray) -> void:
	if not busy: return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or not data is Dictionary: show_failure("Online service could not be reached. Please retry."); return
	if status != 200 or data.get("ok") != true:
		show_failure("Your account is signed in but has not been enrolled for this build." if data.get("code") == "ACCOUNT_NOT_ENROLLED" else "Your account could not join this server. Please retry.")
		return
	if data.get("protocol") != 7 or not data.get("ticket") is String or data.ticket.length() < 20 or data.ticket.length() > 128: show_failure("Online service returned an invalid connection ticket."); return
	submit_ticket(data.ticket)
	ticket_request.queue_free()
	ticket_request = null
	notice = "Joining your boat..."

func _process(_delta: float) -> void:
	if status_label == null: return
	if busy and login.phase == "exchange": notice = "Completing secure sign-in..."
	if busy and connection_deadline > 0 and (Time.get_ticks_msec() >= connection_deadline or session.notice == "Disconnected"):
		show_failure("Could not join. The server may be unavailable, your saved position occupied, or your account active elsewhere. Please retry.")
	if joined and session.binding.is_empty():
		joined = false
		entry_layer.show()
		notice = "Disconnected. Sign in again to reconnect."
	status_label.text = notice
	join_button.disabled = busy or configuration.is_empty()
	picker.disabled = busy

func cancel_join() -> void:
	attempt += 1
	busy = false
	joined = false
	connection_deadline = 0
	access_token = ""
	if login != null: login.cancel()
	if is_instance_valid(ticket_request): ticket_request.cancel_request(); ticket_request.queue_free()
	ticket_request = null
	if session != null: session.close_client()

func show_failure(message: String) -> void:
	cancel_join()
	notice = message
	entry_layer.show()

func _exit_tree() -> void:
	cancel_join()
	super._exit_tree()

func _unhandled_input(event: InputEvent) -> void:
	if entry_layer.visible and event.is_action_pressed("pause") and not event.is_echo():
		cancel_join()
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://features/main/main.tscn")
