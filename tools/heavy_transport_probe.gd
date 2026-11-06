extends "res://features/handling/heavy_transport_test.gd"
var checks: int = 0
var lose_delivery_reply: bool = false

func send(payload: Dictionary) -> Dictionary:
	var result: Dictionary = await super.send(payload)
	if lose_delivery_reply and payload.request.op == "deliver" and result.get("ok", false):
		lose_delivery_reply = false
		return {"ok": false, "code": "LOST_REPLY", "uncertain": true}
	return result

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		push_error(label)
		get_tree().quit(1)
		assert(value, label)

func _ready() -> void:
	await super._ready()
	set_process(false)
	ship.set_physics_process(false)
	check(ready_voyage, "Real HTTP/private SQLite resume succeeds")
	var mode: String = OS.get_environment("SHIPPING_HEAVY_PROBE")
	if mode == "carry":
		await mutate("claim")
		check(job().state == "pickup", "Claim creates durable block job")
		ship.payload_body.position.x += 1000
		ship.request_height(Heavy.LOWERED)
		for i: int in 240: ship.advance_deck(1.0 / 60)
		check(not ship.request_height(Heavy.RAISED) and not ship.attached, "Distant payload cannot attach")
		await refresh()
		ship.request_height(Heavy.LOWERED)
		for i: int in 240: ship.advance_deck(1.0 / 60)
		check(ship.pickup_position_ready(), "Saved stable world block is over lowered deck")
		ship.request_height(Heavy.RAISED)
		await get_tree().process_frame
		while busy: await get_tree().process_frame
		check(ship.attached and job().state == "carrying", "Validated Raise commits before attachment")
		check(ship.payload_body.collision_layer == 0 and not ship.payload_shape.disabled and ship.payload_visual.get_parent() == ship.cargo_mount, "Exactly one constrained payload collider")
		check(ship.definition.forward_acceleration_mps2 < Heavy.DEFINITION.forward_acceleration_mps2 and ship.loaded_draft_m == 0.5, "Loaded mass and visual draft applied")
		for i: int in 240: ship.advance_deck(1.0 / 60)
		ship.command_throttle(1)
		ship.maneuver(0.3, 0)
		for i: int in 120: ship.advance_motion(1.0 / 60)
		check(ship.velocity.length() > 0 and ship.payload_visual.position == Vector3.ZERO, "Payload stays fixed during loaded motion")
		ship.position.z = -1200
		ship.velocity = Vector3.ZERO
		ship.actual_throttle = 0
		ship.zero_throttle()
		ship.maneuver(0, 0)
		ship.yaw_rate = 0
		check(not ship.request_height(Heavy.LOWERED), "Offshore release outside destination refuses")
		await request_despawn()
		check(is_instance_valid(ship) and job().state == "carrying", "Active payload blocks requested despawn")
		await checkpoint()
		check(ready_voyage, "Carried position saved")
	elif mode in ["deliver", "destroy"]:
		check(ship.attached and ship.position.z == -1200 and job().state == "carrying", "New process restores same carried job at saved position")
		check(ship.velocity == Vector3.ZERO and ship.actual_throttle == 0, "Reconnect is stopped in neutral")
		if mode == "deliver":
			ship.position = Vector3(-950, 0, -1792)
			ship.rotation.y = 0
			lose_delivery_reply = true
			check(ship.request_height(Heavy.LOWERED), "Destination permits lowering")
			for i: int in 240: ship.advance_deck(1.0 / 60)
			await get_tree().process_frame
			while busy: await get_tree().process_frame
			check(ship.attached and ship.simulation_paused and not pending.is_empty(), "Lost committed delivery reply retains custody and freezes simulation")
			await retry()
			check(not ship.attached and job().is_empty() and int(snapshot.money) == 71000, "Release delivers once through real boundary")
			check(ship.loaded_draft_m == 0 and ship.definition.forward_acceleration_mps2 == Heavy.DEFINITION.forward_acceleration_mps2, "Delivery clears loaded handling")
			check(not ship.payload_visual.visible and ship.payload_body.collision_layer == 0 and ship.payload_shape.disabled, "Delivered block has no ghost physics")
			await mutate("deliver")
			check(int(snapshot.money) == 71000, "Another delivery cannot pay")
		else:
			ship.state.condition = 0
			await mutate("destroy")
			check(job().is_empty() and int(snapshot.money) == 1000 and ship.simulation_paused, "Destroyed hull fails job without repair or reward")
	elif mode in ["verify", "failed"]:
		check(job().is_empty() and not ship.attached and not ship.payload_visual.visible, "Terminal restart has no attached or floating duplicate")
		check(int(snapshot.money) == (71000 if mode == "verify" else 1000), "Restart never reapplies reward")
		check(not snapshot.available and snapshot.zones.is_empty(), "Terminal payload consumed and zones released")
		if mode == "failed": check(ship.state.condition == 0 and ship.simulation_paused, "Failed hull cannot respawn healthy")
	print("HEAVY TRANSPORT %s: %d checks passed" % [mode, checks])
	get_tree().quit()
