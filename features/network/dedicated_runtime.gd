extends Node3D
## Patch 3.0 authoritative multiplayer with dedicated, migrating saves.
const Connection = preload("res://features/network/play_connection.gd")
const GAME = preload("res://features/game/game.tscn")
const Progression = preload("res://features/game/progression.gd")
const PROTOCOL: int = 30003
const MAX_PLAYERS: int = 8
const INTERVAL: float = 0.05
const BUFFER_SECONDS: float = 0.15
const TIMEOUT_MS: int = 500
const SaveStore = preload("res://features/network/server_save_store.gd")
const SaveSnapshot = preload("res://features/cargo/voyage_snapshot.gd")
var saves = SaveStore.new()
var saves_path: String = ""
var install_key: String = ""
var player_keys: Dictionary = {}
var joining_keys: Dictionary = {}
var teardown_players: Dictionary = {}
var save_elapsed: float = 0.0
var save_failed: bool = false
var launcher = preload("res://features/network/server_launcher_control.gd").new()
var hosting: bool = false
var connection_card: Control
var updating: bool = false
var last_snapshot_ms: int = 0
var connection_failed: bool = false
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
var captain_name: String = "Captain"
var captains: Dictionary = {}
var replicas: Dictionary = {}
var last_gameplay: Dictionary = {}
var action_sequence: int = 0
var action_result: Dictionary = {}
var world_samples: Array[Dictionary] = []
var last_gameplay_at: Dictionary = {}
var incoming_frame: int = -1
var incoming_chunks: Dictionary = {}
var incoming_total: int = 0
var last_salute: Dictionary = {}

func gameplay_payload_error(payload: Dictionary) -> String:
	if payload.size() != 2 or not payload.get("action") is String or not payload.get("value") is String: return "BAD_PAYLOAD"
	if payload.value.length() > 128: return "BAD_PAYLOAD"
	if payload.action not in ["dock", "cancel_dock", "accept", "cancel_load", "abandon", "deliver", "refuel", "repair", "recover", "ship", "sell", "lower", "raise", "salute"]: return "UNKNOWN_ACTION"
	if payload.action in ["ship", "sell"]:
		if not Progression.SHIPS.has(payload.value): return "BAD_PAYLOAD"
	elif payload.action == "accept":
		if payload.value.is_empty(): return "BAD_PAYLOAD"
	elif not payload.value.is_empty(): return "BAD_PAYLOAD"
	return ""

func execute_gameplay(sender: int, payload: Dictionary) -> String:
	if not contexts.has(sender): return "NOT_OWNER"
	var now: int = Time.get_ticks_msec()
	if now - int(last_gameplay_at.get(sender, -1000)) < 100: return "RATE_LIMITED"
	last_gameplay_at[sender] = now
	var context: Node3D = contexts[sender]
	match payload.action:
		"salute":
			if not Progression.PIRATE_KINDS.has(context.ship_kind) or now - int(last_salute.get(sender, -5000)) < 5000: return "OUT_OF_RANGE"
			last_salute[sender] = now
			cosmetic_salute.rpc("ship_%d" % sender)
		"dock":
			if context.loading.busy() or context.cranes_busy() or context.sink_seconds > 0: return "BUSY"
			if context.docking.state(sender) == "docked": context.docking.request_undock(sender)
			else:
				var result: Dictionary = context.docking.request_dock(sender, context.service_id(), context.cargo_id())
				context.offer_notice = result.message
				if not result.ok: return "OUT_OF_RANGE"
		"cancel_dock":
			if not context.docking.cancel(sender): return "OUT_OF_RANGE"
		"accept":
			context.selected_offer = payload.value
			if not context.accept_reason().is_empty(): return "OUT_OF_RANGE"
			context.accept_selected()
			if not context.loading.busy() and context.bulk_active.is_empty() and context.heavy_jobs.active.is_empty(): return "OUT_OF_RANGE"
		"cancel_load":
			if not context.loading.busy() and not (context.heavy_mode and context.heavy_jobs.active.get("state") == "pickup"): return "OUT_OF_RANGE"
			context.end_current_job(false)
		"abandon": context.request_abandon()
		"deliver":
			if not context.deliver_reason().is_empty(): return "OUT_OF_RANGE"
			context.deliver()
		"refuel", "repair":
			if context.docking.state(sender) != "docked" or context.loading.busy(): return "OUT_OF_RANGE"
			if payload.action == "refuel": context.refuel()
			else: context.repair()
		"recover":
			if context.ship.state.fuel_liters > 0 or context.ship.docked: return "OUT_OF_RANGE"
			context.recover()
		"ship":
			if context.cranes_busy(): return "BUSY"
			if context.docking.state(sender) != "docked": return "OUT_OF_RANGE"
			context.ship_action(payload.value)
			var id: String = "ship_%d" % sender
			if ships[id] != context.ship:
				disable_tree(context.ship)
				context.ship.set_physics_process(true)
				replication.orders.erase(id)
				wrap.remove_hull(id)
				ships[id] = context.ship
				wrap.add_hull(id, context.ship)
		"sell":
			if context.docking.state(sender) != "docked": return "OUT_OF_RANGE"
			context.sell_ship(payload.value)
		"lower", "raise":
			if not context.heavy_mode: return "OUT_OF_RANGE"
			if not context.ship.request_height(-1.0 if payload.action == "lower" else 2.6): return "OUT_OF_RANGE"
	return "OK"

