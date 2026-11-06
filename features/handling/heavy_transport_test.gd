extends "res://features/handling/heavy_lifter_test.gd"
## Explicit private fixture; the owned local host is the authority, never public fallback.
const REALM := "private:heavy-transport"
const SHIP := "heavy-fixture-ship"
var snapshot: Dictionary = {}
var pending: Dictionary = {}
var busy: bool = false
var ready_voyage: bool = false
var seconds: float = 0.0
var status: String = "Opening saved heavy voyage…"

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
	for entry: Array in [["Claim block job", func(): mutate("claim")], ["Cancel before pickup", func(): mutate("cancel")], ["Retry / reconnect", retry], ["Despawn (requires no active job)", request_despawn]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		buttons[0].get_parent().add_child(button)
	await get_tree().physics_frame
	await refresh()

func navigation() -> Dictionary:
	return {"position": [ship.position.x, ship.position.y, ship.position.z], "yaw": ship.rotation.y, "deck_height": ship.deck_height, "deck_target": ship.deck_target, "fuel_liters": ship.state.fuel_liters, "condition_bp": roundi(ship.state.condition * 10000), "attached": ship.attached}

func job() -> Dictionary:
	for row: Dictionary in snapshot.get("jobs", []):
		if row.state in ["pickup", "carrying"]: return row
	return {}

func at_destination() -> bool:
	if job().get("state") != "carrying": return false
	var p: Array = snapshot.terms.delivery_position_m
	return Vector2(ship.cargo_mount.global_position.x - float(p[0]), ship.cargo_mount.global_position.z - float(p[2])).length() <= float(snapshot.terms.zone_radius_m)

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
		ship.payload_body.set_meta("payload_id", str(snapshot.terms.payload_id))
		var p: Array = result.terms.pickup_position_m
		ship.restore_heavy_payload(job().get("state") == "carrying", not job().is_empty(), Vector3(p[0], -1, p[2]))
		ready_voyage = true
		ship.simulation_paused = ship.state.condition <= 0
		status = "Job: %s · Wallet: %d" % [job().get("state", "none"), int(result.money)]
	else:
		ready_voyage = false
		status = "Resume unavailable; voyage stopped. Retry to reopen saved state."
	busy = false

func mutate(op: String) -> void:
	if busy or not ready_voyage or not pending.is_empty(): return
	if op == "pickup":
		if not ship.stopped() or ship.operating() or ship.deck_height != Heavy.LOWERED or not ship.pickup_position_ready(): return
		if not ship.space_clear(ship.cargo_mount.global_transform.translated_local(Vector3(0, 4, 0)), ship.payload_shape.shape): return
	if op == "deliver" and (not at_destination() or not ship.stopped() or ship.operating() or ship.deck_height != Heavy.LOWERED): return
	var action: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var nav: Dictionary = navigation()
	if op == "pickup": nav.deck_target = Heavy.RAISED
	pending = {"request": {"op": op, "realm": REALM, "ship_id": SHIP, "payload_id": snapshot.terms.payload_id, "job_id": action if op == "claim" else job().get("id", ""), "action_id": action, "expected_revision": int(snapshot.revision)}, "navigation": nav}
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

func _process(delta: float) -> void:
	super._process(delta)
	readout.text += "\n" + status
	if not ready_voyage or busy: return
	if ship.state.condition <= 0 and not job().is_empty():
		mutate("destroy")
		return
	seconds += delta
	if seconds >= 1.0:
		seconds = 0
		checkpoint()
