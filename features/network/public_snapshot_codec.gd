extends RefCounted
## Fixed-size complete snapshots: loss needs no delta history or chunk assembly.
const HEADER: int = 32
const RECORD: int = 40
const MAX_SHIPS: int = 8
const MAX_BYTES: int = HEADER + RECORD * MAX_SHIPS

static func valid_id(value: String) -> bool:
	return value.length() == 36 and value[8] == "-" and value[13] == "-" and value[18] == "-" and value[23] == "-" and value.replace("-", "").length() == 32 and value.replace("-", "").is_valid_hex_number()

static func encode(rows: Array, sequence: int, fuel: float, speed: float, distance_: float) -> PackedByteArray:
	var bytes: PackedByteArray = []
	if rows.size() > MAX_SHIPS: return bytes
	bytes.resize(HEADER + rows.size() * RECORD)
	bytes.encode_u32(0, 1)
	bytes.encode_u32(4, rows.size())
	bytes.encode_s64(8, sequence)
	bytes.encode_double(16, fuel)
	bytes.encode_float(24, speed)
	bytes.encode_float(28, distance_)
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
	if bytes.size() < HEADER or bytes.size() > MAX_BYTES or bytes.decode_u32(0) != 1: return {}
	var count: int = bytes.decode_u32(4)
	if count > MAX_SHIPS or bytes.size() != HEADER + count * RECORD: return {}
	var sequence: int = bytes.decode_s64(8)
	var fuel: float = bytes.decode_double(16)
	var speed: float = bytes.decode_float(24)
	var distance_: float = bytes.decode_float(28)
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
	return {"rows": rows, "sequence": sequence, "fuel": fuel, "speed": speed, "distance": distance_}