func send_gameplay(kind: String, value: String = "") -> void:
	if entity.is_empty(): return
	action_sequence += 1
	gameplay_action.rpc_id(1, ShipActions.make_request(session.epoch, multiplayer.get_unique_id(), entity, "gameplay", action_sequence, {"action": kind, "value": value}))

@rpc("any_peer", "call_remote", "reliable", 0)
func gameplay_action(request: Dictionary) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not contexts.has(sender): return
	var response: Dictionary = actions.execute(sender, request) if request.get("kind") == "gameplay" else actions.result("", "UNKNOWN_ACTION")
	gameplay_result.rpc_id(sender, response)


@rpc("authority", "call_remote", "reliable", 0)
func gameplay_result(response: Dictionary) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or response.get("epoch") != session.epoch: return
	action_result = response
	actions.result_received.emit(response)
	if not response.get("ok", false): status = "Action refused: " + str(response.get("code"))

func server_preview(owner: int) -> Vector2i:
	return contexts[owner].crane_preview(owner) if contexts.has(owner) else Vector2i.ZERO

func ship_frame(sender: int) -> Dictionary:
	var context: Node3D = contexts[sender]
	var body: HandlingShip = context.ship
	var entry: Dictionary = context.docking.members[sender]
	var visuals: Node3D = body.assembly.container_visuals
	var heavy: Dictionary = {}
	if context.heavy_mode:
		heavy = {"height": body.deck_height, "target": body.deck_target, "attached": body.attached,
			"active": context.heavy_jobs.active, "pose": body.payload_body.global_transform if body.payload_body.is_inside_tree() else Transform3D.IDENTITY}
	return {"owner": sender, "captain": captains[sender], "kind": context.ship_kind,
		"position": body.position, "yaw": body.rotation.y, "velocity": body.velocity, "speed": body.ground_speed_mps,
		"yaw_rate": body.yaw_rate,
		"engine": body.actual_throttle, "throttle": body.commanded_throttle, "rudder": body.rudder, "lateral": body.lateral_order,
		"port": context.world_ports.find(context.port), "dock": entry.state, "berth": entry.berth_index,
		"remaining": entry.remaining, "docked": body.docked, "filled": visuals.filled,
		"paused": body.simulation_paused, "pause_reason": body.pause_reason,
		"heavy": heavy, "job": context.bulk_active if context.bulk_mode() else context.offers.active_job("preview_captain").get("id", ""),
		"credits": context.reward_minor, "readiness": context.docking.readiness(sender, context.service_id(), context.cargo_id()), "crane_remaining": world.cranes.remaining(sender)}

func gameplay_state(context: Node3D) -> Dictionary:
	# Presentation needs the live board, active cargo and last receipt, not the
	# complete session journal. Keep network work bounded on long-running servers.
	var offers: Dictionary = {}
	var receipt: Dictionary = {}
	for row: Dictionary in context.offers._offers.values():
		if row.state in ["available", "accepted", "loaded"]: offers[row.id] = row
		elif row.state == "delivered" and (receipt.is_empty() or row.accepted_ms >= receipt.accepted_ms): receipt = row
	if not receipt.is_empty(): offers[receipt.id] = receipt
	var records: Dictionary = {}
	if context.loading.busy(): records[context.loading.operation] = context.ship.state.operations.record(context.loading.operation)
	return {"kind": context.ship_kind, "port": context.world_ports.find(context.port),
		"offers": offers.duplicate(true), "manifest": context.ship.state.manifest.lines(),
		"operations": {"records": records}, "loading": context.loading.operation,
		"loading_offer": context.loading.offer_id, "loading_notice": context.loading.notice,
		"credits": context.reward_minor, "spent": context.spent_minor, "banked": context.banked_minor,
		"fleet": context.fleet.duplicate(true), "bulk": context.bulk_active, "heavy": context.heavy_jobs.active.duplicate(true),
		"notice": context.offer_notice, "abandon": context.abandon_job_id, "abandon_deadline": maxi(0, context.abandon_deadline - Time.get_ticks_msec()),
		"sell": context.sell_kind, "sell_deadline": maxi(0, context.sell_deadline - Time.get_ticks_msec())}

