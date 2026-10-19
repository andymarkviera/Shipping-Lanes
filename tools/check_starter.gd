extends SceneTree
## Validate imported coordinates and wrapper ownership, not just source metadata.

const BASE: String = "res://features/ships/starter_container_01/"
var failures: Array[String] = []

func _initialize() -> void:
	check.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func check() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "asset_manifest.json"))
	var calibration: Node3D = load(BASE + "axis_calibration.glb").instantiate()
	root.add_child(calibration)
	var expected_axes: Dictionary = {"CAL_bow": Vector3(0, 0, 2), "CAL_port": Vector3(1, 0, 0),
		"CAL_starboard": Vector3(-1, 0, 0), "CAL_up": Vector3(0, 1, 0)}
	for key: String in expected_axes:
		var witness: Node3D = calibration.find_child(key, true, false)
		expect(witness != null and witness.global_position.is_equal_approx(expected_axes[key]), "Axis/scale: " + key)
	var ship: Node3D = load(BASE + "ship_starter_container_01.tscn").instantiate()
	root.add_child(ship)
	expect(ship.get_meta("asset_id") == "starter_container_01", "Stable asset ID")
	expect(ship.get_meta("ship_definition_id") == "ship_starter_container_01", "Stable ship definition ID")
	var nodes: Array[Node] = ship.find_children("*", "", true, false)
	var mesh_count: int = 0
	var full_bounds: AABB
	var has_bounds: bool = false
	for node: Node in nodes:
		expect(not node is CollisionObject3D, "Imported physics owner: " + str(node.name))
		expect(not str(node.name).begins_with("CARGO_") and not str(node.name).begins_with("Cargo_"), "Baked cargo: " + str(node.name))
		if node is MeshInstance3D:
			mesh_count += 1
			var local_bounds: AABB = node.global_transform * node.get_aabb()
			full_bounds = full_bounds.merge(local_bounds) if has_bounds else local_bounds
			has_bounds = true
	for socket_name: String in manifest.required_sockets:
		var matches: Array[Node] = ship.find_children(socket_name, "Node3D", true, false)
		expect(matches.size() == 1, "Missing/duplicate socket: " + socket_name)
		if matches.size() == 1:
			var position_data: Array = manifest.socket_positions[socket_name]
			var expected: Vector3 = Vector3(position_data[0], position_data[1], position_data[2])
			expect(matches[0].global_position.distance_to(expected) < 0.002, "Socket conversion: " + socket_name)
			var normal: Vector3 = Vector3.FORWARD * -1.0
			if socket_name == "SOCKET_name_port":
				normal = Vector3.RIGHT
			elif socket_name == "SOCKET_name_starboard":
				normal = Vector3.LEFT
			expect(matches[0].global_basis.z.distance_to(normal) < 0.002, "Socket forward/normal: " + socket_name)
			expect(matches[0].global_basis.y.distance_to(Vector3.UP) < 0.002, "Socket up: " + socket_name)
	for pivot_name: String in ["PIVOT_rudder_01", "PIVOT_propeller_01"]:
		expect(ship.find_children(pivot_name, "Node3D", true, false).size() == 1, "Pivot missing: " + pivot_name)
	expect(mesh_count == int(manifest.mesh_objects), "Mesh count mismatch")
	var lo: Array = manifest.empty_visual_bounds.min
	var hi: Array = manifest.empty_visual_bounds.max
	expect(full_bounds.position.distance_to(Vector3(lo[0], lo[1], lo[2])) < 0.02, "Imported minimum bounds mismatch")
	expect(full_bounds.end.distance_to(Vector3(hi[0], hi[1], hi[2])) < 0.02, "Imported maximum bounds mismatch")
	var shape: ConvexPolygonShape3D = ship.get_meta("collision_shape")
	expect(shape != null and shape.points.size() == manifest.collision_hull_points.size(), "Collision reference points")
	for index: int in shape.points.size():
		var point: Array = manifest.collision_hull_points[index]
		expect(shape.points[index].distance_to(Vector3(point[0], point[1], point[2])) < 0.001, "Collision point mismatch")
	print("STARTER_CHECK meshes=", mesh_count, " bounds=", full_bounds, " sockets=", manifest.required_sockets.size())
	for failure: String in failures:
		push_error(failure)
	ship.free()
	calibration.free()
	print("STARTER_CHECK_PASS" if failures.is_empty() else "STARTER_CHECK_FAILED")
	quit(0 if failures.is_empty() else 1)
