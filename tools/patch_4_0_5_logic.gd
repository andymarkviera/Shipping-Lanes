extends RefCounted
## Patch 4.0.5 scene-free checks (issue #230). check_catalog.gd runs them in
## the Checks job; tools/patch_4_0_5_check.gd runs them too, plus the game
## scene (a controller sailing, flying and working the menus), and
## `check_dedicated_split.py --errors` sends reports to a real server.
## - pad_map / glyphs: item 1, the controller layout and the button names;
## - scrub / reports / crash / server_log: item 2, the reports;
## - engine_sound: item 3, the plane engine sounds.
const Prefs = preload("res://features/settings/input_preferences.gd")
const GameMenu = preload("res://features/game/game_menu.gd")
const Reports = preload("res://features/network/error_reports.gd")
const ServerLog = preload("res://features/network/client_error_log.gd")
const Sound = preload("res://features/planes/plane_engine_sound.gd")
const FOLDER: String = "user://patch_4_0_5_logic"
const PARTS: Array[String] = ["version", "pad_map", "glyphs", "scrub", "reports", "crash", "server_log", "engine_sound"]
var failures: Array[String] = []
var checks: int = 0

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

## Runs every check; returns the failed labels (empty when all pass).
static func run_all() -> PackedStringArray:
	var suite: RefCounted = new()
	for part: String in PARTS: suite.call(part)
	return suite.failures

