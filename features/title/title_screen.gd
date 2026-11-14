class_name TitleScreen
extends CanvasLayer
## Patch 2.7 item 1: the attract screen. The live toon ocean seen from straight
## above, the Shipping Lanes logo centre-top and a pulsing "Press Any Button".
## Any key, mouse click or gamepad button continues to the menu underneath.
## Layout fractions come from docs/reference/main_menu/title_press_any_button.png
## (1672 x 941), so the screen matches Andy's mockup at any 16:9 size.

signal dismissed
const LOGO: Texture2D = preload("res://features/title/title_logo.png")
const PRESS: Texture2D = preload("res://features/title/press_any_button.png")
## The mockup's light-blue wave streaks and curled swirl foam, sea removed.
const STREAKS: Texture2D = preload("res://features/title/sea_streaks.png")
const OCEAN_PALETTE: WaterPalette = preload("res://features/title/title_ocean.tres")
const MOCKUP: Vector2 = Vector2(1672, 941)
## Visible sea height in metres for the live ocean's own (faint) swirl lines.
const SEA_VIEW_METRES: float = 260.0
## Streak drift in mockup pixels per second: a slow push up and to the left.
const STREAK_DRIFT: Vector2 = Vector2(-14.0, -4.0)
const FADE_SECONDS: float = 0.35

var clock: float = 0.0
var leaving: float = -1.0
var viewport: SubViewport
var ocean: OceanPresentation
var root: Control
var sea: SeaStreaks
var press: TextureRect

## Draws the streak layer tiled, so it can drift forever and fill ultrawide.
class SeaStreaks extends Control:
	var offset: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var tile: Vector2 = Vector2(STREAKS.get_size()) * size.y / MOCKUP.y
		var shift: Vector2 = Vector2(fposmod(offset.x * tile.x / MOCKUP.x, tile.x), fposmod(offset.y * tile.y / MOCKUP.y, tile.y))
		# Centred like the mockup when the screen is wider than 16:9.
		var start: Vector2 = Vector2(fposmod((size.x - tile.x) * 0.5 + shift.x, tile.x) - tile.x, shift.y - tile.y)
		var y: float = start.y
		while y < size.y:
			var x: float = start.x
			while x < size.x:
				draw_texture_rect(STREAKS, Rect2(Vector2(x, y), tile), false)
				x += tile.x
			y += tile.y

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	# The sea: the game's own ocean in its own small world, camera straight down.
	var holder: SubViewportContainer = SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 0
	holder.add_child(viewport)
	ocean = OceanPresentation.new()
	ocean.palette = OCEAN_PALETTE
	ocean.quality = 1
	viewport.add_child(ocean)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = SEA_VIEW_METRES
	camera.far = 200.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 100, 0), Vector3.ZERO, Vector3.FORWARD)
	camera.current = true
	sea = SeaStreaks.new()
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sea.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sea)
	place(art(LOGO), Rect2(236, 84, 1228, 540))
	press = art(PRESS)
	place(press, Rect2(352, 700, 960, 98))
	press.resized.connect(func() -> void: press.pivot_offset = press.size * 0.5)

func art(texture: Texture2D) -> TextureRect:
	var item: TextureRect = TextureRect.new()
	item.texture = texture
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(item)
	return item

## Anchors a piece at its place in the mockup; keep-aspect stops stretching on
## 16:10 or ultrawide screens.
func place(item: Control, mockup_rect: Rect2) -> void:
	item.anchor_left = mockup_rect.position.x / MOCKUP.x
	item.anchor_top = mockup_rect.position.y / MOCKUP.y
	item.anchor_right = mockup_rect.end.x / MOCKUP.x
	item.anchor_bottom = mockup_rect.end.y / MOCKUP.y
	item.offset_left = 0
	item.offset_top = 0
	item.offset_right = 0
	item.offset_bottom = 0

func _process(delta: float) -> void:
	clock += delta
	sea.offset = STREAK_DRIFT * clock
	sea.queue_redraw()
	# Gentle pulse on "Press Any Button".
	var pulse: float = 0.5 + 0.5 * sin(clock * TAU / 1.6)
	press.modulate.a = lerpf(0.6, 1.0, pulse)
	press.scale = Vector2.ONE * lerpf(1.0, 1.04, pulse)
	if leaving >= 0.0:
		leaving += delta
		root.modulate.a = 1.0 - clampf(leaving / FADE_SECONDS, 0.0, 1.0)
		if leaving >= FADE_SECONDS:
			dismissed.emit()
			queue_free()

func _input(event: InputEvent) -> void:
	if leaving >= 0.0: return
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if not key.pressed or key.echo: return
		# Cmd/Ctrl/Alt shortcuts (Cmd+Q, Alt+F4) and F3 (debug mode) keep working.
		if key.meta_pressed or key.ctrl_pressed or key.alt_pressed: return
		if key.keycode == KEY_F3 or key.physical_keycode == KEY_F3:
			dismiss()
			return
	elif not ((event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)):
		return
	get_viewport().set_input_as_handled()
	dismiss()

func dismiss() -> void:
	if leaving >= 0.0: return
	leaving = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
