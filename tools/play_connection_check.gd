extends SceneTree
## Isolated HTTP/UDP loopback only; see check_play_connection.py.
const Connection = preload("res://features/network/play_connection.gd")
var failures: int = 0
var count: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func run() -> void:
	root.child_entered_tree.connect(func(node: Node):
		if node.get_script() == Connection: node.lookup_on_ready = false)
	var endpoint: String = ""
	var mode: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--feed="): endpoint = arg.trim_prefix("--feed=")
		if arg.begins_with("--case="): mode = arg.trim_prefix("--case=")
	for text: String in ["null", "[]", "bad", '{"host":"","port":24565}', '{"host":"https://example.invalid","port":24565}', '{"host":"example.invalid","port":1.5}', '{"host":"example.invalid","port":70000}', '{"host":"example.invalid","port":"24565"}']:
		expect(Connection.parse_feed(text.to_utf8_buffer()).get("error") == "offline", "reject malformed feed")
	expect(Connection.parse_feed('{"host":"example.invalid","port":24565}'.to_utf8_buffer()).get("port") == 24565, "minimal feed supported")
	expect(Connection.parse_feed('{"status":"updating"}'.to_utf8_buffer()).get("error") == "updating", "upkeep needs no address")
	expect(Connection.parse_feed('{"version":"old"}'.to_utf8_buffer()).get("error") == "mismatch", "release mismatch")
	expect(Connection.parse_feed(" ".repeat(4097).to_utf8_buffer()).get("error") == "offline", "body bounded")
	if mode in ["handshake_mismatch", "handshake_updating", "offline", "disconnect"]:
		var runtime: Node = load("res://features/network/dedicated_runtime.tscn").instantiate()
		root.add_child(runtime)
		current_scene = runtime
		if mode == "handshake_mismatch":
			for row: Dictionary in runtime.multiplayer.connected_to_server.get_connections(): runtime.multiplayer.connected_to_server.disconnect(row.callable)
			runtime.multiplayer.connected_to_server.connect(func(): runtime.hello.rpc_id(1, runtime.PROTOCOL, "Captain", "older-release"))
		var deadline: int = Time.get_ticks_msec() + 15000
		while Time.get_ticks_msec() < deadline:
			await create_timer(0.01).timeout
			if runtime.connection_card.retry.visible: break
		expect(runtime.connection_card.retry.visible, "connection fails with retry")
		var expected: String = {"handshake_mismatch": "Update required", "handshake_updating": "Server is updating"}.get(mode, "Server offline")
		expect(runtime.connection_card.heading.text == expected, "correct runtime card: " + runtime.connection_card.heading.text + " status=" + runtime.status)
		expect(runtime.entity.is_empty() and runtime.samples.is_empty(), "failed runtime stops commands/presentation")
		expect(not runtime.view.controls.input_allowed(), "failure blocks helm")
		runtime.connection_card.back_to_menu()
	else:
		var app: Node = load("res://features/main/main.tscn").instantiate()
		root.add_child(app)
		current_scene = app
		app.navigate("game")
		for frame: int in 4: await process_frame
		var card: Control = current_scene
		expect(card.get_script() == Connection, "Play routes to connection screen")
		card.lookup(endpoint)
		var deadline: int = Time.get_ticks_msec() + 15000
		while Time.get_ticks_msec() < deadline:
			await create_timer(0.01).timeout
			if mode == "success":
				if current_scene != card and current_scene.get("received_states") != null and current_scene.received_states > 2: break
			elif card.retry.visible: break
		if mode == "success":
			var runtime: Node = current_scene
			if runtime.get("received_states") == null:
				print("Unexpected scene: ", runtime, " heading=", card.heading.text)
				quit(1)
				return
			expect(runtime.get("received_states") != null and runtime.received_states > 2, "HTTP feed routes into replicated gameplay")
			expect(not has_meta(Connection.TARGET), "address consumed, never retained")
			expect(not runtime.connection_card.visible and runtime.view.visible, "card leaves when snapshots arrive")
			expect(runtime.view.persistence == null, "multiplayer never opens local voyage")
			runtime.fail("test disconnect")
			expect(runtime.connection_card.heading.text == "Server offline", "disconnect card")
			runtime.connection_card.retry.pressed.emit()
			for frame: int in 4: await process_frame
			expect(current_scene.get_script() == Connection and not has_meta(Connection.TARGET), "Retry returns to fresh feed lookup")
			current_scene.back_to_menu()
		else:
			expect(card.retry.visible, "HTTP failure offers retry")
			expect(card.heading.text == {"mismatch": "Update required", "updating": "Server is updating"}.get(mode, "Server offline"), "correct feed card")
			card.back_to_menu()
	for frame: int in 4: await process_frame
	expect(not paused, "tree never paused")
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null
	for frame: int in 3: await process_frame
	print("PLAY_CONNECTION_PASS (%d assertions)" % count if failures == 0 else "PLAY_CONNECTION_FAILED")
	quit(0 if failures == 0 else 1)
