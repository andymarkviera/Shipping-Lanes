extends Node
const Session = preload("res://features/network/public_peer_session.gd")
var session: Node
var folder: String
var sequence: int = 0
var started: int

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--peer-folder="): folder = arg.trim_prefix("--peer-folder=")
	if folder.is_empty(): get_tree().quit(1); return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "/config.json"))
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
	if Time.get_ticks_msec() - started > 240000: get_tree().quit(); return
	var path: String = folder + "/command-" + str(sequence) + ".json"
	if not FileAccess.file_exists(path): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	var result: Dictionary = {"ok": true}
	match data.get("op"):
		"ticket": session.submit_ticket(data.ticket)
		"helm": session.send_helm(int(data.sequence), data.throttle, data.get("rudder", 0.0), data.get("candidate", {}))
		"disconnect": session.close_client()
		"status":
			result = {"nonce": session.nonce, "binding": session.binding, "snapshot": session.last_snapshot, "notice": session.notice, "ticket_sent": session.ticket_sent, "members": session.members.size(), "accepted": session.accepted_commands, "rejected": session.rejected_commands, "ships": [], "visible_ships": session.world_view.replicas.keys(), "replicas": []}
			for id: String in session.world_view.replicas:
				var replica: Dictionary = session.world_view.replicas[id]
				result.replicas.append({"ship": id, "x": replica.node.position.x, "z": replica.node.position.z, "inert": replica.node.process_mode == Node.PROCESS_MODE_DISABLED and replica.node.collision_layer == 0 and replica.node.collision_mask == 0})
			for record: Dictionary in session.members.values():
				result.ships.append({"ship": record.ship, "generation": record.generation, "active": record.hull.authority.active, "space": record.hull.ship.get_world_3d().get_instance_id(), "distance": record.hull.ship.position.length(), "speed": record.hull.ship.velocity.length(), "throttle": record.hull.ship.commanded_throttle})
	write_result("reply-" + str(sequence), result)
	sequence += 1
