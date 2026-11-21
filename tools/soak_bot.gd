extends SceneTree
## Patch 4.0.6 item 3: the headless soak bot. One script, three roles:
## - the launcher (no role given): starts a real dedicated server and N bot
##   clients as separate headless Godot processes on UDP loopback, each with
##   its own isolated user data (XDG_* / APPDATA under user://soak/<stamp>),
##   waits for their reports and prints SOAK_PASS or SOAK_FAIL;
## - the server (--soak-role=server): the real DedicatedRuntime (boot.tscn
##   --server). It keeps the stats (players, slowest frame, memory, errors)
##   and, to fit a whole day's work into minutes, stages the long legs only:
##   a ship that has sailed a while is brought to a berth (its job's
##   destination, else its own port) and a plane that has flown a while is
##   put on a sloppy final approach (tools/flight_autopilot.gd). It unlocks
##   the planes for its bot captains. Storms are on, as on any server;
## - a bot (--soak-role=bot): a real client (boot.tscn --connect) whose
##   captain plays through the real RPCs only: dock, take a container job,
##   wait for the cranes, undock, sail (throttle and steering held as keys
##   are), dock again, deliver, switch to a plane, take off, fly, land with
##   the sloppy pilot's keys, back to the boat, and again.
## Every process counts its own error lines (a Logger); the launcher fails on
## any, on a bot that never joined or dropped out, on storms that did not
## reach a bot (server-authoritative seed), and unless the bots between them
## docked, took a job, sailed, delivered, flew and landed.
## Run: godot --headless --path . --script res://tools/soak_bot.gd -- --bots=3 --seconds=300
## (--port=P picks the UDP port; default a free one.)
const Storms = preload("res://features/sky/storms.gd")
const Airports = preload("res://features/planes/airports.gd")
const Autopilot = preload("res://tools/flight_autopilot.gd")
const BOOT: String = "res://features/main/boot.tscn"
## The server stages a ship that sailed this long, and a plane that flew this long.
const SAIL_MS: int = 9000
const FLY_MS: int = 15000
## Bots act (RPC) at most this often; the server rate limit is 100 ms.
const ACT_MS: int = 600
const GRACE_S: float = 60.0

class ErrorCounter extends Logger:
	var lock: Mutex = Mutex.new()
	var count: int = 0
	var first: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING: return
		lock.lock()
		count += 1
		if first.size() < 5: first.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		lock.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass

var role: String = "launcher"
var bots: int = 3
var seconds: float = 300.0
var port: int = 0
var folder: String = ""
var index: int = 0
var started_ms: int = 0
var runtime: Node3D
var errors: ErrorCounter = ErrorCounter.new()
var done: bool = false

# Launcher.
var pids: Array[int] = []
var launched_bots: bool = false
var ready_wait_ms: int = 0

# Server.
var server: Dictionary = {"players_max": 0, "joins": 0, "leaves": 0, "deliveries": 0, "landings": 0, "staged_ships": 0, "staged_planes": 0,
	"slowest_frame_ms": 0.0, "slowest_physics_ms": 0.0, "memory_peak_mb": 0.0, "storm_seed": 0, "storms_on": false}
var seen: Dictionary = {}
var last_print_ms: int = 0

# Bot.
var stage: String = "start"
var stage_ms: int = 0
var last_act_ms: int = 0
var report: Dictionary = {"joined": false, "docks": 0, "jobs": 0, "deliveries": 0, "flights": 0, "landings": 0, "sailed_m": 0.0,
	"actions": 0, "codes": {}, "storm_seed": -1, "storms_on": false, "dropped": false, "storm_felt": 0.0}
var was_docked: bool = false
var last_at: Vector3 = Vector3.INF
var credits_before: int = 0
var pilot: RefCounted
var last_plane_at: Vector3 = Vector3.INF
var held: Dictionary = {}
## This flight's landing is counted.
var landed: bool = false

func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--soak-role="): role = arg.trim_prefix("--soak-role=")
		elif arg.begins_with("--bots="): bots = clampi(int(arg.trim_prefix("--bots=")), 1, 32)
		elif arg.begins_with("--seconds="): seconds = clampf(float(arg.trim_prefix("--seconds=")), 20.0, 86400.0)
		elif arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--soak-dir="): folder = arg.trim_prefix("--soak-dir=")
		elif arg.begins_with("--index="): index = int(arg.trim_prefix("--index="))
	if role == "launcher":
		launch_server()
		return
	OS.add_logger(errors)
	change_scene_to_file.call_deferred(BOOT)

