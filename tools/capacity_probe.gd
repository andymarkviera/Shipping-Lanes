extends Node3D
## Isolated load fixture: real ENet connections, production hull motion/fuel,
## compact experimental packets. Not a replacement public/session protocol.
const Relevance = preload("res://features/network/ship_relevance.gd")
var role: String
var layout: String
var count: int
var port: int
var result_dir: String
var started: int
var server: ENetMultiplayerPeer
var clients: Array[Dictionary] = []
var members: Dictionary = {}
var grid = Relevance.new()
var ticks: Array[float] = []
var engine_ticks: Array[float] = []
var active_counts: Array[float] = []
var periods: Array[float] = []
var gaps: Array[float] = []
var latencies: Array[float] = []
var client_frames: Array[float] = []
var samples: Array[Dictionary] = []
var presented: Vector3
var clock_offset: float = INF
var previous_tick: int = 0
var last_packet: int = 0
var last_sequence: int = -1
var max_motion_speed: float = 0
var snapshots: int = 0
var retained: int = 0
var max_members: int = 0
var joins: int = 0
var departures: int = 0
var actions: int = 0
var accepted_inputs: int = 0
var sent_bytes: int = 0
var received_bytes: int = 0
var possible_records: int = 0
var sent_records: int = 0
var contacts: int = 0
var largest_packet: int = 0
var failures: int = 0
var sequence: int = 0
var send_accumulator: float = 0
var finished: bool = false
var rendered_ship: Node3D

func arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	role = arg("--capacity-role=")
	layout = arg("--capacity-layout=")
	count = int(arg("--capacity-count="))
	port = int(arg("--capacity-port="))
	result_dir = arg("--capacity-results=")
	started = Time.get_ticks_usec()
	AudioServer.set_bus_mute(0, true)
	grid.rebuild({1: Vector3.ZERO, 2: Vector3(349, 0, 0), 3: Vector3(351, 0, 0), 4: Vector3(-349, 0, 0)})
	check(grid.relevant(1) == [1, 2, 4], "Interest radius includes owner/negative cells and excludes distant hull")
	grid.rebuild({1: Vector3.ZERO, 3: Vector3(340, 0, 0)})
	check(grid.relevant(1) == [1, 3], "Interest rebuild removes departed hull and admits entering hull")
	var positions: Dictionary = {}
	for id: int in range(100): positions[id] = Vector3((id % 10 - 5) * 179.5, 0, (id / 10 - 5) * 179.5)
	grid.rebuild(positions)
	for id: int in positions:
		var expected: Array[int] = []
		for other: int in positions:
			if positions[id].distance_squared_to(positions[other]) <= 350.0 * 350.0: expected.append(other)
		expected.sort()
		check(grid.relevant(id) == expected, "Grid agrees with exact distance query including negative cell boundaries")
	if role == "server":
		server = ENetMultiplayerPeer.new()
		server.set_bind_ip("127.0.0.1")
		check(server.create_server(port, count + 4, 3) == OK, "Create dedicated loopback authority")
		server.peer_disconnected.connect(remove_member)
		if layout == "crowded":
			for side: float in [-1, 1]:
				var quay: StaticBody3D = StaticBody3D.new()
				quay.collision_layer = CollisionRules.SHORE
				quay.position = Vector3(side * 180, 0, 0)
				CollisionRules.add_box_hull(quay, Vector3(8, 12, 900))
				add_child(quay)
			var end_quay: StaticBody3D = StaticBody3D.new()
			end_quay.collision_layer = CollisionRules.SHORE
			end_quay.position.z = (ceili(count / 10.0) - 1) * 40 + 48
			CollisionRules.add_box_hull(end_quay, Vector3(370, 12, 8))
			add_child(end_quay)
		var file: FileAccess = FileAccess.open(result_dir.path_join("ready"), FileAccess.WRITE)
		file.store_string("ready")
		file.close()
	else:
		var first: int = 0 if role == "observer" else 1
		var last: int = 1 if role == "observer" else count
		for slot: int in range(first, last):
			clients.append({"slot": slot, "peer": new_client(), "hello": false, "seq": 0, "rejoined": false, "retry": 0.0})
		if role == "observer" and DisplayServer.get_name() != "headless":
			rendered_ship = preload("res://features/ships/starter_container_01/ship_starter_container_01.tscn").instantiate()
			add_child(rendered_ship)
			var view: Camera3D = Camera3D.new()
			view.position = Vector3(80, 70, -120)
			add_child(view)
			view.look_at(Vector3.ZERO)
			view.current = true
			var light: DirectionalLight3D = DirectionalLight3D.new()
			light.rotation_degrees = Vector3(-40, -30, 0)
			add_child(light)

func new_client() -> ENetMultiplayerPeer:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	check(peer.create_client("127.0.0.1", port, 3) == OK, "Create synthetic connection")
	return peer

func elapsed() -> float:
	return (Time.get_ticks_usec() - started) / 1000000.0

