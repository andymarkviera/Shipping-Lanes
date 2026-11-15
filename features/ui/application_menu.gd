class_name ApplicationMenu
extends Control

signal selected(action: String)
## Aesthetics 5: the playful look (theme and the drawn backdrop).
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
## Patch 2.7 item 3: the mockup's text menu with the yellow swirl cursor.
const SWIRL = preload("res://features/ui/swirl_menu.gd")
## The pages drawn over the title backdrop, in the mockup's text style.
const MENU_PAGES: Array[String] = ["title", "options", "credits", "controls"]
## Mockup pixels (941 high): the first row's top and the words' left edge.
const LIST_TOP: float = 478.0
const LIST_LEFT: float = 165.0
var pages: Dictionary = {}
var first_buttons: Dictionary = {}
var timer_details: Label
var timer_button: Button
var session_revision: int = 0
var session_details: Label
var session_result: Label
var test_load_button: Button
var continue_button: Button
var save_notice: Label
var slot_picker: OptionButton
var slot_status: Label
var slot_result: Label
var recovery_confirmation: ConfirmationDialog
var play_button: Button
## The real game: Start begins a new game, or continues once a save exists.
var game_button: Button
var restart_button: Button
var restart_confirmation: ConfirmationDialog
## Test scenes and test saves. Shown only in developer mode (F3, see DevMode).
var dev_column: VBoxContainer
var footer: Label
var current_page: String = ""
## Patch 2.7 item 2: the arrived title screen (logo top-left, cruising ship)
## stands in for the drawn backdrop and heading on the home page.
var title_backdrop: TitleScreen
var backdrop: Control
var heading: Label
var home: VBoxContainer
var can_continue_session: bool = false
var controls_list: Control
var menu_font: Font

