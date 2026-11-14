extends Control
## Patch 2.0 item 5: the game's simplified HUD. It lays out what the game scene
## (port_test.gd in game_mode) already owns and adds four small things:
## - the helm bar: an R / N / D throttle slider, the speed in knots and Dock;
## - a notice under the job card that shows for a few seconds and fades;
## - the job hub: one card per offer (what, from, to, pay, Accept).
## It owns no cargo, money or docking state. Test scenes never create it.
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const TOAST_SECONDS: float = 6.0
const BOX_COLOURS: Array[Color] = [Color("e2574c"), Color("3d9be0"), Color("ffc940"), Color("7ed957")]
var view: Node3D
var bar: PanelContainer
var slider: HSlider
var knots: Label
var dock_hint: Label
var dragging: bool = false
var toast: PanelContainer
var toast_text: String = ""
var toast_left: float = 0.0
var title: Label
var cards: VBoxContainer
var ships_button: Button

func setup(scene: Node3D) -> void:
	view = scene
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = PLAYFUL.make()
	build_bar()
	build_toast()
	arrange_port_card()

func text(parent: Node, size_px: int, colour: Color = Color.WHITE) -> Label:
	var node: Label = Label.new()
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", colour)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

## Bottom centre: [ R ---N--- D ]  12 kn  [Dock]
func build_bar() -> void:
	bar = PanelContainer.new()
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -20
	bar.offset_bottom = -20
	var column: VBoxContainer = VBoxContainer.new()
	bar.add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var throttle: VBoxContainer = VBoxContainer.new()
	throttle.custom_minimum_size.x = 230
	row.add_child(throttle)
	slider = HSlider.new()
	slider.min_value = -1.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.tick_count = 3
	slider.ticks_on_borders = true
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size.y = 24
	# A pointer, not a fill: neutral must not look half full.
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	slider.drag_started.connect(func() -> void: dragging = true)
	slider.drag_ended.connect(func(_changed: bool) -> void: dragging = false)
	slider.value_changed.connect(order)
	throttle.add_child(slider)
	var letters: HBoxContainer = HBoxContainer.new()
	throttle.add_child(letters)
	for letter: String in ["R", "N", "D"]:
		var mark: Label = text(letters, 18, PLAYFUL.CREAM)
		mark.text = letter
		mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mark.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][letters.get_child_count() - 1]
	knots = text(row, 28, PLAYFUL.SUN)
	knots.custom_minimum_size.x = 92
	knots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	knots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for item: Button in [view.dock_button, view.cancel_button]:
		item.reparent(row, false)
		item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.dock_button.custom_minimum_size = Vector2(104, 46)
	view.dock_button.add_theme_font_size_override("font_size", 19)
	dock_hint = text(column, 14, PLAYFUL.CREAM)
	dock_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func build_toast() -> void:
	toast = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	view.loading_text.reparent(toast, false)
	view.loading_text.custom_minimum_size.x = 290
	view.loading_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view.loading_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## The old top-left panel becomes the port card: shown only while docked (or
## while a heavy job needs its Lower and Raise buttons).
func arrange_port_card() -> void:
	var stack: Node = view.details.get_parent()
	title = text(stack, 22, PLAYFUL.SUN)
	stack.move_child(title, 0)
	view.readiness.hide()
	# The old button row held Dock, Cancel and Main menu. Dock and Cancel moved
	# to the helm bar; the main menu is behind Esc.
	view.switch_button.get_parent().hide()
	var tabs: Node = view.refuel_button.get_parent()
	for item: Node in tabs.get_children():
		if item is Button and item.text in ["CARGO", "Close services"]: item.hide()
		if item is Button and item.text == "SHIPS": ships_button = item
	view.offer_text.hide()
	view.jobs_list.hide()
	view.accept_button.hide()
	view.deliver_button.text = "Deliver"
	view.cancel_load_button.text = "Cancel loading"
	cards = VBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	view.jobs_panel.add_child(cards)
	view.jobs_panel.move_child(cards, 0)

func slider_order(value: float) -> float:
	var tuning: ShipDefinition = view.ship.definition
	return value * (tuning.forward_throttle_limit if value >= 0.0 else tuning.reverse_throttle_limit)

## The slider is a real control: drag or click it to set the engine order.
func order(value: float) -> void:
	if not is_instance_valid(view.ship) or not view.ship.helm_available(): return
	view.ship.command_throttle(0.0 if absf(value) < 0.06 else slider_order(value))

