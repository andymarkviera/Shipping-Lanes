extends SceneTree
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
var runtime: Node3D
var started: int = Time.get_ticks_msec()
var joined: bool = false
var ready_at: int = 0
var checks: int = 0
var failed: bool = false
var reload_save: bool = false
var shutdown_live: bool = false
var expected_credits: int = 7654321
var after_shutdown: bool = false

func _initialize() -> void:
	reload_save = OS.get_cmdline_user_args().has("--reload-save")
	shutdown_live = OS.get_cmdline_user_args().has("--shutdown-live")
	after_shutdown = OS.get_cmdline_user_args().has("--after-shutdown")
	if after_shutdown: expected_credits += 1
	change_scene_to_file.call_deferred("res://features/main/boot.tscn")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(message)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 25000:
		check(false, "persistent reconnect timed out")
		finish()
		return false
	if runtime == null:
		if current_scene != null and current_scene.name == "DedicatedRuntime": runtime = current_scene
		return false
	if runtime.hosting:
		if not joined and runtime.contexts.size() == 1:
			joined = true
			var context: Node3D = runtime.contexts.values()[0]
			if not reload_save:
				context.banked_minor = 7654321
				context.reward_minor = 7654321
				context.fleet["container_2"] = {"fuel": 0.37, "condition": 0.61}
				context.ship_kind = "container_2"
				check(context.select_port(0, true), "stage owned active coastal ship")
				context.ship.state.fuel_liters = context.ship.definition.fuel_capacity_liters * 0.37
				context.ship.state.condition = 0.61
			check(context.ship_kind == "container_2", "active ship survives restart")
			check(context.fleet.has("container") and context.fleet.has("container_2"), "owned fleet retained")
			check(context.reward_minor == expected_credits and context.spent_minor == 0, "credits retained")
			check(is_equal_approx(context.ship.state.condition, 0.61), "condition retained")
			check(absf(context.ship.state.fuel_liters - context.ship.definition.fuel_capacity_liters * 0.37) < 0.5, "fuel retained")
			check(Snapshot.valid(Snapshot.capture(context)), "server authority checkpoint validates")
			if after_shutdown: check(context.loading.busy(), "unfinished loading survives connected shutdown and restart")
			if shutdown_live:
				context.reward_minor += 1
				context.banked_minor += 1
				context.ship.transform = context.port.dock_pose(context.ship, 0)
				check(context.docking.request_dock(context.owner_id, context.service_id(), context.cargo_id()).ok, "stage docked loading on shutdown")
				context.docking.advance(context.docking.MAX_SLIDE_SECONDS + 0.1)
				context.selected_offer = "container_load_0_0_0"
				context.accept_selected()
				check(context.loading.busy(), "shutdown with unfinished loading")
			else: runtime.save_elapsed = 60.0 # Exercise the minute timer without a minute wait.
			ready_at = Time.get_ticks_msec()
		if shutdown_live and ready_at > 0 and Time.get_ticks_msec() - ready_at > 500:
			finish() # Real tree shutdown with an online captain and unsaved payout.
			return false
		if joined and runtime.contexts.is_empty():
			check(runtime.saves.finish(), "disconnect checkpoint completed")
			check(runtime.saves.players.size() == 1, "same install key resumes one record")
			if OS.get_cmdline_user_args().has("--generate-fixtures"):
				generate_fixtures()
			finish()
	else:
		if shutdown_live and ready_at > 0 and runtime.entity.is_empty():
			finish()
			return false
		if runtime.entity.is_empty() or runtime.view.reward_minor != expected_credits + (1 if shutdown_live else 0): return false
		if ready_at == 0:
			ready_at = Time.get_ticks_msec()
			check(runtime.view.ship_kind == "container_2", "client receives restored active hull")
			check(runtime.view.persistence == null and not runtime.view.save_enabled, "client never opens authority saves")
		if Time.get_ticks_msec() - ready_at > 1200: finish()
	return false

func generate_fixtures() -> void:
	# Run once explicitly to create frozen synthetic 3.0 fixtures. Never regenerate
	# these during normal checks: each later 3.x schema adds another fixture.
	var rows: Dictionary = runtime.saves.players.duplicate(true)
	var source_key: String = rows.keys()[0]
	var fixture_players: Dictionary = {"a".repeat(64): rows[source_key]}
	fixture_players["a".repeat(64)].captain = "Synthetic fixture"
	var voyage: Dictionary = fixture_players["a".repeat(64)].voyage
	voyage.offers = {}
	voyage.operations.records = {}
	var offers = preload("res://features/cargo/container_offers.gd").new()
	for id: String in ["container_load_0_0_0", "container_load_0_1_0"]:
		var row: Dictionary = offers.fresh(id, true)
		row.state = "loaded" if id == "container_load_0_0_0" else "delivered"
		row.owner_id = "preview_captain"
		row.ship_id = "preview_ship"
		row.accepted_ms = 0
		voyage.offers[id] = row
		var operation: String = "load_" + id + "_1"
		var duration: float = offers.loading_seconds(row.quantity)
		voyage.operations.records[operation] = {"id": operation, "ship_id": "preview_ship", "rule_id": "port_loading", "payload": {"offer_id": id}, "duration": duration, "elapsed": duration, "state": "committed", "message": "Synthetic cargo receipt"}
		if row.state == "loaded": voyage.manifest = [offers.batch(row)]
		else: voyage.credits += row.reward_minor
	check(Snapshot.valid(voyage), "synthetic loaded cargo and paid receipt fixture validates")
	DirAccess.make_dir_recursive_absolute("res://tools/fixtures/server_saves")
	for version: int in [0, 1]:
		var document: Dictionary = {"schema_version": version}
		document["captains" if version == 0 else "players"] = fixture_players
		var payload: String = Marshalls.raw_to_base64(var_to_bytes(document))
		var file: FileAccess = FileAccess.open("res://tools/fixtures/server_saves/" + ("pre-3.0.json" if version == 0 else "3.0.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"schema_version": version, "payload": payload, "sha256": payload.sha256_text()}) + "\n")
		file.close()

func finish() -> void:
	print("SERVER_SAVES_NETWORK_PASS checks=%d" % checks if not failed else "SERVER_SAVES_NETWORK_FAILED")
	quit(1 if failed else 0)
