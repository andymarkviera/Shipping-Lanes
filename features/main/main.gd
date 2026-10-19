extends Node
## Application owns local navigation; it never pauses the shared SceneTree.
enum State { BOOT, TITLE, SERVERS, PLAYING, PAUSED, SETTINGS }
const Session = preload("res://features/main/test_session.gd")
var state: State = State.BOOT
var settings_return: State = State.TITLE
var session: TestSession
var continuation: Dictionary = {}
var orbit_captured: bool = false
var catalog: DefinitionRegistry = DefinitionRegistry.new()
@onready var controls: PlayerControls = $Controls
@onready var menu: ApplicationMenu = $UI/Menu

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--storage-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/storage_probe.tscn")
		return
	if OS.get_cmdline_user_args().has("--geography-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/geography_probe.tscn")
		return
	var errors: PackedStringArray = catalog.load_definitions(PrototypeCatalog.RECORDS)
	if not errors.is_empty():
		push_error("Catalog validation failed: " + "; ".join(errors))
		get_tree().quit(1)
		return
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(Vector2i(960, 640))
		DisplayServer.window_set_title("Container Ship Sim")
	menu.selected.connect(navigate)
	$UI/Settings.closed.connect(func() -> void: transition(settings_return))
	controls.command_requested.connect(func(action: StringName) -> void:
		if action == &"pause":
			pause_session())
	transition(State.TITLE)
	print("Shipping Lanes: Main scene loaded successfully.")

func navigate(action: String) -> void:
	match action:
		"play": start_session()
		"continue": continue_session()
		"servers": transition(State.SERVERS)
		"settings": open_settings()
		"pause": pause_session()
		"resume": transition(State.PLAYING)
		"title": return_to_title()
		"exit": get_tree().quit()

func start_session(hosted: bool = true, snapshot: Dictionary = {}) -> void:
	destroy_session()
	session = Session.new()
	session.name = "TestSession"
	session.hosted = hosted
	session.elapsed = float(snapshot.get("elapsed", 0.0))
	$World.add_child(session)
	continuation = {}
	transition(State.PLAYING)

func destroy_session() -> void:
	if is_instance_valid(session):
		$World.remove_child(session)
		session.queue_free()
	session = null

func continue_session() -> void:
	if continuation.is_empty():
		return
	start_session(bool(continuation.hosted), continuation.duplicate(true))

func return_to_title() -> void:
	if is_instance_valid(session):
		continuation = session.snapshot()
	destroy_session()
	transition(State.TITLE)

func pause_session() -> void:
	if state == State.PLAYING:
		transition(State.PAUSED)

func open_settings() -> void:
	if state == State.SETTINGS:
		return
	settings_return = State.PAUSED if is_instance_valid(session) else state
	transition(State.SETTINGS)
	$UI/Settings.open(controls)

func transition(next: State) -> void:
	if next == State.PLAYING and not is_instance_valid(session):
		return
	release_capture()
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	state = next
	controls.set_ship_context(state == State.PLAYING)
	controls.set_menu_open(state != State.PLAYING)
	if is_instance_valid(session):
		session.locally_paused = state != State.PLAYING
	$UI/Settings.hide()
	var pages: Dictionary = {State.TITLE: "title", State.SERVERS: "servers", State.PLAYING: "playing", State.PAUSED: "paused"}
	menu.show_page(pages.get(state, ""), not continuation.is_empty())

func release_capture() -> void:
	orbit_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		release_capture()
		pause_session()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if not event.pressed:
			release_capture()
		elif state == State.PLAYING and controls.input_allowed():
			orbit_captured = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	match state:
		State.PLAYING: pause_session()
		State.PAUSED: transition(State.PLAYING)
		State.SERVERS: return_to_title()
	get_viewport().set_input_as_handled()
