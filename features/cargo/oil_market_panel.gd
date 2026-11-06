extends VBoxContainer
## Transport is supplied by the trusted scene/host. Never owns prices or settlement.
var send: Callable
var port_context: Callable
var busy: bool = false
var quote: Dictionary = {}
var pending: Dictionary = {}
var state: Dictionary = {}
var deadline: int = 0
var revision: int = 0
var ports: OptionButton
var side: OptionButton
var quantity: SpinBox
var prices: Label
var terms: Label
var lots: Label
var receipt: Label
var notice: Label
var refresh_button: Button
var quote_button: Button
var accept_button: Button
const PORT_IDS: Array[String] = ["port_brindle_quay", "port_slatewater_works"]

func _ready() -> void:
	custom_minimum_size.x = 440
	prices = label("Inspect prices at either port, including while underway.")
	refresh_button = button("Refresh port prices", inspect)
	ports = OptionButton.new()
	ports.add_item("Brindle Quay")
	ports.add_item("Slatewater Works")
	add_child(ports)
	side = OptionButton.new()
	side.add_item("Buy oil")
	side.add_item("Sell current lot")
	add_child(side)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 200
	quantity.step = 1
	quantity.value = 50
	quantity.suffix = " whole barrels"
	add_child(quantity)
	lots = label("No inventory received.")
	quote_button = button("Request quote for review", request_quote)
	terms = label("Reference prices are indicative. Request and review an exact quote.")
	accept_button = button("Accept displayed quote", accept_quote)
	notice = label("")
	receipt = label("")
	ports.item_selected.connect(func(_i: int): invalidate())
	side.item_selected.connect(func(_i: int): invalidate())
	quantity.value_changed.connect(func(_v: float): invalidate())

func label(value: String) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(node)
	return node

