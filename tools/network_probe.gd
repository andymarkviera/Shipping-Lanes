extends "res://features/network/local_network_test.gd"
var failures: int = 0
var checks: int = 0
var evidence: Array = []
var role: String
var port: int
var result_dir: String

func argument(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

func _ready() -> void:
	super._ready()
	automated_input = true
	role = argument("--network-role=")
	port = int(argument("--network-port="))
	result_dir = argument("--network-results=")
	session.changed.connect(func(): print("NETWORK_EVENT ", role, " ", session.notice, " count=", session.roster.size()))
	print("NETWORK_START ", role, " port=", port)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func until_count(count: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + 8000
	while session.roster.size() != count and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return session.roster.size() == count

func record_round(round_index: int) -> void:
	var ids: Array = session.roster.keys()
	ids.sort()
	evidence.append(ids)
	check(ships.size() == 2, "Exactly two runtime hulls, round %d" % round_index)
	check(ids.size() == 2 and ids[0] != ids[1], "Unique entity IDs")
	for id: String in ids:
		check(ships[id].state.instance_id == id and ships[id].get_multiplayer_authority() == 1, "Host authority and stable instance ID")

func run() -> void:
	if role == "host":
		check(session.host_session(port) == OK, "Host starts")
		var marker: FileAccess = FileAccess.open(result_dir.path_join("ready"), FileAccess.WRITE)
		marker.store_string("ready")
		marker.close()
		var host_id: String = session.roster.keys()[0]
		var guest_instance: int = 0
		var guest_path: String = ""
		var private_realm: String = "private_" + session.epoch
		for round_index: int in range(3):
			if not await until_count(2):
				check(false, "Client did not join")
				break
			record_round(round_index)
			var guest: String = session.guest_record.entity_id
			var ledger: DurableEconomy = session.economies[guest]
			var request: Dictionary = EconomyLedger.request("reconnect_purchase", "purchase_container", 1, 0)
			if round_index == 0:
				guest_instance = ships[guest].get_instance_id()
				guest_path = "user://n/" + session.epoch + "/g.db"
				ships[guest].position = Vector3(80, 0, 65)
				ships[guest].state.fuel_liters = 543.0
				check(ledger.execute("player_test", request).ok, "Commit guest purchase before disconnect")
			else:
				check(ships[guest].get_instance_id() == guest_instance, "Same authoritative hull object restored")
				check(ships[guest].position.distance_to(Vector3(80, 0, 65)) < 0.01, "Position survives despawn/reconnect")
				check(ships[guest].state.fuel_liters <= 543.0 and ships[guest].state.fuel_liters > 540.0, "Fuel not reset or rewarded")
				check(ships[guest].commanded_throttle == 0 and ships[guest].velocity == Vector3.ZERO, "Returning hull is neutral/stationary")
				check(ledger.execute("player_test", request).duplicate, "Reconnected purchase retry retains original receipt")
			check(ledger.view().player_minor == 10000, "No new wallet on reconnect")
			check(session.economies.size() == 2, "Exactly one ledger per authority record")
			check(session.roster.has(host_id), "Host identity survives joins")
			if round_index < 2:
				check(await until_count(1), "Disconnect removes remote ship")
				check(ships.size() == 1 and ships.has(host_id), "No orphan remote hull")
				check(parked.size() == 1 and parked[guest].process_mode == Node.PROCESS_MODE_DISABLED and parked[guest].collision_layer == 0 and not parked[guest].visible, "Disconnected hull has no simulation, collision, or presentation")
				check(session.economies.has(guest), "Disconnect retains authoritative economy")
			else:
				await get_tree().create_timer(0.7).timeout
		session.stop("Host test complete")
		check(ships.is_empty() and parked.is_empty() and session.economies.is_empty(), "Host shutdown removes hulls and closes ledgers")
		var restored: DurableEconomy = DurableEconomy.new()
		check(restored.open_store(guest_path, private_realm), "Committed guest economy opens after host shutdown")
		check(restored.execute("player_test", EconomyLedger.request("reconnect_purchase", "purchase_container", 1, 0)).duplicate, "Shutdown cannot duplicate committed purchase")
		restored.close_store()
	else:
		var previous_remote_id: String = ""
		for round_index: int in range(3):
			if round_index == 1:
				var credential: String = session.reconnect_token()
				check(credential.length() == 64, "Reconnect credential retained across local disconnect")
				get_tree().set_meta("local_reconnect_" + str(port), "0".repeat(64))
				session.join_session(port)
				var rejected_deadline: int = Time.get_ticks_msec() + 4000
				while session.connecting and Time.get_ticks_msec() < rejected_deadline: await get_tree().process_frame
				check(not session.connecting and session.roster.is_empty(), "Wrong credential cannot claim or replace parked record")
				get_tree().set_meta("local_reconnect_" + str(port), credential)
			check(session.join_session(port) == OK, "Client transport starts")
			if not await until_count(2):
				check(false, "Client did not receive roster")
				break
			record_round(round_index)
			var initial: Dictionary = session.roster.duplicate(true)
			var local_id: String = ""
			for id: String in initial:
				if initial[id].peer_id == multiplayer.get_unique_id(): local_id = id
			check(not local_id.is_empty() and (previous_remote_id.is_empty() or local_id == previous_remote_id), "Returning guest reclaims the same entity")
			previous_remote_id = local_id
			for index: int in range(4): session.hello.rpc_id(1, LocalShipSession.PROTOCOL)
			# A local/client-authored snapshot must never create or replace entities.
			session.receive_roster("forged", 999, [])
			await get_tree().create_timer(0.25).timeout
			check(session.roster == initial and ships.size() == 2, "Duplicate hello and unauthorized roster do not duplicate/change ships")
			if round_index < 2:
				session.stop()
				check(ships.is_empty(), "Client disconnect clears hulls")
				await get_tree().create_timer(0.3).timeout
			else:
				check(await until_count(0), "Host loss clears client roster")
				check(ships.is_empty() and session.notice == "Host disconnected", "Host-loss feedback and cleanup")
		# No host remains: prove bounded connection failure and usable cleanup.
		session.join_session(port)
		var deadline: int = Time.get_ticks_msec() + 9000
		while session.connecting and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		check(not session.connecting and ships.is_empty(), "Unavailable host fails within deadline")
		session.stop()
	var file: FileAccess = FileAccess.open(result_dir.path_join(role + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"role": role, "rounds": evidence, "checks": checks, "failures": failures}))
	file.close()
	print("NETWORK_%s_PASS (%d checks)" % [role.to_upper(), checks] if failures == 0 else "NETWORK_FAIL")
	get_tree().quit(0 if failures == 0 else 1)
