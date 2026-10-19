class_name InputPreferences
extends Resource
## Local preferences only; never ship, session or economic state.

const DEFAULT_BINDINGS: Dictionary = {
	"ship_throttle_up": KEY_W, "ship_throttle_down": KEY_S,
	"ship_steer_left": KEY_A, "ship_steer_right": KEY_D,
	"ship_thruster_left": KEY_Q, "ship_thruster_right": KEY_E,
	"ship_brake": KEY_SPACE, "ship_throttle_zero": KEY_X,
	"camera_recenter": KEY_C, "interact": KEY_F, "map_toggle": KEY_M,
	"horn": KEY_H, "pause": KEY_ESCAPE,
}
const LABELS: Dictionary = {
	"ship_throttle_up": "Increase throttle", "ship_throttle_down": "Decrease / reverse throttle",
	"ship_steer_left": "Steer left", "ship_steer_right": "Steer right",
	"ship_thruster_left": "Thruster left", "ship_thruster_right": "Thruster right",
	"ship_brake": "Brake command", "ship_throttle_zero": "Zero throttle",
	"camera_recenter": "Recenter camera", "interact": "Interact", "map_toggle": "Map",
	"horn": "Horn", "pause": "Pause / settings",
}

@export_range(0.0, 1.0) var master_volume: float = 0.8
@export_range(0.25, 3.0) var camera_sensitivity: float = 1.0
@export var invert_camera_y: bool = false
@export var fullscreen: bool = false
@export_enum("Low", "Medium", "High") var water_quality: int = 1
@export var bindings: Dictionary = DEFAULT_BINDINGS.duplicate()

static func valid_key(code: int) -> bool:
	return (code >= KEY_A and code <= KEY_Z) or (code >= KEY_0 and code <= KEY_9) \
		or (code >= KEY_F1 and code <= KEY_F12) \
		or code in [KEY_SPACE, KEY_TAB, KEY_ENTER, KEY_BACKSPACE, KEY_UP, KEY_DOWN,
			KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_INSERT, KEY_DELETE]

func validation_error() -> String:
	if water_quality < 0 or water_quality > 2: return "Invalid water quality."
	if not is_finite(master_volume) or master_volume < 0.0 or master_volume > 1.0:
		return "Volume must be between 0 and 100%."
	if not is_finite(camera_sensitivity) or camera_sensitivity < 0.25 or camera_sensitivity > 3.0:
		return "Camera sensitivity must be between 0.25 and 3.0."
	if bindings.size() != DEFAULT_BINDINGS.size():
		return "Incomplete control bindings."
	var used: Array[int] = []
	for action: String in DEFAULT_BINDINGS:
		if not bindings.has(action) or not (bindings[action] is int):
			return "Invalid control binding: " + action
		var key: int = bindings[action]
		if action == "pause":
			if key != KEY_ESCAPE:
				return "Escape is reserved for closing menus."
		elif not valid_key(key):
			return "Unsupported key for " + LABELS[action]
		if key in used:
			return "Two actions cannot share the same key."
		used.append(key)
	return ""

func to_data() -> Dictionary:
	return {"version": 1, "water_quality": water_quality, "master_volume": master_volume, "camera_sensitivity": camera_sensitivity,
		"invert_camera_y": invert_camera_y, "fullscreen": fullscreen, "bindings": bindings.duplicate()}

static func from_data(data: Variant) -> InputPreferences:
	if not data is Dictionary or data.get("version") != 1:
		return null
	for field: String in ["master_volume", "camera_sensitivity"]:
		if not (data.get(field) is float or data.get(field) is int):
			return null
	for field: String in ["invert_camera_y", "fullscreen"]:
		if not data.get(field) is bool:
			return null
	if not data.get("bindings") is Dictionary:
		return null
	var result: InputPreferences = InputPreferences.new()
	result.master_volume = data.master_volume
	result.camera_sensitivity = data.camera_sensitivity
	result.invert_camera_y = data.invert_camera_y
	result.fullscreen = data.fullscreen
	var quality: Variant = data.get("water_quality", 1)
	if not (quality is int or quality is float) or not is_finite(float(quality)) or float(quality) != floor(float(quality)) or quality < 0 or quality > 2:
		return null
	result.water_quality = int(quality)
	result.bindings = {}
	for action: Variant in data.bindings:
		var value: Variant = data.bindings[action]
		if not (value is float or value is int) or not is_finite(float(value)) \
			or float(value) != floor(float(value)) or float(value) < 0 or float(value) > 16777216:
			return null
		result.bindings[action] = int(value)
	return result if result.validation_error().is_empty() else null
