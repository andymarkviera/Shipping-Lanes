extends "res://features/ports/port_test.gd"
## Private operator fixture only. The launcher owns durable market/profile storage.
var oil_panel: VBoxContainer
var refinery_panel: VBoxContainer
var oil_scroll: ScrollContainer
var endpoint: String
var token: String
var voyage_ready: bool = false
var checkpoint_busy: bool = false
var checkpoint_seconds: float = 0.0

func create_ship() -> HandlingShip:
	var body: HandlingShip = super.create_ship()
	body.definition = body.definition.duplicate(true)
	body.definition.id = "ship_oil_prototype_01"
	body.definition.display_name = "Oil interface prototype"
	body.definition.cargo_type_ids = ["cargo_oil"]
	body.definition.cargo_capacities = {"oil_barrels": 200}
	body.definition.container_layout = null
	return body

func service_id() -> String: return "oil_trade"
func cargo_id() -> String: return "cargo_oil"
func can_switch() -> bool: return not is_instance_valid(ship)

func _ready() -> void:
	save_enabled = false
	super._ready()
	for place: Node3D in world_ports:
		place.definition = place.definition.duplicate(true)
		place.berth = place.berth.duplicate(true)
		place.definition.service_ids.append(service_id())
		place.berth.service_ids.append(service_id())
		place.berth.cargo_type_ids.append(cargo_id())
	switch_button.hide()
	services.hide()
	endpoint = OS.get_environment("SHIPPING_OIL_FIXTURE_URL")
	token = OS.get_environment("SHIPPING_OIL_FIXTURE_TOKEN")
	oil_scroll = ScrollContainer.new()
	oil_scroll.custom_minimum_size = Vector2(470, 380)
	services.get_parent().add_child(oil_scroll)
	oil_panel = preload("res://features/cargo/oil_market_panel.gd").new()
	oil_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oil_scroll.add_child(oil_panel)
	button(dock_button.get_parent(), "Oil prices / close", func(): oil_scroll.visible = not oil_scroll.visible)
	oil_panel.port_context = context
	if endpoint.begins_with("http://127.0.0.1:") and not token.is_empty():
		oil_panel.send = market_request
		oil_panel.inspect()
		if OS.get_environment("SHIPPING_REFINERY_FIXTURE") == "1":
			refinery_panel = preload("res://features/cargo/refinery_panel.gd").new()
			oil_panel.add_child(refinery_panel)
			refinery_panel.port_context = context
			refinery_panel.send = market_request
			refinery_panel.inspect()
		if OS.get_environment("SHIPPING_CARGO_FUEL_FIXTURE") == "1":
			refinery_panel = preload("res://features/cargo/cargo_fuel_panel.gd").new()
			oil_panel.add_child(refinery_panel)
			refinery_panel.port_context = context
			refinery_panel.send = market_request
			var commodity := OptionButton.new()
			commodity.add_item("Crude oil market")
			commodity.add_item("Refined cargo fuel")
			oil_panel.add_child(commodity)
			oil_panel.move_child(commodity, 0)
			refinery_panel.hide()
			commodity.item_selected.connect(func(index: int):
				for child: Node in oil_panel.get_children():
					if child is Control and child != commodity: child.visible = (child == refinery_panel) == (index == 1)
				if index == 1: refinery_panel.inspect())
			refinery_panel.inspect()
			await resume_cargo_voyage()
	else:
		oil_panel.notice.text = "Launch with tools/oil_market_fixture.py and an explicitly provisioned private database. No public or local price fallback."

func navigation_state() -> Dictionary:
	return {"position": [ship.global_position.x, ship.global_position.y, ship.global_position.z], "yaw": ship.rotation.y, "fuel_liters": ship.state.fuel_liters, "condition": ship.state.condition}

func context() -> Dictionary:
	return {"docked": docking.state(1) == "docked" and ship.docked, "port_id": port.definition.id, "navigation": navigation_state()}

