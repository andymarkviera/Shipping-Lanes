extends SceneTree
## Patch 2.7 item 1: the "Press Any Button" screen loads its art, ignores
## Ctrl/Cmd shortcuts and continues on a key, click or gamepad button.
## Patch 2.7 item 2: that press sails a fleet container ship in, moves the logo
## to the top-left, and the screen stays as a backdrop below the menu layer; a
## second press skips the arrival. With a display, `-- --screenshot=<path>`
## saves the attract screen and `--arrived-screenshot=<path>` the arrival.
## Patch 2.7 item 4: a replay sails straight in without "Press Any Button";
## Start's dive tilts the camera down to the ship, ignores presses, fades the
## screen and fires `departed` (`--dive-screenshot=<path>` saves mid-dive).
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
	await check_replay_and_departure(shots)
	print("TITLE_CHECK %s" % ("passed" if failures == 0 else "failed: %d" % failures))
	quit(1 if failures else 0)

func check_replay_and_departure(shots: Dictionary) -> void:
	var title: TitleScreen = TitleScreen.new()
	root.add_child(title)
	await process_frame
	title.replay()
	check(title.arriving >= 0.0 and not title.press.visible, "A replay must sail in without Press Any Button")
	var started: int = Time.get_ticks_msec()
	while not title.arrived and Time.get_ticks_msec() - started < 15000: await process_frame
	check(title.arrived, "The replayed arrival must finish")
	var left: Array[bool] = [false]
	title.departed.connect(func() -> void: left[0] = true)
	title.depart()
	check(title.layer >= 10, "The dive must draw above the menu")
	for frame: int in 20: await process_frame
	send(key(KEY_SPACE, false))
	check(not left[0] and title.departing > 0.0, "A press must not cut the dive short")
	if shots.has("--dive-screenshot"):
		while title.departing < 1.2: await process_frame
		await shoot(shots["--dive-screenshot"], 0)
	started = Time.get_ticks_msec()
	while not left[0] and Time.get_ticks_msec() - started < 15000: await process_frame
	check(left[0], "The dive must end in `departed`")
	check(title.ship_camera.rotation.x > -PI / 3.0 and title.ship_camera.size < title.ship_view_size, "The camera must end low and close on the ship")
	check(is_instance_valid(title.fade) and title.fade.veil.modulate.a >= 1.0, "The screen must be covered when `departed` fires")
	# No scene change here: the veil still lifts by itself.
	var fade: ScreenFade = title.fade
	title.queue_free()
	fade.reveal()
	started = Time.get_ticks_msec()
	while is_instance_valid(fade) and Time.get_ticks_msec() - started < 5000: await process_frame
	check(not is_instance_valid(fade), "The fade must lift and free itself")

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
