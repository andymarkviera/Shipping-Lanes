class_name CargoReplication
extends Node
const Heavy = preload("res://features/handling/heavy_lifter.gd")
var world: Node3D
var session: LocalShipSession
var versions: Dictionary = {}
var commands: Dictionary = {}
var sequence: int = 0
var rejected: int = 0
var accepted: int = 0

func configure(owner_world: Node3D, source: LocalShipSession) -> void:
	world = owner_world
	session = source
	set_multiplayer_authority(1)
	session.changed.connect(func():
		for id: String in versions.keys():
			if not session.roster.has(id): versions.erase(id)
		for id: String in commands.keys():
			if not session.roster.has(id): commands.erase(id)
		if session.roster.is_empty(): sequence = 0)

func submit(action: String) -> void:
	var id: String = world.replication.local_entity()
	if id.is_empty(): return
	sequence += 1
	if session.hosting: accept(1, session.epoch, id, sequence, action)
	else: world.replication.queue_packet("cargo", [session.epoch, id, sequence, action])

@rpc("any_peer", "call_remote", "reliable", 0)
func request_action(session_epoch: String, id: String, seq: int, action: String) -> void:
	if session.hosting: accept(multiplayer.get_remote_sender_id(), session_epoch, id, seq, action)

func accept(sender: int, session_epoch: String, id: String, seq: int, action: String) -> bool:
	if not session.hosting or session_epoch != session.epoch or not session.roster.has(id) or session.roster[id].peer_id != sender or not world.ships.has(id) or not world.ships[id] is Heavy:
		rejected += 1
		return false
	if seq <= commands.get(id, -1) or seq < 0 or action not in ["lower", "align", "secure", "raise", "release"]:
		rejected += 1
		return false
	commands[id] = seq
	var ship: Heavy = world.ships[id]
	var ok: bool = false
	match action:
		"lower": ok = ship.request_height(Heavy.LOWERED)
		"align": ok = ship.align_test_payload()
		"secure": ok = ship.attach_payload()
		"raise": ok = ship.request_height(Heavy.RAISED)
		"release": ok = ship.detach_payload()
	if ok:
		versions[id] = versions.get(id, 0) + 1
		accepted += 1
	else: rejected += 1
	return ok

func snapshot(id: String, body: HandlingShip) -> Dictionary:
	if not body is Heavy: return {}
	var ship: Heavy = body
	return {"id": id + "_payload", "version": versions.get(id, 0), "attached": ship.attached,
		"deck": ship.deck_height, "target": ship.deck_target, "pose": ship.payload_body.global_transform,
		"notice": ship.notice}

static func valid(id: String, body: HandlingShip, state: Variant) -> bool:
	if not state is Dictionary: return false
	if not body is Heavy: return state.is_empty()
	if state.get("id") != id + "_payload" or not state.get("version") is int or state.version < 0 or not state.get("attached") is bool: return false
	for field: String in ["deck", "target"]:
		if not state.get(field) is float or not is_finite(state[field]) or state[field] < Heavy.LOWERED or state[field] > Heavy.RAISED: return false
	return state.get("pose") is Transform3D and state.pose.is_finite() and state.get("notice") is String and state.notice.length() < 256

static func present(body: HandlingShip, a: Dictionary, b: Dictionary, weight: float) -> void:
	if not body is Heavy: return
	var ship: Heavy = body
	if not is_instance_valid(ship.payload_body) or not ship.payload_body.is_inside_tree(): return
	# Discrete ownership and deck state share the same delayed ship timeline.
	var state: Dictionary = b if weight >= 1 else a
	var height: float = lerpf(a.deck, b.deck, weight) if a.attached == b.attached else state.deck
	ship.deck_height = height
	ship.deck_target = state.target
	ship.deck_visual.position.y = height - Heavy.RAISED
	ship.cargo_mount.position.y = height
	ship.payload_shape.disabled = true
	ship.payload_body.collision_layer = 0
	ship.attached = state.attached
	var parent: Node3D = ship.cargo_mount if state.attached else ship.payload_body
	if ship.payload_visual.get_parent() != parent: ship.payload_visual.reparent(parent, false)
	ship.payload_visual.transform = Transform3D.IDENTITY
	if not state.attached: ship.payload_body.global_transform = state.pose
	ship.notice = state.notice