func measured() -> bool:
	return elapsed() >= 3 and elapsed() < 17

func send(peer: ENetMultiplayerPeer, target: int, packet: Array, reliable: bool = false) -> void:
	peer.set_target_peer(target)
	peer.transfer_channel = 0 if reliable else 1
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	var bytes: PackedByteArray = var_to_bytes(packet)
	largest_packet = maxi(largest_packet, bytes.size())
	check(peer.put_packet(bytes) == OK, "Queue load-test packet")
	if measured(): sent_bytes += bytes.size()

func remove_member(id: int) -> void:
	if not members.has(id): return
	members[id].ship.queue_free()
	members.erase(id)
	departures += 1

func receive_server() -> void:
	server.poll()
	while server.get_available_packet_count() > 0:
		var sender: int = server.get_packet_peer()
		var bytes: PackedByteArray = server.get_packet()
		if measured(): received_bytes += bytes.size()
		var data: Variant = bytes_to_var(bytes)
		if not data is Array or data.is_empty(): continue
		if data[0] == "hello" and data.size() == 2 and data[1] is int and data[1] >= 0 and data[1] < count and not members.has(sender):
			var slot: int = data[1]
			var occupied: bool = false
			for member: Dictionary in members.values(): occupied = occupied or member.slot == slot
			if occupied: continue
			var ship: HandlingShip = HandlingShip.new()
			ship.position = Vector3((slot % 10 - 4.5) * (32 if layout == "crowded" else 180), 0, (slot / 10 - 4.5) * (80 if layout == "crowded" else 180))
			if layout == "crowded": ship.position.z = (slot / 10 - (ceili(count / 10.0) - 1) * 0.5) * 80
			if layout == "dispersed" and slot % 5 == 0 and slot != 0: ship.rotation.y = PI / 2
			CollisionRules.add_box_hull(ship)
			add_child(ship)
			ship.set_physics_process(false)
			members[sender] = {"ship": ship, "slot": slot, "seq": -1, "ack": 0, "at": Time.get_ticks_msec(), "action": -1}
			joins += 1
			max_members = maxi(max_members, members.size())
		elif data[0] == "input" and data.size() == 6 and members.has(sender):
			var member: Dictionary = members[sender]
			if not data[1] is int or data[1] <= member.seq or not data[5] is int: continue
			if not data[2] is float or not is_finite(data[2]) or absf(data[2]) > 1: continue
			if not data[3] is float or not is_finite(data[3]) or absf(data[3]) > 1: continue
			member.seq = data[1]
			member.ack = data[5]
			member.at = Time.get_ticks_msec()
			member.ship.command_throttle(data[2])
			member.ship.maneuver(data[3], 0)
			accepted_inputs += 1
		elif data[0] == "action" and data.size() == 2 and data[1] is int and members.has(sender):
			if data[1] > members[sender].action:
				members[sender].action = data[1]
				actions += 1
		elif data[0] == "rejoin" and members.has(sender):
			remove_member(sender)
			server.disconnect_peer(sender)

func _physics_process(delta: float) -> void:
	if finished or role != "server": return
	var start: int = Time.get_ticks_usec()
	if measured() and previous_tick > 0: periods.append((start - previous_tick) / 1000.0)
	previous_tick = start
	receive_server()
	for member: Dictionary in members.values():
		if Time.get_ticks_msec() - member.at > 500:
			member.ship.zero_throttle()
			member.ship.maneuver(0, 0)
		member.ship._physics_process(delta)
		if measured(): contacts += member.ship.get_slide_collision_count()
	send_accumulator += delta
	if send_accumulator >= 0.05:
		send_accumulator = fmod(send_accumulator, 0.05)
		sequence += 1
		var positions: Dictionary = {}
		var records: Dictionary = {}
		for id: int in members:
			var ship: HandlingShip = members[id].ship
			positions[id] = ship.position
			records[id] = [id, ship.position, ship.rotation.y, ship.velocity, ship.state.fuel_liters]
		grid.rebuild(positions)
		for id: int in members:
			var visible: Array = []
			for other: int in grid.relevant(id): visible.append(records[other])
			if measured():
				possible_records += members.size()
				sent_records += visible.size()
			send(server, id, ["state", sequence, Time.get_ticks_msec(), id, members[id].ack, visible, members[id].action])
	if measured(): ticks.append((Time.get_ticks_usec() - start) / 1000.0)
	if measured(): engine_ticks.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if measured(): active_counts.append(members.size())
	if elapsed() > 19: finish_run()

