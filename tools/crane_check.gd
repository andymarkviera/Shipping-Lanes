extends SceneTree
## Patch 2.4 item 5: containers one by one. In the real game scene, ships 1, 3
## and 5 of the container family dock, take a full job and the quay cranes put
## the boxes aboard one at a time (more cranes on bigger ships), in about the
## loading timer's time, never floating over an empty slot, with Undock held
## until the last box is down. Abandoning the cargo takes them off one by one.
## A bulk ship gets no crane work. Isolated save; clocks are stepped by hand.
## Run: godot --headless --path . --script res://tools/crane_check.gd

const FOLDER: String = "user://crane_check"
const Progression = preload("res://features/game/progression.gd")
const CRANES = preload("res://features/ports/container_cranes.gd")
const Offers = preload("res://features/cargo/container_offers.gd")
const SAILED: Array[String] = ["container", "container_3", "container_5"]
const STEP: float = 1.0 / 20.0
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("CRANE FAILED: " + label)
	return condition

func wipe() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)

func open_game() -> Node:
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and scene.get("persistence") != null and is_instance_valid(scene.persistence) and (scene.persistence.ready_to_save or scene.persistence.blocked):
			return scene
	expect(false, "Game scene opened")
	return null

## Docks the game's ship of this kind at the first port that takes it.
func dock(game: Node, kind: String) -> bool:
	game.ship_kind = kind
	game.heavy_mode = kind.begins_with("heavy")
	game.bulk_active = ""
	game.fleet[kind] = {"fuel": 1.0, "condition": 1.0}
	for index: int in game.world_ports.size():
		if not game.select_port(index): continue
		var port: Node3D = game.world_ports[index]
		for frame: int in 2: await physics_frame
		game.ship.global_transform = port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
		game.ship.velocity = Vector3.ZERO
		for frame: int in 2: await physics_frame
		if not game.docking.request_dock(1, game.service_id(), game.cargo_id()).ok: continue
		for frame: int in 600:
			await physics_frame
			if game.docking.state(1) == "docked": return true
	return expect(false, "%s docks somewhere" % kind)

## No box sits over an empty slot of the same stack.
func supported(visuals: Node3D) -> bool:
	var centres: PackedVector3Array = visuals.layout.centres
	for slot: int in visuals.capacity:
		if visuals.filled[slot] == 0: continue
		for below: int in visuals.capacity:
			var c: Vector3 = centres[below]
			if visuals.filled[below] == 0 and c.y < centres[slot].y - 0.5 and absf(c.x - centres[slot].x) < 0.1 and absf(c.z - centres[slot].z) < 0.1: return false
	return true

## Steps the cranes (and the loading timer) by hand until they rest.
func work(game: Node, limit: float, label: String) -> Dictionary:
	var visuals: Node3D = game.ship.assembly.container_visuals
	var seen: Dictionary = {"seconds": 0.0, "steps_changed": 0, "max_jump": 0, "carried": false, "held": true, "supported": true, "spaced": true, "on_quay": true}
	var last: int = visuals.shown_count
	while seen.seconds < limit:
		game.loading.advance(STEP)
		game.cranes.advance(STEP)
		seen.seconds += STEP
		var now: int = visuals.shown_count
		if now != last:
			seen.steps_changed += 1
			seen.max_jump = maxi(seen.max_jump, absi(now - last))
			if not supported(visuals): seen.supported = false
		last = now
		for crane: Dictionary in game.cranes.works.get(1, {}).get("cranes", []):
			if crane.carried.visible: seen.carried = true
		for row: Array in game.cranes.ports[game.port]:
			for crane: Dictionary in row:
				if not on_quay(game.port, crane): seen.on_quay = false
			for index: int in range(1, row.size()):
				if row[index].z - row[index - 1].z < CRANES.GAP_M - 0.5: seen.spaced = false
		if visuals.shown_count != visuals.target_count and not game.cranes_busy(): seen.held = false
		if not game.loading.busy() and not game.cranes.busy(1): break
	expect(seen.on_quay, "%s: all crane bogies stay on solid quay throughout work" % label)
	expect(seen.spaced, "%s: cranes never run into each other on the rails" % label)
	expect(seen.seconds < limit, "%s: cranes finish within %.0f s (took %.1f s)" % [label, limit, seen.seconds])
	return seen

