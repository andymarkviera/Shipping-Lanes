extends "res://features/network/local_network_test.gd"
var role: String
var port: int
var result_dir: String
var checks: int = 0
var failures: int = 0
var replies: Array[Dictionary] = []
var done: bool = false
var old_guest: String = ""

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
	super._ready()
	automated_input = true
	AudioServer.set_bus_mute(0, true)
	role = argument("--network-role=")
	port = int(argument("--network-port="))
	result_dir = argument("--network-results=")
	actions.result_received.connect(func(response: Dictionary): replies.append(response))
	run.call_deferred()

func wait_for(condition: Callable, seconds: float = 8) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	return condition.call()

func make(kind: String, seq: int, payload: Dictionary = {}) -> Dictionary:
	return ShipActions.make_request(session.epoch, multiplayer.get_unique_id(), replication.local_entity(), kind, seq, payload)

func ask(data: Dictionary) -> Dictionary:
	var before: int = replies.size()
	actions.submit(data)
	check(await wait_for(func(): return replies.size() > before), "Typed result returns over reliable channel")
	return replies.back() if replies.size() > before else {"code": "TIMEOUT", "value": -1, "duplicate": false, "applied": false}

@rpc("any_peer", "call_remote", "reliable", 0)
func finish_client(previous_entity: String) -> void:
	if session.hosting and multiplayer.get_remote_sender_id() in multiplayer.get_peers():
		old_guest = previous_entity
		done = true

func run() -> void:
	if role == "host":
		check(session.host_session(port) == OK, "Host action fixture")
		await host_checks()
		var file: FileAccess = FileAccess.open(result_dir.path_join("ready"), FileAccess.WRITE)
		file.store_string("ready")
		file.close()
		check(await wait_for(func(): return done, 18), "Client finishes forged/retried/reconnect actions")
		check(session.roster.has(old_guest) and actions.pulses.get(old_guest, 0) == 1, "Same ship has a new connection-scoped harmless action stream")
		check(actions.pulses.get(replication.local_entity(), 0) == 140, "Client could not mutate host action state")
		await get_tree().create_timer(0.3).timeout
	else:
		check(session.join_session(port) == OK, "Client joins action fixture")
		check(await wait_for(func(): return session.roster.size() == 2), "Client has authoritative roster")
		await client_checks()
	var evidence: Dictionary = {"role": role, "checks": checks, "failures": failures, "wire_results": actions.received_results}
	var file: FileAccess = FileAccess.open(result_dir.path_join(role + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence))
	file.close()
	print("ACTION_METRICS ", JSON.stringify(evidence))
	print("NETWORK_%s_PASS" % role.to_upper() if failures == 0 else "NETWORK_FAIL")
	session.stop()
	get_tree().quit(0 if failures == 0 else 1)

