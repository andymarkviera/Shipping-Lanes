extends SceneTree
const Service = preload("res://features/cargo/bulk_service.gd")
const BulkPanel = preload("res://features/cargo/bulk_service_panel.gd")
const ID = "bulk_0_grain_forward"
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh() -> RefCounted:
	var s = Service.new()
	s.seed_offers()
	s.docked = true
	return s
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var mode: String = "suite"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bulk-mode="): mode = arg.get_slice("=", 1)
	if mode == "suite": await suite()
	elif mode == "scene": await scene_test()
	else: durable(mode)
	print("BULK_SERVICE_PASS ", mode, " checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
func suite() -> void:
	var s = fresh()
	check(Service.valid(s.capture()), "new bulk state validates")
	check(s.start_loading(ID), "accept and reserve loading through shared operation")
	check(not s.start_loading(ID), "double click cannot reserve a second operation")
	check(s.advance(2.0) and s.manifest.lines().is_empty(), "partial loading is not cargo")
	var copy = Service.new()
	check(copy.restore(bytes_to_var(var_to_bytes(s.capture()))), "object-free pending loading round trip")
	check(copy.advance(3.0) and copy.manifest.lines()[0].quantity == 123456789, "resume remaining authority duration exactly once")
	var loaded: Dictionary = copy.capture()
	check(copy.operations.commit("bulk_operation_1").ok and copy.capture() == loaded, "repeated operation completion has no mutation")
	copy.port = Service.PORTS[1]
	check(copy.start_discharge(50000000) and copy.advance(5.0), "partial discharge commits")
	check(copy.credits == 4009 and copy.manifest.lines()[0].quantity == 73456789, "partial wallet and remaining grams reconcile")
	var partial: Dictionary = copy.capture()
	check(s.restore(partial), "partial voyage restores")
	check(s.offers.view(ID).terms == partial.seeds[ID].terms and s.manifest.lines()[0].hold_id == "hold_forward", "quote and hold survive interruption")
	var historical: Dictionary = s.offers.discharge("bulk_operation_2", ID, Service.OWNER, Service.SHIP, Service.PORTS[1], s.manifest, 50000000, true)
	check(historical.ok and historical.reward_minor == 0 and s.credits == 4009, "receipt retry after reload has zero economic delta")
	check(not s.start_discharge(73456790), "over-discharge rejected")
	check(s.start_discharge(73456789) and s.advance(1), "start remaining discharge")
	check(s.cancel() and s.manifest.lines()[0].quantity == 73456789 and s.credits == 4009, "cancel unfinished unload preserves partial voyage")
	check(s.start_discharge(73456789) and s.advance(5), "finish remaining discharge")
	check(s.credits == s.seeds[ID].reward_minor and s.manifest.lines().is_empty(), "final wallet matches one frozen quote")
	check(not s.start_discharge(1) and not s.start_loading(ID), "completed job cannot pay or load again")
	for field: String in ["credits", "sequence", "manifest", "events", "pose", "fuel", "condition", "active", "seeds"]:
		var bad: Dictionary = partial.duplicate(true)
		bad[field] = null
		var target = fresh()
		var before: Dictionary = target.capture()
		check(not target.restore(bad) and target.capture() == before, "malformed %s quarantined without mutation" % field)
	var changed: Dictionary = partial.duplicate(true)
	changed.seeds[ID].terms.origin_modifier_bp = 20000
	check(not Service.valid(changed), "changed frozen quote rejected")
	changed = partial.duplicate(true); changed.events.back().grams += 1
	check(not Service.valid(changed), "receipt quantity mismatch rejected")
	changed = partial.duplicate(true); changed.manifest[0].hold_id = "hold_aft"
	check(not Service.valid(changed), "hold provenance mismatch rejected")
	changed = partial.duplicate(true); changed.operations.records.bulk_operation_2.state = "running"
	check(not Service.valid(changed), "committed receipt cannot become unfinished work")
	var cancel = fresh()
	check(cancel.start_loading(ID) and cancel.advance(1) and cancel.cancel(), "cancel partial loading")
	check(cancel.offers.view(ID).state == "available" and cancel.manifest.lines().is_empty(), "cancel releases pending job without cargo")
	check(cancel.start_loading(ID) and cancel.advance(5), "released job can load once later")
	var panel = BulkPanel.new()
	root.add_child(panel)
	var visual = fresh()
	check(visual.start_loading(ID) and visual.advance(2), "prepare active authority for visual-only updates")
	var display: Dictionary = visual.presentation()
	var before_panel: Dictionary = visual.capture()
	for i: int in 100:
		display.progress = float(i) / 10
		panel.refresh(display, s.offers.list_at(s.port), true)
		panel.crane.queue_redraw()
	await process_frame
	check(visual.capture() == before_panel, "100 visual updates cannot finish or settle another operation")
	var selected = fresh()
	panel.refresh(selected.presentation(), selected.offers.list_at(selected.port), true)
	panel.commodities.select(1)
	panel.holds.select(1)
	panel.select_quote()
	check(panel.selected_id == "bulk_0_coal_aft", "commodity and hold selectors resolve authored quote")
	panel.load_requested.connect(func(id: String): selected.start_loading(id))
	panel.load_button.pressed.emit()
	check(selected.advance(5) and selected.manifest.lines()[0].cargo_id == "cargo_bulk_coal" and selected.manifest.lines()[0].hold_id == "hold_aft", "selected commodity and hold reach shared operation")
	panel.free()
	for cargo: String in ["grain", "coal", "ore", "limestone"]:
		for hold: String in ["forward", "aft"]:
			var pair = fresh()
			check(pair.start_loading("bulk_0_%s_%s" % [cargo, hold]) and pair.advance(5), "all commodity/hold pairs load")
			pair.port = Service.PORTS[1]
			check(pair.start_discharge(1) and pair.advance(5), "one-gram partial through shared path")
			check(Service.valid(pair.capture()), "partial pair checkpoint validates")
	# SQLite compare-and-swap failure cannot publish staged cargo or wallet.
	var a = Service.new(); var b = Service.new()
	check(a.open("user://bulk_probe/stale.db") and b.open("user://bulk_probe/stale.db"), "open isolated concurrent save writers")
	a.docked = true; b.docked = true
	check(a.start_loading(ID), "first writer saves operation")
	check(not b.start_loading(ID) and b.blocked and b.manifest.lines().is_empty() and b.credits == 0, "stale writer fences without publishing")
	a.store.close(); b.store.close()

func durable(mode: String) -> void:
	var s = Service.new()
	check(s.open("user://bulk_crash/voyage.db"), "open durable bulk voyage")
	if failures: return
	match mode:
		"seed":
			s.docked = true
			check(s.start_loading(ID) and s.advance(2), "save partial load")
		"load_before", "load_after":
			install_fault(s, "before_commit" if mode.ends_with("before") else "after_commit")
			s.advance(3)
		"verify_pending": check(s.manifest.lines().is_empty() and s.operations.record(s.active).elapsed == 2, "uncommitted load rolled back")
		"verify_loaded": check(s.manifest.lines().size() == 1 and s.active.is_empty() and s.credits == 0, "committed load recovered exactly once")
		"prepare_partial":
			s.port = Service.PORTS[1]
			check(s.start_discharge(50000000) and s.advance(2), "save partial unload presentation")
		"unload_before", "unload_after":
			install_fault(s, "before_commit" if mode.ends_with("before") else "after_commit")
			s.advance(3)
		"verify_unpaid": check(s.credits == 0 and s.manifest.lines()[0].quantity == 123456789, "uncommitted payout and cargo both rolled back")
		"verify_partial":
			check(s.credits == 4009 and s.manifest.lines()[0].quantity == 73456789 and s.active.is_empty(), "partial discharge wallet, hold and remainder recovered")
			check(s.offers.discharge("bulk_operation_2", ID, Service.OWNER, Service.SHIP, s.port, s.manifest, 50000000, true).reward_minor == 0, "lost reply replay after process death cannot pay")
		"finish": check(s.start_discharge(73456789) and s.advance(5), "finish interrupted voyage")
		"verify_final": check(s.credits == s.seeds[ID].reward_minor and s.manifest.lines().is_empty() and not s.start_discharge(1), "final settlement remains single after reopen")
	s.store.close()

func install_fault(s: RefCounted, phase: String) -> void:
	s.store.fault_hook = func(point: String):
		if point == phase:
			print("BULK_KILL_READY ", point)
			while true: OS.delay_msec(50)

func scene_test() -> void:
	var view = preload("res://features/ports/bulk_port_test.tscn").instantiate()
	root.add_child(view)
	for i: int in 30: await physics_frame
	check(view.booted and not view.bulk.blocked, "actual bulk scene boots with durable store")
	view.ship.global_transform = view.port.berth_anchor.global_transform
	view.ship.velocity = Vector3.ZERO
	await physics_frame
	check(view.docking.request_dock(1, view.service_id(), view.cargo_id()).ok, "bulk berth explicitly supports commodity")
	view.docking.advance(1.1)
	view.sync_context()
	check(view.bulk.docked, "actual docking authority confirms berth")
	view.bulk_panel.load_requested.emit(ID)
	check(not view.bulk.active.is_empty(), "panel intent uses shared authority")
	check(view.bulk.advance(5), "authority completes loading")
	view.publish_state()
	check(view.ship.state.manifest.lines() == view.bulk.manifest.lines(), "committed bulk manifest presented on ship")
	view.bulk_panel.discharge_requested.emit(1)
	check(view.bulk.credits == 0 and view.bulk.active.is_empty(), "panel cannot unload at origin")
	view.bulk.checkpoint()
	view.free()
	var resumed = preload("res://features/ports/bulk_port_test.tscn").instantiate()
	root.add_child(resumed)
	for i: int in 30: await physics_frame
	check(resumed.booted and not resumed.bulk.blocked and resumed.bulk.manifest.lines().size() == 1, "actual scene restores loaded voyage")
	resumed.docking.disconnect_owner(1)
	resumed.port = resumed.world_ports[1]
	resumed.bind_port()
	resumed.ship.global_transform = resumed.port.berth_anchor.global_transform
	resumed.ship.velocity = Vector3.ZERO
	await physics_frame
	check(resumed.docking.request_dock(1, resumed.service_id(), resumed.cargo_id()).ok, "actual destination dock")
	resumed.docking.advance(1.1)
	resumed.sync_context()
	resumed.bulk_panel.discharge_requested.emit(50000000)
	check(resumed.bulk.advance(5) and resumed.bulk.credits == 4009, "panel partial discharge at destination")
	resumed.bulk_panel.discharge_requested.emit(10000000)
	check(resumed.bulk.advance(1), "unfinished second discharge")
	resumed.cargo_scroll.hide()
	check(not resumed.bulk.active.is_empty(), "closing cargo panel does not cancel or finish service")
	resumed.docking.disconnect_owner(1)
	resumed.docking.register(1, resumed.ship, resumed.port)
	resumed.sync_context()
	check(resumed.bulk.active.is_empty() and resumed.bulk.credits == 4009 and resumed.bulk.manifest.lines()[0].quantity == 73456789, "berth loss cancels pending unload only")
	resumed.ship.global_position = Vector3(4000, 0, -4000)
	resumed.ship.state.fuel_liters = 321.25
	resumed.sync_context()
	check(resumed.bulk.checkpoint(), "save interrupted partial sailing voyage")
	resumed.free()
	var partial = preload("res://features/ports/bulk_port_test.tscn").instantiate()
	root.add_child(partial)
	for i: int in 30: await physics_frame
	check(not partial.bulk.blocked and partial.bulk.credits == 4009 and partial.bulk.manifest.lines()[0].quantity == 73456789, "scene restart retains partial wallet and hold")
	check(partial.ship.global_position.distance_to(Vector3(4000, 0, -4000)) < .01 and absf(partial.ship.state.fuel_liters - 321.25) < .01 and partial.ship.commanded_throttle == 0, "partial voyage resumes at saved position and fuel in neutral")
	partial.free()
