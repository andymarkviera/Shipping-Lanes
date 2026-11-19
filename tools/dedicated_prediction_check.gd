extends SceneTree
## Patch 3.0.1: real UDP server + two clients with the client runtime's own
## physics left ON. Held keys must move the own hull before the server echoes
## it, reconciliation must stay smooth, ping must be shown and a live rename
## must reach the other captain's nameplate.
var runtime: Node3D
var started: int
var ready_at: int = 0
var checks: int = 0
var failures: int = 0
var pressed_at: int = 0
var start_position: Vector3 = Vector3.INF
var moved_before_echo: bool = false
var max_gap: float = 0.0
var max_step: float = 0.0
var last_position: Vector3 = Vector3.INF
var renamed: bool = false
var saw_rename: bool = false
var server_peak_bytes: float = 0.0
var steering_client: bool = false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	change_scene_to_file.call_deferred("res://features/main/boot.tscn")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PREDICTION_CHECK: " + message)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 60000:
		check(false, "timed out")
		finish()
		return false
	if runtime == null:
		if current_scene != null and current_scene.name == "DedicatedRuntime": runtime = current_scene
		return false
	if runtime.hosting: server_step()
	elif not runtime.entity.is_empty() and runtime.received_states > 0: client_step()
	return false

func server_step() -> void:
	if runtime.contexts.size() == 2 and ready_at == 0: ready_at = Time.get_ticks_msec()
	if ready_at == 0: return
	if Time.get_ticks_msec() - ready_at > 3000 and runtime.contexts.size() == 2:
		server_peak_bytes = maxf(server_peak_bytes, runtime.sent_bytes / maxf(0.001, runtime.report_elapsed))
	if Time.get_ticks_msec() - ready_at > 26000:
		check(runtime.contexts.is_empty(), "both clients left cleanly")
		# Each of 2 recipients gets 2 ships at 20 Hz: bytes per ship per second
		# per recipient (frame header shared) must stay under 1 KiB.
		check(server_peak_bytes > 0 and server_peak_bytes / 4.0 < 1024.0, "server motion bytes per ship per second %.0f under budget" % (server_peak_bytes / 4.0))
		print("SERVER_METRICS bytes_per_ship_s=%.0f send_us=%.0f" % [server_peak_bytes / 4.0, runtime.server_send_us])
		check(runtime.server_send_us < 20000, "server send path %.0f us per tick" % runtime.server_send_us)
		finish()

func client_step() -> void:
	var view: Node3D = runtime.view
	var now: int = Time.get_ticks_msec()
	if ready_at == 0:
		ready_at = now
		steering_client = runtime.captain_name.ends_with("client1")
		check(runtime.is_physics_processing() and is_instance_valid(runtime.ghost), "prediction runtime active")
		check(not view.ship.is_physics_processing() and view.ship.collision_layer == 0, "presented hull still render only")
		check(runtime.captain_name.begins_with("Probe"), "--captain= override kept")
	var age: int = now - ready_at
	if age < 1500: return
	if not steering_client:
		if runtime.replicas.size() == 1:
			var label: String = runtime.replicas.values()[0].label.text
			if label == "Renamed One": saw_rename = true
		if age > 18000:
			check(saw_rename, "live rename reached the other captain's nameplate")
			check(runtime.rtt_ms >= 0 and runtime.ping_label != null and runtime.ping_label.text.ends_with(" ms"), "ping readout shown")
			check(runtime.buffer_seconds >= runtime.BUFFER_MIN and runtime.buffer_seconds <= runtime.BUFFER_MAX, "adaptive buffer clamped (%.3f s)" % runtime.buffer_seconds)
			finish()
		return
	if pressed_at == 0:
		if not runtime.predicting(): return
		pressed_at = now
		start_position = view.ship.position
		Input.action_press("ship_throttle_up")
		Input.action_press("ship_steer_right", 0.3)
	if not renamed and age > 4000:
		renamed = true
		runtime.rename_captain.rpc_id(1, "  Renamed  One!!  ")
		runtime.captain_name = "Renamed One"
	if last_position != Vector3.INF:
		max_step = maxf(max_step, runtime.Progression.short_way(view.ship.position - last_position).length())
	last_position = view.ship.position
	# Before the server can have echoed any helm, the presented hull moves.
	if now - pressed_at < 400 and runtime.last_state.velocity.length() < 0.05 and runtime.ghost.velocity.length() > 0.01: moved_before_echo = true
	if now - pressed_at > 4000 and now - pressed_at < 9000:
		max_gap = maxf(max_gap, runtime.Progression.short_way(view.ship.position - runtime.last_state.position).length())
	if now - pressed_at > 9000:
		Input.action_release("ship_throttle_up")
		Input.action_release("ship_steer_right")
		check(runtime.predicted_frames > 100, "own hull predicted every physics tick")
		check(moved_before_echo, "own hull answers the helm before the server echo")
		check(runtime.Progression.short_way(view.ship.position - start_position).length() > 5, "own hull sailed")
		# Loopback: prediction leads the snapshot by about one send interval.
		check(max_gap < 6.0, "prediction stays near the authority (max gap %.2f m)" % max_gap)
		check(runtime.snaps == 0, "no hard snaps while sailing in open water")
		check(max_step < 2.0, "presented own hull never jumps (max frame step %.2f m)" % max_step)
		check(runtime.history_count < runtime.HISTORY, "acknowledged helm history is trimmed")
		check(runtime.rtt_ms >= 0 and runtime.ping_label.text.ends_with(" ms"), "ping readout shown")
		print("PREDICTION_METRICS gap=%.2fm step=%.2fm rtt=%.0fms buffer=%.0fms corrections=%d snaps=%d snapshot_us=%.0f" % [max_gap, max_step, runtime.rtt_ms, runtime.buffer_seconds * 1000.0, runtime.corrections, runtime.snaps, runtime.client_snapshot_us])
		finish()

func finish() -> void:
	print("DEDICATED_PREDICTION_%s %s checks=%d" % ["PASS" if failures == 0 else "FAIL", "server" if runtime != null and runtime.hosting else "client", checks])
	quit(0 if failures == 0 else 1)
