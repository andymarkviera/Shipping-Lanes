extends Control
## Patch 2.0 item 5: the game's minimap is a small globe. The flat world is
## wrapped onto a sphere that turns as the ship sails, so the ship stays near
## the middle. It shows land, the ports, the ship and a line to the job's
## destination. Read-only: it draws, it owns nothing.
const Navigation = preload("res://features/ports/local_navigation.gd")
const Progression = preload("res://features/game/progression.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
## Metres of world per radian of globe. The whole strait covers about a third of it.
const METRES_PER_RADIAN: float = 3200.0
## Middle of the world in chart units (east, south), so the strait sits on the equator.
const WORLD_CENTRE: Vector2 = Vector2(-750, 100)
var view: Node3D
var clock: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -196
	offset_right = -20
	offset_top = -196
	offset_bottom = -20
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	clock += delta

## World position to (longitude, latitude) in radians. East and north are positive.
static func sphere_point(world: Vector3) -> Vector2:
	var chart: Vector2 = Navigation.chart_vector(world) - WORLD_CENTRE
	return Vector2(chart.x, -chart.y) / METRES_PER_RADIAN

## Orthographic view of a globe turned to face `centre`. Returns x, y on the unit
## disc (y up) and z toward the viewer; z below zero is on the far side.
static func facing(point: Vector2, centre: Vector2) -> Vector3:
	var turn: float = point.x - centre.x
	var flat: Vector3 = Vector3(cos(point.y) * sin(turn), sin(point.y), cos(point.y) * cos(turn))
	return Vector3(flat.x, flat.y * cos(centre.y) - flat.z * sin(centre.y), flat.y * sin(centre.y) + flat.z * cos(centre.y))

func on_disc(point: Vector2, centre: Vector2, radius: float) -> Vector2:
	var seen: Vector3 = facing(point, centre)
	var flat: Vector2 = Vector2(seen.x, -seen.y)
	# The far side is pressed onto the rim, so land that wraps round ends there.
	if seen.z < 0.0: flat = flat.normalized() if flat.length() > 0.0001 else Vector2.RIGHT
	return size / 2 + flat * radius

func visible_on(point: Vector2, centre: Vector2) -> bool:
	return facing(point, centre).z > 0.02

func grid_line(centre: Vector2, radius: float, fixed: float, along_latitude: bool) -> void:
	var run: PackedVector2Array = PackedVector2Array()
	for step: int in 49:
		var t: float = step / 48.0
		var point: Vector2 = Vector2(lerpf(-PI, PI, t), fixed) if along_latitude else Vector2(fixed, lerpf(-PI / 2, PI / 2, t))
		if visible_on(point, centre): run.append(on_disc(point, centre, radius))
		else:
			if run.size() > 1: draw_polyline(run, Color(1, 1, 1, 0.22), 1.5, true)
			run = PackedVector2Array()
	if run.size() > 1: draw_polyline(run, Color(1, 1, 1, 0.22), 1.5, true)

func _draw() -> void:
	if not is_instance_valid(view) or not is_instance_valid(view.ship): return
	var middle: Vector2 = size / 2
	var radius: float = minf(size.x, size.y) / 2 - 8
	var ship_at: Vector2 = sphere_point(view.ship.global_position)
	# The globe turns most of the way with the ship, so it visibly rolls under way.
	var centre: Vector2 = ship_at * 0.85
	draw_circle(middle + Vector2(0, 4), radius + 6, Color(PLAYFUL.INK, 0.35))
	draw_circle(middle, radius + 6, PLAYFUL.INK)
	draw_circle(middle, radius + 4, PLAYFUL.CREAM)
	draw_circle(middle, radius, Color("1aa0d8"))
	for line: int in range(-2, 3): grid_line(centre, radius, line * PI / 6, true)
	for line: int in 12: grid_line(centre, radius, -PI + line * PI / 6, false)
	for land: Rect2 in Progression.LAND:
		var outline: PackedVector2Array = PackedVector2Array()
		var corners: Array[Vector2] = [land.position, Vector2(land.end.x, land.position.y), land.end, Vector2(land.position.x, land.end.y)]
		var any_visible: bool = false
		for index: int in 4:
			for step: int in 6:
				var spot: Vector2 = corners[index].lerp(corners[(index + 1) % 4], step / 6.0)
				var point: Vector2 = sphere_point(Vector3(spot.x, 0, spot.y))
				any_visible = any_visible or visible_on(point, centre)
				outline.append(on_disc(point, centre, radius))
		if any_visible and not Geometry2D.triangulate_polygon(outline).is_empty():
			draw_colored_polygon(outline, PLAYFUL.LEAF)
			outline.append(outline[0])
			draw_polyline(outline, Color("3f9a3a"), 1.5, true)
	# Toon shading: a soft shadow on the lower right, a shine on the upper left.
	draw_arc(middle, radius - 5, deg_to_rad(-10), deg_to_rad(100), 24, Color(PLAYFUL.INK, 0.16), 10, true)
	draw_arc(middle, radius - 9, deg_to_rad(200), deg_to_rad(250), 12, Color(1, 1, 1, 0.45), 4, true)
	var boat: Vector2 = on_disc(ship_at, centre, radius)
	var destination: Dictionary = Navigation.target(view)
	var goal_at: Vector2 = sphere_point(destination.position) if not destination.is_empty() else Vector2.ZERO
	if not destination.is_empty():
		# A dotted course from the ship to the destination, curved with the globe.
		for step: int in range(1, 12):
			var point: Vector2 = ship_at.lerp(goal_at, step / 12.0)
			if visible_on(point, centre): draw_circle(on_disc(point, centre, radius), 1.8, PLAYFUL.SUN)
	for port: Node3D in view.world_ports:
		var point: Vector2 = sphere_point(port.berth_anchor.global_position)
		if not visible_on(point, centre): continue
		var dot: Vector2 = on_disc(point, centre, radius)
		draw_circle(dot, 5.5, PLAYFUL.INK)
		draw_circle(dot, 3.5, PLAYFUL.SUN if port == view.port else Color.WHITE)
	if not destination.is_empty() and visible_on(goal_at, centre):
		var goal: Vector2 = on_disc(goal_at, centre, radius)
		draw_arc(goal, 8.0 + 2.0 * sin(clock * 4.0), 0, TAU, 20, PLAYFUL.SUN, 2.5, true)
		var font: Font = ThemeDB.fallback_font
		var title: String = str(destination.label).get_slice(" ", 0)
		var at: Vector2 = Vector2(clampf(goal.x - 24, 6, size.x - 70), goal.y - 12)
		draw_string_outline(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, PLAYFUL.INK)
		draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# The ship: an arrow pointing the way the bow points on the globe.
	var ahead: Vector2 = on_disc(sphere_point(view.ship.global_position + view.ship.global_basis.z * 60.0), centre, radius) - boat
	var forward: Vector2 = ahead.normalized() if ahead.length() > 0.0001 else Vector2.UP
	var side: Vector2 = Vector2(-forward.y, forward.x)
	var hull: PackedVector2Array = PackedVector2Array([boat + forward * 10, boat - forward * 6 + side * 6, boat - forward * 6 - side * 6])
	draw_colored_polygon(hull, PLAYFUL.SUN)
	draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[0]]), PLAYFUL.INK, 2, true)
