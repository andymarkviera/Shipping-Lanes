extends SceneTree
const Service = preload("res://features/cargo/bulk_service.gd")
const BulkPanel = preload("res://features/cargo/bulk_service_panel.gd")
var ID: String = "bulk_0_grain_forward"
var family: String = "bulk"
var full: int = 123456789
var part: int = 50000000
var remainder: int = 73456789
# Step 86 rates: 50 t of grain at 800, or 50 m3 of LNG at 1000, over 1500 m.
var partial_minor: int = 32073
var scene_path: String = "res://features/ports/bulk_port_test.tscn"
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh() -> RefCounted:
	var s = Service.new(family)
	s.seed_offers()
	s.docked = true
	return s
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var mode: String = "suite"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bulk-mode="): mode = arg.get_slice("=", 1)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--cargo-family=gas":
			family = "gas"
			ID = "gas_0_lng_lng"
			full = 123; part = 50; remainder = 73; partial_minor = 40091
			scene_path = "res://features/ports/gas_port_test.tscn"
	if mode == "suite": await suite()
	elif mode == "scene": await scene_test()
	else: durable(mode)
	print("BULK_SERVICE_PASS ", mode, " checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
func suite() -> void:
	var s = fresh()
	check(Service.valid(s.capture(), family), "new bulk state validates")
	check(s.start_loading(ID), "accept and reserve loading through shared operation")
	check(not s.start_loading(ID), "double click cannot reserve a second operation")
	check(s.advance(2.0) and s.manifest.lines().is_empty(), "partial loading is not cargo")
	var copy = Service.new(family)
	check(copy.restore(bytes_to_var(var_to_bytes(s.capture()))), "object-free pending loading round trip")
	check(copy.advance(3.0) and copy.manifest.lines()[0].quantity == full, "resume remaining authority duration exactly once")
	var loaded: Dictionary = copy.capture()
	check(copy.operations.commit(family + "_operation_1").ok and copy.capture() == loaded, "repeated operation completion has no mutation")
	copy.port = Service.PORTS[1]
	check(copy.start_discharge(part) and copy.advance(5.0), "partial discharge commits")
	check(copy.credits == partial_minor and copy.manifest.lines()[0].quantity == remainder, "partial wallet and remaining grams reconcile")
	var partial: Dictionary = copy.capture()
	check(s.restore(partial), "partial voyage restores")
	check(s.offers.view(ID).terms == partial.seeds[ID].terms and s.manifest.lines()[0][s.offers.allocation_key] == ("tank_lng" if family == "gas" else "hold_forward"), "quote and hold survive interruption")
	var historical: Dictionary = s.offers.discharge(family + "_operation_2", ID, s.owner_id, s.ship_id, Service.PORTS[1], s.manifest, part, true)
	check(historical.ok and historical.reward_minor == 0 and s.credits == partial_minor, "receipt retry after reload has zero economic delta")
	check(not s.start_discharge(remainder + 1), "over-discharge rejected")
	check(s.start_discharge(remainder) and s.advance(1), "start remaining discharge")
	check(s.cancel() and s.manifest.lines()[0].quantity == remainder and s.credits == partial_minor, "cancel unfinished unload preserves partial voyage")
	check(s.start_discharge(remainder) and s.advance(5), "finish remaining discharge")
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
	check(not Service.valid(changed, family), "changed frozen quote rejected")
	changed = partial.duplicate(true); changed.events.back()[s.quantity_key] += 1
	check(not Service.valid(changed, family), "receipt quantity mismatch rejected")
	changed = partial.duplicate(true); changed.manifest[0][s.offers.allocation_key] = "tank_aft" if family == "gas" else "hold_aft"
	check(not Service.valid(changed, family), "hold provenance mismatch rejected")
	changed = partial.duplicate(true); changed.operations.records[family + "_operation_2"].state = "running"
	check(not Service.valid(changed, family), "committed receipt cannot become unfinished work")
	var cancel = fresh()
	check(cancel.start_loading(ID) and cancel.advance(1) and cancel.cancel(), "cancel partial loading")
	check(cancel.offers.view(ID).state == "available" and cancel.manifest.lines().is_empty(), "cancel releases pending job without cargo")
	check(cancel.start_loading(ID) and cancel.advance(5), "released job can load once later")
	var panel = BulkPanel.new()
	panel.family = family
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
	check(panel.quote.text.begins_with(visual.offers.format_quote(display.job)), "accepted frozen quote remains visible during service")
	var selected = fresh()
	panel.refresh(selected.presentation(), selected.offers.list_at(selected.port), true)
	panel.commodities.select(1)
	panel.holds.select(2 if family == "gas" else 1)
	panel.select_quote()
	check(panel.selected_id == ("gas_0_nitrogen_aft" if family == "gas" else "bulk_0_coal_aft"), "commodity and hold selectors resolve authored quote")
	panel.load_requested.connect(func(id: String): selected.start_loading(id))
	panel.load_button.pressed.emit()
	check(selected.advance(5) and selected.manifest.lines()[0].cargo_id == ("cargo_gas_nitrogen" if family == "gas" else "cargo_bulk_coal") and selected.manifest.lines()[0][selected.offers.allocation_key] == ("tank_aft" if family == "gas" else "hold_aft"), "selected commodity and hold reach shared operation")
	panel.free()
	for row: Dictionary in fresh().seeds.values():
		var pair = fresh()
		pair.port = row.origin_port_id
		check(pair.start_loading(row.id) and pair.advance(5), "all compatible commodity/allocation pairs load")
		pair.port = row.destination_port_id
		check(pair.start_discharge(1) and pair.advance(5), "minimum-unit partial through shared path")
		check(Service.valid(pair.capture(), family), "partial pair checkpoint validates")
	if family == "gas": gas_checks()

	# SQLite compare-and-swap failure cannot publish staged cargo or wallet.
	var a = Service.new(family); var b = Service.new(family)
	check(a.open("user://bulk_probe/stale.db") and b.open("user://bulk_probe/stale.db"), "open isolated concurrent save writers")
	a.docked = true; b.docked = true
	check(a.start_loading(ID), "first writer saves operation")
	check(not b.start_loading(ID) and b.blocked and b.manifest.lines().is_empty() and b.credits == 0, "stale writer fences without publishing")
	a.store.close(); b.store.close()

func durable(mode: String) -> void:
	var s = Service.new(family)
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
			check(s.start_discharge(part) and s.advance(2), "save partial unload presentation")
		"unload_before", "unload_after":
			install_fault(s, "before_commit" if mode.ends_with("before") else "after_commit")
			s.advance(3)
		"verify_unpaid": check(s.credits == 0 and s.manifest.lines()[0].quantity == full, "uncommitted payout and cargo both rolled back")
		"verify_partial":
			check(s.credits == partial_minor and s.manifest.lines()[0].quantity == remainder and s.active.is_empty(), "partial discharge wallet, hold and remainder recovered")
			check(s.offers.discharge(family + "_operation_2", ID, s.owner_id, s.ship_id, s.port, s.manifest, part, true).reward_minor == 0, "lost reply replay after process death cannot pay")
		"finish": check(s.start_discharge(remainder) and s.advance(5), "finish interrupted voyage")
		"verify_final": check(s.credits == s.seeds[ID].reward_minor and s.manifest.lines().is_empty() and not s.start_discharge(1), "final settlement remains single after reopen")
	s.store.close()

func install_fault(s: RefCounted, phase: String) -> void:
	s.store.fault_hook = func(point: String):
		if point == phase:
			print("BULK_KILL_READY ", point)
			while true: OS.delay_msec(50)

func scene_test() -> void:
	var view = load(scene_path).instantiate()
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
	var resumed = load(scene_path).instantiate()
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
	resumed.bulk_panel.discharge_requested.emit(part)
	check(resumed.bulk.advance(5) and resumed.bulk.credits == partial_minor, "panel partial discharge at destination")
	resumed.bulk_panel.discharge_requested.emit(10 if family == "gas" else 10000000)
	check(resumed.bulk.advance(1), "unfinished second discharge")
	resumed.cargo_scroll.hide()
	check(not resumed.bulk.active.is_empty(), "closing cargo panel does not cancel or finish service")
	resumed.docking.disconnect_owner(1)
	resumed.docking.register(1, resumed.ship, resumed.port)
	resumed.sync_context()
	check(resumed.bulk.active.is_empty() and resumed.bulk.credits == partial_minor and resumed.bulk.manifest.lines()[0].quantity == remainder, "berth loss cancels pending unload only")
	resumed.ship.global_position = Vector3(4000, 0, -4000)
	resumed.ship.state.fuel_liters = 321.25
	resumed.sync_context()
	check(resumed.bulk.checkpoint(), "save interrupted partial sailing voyage")
	resumed.free()
	var partial = load(scene_path).instantiate()
	root.add_child(partial)
	for i: int in 30: await physics_frame
	check(not partial.bulk.blocked and partial.bulk.credits == partial_minor and partial.bulk.manifest.lines()[0].quantity == remainder, "scene restart retains partial wallet and hold")
	check(partial.ship.global_position.distance_to(Vector3(4000, 0, -4000)) < .01 and absf(partial.ship.state.fuel_liters - 321.25) < .01 and partial.ship.commanded_throttle == 0, "partial voyage resumes at saved position and fuel in neutral")
	partial.free()

func gas_checks() -> void:
	var s = fresh()
	# Expected values calculated independently with Python arbitrary-precision integers.
	for v: Array in [
		[2547, 6655, 3162, 14462, 15116, 63264944],
		[1383, 247677, 534, 19891, 14722, 289222159],
		[6937, 156499, 4933, 10025, 11770, 3412040980],
		[5119, 229782, 4056, 12015, 9725, 3010034572],
		[8182, 241040, 8610, 8275, 14339, 10879216767],
		[223, 86617, 2629, 15312, 14679, 61629124],
		[4079, 291815, 9408, 5085, 10420, 3203880578],
		[6227, 147703, 4050, 13502, 17374, 4718241256],
		[5065, 158930, 773, 2649, 6669, 59356258],
		[1574, 106806, 4807, 15679, 19859, 1358655196],
		[6855, 194028, 9859, 19282, 18053, 24647065041],
		[2073, 57473, 7765, 4678, 3640, 85059974],
		[7515, 28937, 4974, 11475, 8202, 549692418],
		[1825, 217606, 8658, 1658, 14070, 433100771],
		[3742, 150808, 4661, 15208, 9171, 1980865925],
		[3821, 47873, 4673, 2153, 6360, 63200952],
		[5098, 73170, 3326, 1680, 2682, 30184376],
		[4341, 184813, 9574, 19006, 4758, 3750506358],
		[2541, 102289, 5306, 1954, 1580, 22990134],
		[3836, 96569, 1770, 2590, 8968, 82232592],
		[621296653, 8616, 333150, 6591, 6967, -1],
		[130717628, 169095, 869513, 14385, 7823, -1],
		[379803634, 311098, 684739, 6439, 235, -1],
		[569773379, 260899, 936383, 5051, 12503, -1],
		[944234759, 53573, 623623, 10985, 9836, -1],
		[515953436, 297379, 181031, 9086, 949, -1],
		[920544639, 252547, 175065, 17092, 16882, -1],
		[439028501, 201736, 855799, 995, 11568, -1],
		[889917444, 43660, 197268, 16652, 18494, -1],
		[456902259, 190963, 481830, 1154, 17477, -1],
		[799592564, 113851, 644387, 10694, 991, -1],
		[769312774, 185892, 708427, 19197, 2079, -1],
		[140344607, 56152, 434116, 1350, 3892, -1],
		[33689678, 176961, 641862, 17625, 10436, -1],
		[925386679, 185873, 753852, 381, 18666, -1],
		[865965635, 22613, 554162, 6222, 3747, -1],
		[224092832, 145635, 909706, 12602, 2365, -1],
		[751362664, 37903, 881526, 9878, 7740, -1],
		[877460901, 80751, 27373, 3573, 4851, -1],
		[345389423, 6241, 767766, 17968, 10858, -1],
	]:
		check(s.offers.calculate(v[0], {"direct_distance_m": v[1], "rate_minor_per_cubic_meter_nm": v[2], "origin_modifier_bp": v[3], "destination_modifier_bp": v[4]}) == v[5], "gas rational vector and overflow bound")
	check(s.seeds[ID].reward_minor == 98625, "123 m3, 1500 m, 1000 minor/m3/NM, 11000/9000 bp = 986.25 credits")
	check(s.offers.format_quote(s.seeds[ID]).contains("credits/m³/NM"), "quote labels gas units")
	check(not Service.valid(s.capture()) and not Service.valid(Service.new().capture(), "gas"), "bulk and gas realms cannot cross-load")
	s.terminals[s.port].gas_pipelines.pipe_lng.can_load = false
	check(not s.start_loading(ID) and s.events.is_empty(), "incompatible admission has no reservation or cargo")
	s.terminals[s.port].gas_pipelines.pipe_lng.can_load = true
	check(s.start_loading(ID) and s.advance(2), "start compatible pipeline transfer")
	s.terminals[s.port].gas_pipelines.pipe_lng.can_load = false
	check(s.advance(3) and s.active.is_empty() and s.manifest.lines().is_empty(), "lost loading permission cancels unfinished service at completion")
	s.terminals[s.port].gas_pipelines.pipe_lng.can_load = true
	check(s.start_loading(ID) and s.advance(5), "compatible retry loads once")
	check(not s.start_discharge(1), "origin cannot unload delivery")
	s.port = Service.PORTS[1]
	for amount: Variant in [0, -1, 1.5, true, "1", 124]:
		check(not s.start_discharge(amount), "reject invalid whole-m3 partial")
	s.terminals[s.port].gas_pipelines.pipe_lng.can_unload = false
	check(not s.start_discharge(50), "incompatible destination admission rejected")
	s.terminals[s.port].gas_pipelines.pipe_lng.can_unload = true
	check(s.start_discharge(50) and s.advance(2), "start timed partial")
	s.terminals[s.port].gas_pipelines.pipe_lng.pipeline_type = "industrial_cryogenic"
	check(s.advance(3) and s.credits == 0 and s.manifest.lines()[0].quantity == 123, "incompatible completion retains cargo and wallet")
	s.terminals[s.port].gas_pipelines.pipe_lng.pipeline_type = "lng"
	check(s.start_discharge(50) and s.advance(5), "compatible partial pays")
	var receipt: Dictionary = s.presentation().receipt
	check(receipt.tank_id == "tank_lng" and receipt.acquisition_id == s.manifest.lines()[0].acquisition_id, "receipt keeps acquisition and tank provenance")
	check(receipt.reward_minor == 40091 and receipt.remaining_cubic_meters == 73 and receipt.origin_port_id == Service.PORTS[0], "gas receipt retains units and origin")
	check(not s.offers.discharge(receipt.action_id, ID, s.owner_id, s.ship_id, s.port, s.manifest, 51, true).ok, "conflicting replay rejected")
	check(not s.offers.discharge("wrong_owner", ID, "other", s.ship_id, s.port, s.manifest, 1, true).ok, "wrong owner rejected")
	check(not s.offers.discharge("wrong_ship", ID, s.owner_id, "other", s.port, s.manifest, 1, true).ok, "wrong ship rejected")
	for i: int in 73:
		check(s.start_discharge(1) and s.advance(5), "one-m3 fragment settles")
	check(s.credits == 98625 and s.manifest.lines().is_empty(), "fragmented final total exactly matches quote")