func _process(delta: float) -> void:
	if finished or role == "server": return
	if role == "observer" and measured(): client_frames.append(delta * 1000)
	send_accumulator += delta
	var due: bool = send_accumulator >= 0.05
	if due: send_accumulator = fmod(send_accumulator, 0.05)
	for client: Dictionary in clients:
		var peer: ENetMultiplayerPeer = client.peer
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED: peer.poll()
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			if client.rejoined and elapsed() > client.retry:
				peer.close()
				client.peer = new_client()
				client.hello = false
				client.retry = elapsed() + 2
			continue
		if not client.hello:
			send(peer, 1, ["hello", client.slot], true)
			client.hello = true
		if due:
			client.seq += 1
			send(peer, 1, ["input", client.seq, 0.6, 0.1, 0.0, Time.get_ticks_msec()])
			if client.seq % 10 == 0: send(peer, 1, ["action", client.seq / 10], true)
		if elapsed() > 7 and not client.rejoined and client.slot % 5 == 1:
			send(peer, 1, ["rejoin"], true)
			client.rejoined = true
			client.retry = elapsed() + 0.5
		while peer.get_available_packet_count() > 0:
			var bytes: PackedByteArray = peer.get_packet()
			if measured(): received_bytes += bytes.size()
			var packet: Variant = bytes_to_var(bytes)
			if role == "observer" and packet is Array and packet.size() == 7 and packet[0] == "state": observe(packet)
	if role == "observer" and samples.size() >= 2:
		var target: float = Time.get_ticks_msec() - clock_offset - 150
		while samples.size() > 2 and samples[1].stamp <= target: samples.pop_front()
		var a: Dictionary = samples[0]
		var b: Dictionary = samples[1]
		var weight: float = clampf((target - a.stamp) / maxf(1, b.stamp - a.stamp), 0, 1)
		var next: Vector3 = a.position.lerp(b.position, weight)
		if measured(): max_motion_speed = maxf(max_motion_speed, next.distance_to(presented) / maxf(delta, 0.000001))
		presented = next
		if is_instance_valid(rendered_ship):
			rendered_ship.position = next - samples[0].initial
			rendered_ship.rotation.y = lerp_angle(a.yaw, b.yaw, weight)
	if elapsed() > 18: finish_run()

func observe(packet: Array) -> void:
	if packet[1] <= last_sequence: return
	last_sequence = packet[1]
	var now: int = Time.get_ticks_msec()
	clock_offset = minf(clock_offset, now - packet[2])
	retained = packet[5].size()
	for record: Array in packet[5]:
		if record[0] != packet[3]: continue
		var initial: Vector3 = record[1] if samples.is_empty() else samples[0].initial
		samples.append({"stamp": packet[2], "position": record[1], "yaw": record[2], "initial": initial})
		while samples.size() > 16: samples.pop_front()
		if samples.size() == 1: presented = record[1]
		if measured():
			if last_packet > 0: gaps.append(now - last_packet)
			latencies.append(now - packet[4])
			snapshots += 1
		last_packet = now

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	var total: float = 0
	for value: float in values: total += value
	return {"samples": values.size(), "mean": total / values.size(), "p95": values[int((values.size() - 1) * 0.95)], "p99": values[int((values.size() - 1) * 0.99)], "max": values.back()}

func finish_run() -> void:
	finished = true
	if role == "server":
		check(max_members == count, "Reached requested simultaneous clients")
		check(joins >= count + maxi(1, count / 5) and departures >= maxi(1, count / 5), "Reconnect traffic exercised")
		check(actions > count * 10 and accepted_inputs > count * 100, "Action and helm traffic reached authority")
		check(ticks.size() > 600, "Measured sufficient authority ticks")
		check(stats(active_counts).mean > count * 0.95, "Maintain requested load except bounded reconnect gaps")
		if layout == "crowded": check(contacts > 0, "Crowded fixture exercises actual quay contact")
	elif role == "observer":
		check(snapshots > 150 and not samples.is_empty(), "Real observer receives ongoing motion")
		check(max_motion_speed < 25 and presented.is_finite(), "Observer has no unbounded motion jump")
	var result: Dictionary = {"role": role, "layout": layout, "requested_clients": count, "failures": failures,
		"max_clients": max_members, "joins": joins, "departures": departures, "actions": actions, "inputs": accepted_inputs,
		"tick_ms": stats(ticks), "tick_period_ms": stats(periods), "snapshot_gap_ms": stats(gaps), "input_ack_ms": stats(latencies),
		"engine_physics_ms": stats(engine_ticks),
		"active_clients": stats(active_counts),
		"client_frame_ms": stats(client_frames), "largest_application_packet_bytes": largest_packet,
		"max_presentation_speed_mps": max_motion_speed, "snapshots": snapshots, "last_relevant_count": retained,
		"sent_bytes": sent_bytes, "received_bytes": received_bytes, "measurement_seconds": 14,
		"sent_records": sent_records, "unfiltered_records": possible_records, "collision_contacts": contacts}
	var file: FileAccess = FileAccess.open(result_dir.path_join(role + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("CAPACITY_%s_%s" % [role.to_upper(), "PASS" if failures == 0 else "FAIL"])
	if server != null: server.close()
	for client: Dictionary in clients: client.peer.close()
	get_tree().quit(0 if failures == 0 else 1)
