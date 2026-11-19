extends SceneTree
## Patch 3.0.1 item 3: snapshot bytes per ship per second stay under budget.
## Also checks the quantized codec round trip and captain-name cleaning.
## godot --headless --path . --script res://tools/check_snapshot_budget.gd
const Codec = preload("res://features/network/public_snapshot_codec.gd")
const Relevance = preload("res://features/network/ship_relevance.gd")
const CaptainName = preload("res://features/network/captain_name.gd")
## Per ship, per recipient, per second, including an estimated per-packet
## RPC + ENet + UDP/IP overhead shared by the ships in the frame.
const BUDGET_BYTES: float = 1024.0
const PACKET_OVERHEAD: int = 64
const RATE_HZ: int = 20
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("SNAPSHOT_BUDGET: " + message)

func own_state() -> Dictionary:
	return {"ack": 1234, "position": Vector3(-3590.37, 0.0, 6250.81), "yaw": -2.4, "velocity": Vector3(4.2, 0, -7.9),
		"ground_speed": 8.9, "yaw_rate": 0.031, "engine": 0.8, "throttle": 1.0, "rudder": -0.5, "lateral": 0.0,
		"fuel": 812.5, "condition": 0.93}

func ship_row(peer: int, at: Vector3, heavy: bool = false) -> Dictionary:
	var row: Dictionary = {"peer": peer, "position": at, "yaw": 1.2, "velocity": Vector3(-3.1, 0, 5.5), "speed": 6.3,
		"yaw_rate": -0.02, "engine": 0.6, "throttle": 0.7, "rudder": 0.25, "lateral": -1.0, "remaining": 0.0}
	if heavy: row.heavy = {"height": 1.3, "pose": Transform3D(Basis(Vector3.UP, 0.4), at + Vector3(1, 2.5, -3))}
	return row

## The 3.0.0 per-ship Dictionary sent every tick, for the before/after report.
func legacy_frame(peer: int, at: Vector3) -> Dictionary:
	return {"owner": peer, "captain": "Captain Name", "kind": "container", "position": at, "yaw": 1.2,
		"velocity": Vector3(-3.1, 0, 5.5), "speed": 6.3, "yaw_rate": -0.02, "engine": 0.6, "throttle": 0.7,
		"rudder": 0.25, "lateral": -1.0, "port": 2, "dock": "underway", "berth": -1, "remaining": 0.0, "docked": false,
		"filled": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "paused": false, "pause_reason": "", "heavy": {}, "job": "",
		"credits": 125000, "readiness": {"eligible": false, "code": "OUT_OF_RANGE", "message": "Move closer to a berth."}, "crane_remaining": 0.0}

