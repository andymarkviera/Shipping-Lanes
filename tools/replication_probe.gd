extends "res://features/network/local_network_test.gd"
var role: String
var port: int
var result_dir: String
var checks: int = 0
var failures: int = 0
var active: bool = false
var finished: bool = false
var throttle: float = 1.0
var tick_time: float = 0
var previous: Dictionary = {}
var maximum_step_speed: float = 0
var maximum_sample_gap: float = 0
var rtt_samples: Array[float] = []

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
	if not active: return
	tick_time += delta
	if tick_time >= 0.05:
		tick_time = fmod(tick_time, 0.05)
		replication.submit(throttle if role == "client" else 0.4, 0.4 if role == "client" else -0.3, 0)

func _process(delta: float) -> void:
	super._process(delta)
	if role != "client" or not active or replication.snapshot_count < 10: return
	if replication.rtt_ms > 0: rtt_samples.append(replication.rtt_ms)
	if rtt_samples.size() > 2000: rtt_samples.pop_front()
	for id: String in ships:
		if previous.has(id) and delta > 0:
			maximum_step_speed = maxf(maximum_step_speed, ships[id].position.distance_to(previous[id]) / delta)
		previous[id] = ships[id].position
		if replication.latest.has(id): maximum_sample_gap = maxf(maximum_sample_gap, ships[id].position.distance_to(replication.latest[id].position))

@rpc("any_peer", "call_remote", "reliable")
func client_finished() -> void:
	if session.hosting and multiplayer.get_remote_sender_id() in multiplayer.get_peers(): finished = true

func run() -> void:
	if role == "host":
		check(session.host_session(port) == OK, "Host starts")
		var marker: FileAccess = FileAccess.open(result_dir.path_join("ready"), FileAccess.WRITE)
		marker.store_string("ready")
		marker.close()
	else: check(session.join_session(port) == OK, "Client starts")
	var deadline: int = Time.get_ticks_msec() + 8000
	while session.roster.size() != 2 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	check(session.roster.size() == 2, "Both players joined")
	if session.roster.size() != 2:
		get_tree().quit(1)
		return
	active = true
	var mine: String = replication.local_entity()
	if role == "client":
		var host_id: String = ""
		for id: String in session.roster:
			if session.roster[id].peer_id == 1: host_id = id
		for args: Array in [[session.epoch, host_id, 100, -0.6, 0, 0], ["wrong_epoch", mine, 101, 1, 0, 0], [session.epoch, "unknown", 102, 1, 0, 0], [session.epoch, mine, 103, NAN, 0, 0], [session.epoch, mine, 104, 9, 0, 0], [session.epoch, mine, -1, 1, 0, 0]]:
			replication.request_input.rpc_id(1, args[0], args[1], args[2], args[3], args[4], args[5], Time.get_ticks_msec())
			await get_tree().create_timer(0.03).timeout
		await get_tree().create_timer(8).timeout
		check(ships[mine].position.z > 10, "Authorized client sails forward")
		check(ships[mine].rotation.y < -0.01, "Client rudder turns authoritative hull")
		check(ships[host_id].position.z > 3 and ships[host_id].rotation.y > 0, "Host controls only its own boat")
		check(ships[mine].state.fuel_liters < 999, "Host fuel replicates")
		check(ships[mine].distance_m == 0 and not ships[mine].is_physics_processing(), "Client does not simulate physical movement/fuel")
		check(replication.snapshot_count > 60, "Sustained snapshots arrive")
		check(maximum_step_speed < 25 and maximum_sample_gap < 2, "Buffered remote motion stays bounded")
		check(replication.pending.size() < 10 and replication.samples[mine].size() <= 16, "Queues remain bounded")
		replication.input_enabled = false
		await get_tree().create_timer(1.2).timeout
		check(absf(replication.latest[mine].command) < 0.001, "Missing inputs timeout to neutral")
		replication.input_enabled = true
		await get_tree().create_timer(1).timeout
		check(replication.latest[mine].command > 0.9, "Input resumes after interruption")
		if replication.impairment: check(replication.dropped > 10, "Impairment drops input packets")
		check(not rtt_samples.is_empty(), "Input acknowledgement latency measured")
		check(not rtt_samples.is_empty() and rtt_samples.max() < 800, "Fresh input acknowledgement stays below 800 ms")
		client_finished.rpc_id(1)
		active = false
		await get_tree().create_timer(0.5).timeout
	else:
		deadline = Time.get_ticks_msec() + 16000
		while not finished and Time.get_ticks_msec() < deadline: await get_tree().process_frame
		check(finished, "Client completed movement test")
		check(replication.rejected_inputs >= 6, "Ownership, epoch, bounds, finite and sequence guards reject requests")
		check(replication.accepted_inputs > 100, "Host and client use validated input path")
		for id: String in ships:
			check(ships[id].distance_m > 3 and ships[id].state.fuel_liters < 1000, "Host simulates each hull and fuel")
			check(ships[id].position.is_finite() and ships[id].velocity.length() <= 20, "Host movement stays bounded")
		check(ships[mine].commanded_throttle >= 0, "Remote cannot reverse host boat")
		if replication.impairment: check(replication.dropped > 10, "Impairment drops snapshots")
		active = false
		await get_tree().create_timer(0.7).timeout
	var average: float = 0
	for value: float in rtt_samples: average += value / maxf(1, rtt_samples.size())
	var metrics: Dictionary = {"role": role, "checks": checks, "failures": failures, "rtt_mean_ms": average, "rtt_max_ms": rtt_samples.max() if not rtt_samples.is_empty() else 0, "max_presentation_speed_mps": maximum_step_speed, "max_latest_sample_gap_m": maximum_sample_gap, "snapshots": replication.snapshot_count, "dropped": replication.dropped}
	var file: FileAccess = FileAccess.open(result_dir.path_join(role + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics))
	file.close()
	print("REPLICATION_METRICS ", JSON.stringify(metrics))
	print("NETWORK_%s_PASS" % role.to_upper() if failures == 0 else "NETWORK_FAIL")
	session.stop()
	get_tree().quit(0 if failures == 0 else 1)
