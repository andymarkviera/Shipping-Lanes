extends RefCounted
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")
const IDS = ["port_brindle_quay", "port_slatewater_works"]
const SCENES = [preload("res://features/ports/brindle_quay.tscn"), preload("res://features/ports/slatewater_works.tscn")]

static func address(id: String) -> Dictionary:
	var index: int = IDS.find(id)
	if index < 0: return {}
	return Geo.normalized(0, 0) if index == 0 else Nav.travel(Geo.normalized(0, 0, 270), 1500)

static func pose(origin: Dictionary, id: String) -> Transform3D:
	var at: Dictionary = address(id)
	return Transform3D(Basis(Vector3.UP, -Nav.transport_rotation(origin, at)), Nav.local_position(origin, at))

static func spawn_clear(at: Dictionary, hull_size: Vector3) -> bool:
	for index: int in IDS.size():
		var anchor: Dictionary = address(IDS[index])
		if Nav.separation(anchor, at) > 400: continue
		var local_pose := Transform3D(Basis(Vector3.UP, -deg_to_rad(at.heading_deg) - Nav.transport_rotation(anchor, at)), Nav.local_position(anchor, at) + Vector3(0, 1, 0))
		var hull: AABB = local_pose * AABB(-hull_size / 2, hull_size)
		var side: float = -1.0 if index == 0 else 1.0
		var length_: float = 140.0 if index == 0 else 190.0
		if hull.intersects(AABB(Vector3(side * 60 - 40, -2, 0), Vector3(80, 6, length_))): return false
		for z: float in [-70.0, -110.0, -150.0]:
			for x: float in [-42.0, 42.0]:
				if hull.intersects(AABB(Vector3(x - 1.5, -1, z - 1.5), Vector3(3, 4, 3))): return false
	return true
