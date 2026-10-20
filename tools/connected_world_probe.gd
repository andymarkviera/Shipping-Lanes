extends Node3D
const Nav = preload("res://features/geography/navigation_experiment.gd")
const Geo = preload("res://features/geography/geographic_address.gd")
const Spatial = preload("res://features/geography/spatial_snapshot.gd")
const Heavy = preload("res://features/handling/heavy_lifter.gd")
var session: LocalShipSession
var ship: Heavy
var camera: OrbitCameraRig
var marker: StaticBody3D
var role: String
var port: int
var result_dir: String
var checks: int = 0
var failures: int = 0
var acknowledged: int = -1
var received: int = -1
var entity: String = ""
var latest: Dictionary = {}
var max_view_error: float = 0
var max_payload_error: float = 0
var reconnect_ready: bool = false
var done: bool = false
var impaired: bool = false
var reconnect_allowed: bool = false
var last_ack_sent: int = -1

func argument(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	role = argument("--network-role=")
	port = int(argument("--network-port="))
	result_dir = argument("--network-results=")
	impaired = argument("--network-profile=") == "impaired"
	AudioServer.set_bus_mute(0, true)
	session = LocalShipSession.new()
	session.name = "Session"
	add_child(session)
	ship = Heavy.new()
	add_child(ship)
	ship.set_physics_process(false)
	camera = OrbitCameraRig.new()
	add_child(camera)
	camera.set_focus(ship.assembly.focus)
	camera.set_physics_process(false)
	marker = StaticBody3D.new()
	marker.collision_layer = CollisionRules.SHORE
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.5, 1, 20)
	collider.shape = box
	marker.add_child(collider)
	add_child(marker)
	marker.position = Vector3(200, 8, 0)
	run.call_deferred()

func wait_for(condition: Callable, seconds: float = 8) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	return condition.call()

func host_entity() -> String:
	for id: String in session.roster:
		if session.roster[id].peer_id == 1: return id
	return ""

func run() -> void:
	await get_tree().physics_frame
	if role == "host":
		await run_host()
	else:
		await run_client()
	var metrics: Dictionary = {"role": role, "checks": checks, "failures": failures, "entity": entity, "revision": received if role == "client" else acknowledged, "max_view_error_m": max_view_error, "max_payload_error_m": max_payload_error}
	var file: FileAccess = FileAccess.open(result_dir.path_join(role + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics))
	file.close()
	print("CONNECTED_WORLD_METRICS ", JSON.stringify(metrics))
	print("NETWORK_%s_PASS" % role.to_upper() if failures == 0 else "NETWORK_FAIL")
	session.stop()
	get_tree().quit(0 if failures == 0 else 1)

func load_fixture() -> void:
	check(ship.request_height(Heavy.LOWERED), "Lower test deck")
	for tick: int in range(240): ship.advance_deck(1.0 / 60)
	check(ship.align_test_payload(), "Stage disposable payload")
	await get_tree().physics_frame
	check(ship.attach_payload(), "Secure real compound payload")
	check(ship.request_height(Heavy.RAISED), "Raise secured payload")
	for tick: int in range(240): ship.advance_deck(1.0 / 60)
	check(ship.attached and ship.deck_height == Heavy.RAISED, "Loaded fixture ready")

func bundle(origin: Dictionary, address: Dictionary, revision: int) -> Dictionary:
	return {"schema": 1, "epoch": session.epoch, "entity": entity, "owner": 1,
		"revision": revision, "radius_m": Nav.RADIUS_M, "origin": origin, "address": address,
		"position": Spatial.vector(ship.position), "velocity": Spatial.vector(ship.velocity),
		"yaw": ship.rotation.y, "marker": Spatial.vector(marker.position),
		"payload": entity + "_payload", "attached": ship.attached}

func send_bundle(data: Dictionary) -> void:
	if impaired: await get_tree().create_timer(0.12).timeout
	for peer: int in multiplayer.get_peers(): receive_bundle.rpc_id(peer, data)

