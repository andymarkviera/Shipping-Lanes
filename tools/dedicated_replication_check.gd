extends SceneTree
## Real UDP server + two clients. Only the server probe stages berth approaches;
## docking, loading, delivery, duplicate requests and presentation use real RPCs.
var runtime: Node3D
var started: int
var ready_at: int = 0
var checks: int = 0
var failures: int = 0
var stage: int = 0
var staged: Dictionary = {}
var payouts: Dictionary = {}
var saw_remote: bool = false
var saw_crane: bool = false
var saw_loading: bool = false
var saw_dock: bool = false
var saw_other_payout: bool = false
var delivery_request: Dictionary = {}
var expected_pay: int = 0
var last_action_at: int = 0
var paid_at: int = 0
var first_remote_position: Vector3
var remote_moved: bool = false
var wire_results: Array[Dictionary] = []
var families: bool = false
var saw_heavy: bool = false
var saw_bulk: bool = false
var saw_attached: bool = false
var saw_family_map: bool = false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	families = OS.get_cmdline_user_args().has("--families")
	change_scene_to_file.call_deferred("res://features/main/boot.tscn")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("REPLICATION_CHECK: " + message)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 65000:
		check(false, "timed out stage=%d" % stage)
		finish()
		return false
	if runtime == null:
		if current_scene != null and current_scene.name == "DedicatedRuntime": runtime = current_scene
		return false
	if runtime.hosting: server_step()
	elif not runtime.entity.is_empty(): client_step()
	return false

func server_step() -> void:
	if families:
		family_server()
		return
	if runtime.contexts.size() == 2 and ready_at == 0:
		ready_at = Time.get_ticks_msec()
		check(runtime.peer is ENetMultiplayerPeer, "one UDP ENet transport")
		check(runtime.world.docking.claims.holders.is_empty(), "clean isolated berth claims")
		var index: int = 0
		for sender: int in runtime.contexts:
			var context: Node3D = runtime.contexts[sender]
			context.ship.transform = context.port.dock_pose(context.ship, index)
			staged[sender] = 0
			index += 1
	if ready_at == 0: return
	for sender: int in runtime.contexts:
		var context: Node3D = runtime.contexts[sender]
		if staged[sender] == 0 and context.offers.active_job("preview_captain").get("state") == "loaded" and not context.cranes_busy():
			var job: Dictionary = context.offers.active_job("preview_captain")
			payouts[sender] = job.reward_minor
			context.docking.disconnect_owner(sender)
			for place: Node3D in context.world_ports:
				if place.definition.id == job.destination_port_id: context.port = place
			context.bind_port()
			context.ship.transform = context.port.dock_pose(context.ship, staged.size() - 1 if sender == staged.keys()[0] else 0)
			staged[sender] = 1
		if staged[sender] == 1 and context.reward_minor > 0:
			check(context.reward_minor == payouts[sender], "server payout once with frozen terms")
			check(context.ship.state.manifest.lines().is_empty(), "server delivery consumes cargo")
			staged[sender] = 2
	if Time.get_ticks_msec() - ready_at > 42000:
		check(staged.size() == 2 and staged.values().count(2) == 2, "both captains delivered")
		check(runtime.contexts.is_empty(), "disconnected contexts cleaned up")
		check(runtime.world.docking.claims.holders.is_empty(), "disconnected berths released")
		finish()

