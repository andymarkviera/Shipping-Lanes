class_name PlayerControls
extends Node
## Controllers read this boundary; they must not poll raw Input behind menus.

signal command_requested(action: StringName)
signal camera_motion_requested(motion: Vector2)
## Trackpad gestures (macOS sends two-finger scroll and pinch as gestures, not wheel clicks).
signal camera_zoom_requested(amount: float)
signal camera_turn_requested(motion: Vector2)

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
## The window outlives scenes: these keep the Mac display setup to once per run.
static var hidpi_sized: bool = false
static var applied_fullscreen: int = -1
const BOOST_COMMAND: StringName = &"jetty_boost"
const PAN_ZOOM: float = 0.35
const PAN_TURN: float = 40.0

func _ready() -> void:
	load_preferences()
	apply_preferences()
	apply_display_scale()
	if not get_window().dpi_changed.is_connected(apply_display_scale):
		get_window().dpi_changed.connect(apply_display_scale)

static func is_mac() -> bool:
	return OS.has_feature("macos")

## Retina/HiDPI: Godot sizes the window and HUD in pixels, so on a 2x Mac screen
## they came out half size. Scale both by the screen's factor; the 3D view and
## fonts still render at full pixel resolution, so the HUD stays crisp.
## Windows and Linux report 1.0 and are left exactly as before.
func apply_display_scale() -> void:
	if not is_mac() or DisplayServer.get_name() == "headless": return
	var window: Window = get_window()
	var scale: float = clampf(DisplayServer.screen_get_scale(window.current_screen), 1.0, 4.0)
	window.content_scale_factor = scale
	# Apple Silicon performance: a 2x Retina window is 4x the 3D pixels. Render
	# the 3D view at 1.5x the logical size (0.75 on Retina) and upscale with FSR
	# (set in project.godot); HUD and text stay at full Retina resolution.
	window.scaling_3d_scale = clampf(1.5 / scale, 0.5, 1.0)
	if not hidpi_sized and window.mode == Window.MODE_WINDOWED:
		hidpi_sized = true
		var screen: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
		var wanted: Vector2i = Vector2i((Vector2(window.size) * scale).round())
		wanted = wanted.min(Vector2i((Vector2(screen.size) * 0.9).round()))
		if wanted.x > window.size.x and wanted.y > window.size.y:
			window.size = wanted
			window.position = screen.position + (screen.size - wanted) / 2
	hidpi_sized = true

func load_preferences() -> void:
	preferences = DEFAULTS.duplicate(true)
	settings_notice = ""
	if not FileAccess.file_exists(preferences_path):
		preferences.water_quality = InputPreferences.auto_water_quality()
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
	# MacBook trackpads have no easy right-drag: click-drag (and Ctrl-click drag) also orbits.
	if is_mac():
		var drag: InputEventMouseButton = InputEventMouseButton.new()
		drag.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("camera_orbit", drag)
	AudioServer.set_bus_mute(0, preferences.master_volume == 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, preferences.master_volume)))
	var ambience: Node = get_tree().root.get_node_or_null("MenuBeachAmbience")
	if ambience != null: ambience.set_volume(preferences.ambience_volume)
	get_tree().call_group("game_ambience", "set_volume", preferences.ambience_volume)
	# Only on start and when the setting changes, so a scene change never undoes the
	# macOS green button / Ctrl+Cmd+F, and the window never flickers between scenes.
	if DisplayServer.get_name() != "headless" and applied_fullscreen != int(preferences.fullscreen):
		applied_fullscreen = int(preferences.fullscreen)
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

## Patch 4.0.3 item 1: a fixed key held (the plane's Shift / Ctrl throttle),
## through the same gate as the bound actions.
func held_key(key: Key) -> float:
	return 1.0 if input_allowed() and Input.is_physical_key_pressed(key) else 0.0

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
	# Cmd+Q quits like the window's close button (the game scene saves first).
	# Godot's Mac app menu normally turns Cmd+Q into that close request itself;
	# this catches it if the key reaches the game instead.
	if is_mac() and event is InputEventKey and event.pressed and not event.echo and event.meta_pressed \
			and (event.keycode == KEY_Q or event.physical_keycode == KEY_Q):
		get_viewport().set_input_as_handled()
		request_quit()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F3 or event.keycode == KEY_F3) \
			and not event.alt_pressed and not event.meta_pressed and not event.shift_pressed and not ApplicationMenu.friends_client():
		DevMode.toggle(get_tree())
		get_viewport().set_input_as_handled()

## Same path as the window's close button: scenes that save (port_test.gd) turn
## off auto_accept_quit and save in NOTIFICATION_WM_CLOSE_REQUEST.
func request_quit() -> void:
	var tree: SceneTree = get_tree()
	if tree.auto_accept_quit:
		tree.quit()
	else:
		tree.root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

func _unhandled_input(event: InputEvent) -> void:
	if not input_allowed():
		return
	if event is InputEventPanGesture:
		# Two-finger scroll: up/down zooms, sideways turns the view.
		var pan: Vector2 = event.delta
		if absf(pan.y) >= absf(pan.x): camera_zoom_requested.emit(clampf(pan.y * PAN_ZOOM, -1.0, 1.0))
		else: camera_turn_requested.emit(Vector2(pan.x * PAN_TURN * preferences.camera_sensitivity, 0.0))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMagnifyGesture and event.factor > 0.0:
		camera_zoom_requested.emit(clampf(-log(event.factor) / 0.12, -1.0, 1.0))
		get_viewport().set_input_as_handled()
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
	# Patch 4.0.2: Shift is the Jetty's blaster boost (a fixed key, like the
	# plane's mouse; no binding can take Shift, see InputPreferences.valid_key).
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SHIFT or event.physical_keycode == KEY_SHIFT):
		command_requested.emit(BOOST_COMMAND)
		get_viewport().set_input_as_handled()
