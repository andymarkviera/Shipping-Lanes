extends Control
## Patch 2.0 item 5: the game's minimap is a small globe. It shows land, the
## ports, the ship and a line to the job's destination. Read-only: it draws, it
## owns nothing.
## Patch 2.1 item 3: the world wraps round in every direction, and so does the
## globe. The ship stays in the middle and the world rolls under it: sailing
## once round the world, east-west or north-south, turns the globe once.
const Navigation = preload("res://features/ports/local_navigation.gd")
const Progression = preload("res://features/game/progression.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
## Metres of world per radian of globe: once round the world is one full turn.
const METRES_PER_RADIAN: float = Progression.WRAP_M / TAU
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

## A world position as (east, north) radians round the globe from `ship`, the
## short way round the world.
static func sphere_point(world: Vector3, ship: Vector3) -> Vector2:
	var step: Vector3 = Progression.short_way(world - ship)
	return Vector2(-step.x, step.z) / METRES_PER_RADIAN

## Only the near half of the globe can be seen.
static func visible_on(point: Vector2) -> bool:
	return point.length() < PI / 2 - 0.02

## Where a globe point is drawn. The far side is pressed onto the rim, so land
## that goes over the horizon ends there.
func on_disc(point: Vector2, radius: float) -> Vector2:
	var angle: float = point.length()
	var flat: Vector2 = point.normalized() * (sin(angle) if angle < PI / 2 else 1.0)
	return size / 2 + Vector2(flat.x, -flat.y) * radius

## One line of the world's grid, drawn where it is on the near side.
func grid_line(radius: float, fixed: float, north_south: bool) -> void:
	var run: PackedVector2Array = PackedVector2Array()
	for step: int in 49:
		var along: float = lerpf(-PI, PI, step / 48.0)
		var point: Vector2 = Vector2(fixed, along) if north_south else Vector2(along, fixed)
		if visible_on(point): run.append(on_disc(point, radius))
		else:
			if run.size() > 1: draw_polyline(run, Color(1, 1, 1, 0.22), 1.5, true)
			run = PackedVector2Array()
	if run.size() > 1: draw_polyline(run, Color(1, 1, 1, 0.22), 1.5, true)

func _draw() -> void:
	if not is_instance_valid(view) or not is_instance_valid(view.ship): return
	var middle: Vector2 = size / 2
	var radius: float = minf(size.x, size.y) / 2 - 8
	var ship: Vector3 = view.ship.global_position
	draw_circle(middle + Vector2(0, 4), radius + 6, Color(PLAYFUL.INK, 0.35))
	draw_circle(middle, radius + 6, PLAYFUL.INK)
	draw_circle(middle, radius + 4, PLAYFUL.CREAM)
	draw_circle(middle, radius, Color("1aa0d8"))
	# Twelve grid lines each way, fixed to the world, so the globe visibly rolls.
	var origin: Vector2 = sphere_point(Progression.WRAP_CENTRE, ship)
	for line: int in 12:
		grid_line(radius, wrapf(origin.x + line * PI / 6, -PI, PI), true)
		grid_line(radius, wrapf(origin.y + line * PI / 6, -PI, PI), false)
	var ice_from: int = Progression.LAND.size()
	for index_land: int in ice_from + Progression.ICE_SHELVES.size():
		# Land is green; the polar ice shelves are white.
		var land: Rect2 = Progression.LAND[index_land] if index_land < ice_from else Progression.ICE_SHELVES[index_land - ice_from]
		# The whole block is drawn as its copy nearest the ship, so it is never torn.
		var centre: Vector2 = land.get_center()
		var near: Vector3 = Progression.nearest(Vector3(centre.x, 0, centre.y), ship) - Vector3(centre.x, 0, centre.y)
		var outline: PackedVector2Array = PackedVector2Array()
		var corners: Array[Vector2] = [land.position, Vector2(land.end.x, land.position.y), land.end, Vector2(land.position.x, land.end.y)]
		var any_visible: bool = false
		for index: int in 4:
			for step: int in 10:
				var spot: Vector2 = corners[index].lerp(corners[(index + 1) % 4], step / 10.0)
				var point: Vector2 = (Vector2(-spot.x, spot.y) - Vector2(-ship.x, ship.z) + Vector2(-near.x, near.z)) / METRES_PER_RADIAN
				any_visible = any_visible or visible_on(point)
				outline.append(on_disc(point, radius))
		if any_visible and not Geometry2D.triangulate_polygon(outline).is_empty():
			var ice: bool = index_land >= ice_from
			draw_colored_polygon(outline, Color("f7fbfd") if ice else PLAYFUL.LEAF)
			outline.append(outline[0])
			draw_polyline(outline, Color("8fc3d6") if ice else Color("3f9a3a"), 1.5, true)
	# Toon shading: a soft shadow on the lower right, a shine on the upper left.
	draw_arc(middle, radius - 5, deg_to_rad(-10), deg_to_rad(100), 24, Color(PLAYFUL.INK, 0.16), 10, true)
	draw_arc(middle, radius - 9, deg_to_rad(200), deg_to_rad(250), 12, Color(1, 1, 1, 0.45), 4, true)
	# Patch 2.1 item 3: icebergs as small white dots.
	for berg: Vector3 in Progression.ICEBERGS:
		var spot: Vector2 = sphere_point(Vector3(berg.x, 0, berg.z), ship)
		if not visible_on(spot): continue
		draw_circle(on_disc(spot, radius), 3.0, Color("8fc3d6"))
		draw_circle(on_disc(spot, radius), 2.0, Color.WHITE)
	var destination: Dictionary = Navigation.target(view)
	var goal_at: Vector2 = sphere_point(destination.position, ship) if not destination.is_empty() else Vector2.ZERO
	if not destination.is_empty():
		# A dotted course from the ship to the destination, the short way round.
		for step: int in range(1, 12):
			var point: Vector2 = goal_at * (step / 12.0)
			if visible_on(point): draw_circle(on_disc(point, radius), 1.8, PLAYFUL.SUN)
	for port: Node3D in view.world_ports:
		var point: Vector2 = sphere_point(port.berth_anchor.global_position, ship)
		if not visible_on(point): continue
		var dot: Vector2 = on_disc(point, radius)
		draw_circle(dot, 5.5, PLAYFUL.INK)
		draw_circle(dot, 3.5, PLAYFUL.SUN if port == view.port else Color.WHITE)
	if not destination.is_empty():
		# A destination over the horizon sits on the rim, in the direction to sail.
		var goal: Vector2 = on_disc(goal_at, radius)
		draw_arc(goal, 8.0 + 2.0 * sin(clock * 4.0), 0, TAU, 20, PLAYFUL.SUN, 2.5, true)
		var font: Font = ThemeDB.fallback_font
		var title: String = str(destination.label).get_slice(" ", 0)
		var at: Vector2 = Vector2(clampf(goal.x - 24, 6, size.x - 70), clampf(goal.y - 12, 14, size.y - 6))
		draw_string_outline(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, PLAYFUL.INK)
		draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# The ship: an arrow in the middle, pointing the way the bow points. North is up.
	var bow: Vector3 = view.ship.global_basis.z
	var forward: Vector2 = Vector2(-bow.x, -bow.z).normalized() if Vector2(bow.x, bow.z).length() > 0.0001 else Vector2.UP
	var side: Vector2 = Vector2(-forward.y, forward.x)
	# Patch 2.2: the arrow grows with the hull, up to twice the starter's.
	var grow: float = clampf(sqrt(view.ship.definition.hull_size_m.z / 64.0), 1.0, 2.0)
	forward *= grow
	side *= grow
	var hull: PackedVector2Array = PackedVector2Array([middle + forward * 10, middle - forward * 6 + side * 6, middle - forward * 6 - side * 6])
	draw_colored_polygon(hull, PLAYFUL.SUN)
	draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[0]]), PLAYFUL.INK, 2, true)
