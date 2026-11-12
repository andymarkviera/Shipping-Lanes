extends CanvasLayer
## No silent dead ends (REBUILD_PLAN.md fix-first item 4).
## Whenever the helm is off, this banner says why and how to get out.
## ShipHelm owns it, so every sailing scene gets it.
const HOLD_SECONDS: float = 0.4
var ship: HandlingShip
var controls: PlayerControls
## Scene wording. Text keys: "leave", "docked", "empty", "panel". "rescue": true shows
## the free test-fuel button in scenes with no other refuel while adrift. The game
## sets "rescue_text" and "rescue_action" to turn that button into its paid tow.
var hints: Dictionary = {}
var panel: PanelContainer
var label: Label
var rescue: Button
var blocked_seconds: float = 0.0

func _ready() -> void:
	layer = 3
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	root.add_child(panel)
	# Sits just above the throttle indicator and grows upward.
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -155
	panel.offset_bottom = -155
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("6b3a1f")
	for edge: String in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 10.0)
	panel.add_theme_stylebox_override("panel", style)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)
	label = Label.new()
	label.custom_minimum_size.x = 520
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	stack.add_child(label)
	rescue = Button.new()
	rescue.focus_mode = Control.FOCUS_NONE
	rescue.pressed.connect(add_test_fuel)
	stack.add_child(rescue)
	rescue.hide()
	panel.hide()

func hint(key: String, fallback: String) -> String:
	return str(hints.get(key, fallback))

func fuel_empty() -> bool:
	return is_instance_valid(ship) and ship.state != null and ship.state.fuel_liters <= 0

## Empty when the helm works. Otherwise: what stopped the ship, then the way out.
func reason() -> String:
	if not is_instance_valid(ship) or not is_instance_valid(controls) or ship.state == null: return ""
	if not controls.ship_context_active: return ""
	var leave: String = hint("leave", "Press Esc for the main menu")
	if not ship.is_physics_processing():
		return "SHIP SWITCHED OFF — this voyage could not be loaded.\n%s, then open this scene again." % leave
	if ship.simulation_paused:
		if not ship.pause_reason.is_empty(): return ship.pause_reason
		return "PAUSED — the voyage is loading, saving or stopped by an error (see the panel text).\nStill paused after a few seconds? %s, then open this scene again." % leave
	if ship.docked:
		return "DOCKED — the helm is locked at the berth.\n" + hint("docked", "Click \"Undock (test)\" to sail.")
	if not ship.helm_available():
		return "HELM LOCKED — the deck is moving, or the load is not fully raised.\nWait for the deck. With a load on board, click Raise before sailing."
	if fuel_empty():
		return "FUEL TANK EMPTY — engine and thrusters are off.\n" + hint("empty", "Let the boat stop, then click \"Refuel (test)\".")
	if controls.menu_open:
		return "HELM OFF — a panel is open.\n" + hint("panel", "Close the panel to sail.")
	if not controls.window_focused:
		return "HELM OFF — the game window is not active.\nClick the game window."
	if get_viewport().gui_get_focus_owner() != null:
		return "HELM OFF — a button, list or text box has the keyboard.\nPress Esc to give the keyboard back to the helm."
	if controls.wait_for_release:
		return "HELM WAITING — let go of all keys and mouse buttons, then press again."
	return ""

func add_test_fuel() -> void:
	if not fuel_empty(): return
	# The game replaces the free test fuel with its own paid tow.
	if hints.has("rescue_action"):
		hints.rescue_action.call()
		return
	ship.refuel(ship.definition.fuel_capacity_liters * 0.25)
	controls.wait_for_release = true

func _process(delta: float) -> void:
	if is_instance_valid(ship) and not ship.simulation_paused: ship.pause_reason = ""
	var text: String = reason()
	# Short blocks (a button click, a save tick) pass without a flash.
	blocked_seconds = blocked_seconds + delta if not text.is_empty() else 0.0
	panel.visible = blocked_seconds >= HOLD_SECONDS
	if not panel.visible: return
	label.text = text
	rescue.visible = bool(hints.get("rescue", false)) and fuel_empty() and ship.helm_available()
	if rescue.visible:
		rescue.disabled = ship.velocity.length() > 0.05
		rescue.text = "Wait for the ship to stop…" if rescue.disabled else str(hints.get("rescue_text", "Add free test fuel (quarter tank)"))

func _input(event: InputEvent) -> void:
	# A focused control swallows the helm keys. Esc hands the keyboard back.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE \
			and is_instance_valid(controls) and controls.ship_context_active and get_viewport().gui_get_focus_owner() != null:
		get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()
