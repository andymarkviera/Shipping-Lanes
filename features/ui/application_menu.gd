class_name ApplicationMenu
extends Control

signal selected(action: String)
var pages: Dictionary = {}
var first_buttons: Dictionary = {}
var timer_details: Label
var timer_button: Button
var session_revision: int = 0
var session_details: Label
var session_result: Label
var test_load_button: Button
var continue_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background: ColorRect = ColorRect.new()
	background.color = Color("263b48")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title: Label = Label.new()
	title.text = "CONTAINER SHIP SIM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 42
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_shadow_color", Color("15232e"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title)
	var footer: Label = Label.new()
	footer.text = "DEVELOPMENT BUILD   /   MENU & SESSION TEST"
	footer.add_theme_font_size_override("font_size", 13)
	footer.modulate = Color("a5b9c2")
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(64, -40)
	add_child(footer)
	var home: VBoxContainer = page("title")
	button(home, "PLAY", "play")
	continue_button = button(home, "CONTINUE TEST SESSION", "continue")
	button(home, "SERVERS", "servers")
	button(home, "SETTINGS", "settings")
	var fleet: Button = button(home, "FLEET", "fleet")
	fleet.disabled = true
	fleet.tooltip_text = "Fleet management will arrive in a later step."
	button(home, "EXIT", "exit")
	var servers: VBoxContainer = page("servers")
	label(servers, "SERVERS", 26)
	label(servers, "Online servers are not connected yet.\nUse the local session to test the menus.", 18)
	button(servers, "LOCAL TEST SESSION", "play")
	button(servers, "BACK", "title")
	var playing: VBoxContainer = page("playing")
	label(playing, "LOCAL TEST SESSION", 26)
	label(playing, "Session ready. Boat controls and the world\nwill arrive in later build steps.\n\nEscape opens the session menu.", 18)
	button(playing, "SESSION MENU", "pause")
	session_details = Label.new()
	session_details.add_theme_font_size_override("font_size", 18)
	playing.add_child(session_details)
	test_load_button = button(playing, "LOAD TEST CONTAINER — 100 CREDITS", "test_load")
	session_result = Label.new()
	session_result.add_theme_font_size_override("font_size", 16)
	playing.add_child(session_result)
	timer_button = button(playing, "START 10-SECOND TEST", "test_timer")
	timer_details = Label.new()
	playing.add_child(timer_details)
	var paused: VBoxContainer = page("paused")
	label(paused, "SESSION MENU", 26)
	label(paused, "Your controls are released. Hosted sessions\nkeep running while this menu is open.", 18)
	button(paused, "RESUME", "resume")
	button(paused, "SETTINGS", "settings")
	button(paused, "NEW TEST SESSION", "play")
	button(paused, "RETURN TO MENU", "title")

func page(id: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(64, 170)
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	pages[id] = column
	return column

func label(parent: Control, text: String, size: int) -> void:
	var item: Label = Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	parent.add_child(item)

func button(parent: Control, text: String, action: String) -> Button:
	var item: Button = Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(280, 46)
	item.add_theme_font_size_override("font_size", 21)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("596e7b") if state == "normal" else Color("708895")
		if state == "disabled":
			style.bg_color = Color("324854")
		style.border_color = Color("c3d0d5") if state != "focus" else Color("ffffff")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(3)
		item.add_theme_stylebox_override(state, style)
	item.pressed.connect(func() -> void: selected.emit(action))
	parent.add_child(item)
	if not first_buttons.has(parent):
		first_buttons[parent] = item
	return item

func show_page(id: String, can_continue: bool) -> void:
	continue_button.visible = can_continue
	for key: String in pages:
		pages[key].visible = key == id
	if pages.has(id) and id != "playing":
		first_buttons[pages[id]].grab_focus()

func show_session_state(snapshot: Dictionary, message: String) -> void:
	session_revision = snapshot.revision
	session_details.text = "TEST STATE  |  Credits: %s  |  Containers: %d" % [GameUnits.format_minor(snapshot.player.wallet_minor).value, snapshot.inventory.cargo.cargo_test_container]
	session_result.text = message

func show_timer(view: Dictionary) -> void:
	timer_details.text = "Timer: %s  |  Remaining: %.1f s" % [view.status, float(view.remaining_ms) / 1000.0]
