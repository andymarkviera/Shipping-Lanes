extends SceneTree
## Three-process loopback probe, launched by tools/check_dedicated_split.py.
var runtime: Node3D
var started: int = 0
var ready_at: int = 0
var checks: int = 0
var failures: int = 0
var tampered: bool = false
var server_seen: bool = false
var initial: Dictionary = {}
var moved: bool = false
var timed_out: bool = false
var last_send: int = 0
var label: String = ""
var remote_start: Vector3 = Vector3.INF
var remote_moved: bool = false
var remote_frames: int = 0
var remote_last: Vector3
var remote_smooth: bool = true

func _initialize() -> void:
	started = Time.get_ticks_msec()
	label = "server" if OS.get_cmdline_user_args().has("--server") else "client"
	change_scene_to_file.call_deferred("res://features/main/boot.tscn")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("SPLIT_CHECK: " + message)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 45000:
		check(false, "timed out")
		finish()
		return false
	if runtime == null:
		if current_scene != null and current_scene.name == "DedicatedRuntime": runtime = current_scene
		return false
	if runtime.hosting: server_step()
	else: client_step()
	return false

func server_step() -> void:
	if runtime.contexts.size() == 2 and not server_seen:
		server_seen = true
		ready_at = Time.get_ticks_msec()
		check(runtime.world.world_ports.size() == runtime.Progression.WORLD.size(), "every port, Point Nemo too (%d)" % runtime.world.world_ports.size())
		check(runtime.world.icebergs.size() == runtime.Progression.ICEBERGS.size(), "icebergs retained")
		check(not paused, "server tree is running")
		check(runtime.wrap.static_shapes > 0, "static edge collision copies exist")
		check(runtime.wrap.hulls.size() == 2, "pooled hull edge copies exist")
		for sender: int in runtime.contexts:
			var context: Node3D = runtime.contexts[sender]
			check(context.persistence == null and not context.save_enabled, "no player-save access")
			check(context.controls == null and context.camera == null, "no per-player presentation")
			check(context.world_ports[0] == runtime.world.world_ports[0], "shared port colliders")
			check(context.docking.claims == runtime.world.docking.claims, "shared berth ownership")
			check(context.ship.is_physics_processing(), "server hull simulates")
			check(context.fleet.has("container") and not context.offers.list_at(context.port.definition.id).is_empty(), "server fleet/jobs exist")
			initial[sender] = context.ship.position
		var peers: Array = runtime.contexts.keys()
		var claims = runtime.world.docking.claims
		check(claims.claim("check/berth", peers[0]), "first berth claim")
		check(not claims.claim("check/berth", peers[1]), "second berth claim rejected")
		claims.release_owner(peers[0])
	if not server_seen: return
	for sender: int in runtime.contexts:
		var ship: HandlingShip = runtime.contexts[sender].ship
		if initial.has(sender) and ship.position.distance_to(initial[sender]) > 0.2: moved = true
		if Time.get_ticks_msec() - ready_at > 4500 and ship.commanded_throttle == 0 and ship.rudder == 0: timed_out = true
	if Time.get_ticks_msec() - ready_at > 10500:
		check(moved, "accepted helm moves an authoritative hull")
		check(timed_out, "silent clients neutralize after 500 ms")
		check(runtime.rejected_inputs >= 8, "forged/malformed/stale helm rejected")
		check(runtime.contexts.is_empty() and runtime.ships.is_empty(), "departed hulls removed")
		check(runtime.world.docking.claims.holders.is_empty(), "departed berth claims released")
		check(runtime.wrap.hulls.is_empty(), "departed edge hulls removed")
		check(runtime.actions.receipts.is_empty() and runtime.replication.orders.is_empty(), "departed input state released")
		finish()

func client_step() -> void:
	if runtime.entity.is_empty(): return
	if ready_at == 0:
		ready_at = Time.get_ticks_msec()
		runtime.set_physics_process(false) # this probe drives the normal RPC sender
		check(runtime.view.persistence == null and not runtime.view.save_enabled, "client never opens a save")
		check(not runtime.view.ship.is_physics_processing(), "client hull cannot simulate")
		check(not runtime.view.docking.is_physics_processing(), "client cannot dock locally")
		check(runtime.view.ship.collision_layer == 0 and runtime.view.ship.collision_mask == 0, "client hull is presentation only")
		check(not runtime.view.is_physics_processing(), "client economy/world physics disabled")
		check(runtime.view.ship.assembly.visual != null and runtime.view.wake != null, "toon hull/waves/wake retained")
		# Real wire ingress: forged owner, wrong epoch, nonfinite, range and kind.
		var request: Dictionary = ShipActions.make_request(runtime.session.epoch, runtime.multiplayer.get_unique_id(), runtime.entity, "helm", 1,
			{"throttle": 0.5, "rudder": 0.0, "lateral": 0.0, "sent_ms": Time.get_ticks_msec()})
		var bad: Dictionary = request.duplicate(true)
		bad.player = 1
		runtime.helm_input.rpc_id(1, bad)
		bad = request.duplicate(true); bad.epoch = "old"
		runtime.helm_input.rpc_id(1, bad)
		bad = request.duplicate(true); bad.payload.throttle = NAN
		runtime.helm_input.rpc_id(1, bad)
		bad = request.duplicate(true); bad.payload.rudder = 2.0
		runtime.helm_input.rpc_id(1, bad)
		bad = request.duplicate(true); bad.kind = "pay"
		runtime.helm_input.rpc_id(1, bad)
		runtime.sequence = 10
		runtime.view.controls.command_requested.emit(&"pause")
		check(runtime.view.game_menu.is_open() and not paused, "Esc opens menu without pausing")
		runtime.view.game_menu.close()
		check(runtime.view.cranes != null, "crane presentation retained")
	var age: int = Time.get_ticks_msec() - ready_at
	if runtime.replicas.size() == 1 and age < 3500:
		var body: HandlingShip = runtime.replicas.values()[0].body
		if remote_start == Vector3.INF: remote_start = body.position
		else:
			remote_moved = remote_moved or body.position.distance_to(remote_start) > 0.2
			if remote_frames > 0 and body.position.distance_to(remote_last) > 1.0: remote_smooth = false
		remote_last = body.position
		remote_frames += 1
	if age < 3000 and Time.get_ticks_msec() - last_send >= 50:
		last_send = Time.get_ticks_msec()
		runtime.send_helm(0.7, 0.1, 0.0)
	if age > 4000 and not tampered and not runtime.last_state.is_empty():
		tampered = true
		runtime.view.ship.position += Vector3(5000, 0, 0)
		runtime.view.ship.state.fuel_liters = 0.0
		runtime.view.reward_minor = 99999999
	if age > 8000:
		check(remote_moved and remote_frames > 30 and remote_smooth, "other captain's helm drives a smoothly presented remote hull")
		check(runtime.received_states > 40, "20 Hz server snapshots received")
		check(runtime.samples.size() <= 16, "bounded interpolation buffer")
		check(runtime.last_state.get("throttle", -1.0) == 0.0, "server stopped stale helm")
		check(runtime.view.ship.state.fuel_liters > 0, "client fuel tamper overwritten")
		check(not runtime.last_state.is_empty() and runtime.view.ship.position.distance_to(runtime.last_state.get("position", Vector3.INF)) < 10, "client pose tamper overwritten")
		check(not paused, "client menu never pauses world")
		finish()

func finish() -> void:
	print("DEDICATED_SPLIT_%s %s checks=%d" % ["PASS" if failures == 0 else "FAIL", label, checks])
	quit(0 if failures == 0 else 1)
