extends Node3D
## Patch 3.0 item 1. Ephemeral sessions only; persistence and gameplay replication
## are later items. Never opens a player database or contacts an external service.
const GAME = preload("res://features/game/game.tscn")
const Progression = preload("res://features/game/progression.gd")
const PROTOCOL: int = 30001
const MAX_PLAYERS: int = 8
const INTERVAL: float = 0.05
const BUFFER_SECONDS: float = 0.15
const TIMEOUT_MS: int = 500
var hosting: bool = false
var peer: ENetMultiplayerPeer
var wrap: Node3D
var world: Node3D
var view: Node3D
var contexts: Dictionary = {}
var ships: Dictionary = {}
# Reuse the established ACTION_VALIDATION contract without the old private-save
# transport. This session is not added to the tree and never opens its stores.
var session: LocalShipSession = LocalShipSession.new()
var replication: Dictionary = {"orders": {}}
var actions: ShipActions = ShipActions.new()
var entity: String = ""
var sequence: int = 0
var tick: int = 0
var elapsed: float = 0.0
var send_elapsed: float = 0.0
var throttle: float = 0.0
var samples: Array[Dictionary] = []
var clock_offset: float = INF
var last_tick: int = -1
var received_states: int = 0
var last_state: Dictionary = {}
var rejected_inputs: int = 0
var notice: Label
var status: String = "Connecting…"
var join_deadline: int = 0
var pending_peers: Dictionary = {}
var port_number: int = 24565

func _ready() -> void:
	process_physics_priority = -20
	var args: PackedStringArray = OS.get_cmdline_user_args()
	hosting = OS.has_feature("dedicated_server") or OS.has_feature("server") or args.has("--server")
	var host: String = "127.0.0.1"
	var bind_address: String = "127.0.0.1"
	for arg: String in args:
		if arg.begins_with("--port="):
			var number: String = arg.trim_prefix("--port=")
			if not number.is_valid_int() or int(number) < 1024 or int(number) > 65535:
				fail("Invalid UDP port", 2)
				return
			port_number = int(number)
		elif arg.begins_with("--host="): host = arg.trim_prefix("--host=")
		elif arg.begins_with("--bind="): bind_address = arg.trim_prefix("--bind=")
	if hosting and DisplayServer.get_name() != "headless":
		fail("Server requires --headless", 2)
		return
	if hosting:
		world = GAME.instantiate()
		world.runtime_role = "world"
		world.name = "World"
		add_child(world)
		disable_tree(world)
		wrap = preload("res://features/network/dedicated_wrap.gd").new()
		add_child(wrap)
		wrap.setup(world)
		# These UI objects normally join the local HUD after world construction.
		world.voyage_hud.free()
		world.minimap.free()
		session.hosting = true
		session.epoch = Crypto.new().generate_random_bytes(16).hex_encode()
	else:
		view = GAME.instantiate()
		view.runtime_role = "client"
		view.name = "View"
		add_child(view)
		view.set_physics_process(false)
		view.docking.set_physics_process(false)
		view.loading.set_process(false)
		view.loading.set_physics_process(false)
		disable_tree(view.cranes)
		disable_tree(view.mooring)
		view.ship.set_physics_process(false)
		view.ship.collision_layer = 0
		view.ship.collision_mask = 0
		view.helm.set_physics_process(false)
		view.controls.command_requested.disconnect(view.helm.command)
		view.controls.command_requested.connect(client_command)
		view.helm.notice.hints = {"rescue": false}
		# Item 2 adds authoritative service UI. No local click may mutate cargo,
		# wallet, fleet, docking or recovery in this render-only runtime.
		view.port_panel.hide()
		view.game_hud.hide()
		var layer: CanvasLayer = CanvasLayer.new()
		add_child(layer)
		notice = Label.new()
		notice.position = Vector2(24, 24)
		layer.add_child(notice)
		join_deadline = Time.get_ticks_msec() + 10000
	actions.name = "Actions"
	add_child(actions)
	actions.configure(self, session)
	# Only the bounded helm ingress below is exposed in item 1. ShipActions
	# remains the validator, not an extra reachable RPC node.
	actions.rpc_config("request_action", {"rpc_mode": MultiplayerAPI.RPC_MODE_DISABLED})
	peer = ENetMultiplayerPeer.new()
	var error: Error
	if hosting:
		peer.set_bind_ip(bind_address)
		error = peer.create_server(port_number, MAX_PLAYERS, 3)
	else:
		error = peer.create_client(host, port_number, 3)
	if error != OK:
		fail("Cannot open UDP transport (%s)" % error_string(error), 2)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(id: int):
		if hosting: pending_peers[id] = Time.get_ticks_msec() + 10000)
	multiplayer.peer_disconnected.connect(depart)
	multiplayer.connected_to_server.connect(func(): hello.rpc_id(1, PROTOCOL))
	multiplayer.connection_failed.connect(func(): fail("Connection failed"))
	multiplayer.server_disconnected.connect(func(): fail("Server disconnected"))
	if hosting: print("DEDICATED_SERVER_READY port=%d" % port_number)

