extends "res://features/network/private_network_test.gd"
var checks: int = 0
var failures: int = 0
var role: String
var result_dir: String
var port: int
var heavy: bool

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _ready() -> void:
	super._ready()
	automated_input = true
	role = argument("--identity-role=")
	result_dir = argument("--identity-folder=")
	port = int(argument("--identity-port="))
	heavy = argument("--identity-heavy=") == "yes"
	session.ship_definition_id = "ship_heavy_lifter_01" if heavy else "ship_starter_container_01"
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func mark(name: String, data: String = "ready") -> void:
	var file: FileAccess = FileAccess.open(result_dir.path_join(name), FileAccess.WRITE)
	file.store_string(data)
	file.close()

func until(test: Callable, seconds: float = 12) -> bool:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000)
	while not test.call() and Time.get_ticks_msec() < end: await get_tree().process_frame
	return test.call()

func run() -> void:
	if role == "host": await host_test()
	elif role == "recovery": await recovery_test()
	else: await client_test()
	mark(role + ".json", JSON.stringify({"checks": checks, "failures": failures}))
	print("IDENTITY_", role.to_upper(), "_PASS (", checks, ")" if failures == 0 else "_FAIL")
	get_tree().quit(0 if failures == 0 else 1)

func host_test() -> void:
	check(session.host_session(port) == OK, "Secure private host opens")
	if not session.hosting: return
	var world: String = session.store.world_id
	var certificate: String = session.store.fingerprint
	var host_id: String = session.roster.keys()[0]
	mark("invite.json", JSON.stringify(session.invitation))
	check(await until(func(): return session.roster.size() == 2), "First guest admitted")
	if session.roster.size() != 2: return
	var guest: String = session.roster.keys().filter(func(id: String): return id != host_id)[0]
	var first: Dictionary = session.roster[guest].duplicate(true)
	check(await until(func(): return replication.accepted_inputs > 0), "Authenticated live helm RPC accepted")
	replication.orders.clear()
	await get_tree().process_frame
	ships[guest].position = Vector3(80, 0, 65)
	ships[guest].state.fuel_liters = 543.0
	ships[guest].velocity = Vector3.ZERO
	ships[guest].commanded_throttle = 0
	ships[guest].actual_throttle = 0
	ships[guest].yaw_rate = 0
	ships[guest].maneuver(0, 0)
	if heavy:
		ships[guest].attached = true
		ships[guest].payload_body.collision_layer = 0
		ships[guest].payload_visual.reparent(ships[guest].cargo_mount, false)
		ships[guest].payload_shape.disabled = false
	var purchase: Dictionary = EconomyLedger.request("identity_purchase", "purchase_container", 1, 0)
	check(session.economies[guest].execute("player_test", purchase).ok, "Committed economy belongs to durable private member")
	check(session.checkpoint(), "Authoritative ship checkpoint commits")
	mark("armed")
	check(await until(func(): return session.roster.has(guest) and session.roster[guest].generation > first.generation, 25), "Duplicate authenticated login replaces binding")
	if not session.roster.has(guest): return
	await get_tree().process_frame
	var second: Dictionary = session.roster[guest].duplicate(true)
	check(second.player_id == first.player_id and second.peer_id != first.peer_id and ships.size() == 2, "One durable player, one ship, one new helm")
	check(ships[guest].position.distance_to(Vector3(80, 0, 65)) < 0.1 and ships[guest].state.fuel_liters <= 543 and ships[guest].state.fuel_liters > 542, "Reconnect retains pose and fuel")
	check(ships[guest].velocity == Vector3.ZERO and ships[guest].commanded_throttle == 0, "Handoff starts neutral")
	check(actions.execute(first.peer_id, ShipActions.make_request(session.epoch, first.peer_id, guest, "test_pulse", 1, {}, second.generation)).code == "NOT_OWNER", "Old connection cannot control rebound ship")
	check(actions.execute(second.peer_id, ShipActions.make_request(session.epoch, second.peer_id, guest, "test_pulse", 1, {}, first.generation)).code == "NOT_OWNER", "Old connection generation rejected")
	check(not replication.accept_input(second.peer_id, [session.epoch, guest, 99, 0.2, 0.0, 0.0, Time.get_ticks_msec(), first.generation]), "Delayed helm packet from prior generation rejected")
	check(actions.execute(second.peer_id, ShipActions.make_request(session.epoch, second.peer_id, host_id, "test_pulse", 1, {}, second.generation)).code == "NOT_OWNER", "Guest cannot seize host ship")
	check(actions.execute(second.peer_id, ShipActions.make_request(session.epoch, second.peer_id, guest, "test_pulse", 1, {}, second.generation)).ok, "Current generation controls only own ship")
	check(not session.store.save_state(first.player_id, first.generation, capture_private_state(guest)), "Stale generation cannot commit spatial state")
	check(session.economies[guest].execute("player_test", purchase).duplicate and session.economies[guest].view().player_minor == 10000, "No duplicate wallet or purchase after handoff")
	if heavy:
		check(ships[guest].attached, "Attached cargo stays with permitted ship")
		check(not cargo_sync.accept(second.peer_id, session.epoch, guest, 1, "release", first.generation), "Stale generation cargo action rejected")
	var old_epoch: String = session.epoch
	mark("replacement_checked")
	check(await until(func(): return FileAccess.file_exists(result_dir.path_join("restart_requested"))), "Guest ready for host restart")
	session.stop()
	check(ships.is_empty() and parked.is_empty(), "Host departure removes all interactive hulls")
	check(session.host_session(port) == OK, "Host reopens durable private world")
	check(session.store.world_id == world and session.store.fingerprint == certificate and session.roster.has(host_id), "World, certificate and host ownership survive restart")
	mark("restarted")
	check(await until(func(): return session.roster.has(guest)), "Credential reclaims same ship after host restart")
	await get_tree().process_frame
	if session.roster.has(guest):
		check(session.roster[guest].player_id == first.player_id and session.roster[guest].generation > second.generation, "Durable identity advances generation after restart")
		check(ships[guest].position.distance_to(Vector3(80, 0, 65)) < 0.1 and ships[guest].state.fuel_liters <= 543 and ships[guest].state.fuel_liters > 542, "Host restart restores saved pose/fuel")
		if heavy: check(ships[guest].attached, "Host restart restores attached cargo")
		check(session.economies[guest].execute("player_test", purchase).duplicate, "Receipt survives world reopen")
		check(actions.execute(session.roster[guest].peer_id, ShipActions.make_request(old_epoch, session.roster[guest].peer_id, guest, "test_pulse", 2, {}, session.generation(guest))).code == "STALE_SESSION", "Previous process/session commands rejected")
	mark("complete")
	mark("durable.json", JSON.stringify({"world": world, "fingerprint": certificate, "host": host_id, "guest": guest, "player": first.player_id}))
	await get_tree().create_timer(0.3).timeout
	session.stop()

