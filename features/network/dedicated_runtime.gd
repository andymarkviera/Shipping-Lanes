extends Node3D
## Patch 3.0 authoritative multiplayer with dedicated, migrating saves.
## Patch 3.0.1: own-hull prediction, adaptive interpolation, ping, compact frames.
const Connection = preload("res://features/network/play_connection.gd")
const GAME = preload("res://features/game/game.tscn")
const Progression = preload("res://features/game/progression.gd")
const CaptainName = preload("res://features/network/captain_name.gd")
const Codec = preload("res://features/network/public_snapshot_codec.gd")
const Relevance = preload("res://features/network/ship_relevance.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const DayNight = preload("res://features/sky/day_night.gd")
# 3.1.0 adds the world clock to welcome/pong (3.1.1: same wire, 18-minute cycle). 3.0.1 frames are wire-incompatible with 3.0.0 (binary motion + reliable status).
const PROTOCOL: int = 40000
const Planes = preload("res://features/planes/plane_catalog.gd")
const Levels = preload("res://features/game/levels.gd")
const PlaneLook = preload("res://features/planes/plane_look.gd")
const PlaneEngineSound = preload("res://features/planes/plane_engine_sound.gd")
## Patch 4.0: other captains' planes, drawn from their motion's air block.
var air_replicas: Dictionary = {}
## Patch 4.0 item 15: boat actions are refused while a captain flies, plane
## actions while they sail; the plane's own rules (Aviation) do the rest.
const BOAT_ACTIONS: Array[String] = ["dock", "cancel_dock", "accept", "cancel_load", "abandon", "deliver", "refuel", "repair", "recover", "ship", "sell", "lower", "raise", "salute", "boost"]
const PLANE_ACTIONS: Array[String] = ["plane_switch", "boat_switch", "plane_buy", "plane_select", "plane_refuel", "plane_repair", "plane_accept", "plane_deliver"]
const MAX_PLAYERS: int = 8
const INTERVAL: float = 0.05
const BUFFER_SECONDS: float = 0.15
const BUFFER_MIN: float = 0.08
const BUFFER_MAX: float = 0.25
const EXTRAPOLATE_SECONDS: float = 0.25
const TIMEOUT_MS: int = 500
## Own-hull reconciliation: errors fade over CORRECTION_SECONDS, but anything
## past SNAP_* (a collision, a teleport, a berth) is applied at once.
const SNAP_ERROR_M: float = 20.0
const SNAP_YAW: float = 0.6
const CORRECTION_SECONDS: float = 0.15
const HISTORY: int = 128
const TRACK_SAMPLES: int = 8
const STATUS_EVERY: int = 2
const CRANE_RANGE_M: float = 2500.0
const PING_SECONDS: float = 1.0
const EMPTY: Dictionary = {}
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
# Patch 3.0.1 server state.
var status_sent: Dictionary = {}
var last_ping: Dictionary = {}
var last_rename: Dictionary = {}
var server_send_us: float = 0.0
var sent_bytes: int = 0
var report_elapsed: float = 0.0
# Patch 3.0.1 client state: reliable ship status, per-ship motion tracks.
var statuses: Dictionary = {}
var tracks: Dictionary = {}
var peer_names: Dictionary = {}
var members: Dictionary = {}
var epoch_tag: int = 0
var buffer_seconds: float = BUFFER_SECONDS
var snapshot_interval: float = INTERVAL
var snapshot_jitter: float = 0.0
var last_arrival: float = -1.0
var client_snapshot_us: float = 0.0
var ghost: HandlingShip
var hist_seq: PackedInt32Array = PackedInt32Array()
var hist_values: PackedFloat32Array = PackedFloat32Array()
var history_head: int = 0
var history_count: int = 0
var ghost_previous: Transform3D = Transform3D.IDENTITY
var offset_position: Vector3 = Vector3.ZERO
var offset_yaw: float = 0.0
var predicted_frames: int = 0
var corrections: int = 0
var snaps: int = 0
var steering: float = 0.0
var thruster: float = 0.0
var ping_elapsed: float = 0.0
var rtt_ms: float = -1.0
var ping_label: Label
var name_layer: CanvasLayer
# Patch 3.1.1 item 2 server state: admin player keys and kept-aside real saves.
var config_path: String = ""
var admin_keys: Array[String] = []
var debug_real: Dictionary = {}
## Patch 4.0.5 item 2: the server's client error log, and the client's pace.
var error_log = preload("res://features/network/client_error_log.gd").new()
var error_send_elapsed: float = 0.0
## Reports this client has handed to the server (for checks).
var errors_sent: int = 0
const ERROR_SEND_SECONDS: float = 3.0

func gameplay_payload_error(payload: Dictionary) -> String:
	if payload.size() != 2 or not payload.get("action") is String or not payload.get("value") is String: return "BAD_PAYLOAD"
	if payload.value.length() > 128: return "BAD_PAYLOAD"
	if payload.action not in BOAT_ACTIONS and payload.action not in PLANE_ACTIONS: return "UNKNOWN_ACTION"
	if payload.action in ["ship", "sell"]:
		if not Progression.SHIPS.has(payload.value): return "BAD_PAYLOAD"
	elif payload.action in ["plane_buy", "plane_select"]:
		if not Planes.PLANES.has(payload.value): return "BAD_PAYLOAD"
	elif payload.action in ["accept", "plane_accept"]:
		if payload.value.is_empty(): return "BAD_PAYLOAD"
	elif not payload.value.is_empty(): return "BAD_PAYLOAD"
	return ""

func execute_gameplay(sender: int, payload: Dictionary) -> String:
	if not contexts.has(sender): return "NOT_OWNER"
	var now: int = Time.get_ticks_msec()
	if now - int(last_gameplay_at.get(sender, -1000)) < 100: return "RATE_LIMITED"
	last_gameplay_at[sender] = now
	var context: Node3D = contexts[sender]
	var air: Node = context.aviation
	if air.flying() and payload.action in BOAT_ACTIONS and payload.action != "salute": return "OUT_OF_RANGE"
	if payload.action in PLANE_ACTIONS:
		var done: bool = false
		match payload.action:
			"plane_switch": done = air.switch_to_plane()
			"boat_switch": done = air.switch_to_boat()
			"plane_buy": done = air.buy(payload.value)
			"plane_select": done = air.select(payload.value)
			"plane_refuel": done = air.refuel()
			"plane_repair": done = air.repair()
			"plane_accept": done = air.accept(payload.value)
			"plane_deliver": done = air.deliver()
		adopt_hull(sender)
		return "OK" if done else "OUT_OF_RANGE"
	match payload.action:
		"boost":
			# Patch 4.0.2: the server's hull is the one whose speed the boost changes.
			if not context.ship.request_boost(): return "OUT_OF_RANGE"
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
			adopt_hull(sender)
		"sell":
			if context.docking.state(sender) != "docked": return "OUT_OF_RANGE"
			context.sell_ship(payload.value)
		"lower", "raise":
			if not context.heavy_mode: return "OUT_OF_RANGE"
			if not context.ship.request_height(-1.0 if payload.action == "lower" else 2.6): return "OUT_OF_RANGE"
	return "OK"

## A captain's simulation made a new hull (a ship swap, or back from a plane):
## it joins the shared world in place of the old one.
func adopt_hull(sender: int) -> void:
	var context: Node3D = contexts[sender]
	var id: String = "ship_%d" % sender
	if ships.get(id) == context.ship: return
	disable_tree(context.ship)
	context.ship.set_physics_process(not context.flying())
	replication.orders.erase(id)
	wrap.remove_hull(id)
	ships[id] = context.ship
	wrap.add_hull(id, context.ship)

## Patch 4.0: whether a captain is flying (helm limits and motion differ).
func entity_flying(sender: int) -> bool:
	return contexts.has(sender) and contexts[sender].flying()

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
	# Gameplay state is sent on change only; any action forces a fresh copy.
	last_gameplay.erase(sender)
	gameplay_result.rpc_id(sender, response)


@rpc("authority", "call_remote", "reliable", 0)
func gameplay_result(response: Dictionary) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or response.get("epoch") != session.epoch: return
	action_result = response
	actions.result_received.emit(response)
	if not response.get("ok", false): status = "Action refused: " + str(response.get("code"))

func server_preview(owner: int) -> Vector2i:
	return contexts[owner].crane_preview(owner) if contexts.has(owner) else Vector2i.ZERO

## Slow-changing ship facts, sent reliably and only when they change.
func status_row(sender: int) -> Dictionary:
	var context: Node3D = contexts[sender]
	var body: HandlingShip = context.ship
	var entry: Dictionary = context.docking.members[sender]
	var heavy: Dictionary = {}
	if context.heavy_mode: heavy = {"target": body.deck_target, "attached": body.attached, "active": context.heavy_jobs.active}
	return {"owner": sender, "captain": captains[sender], "kind": context.ship_kind,
		"port": context.world_ports.find(context.port), "dock": entry.state, "berth": entry.berth_index,
		"docked": body.docked, "filled": body.assembly.container_visuals.filled,
		"paused": body.simulation_paused, "pause_reason": body.pause_reason, "heavy": heavy,
		"job": context.bulk_active if context.bulk_mode() else context.offers.active_job("preview_captain").get("id", ""),
		"credits": context.reward_minor, "plane": context.aviation.plane_kind if context.flying() else "",
		"boost": body.boost.uses()}

## Per-tick motion for one hull; quantized by the codec, shared by recipients.
func motion_row(sender: int) -> Dictionary:
	var context: Node3D = contexts[sender]
	if context.flying(): return air_motion(sender, false)
	var body: HandlingShip = context.ship
	var row: Dictionary = {"peer": sender, "position": body.position, "yaw": body.rotation.y, "velocity": body.velocity,
		"speed": body.ground_speed_mps, "yaw_rate": body.yaw_rate, "engine": body.actual_throttle,
		"throttle": body.commanded_throttle, "rudder": body.rudder, "lateral": body.lateral_order,
		"remaining": float(context.docking.members[sender].remaining)}
	if context.heavy_mode:
		row.heavy = {"height": body.deck_height, "pose": body.payload_body.global_transform if body.payload_body.is_inside_tree() else Transform3D.IDENTITY}
	return row

## Patch 4.0 item 15: a plane's motion. The air block carries the altitude
## (full precision), the whole attitude and the climb rate.
func air_motion(sender: int, own: bool) -> Dictionary:
	var air: Node = contexts[sender].aviation
	var m: RefCounted = air.model
	var block: Dictionary = {"altitude": m.position.y, "basis": m.basis, "vy": m.velocity.y, "ground": m.on_ground, "gear": m.gear_down, "stall": m.stalled}
	if own:
		return {"ack": int(replication.orders.get("ship_%d" % sender, EMPTY).get("seq", 0)),
			"position": m.position, "yaw": m.heading(), "velocity": m.velocity, "ground_speed": m.airspeed(), "yaw_rate": 0.0,
			"throttle": float(air.order.throttle), "engine": m.engine, "rudder": float(air.order.roll), "lateral": float(air.order.yaw),
			"fuel": m.fuel_l, "condition": air.condition(), "air": block}
	return {"peer": sender, "position": m.position, "yaw": m.heading(), "velocity": m.velocity, "speed": m.airspeed(), "yaw_rate": 0.0,
		"engine": m.engine, "throttle": clampf(float(air.order.throttle), -1.0, 1.0), "rudder": float(air.order.roll), "lateral": float(air.order.yaw), "remaining": 0.0, "air": block}

func own_motion(sender: int) -> Dictionary:
	if contexts[sender].flying(): return air_motion(sender, true)
	var ship: HandlingShip = contexts[sender].ship
	return {"ack": int(replication.orders.get("ship_%d" % sender, EMPTY).get("seq", 0)),
		"position": ship.global_position, "yaw": ship.rotation.y, "velocity": ship.velocity,
		"ground_speed": ship.ground_speed_mps, "yaw_rate": ship.yaw_rate,
		"throttle": ship.commanded_throttle, "engine": ship.actual_throttle,
		"rudder": ship.rudder, "lateral": ship.lateral_order,
		"fuel": ship.state.fuel_liters, "condition": ship.state.condition}

## Patch 4.0.4 item 1: no deep copies in here; send_frames keeps the one
## deep copy it compares against, and the RPC serialises at once.
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
		"offers": offers, "manifest": context.ship.state.manifest.lines(),
		"operations": {"records": records}, "loading": context.loading.operation,
		"loading_offer": context.loading.offer_id, "loading_notice": context.loading.notice,
		"credits": context.reward_minor, "spent": context.spent_minor, "banked": context.banked_minor,
		"fleet": context.fleet, "bulk": context.bulk_active, "heavy": context.heavy_jobs.active,
		"notice": context.offer_notice, "abandon": context.abandon_job_id, "abandon_deadline": maxi(0, context.abandon_deadline - Time.get_ticks_msec()),
		"sell": context.sell_kind, "sell_deadline": maxi(0, context.sell_deadline - Time.get_ticks_msec()),
		"air": context.aviation.state()}

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
	# Patch 4.0: XP, planes and plane mode are the server's word.
	if data.get("air") is Dictionary: view.aviation.apply_state(data.air)
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
	make_ghost()

