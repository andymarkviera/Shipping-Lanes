extends Node3D
const Nav = preload("res://features/geography/navigation_experiment.gd")
const Geo = preload("res://features/geography/geographic_address.gd")
var checks: int = 0
var failures: int = 0
var fixtures: Array[Dictionary] = []
var pairs: Array[Dictionary] = []
var tick: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _ready() -> void:
	check_geography()
	# Unshifted controls reveal precision loss; +/-1 km is our local patch budget.
	for offset: float in [0.0, 1000.0, -1000.0, 100000.0, 1000000.0, 10000000.0]:
		add_fixture(offset)
	for address: Dictionary in [Geo.normalized(0, 179.98, 90), Geo.normalized(89.98, 20, 0)]:
		add_pair(address)

func add_pair(address: Dictionary) -> void:
	var base: Vector3 = Vector3(3000 + pairs.size() * 300, 0, 0)
	var ship: HandlingShip = HandlingShip.new()
	ship.position = base
	ship.rotation.y = -deg_to_rad(address.heading_deg)
	ship.velocity = ship.basis.z * 20
	CollisionRules.add_box_hull(ship)
	add_child(ship)
	var other: HandlingShip = HandlingShip.new()
	other.position = base + Nav.local_position(address, Nav.travel(address, 80))
	other.rotation.y = ship.rotation.y
	CollisionRules.add_box_hull(other)
	add_child(other)
	other.set_physics_process(false)
	check(absf(ship.position.distance_to(other.position) - 80) < 0.001, "Opposite seam/pole hulls share one local collision space")
	pairs.append({"ship": ship, "other": other, "contact": false})

func check_geography() -> void:
	check(Nav.travel(Geo.normalized(0, 0), 1, 0).is_empty(), "Invalid radius rejected")
	for origin: Dictionary in [Geo.normalized(0, 179.999, 90), Geo.normalized(89.999, 20, 0), Geo.normalized(-89.999, 20, 180), Geo.normalized(90, 20, 0)]:
		var position_now: Dictionary = origin
		for index: int in range(500):
			var next: Dictionary = Nav.travel(position_now, 1.0)
			if next.is_empty():
				check(false, "Invalid travel from " + JSON.stringify(position_now))
				return
			check(absf(Nav.separation(position_now, next) - 1.0) < 0.00001, "One-meter seam/pole advance")
			position_now = next
		check(absf(Nav.separation(origin, position_now) - 500.0) < 0.001, "Seam/pole path length")
		check(absf(Nav.local_position(origin, position_now).length() - 500.0) < 0.001, "Local marker matches navigation distance")
		var restored: Dictionary = Geo.decode(JSON.parse_string(JSON.stringify(position_now)))
		check(Nav.separation(restored, position_now) < 0.000001, "Scalar address round trip")
		var angle: float = Nav.transport_rotation(origin, position_now)
		check(is_finite(angle), "Chart rotation remains finite at poles")
	var start: Dictionary = Geo.normalized(0, 179, 90)
	var current: Dictionary = start
	for index: int in range(3600): current = Nav.travel(current, TAU * Nav.RADIUS_M / 3600.0)
	check(Nav.separation(start, current) < 0.001, "Complete circuit returns to start within one millimeter")
	check(absf(Geo.longitude_delta(start.heading_deg, current.heading_deg)) < 0.000001, "Full circuit preserves transported heading")
	start = Geo.normalized(0, 20, 0)
	current = start
	for index: int in range(3600): current = Nav.travel(current, TAU * Nav.RADIUS_M / 3600.0)
	check(Nav.separation(start, current) < 0.001, "Meridian circuit crosses both poles and returns")
	var patch: Dictionary = Geo.normalized(0, 0, 90)
	var edge: Dictionary = Nav.travel(patch, 900)
	edge.heading_deg = 0.0
	var neighbor: Dictionary = Nav.travel(edge, 200)
	var planar_distance: float = Nav.local_position(patch, edge).distance_to(Nav.local_position(patch, neighbor))
	print("WORLD_PATCH 200m_neighbor_at_900m_edge_error_m=%.9f" % absf(planar_distance - 200.0))
	check(absf(planar_distance - 200.0) < 0.005, "Nearby collision marker projection error under 5 mm near patch edge")
	for radius: float in [50000.0, 100000.0, 250000.0]:
		print("WORLD_TRAVEL radius_m=%.0f circuit_km=%.3f circuit_hours_at_10mps=%.3f medium_10deg_minutes=%.3f" % [radius, TAU * radius / 1000.0, TAU * radius / 10.0 / 3600.0, deg_to_rad(10.0) * radius / 10.0 / 60.0])
	print("WORLD_TRAVEL synthetic_local_2km_minutes=3.333 longest_180deg_hours_at_100km_radius=8.727")