func recovery_test() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(result_dir.path_join("durable.json")))
	check(session.host_session(port) == OK, "New host process opens saved world")
	if not session.hosting: return
	check(session.store.world_id == expected.world and session.store.fingerprint == expected.fingerprint and session.roster.has(expected.host), "Fresh process preserves world certificate and owner")
	mark("recovery_ready")
	check(await until(func(): return session.roster.has(expected.guest)), "New process restores authenticated guest's ship")
	await get_tree().process_frame
	if session.roster.has(expected.guest):
		var guest: String = expected.guest
		check(session.roster[guest].player_id == expected.player, "Player identity independent of both process IDs")
		check(ships[guest].position.distance_to(Vector3(80, 0, 65)) < 0.1 and ships[guest].state.fuel_liters > 542 and ships[guest].state.fuel_liters <= 543, "Fresh process restores pose/fuel")
		check(session.economies[guest].execute("player_test", EconomyLedger.request("identity_purchase", "purchase_container", 1, 0)).duplicate, "Fresh process retains payment receipt")
		if heavy: check(ships[guest].attached, "Fresh process restores attached cargo")
	mark("recovery_complete")
	await get_tree().create_timer(0.3).timeout
	var source_folder: String = session.store.folder
	var host_player: String = session.roster[expected.host].player_id
	session.stop()
	# Independent incomplete copy: never remove or alter the source world's files.
	var incomplete: String = "user://incomplete_private"
	DirAccess.make_dir_recursive_absolute(incomplete)
	for filename: String in ["members.db", "host.crt", "host.key"]:
		check(DirAccess.copy_absolute(source_folder + "/" + filename, incomplete + "/" + filename) == OK, "Create isolated incomplete recovery fixture")
	session.world_folder = incomplete
	check(session.host_session(port) != OK and not session.hosting and ships.is_empty(), "Missing existing ledger fails closed without granting a helm")
	check(not FileAccess.file_exists(incomplete + "/" + host_player + ".db"), "Missing ledger is not silently replaced with a new wallet")

func client_test() -> void:
	var invitation_text: String = FileAccess.get_file_as_string(result_dir.path_join("invite.json"))
	if role == "wrongworld":
		var wrong: Dictionary = JSON.parse_string(invitation_text)
		wrong.world = "0".repeat(32)
		invitation_text = JSON.stringify(wrong)
	check(session.trust_invitation(invitation_text), "Explicit invitation parsed")
	if role in ["replacement", "returning", "wrongworld", "forged"]:
		var token: String = FileAccess.get_file_as_string(result_dir.path_join("test-credential")) if role != "forged" else "0".repeat(64)
		get_tree().set_meta(session.credential_key(), token)
	check(session.join_session(port) == OK, "Verified DTLS connection starts")
	if role in ["forged", "wrongworld", "fresh"]:
		check(await until(func(): return not session.connecting), "Unauthorized connection ends")
		check(session.roster.is_empty() and ships.is_empty(), "Unauthorized connection cannot spawn or seize a ship")
		return
	check(await until(func(): return session.roster.size() == 2), "Authenticated roster arrives")
	if session.roster.size() != 2: return
	var id: String = replication.local_entity()
	check(not id.is_empty(), "Exactly one permitted local helm")
	if role == "returning":
		check(await until(func(): return FileAccess.file_exists(result_dir.path_join("recovery_complete"))), "Fresh host confirms recovery")
		return
	if role == "first":
		replication.submit(0.2, 0.1, 0)
		check(await until(func(): return session.reconnect_token().length() == 64), "Private reconnect credential delivered inside DTLS")
		# Disposable automated test courier only; production retains this in memory.
		mark("test-credential", session.reconnect_token())
		check(await until(func(): return session.roster.is_empty(), 25), "Superseded client disconnected")
		check(ships.is_empty() and replication.local_entity().is_empty(), "Superseded client has no active helm")
	else:
		check(await until(func(): return FileAccess.file_exists(result_dir.path_join("replacement_checked"))), "Host validates control fence")
		mark("restart_requested")
		check(await until(func(): return session.roster.is_empty()), "Host departure ends client control")
		check(await until(func(): return FileAccess.file_exists(result_dir.path_join("restarted"))), "Host restarted")
		check(session.join_session(port) == OK, "Reconnect to same trusted world")
		check(await until(func(): return session.roster.has(id)), "Reopened world returns same ship")
		check(await until(func(): return FileAccess.file_exists(result_dir.path_join("complete"))), "Host completed restart assertions")
