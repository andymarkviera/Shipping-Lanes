class_name GeographicAddress
extends RefCounted
## Draft scalar address: never serialize float32 scene vectors as identity.
const WORLD_ID: String = "world_coordinate_fixture"
const CONTENT_REVISION: int = 1
const FRAME: String = "meridian_tangent_v1"

static func normalized(latitude: float, longitude: float, heading: float = 0.0, altitude: float = 0.0) -> Dictionary:
	if not is_finite(latitude) or not is_finite(longitude) or not is_finite(heading) or not is_finite(altitude):
		return {}
	var lat: float = wrap_scalar(latitude, -180.0, 360.0)
	var lon: float = longitude
	# Reflection across a pole also moves the reference meridian by 180 degrees.
	if lat > 90.0:
		lat = 180.0 - lat
		lon += 180.0
	elif lat < -90.0:
		lat = -180.0 - lat
		lon += 180.0
	return {"world_id": WORLD_ID, "content_revision": CONTENT_REVISION,
		"latitude_deg": lat, "longitude_deg": wrap_scalar(lon, -180.0, 360.0),
		"altitude_m": altitude, "heading_deg": wrap_scalar(heading, 0.0, 360.0), "frame": FRAME}

static func decode(data: Variant) -> Dictionary:
	if not data is Dictionary or data.size() != 7:
		return {}
	if not (data.get("content_revision") is int or data.get("content_revision") is float):
		return {}
	if data.get("world_id") != WORLD_ID or data.get("content_revision") != CONTENT_REVISION or data.get("frame") != FRAME:
		return {}
	for field: String in ["latitude_deg", "longitude_deg", "altitude_m", "heading_deg"]:
		if not (data.get(field) is float or data.get(field) is int) or not is_finite(float(data[field])):
			return {}
	if data.latitude_deg < -90.0 or data.latitude_deg > 90.0 or data.longitude_deg < -180.0 or data.longitude_deg >= 180.0 or data.heading_deg < 0.0 or data.heading_deg >= 360.0:
		return {}
	return normalized(data.latitude_deg, data.longitude_deg, data.heading_deg, data.altitude_m)

static func globe(address: Dictionary) -> Vector3:
	var lat: float = deg_to_rad(address.latitude_deg)
	var lon: float = deg_to_rad(address.longitude_deg)
	return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))

static func from_globe(direction: Vector3, pole_meridian_deg: float = 0.0) -> Dictionary:
	if not direction.is_finite() or direction.length_squared() < 0.000000000001 or not is_finite(pole_meridian_deg):
		return {}
	var radial: float = sqrt(float(direction.x) * direction.x + float(direction.z) * direction.z)
	var longitude: float = pole_meridian_deg if radial < 0.00000001 else rad_to_deg(atan2(direction.z, direction.x))
	return normalized(rad_to_deg(atan2(direction.y, radial)), longitude)

static func flat(address: Dictionary) -> Dictionary:
	# Equirectangular normalized coordinates; scalar doubles preserve precision.
	return {"u": (address.longitude_deg + 180.0) / 360.0, "v": (90.0 - address.latitude_deg) / 180.0}

static func from_flat(u: float, v: float) -> Dictionary:
	if not is_finite(u) or not is_finite(v) or v < 0.0 or v > 1.0:
		return {}
	return normalized(90.0 - v * 180.0, wrap_scalar(u, 0.0, 1.0) * 360.0 - 180.0)

static func longitude_delta(from_deg: float, to_deg: float) -> float:
	return wrap_scalar(to_deg - from_deg, -180.0, 360.0)

static func tangent_frame(address: Dictionary) -> Basis:
	var lat: float = deg_to_rad(address.latitude_deg)
	var lon: float = deg_to_rad(address.longitude_deg)
	var east: Vector3 = Vector3(-sin(lon), 0.0, cos(lon))
	var north: Vector3 = Vector3(-sin(lat) * cos(lon), cos(lat), -sin(lat) * sin(lon))
	return Basis(east, globe(address), north)

static func forward(address: Dictionary) -> Vector3:
	var angle: float = deg_to_rad(address.heading_deg)
	var frame: Basis = tangent_frame(address)
	return frame.z * cos(angle) + frame.x * sin(angle)

static func angular_separation(a: Dictionary, b: Dictionary) -> float:
	# atan2 keeps small seam distances stable; result is radians, not world meters.
	var x: Vector3 = globe(a)
	var y: Vector3 = globe(b)
	return atan2(x.cross(y).length(), x.dot(y))

static func wrap_scalar(value: float, minimum: float, span: float) -> float:
	# Avoid approximate endpoint equality in wrapf near longitude +180.
	return value - span * floor((value - minimum) / span)