func host_checks() -> void:
	var first: Dictionary = make("test_pulse", 1)
	check(actions.execute(1, first).value == 1, "Harmless action commits once")
	var repeated: Dictionary = actions.execute(1, first)
	check(repeated.duplicate and not repeated.applied and repeated.value == 1, "Duplicate returns original receipt without repeated effect")
	for seq: int in range(2, 141): actions.execute(1, make("test_pulse", seq))
	var id: String = replication.local_entity()
	check(actions.receipts[id].size() == ShipActions.RECEIPT_LIMIT, "Receipt cache stays bounded")
	check(actions.execute(1, first).code == "STALE_ACTION" and actions.pulses[id] == 140, "Evicted action cannot execute again")
	var recycled: Dictionary = make("test_pulse", 141)
	recycled.action_id = first.action_id
	check(actions.execute(1, recycled).code == "BAD_ACTION_ID", "Old action ID cannot be recycled with a new sequence")
	check(actions.execute(1, {}).code == "BAD_REQUEST", "Missing typed header rejected")
	var wrong: Dictionary = make("unknown", 1)
	check(actions.execute(1, wrong).code == "UNKNOWN_ACTION", "No arbitrary action dispatcher")
	wrong = make("test_pulse", 141, {"extra": 1})
	check(actions.execute(1, wrong).code == "BAD_PAYLOAD", "Unknown payload fields rejected")
	wrong = make("test_pulse", 141)
	wrong.version = 1.0
	check(actions.execute(1, wrong).code == "BAD_REQUEST", "Header version has strict integer type")
	var helm: Dictionary = make("helm", 1, {"throttle": 0.4, "rudder": 0.0, "lateral": 0.0, "sent_ms": 1})
	check(actions.execute(1, helm).applied, "Typed helm writes authoritative intent")
	var accepted_at: int = replication.orders[id].at
	wrong = helm.duplicate(true)
	wrong.payload.throttle = 0.2
	check(actions.execute(1, wrong).code == "ID_CONFLICT", "Same action ID with changed payload is rejected")
	check(actions.execute(1, helm).duplicate and replication.orders[id].at == accepted_at, "Helm retry does not refresh dead-man timer")
	var limited: Dictionary = make("helm", 2, {"throttle": 0.3, "rudder": 0.0, "lateral": 0.0, "sent_ms": 2})
	check(actions.execute(1, limited).code == "RATE_LIMITED", "Command rate bound returns explicit code")
	await get_tree().create_timer(0.03).timeout
	check(actions.execute(1, limited).duplicate and replication.orders[id].throttle == 0.4, "Rejected command retry never applies later")
	wrong = make("helm", 3, {"throttle": NAN, "rudder": 0.0, "lateral": 0.0, "sent_ms": 3})
	check(actions.execute(1, wrong).code == "NONFINITE", "Nonfinite control rejected")
	wrong.payload.throttle = 2.0
	check(actions.execute(1, wrong).code == "OUT_OF_RANGE", "Ship-specific bounds checked")
	wrong.payload.throttle = "0.4"
	check(actions.execute(1, wrong).code == "BAD_PAYLOAD", "String is not a control number")
	check(not replication.accept_input(1, []), "Malformed legacy ingress cannot index missing fields")

func client_checks() -> void:
	var pulse: Dictionary = make("test_pulse", 1)
	var response: Dictionary = await ask(pulse)
	check(response.code == "OK" and response.value == 1 and response.applied, "Owned remote test action succeeds")
	# Deliberately discard the response, as if the caller lost its reply.
	response = await ask(pulse)
	check(response.duplicate and response.value == 1 and not response.applied, "Lost-reply retry returns original result")
	var forged: Dictionary = make("test_pulse", 2)
	for id: String in session.roster:
		if session.roster[id].peer_id == 1: forged.entity = id
	check((await ask(forged)).code == "NOT_OWNER", "Remote cannot act on host ship")
	forged.player = 1
	check((await ask(forged)).code == "NOT_OWNER", "Claimed player cannot override transport sender")
	forged = make("test_pulse", 2)
	forged.epoch = "old-session"
	check((await ask(forged)).code == "STALE_SESSION", "Previous session rejected")
	forged = make("test_pulse", 2)
	forged.entity = "absent"
	check((await ask(forged)).code == "UNKNOWN_ENTITY", "Unknown entity rejected")
	var helm: Dictionary = make("helm", 1, {"throttle": 0.5, "rudder": 0.2, "lateral": 0.0, "sent_ms": Time.get_ticks_msec()})
	check((await ask(helm)).applied, "Remote helm uses same authority path")
	check((await ask(helm)).duplicate, "Remote repeated helm has no second application")
	forged = helm.duplicate(true)
	forged.payload.rudder = -0.2
	check((await ask(forged)).code == "ID_CONFLICT", "Wire payload mismatch returns clear error")
	await get_tree().create_timer(0.7).timeout
	check(replication.latest.has(pulse.entity) and absf(replication.latest[pulse.entity].command) < 0.001, "Retried helm still times out to neutral")
	var old: String = pulse.entity
	session.stop()
	await get_tree().create_timer(0.3).timeout
	check(session.join_session(port) == OK, "Reconnect action client")
	check(await wait_for(func(): return session.roster.size() == 2), "New controller roster arrives")
	check((await ask(pulse)).code == "NOT_OWNER", "Previous transport sender cannot revive its old action")
	response = await ask(make("test_pulse", 1))
	check(response.code == "OK" and response.value == 1 and not response.duplicate, "New connection has isolated transient sequence state")
	finish_client.rpc_id(1, old)
	await get_tree().create_timer(0.2).timeout