func make_replica(id: String, state: Dictionary) -> void:
	var fresh: HandlingShip = render_ship(state.kind)
	var nameplate: Label3D = Label3D.new()
	nameplate.text = state.captain
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.position.y = fresh.definition.hull_size_m.y + 14
	nameplate.font_size = 48
	nameplate.pixel_size = 0.08
	nameplate.visibility_range_end = 1800
	fresh.add_child(nameplate)
	replicas[id] = {"body": fresh, "kind": state.kind, "wake": fresh.assembly.create_wake(view.ocean), "label": nameplate,
		"entry": {"kind": state.kind, "position": Vector3.ZERO, "heading": 0.0, "captain": state.captain}}

func drop_replica(id: String) -> void:
	replicas[id].body.queue_free()
	replicas[id].wake.queue_free()
	replicas.erase(id)

## Patch 3.0.1 item 2b: each hull interpolates inside its own track at the
## adaptive buffer delay, and extrapolates briefly when its next sample is late
## (far ships arrive at a quarter rate). Reuses cached dictionaries per frame.
func present_world(target: float, _delta: float) -> void:
	view.other_ships.clear()
	view.docking.members.clear()
	for id: String in statuses:
		var track: Array = tracks.get(id, [])
		if track.is_empty(): continue
		var state: Dictionary = statuses[id]
		while track.size() > 2 and track[1].stamp <= target: track.pop_front()
		var a: Dictionary = track[0]
		var b: Dictionary = track[mini(1, track.size() - 1)]
		var weight: float = clampf((target - a.stamp) / maxf(0.000001, b.stamp - a.stamp), 0, 1)
		var ahead: float = clampf(target - b.stamp, 0.0, EXTRAPOLATE_SECONDS)
		var body: HandlingShip = view.ship
		var own: bool = id == entity
		if not own and str(state.get("plane", "")) != "" and Planes.PLANES.has(str(state.plane)) and b.has("air"):
			present_plane(id, state, a, b, weight, ahead, _delta)
			continue
		if air_replicas.has(id): drop_air_replica(id)
		if own and view.flying(): continue
		if not own:
			if replicas.has(id) and replicas[id].kind != state.kind: drop_replica(id)
			if not replicas.has(id): make_replica(id, state)
			var replica: Dictionary = replicas[id]
			body = replica.body
			var next: Vector3 = a.position.lerp(Progression.nearest(b.position, a.position), weight) + b.velocity * ahead
			var near: Vector3 = Progression.nearest(next, view.ship.position)
			var shift: Vector3 = Progression.nearest(body.position, near) - body.position
			if shift.length() > 1: replica.wake.shift(shift)
			body.position = near
			body.rotation.y = lerp_angle(a.yaw, b.yaw, weight) + b.yaw_rate * ahead
			body.velocity = a.velocity.lerp(b.velocity, weight)
			body.ground_speed_mps = lerpf(a.speed, b.speed, weight)
			body.actual_throttle = b.engine
			body.commanded_throttle = b.throttle
			body.rudder = b.rudder
			body.lateral_order = b.lateral
			body.yaw_rate = lerpf(a.yaw_rate, b.yaw_rate, weight)
			# Patch 4.0.4 item 4: another captain's blaster. A rise in their
			# boost count starts this replica's charge; JettyFx runs its clock
			# (the replica has no physics), so the orb, flame and sound play.
			var fired: int = int(state.get("boost", 0))
			if fired > int(replica.get("boost_seen", fired)) and body.boost.phase == "ready": body.boost.trigger()
			replica.boost_seen = fired
			var entry: Dictionary = replica.entry
			entry.position = body.position
			entry.heading = body.rotation.y
			entry.captain = state.captain
			view.other_ships.append(entry)
		elif not predicting(): body.yaw_rate = lerpf(a.yaw_rate, b.yaw_rate, weight)
		body.docked = state.docked
		body.simulation_paused = state.paused
		body.pause_reason = state.pause_reason
		var visuals: Node3D = body.assembly.container_visuals
		if visuals.capacity > 0:
			visuals.hand_to_cranes()
			for slot: int in mini(visuals.capacity, state.filled.size()): visuals.set_slot(slot, state.filled[slot] != 0)
		if not state.heavy.is_empty() and b.has("heavy") and body.get("payload_body") != null and body.payload_body.is_inside_tree():
			body.deck_height = lerpf(a.get("heavy", b.heavy).height, b.heavy.height, weight)
			body.deck_target = state.heavy.target
			var load_id: String = state.heavy.active.get("id", "")
			var key: String = load_id + str(state.heavy.attached)
			if body.get_meta("heavy_state", "") != key:
				if not load_id.is_empty(): body.use_job_load(preload("res://features/cargo/heavy_ocean_job.gd").load_for(load_id))
				body.restore_heavy_payload(state.heavy.attached, not load_id.is_empty(), b.heavy.pose.origin)
				body.set_meta("heavy_state", key)
			body.deck_visual.position.y = body.deck_height - body.RAISED
			body.cargo_mount.position.y = body.deck_height
			if not state.heavy.attached:
				var pose: Transform3D = a.get("heavy", b.heavy).pose.interpolate_with(b.heavy.pose, weight)
				pose.origin = Progression.nearest(pose.origin, view.ship.position)
				body.payload_body.global_transform = pose
			body.payload_body.collision_layer = 0
			body.payload_collider.disabled = true
			body.payload_shape.disabled = true
		var place: Node3D = view.world_ports[state.port]
		if not members.has(id): members[id] = {"berth_index": -2}
		var member: Dictionary = members[id]
		if member.berth_index != state.berth or member.get("port") != place:
			member.berth_id = place.berth_id(maxi(0, state.berth))
		member.body = body
		member.port = place
		member.state = state.dock
		member.remaining = lerpf(a.remaining, b.remaining, weight)
		member.berth_index = state.berth
		view.docking.members[state.owner] = member
		if own:
			view.dock_status = state.get("readiness", view.dock_status)
			view.network_crane_remaining = state.get("crane_remaining", 0.0)
			view.dock_button.text = "Undock" if state.dock == "docked" else "Dock"
			view.dock_button.disabled = state.dock in ["docking", "undocking"] or view.loading.busy() or view.network_crane_remaining > 0 or (state.dock != "docked" and not view.dock_status.get("eligible", false))
	if world_samples.is_empty(): return
	while world_samples.size() > 2 and world_samples[1].stamp <= target: world_samples.pop_front()
	var first: Dictionary = world_samples[0]
	var second: Dictionary = world_samples[mini(1, world_samples.size() - 1)]
	if first.cranes.is_empty() and second.cranes.is_empty() and presented_cranes.is_empty(): return
	apply_cranes(first.cranes, second.cranes, clampf((target - first.stamp) / maxf(0.000001, second.stamp - first.stamp), 0, 1))

