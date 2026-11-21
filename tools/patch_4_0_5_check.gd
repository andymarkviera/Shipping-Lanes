extends SceneTree
## Patch 4.0.5 headless checks (issue #230), in the real game scene with an
## isolated save. First the scene-free parts (patch_4_0_5_logic.gd, also run
## by check_catalog.gd), then item 1 with controller events sent through
## Input (as a real pad's are):
## - sailing: the left stick moves the throttle order and steers, B zeroes
##   the engine, RT raises the order, the right stick turns the camera; the
##   W key still works and the key bindings are unchanged;
## - glyphs: after a pad press the helm notice and the Controls list show
##   pad buttons; after a key press they show keys again;
## - menus: Menu (Start) opens the Esc menu; the D-pad moves the cursor
##   ring over its buttons; A presses CONTROLS (which lists pad buttons);
##   B goes back; A on RESUME closes the menu and the helm works again;
## - the HUD: sailing, the D-pad puts the ring on a HUD button while the
##   stick still steers; B hides it;
## - flying: RT / LT move the plane's throttle lever; the plane's engine
##   sound (item 3) is the turboprop's, plays, and rises in pitch with it.
## Run: godot --headless --path . --script res://tools/patch_4_0_5_check.gd
const Logic = preload("res://tools/patch_4_0_5_logic.gd")
const Prefs = preload("res://features/settings/input_preferences.gd")
const FOLDER: String = "user://patch_4_0_5_check"
const KIND: String = "plane_turboprop"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("PATCH 4.0.5 FAILED: " + label)
	return condition

func frames(count: int = 3) -> void:
	for frame: int in count:
		await process_frame
		await physics_frame

func wait_for(test: Callable) -> Node:
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and test.call(scene): return scene
	return null

## A pad's stick or trigger, as the driver sends it.
func axis(which: JoyAxis, value: float) -> void:
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = which
	motion.axis_value = value
	Input.parse_input_event(motion)

## A pad button press and release (the release a few frames later).
func button(which: JoyButton, hold: int = 2) -> void:
	for down: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.device = 0
		event.button_index = which
		event.pressed = down
		Input.parse_input_event(event)
		await frames(hold if down else 2)

func key(code: Key, down: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func run() -> void:
	# Headless windows start at 64 x 64: give the menus a real screen to lay out on.
	root.size = Vector2i(1280, 720)
	var logic: RefCounted = Logic.new()
	for part: String in Logic.PARTS: logic.call(part)
	checks += logic.checks
	for label: String in logic.failures:
		failures.append(label)
		print("PATCH 4.0.5 FAILED: " + label)
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = await wait_for(func(scene: Node) -> bool: return scene.get("persistence") != null and is_instance_valid(scene.persistence) and scene.persistence.ready_to_save)
	if not expect(game != null and is_instance_valid(game.get("aviation")), "the game opened"): return finish()
	await frames()
	await undock(game)
	await sail(game)
	await menus(game)
	await hud_cursor(game)
	await fly(game)
	for which: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]: axis(which, 0.0)
	await frames()
	game.leave()
	var main: Node = await wait_for(func(scene: Node) -> bool: return scene.name == "Main")
	if expect(main != null, "back at the main menu"): await main_menu(main)
	finish()

## The main menu's list keeps focus on its rows: the D-pad moves it (Godot's
## own focus moves) and A chooses, B goes back.
func main_menu(main: Node) -> void:
	await frames(10)
	var chosen: Array[String] = []
	main.menu.selected.connect(func(action: String) -> void: chosen.append(action))
	var first: Control = root.gui_get_focus_owner()
	if not expect(first is Button, "the main menu has a row focused (%s)" % first): return
	await button(JOY_BUTTON_DPAD_DOWN)
	var second: Control = root.gui_get_focus_owner()
	expect(second is Button and second != first, "the D-pad moves down the list (%s -> %s)" % [(first as Button).text, (second as Button).text if second is Button else "none"])
	await button(JOY_BUTTON_DPAD_UP)
	expect(root.gui_get_focus_owner() == first, "and back up")
	# Down to Credits (harmless: it only shows a page), then A.
	for step: int in 8:
		var row: Control = root.gui_get_focus_owner()
		if row is Button and (row as Button).text.to_lower().contains("credits"): break
		await button(JOY_BUTTON_DPAD_DOWN)
	await button(JOY_BUTTON_A)
	expect(chosen == ["credits"], "A chooses the focused row (%s)" % str(chosen))
	await button(JOY_BUTTON_B)
	await frames(10)
	var back: Control = root.gui_get_focus_owner()
	expect(chosen.size() == 2 and back is Button, "B goes back to the list (%s, focus %s)" % [str(chosen), (back as Button).text if back is Button else str(back)])
	# The menu's tick and select sounds finish before the check quits.
	for frame: int in 90: await process_frame

