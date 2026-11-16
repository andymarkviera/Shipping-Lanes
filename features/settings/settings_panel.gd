class_name SettingsPanel
extends PanelContainer

signal closed
var controls: PlayerControls
var draft: InputPreferences
var waiting_action: String = ""
var rows: Dictionary = {}
var status: Label
var ambience_volume: HSlider
var volume: HSlider
var sensitivity: HSlider
var invert_y: CheckBox
var fullscreen_option: CheckBox
var save_button: Button
var water_quality: OptionButton

func _ready() -> void:
	# Aesthetics 5: the playful look.
	preload("res://features/ui/playful_theme.gd").dress(self)
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -340
	offset_right = 340
	offset_top = -290
	offset_bottom = 290
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading: Label = Label.new()
	heading.text = "Settings"
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	volume = add_slider(column, "Master volume", 0.0, 1.0, false)
	ambience_volume = add_slider(column, "Music/Ambience", 0.0, 1.0, false)
	ambience_volume.value_changed.connect(preview_ambience)
	sensitivity = add_slider(column, "Camera sensitivity", 0.25, 3.0, true)
	invert_y = CheckBox.new()
	invert_y.text = "Invert camera Y: Off"
	invert_y.toggled.connect(func(enabled: bool) -> void: invert_y.text = "Invert camera Y: " + ("On" if enabled else "Off"))
	column.add_child(invert_y)
	fullscreen_option = CheckBox.new()
	fullscreen_option.text = "Fullscreen: Off"
	fullscreen_option.toggled.connect(func(enabled: bool) -> void: fullscreen_option.text = "Fullscreen: " + ("On" if enabled else "Off"))
	column.add_child(fullscreen_option)
	var water_row: HBoxContainer = HBoxContainer.new()
	column.add_child(water_row)
	var water_label: Label = Label.new()
	water_label.text = "Water quality"
	water_label.custom_minimum_size.x = 180
	water_row.add_child(water_label)
	water_quality = OptionButton.new()
	for choice: String in ["Low", "Medium", "High"]: water_quality.add_item(choice)
	water_quality.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	water_row.add_child(water_quality)
	var hint: Label = Label.new()
	hint.text = "Click a key to change it. Esc cancels."
	column.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 155
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var bindings_column: VBoxContainer = VBoxContainer.new()
	bindings_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bindings_column)
	for action: String in InputPreferences.DEFAULT_BINDINGS:
		var row: HBoxContainer = HBoxContainer.new()
		bindings_column.add_child(row)
		var label: Label = Label.new()
		label.text = InputPreferences.LABELS[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button: Button = Button.new()
		button.custom_minimum_size.x = 155
		button.disabled = action == "pause"
		button.pressed.connect(begin_binding.bind(action))
		row.add_child(button)
		rows[action] = button
	status = Label.new()
	status.custom_minimum_size.y = 42
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var footer: HBoxContainer = HBoxContainer.new()
	column.add_child(footer)
	var reset: Button = Button.new()
	reset.text = "Reset defaults"
	reset.pressed.connect(reset_draft)
	footer.add_child(reset)
	var cancel: Button = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(close)
	footer.add_child(cancel)
	save_button = Button.new()
	save_button.text = "Save & close"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(save)
	footer.add_child(save_button)

func add_slider(parent: VBoxContainer, title: String, minimum: float, maximum: float, show_value: bool) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = title
	label.custom_minimum_size.x = 180
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	if show_value:
		var value_label: Label = Label.new()
		value_label.custom_minimum_size.x = 55
		value_label.text = "%.2f" % slider.value
		row.add_child(value_label)
		slider.value_changed.connect(func(value: float) -> void: value_label.text = "%.2f" % value)
	return slider

func open(service: PlayerControls) -> void:
	controls = service
	draft = controls.preferences.duplicate(true)
	controls.set_menu_open(true)
	waiting_action = ""
	refresh()
	status.text = controls.settings_notice
	show()
	save_button.grab_focus()

func refresh() -> void:
	volume.value = draft.master_volume
	ambience_volume.value = draft.ambience_volume
	sensitivity.value = draft.camera_sensitivity
	invert_y.button_pressed = draft.invert_camera_y
	fullscreen_option.button_pressed = draft.fullscreen
	water_quality.select(draft.water_quality)
	for action: String in rows:
		rows[action].text = OS.get_keycode_string(draft.bindings[action])

func begin_binding(action: String) -> void:
	waiting_action = action
	status.text = "Press a new key for " + InputPreferences.LABELS[action] + ". Escape cancels."

func reset_draft() -> void:
	waiting_action = ""
	draft = PlayerControls.DEFAULTS.duplicate(true)
	refresh()
	status.text = "Defaults selected. Save to apply them."

func preview_ambience(value: float) -> void:
	var ambience: Node = get_tree().root.get_node_or_null("MenuBeachAmbience")
	if ambience != null: ambience.set_volume(value)
	get_tree().call_group("game_ambience", "set_volume", value)

func close() -> void:
	if controls != null: preview_ambience(controls.preferences.ambience_volume)
	waiting_action = ""
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	hide()
	if controls != null:
		controls.set_menu_open(false)
	closed.emit()

func save() -> void:
	if not waiting_action.is_empty():
		status.text = "Choose a key or press Escape to cancel the binding first."
		return
	draft.master_volume = volume.value
	draft.ambience_volume = ambience_volume.value
	draft.camera_sensitivity = sensitivity.value
	draft.invert_camera_y = invert_y.button_pressed
	draft.fullscreen = fullscreen_option.button_pressed
	draft.water_quality = water_quality.selected
	var error: String = controls.save_preferences(draft)
	if error.is_empty():
		close()
	else:
		status.text = error

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		if waiting_action.is_empty():
			close()
		else:
			waiting_action = ""
			status.text = "Binding change canceled."
		get_viewport().set_input_as_handled()
	elif not waiting_action.is_empty():
		get_viewport().set_input_as_handled()
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
			status.text = "Use a single key without Shift, Ctrl, Alt or Windows."
			return
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var candidate: InputPreferences = draft.duplicate(true)
		candidate.bindings[waiting_action] = key
		var error: String = candidate.validation_error()
		if not error.is_empty():
			status.text = error
			return
		draft.bindings = candidate.bindings
		rows[waiting_action].text = OS.get_keycode_string(key)
		waiting_action = ""
		status.text = "Binding changed. Save to apply it."
