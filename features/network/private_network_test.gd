extends "res://features/network/local_network_test.gd"
## Private-world UI uses explicit host invitations; still loopback-only.
func make_session() -> LocalShipSession:
	return PrivateShipSession.new()

func add_session_buttons(stack: VBoxContainer, layer: CanvasLayer) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Join a trusted private world"
	dialog.ok_button_text = "Trust invitation and join"
	dialog.min_size = Vector2i(650, 330)
	var box: VBoxContainer = VBoxContainer.new()
	dialog.add_child(box)
	var label: Label = Label.new()
	label.text = "Paste an invitation copied from your host window.\nThis pins that world's certificate. Only trust a host you intended to join.\nReconnect credentials stay in memory until this game window closes."
	box.add_child(label)
	var text: TextEdit = TextEdit.new()
	text.custom_minimum_size = Vector2(610, 180)
	text.placeholder_text = "Paste private-world invitation"
	box.add_child(text)
	dialog.confirmed.connect(func():
		if session.trust_invitation(text.text): session.join_session()
		else:
			session.notice = "Invalid invitation; connection not started"
			session.changed.emit())
	layer.add_child(dialog)
	var row: HBoxContainer = HBoxContainer.new()
	stack.add_child(row)
	for caption: String in ["Host / resume starter", "Host / resume heavy", "Copy invitation", "Join invitation", "Reconnect", "Disconnect", "Main menu"]:
		if caption == "Join invitation":
			row = HBoxContainer.new()
			stack.add_child(row)
		var button: Button = Button.new()
		button.text = caption
		row.add_child(button)
		button.pressed.connect(func():
			match caption:
				"Host / resume starter":
					session.ship_definition_id = "ship_starter_container_01"
					session.host_session()
				"Host / resume heavy":
					session.ship_definition_id = "ship_heavy_lifter_01"
					session.host_session()
				"Copy invitation":
					if session.hosting: DisplayServer.clipboard_set(JSON.stringify(session.invitation))
				"Join invitation": dialog.popup_centered()
				"Reconnect": session.join_session()
				"Disconnect": session.stop()
				"Main menu": get_tree().change_scene_to_file("res://features/main/main.tscn")
			button.release_focus())

func update_readout() -> void:
	super.update_readout()
	if readout != null:
		readout.text = readout.text.replace("LOCAL MULTIPLAYER TEST · STEP 39", "PRIVATE MULTIPLAYER · STEP 40").replace("Guest reconnect: same running host only · No host migration", "Trusted invitation · Stable private identity · No host migration")

func capture_private_state(id: String) -> Dictionary:
	var ship: HandlingShip = ships.get(id, parked.get(id))
	if ship == null: return {}
	var data: Dictionary = {"version": 1, "position": ship.position, "yaw": ship.rotation.y, "fuel": ship.state.fuel_liters, "heavy": ship is CargoReplication.Heavy}
	if ship is CargoReplication.Heavy:
		if not ship.payload_body.is_inside_tree(): return {}
		data.deck = ship.deck_height
		data.attached = ship.attached
		data.payload = ship.payload_body.global_transform
	return data

func valid_private_state(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("position") is Vector3 or not data.position.is_finite() or data.position.length() > 1000000: return false
	for field: String in ["yaw", "fuel"]:
		if not data.get(field) is float or not is_finite(data[field]): return false
	if data.fuel < 0 or not data.get("heavy") is bool: return false
	if data.heavy != (session.ship_definition_id == "ship_heavy_lifter_01"): return false
	var definition: ShipDefinition = load("res://features/catalog/records/heavy_lifter.tres" if data.heavy else "res://features/catalog/records/starter_ship.tres")
	if data.fuel > definition.fuel_capacity_liters: return false
	if data.heavy:
		if not data.get("deck") is float or not is_finite(data.deck) or data.deck < CargoReplication.Heavy.LOWERED or data.deck > CargoReplication.Heavy.RAISED: return false
		if not data.get("attached") is bool or not data.get("payload") is Transform3D or not data.payload.is_finite(): return false
	return true

func refresh() -> void:
	super.refresh()
	if not session is PrivateShipSession or not session.hosting: return
	for id: String in session.restored_states.keys():
		if not ships.has(id): continue
		var data: Dictionary = session.restored_states[id]
		session.restored_states.erase(id)
		var ship: HandlingShip = ships[id]
		ship.simulation_paused = true
		ship.set_physics_process(false)
		restore_ship.call_deferred(ship, data)

func restore_ship(ship: HandlingShip, data: Dictionary) -> void:
	if not is_instance_valid(ship) or not session.hosting: return
	ship.position = data.position
	ship.rotation.y = data.yaw
	ship.state.fuel_liters = data.fuel
	ship.velocity = Vector3.ZERO
	ship.commanded_throttle = 0
	ship.actual_throttle = 0
	ship.yaw_rate = 0
	ship.maneuver(0, 0)
	if ship is CargoReplication.Heavy:
		ship.deck_height = data.deck
		ship.deck_target = data.deck # Interrupted lift resumes stopped, never auto-delivers.
		ship.deck_visual.position.y = data.deck - CargoReplication.Heavy.RAISED
		ship.deck_shape.position.y = data.deck - 0.3
		ship.cargo_mount.position.y = data.deck
		ship.payload_shape.position.y = data.deck + 4
		ship.attached = data.attached
		ship.payload_body.global_transform = data.payload
		ship.payload_visual.reparent(ship.cargo_mount if data.attached else ship.payload_body, false)
		ship.payload_visual.transform = Transform3D.IDENTITY
		ship.payload_shape.disabled = not data.attached
		ship.payload_body.collision_layer = 0 if data.attached else CollisionRules.HULL
	ship.simulation_paused = false
	ship.set_physics_process(true)
