extends "res://features/network/public_entry.gd"
var folder: String
var probe_sequence: int = 0
var started: int = 0

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--login-folder="): folder = arg.trim_prefix("--login-folder=")
	super._ready()
	started = Time.get_ticks_msec()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "/config.json"))
	write_result("ready", {"ok": configure_services(data)})

func write_result(name_: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(folder + "/" + name_ + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(folder + "/" + name_ + ".tmp", folder + "/" + name_ + ".json")

func _process(delta: float) -> void:
	super._process(delta)
	if Time.get_ticks_msec() - started > 180000: get_tree().quit(); return
	var path: String = folder + "/command-%d.json" % probe_sequence
	if not FileAccess.file_exists(path): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	var result: Dictionary = {"ok": true}
	match data.get("op"):
		"begin": start_join(0, false)
		"cancel": cancel_join()
		"expire": login.deadline = 0
		"disconnect": session.close_client()
		"drive":
			presentation.controls.wait_for_release = false
			Input.action_press("ship_throttle_up")
		"status":
			result = {"token_result": login.response_result, "token_status": login.response_status, "http_status": login.request.get_http_client_status() if is_instance_valid(login.request) else -1, "connection_notice": session.notice, "phase": login.phase, "url": login.authorization_url, "notice": notice, "busy": busy, "joined": joined, "binding": session.binding, "ready": presentation.ready_to_drive, "snapshot": session.last_snapshot, "overlay": entry_layer.visible, "token_cleared": access_token.is_empty()}
	write_result("reply-%d" % probe_sequence, result)
	probe_sequence += 1
