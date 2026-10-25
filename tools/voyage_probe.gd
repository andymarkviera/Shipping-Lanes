extends Node3D
const Preview = preload("res://features/ports/port_test.tscn")
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
const Store = preload("res://features/cargo/voyage_store.gd")
const PATH = "user://voyage_test/voyage.db"
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _ready() -> void:
	run.call_deferred()

func make_view() -> Node3D:
	var view: Node3D = Preview.instantiate()
	view.save_enabled = false
	add_child(view)
	view.set_physics_process(false)
	view.loading.set_physics_process(false)
	view.docking.set_physics_process(false)
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
	await get_tree().physics_frame
	return view

func dock(view: Node3D) -> void:
	view.ship.global_transform = view.port.berth_anchor.global_transform
	view.ship.velocity = Vector3.ZERO
	check(view.docking.request_dock(1, view.service_id(), view.cargo_id()).ok, "Fixture docks")
	view.docking.advance(1.1)

func run() -> void:
	var mode: String = "suite"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--voyage-mode="): mode = arg.trim_prefix("--voyage-mode=")
	var view: Node3D = await make_view()
	var store = Store.new()
	check(store.open_store(PATH), "Store opens")
	if mode == "seed":
		dock(view)
		view.accept_selected()
		view.loading.advance(2)
		check(view.loading.progress_percent() == 40, "Seed loading is partially complete")
		check(store.save(Snapshot.capture(view)), "Partial loading saved atomically")
	elif mode in ["before_commit", "after_commit", "verify_partial", "verify_loaded", "deliver", "verify_delivered"]:
		check(not store.current.is_empty(), "Existing checkpoint found")
		if not store.current.is_empty():
			check(await Snapshot.restore(view, store.current), "Fresh process restores voyage")
			view.ship.set_physics_process(false)
			view.helm.set_physics_process(false)
			if mode == "verify_partial":
				check(view.loading.busy() and view.loading.progress_percent() == 40 and view.ship.state.manifest.lines().is_empty(), "Uncommitted crash retains original progress without free cargo")
			elif mode in ["before_commit", "after_commit"]:
				view.loading.advance(5)
				check(view.ship.state.manifest.lines().size() == 1, "Completion creates exactly one batch")
				store.fault_hook = func(phase: String):
					if phase == mode:
						var marker: FileAccess = FileAccess.open("user://fault_" + phase, FileAccess.WRITE)
						marker.store_string(phase)
						marker.flush()
						marker.close()
						OS.kill(OS.get_process_id())
				store.save(Snapshot.capture(view))
				check(false, "Crash hook must terminate process")
			elif mode == "verify_loaded":
				check(not view.loading.busy() and view.ship.state.manifest.lines().size() == 1, "Committed crash restores loaded cargo and terminal receipt")
				check(view.ship.state.operations._locks.is_empty(), "Completed load leaves no permanent reservation")
				view.loading.advance(100)
				check(view.ship.state.manifest.lines().size() == 1, "Restart cannot duplicate cargo")
			elif mode == "deliver":
				view.docking.request_undock(1)
				view.docking.advance(1)
				view.port = view.world_ports[1]
				view.bind_port()
				dock(view)
				view.deliver()
				check(view.reward_minor == 25000 and view.ship.state.manifest.lines().is_empty(), "Delivery atomically consumes job cargo and grants quoted reward")
				check(store.save(Snapshot.capture(view)), "Delivery saved")
			else:
				view.deliver()
				check(view.reward_minor == 25000 and view.ship.state.manifest.lines().is_empty(), "Restarted delivery cannot pay twice")
	else:
		await suite(view, store)
	store.close()
	view.queue_free()
	await get_tree().process_frame
	print("VOYAGE_%s mode=%s checks=%d" % ["PASS" if failures == 0 else "FAIL", mode, checks])
	get_tree().quit(0 if failures == 0 else 1)

