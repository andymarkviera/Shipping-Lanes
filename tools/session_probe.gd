extends Node
const Authority = preload("res://features/session/session_authority.gd")
const Session = preload("res://features/main/test_session.gd")
var checks: int = 0
var failures: int = 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var authority: SessionAuthority = Authority.new()
	var pristine: Dictionary = authority.view()
	var copy: Dictionary = authority.view()
	copy.player.wallet_minor = 999999
	copy.inventory.cargo.cargo_test_container = 100
	check(authority.view() == pristine,"Read views cannot mutate authority")
	for args: Array in [["intruder","ship_test",0],["player_test","missing",0],["player_test","ship_test",true],["player_test","ship_test",1]]:
		check(not authority.request_test_load(args[0],args[1],args[2]).ok,"Invalid request rejected")
		check(authority.view() == pristine,"Rejected action changes nothing")
	var first: Dictionary = authority.request_test_load("player_test","ship_test",0)
	check(first.ok and first.state.player.wallet_minor == 10000 and first.state.inventory.cargo.cargo_test_container == 1 and first.state.revision == 1,"Atomic approval")
	first.state.player.wallet_minor = 123456
	check(authority.view().player.wallet_minor == 10000,"Result cannot mutate authority")
	check(authority.request_test_load("player_test","ship_test",0).code == "stale_revision","Repeated stale request does not charge twice")
	check(authority.request_test_load("player_test","ship_test",1).ok,"Second valid load")
	var exhausted: Dictionary = authority.view()
	check(authority.request_test_load("player_test","ship_test",2).code == "insufficient_funds","Clear funds rejection")
	check(authority.view() == exhausted,"No partial charge or cargo on rejection")
	var local: TestSession = Session.new()
	var hosted: TestSession = Session.new()
	local.hosted = false
	hosted.hosted = true
	check(local.request_test_load(0) == hosted.request_test_load(0),"Local and hosted fixture use identical action path")
	local.free()
	hosted.free()
	var app: Node = load("res://features/main/main.tscn").instantiate()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	app.start_session()
	app.menu.test_load_button.pressed.emit()
	check(app.session.state_view().player.wallet_minor == 10000 and app.menu.session_result.text == "Test container loaded.","UI request reaches session and displays approval")
	app.return_to_title()
	app.continue_session()
	check(app.session.state_view().inventory.cargo.cargo_test_container == 1 and app.menu.session_revision == 1,"Continue retains authoritative fixture")
	app.menu.test_load_button.pressed.emit()
	app.menu.test_load_button.pressed.emit()
	check(app.menu.session_result.text.begins_with("Not enough") and app.session.state_view().inventory.cargo.cargo_test_container == 2,"UI displays rejection without extra cargo")
	app.pause_session()
	app.menu.test_load_button.pressed.emit()
	check(app.session.state_view().revision == 2,"Inactive UI cannot dispatch")
	app.start_session()
	check(app.session.state_view() == pristine,"New session resets disposable state")
	app.queue_free()
	await get_tree().process_frame
	print("SESSION_CHECK_PASS (%d checks)" % checks if failures == 0 else "SESSION_CHECK_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
