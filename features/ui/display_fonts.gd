extends RefCounted
## Baked once offline; shared FontFiles, no per-frame slicing or texture uploads.
const WHITE: FontFile = preload("res://features/ui/fonts/white.fnt")
const GOLD: FontFile = preload("res://features/ui/fonts/gold.fnt")
const RED: FontFile = preload("res://features/ui/fonts/red.fnt")
static var prepared: bool = false

static func font(kind: String = "white") -> Font:
	if not prepared:
		for face: FontFile in [WHITE, GOLD, RED]:
			face.fallbacks = [ThemeDB.fallback_font]
		prepared = true
	if kind == "gold": return GOLD
	if kind == "red": return RED
	return WHITE

static func apply(control: Control, kind: String = "white") -> void:
	control.add_theme_font_override("font", font(kind))
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Colour and outline are baked into each glyph, never tint them twice.
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		control.add_theme_color_override(state, Color.WHITE)
	control.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	control.add_theme_constant_override("outline_size", 0)
	control.add_theme_constant_override("shadow_outline_size", 0)
	control.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)

## Return transient message/status labels to their inherited body styling.
static func clear(control: Control) -> void:
	control.remove_theme_font_override("font")
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color", "font_shadow_color"]:
		control.remove_theme_color_override(key)
	for key: String in ["outline_size", "shadow_outline_size"]:
		control.remove_theme_constant_override(key)

## Draw within the existing animated logo rectangle, without a Label minimum
## size resisting the shrink when the title moves into the menu corner.
class Logo extends Control:
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 2.0 or size.y < 2.0: return
		var face: Font = WHITE
		var px: int = floori(minf(size.y / 2.2, size.x * 64.0 / face.get_string_size("SHIPPING", HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x))
		for index: int in 2:
			var word: String = ["SHIPPING", "LANES"][index]
			var width: float = face.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			draw_string(face, Vector2((size.x - width) * 0.5, size.y * 0.5 - px + face.get_ascent(px) + index * px), word, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
