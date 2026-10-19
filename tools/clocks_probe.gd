extends Node
const Clock = preload("res://features/simulation/simulation_clock.gd")
const Authority = preload("res://features/session/session_authority.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var clock: SimulationClock = Clock.new()
	clock.sample(0,true)
	clock.sample(49999,true)
	check(clock.view().clock_ms == 0 and clock.view().remainder_us == 49999,"Subtick remainder retained")
	clock.sample(50000,true)
	check(clock.view().clock_ms == 50,"Exact tick boundary")
	clock.sample(100000,false)
	clock.sample(150000,true)
	check(clock.view().clock_ms == 100,"Paused time not credited later")
	clock.sample(1,true)
	clock.sample(150000,true)
	check(clock.view().clock_ms == 100,"Backward/duplicate samples grant no time")
	clock.sample(10150000,true)
	check(clock.view().clock_ms == 350 and clock.view().discarded_us == 9750000,"Long gap bounded, remainder discarded deliberately")
	clock.reanchor()
	clock.sample(999999999,true)
	check(clock.view().clock_ms == 350,"Reattach does not catch up offline time")
	var authority: SessionAuthority = Authority.new()
	check(not authority.request_test_timer("player_test").ok,"Detached timer rejected")
	authority.attach_clock()
	authority.pump(0,true)
	check(not authority.request_test_timer("intruder").ok,"Unknown actor rejected")
	check(authority.request_test_timer("player_test").ok,"Test timer starts")
	check(not authority.request_test_timer("player_test").ok,"Duplicate start cannot reset deadline")
	var view: Dictionary = authority.timer_view()
	view.due_world_ms = 0
	check(authority.timer_view().due_world_ms == 10000,"Timer view is a copy")
	for i: int in range(1,200): authority.pump(i * 50000,true)
	check(authority.timer_view().status == "running" and authority.timer_view().remaining_ms == 50,"Not complete before deadline")
	authority.pump(10000000,true)
	check(authority.timer_view().status == "completed" and authority.timer_view().completion_count == 1 and authority.timer_view().completed_world_ms == 10000,"Completes at exact authoritative deadline")
	authority.pump(10050000,true)
	check(authority.timer_view().completion_count == 1,"Completion not duplicated")
	check(authority.view().player.wallet_minor == 20000,"Timer does not alter economy")
	var app: Node = load("res://features/main/main.tscn").instantiate()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	app.start_session(true)
	app.menu.timer_button.pressed.emit()
	await get_tree().create_timer(0.12).timeout
	var before: int = app.session.timer_view().clock.clock_ms
	app.open_settings()
	await get_tree().create_timer(0.12).timeout
	check(app.session.timer_view().clock.clock_ms > before,"Hosted settings does not freeze timer")
	app.get_node("UI/Settings").close()
	app.return_to_title()
	var retained: SessionAuthority = app.continuation.authority
	before = retained.timer_view().clock.clock_ms
	await get_tree().create_timer(0.12).timeout
	check(retained.timer_view().clock.clock_ms == before and not retained.timer_view().attached,"Title explicitly suspends fixture work")
	app.continue_session()
	check(app.session.timer_view().clock.clock_ms == before and app.session.timer_view().due_world_ms == 10000,"Continue transfers deadline and clock")
	app.start_session(false)
	check(retained.timer_view().status == "canceled","Replacing live session cancels old work")
	app.menu.timer_button.pressed.emit()
	await get_tree().create_timer(0.12).timeout
	app.pause_session()
	before = app.session.timer_view().clock.clock_ms
	await get_tree().create_timer(0.12).timeout
	check(app.session.timer_view().clock.clock_ms == before,"Offline pause freezes operation")
	app.return_to_title()
	retained = app.continuation.authority
	app.start_session()
	check(retained.timer_view().status == "canceled" and app.session.timer_view().status == "idle","New from title cancels continuation")
	app.menu.timer_button.pressed.emit()
	app.return_to_title()
	retained = app.continuation.authority
	app.queue_free()
	await get_tree().process_frame
	check(retained.timer_view().status == "canceled","Application teardown cancels retained work")
	print("CLOCK_CHECK_PASS (%d checks)" % checks if failures == 0 else "CLOCK_CHECK_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
