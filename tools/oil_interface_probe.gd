extends "res://features/ports/oil_port_test.gd"
var checks: int = 0
var failures: int = 0
var calls: Array[Dictionary] = []
var lose_next_reply: bool = false
var reject_next_expired: bool = false
var change_selection: bool = false

func check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(title)

func intercepted(request: Dictionary) -> Dictionary:
	calls.append(request.duplicate(true))
	if reject_next_expired and request.op == "oil_accept":
		reject_next_expired = false
		return {"ok": false, "code": "QUOTE_EXPIRED"}
	var result: Dictionary = await market_request(request)
	if change_selection and request.op == "oil_quote":
		change_selection = false
		oil_panel.quantity.value += 1
	if lose_next_reply and request.op == "oil_accept":
		lose_next_reply = false
		return {"ok": false, "code": "MARKET_UNAVAILABLE", "uncertain": true}
	return result

func _ready() -> void:
	super._ready()
	run.call_deferred()

func dock_at(index: int) -> void:
	docking.disconnect_owner(1)
	port = world_ports[index]
	ship.global_transform = port.berth_anchor.global_transform
	ship.velocity = Vector3.ZERO
	ship.zero_throttle()
	bind_port()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(docking.request_dock(1, service_id(), cargo_id()).ok, "real oil berth admission")
	docking.advance(1.1)
	check(context().docked, "real docking completes")

func run() -> void:
	while oil_panel.busy: await get_tree().process_frame
	oil_panel.send = intercepted
	check(not oil_panel.state.is_empty(), "actual HTTP snapshot received underway")
	check(oil_panel.prices.text.contains("UTC") and oil_panel.prices.text.contains("Slatewater"), "per-port timestamps visible")
	await oil_panel.request_quote()
	check(calls.is_empty(), "underway quote request cannot execute")
	await dock_at(0)
	oil_panel.quantity.value = 123
	await oil_panel.request_quote()
	check(not oil_panel.quote.is_empty() and oil_panel.terms.text.contains("123 barrels"), "custom quantity quote displayed")
	var original: Dictionary = oil_panel.quote.duplicate(true)
	await oil_panel.inspect()
	check(oil_panel.quote == original, "price refresh cannot replace displayed executable quote")
	oil_panel.quantity.value = 122
	check(oil_panel.quote.is_empty(), "quantity change invalidates accepted terms")
	oil_panel.quantity.value = 123
	change_selection = true
	await oil_panel.request_quote()
	check(oil_panel.quote.is_empty(), "late quote response cannot override changed selection")
	oil_panel.quantity.value = 123
	await oil_panel.request_quote()
	oil_panel.deadline = 0
	var before: int = calls.size()
	await oil_panel.accept_quote()
	check(calls.size() == before, "locally expired quote never sent")
	await oil_panel.request_quote()
	reject_next_expired = true
	await oil_panel.accept_quote()
	check(oil_panel.quote.is_empty() and calls.back().op == "oil_accept", "authority expiry rejection never auto-requotes")
	check(oil_panel.notice.text.contains("QUOTE_EXPIRED"), "expiry rejection explained")
	await oil_panel.request_quote()
	lose_next_reply = true
	await oil_panel.accept_quote()
	check(not oil_panel.pending.is_empty(), "lost committed response retains original intent")
	var retry: Dictionary = oil_panel.pending.duplicate(true)
	before = calls.size()
	await oil_panel.request_quote()
	await oil_panel.inspect()
	check(calls.size() == before, "uncertain outcome blocks new quote and snapshot")
	oil_panel.deadline = 0
	docking.disconnect_owner(1)
	docking.register(1, ship, port)
	await oil_panel.accept_quote()
	check(calls[before] == retry and oil_panel.pending.is_empty(), "explicit retry submits identical action quote and revision")
	check(oil_panel.state.lots[0].remaining_barrels == 123, "recovered purchase happens once")
	var acquisition: int = int(oil_panel.state.lots[0].acquisition_cost_minor)
	await dock_at(1)
	oil_panel.ports.select(1)
	oil_panel.ports.item_selected.emit(1)
	oil_panel.side.select(1)
	oil_panel.side.item_selected.emit(1)
	oil_panel.quantity.value = 50
	await oil_panel.request_quote()
	check(oil_panel.quote.side == "sell", "partial sale quote exists")
	await oil_panel.accept_quote()
	var lot: Dictionary = oil_panel.state.lots[0]
	check(lot.remaining_barrels == 73 and int(lot.remaining_cost_minor) + int(lot.sold_cost_minor) == acquisition, "partial sale reconciles remaining lot cost")
	check(oil_panel.receipt.text.contains("realized profit") and oil_panel.lots.text.contains("73/123"), "receipt and remaining lot presented")
	# Rebuild the actual panel against the same durable service (no in-memory inventory).
	var previous: Dictionary = oil_panel.state.duplicate(true)
	oil_scroll.remove_child(oil_panel)
	oil_panel.queue_free()
	oil_panel = preload("res://features/cargo/oil_market_panel.gd").new()
	oil_scroll.add_child(oil_panel)
	oil_panel.send = intercepted
	oil_panel.port_context = context
	await oil_panel.inspect()
	check(oil_panel.state.lots == previous.lots and oil_panel.state.money == previous.money, "panel reopen restores authoritative partial inventory and wallet")
	check(oil_panel.receipt.text.contains("Remaining 73 barrels"), "durable last receipt restored")
	oil_panel.ports.select(1)
	oil_panel.side.select(1)
	oil_panel.quantity.value = 73
	await oil_panel.request_quote()
	await oil_panel.accept_quote()
	check(oil_panel.state.lots.is_empty(), "final sale empties current lot")
	check(oil_panel.receipt.text.contains("remaining cost 0.00"), "final receipt has no stranded acquisition cost")
	oil_scroll.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not controls.menu_open, "closing prices restores helm input")
	print("OIL_INTERFACE_PASS checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
