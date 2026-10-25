extends Node3D
const Preview = preload("res://features/ports/port_test.tscn")
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
const Store = preload("res://features/cargo/voyage_store.gd")
const Lifecycle = preload("res://features/cargo/voyage_lifecycle.gd")
const Navigation = preload("res://features/ports/local_navigation.gd")
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
	elif mode in ["before_commit", "after_commit", "verify_partial", "verify_loaded", "deliver", "delivery_before_commit", "delivery_after_commit", "verify_delivered"]:
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
				check(view.ship.assembly.container_visuals.shown_count == 1, "Fresh-process reload reconstructs one visible container")
			elif mode in ["deliver", "delivery_before_commit", "delivery_after_commit"]:
				view.docking.request_undock(1)
				view.docking.advance(1)
				view.port = view.world_ports[1]
				view.bind_port()
				dock(view)
				var writer: Node = preload("res://features/cargo/voyage_persistence.gd").new()
				writer.view = view
				writer.store = store
				writer.ready_to_save = true
				view.persistence = writer
				if mode.begins_with("delivery_"):
					store.fault_hook = func(phase: String):
						if "delivery_" + phase == mode:
							var marker: FileAccess = FileAccess.open("user://fault_" + mode, FileAccess.WRITE)
							marker.store_string(mode)
							marker.flush()
							marker.close()
							OS.kill(OS.get_process_id())
				view.deliver()
				check(not mode.begins_with("delivery_"), "Delivery fault hook terminates inside actual commit")
				writer.free()
				check(view.reward_minor == 25000 and view.ship.state.manifest.lines().is_empty(), "Delivery atomically consumes job cargo and grants quoted reward")
				check(view.ship.assembly.container_visuals.shown_count == 0, "Delivery removes visible containers immediately")
				check(store.current.credits == 25000 and store.current.manifest.is_empty(), "Delivery saved before reporting success")
			else:
				view.deliver()
				check(view.reward_minor == 25000 and view.ship.state.manifest.lines().is_empty(), "Restarted delivery cannot pay twice")
				check(view.delivery.receipts(view.offers, "preview_captain").size() == 1 and view.delivery.receipt_text(view.offers).contains("250.00"), "Reopening retains exactly one matching delivery receipt")
	else:
		await lifecycle_suite(view)
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
	view._process(0)
	check(Navigation.target(view).label == "Slatewater Works", "Navigation points to accepted delivery port")
	check(view.action_reason.text.contains("Loading in progress") and view.refuel_button.disabled, "Pending service actions expose reason and remain disabled")
	check(view.voyage_hud.heading.text == "LOADING CARGO" and view.voyage_hud.progress.value == 40, "HUD shows authoritative pending loading progress")
	check(view.voyage_hud.cargo.text.contains("aboard: 0") and view.voyage_hud.route.text.contains("Slatewater Works"), "Pending HUD distinguishes promised cargo from aboard cargo")
	var op_count: int = view.ship.state.operations._records.size()
	view.accept_selected()
	view.accept_selected()
	check(view.ship.state.operations._records.size() == op_count, "Rapid accept clicks do not duplicate operations")
	check(Snapshot.valid(partial) and store.save(partial), "Accepted terms, lock and progress saved together")
	check(not stale.save(initial), "Stale writer cannot roll progress backwards")
	stale.close()
	view.ship.collision_layer = 0 # Old connection is gone; its hull must not occupy the recovered berth.
	var restored: Node3D = await make_view()
	check(await Snapshot.restore(restored, partial), "Reconnect snapshot restores partial loading")
	check(restored.loading.progress_percent() == 40 and restored.docking.state(1) == "docked", "Progress and dock reservation reconstructed")
	check(restored.ship.assembly.container_visuals.shown_count == 0, "Incomplete loading restores no phantom visible cargo")
	check(restored.ship.commanded_throttle == 0 and restored.ship.velocity == Vector3.ZERO, "Reconnection is neutral and stopped")
	restored.loading.advance(3)
	check(restored.ship.state.manifest.lines().size() == 1 and not restored.loading.busy(), "Resumed timer completes once")
	check(restored.ship.assembly.container_visuals.shown_count == 1, "Resumed completion creates exactly one visible container")
	restored._process(0)
	check(not restored.loading_text.text.contains("Accepted — loading"), "Completed load cannot keep a stale pending notice")
	check(restored.voyage_hud.cargo.text.contains("aboard: 1") and not restored.voyage_hud.progress.visible, "Loaded HUD shows cargo and removes pending progress")
	var destination_hud: Dictionary = preload("res://features/ports/voyage_hud.gd").describe(restored)
	check(destination_hud.route.contains("Slatewater Works") and destination_hud.next.contains("Undock"), "Loaded origin HUD gives departure instruction")
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
	view._process(0)
	check(Navigation.target(view).kind == "pickup" and Navigation.target(view).position == view.ship.payload_body.global_position, "Minimap pickup uses physical load location")
	check(view.voyage_hud.heading.text == "COLLECT HEAVY LOAD" and view.voyage_hud.cargo.text.contains("awaiting pickup"), "Heavy pickup HUD does not claim cargo aboard")
	check(Snapshot.valid(pickup), "Nearby heavy pickup and ocean destination can be saved")
	check(Lifecycle.end_job(view).ok and view.heavy_jobs.active.is_empty() and view.ship.payload_body.collision_layer == 0, "Cancel heavy pickup removes floating load without reward")
	check(await Snapshot.restore(view, pickup), "Cancelled pickup fixture restores for carrying tests")
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
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
	check(not Lifecycle.end_job(view, true).ok and not Lifecycle.before_ship_removal(view).ok and view.ship.attached, "Carrying heavy load cannot be silently discarded or despawned")
	view.ship.collision_layer = 0
	var heavy: Node3D = await make_view()
	check(await Snapshot.restore(heavy, carrying), "Heavy attachment restores in fresh scene")
	heavy.ship.set_physics_process(false)
	heavy.helm.set_physics_process(false)
	check(heavy.ship.assembly.container_visuals.instances == null, "Heavy industrial cargo does not get container boxes")
	check(heavy.ship.attached and heavy.ship.payload_visual.get_parent() == heavy.ship.cargo_mount and heavy.ship.payload_body.collision_layer == 0 and not heavy.ship.payload_shape.disabled, "Restored heavy cargo has exactly one collision owner")
	for i: int in 240: heavy.ship.advance_deck(1.0 / 60)
	check(heavy.ship.deck_height == 2.6 and heavy.ship.helm_available(), "Interrupted lift finishes and helm unlocks")
	heavy._process(0)
	check(Navigation.target(heavy).kind == "drop" and Navigation.target(heavy).position == heavy.heavy_jobs.active.drop, "Reopened heavy voyage map uses saved ocean drop")
	check(heavy.voyage_hud.heading.text == "DELIVER HEAVY LOAD" and heavy.voyage_hud.route.text.contains("Ocean drop-off"), "Recovered heavy cargo HUD follows ocean destination")
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
	resumed.loading.set_physics_process(false)
	resumed.docking.set_physics_process(false)
	resumed.docking.request_undock(1)
	resumed.docking.advance(1)
	resumed.port = resumed.world_ports[1]
	resumed.bind_port()
	dock(resumed)
	resumed._process(0)
	check(Navigation.target(resumed).position == resumed.world_ports[1].berth_anchor.global_position, "Navigation target stays at destination after port-context changes")
	check(resumed.voyage_hud.route.text.contains("Slatewater Works") and resumed.voyage_hud.instruction.text.contains("Deliver cargo"), "At destination HUD stays on accepted route and explains delivery")
	var before_delivery: Dictionary = Snapshot.capture(resumed)
	var competitor = Store.new()
	check(competitor.open_store(resumed.save_path) and competitor.save(before_delivery), "Competing session advances durable revision")
	competitor.close()
	resumed.deliver()
	resumed._process(0)
	check(resumed.voyage_hud.heading.text == "SAVE NEEDS ATTENTION", "Save failure replaces travel instruction with visible blocked state")
	check(resumed.persistence.blocked and resumed.reward_minor == 0 and resumed.ship.state.manifest.lines().size() == 1, "Failed delivery commit leaves live cargo and wallet unchanged")
	check(resumed.delivery.receipts(resumed.offers, "preview_captain").is_empty(), "Failed delivery cannot display a paid receipt")
	resumed.queue_free()
	await get_tree().process_frame

