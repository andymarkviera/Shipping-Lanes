extends Control
const DISPLAY = preload("res://features/ui/display_fonts.gd")
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
## Patch 2.5 item 1B: beach colour round the land on the minimap and globe.
const SAND: Color = Color("f1dfa4")
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

## Patch 2.9 item 6A: [outline, ice, centre] for each natural landmass (every
## other outline point, about 120 m apart) and piece of the polar ice cap,
## then its reach from that centre in metres. Built once.
static var _rings: Array = []
static func land_rings() -> Array:
	var rings: Array = []
	for entry: Dictionary in Progression.natural_land().get("outlines", []):
		var ring: PackedVector2Array = PackedVector2Array()
		var source: PackedVector2Array = entry.outline
		for index: int in range(0, source.size(), 2): ring.append(source[index])
		if ring.size() >= 3: rings.append([ring, false])
	# Patch 2.9.1 item 6: the polar ice cap's pieces (none crosses an edge of
	# the world; neighbours share their edges, so the fills join up).
	for ring: PackedVector2Array in Progression.polar_ice().get("outlines", []): rings.append([ring, true])
	for entry: Array in rings:
		var bounds: Rect2 = Rect2(entry[0][0], Vector2.ZERO)
		for spot: Vector2 in entry[0]: bounds = bounds.expand(spot)
		entry.append(bounds.get_center())
		entry.append(bounds.size.length() / 2)
	return rings

## The near side's edge as a polygon in globe radians (Patch 2.9 item 6A).
static var _horizon: PackedVector2Array = PackedVector2Array()
static func horizon() -> PackedVector2Array:
	if _horizon.is_empty():
		for step: int in 64: _horizon.append(Vector2.from_angle(TAU * step / 64.0) * (PI / 2 - 0.03))
	return _horizon

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
	# Patch 2.5 item 1B: land in three passes, so a continent made of blocks
	# reads as one shape: an ink coastline, a sandy beach, then the fills, which
	# cover the strokes inside the continent.
	var shapes: Array = []
	# Patch 2.9 item 6A: the natural landmasses' outlines (every other point,
	# about 120 m apart), then the polar ice cap's pieces (Patch 2.9.1 item 6).
	if _rings.is_empty(): _rings = land_rings()
	for entry: Array in _rings:
		var ring: PackedVector2Array = entry[0]
		# The whole shape is drawn as its copy nearest the ship, so it is never torn.
		var centre: Vector2 = entry[2]
		var near: Vector3 = Progression.nearest(Vector3(centre.x, 0, centre.y), ship) - Vector3(centre.x, 0, centre.y)
		# Wholly over the horizon: nothing to work out.
		if Vector2(centre.x + near.x - ship.x, centre.y + near.z - ship.z).length() > METRES_PER_RADIAN * PI / 2 + entry[3]: continue
		var points: PackedVector2Array = PackedVector2Array()
		var any_visible: bool = false
		var all_visible: bool = true
		for spot: Vector2 in ring:
			var point: Vector2 = (Vector2(-spot.x, spot.y) - Vector2(-ship.x, ship.z) + Vector2(-near.x, near.z)) / METRES_PER_RADIAN
			any_visible = any_visible or visible_on(point)
			all_visible = all_visible and visible_on(point)
			points.append(point)
		if not any_visible: continue
		# Patch 2.9 item 6A: a continent can run over the horizon; only its near
		# side is drawn, cut at the horizon, so its shape stays one fill.
		var pieces: Array = [points] if all_visible else Geometry2D.intersect_polygons(points, horizon())
		for piece: PackedVector2Array in pieces:
			if Geometry2D.is_polygon_clockwise(piece) != Geometry2D.is_polygon_clockwise(points) and not all_visible: continue
			var outline: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in piece: outline.append(on_disc(point, radius))
			var closed: PackedVector2Array = outline.duplicate()
			closed.append(outline[0])
			shapes.append([outline, closed, entry[1], not Geometry2D.triangulate_polygon(outline).is_empty()])
	for shape: Array in shapes: draw_polyline(shape[1], Color("8fc3d6") if shape[2] else Color("2f7a33"), 5.0, true)
	for shape: Array in shapes: draw_polyline(shape[1], Color("dff3f8") if shape[2] else SAND, 2.5, true)
	for shape: Array in shapes:
		if shape[3]: draw_colored_polygon(shape[0], Color("f7fbfd") if shape[2] else PLAYFUL.LEAF)
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
		# Patch 2.5 item 1: it follows the sea route round the land.
		var corners: Array = destination.get("route", [])
		if corners.is_empty(): corners = [destination.position]
		var from: Vector2 = Vector2.ZERO
		for corner: Vector3 in corners:
			var to: Vector2 = sphere_point(corner, ship)
			var dots: int = clampi(roundi(from.distance_to(to) / 0.06), 1, 24)
			for step: int in range(1, dots + 1):
				var point: Vector2 = from.lerp(to, step / float(dots))
				if visible_on(point): draw_circle(on_disc(point, radius), 1.8, PLAYFUL.SUN)
			from = to
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
		var font: Font = DISPLAY.font()
		var title: String = str(destination.label).get_slice(" ", 0)
		var width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var at: Vector2 = Vector2(clampf(goal.x - width * 0.5, 6, size.x - width - 6), clampf(goal.y - 12, 14, size.y - 6))
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