static func clear(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null: return
	for name: String in dir.get_files(): dir.remove(name)

func version() -> void:
	var connection: GDScript = load("res://features/network/play_connection.gd")
	expect(connection.VERSION.naturalnocasecmp_to("4.0.5") >= 0, "VERSION is 4.0.5 or later (%s)" % connection.VERSION)

## Item 1: every boat and plane action has a pad event, added after the key
## (the key is kept); the keyboard bindings and their rules are unchanged.
func pad_map() -> void:
	var defaults: Dictionary = Prefs.DEFAULT_BINDINGS
	expect(defaults.size() == 14 and defaults.ship_throttle_up == KEY_W and defaults.cannon_salute == KEY_G and defaults.pause == KEY_ESCAPE,
		"the default keys are unchanged")
	var prefs: InputPreferences = Prefs.new()
	expect(prefs.validation_error().is_empty(), "the default keys still validate")
	for action: String in defaults:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = defaults[action]
		InputMap.action_add_event(action, key)
	Gamepad.apply_events()
	for action: String in defaults:
		if action == "pause": continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var has_key: bool = false
		var has_pad: bool = false
		for event: InputEvent in events:
			if event is InputEventKey and event.physical_keycode == defaults[action]: has_key = true
			if event is InputEventJoypadButton or event is InputEventJoypadMotion: has_pad = true
		expect(has_key and has_pad, "%s keeps its key and has a pad event" % action)
	for action: String in Gamepad.PAD_ONLY:
		expect(InputMap.has_action(action) and InputMap.action_get_events(action).size() == 1, "%s exists with one pad event" % action)
	# Applying twice adds nothing twice (pad-only actions are rebuilt).
	Gamepad.apply_events()
	expect(InputMap.action_get_events(Gamepad.LEVER_UP).size() == 1, "applying twice keeps one trigger event")
	var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	expect(stick.is_action_pressed("ship_throttle_up") and not stick.is_action_pressed("ship_throttle_down"), "left stick up is the throttle up (a plane's climb)")
	stick.axis_value = 0.1
	expect(not stick.is_action_pressed("ship_throttle_up"), "a resting stick (0.1) is inside the dead zone")
	var steer: InputEventJoypadMotion = InputEventJoypadMotion.new()
	steer.axis = JOY_AXIS_LEFT_X
	steer.axis_value = 0.75
	expect(steer.is_action_pressed("ship_steer_right") and not steer.is_action_pressed("ship_steer_left") and steer.get_action_strength("ship_steer_right") > 0.5, "left stick right steers right, in proportion")
	var trigger: InputEventJoypadMotion = InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	expect(trigger.is_action_pressed(Gamepad.LEVER_UP), "RT is the lever up")
	for pair: Array in [[JOY_BUTTON_A, "interact"], [JOY_BUTTON_B, "ship_throttle_zero"], [JOY_BUTTON_X, "ship_brake"],
			[JOY_BUTTON_Y, "cannon_salute"], [JOY_BUTTON_LEFT_SHOULDER, "ship_thruster_left"], [JOY_BUTTON_RIGHT_SHOULDER, "ship_thruster_right"],
			[JOY_BUTTON_BACK, "map_toggle"], [JOY_BUTTON_LEFT_STICK, "horn"], [JOY_BUTTON_RIGHT_STICK, "camera_recenter"]]:
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = pair[0]
		button.pressed = true
		expect(InputMap.event_is_action(button, pair[1]), "pad button %d is %s" % [pair[0], pair[1]])
	var accept: InputEventJoypadButton = InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	expect(InputMap.event_is_action(accept, "ui_accept"), "A is ui_accept (focused buttons, popups, the hangars)")
	# Start is not bound to an action: PlayerControls turns it into Esc.
	var start: InputEventJoypadButton = InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	var bound: bool = false
	for action: String in defaults: if InputMap.event_is_action(start, action): bound = true
	expect(not bound, "Start sends Esc instead of being an action")

## Item 1: glyphs follow the last device and the pad's family.
func glyphs() -> void:
	var was: bool = Gamepad.pad_last
	var kind: String = Gamepad.family
	expect(Gamepad.family_of("PS5 Controller") == "playstation" and Gamepad.family_of("Sony DualSense Wireless Controller") == "playstation"
		and Gamepad.family_of("Xbox Series Controller") == "xbox" and Gamepad.family_of("") == "xbox", "pad families from their names")
	Gamepad.set_last(false)
	expect(Gamepad.label("cannon_salute", "G") == "G" and Gamepad.swap("Press Esc for the main menu") == "Press Esc for the main menu", "keyboard last: key text")
	var rows: Array = GameMenu.rows_for(Prefs.new())
	expect(rows.size() > 3 and rows[0][1] == "W / S", "keyboard last: the Controls list shows keys (%s)" % str(rows[0]))
	var before: int = Gamepad.revision
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	expect(Gamepad.note(button) and Gamepad.pad_last and Gamepad.revision > before, "a pad press makes the pad the last device")
	expect(Gamepad.label("cannon_salute", "G") == "[Y]" and Gamepad.action_glyph("ship_steer_left") == "[L-stick]" and Gamepad.action_glyph(Gamepad.LEVER_UP) == "[RT]",
		"Xbox glyphs: Y, L-stick, RT")
	expect(Gamepad.swap("Press Esc for the main menu") == "Press [Menu] for the main menu", "Esc reads as the Menu button (%s)" % Gamepad.swap("Press Esc for the main menu"))
	expect("[B]" in Gamepad.swap("HELM OFF — a button, list or text box has the keyboard.\nPress Esc to give the keyboard back to the helm."), "a focused button: B gives the controls back")
	rows = GameMenu.rows_for(Prefs.new())
	expect(rows[0][1].begins_with("[L-stick]") and str(rows).contains("[Menu]"), "pad last: the Controls list shows pad buttons")
	Gamepad.set_last(true, "playstation")
	expect(Gamepad.label("cannon_salute", "G") == "[Triangle]" and Gamepad.glyph("RT") == "[R2]" and Gamepad.glyph(JOY_BUTTON_START) == "[Options]", "PlayStation glyphs")
	var synthetic: InputEventKey = InputEventKey.new()
	synthetic.keycode = KEY_ESCAPE
	synthetic.pressed = true
	synthetic.set_meta(Gamepad.SYNTHETIC, true)
	expect(not Gamepad.note(synthetic) and Gamepad.pad_last, "the Esc the pad sends does not count as the keyboard")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	expect(Gamepad.note(key) and not Gamepad.pad_last, "a key press makes the keyboard the last device")
	Gamepad.set_last(was, kind)

## Item 2: what could identify a player is taken out of reports.
func scrub() -> void:
	var words: PackedStringArray = Reports.private_words
	Reports.private_words = PackedStringArray(["Skipper Andy"])
	var text: String = "Load failed C:\\Users\\andy\\AppData\\Roaming\\Godot\\x.db from 192.168.1.20:24565 and 2001:0db8:85a3:0000:0000:8a2e:0370:7334 for skipper@example.com /home/andy/game /Users/andy/Library by Skipper Andy at res://features/game/game.gd:12"
	var clean: String = Reports.scrub(text, 2000)
	expect(not clean.contains("andy") and not clean.contains("192.168") and not clean.contains("0db8") and not clean.contains("example.com") and not clean.contains("Skipper Andy"),
		"names, folders, addresses and e-mail are scrubbed (%s)" % clean)
	expect(clean.contains("<home>") and clean.contains("<ip>") and clean.contains("<email>") and clean.contains("res://features/game/game.gd:12"), "markers replace them; game paths stay")
	expect(Reports.scrub("time 12:34:56 in Node::add_child", 100) == "time 12:34:56 in Node::add_child", "clock times and C++ names are left alone")
	expect(Reports.scrub("x".repeat(900), 500).length() == 500 and Reports.scrub("a\u0007b\nc", 10) == "ab\nc", "cut to size; control characters dropped")
	Reports.private_words = words

## Item 2: the client's reports: fixed fields only, capped, repeats counted,
## the outbox kept to size and saved; the Logger feeds it.
func reports() -> void:
	var folder: String = FOLDER + "/client"
	clear(folder)
	var node: Node = Reports.new()
	node.folder = folder
	node.logs_folder = FOLDER + "/no_logs"
	var report: Dictionary = node.add_report("error", "boom " + "m".repeat(800), "res://a.gd:3 f", "s".repeat(9000), "res://features/game/game.tscn", "4.0.5")
	expect(report.keys() == Reports.KEYS, "a report has exactly the fixed fields (%s)" % str(report.keys()))
	expect(str(report.message).length() == Reports.MESSAGE_LIMIT and str(report.stack).length() <= Reports.STACK_LIMIT, "message and stack are capped")
	expect(JSON.stringify(report).to_utf8_buffer().size() <= Reports.REPORT_BYTES, "a report fits REPORT_BYTES")
	expect(report.version == "4.0.5" and str(report.os).begins_with(OS.get_name()) and report.scene == "res://features/game/game.tscn", "version, OS and scene are kept")
	expect(Reports.make_report("error", "x", "", "", "C:/Users/me/save.tscn", "4.0.5").scene == "", "a scene outside res:// is dropped")
	node.add_report("error", "boom " + "m".repeat(800), "res://a.gd:3 f", "", "", "4.0.5")
	expect(node.outbox.size() == 1 and int(node.outbox[0].count) == 2, "a repeat raises the count")
	for index: int in 60: node.add_report("error", "different %d" % index, "", "", "", "4.0.5")
	expect(node.outbox.size() == Reports.OUTBOX_LIMIT and node.added == Reports.SESSION_LIMIT, "the outbox keeps %d; a run adds at most %d" % [Reports.OUTBOX_LIMIT, Reports.SESSION_LIMIT])
	node.save_outbox()
	var again: Node = Reports.new()
	again.folder = folder
	again.load_outbox()
	expect(again.outbox.size() == Reports.OUTBOX_LIMIT and again.outbox[-1].message == node.outbox[-1].message, "the outbox is saved and loads back")
	var taken: Array[Dictionary] = again.take(3)
	expect(taken.size() == 3 and again.outbox.size() == Reports.OUTBOX_LIMIT - 3, "take() hands reports out of the outbox")
	again.free()
	node.free()
	# The Logger: an error with its GDScript backtrace becomes a report; a warning does not.
	var logger: Logger = Reports.ReportLogger.new()
	Reports.lock.lock()
	Reports.raw.clear()
	Reports.lock.unlock()
	var traces: Array[ScriptBacktrace] = []
	logger._log_error("push_error", "core/variant/variant_utility.cpp", 10, "", "Probe error from 10.0.0.7", false, Logger.ERROR_TYPE_ERROR, traces)
	logger._log_error("push_warning", "core/variant/variant_utility.cpp", 11, "", "only a warning", false, Logger.ERROR_TYPE_WARNING, traces)
	var sink: Node = Reports.new()
	sink.folder = folder
	sink.drain()
	expect(sink.outbox.size() == 1 and sink.outbox[0].message == "Probe error from <ip>" and sink.outbox[0].kind == "error", "the Logger's error is a scrubbed report; warnings are not")
	sink.free()
	clear(folder)

## Item 2: a run that did not exit leaves running.json; when its Godot log
## has a crash backtrace, the next run reports it (once).
func crash() -> void:
	var folder: String = FOLDER + "/crash"
	var logs: String = FOLDER + "/crash_logs"
	clear(folder)
	clear(logs)
	var log: FileAccess = FileAccess.open(logs + "/godot2026-11-21T10.00.00.log", FileAccess.WRITE)
	log.store_string("Godot Engine v4.7.2\nloading\n================================================================\nCrashHandlerException: Program crashed\nEngine version: Godot Engine v4.7.2.stable.official\nDumping the backtrace.\n[0] Node::propagate C:\\Users\\andy\\game.exe\n-- END OF C++ BACKTRACE --\nGDScript backtrace (most recent call first):\n    [0] _process (res://features/game/game.gd:40)\n-- END OF GDSCRIPT BACKTRACE --\n================================================================\nafter\n")
	log.close()
	var current: FileAccess = FileAccess.open(logs + "/godot.log", FileAccess.WRITE)
	current.store_string("this run\n")
	current.close()
	var trace: String = Reports.crash_backtrace(logs + "/godot2026-11-21T10.00.00.log")
	expect(trace.begins_with("CrashHandlerException: Program crashed") and trace.ends_with("-- END OF GDSCRIPT BACKTRACE --"), "the crash part of the log is found")
	expect(Reports.crash_backtrace(logs + "/godot.log").is_empty(), "a log with no crash gives nothing")
	var marker: FileAccess = FileAccess.open(folder + "/running.json", FileAccess.WRITE)
	marker.store_string(JSON.stringify({"version": "4.0.4", "scene": "res://features/game/game.tscn"}))
	marker.close()
	var node: Node = Reports.new()
	node.folder = folder
	node.logs_folder = logs
	node.check_previous_run()
	expect(node.outbox.size() == 1 and node.outbox[0].kind == "crash" and node.outbox[0].version == "4.0.4" and node.outbox[0].scene == "res://features/game/game.tscn",
		"the crash is reported with the crashed run's version and scene")
	expect(node.outbox.size() == 1 and str(node.outbox[0].stack).contains("game.gd:40") and not str(node.outbox[0].stack).contains("andy"), "with its backtrace, scrubbed")
	node.write_marker()
	node.stop(true)
	expect(not FileAccess.file_exists(folder + "/running.json"), "a clean exit removes the marker")
	node.free()
	var clean_run: Node = Reports.new()
	clean_run.folder = folder
	clean_run.logs_folder = logs
	clean_run.load_outbox()
	var saved: int = clean_run.outbox.size()
	clean_run.check_previous_run()
	expect(clean_run.outbox.size() == saved, "after a clean exit nothing new is reported")
	clean_run.free()
	clear(folder)
	clear(logs)

## Item 2: the server's log: only known fields, scrubbed; rate and size
## limits; one JSON line each; rotation.
func server_log() -> void:
	var folder: String = FOLDER + "/server"
	clear(folder)
	expect(ServerLog.folder_for("C:/ShippingLanesServer/saves") == "C:/ShippingLanesServer/logs/client_errors", "the packaged server logs to C:\\ShippingLanesServer\\logs\\client_errors")
	expect(ServerLog.folder_for("C:\\ShippingLanesServer\\saves").replace("\\", "/") == "C:/ShippingLanesServer/logs/client_errors", "backslashes too (%s)" % ServerLog.folder_for("C:\\ShippingLanesServer\\saves"))
	var log: RefCounted = ServerLog.new()
	log.folder = folder
	log.now_ms = 100000
	var report: Dictionary = {"kind": "error", "version": "4.0.5", "os": "Windows 10.0", "scene": "res://features/game/game.tscn",
		"message": "failed at 10.1.2.3", "location": "res://x.gd:1", "stack": "", "count": 3, "captain": "Skipper", "ip": "10.1.2.3", "key": "abc"}
	var results: Array[String] = []
	for index: int in 7: results.append(log.accept(7, report))
	expect(results.slice(0, 5) == ["", "", "", "", ""] and results[5] == "rate limit" and results[6] == "rate limit", "a burst of 5, then rate limited (%s)" % str(results))
	log.now_ms += int(ServerLog.REFILL_S * 1000.0) + 1
	expect(log.accept(7, report) == "" and log.accept(7, report) == "rate limit", "one more after REFILL_S")
	expect(log.accept(8, report) == "", "each captain has their own limit")
	expect(log.accept(9, {"message": "x".repeat(ServerLog.MAX_REPORT_BYTES)}) == "too large" and log.accept(9, "text") == "not a report", "oversized or malformed reports are refused")
	for index: int in 40:
		log.now_ms += 10000
		log.accept(10, report)
	expect(int(log.buckets[10].total) == ServerLog.PER_PEER, "at most %d per connection" % ServerLog.PER_PEER)
	log.forget(10)
	expect(not log.buckets.has(10), "a departed captain's limit is dropped")
	var lines: PackedStringArray = FileAccess.get_file_as_string(folder + "/client_errors.log").strip_edges().split("\n")
	var entry: Variant = JSON.parse_string(lines[0])
	expect(lines.size() == 7 + ServerLog.PER_PEER, "one line per accepted report (%d)" % lines.size())
	expect(entry is Dictionary and sorted((entry as Dictionary).keys()) == sorted(["time", "kind", "version", "os", "scene", "message", "location", "stack", "count"]), "a line has only the known fields")
	expect(entry is Dictionary and entry.message == "failed at <ip>" and int(entry.count) == 3 and not lines[0].contains("Skipper") and not lines[0].contains("abc"), "scrubbed again; no captain, address or key")
	# Rotation: a full log moves to .1 and a new one starts.
	var big: FileAccess = FileAccess.open(folder + "/client_errors.log", FileAccess.WRITE)
	big.store_buffer(zeros(ServerLog.MAX_FILE_BYTES - 10))
	big.close()
	log.now_ms += 100000
	expect(log.accept(11, report) == "", "a report past the size limit is still written")
	expect(FileAccess.file_exists(folder + "/client_errors.1.log") and FileAccess.get_file_as_string(folder + "/client_errors.log").split("\n", false).size() == 1, "the full log rotated to client_errors.1.log")
	for index: int in ServerLog.KEEP + 2: log.rotate()
	var dir: DirAccess = DirAccess.open(folder)
	expect(dir != null and dir.get_files().size() <= ServerLog.KEEP, "at most %d files are kept" % ServerLog.KEEP)
	clear(folder)

static func sorted(items: Array) -> Array:
	var out: Array = items.duplicate()
	out.sort()
	return out

static func zeros(count: int) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count)
	bytes.fill(32)
	return bytes

