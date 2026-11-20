extends RefCounted
## Baked once offline; shared FontFiles, no per-frame slicing or texture uploads.
const WHITE: FontFile = preload("res://features/ui/fonts/white.fnt")
const GOLD: FontFile = preload("res://features/ui/fonts/gold.fnt")
const RED: FontFile = preload("res://features/ui/fonts/red.fnt")
static var prepared: bool = false
## Patch 3.2 typography: sprite lettering is only for the port name heading, the
## money figure and the objective card title. Every in-game button uses this one
## plain bold UI font at BUTTON_SIZE, in Title Case; body text uses the same face.
const BUTTON_SIZE: int = 18
static var plain_face: FontVariation

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

## The plain bold UI face (the playful theme's default font), shared by every
## in-game button and body label.
static func plain_font() -> Font:
	if plain_face == null:
		plain_face = FontVariation.new()
		plain_face.base_font = ThemeDB.fallback_font
		plain_face.variation_embolden = 0.5
	return plain_face

## The one in-game button style: plain bold face, BUTTON_SIZE, theme colours.
static func style_button(control: Button) -> void:
	clear(control)
	control.add_theme_font_override("font", plain_font())
	control.add_theme_font_size_override("font_size", BUTTON_SIZE)
	control.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE

## Plain bold text in a colour (gold amounts, red warnings) instead of a sprite sheet.
static func plain(control: Control, colour: Color = Color.WHITE, size_px: int = 0) -> void:
	clear(control)
	control.add_theme_font_override("font", plain_font())
	control.add_theme_color_override("font_color", colour)
	if size_px > 0: control.add_theme_font_size_override("font_size", size_px)

## Shrink a one-line heading's font until its text fits `width` pixels.
static func fit(label: Label, width: float, largest: int, smallest: int = 12) -> void:
	var font: Font = label.get_theme_font("font")
	var px: int = largest
	while px > smallest and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width: px -= 1
	label.add_theme_font_size_override("font_size", px)

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
