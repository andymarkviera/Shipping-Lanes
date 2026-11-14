extends RefCounted
## Read-only local chart targets; no gameplay authority.
## Patch 2.5 item 1: in the game the target also carries "route", the turning
## points of the way there by sea round the land (Progression.course).
const Progression = preload("res://features/game/progression.gd")

static func target(view: Node3D) -> Dictionary:
	var found: Dictionary = _target(view)
	if not found.is_empty() and view.get("game_mode") == true and is_instance_valid(view.ship):
		var index: int = Progression.port_index(found.get("port_id", ""))
		found.route = Progression.course(view.ship.global_position, Progression.nearest(found.position, view.ship.global_position), index)
	return found

static func _target(view: Node3D) -> Dictionary:
	if view.heavy_mode and not view.heavy_jobs.active.is_empty():
		var carrying: bool = view.ship.attached
		return {"position": view.heavy_jobs.active.drop if carrying else view.ship.payload_body.global_position, "label": "Ocean drop-off" if carrying else "Heavy pickup", "kind": "drop" if carrying else "pickup"}
	var job: Dictionary = view.offers.active_job("preview_captain")
	# M3: a bulk job is tracked by the game scene, not by the container offers.
	if job.is_empty() and view.get("bulk_active") is String and not view.bulk_active.is_empty(): job = {"destination_port_id": view.bulk_destination().definition.id}
	if not job.is_empty():
		for port: Node3D in view.world_ports:
			if port.definition.id == job.destination_port_id:
				return {"position": port.berth_anchor.global_position, "label": port.definition.display_name, "kind": "delivery", "port_id": port.definition.id}
	return {}

static func chart_vector(world: Vector3) -> Vector2:
	# Local helm convention: +Z north, -X east; heading grows clockwise.
	return Vector2(-world.x, -world.z)

static func frame(view: Node3D) -> Dictionary:
	var points: Array[Vector2] = [chart_vector(view.ship.global_position)]
	for port: Node3D in view.world_ports: points.append(chart_vector(port.berth_anchor.global_position))
	var destination: Dictionary = target(view)
	if not destination.is_empty(): points.append(chart_vector(destination.position))
	var low: Vector2 = points[0]
	var high: Vector2 = points[0]
	for point: Vector2 in points:
		low = low.min(point)
		high = high.max(point)
	return {"center": (low + high) * .5, "span": Vector2(maxf(high.x - low.x, 400), maxf(high.y - low.y, 400))}

static func project(world: Vector3, bounds: Dictionary, rect: Rect2) -> Vector2:
	var scale: float = minf(rect.size.x / bounds.span.x, rect.size.y / bounds.span.y)
	return rect.get_center() + (chart_vector(world) - bounds.center) * scale
