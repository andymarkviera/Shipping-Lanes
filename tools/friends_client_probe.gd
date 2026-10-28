extends Node
var failures: int = 0

func _ready() -> void:
	reparent.call_deferred(get_tree().root)
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
		return
	print("PASS ", message)

func run() -> void:
	var scene: Node = load("res://features/main/main.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	var app: Node = get_tree().current_scene
	var labels: Array[String] = []
	for child: Node in app.menu.pages.title.get_children():
		if child is Button: labels.append(child.text)
	check(labels == ["SERVERS", "SETTINGS", "QUIT"], "Only three friends menu buttons")
	check(not app.menu.save_notice.visible and app.developer_overlay == null, "No local save notice or developer overlay")
	check(get_tree().get_root().gui_get_focus_owner().text == "SERVERS", "Keyboard focus starts on Servers")
	app.navigate("ports")
	check(get_tree().current_scene == app, "Development navigation is unavailable")
	app.navigate("settings")
	check(app.get_node("UI/Settings").visible, "Settings opens")
	app.get_node("UI/Settings").closed.emit()
	check(app.menu.pages.title.visible, "Settings returns to three-button menu")
	app.navigate("servers")
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene.get_script().resource_path == "res://features/network/public_entry.gd", "Servers opens authenticated entry")
	var entry: Node = get_tree().current_scene
	if OS.get_cmdline_user_args().has("--friends-configured-check"):
		check(not entry.configuration.is_empty() and not entry.join_button.disabled, "Portable public configuration enables server selection")
		check(entry.configuration.login.ca == OS.get_executable_path().get_base_dir().get_base_dir().path_join("server-certificate.pem"), "Certificate path resolves beside relocated client")
	else:
		check(entry.configuration.is_empty() and entry.join_button.disabled, "Unconfigured package cannot join an unintended server")
	get_tree().change_scene_to_file("res://features/main/main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene.menu.pages.title.get_child_count() == 3, "Return preserves friends menu")
	if failures == 0: print("FRIENDS_CLIENT_PASS")
	get_tree().quit(failures)
