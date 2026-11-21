class_name Gamepad
extends RefCounted
## Patch 4.0.5 item 1: Xbox and PlayStation controllers. Godot reads both
## through SDL's standard layout, so one table serves both (A is Cross, B is
## Circle, X is Square, Y is Triangle, LB/RB are L1/R1, LT/RT are L2/R2).
## The pad events are added to the same InputMap actions the keys use, after
## the keys (PlayerControls.apply_preferences). The keyboard bindings, their
## validation and their saved file are not touched: rebinding a key never
## moves a pad button, and the pad layout is fixed.
##
## Boats: left stick steers (X) and moves the throttle order (Y, like W / S);
## RT / LT also raise and lower it. LB / RB are the side thrusters. A is
## Interact, B zero throttle, X the Jetty's blaster, Y the cannon salute, L3
## the horn, R3 recenters the camera, the right stick looks around, View is
## the map and Menu (Start / Options) the Esc menu.
## Planes: left stick climbs / descends (Y) and turns (X); RT / LT the
## throttle lever (Shift / Ctrl); LB / RB a barrel roll (Q / E); X the brakes
## (Space); Y the gear (G).
## Menus: the D-pad (or the left stick while a menu is open) moves a cursor
## over the buttons on screen, A presses, B goes back (it sends Esc).

const LEVER_UP: String = "pad_lever_up"
const LEVER_DOWN: String = "pad_lever_down"
const LOOK_LEFT: String = "pad_look_left"
const LOOK_RIGHT: String = "pad_look_right"
const LOOK_UP: String = "pad_look_up"
const LOOK_DOWN: String = "pad_look_down"
## Action -> pad events: [button] or [axis, direction].
const BINDINGS: Dictionary = {
	"ship_throttle_up": [[JOY_AXIS_LEFT_Y, -1.0]], "ship_throttle_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	"ship_steer_left": [[JOY_AXIS_LEFT_X, -1.0]], "ship_steer_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"ship_thruster_left": [[JOY_BUTTON_LEFT_SHOULDER]], "ship_thruster_right": [[JOY_BUTTON_RIGHT_SHOULDER]],
	"ship_brake": [[JOY_BUTTON_X]], "ship_throttle_zero": [[JOY_BUTTON_B]],
	"camera_recenter": [[JOY_BUTTON_RIGHT_STICK]], "interact": [[JOY_BUTTON_A]], "map_toggle": [[JOY_BUTTON_BACK]],
	"horn": [[JOY_BUTTON_LEFT_STICK]], "cannon_salute": [[JOY_BUTTON_Y]],
	# Pad-only actions (no key): the plane's lever and the camera.
	LEVER_UP: [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], LEVER_DOWN: [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	LOOK_LEFT: [[JOY_AXIS_RIGHT_X, -1.0]], LOOK_RIGHT: [[JOY_AXIS_RIGHT_X, 1.0]],
	LOOK_UP: [[JOY_AXIS_RIGHT_Y, -1.0]], LOOK_DOWN: [[JOY_AXIS_RIGHT_Y, 1.0]],
}
const PAD_ONLY: Array[String] = [LEVER_UP, LEVER_DOWN, LOOK_LEFT, LOOK_RIGHT, LOOK_UP, LOOK_DOWN]
## Jetty's blaster (Shift on the keyboard).
const BOOST_BUTTON: JoyButton = JOY_BUTTON_X
## Sticks rest near zero but rarely at it; triggers rest at zero.
const STICK_DEADZONE: float = 0.25
const TRIGGER_DEADZONE: float = 0.12
## Screens that move their own selection with the D-pad (the hangars) join this
## group and answer is_open(); the menu cursor leaves them alone while open.
const NAV_GROUP: StringName = &"pad_navigation"
## Marks events the pad code made (the Esc that B / Menu send, the cursor's
## click), so they do not count as keyboard or mouse use.
const SYNTHETIC: StringName = &"pad_synthetic"

## Button names, Xbox then PlayStation.
const XBOX: Dictionary = {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_DPAD_UP: "D-pad", "LT": "LT", "RT": "RT"}
const PLAYSTATION: Dictionary = {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Create", JOY_BUTTON_START: "Options", JOY_BUTTON_DPAD_UP: "D-pad", "LT": "L2", "RT": "R2"}

## The last input used was a pad (glyphs show pad buttons, the cursor shows).
static var pad_last: bool = false
## "xbox" or "playstation" (from the pad's name; Xbox names are the default).
static var family: String = "xbox"
## Rises whenever pad_last or family changes, so screens can refresh text.
static var revision: int = 0

## Adds the pad events to the InputMap. Called after the key events are set.
static func apply_events() -> void:
	for action: String in BINDINGS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		if action in PAD_ONLY: InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, TRIGGER_DEADZONE if action in [LEVER_UP, LEVER_DOWN] else STICK_DEADZONE)
		for spec: Array in BINDINGS[action]:
			InputMap.action_add_event(action, make_event(spec))
	# A presses a focused button or list row (menus, popups, the hangars).
	var accept: InputEventJoypadButton = make_event([JOY_BUTTON_A])
	if not InputMap.action_has_event("ui_accept", accept): InputMap.action_add_event("ui_accept", accept)

static func make_event(spec: Array) -> InputEvent:
	if spec.size() == 1:
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = spec[0]
		button.device = -1
		return button
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = spec[0]
	motion.axis_value = spec[1]
	motion.device = -1
	return motion

## Notes which device was used last. True when that changed.
static func note(event: InputEvent) -> bool:
	if event.has_meta(SYNTHETIC): return false
	var pad: int = -1
	if event is InputEventJoypadButton and event.pressed: pad = 1
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5: pad = 1
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed): pad = 0
	elif event is InputEventMouseMotion and event.relative.length() > 6.0: pad = 0
	if pad < 0: return false
	var kind: String = family
	if pad == 1: kind = family_of(Input.get_joy_name(event.device))
	if (pad == 1) == pad_last and kind == family: return false
	pad_last = pad == 1
	family = kind
	revision += 1
	return true

