extends "res://features/network/public_client.gd"
var folder: String
var sequence: int = 0
var sent_at: Dictionary = {}
var frame_ms: Array[float] = []
var started: int

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--peer-folder="): folder = arg.trim_prefix("--peer-folder=")
	if folder.is_empty(): get_tree().quit(1); return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "/config.json"))
	if config.role == "client":
		super._ready()
		presentation.controls_enabled = false
	else:
		session = Session.new()
		session.name = "Session"
		add_child(session)
	var error: Error = session.start_server(config) if config.role == "server" else session.start_client(config)
	started = Time.get_ticks_msec()
	var cert: X509Certificate = X509Certificate.new()
	cert.load(config.certificate)
	write_result("ready", {"ok": error == OK, "error": error, "fingerprint": FileAccess.get_sha256(config.certificate)})
	if error != OK: get_tree().quit(1)

func write_result(name_: String, result: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(folder + "/" + name_ + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	DirAccess.rename_absolute(folder + "/" + name_ + ".tmp", folder + "/" + name_ + ".json")

func _process(_delta: float) -> void:
	frame_ms.append(_delta * 1000.0)
	if frame_ms.size() > 600: frame_ms.pop_front()
	if Time.get_ticks_msec() - started > 240000: get_tree().quit(); return
	var path: String = folder + "/command-" + str(sequence) + ".json"
	if not FileAccess.file_exists(path): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	var result: Dictionary = {"ok": true}
	match data.get("op"):
		"reconnect": session.start_client(session.config.duplicate(true))
		"ticket":
			if data.has("version"): session.join_public.rpc_id(1, int(data.version), data.ticket)
			else: session.submit_ticket(data.ticket)
		"helm":
			sent_at[int(data.sequence)] = Time.get_ticks_msec()
			if sent_at.size() > 128: sent_at.erase(sent_at.keys()[0])
			session.send_helm(int(data.sequence), data.throttle, data.get("rudder", 0.0), data.get("candidate", {}), data.get("lateral", 0.0))
		"pace_burst":
			var previous: bool = presentation.controls_enabled
			presentation.controls_enabled = true
			var before: int = presentation.sequence
			for i: int in 30: presentation._physics_process(1.0 / 60.0)
			result = {"sent": presentation.sequence - before}
			presentation.controls_enabled = previous
		"input_off":
			presentation.controls_enabled = false
			Input.action_release("ship_thruster_left")
			Input.action_release("ship_thruster_right")
		"capture":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(folder + "/helm.png")
		"thruster":
			presentation.controls_enabled = true
			presentation.controls.wait_for_release = false
			Input.action_release("ship_thruster_left")
			Input.action_release("ship_thruster_right")
			if data.get("axis", 0) != 0: Input.action_press("ship_thruster_right" if data.axis > 0 else "ship_thruster_left")
		"drive":
			presentation.controls_enabled = true
			presentation.controls.wait_for_release = false
			Input.action_release("ship_throttle_up")
			Input.action_release("ship_throttle_down")
			Input.action_press("ship_throttle_up" if data.get("axis", 1) > 0 else "ship_throttle_down")
		"menu":
			Input.action_release("ship_throttle_down")
			Input.action_release("ship_throttle_up")
			presentation.set_menu(data.get("open", true))
		"stale":
			session.last_snapshot.received_at = Time.get_ticks_msec() - 2000
			presentation._process(0)
			presentation._physics_process(0.1)
			result = {"ready": presentation.ready_to_drive, "order": presentation.throttle_order}
		"focus_loss": presentation.controls.window_focused = false
		"zoom": presentation.camera_rig.zoom(-1)
		"disconnect": session.close_client()
		"status":
			result = {"nonce": session.nonce, "tick": session.world_view.tick, "frames_drawn": Engine.get_frames_drawn(), "display": DisplayServer.get_name(), "frame_ms": frame_ms, "binding": session.binding, "snapshot": session.last_snapshot, "notice": session.notice, "join_failure": session.join_failure, "failure_message": session.failure_message(session.join_failure), "ticket_sent": session.ticket_sent, "members": session.members.size(), "snapshot_work_us": session.snapshot_work_us, "physics_work_us": session.physics_work_us, "snapshot_bytes": session.snapshot_bytes_sent, "snapshot_packets": session.snapshot_packets_sent, "max_snapshot_bytes": session.max_snapshot_bytes, "accepted": session.accepted_commands, "rejected": session.rejected_commands, "ships": [], "visible_ships": session.world_view.replicas.keys(), "replicas": []}
			if sent_at.has(int(session.last_snapshot.get("sequence", -2))):
				result.ack_ms = session.last_snapshot.received_at - sent_at[int(session.last_snapshot.sequence)]
			if presentation != null:
				result.presentation = {"ready": presentation.ready_to_drive, "camera": is_instance_valid(presentation.camera_rig.focus), "zoom": presentation.camera_rig.distance_order, "order": presentation.throttle_order, "hud": presentation.readout.text, "menu": presentation.controls.menu_open, "indicator": presentation.throttle_display.motion.text, "indicator_value": presentation.throttle_display.slider.value}
			for id: String in session.world_view.replicas:
				var replica: Dictionary = session.world_view.replicas[id]
				result.replicas.append({"ship": id, "x": replica.node.position.x, "z": replica.node.position.z, "inert": replica.node.process_mode == Node.PROCESS_MODE_DISABLED and replica.node.collision_layer == 0 and replica.node.collision_mask == 0})
			for record: Dictionary in session.members.values():
				result.ships.append({"ship": record.ship, "generation": record.generation, "active": record.hull.authority.active, "space": record.hull.ship.get_world_3d().get_instance_id(), "distance": record.hull.ship.position.length(), "speed": record.hull.ship.velocity.length(), "throttle": record.hull.ship.commanded_throttle, "lateral": record.hull.ship.lateral_order, "side_speed": record.hull.ship.lateral_speed()})
	write_result("reply-" + str(sequence), result)
	sequence += 1
