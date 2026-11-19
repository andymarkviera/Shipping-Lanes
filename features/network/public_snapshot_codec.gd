extends RefCounted
## Fixed-size complete snapshots: loss needs no delta history or chunk assembly.
const HEADER: int = 36
const RECORD: int = 40
const MAX_SHIPS: int = 8
const MAX_BYTES: int = HEADER + RECORD * MAX_SHIPS

static func valid_id(value: String) -> bool:
	return value.length() == 36 and value[8] == "-" and value[13] == "-" and value[18] == "-" and value[23] == "-" and value.replace("-", "").length() == 32 and value.replace("-", "").is_valid_hex_number()

static func encode(rows: Array, sequence: int, fuel: float, speed: float, distance_: float, forward_speed: float = 0.0) -> PackedByteArray:
	var bytes: PackedByteArray = []
	if rows.size() > MAX_SHIPS: return bytes
	bytes.resize(HEADER + rows.size() * RECORD)
	bytes.encode_u32(0, 2)
	bytes.encode_u32(4, rows.size())
	bytes.encode_s64(8, sequence)
	bytes.encode_double(16, fuel)
	bytes.encode_float(24, speed)
	bytes.encode_float(28, distance_)
	bytes.encode_float(32, forward_speed)
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		if not valid_id(row.ship): return PackedByteArray()
		var at: int = HEADER + i * RECORD
		var hex: String = row.ship.replace("-", "")
		for j: int in 16: bytes[at + j] = hex.substr(j * 2, 2).hex_to_int()
		bytes.encode_s64(at + 16, row.generation)
		bytes.encode_float(at + 24, row.position.x)
		bytes.encode_float(at + 28, row.position.y)
		bytes.encode_float(at + 32, row.position.z)
		bytes.encode_float(at + 36, row.yaw)
	return bytes

static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER or bytes.size() > MAX_BYTES or bytes.decode_u32(0) != 2: return {}
	var count: int = bytes.decode_u32(4)
	if count > MAX_SHIPS or bytes.size() != HEADER + count * RECORD: return {}
	var sequence: int = bytes.decode_s64(8)
	var fuel: float = bytes.decode_double(16)
	var speed: float = bytes.decode_float(24)
	var distance_: float = bytes.decode_float(28)
	var forward_speed: float = bytes.decode_float(32)
	if not is_finite(forward_speed) or absf(forward_speed) > speed + 0.001: return {}
	if sequence < -1 or sequence > 2147483647 or not is_finite(fuel) or fuel < 0 or fuel > 1000 or not is_finite(speed) or speed < 0 or not is_finite(distance_) or distance_ < 0: return {}
	var rows: Array = []
	var ids: Dictionary = {}
	for i: int in count:
		var at: int = HEADER + i * RECORD
		var hex: String = bytes.slice(at, at + 16).hex_encode()
		var id: String = "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
		var generation: int = bytes.decode_s64(at + 16)
		var position_: Vector3 = Vector3(bytes.decode_float(at + 24), bytes.decode_float(at + 28), bytes.decode_float(at + 32))
		var yaw: float = bytes.decode_float(at + 36)
		if not valid_id(id) or ids.has(id) or generation < 1 or generation > 9000000000000 or not position_.is_finite() or position_.length() > 1001 or not is_finite(yaw): return {}
		ids[id] = true
		rows.append({"ship": id, "generation": generation, "position": position_, "yaw": yaw})
	return {"rows": rows, "sequence": sequence, "fuel": fuel, "speed": speed, "forward_speed": forward_speed, "distance": distance_}

# --- Patch 3.0.1 item 3: dedicated-server motion frames -------------------------
# One unreliable binary frame per recipient per send tick. Positions are fixed
# point (1/256 m), yaw is a u16 turn fraction, rates and velocities are halves.
# Slow-changing ship status travels separately, reliably and only on change.
const MOTION_FORMAT: int = 3
const MOTION_HEADER: int = 44
const MOTION_RECORD: int = 32
const MOTION_HEAVY: int = 26
const MOTION_MAX_SHIPS: int = 16
const POSITION_SCALE: float = 256.0
const ORDER_SCALE: float = 16384.0
const FLAG_HEAVY: int = 1

