extends SceneTree
## Patch 4.0.5 item 2: real UDP server + two clients (check_dedicated_split.py
## --errors). Each client boots through boot.tscn, so ErrorReports is
## installed as in the game. It raises one error through the reporter's
## Logger (as an uncaught script error would be caught; push_error is not
## used so the run stays free of ERROR lines), with an address, an e-mail and
## the captain's name in it. The runtime sends it on its own (one every
## ERROR_SEND_SECONDS). Then the client floods the server: one oversized
## report and eight more, straight through the RPC.
## The server checks its log, <saves>/../logs/client_errors/client_errors.log:
## every line is a known-fields JSON report with this VERSION, the OS and the
## scene; nothing private is in it; the flood was cut by the rate limit and
## the oversized one refused.
const Reports = preload("res://features/network/error_reports.gd")
const Connection = preload("res://features/network/play_connection.gd")
const FLOOD: int = 8
var runtime: Node3D
var started: int
var checks: int = 0
var failures: int = 0
var raised: bool = false
var flooded_at: int = 0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	change_scene_to_file.call_deferred("res://features/main/boot.tscn")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("ERRORS_CHECK FAILED: " + message)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 60000:
		check(false, "timed out")
		finish()
		return false
	if runtime == null:
		if current_scene != null and current_scene.name == "DedicatedRuntime": runtime = current_scene
		return false
	if runtime.hosting: server_step()
	elif flooded_at > 0:
		# Done sending (the server may already have finished and left).
		if Time.get_ticks_msec() - flooded_at > 2500: finish()
	elif not runtime.entity.is_empty(): client_step()
	return false

func client_step() -> void:
	var reports: Node = Reports.find(self)
	if not raised:
		check(reports != null, "the client runs the error reporter")
		if reports == null: return finish()
		raised = true
		var traces: Array[ScriptBacktrace] = []
		reports.logger._log_error("_process", "res://features/game/game.gd", 99, "", "Probe failure near 172.16.4.9 for probe@example.org by %s" % runtime.captain_name,
			false, Logger.ERROR_TYPE_SCRIPT, traces)
		return
	if flooded_at == 0 and runtime.errors_sent >= 1:
		check(reports.outbox.is_empty(), "the waiting report was handed to the server")
		var base: Dictionary = Reports.make_report("error", "flood", "res://x.gd:1", "", "res://features/game/game.tscn", Connection.VERSION)
		var big: Dictionary = base.duplicate()
		big.message = "x".repeat(12000)
		runtime.client_error_report.rpc_id(1, big)
		for index: int in FLOOD:
			var copy: Dictionary = base.duplicate()
			copy.message = "flood %d" % index
			copy.captain = runtime.captain_name
			runtime.client_error_report.rpc_id(1, copy)
		flooded_at = Time.get_ticks_msec()

func server_step() -> void:
	var log: RefCounted = runtime.error_log
	# Two clients, each: 1 real report + 1 oversized + FLOOD.
	if log.accepted + log.refused < 2 * (2 + FLOOD): return
	var path: String = log.path()
	check(log.folder.ends_with("logs/client_errors"), "the log is in <root>/logs/client_errors (%s)" % log.folder)
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).strip_edges().split("\n", false)
	check(lines.size() == log.accepted, "one line per accepted report (%d lines, %d accepted)" % [lines.size(), log.accepted])
	check(log.accepted >= 2 * 5 and log.accepted <= 2 * 6, "the rate limit let 5 or 6 through per client (%d accepted)" % log.accepted)
	check(log.refused >= 2 * 4, "the oversized report and the rest of the flood were refused (%d)" % log.refused)
	var probes: int = 0
	for line: String in lines:
		var entry: Variant = JSON.parse_string(line)
		if not entry is Dictionary:
			check(false, "a line is JSON: " + line)
			continue
		var keys: Array = entry.keys()
		keys.sort()
		check(keys == ["count", "kind", "location", "message", "os", "scene", "stack", "time", "version"], "a line has only the known fields (%s)" % str(keys))
		# The caught error was raised online (the runtime's scene); the flood says the game's.
		check(entry.version == Connection.VERSION and not str(entry.os).is_empty() and entry.scene in ["res://features/network/dedicated_runtime.tscn", "res://features/game/game.tscn"], "version, OS and scene (%s, %s, %s)" % [entry.version, entry.os, entry.scene])
		check(not line.contains("Probe-client") and not line.contains("172.16") and not line.contains("example.org") and not line.contains("captain"), "nothing private: " + line)
		if str(entry.message).begins_with("Probe failure near <ip> for <email>"): probes += 1
	check(probes == 2, "each client's caught error arrived, scrubbed (%d)" % probes)
	finish()

func finish() -> void:
	print("DEDICATED_ERRORS_%s %s checks=%d" % ["PASS" if failures == 0 else "FAIL", "server" if runtime != null and runtime.hosting else "client", checks])
	quit(0 if failures == 0 else 1)