func button(value: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.pressed.connect(action)
	add_child(node)
	return node

static func money(value: int) -> String:
	return "%s%d.%02d" % ["-" if value < 0 else "", absi(value) / 100, absi(value) % 100]

static func stamp(value: int) -> String:
	return Time.get_datetime_string_from_unix_time(value).replace("T", " ") + " UTC"

func invalidate() -> void:
	quote.clear()
	deadline = 0
	terms.text = "Selection changed. Request and review a new quote."

func selected_lot() -> String:
	var rows: Array = state.get("lots", [])
	return str(rows[0].id) if side.selected == 1 and not rows.is_empty() else ""

func _process(_delta: float) -> void:
	if accept_button == null: return
	var retry: bool = not pending.is_empty()
	var context: Dictionary = port_context.call() if port_context.is_valid() else {}
	var docked_here: bool = context.get("docked", false) and context.get("port_id", "") == PORT_IDS[ports.selected]
	refresh_button.disabled = busy or retry or not send.is_valid()
	quote_button.disabled = busy or retry or state.is_empty() or not docked_here
	ports.disabled = busy or retry
	side.disabled = busy or retry
	quantity.editable = not busy and not retry
	accept_button.text = "Retry original trade (outcome unknown)" if retry else "Accept displayed quote"
	accept_button.disabled = busy or (not retry and (quote.is_empty() or Time.get_ticks_msec() >= deadline or not docked_here))
	if not quote.is_empty() and not retry:
		var remaining: int = maxi(0, deadline - Time.get_ticks_msec())
		notice.text = "Quote expired. Request and review new terms." if remaining == 0 else "Frozen quote · %d seconds remaining%s" % [ceili(remaining / 1000.0), " · dock at this port to accept" if not docked_here else ""]

func inspect() -> void:
	if busy or not pending.is_empty() or not send.is_valid(): return
	busy = true
	var result: Dictionary = await send.call({"op": "oil_snapshot"})
	busy = false
	if not result.get("ok", false):
		notice.text = "Prices unavailable. Previous timestamps remain visible; no replacement prices."
		return
	state = result.duplicate(true)
	revision = int(result.revision)
	var lines: PackedStringArray = []
	for port_id: String in PORT_IDS:
		var row: Dictionary = result.market.ports[port_id]
		lines.append("%s: %s credits/barrel · observed %s" % ["Brindle Quay" if port_id == PORT_IDS[0] else "Slatewater Works", money(int(row.reference_minor)), stamp(int(row.observed_at))])
	prices.text = "REFERENCE PRICES (not executable quotes)\n" + "\n".join(lines)
	show_inventory()
	if not result.get("last_receipt", {}).is_empty(): show_receipt(result.last_receipt)
	notice.text = "Prices updated. Existing quoted terms are unchanged."

func show_inventory() -> void:
	lots.text = "Wallet: %s credits" % money(int(state.get("money", 0)))
	for lot: Dictionary in state.get("lots", []):
		lots.text += "\nLot %s · %d/%d barrels remaining\nAcquisition cost %s · sold cost %s · remaining cost %s\nCumulative realized profit %s credits" % [lot.id, lot.remaining_barrels, lot.acquired_barrels, money(int(lot.acquisition_cost_minor)), money(int(lot.sold_cost_minor)), money(int(lot.acquisition_cost_minor) - int(lot.sold_cost_minor)), money(int(lot.proceeds_minor) - int(lot.sold_cost_minor))]

func request_quote() -> void:
	if busy or not pending.is_empty() or state.is_empty() or not send.is_valid(): return
	var context: Dictionary = port_context.call()
	if not context.get("docked", false) or context.port_id != PORT_IDS[ports.selected]: return
	invalidate()
	busy = true
	# Capture revision at issuance. Later snapshot refresh cannot change acceptance intent.
	var expected: int = revision
	var started: int = Time.get_ticks_msec()
	var intent: Dictionary = {"op": "oil_quote", "port_id": PORT_IDS[ports.selected], "side": "buy" if side.selected == 0 else "sell", "barrels": int(quantity.value), "lot_id": selected_lot()}
	var result: Dictionary = await send.call(intent)
	busy = false
	if not result.get("ok", false):
		notice.text = "Quote rejected: " + str(result.get("code", "MARKET_UNAVAILABLE"))
		return
	if intent.port_id != PORT_IDS[ports.selected] or intent.barrels != int(quantity.value) or intent.side != ("buy" if side.selected == 0 else "sell") or intent.lot_id != selected_lot():
		invalidate()
		return
	quote = result.quote.duplicate(true)
	quote["expected_revision"] = expected
	# Monotonic conservative countdown includes request latency; local wall clock is irrelevant.
	deadline = started + maxi(0, int(quote.expires_at) - int(result.server_time)) * 1000
	terms.text = "%s %d barrels at %s credits/barrel\nTotal: %s credits · %s\nIssued %s · expires %s\nQuote %s · version %d" % [str(quote.side).capitalize(), quote.barrels, money(int(quote.unit_minor)), money(int(quote.total_minor)), ports.get_item_text(ports.selected), stamp(int(quote.issued_at)), stamp(int(quote.expires_at)), quote.id, quote.version]

func accept_quote() -> void:
	if busy or not send.is_valid(): return
	if pending.is_empty():
		var context: Dictionary = port_context.call()
		if quote.is_empty() or Time.get_ticks_msec() >= deadline or not context.get("docked", false) or context.port_id != quote.port: return
		pending = {"op": "oil_accept", "action_id": Crypto.new().generate_random_bytes(16).hex_encode(), "expected_revision": int(quote.expected_revision), "quote_id": quote.id, "quote_version": int(quote.version), "port_id": quote.port}
	busy = true
	var result: Dictionary = await send.call(pending.duplicate(true))
	busy = false
	if result.get("uncertain", false) or result.get("code", "") in ["MARKET_UNAVAILABLE", "BACKEND_UNAVAILABLE", "OUTCOME_UNKNOWN"]:
		notice.text = "Trade outcome unknown. Retry keeps the original action and quote; no new trade is allowed."
		return
	pending.clear()
	invalidate()
	if result.get("ok", false):
		show_receipt(result)
		await inspect()
		show_receipt(result)
	else:
		notice.text = "Trade rejected: %s. Refresh, then explicitly request and review a new quote." % result.get("code", "INVALID_RESPONSE")

func show_receipt(result: Dictionary) -> void:
	var q: Dictionary = result.quote
	var lot: Dictionary = result.lot
	var cost: int = int(lot.get("allocated_cost_minor", 0))
	receipt.text = "LAST TRADE RECEIPT · %s%s\n%s %d barrels · %s credits/barrel · total %s\nAllocated acquisition cost %s · realized profit %s\nDebt repaid %s · wallet change %s\nRemaining %d barrels · remaining cost %s credits" % [result.action_id, " (recovered; no additional payment)" if result.get("duplicate", false) else "", str(q.side).capitalize(), q.barrels, money(int(q.unit_minor)), money(int(q.total_minor)), money(cost), money(int(q.total_minor) - cost if q.side == "sell" else 0), money(int(result.get("recovery_repaid_minor", 0))), money(int(result.amount)), lot.remaining_barrels, money(int(lot.acquisition_cost_minor) - int(lot.sold_cost_minor))]