@rpc("authority", "call_remote", "reliable", 0)
func gameplay_snapshot(epoch: String, data: Dictionary) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or entity.is_empty() or epoch != session.epoch: return
	var jobs_changed: bool = data.kind != view.ship_kind or view.world_ports.find(view.port) != data.port or view.offers._offers != data.offers
	if data.kind != view.ship_kind: replace_own_ship(data.kind)
	view.port = view.world_ports[data.port]
	view.loading.rule.body = view.ship
	view.loading.rule.port = view.port
	view.offers._offers = data.offers.duplicate(true)
	view.ship.state.manifest.replace(typed_lines(data.manifest))
	# A render-only operation service is never advanced or committed locally.
	view.ship.state.operations._records = data.operations.records.duplicate(true)
	view.loading.operation = data.loading
	view.loading.offer_id = data.loading_offer
	view.loading.notice = data.loading_notice
	view.reward_minor = data.credits
	view.spent_minor = data.spent
	view.banked_minor = data.banked
	view.fleet = data.fleet.duplicate(true)
	view.bulk_active = data.bulk
	view.heavy_jobs.active = data.heavy.duplicate(true)
	view.offer_notice = data.notice
	view.abandon_job_id = data.abandon
	view.abandon_deadline = Time.get_ticks_msec() + data.abandon_deadline
	view.sell_kind = data.sell
	view.sell_deadline = Time.get_ticks_msec() + data.sell_deadline
	if jobs_changed: view.refresh_jobs()