func sail(game: Node, kind: String) -> void:
	if not await dock(game, kind): return
	game.set_physics_process(false)
	game.loading.set_physics_process(false)
	game.cranes.set_process(false)
	var visuals: Node3D = game.ship.assembly.container_visuals
	game.cranes.advance(STEP)
	if not expect(game.cranes.works.has(1), "%s is worked by the cranes" % kind): return
	var count: int = game.cranes.works[1].cranes.size()
	expect(count >= 1 and count <= CRANES.cranes_for(visuals.capacity), "%s gets %d crane(s)" % [kind, count])
	if kind == "container_5": expect(count == CRANES.PER_BERTH, "Ship 5 gets every crane on the berth")
	expect(visuals.crane_driven, "%s deck is handed to the cranes" % kind)
	for frame: int in int(CRANES.BOOM_SECONDS / STEP) + 2: game.cranes.advance(STEP)
	for crane: Dictionary in game.cranes.works[1].cranes:
		expect(is_zero_approx(crane.raised), "%s working crane boom is down" % kind)
	# Take the biggest job on offer here (a full ship where there is one).
	game.refresh_jobs()
	var best: String = ""
	var quantity: int = 0
	for item: int in game.jobs_list.item_count:
		var id: String = str(game.jobs_list.get_item_metadata(item))
		var offer: Dictionary = game.offers.view(id)
		if int(offer.get("quantity", 0)) > quantity and int(offer.quantity) <= visuals.capacity:
			best = id
			quantity = int(offer.quantity)
	if not expect(quantity > 0, "%s has a container job" % kind): return
	game.selected_offer = best
	game.accept_selected()
	if not expect(game.loading.busy(), "%s starts loading %d containers" % [kind, quantity]): return
	expect(visuals.shown_count == 0, "%s deck is empty when loading starts" % kind)
	var timer: float = Offers.loading_seconds(quantity)
	game.cranes.advance(0.0)
	var limit: float = timer + 2.0 * game.cranes.works[1].period + 4.0
	var loaded: Dictionary = work(game, limit + 5.0, kind + " loading")
	expect(visuals.shown_count == quantity and visuals.target_count == quantity, "%s ends with all %d containers aboard (%d)" % [kind, quantity, visuals.shown_count])
	expect(loaded.seconds <= limit, "%s loads in about the timer's %.0f s (%.1f s)" % [kind, timer, loaded.seconds])
	expect(loaded.max_jump <= count, "%s boxes land one per crane at a time (jump %d)" % [kind, loaded.max_jump])
	expect(loaded.steps_changed >= quantity / count, "%s boxes appear over %d separate moments" % [kind, loaded.steps_changed])
	expect(loaded.carried, "%s cranes carry visible boxes" % kind)
	expect(loaded.held, "%s Undock waits for the cranes" % kind)
	expect(loaded.supported, "%s never stacks a box over an empty slot" % kind)
	print("%s: %d boxes, %d cranes, %.2f s a box, timer %.1f s, loaded in %.1f s" % [kind, quantity, count, game.cranes.works[1].period, timer, loaded.seconds])
	# Abandon the cargo: the manifest empties at once, the cranes take it off.
	game.end_current_job(true)
	expect(visuals.target_count == 0 and visuals.shown_count == quantity and game.cranes_busy(), "%s cargo leaves by crane, not all at once" % kind)
	var off: Dictionary = work(game, limit + 5.0, kind + " unloading")
	expect(visuals.shown_count == 0, "%s deck is empty after unloading" % kind)
	expect(off.seconds <= limit, "%s unloads in about the timer's time (%.1f s)" % [kind, off.seconds])
	expect(off.max_jump <= count and off.steps_changed >= quantity / count, "%s boxes leave one at a time" % kind)
	print("%s: unloaded in %.1f s" % [kind, off.seconds])
	expect(off.supported, "%s unloads from the top down" % kind)
	# Undock: the cranes stand down and raise their booms.
	expect(game.docking.request_undock(1), "%s can undock once the cranes rest" % kind)
	game.docking.advance(game.docking.undock_seconds + 0.01)
	game.cranes.advance(STEP)
	expect(not game.cranes.works.has(1), "%s work ends on undock" % kind)
	for frame: int in int(CRANES.BOOM_SECONDS / STEP) + 2: game.cranes.advance(STEP)
	for row: Array in game.cranes.ports[game.port]:
		for crane: Dictionary in row:
			expect(is_equal_approx(crane.raised, 1.0) and not crane.carried.visible, "%s idle cranes raise their booms" % kind)
	game.cranes.set_process(true)
	game.loading.set_physics_process(true)
	game.set_physics_process(true)