## Patch 4.0: another captain's plane between its last two motion samples.
func present_plane(id: String, state: Dictionary, a: Dictionary, b: Dictionary, weight: float, ahead: float, delta: float) -> void:
	if replicas.has(id): drop_replica(id)
	var kind: String = str(state.plane)
	if air_replicas.has(id) and air_replicas[id].kind != kind: drop_air_replica(id)
	if not air_replicas.has(id):
		var node: Node3D = PlaneLook.model(kind)
		var plate: Label3D = Label3D.new()
		plate.text = state.captain
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.position.y = float(Planes.PLANES[kind].length_m) * 0.6 + 8.0
		plate.font_size = 48
		plate.pixel_size = 0.08
		plate.visibility_range_end = 2500
		node.add_child(plate)
		view.add_child(node)
		air_replicas[id] = {"node": node, "kind": kind, "label": plate, "entry": {"kind": kind, "position": Vector3.ZERO, "heading": 0.0, "captain": state.captain}}
	var replica: Dictionary = air_replicas[id]
	var from_air: Dictionary = a.get("air", b.air)
	var from: Vector3 = Vector3(a.position.x, from_air.altitude, a.position.z)
	var to: Vector3 = Vector3(b.position.x, b.air.altitude, b.position.z)
	var basis: Basis = from_air.basis.slerp(b.air.basis, weight)
	# A pole or seam crossing between samples: no sweep across the world.
	if Progression.short_way(to - from).length() > 2000.0:
		from = to
		basis = b.air.basis
	var next: Vector3 = from.lerp(Progression.nearest(to, from), weight) + Vector3(b.velocity.x, b.air.vy, b.velocity.z) * ahead
	var near: Vector3 = Progression.nearest(next, view.ship.position)
	near.y = next.y
	var gear: float = clampf(float(Planes.PLANES[kind].length_m) * 0.12, 1.2, 4.5)
	replica.node.global_transform = Transform3D(basis, near - basis.y * gear)
	PlaneLook.animate(replica.node, b.engine, b.air.gear, delta)
	# Patch 4.0.5 item 3: their engine, from their plane, with the doppler shift.
	if not replica.has("sound"):
		replica.sound = PlaneEngineSound.make(kind, true)
		replica.node.add_child(replica.sound)
	var source_velocity: Vector3 = Vector3(b.velocity.x, b.air.vy, b.velocity.z)
	var listener: Dictionary = listener_motion(delta)
	replica.sound.update(float(b.engine), clampf(float(b.get("throttle", b.engine)), 0.0, 1.0),
		PlaneEngineSound.doppler(near, source_velocity, listener.position, listener.velocity))
	replica.label.text = state.captain
	var entry: Dictionary = replica.entry
	entry.position = near
	entry.heading = atan2(basis.z.x, basis.z.z)
	entry.captain = state.captain
	view.other_ships.append(entry)

