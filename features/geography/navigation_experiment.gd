extends RefCounted
## Experimental spherical navigation in scalar doubles; not a production save schema.
const Geo = preload("res://features/geography/geographic_address.gd")
const RADIUS_M: float = 100000.0
const LOCAL_RANGE_M: float = 1000.0

static func dot(a: Array, b: Array) -> float:
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]

static func frame(address: Dictionary) -> Array:
	var lat: float = deg_to_rad(address.latitude_deg)
	var lon: float = deg_to_rad(address.longitude_deg)
	return [[cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)],
		[-sin(lon), 0.0, cos(lon)],
		[-sin(lat) * cos(lon), cos(lat), -sin(lat) * sin(lon)]]

static func travel(address: Dictionary, distance_m: float, radius: float = RADIUS_M) -> Dictionary:
	if Geo.decode(address).is_empty() or not is_finite(distance_m) or not is_finite(radius) or radius <= 0.0: return {}
	var basis: Array = frame(address)
	var angle: float = distance_m / radius
	var bearing: float = deg_to_rad(address.heading_deg)
	var radial: Array = []
	var tangent: Array = []
	for index: int in range(3):
		var forward: float = basis[2][index] * cos(bearing) + basis[1][index] * sin(bearing)
		radial.append(basis[0][index] * cos(angle) + forward * sin(angle))
		tangent.append(forward * cos(angle) - basis[0][index] * sin(angle))
	var horizontal: float = sqrt(radial[0] * radial[0] + radial[2] * radial[2])
	var longitude: float = address.longitude_deg if horizontal < 1e-12 else rad_to_deg(atan2(radial[2], radial[0]))
	var result: Dictionary = Geo.normalized(rad_to_deg(atan2(radial[1], horizontal)), longitude, 0.0, address.altitude_m)
	var destination: Array = frame(result)
	result.heading_deg = Geo.wrap_scalar(rad_to_deg(atan2(dot(tangent, destination[1]), dot(tangent, destination[2]))), 0.0, 360.0)
	if result.heading_deg >= 360.0: result.heading_deg = 0.0
	return result

static func separation(a: Dictionary, b: Dictionary, radius: float = RADIUS_M) -> float:
	var u: Array = frame(a)[0]
	var v: Array = frame(b)[0]
	var cross: Array = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
	return atan2(sqrt(dot(cross, cross)), dot(u, v)) * radius

static func local_position(origin: Dictionary, address: Dictionary, radius: float = RADIUS_M) -> Vector3:
	# Azimuthal equidistant patch. Port is +X, geographic north is +Z.
	var basis: Array = frame(origin)
	var radial: Array = frame(address)[0]
	var east: float = dot(radial, basis[1])
	var north: float = dot(radial, basis[2])
	var sine: float = sqrt(east * east + north * north)
	var cosine: float = dot(radial, basis[0])
	if sine < 1e-12:
		return Vector3(0, address.altitude_m - origin.altitude_m, 0) if cosine > 0.0 else Vector3(INF, INF, INF)
	var scale_m: float = atan2(sine, cosine) * radius / sine
	return Vector3(-east * scale_m, address.altitude_m - origin.altitude_m, north * scale_m)

static func transport_rotation(old_origin: Dictionary, new_origin: Dictionary) -> float:
	# Parallel-transport chart north along the shortest origin-to-origin geodesic.
	var offset: Vector3 = local_position(old_origin, new_origin)
	if offset.length() < 1e-6: return 0.0
	var bearing: float = rad_to_deg(atan2(-offset.x, offset.z))
	var directed: Dictionary = old_origin.duplicate()
	directed.heading_deg = Geo.wrap_scalar(bearing, 0.0, 360.0)
	if directed.heading_deg >= 360.0: directed.heading_deg = 0.0
	var arrived: Dictionary = travel(directed, offset.length())
	return -deg_to_rad(Geo.longitude_delta(bearing, arrived.heading_deg))

static func reframe(roots: Array[Node3D], camera: OrbitCameraRig, shift: Vector3, angle: float) -> void:
	# Isolated experiment: all related roots must participate in one mapping change.
	var rotation: Basis = Basis(Vector3.UP, angle)
	for node: Node3D in roots:
		var pose: Transform3D = node.global_transform
		pose.origin = rotation * (pose.origin - shift)
		pose.basis = rotation * pose.basis
		node.global_transform = pose
		if node is CharacterBody3D: node.velocity = rotation * node.velocity
	camera.pivot = rotation * (camera.pivot - shift)
	camera.yaw += angle
	var camera_pose: Transform3D = camera.camera.global_transform
	camera_pose.origin = rotation * (camera_pose.origin - shift)
	camera_pose.basis = rotation * camera_pose.basis
	camera.camera.global_transform = camera_pose
