extends Control
## Unlabeled shared condition / propulsion-fuel HUD, drawn as original vector shapes.
var condition: float = 1.0
var fuel: float = 1.0

func _ready() -> void:
	custom_minimum_size = Vector2(180, 66)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_values(health: float, remaining: float) -> void:
	condition = clampf(health, 0, 1)
	fuel = clampf(remaining, 0, 1)
	queue_redraw()

func icon(points: PackedVector2Array, level: float, tint: Color) -> void:
	draw_colored_polygon(points, Color("14242c"))
	var waterline: float = lerpf(56, 10, level)
	var clip := PackedVector2Array([Vector2(0, waterline), Vector2(180, waterline), Vector2(180, 60), Vector2(0, 60)])
	for filled: PackedVector2Array in Geometry2D.intersect_polygons(points, clip):
		draw_colored_polygon(filled, tint)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, tint.lightened(0.22), 2.5, true)

func _draw() -> void:
	var amber := Color("ffc84f")
	var aqua := Color("7bdddf")
	icon(PackedVector2Array([Vector2(12,24),Vector2(25,24),Vector2(32,16),Vector2(56,16),Vector2(66,27),Vector2(75,27),Vector2(75,23),Vector2(83,23),Vector2(83,49),Vector2(74,49),Vector2(74,45),Vector2(66,45),Vector2(57,56),Vector2(31,56),Vector2(22,47),Vector2(12,47)]), condition, amber)
	draw_line(Vector2(34,10),Vector2(54,10),amber,3,true)
	draw_line(Vector2(44,10),Vector2(44,16),amber,3,true)
	draw_line(Vector2(6,26),Vector2(6,47),amber,3,true)
	draw_line(Vector2(6,36),Vector2(12,36),amber,3,true)
	icon(PackedVector2Array([Vector2(111,56),Vector2(111,14),Vector2(116,10),Vector2(137,10),Vector2(142,14),Vector2(142,56)]), fuel, aqua)
	draw_style_box(window_style(),Rect2(117,16,19,13))
	draw_polyline(PackedVector2Array([Vector2(142,31),Vector2(149,31),Vector2(149,47),Vector2(156,47),Vector2(156,24),Vector2(149,17)]),aqua,3,true)
	draw_line(Vector2(107,56),Vector2(146,56),aqua,3,true)

func window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14242c")
	return style
