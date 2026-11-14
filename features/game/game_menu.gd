extends CanvasLayer
## Patch 2.0 item 1: the in-game Esc menu. It is drawn over a world that keeps
## running: nothing here pauses the tree, the ship or the clock. While it is open
## the helm keys are released and the ship holds its course (see ShipHelm).
## Patch 2.5 item 8: CONTROLS is the one place the game lists its keys.
signal main_menu_requested
signal quit_requested
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
var controls: PlayerControls
var panel: PanelContainer
var settings: SettingsPanel
var controls_panel: PanelContainer
var controls_grid: GridContainer
## The keys the game uses, in the order the Controls screen lists them.
const KEY_ROWS: Array = [["Throttle up / down", "ship_throttle_up", "ship_throttle_down"],
	["Steer left / right", "ship_steer_left", "ship_steer_right"],
	["Side thrusters", "ship_thruster_left", "ship_thruster_right"],
	["Engine to zero", "ship_throttle_zero"], ["Horn", "horn"],
	["World map", "map_toggle"], ["Recenter camera", "camera_recenter"]]
const FIXED_ROWS: Array = [["Look around", "Hold right mouse"], ["Zoom", "Mouse wheel"],
	["Turn the world map", "Drag"], ["Menu", "Esc"]]

func _ready() -> void:
	layer = 10
	panel = PanelContainer.new()
	PLAYFUL.dress(panel)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading: Label = Label.new()
	heading.text = "MENU"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	for entry: Array in [["RESUME", close], ["CONTROLS", open_controls], ["SETTINGS", open_settings],
			["MAIN MENU", func() -> void: main_menu_requested.emit()], ["QUIT", func() -> void: quit_requested.emit()]]:
		var item: Button = Button.new()
		item.text = entry[0]
		item.custom_minimum_size = Vector2(280, 50)
		item.add_theme_font_size_override("font_size", 21)
		# No keyboard focus: Esc must always reach this menu, never a focused button.
		item.focus_mode = Control.FOCUS_NONE
		item.pressed.connect(entry[1])
		column.add_child(item)
	settings = SettingsPanel.new()
	add_child(settings)
	settings.closed.connect(func() -> void:
		panel.show()
		controls.set_menu_open(true))
	panel.hide()
	build_controls()

## A plain two-column list of the keys, with Back.
func build_controls() -> void:
	controls_panel = PanelContainer.new()
	PLAYFUL.dress(controls_panel)
	add_child(controls_panel)
	controls_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	controls_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	controls_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	controls_panel.add_child(column)
	var heading: Label = Label.new()
	heading.text = "CONTROLS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	controls_grid = GridContainer.new()
	controls_grid.columns = 2
	controls_grid.add_theme_constant_override("h_separation", 32)
	controls_grid.add_theme_constant_override("v_separation", 6)
	column.add_child(controls_grid)
	var note: Label = Label.new()
	note.text = "Keys can be changed in Settings."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	column.add_child(note)
	var back: Button = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(280, 50)
	back.add_theme_font_size_override("font_size", 21)
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close_controls)
	column.add_child(back)
	controls_panel.hide()

## The rows as they are bound right now (Settings can change them).
func control_rows() -> Array:
	var rows: Array = []
	for entry: Array in KEY_ROWS:
		var keys: Array = []
		for action: String in entry.slice(1):
			keys.append(OS.get_keycode_string(controls.preferences.bindings.get(action, InputPreferences.DEFAULT_BINDINGS[action])))
		rows.append([entry[0], " / ".join(keys)])
	rows.append_array(FIXED_ROWS)
	return rows

func open_controls() -> void:
	for old: Node in controls_grid.get_children():
		controls_grid.remove_child(old)
		old.queue_free()
	for row: Array in control_rows():
		for index: int in 2:
			var cell: Label = Label.new()
			cell.text = row[index]
			cell.add_theme_font_size_override("font_size", 18)
			if index == 1: cell.add_theme_color_override("font_color", PLAYFUL.SUN)
			controls_grid.add_child(cell)
	panel.hide()
	controls_panel.show()

func close_controls() -> void:
	controls_panel.hide()
	panel.show()

func is_open() -> bool:
	return panel.visible or settings.visible or controls_panel.visible

func open() -> void:
	if is_open(): return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.show()
	controls.set_menu_open(true)

func close() -> void:
	if settings.visible: settings.close()
	controls_panel.hide()
	panel.hide()
	controls.set_menu_open(false)

func toggle() -> void:
	if controls_panel.visible: close_controls()
	elif is_open(): close()
	else: open()

func open_settings() -> void:
	panel.hide()
	settings.open(controls)

## PlayerControls reports Esc only while the helm has the keyboard. This catches
## it the rest of the time (menu open, window just clicked, a key still held).
## Settings handles its own Esc first and comes back to this menu; Esc on the
## Controls screen comes back too.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		toggle()
		get_viewport().set_input_as_handled()
