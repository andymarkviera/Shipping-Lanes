extends "res://tools/oil_interface_probe.gd"
var lose_refinery_reply: bool = false
var refinery_calls: Array[Dictionary] = []

func refinery_transport(request: Dictionary) -> Dictionary:
	refinery_calls.append(request.duplicate(true))
	var result: Dictionary = await market_request(request)
	if lose_refinery_reply and request.op == "refinery_submit":
		lose_refinery_reply = false
		return {"ok": false, "code": "OUTCOME_UNKNOWN", "uncertain": true}
	return result

func run() -> void:
	while oil_panel.busy or refinery_panel.busy: await get_tree().process_frame
	refinery_panel.set_process(false)
	refinery_panel.send = refinery_transport
	await refinery_panel.inspect()
	check(refinery_panel.state.refinery_id == "refinery_slatewater_01", "one stable refinery")
	check(refinery_panel.summary.text.contains("yield 7/10"), "configured yield visible")
	await refinery_panel.submit()
	check(refinery_calls.size() == 1, "underway cannot submit")
	await dock_at(0)
	oil_panel.quantity.value = 3
	await oil_panel.request_quote()
	await oil_panel.accept_quote()
	check(oil_panel.state.lots.size() == 1, "purchase actual oil for refinery")
	await refinery_panel.inspect()
	await refinery_panel.submit()
	check(not refinery_calls.back().op == "refinery_submit", "wrong port cannot submit")
	await dock_at(1)
	await refinery_panel.inspect()
	refinery_panel.quantity.value = 1001
	lose_refinery_reply = true
	await refinery_panel.submit()
	check(not refinery_panel.pending.is_empty(), "lost committed submission retains request")
	var original: Dictionary = refinery_panel.pending.duplicate(true)
	await dock_at(0)
	await refinery_panel.submit()
	check(refinery_panel.pending.is_empty(), "retry succeeds after berth loss")
	check(refinery_calls[-2] == original, "retry preserves exact action quantity and revision")
	check(int(refinery_panel.state.lots[0].remaining_millibarrels) == 1999, "one atomic crude debit")
	check(refinery_panel.summary.text.contains("not propulsion fuel"), "cargo fuel distinguished")
	refinery_panel.hide()
	await get_tree().create_timer(1.5).timeout
	await refinery_panel.inspect()
	check(int(refinery_panel.state.owner.stock_millibarrels) == 700, "hidden panel does not stop host completion")
	check(int(refinery_panel.state.owner.remainder) == 7, "fraction saved exactly")
	check(refinery_panel.progress.value == 100, "completed progress comes from authority")
	var stock: int = int(refinery_panel.state.owner.stock_millibarrels)
	for i: int in range(20): refinery_panel.progress.value = i * 5
	await refinery_panel.inspect()
	check(int(refinery_panel.state.owner.stock_millibarrels) == stock, "visual progress cannot create output")
	refinery_panel.show()
	await dock_at(1)
	refinery_panel.quantity.value = 999
	await refinery_panel.submit()
	await get_tree().create_timer(1.5).timeout
	await refinery_panel.inspect()
	check(int(refinery_panel.state.owner.stock_millibarrels) == 1400 and int(refinery_panel.state.owner.remainder) == 0, "fraction carry conserved across submissions")
	await oil_panel.inspect()
	check(int(oil_panel.state.lots[0].remaining_millibarrels) == 1000, "oil panel sees remaining exact crude")
	check(oil_panel.receipt.text.contains("buy".capitalize()), "refinery receipt does not replace oil receipt")
	oil_scroll.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not controls.menu_open, "closing combined services releases helm")
	print("REFINERY_INTERFACE_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
