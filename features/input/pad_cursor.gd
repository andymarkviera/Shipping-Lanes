extends CanvasLayer
## Patch 4.0.5 item 1: a controller cursor over the buttons on screen.
## Many of the game's buttons never take keyboard focus (so Esc always reaches
## the menu and the helm keeps its keys), so Godot's own focus moves cannot
## reach them. This cursor does not use focus: the D-pad (and the left stick
## while a menu is open) moves a ring to the nearest button that way, A
## clicks it at its centre (the same path as the mouse), left / right on a
## slider moves it. Sailing, the ring can pick the HUD's buttons while the
## sticks keep steering; B hides it. PlayerControls owns one in every scene.
const RING: Color = Color("ffd23f")
const STICK_ON: float = 0.6
const STICK_OFF: float = 0.3
const REPEAT_FIRST_S: float = 0.4
const REPEAT_S: float = 0.14
var controls: PlayerControls
var target: Control
var active: bool = false
var canvas: Control
var clock: float = 0.0
## The left stick as a D-pad in menus: held direction and its repeat timer.
var stick_dir: Vector2 = Vector2.ZERO
var stick_wait: float = 0.0
## Presses made, for checks.
var clicks: int = 0

func _ready() -> void:
	layer = 120
	canvas = Control.new()
	canvas.name = "PadCursorRing"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(draw_ring)
	add_child(canvas)

func in_menu() -> bool:
	return not is_instance_valid(controls) or controls.menu_open or not controls.ship_context_active

## A hangar (or other screen in Gamepad.NAV_GROUP) that moves its own selection.
func screen_owns_pad() -> bool:
	for node: Node in get_tree().get_nodes_in_group(Gamepad.NAV_GROUP):
		if node.has_method("is_open") and node.is_open(): return true
	return false

## Everything the cursor can land on: visible, enabled buttons and sliders in
## the main window. With a menu open only the topmost layer counts, so the
## HUD under the Esc menu is skipped.
func candidates() -> Array[Control]:
	var found: Array[Control] = []
	var layers: Array[int] = []
	collect(get_tree().root, 0, found, layers)
	if not in_menu() or found.is_empty(): return found
	var top: int = layers.max()
	var kept: Array[Control] = []
	for index: int in found.size():
		if layers[index] == top: kept.append(found[index])
	return kept

func collect(node: Node, depth_layer: int, found: Array[Control], layers: Array[int]) -> void:
	if node == self: return
	var layer_here: int = depth_layer
	if node is CanvasLayer:
		if not (node as CanvasLayer).visible: return
		layer_here = (node as CanvasLayer).layer
	if node is Viewport and node != get_tree().root: return
	if node is CanvasItem and not (node as CanvasItem).visible: return
	if node is Control and usable(node as Control):
		found.append(node as Control)
		layers.append(layer_here)
	for child: Node in node.get_children():
		collect(child, layer_here, found, layers)

static func usable(control: Control) -> bool:
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE: return false
	if control is BaseButton:
		if (control as BaseButton).disabled: return false
	elif not (control is Slider): return false
	if not control.is_visible_in_tree() or control.size.x < 2.0 or control.size.y < 2.0: return false
	if control.get_global_transform_with_canvas().get_scale().x <= 0.0: return false
	var box: Rect2 = screen_rect(control)
	return box.intersects(control.get_viewport().get_visible_rect())

static func screen_rect(control: Control) -> Rect2:
	var xform: Transform2D = control.get_global_transform_with_canvas()
	return Rect2(xform.origin, control.size * xform.get_scale())

## `full` also checks the target is still on the topmost layer (a menu opened
## over it). The cheap check runs every frame; the full one on each press.
func valid_target(full: bool = true) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or not usable(target): return false
	return not full or candidates().has(target)

## The nearest candidate from the current one in `direction` (unit vector).
## No current one: the first on screen (top left).
func pick(direction: Vector2) -> Control:
	var options: Array[Control] = candidates()
	if options.is_empty(): return null
	if not valid_target() or direction == Vector2.ZERO:
		var best: Control = null
		var best_score: float = INF
		for option: Control in options:
			var at: Vector2 = screen_rect(option).get_center()
			var score: float = at.y * 4.0 + at.x
			if score < best_score:
				best_score = score
				best = option
		return best
	var from: Vector2 = screen_rect(target).get_center()
	var chosen: Control = null
	var chosen_score: float = INF
	for option: Control in options:
		if option == target: continue
		var offset: Vector2 = screen_rect(option).get_center() - from
		var along: float = offset.dot(direction)
		if along <= 1.0: continue
		var across: float = absf(offset.cross(direction))
		var score: float = along + across * 2.5
		if score < chosen_score:
			chosen_score = score
			chosen = option
	return chosen if chosen != null else target

