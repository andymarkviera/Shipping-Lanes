extends PanelContainer
## Read-only online voyage state plus bounded commands; no local settlement.
var session: Node
var installed_binding: Dictionary = {}
var heading: Label
var status: Label
var receipt: Label
var list: ItemList
var accept: Button
var deliver: Button
var cancel: Button
var cargo_contents: VBoxContainer
var fuel_contents: VBoxContainer
var fuel_amount: SpinBox
var fuel_text: Label
var fuel_buy: Button
var recover_button: Button
var displayed_quote: String = ""
var services: VBoxContainer
var selected: String = ""
var signature: String = ""
var waiting: int = 0
var sent_ms: int = 0
var confirm_until: int = 0
var confirm_job: String = ""

func label(parent: Node) -> Label:
	var item := Label.new()
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func button(parent: Node, title: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = title
	item.focus_mode = Control.FOCUS_NONE
	parent.add_child(item)
	item.pressed.connect(action)
	return item

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -400
	offset_right = -20
	offset_top = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243642")
	for edge: String in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 12)
	add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	add_child(stack)
	heading = label(stack)
	status = label(stack)
	recover_button = button(stack, "Recover ship", recover_ship)
	services = VBoxContainer.new()
	stack.add_child(services)
	button(services, "CARGO", func(): cargo_contents.show(); fuel_contents.hide())
	cargo_contents = VBoxContainer.new()
	services.add_child(cargo_contents)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(350, 95)
	list.add_theme_font_size_override("font_size", 14)
	list.focus_mode = Control.FOCUS_NONE
	cargo_contents.add_child(list)
	for child: Node in list.get_children(true):
		if child is ScrollBar: child.focus_mode = Control.FOCUS_NONE
	list.item_selected.connect(func(index: int): selected = list.get_item_metadata(index); list.release_focus())
	accept = button(cargo_contents, "Accept selected job", func(): send("accept"))
	deliver = button(cargo_contents, "Deliver cargo", func(): send("deliver"))
	cancel = button(cargo_contents, "Cancel loading", cancel_job)
	button(services, "REFUEL", func(): cargo_contents.hide(); fuel_contents.show())
	fuel_contents = VBoxContainer.new()
	services.add_child(fuel_contents)
	fuel_contents.hide()
	fuel_text = label(fuel_contents)
	fuel_amount = SpinBox.new()
	fuel_amount.min_value = 1
	fuel_amount.max_value = 1000
	fuel_amount.step = 1
	fuel_amount.value = 10
	fuel_amount.suffix = "L"
	fuel_amount.update_on_text_changed = true
	fuel_contents.add_child(fuel_amount)
	fuel_buy = button(fuel_contents, "Buy propulsion fuel", buy_fuel)
	receipt = label(stack)

func send(action: String, abandon: bool = false) -> void:
	if session == null or waiting > 0 or session.voyage_snapshot.get("busy", false): return
	session.send_voyage(action, selected if action == "accept" else "", abandon)
	waiting = session.voyage_sequence
	sent_ms = Time.get_ticks_msec()

func recover_ship() -> void:
	if recover_button.disabled or waiting > 0: return
	var recovery: Dictionary = session.voyage_snapshot.get("recovery", {})
	if recovery.get("state") != "pending": return
	session.send_recover(recovery.id)
	waiting = session.voyage_sequence
	sent_ms = Time.get_ticks_msec()

func buy_fuel() -> void:
	if fuel_buy.disabled or waiting > 0 or displayed_quote.is_empty(): return
	session.send_refuel(displayed_quote, int(fuel_amount.value))
	waiting = session.voyage_sequence
	sent_ms = Time.get_ticks_msec()

func cancel_job() -> void:
	var job: Dictionary = session.voyage_snapshot.get("job", {})
	if job.get("state") != "loaded": send("cancel"); return
	if confirm_job == job.id and Time.get_ticks_msec() < confirm_until:
		send("cancel", true)
		confirm_job = ""
	else:
		confirm_job = job.id
		confirm_until = Time.get_ticks_msec() + 5000

static func port_name(id: String) -> String:
	return "Brindle Quay" if id == "port_brindle_quay" else "Slatewater Works"

func refresh_choices(rows: Array) -> void:
	var next: String = JSON.stringify(rows)
	if next == signature: return
	signature = next
	list.clear()
	var index: int = 0
	for row: Dictionary in rows:
		list.add_item("%d container%s · %s · %.2f cr" % [row.quantity, "" if row.quantity == 1 else "s", "Brindle" if row.destination == "port_brindle_quay" else "Slatewater", row.reward / 100.0])
		list.set_item_metadata(list.item_count - 1, row.id)
		if row.id == selected: index = list.item_count - 1
	selected = ""
	if list.item_count > 0:
		list.select(index)
		selected = list.get_item_metadata(index)

