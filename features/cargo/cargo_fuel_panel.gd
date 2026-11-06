extends VBoxContainer
## Cargo fuel only: no propulsion refuel request is available here.
const REFINERY_ID := "refinery_slatewater_01"
const LOAD_PORT := "port_slatewater_works"
const SALE_PORT := "port_brindle_quay"
var send: Callable
var port_context: Callable
var busy: bool = false
var pending: Dictionary = {}
var state: Dictionary = {}
var quote: Dictionary = {}
var quantity: SpinBox
var summary: Label
var notice: Label
var action: OptionButton
var execute_button: Button

func _ready() -> void:
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 200000
	quantity.step = 1
	quantity.value = 1000
	quantity.suffix = " millibarrels (1000 = 1 barrel)"
	quantity.value_changed.connect(func(_value: float): quote.clear())
	add_child(quantity)
	action = OptionButton.new()
	for title: String in ["Refine crude at Slatewater", "Quote cargo-fuel withdrawal", "Accept quoted withdrawal", "Load cargo fuel at Slatewater", "Sell cargo fuel at Brindle"]:
		action.add_item(title)
	add_child(action)
	execute_button = Button.new()
	execute_button.text = "Execute selected cargo operation"
	execute_button.pressed.connect(execute_selected)
	add_child(execute_button)
	var refresh := Button.new()
	refresh.text = "Refresh cargo fuel"
	refresh.pressed.connect(inspect)
	add_child(refresh)
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)

func _process(_delta: float) -> void:
	quantity.editable = not busy and pending.is_empty()
	action.disabled = busy or not pending.is_empty()
	execute_button.disabled = busy or not send.is_valid()
	execute_button.text = "Retry identical cargo operation" if not pending.is_empty() else "Execute selected cargo operation"

func inspect() -> void:
	if busy or not pending.is_empty() or not send.is_valid(): return
	busy = true
	var result: Dictionary = await send.call({"op": "refinery_snapshot", "refinery_id": REFINERY_ID})
	busy = false
	if not result.get("ok", false):
		notice.text = "Cargo fuel unavailable: " + str(result.get("code"))
		return
	state = result
	summary.text = "CARGO FUEL · separate from propulsion fuel\nWallet: %d minor credits · capacity: %d millibarrels\nRefinery stock: %d · sale: %d minor credits/barrel at Brindle\nHandling fee is not total production cost. Refresh after processing." % [int(state.money), int(state.cargo_fuel_capacity), int(state.owner.stock_millibarrels), int(state.price_minor_per_barrel)]
	for item: Dictionary in state.collections:
		summary.text += "\nCollection %s: %d waiting" % [item.action_id, int(item.millibarrels) - int(item.get("loaded_millibarrels", 0))]
	for lot: Dictionary in state.cargo_fuel:
		summary.text += "\nAboard %s: %d millibarrels · sale price %d/barrel" % [lot.id, int(lot.remaining_millibarrels), int(lot.price_minor_per_barrel)]

func execute_selected() -> void:
	if busy or not send.is_valid(): return
	if pending.is_empty():
		if state.is_empty(): return
		var context: Dictionary = port_context.call()
		var selected: int = action.selected
		var port_id: String = SALE_PORT if selected == 4 else LOAD_PORT
		if not context.get("docked", false) or context.get("port_id") != port_id:
			notice.text = "Dock at the eligible pipeline first."
			return
		var ops: Array[String] = ["refinery_submit", "refinery_quote", "refinery_withdraw", "refinery_load", "refinery_sell"]
		pending = {"op": ops[selected], "refinery_id": REFINERY_ID, "port_id": port_id}
		if selected != 1:
			pending.merge({"action_id": Crypto.new().generate_random_bytes(16).hex_encode(), "expected_revision": int(state.revision)})
		if selected == 0:
			if state.crude_lots.is_empty(): pending.clear(); return
			pending.merge({"lot_id": state.crude_lots[0].id, "input_millibarrels": int(quantity.value)})
		elif selected == 2:
			if quote.is_empty(): pending.clear(); return
			pending["quote_id"] = quote.id
		else:
			pending["millibarrels"] = int(quantity.value)
			if selected == 3:
				if state.collections.is_empty(): pending.clear(); return
				pending["collection_id"] = state.collections[0].action_id
			if selected == 4:
				if state.cargo_fuel.is_empty(): pending.clear(); return
				pending["lot_id"] = state.cargo_fuel[0].id
	busy = true
	var result: Dictionary = await send.call(pending.duplicate(true))
	busy = false
	if result.get("uncertain", false) or result.get("code") in ["MARKET_UNAVAILABLE", "REFINERY_UNAVAILABLE", "OUTCOME_UNKNOWN"]:
		notice.text = "Outcome unknown. Retry the identical operation."
		return
	pending.clear()
	notice.text = str(result.get("code"))
	if result.get("code") == "REFINERY_QUOTE":
		quote = result.quote
		notice.text = "Review withdrawal: %d millibarrels, %d minor credit handling fee. Select Accept quoted withdrawal." % [int(quote.millibarrels), int(quote.cost_minor)]
	elif result.get("code") == "CARGO_FUEL_SOLD":
		notice.text = "Sold: gross %d, debt repaid %d, wallet change +%d minor credits. Propulsion tank unchanged." % [int(result.gross_minor), int(result.debt_repayment_minor), int(result.amount)]
	await inspect()