## Patch 4.0.5 item 3: where the ears are (the active camera) and how fast
## they move, for the doppler shift. A jump (a world wrap, a respawn, a
## camera switch) counts as standing still.
var listener_at: Vector3 = Vector3.INF
var listener_velocity: Vector3 = Vector3.ZERO
var listener_frame: int = -1
func listener_motion(delta: float) -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return {"position": Vector3.ZERO, "velocity": Vector3.ZERO}
	var at: Vector3 = camera.global_position
	if listener_frame != Engine.get_process_frames():
		listener_frame = Engine.get_process_frames()
		var step: Vector3 = at - listener_at if listener_at.is_finite() else Vector3.ZERO
		var speed: Vector3 = step / maxf(delta, 0.001)
		listener_velocity = listener_velocity.lerp(speed if speed.length() < 600.0 else Vector3.ZERO, 0.3)
		listener_at = at
	return {"position": at, "velocity": listener_velocity}

func drop_air_replica(id: String) -> void:
	air_replicas[id].node.queue_free()
	air_replicas.erase(id)

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
	var cli_captain: String = ""
	for arg: String in args:
		if arg.begins_with("--port="):
			var number: String = arg.trim_prefix("--port=")
			if not number.is_valid_int() or int(number) < 1024 or int(number) > 65535:
				fail("Invalid UDP port", 2)
				return
			port_number = int(number)
		elif arg.begins_with("--host="): host = arg.trim_prefix("--host=")
		elif arg.begins_with("--bind="): bind_address = arg.trim_prefix("--bind=")
		elif arg.begins_with("--captain="): cli_captain = arg.trim_prefix("--captain=")
		elif arg.begins_with("--saves-dir="): saves_path = arg.trim_prefix("--saves-dir=")
		elif arg.begins_with("--control-dir="): launcher.folder = arg.trim_prefix("--control-dir=")
		elif arg.begins_with("--server-config="): config_path = arg.trim_prefix("--server-config=")
		elif arg.begins_with("--client-errors-dir="): error_log.folder = arg.trim_prefix("--client-errors-dir=")
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
		# Patch 4.0.5 item 2: client error reports go to <root>/logs/client_errors.
		if error_log.folder.is_empty(): error_log.folder = error_log.folder_for(saves_path)
		# Patch 3.1.1 item 2: server-config.json sits beside the saves folder.
		load_admin_keys(config_path if not config_path.is_empty() else saves_path.get_base_dir().path_join("server-config.json"))
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
		# Patch 3.0.1 item 1: --captain= (tests) wins over the saved name.
		captain_name = CaptainName.sanitize(cli_captain) if not cli_captain.is_empty() else CaptainName.load_saved()
		if captain_name.is_empty(): captain_name = CaptainName.FALLBACK
		# Patch 4.0.5 item 2: error reports never carry the captain's name.
		ErrorReports.keep_private(captain_name)
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
		view.game_menu.add_entry("CAPTAIN NAME", open_name_dialog, view.game_menu.menu_column.get_child_count() - 2)
		name_layer = CanvasLayer.new()
		name_layer.layer = 121
		add_child(name_layer)
		if is_instance_valid(view.game_hud):
			ping_label = view.game_hud.text(view.game_hud, 16, PLAYFUL.CREAM)
			ping_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			ping_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			# Patch 4.0 item 7: just left of the money panel (which spans 340 to
			# 20 px from the right edge), with a margin, clear of its border.
			ping_label.offset_left = -456
			ping_label.offset_right = -352
			ping_label.offset_top = 26
			ping_label.text = "— ms"
		make_ghost()
		hist_seq.resize(HISTORY)
		hist_values.resize(HISTORY * 4)
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
	# Patch 4.0.2 item 6: while flying, G is the landing gear (Aviation.on_command).
	if action == &"cannon_salute" and view.flying(): return
	# Patch 4.0.4 item 1: one salute per press (a second, ungated send fired it twice).
	if action == &"cannon_salute" and view.controls.input_allowed(): send_gameplay("salute")
	# Patch 4.0.2: Shift asks the server for the Jetty's blaster boost; the own
	# presentation hull starts its looks and sound at once (JettyFx runs its clock).
	if action == PlayerControls.BOOST_COMMAND and not view.flying() and view.ship.request_boost(): send_gameplay("boost")

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
	tracks.clear()
	history_count = 0
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
	if not SaveStore.key_valid(key) or contexts.size() + joining_keys.size() >= MAX_PLAYERS:
		peer.disconnect_peer(sender)
		return
	# Patch 3.0.1 item 1: never trust the client's filter; clean it again.
	var clean: String = CaptainName.sanitize(captain)
	if clean.is_empty(): clean = CaptainName.FALLBACK
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
		# Patch 4.0: XP, planes and plane mode (rows from 4.0 on always have them).
		var progress: Variant = saves.players[player_key].get("progress")
		if progress is Dictionary: context.aviation.restore(progress)
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
	context.ship.set_physics_process(not context.flying())
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
	apply_captain(sender, clean)
	context.cranes = world.cranes
	context.docking.undock_seconds = 1.0
	ships[id] = context.ship
	wrap.add_hull(id, context.ship)
	session.roster[id] = {"peer_id": sender}
	welcome.rpc_id(sender, PROTOCOL, session.epoch, id, DayNight.world_seconds())
	print("DEDICATED_JOIN players=%d" % contexts.size())

@rpc("authority", "call_remote", "reliable", 0)
func join_rejected(reason: String) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1: return
	fail("Join refused", 0, reason if reason in ["mismatch", "updating"] else "offline")

func depart(sender: int) -> void:
	if not hosting: return
	pending_peers.erase(sender)
	error_log.forget(sender)
	if not contexts.has(sender): return
	var context: Node3D = contexts[sender]
	capture_player(sender)
	if not saves.checkpoint(): save_error()
	debug_real.erase(sender)
	player_keys.erase(sender)
	context.docking.disconnect_owner(sender)
	context.port.spawn_allocator.release(context.spawn_ticket)
	var id: String = "ship_%d" % sender
	contexts.erase(sender)
	captains.erase(sender)
	last_gameplay_at.erase(sender)
	last_salute.erase(sender)
	last_gameplay.erase(sender)
	status_sent.erase(sender)
	last_ping.erase(sender)
	last_rename.erase(sender)
	world.docking.members.erase(sender)
	ships.erase(id)
	wrap.remove_hull(id)
	session.roster.erase(id)
	replication.orders.erase(id)
	actions.reconcile()
	context.queue_free()
	print("DEDICATED_LEAVE players=%d" % contexts.size())

