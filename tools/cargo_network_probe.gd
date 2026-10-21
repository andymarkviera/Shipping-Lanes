extends "res://features/network/local_network_test.gd"
const Heavy = preload("res://features/handling/heavy_lifter.gd")
var role: String
var port: int
var result_dir: String
var checks: int = 0
var failures: int = 0
var stage: int = 0
var sailing: bool = false
var timer: float = 0
var samples_checked: int = 0
var max_relative_error: float = 0

func argument(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

func _ready() -> void:
	super._ready()
	automated_input = true
	AudioServer.set_bus_mute(0, true)
	role = argument("--network-role=")
	port = int(argument("--network-port="))
	result_dir = argument("--network-results=")
	replication.impairment = argument("--network-profile=") == "impaired"
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _physics_process(delta: float) -> void:
	if not session.hosting: return
	timer += delta
	if timer >= 0.05:
		timer = fmod(timer, 0.05)
		replication.submit(1 if sailing else 0, 0.7 if sailing else 0, 0)

func _process(delta: float) -> void:
	super._process(delta)
	for id: String in ships:
		var ship: Heavy = ships[id]
		if not ship.attached: continue
		samples_checked += 1
		max_relative_error = maxf(max_relative_error, ship.payload_visual.global_position.distance_to(ship.cargo_mount.global_position))

@rpc("any_peer", "call_remote", "reliable")
func advance_stage(value: int) -> void:
	if session.hosting and multiplayer.get_remote_sender_id() in multiplayer.get_peers() and value == stage + 1: stage = value

func wait_for(condition: Callable, limit: float = 8) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(limit * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	return condition.call()

func host_id() -> String:
	for id: String in session.roster:
		if session.roster[id].peer_id == 1: return id
	return ""

func run() -> void:
	if role == "host": await host_test()
	else: await client_test()
	check(samples_checked > 100 and max_relative_error < 0.001, "Attached payload never slips from interpolated parent")
	var metrics: Dictionary = {"role": role, "checks": checks, "failures": failures, "attached_samples": samples_checked, "max_attachment_error_m": max_relative_error, "dropped": replication.dropped, "accepted_actions": cargo_sync.accepted, "rejected_actions": cargo_sync.rejected}
	var file: FileAccess = FileAccess.open(result_dir.path_join(role + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics))
	file.close()
	print("CARGO_NETWORK_METRICS ", JSON.stringify(metrics))
	print("NETWORK_%s_PASS" % role.to_upper() if failures == 0 else "NETWORK_FAIL")
	session.stop()
	get_tree().quit(0 if failures == 0 else 1)

func host_test() -> void:
	session.ship_definition_id = "ship_heavy_lifter_01"
	check(session.host_session(port) == OK, "Host heavy session")
	await get_tree().process_frame
	var ship: Heavy = ships[host_id()]
	cargo_sync.submit("lower")
	# Prepare a loaded late-join fixture without waiting through the initial lift.
	for tick: int in range(240): ship.advance_deck(1.0 / 60)
	cargo_sync.submit("align")
	await get_tree().physics_frame
	cargo_sync.submit("secure")
	cargo_sync.submit("raise")
	for tick: int in range(240): ship.advance_deck(1.0 / 60)
	check(ship.attached and ship.deck_height == Heavy.RAISED, "Host fixture starts loaded")
	var marker: FileAccess = FileAccess.open(result_dir.path_join("ready"), FileAccess.WRITE)
	marker.store_string("ready")
	marker.close()
	sailing = true
	check(await wait_for(func(): return stage == 1, 20), "Client observed loaded turn and rejoined")
	check(absf(ship.rotation.y) > 0.03 and ship.distance_m > 5, "Loaded host actually sailed and turned")
	check(cargo_sync.rejected >= 3, "Foreign, stale and invalid cargo commands rejected")
	sailing = false
	ship.velocity = Vector3.ZERO
	ship.zero_throttle()
	ship.actual_throttle = 0
	ship.maneuver(0, 0)
	# Only cargo's high envelope reaches this rail; client cannot decide collision.
	var rail: StaticBody3D = StaticBody3D.new()
	rail.transform = ship.transform
	rail.position = ship.to_global(Vector3(12, 8, -8))
	rail.collision_layer = CollisionRules.SHORE
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.5, 1, 20)
	collider.shape = box
	rail.add_child(collider)
	add_child(rail)
	await get_tree().physics_frame
	check(ship.test_move(ship.global_transform, ship.global_basis.x * 10), "Carried collider detects high rail")
	ship.payload_shape.disabled = true
	check(not ship.test_move(ship.global_transform, ship.global_basis.x * 10), "Bare hull clears same rail")
	ship.payload_shape.disabled = false
	var initial: Vector3 = ship.position
	var direction: Vector3 = ship.basis.x
	ship.velocity = direction * 8
	var contact: bool = false
	for tick: int in range(90):
		await get_tree().physics_frame
		contact = contact or ship.get_slide_collision_count() > 0
	check(contact and (ship.position - initial).dot(direction) < 5.3, "Host physically stops carried cargo at rail under networking")
	remove_child(rail)
	rail.queue_free()
	ship.velocity = Vector3.ZERO
	ship.zero_throttle()
	ship.actual_throttle = 0
	cargo_sync.submit("lower")
	check(await wait_for(func(): return not ship.operating()), "Networked deck lowering completes")
	var before: Transform3D = ship.payload_visual.global_transform
	cargo_sync.submit("release")
	check(not ship.attached and ship.payload_visual.global_transform.is_equal_approx(before), "Release preserves authoritative world transform")
	check(ship.payload_shape.disabled and ship.payload_body.collision_layer == CollisionRules.HULL, "Released collision has one host owner")
	ship.position += ship.basis.x * 2
	check(await wait_for(func(): return stage == 2), "Client sees release at fixed world position")
	cargo_sync.submit("align")
	cargo_sync.submit("secure")
	check(ship.attached, "Host can resecure after release")
	check(await wait_for(func(): return stage == 3), "Client sees reattachment in order")
	await get_tree().create_timer(0.5).timeout

func client_test() -> void:
	check(session.join_session(port) == OK, "Client joins")
	check(await wait_for(func(): return ships.size() == 2 and not host_id().is_empty() and ships[host_id()].attached), "Late join reconstructs already attached cargo")
	if ships.size() != 2: return
	var host_entity: String = host_id()
	var ship: Heavy = ships[host_entity]
	check(ship.payload_visual.get_parent() == ship.cargo_mount and ship.payload_shape.disabled and ship.payload_body.collision_layer == 0, "Client attachment visual has no collision authority")
	cargo_sync.request_action.rpc_id(1, session.epoch, host_entity, 500, "release")
	cargo_sync.request_action.rpc_id(1, "stale", replication.local_entity(), 501, "lower")
	cargo_sync.request_action.rpc_id(1, session.epoch, replication.local_entity(), 502, "invented")
	# Exercise a real client-owned load using the same controls as the UI.
	cargo_sync.submit("lower")
	check(await wait_for(func(): return ships[replication.local_entity()].deck_height < -0.999), "Client lower command reaches host and returns")
	cargo_sync.submit("align")
	cargo_sync.submit("secure")
	check(await wait_for(func(): return ships[replication.local_entity()].attached), "Back-to-back align/secure retains reliable command order")
	var mine: String = replication.local_entity()
	var seq: int = cargo_sync.sequence
	cargo_sync.request_action.rpc_id(1, session.epoch, mine, seq, "release")
	await get_tree().create_timer(0.3).timeout
	check(ships[mine].attached, "Duplicate sequence cannot release secured load")
	await get_tree().create_timer(2).timeout
	check(ship.attached and absf(ship.rotation.y) > 0.01, "Foreign release cannot alter turning host load")
	session.stop()
	await get_tree().create_timer(0.4).timeout
	check(ships.is_empty(), "Disconnect removes cargo-bearing hulls")
	session.join_session(port)
	check(await wait_for(func(): return ships.has(host_entity) and ships[host_entity].attached), "Reconnect reconstructs same host and carried payload")
	check(await wait_for(func(): return ships.has(mine) and ships[mine].attached), "Returning guest retains its own secured load")
	check(replication.local_entity() == mine, "Guest ship identity survives reconnect")
	ship = ships[host_entity]
	check(replication.latest[host_entity].cargo.id == host_entity + "_payload", "Payload identity stable across reconnect")
	advance_stage.rpc_id(1, 1)
	check(await wait_for(func(): return not ship.attached, 10), "Release eventually arrives despite snapshot loss")
	await get_tree().create_timer(0.4).timeout
	check(ship.payload_visual.get_parent() == ship.payload_body, "Released cargo has world parent")
	check(ship.payload_body.global_transform.is_equal_approx(replication.latest[host_entity].cargo.pose), "Released world pose matches authority")
	check(ship.payload_body.collision_layer == 0 and ship.payload_shape.disabled, "Client never enables carried or floating physics")
	advance_stage.rpc_id(1, 2)
	check(await wait_for(func(): return ship.attached), "Reattachment converges without duplicate visual")
	check(ship.payload_visual.get_parent() == ship.cargo_mount and ship.payload_visual.transform.is_equal_approx(Transform3D.IDENTITY), "Reattachment restores exact local pose")
	advance_stage.rpc_id(1, 3)
	await get_tree().create_timer(0.2).timeout
