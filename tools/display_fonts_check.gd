extends SceneTree
## Isolated real-screen layout and glyph checks; optionally capture with -- --shots.
const DISPLAY = preload("res://features/ui/display_fonts.gd")
const Progression = preload("res://features/game/progression.gd")
var failures: int = 0
var checks: int = 0
var shots: bool = false

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame: int in 5: await process_frame

func capture(label: String) -> void:
	if not shots: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/lettering_%s_%dx%d.png" % [label, root.size.x, root.size.y])

func fits(control: Control, label: String) -> void:
	var rect: Rect2 = control.get_global_rect()
	expect(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1).encloses(rect), label + " inside viewport")
	if control is Label and control.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var width: float = control.get_theme_font("font").get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x
		expect(width <= control.size.x + 1, label + " glyph width fits")

func run() -> void:
	shots = "--shots" in OS.get_cmdline_user_args()
	for kind: String in ["white", "gold", "red"]:
		var font: Font = DISPLAY.font(kind)
		for code: int in range(32, 127):
			expect(font.has_char(code), "%s U+%04X" % [kind, code])
		for px: int in [32, 64, 128]:
			expect(font.get_string_size("PGHOV4!? 0123456789", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 0, "Measured glyphs")
	for resolution: Vector2i in [Vector2i(1440,900), Vector2i(2560,1080)]:
		root.size = resolution
		var title: TitleScreen = TitleScreen.new()
		root.add_child(title)
		await settle()
		fits(title.logo, "Title logo")
		await capture("title")
		title.arriving = title.ARRIVAL_SECONDS
		title.ship.show()
		title.update_arrival()
		title.settle()
		var menu: ApplicationMenu = ApplicationMenu.new()
		root.add_child(menu)
		menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		menu.use_title_backdrop(title)
		menu.show_page("title", false)
		await settle()
		for item: Button in menu.pages.title.items: fits(item, "Menu " + item.text)
		await capture("menu")
		menu.queue_free()
		title.queue_free()
		await settle()
	set_meta("game_save_path", "user://display_fonts_check/voyage.db")
	DirAccess.make_dir_recursive_absolute("user://display_fonts_check")
	change_scene_to_file("res://features/game/game.tscn")
	for frame: int in 1200:
		await process_frame
		if current_scene != null and current_scene.is_node_ready() and is_instance_valid(current_scene.persistence) and current_scene.persistence.ready_to_save: break
	var game: Node = current_scene
	expect(game != null and game.persistence.ready_to_save, "Real game ready")
	if game == null: quit(1); return
	var fuel: float = game.ship.state.fuel_liters
	game.ship.state.fuel_liters = 1.0
	game.offer_notice = "Collision! Hull 75%. Dock and click REPAIR."
	await settle()
	# Patch 3.2: warnings are plain bold text in red, not the red sprite sheet.
	expect(game.voyage_hud.instruments.get_theme_font("font") == DISPLAY.plain_font() and game.voyage_hud.instruments.get_theme_color("font_color").r > 0.9, "Low fuel is plain red text")
	expect(game.loading_text.get_theme_font("font") == DISPLAY.plain_font() and game.loading_text.get_theme_color("font_color").r > 0.9, "Collision is plain red text")
	game.ship.state.fuel_liters = fuel
	game.offer_notice = ""
	await settle()
	expect(not game.voyage_hud.instruments.has_theme_font_override("font"), "Healthy instruments return to body font")
	for resolution: Vector2i in [Vector2i(1440,900), Vector2i(2560,1080)]:
		root.size = resolution
		await settle()
		game.game_hud.show_salute()
		await settle()
		fits(game.game_hud.knots, "Knots")
		fits(game.voyage_hud.money, "Wallet")
		fits(game.game_hud.salute, "Salute")
		await capture("hud")
		game.hangar.open()
		await settle()
		for kind: String in game.hangar.kinds:
			if shots and kind != "small_galleon": continue
			game.hangar.index = game.hangar.kinds.find(kind)
			game.hangar.refresh()
			await settle()
			fits(game.hangar.name_label, kind + " name")
			fits(game.hangar.wallet_label, kind + " wallet")
			fits(game.hangar.action_button, kind + " price")
			if kind == "small_galleon": await capture("hangar")
		game.hangar.close()
	print("DISPLAY_FONTS_CHECK %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
