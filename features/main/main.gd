extends Node
## Entry point for the project's separate world and interface scenes.

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(Vector2i(960, 640))
	$UI/StartupScreen/SettingsButton.pressed.connect(open_settings)
	$UI/Settings.closed.connect(func() -> void: $UI/StartupScreen.show())
	$Controls.command_requested.connect(func(action: StringName) -> void:
		if action == &"pause":
			open_settings())
	print("Shipping Lanes: Main scene loaded successfully.")

func open_settings() -> void:
	$UI/StartupScreen.hide()
	$UI/Settings.open($Controls)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		open_settings()
		get_viewport().set_input_as_handled()