func helm_ready(game: Node) -> void:
	var controls: PlayerControls = game.controls
	controls.window_focused = true
	for frame: int in 60:
		if controls.input_allowed(): return
		await frames(1)

func undock(game: Node) -> void:
	if game.docking.state(game.owner_id) == "docked":
		game.docking.request_undock(game.owner_id)
		for frame: int in 400:
			await physics_frame
			if game.docking.state(game.owner_id) != "docked" and game.ship.helm_available(): break

func sail(game: Node) -> void:
	var controls: PlayerControls = game.controls
	var ship: HandlingShip = game.ship
	await helm_ready(game)
	if not expect(controls.input_allowed() and ship.helm_available(), "the helm is free to sail (%s)" % game.helm.notice.reason()): return
	var bindings: Dictionary = controls.preferences.bindings.duplicate()
	ship.zero_throttle()
	axis(JOY_AXIS_LEFT_Y, -1.0)
	await frames(40)
	var raised: float = ship.commanded_throttle
	expect(raised > 0.2, "left stick up raises the throttle order (%.2f)" % raised)
	expect(Gamepad.pad_last, "the pad is now the last device")
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await frames(10)
	expect(absf(ship.commanded_throttle - raised) < 0.12, "let go, the order holds (%.2f)" % ship.commanded_throttle)
	await button(JOY_BUTTON_B)
	expect(is_zero_approx(ship.commanded_throttle), "B puts the engine to zero (%.2f)" % ship.commanded_throttle)
	expect(not game.game_menu.is_open(), "sailing, B does not open the menu")
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(30)
	expect(ship.commanded_throttle > 0.15, "RT raises the order too (%.2f)" % ship.commanded_throttle)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	axis(JOY_AXIS_LEFT_X, 0.8)
	await frames(4)
	expect(controls.steering_axis() > 0.5, "left stick right steers right (%.2f)" % controls.steering_axis())
	axis(JOY_AXIS_LEFT_X, 0.0)
	var view: float = game.camera.orbit_offset
	axis(JOY_AXIS_RIGHT_X, 1.0)
	await frames(20)
	expect(absf(wrapf(game.camera.orbit_offset - view, -PI, PI)) > 0.2, "the right stick turns the camera (%.2f rad)" % absf(game.camera.orbit_offset - view))
	axis(JOY_AXIS_RIGHT_X, 0.0)
	await frames(4)
	# Item 1 glyphs: the helm notice speaks controller after a pad press.
	expect(Gamepad.swap("Press Esc, then Main Menu") == "Press [Menu], then Main Menu", "the game's hints name the Menu button")
	# The keyboard still sails, with its own keys.
	ship.zero_throttle()
	key(KEY_W, true)
	await frames(30)
	key(KEY_W, false)
	await frames(2)
	expect(ship.commanded_throttle > 0.2 and not Gamepad.pad_last, "W still raises the order; the keyboard is the last device again")
	expect(controls.preferences.bindings == bindings and bindings == Prefs.DEFAULT_BINDINGS, "the key bindings are unchanged")
	ship.zero_throttle()

func menus(game: Node) -> void:
	var controls: PlayerControls = game.controls
	var menu: CanvasLayer = game.game_menu
	var cursor: CanvasLayer = controls.pad_cursor
	await button(JOY_BUTTON_START)
	if not expect(menu.is_open() and controls.menu_open, "Menu (Start) opens the Esc menu"): return
	await button(JOY_BUTTON_DPAD_DOWN)
	expect(cursor.active and cursor.target is Button and menu.menu_column.is_ancestor_of(cursor.target), "the D-pad puts the ring on a menu button")
	var label: String = ""
	for step: int in 6:
		label = (cursor.target as Button).text if cursor.target is Button else ""
		if label == "CONTROLS": break
		await button(JOY_BUTTON_DPAD_DOWN)
	if not expect(label == "CONTROLS", "the ring reaches CONTROLS (%s)" % label): return
	await button(JOY_BUTTON_A)
	expect(menu.controls_panel.visible, "A presses CONTROLS")
	var listed: String = ""
	for cell: Node in menu.controls_grid.get_children(): listed += (cell as Label).text + " "
	expect(listed.contains("[L-stick]") and listed.contains("[Menu]"), "the Controls list shows the pad's buttons")
	await button(JOY_BUTTON_B)
	expect(not menu.controls_panel.visible and menu.panel.visible, "B goes back to the menu")
	for step: int in 6:
		label = (cursor.target as Button).text if cursor.target is Button else ""
		if label == "RESUME": break
		await button(JOY_BUTTON_DPAD_UP)
	expect(label == "RESUME", "the ring goes back up to RESUME (%s)" % label)
	await button(JOY_BUTTON_A)
	expect(not menu.is_open() and not controls.menu_open, "A on RESUME closes the menu")
	await button(JOY_BUTTON_START)
	await button(JOY_BUTTON_B)
	expect(not menu.is_open(), "Menu opens it and B closes it")
	await helm_ready(game)
	expect(controls.input_allowed(), "the helm has the controls again")