@rpc("authority", "call_remote", "reliable", 0)
func cosmetic_salute(id: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1: return
	var body: HandlingShip = view.ship if id == entity else (replicas[id].body if replicas.has(id) else null)
	if not is_instance_valid(body): return
	var cannons: Node = body.find_child("Cannons", true, false)
	if cannons != null: cannons.fire()
	if id == entity: view.game_hud.show_salute()

static func typed_lines(source: Array) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	lines.assign(source)
	return lines

func render_ship(kind: String) -> HandlingShip:
	var body: HandlingShip = load("res://features/ships/heavy_lifter_01/heavy_runtime.tscn" if Progression.heavy_tier(kind) > 0 else "res://features/ships/starter_container_01/starter_runtime.tscn").instantiate()
	body.definition = Progression.definition(kind)
	view.add_child(body)
	body.set_physics_process(false)
	body.collision_layer = 0
	body.collision_mask = 0
	if body.get("payload_body") != null:
		body.payload_body.hide()
		body.payload_visual.hide()
		body.payload_body.collision_layer = 0
	view.CHUNKY_LOOK.dress_ship(body, kind)
	view.TOON_LOOK.apply(body)
	return body

func replace_own_ship(kind: String) -> void:
	var previous: HandlingShip = view.ship
	view.ship = render_ship(kind)
	view.ship.transform = previous.transform
	view.ship_kind = kind
	view.heavy_mode = Progression.heavy_tier(kind) > 0
	view.helm.ship = view.ship
	view.helm.feedback = view.ship.assembly.feedback
	view.helm.notice.ship = view.ship
	view.helm.gauge_display.ship = view.ship
	view.helm.throttle_display.ship = view.ship
	view.wake.queue_free()
	view.wake = view.ship.assembly.create_wake(view.ocean)
	view.camera.set_focus(view.ship.assembly.focus)
	view.camera.distance_order = view.ship.definition.camera_distance_m
	previous.queue_free()
	throttle = 0.0

func present_world(target: float, _delta: float) -> void:
	if world_samples.is_empty(): return
	while world_samples.size() > 2 and world_samples[1].stamp <= target: world_samples.pop_front()
	var a: Dictionary = world_samples[0]
	var b: Dictionary = world_samples[mini(1, world_samples.size() - 1)]
	var weight: float = clampf((target - a.stamp) / maxf(0.000001, b.stamp - a.stamp), 0, 1)
	view.other_ships.clear()
	view.docking.members.clear()
	for id: String in b.ships:
		var state: Dictionary = b.ships[id]
		var before: Dictionary = a.ships.get(id, state)
		var body: HandlingShip = view.ship
		if id != entity:
			if replicas.has(id) and replicas[id].kind != state.kind:
				replicas[id].body.queue_free()
				replicas[id].wake.queue_free()
				replicas.erase(id)
			if not replicas.has(id):
				var fresh: HandlingShip = render_ship(state.kind)
				var nameplate: Label3D = Label3D.new()
				nameplate.text = state.captain
				nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				nameplate.position.y = fresh.definition.hull_size_m.y + 14
				nameplate.font_size = 48
				nameplate.pixel_size = 0.08
				nameplate.visibility_range_end = 1800
				fresh.add_child(nameplate)
				replicas[id] = {"body": fresh, "kind": state.kind, "wake": fresh.assembly.create_wake(view.ocean), "label": nameplate}
			body = replicas[id].body
			var next: Vector3 = before.position.lerp(Progression.nearest(state.position, before.position), weight)
			var near: Vector3 = Progression.nearest(next, view.ship.position)
			var shift: Vector3 = Progression.nearest(body.position, near) - body.position
			if shift.length() > 1: replicas[id].wake.shift(shift)
			body.position = near
			body.rotation.y = lerp_angle(before.yaw, state.yaw, weight)
			body.velocity = before.velocity.lerp(state.velocity, weight)
			body.ground_speed_mps = lerpf(before.speed, state.speed, weight)
			body.actual_throttle = state.engine
			body.commanded_throttle = state.throttle
			body.rudder = state.rudder
			body.lateral_order = state.lateral
			view.other_ships.append({"kind": state.kind, "position": body.position, "heading": body.rotation.y, "captain": state.captain})
		body.docked = state.docked
		body.yaw_rate = lerpf(before.yaw_rate, state.yaw_rate, weight)
		body.simulation_paused = state.paused
		body.pause_reason = state.pause_reason
		var visuals: Node3D = body.assembly.container_visuals
		if visuals.capacity > 0:
			visuals.hand_to_cranes()
			for slot: int in mini(visuals.capacity, state.filled.size()): visuals.set_slot(slot, state.filled[slot] != 0)
		if not state.heavy.is_empty() and body.get("payload_body") != null and body.payload_body.is_inside_tree():
			body.deck_height = lerpf(before.heavy.get("height", state.heavy.height), state.heavy.height, weight)
			body.deck_target = state.heavy.target
			var load_id: String = state.heavy.active.get("id", "")
			var key: String = load_id + str(state.heavy.attached)
			if body.get_meta("heavy_state", "") != key:
				if not load_id.is_empty(): body.use_job_load(preload("res://features/cargo/heavy_ocean_job.gd").load_for(load_id))
				body.restore_heavy_payload(state.heavy.attached, not load_id.is_empty(), state.heavy.pose.origin)
				body.set_meta("heavy_state", key)
			body.deck_visual.position.y = body.deck_height - body.RAISED
			body.cargo_mount.position.y = body.deck_height
			if not state.heavy.attached:
				var pose: Transform3D = before.heavy.get("pose", state.heavy.pose).interpolate_with(state.heavy.pose, weight)
				pose.origin = Progression.nearest(pose.origin, view.ship.position)
				body.payload_body.global_transform = pose
			body.payload_body.collision_layer = 0
			body.payload_collider.disabled = true
			body.payload_shape.disabled = true
		view.docking.members[state.owner] = {"body": body, "port": view.world_ports[state.port], "state": state.dock,
			"remaining": state.remaining, "berth_index": state.berth, "berth_id": view.world_ports[state.port].berth_id(maxi(0, state.berth))}
		if id == entity:
			view.dock_status = state.readiness
			view.network_crane_remaining = state.crane_remaining
			view.dock_button.text = "Undock" if state.dock == "docked" else "Dock"
			view.dock_button.disabled = state.dock in ["docking", "undocking"] or view.loading.busy() or state.crane_remaining > 0 or (state.dock != "docked" and not state.readiness.eligible)
	for id: String in replicas.keys():
		if not b.ships.has(id):
			replicas[id].body.queue_free()
			replicas[id].wake.queue_free()
			replicas.erase(id)
	apply_cranes(a.cranes, b.cranes, weight)

func pack_cranes() -> Array:
	var frames: Array = []
	for port_index: int in world.world_ports.size():
		var place: Node3D = world.world_ports[port_index]
		for berth: int in world.cranes.ports[place].size():
			for index: int in world.cranes.PER_BERTH:
				var crane: Dictionary = world.cranes.ports[place][berth][index]
				if crane.work < 0 and is_equal_approx(crane.z, crane.park_z) and crane.raised >= 1.0: continue
				frames.append({"port": port_index, "berth": berth, "index": index, "z": crane.z, "raised": crane.raised,
					"hook": crane.spreader.transform, "trolley": crane.trolley.position, "rope": crane.rope.transform,
					"carried": crane.carried.transform, "visible": crane.carried.visible, "size": crane.spreader_size,
					"box_size": crane.carried.mesh.get_aabb().size if crane.carried.mesh != null else Vector3.ONE})
	return frames

func apply_cranes(previous: Array, current: Array, weight: float) -> void:
	var old: Dictionary = {}
	for frame: Dictionary in previous: old[Vector3i(frame.port, frame.berth, frame.index)] = frame
	var live: Dictionary = {}
	for frame: Dictionary in current:
		var key: Vector3i = Vector3i(frame.port, frame.berth, frame.index)
		live[key] = true
		var before: Dictionary = old.get(key, frame)
		var place: Node3D = view.world_ports[frame.port]
		var crane: Dictionary = view.cranes.ports[place][frame.berth][frame.index]
		crane.z = lerpf(before.z, frame.z, weight)
		crane.raised = lerpf(before.raised, frame.raised, weight)
		crane.spreader_size = frame.size
		view.cranes.draw(place, crane)
		crane.spreader.transform = before.hook.interpolate_with(frame.hook, weight)
		crane.trolley.position = before.trolley.lerp(frame.trolley, weight)
		crane.rope.transform = before.rope.interpolate_with(frame.rope, weight)
		crane.carried.transform = before.carried.interpolate_with(frame.carried, weight)
		crane.carried.visible = frame.visible
		if crane.carried.get_meta("size", Vector3.ZERO) != frame.box_size:
			crane.carried.mesh = preload("res://features/cargo/container_visuals.gd").container_mesh(frame.box_size)
			view.TOON_LOOK.apply(crane.carried)
			crane.carried.set_meta("size", frame.box_size)
	for key: Vector3i in presented_cranes:
		if live.has(key): continue
		var place: Node3D = view.world_ports[key.x]
		var crane: Dictionary = view.cranes.ports[place][key.y][key.z]
		crane.z = crane.park_z
		crane.raised = 1.0
		view.cranes.draw(place, crane)
	presented_cranes = live

var presented_cranes: Dictionary = {}

func _ready() -> void:
	process_physics_priority = -20
	var args: PackedStringArray = OS.get_cmdline_user_args()
	hosting = OS.has_feature("dedicated_server") or OS.has_feature("server") or args.has("--server")
	updating = args.has("--updating")
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
		elif arg.begins_with("--captain="): captain_name = arg.trim_prefix("--captain=")
		elif arg.begins_with("--saves-dir="): saves_path = arg.trim_prefix("--saves-dir=")
		elif arg.begins_with("--control-dir="): launcher.folder = arg.trim_prefix("--control-dir=")
	if not hosting and get_tree().has_meta(Connection.TARGET):
		var target: Dictionary = get_tree().get_meta(Connection.TARGET)
		get_tree().remove_meta(Connection.TARGET)
		host = target.host
		port_number = target.port
	if hosting and DisplayServer.get_name() != "headless":
		fail("Server requires --headless", 2)
		return
	if hosting:
		if saves_path.is_empty():
			saves_path = "user://dedicated/saves" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("saves")
		if not saves.open_store(saves_path):
			fail(saves.error, 2)
			return
		get_tree().auto_accept_quit = false
		world = GAME.instantiate()
		world.runtime_role = "world"
		world.name = "World"
		add_child(world)
		disable_tree(world)
		world.cranes.loading_preview = server_preview
		wrap = preload("res://features/network/dedicated_wrap.gd").new()
		add_child(wrap)
		wrap.setup(world)
		# These UI objects normally join the local HUD after world construction.
		world.voyage_hud.free()
		world.minimap.free()
		session.hosting = true
		session.epoch = Crypto.new().generate_random_bytes(16).hex_encode()
	else:
		if not load_install_key():
			fail("Cannot read or preserve this installation's captain identity", 2)
			return
		view = GAME.instantiate()
		view.runtime_role = "client"
		view.network_runtime = self
		view.name = "View"
		add_child(view)
		view.set_physics_process(false)
		view.docking.set_physics_process(false)
		view.docking.presentation_only = true
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
		view.helm.notice.presentation_only = true
		view.helm.notice.hints = view.helm_hints()
		# Item 2 adds authoritative service UI. No local click may mutate cargo,
		# wallet, fleet, docking or recovery in this render-only runtime.
		view.mooring.set_process(true)
		var layer: CanvasLayer = CanvasLayer.new()
		add_child(layer)
		notice = Label.new()
		notice.position = Vector2(24, 24)
		layer.add_child(notice)
		var card_layer: CanvasLayer = CanvasLayer.new()
		card_layer.layer = 120
		add_child(card_layer)
		connection_card = Connection.new()
		connection_card.lookup_on_ready = false
		card_layer.add_child(connection_card)
		connection_card.heading.text = "Connecting…"
		connection_card.details.text = "Joining the Shipping Lanes server."
		connection_card.retry.hide()
		view.controls.set_menu_open(true)
		view.hide()
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
		fail("Cannot open UDP transport (%s)" % error_string(error), 2 if hosting else 0)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(id: int):
		if hosting: pending_peers[id] = Time.get_ticks_msec() + 10000)
	multiplayer.peer_disconnected.connect(depart)
	multiplayer.connected_to_server.connect(func(): hello.rpc_id(1, PROTOCOL, captain_name, Connection.VERSION, install_key))
	multiplayer.connection_failed.connect(func(): fail("Connection failed"))
	multiplayer.server_disconnected.connect(func(): fail("Server disconnected"))
	if hosting: print("DEDICATED_SERVER_READY port=%d" % port_number)