static func family_of(joy_name: String) -> String:
	var lower: String = joy_name.to_lower()
	for word: String in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if word in lower: return "playstation"
	return "xbox"

## For checks: pretend the last input was a pad (or the keyboard).
static func set_last(pad: bool, kind: String = "xbox") -> void:
	if pad == pad_last and kind == family: return
	pad_last = pad
	family = kind
	revision += 1

static func button_name(button: Variant) -> String:
	return str((PLAYSTATION if family == "playstation" else XBOX).get(button, "?"))

## A pad glyph: the button name in brackets, e.g. "[A]" or "[Cross]".
static func glyph(button: Variant) -> String:
	return "[" + button_name(button) + "]"

## The glyph for an action (its first pad event), e.g. "[Y]" for the gear.
static func action_glyph(action: String) -> String:
	if not BINDINGS.has(action): return ""
	var spec: Array = BINDINGS[action][0]
	if spec.size() == 1: return glyph(spec[0])
	match int(spec[0]):
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "[L-stick]"
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "[R-stick]"
		JOY_AXIS_TRIGGER_LEFT: return glyph("LT")
		JOY_AXIS_TRIGGER_RIGHT: return glyph("RT")
	return ""

## The key text, or the pad glyph when a pad was used last.
static func label(action: String, key_text: String) -> String:
	return action_glyph(action) if pad_last else key_text

## Either text, whichever device was used last.
static func pick(key_text: String, pad_text: String) -> String:
	return pad_text if pad_last else key_text

## Swaps the fixed key words in a hint for pad glyphs (only when a pad was
## used last). Bound keys are swapped where the text is built.
static func swap(text: String) -> String:
	if not pad_last or text.is_empty(): return text
	var menu: String = glyph(JOY_BUTTON_START)
	var out: String = text
	out = out.replace("RMB orbit · Wheel zoom · Esc menu", "[R-stick] look · %s menu" % menu)
	out = out.replace("Press Esc to give the keyboard back to the helm", "Press %s to give the controls back to the helm" % glyph(JOY_BUTTON_B))
	out = out.replace("Press Esc", "Press " + menu)
	out = out.replace("Esc menu", menu + " menu")
	out = out.replace("Click \"", "Pick \"")
	out = out.replace("Click the game window", "Press any button")
	return out

## The game's Controls list, pad column (Patch 4.0.5 item 1).
static func control_rows() -> Array:
	return [["Throttle up / down", "[L-stick] up / down, %s / %s" % [glyph("RT"), glyph("LT")]],
		["Steer left / right", "[L-stick] left / right"],
		["Side thrusters", "%s / %s" % [glyph(JOY_BUTTON_LEFT_SHOULDER), glyph(JOY_BUTTON_RIGHT_SHOULDER)]],
		["Engine to zero", glyph(JOY_BUTTON_B)], ["Horn", glyph(JOY_BUTTON_LEFT_STICK)],
		["World map", glyph(JOY_BUTTON_BACK)], ["Recenter camera", glyph(JOY_BUTTON_RIGHT_STICK)],
		["Interact", glyph(JOY_BUTTON_A)], ["Cannon salute (pirate ships)", glyph(JOY_BUTTON_Y)],
		["Plane: climb / descend", "[L-stick] up / down"], ["Plane: turn", "[L-stick] left / right"],
		["Plane: throttle", "%s / %s" % [glyph("RT"), glyph("LT")]], ["Plane: brakes, air brake", glyph(JOY_BUTTON_X)],
		["Plane: barrel roll", "%s / %s" % [glyph(JOY_BUTTON_LEFT_SHOULDER), glyph(JOY_BUTTON_RIGHT_SHOULDER)]],
		["Plane: landing gear", glyph(JOY_BUTTON_Y)], ["Jetty: blaster boost", glyph(BOOST_BUTTON)],
		["Look around", "[R-stick]"], ["Menus: move, press, back", "%s, %s, %s" % [glyph(JOY_BUTTON_DPAD_UP), glyph(JOY_BUTTON_A), glyph(JOY_BUTTON_B)]],
		["Menu", glyph(JOY_BUTTON_START)]]
