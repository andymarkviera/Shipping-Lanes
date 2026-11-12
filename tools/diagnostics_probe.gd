extends Node
var failures: int = 0
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var registry: DefinitionRegistry = DefinitionRegistry.new()
	var invalid: ShipDefinition = PrototypeCatalog.RECORDS[0].duplicate(true)
	invalid.cargo_type_ids = ["missing_cargo_for_diagnostic"]
	var records: Array[ContentDefinition] = PrototypeCatalog.RECORDS.duplicate()
	records[0] = invalid
	var errors: PackedStringArray = registry.load_definitions(records)
	check(str(errors).contains("ship_starter_container_01 -> missing_cargo_for_diagnostic"),"Bad definition identifies source and missing target")
	print("EXPECTED_VALIDATION_ERROR: ", "; ".join(errors))
	var app: Node = load("res://features/main/main.tscn").instantiate()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	app.start_session()
	var overlay: DeveloperOverlay = app.developer_overlay
	check(not overlay.enabled and not overlay.panel.visible,"Overlay starts off")
	check(not app.menu.dev_column.visible and not app.menu.footer.visible,"Test-scene buttons start hidden")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_F3
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	Input.flush_buffered_events()
	await get_tree().process_frame
	check(overlay.enabled and DevMode.enabled,"F3 enables developer mode and the overlay")
	await get_tree().process_frame
	check(overlay.readout.text.contains("ship_test") and overlay.readout.text.contains("40.00 L") and overlay.readout.text.contains("Not connected"),"Readout distinguishes fixture state from absent movement")
	check(overlay.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.readout.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Overlay cannot block pointer")
	var copy: Dictionary = app.session.diagnostic_view()
	copy.fuel_ml = 0
	check(app.session.state_view().ship.fuel_ml == 40000,"Diagnostics cannot mutate ship")
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	Input.flush_buffered_events()
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	Input.flush_buffered_events()
	check(not overlay.enabled and not overlay.panel.visible,"Shortcut hides overlay")
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	Input.flush_buffered_events()
	app.menu.test_load_button.pressed.emit()
	check(app.session.state_view().inventory.cargo.cargo_test_container == 1,"Normal action works with overlay off")
	app.pause_session()
	check(app.state == app.State.PAUSED,"Pause remains usable")
	app.queue_free()
	await get_tree().process_frame
	print("DIAGNOSTICS_CHECK_PASS (%d checks)" % checks if failures == 0 else "DIAGNOSTICS_CHECK_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