func client_step() -> void:
	if families:
		family_client()
		return
	var view: Node3D = runtime.view
	if ready_at == 0:
		ready_at = Time.get_ticks_msec()
		runtime.set_physics_process(false)
		runtime.actions.result_received.connect(func(response: Dictionary): wire_results.append(response))
		check(view.persistence == null and not view.save_enabled, "no local multiplayer save")
		check(not view.ship.is_physics_processing(), "client hull presentation only")
		check(not view.docking.is_physics_processing() and not view.loading.is_physics_processing(), "no client docking/loading simulation")
		var forged: Dictionary = ShipActions.make_request(runtime.session.epoch, 1, runtime.entity, "gameplay", 1, {"action": "deliver", "value": ""})
		runtime.gameplay_action.rpc_id(1, forged)
		check(runtime.gameplay_payload_error({"action": "gift", "value": ""}) == "UNKNOWN_ACTION", "no gift/trade/combat action")
		check(runtime.gameplay_payload_error({"action": "deliver", "value": "", "credits": 999}) == "BAD_PAYLOAD", "client cannot choose payout")
	if runtime.replicas.size() == 1:
		var replica: Dictionary = runtime.replicas.values()[0]
		if not saw_remote:
			saw_remote = true
			first_remote_position = replica.body.position
			check(replica.label.text.begins_with("Probe"), "captain name over other boat")
			check(replica.body.collision_layer == 0 and not replica.body.is_physics_processing(), "remote boat cannot simulate")
			check(view.other_ships.size() == 1 and view.globe_map.ship_entries().size() == 2, "minimap and 3D M-map share both ships")
		if replica.body.position.distance_to(first_remote_position) > 1: remote_moved = true
	for sample: Dictionary in runtime.world_samples:
		if not sample.cranes.is_empty(): saw_crane = true
		for id: String in sample.ships:
			if id != runtime.entity and sample.ships[id].credits > 0: saw_other_payout = true
	if view.loading.busy(): saw_loading = true
	var now: int = Time.get_ticks_msec()
	if now - last_action_at < 600: return
	last_action_at = now
	var docked: bool = view.docking.state(view.owner_id) == "docked"
	if docked: saw_dock = true
	match stage:
		0:
			if docked:
				check(wire_results.any(func(result: Dictionary): return result.code == "NOT_OWNER"), "forged owner rejected over wire")
				var id: String = "container_load_0_0_0"
				expected_pay = view.offers.view(id).reward_minor
				runtime.send_gameplay("accept", id)
				stage = 1
			else: runtime.send_gameplay("dock")
		1:
			var job: Dictionary = view.offers.active_job("preview_captain")
			if job.get("state") == "loaded" and view.port.definition.id == job.destination_port_id:
				if not docked: runtime.send_gameplay("dock")
				else:
					runtime.action_sequence += 1
					delivery_request = ShipActions.make_request(runtime.session.epoch, runtime.multiplayer.get_unique_id(), runtime.entity, "gameplay", runtime.action_sequence, {"action": "deliver", "value": ""})
					runtime.gameplay_action.rpc_id(1, delivery_request)
					stage = 2
		2:
			if view.reward_minor == expected_pay:
				check(view.ship.state.manifest.lines().is_empty(), "client cargo consumed with payout")
				runtime.gameplay_action.rpc_id(1, delivery_request)
				var conflict: Dictionary = delivery_request.duplicate(true)
				conflict.payload.action = "refuel"
				runtime.gameplay_action.rpc_id(1, conflict)
				view.reward_minor = 99999999
				runtime.send_gameplay("refuel") # forces a fresh canonical owner state
				paid_at = now
				stage = 3
		3:
			if now - paid_at > 3000:
				check(view.reward_minor == expected_pay, "wallet tamper corrected; duplicate delivery never pays twice")
				check(wire_results.any(func(result: Dictionary): return result.duplicate and result.ok and not result.applied), "exact delivery retry returns original receipt")
				check(wire_results.any(func(result: Dictionary): return result.code == "ID_CONFLICT"), "changed delivery retry rejected")
				check(saw_remote and remote_moved, "other player's boat appears and moves")
				check(saw_crane and saw_loading and saw_dock, "authoritative crane/loading/docking received")
				check(saw_other_payout, "other captain's payout replicated")
				check(runtime.samples.size() <= 16 and runtime.world_samples.size() <= 16, "bounded motion buffers")
				check(runtime.received_states > 100, "continuous snapshots throughout cargo cycle")
				finish()

func finish() -> void:
	print("DEDICATED_REPLICATION_%s %s checks=%d" % ["PASS" if failures == 0 else "FAIL", "server" if runtime != null and runtime.hosting else "client", checks])
	quit(0 if failures == 0 else 1)