func client_command(action: StringName) -> void:
	if action == &"pause": view.game_menu.open()
	if action == &"horn": view.helm.feedback.sound_horn(view.controls.input_allowed())

static func disable_tree(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	if node is CanvasLayer: node.hide()
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	for child: Node in node.get_children(): disable_tree(child)

func fail(message: String, exit_code: int = 0) -> void:
	status = message
	entity = ""
	samples.clear()
	throttle = 0.0
	join_deadline = 0
	if peer != null: peer.close()
	if is_instance_valid(view):
		view.ship.velocity = Vector3.ZERO
		view.ship.ground_speed_mps = 0.0
	if hosting or exit_code != 0:
		push_error(message)
		get_tree().quit(maxi(1, exit_code))

@rpc("any_peer", "call_remote", "reliable", 0)
func hello(version: int) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not pending_peers.has(sender): return
	pending_peers.erase(sender)
	if version != PROTOCOL or contexts.size() >= MAX_PLAYERS:
		peer.disconnect_peer(sender)
		return
	var context: Node3D = GAME.instantiate()
	context.runtime_role = "server"
	context.owner_id = sender
	context.shared_world = world
	context.docking.claims = world.docking.claims
	context.name = "Player%d" % sender
	add_child(context)
	if not is_instance_valid(context.ship):
		context.queue_free()
		peer.disconnect_peer(sender)
		return
	disable_tree(context)
	context.set_physics_process(true)
	context.ship.set_physics_process(true)
	context.docking.set_physics_process(true)
	context.loading.set_process(true)
	context.loading.set_physics_process(true)
	var id: String = "ship_%d" % sender
	contexts[sender] = context
	ships[id] = context.ship
	wrap.add_hull(id, context.ship)
	session.roster[id] = {"peer_id": sender}
	welcome.rpc_id(sender, PROTOCOL, session.epoch, id)
	print("DEDICATED_JOIN players=%d" % contexts.size())

func depart(sender: int) -> void:
	if not hosting: return
	pending_peers.erase(sender)
	if not contexts.has(sender): return
	var context: Node3D = contexts[sender]
	context.docking.disconnect_owner(sender)
	context.port.spawn_allocator.release(context.spawn_ticket)
	var id: String = "ship_%d" % sender
	contexts.erase(sender)
	ships.erase(id)
	wrap.remove_hull(id)
	session.roster.erase(id)
	replication.orders.erase(id)
	actions.reconcile()
	context.queue_free()
	print("DEDICATED_LEAVE players=%d" % contexts.size())

@rpc("authority", "call_remote", "reliable", 0)
func welcome(version: int, epoch: String, id: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or version != PROTOCOL: return
	if not entity.is_empty() or epoch.length() != 32 or id != "ship_%d" % multiplayer.get_unique_id(): return
	session.epoch = epoch
	entity = id
	join_deadline = 0
	status = "Connected · Helm preview · W/S throttle, A/D steer · Esc menu"

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func helm_input(request: Dictionary) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not contexts.has(sender) or request.get("kind") != "helm":
		rejected_inputs += 1
		return
	var result: Dictionary = actions.execute(sender, request)
	if not result.applied: rejected_inputs += 1

func _physics_process(delta: float) -> void:
	elapsed += delta
	if hosting:
		wrap.sync(ships)
		for sender: int in pending_peers.keys():
			if Time.get_ticks_msec() > pending_peers[sender]:
				pending_peers.erase(sender)
				peer.disconnect_peer(sender)
		for id: String in ships:
			var ship: HandlingShip = ships[id]
			var order: Dictionary = replication.orders.get(id, {})
			if order.is_empty() or Time.get_ticks_msec() - order.at > TIMEOUT_MS:
				ship.zero_throttle()
				ship.maneuver(0, 0)
			else:
				ship.command_throttle(order.throttle)
				ship.maneuver(order.rudder, order.lateral)
	elif not entity.is_empty() and is_instance_valid(view):
		var allowed: bool = view.controls.input_allowed()
		var axis: float = view.controls.action_strength("ship_throttle_up") - view.controls.action_strength("ship_throttle_down") if allowed else 0.0
		throttle = HandlingShip.adjusted_order(throttle, axis, delta, view.ship.definition)
		if allowed and view.controls.action_strength("ship_throttle_zero") > 0: throttle = 0.0
	send_elapsed += delta
	if send_elapsed < INTERVAL: return
	send_elapsed = fmod(send_elapsed, INTERVAL)
	if hosting:
		tick += 1
		for sender: int in contexts:
			var ship: HandlingShip = contexts[sender].ship
			snapshot.rpc_id(sender, session.epoch, tick, elapsed, {
				"position": ship.global_position, "yaw": ship.rotation.y,
				"velocity": ship.velocity, "ground_speed": ship.ground_speed_mps,
				"throttle": ship.commanded_throttle, "engine": ship.actual_throttle,
				"rudder": ship.rudder, "lateral": ship.lateral_order,
				"fuel": ship.state.fuel_liters, "condition": ship.state.condition})
	elif not entity.is_empty():
		var allowed: bool = view.controls.input_allowed()
		send_helm(throttle, view.controls.steering_axis() if allowed else 0.0,
			view.controls.action_strength("ship_thruster_right") - view.controls.action_strength("ship_thruster_left") if allowed else 0.0)

func send_helm(command: float, rudder: float, lateral: float) -> void:
	sequence += 1
	helm_input.rpc_id(1, ShipActions.make_request(session.epoch, multiplayer.get_unique_id(), entity, "helm", sequence,
		{"throttle": command, "rudder": rudder, "lateral": lateral, "sent_ms": Time.get_ticks_msec()}))

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func snapshot(epoch: String, frame: int, stamp: float, state: Dictionary) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or entity.is_empty() or epoch != session.epoch or frame <= last_tick: return
	if not is_finite(stamp) or stamp < 0 or state.size() != 10: return
	for key: String in ["position", "velocity"]:
		if not state.get(key) is Vector3 or not state[key].is_finite(): return
	for key: String in ["yaw", "ground_speed", "throttle", "engine", "rudder", "lateral", "fuel", "condition"]:
		if not state.get(key) is float or not is_finite(state[key]): return
	last_tick = frame
	received_states += 1
	last_state = state
	clock_offset = minf(clock_offset, Time.get_ticks_msec() / 1000.0 - stamp)
	samples.append({"stamp": stamp, "state": state})
	while samples.size() > 16: samples.pop_front()
	if received_states == 1:
		view.ship.position = state.position
		view.ship.rotation.y = state.yaw
		view.camera.set_focus(view.ship.assembly.focus)

func _process(_delta: float) -> void:
	if hosting: return
	if join_deadline > 0 and Time.get_ticks_msec() > join_deadline: fail("Connection timed out")
	if notice != null: notice.text = status
	if samples.is_empty(): return
	var target: float = Time.get_ticks_msec() / 1000.0 - clock_offset - BUFFER_SECONDS
	while samples.size() > 2 and samples[1].stamp <= target: samples.pop_front()
	var a: Dictionary = samples[0]
	var b: Dictionary = samples[mini(1, samples.size() - 1)]
	var weight: float = clampf((target - a.stamp) / maxf(0.000001, b.stamp - a.stamp), 0.0, 1.0)
	var ship: HandlingShip = view.ship
	# Interpolate across the short side of the torus, never through its middle.
	var next: Vector3 = a.state.position.lerp(Progression.nearest(b.state.position, a.state.position), weight)
	var wrapped: Vector3 = Progression.wrapped(next)
	var shift: Vector3 = wrapped - next
	# Camera/wake follow the same seam crossing as the presented hull.
	var old_near: Vector3 = Progression.nearest(ship.position, wrapped)
	var seam: Vector3 = old_near - ship.position
	if seam.length() > 1.0:
		view.camera.shift(seam)
		view.wake.shift(seam)
		view.ocean.shift(seam)
	ship.position = next + shift
	ship.rotation.y = lerp_angle(a.state.yaw, b.state.yaw, weight)
	ship.velocity = a.state.velocity.lerp(b.state.velocity, weight)
	ship.ground_speed_mps = lerpf(a.state.ground_speed, b.state.ground_speed, weight)
	ship.commanded_throttle = b.state.throttle
	ship.actual_throttle = b.state.engine
	ship.rudder = b.state.rudder
	ship.lateral_order = b.state.lateral
	ship.state.fuel_liters = b.state.fuel
	ship.state.condition = b.state.condition
	view.place_icebergs()

func _exit_tree() -> void:
	if peer != null: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session.free()