@rpc("authority", "call_remote", "reliable", 0)
func welcome(version: int, epoch: String, id: String, clock: float) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or version != PROTOCOL: return
	if not entity.is_empty() or epoch.length() != 32 or id != "ship_%d" % multiplayer.get_unique_id(): return
	session.epoch = epoch
	# Patch 3.1: every player shares the server's time of day.
	DayNight.sync(clock)
	epoch_tag = epoch.left(8).hex_to_int()
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
		report_elapsed += delta
		if report_elapsed >= 60.0:
			# Patch 3.0.1 item 3: a cheap, always-on profile of the send path.
			print("DEDICATED_TICK players=%d send_us=%d bytes_per_s=%d" % [contexts.size(), roundi(server_send_us), roundi(sent_bytes / report_elapsed)])
			report_elapsed = 0.0
			sent_bytes = 0
		for sender: int in debug_real.keys(): tick_debug(sender)
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
		if not pending_peers.is_empty():
			for sender: int in pending_peers.keys():
				if Time.get_ticks_msec() > pending_peers[sender]:
					pending_peers.erase(sender)
					peer.disconnect_peer(sender)
		for id: String in ships:
			var ship: HandlingShip = ships[id]
			var order: Dictionary = replication.orders.get(id, EMPTY)
			var owner_context: Node3D = contexts.get(int(id.trim_prefix("ship_")))
			if owner_context != null and owner_context.flying():
				# Patch 4.0: a flying captain's helm flies the plane (Aviation.tick).
				var live: bool = not order.is_empty() and Time.get_ticks_msec() - order.at <= TIMEOUT_MS
				owner_context.aviation.order = {"throttle": float(order.throttle) if live else 0.0, "pitch": float(order.get("pitch", 0.0)) if live else 0.0,
					"roll": float(order.rudder) if live else 0.0, "yaw": float(order.lateral) if live else 0.0,
					"gear": float(order.get("gear", -1.0)) if live else -1.0}
				continue
			if order.is_empty() or Time.get_ticks_msec() - order.at > TIMEOUT_MS:
				ship.zero_throttle()
				ship.maneuver(0, 0)
			else:
				ship.command_throttle(order.throttle)
				ship.maneuver(order.rudder, order.lateral)
	elif not entity.is_empty() and is_instance_valid(view) and view.flying():
		# Patch 4.0 item 15: the own plane answers its controls this tick, with
		# the server's physics; reconcile() later corrects it without a snap.
		var flight: Dictionary = view.aviation.client_input(delta)
		throttle = float(flight.throttle)
		steering = float(flight.roll)
		thruster = float(flight.yaw)
		view.aviation.predict(delta, sequence + 1)
		history_count = 0
	elif not entity.is_empty() and is_instance_valid(view):
		if not view.ship.helm_available(): throttle = 0.0
		var allowed: bool = view.controls.input_allowed() and view.ship.helm_available()
		# Patch 4.0.5 item 1: a controller's triggers move the order as the keys do.
		var axis: float = clampf(view.controls.action_strength("ship_throttle_up") - view.controls.action_strength("ship_throttle_down") + view.controls.lever_axis(), -1.0, 1.0) if allowed else 0.0
		throttle = HandlingShip.adjusted_order(throttle, axis, delta, view.ship.definition)
		if allowed and view.controls.action_strength("ship_throttle_zero") > 0: throttle = 0.0
		var steer_allowed: bool = view.controls.input_allowed()
		steering = view.controls.steering_axis() if steer_allowed else 0.0
		thruster = view.controls.action_strength("ship_thruster_right") - view.controls.action_strength("ship_thruster_left") if steer_allowed else 0.0
		# Patch 3.0.1 item 2a: the own hull answers the helm this tick.
		if predicting(): step_prediction(delta)
		else: history_count = 0
	send_elapsed += delta
	if send_elapsed < INTERVAL: return
	send_elapsed = fmod(send_elapsed, INTERVAL)
	if hosting:
		var started_us: int = Time.get_ticks_usec()
		tick += 1
		send_frames()
		server_send_us = lerpf(server_send_us, float(Time.get_ticks_usec() - started_us), 0.05)
	elif not entity.is_empty():
		send_helm(throttle, steering, thruster)

## Patch 3.0.1 item 3: one compact unreliable motion frame per recipient,
## reliable status only on change, gameplay state only on change or action.
func send_frames() -> void:
	var rows: Dictionary = {}
	for sender: int in contexts: rows[sender] = motion_row(sender)
	var crane_frame: Array = pack_cranes()
	var fresh: Dictionary = {}
	if tick % STATUS_EVERY == 0:
		for sender: int in contexts: fresh["ship_%d" % sender] = status_row(sender)
	var tag: int = session.epoch.left(8).hex_to_int()
	for sender: int in contexts:
		var own_position: Vector3 = contexts[sender].ship.position
		var picked: Array = []
		for other: int in contexts:
			if other == sender or Relevance.due(Relevance.near(own_position, contexts[other].ship.position), tick, other): picked.append(rows[other])
		var packed: PackedByteArray = Codec.encode_motion(own_motion(sender), picked, crane_blob(own_position, crane_frame))
		sent_bytes += packed.size()
		var count: int = ceili(packed.size() / 900.0)
		if count == 1: snapshot_chunk.rpc_id(sender, tag, tick, elapsed, 0, 1, packed)
		else:
			for index: int in count:
				snapshot_chunk.rpc_id(sender, tag, tick, elapsed, index, count, packed.slice(index * 900, mini(packed.size(), (index + 1) * 900)))
		if not fresh.is_empty(): send_status(sender, fresh)
		if tick % 4 == 0:
			var data: Dictionary = gameplay_state(contexts[sender])
			if last_gameplay.get(sender, EMPTY) != data:
				last_gameplay[sender] = data.duplicate(true)
				gameplay_snapshot.rpc_id(sender, session.epoch, data)

## Cranes near the recipient only, FastLZ-packed. Four zero bytes mean none.
func crane_blob(at: Vector3, frames: Array) -> PackedByteArray:
	var near: Array = []
	for frame: Dictionary in frames:
		if Progression.short_way(world.world_ports[frame.port].global_position - at).length() <= CRANE_RANGE_M: near.append(frame)
	var blob: PackedByteArray = PackedByteArray()
	blob.resize(4)
	if near.is_empty():
		blob.encode_u32(0, 0)
		return blob
	var raw: PackedByteArray = var_to_bytes(near)
	blob.encode_u32(0, raw.size())
	blob.append_array(raw.compress(FileAccess.COMPRESSION_FASTLZ))
	return blob

func send_status(sender: int, fresh: Dictionary) -> void:
	if not status_sent.has(sender): status_sent[sender] = {}
	var sent: Dictionary = status_sent[sender]
	var changes: Dictionary = {}
	var own_id: String = "ship_%d" % sender
	for id: String in fresh:
		var row: Dictionary = fresh[id]
		if id == own_id:
			row = row.duplicate()
			var context: Node3D = contexts[sender]
			row.readiness = context.docking.readiness(sender, context.service_id(), context.cargo_id())
			row.crane_remaining = snappedf(world.cranes.remaining(sender), 0.1)
		if sent.get(id, EMPTY) != row:
			changes[id] = row
			sent[id] = row.duplicate(true)
	var removed: Array = []
	for id: String in sent.keys():
		if not fresh.has(id):
			removed.append(id)
			sent.erase(id)
	if not changes.is_empty() or not removed.is_empty(): fleet_status.rpc_id(sender, session.epoch, changes, removed)