func family_server() -> void:
	if runtime.contexts.size() == 2 and ready_at == 0:
		ready_at = Time.get_ticks_msec()
		for sender: int in runtime.contexts:
			staged[sender] = 0
			for kind: String in ["bulk", "heavy"]: runtime.contexts[sender].fleet[kind] = {"fuel": 1.0, "condition": 1.0}
			var context: Node3D = runtime.contexts[sender]
			context.ship.transform = context.port.dock_pose(context.ship, 0 if runtime.captains[sender].ends_with("client1") else 1)
	if ready_at == 0: return
	for sender: int in runtime.contexts:
		var context: Node3D = runtime.contexts[sender]
		if staged[sender] == 0 and context.ship_kind in ["bulk", "heavy"]:
			context.ship.transform = context.port.dock_pose(context.ship, 0 if context.bulk_mode() else 1)
			staged[sender] = 1
		if context.bulk_mode() and staged[sender] == 1 and not context.bulk_active.is_empty():
			context.docking.disconnect_owner(sender)
			context.port = context.bulk_destination()
			context.bind_port()
			context.ship.transform = context.port.dock_pose(context.ship, 0)
			staged[sender] = 2
		if context.heavy_mode and staged[sender] == 1 and not context.heavy_jobs.active.is_empty() and context.ship.deck_height == context.ship.LOWERED:
			context.docking.disconnect_owner(sender)
			context.bind_port()
			context.ship.position = context.ship.payload_body.position - context.ship.basis * context.ship.cargo_mount.position
			context.ship.position.y = 0
			staged[sender] = 2
		if context.heavy_mode and staged[sender] == 2 and context.ship.attached:
			context.ship.position = context.heavy_jobs.active.drop - context.ship.basis * context.ship.cargo_mount.position
			context.ship.position.y = 0
			staged[sender] = 3
		if context.reward_minor > 0: payouts[sender] = context.reward_minor
	if Time.get_ticks_msec() - ready_at > 52000:
		check(payouts.size() == 2, "bulk and heavy both paid by authority")
		check(runtime.contexts.is_empty() and runtime.ships.is_empty(), "bulk and heavy disconnected cleanly")
		finish()

func family_client() -> void:
	var view: Node3D = runtime.view
	saw_family_map = saw_family_map or (runtime.replicas.size() == 1 and view.globe_map.ship_entries().size() == 2)
	if ready_at == 0:
		ready_at = Time.get_ticks_msec()
		runtime.set_physics_process(false)
	var kind: String = "bulk" if runtime.captain_name.ends_with("client1") else "heavy"
	for sample: Dictionary in runtime.world_samples:
		for state: Dictionary in sample.ships.values():
			saw_bulk = saw_bulk or state.kind == "bulk"
			saw_heavy = saw_heavy or state.kind == "heavy"
			if not state.heavy.is_empty(): saw_attached = saw_attached or state.heavy.attached
	var now: int = Time.get_ticks_msec()
	if now - last_action_at < 700: return
	last_action_at = now
	var docked: bool = view.docking.state(view.owner_id) == "docked"
	match stage:
		0:
			if view.ship_kind == kind:
				check(not view.ship.is_physics_processing() and view.ship.collision_layer == 0, "switched hull remains render only")
				check(view.loading.rule.body == view.ship and view.helm.notice.presentation_only, "swapped hull keeps progress projection and remote helm notice")
				stage = 1
			elif view.fleet.has(kind):
				if docked: runtime.send_gameplay("ship", kind)
				else: runtime.send_gameplay("dock")
		1:
			if docked:
				var id: String = runtime.Progression.bulk_ids(0)[0] if kind == "bulk" else view.heavy_jobs.list_at(view.port.definition.id)[0].id
				expected_pay = runtime.Progression.bulk_job(id).reward_minor if kind == "bulk" else 70000
				runtime.send_gameplay("accept", id)
				stage = 2
			else: runtime.send_gameplay("dock")
		2:
			if kind == "bulk":
				if not view.bulk_active.is_empty() and view.port == view.bulk_destination():
					if docked: runtime.send_gameplay("deliver"); stage = 3
					else: runtime.send_gameplay("dock")
			elif not view.heavy_jobs.active.is_empty():
				if view.ship.attached:
					if view.ship.deck_height == view.ship.RAISED and view.ship.cargo_mount.global_position.distance_to(view.heavy_jobs.active.drop) < 30:
						runtime.send_gameplay("lower")
						stage = 3
				elif view.ship.deck_height == view.ship.LOWERED and not docked: runtime.send_gameplay("raise")
				elif not view.ship.operating(): runtime.send_gameplay("lower")
		3:
			if view.reward_minor == expected_pay:
				check(view.bulk_active.is_empty() and view.heavy_jobs.active.is_empty(), "completed family job cleared with payout")
				paid_at = now
				stage = 4
		4:
			if now - paid_at > 4000:
				check(saw_bulk and saw_heavy and saw_attached, "both hull families and attached heavy cargo replicated")
				check(saw_family_map, "swapped boats retained in world and maps")
				check(runtime.view.reward_minor == expected_pay, "family payout applied once")
				finish()