func move(direction: Vector2) -> void:
	if valid_target() and target is Slider and direction.y == 0.0:
		var slider: Slider = target as Slider
		var step: float = slider.step if slider.step > 0.0 else (slider.max_value - slider.min_value) / 20.0
		slider.value += step * signf(direction.x) * maxf(1.0, (slider.max_value - slider.min_value) / 20.0 / step)
		return
	var was_active: bool = active and valid_target()
	active = true
	var next: Control = pick(direction if was_active else Vector2.ZERO)
	if next != null: aim(next)

func aim(control: Control) -> void:
	target = control
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(control)
			break
		parent = parent.get_parent()
	canvas.queue_redraw()

## Clicks the target at its centre, like the mouse. A button that takes focus
## from the click gives it back, so the helm keeps its keys while sailing.
func press() -> bool:
	if not valid_target(): return false
	var at: Vector2 = screen_rect(target).get_center()
	var pressed: Control = target
	for down: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		click.set_meta(Gamepad.SYNTHETIC, true)
		get_viewport().push_input(click)
	clicks += 1
	if not in_menu() and is_instance_valid(pressed) and pressed.has_focus(): pressed.release_focus()
	return true

func hide_ring() -> void:
	active = false
	canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	# This child sees input before its PlayerControls: note the device here too.
	Gamepad.note(event)
	if event.has_meta(Gamepad.SYNTHETIC): return
	if event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 6.0):
		if active: hide_ring()
		return
	if screen_owns_pad() or get_viewport().gui_get_focus_owner() != null:
		# A screen (or a focused control) moves its own selection.
		if active: hide_ring()
		return
	if event is InputEventJoypadMotion and in_menu() and (event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y):
		stick_event(event)
		return
	if not event is InputEventJoypadButton or not event.pressed: return
	var direction: Vector2 = {JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN,
		JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT}.get(event.button_index, Vector2.ZERO)
	if direction != Vector2.ZERO:
		move(direction)
		get_viewport().set_input_as_handled()
	elif event.button_index == JOY_BUTTON_A and (active or in_menu()):
		if not active or not valid_target():
			# In a menu, A with no ring yet lands on the first button.
			if not in_menu(): return
			move(Vector2.ZERO)
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		press()
	elif event.button_index == JOY_BUTTON_B and active and not in_menu():
		hide_ring()

func stick_event(event: InputEventJoypadMotion) -> void:
	var stick: Vector2 = Vector2(Input.get_joy_axis(event.device, JOY_AXIS_LEFT_X), Input.get_joy_axis(event.device, JOY_AXIS_LEFT_Y))
	var direction: Vector2 = Vector2.ZERO
	if stick.length() > STICK_ON:
		direction = Vector2(signf(stick.x), 0.0) if absf(stick.x) > absf(stick.y) else Vector2(0.0, signf(stick.y))
	elif stick.length() > STICK_OFF:
		direction = stick_dir
	if direction == stick_dir: return
	stick_dir = direction
	stick_wait = REPEAT_FIRST_S
	if direction != Vector2.ZERO: move(direction)

func _process(delta: float) -> void:
	clock += delta
	if stick_dir != Vector2.ZERO:
		stick_wait -= delta
		if stick_wait <= 0.0:
			stick_wait = REPEAT_S
			move(stick_dir)
	if active and not Gamepad.pad_last: hide_ring()
	if active and not valid_target(false):
		# The button went away (a panel closed): the next press finds a new one.
		target = null
	if active: canvas.queue_redraw()

func draw_ring() -> void:
	if not active or not is_instance_valid(target) or not target.is_visible_in_tree(): return
	var box: Rect2 = screen_rect(target).grow(4.0 + sin(clock * TAU * 1.2) * 1.5)
	canvas.draw_rect(box, Color(0, 0, 0, 0.55), false, 7.0)
	canvas.draw_rect(box, RING, false, 4.0)