func run_host() -> void:
	session.ship_definition_id = "ship_heavy_lifter_01"
	check(session.host_session(port) == OK, "Start loopback world host")
	entity = host_entity()
	await load_fixture()
	var ready_file: FileAccess = FileAccess.open(result_dir.path_join("ready"), FileAccess.WRITE)
	ready_file.store_string("ready")
	ready_file.close()
	check(await wait_for(func(): return session.roster.size() == 2), "Second process joins")
	var revision: int = 0
	for origin: Dictionary in [Geo.normalized(0, 179.999, 90), Geo.normalized(89.999, 20, 0), Geo.normalized(-89.999, 20, 180)]:
		var destination: Dictionary = Nav.travel(origin, 500)
		ship.position = Nav.local_position(origin, destination)
		ship.rotation.y = -deg_to_rad(origin.heading_deg)
		ship.velocity = ship.basis.z * 4
		marker.transform = ship.transform
		marker.position = ship.to_global(Vector3(12, 8, -8))
		camera.pivot = ship.position
		camera.camera.position = ship.position + Vector3(50, 40, -90)
		latest = bundle(origin, destination, revision)
		check(Spatial.valid(latest, session.epoch, entity), "Pre-transition spatial envelope valid")
		await send_bundle(latest)
		check(await wait_for(func(): return acknowledged == revision), "Client receives pre-transition state")
		var before_view: Vector3 = camera.camera.to_local(ship.position)
		var before_velocity: Vector3 = ship.basis.inverse() * ship.velocity
		var shift: Vector3 = ship.position
		var angle: float = Nav.transport_rotation(origin, destination)
		Nav.reframe([ship, marker], camera, shift, angle)
		max_view_error = maxf(max_view_error, before_view.distance_to(camera.camera.to_local(ship.position)))
		check((ship.basis.inverse() * ship.velocity).distance_to(before_velocity) < 0.00001, "Transition preserves local velocity")
		check(absf(Geo.longitude_delta(-rad_to_deg(ship.rotation.y), destination.heading_deg)) < 0.0001, "Transported hull heading matches geographic heading")
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(ship.test_move(ship.transform, ship.basis.x * 10), "Attached payload still collides after chart transition")
		ship.payload_shape.disabled = true
		check(not ship.test_move(ship.transform, ship.basis.x * 10), "Bare hull clears high marker")
		ship.payload_shape.disabled = false
		var start: Vector3 = ship.position
		ship.velocity = ship.basis.x * 20
		for tick: int in range(30):
			await get_tree().physics_frame
			ship.velocity = ship.basis.x * 20
			ship.move_and_slide()
		check(ship.get_slide_collision_count() > 0 and ship.position.distance_to(start) < 5, "Real loaded motion blocked by solid marker after transition")
		ship.position = start
		ship.velocity = ship.basis * before_velocity
		revision += 1
		latest = bundle(destination, destination, revision)
		await send_bundle(latest)
		check(await wait_for(func(): return acknowledged == revision), "Client atomically changes chart")
		revision += 1
	check(max_view_error < 0.001, "Host camera transition under one millimeter")
	var save: FileAccess = FileAccess.open(result_dir.path_join("spatial-fixture.json"), FileAccess.WRITE)
	save.store_string(JSON.stringify(latest))
	save.close()
	var restored: Dictionary = Spatial.decode_json(FileAccess.get_file_as_string(result_dir.path_join("spatial-fixture.json")))
	check(Spatial.valid(restored, session.epoch, entity), "Disk JSON reload preserves validated identity and spatial state")
	check(Nav.separation(restored.address, latest.address) < 0.000001 and restored.payload == latest.payload, "Reload preserves geographic address and payload identity")
	latest = restored
	for peer: int in multiplayer.get_peers(): permit_reconnect.rpc_id(peer)
	check(await wait_for(func(): return reconnect_ready), "Returning peer requests fixture state")
	await send_bundle(latest)
	check(await wait_for(func(): return done), "Reconnected peer verifies same host ship and payload")