@rpc("authority", "call_remote", "reliable", 0)
func fleet_status(epoch: String, changes: Dictionary, removed: Array) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or entity.is_empty() or epoch != session.epoch: return
	for id: Variant in removed:
		if not id is String: continue
		statuses.erase(id)
		tracks.erase(id)
		members.erase(id)
		if replicas.has(id): drop_replica(id)
		if air_replicas.has(id): drop_air_replica(id)
	for id: Variant in changes:
		var row: Variant = changes[id]
		if not id is String or not row is Dictionary or not row.get("kind") is String or not Progression.SHIPS.has(row.kind): continue
		if not row.get("captain") is String or not row.get("port") is int or row.port < 0 or row.port >= view.world_ports.size(): continue
		if not row.get("owner") is int or row.get("filled") == null or not row.get("heavy") is Dictionary: continue
		row.captain = CaptainName.sanitize(row.captain)
		statuses[id] = row
		if replicas.has(id) and replicas[id].label.text != row.captain: replicas[id].label.text = row.captain

func send_helm(command: float, rudder: float, lateral: float) -> void:
	sequence += 1
	var payload: Dictionary = {"throttle": command, "rudder": rudder, "lateral": lateral, "sent_ms": Time.get_ticks_msec()}
	# Patch 4.0: a plane's helm also sends the pitch.
	if is_instance_valid(view) and view.flying():
		payload.pitch = float(view.aviation.order.pitch)
		# Patch 4.0.2 item 6: and the gear lever.
		payload.gear = float(view.aviation.order.get("gear", 1.0))
	helm_input.rpc_id(1, ShipActions.make_request(session.epoch, multiplayer.get_unique_id(), entity, "helm", sequence, payload))

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func snapshot_chunk(tag: int, frame: int, stamp: float, index: int, count: int, chunk: PackedByteArray) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1 or entity.is_empty() or tag != epoch_tag or frame <= last_tick or frame < incoming_frame: return
	if count < 1 or count > 64 or index < 0 or index >= count or chunk.size() > 900: return
	if count == 1:
		snapshot(frame, stamp, chunk)
		return
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
	snapshot(frame, stamp, packed)

func snapshot(frame: int, stamp: float, packed: PackedByteArray) -> void:
	if frame <= last_tick or not is_finite(stamp) or stamp < 0: return
	var started_us: int = Time.get_ticks_usec()
	var decoded: Dictionary = Codec.decode_motion(packed)
	if decoded.is_empty(): return
	var cranes: Array = []
	var blob: PackedByteArray = decoded.cranes
	if blob.size() < 4: return
	var length: int = blob.decode_u32(0)
	if length > 0:
		if length > 65536 or blob.size() < 5: return
		var unpacked: Variant = bytes_to_var(blob.slice(4).decompress(length, FileAccess.COMPRESSION_FASTLZ))
		if not unpacked is Array: return
		cranes = unpacked
	var state: Dictionary = decoded.own
	last_tick = frame
	last_snapshot_ms = Time.get_ticks_msec()
	join_deadline = 0
	if received_states == 0 and is_instance_valid(connection_card):
		connection_card.hide()
		view.show()
		view.controls.set_menu_open(false)
	received_states += 1
	last_state = state
	var now: float = Time.get_ticks_msec() / 1000.0
	# Patch 3.0.1 item 2b: buffer ≈ 2 × measured interval + jitter, 80–250 ms.
	if last_arrival >= 0:
		var gap: float = now - last_arrival
		snapshot_jitter = lerpf(snapshot_jitter, absf(gap - snapshot_interval), 0.1)
		snapshot_interval = lerpf(snapshot_interval, gap, 0.1)
		buffer_seconds = clampf(2.0 * snapshot_interval + snapshot_jitter, BUFFER_MIN, BUFFER_MAX)
	last_arrival = now
	clock_offset = minf(clock_offset, now - stamp)
	samples.append({"stamp": stamp, "state": state})
	while samples.size() > 16: samples.pop_front()
	for row: Dictionary in decoded.rows:
		if not peer_names.has(row.peer): peer_names[row.peer] = "ship_%d" % row.peer
		var id: String = peer_names[row.peer]
		if not statuses.has(id): continue
		if not tracks.has(id): tracks[id] = []
		var track: Array = tracks[id]
		row.stamp = stamp
		track.append(row)
		while track.size() > TRACK_SAMPLES: track.pop_front()
	world_samples.append({"stamp": stamp, "ships": statuses, "cranes": cranes})
	while world_samples.size() > 16: world_samples.pop_front()
	if received_states == 1:
		view.ship.position = Vector3(state.position.x, 0.0 if state.has("air") else state.position.y, state.position.z)
		view.ship.rotation.y = state.yaw
		view.camera.set_focus(view.ship.assembly.focus)
	if state.has("air"): view.aviation.reconcile(state)
	else: reconcile(state)
	client_snapshot_us = lerpf(client_snapshot_us, float(Time.get_ticks_usec() - started_us), 0.05)

# --- Patch 3.0.1 item 2a: own-hull prediction ----------------------------------

## A bare, shapeless HandlingShip runs the same advance_motion as the server.
func make_ghost() -> void:
	if is_instance_valid(ghost): ghost.queue_free()
	ghost = HandlingShip.new()
	ghost.name = "PredictedHelm"
	ghost.definition = view.ship.definition
	add_child(ghost)
	ghost.set_physics_process(false)
	ghost.collision_layer = 0
	ghost.collision_mask = 0
	history_count = 0

## Free sailing only: berthing, pauses and docked hulls follow the server.
func predicting() -> bool:
	if not is_physics_processing() or not is_instance_valid(ghost) or received_states == 0: return false
	var own: Dictionary = statuses.get(entity, EMPTY)
	if view.flying(): return false
	return not own.is_empty() and own.dock in ["underway", "approaching"] and not own.docked and not own.paused

func ghost_step(command: float, rudder: float, lateral: float, delta: float) -> void:
	ghost.command_throttle(command)
	ghost.maneuver(rudder, lateral)
	ghost.advance_motion(delta)
	ghost.position = Progression.wrapped(ghost.position + ghost.velocity * delta)

func step_prediction(delta: float) -> void:
	if history_count == HISTORY:
		history_head = (history_head + 1) % HISTORY
		history_count -= 1
	var slot: int = (history_head + history_count) % HISTORY
	hist_seq[slot] = sequence + 1
	hist_values[slot * 4] = throttle
	hist_values[slot * 4 + 1] = steering
	hist_values[slot * 4 + 2] = thruster
	hist_values[slot * 4 + 3] = delta
	history_count += 1
	ghost_previous = ghost.transform
	ghost_step(throttle, steering, thruster, delta)
	predicted_frames += 1

## Reset to the server's hull, replay unacknowledged helm, then fade the gap.
func reconcile(state: Dictionary) -> void:
	if not is_instance_valid(ghost): return
	while history_count > 0 and hist_seq[history_head] <= state.ack:
		history_head = (history_head + 1) % HISTORY
		history_count -= 1
	ghost.transform = Transform3D(Basis(Vector3.UP, state.yaw), state.position)
	ghost.velocity = state.velocity
	ghost.yaw_rate = state.yaw_rate
	ghost.actual_throttle = state.engine
	ghost.commanded_throttle = state.throttle
	ghost.rudder = state.rudder
	ghost.lateral_order = state.lateral
	ghost.state.fuel_liters = state.fuel
	ghost.state.condition = state.condition
	ghost.docked = false
	ghost.simulation_paused = false
	for index: int in history_count:
		var slot: int = (history_head + index) % HISTORY
		ghost_step(hist_values[slot * 4], hist_values[slot * 4 + 1], hist_values[slot * 4 + 2], hist_values[slot * 4 + 3])
	ghost_previous = ghost.transform
	var shown: Vector3 = Progression.nearest(view.ship.position, ghost.position)
	offset_position = shown - ghost.position
	offset_yaw = angle_difference(ghost.rotation.y, view.ship.rotation.y)
	# Patch 4.0 item 15: scaled with speed, so the 1000 kn Jetty's ordinary
	# prediction error is smoothed, never snapped (no rubber band).
	if offset_position.length() > maxf(SNAP_ERROR_M, ghost.velocity.length() * 0.5) or absf(offset_yaw) > SNAP_YAW:
		offset_position = Vector3.ZERO
		offset_yaw = 0.0
		snaps += 1
	elif offset_position.length() > 0.05: corrections += 1

