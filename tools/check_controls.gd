extends SceneTree

var failures: Array[String] = []
var commands: Array[StringName] = []
var camera_moves: Array[Vector2] = []

func _initialize() -> void:
	run_checks.call_deferred()

func expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run_checks() -> void:
	var controls: PlayerControls = PlayerControls.new()
	controls.preferences_path = "user://controls-test-%s.json" % Time.get_ticks_usec()
	root.add_child(controls)
	controls.command_requested.connect(func(action: StringName) -> void: commands.append(action))
	controls.camera_motion_requested.connect(func(motion: Vector2) -> void: camera_moves.append(motion))
	var original_path: String = controls.preferences_path
	var candidate: InputPreferences = controls.preferences.duplicate(true)
	candidate.bindings.ship_throttle_up = KEY_T
	candidate.master_volume = 0.35
	candidate.camera_sensitivity = 1.5
	expect(controls.save_preferences(candidate).is_empty(), "First preference save")
	candidate.master_volume = 0.6
	expect(controls.save_preferences(candidate).is_empty(), "Replace existing preferences")
	controls.load_preferences()
	controls.apply_preferences()
	expect(controls.preferences.bindings.ship_throttle_up == KEY_T and is_equal_approx(controls.preferences.master_volume, 0.6), "Reload persisted values")
	var duplicate: InputPreferences = candidate.duplicate(true)
	duplicate.bindings.ship_steer_left = KEY_T
	expect(not controls.save_preferences(duplicate).is_empty(), "Reject duplicate binding")
	expect(controls.preferences.bindings.ship_steer_left == KEY_A, "Rejected binding leaves active controls intact")
	controls.preferences_path = "user://missing-settings-directory/preferences.json"
	expect(not controls.save_preferences(candidate).is_empty(), "Report write failure")
	controls.preferences_path = original_path
	var invalid: Dictionary = candidate.to_data()
	invalid.version = 999
	expect(InputPreferences.from_data(invalid) == null, "Reject unsupported version")
	invalid = candidate.to_data()
	invalid.bindings.ship_throttle_up = 65.5
	expect(InputPreferences.from_data(invalid) == null, "Reject fractional keycode")
	invalid = candidate.to_data()
	invalid.master_volume = "loud"
	expect(InputPreferences.from_data(invalid) == null, "Reject wrong preference type")
	var file: FileAccess = FileAccess.open(original_path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	controls.load_preferences()
	expect(not controls.settings_notice.is_empty(), "Report malformed file")
	expect(FileAccess.get_file_as_string(original_path) == "{broken json", "Preserve malformed file until explicit save")
	expect(controls.save_preferences(candidate).is_empty(), "Explicit save repairs malformed file")
	await process_frame
	key(KEY_T, true)
	expect(controls.action_strength("ship_throttle_up") == 0.0, "No vehicle input outside ship context")
	key(KEY_T, false)
	controls.set_ship_context(true)
	await process_frame
	await process_frame
	key(KEY_W, true)
	expect(controls.action_strength("ship_throttle_up") == 0.0, "Old key no longer controls throttle")
	key(KEY_W, false)
	key(KEY_T, true)
	expect(controls.action_strength("ship_throttle_up") == 1.0, "Rebound key controls throttle")
	expect(&"ship_throttle_up" in commands, "Unconsumed input emits command")
	var panel: SettingsPanel = SettingsPanel.new()
	root.add_child(panel)
	panel.open(controls)
	expect(controls.action_strength("ship_throttle_up") == 0.0, "Menu blocks held throttle")
	panel.close()
	await process_frame
	expect(controls.action_strength("ship_throttle_up") == 0.0, "Closing menu does not resume held key")
	key(KEY_T, false)
	await process_frame
	await process_frame
	key(KEY_T, true)
	expect(controls.action_strength("ship_throttle_up") == 1.0, "Fresh press after release works")
	key(KEY_T, false)
	panel.open(controls)
	panel.begin_binding("ship_steer_left")
	var command_count: int = commands.size()
	key(KEY_J, true)
	expect(panel.draft.bindings.ship_steer_left == KEY_J, "Rebind UI accepts a free key")
	expect(commands.size() == command_count, "Binding key never reaches vehicle commands")
	key(KEY_J, false)
	panel.close()
	expect(controls.preferences.bindings.ship_steer_left == KEY_A, "Cancel discards unsaved draft")
	panel.open(controls)
	panel.begin_binding("ship_steer_left")
	key(KEY_T, true)
	expect(panel.draft.bindings.ship_steer_left == KEY_A and not panel.waiting_action.is_empty(), "UI rejects binding conflict")
	key(KEY_T, false)
	key(KEY_ESCAPE, true)
	expect(panel.visible and panel.waiting_action.is_empty(), "Escape cancels capture before closing menu")
	key(KEY_ESCAPE, false)
	key(KEY_ESCAPE, true)
	expect(not panel.visible, "Second Escape closes settings")
	key(KEY_ESCAPE, false)
	panel.open(controls)
	panel.volume.value = 0.25
	panel.invert_y.button_pressed = true
	panel.save()
	controls.load_preferences()
	expect(not panel.visible and is_equal_approx(controls.preferences.master_volume, 0.25) \
		and controls.preferences.invert_camera_y, "Save UI persists its draft")
	expect(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.25)), "Volume setting applies to audio bus")
	var focus_button: Button = Button.new()
	root.add_child(focus_button)
	focus_button.grab_focus()
	await process_frame
	key(KEY_T, true)
	expect(controls.action_strength("ship_throttle_up") == 0.0, "GUI focus blocks raw polling")
	focus_button.release_focus()
	await process_frame
	expect(controls.action_strength("ship_throttle_up") == 0.0, "Focus release requires key release")
	key(KEY_T, false)
	await process_frame
	await process_frame
	Input.action_press("camera_orbit")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(2, 4)
	motion.position = Vector2(1000, 600)
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	expect(camera_moves.size() == 1 and camera_moves[0].is_equal_approx(Vector2(3, -6)), "Camera request applies sensitivity and inversion")
	Input.action_release("camera_orbit")
	await process_frame
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	key(KEY_T, true)
	expect(controls.action_strength("ship_throttle_up") == 0.0, "Window focus loss blocks controls")
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(controls.action_strength("ship_throttle_up") == 0.0, "Window return requires key release")
	key(KEY_T, false)
	await process_frame
	focus_button.free()
	panel.free()
	controls.free()
	DirAccess.remove_absolute(original_path)
	for failure: String in failures:
		push_error(failure)
	print("CONTROLS_CHECK_PASS" if failures.is_empty() else "CONTROLS_CHECK_FAILED")
	quit(0 if failures.is_empty() else 1)
