extends Control
## Play resolves the public feed afresh on every attempt. No address is saved.
const FEED: String = "https://raw.githubusercontent.com/andymarkviera/Shipping-Lanes-Releases/main/server.json"
const SCENE: String = "res://features/network/play_connection.tscn"
const TARGET: StringName = &"play_server"
const VERSION: String = "4.0.4"
const CaptainName = preload("res://features/network/captain_name.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
var lookup_on_ready: bool = true
var request: HTTPRequest
var heading: Label
var details: Label
var resolve_id: int = IP.RESOLVER_INVALID_ID
var resolve_deadline: int = 0
var destination: Dictionary = {}
var retry: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = PLAYFUL.make()
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.025, 0.065, 0.1, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 420
	PLAYFUL.dress(panel)
	center.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	panel.add_child(stack)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	stack.add_child(heading)
	details = Label.new()
	details.custom_minimum_size = Vector2(380, 80)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(details)
	retry = Button.new()
	retry.text = "Retry"
	retry.pressed.connect(func() -> void: get_tree().change_scene_to_file(SCENE))
	stack.add_child(retry)
	var back: Button = Button.new()
	back.text = "Back to menu"
	back.pressed.connect(back_to_menu)
	stack.add_child(back)
	back.grab_focus()
	if not lookup_on_ready: return
	# Patch 3.0.1 item 1: the first Play asks for a captain name, then sails.
	if CaptainName.load_saved().is_empty():
		heading.text = "Welcome aboard"
		details.text = "Choose the name other captains will see over your boat."
		retry.hide()
		add_child(CaptainName.make_dialog("", func(_name: String) -> void: lookup()))
	else: lookup()

func lookup(endpoint: String = FEED) -> void:
	get_tree().remove_meta(TARGET)
	heading.text = "Connecting…"
	details.text = "Finding the Shipping Lanes server."
	retry.hide()
	request = HTTPRequest.new()
	request.timeout = 10.0
	request.body_size_limit = 4096
	request.max_redirects = 2
	request.use_threads = true
	add_child(request)
	request.request_completed.connect(completed)
	if request.request(endpoint, PackedStringArray(["Cache-Control: no-cache"])) != OK: show_error("offline")

## Minimal host/port feed; optional status/version let an operator announce upkeep.
static func parse_feed(body: PackedByteArray) -> Dictionary:
	if body.size() > 4096: return {"error": "offline"}
	var json: JSON = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary: return {"error": "offline"}
	var data: Dictionary = json.data
	if data.get("status", "online") == "updating": return {"error": "updating"}
	if data.get("status", "online") != "online": return {"error": "offline"}
	if data.has("version") and (not data.version is String or data.version.trim_prefix("v") != VERSION): return {"error": "mismatch"}
	if not data.get("host") is String or not (data.get("port") is float or data.get("port") is int): return {"error": "offline"}
	var host: String = data.host
	if host.is_empty() or host.length() > 253 or host != host.strip_edges(): return {"error": "offline"}
	for character: String in host:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:": return {"error": "offline"}
	if data.port != int(data.port) or data.port < 1024 or data.port > 65535: return {"error": "offline"}
	return {"host": host, "port": int(data.port)}

func completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		show_error("updating" if code == 503 else "offline")
		return
	var target: Dictionary = parse_feed(body)
	if target.has("error"):
		show_error(target.error)
		return
	destination = target
	if target.host.is_valid_ip_address():
		connect_to_server()
		return
	details.text = "Resolving the server address."
	resolve_id = IP.resolve_hostname_queue_item(target.host, IP.TYPE_IPV4)
	resolve_deadline = Time.get_ticks_msec() + 5000
	if resolve_id == IP.RESOLVER_INVALID_ID: show_error("offline")

func _process(_delta: float) -> void:
	if resolve_id == IP.RESOLVER_INVALID_ID: return
	var state: int = IP.get_resolve_item_status(resolve_id)
	if state == IP.RESOLVER_STATUS_DONE:
		destination.host = IP.get_resolve_item_address(resolve_id)
		clear_resolver()
		connect_to_server()
	elif state == IP.RESOLVER_STATUS_ERROR or Time.get_ticks_msec() > resolve_deadline:
		clear_resolver()
		show_error("offline")

func clear_resolver() -> void:
	if resolve_id != IP.RESOLVER_INVALID_ID: IP.erase_resolve_item(resolve_id)
	resolve_id = IP.RESOLVER_INVALID_ID

func connect_to_server() -> void:
	get_tree().set_meta(TARGET, destination)
	get_tree().change_scene_to_file("res://features/network/dedicated_runtime.tscn")

func show_error(reason: String) -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	heading.text = {"updating": "Server is updating", "mismatch": "Update required"}.get(reason, "Server offline")
	details.text = {"updating": "The server is being updated. Try again shortly.", "mismatch": "Client and server versions must match. Update Shipping Lanes in the launcher, then try again."}.get(reason, "The server could not be reached. Check your connection and try again.")
	retry.show()
	retry.grab_focus()

func back_to_menu() -> void:
	get_tree().remove_meta(TARGET)
	get_tree().change_scene_to_file("res://features/main/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		back_to_menu()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	clear_resolver()
	if is_instance_valid(request): request.cancel_request()