func add_fixture(offset: float) -> void:
	var base: Vector3 = Vector3(offset, 0, offset)
	var ship: HandlingShip = HandlingShip.new()
	ship.position = base
	ship.velocity = Vector3(0, 0, 0.1)
	CollisionRules.add_box_hull(ship)
	add_child(ship)
	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = base + Vector3(0, 0, 40)
	wall.collision_layer = CollisionRules.SHORE
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(100, 20, 0.1)
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)
	var focus: CameraFocus = CameraFocus.new()
	focus.position = Vector3(0, 5, 0)
	focus.hull_radius = 34
	focus.collision_body = ship
	ship.add_child(focus)
	var camera: OrbitCameraRig = OrbitCameraRig.new()
	add_child(camera)
	camera.set_focus(focus)
	fixtures.append({"offset": offset, "base": base, "ship": ship, "wall": wall, "camera": camera, "contact": false, "slow_distance": 0.0})

func _physics_process(_delta: float) -> void:
	tick += 1
	for item: Dictionary in fixtures:
		item.contact = item.contact or item.ship.get_slide_collision_count() > 0
	for pair: Dictionary in pairs:
		pair.contact = pair.contact or pair.ship.get_slide_collision_count() > 0
	if tick == 61:
		for item: Dictionary in fixtures:
			item.slow_distance = item.ship.position.z - item.base.z
			item.ship.velocity = Vector3(0, 0, 20)
	if tick == 181:
		for item: Dictionary in fixtures:
			var relative: Vector3 = item.ship.position - item.base
			var camera_error: float = item.camera.pivot.distance_to(item.camera.focus.global_position)
			print("WORLD_PRECISION offset_m=%.0f slow_1s_m=%.9f pier_stop_z=%.6f contact=%s camera_lag_m=%.6f" % [item.offset, item.slow_distance, relative.z, item.contact, camera_error])
			if absf(item.offset) <= Nav.LOCAL_RANGE_M:
				check(absf(item.slow_distance - fixtures[0].slow_distance) < 0.005, "Local slow movement error under 5 mm")
				check(item.contact and relative.z <= 7.951 and relative.z > 7.8, "Local thin pier blocks maximum-speed hull")
				check(camera_error < 0.01 and item.camera.camera.global_transform.is_finite(), "Local camera settles without precision jump")
		check(fixtures.back().slow_distance < fixtures[0].slow_distance * 0.5, "Unbounded float32 control demonstrates loss of slow movement")
		for pair: Dictionary in pairs:
			check(pair.contact and pair.ship.position.distance_to(pair.other.position) >= 63.99, "Hull contact remains solid across seam/polar addresses")
			pair.ship.queue_free()
			pair.other.queue_free()
		pairs.clear()
		check_reframe()
		for item: Dictionary in fixtures:
			if item != fixtures[1]:
				item.ship.queue_free()
				item.wall.queue_free()
				item.camera.queue_free()
		fixtures = [fixtures[1]]
	if tick == 186:
		check(fixtures[0].ship.get_slide_collision_count() > 0, "Physics contact survives reframing after broadphase synchronization")
		set_physics_process(false)
		print("WORLD_SIZE_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
		get_tree().quit(0 if failures == 0 else 1)

func check_reframe() -> void:
	var item: Dictionary = fixtures[1]
	var ship: HandlingShip = item.ship
	var camera: OrbitCameraRig = item.camera
	var before: Vector3 = camera.camera.to_local(ship.global_position)
	var relative_wall: Vector3 = ship.to_local(item.wall.global_position)
	ship.velocity = Vector3(3, 0, 4)
	var local_velocity: Vector3 = ship.global_basis.inverse() * ship.velocity
	var payload: Node3D = Node3D.new()
	payload.position = Vector3(0, 4, 10)
	ship.add_child(payload)
	var payload_before: Vector3 = ship.to_local(payload.global_position)
	var angle: float = Nav.transport_rotation(Geo.normalized(89.999, 20, 0), Nav.travel(Geo.normalized(89.999, 20, 0), 500))
	var roots: Array[Node3D] = [ship, item.wall]
	Nav.reframe(roots, camera, ship.global_position, angle)
	check(ship.global_position.length() < 0.001, "Chart change recenters active ship")
	check(camera.camera.to_local(ship.global_position).distance_to(before) < 0.001, "Polar chart change preserves camera-relative view")
	check(ship.to_local(item.wall.global_position).distance_to(relative_wall) < 0.001, "Chart change preserves relative solid marker")
	check((ship.global_basis.inverse() * ship.velocity).distance_to(local_velocity) < 0.00001, "Chart change transports velocity with heading")
	check(is_equal_approx(ship.velocity.length(), 5.0), "Chart change preserves speed")
	check(ship.to_local(payload.global_position).distance_to(payload_before) < 0.001, "Attached visual follows frame mapping once")
