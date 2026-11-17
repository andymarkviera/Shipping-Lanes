extends Control
const DISPLAY = preload("res://features/ui/display_fonts.gd")
## Patch 2.7 item 3: the main menu list from docs/reference/main_menu/
## menu_ship_arrives.png. White bold rounded-serif words with a dark navy outline,
## a yellow wind-swirl cursor left of the selected one that bobs, and a small
## sound on move and select. Arrows/WASD, mouse hover/click and a gamepad's
## d-pad/stick and A all work; Esc (or B) takes the page's back action.
## Sizes are mockup pixels (941 high) times `unit`, set by the menu's layout.

signal chosen(action: String)
const MOCKUP_HEIGHT: float = 941.0
const NAVY: Color = Color("14245c")
const GOLD: Color = Color("ffc928")
const GOLD_LIGHT: Color = Color("ffe680")
## The mockup's rows: 54 px words, 78 px apart, the swirl 87 px left of them.
const FONT_SIZE: float = 54.0
const ROW: float = 78.0
const CURSOR_SIZE: Vector2 = Vector2(74, 46)
const CURSOR_GAP: float = 90.0
## Shared by the menu's pages (one glyph cache); set before adding to the tree.
var font: Font
var select_sound: AudioStreamWAV

var unit: float = 1.0
var back_action: String = ""
var list: VBoxContainer
var cursor: SwirlCursor
var items: Array[Button] = []
var clock: float = 0.0
var cursor_y: float = 0.0
var quiet: bool = false
## Frames left to snap the cursor straight to its row (the list lays out late).
var snap_frames: int = 0
var tick: AudioStreamPlayer

## The wind swirl: a curl on the left whose tail sweeps right into an arrow.
class SwirlCursor extends Control:
	func _draw() -> void:
		var s: float = size.y / 46.0
		var centre: Vector2 = Vector2(17, 19) * s
		var points: PackedVector2Array = PackedVector2Array()
		# From the eye of the curl outward, ending at its bottom heading right.
		var turns: float = 1.15
		for index: int in 41:
			var t: float = float(index) / 40.0
			var angle: float = PI * 0.5 + (1.0 - t) * turns * TAU
			points.append(centre + Vector2(cos(angle), sin(angle)) * lerpf(3.0, 12.5, t) * s)
		# The tail, rising a little towards the arrow.
		for index: int in range(1, 11):
			var t: float = float(index) / 10.0
			points.append(centre + Vector2(lerpf(0.0, 33.0, t), lerpf(12.5, 6.0, t * t)) * s)
		var tip: Vector2 = centre + Vector2(54, 5) * s
		var arrow: PackedVector2Array = PackedVector2Array([centre + Vector2(33, -8) * s, tip, centre + Vector2(33, 18) * s, centre + Vector2(39, 6) * s])
		var outline: PackedVector2Array = PackedVector2Array([centre + Vector2(29, -13.5) * s, tip + Vector2(5.5, 0) * s, centre + Vector2(29, 23.5) * s, centre + Vector2(34, 6) * s])
		draw_colored_polygon(outline, NAVY)
		draw_polyline(points, NAVY, 14.0 * s, true)
		draw_circle(points[0], 7.0 * s, NAVY)
		draw_circle(points[points.size() - 1], 7.0 * s, NAVY)
		draw_colored_polygon(arrow, GOLD)
		draw_polyline(points, GOLD, 8.5 * s, true)
		draw_circle(points[0], 4.25 * s, GOLD)
		# A light glint along the top of the curl.
		var glint: PackedVector2Array = PackedVector2Array()
		for index: int in 9:
			var angle: float = PI * 1.15 + float(index) / 8.0 * PI * 0.6
			glint.append(centre + Vector2(cos(angle), sin(angle)) * 10.0 * s)
		draw_polyline(glint, GOLD_LIGHT, 2.0 * s, true)

## Sheet lettering for menu actions; the original system serif for body copy.
static func menu_font() -> Font:
	return DISPLAY.font()

static func body_font() -> SystemFont:
	var system: SystemFont = SystemFont.new()
	system.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Palatino", "DejaVu Serif", "Liberation Serif", "serif"])
	system.font_weight = 700
	return system

## Two tiny tones: a tick on move and a rising blip on select.
static func blip(notes: PackedFloat32Array, note_seconds: float, volume: float) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count: int = int(note_seconds * notes.size() * stream.mix_rate)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(count * 2)
	for index: int in count:
		var t: float = float(index) / stream.mix_rate
		var note: int = mini(int(t / note_seconds), notes.size() - 1)
		var local: float = t - note * note_seconds
		var wave: float = sin(TAU * notes[note] * t) * minf(1.0, local / 0.004) * exp(-9.0 * local / note_seconds)
		samples.encode_s16(index * 2, int(clampf(wave * volume, -1.0, 1.0) * 24000))
	stream.data = samples
	return stream

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null: font = menu_font()
	select_sound = blip(PackedFloat32Array([880.0, 1320.0]), 0.09, 0.45)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list)
	cursor = SwirlCursor.new()
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.visible = false
	add_child(cursor)
	tick = AudioStreamPlayer.new()
	tick.stream = blip(PackedFloat32Array([1320.0]), 0.06, 0.35)
	add_child(tick)
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	layout(unit)

