class_name ErrorReports
extends Node
## Patch 4.0.5 item 2: automatic error and crash reports.
## A Logger catches every engine and script error this game raises (not
## warnings) with its GDScript backtrace. Each report carries only the game
## VERSION, the OS name and version, the scene file, the message and the
## stack. Before it is kept, `scrub` replaces user folders, the install
## folder, the captain name, IP addresses and e-mail addresses. Nothing else
## is collected: no account, captain, install key, save or address.
## Reports wait in user://crash_reports/outbox.json (capped) and the online
## client (dedicated_runtime.gd) hands them to the game server, which keeps
## them in its own rotating log (client_error_log.gd).
## A crash cannot run game code, so each run writes running.json and removes
## it on a clean exit. If the next run finds it, the previous run did not
## exit; when that run's Godot log holds a crash backtrace ("Program
## crashed"), that backtrace becomes a "crash" report.
const Connection = preload("res://features/network/play_connection.gd")
const NODE_NAME: String = "ErrorReports"
const MESSAGE_LIMIT: int = 500
const STACK_LIMIT: int = 3000
const LOCATION_LIMIT: int = 200
const SCENE_LIMIT: int = 160
## The outbox keeps at most this many reports (oldest dropped first)...
const OUTBOX_LIMIT: int = 20
## ...and this run adds at most this many (a looping error repeats as a count).
const SESSION_LIMIT: int = 40
## One report, as JSON, is never larger than this.
const REPORT_BYTES: int = 4096
const SAVE_EVERY_S: float = 2.0
const KEYS: Array[String] = ["kind", "version", "os", "scene", "message", "location", "stack", "count"]

var folder: String = "user://crash_reports"
var logs_folder: String = "user://logs"
var outbox: Array[Dictionary] = []
var dirty: bool = false
var save_wait: float = 0.0
var added: int = 0
var logger: ReportLogger
## Raw errors from the Logger (any thread), drained on the main thread.
static var lock: Mutex = Mutex.new()
static var raw: Array[Dictionary] = []
## The scene the game is in, for reports raised off the main thread.
static var scene_path: String = ""
## Words to scrub besides the patterns (user folders, the captain name).
static var private_words: PackedStringArray = PackedStringArray()

class ReportLogger extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING: return
		var stack: PackedStringArray = PackedStringArray()
		for trace: ScriptBacktrace in script_backtraces:
			if trace != null and not trace.is_empty(): stack.append(trace.format())
		var entry: Dictionary = {"message": rationale if not rationale.is_empty() else code,
			"location": "%s:%d %s" % [file, line, function], "stack": "\n".join(stack)}
		# Never block or recurse inside the logger: busy means drop this one.
		if not ErrorReports.lock.try_lock(): return
		if ErrorReports.raw.size() < 64: ErrorReports.raw.append(entry)
		ErrorReports.lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

## Adds the reporter once, under the root (it outlives scene changes).
static func install(tree: SceneTree) -> Node:
	var existing: Node = tree.root.get_node_or_null(NODE_NAME)
	if existing != null: return existing
	var node: Node = ErrorReports.new()
	node.name = NODE_NAME
	tree.root.add_child.call_deferred(node)
	return node

static func find(tree: SceneTree) -> Node:
	return tree.root.get_node_or_null(NODE_NAME) if tree != null else null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start()

## Separate from _ready so checks can point it at isolated folders first.
func start() -> void:
	if logger != null: return
	DirAccess.make_dir_recursive_absolute(folder)
	note_private_words()
	load_outbox()
	check_previous_run()
	write_marker()
	logger = ReportLogger.new()
	OS.add_logger(logger)

func _exit_tree() -> void:
	stop(true)

## A clean exit: the marker goes, the outbox is saved, the logger comes off.
func stop(clean: bool) -> void:
	if logger != null:
		OS.remove_logger(logger)
		logger = null
	drain()
	if dirty: save_outbox()
	if clean: DirAccess.remove_absolute(folder.path_join("running.json"))