func _process(_delta: float) -> void:
	visible = session != null and not session.binding.is_empty()
	if not visible:
		waiting = 0
		return
	if installed_binding != session.binding:
		installed_binding = session.binding.duplicate()
		waiting = 0
		confirm_job = ""
	var data: Dictionary = session.voyage_snapshot
	var fresh: bool = not data.is_empty() and Time.get_ticks_msec() - session.voyage_received_ms < 2000
	var job: Dictionary = data.get("job", {})
	if int(data.get("ack", 0)) >= waiting and not data.get("busy", false): waiting = 0
	var pending: bool = waiting > 0 or data.get("busy", false)
	heading.text = "ONLINE VOYAGE · %.2f credits" % (int(data.get("wallet", 0)) / 100.0)
	var docked: bool = session.dock_snapshot.get("state") == "docked"
	var recovery: Dictionary = data.get("recovery", {})
	var sunk: bool = recovery.get("state") == "pending"
	recover_button.visible = sunk
	recover_button.disabled = not fresh or pending
	recover_button.text = "Recover ship — fee already recorded"
	services.visible = docked and fresh and not sunk
	refresh_choices(data.get("offers", []))
	var quote: Dictionary = data.get("refuel", {})
	displayed_quote = str(quote.get("id", ""))
	var liters: int = int(fuel_amount.value)
	var cost: int = liters * int(quote.get("unit_price_minor", 0))
	fuel_buy.disabled = pending or not fresh or not docked or quote.is_empty() or liters < 1 or liters > int(quote.get("max_liters", 0)) or cost > int(data.get("wallet", 0))
	fuel_amount.editable = not pending
	fuel_text.text = "Propulsion tank fuel only. Not cargo fuel."
	if quote.is_empty(): fuel_text.text += "\nRefueling unavailable while loading or at this berth."
	else:
		fuel_text.text += "\nTank: %.1f / %.0f L · Space: %d whole L\n%.2f credits/L · Total: %.2f credits" % [quote.fuel, quote.capacity, quote.max_liters, quote.unit_price_minor / 100.0, cost / 100.0]
		if liters > int(quote.max_liters): fuel_text.text += "\nChoose fewer liters; not enough tank space."
		elif cost > int(data.get("wallet", 0)): fuel_text.text += "\nNot enough credits."
	fuel_buy.text = "Buy %d L · %.2f credits" % [liters, cost / 100.0]
	accept.disabled = pending or not job.is_empty() or selected.is_empty()
	accept.tooltip_text = "Finish your current job first." if not job.is_empty() else ""
	deliver.visible = job.get("state") == "loaded"
	deliver.disabled = pending or job.get("destination") != data.get("port")
	deliver.tooltip_text = "Dock at the job destination." if deliver.disabled else ""
	cancel.visible = not job.is_empty()
	cancel.disabled = pending
	cancel.text = "Cancel loading" if job.get("state") == "loading" else ("Confirm abandon — no payment" if job.get("id") == confirm_job and Time.get_ticks_msec() < confirm_until else "Abandon cargo — no payment")
	status.text = "Cargo aboard: %d container%s" % [int(data.get("cargo", 0)), "" if int(data.get("cargo", 0)) == 1 else "s"]
	if job.is_empty(): status.text += "\nDock, open CARGO and choose one job."
	else:
		status.text += "\nDestination: " + port_name(job.destination)
		if session.world_view.ports.has(job.destination):
			var destination: Node3D = session.world_view.ports[job.destination]
			status.text += " · %.0f m" % destination.berth_anchor.global_position.length()
		status.text += "\nJob payment: %.2f credits" % (job.reward_minor / 100.0)
		if job.state == "loading": status.text += "\nLoading · %d s remaining. Stay docked." % ceili(int(data.get("remaining_ms", 0)) / 1000.0)
		else: status.text += "\n" + ("Select Deliver cargo." if docked and data.get("port") == job.destination else "Sail to the destination, stop and dock.")
	status.text += "\nHull: %.0f%%" % (int(data.get("condition_bp", 10000)) / 100.0)
	var debt: int = int(data.get("recovery_debt_minor", 0))
	if debt > 0: status.text += "\nRecovery balance: %.2f credits\nHalf of future delivery earnings repays this balance." % (debt / 100.0)
	if sunk:
		status.text = "SHIP SUNK · Cargo lost, ship ownership retained.\nRecovery fee: %.2f credits\nPaid: %.2f · Added to balance: %.2f\nRecovery includes hull restoration and at least 100 L propulsion fuel." % [int(recovery.fee_minor) / 100.0, int(recovery.paid_minor) / 100.0, int(recovery.debt_added_minor) / 100.0]
		if debt > 0: status.text += "\nBalance owed: %.2f credits; half of future delivery earnings repays it." % (debt / 100.0)
	elif data.get("recovery_placing", false): status.text += "\nWaiting for clear water before releasing the ship."
	elif data.get("damage_pending", false): status.text += "\nImpact detected. Saving hull damage…"
	if not fresh: status.text += "\nWaiting for current server voyage state…"
	elif pending: status.text += "\n" + ("Request unconfirmed. Reconnect to recover safely." if waiting > 0 and Time.get_ticks_msec() - sent_ms > 8000 else "Waiting for server…")
	elif not data.get("message", "").is_empty(): status.text += "\n" + data.message
	var last: Dictionary = data.get("receipt", {})
	receipt.visible = not last.is_empty()
	if not last.is_empty(): receipt.text = "LAST DELIVERY RECEIPT\n%d containers · %s\nPaid %.2f credits" % [last.quantity, port_name(last.destination), last.amount / 100.0]
	if not last.is_empty() and int(last.get("repaid", 0)) > 0: receipt.text += "\nRecovery balance repaid: %.2f credits" % (int(last.repaid) / 100.0)