func lifecycle_suite(view: Node3D) -> void:
	check(Navigation.target(view).is_empty(), "Idle minimap has no stale job target")
	view.selected_offer = view.jobs_list.get_item_metadata(1)
	var selection: String = view.selected_offer
	view.refresh_jobs()
	view.refresh_jobs()
	check(view.selected_offer == selection and view.jobs_list.get_selected_items()[0] == 1, "Service refresh preserves selection by job ID")
	view.selected_offer = view.jobs_list.get_item_metadata(0)
	view.refresh_jobs()
	check(view.accept_reason() == "Dock before accepting a job.", "Unavailable job acceptance explains docking requirement")
	var bounds: Dictionary = Navigation.frame(view)
	var area := Rect2(30, 58, 260, 125)
	for place: Node3D in view.world_ports:
		check(area.grow(1).has_point(Navigation.project(place.berth_anchor.global_position, bounds, area)), "Auto-fit keeps each port within chart")
	check(Navigation.chart_vector(Vector3.FORWARD) == Vector2(0, 1) and Navigation.chart_vector(Vector3(0, 0, 1)) == Vector2(0, -1), "Chart north follows the ship's positive-Z bow convention")
	check(Navigation.chart_vector(Vector3(-1, 0, 0)) == Vector2(1, 0), "Chart east agrees with clockwise helm heading")
	var initial: Dictionary = Snapshot.capture(view)
	var legacy: Dictionary = initial.duplicate(true)
	legacy.version = 1
	check(Snapshot.valid(legacy), "Existing version-one voyages remain readable")
	dock(view)
	view.accept_selected()
	view.loading.advance(2)
	var partial: Dictionary = Snapshot.capture(view)
	var body: Node3D = view.ship
	check(not view.select_port(1) and view.ship == body, "Active loading cannot replace the ship")
	check(Lifecycle.end_job(view).ok, "Cancel unfinished loading")
	check(view.ship.state.operations._locks.is_empty() and view.offers.active_job("preview_captain").is_empty() and view.reward_minor == 0, "Cancel clears job and lock without payment")
	check(not Lifecycle.end_job(view).ok, "Repeated cancellation changes nothing")
	var orphan: Dictionary = partial.duplicate(true)
	orphan.operations.records.clear()
	orphan.loading = ""
	orphan.loading_offer = ""
	var repair: Dictionary = Lifecycle.reconcile(orphan)
	check(repair.ok and repair.changed and Snapshot.valid(repair.data), "Orphan accepted job safely released")
	check(not Lifecycle.reconcile(repair.data).changed, "Orphan repair is idempotent")
	var recovery_store = Store.new()
	check(recovery_store.open_store("user://voyage_test/orphan.db") and recovery_store.save(partial), "Orphan store starts from a valid checkpoint")
	var encoded: String = Marshalls.raw_to_base64(var_to_bytes(orphan))
	recovery_store.db.query_with_bindings("UPDATE voyage SET payload=?, digest=? WHERE id=1", [encoded, encoded.sha256_text()])
	recovery_store.close()
	check(recovery_store.open_store("user://voyage_test/orphan.db") and not recovery_store.recovery_notice.is_empty() and Snapshot.valid(recovery_store.current), "Store reconciles checksummed orphan on reopen")
	recovery_store.close()
	orphan = partial.duplicate(true)
	orphan.docked = false
	repair = Lifecycle.reconcile(orphan)
	check(repair.ok and repair.changed and repair.data.operations.records.values()[0].state == "interrupted", "Orphan live operation releases its lock")
	orphan.credits += 1
	check(not Lifecycle.reconcile(orphan).ok, "Recovery never conceals unexplained payment")
	orphan = partial.duplicate(true)
	orphan.operations.records.values()[0].state = "committing"
	check(not Lifecycle.reconcile(orphan).ok, "Recovery refuses ambiguous settlement")
	view.accept_selected()
	view.loading.advance(10)
	var loaded: Dictionary = Snapshot.capture(view)
	check(not view.select_port(1) and view.ship == body, "Loaded ship cannot be replaced")
	check(not Lifecycle.end_job(view).ok and not view.ship.state.manifest.lines().is_empty(), "Loaded cargo requires explicit abandonment")
	view.request_abandon()
	check(not view.ship.state.manifest.lines().is_empty(), "First abandon click only requests confirmation")
	view.request_abandon()
	var abandoned: Dictionary = Snapshot.capture(view)
	check(Snapshot.valid(abandoned) and abandoned.manifest.is_empty() and abandoned.credits == 0, "Confirmed abandonment removes cargo without reward")
	check(view.delivery.receipts(view.offers, "preview_captain").is_empty() and view.ship.assembly.container_visuals.shown_count == 0, "Abandonment produces no paid receipt or visible cargo")
	check(not Lifecycle.end_job(view, true).ok, "Repeated abandonment cannot create payment")
	check(Navigation.target(view).is_empty(), "Abandonment removes target immediately")
	check(await Snapshot.restore(view, abandoned), "Abandoned job survives reopen")
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
	check(await Snapshot.restore(view, loaded), "Restore loaded fixture for despawn policy")
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
	check(Lifecycle.before_ship_removal(view).ok and view.ship.state.manifest.lines().is_empty() and view.reward_minor == 0, "Trusted despawn settles container loss without payment")
	check(await Snapshot.restore(view, loaded), "Restore fixture for failed cancellation save")
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
	var durable = Store.new()
	check(durable.open_store("user://voyage_test/lifecycle.db") and durable.save(loaded), "Lifecycle fixture saved")
	var other = Store.new()
	check(other.open_store("user://voyage_test/lifecycle.db") and other.save(loaded), "Another writer advances lifecycle revision")
	other.close()
	var writer: Node = preload("res://features/cargo/voyage_persistence.gd").new()
	writer.view = view
	writer.store = durable
	writer.ready_to_save = true
	view.persistence = writer
	check(not Lifecycle.end_job(view, true).ok and view.ship.state.manifest.lines().size() == 1 and view.reward_minor == 0, "Failed abandonment save preserves live cargo and payment")
	view.persistence = null
	writer.free()
	durable.close()
	check(await Snapshot.restore(view, initial), "Lifecycle suite returns to empty voyage")
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
