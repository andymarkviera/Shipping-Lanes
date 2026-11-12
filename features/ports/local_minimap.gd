extends Control
## Small chart, north up: land, ports, the ship and a line to the job's destination.
const Navigation = preload("res://features/ports/local_navigation.gd")
const Progression = preload("res://features/game/progression.gd")
var view: Node3D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -220
	offset_right = -20
	offset_top = -260
	offset_bottom = -20
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _draw() -> void:
	if not is_instance_valid(view) or not is_instance_valid(view.ship): return
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color("2f6f8f"))
	var bounds: Dictionary = Navigation.frame(view)
	var area: Rect2 = Rect2(Vector2.ZERO, size).grow(-22)
	if view.get("game_mode") == true:
		for land: Rect2 in Progression.LAND:
			var corner: Vector2 = Navigation.project(Vector3(land.position.x, 0, land.position.y), bounds, area)
			var opposite: Vector2 = Navigation.project(Vector3(land.end.x, 0, land.end.y), bounds, area)
			draw_rect(Rect2(corner, opposite - corner).abs(), Color("8fa97a"))
	var boat: Vector2 = Navigation.project(view.ship.global_position, bounds, area)
	var destination: Dictionary = Navigation.target(view)
	if not destination.is_empty():
		var goal: Vector2 = Navigation.project(destination.position, bounds, area)
		draw_dashed_line(boat, goal, Color("f7d779"), 2, 5)
		draw_arc(goal, 8, 0, TAU, 24, Color("f7d779"), 2, true)
	for port: Node3D in view.world_ports:
		var point: Vector2 = Navigation.project(port.berth_anchor.global_position, bounds, area)
		draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), Color.WHITE)
		var short_name: String = port.definition.display_name.get_slice(" ", 0)
		draw_string(font, Vector2(clampf(point.x - 24, 4, size.x - 78), point.y - 8), short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	var forward: Vector2 = Navigation.chart_vector(view.ship.global_basis.z).normalized()
	var side: Vector2 = Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([boat + forward * 9, boat - forward * 6 + side * 5, boat - forward * 6 - side * 5]), Color("9ee3b1"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("243642"), false, 3)