## Place the presented own hull; camera, wake and sea follow a seam crossing.
func place_own(at: Vector3, yaw: float) -> void:
	var ship: HandlingShip = view.ship
	var wrapped: Vector3 = Progression.wrapped(at)
	var seam: Vector3 = Progression.nearest(ship.position, wrapped) - ship.position
	if seam.length() > 1.0:
		view.camera.shift(seam)
		view.wake.shift(seam)
		view.ocean.shift(seam)
	ship.position = wrapped
	ship.rotation.y = yaw

func _process(_delta: float) -> void:
	if hosting:
		launcher.poll(self, _delta)
		return
	if join_deadline > 0 and Time.get_ticks_msec() > join_deadline: fail("Connection timed out")
	if last_snapshot_ms > 0 and Time.get_ticks_msec() - last_snapshot_ms > 10000: fail("Server stopped responding")
	if notice != null: notice.text = status
	if not entity.is_empty():
		ping_elapsed += _delta
		if ping_elapsed >= PING_SECONDS:
			ping_elapsed = 0.0
			ping.rpc_id(1, Time.get_ticks_msec())
		send_error_reports(_delta)
	if samples.is_empty(): return
	var target: float = Time.get_ticks_msec() / 1000.0 - clock_offset - buffer_seconds
	var ship: HandlingShip = view.ship
	if view.flying():
		# Patch 4.0: the laid-up boat follows the predicted plane at sea level.
		# Patch 4.0.1 item 3: it stays at the wreck while the crash view lasts.
		var m: RefCounted = view.aviation.model
		var anchor: Vector3 = view.aviation.view_anchor()
		place_own(Vector3(anchor.x, 0.0, anchor.z), m.heading())
		ship.velocity = Vector3.ZERO
		ship.ground_speed_mps = 0.0
		view.place_icebergs()
		present_world(target, _delta)
		return
	if predicting():
		var fade: float = exp(-_delta / CORRECTION_SECONDS)
		offset_position *= fade
		offset_yaw *= fade
		var blend: float = Engine.get_physics_interpolation_fraction()
		var from: Vector3 = Progression.nearest(ghost_previous.origin, ghost.position)
		place_own(from.lerp(ghost.position, blend) + offset_position,
			lerp_angle(ghost_previous.basis.get_euler().y, ghost.rotation.y, blend) + offset_yaw)
		ship.velocity = ghost.velocity
		ship.ground_speed_mps = Vector2(ghost.velocity.x, ghost.velocity.z).length()
		ship.yaw_rate = ghost.yaw_rate
		ship.commanded_throttle = throttle
		ship.actual_throttle = ghost.actual_throttle
		ship.rudder = ghost.rudder
		ship.lateral_order = ghost.lateral_order
	else:
		while samples.size() > 2 and samples[1].stamp <= target: samples.pop_front()
		var a: Dictionary = samples[0].state
		var b: Dictionary = samples[mini(1, samples.size() - 1)].state
		var weight: float = clampf((target - samples[0].stamp) / maxf(0.000001, samples[mini(1, samples.size() - 1)].stamp - samples[0].stamp), 0.0, 1.0)
		# Interpolate across the short side of the torus, never through its middle.
		place_own(a.position.lerp(Progression.nearest(b.position, a.position), weight), lerp_angle(a.yaw, b.yaw, weight))
		ship.velocity = a.velocity.lerp(b.velocity, weight)
		ship.ground_speed_mps = lerpf(a.ground_speed, b.ground_speed, weight)
		ship.commanded_throttle = b.throttle
		ship.actual_throttle = b.engine
		ship.rudder = b.rudder
		ship.lateral_order = b.lateral
	ship.state.fuel_liters = last_state.fuel
	ship.state.condition = last_state.condition
	view.place_icebergs()
	present_world(target, _delta)

# --- Patch 4.0.5 item 2: client error and crash reports ------------------------

## One waiting report every ERROR_SEND_SECONDS (the server's own pace), once
## this client has joined.
func send_error_reports(delta: float) -> void:
	error_send_elapsed += delta
	if error_send_elapsed < ERROR_SEND_SECONDS: return
	var reports: Node = ErrorReports.find(get_tree())
	if reports == null: return
	error_send_elapsed = 0.0
	for report: Dictionary in reports.take(1):
		client_error_report.rpc_id(1, report)
		errors_sent += 1

@rpc("any_peer", "call_remote", "reliable", 0)
func client_error_report(report: Variant) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	# Only captains who have joined; the log never records who sent it.
	if not contexts.has(sender): return
	error_log.accept(sender, report)

# --- Patch 3.0.1 item 2c: round-trip time -------------------------------------

@rpc("any_peer", "call_remote", "unreliable", 1)
func ping(stamp: int) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not contexts.has(sender): return
	var now: int = Time.get_ticks_msec()
	if now - int(last_ping.get(sender, -1000)) < 500: return
	last_ping[sender] = now
	pong.rpc_id(sender, stamp, DayNight.world_seconds())

@rpc("authority", "call_remote", "unreliable", 1)
func pong(stamp: int, clock: float) -> void:
	if hosting or multiplayer.get_remote_sender_id() != 1: return
	var rtt: int = Time.get_ticks_msec() - stamp
	if rtt < 0 or rtt > 10000: return
	DayNight.sync(clock + rtt / 2000.0)
	rtt_ms = float(rtt) if rtt_ms < 0 else lerpf(rtt_ms, float(rtt), 0.3)
	if ping_label != null: ping_label.text = "%d ms" % roundi(rtt_ms)

# --- Patch 3.0.1 item 1: change captain name ----------------------------------

func open_name_dialog() -> void:
	if not is_instance_valid(name_layer) or name_layer.get_child_count() > 0: return
	view.game_menu.close()
	view.controls.set_menu_open(true)
	name_layer.add_child(CaptainName.make_dialog(captain_name, func(chosen: String) -> void:
		captain_name = chosen
		ErrorReports.keep_private(chosen)
		if not entity.is_empty():
			status = "Connected · " + captain_name
			rename_captain.rpc_id(1, captain_name)
		view.controls.set_menu_open(false), "Change captain name"))

@rpc("any_peer", "call_remote", "reliable", 0)
func rename_captain(captain: String) -> void:
	if not hosting: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not contexts.has(sender): return
	var now: int = Time.get_ticks_msec()
	if now - int(last_rename.get(sender, -5000)) < 2000: return
	var clean: String = CaptainName.sanitize(captain)
	if clean.is_empty(): return
	last_rename[sender] = now
	apply_captain(sender, clean)

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
	saves.players[player_keys[sender]] = {"captain": captains[sender], "voyage": real_voyage(sender), "progress": real_progress(sender)}

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
	if not hosting: DayNight.clock_offset = 0.0
	shutdown_saves()
	if peer != null: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session.free()