func resume_cargo_voyage() -> void:
	# Resume is isolated from market busy guards and never orders movement.
	var result: Dictionary = await market_request({"op": "fixture_resume"})
	if not result.get("ok", false):
		oil_panel.notice.text = "Voyage unavailable; reopen the fixture."
		oil_panel.send = Callable()
		refinery_panel.send = Callable()
		ship.set_physics_process(false)
		return
	var saved: Dictionary = result.navigation
	if not saved.is_empty():
		docking.disconnect_owner(1)
		ship.global_position = Vector3(float(saved.position[0]), float(saved.position[1]), float(saved.position[2]))
		ship.rotation.y = float(saved.yaw)
		ship.state.fuel_liters = float(saved.fuel_liters)
		ship.state.condition = float(saved.condition)
		ship.zero_throttle()
		ship.velocity = Vector3.ZERO
		for place: Node3D in world_ports:
			if ship.global_position.distance_to(place.berth_anchor.global_position) < ship.global_position.distance_to(port.berth_anchor.global_position): port = place
		bind_port()
	voyage_ready = true

func checkpoint_cargo_voyage() -> void:
	if not voyage_ready or checkpoint_busy: return
	checkpoint_busy = true
	var result: Dictionary = await market_request({"op": "fixture_checkpoint", "navigation": navigation_state()})
	checkpoint_busy = false
	if not result.get("ok", false):
		oil_panel.notice.text = "Voyage checkpoint unavailable; last durable position retained."


func market_request(request: Dictionary) -> Dictionary:
	var refinery_request: bool = str(request.op).begins_with("refinery_")
	if refinery_request and (oil_panel.busy or not oil_panel.pending.is_empty()):
		return {"ok": false, "code": "SERVICE_BUSY"}
	if not refinery_request and not str(request.op).begins_with("fixture_") and is_instance_valid(refinery_panel) and (refinery_panel.busy or not refinery_panel.pending.is_empty()):
		return {"ok": false, "code": "SERVICE_BUSY"}
	var http := HTTPRequest.new()
	http.timeout = 6
	http.body_size_limit = 262144
	http.max_redirects = 0
	add_child(http)
	var result: Dictionary = {"ok": false, "code": "MARKET_UNAVAILABLE", "uncertain": request.op in ["oil_accept", "refinery_submit"]}
	var error: Error = http.request(endpoint, ["Content-Type: application/json", "Authorization: Bearer " + token], HTTPClient.METHOD_POST, JSON.stringify({"request": request, "context": context()}))
	if error == OK:
		var response: Array = await http.request_completed
		if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200:
			var parsed: Variant = JSON.parse_string(response[3].get_string_from_utf8())
			if parsed is Dictionary and parsed.get("ok") is bool and parsed.get("code") is String: result = parsed
	http.queue_free()
	return result

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	services.hide()
	# Do not lose berth eligibility while a consequential request is in flight.
	if is_instance_valid(oil_panel) and (oil_panel.busy or not oil_panel.pending.is_empty()): dock_button.disabled = true
	if is_instance_valid(refinery_panel) and (refinery_panel.busy or not refinery_panel.pending.is_empty()): dock_button.disabled = true

func _process(_delta: float) -> void:
	if voyage_ready:
		checkpoint_seconds += _delta
		if checkpoint_seconds >= 1.0:
			checkpoint_seconds = 0
			checkpoint_cargo_voyage()
	if not is_instance_valid(oil_panel): return
	services.hide()
	jobs_panel.hide()
	controls.set_menu_open(oil_scroll.visible)
	oil_scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 250, 160, 420)
	details.text = "Oil port test · %s" % port.definition.display_name
	loading_text.text = "Inspect prices underway · dock to request/accept trades"
	minimap.queue_redraw()
	waypoint.hide()
	# Avoid container HUD/job actions in this isolated oil fixture.
	voyage_hud.hide()
	heavy_controls.hide()

func leave() -> void:
	if is_instance_valid(refinery_panel) and refinery_panel.busy: return
	if is_instance_valid(oil_panel) and oil_panel.busy: return
	if voyage_ready: await checkpoint_cargo_voyage()
	super.leave()
