extends RefCounted
## Patch 3.0.1 item 1: the captain's display name. No account, no password: the
## name is a label saved beside the install key and shown over the boat.
const PATH: String = "user://captain_name.txt"
const MIN_LENGTH: int = 3
const MAX_LENGTH: int = 16
const FALLBACK: String = "Captain"
const ALLOWED: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-"
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const DISPLAY = preload("res://features/ui/display_fonts.gd")

## Trimmed, allowed characters only, single spaces, at most MAX_LENGTH. Returns
## "" when fewer than MIN_LENGTH characters survive. Server and client share it.
static func sanitize(raw: String) -> String:
	var kept: String = ""
	var space: bool = false
	for character: String in raw.strip_edges().left(64):
		if not character in ALLOWED: continue
		if character == " ":
			if space: continue
			space = true
		else: space = false
		kept += character
	kept = kept.strip_edges().left(MAX_LENGTH).strip_edges()
	return kept if kept.length() >= MIN_LENGTH else ""

static func valid(raw: String) -> bool:
	return not raw.is_empty() and sanitize(raw) == raw

static func load_saved(path: String = PATH) -> String:
	if not FileAccess.file_exists(path): return ""
	return sanitize(FileAccess.get_file_as_string(path))

static func save(value: String, path: String = PATH) -> bool:
	var clean: String = sanitize(value)
	if clean.is_empty(): return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(clean)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok

## A small centred modal in the playful style. `done` receives the saved name.
## Enter submits; the button stays disabled until the name is acceptable.
static func make_dialog(current: String, done: Callable, heading_text: String = "Captain name", path: String = PATH) -> Control:
	var root: Control = Control.new()
	root.name = "CaptainNameDialog"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = PLAYFUL.make()
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.025, 0.065, 0.1, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 380
	PLAYFUL.dress(panel)
	center.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	var heading: Label = Label.new()
	DISPLAY.apply(heading)
	heading.text = heading_text.to_upper()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	stack.add_child(heading)
	var field: LineEdit = LineEdit.new()
	field.name = "Name"
	field.placeholder_text = "Captain name"
	field.max_length = MAX_LENGTH
	field.text = current
	field.custom_minimum_size = Vector2(320, 44)
	field.add_theme_font_size_override("font_size", 20)
	stack.add_child(field)
	var hint: Label = Label.new()
	hint.text = "%d-%d letters, digits, spaces, _ or -" % [MIN_LENGTH, MAX_LENGTH]
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	stack.add_child(hint)
	var sail: Button = Button.new()
	sail.name = "SetSail"
	sail.text = "Set sail"
	sail.custom_minimum_size = Vector2(240, 48)
	sail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(sail)
	var refresh: Callable = func(_text: String = "") -> void: sail.disabled = sanitize(field.text).is_empty()
	var submit: Callable = func(_text: String = "") -> void:
		var clean: String = sanitize(field.text)
		if clean.is_empty(): return
		if not save(clean, path): hint.text = "Could not save the name; using it for this voyage."
		root.queue_free()
		done.call(clean)
	field.text_changed.connect(refresh)
	field.text_submitted.connect(submit)
	sail.pressed.connect(submit)
	refresh.call()
	field.ready.connect(func() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		field.grab_focus()
		field.caret_column = field.text.length())
	return root