static func friends_client() -> bool:
	return OS.get_cmdline_user_args().has("--friends-client") or FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("friends-client.flag"))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = PLAYFUL.make()
	backdrop = PLAYFUL.Backdrop.new()
	add_child(backdrop)
	var title: Label = Label.new()
	heading = title
	title.text = "SHIPPING LANES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 36
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", PLAYFUL.SUN)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_shadow_color", PLAYFUL.INK)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 14)
	add_child(title)
	footer = Label.new()
	footer.text = "FRIENDS PLAYTEST" if friends_client() else "DEVELOPER MODE   /   F3 TO HIDE"
	footer.add_theme_font_size_override("font_size", 13)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(64, -40)
	add_child(footer)
	if friends_client():
		home = page("title")
		home.position.y = 210
		home.add_theme_constant_override("separation", 14)
		button(home, "SERVERS", "servers")
		button(home, "SETTINGS", "settings")
		button(home, "QUIT", "exit")
	else:
		# Patch 2.7 item 3: Start (new game or continue), Options, Credits, Quit Game.
		var list: Control = swirl_page("title")
		game_button = list.add_item("Start", "game")
		list.add_item("Options", "options")
		list.add_item("Credits", "credits")
		list.add_item("Quit Game", "exit")
		var options: Control = swirl_page("options", "title")
		options.add_item("Settings", "settings")
		options.add_item("Controls", "controls")
		# Patch 2.3 debug (temporary): a throwaway world with every ship. See features/debug.
		options.add_item("Debug Mode", "debug")
		# Shown only when there is a save to erase (see main.gd refresh_save_status).
		restart_button = options.add_item("Restart Progress", "restart")
		options.add_item("Back", "title")
		var credits: Control = swirl_page("credits", "title")
		credits.add_line("Shipping Lanes", 0.9, SWIRL.GOLD)
		credits.add_line("A game by Andy Viera", 0.6)
		credits.add_line("Made with the Godot Engine", 0.6)
		credits.add_line("Thanks for sailing!", 0.5)
		credits.add_item("Back", "title")
		controls_list = swirl_page("controls", "options")
		controls_list.add_item("Back", "options")
		restart_confirmation = ConfirmationDialog.new()
		restart_confirmation.title = "Restart progress?"
		restart_confirmation.dialog_text = "This erases your saved game: money, ship and jobs.\nIt cannot be undone."
		restart_confirmation.ok_button_text = "Erase and start over"
		restart_confirmation.confirmed.connect(func() -> void: selected.emit("confirm_restart"))
		add_child(restart_confirmation)
		# Everything else is a test fixture: developer mode only.
		dev_column = VBoxContainer.new()
		dev_column.position = Vector2(420, 112)
		dev_column.add_theme_constant_override("separation", 4)
		add_child(dev_column)
		label(dev_column, "DEVELOPER TESTS", 16)
		play_button = button(dev_column, "LOCAL SAVE TEST", "play")
		button(dev_column, "BOAT HANDLING TEST", "handling")
		button(dev_column, "HEAVY-LIFTER TEST", "heavy_lifter")
		button(dev_column, "PORT TEST", "ports")
		button(dev_column, "BULK PORT TEST", "bulk_ports")
		button(dev_column, "GAS PORT TEST", "gas_ports")
		button(dev_column, "LOCAL MULTIPLAYER TEST", "local_network")
		continue_button = button(dev_column, "CONTINUE TEST SESSION", "continue")
		button(dev_column, "SERVERS", "servers")
		button(dev_column, "LOCAL SAVES", "saves")
		for child: Node in dev_column.get_children():
			if child is Button: child.custom_minimum_size.y = 40
	save_notice = Label.new()
	save_notice.add_theme_font_size_override("font_size", 15)
	save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_notice.custom_minimum_size.x = 320
	save_notice.position = Vector2(64, 470)
	save_notice.size = Vector2(320, 180)
	if menu_font == null: menu_font = SWIRL.menu_font()
	save_notice.add_theme_font_override("font", menu_font)
	save_notice.add_theme_color_override("font_outline_color", SWIRL.NAVY)
	add_child(save_notice)
	add_to_group(DevMode.GROUP)
	dev_mode_changed()
	if friends_client(): return
	resized.connect(place_home)
	var saves: VBoxContainer = page("saves")
	saves.position.y = 135
	saves.add_theme_constant_override("separation", 6)
	label(saves, "LOCAL SAVES", 26)
	label(saves, "Private development progress only. Online accounts come later.", 16)
	slot_picker = OptionButton.new()
	for index: int in range(3): slot_picker.add_item("Local slot %d" % (index + 1))
	slot_picker.custom_minimum_size = Vector2(600, 42)
	saves.add_child(slot_picker)
	slot_picker.item_selected.connect(func(_index: int) -> void: selected.emit("select_slot"))
	slot_status = Label.new()
	slot_status.custom_minimum_size = Vector2(600, 74)
	slot_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	saves.add_child(slot_status)
	button(saves, "USE SELECTED SLOT", "use_slot")
	button(saves, "NEW GAME IN EMPTY SLOT", "new_slot")
	button(saves, "RECOVER BACKUP TO EMPTY SLOT", "recover_slot")
	button(saves, "BACK", "title")
	slot_result = Label.new()
	slot_result.custom_minimum_size.x = 600
	slot_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	saves.add_child(slot_result)
	recovery_confirmation = ConfirmationDialog.new()
	recovery_confirmation.title = "Recover local backup?"
	recovery_confirmation.ok_button_text = "Recover into empty slot"
	recovery_confirmation.confirmed.connect(func() -> void: selected.emit("confirm_recovery"))
	add_child(recovery_confirmation)
	var servers: VBoxContainer = page("servers")
	label(servers, "SERVERS", 26)
	label(servers, "Online servers are not connected yet.\nUse the local session to test the menus.", 18)
	button(servers, "LOCAL TEST SESSION", "play")
	button(servers, "BACK", "title")
	var playing: VBoxContainer = page("playing")
	label(playing, "LOCAL TEST SESSION", 26)
	label(playing, "Local development save. Use Boat Handling Test\nto sail your saved starter ship.\n\nEscape opens the session menu.", 18)
	button(playing, "SESSION MENU", "pause")
	session_details = Label.new()
	session_details.add_theme_font_size_override("font_size", 18)
	playing.add_child(session_details)
	test_load_button = button(playing, "LOAD TEST CONTAINER â€” 100 CREDITS", "test_load")
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
	button(paused, "REOPEN LOCAL SAVE", "play")
	button(paused, "RETURN TO MENU", "title")

