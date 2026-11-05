extends VBoxContainer
## Read-only presentation; signals carry intent, never time or economic results.
signal load_requested(id: String)
signal discharge_requested(quantity: int)
signal cancel_requested
const Bulk = preload("res://features/cargo/bulk_earnings.gd")
var family: String = "bulk"
var model = Bulk.new()
var commodities: OptionButton
var holds: OptionButton
var quantity: SpinBox
var quote: Label
var status: Label
var receipt: Label
var load_button: Button
var discharge_button: Button
var cancel_button: Button
var crane: Control
var rows: Array[Dictionary] = []
var selected_id: String = ""
var progress: float = 0.0
var operation: String = ""

func _ready() -> void:
	model = Bulk.new(family)
	custom_minimum_size.x = 440
	commodities = OptionButton.new()
	for name_: String in (["LNG", "Nitrogen", "Oxygen", "Argon"] if family == "gas" else ["Grain", "Coal", "Ore", "Limestone"]): commodities.add_item(name_)
	add_child(commodities)
	holds = OptionButton.new()
	if family == "gas":
		holds.add_item("LNG tank — 400 m³")
		holds.add_item("Forward tank — 600 m³")
		holds.add_item("Aft tank — 600 m³")
	else:
		holds.add_item("Forward hold — 400 t")
		holds.add_item("Aft hold — 600 t")
	add_child(holds)
	quote = Label.new()
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(quote)
	load_button = make_button("Accept quote and load", func(): load_requested.emit(selected_id))
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 1000000000
	quantity.step = 1
	quantity.value = 50 if family == "gas" else 50000000
	quantity.suffix = " m³ to discharge" if family == "gas" else " g to discharge"
	add_child(quantity)
	discharge_button = make_button("Unload selected m³" if family == "gas" else "Unload selected grams", func(): discharge_requested.emit(int(quantity.value)))
	cancel_button = make_button("Cancel current service", func(): cancel_requested.emit())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	crane = Control.new()
	crane.custom_minimum_size = Vector2(420, 65)
	crane.draw.connect(draw_crane)
	add_child(crane)
	receipt = Label.new()
	receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(receipt)
	commodities.item_selected.connect(func(_index: int): select_quote())
	holds.item_selected.connect(func(_index: int): select_quote())

func make_button(title: String, action: Callable) -> Button:
	var node = Button.new()
	node.text = title
	add_child(node)
	node.pressed.connect(action)
	return node

func select_quote() -> void:
	selected_id = ""
	var cargo: String = model.commodities[commodities.selected]
	var hold: String = (["tank_lng", "tank_forward", "tank_aft"] if family == "gas" else ["hold_forward", "hold_aft"])[holds.selected]
	for row: Dictionary in rows:
		if row.cargo_id == cargo and row[model.allocation_key] == hold and row.state == "available":
			selected_id = row.id
			quote.text = model.format_quote(row)
			if family == "gas": quote.text += "\nPipeline: " + ("LNG" if row.cargo_id == "cargo_gas_lng" else "industrial cryogenic")
			return
	quote.text = "No compatible remaining quote for this commodity and allocation at this port."

func refresh(state: Dictionary, available: Array[Dictionary], docked: bool) -> void:
	rows = available.duplicate(true)
	select_quote()
	operation = state.operation
	progress = clampf(state.progress, 0, 1)
	var busy: bool = not operation.is_empty()
	var job: Dictionary = state.job
	load_button.disabled = state.blocked or not docked or busy or not job.is_empty() or selected_id.is_empty()
	commodities.disabled = busy or not job.is_empty()
	holds.disabled = commodities.disabled
	discharge_button.disabled = state.blocked or not docked or busy or job.get("state") != "loaded" or not state.get("at_destination", false)
	quantity.editable = not discharge_button.disabled
	if job.get("state") == "loaded": quantity.max_value = job.quantity - job[model.cumulative_key]
	cancel_button.disabled = state.blocked or not busy
	status.text = "%s %.0f%%" % ["Loading" if state.kind == "load" else "Unloading", progress * 100] if busy else state.notice
	if not job.is_empty():
		quote.text = model.format_quote(job)
		if family == "gas": quote.text += "\nPipeline: " + ("LNG" if job.cargo_id == "cargo_gas_lng" else "industrial cryogenic")
		var remaining: String = "%d m³" % (job.quantity - job[model.cumulative_key]) if family == "gas" else "%.6f t" % ((job.quantity - job[model.cumulative_key]) / 1000000.0)
		status.text += "\n%s · %s · %s remaining\n%s → %s" % [job.cargo_id.trim_prefix("cargo_" + family + "_"), job[model.allocation_key], remaining, job.origin_port_id.trim_prefix("port_"), job.destination_port_id.trim_prefix("port_")]
	receipt.text = "" if state.receipt.is_empty() else model.format_receipt(state.receipt)
	crane.visible = busy
	crane.queue_redraw()

func draw_crane() -> void:
	# Decorative progress derives only from the last committed authority sample.
	if family == "gas":
		crane.draw_line(Vector2(35, 32), Vector2(390, 32), Color.DIM_GRAY, 12)
		crane.draw_line(Vector2(35, 32), Vector2(35 + 355 * progress, 32), Color.SKY_BLUE, 8)
		return
	crane.draw_line(Vector2(35, 60), Vector2(35, 8), Color.GOLD, 5)
	crane.draw_line(Vector2(35, 8), Vector2(390, 8), Color.GOLD, 5)
	var x: float = lerpf(50, 375, progress)
	crane.draw_line(Vector2(x, 8), Vector2(x, 38), Color.WHITE, 2)
	crane.draw_rect(Rect2(x - 9, 38, 18, 12), Color.SANDY_BROWN)
