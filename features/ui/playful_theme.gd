extends RefCounted
## Aesthetics 5: the playful HUD and menu look. One Theme built in code: navy
## panels with a thick cream rim, chunky sunny buttons, bold inked text. No image
## or font file. The home menu, Settings and the game's HUD use it; the test
## scenes keep their plain look. Looks only: no layout owner, no game state.
const INK: Color = Color("1b2540")
const CREAM: Color = Color("fff4d6")
const NAVY: Color = Color("1f4f8a")
const DEEP: Color = Color("163a66")
const SUN: Color = Color("ffc940")
const SUN_LIGHT: Color = Color("ffe085")
const SUN_DARK: Color = Color("f29e2e")
const LEAF: Color = Color("7ed957")
const RUST: Color = Color("b8472e")
static var cached: Theme

static func box(fill: Color, rim: Color, radius: int, rim_width: int, margin: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = rim
	style.set_border_width_all(rim_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	return style

## A HUD or menu panel. `fill` changes for the warning banner.
static func panel_box(fill: Color = NAVY) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(fill, CREAM, 16, 4, 12)
	style.shadow_color = Color(INK, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	return style

## A button with a thick lower lip, so it reads as something to press.
static func button_box(fill: Color, lip: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(fill, INK, 12, 3, 6)
	style.border_width_bottom = lip
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 3 + (6 - lip)
	style.content_margin_bottom = 3 + lip
	return style

static func make() -> Theme:
	if cached != null: return cached
	var theme: Theme = Theme.new()
	var font: FontVariation = FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.5
	theme.default_font = font
	for kind: String in ["PanelContainer", "Panel", "AcceptDialog", "PopupPanel"]:
		theme.set_stylebox("panel", kind, panel_box())
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_outline_color", "Label", INK)
	theme.set_constant("outline_size", "Label", 4)
	# Button, and with it OptionButton and the dialog buttons.
	theme.set_stylebox("normal", "Button", button_box(SUN, 6))
	theme.set_stylebox("hover", "Button", button_box(SUN_LIGHT, 6))
	theme.set_stylebox("pressed", "Button", button_box(SUN_DARK, 3))
	theme.set_stylebox("disabled", "Button", button_box(Color("9fb2c4"), 6))
	var ring: StyleBoxFlat = box(Color.TRANSPARENT, Color.WHITE, 14, 3, 0)
	ring.draw_center = false
	ring.set_expand_margin_all(3)
	theme.set_stylebox("focus", "Button", ring)
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(item, "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color(INK, 0.5))
	theme.set_constant("modulate_arrow", "OptionButton", 1)
	# A tick box is a Button too; it stays flat with light text.
	for kind: String in ["CheckBox", "CheckButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, kind, box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 4))
		for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			theme.set_color(item, kind, CREAM)
		theme.set_color("font_disabled_color", kind, Color(CREAM, 0.5))
	theme.set_stylebox("background", "ProgressBar", box(DEEP, INK, 9, 2, 2))
	theme.set_stylebox("fill", "ProgressBar", box(LEAF, INK, 9, 2, 2))
	theme.set_color("font_outline_color", "ProgressBar", INK)
	theme.set_constant("outline_size", "ProgressBar", 4)
	theme.set_stylebox("slider", "HSlider", box(DEEP, INK, 6, 2, 5))
	theme.set_stylebox("grabber_area", "HSlider", box(SUN, INK, 6, 2, 5))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(SUN_LIGHT, INK, 6, 2, 5))
	theme.set_stylebox("panel", "ItemList", box(DEEP, INK, 10, 2, 6))
	theme.set_stylebox("focus", "ItemList", box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 0))
	for state: String in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus"]:
		theme.set_stylebox(state, "ItemList", box(SUN, INK, 6, 0, 0))
	theme.set_stylebox("hovered", "ItemList", box(Color(CREAM, 0.15), INK, 6, 0, 0))
	theme.set_color("font_color", "ItemList", CREAM)
	theme.set_color("font_hovered_color", "ItemList", Color.WHITE)
	theme.set_color("font_selected_color", "ItemList", INK)
	theme.set_color("font_hovered_selected_color", "ItemList", INK)
	theme.set_stylebox("panel", "PopupMenu", box(NAVY, CREAM, 10, 3, 6))
	theme.set_stylebox("hover", "PopupMenu", box(SUN, INK, 6, 0, 0))
	theme.set_color("font_color", "PopupMenu", Color.WHITE)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("panel", "TooltipPanel", box(CREAM, INK, 8, 2, 6))
	theme.set_color("font_color", "TooltipLabel", INK)
	# The frame of the Restart Progress question.
	var frame: StyleBoxFlat = box(DEEP, CREAM, 14, 4, 0)
	frame.expand_margin_left = 10
	frame.expand_margin_right = 10
	frame.expand_margin_bottom = 10
	frame.expand_margin_top = 40
	for item: String in ["embedded_border", "embedded_unfocused_border"]:
		theme.set_stylebox(item, "Window", frame)
	theme.set_constant("title_height", "Window", 36)
	theme.set_color("title_color", "Window", CREAM)
	theme.set_stylebox("panel", "AcceptDialog", box(DEEP, DEEP, 0, 0, 10))
	cached = theme
	return theme

## Gives one HUD or menu control the look. Its own flat panel style, if it set
## one, is dropped; `warning` keeps a rust panel for the helm banner.
static func dress(control: Control, warning: bool = false) -> void:
	control.theme = make()
	if control is PanelContainer:
		if warning: control.add_theme_stylebox_override("panel", panel_box(RUST))
		else: control.remove_theme_stylebox_override("panel")

## The home menu's picture: sky, sun, drifting puffy clouds, sea and a chunky ship.
class Backdrop extends Control:
	var clock: float = 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		clock += delta
		queue_redraw()

	func puff(at: Vector2, scale: float) -> void:
		draw_rect(Rect2(at + Vector2(-58, 2) * scale, Vector2(116, 12) * scale), Color("cfe9ff"))
		for blob: Vector3 in [Vector3(-40, 0, 24), Vector3(-10, -16, 34), Vector3(26, -6, 28), Vector3(50, 2, 18)]:
			draw_circle(at + Vector2(blob.x, blob.y) * scale, blob.z * scale, Color.WHITE)

	func _draw() -> void:
		var horizon: float = size.y * 0.68
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, horizon), Vector2(0, horizon)]),
			PackedColorArray([Color("2f8fe0"), Color("2f8fe0"), Color("c4ecff"), Color("c4ecff")]))
		var sun: Vector2 = Vector2(size.x * 0.84, size.y * 0.2)
		draw_circle(sun, 78, Color(1, 0.96, 0.7, 0.35))
		draw_circle(sun, 56, Color("fff3a8"))
		var clouds: Array[Vector3] = [Vector3(0.08, 0.2, 1.0), Vector3(0.42, 0.34, 1.5), Vector3(0.7, 0.14, 0.8), Vector3(0.95, 0.42, 1.2)]
		for cloud: Vector3 in clouds:
			var span: float = size.x + 400.0
			puff(Vector2(fposmod(cloud.x * span + clock * 6.0 * cloud.z, span) - 200.0, size.y * cloud.y), cloud.z)
		draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color("1aa0d8"))
		draw_rect(Rect2(0, horizon + (size.y - horizon) * 0.55, size.x, size.y), Color("148ac6"))
		draw_line(Vector2(0, horizon), Vector2(size.x, horizon), Color.WHITE, 3)
		for row: int in 4:
			var y: float = horizon + 26.0 + row * 44.0
			var x: float = fposmod(clock * (8.0 + row * 4.0) + row * 70.0, 180.0) - 180.0
			while x < size.x:
				draw_arc(Vector2(x, y), 22, PI * 1.15, PI * 1.85, 10, Color(1, 1, 1, 0.85), 4, true)
				x += 180.0
		# The ship: red hull, white house, banded funnel, inked like the 3D ones.
		var at: Vector2 = Vector2(size.x * 0.68, horizon + 34.0 + sin(clock * 1.3) * 3.0)
		var shapes: Array = [
			[Color("d8402f"), [Vector2(-150, -34), Vector2(128, -34), Vector2(170, -52), Vector2(140, 8), Vector2(-136, 8)]],
			[Color.WHITE, [Vector2(-128, -86), Vector2(-64, -86), Vector2(-64, -34), Vector2(-128, -34)]],
			[Color("ffc940"), [Vector2(-112, -122), Vector2(-84, -122), Vector2(-84, -86), Vector2(-112, -86)]],
			[Color("2f8fe0"), [Vector2(-40, -62), Vector2(20, -62), Vector2(20, -34), Vector2(-40, -34)]],
			[Color("7ed957"), [Vector2(28, -62), Vector2(88, -62), Vector2(88, -34), Vector2(28, -34)]]]
		for shape: Array in shapes:
			var points: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in shape[1]: points.append(at + point)
			draw_colored_polygon(points, shape[0])
			points.append(points[0])
			draw_polyline(points, Color("1b2540"), 4, true)
		draw_rect(Rect2(at + Vector2(-120, -76), Vector2(48, 12)), Color("1b2540"))
		draw_line(at + Vector2(-160, 9), at + Vector2(176, 9), Color.WHITE, 5, true)
