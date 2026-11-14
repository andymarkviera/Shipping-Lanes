extends SceneTree
## Patch 2.7 item 1: the "Press Any Button" screen loads its art, ignores
## Ctrl/Cmd shortcuts, continues on a key, click or gamepad button, and frees
## itself. With a display, `-- --screenshot=<path>` saves what it shows.
## Run: godot --headless --path . --script res://tools/check_title.gd
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for event: InputEvent in [key(KEY_SPACE, false), mouse(), pad()]:
		var title: TitleScreen = TitleScreen.new()
		root.add_child(title)
		await process_frame
		check(title.LOGO.get_width() >= 2048 and title.PRESS != null and title.STREAKS != null, "Title art must load at 2x size")
		var gone: Array[bool] = [false]
		title.dismissed.connect(func() -> void: gone[0] = true)
		if event is InputEventKey:
			send(key(KEY_Q, true))
			for frame: int in 30: await process_frame
			check(is_instance_valid(title) and title.leaving < 0.0, "Ctrl/Cmd shortcuts must not dismiss the title")
			for argument: String in OS.get_cmdline_user_args():
				if argument.begins_with("--screenshot="):
					for frame: int in 60: await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(argument.trim_prefix("--screenshot="))
		send(event)
		var waited: float = 0.0
		while not gone[0] and waited < 3.0:
			await process_frame
			waited += 1.0 / 60.0
		await process_frame
		check(gone[0] and not is_instance_valid(title), "%s must continue past the title" % event.get_class())
	print("TITLE_CHECK %s" % ("passed" if failures == 0 else "failed: %d" % failures))
	quit(1 if failures else 0)

func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key, ctrl: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = ctrl
	event.pressed = true
	return event

func mouse() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

func pad() -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event
