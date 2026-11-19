extends RefCounted
## Local launcher control only. No sockets, HTTP, package work or pause.
var folder: String = ""
var elapsed: float = 0.0
var stopping: bool = false

func document(name: String, value: Dictionary) -> void:
	var path: String = folder.path_join(name)
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(value))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)

func poll(runtime: Node, delta: float) -> void:
	if folder.is_empty() or stopping: return
	elapsed += delta
	if elapsed < 1.0: return
	elapsed = 0.0
	if FileAccess.file_exists(folder.path_join("stop.request")):
		stopping = true
		runtime.updating = true # Reject joins during the final checkpoint.
		runtime.shutdown_saves()
		document("stopped.json", {"pid": OS.get_process_id(), "saved": not runtime.save_failed})
		runtime.get_tree().quit(1 if runtime.save_failed else 0)
		return
	document("status.json", {"pid": OS.get_process_id(), "version": runtime.Connection.VERSION,
		"players": runtime.contexts.size(), "listening": runtime.peer != null and runtime.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
		"save_failed": runtime.save_failed})
