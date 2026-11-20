extends SceneTree
## Patch 3.2 item 1: one typography system in the real game scene.
## Walks the HUD, the docked port card, the debug layer (collapsed and open),
## the hangar and the world map at three screen sizes and checks:
## - every visible Button uses the shared plain button font at BUTTON_SIZE;
## - sprite lettering is used only by the port name, the money and the card title;
## - no Label or Button text is wider (or taller) than its own rect, and nothing
##   leaves the screen;
## - the DEBUG badge and the Debug Menu button/panel overlap no heading, the
##   throttle bar or the minimap.
## Debug session: no save is opened. Run:
## godot --headless --path . --script res://tools/ui_text_check.gd
const DISPLAY = preload("res://features/ui/display_fonts.gd")
const DebugGame = preload("res://features/debug/debug_game.gd")
var failures: Array[String] = []
var checks: int = 0
var game: Node

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("UI_TEXT FAILED: " + label)
	return condition

func settle() -> void:
	for frame: int in 4:
		await process_frame
		await physics_frame

func sprite(font: Font) -> bool:
	return font in [DISPLAY.WHITE, DISPLAY.GOLD, DISPLAY.RED]

func name_of(item: Control) -> String:
	return "%s \"%s\"" % [item.get_class(), str(item.get("text")).replace("\n", " ").left(40)]

## Every visible Label and Button under `base`.
func audit(base: Node, where: String) -> void:
	var allowed: Array = [game.game_hud.title, game.voyage_hud.money, game.voyage_hud.heading, game.hangar.name_label, game.hangar.wallet_label, game.hangar.title_label]
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size)).grow(1)
	for node: Node in [base] + base.find_children("*", "Control", true, false):
		if not (node is Label or node is Button): continue
		var item: Control = node
		if not item.is_visible_in_tree() or str(item.text).is_empty(): continue
		var font: Font = item.get_theme_font("font")
		var px: int = item.get_theme_font_size("font_size")
		var label: String = "%s: %s" % [where, name_of(item)]
		if item is Button:
			# Arrow-only buttons ("<", ">") may be bigger; the face is still shared.
			expect(font == DISPLAY.plain_font(), label + " uses the shared button font")
			if item.text.length() > 1: expect(px == DISPLAY.BUTTON_SIZE, label + " is %d px (want %d)" % [px, DISPLAY.BUTTON_SIZE])
		elif sprite(font):
			expect(item in allowed, label + " uses sprite lettering but is not a heading or money")
		var rect: Rect2 = item.get_global_rect()
		expect(screen.encloses(rect), label + " inside the screen %s" % rect)
		var lines: Vector2 = font.get_multiline_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var room: Vector2 = item.size
		if item is Button:
			var box: StyleBox = item.get_theme_stylebox("normal")
			room -= box.get_minimum_size()
		if item is Label and item.autowrap_mode != TextServer.AUTOWRAP_OFF: continue
		expect(lines.x <= room.x + 1.0, label + " text %.0f px fits width %.0f" % [lines.x, room.x])
		expect(lines.y <= room.y + 2.0, label + " text %.0f px fits height %.0f" % [lines.y, room.y])

func apart(a: Control, b: Control, label: String) -> void:
	if not a.is_visible_in_tree() or not b.is_visible_in_tree(): return
	expect(not a.get_global_rect().intersects(b.get_global_rect()), label)

func dock_anywhere() -> bool:
	for index: int in game.world_ports.size():
		if game.docking.state(1) == "docked": return true
		if not game.select_port(index): continue
		await settle()
		game.ship.global_transform = game.port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
		game.ship.velocity = Vector3.ZERO
		await settle()
		if not game.docking.request_dock(1, game.service_id(), game.cargo_id()).ok: continue
		for frame: int in 400:
			await physics_frame
			if game.docking.state(1) == "docked": return true
	return false

func run() -> void:
	set_meta(DebugGame.META, true)
	change_scene_to_file("res://features/game/game.tscn")
	for frame: int in 1200:
		await process_frame
		if current_scene != null and current_scene.is_node_ready() and is_instance_valid(current_scene.get("debug")): break
	game = current_scene
	if not expect(game != null and is_instance_valid(game.get("debug")), "debug game opened"): return finish()
	await settle()
	var debug: Node = game.debug
	var minimap: Control = game.minimap
	var bar: Control = game.game_hud.bar
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(2560, 1080)]:
		root.size = resolution
		var at: String = "%dx%d" % [resolution.x, resolution.y]
		await settle()
		# Under way, debug controls collapsed.
		expect(not debug.is_open(), at + ": debug controls start collapsed")
		audit(game.game_hud, at + " HUD")
		audit(game.voyage_hud, at + " objective card")
		audit(debug.toggle_button, at + " debug")
		audit(debug.badge, at + " debug badge")
		for item: Control in [debug.toggle_button, debug.badge]:
			apart(item, bar, at + ": %s clear of the throttle bar" % name_of(item))
			apart(item, minimap, at + ": %s clear of the minimap" % name_of(item))
		apart(debug.toggle_button, debug.badge, at + ": Debug Menu clear of the DEBUG badge")
		# Open.
		debug.toggle()
		await settle()
		audit(debug.panel, at + " debug panel")
		apart(debug.panel, bar, at + ": open debug panel clear of the throttle bar")
		apart(debug.panel, minimap, at + ": open debug panel clear of the minimap")
		apart(debug.panel, debug.toggle_button, at + ": open debug panel clear of its button")
		debug.toggle()
		# World map: the badge sits clear of every heading.
		game.globe_map.open()
		await settle()
		for node: Node in game.globe_map.find_children("*", "Label", true, false):
			if node is Label and (node as Label).is_visible_in_tree() and not (node as Label).text.is_empty():
				apart(debug.badge, node, at + ": DEBUG badge clear of map text " + name_of(node))
		game.globe_map.close()
		await settle()
	# Docked: the port card, its buttons and the job cards.
	root.size = Vector2i(1440, 900)
	if expect(await dock_anywhere(), "docked at a port"):
		for frame: int in 30: await process_frame
		for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(2560, 1080)]:
			root.size = resolution
			await settle()
			var at: String = "%dx%d docked" % [resolution.x, resolution.y]
			expect(game.game_hud.title.is_visible_in_tree(), at + ": port name heading shown")
			expect(sprite(game.game_hud.title.get_theme_font("font")) and sprite(game.voyage_hud.money.get_theme_font("font")), at + ": port name and money keep sprite lettering")
			expect(game.refuel_button.text == "Refuel" or game.refuel_button.text.begins_with("Refuel  "), at + ": Refuel button in Title Case with its price (%s)" % game.refuel_button.text)
			audit(game.port_panel, at + " port card")
			audit(game.game_hud, at + " HUD")
			audit(game.voyage_hud, at + " objective card")
			for card: Node in game.game_hud.cards.get_children():
				for node: Node in card.find_children("*", "Label", true, false):
					if (node as Label).text.begins_with("+"):
						expect((node as Label).get_theme_font("font") == DISPLAY.plain_font() and (node as Label).get_theme_font_size("font_size") == game.game_hud.PAY_PX, at + ": job amount in the plain bold face at one size")
		# Hangar buttons.
		game.hangar.open()
		await settle()
		audit(game.hangar, "hangar")
		game.hangar.close()
	finish()

func finish() -> void:
	print("UI_TEXT_CHECK %s (%d checks, %d failed)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