## A selectable word.
func add_item(text: String, action: String) -> Button:
	var item: Button = Button.new()
	item.text = text
	item.flat = true
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.focus_mode = Control.FOCUS_ALL
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		item.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		item.add_theme_color_override(state, Color.WHITE)
	item.add_theme_color_override("font_outline_color", NAVY)
	item.add_theme_font_override("font", font)
	item.mouse_entered.connect(func() -> void: if item.focus_mode != Control.FOCUS_NONE: item.grab_focus())
	item.focus_entered.connect(func() -> void: moved_to(item))
	item.pressed.connect(func() -> void: choose(action))
	list.add_child(item)
	items.append(item)
	link_items()
	style(item, 1.0)
	return item

## A line of plain text (credits, the controls list); the cursor skips it.
func add_line(text: String, scale: float, colour: Color = Color.WHITE) -> Label:
	var line: Label = Label.new()
	line.text = text
	line.set_meta("scale", scale)
	line.add_theme_color_override("font_color", colour)
	line.add_theme_color_override("font_outline_color", NAVY)
	line.add_theme_font_override("font", body_font())
	list.add_child(line)
	style(line, scale)
	return line

func clear_lines() -> void:
	for child: Node in list.get_children():
		if child is Label:
			list.remove_child(child)
			child.queue_free()

func style(item: Control, scale: float) -> void:
	item.add_theme_font_size_override("font_size", maxi(12, roundi(FONT_SIZE * scale * unit)))
	item.add_theme_constant_override("outline_size", maxi(4, roundi(11.0 * scale * unit)))
	item.add_theme_color_override("font_shadow_color", Color(NAVY, 0.55))
	item.add_theme_constant_override("shadow_offset_x", 0)
	item.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(3.0 * scale * unit)))
	item.add_theme_constant_override("shadow_outline_size", maxi(4, roundi(11.0 * scale * unit)))
	if item is Button: DISPLAY.apply(item)
	item.custom_minimum_size = Vector2(0, ROW * scale * unit)

## Re-sizes everything for a screen `new_unit` times the mockup's height.
func layout(new_unit: float) -> void:
	unit = new_unit
	if list == null: return
	for child: Node in list.get_children():
		style(child as Control, float(child.get_meta("scale", 1.0)))
	list.reset_size()
	cursor.size = CURSOR_SIZE * unit
	cursor.queue_redraw()
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused in items: cursor_y = target_y(focused)

## Up from the first wraps to the last and back.
func link_items() -> void:
	if not is_inside_tree(): return
	var shown: Array = items.filter(func(item: Button) -> bool: return item.visible)
	for index: int in shown.size():
		shown[index].focus_neighbor_top = shown[index - 1].get_path()
		shown[index].focus_neighbor_bottom = shown[(index + 1) % shown.size()].get_path()

func focus_first() -> void:
	link_items()
	for item: Button in items:
		if item.visible:
			quiet = true
			item.grab_focus()
			quiet = false
			snap_frames = 2
			return

func target_y(item: Control) -> float:
	return list.position.y + item.position.y + (item.size.y - cursor.size.y) * 0.5

## Credits roll up into place.
func roll() -> void:
	list.position.y = 240.0 * unit
	modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(list, "position:y", 0.0, 1.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func moved_to(item: Button) -> void:
	cursor.visible = true
	if not quiet and is_visible_in_tree(): tick.play()

func choose(action: String) -> void:
	# The select sound lives on the root so a scene change does not cut it off.
	var sound: AudioStreamPlayer = AudioStreamPlayer.new()
	sound.stream = select_sound
	get_tree().root.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
	chosen.emit(action)

func _process(delta: float) -> void:
	clock += delta
	var focused: Control = get_viewport().gui_get_focus_owner()
	if not focused in items: return
	# Glide to the new row, then bob left and right.
	if snap_frames > 0:
		snap_frames -= 1
		cursor_y = target_y(focused)
	cursor_y = lerpf(cursor_y, target_y(focused), 1.0 - exp(-22.0 * delta))
	cursor.position = Vector2(list.position.x - CURSOR_GAP * unit + sin(clock * TAU / 1.1) * 4.0 * unit, cursor_y)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo() or not event.is_pressed(): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var key: InputEventKey = event as InputEventKey
	if key != null and not (key.ctrl_pressed or key.meta_pressed or key.alt_pressed) and focused in items:
		var step: int = {KEY_W: -1, KEY_S: 1}.get(key.physical_keycode, 0)
		if step != 0:
			var index: int = items.find(focused)
			for attempt: int in items.size():
				index = posmod(index + step, items.size())
				if items[index].visible: break
			items[index].grab_focus()
			get_viewport().set_input_as_handled()
			return
	if not back_action.is_empty() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		choose(back_action)
