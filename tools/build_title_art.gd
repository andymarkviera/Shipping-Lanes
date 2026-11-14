extends SceneTree
## Patch 2.7 item 1: cuts the title logo and the "Press Any Button" line out of
## Andy's mockup (2x Lanczos upscale), plus the mockup's wave streaks and curled
## swirl foam as one sea layer (1x, logo and text removed). Keys out the
## royal-blue sea and writes transparent PNGs to features/title/.
## Run: godot --headless --path . --script res://tools/build_title_art.gd
const SOURCE: String = "res://docs/reference/main_menu/title_press_any_button.png"

func _init() -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	image.convert(Image.FORMAT_RGBA8)
	cut(image, Rect2i(236, 84, 1228, 540), 6000, 2, [], "res://features/title/title_logo.png")
	cut(image, Rect2i(352, 700, 960, 98), 400, 2, [], "res://features/title/press_any_button.png")
	var whole: Rect2i = Rect2i(Vector2i.ZERO, image.get_size())
	cut(image, whole, 300, 1, [Rect2i(260, 140, 1180, 470), Rect2i(352, 700, 960, 98)], "res://features/title/sea_streaks.png")
	quit()

static func background(pixel: Color) -> Color:
	return Color(0.0, clampf(pixel.g, 0.27, 0.37), clampf(pixel.b, 0.82, 0.88))

## Pieces smaller than keep_area, touching the cut edge, centred in a drop
## zone or only faint (sea halo) are removed.
func cut(source: Image, rect: Rect2i, keep_area: int, scale: int, drop_zones: Array[Rect2i], target: String) -> void:
	var image: Image = source.get_region(rect)
	var w: int = image.get_width()
	var h: int = image.get_height()
	for y: int in h:
		for x: int in w:
			var pixel: Color = image.get_pixel(x, y)
			var sea: Color = background(pixel)
			var distance: float = Vector3(pixel.r - sea.r, pixel.g - sea.g, pixel.b - sea.b).length()
			var alpha: float = clampf((distance - 0.10) / 0.25, 0.0, 1.0)
			if alpha <= 0.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			elif alpha < 1.0:
				# Unmix the sea so edges carry no blue fringe.
				var c: Color = (pixel - sea * (1.0 - alpha)) / alpha
				image.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1), alpha))
	var label: PackedInt32Array = PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var stack: PackedInt32Array = PackedInt32Array()
	for start: int in w * h:
		if label[start] != -1 or image.get_pixel(start % w, start / w).a < 0.05: continue
		var members: PackedInt32Array = PackedInt32Array([start])
		label[start] = start
		stack.append(start)
		var edge: bool = false
		var box: Rect2i = Rect2i(start % w, start / w, 1, 1)
		var solid: float = 0.0
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var px: int = i % w
			var py: int = i / w
			if px == 0 or py == 0 or px == w - 1 or py == h - 1: edge = true
			box = box.expand(Vector2i(px, py))
			solid = maxf(solid, image.get_pixel(px, py).a)
			for n: Vector2i in [Vector2i(px + 1, py), Vector2i(px - 1, py), Vector2i(px, py + 1), Vector2i(px, py - 1)]:
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h: continue
				var j: int = n.y * w + n.x
				if label[j] != -1 or image.get_pixel(n.x, n.y).a < 0.05: continue
				label[j] = start
				members.append(j)
				stack.append(j)
		var dropped: bool = false
		for zone: Rect2i in drop_zones: dropped = dropped or zone.has_point(box.get_center())
		if members.size() < keep_area or edge or dropped or solid < 0.6:
			for i: int in members: image.set_pixel(i % w, i / w, Color(0, 0, 0, 0))
	if scale > 1: image.resize(w * scale, h * scale, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(target))
	print("wrote ", target, " ", image.get_size())
