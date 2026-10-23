extends Node
const Codec = preload("res://features/network/public_snapshot_codec.gd")
var checks: int = 0
func verify(value: bool) -> void:
	assert(value)
	if not value: get_tree().quit(1)
	checks += 1
func _ready() -> void:
	var rows: Array = []
	for i: int in 8:
		rows.append({"ship": "00000000-0000-0000-0000-%012d" % i, "generation": 2, "position": Vector3(i * 70, 0, 12.345), "yaw": 0.123})
	var bytes: PackedByteArray = Codec.encode(rows, 42, 799.25, 3.4, 200)
	verify(bytes.size() == 352)
	var decoded: Dictionary = Codec.decode(bytes)
	verify(decoded.rows.size() == 8 and decoded.sequence == 42 and decoded.fuel == 799.25)
	verify(decoded.rows[7].position.distance_to(rows[7].position) < 0.001)
	for length_: int in [0, 31, 32, 351, 353, 1201]:
		var bad: PackedByteArray = bytes.duplicate(); bad.resize(length_)
		verify(Codec.decode(bad).is_empty())
	for offset: int in [16, 24, 28, 56, 60, 64, 68]:
		var bad: PackedByteArray = bytes.duplicate()
		if offset == 16: bad.encode_double(offset, NAN)
		else: bad.encode_float(offset, NAN)
		verify(Codec.decode(bad).is_empty())
	var bad: PackedByteArray = bytes.duplicate(); bad.encode_u32(0, 99)
	verify(Codec.decode(bad).is_empty())
	bad = bytes.duplicate(); bad.encode_s64(8, -2)
	verify(Codec.decode(bad).is_empty())
	bad = bytes.duplicate(); bad.encode_s64(48, 0)
	verify(Codec.decode(bad).is_empty())
	bad = bytes.duplicate(); bad.encode_float(56, 2000)
	verify(Codec.decode(bad).is_empty())
	bad = bytes.duplicate()
	for j: int in 16: bad[72+j] = bad[32+j]
	verify(Codec.decode(bad).is_empty())
	# Full frames do not depend on delivery of any earlier frame.
	verify(Codec.decode(Codec.encode(rows, 100, 790, 5, 250)).sequence == 100)
	var legacy: int = var_to_bytes([rows]).size() + var_to_bytes([rows[0].ship, 1, 2, Vector3.ZERO, 0.0, Vector3.ZERO, 799.25, 42]).size()
	var compact: int = var_to_bytes([rows[0].ship, 1, 2, 1, [bytes]]).size()
	verify(compact <= 1200 and compact * 10 < legacy * 5)
	print("COMPACT_NETWORK_PASS checks=", checks, " payload=", bytes.size(), " compact_args=", compact, " legacy_lower_bound_args=", legacy, " compact_bytes_per_second=", compact*10, " legacy_lower_bound_bytes_per_second=", legacy*5)
	get_tree().quit()