func note_private_words() -> void:
	var words: PackedStringArray = PackedStringArray()
	for path: String in [OS.get_user_data_dir(), OS.get_executable_path().get_base_dir(), OS.get_environment("USERPROFILE"), OS.get_environment("HOME")]:
		if path.length() >= 4:
			words.append(path)
			words.append(path.replace("\\", "/"))
	for name: String in [OS.get_environment("USERNAME"), OS.get_environment("USER"), preload("res://features/network/captain_name.gd").load_saved()]:
		if name.length() >= 3: words.append(name)
	private_words = words

## A word (a captain's name) that reports must never carry.
static func keep_private(word: String) -> void:
	if word.length() >= 3 and not private_words.has(word): private_words.append(word)

## Replaces what could identify a player: their folders and names, IP
## addresses (v4 and v6) and e-mail addresses. Then cuts to `limit`.
static func scrub(text: String, limit: int) -> String:
	var out: String = text
	for word: String in private_words:
		if not word.is_empty(): out = out.replace(word, "<private>")
	for rule: Array in RULES:
		out = (rule[0] as RegEx).sub(out, rule[1], true)
	# Control characters (but not new lines or tabs) are dropped.
	var clean: PackedStringArray = PackedStringArray()
	for index: int in out.length():
		var code: int = out.unicode_at(index)
		if code >= 32 or code == 10 or code == 9: clean.append(out[index])
	out = "".join(clean)
	return out.substr(0, limit) if out.length() > limit else out

static var RULES: Array = make_rules()

static func make_rules() -> Array:
	var rules: Array = []
	for pair: Array in [
			# Home folders on Windows, macOS and Linux (the user's name is in them).
			["(?i)[a-z]:[\\\\/]+(users|documents and settings)[\\\\/]+[^\\\\/\\s\"':]+", "<home>"],
			["/(Users|home)/[^/\\s\"':]+", "<home>"],
			["[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "<email>"],
			["\\b(?:\\d{1,3}\\.){3}\\d{1,3}(?::\\d{1,5})?\\b", "<ip>"],
			["\\b(?:[0-9A-Fa-f]{1,4}:){4,7}[0-9A-Fa-f]{1,4}\\b", "<ip>"],
			["(?i)\\b(?:[0-9a-f]{1,4}:){1,6}:[0-9a-f]{1,4}\\b|::ffff:[0-9a-f.:]+", "<ip>"]]:
		var regex: RegEx = RegEx.new()
		regex.compile(pair[0])
		rules.append([regex, pair[1]])
	return rules

func _process(delta: float) -> void:
	var tree: SceneTree = get_tree()
	var scene: String = tree.current_scene.scene_file_path if tree.current_scene != null else ""
	if scene != scene_path:
		scene_path = scene
		write_marker()
	drain()
	save_wait -= delta
	if dirty and save_wait <= 0.0:
		save_outbox()

## Moves the Logger's raw errors into the outbox, as reports.
func drain() -> void:
	lock.lock()
	var taken: Array[Dictionary] = raw.duplicate()
	raw.clear()
	lock.unlock()
	for entry: Dictionary in taken:
		add_report("error", str(entry.message), str(entry.location), str(entry.stack), scene_path, Connection.VERSION)

## One report: the fixed fields, scrubbed and capped. A repeat of one still in
## the outbox raises its count instead.
func add_report(kind: String, message: String, location: String, stack: String, scene: String, version: String) -> Dictionary:
	var report: Dictionary = make_report(kind, message, location, stack, scene, version)
	for existing: Dictionary in outbox:
		if existing.kind == report.kind and existing.message == report.message and existing.location == report.location:
			existing.count = mini(int(existing.count) + 1, 1000000)
			dirty = true
			return existing
	if added >= SESSION_LIMIT: return {}
	added += 1
	outbox.append(report)
	while outbox.size() > OUTBOX_LIMIT: outbox.pop_front()
	dirty = true
	return report

static func make_report(kind: String, message: String, location: String, stack: String, scene: String, version: String) -> Dictionary:
	var report: Dictionary = {"kind": "crash" if kind == "crash" else "error",
		"version": scrub(version, 32), "os": scrub("%s %s" % [OS.get_name(), OS.get_version()], 40),
		"scene": scene if scene.begins_with("res://") and scene.length() <= SCENE_LIMIT else "",
		"message": scrub(message, MESSAGE_LIMIT), "location": scrub(location, LOCATION_LIMIT),
		"stack": scrub(stack, STACK_LIMIT), "count": 1}
	# The whole report fits REPORT_BYTES: the stack gives way first.
	while JSON.stringify(report).to_utf8_buffer().size() > REPORT_BYTES and not str(report.stack).is_empty():
		report.stack = str(report.stack).substr(0, maxi(0, str(report.stack).length() - 400))
	return report

## Up to `count` reports, oldest first, taken out of the outbox.
func take(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	while not outbox.is_empty() and out.size() < count:
		out.append(outbox.pop_front())
	if not out.is_empty(): dirty = true
	return out

func load_outbox() -> void:
	outbox.clear()
	var path: String = folder.path_join("outbox.json")
	if not FileAccess.file_exists(path): return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > OUTBOX_LIMIT * REPORT_BYTES * 2: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array: return
	for item: Variant in parsed:
		if not item is Dictionary: continue
		var report: Dictionary = make_report(str(item.get("kind", "error")), str(item.get("message", "")), str(item.get("location", "")),
			str(item.get("stack", "")), str(item.get("scene", "")), str(item.get("version", "")))
		report.count = clampi(int(item.get("count", 1)), 1, 1000000)
		outbox.append(report)
		if outbox.size() >= OUTBOX_LIMIT: break

func save_outbox() -> void:
	dirty = false
	save_wait = SAVE_EVERY_S
	var path: String = folder.path_join("outbox.json")
	if outbox.is_empty():
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		return
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(outbox))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)