func _initialize() -> void:
	# Captain names: trimmed, filtered, 3-16 chars.
	check(CaptainName.sanitize("  Ada Lovelace ") == "Ada Lovelace", "trim")
	check(CaptainName.sanitize("Bad@Name!") == "BadName", "filter")
	check(CaptainName.sanitize("ab") == "", "too short")
	check(CaptainName.sanitize("Captain_Very-Long Name Here").length() == CaptainName.MAX_LENGTH, "truncate")
	check(CaptainName.sanitize("a\nb\rc  d") == "abc d", "no control characters, single spaces")
	check(CaptainName.valid("Probe-client1") and not CaptainName.valid(" x "), "valid")
	var path: String = "user://snapshot_budget_name.txt"
	check(CaptainName.save(" Mary Read ", path) and CaptainName.load_saved(path) == "Mary Read", "saved name round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(CaptainName.load_saved("user://missing_name.txt") == "", "missing name file means first Play")
	var chosen: Array[String] = []
	var dialog: Control = CaptainName.make_dialog("", func(value: String) -> void: chosen.append(value), "Captain name", path)
	root.add_child(dialog)
	var field: LineEdit = dialog.find_child("Name", true, false)
	var sail: Button = dialog.find_child("SetSail", true, false)
	check(field != null and sail != null and sail.disabled, "modal starts with Set sail disabled")
	field.text = "  Anne Bonny  "
	field.text_changed.emit(field.text)
	check(not sail.disabled, "valid name enables Set sail")
	field.text_submitted.emit(field.text)
	check(chosen == ["Anne Bonny"] and CaptainName.load_saved(path) == "Anne Bonny", "Enter submits and saves the cleaned name")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# Codec round trip within quantization tolerance.
	var rows: Array = [ship_row(11, Vector3(5040.2, 0.0, 250.7)), ship_row(22, Vector3(-210.0, 0.4, 1850.3), true)]
	var bytes: PackedByteArray = Codec.encode_motion(own_state(), rows, PackedByteArray([0, 0, 0, 0]))
	var back: Dictionary = Codec.decode_motion(bytes)
	check(not back.is_empty(), "frame decodes")
	if not back.is_empty():
		check(back.own.ack == 1234 and back.own.position.distance_to(own_state().position) < 0.01, "own position within 1 cm")
		check(absf(angle_difference(back.own.yaw, -2.4)) < 0.001 and absf(back.own.engine - 0.8) < 0.001, "own yaw/engine quantized")
		check(back.rows.size() == 2 and back.rows[1].has("heavy") and not back.rows[0].has("heavy"), "heavy extension only when present")
		check(back.rows[1].heavy.pose.origin.distance_to(rows[1].heavy.pose.origin) < 0.01, "heavy payload pose")
		check(back.rows[1].heavy.height == float(1.3) or is_equal_approx(back.rows[1].heavy.height, 1.3), "heavy deck height keeps float precision")
		var raised: Dictionary = ship_row(33, Vector3.ZERO, true)
		raised.heavy.height = 2.6
		check(Codec.decode_motion(Codec.encode_motion(own_state(), [raised], PackedByteArray([0, 0, 0, 0]))).rows[0].heavy.height == 2.6, "RAISED deck height survives exactly")
		check(back.rows[0].velocity.distance_to(rows[0].velocity) < 0.02, "velocity halves")
	var broken: PackedByteArray = bytes.duplicate()
	broken.resize(bytes.size() - 1)
	check(Codec.decode_motion(broken).is_empty(), "truncated frame rejected")
	var nan_frame: PackedByteArray = bytes.duplicate()
	nan_frame.encode_float(36, NAN)
	check(Codec.decode_motion(nan_frame).is_empty(), "non-finite fuel rejected")

	# Budget: a full 8-captain server over one second, recipient 1's view.
	for spread: bool in [false, true]:
		var positions: Array[Vector3] = []
		for index: int in 8: positions.append(Vector3(index * (900.0 if spread else 40.0), 0, 0))
		var total: int = 0
		for tick: int in RATE_HZ:
			var picked: Array = []
			for index: int in 8:
				if index == 0 or Relevance.due(Relevance.near(positions[0], positions[index]), tick, index + 1):
					picked.append(ship_row(index + 1, positions[index], index == 3))
			total += Codec.encode_motion(own_state(), picked, PackedByteArray([0, 0, 0, 0])).size() + PACKET_OVERHEAD
		var per_ship: float = total / 8.0
		print("SNAPSHOT_BUDGET %s fleet: %.0f bytes per ship per second" % ["spread" if spread else "close", per_ship])
		check(per_ship < BUDGET_BYTES, "%.0f B/ship/s exceeds %.0f" % [per_ship, BUDGET_BYTES])
	var legacy: Dictionary = {}
	for index: int in 8: legacy["ship_%d" % index] = legacy_frame(index, Vector3(index * 40.0, 0, 0))
	var raw: PackedByteArray = var_to_bytes({"own": own_state(), "ships": legacy, "cranes": []})
	var legacy_per_ship: float = (raw.compress(FileAccess.COMPRESSION_FASTLZ).size() + 4 + 32 + PACKET_OVERHEAD) * RATE_HZ / 8.0
	print("SNAPSHOT_BUDGET 3.0.0 equivalent: %.0f bytes per ship per second" % legacy_per_ship)
	var edge: float = 2000.0 * PI
	check(Relevance.near(Vector3(750 - edge + 5, 0, 0), Vector3(750 + edge - 5, 0, 0)), "relevance measures across the world seam")
	check(not Relevance.near(Vector3.ZERO, Vector3(900, 0, 0)) and Relevance.due(false, 3, 1) and not Relevance.due(false, 1, 1), "far ships at a quarter rate")

	# Encode + decode cost of a full 8-ship frame.
	var full: Array = []
	for index: int in 8: full.append(ship_row(index + 1, Vector3(index * 40.0, 0, 0)))
	var started: int = Time.get_ticks_usec()
	for repeat: int in 200: Codec.decode_motion(Codec.encode_motion(own_state(), full, PackedByteArray([0, 0, 0, 0])))
	var cost: float = (Time.get_ticks_usec() - started) / 200.0
	print("SNAPSHOT_BUDGET encode+decode 8 ships: %.0f us" % cost)
	check(cost < 2000.0, "codec cost %.0f us" % cost)
	print("SNAPSHOT_BUDGET_%s checks=%d" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
