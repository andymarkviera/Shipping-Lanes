extends CanvasLayer
## Patch 2.0 item 1: the in-game Esc menu. It is drawn over a world that keeps
## running: nothing here pauses the tree, the ship or the clock. While it is open
## the helm keys are released and the ship holds its course (see ShipHelm).
signal main_menu_requested
signal quit_requested
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
var controls: PlayerControls
var panel: PanelContainer
var settings: SettingsPanel

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
	var note: Label = Label.new()
	note.text = "The world keeps running."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	column.add_child(note)
	for entry: Array in [["RESUME", close], ["SETTINGS", open_settings],
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

func is_open() -> bool:
	return panel.visible or settings.visible

func open() -> void:
	if is_open(): return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.show()
	controls.set_menu_open(true)

func close() -> void:
	if settings.visible: settings.close()
	panel.hide()
	controls.set_menu_open(false)

func toggle() -> void:
	if is_open(): close()
	else: open()

func open_settings() -> void:
	panel.hide()
	settings.open(controls)

## PlayerControls reports Esc only while the helm has the keyboard. This catches
## it the rest of the time (menu open, window just clicked, a key still held).
## Settings handles its own Esc first and comes back to this menu.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		toggle()
		get_viewport().set_input_as_handled()
