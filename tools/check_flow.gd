extends SceneTree
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var app = load("res://features/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.state == app.State.TITLE, "Boot must reach title")
	var ui_count: int = app.get_node("UI").get_child_count()
	var preferences: Dictionary = app.controls.preferences.to_data()
	for cycle: int in range(12):
		app.start_session()
		await process_frame
		check(app.get_node("World").get_child_count() == 1, "One active session")
		var saved_elapsed: float = app.session.elapsed
		app.return_to_title()
		check(app.get_node("World").get_child_count() == 0, "Title tears down session")
		check(app.menu.continue_button.visible, "Continue visible with snapshot")
		app.continue_session()
		check(app.session.elapsed == saved_elapsed, "Continue restores in-memory snapshot")
		app.start_session()
		check(app.session.elapsed == 0.0, "New session resets gameplay")
		check(app.controls.preferences.to_data() == preferences, "Gameplay reset preserves settings")
		check(app.get_node("UI").get_child_count() == ui_count, "No duplicate UI")
		app.return_to_title()
		await process_frame
	app.start_session(true)
	app.pause_session()
	var before: float = app.session.elapsed
	await create_timer(0.12).timeout
	check(app.session.elapsed > before, "Hosted policy keeps session running")
	check(not paused and not app.controls.input_allowed(), "Local menu cannot pause tree or send helm input")
	app.open_settings()
	app.get_node("UI/Settings").close()
	check(app.state == app.State.PAUSED, "Settings returns to pause")
	app.start_session(false)
	app.pause_session()
	before = app.session.elapsed
	await create_timer(0.12).timeout
	check(app.session.elapsed == before, "Offline fixture pauses locally")
	app.transition(app.State.PLAYING)
	await process_frame
	await process_frame
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	app._input(mouse)
	check(app.orbit_captured, "Fresh orbit press captures")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(app.state == app.State.PAUSED and not app.orbit_captured, "Focus loss pauses local input and releases mouse")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(app.state == app.State.PAUSED, "Focus return requires explicit resume")
	var escape: InputEventKey = InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_input(escape)
	check(app.state == app.State.PLAYING, "Escape resumes paused session")
	app.return_to_title()
	app.transition(app.State.SERVERS)
	app.open_settings()
	app.get_node("UI/Settings").close()
	check(app.state == app.State.SERVERS, "Settings preserves originating menu")
	app._unhandled_input(escape)
	check(app.state == app.State.TITLE, "Escape returns from servers")
	check(root.gui_get_focus_owner() != null, "Menus have keyboard focus")
	app.navigate("servers")
	app.queue_free()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.get_script().resource_path == "res://features/network/public_entry.gd", "Servers opens public entry scene")
	check(not current_scene.busy and current_scene.session.binding.is_empty(), "Server selection never auto-signs in")
	current_scene._unhandled_input(escape)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.get_script().resource_path == "res://features/main/main.gd", "Escape returns from public server selection")
	print("Application flow checks: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