static func put_position(bytes: PackedByteArray, at: int, value: Vector3) -> void:
	bytes.encode_s32(at, roundi(clampf(value.x, -8.0e6, 8.0e6) * POSITION_SCALE))
	bytes.encode_s32(at + 4, roundi(clampf(value.z, -8.0e6, 8.0e6) * POSITION_SCALE))

static func put_yaw(bytes: PackedByteArray, at: int, yaw: float) -> void:
	bytes.encode_u16(at, roundi(fposmod(yaw, TAU) / TAU * 65536.0) & 0xFFFF)

static func get_yaw(bytes: PackedByteArray, at: int) -> float:
	return wrapf(bytes.decode_u16(at) / 65536.0 * TAU, -PI, PI)

static func put_unit(bytes: PackedByteArray, at: int, value: float) -> void:
	bytes.encode_s8(at, clampi(roundi((value if is_finite(value) else 0.0) * 127.0), -127, 127))

static func put_order(bytes: PackedByteArray, at: int, value: float) -> void:
	bytes.encode_s16(at, clampi(roundi((value if is_finite(value) else 0.0) * ORDER_SCALE), -32767, 32767))

## Encode one recipient's frame. `own` is a Dictionary with ack, position, yaw,
## velocity, ground_speed, yaw_rate, engine, throttle, rudder, lateral, fuel,
## condition. Each row: peer, position, yaw, velocity, speed, yaw_rate, engine,
## throttle, rudder, lateral, remaining and optional heavy {height, pose}.
static func encode_motion(own: Dictionary, rows: Array, cranes: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	if rows.size() > MOTION_MAX_SHIPS or cranes.size() > 60000: return bytes
	var size: int = MOTION_HEADER + cranes.size()
	for row: Dictionary in rows: size += MOTION_RECORD + (MOTION_HEAVY if row.has("heavy") else 0)
	bytes.resize(size)
	bytes.encode_u8(0, MOTION_FORMAT)
	bytes.encode_u8(1, rows.size())
	bytes.encode_u16(2, cranes.size())
	bytes.encode_u32(4, clampi(own.ack, 0, 2147483647))
	put_position(bytes, 8, own.position)
	bytes.encode_half(16, own.position.y)
	put_yaw(bytes, 18, own.yaw)
	bytes.encode_half(20, own.velocity.x)
	bytes.encode_half(22, own.velocity.z)
	bytes.encode_half(24, own.ground_speed)
	bytes.encode_half(26, own.yaw_rate)
	put_order(bytes, 28, own.engine)
	put_order(bytes, 30, own.throttle)
	put_unit(bytes, 32, own.rudder)
	put_unit(bytes, 33, own.lateral)
	bytes.encode_float(36, own.fuel)
	bytes.encode_float(40, own.condition)
	var at: int = MOTION_HEADER
	for row: Dictionary in rows:
		bytes.encode_u32(at, row.peer)
		put_position(bytes, at + 4, row.position)
		bytes.encode_half(at + 12, row.position.y)
		put_yaw(bytes, at + 14, row.yaw)
		bytes.encode_half(at + 16, row.velocity.x)
		bytes.encode_half(at + 18, row.velocity.z)
		bytes.encode_half(at + 20, row.speed)
		bytes.encode_half(at + 22, row.yaw_rate)
		put_unit(bytes, at + 24, row.engine)
		put_unit(bytes, at + 25, row.throttle)
		put_unit(bytes, at + 26, row.rudder)
		put_unit(bytes, at + 27, row.lateral)
		bytes.encode_half(at + 28, row.remaining)
		bytes.encode_u8(at + 30, FLAG_HEAVY if row.has("heavy") else 0)
		at += MOTION_RECORD
		if row.has("heavy"):
			var pose: Transform3D = row.heavy.pose
			var turn: Quaternion = pose.basis.get_rotation_quaternion()
			# Deck height is compared exactly against RAISED/LOWERED: keep f64.
			bytes.encode_double(at, row.heavy.height)
			put_position(bytes, at + 8, pose.origin)
			bytes.encode_half(at + 16, pose.origin.y)
			var parts: Array[float] = [turn.x, turn.y, turn.z, turn.w]
			for index: int in 4: bytes.encode_s16(at + 18 + index * 2, clampi(roundi(parts[index] * 32767.0), -32767, 32767))
			at += MOTION_HEAVY
	for index: int in cranes.size(): bytes[at + index] = cranes[index]
	return bytes

## Returns {} for anything malformed or non-finite. Otherwise {own, rows, cranes}.
static func decode_motion(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < MOTION_HEADER or bytes.decode_u8(0) != MOTION_FORMAT: return {}
	var count: int = bytes.decode_u8(1)
	var crane_size: int = bytes.decode_u16(2)
	if count > MOTION_MAX_SHIPS or bytes.size() < MOTION_HEADER + count * MOTION_RECORD + crane_size: return {}
	var own: Dictionary = {"ack": bytes.decode_u32(4),
		"position": Vector3(bytes.decode_s32(8) / POSITION_SCALE, bytes.decode_half(16), bytes.decode_s32(12) / POSITION_SCALE),
		"yaw": get_yaw(bytes, 18), "velocity": Vector3(bytes.decode_half(20), 0.0, bytes.decode_half(22)),
		"ground_speed": bytes.decode_half(24), "yaw_rate": bytes.decode_half(26),
		"engine": bytes.decode_s16(28) / ORDER_SCALE, "throttle": bytes.decode_s16(30) / ORDER_SCALE,
		"rudder": bytes.decode_s8(32) / 127.0, "lateral": bytes.decode_s8(33) / 127.0,
		"fuel": bytes.decode_float(36), "condition": bytes.decode_float(40)}
	if not own.position.is_finite() or not own.velocity.is_finite() or not is_finite(own.ground_speed) or not is_finite(own.yaw_rate): return {}
	if not is_finite(own.fuel) or own.fuel < 0 or not is_finite(own.condition): return {}
	var rows: Array = []
	var at: int = MOTION_HEADER
	for index: int in count:
		if bytes.size() < at + MOTION_RECORD + crane_size: return {}
		var row: Dictionary = {"peer": bytes.decode_u32(at),
			"position": Vector3(bytes.decode_s32(at + 4) / POSITION_SCALE, bytes.decode_half(at + 12), bytes.decode_s32(at + 8) / POSITION_SCALE),
			"yaw": get_yaw(bytes, at + 14), "velocity": Vector3(bytes.decode_half(at + 16), 0.0, bytes.decode_half(at + 18)),
			"speed": bytes.decode_half(at + 20), "yaw_rate": bytes.decode_half(at + 22),
			"engine": bytes.decode_s8(at + 24) / 127.0, "throttle": bytes.decode_s8(at + 25) / 127.0,
			"rudder": bytes.decode_s8(at + 26) / 127.0, "lateral": bytes.decode_s8(at + 27) / 127.0,
			"remaining": bytes.decode_half(at + 28)}
		var flags: int = bytes.decode_u8(at + 30)
		at += MOTION_RECORD
		if not row.position.is_finite() or not row.velocity.is_finite() or not is_finite(row.speed) or not is_finite(row.yaw_rate) or not is_finite(row.remaining): return {}
		if flags & FLAG_HEAVY:
			if bytes.size() < at + MOTION_HEAVY + crane_size: return {}
			var turn: Quaternion = Quaternion(bytes.decode_s16(at + 18) / 32767.0, bytes.decode_s16(at + 20) / 32767.0, bytes.decode_s16(at + 22) / 32767.0, bytes.decode_s16(at + 24) / 32767.0)
			if turn.length_squared() < 0.5: return {}
			var origin: Vector3 = Vector3(bytes.decode_s32(at + 8) / POSITION_SCALE, bytes.decode_half(at + 16), bytes.decode_s32(at + 12) / POSITION_SCALE)
			var height: float = bytes.decode_double(at)
			if not origin.is_finite() or not is_finite(height): return {}
			row.heavy = {"height": height, "pose": Transform3D(Basis(turn.normalized()), origin)}
			at += MOTION_HEAVY
		rows.append(row)
	if bytes.size() != at + crane_size: return {}
	return {"own": own, "rows": rows, "cranes": bytes.slice(at, at + crane_size)}