func suite(view: Node3D, store: RefCounted) -> void:
	var initial: Dictionary = Snapshot.capture(view)
	check(Snapshot.valid(initial) and store.save(initial), "Empty voyage is valid and durable")
	var stale = Store.new()
	check(stale.open_store(PATH), "Second writer reads same generation")
	dock(view)
	view.accept_selected()
	view.loading.advance(2)
	var partial: Dictionary = Snapshot.capture(view)
	check(Snapshot.valid(partial) and store.save(partial), "Accepted terms, lock and progress saved together")
	check(not stale.save(initial), "Stale writer cannot roll progress backwards")
	stale.close()
	view.ship.collision_layer = 0 # Old connection is gone; its hull must not occupy the recovered berth.
	var restored: Node3D = await make_view()
	check(await Snapshot.restore(restored, partial), "Reconnect snapshot restores partial loading")
	check(restored.loading.progress_percent() == 40 and restored.docking.state(1) == "docked", "Progress and dock reservation reconstructed")
	check(restored.ship.commanded_throttle == 0 and restored.ship.velocity == Vector3.ZERO, "Reconnection is neutral and stopped")
	restored.loading.advance(3)
	check(restored.ship.state.manifest.lines().size() == 1 and not restored.loading.busy(), "Resumed timer completes once")
	var committed: Dictionary = Snapshot.capture(restored)
	check(Snapshot.valid(committed), "Loaded manifest and operation receipt agree")
	var bad: Dictionary = committed.duplicate(true)
	bad.manifest.clear()
	check(not Snapshot.valid(bad), "Missing cargo cannot be silently accepted")
	bad = committed.duplicate(true)
	bad.credits += 1
	check(not Snapshot.valid(bad), "Unreceipted credits rejected")
	bad = partial.duplicate(true)
	bad.operations.records.values()[0].state = "committing"
	check(not Snapshot.valid(bad), "Ambiguous operation state rejected")
	bad = partial.duplicate(true)
	bad.offers.values()[0].reward_minor += 100
	check(not Snapshot.valid(bad), "Changed quote terms rejected")
	restored.queue_free()
	await get_tree().process_frame
	for phase: String in ["reserved", "ready"]:
		var boundary: Dictionary = partial.duplicate(true)
		var entry: Dictionary = boundary.operations.records.values()[0]
		entry.state = phase
		entry.elapsed = 0.0 if phase == "reserved" else entry.duration
		var edge: Node3D = await make_view()
		check(await Snapshot.restore(edge, boundary), "Restore operation at " + phase + " boundary")
		edge.loading.advance(5 if phase == "reserved" else 0)
		check(not edge.loading.busy() and edge.ship.state.manifest.lines().size() == 1, "Boundary resumes and commits exactly once: " + phase)
		edge.queue_free()
		await get_tree().process_frame
	view.ship.collision_layer = CollisionRules.HULL
	view.loading.cancel()
	check(Snapshot.valid(Snapshot.capture(view)), "Cancellation releases the persisted job and lock")
	view.docking.request_undock(1)
	view.docking.advance(1)
	view.heavy_mode = true
	view.select_port(0)
	await get_tree().physics_frame
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
	dock(view)
	view.accept_selected()
	var pickup: Dictionary = Snapshot.capture(view)
	check(Snapshot.valid(pickup), "Nearby heavy pickup and ocean destination can be saved")
	view.docking.request_undock(1)
	view.docking.advance(1)
	view.ship.request_height(-1.0)
	for i: int in 240: view.ship.advance_deck(1.0 / 60)
	view.ship.global_transform = view.ship.payload_body.global_transform * Transform3D(Basis(Vector3.UP, .35), Vector3(3, 1, 8))
	check(view.ship.request_height(2.6) and view.ship.attached, "Crooked offset platform picks up using Raise alone")
	view.ship.advance_deck(.5)
	view.heavy_jobs.update(view.ship)
	var carrying: Dictionary = Snapshot.capture(view)
	check(Snapshot.valid(carrying), "In-flight deck movement and attachment form valid checkpoint")
	view.ship.collision_layer = 0
	var heavy: Node3D = await make_view()
	check(await Snapshot.restore(heavy, carrying), "Heavy attachment restores in fresh scene")
	heavy.ship.set_physics_process(false)
	heavy.helm.set_physics_process(false)
	check(heavy.ship.attached and heavy.ship.payload_visual.get_parent() == heavy.ship.cargo_mount and heavy.ship.payload_body.collision_layer == 0 and not heavy.ship.payload_shape.disabled, "Restored heavy cargo has exactly one collision owner")
	for i: int in 240: heavy.ship.advance_deck(1.0 / 60)
	check(heavy.ship.deck_height == 2.6 and heavy.ship.helm_available(), "Interrupted lift finishes and helm unlocks")
	check(not heavy.ship.request_height(-1.0), "Job cannot be lowered for delivery at wrong location")
	heavy.ship.global_position = heavy.heavy_jobs.active.drop - heavy.ship.global_basis * Vector3(0, 0, -8)
	check(heavy.ship.request_height(-1.0), "Lower allowed at actual drop-off")
	for i: int in 240: heavy.ship.advance_deck(1.0 / 60)
	heavy.heavy_jobs.update(heavy.ship)
	heavy.reward_minor += heavy.heavy_jobs.reward_pending
	heavy.heavy_jobs.reward_pending = 0
	check(not heavy.ship.attached and heavy.heavy_jobs.active.is_empty(), "Lower automatically delivers without Secure or Drop buttons")
	check(heavy.ship.request_height(2.6), "Empty deck can raise after delivered payload disappears")
	for i: int in 240: heavy.ship.advance_deck(1.0 / 60)
	check(heavy.ship.deck_height == 2.6, "Invisible delivered load cannot block the platform")
	var delivered: Dictionary = Snapshot.capture(heavy)
	check(Snapshot.valid(delivered) and store.save(delivered), "Heavy receipt and reward persisted together")
	var after: Node3D = await make_view()
	check(await Snapshot.restore(after, delivered), "Completed heavy job restores")
	after.heavy_jobs.update(after.ship)
	check(after.reward_minor == heavy.reward_minor and after.heavy_jobs.reward_pending == 0, "Heavy restart never duplicates payout")
	heavy.queue_free()
	after.queue_free()
	await get_tree().process_frame
	store.db.query("UPDATE voyage SET digest='damaged' WHERE id=1")
	var damaged = Store.new()
	check(not damaged.open_store(PATH) and not damaged.error.is_empty(), "Damaged save is preserved and refused instead of reset")
	damaged.close()
	# Exercise the actual autosave coordinator, not only its codec/store helpers.
	view.ship.collision_layer = 0
	view.ship.payload_body.collision_layer = 0
	var live: Node3D = await make_view()
	live.save_path = "user://voyage_test/integration.db"
	live.persistence = preload("res://features/cargo/voyage_persistence.gd").new()
	live.add_child(live.persistence)
	for i: int in 10: await get_tree().physics_frame
	check(live.persistence.ready_to_save and not live.persistence.blocked, "Actual voyage coordinator initializes and saves")
	live.loading.set_physics_process(false)
	live.docking.set_physics_process(false)
	dock(live)
	live.accept_selected()
	live.loading.advance(2)
	check(live.persistence.checkpoint(), "Actual coordinator checkpoints an in-flight load")
	live.queue_free()
	await get_tree().process_frame
	var resumed: Node3D = await make_view()
	resumed.save_path = "user://voyage_test/integration.db"
	resumed.persistence = preload("res://features/cargo/voyage_persistence.gd").new()
	resumed.add_child(resumed.persistence)
	for i: int in 10: await get_tree().physics_frame
	check(resumed.persistence.ready_to_save and not resumed.persistence.blocked and resumed.loading.busy() and resumed.loading.progress_percent() >= 40, "Reopening actual preview resumes saved loading")
	resumed.loading.advance(5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(resumed.persistence.store.current.loading == "" and resumed.persistence.store.current.manifest.size() == 1, "Autosave persists cargo completion without a manual save")
	resumed.queue_free()
	await get_tree().process_frame
