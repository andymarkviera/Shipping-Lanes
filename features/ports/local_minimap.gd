extends Control
const Navigation = preload("res://features/ports/local_navigation.gd")
var view: Node3D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -340
	offset_right = -20
	offset_top = -270
	offset_bottom = -20
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if not is_instance_valid(view) or not is_instance_valid(view.ship): return
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color("243642"))
	draw_string(font, Vector2(12, 24), "LOCAL MAP · N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var bounds: Dictionary = Navigation.frame(view)
	var area := Rect2(30, 58, 260, 125)
	var boat: Vector2 = Navigation.project(view.ship.global_position, bounds, area)
	var destination: Dictionary = Navigation.target(view)
	if not destination.is_empty():
		var goal: Vector2 = Navigation.project(destination.position, bounds, area)
		draw_dashed_line(boat, goal, Color("f7d779"), 2, 5)
		draw_arc(goal, 9, 0, TAU, 24, Color("f7d779"), 2, true)
		draw_string(font, Vector2(12, 222), destination.label, HORIZONTAL_ALIGNMENT_LEFT, 296, 15, Color("f7d779"))
	else:
		draw_string(font, Vector2(12, 222), "Dock at either port to choose a job", HORIZONTAL_ALIGNMENT_LEFT, 296, 14, Color.WHITE)
	for port: Node3D in view.world_ports:
		var point: Vector2 = Navigation.project(port.berth_anchor.global_position, bounds, area)
		draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), Color("a0dce9"))
		var short_name: String = port.definition.display_name.get_slice(" ", 0)
		draw_string(font, Vector2(clampf(point.x - 26, 12, 232), point.y - 12), short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	var forward: Vector2 = Navigation.chart_vector(view.ship.global_basis.z).normalized()
	var side := Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([boat + forward * 9, boat - forward * 6 + side * 5, boat - forward * 6 - side * 5]), Color("9ee3b1"))
	draw_string(font, Vector2(12, 202), "▲ You   ■ Port   ○ Job target", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(font, Vector2(12, 242), "Auto-fit · direct guide, steer around quays", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c0cdd3"))