## Check the full bogie footprint against actual solid quay geometry, including
## mirrored/rotated polar ports; not just crane centres or a copied rail limit.
func on_quay(port: Node3D, crane: Dictionary) -> bool:
	for q: float in [CRANES.SEA_LEG_Q, CRANES.LAND_LEG_Q]:
		for dx: float in [-1.2, 1.2]:
			for dz: float in [-5.8, 5.8]:
				var foot: Vector3 = crane.node.to_global(Vector3(port.quay_side * q + dx, CRANES.QUAY_TOP_Y, dz))
				var supported_foot: bool = false
				for label: String in ["Quay", "QuayExtension"]:
					var body: Node3D = port.get_node_or_null(label)
					if body == null: continue
					for child: Node in body.get_children():
						if child is CollisionShape3D and child.shape is BoxShape3D:
							var local: Vector3 = child.to_local(foot)
							var half: Vector3 = child.shape.size / 2.0
							if absf(local.x) <= half.x + 0.02 and absf(local.z) <= half.z + 0.02 and absf(local.y - half.y) < 0.02:
								supported_foot = true
				if not supported_foot: return false
	return true

func run() -> void:
	await process_frame
	wipe()
	for capacity: int in [24, 60, 112, 180, 288]:
		var count: int = CRANES.cranes_for(capacity)
		var per: float = CRANES.period_for(capacity, ceili(float(capacity) / count))
		expect(per >= CRANES.MIN_PERIOD and per <= 2.0, "A full %d-box ship: %d crane(s), %.2f s a box each" % [capacity, count, per])
	var game: Node = await open_game()
	if game != null and expect(not game.persistence.blocked, "Isolated save opens"):
		expect(game.cranes != null and game.cranes.ports.size() == game.world_ports.size(), "Every port has quay cranes")
		for port: Node3D in game.world_ports:
			expect(game.cranes.ports[port].size() == port.berth_anchors.size(), "%s has cranes on every berth" % port.definition.id)
			for row: Array in game.cranes.ports[port]:
				for crane: Dictionary in row:
					expect(on_quay(port, crane), "%s: parked crane %.1f stands on solid quay" % [port.definition.id, crane.z])
		for kind: String in SAILED: await sail(game, kind)
		if await dock(game, "bulk"):
			game.cranes.advance(STEP)
			expect(not game.cranes.works.has(1), "A bulk ship gets no crane work")
	if current_scene != null:
		current_scene.queue_free()
		for frame: int in 3: await process_frame
	wipe()
	for failure: String in failures: push_error(failure)
	print("CRANE_CHECK_PASS checks=%d" % checks if failures.is_empty() else "CRANE_CHECK_FAILED %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
