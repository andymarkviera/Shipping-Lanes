extends SceneTree
## Patch 2.7 item 1: the "Press Any Button" screen loads its art, ignores
## Ctrl/Cmd shortcuts and continues on a key, click or gamepad button.
## Patch 2.7 item 2: that press sails a fleet container ship in, moves the logo
## to the top-left, and the screen stays as a backdrop below the menu layer; a
## second press skips the arrival. With a display, `-- --screenshot=<path>`
## saves the attract screen and `--arrived-screenshot=<path>` the arrival.
## Run: godot --headless --path . --script res://tools/check_title.gd
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var shots: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="): shots[argument.get_slice("=", 0)] = argument.get_slice("=", 1)
	for event: InputEvent in [key(KEY_SPACE, false), mouse(), pad()]:
		var title: TitleScreen = TitleScreen.new()
		root.add_child(title)
		await process_frame
		check(title.LOGO.get_width() >= 2048 and title.PRESS != null and title.STREAKS != null, "Title art must load at 2x size")
		check(title.ship != null and title.ship_kind in title.PROGRESSION.CONTAINER_KINDS, "Menu ship must be a fleet container ship")
		var gone: Array[bool] = [false]
		title.dismissed.connect(func() -> void: gone[0] = true)
		var started: int = Time.get_ticks_msec()
		if event is InputEventKey:
			send(key(KEY_Q, true))
			for frame: int in 30: await process_frame
			check(title.arriving < 0.0, "Ctrl/Cmd shortcuts must not dismiss the title")
			if shots.has("--screenshot"): await shoot(shots["--screenshot"], 60)
		send(event)
		await process_frame
		check(title.arriving >= 0.0 and title.ship.visible, "%s must start the ship's arrival" % event.get_class())
		if event is InputEventJoypadButton:
			# A second press skips the arrival.
			for frame: int in 5: await process_frame
			send(pad())
			await process_frame
			check(gone[0], "A second press must skip the arrival")
		started = Time.get_ticks_msec()
		while not gone[0] and Time.get_ticks_msec() - started < 15000:
			await process_frame
		check(gone[0], "%s must bring the ship in and show the menu" % event.get_class())
		check(is_instance_valid(title) and title.layer < 1 and title.root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Arrived title must sit below the menu and let clicks through")
		check(title.logo.position.x < title.root.size.x * 0.1 and title.logo.size.x < title.root.size.y * 0.95, "Logo must end small in the top-left")
		check(title.ship.position.x > 0.0, "Ship must settle right of centre")
		if event is InputEventKey and shots.has("--arrived-screenshot"): await shoot(shots["--arrived-screenshot"], 30)
		title.queue_free()
		await process_frame
	print("TITLE_CHECK %s" % ("passed" if failures == 0 else "failed: %d" % failures))
	quit(1 if failures else 0)

func shoot(path: String, frames: int) -> void:
	for frame: int in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

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