# --- Patch 3.1.1 item 2: admin "debug" captain name ----------------------------
## A captain renamed "debug" (any case) on an admin key gets infinite money and
## every ship until renamed. It is a server-only overlay: the real money, fleet
## and voyage are kept aside, and checkpoints only ever write those. The
## nameplate still reads "debug". Admin keys are player keys (the sha256 of an
## install key, the keys of "players" in saves/world.json) listed in an
## "admin_keys" array in server-config.json. That file is never in the repo.
## Anyone else named "debug" only gets the label.
const DEBUG_NAME: String = "debug"
const DEBUG_CREDITS_MINOR: int = 99999999900
const DEBUG_RETRY_MS: int = 1000

func load_admin_keys(path: String) -> void:
	admin_keys.clear()
	if path.is_empty() or not FileAccess.file_exists(path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("admin_keys") is Array: return
	for key: Variant in parsed.admin_keys:
		if key is String and SaveStore.key_valid(key.strip_edges().to_lower()): admin_keys.append(key.strip_edges().to_lower())
	if not admin_keys.is_empty(): print("DEDICATED_ADMINS keys=%d" % admin_keys.size())

func is_admin(sender: int) -> bool:
	return player_keys.has(sender) and admin_keys.has(String(player_keys[sender]).to_lower())

func debug_active(sender: int) -> bool:
	return debug_real.has(sender) and debug_real[sender].active

## Every name change on the server goes through here.
func apply_captain(sender: int, clean: String) -> void:
	captains[sender] = clean
	if not contexts.has(sender): return
	var wants: bool = clean.to_lower() == DEBUG_NAME and is_admin(sender)
	if wants and not debug_active(sender): start_debug(sender)
	elif not wants and debug_active(sender): end_debug(sender)

func start_debug(sender: int) -> void:
	var context: Node3D = contexts[sender]
	# A pending swap back (renamed away, still in a debug ship) keeps its real copy.
	if not debug_real.has(sender):
		debug_real[sender] = {"credits": context.reward_minor, "spent": context.spent_minor, "banked": context.banked_minor,
			"fleet": context.fleet.duplicate(true), "ship": context.ship_kind, "voyage": SaveSnapshot.capture(context),
			"progress": context.aviation.capture(), "planes": context.aviation.planes.duplicate(true)}
	debug_real[sender].active = true
	# Patch 4.0 item 16: every plane too, at any level.
	context.aviation.unlock_all()
	for kind: String in Progression.SHIPS:
		if Progression.buyable(kind) and not context.fleet.has(kind): context.fleet[kind] = {"fuel": 1.0, "condition": 1.0}
	context.reward_minor = DEBUG_CREDITS_MINOR
	context.offer_notice = "Debug captain: infinite money and every ship until you rename."

func end_debug(sender: int) -> void:
	var context: Node3D = contexts[sender]
	var real: Dictionary = debug_real[sender]
	real.active = false
	real.retry_at = 0
	context.reward_minor = real.credits
	context.spent_minor = real.spent
	context.banked_minor = real.banked
	context.fleet = real.fleet.duplicate(true)
	context.sell_kind = ""
	context.aviation.debug_unlocked = false
	context.aviation.planes = real.planes.duplicate(true)
	# A plane that was only the overlay's is kept until the captain lands and
	# switches; the checkpoint stores the real progress meanwhile.
	if context.flying() and not context.aviation.planes.has(context.aviation.plane_kind):
		context.aviation.planes[context.aviation.plane_kind] = {"fuel": 1.0, "condition": 1.0}
		real.borrowed_plane = context.aviation.plane_kind
	elif not context.aviation.planes.has(context.aviation.plane_kind): context.aviation.plane_kind = context.aviation.first_plane()
	context.offer_notice = "Debug off: your own money and ships are back."
	return_real_ship(sender)

## Puts the captain back in their own ship when the debug one is not theirs.
## A job under way waits: the swap is retried until the job is finished.
func return_real_ship(sender: int) -> void:
	var context: Node3D = contexts[sender]
	var real: Dictionary = debug_real[sender]
	if real.has("borrowed_plane"):
		# Patch 4.0: an overlay-only plane goes back once the captain is a sailor again.
		if context.flying():
			real.retry_at = Time.get_ticks_msec() + DEBUG_RETRY_MS
			context.offer_notice = "Debug off. Land and switch to your boat to give the debug plane back."
			return
		context.aviation.planes.erase(real.borrowed_plane)
		if context.aviation.plane_kind == real.borrowed_plane: context.aviation.plane_kind = context.aviation.first_plane()
		real.erase("borrowed_plane")
	if context.ship_kind == real.ship:
		debug_real.erase(sender)
		return
	real.retry_at = Time.get_ticks_msec() + DEBUG_RETRY_MS
	if context.loading.busy() or context.cranes_busy() or context.sink_seconds > 0.0 or not context.can_switch():
		context.offer_notice = "Debug off. Finish or cancel this job to return to your own ship."
		return
	var previous: String = context.ship_kind
	context.ship_kind = real.ship
	context.heavy_mode = Progression.heavy_tier(real.ship) > 0
	if not context.select_port(context.world_ports.find(context.port)):
		context.ship_kind = previous
		context.heavy_mode = Progression.heavy_tier(previous) > 0
		return
	context.ship.state.fuel_liters = float(real.voyage.fuel)
	context.ship.state.condition = float(real.voyage.condition)
	if is_instance_valid(world):
		disable_tree(context.ship)
		context.ship.set_physics_process(true)
	replication.orders.erase("ship_%d" % sender)
	debug_real.erase(sender)
	context.offer_notice = "Debug off: back in your own %s." % Progression.SHIPS[real.ship].name

func tick_debug(sender: int) -> void:
	if not debug_real.has(sender): return
	if not contexts.has(sender):
		debug_real.erase(sender)
		return
	var real: Dictionary = debug_real[sender]
	if real.active: contexts[sender].reward_minor = DEBUG_CREDITS_MINOR
	elif Time.get_ticks_msec() >= int(real.get("retry_at", 0)): return_real_ship(sender)

## Patch 4.0: the progress row a checkpoint stores. Never the debug overlay:
## while it is on, the progress as it was when debug began (with the plane
## mode as it is now, if that plane is the captain's own).
func real_progress(sender: int) -> Dictionary:
	var context: Node3D = contexts[sender]
	var live: Dictionary = context.aviation.capture()
	if not debug_real.has(sender): return live
	var real: Dictionary = debug_real[sender].progress.duplicate(true)
	real.planes = debug_real[sender].planes.duplicate(true)
	if context.flying() and real.planes.has(context.aviation.plane_kind):
		real.mode = "plane"
		real.plane = context.aviation.plane_kind
		real.airport = live.airport
		real.plane_job = live.plane_job
	else:
		real.mode = "boat"
		real.plane_job = ""
		if not real.planes.has(real.plane): real.plane = ""
	if not Levels.progress_valid(real): return Levels.fresh_progress()
	return real

## What a checkpoint stores. Never the debug overlay: in the real ship, the live
## voyage with the real money and fleet; in a debug ship, the voyage as it was
## when debug began.
func real_voyage(sender: int) -> Dictionary:
	var context: Node3D = contexts[sender]
	if not debug_real.has(sender): return SaveSnapshot.capture(context)
	var real: Dictionary = debug_real[sender]
	if context.ship_kind != real.ship: return real.voyage.duplicate(true)
	var data: Dictionary = SaveSnapshot.capture(context)
	data.credits = real.credits
	data.spent = real.spent
	data.banked = real.banked
	data.fleet = real.fleet.duplicate(true)
	data.ship = real.ship
	return data