## Item 3: one sound per engine family, seamless loops, pitched by RPM, the
## afterburner only on the fighter's high throttle, and the doppler shift.
func engine_sound() -> void:
	var seen: Dictionary = {}
	for kind: String in ["plane_prop", "plane_turboprop", "plane_jet", "plane_fighter"]:
		var family: String = Sound.family_of(kind)
		seen[family] = kind
		var node: Node3D = Sound.make(kind, false)
		for layer: String in node.layers():
			var stream: AudioStreamWAV = Sound.loop(family, layer)
			var wave: PackedFloat32Array = Sound.samples(family, layer)
			expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == Sound.LOOP_SAMPLES and stream.data.size() == Sound.LOOP_SAMPLES * 2, "%s %s is a one-second loop" % [family, layer])
			var energy: float = 0.0
			var step: float = 0.0
			for index: int in wave.size():
				energy += wave[index] * wave[index]
				if index > 0: step = maxf(step, absf(wave[index] - wave[index - 1]))
			var rms: float = sqrt(energy / wave.size())
			expect(rms > 0.08, "%s %s is audible (rms %.3f)" % [family, layer, rms])
			expect(absf(wave[0] - wave[-1]) <= step * 1.5 + 0.02, "%s %s joins without a click (%.3f vs step %.3f)" % [family, layer, absf(wave[0] - wave[-1]), step])
		node.free()
	expect(seen.keys().size() == 4 and seen.has("prop1") and seen.has("prop2") and seen.has("fan2") and seen.has("afterburner"), "prop, turboprop, turbofan and afterburner each have a sound")
	expect(crossings(Sound.samples("prop1", "core")) < crossings(Sound.samples("fan2", "core")), "the turbofan's core is higher than the piston's")
	for family: String in Sound.FAMILIES:
		var idle: Dictionary = Sound.mix(family, 0.0, 0.0)
		var full: Dictionary = Sound.mix(family, 1.0, 1.0)
		expect(full.core_pitch > idle.core_pitch + 0.4 and full.core_db > idle.core_db and full.air_db > idle.air_db, "%s: pitch and roar rise with RPM" % family)
	expect(Sound.mix("afterburner", 1.0, 1.0).burner > 0.9 and Sound.mix("afterburner", 1.0, 0.8).burner == 0.0 and Sound.mix("fan2", 1.0, 1.0).burner == 0.0,
		"the afterburner lights only on the fighter, over %.0f%% lever" % (Sound.AFTERBURNER_LEVER * 100.0))
	expect(Sound.mix("afterburner", 0.5, 1.0).burner == 0.0, "no afterburner before the engine spools up")
	var closing: float = Sound.doppler(Vector3.ZERO, Vector3(0, 0, 100), Vector3(0, 0, 1000), Vector3.ZERO)
	var parting: float = Sound.doppler(Vector3.ZERO, Vector3(0, 0, -100), Vector3(0, 0, 1000), Vector3.ZERO)
	expect(is_equal_approx(closing, 343.0 / 243.0) and is_equal_approx(parting, 343.0 / 443.0), "doppler: %.3f closing, %.3f parting at 100 m/s" % [closing, parting])
	expect(is_equal_approx(Sound.doppler(Vector3.ZERO, Vector3(50, 0, 0), Vector3(0, 0, 1000), Vector3.ZERO), 1.0), "no shift flying across the line of sight")
	expect(is_equal_approx(Sound.doppler(Vector3.ZERO, Vector3(0, 0, 100), Vector3(0, 0, 1000), Vector3(0, 0, -100)), 443.0 / 243.0), "the listener's motion counts too")
	expect(Sound.doppler(Vector3.ZERO, Vector3(0, 0, 600), Vector3(0, 0, 1000), Vector3.ZERO) == 2.0, "a supersonic pass is clamped")
	var remote: Node3D = Sound.make("plane_fighter", true)
	remote._ready()
	remote.update(1.0, 1.0, 1.4)
	var core: Node = remote.players.core
	expect(core is AudioStreamPlayer3D and is_equal_approx(core.pitch_scale, Sound.mix("afterburner", 1.0, 1.0).core_pitch * 1.4), "another captain's plane plays from its position, doppler-shifted")
	remote.free()

static func crossings(wave: PackedFloat32Array) -> int:
	var count: int = 0
	for index: int in range(1, wave.size()):
		if (wave[index - 1] < 0.0) != (wave[index] < 0.0): count += 1
	return count
