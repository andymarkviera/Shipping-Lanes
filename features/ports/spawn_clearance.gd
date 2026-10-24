extends RefCounted
## Synchronous authority-side allocation. Reservations are conservative world AABBs.
## Call in the same physics world as the port; release holds after materialization/cancellation.
var holds: Dictionary = {}
var next_ticket: int = 1

func reserve(space: PhysicsDirectSpaceState3D, candidates: Array[Transform3D], size: Vector3, center: Vector3 = Vector3(0, 1, 0), cargo: Array[AABB] = []) -> Dictionary:
	if not size.is_finite() or not center.is_finite() or minf(size.x, minf(size.y, size.z)) <= 0:
		return {"ok": false, "reason": "INVALID_ENVELOPE"}
	for envelope: AABB in cargo:
		if not envelope.position.is_finite() or not envelope.size.is_finite() or minf(envelope.size.x, minf(envelope.size.y, envelope.size.z)) <= 0:
			return {"ok": false, "reason": "INVALID_ENVELOPE"}
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size + Vector3(4, 2, 4)
	for index: int in candidates.size():
		var pose: Transform3D = candidates[index]
		if not pose.is_finite() or not pose.basis.is_equal_approx(pose.basis.orthonormalized()):
			return {"ok": false, "reason": "INVALID_ANCHOR"}
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = pose.translated_local(center)
		query.collision_mask = CollisionRules.HULL | CollisionRules.SHORE | CollisionRules.CARGO_VISUAL
		query.collide_with_areas = true
		var bounds: AABB = query.transform * AABB(-shape.size / 2, shape.size)
		var blocked: bool = not space.intersect_shape(query, 1).is_empty()
		for held: AABB in holds.values():
			blocked = blocked or bounds.intersects(held)
		for envelope: AABB in cargo:
			blocked = blocked or bounds.intersects(envelope)
		if blocked: continue
		var ticket: int = next_ticket
		next_ticket += 1
		holds[ticket] = bounds
		return {"ok": true, "ticket": ticket, "index": index, "transform": pose}
	return {"ok": false, "reason": "SPAWN_OCCUPIED"}

func release(ticket: int) -> void:
	holds.erase(ticket)

func hold_volume(bounds: AABB) -> int:
	# For an authority-owned berth reservation or cargo operation envelope.
	if not bounds.position.is_finite() or not bounds.size.is_finite() or minf(bounds.size.x, minf(bounds.size.y, bounds.size.z)) <= 0: return 0
	var ticket: int = next_ticket
	next_ticket += 1
	holds[ticket] = bounds
	return ticket
