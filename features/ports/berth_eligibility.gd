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
		return result("POSITION", "Move the whole ship inside the berth area.")
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
	query.collision_mask = CollisionRules.HULL | CollisionRules.SHORE | CollisionRules.CARGO_VISUAL
	query.collide_with_areas = true
	query.exclude = exclude
	if not space.intersect_shape(query, 1).is_empty():
		return result("BLOCKED", "Keep clear of boats, cargo and dock structures.")
	return result("READY", "Ready to dock — select Dock.")