func client_command(action: StringName) -> void:
	if action == &"pause": view.game_menu.open()
	if action == &"horn": view.helm.feedback.sound_horn(view.controls.input_allowed())
	if action == &"cannon_salute" and view.controls.input_allowed(): send_gameplay("salute")
	if action == &"cannon_salute": send_gameplay("salute")

static func disable_tree(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	if node is CanvasLayer: node.hide()
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	for child: Node in node.get_children(): disable_tree(child)

func fail(message: String, exit_code: int = 0, reason: String = "offline") -> void:
	if connection_failed: return
	connection_failed = true
	status = message
	entity = ""
	samples.clear()
	world_samples.clear()
	throttle = 0.0
	join_deadline = 0
	last_snapshot_ms = 0
	if peer != null: peer.close()
	if is_instance_valid(view):
		view.controls.set_menu_open(true)
		view.set_process_unhandled_input(false)
		view.controls.set_process_unhandled_input(false)
		view.game_menu.set_process_unhandled_input(false)
		view.game_menu.hide()
		view.other_ships.clear()
		view.docking.members.clear()
		view.port_panel.hide()
		view.game_hud.hide()
		for replica: Dictionary in replicas.values():
			replica.body.hide()
		view.ship.velocity = Vector3.ZERO
		view.ship.ground_speed_mps = 0.0
	if is_instance_valid(connection_card): connection_card.show_error(reason)
	if hosting or exit_code != 0:
		push_error(message)
		get_tree().quit(maxi(1, exit_code))

@rpc("any_peer", "call_remote", "reliable", 0)
func hello(version: int, captain: String, release: String = "", key: String = "") -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not pending_peers.has(sender): return
	if version != PROTOCOL or release != Connection.VERSION:
		join_rejected.rpc_id(sender, "mismatch")
		return
	if updating:
		join_rejected.rpc_id(sender, "updating")
		return
	pending_peers.erase(sender)
	if not SaveStore.key_valid(key) or contexts.size() + joining_keys.size() >= MAX_PLAYERS or captain.strip_edges().is_empty() or captain.length() > 24 or captain != captain.validate_node_name() or "\n" in captain or "\r" in captain:
		peer.disconnect_peer(sender)
		return
	var player_key: String = key.sha256_text()
	if player_keys.values().has(player_key) or joining_keys.has(player_key):
		peer.disconnect_peer(sender)
		return
	joining_keys[player_key] = sender
	var context: Node3D = GAME.instantiate()
	context.runtime_role = "server"
	context.owner_id = sender
	context.shared_world = world
	context.docking.claims = world.docking.claims
	context.name = "Player%d" % sender
	add_child(context)
	if not is_instance_valid(context.ship):
		context.queue_free()
		joining_keys.erase(player_key)
		peer.disconnect_peer(sender)
		return
	disable_tree(context)
	context.cranes = world.cranes
	if saves.players.has(player_key):
		context.port.spawn_allocator.release(context.spawn_ticket)
		context.ship.collision_layer = 0
		if not await SaveSnapshot.restore(context, saves.players[player_key].voyage.duplicate(true)):
			context.docking.disconnect_owner(sender)
			context.port.spawn_allocator.release(context.spawn_ticket)
			context.queue_free()
			joining_keys.erase(player_key)
			peer.disconnect_peer(sender)
			return
		# select_port creates a replacement hull; never run it during recovery.
		disable_tree(context)
	joining_keys.erase(player_key)
	if not multiplayer.get_peers().has(sender):
		context.docking.disconnect_owner(sender)
		context.port.spawn_allocator.release(context.spawn_ticket)
		context.queue_free()
		return
	player_keys[sender] = player_key
	context.set_physics_process(true)
	context.ship.set_physics_process(true)
	context.docking.set_physics_process(true)
	context.loading.set_process(true)
	context.loading.set_physics_process(true)
	var id: String = "ship_%d" % sender
	contexts[sender] = context
	# Children exit in reverse order. Capture before loading/docking teardown
	# releases unfinished operations and berths during SceneTree.quit().
	var guard: Node = Node.new()
	guard.name = "SaveBeforeTeardown"
	context.add_child(guard)
	guard.tree_exiting.connect(func() -> void:
		if contexts.has(sender):
			capture_player(sender)
			teardown_players[sender] = true)
	captains[sender] = captain.strip_edges()
	context.cranes = world.cranes
	context.docking.undock_seconds = 1.0
	ships[id] = context.ship
	wrap.add_hull(id, context.ship)
	session.roster[id] = {"peer_id": sender}
	welcome.rpc_id(sender, PROTOCOL, session.epoch, id)
	print("DEDICATED_JOIN players=%d" % contexts.size())

@rpc("authority", "call_remote", "reliable", 0)
func join_rejected(reason: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1: return
	fail("Join refused", 0, reason if reason in ["mismatch", "updating"] else "offline")

func depart(sender: int) -> void:
	if not hosting: return
	pending_peers.erase(sender)
	if not contexts.has(sender): return
	var context: Node3D = contexts[sender]
	capture_player(sender)
	if not saves.checkpoint(): save_error()
	player_keys.erase(sender)
	context.docking.disconnect_owner(sender)
	context.port.spawn_allocator.release(context.spawn_ticket)
	var id: String = "ship_%d" % sender
	contexts.erase(sender)
	captains.erase(sender)
	last_gameplay_at.erase(sender)
	last_salute.erase(sender)
	last_gameplay.erase(sender)
	world.docking.members.erase(sender)
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
	view.owner_id = multiplayer.get_unique_id()
	view.docking.members.clear()
	status = "Connected · " + captain_name

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
		if not saves.finish(false):
			save_error()
			return
		save_elapsed += delta
		if save_elapsed >= 60.0:
			save_elapsed = fmod(save_elapsed, 60.0)
			checkpoint_players()
		world.docking.members.clear()
		for sender: int in contexts:
			var context: Node3D = contexts[sender]
			world.docking.members[sender] = context.docking.members[sender]
			var id: String = "ship_%d" % sender
			if ships[id] != context.ship:
				wrap.remove_hull(id)
				ships[id] = context.ship
				wrap.add_hull(id, context.ship)
		world.cranes.advance(delta)
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
		if not view.ship.helm_available(): throttle = 0.0
		var allowed: bool = view.controls.input_allowed() and view.ship.helm_available()
		var axis: float = view.controls.action_strength("ship_throttle_up") - view.controls.action_strength("ship_throttle_down") if allowed else 0.0
		throttle = HandlingShip.adjusted_order(throttle, axis, delta, view.ship.definition)
		if allowed and view.controls.action_strength("ship_throttle_zero") > 0: throttle = 0.0
	send_elapsed += delta
	if send_elapsed < INTERVAL: return
	send_elapsed = fmod(send_elapsed, INTERVAL)
	if hosting:
		tick += 1
		var fleet_frame: Dictionary = {}
		for sender: int in contexts: fleet_frame["ship_%d" % sender] = ship_frame(sender)
		var crane_frame: Array = pack_cranes()
		for sender: int in contexts:
			var ship: HandlingShip = contexts[sender].ship
			var own: Dictionary = {
				"position": ship.global_position, "yaw": ship.rotation.y,
				"velocity": ship.velocity, "ground_speed": ship.ground_speed_mps,
				"throttle": ship.commanded_throttle, "engine": ship.actual_throttle,
				"rudder": ship.rudder, "lateral": ship.lateral_order,
				"fuel": ship.state.fuel_liters, "condition": ship.state.condition}
			var raw: PackedByteArray = var_to_bytes({"own": own, "ships": fleet_frame, "cranes": crane_frame})
			var packed: PackedByteArray = PackedByteArray()
			packed.resize(4)
			packed.encode_u32(0, raw.size())
			packed.append_array(raw.compress(FileAccess.COMPRESSION_FASTLZ))
			var count: int = ceili(packed.size() / 900.0)
			for index: int in count:
				snapshot_chunk.rpc_id(sender, session.epoch, tick, elapsed, index, count, packed.slice(index * 900, mini(packed.size(), (index + 1) * 900)))
			if tick % 4 == 0:
				var data: Dictionary = gameplay_state(contexts[sender])
				if tick % 20 == 0 or last_gameplay.get(sender, {}) != data:
					last_gameplay[sender] = data.duplicate(true)
					gameplay_snapshot.rpc_id(sender, session.epoch, data)
	elif not entity.is_empty():
		var allowed: bool = view.controls.input_allowed()
		send_helm(throttle, view.controls.steering_axis() if allowed else 0.0,
			view.controls.action_strength("ship_thruster_right") - view.controls.action_strength("ship_thruster_left") if allowed else 0.0)

func send_helm(command: float, rudder: float, lateral: float) -> void:
	sequence += 1
	helm_input.rpc_id(1, ShipActions.make_request(session.epoch, multiplayer.get_unique_id(), entity, "helm", sequence,
		{"throttle": command, "rudder": rudder, "lateral": lateral, "sent_ms": Time.get_ticks_msec()}))

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func snapshot_chunk(epoch: String, frame: int, stamp: float, index: int, count: int, chunk: PackedByteArray) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or entity.is_empty() or epoch != session.epoch or frame <= last_tick or frame < incoming_frame: return
	if count < 1 or count > 64 or index < 0 or index >= count or chunk.size() > 900: return
	if frame > incoming_frame:
		incoming_frame = frame
		incoming_chunks.clear()
		incoming_total = count
	if count != incoming_total: return
	incoming_chunks[index] = chunk
	if incoming_chunks.size() != count: return
	var packed: PackedByteArray = PackedByteArray()
	for part: int in count: packed.append_array(incoming_chunks[part])
	incoming_chunks.clear()
	if packed.size() < 5: return
	var length: int = packed.decode_u32(0)
	if length < 1 or length > 65536: return
	var decoded: Variant = bytes_to_var(packed.slice(4).decompress(length, FileAccess.COMPRESSION_FASTLZ))
	if not decoded is Dictionary or decoded.size() != 3: return
	snapshot(epoch, frame, stamp, decoded.own, decoded.ships, decoded.cranes)

func snapshot(epoch: String, frame: int, stamp: float, state: Dictionary, fleet_frame: Dictionary, crane_frame: Array) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or entity.is_empty() or epoch != session.epoch or frame <= last_tick: return
	if not is_finite(stamp) or stamp < 0 or state.size() != 10: return
	for key: String in ["position", "velocity"]:
		if not state.get(key) is Vector3 or not state[key].is_finite(): return
	for key: String in ["yaw", "ground_speed", "throttle", "engine", "rudder", "lateral", "fuel", "condition"]:
		if not state.get(key) is float or not is_finite(state[key]): return
	last_tick = frame
	last_snapshot_ms = Time.get_ticks_msec()
	join_deadline = 0
	if received_states == 0 and is_instance_valid(connection_card):
		connection_card.hide()
		view.show()
		view.controls.set_menu_open(false)
	received_states += 1
	last_state = state
	clock_offset = minf(clock_offset, Time.get_ticks_msec() / 1000.0 - stamp)
	samples.append({"stamp": stamp, "state": state})
	while samples.size() > 16: samples.pop_front()
	world_samples.append({"stamp": stamp, "ships": fleet_frame, "cranes": crane_frame})
	while world_samples.size() > 16: world_samples.pop_front()
	if received_states == 1:
		view.ship.position = state.position
		view.ship.rotation.y = state.yaw
		view.camera.set_focus(view.ship.assembly.focus)

func _process(_delta: float) -> void:
	if hosting:
		launcher.poll(self, _delta)
		return
	if join_deadline > 0 and Time.get_ticks_msec() > join_deadline: fail("Connection timed out")
	if last_snapshot_ms > 0 and Time.get_ticks_msec() - last_snapshot_ms > 10000: fail("Server stopped responding")
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
	present_world(target, _delta)

func load_install_key() -> bool:
	var path: String = "user://dedicated_install.key"
	if FileAccess.file_exists(path):
		install_key = FileAccess.get_file_as_string(path).strip_edges()
		return SaveStore.key_valid(install_key)
	install_key = Crypto.new().generate_random_bytes(32).hex_encode()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(install_key)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok

func capture_player(sender: int) -> void:
	if teardown_players.has(sender): return
	var context: Node3D = contexts[sender]
	# The existing heavy-job authority reconciles its final reward in the same
	# tick as cargo completion. Checkpoint money and receipt together.
	if context.heavy_mode:
		context.heavy_jobs.update(context.ship)
		context.reward_minor += context.heavy_jobs.reward_pending
		context.heavy_jobs.reward_pending = 0
	saves.players[player_keys[sender]] = {"captain": captains[sender], "voyage": SaveSnapshot.capture(context)}

func checkpoint_players() -> void:
	for sender: int in contexts: capture_player(sender)
	if not saves.checkpoint(): save_error()

func save_error() -> void:
	if save_failed: return
	save_failed = true
	# Stop this server on durability failure. Never pause a world or let players
	# continue earning against an unwriteable checkpoint.
	fail("Server saving failed: " + saves.error, 2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and hosting:
		shutdown_saves()
		get_tree().quit(1 if save_failed else 0)

func shutdown_saves() -> void:
	if not hosting or not saves.locked: return
	if not saves.finish(): save_error()
	if not save_failed:
		checkpoint_players()
		if not saves.finish(): save_error()
	saves.close()

func _exit_tree() -> void:
	shutdown_saves()
	if peer != null: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session.free()
