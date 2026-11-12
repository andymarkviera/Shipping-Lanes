extends RefCounted
## Read-only readiness, not permission to mutate a ship or complete a transaction.
static func result(code: String, message: String) -> Dictionary:
	return {"eligible": code == "READY", "code": code, "message": message}

static func evaluate(berth: BerthDefinition, anchor: Transform3D, ship: ShipDefinition, pose: Transform3D, velocity: Vector3, service: String, cargo_id: String, space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []) -> Dictionary:
	if berth == null or ship == null or not berth.eligibility_error().is_empty() or not ship.handling_error().is_empty():
		return result("INVALID_DATA", "Berth or ship data is unavailable.")
	if not pose.is_finite() or not anchor.is_finite() or not velocity.is_finite() or not pose.basis.is_equal_approx(pose.basis.orthonormalized()) or not anchor.basis.is_equal_approx(anchor.basis.orthonormalized()):
		return result("INVALID_DATA", "Berth or ship position is unavailable.")
	if service.is_empty() or not berth.service_ids.has(service):
		return result("SERVICE", "This berth does not offer the requested service.")
	if not cargo_id.is_empty() and (not ship.cargo_type_ids.has(cargo_id) or not berth.cargo_type_ids.has(cargo_id)):
		return result("CARGO", "This ship and berth cannot handle the selected cargo.")
	var size: Vector3 = ship.hull_size_m + Vector3.ONE * berth.clearance_margin_m * 2
	if size.x > berth.envelope_m.x or size.y > berth.envelope_m.y or size.z > berth.envelope_m.z:
		return result("SIZE", "This ship is too large for the berth.")
	var local: Transform3D = anchor.affine_inverse() * pose.translated_local(Vector3(0, 1, 0))
	var bounds: AABB = local * AABB(-size / 2, size)
	var zone: AABB = AABB(-berth.envelope_m / 2, berth.envelope_m)
	if not zone.encloses(bounds):
		var offset: Vector3 = pose.affine_inverse() * anchor.origin
		return result("POSITION", "Berth centre: %.0f m %s, %.0f m %s. Align alongside the quay." % [absf(offset.x), "starboard" if offset.x > 0 else "port", absf(offset.z), "ahead" if offset.z > 0 else "astern"])
	if velocity.length() > berth.max_docking_speed_mps + 0.000001:
		return result("SPEED", "Slow to %.2f m/s or less to dock." % berth.max_docking_speed_mps)
	var heading_error: float = rad_to_deg(acos(clampf(pose.basis.z.dot(anchor.basis.z), -1, 1)))
	if heading_error > berth.max_heading_error_degrees + 0.0001:
		return result("HEADING", "Align with the berth direction (within %.0f degrees)." % berth.max_heading_error_degrees)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose.translated_local(Vector3(0, 1, 0))
	query.collision_mask = CollisionRules.HULL | CollisionRules.CARGO_VISUAL
	query.collide_with_areas = true
	query.exclude = exclude
	if not space.intersect_shape(query, 1).is_empty():
		return result("BLOCKED", "Keep clear of boats, cargo and dock structures.")
	# Keep the padded buffer around other boats/cargo, but mooring is allowed
	# against the quay. Only actual hull overlap blocks shore eligibility.
	# A 1 cm inset per face avoids classifying exact surface contact as penetration;
	# physical hull/shore collision remains unchanged.
	var shore_shape: BoxShape3D = BoxShape3D.new()
	shore_shape.size = ship.hull_size_m - Vector3.ONE * .02
	query.shape = shore_shape
	query.collision_mask = CollisionRules.SHORE
	query.margin = 0
	if not space.intersect_shape(query, 1).is_empty():
		return result("BLOCKED", "The hull overlaps a dock structure. Move clear, then dock alongside.")
	return result("READY", "Ready to dock — select Dock.")

## Patch 2.0 easy docking, single-player. Near + slow = Dock works; the docking
## authority then slides the ship to berth_pose(). No angle or fit-in-box rule.
## Messages say only what to do.
const EASY_RANGE_M: float = 45.0
const EASY_SPEED_MPS: float = 3.0

## Where the slide ends: the berth centre and heading, at the ship's own height.
static func berth_pose(anchor: Transform3D, pose: Transform3D) -> Transform3D:
	var target: Transform3D = anchor
	target.origin += anchor.basis.y * (anchor.affine_inverse() * pose.origin).y
	return target

static func evaluate_easy(berth: BerthDefinition, anchor: Transform3D, ship: ShipDefinition, pose: Transform3D, velocity: Vector3, service: String, cargo_id: String, space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []) -> Dictionary:
	if berth == null or ship == null or not berth.eligibility_error().is_empty() or not ship.handling_error().is_empty():
		return result("INVALID_DATA", "Berth or ship data is unavailable.")
	if not pose.is_finite() or not anchor.is_finite() or not velocity.is_finite() or not anchor.basis.is_equal_approx(anchor.basis.orthonormalized()):
		return result("INVALID_DATA", "Berth or ship position is unavailable.")
	if service.is_empty() or not berth.service_ids.has(service):
		return result("SERVICE", "This berth does not offer the requested service.")
	if not cargo_id.is_empty() and (not ship.cargo_type_ids.has(cargo_id) or not berth.cargo_type_ids.has(cargo_id)):
		return result("CARGO", "This ship and berth cannot handle the selected cargo.")
	var size: Vector3 = ship.hull_size_m + Vector3.ONE * berth.clearance_margin_m * 2
	if size.x > berth.envelope_m.x or size.y > berth.envelope_m.y or size.z > berth.envelope_m.z:
		return result("SIZE", "This ship is too large for the berth.")
	# Near: the ship's centre is inside the berth box grown by EASY_RANGE_M.
	var offset: Vector3 = anchor.affine_inverse() * pose.origin
	if absf(offset.x) > berth.envelope_m.x / 2 + EASY_RANGE_M or absf(offset.z) > berth.envelope_m.z / 2 + EASY_RANGE_M:
		return result("POSITION", "Sail closer to the berth to dock.")
	if velocity.length() > EASY_SPEED_MPS + 0.000001:
		return result("SPEED", "Slow down to dock.")
	# The berth itself must be free: checked where the ship will end up, not
	# where it is now, so a crooked or quay-touching approach still docks.
	var target: Transform3D = berth_pose(anchor, pose)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = target.translated_local(Vector3(0, 1, 0))
	query.collision_mask = CollisionRules.HULL | CollisionRules.CARGO_VISUAL
	query.collide_with_areas = true
	query.exclude = exclude
	if not space.intersect_shape(query, 1).is_empty():
		return result("BLOCKED", "Wait for the berth to clear.")
	var shore_shape: BoxShape3D = BoxShape3D.new()
	shore_shape.size = ship.hull_size_m - Vector3.ONE * .02
	query.shape = shore_shape
	query.collision_mask = CollisionRules.SHORE
	query.margin = 0
	if not space.intersect_shape(query, 1).is_empty():
		return result("BLOCKED", "Wait for the berth to clear.")
	return result("READY", "Ready to dock — select Dock.")
