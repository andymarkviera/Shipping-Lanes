class_name PlayerControls
extends Node
## Controllers read this boundary; they must not poll raw Input behind menus.

signal command_requested(action: StringName)
signal camera_motion_requested(motion: Vector2)

const DEFAULTS: InputPreferences = preload("res://features/settings/default_preferences.tres")
const MOUSE_BINDINGS: Dictionary = {"camera_orbit": MOUSE_BUTTON_RIGHT,
	"camera_zoom_in": MOUSE_BUTTON_WHEEL_UP, "camera_zoom_out": MOUSE_BUTTON_WHEEL_DOWN}
@export var preferences_path: String = "user://preferences.json"
var preferences: InputPreferences = DEFAULTS.duplicate(true)
var settings_notice: String = ""
var ship_context_active: bool = false
var menu_open: bool = false
var wait_for_release: bool = true
var window_focused: bool = true

func _ready() -> void:
	load_preferences()
	apply_preferences()

func load_preferences() -> void:
	preferences = DEFAULTS.duplicate(true)
	settings_notice = ""
	if not FileAccess.file_exists(preferences_path):
		return
	var file: FileAccess = FileAccess.open(preferences_path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		settings_notice = "Saved settings could not be read. Defaults are active."
		return
	var parser: JSON = JSON.new()
	var parsed: Error = parser.parse(file.get_as_text())
	var candidate: InputPreferences = InputPreferences.from_data(parser.data) if parsed == OK else null
	if candidate == null:
		settings_notice = "Saved settings are invalid or from a newer version. Defaults are active."
	else:
		preferences = candidate

func save_preferences(candidate: InputPreferences) -> String:
	var error: String = candidate.validation_error()
	if not error.is_empty():
		return error
	var temporary: String = preferences_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Settings could not be saved. Your previous settings are unchanged."
	file.store_string(JSON.stringify(candidate.to_data(), "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary, preferences_path) != OK:
		return "Settings could not be saved. Your previous settings are unchanged."
	preferences = candidate.duplicate(true)
	settings_notice = ""
	apply_preferences()
	return ""

func apply_preferences() -> void:
	for action: String in preferences.bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = preferences.bindings[action]
		InputMap.action_add_event(action, event)
	for action: String in MOUSE_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BINDINGS[action]
		InputMap.action_add_event(action, event)
	AudioServer.set_bus_mute(0, preferences.master_volume == 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, preferences.master_volume)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if preferences.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	wait_for_release = true

func set_ship_context(active: bool) -> void:
	ship_context_active = active
	wait_for_release = true

func set_menu_open(open: bool) -> void:
	# Scenes call this every frame. Re-arming on an unchanged value would hold
	# wait_for_release forever while a key is down, and the helm would never see it.
	if menu_open == open: return
	menu_open = open
	wait_for_release = true

func input_allowed() -> bool:
	return ship_context_active and not menu_open and window_focused and not wait_for_release \
		and get_viewport().gui_get_focus_owner() == null

func action_strength(action: StringName) -> float:
	return Input.get_action_strength(action) if input_allowed() and InputMap.has_action(action) else 0.0

func steering_axis() -> float:
	return action_strength("ship_steer_right") - action_strength("ship_steer_left")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		window_focused = false
		wait_for_release = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		window_focused = true
		wait_for_release = true

func _process(_delta: float) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		wait_for_release = true
		return
	if not wait_for_release or menu_open or not window_focused:
		return
	for action: String in preferences.bindings.keys() + MOUSE_BINDINGS.keys():
		if Input.is_action_pressed(action):
			return
	wait_for_release = false

## F3 is the one developer toggle. Read here because every scene has a PlayerControls.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F3 or event.keycode == KEY_F3) \
			and not event.alt_pressed and not event.meta_pressed and not event.shift_pressed and not ApplicationMenu.friends_client():
		DevMode.toggle(get_tree())
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not input_allowed():
		return
	if event is InputEventMouseMotion and Input.is_action_pressed("camera_orbit"):
		var motion: Vector2 = event.relative * preferences.camera_sensitivity
		if preferences.invert_camera_y:
			motion.y = -motion.y
		camera_motion_requested.emit(motion)
		get_viewport().set_input_as_handled()
		return
	for action: String in preferences.bindings.keys() + MOUSE_BINDINGS.keys():
		if event.is_action_pressed(action) and not event.is_echo():
			command_requested.emit(StringName(action))
			get_viewport().set_input_as_handled()
			return