func hud_cursor(game: Node) -> void:
	var controls: PlayerControls = game.controls
	var cursor: CanvasLayer = controls.pad_cursor
	await button(JOY_BUTTON_DPAD_UP)
	expect(cursor.active and (cursor.target is BaseButton or cursor.target is Slider), "sailing, the D-pad puts the ring on a HUD button (%s)" % (cursor.target.name if cursor.target != null else "none"))
	axis(JOY_AXIS_LEFT_X, -0.9)
	await frames(4)
	expect(controls.steering_axis() < -0.5, "the stick still steers with the ring shown")
	axis(JOY_AXIS_LEFT_X, 0.0)
	await button(JOY_BUTTON_B)
	expect(not cursor.active, "B hides the ring")
	await frames(2)

func fly(game: Node) -> void:
	var air: Node = game.aviation
	game.ship.global_transform = game.port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
	game.ship.velocity = Vector3.ZERO
	await frames(2)
	var asked: Dictionary = game.docking.request_dock(game.owner_id, game.service_id(), game.cargo_id())
	for frame: int in 400:
		await physics_frame
		if game.docking.state(game.owner_id) == "docked": break
	if not expect(asked.ok and game.docking.state(game.owner_id) == "docked", "the ship docks to switch to a plane"): return
	air.unlock_all()
	air.plane_kind = KIND
	if not expect(air.switch_to_plane() and game.flying(), "the captain switches to the %s" % KIND): return
	await frames(4)
	await helm_ready(game)
	air.lever = 0.0
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(45)
	var lever: float = air.lever
	expect(lever > 0.3, "RT moves the plane's throttle lever up (%.2f)" % lever)
	var sound: Node3D = air.engine_sound
	if expect(is_instance_valid(sound) and sound.family == "prop2", "the turboprop has its own engine sound"):
		var core: AudioStreamPlayer = sound.players.core
		expect(core.playing and core.pitch_scale > 0.75, "its core plays, pitched by RPM (%.2f)" % core.pitch_scale)
		var pitch: float = core.pitch_scale
		await frames(60)
		expect(core.pitch_scale > pitch, "the pitch rises as the engine spools up (%.2f -> %.2f)" % [pitch, core.pitch_scale])
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	lever = air.lever
	axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await frames(45)
	expect(air.lever < lever - 0.2, "LT moves it down (%.2f -> %.2f)" % [lever, air.lever])
	axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	# X holds the brakes (Space) until the plane stops on the runway.
	var brake: InputEventJoypadButton = InputEventJoypadButton.new()
	brake.button_index = JOY_BUTTON_X
	brake.pressed = true
	Input.parse_input_event(brake)
	for frame: int in 600:
		await physics_frame
		if air.model.airspeed() < 0.5 and air.stopped_at() >= 0: break
	brake.pressed = false
	Input.parse_input_event(brake)
	expect(air.model.airspeed() < 0.5, "X brakes the plane to a stop (%.1f m/s)" % air.model.airspeed())
	await frames(4)
	expect(air.switch_to_boat() and not game.flying(), "back to the boat (%s)" % air.boat_reason())
	await frames(4)
	expect(not is_instance_valid(air.engine_sound) or not air.engine_sound.players.core.playing, "on the boat the plane engine is silent")

func finish() -> void:
	if failures.is_empty(): print("PATCH_4_0_5_CHECK_PASS (%d checks)" % checks)
	else: print("PATCH_4_0_5_CHECK_FAIL (%d of %d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
