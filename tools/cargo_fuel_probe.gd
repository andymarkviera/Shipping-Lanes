extends "res://tools/oil_interface_probe.gd"
var lost_sale: bool = false

func fuel_transport(request: Dictionary) -> Dictionary:
	var result: Dictionary = await market_request(request)
	if lost_sale and request.op == "refinery_sell":
		lost_sale = false
		return {"ok": false, "code": "OUTCOME_UNKNOWN", "uncertain": true}
	return result

func run() -> void:
	while oil_panel.busy or refinery_panel.busy or not voyage_ready: await get_tree().process_frame
	refinery_panel.send = fuel_transport
	await refinery_panel.inspect()
	check(not refinery_panel.state.is_empty(), "cargo-fuel snapshot")
	await refinery_panel.execute_selected()
	check(refinery_panel.notice.text.contains("Dock"), "underway operation rejected")
	if refinery_panel.state.cargo_fuel.is_empty() and int(refinery_panel.state.money) == 20000:
		await dock_at(0)
		oil_panel.quantity.value = 3
		await oil_panel.request_quote()
		await oil_panel.accept_quote()
		await dock_at(1)
		await refinery_panel.inspect()
		refinery_panel.quantity.value = 3000
		refinery_panel.action.select(0)
		await refinery_panel.execute_selected()
		await get_tree().create_timer(3.3).timeout
		await refinery_panel.inspect()
		check(int(refinery_panel.state.owner.stock_millibarrels) == 2100, "processing output")
		refinery_panel.quantity.value = 2100
		refinery_panel.action.select(1)
		await refinery_panel.execute_selected()
		check(int(refinery_panel.quote.cost_minor) == 3, "fractional withdrawal fee reviewed")
		refinery_panel.action.select(2)
		await refinery_panel.execute_selected()
		refinery_panel.action.select(3)
		await refinery_panel.execute_selected()
		check(int(refinery_panel.state.cargo_fuel[0].remaining_millibarrels) == 2100, "loaded cargo fuel aboard")
		# Save a sailing boundary and exit; next process must restore it.
		docking.disconnect_owner(1)
		ship.global_position = Vector3(750, 0, -400)
		ship.rotation.y = 0.7
		ship.state.fuel_liters = 123.5
		ship.velocity = Vector3.ZERO
		ship.zero_throttle()
		await checkpoint_cargo_voyage()
		print("CARGO_FUEL_VOYAGE_LOADED checks=", checks, " failures=", failures)
	else:
		check(ship.global_position.distance_to(Vector3(750, 0, -400)) < 1, "restart restores underway position")
		check(is_equal_approx(ship.state.fuel_liters, 123.5), "restart restores propulsion fuel")
		check(int(refinery_panel.state.cargo_fuel[0].remaining_millibarrels) == 2100, "restart restores aboard cargo")
		await dock_at(0)
		await refinery_panel.inspect()
		var fuel_before: float = ship.state.fuel_liters
		var wallet_before: int = int(refinery_panel.state.money)
		refinery_panel.action.select(4)
		refinery_panel.quantity.value = 1001
		lost_sale = true
		await refinery_panel.execute_selected()
		check(not refinery_panel.pending.is_empty(), "lost sale reply retains request")
		await dock_at(1)
		await refinery_panel.execute_selected()
		check(refinery_panel.pending.is_empty(), "retry after berth loss recovers receipt")
		await dock_at(0)
		refinery_panel.quantity.value = 1099
		await refinery_panel.execute_selected()
		check(refinery_panel.state.cargo_fuel.is_empty(), "final sale removes lot")
		check(int(refinery_panel.state.money) == wallet_before + 672, "wallet adds exact 672 proceeds to saved post-purchase/fee balance")
		check(is_equal_approx(ship.state.fuel_liters, fuel_before), "partial sales never alter propulsion tank")
		print("CARGO_FUEL_VOYAGE_SOLD checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