func write_marker() -> void:
	var file: FileAccess = FileAccess.open(folder.path_join("running.json"), FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"version": Connection.VERSION, "scene": scene_path}))
	file.close()

## The last run did not exit cleanly: look for its crash backtrace.
func check_previous_run() -> void:
	var marker: String = folder.path_join("running.json")
	if not FileAccess.file_exists(marker): return
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(marker))
	if not previous is Dictionary: previous = {}
	var crash: String = crash_backtrace(previous_log())
	if crash.is_empty(): return
	var first: String = crash.get_slice("\n", 0).strip_edges()
	add_report("crash", first, "", crash, str(previous.get("scene", "")), str(previous.get("version", "")))

## Godot renames last run's godot.log to godot<date>.log when this run
## starts: the newest of those is the previous run's log.
func previous_log() -> String:
	var dir: DirAccess = DirAccess.open(logs_folder)
	if dir == null: return ""
	var newest: String = ""
	var newest_time: int = -1
	for name: String in dir.get_files():
		if not name.begins_with("godot") or not name.ends_with(".log") or name == "godot.log": continue
		var path: String = logs_folder.path_join(name)
		var stamp: int = FileAccess.get_modified_time(path)
		if stamp > newest_time or (stamp == newest_time and name > newest.get_file()):
			newest_time = stamp
			newest = path
	return newest

## The crash part of a Godot log: from "Program crashed" to the end of the
## backtraces (at most 80 lines). Empty when the log has no crash.
static func crash_backtrace(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path): return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	# Only the end of a long log matters.
	var length: int = file.get_length()
	if length > 262144: file.seek(length - 262144)
	var lines: PackedStringArray = file.get_buffer(mini(length, 262144)).get_string_from_utf8().split("\n")
	var start: int = -1
	for index: int in lines.size():
		if "Program crashed" in lines[index]: start = index
	if start < 0: return ""
	var kept: PackedStringArray = PackedStringArray()
	for index: int in range(start, mini(lines.size(), start + 80)):
		var line: String = lines[index].strip_edges(false, true)
		kept.append(line)
		if "END OF GDSCRIPT BACKTRACE" in line: break
	return "\n".join(kept)