func now_ms() -> int:
	return Time.get_ticks_msec() - started_ms

# --- Launcher -------------------------------------------------------------------

func free_port() -> int:
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	for attempt: int in 50:
		var candidate: int = randi_range(20000, 60000)
		if udp.bind(candidate, "127.0.0.1") == OK:
			udp.close()
			return candidate
	return 47006

## A child Godot, headless, with its own user data folders.
func spawn(name: String, args: PackedStringArray) -> int:
	var data: String = folder.path_join(name)
	var keep: Dictionary = {}
	var env: Dictionary = {"XDG_DATA_HOME": data.path_join("data"), "XDG_CONFIG_HOME": data.path_join("config"), "XDG_CACHE_HOME": data.path_join("cache"),
		"APPDATA": data.path_join("data"), "LOCALAPPDATA": data.path_join("local")}
	for key: String in env:
		DirAccess.make_dir_recursive_absolute(env[key])
		keep[key] = OS.get_environment(key)
		OS.set_environment(key, env[key])
	var command: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/soak_bot.gd", "--"]
	command.append_array(args)
	command.append_array(["--soak-dir=" + folder, "--seconds=%d" % roundi(seconds), "--bots=%d" % bots, "--port=%d" % port])
	var pid: int = OS.create_process(OS.get_executable_path(), command)
	for key: String in keep:
		if str(keep[key]).is_empty(): OS.unset_environment(key)
		else: OS.set_environment(key, keep[key])
	return pid

func launch_server() -> void:
	folder = ProjectSettings.globalize_path("user://soak").path_join(str(int(Time.get_unix_time_from_system() * 1000.0)))
	DirAccess.make_dir_recursive_absolute(folder)
	if port == 0: port = free_port()
	print("SOAK launching a server and %d bots for %d s on UDP %d (%s)" % [bots, roundi(seconds), port, folder])
	pids.append(spawn("server", ["--server", "--soak-role=server", "--saves-dir=" + folder.path_join("saves")]))

func launcher_step() -> void:
	if not launched_bots:
		if FileAccess.file_exists(folder.path_join("server.ready")):
			launched_bots = true
			for bot: int in bots:
				pids.append(spawn("bot_%d" % bot, ["--connect", "--soak-role=bot", "--index=%d" % bot, "--captain=Soak Bot %d" % bot]))
		elif now_ms() > 60000:
			conclude(["the server never became ready"])
		return
	var finished: bool = FileAccess.file_exists(folder.path_join("server.json"))
	for bot: int in bots:
		if not FileAccess.file_exists(folder.path_join("bot_%d.json" % bot)): finished = false
	if finished:
		conclude([])
	elif now_ms() > int((seconds + GRACE_S * 2.0) * 1000.0):
		conclude(["timed out waiting for the reports"])

static func read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return value if value is Dictionary else {}

func conclude(problems: Array[String]) -> void:
	if done: return
	done = true
	var host: Dictionary = read_json(folder.path_join("server.json"))
	if host.is_empty(): problems.append("no server report")
	else:
		print("SOAK server: %s" % JSON.stringify(host))
		if int(host.errors) > 0: problems.append("the server logged %d errors: %s" % [host.errors, host.first_errors])
		if int(host.players_max) < bots: problems.append("the server saw %d of %d bots" % [host.players_max, bots])
	var total: Dictionary = {"docks": 0, "jobs": 0, "deliveries": 0, "flights": 0, "landings": 0}
	for bot: int in bots:
		var row: Dictionary = read_json(folder.path_join("bot_%d.json" % bot))
		if row.is_empty():
			problems.append("bot %d sent no report" % bot)
			continue
		print("SOAK bot %d: %s" % [bot, JSON.stringify(row)])
		if not row.joined: problems.append("bot %d never joined" % bot)
		if row.dropped: problems.append("bot %d dropped out" % bot)
		if int(row.errors) > 0: problems.append("bot %d logged %d errors: %s" % [bot, row.errors, row.first_errors])
		if not host.is_empty() and (not row.storms_on or int(row.storm_seed) != int(host.storm_seed)): problems.append("bot %d did not get the server's storms (%s, seed %d)" % [bot, row.storms_on, row.storm_seed])
		if float(row.sailed_m) < 50.0: problems.append("bot %d hardly sailed (%.0f m)" % [bot, row.sailed_m])
		for key: String in total: total[key] += int(row[key])
	for key: String in total:
		if total[key] < 1: problems.append("no bot %s" % {"docks": "docked", "jobs": "took a job", "deliveries": "delivered", "flights": "flew", "landings": "landed"}[key])
	for pid: int in pids:
		if OS.is_process_running(pid): OS.kill(pid)
	print("SOAK totals: %s" % JSON.stringify(total))
	for problem: String in problems: print("SOAK problem: " + problem)
	print("SOAK_PASS (%d bots, %d s)" % [bots, roundi(seconds)] if problems.is_empty() else "SOAK_FAIL (%d problems)" % problems.size())
	quit(0 if problems.is_empty() else 1)