## One card per offer. Called by the scene whenever its job list changes.
func rebuild_cards() -> void:
	if cards == null: return
	for old: Node in cards.get_children():
		cards.remove_child(old)
		old.queue_free()
	var from: String = view.port.definition.display_name
	for job: Dictionary in view.job_cards:
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", PLAYFUL.box(PLAYFUL.DEEP, PLAYFUL.INK, 12, 2, 8))
		cards.add_child(card)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var art: Control = Control.new()
		art.custom_minimum_size = Vector2(58, 44)
		art.draw.connect(draw_cargo.bind(art, str(job.kind), int(job.count)))
		row.add_child(art)
		var words: VBoxContainer = VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.custom_minimum_size.x = 210
		row.add_child(words)
		text(words, 18).text = str(job.what)
		text(words, 13, PLAYFUL.CREAM).text = "%s → %s" % [from, job.to]
		var pay: Label = text(row, 20, PLAYFUL.SUN)
		pay.text = "+%.2f" % (int(job.pay) / 100.0)
		pay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var accept: Button = view.button(row, "Accept", take.bind(str(job.id)))
		accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func take(id: String) -> void:
	view.selected_offer = id
	view.accept_selected()

## A little picture of the load: a stack of boxes, a heap, or one big module.
func draw_cargo(art: Control, kind: String, count: int) -> void:
	var floor_y: float = art.size.y - 4
	if kind == "bulk":
		art.draw_colored_polygon(PackedVector2Array([Vector2(2, floor_y), Vector2(20, floor_y - 26), Vector2(34, floor_y - 18), Vector2(42, floor_y - 30), Vector2(56, floor_y)]), Color("c9a063"))
		art.draw_polyline(PackedVector2Array([Vector2(2, floor_y), Vector2(20, floor_y - 26), Vector2(34, floor_y - 18), Vector2(42, floor_y - 30), Vector2(56, floor_y), Vector2(2, floor_y)]), PLAYFUL.INK, 2, true)
		return
	if kind == "heavy":
		art.draw_rect(Rect2(8, floor_y - 30, 42, 30), Color("9fb2c4"))
		art.draw_rect(Rect2(8, floor_y - 30, 42, 30), PLAYFUL.INK, false, 2)
		art.draw_line(Vector2(29, floor_y - 30), Vector2(29, 2), PLAYFUL.INK, 2)
		return
	# Up to 15 boxes, five to a row from the bottom: a bigger job is a taller stack.
	for index: int in clampi(count, 1, 15):
		var box: Rect2 = Rect2(2 + (index % 5) * 11, floor_y - 12 - floori(index / 5.0) * 13, 10, 12)
		art.draw_rect(box, BOX_COLOURS[(index * 3 + floori(index / 5.0)) % BOX_COLOURS.size()])
		art.draw_rect(box, PLAYFUL.INK, false, 1.5)

func refresh(delta: float) -> void:
	var ship: HandlingShip = view.ship
	var state: String = view.docking.state(1)
	var docked: bool = state == "docked"
	# Helm bar.
	knots.text = "%d kn" % roundi(HandlingFeedback.instruments(ship).speed_knots)
	var commanded: float = ship.commanded_throttle
	if not dragging:
		slider.set_value_no_signal(commanded / maxf(0.01, ship.definition.forward_throttle_limit if commanded >= 0.0 else ship.definition.reverse_throttle_limit))
	slider.editable = ship.helm_available()
	var status: Dictionary = view.dock_status
	var near: bool = state in ["underway", "approaching"] and status.get("code", "") in ["SPEED", "BLOCKED"]
	dock_hint.text = str(status.get("message", "")) if near else ""
	dock_hint.visible = near
	view.dock_button.tooltip_text = "" if not view.dock_button.disabled or docked else "Sail up to a berth and slow down."
	# Patch 2.5 item 8: no key hints on the HUD. They live in Esc > CONTROLS.
	# Notice: shows when it changes, then fades. Loading progress stays up.
	var words: String = view.loading_text.text
	if words != toast_text:
		toast_text = words
		toast_left = TOAST_SECONDS
	toast_left = maxf(0.0, toast_left - delta)
	var held: bool = view.loading.busy() or (is_instance_valid(view.persistence) and view.persistence.blocked)
	toast.visible = not words.is_empty() and (held or toast_left > 0.0)
	toast.modulate.a = 1.0 if held else clampf(toast_left, 0.0, 1.0)
	# It sits under the job card on the right, clear of the port card and the helm.
	toast.reset_size()
	toast.position = Vector2(size.x - 20 - toast.size.x, view.voyage_hud.position.y + view.voyage_hud.size.y + 10)
	# Port card.
	view.port_panel.visible = docked or view.heavy_controls.visible or DevMode.enabled
	title.text = view.port.definition.display_name.to_upper()
	title.visible = docked
	view.navigation.visible = not view.navigation.text.is_empty()
	view.jobs_panel.visible = docked and not view.ships_panel.visible
	if ships_button != null: ships_button.text = "JOBS" if view.ships_panel.visible else "SHIPS"
	cards.visible = view.accept_reason().is_empty()
	# Deliver shows only where it works; elsewhere the line below says where to go.
	view.deliver_button.visible = view.abandon_button.visible and not view.deliver_button.disabled
	view.receipt_label.hide()
