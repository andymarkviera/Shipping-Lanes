extends "res://features/handling/heavy_lifter_test.gd"
## Explicit private fixture; the owned local host is the authority, never public fallback.
## Step 83 guidance, cues and offers below are presentation derived from the
## canonical snapshot. They never decide custody, position evidence or reward.
const REALM := "private:heavy-transport"
const SHIP := "heavy-fixture-ship"
const BLOCK := "payload_offshore_block_01"
var snapshot: Dictionary = {}
var pending: Dictionary = {}
var busy: bool = false
var ready_voyage: bool = false
var seconds: float = 0.0
var status: String = "Opening saved heavy voyage…"
var claim_box: VBoxContainer
var claim_buttons: Dictionary = {}
var beacon: MeshInstance3D
var pointer: Label
var last_state: String = ""
var last_money: int = -1

func _ready() -> void:
	super._ready()
	ship.simulation_paused = true
	ship.payload_mass_kg = 100000
	ship.condition_affects_propulsion = true
	ship.pickup_commit_guard = pickup_guard
	ship.release_commit_guard = delivery_guard
	ship.release_guard = at_destination
	ship.validated_impact.connect(func(damage: int): ship.state.condition = maxf(0, ship.state.condition - damage / 10000.0))
	buttons[1].hide() # Never move the durable world payload using the staging shortcut.
	for child: Node in buttons[0].get_parent().get_children():
		if child is FuelTestControls: child.queue_free()
	claim_box = VBoxContainer.new()
	buttons[0].get_parent().add_child(claim_box)
	for entry: Array in [["Cancel before pickup", func(): mutate("cancel")], ["Retry / reconnect", retry], ["Despawn (requires no active job)", request_despawn]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		buttons[0].get_parent().add_child(button)
	build_guidance()
	await get_tree().physics_frame
	await refresh()

func build_guidance() -> void:
	# Flat ring on the water at the active zone plus a high marker; no collision.
	beacon = MeshInstance3D.new()
	beacon.mesh = TorusMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.material_override = material
	var marker := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 3.0
	ball.height = 6.0
	marker.mesh = ball
	marker.material_override = material
	marker.position.y = 40
	beacon.add_child(marker)
	beacon.visible = false
	add_child(beacon)
	pointer = Label.new()
	pointer.add_theme_font_size_override("font_size", 18)
	pointer.visible = false
	readout.get_parent().get_parent().get_parent().add_child(pointer)

func navigation() -> Dictionary:
	return {"position": [ship.position.x, ship.position.y, ship.position.z], "yaw": ship.rotation.y, "deck_height": ship.deck_height, "deck_target": ship.deck_target, "fuel_liters": ship.state.fuel_liters, "condition_bp": roundi(ship.state.condition * 10000), "attached": ship.attached}

func job() -> Dictionary:
	for row: Dictionary in snapshot.get("jobs", []):
		if row.state in ["pickup", "carrying"]: return row
	return {}

## Saved payload definition (terms, label, envelope, availability) by stable ID.
func definition_for(payload_id: String) -> Dictionary:
	for row: Dictionary in snapshot.get("payloads", []):
		if row.payload_id == payload_id: return row
	return {}

func payload_extent(row: Dictionary) -> Vector3:
	var size: Array = row.size_m
	return Vector3(float(size[0]), float(size[1]), float(size[2]))

## Load limits: the lifter's own rule and the limits published by the authority.
func fits(row: Dictionary) -> bool:
	var size: Vector3 = payload_extent(row)
	var limit: Dictionary = snapshot.get("lifter", {})
	if limit.is_empty() or not Heavy.load_within_limits(size, float(row.mass_kg)): return false
	var most: Array = limit.max_envelope_m
	return float(row.mass_kg) <= float(limit.max_payload_kg) and size.x <= float(most[0]) and size.y <= float(most[1]) and size.z <= float(most[2])

func at_destination() -> bool:
	var row: Dictionary = job()
	if row.get("state") != "carrying": return false
	var p: Array = row.terms.delivery_position_m
	return Vector2(ship.cargo_mount.global_position.x - float(p[0]), ship.cargo_mount.global_position.z - float(p[2])).length() <= float(row.terms.zone_radius_m)

## Active offshore waypoint from the job's frozen terms; empty without a job.
func target() -> Dictionary:
	var row: Dictionary = job()
	if row.is_empty(): return {}
	var carrying: bool = row.state == "carrying"
	var p: Array = row.terms.delivery_position_m if carrying else row.terms.pickup_position_m
	return {"label": "Drop-off" if carrying else "Pickup", "position": Vector3(float(p[0]), 0, float(p[2])), "radius_m": float(row.terms.zone_radius_m), "delivery": carrying}

## Horizontal distance from the cargo anchor and the turn needed from the bow
## (positive is port, +X, with +Z as the bow).
func guidance() -> Dictionary:
	var goal: Dictionary = target()
	if goal.is_empty(): return {}
	var at: Vector3 = goal.position
	var anchor: Vector3 = ship.cargo_mount.global_position
	var local: Vector3 = ship.to_local(Vector3(at.x, ship.global_position.y, at.z))
	var distance: float = Vector2(anchor.x - at.x, anchor.z - at.z).length()
	return {"label": goal.label, "distance_m": distance, "turn_degrees": rad_to_deg(atan2(local.x, local.z)), "inside": distance <= float(goal.radius_m), "delivery": goal.delivery}

func guidance_text() -> String:
	var found: Dictionary = guidance()
	if found.is_empty(): return ""
	var turn: float = found.turn_degrees
	var side: String = "dead ahead"
	if absf(turn) > 175: side = "directly astern"
	elif absf(turn) >= 5: side = "%.0f° to %s" % [absf(turn), "port" if turn > 0 else "starboard"]
	return "%s waypoint: %.0f m, %s%s" % [found.label, float(found.distance_m), side, " — inside the ring" if found.inside else ""]

func load_text() -> String:
	var limit: Dictionary = snapshot.get("lifter", {})
	var row: Dictionary = definition_for(str(job().get("payload", "")))
	if limit.is_empty(): return ""
	if row.is_empty(): return "Lifter load limit: %.0f t" % (float(limit.max_payload_kg) / 1000.0)
	return "%s: %.0f t of %.0f t limit · sits %.1f m deeper when loaded" % [row.label, float(row.mass_kg) / 1000.0, float(limit.max_payload_kg) / 1000.0, float(limit.draft_m_per_100t) * float(row.mass_kg) / 100000.0]

## Plain next instruction so a job can be completed without developer notes.
func next_step() -> String:
	if not ready_voyage: return "Voyage stopped. Press Retry / reconnect."
	if ship.state.condition <= 0: return "Hull destroyed. This ship cannot continue."
	var row: Dictionary = job()
	if row.is_empty(): return "Choose a heavy job below. One job at a time; jobs never expire."
	if ship.operating(): return "Deck moving — hold position."
	if row.state == "pickup":
		if ship.deck_height != Heavy.LOWERED: return "Follow the yellow ring to the load, stop nearby in neutral and press Lower deck."
		if ship.pickup_position_ready(): return "In position. Stop in neutral and press Raise to secure the load."
		return "Deck lowered. Ease the platform underneath the load centre — crooked is fine."
	if ship.deck_height == Heavy.LOWERED: return "Stopped at the drop-off: delivery is being recorded." if at_destination() else "Press Raise to lift the secured load."
	if at_destination(): return "Inside the green ring. Stop in neutral and press Lower deck to deliver."
	return "Follow the green ring to the drop-off. Lowering is locked until you arrive."

## Pickup/delivery cue shown once when the canonical job state changes.
func cue(state: String, money: int) -> String:
	var text: String = "Job: %s · Wallet: %d" % [state, money]
	if last_money < 0 or state == last_state: return text
	if state == "pickup": return text + "\nJOB ACCEPTED — a yellow ring marks the pickup."
	if state == "carrying": return text + "\nLOAD SECURED — a green ring marks the drop-off."
	if money > last_money: return text + "\nDELIVERED — paid %d." % (money - last_money)
	if ship.state.condition <= 0: return text + "\nJOB FAILED — hull destroyed, no reward."
	return text + "\nJob cancelled. No payment."

func sync_offers() -> void:
	var idle: bool = job().is_empty()
	claim_box.visible = idle
	for row: Dictionary in snapshot.get("payloads", []):
		var id: String = str(row.payload_id)
		if not claim_buttons.has(id):
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(func(): mutate("claim", id))
			claim_box.add_child(button)
			claim_buttons[id] = button
		var size: Vector3 = payload_extent(row)
		var offer: Button = claim_buttons[id]
		offer.text = "Claim %s — %.0f t, %.0f × %.0f × %.0f m, pays %d" % [row.label, float(row.mass_kg) / 1000.0, size.x, size.y, size.z, int(row.reward_minor)]
		if not fits(row): offer.text += " (over load limit)"
		elif not row.available: offer.text += " (taken)"
		offer.disabled = not idle or not row.available or not fits(row)

func pickup_guard() -> bool:
	if ready_voyage and not busy and job().get("state") == "pickup": mutate.call_deferred("pickup")
	return false # Physical attachment happens only after the durable commit.

func delivery_guard() -> bool:
	if ready_voyage and not busy and at_destination(): mutate.call_deferred("deliver")
	return false

func send(payload: Dictionary) -> Dictionary:
	var endpoint: String = OS.get_environment("SHIPPING_HEAVY_URL")
	if not endpoint.begins_with("http://127.0.0.1:"): return {"ok": false, "code": "FIXTURE_NOT_CONFIGURED"}
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 5
	var result: Dictionary = {"ok": false, "code": "HEAVY_UNAVAILABLE", "uncertain": true}
	var error: Error = http.request(endpoint, ["Content-Type: application/json", "Authorization: Bearer " + OS.get_environment("SHIPPING_HEAVY_TOKEN")], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error == OK:
		var response: Array = await http.request_completed
		if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200:
			var parsed: Variant = JSON.parse_string(response[3].get_string_from_utf8())
			if parsed is Dictionary: result = parsed
	http.queue_free()
	return result

func refresh() -> void:
	busy = true
	ship.simulation_paused = true
	var result: Dictionary = await send({"request": {"op": "snapshot"}})
	if result.get("ok", false):
		snapshot = result
		var row: Dictionary = job()
		var shown: Dictionary = definition_for(str(row.get("payload", BLOCK)))
		# Missing or over-limit saved definitions fence the voyage; never guess a size.
		if shown.is_empty() or not fits(shown) or not ship.configure_payload(payload_extent(shown), float(shown.mass_kg)):
			ready_voyage = false
			status = "Saved load definition is missing or exceeds this lifter's limits. Voyage stopped."
			busy = false
			return
		var nav: Dictionary = result.navigation
		ship.position = Vector3(nav.position[0], nav.position[1], nav.position[2])
		ship.rotation.y = nav.yaw
		ship.velocity = Vector3.ZERO
		ship.yaw_rate = 0
		ship.actual_throttle = 0
		ship.zero_throttle()
		ship.maneuver(0, 0)
		ship.deck_height = nav.deck_height
		ship.deck_target = nav.deck_target
		ship.state.fuel_liters = nav.fuel_liters
		ship.state.condition = float(nav.condition_bp) / 10000.0
		ship.state.instance_id = SHIP
		ship.payload_body.set_meta("payload_id", str(shown.payload_id))
		var p: Array = shown.pickup_position_m
		ship.restore_heavy_payload(row.get("state") == "carrying", not row.is_empty(), Vector3(p[0], -1, p[2]))
		ready_voyage = true
		ship.simulation_paused = ship.state.condition <= 0
		var state: String = str(row.get("state", "none"))
		status = cue(state, int(result.money))
		last_state = state
		last_money = int(result.money)
		sync_offers()
	else:
		ready_voyage = false
		status = "Resume unavailable; voyage stopped. Retry to reopen saved state."
	busy = false

func mutate(op: String, payload_id: String = "") -> void:
	if busy or not ready_voyage or not pending.is_empty(): return
	if op == "claim":
		if payload_id.is_empty(): payload_id = BLOCK
		var offer: Dictionary = definition_for(payload_id)
		if offer.is_empty() or not fits(offer):
			status = "That load exceeds this lifter's limits."
			return
	else: payload_id = str(job().get("payload", BLOCK))
	if op == "pickup":
		if not ship.stopped() or ship.operating() or ship.deck_height != Heavy.LOWERED or not ship.pickup_position_ready(): return
		if not ship.space_clear(ship.cargo_mount.global_transform.translated_local(Vector3(0, ship.payload_size.y * 0.5, 0)), ship.payload_shape.shape): return
	if op == "deliver" and (not at_destination() or not ship.stopped() or ship.operating() or ship.deck_height != Heavy.LOWERED): return
	var action: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var nav: Dictionary = navigation()
	if op == "pickup": nav.deck_target = Heavy.RAISED
	pending = {"request": {"op": op, "realm": REALM, "ship_id": SHIP, "payload_id": payload_id, "job_id": action if op == "claim" else job().get("id", ""), "action_id": action, "expected_revision": int(snapshot.revision)}, "navigation": nav}
	await retry()

func retry() -> void:
	if busy: return
	if pending.is_empty():
		await refresh()
		return
	busy = true
	ship.simulation_paused = true
	var result: Dictionary = await send(pending)
	busy = false
	if result.get("ok", false):
		pending.clear()
		await refresh() # Canonical state wins over an old receipt on replay.
	elif not result.get("uncertain", false):
		pending.clear()
		await refresh()
		status = "Action refused: " + str(result.get("code", "UNKNOWN"))
	else:
		ready_voyage = false
		status = "Save outcome unknown. Retry the same action; voyage stopped."

func checkpoint() -> void:
	if busy or not ready_voyage or not pending.is_empty(): return
	busy = true
	var result: Dictionary = await send({"request": {"op": "checkpoint", "revision": int(snapshot.revision)}, "navigation": navigation()})
	busy = false
	if result.get("ok", false): snapshot.revision = result.revision
	else:
		ready_voyage = false
		ship.simulation_paused = true
		status = "Checkpoint unavailable; reconnect to the last durable position."

func request_despawn() -> void:
	if not job().is_empty() or busy or not pending.is_empty():
		status = "Finish or cancel the active job before despawning."
		return
	await checkpoint()
	if ready_voyage: get_tree().change_scene_to_file("res://features/main/main.tscn")

func update_guidance() -> void:
	var goal: Dictionary = target() if ready_voyage else {}
	beacon.visible = not goal.is_empty()
	pointer.visible = beacon.visible
	if goal.is_empty(): return
	var at: Vector3 = goal.position
	var radius: float = goal.radius_m
	var ring: TorusMesh = beacon.mesh as TorusMesh
	ring.outer_radius = radius
	ring.inner_radius = radius - 1.0
	beacon.global_position = at + Vector3(0, 0.6, 0)
	(beacon.material_override as StandardMaterial3D).albedo_color = Color("5fd38a") if goal.delivery else Color("ffd23f")
	var view: Camera3D = get_viewport().get_camera_3d()
	if view == null:
		pointer.visible = false
		return
	# Screen-edge pointer so the waypoint stays findable when the ring is off-screen.
	var area: Vector2 = get_viewport().get_visible_rect().size
	var screen: Vector2 = view.unproject_position(at)
	if view.is_position_behind(at): screen = Vector2(area.x - screen.x, area.y)
	pointer.position = screen.clamp(Vector2(20, 20), area - Vector2(240, 50))
	pointer.text = "◆ %s %.0f m" % [goal.label, float(guidance().distance_m)]

func _process(delta: float) -> void:
	super._process(delta)
	var text: String = "HEAVY JOB"
	for line: String in [status, load_text(), "Speed %.1f kn · Deck %.1f m" % [ship.velocity.length() * 3600 / 1852, ship.deck_height], str(FuelTestControls.readout(ship)), guidance_text(), ship.alignment_feedback() if job().get("state") == "pickup" else "", "NEXT: " + next_step(), ship.notice]:
		if not line.is_empty(): text += "\n" + line
	readout.text = text
	update_guidance()
	if not ready_voyage or busy: return
	if ship.state.condition <= 0 and not job().is_empty():
		mutate("destroy")
		return
	seconds += delta
	if seconds >= 1.0:
		seconds = 0
		checkpoint()