# --- Server and bots --------------------------------------------------------------

func _process(_delta: float) -> bool:
	if role == "launcher":
		if not done: launcher_step()
		return false
	if done: return false
	if runtime == null:
		if current_scene != null and current_scene.name == "DedicatedRuntime": runtime = current_scene
		elif now_ms() > 60000: finish_role()
		return false
	if role == "server": server_step(_delta)
	else: bot_step()
	return false

func finish_role() -> void:
	if done: return
	done = true
	var data: Dictionary = server if role == "server" else report
	data.errors = errors.count
	data.first_errors = errors.first
	data.seconds = now_ms() / 1000.0
	if role == "bot":
		for action: String in held.keys(): Input.action_release(action)
	var name: String = "server.json" if role == "server" else "bot_%d.json" % index
	var file: FileAccess = FileAccess.open(folder.path_join(name + ".tmp"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(folder.path_join(name + ".tmp"), folder.path_join(name))
	print("SOAK %s done: %s" % [role if role == "server" else "bot %d" % index, JSON.stringify(data)])
	quit(0)

# --- Server -------------------------------------------------------------------------

func server_step(delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if not FileAccess.file_exists(folder.path_join("server.ready")) and runtime.hosting and runtime.world != null:
		var marker: FileAccess = FileAccess.open(folder.path_join("server.ready"), FileAccess.WRITE)
		marker.store_string("ready")
		marker.close()
		server.storm_seed = Storms.storm_seed
		server.storms_on = Storms.enabled
	server.slowest_frame_ms = maxf(server.slowest_frame_ms, delta * 1000.0) if now_ms() > 10000 else 0.0
	server.slowest_physics_ms = maxf(server.slowest_physics_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	server.memory_peak_mb = maxf(server.memory_peak_mb, OS.get_static_memory_peak_usage() / 1048576.0)
	server.players_max = maxi(server.players_max, runtime.contexts.size())
	for sender: int in seen.keys():
		if not runtime.contexts.has(sender):
			seen.erase(sender)
			server.leaves += 1
	for sender: int in runtime.contexts:
		var context: Node3D = runtime.contexts[sender]
		if not seen.has(sender):
			seen[sender] = {"slot": seen.size() % 3, "underway_ms": 0, "air_ms": 0, "staged_air": false, "credits": int(context.reward_minor)}
			server.joins += 1
			context.aviation.unlock_all()
		stage_server(sender, context, seen[sender], now)
	if now - last_print_ms > 15000:
		last_print_ms = now
		print("SOAK_SERVER t=%ds players=%d frame_max=%.1fms memory_peak=%.0fMB deliveries=%d landings=%d" % [now_ms() / 1000, runtime.contexts.size(), server.slowest_frame_ms, server.memory_peak_mb, server.deliveries, server.landings])
	# Done once every bot reported, or the time is up.
	var reported: int = 0
	for bot: int in bots:
		if FileAccess.file_exists(folder.path_join("bot_%d.json" % bot)): reported += 1
	if (reported == bots and runtime.contexts.is_empty()) or now_ms() > int((seconds + GRACE_S) * 1000.0): finish_role()

func stage_server(sender: int, context: Node3D, row: Dictionary, now: int) -> void:
	if int(context.reward_minor) > int(row.credits): server.deliveries += 1
	row.credits = int(context.reward_minor)
	var air: Node = context.aviation
	if air.flying():
		row.underway_ms = 0
		var m: RefCounted = air.model
		if m.on_ground:
			if row.staged_air and m.airspeed() < 0.5:
				server.landings += 1
				row.staged_air = false
				row.air_ms = 0
			return
		if row.air_ms == 0: row.air_ms = now
		if not row.staged_air and now - row.air_ms > FLY_MS:
			# The long flight, skipped: a sloppy final at the nearest airport.
			var landing: RefCounted = Autopilot.new(maxi(0, Airports.nearest(m.position)))
			landing.sloppy_start(m, 2500.0, 60.0, deg_to_rad(5.0), 15.0, 1.35)
			row.staged_air = true
			server.staged_planes += 1
		return
	row.air_ms = 0
	row.staged_air = false
	if context.docking.state(sender) not in ["underway", "approaching"]:
		row.underway_ms = 0
		return
	if row.underway_ms == 0: row.underway_ms = now
	if now - row.underway_ms < SAIL_MS: return
	# The long voyage, skipped: next to a berth at the job's destination, or home.
	var job: Dictionary = context.offers.active_job("preview_captain")
	context.docking.disconnect_owner(sender)
	if job.get("state") == "loaded":
		for place: Node3D in context.world_ports:
			if place.definition.id == job.destination_port_id: context.port = place
	context.bind_port()
	context.ship.transform = context.port.dock_pose(context.ship, int(row.slot))
	context.ship.velocity = Vector3.ZERO
	row.underway_ms = 0
	server.staged_ships += 1

# --- Bot ----------------------------------------------------------------------------

func press(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
		held[action] = true
	elif held.has(action):
		Input.action_release(action)
		held.erase(action)

func act(kind: String, value: String = "") -> bool:
	var now: int = Time.get_ticks_msec()
	if now - last_act_ms < ACT_MS: return false
	last_act_ms = now
	report.actions += 1
	runtime.send_gameplay(kind, value)
	return true

func go(next: String) -> void:
	if next != stage: print("SOAK bot %d t=%ds: %s -> %s" % [index, now_ms() / 1000, stage, next])
	stage = next
	stage_ms = Time.get_ticks_msec()

func bot_step() -> void:
	if runtime.entity.is_empty():
		if report.joined and not done:
			report.dropped = true
			finish_role()
		elif now_ms() > 45000: finish_role()
		return
	var view: Node3D = runtime.view
	if not is_instance_valid(view) or not is_instance_valid(view.ship): return
	if not report.joined:
		report.joined = true
		runtime.actions.result_received.connect(func(response: Dictionary) -> void:
			var code: String = str(response.get("code", "?"))
			report.codes[code] = int(report.codes.get(code, 0)) + 1)
		go("start")
	report.storm_seed = Storms.storm_seed
	report.storms_on = Storms.enabled
	var controls: PlayerControls = view.controls
	controls.window_focused = true
	controls.wait_for_release = false
	var docked: bool = view.docking.state(view.owner_id) == "docked"
	if docked and not was_docked: report.docks += 1
	was_docked = docked
	if not view.flying():
		var at: Vector3 = view.ship.global_position
		if last_at != Vector3.INF and not docked and at.distance_to(last_at) < 50.0: report.sailed_m += at.distance_to(last_at)
		last_at = at
		report.storm_felt = maxf(report.storm_felt, Storms.intensity_at(at))
	if now_ms() > int(seconds * 1000.0):
		finish_role()
		return
	match stage:
		"start": bot_start(view, docked)
		"loading": bot_loading(view)
		"sail": bot_sail(view, docked)
		"deliver": bot_deliver(view)
		"fly": bot_fly(view)
		"air": bot_air(view)

func idle_helm() -> void:
	for action: String in ["ship_steer_left", "ship_steer_right", "ship_throttle_up", "ship_throttle_down", "ship_brake"]: press(action, 0.0)

## Docked: take the smallest container job this port offers (or go flying).
func bot_start(view: Node3D, docked: bool) -> void:
	idle_helm()
	runtime.throttle = 0.0
	if not docked:
		act("dock")
		return
	var job: Dictionary = view.offers.active_job("preview_captain")
	if Time.get_ticks_msec() - stage_ms < 1500: return
	if job.get("state") == "loaded":
		go("sail")
		return
	var best: Dictionary = {}
	for offer: Dictionary in view.offers._offers.values():
		if offer.get("state") != "available" or offer.get("origin_port_id") != view.port.definition.id: continue
		if best.is_empty() or int(offer.quantity) < int(best.quantity): best = offer
	if best.is_empty() or report.jobs > report.flights:
		go("fly")
		return
	if act("accept", str(best.id)):
		report.jobs += 1
		go("loading")

func bot_loading(view: Node3D) -> void:
	var job: Dictionary = view.offers.active_job("preview_captain")
	if job.is_empty() and Time.get_ticks_msec() - stage_ms > 5000:
		go("start")
		return
	if job.get("state") != "loaded" or view.loading.busy() or view.cranes_busy(): return
	if view.docking.state(view.owner_id) == "docked": act("dock")
	else: go("sail")

## Out to sea: full ahead, the wheel wandering; then stop and ask to dock
## (the server brings a ship that has sailed a while to a berth).
func bot_sail(view: Node3D, docked: bool) -> void:
	var age: int = Time.get_ticks_msec() - stage_ms
	if docked and age > 3000:
		idle_helm()
		runtime.throttle = 0.0
		var job: Dictionary = view.offers.active_job("preview_captain")
		credits_before = int(view.reward_minor)
		# (The server knows which port this is: it refuses a delivery elsewhere.)
		go("deliver" if job.get("state") == "loaded" else "start")
		return
	if docked:
		act("dock")
		return
	if age < SAIL_MS - 2000:
		runtime.throttle = 1.0
		var wheel: float = sin(age / 1000.0 * 0.4 + index)
		press("ship_steer_right", wheel * 0.7)
		press("ship_steer_left", -wheel * 0.7)
	else:
		idle_helm()
		runtime.throttle = 0.0
		press("ship_brake", 1.0 if view.ship.velocity.length() > 0.5 else 0.0)
		# (After the server has brought it to a berth: see stage_server.)
		if age > SAIL_MS + 1500: act("dock")

func bot_deliver(view: Node3D) -> void:
	if int(view.reward_minor) > credits_before:
		report.deliveries += 1
		go("start")
		return
	if Time.get_ticks_msec() - stage_ms > 6000:
		go("start")
		return
	act("deliver")

## Docked: switch to the plane, then take off with the autopilot's keys.
func bot_fly(view: Node3D) -> void:
	idle_helm()
	runtime.throttle = 0.0
	if view.flying():
		report.flights += 1
		landed = false
		var m: RefCounted = view.aviation.model
		pilot = Autopilot.new(maxi(0, (Airports.nearest(m.position) + 1) % Airports.count()))
		last_plane_at = m.position
		go("air")
		return
	if view.docking.state(view.owner_id) != "docked":
		go("start")
		return
	act("plane_switch")

func bot_air(view: Node3D) -> void:
	var air: Node = view.aviation
	if not view.flying():
		idle_helm()
		go("start")
		return
	var m: RefCounted = air.model
	# The server staged the final approach: the plane jumped. Land there.
	if last_plane_at != Vector3.INF and m.position.distance_to(last_plane_at) > 800.0 and pilot.phase not in ["sloppy", "rollout"]:
		pilot = Autopilot.new(maxi(0, Airports.nearest(m.position)))
		pilot.phase = "sloppy"
		pilot.lever = 0.3
	last_plane_at = m.position
	var out: Dictionary = pilot.sloppy_inputs(m) if pilot.phase in ["sloppy", "rollout"] else pilot.inputs(m)
	air.lever = clampf(float(out.get("throttle", 0.0)), 0.0, 1.0)
	air.gear_order = float(out.get("gear", air.gear_order))
	var pitch: float = float(out.get("pitch", 0.0))
	var roll: float = float(out.get("roll", 0.0))
	press("ship_throttle_up", pitch)
	press("ship_throttle_down", -pitch)
	press("ship_steer_right", roll)
	press("ship_steer_left", -roll)
	press("ship_brake", float(out.get("brake", 0.0)))
	if pilot.phase == "rollout" and m.on_ground and m.airspeed() < 0.5:
		idle_helm()
		if not landed:
			landed = true
			report.landings += 1
		if air.stopped_at() >= 0: act("boat_switch")