func page(id: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(64, 170)
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	pages[id] = column
	return column

## A page in the mockup's text style; Esc goes to `back`.
func swirl_page(id: String, back: String = "") -> Control:
	var list: Control = SWIRL.new()
	if menu_font == null: menu_font = SWIRL.menu_font()
	list.font = menu_font
	add_child(list)
	list.back_action = back
	list.chosen.connect(func(action: String) -> void: selected.emit(action))
	pages[id] = list
	return list

## The Controls screen from Patch 2.5, as text under the logo.
func show_controls(rows: Array) -> void:
	controls_list.clear_lines()
	for row: Array in rows:
		var line: Label = controls_list.add_line("%s:  %s" % row, 0.42)
		controls_list.list.move_child(line, line.get_index() - 1)

func label(parent: Control, text: String, size: int) -> void:
	var item: Label = Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	parent.add_child(item)

func button(parent: Control, text: String, action: String) -> Button:
	var item: Button = Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(280, 50)
	item.add_theme_font_size_override("font_size", 21)
	item.pressed.connect(func() -> void: selected.emit(action))
	parent.add_child(item)
	if not first_buttons.has(parent):
		first_buttons[parent] = item
	return item

func show_page(id: String, can_continue: bool) -> void:
	current_page = id
	can_continue_session = can_continue
	dev_mode_changed()
	for key: String in pages:
		pages[key].visible = key == id
	if is_instance_valid(title_backdrop):
		var on: bool = id in MENU_PAGES
		title_backdrop.set_backdrop_visible(on)
		backdrop.visible = not on
		heading.visible = not on
	place_home()
	if id == "credits": pages.credits.roll()
	if pages.has(id) and id != "playing":
		if pages[id].has_method("focus_first"): pages[id].focus_first()
		else: first_buttons[pages[id]].grab_focus()

## Patch 2.7 item 4: Start's camera dive shows only the sea and the ship.
func clear_for_departure() -> void:
	for key: String in pages: pages[key].visible = false
	save_notice.visible = false
	footer.visible = false
	if dev_column != null: dev_column.visible = false
	get_viewport().gui_release_focus()

func use_title_backdrop(screen: TitleScreen) -> void:
	title_backdrop = screen
	show_page(current_page, can_continue_session)

## Patch 2.7 item 3: the text lists sit under the corner logo where the mockup
## has them, sized by screen height so 16:10 and ultrawide keep its look.
func place_home() -> void:
	if friends_client() or size.y <= 0.0: return
	var unit: float = size.y / SWIRL.MOCKUP_HEIGHT
	for id: String in MENU_PAGES:
		pages[id].position = Vector2(LIST_LEFT, LIST_TOP) * unit
		pages[id].layout(unit)
	# The save notice goes under the visible list; the developer list beside it.
	var rows: float = 4.0
	if current_page == "options": rows = 5.0 if restart_button.visible else 4.0
	save_notice.add_theme_font_size_override("font_size", maxi(13, roundi(19.0 * unit)))
	save_notice.add_theme_constant_override("outline_size", maxi(3, roundi(6.0 * unit)))
	save_notice.position = Vector2(LIST_LEFT, LIST_TOP + rows * SWIRL.ROW + 6.0) * unit
	save_notice.size = Vector2(maxf(320.0, 560.0 * unit), 0.0)
	save_notice.custom_minimum_size.x = save_notice.size.x
	dev_column.position = Vector2(maxf(470.0, 600.0 * unit), 112.0 + maxf(0.0, LIST_TOP * unit - 210.0))

## Called by DevMode when F3 is pressed, and whenever the page changes.
func dev_mode_changed() -> void:
	var dev: bool = DevMode.enabled and not friends_client()
	footer.visible = dev or friends_client()
	save_notice.visible = current_page in ["title", "options"] and not friends_client()
	if dev_column != null: dev_column.visible = dev and current_page == "title"
	if continue_button != null: continue_button.visible = can_continue_session

func show_session_state(snapshot: Dictionary, message: String) -> void:
	session_revision = snapshot.revision
	session_details.text = "TEST STATE  |  Credits: %s  |  Containers: %d" % [GameUnits.format_minor(snapshot.player.wallet_minor).value, snapshot.inventory.cargo.cargo_test_container]
	session_result.text = message

func show_timer(view: Dictionary) -> void:
	timer_details.text = "Timer: %s  |  Remaining: %.1f s" % [view.status, float(view.remaining_ms) / 1000.0]