@rpc("authority", "call_remote", "reliable", 0)
func receive_bundle(data: Dictionary) -> void:
	if session.hosting: return
	if entity.is_empty(): entity = host_entity()
	check(Spatial.valid(data, session.epoch, entity, received), "Received ordered, authority-owned spatial snapshot")
	if not Spatial.valid(data, session.epoch, entity, received): return
	if not latest.is_empty() and data.revision % 2 == 1 and received == data.revision - 1:
		var before: Vector3 = camera.camera.to_local(ship.position)
		Nav.reframe([ship, marker], camera, Nav.local_position(latest.origin, data.origin), Nav.transport_rotation(latest.origin, data.origin))
		max_view_error = maxf(max_view_error, before.distance_to(camera.camera.to_local(ship.position)))
		check(ship.position.distance_to(Spatial.unpack(data.position)) < 0.001, "Client frame mapping agrees with authoritative position")
	ship.position = Spatial.unpack(data.position)
	ship.rotation.y = data.yaw
	ship.velocity = Spatial.unpack(data.velocity)
	marker.position = Spatial.unpack(data.marker)
	marker.rotation.y = ship.rotation.y
	if not ship.attached:
		ship.payload_visual.reparent(ship.cargo_mount, false)
		ship.payload_visual.transform = Transform3D.IDENTITY
		ship.attached = true
	ship.payload_body.collision_layer = 0
	ship.payload_shape.disabled = true
	ship.collision_layer = 0
	ship.collision_mask = 0
	max_payload_error = maxf(max_payload_error, ship.payload_visual.global_position.distance_to(ship.cargo_mount.global_position))
	check(ship.to_local(marker.position).distance_to(Vector3(12, 8, -8)) < 0.001, "Nearby interest marker stays in the same ship-relative place")
	check(ship.velocity.length() > 3.99 and ship.velocity.length() < 4.01, "Network velocity preserves speed")
	latest = data.duplicate(true)
	received = data.revision
	if impaired: await get_tree().create_timer(0.08).timeout
	ack.rpc_id(1, received)
	last_ack_sent = received

@rpc("any_peer", "call_remote", "reliable", 0)
func ack(revision: int) -> void:
	if session.hosting and multiplayer.get_remote_sender_id() in multiplayer.get_peers() and revision == latest.revision: acknowledged = revision

@rpc("any_peer", "call_remote", "reliable", 0)
func request_reload() -> void:
	if session.hosting and multiplayer.get_remote_sender_id() in multiplayer.get_peers(): reconnect_ready = true

@rpc("authority", "call_remote", "reliable", 0)
func permit_reconnect() -> void:
	reconnect_allowed = true

@rpc("any_peer", "call_remote", "reliable", 0)
func finish() -> void:
	if session.hosting and multiplayer.get_remote_sender_id() in multiplayer.get_peers(): done = true

func run_client() -> void:
	check(session.join_session(port) == OK, "Join world fixture")
	check(await wait_for(func(): return received == 5, 16), "Receive seam and both polar transitions")
	check(max_view_error < 0.001 and max_payload_error < 0.001, "Camera and attached payload retain relative pose")
	check(not Spatial.valid(latest, session.epoch, entity, received), "Reject stale chart revision")
	var bad: Dictionary = latest.duplicate(true)
	bad.owner = 2
	check(not Spatial.valid(bad, session.epoch, entity), "Reject foreign owner")
	bad = latest.duplicate(true)
	bad.origin.content_revision = 999
	check(not Spatial.valid(bad, session.epoch, entity), "Reject incompatible world revision")
	bad = latest.duplicate(true)
	bad.position = [999, 0, 999]
	check(not Spatial.valid(bad, session.epoch, entity), "Reject mixed chart and local pose")
	bad = latest.duplicate(true)
	bad.velocity = [NAN, 0, 0]
	check(not Spatial.valid(bad, session.epoch, entity), "Reject nonfinite velocity")
	check(not Spatial.valid(latest, "previous-session", entity), "Reject obsolete session epoch")
	var original_entity: String = entity
	var original_payload: String = latest.payload
	check(await wait_for(func(): return reconnect_allowed), "Host acknowledged transitions before reconnect")
	session.stop()
	received = -1
	last_ack_sent = -1
	latest = {}
	await get_tree().create_timer(0.3).timeout
	check(session.join_session(port) == OK, "Reconnect observer")
	check(await wait_for(func(): return session.roster.size() == 2), "Reconnect roster synchronized")
	request_reload.rpc_id(1)
	check(await wait_for(func(): return received == 5), "Receive reloaded spatial fixture")
	check(await wait_for(func(): return last_ack_sent == 5), "Finish delayed acknowledgement before shutdown")
	check(host_entity() == original_entity and latest.payload == original_payload, "Host ownership, ship and attached payload identity survive reconnect")
	finish.rpc_id(1)
	await get_tree().create_timer(0.25).timeout
