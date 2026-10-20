extends RefCounted
## Versioned experimental envelope. Geographic identity outlives local chart poses.
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")

static func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func finite_vector(value: Variant, limit: float) -> bool:
	if not value is Array or value.size() != 3: return false
	for component: Variant in value:
		if not (component is float or component is int) or not is_finite(component) or absf(component) > limit: return false
	return true

static func unpack(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func valid(data: Variant, epoch: String, entity: String, previous: int = -1) -> bool:
	if not data is Dictionary: return false
	if data.get("schema") != 1 or data.get("epoch") != epoch or data.get("entity") != entity or data.get("owner") != 1: return false
	if not data.get("revision") is int or data.revision <= previous: return false
	if data.get("radius_m") != Nav.RADIUS_M: return false
	if Geo.decode(data.get("origin")).is_empty() or Geo.decode(data.get("address")).is_empty(): return false
	if not finite_vector(data.get("position"), 1000) or not finite_vector(data.get("velocity"), 100): return false
	if not finite_vector(data.get("marker"), 1000): return false
	if not (data.get("yaw") is float or data.get("yaw") is int) or not is_finite(data.yaw): return false
	if data.get("payload") != entity + "_payload" or data.get("attached") != true: return false
	# The ship address and chart position must describe the same point.
	return Nav.local_position(data.origin, data.address).distance_to(unpack(data.position)) < 0.005

static func decode_json(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary: return {}
	# JSON stores integers as floats. Restore only exact integer fields.
	for field: String in ["schema", "owner", "revision"]:
		var value: Variant = parsed.get(field)
		if not (value is float or value is int) or not is_finite(value) or value != floor(value) or absf(value) > 2147483647: return {}
		parsed[field] = int(value)
	return parsed
