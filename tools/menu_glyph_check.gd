extends SceneTree
## Patch 3.1.1 item 3: no swirl menu label renders with a missing or misplaced
## glyph. Builds the real main menu, walks every swirl page and checks each
## label's characters exist in the sprite font the label is drawn with (read
## straight from the .fnt, so the system fallback font cannot hide a gap).
## Also checks the punctuation sits where it reads right: "-" mid-height (not
## on the baseline like "_"), "_" below it, quotes up at cap height.
## Run: godot --headless --path . --script res://tools/menu_glyph_check.gd
const SWIRL = preload("res://features/ui/swirl_menu.gd")
const DISPLAY = preload("res://features/ui/display_fonts.gd")
const FONTS: Array[String] = ["res://features/ui/fonts/white.fnt", "res://features/ui/fonts/gold.fnt", "res://features/ui/fonts/red.fnt"]
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("MENU_GLYPH FAILED: " + label)
	return condition

## id -> {"y": yoffset, "h": height, "advance": xadvance}, plus "base".
func read_font(path: String) -> Dictionary:
	var result: Dictionary = {"chars": {}}
	var text: String = FileAccess.get_file_as_string(path)
	var number: RegEx = RegEx.create_from_string("(\\w+)=(-?\\d+)")
	for line: String in text.split("\n"):
		var fields: Dictionary = {}
		for match_: RegExMatch in number.search_all(line): fields[match_.get_string(1)] = int(match_.get_string(2))
		if line.begins_with("common "): result.base = fields.base
		elif line.begins_with("char "): result.chars[fields.id] = {"y": fields.yoffset, "h": fields.height, "advance": fields.xadvance}
	return result

func swirls(node: Node, found: Array[Node]) -> void:
	if node.get_script() == SWIRL: found.append(node)
	for child: Node in node.get_children(): swirls(child, found)

func run() -> void:
	root.size = Vector2i(1440, 900)
	var fonts: Dictionary = {}
	for path: String in FONTS:
		var face: Dictionary = read_font(path)
		fonts[path] = face
		var name_: String = path.get_file()
		var chars: Dictionary = face.chars
		expect(chars.size() >= 95, "%s: all printable ASCII present (%d)" % [name_, chars.size()])
		var base: int = face.base
		var cap_top: int = chars[ord("H")].y
		var x_top: int = chars[ord("x")].y
		var hyphen: Dictionary = chars[ord("-")]
		var under: Dictionary = chars[ord("_")]
		var hyphen_mid: float = hyphen.y + hyphen.h / 2.0
		expect(hyphen_mid > x_top and hyphen.y + hyphen.h < base - 4, "%s: '-' sits mid-height, not on the baseline (centre %.0f, x-height %d..%d)" % [name_, hyphen_mid, x_top, base])
		expect(under.y + under.h > base and under.y > hyphen.y + hyphen.h, "%s: '_' sits below the baseline, clearly under '-'" % name_)
		for quote: String in ["\"", "'"]:
			expect(chars[ord(quote)].y <= cap_top + 2, "%s: %s sits at cap height" % [name_, quote])
		expect(chars[ord(",")].y + chars[ord(",")].h > base, "%s: ',' dips below the baseline" % name_)
		var space: int = chars[32].advance
		expect(space > 0 and space <= chars[ord("n")].advance, "%s: a space is no wider than a letter (%d)" % [name_, space])
	var layer: CanvasLayer = CanvasLayer.new()
	root.add_child(layer)
	var menu: ApplicationMenu = ApplicationMenu.new()
	layer.add_child(menu)
	menu.show_page("title", false)
	await process_frame
	var found: Array[Node] = []
	swirls(menu, found)
	expect(found.size() >= 3, "swirl menu pages found (%d)" % found.size())
	var labels: int = 0
	var single: bool = false
	for page: Node in found:
		for item: Button in page.items:
			labels += 1
			var path: String = item.get_theme_font("font").resource_path
			if not expect(fonts.has(path), "'%s' is drawn with a sprite font (%s)" % [item.text, path]): continue
			var missing: Array[String] = []
			for index: int in item.text.length():
				if not fonts[path].chars.has(item.text.unicode_at(index)): missing.append(item.text[index])
			expect(missing.is_empty(), "'%s': every glyph is in %s %s" % [item.text, path.get_file(), missing])
			expect(not item.text.contains("_") and not item.text.contains("  "), "'%s': no underscores or double spaces" % item.text)
			if item.text == "Single Player": single = true
	expect(labels >= 10, "swirl menu labels checked (%d)" % labels)
	expect(single, "Options shows \"Single Player\"")
	layer.queue_free()
	await process_frame
	await process_frame
	print("MENU_GLYPH CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
