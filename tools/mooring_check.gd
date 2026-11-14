extends SceneTree
## Patch 2.4 item 4: mooring lines. Checks that every ladder ship model has
## fairleads at the bow and stern on both sides, and in the real game scene
## that a small and a big ship of each family tie up after docking (bow and
## stern lines; springs too on big ships) to quay bollards on the quay side,
## and on Undock let go and reel in before the helm comes back. Isolated save.
## Run: godot --headless --path . --script res://tools/mooring_check.gd

const FOLDER: String = "user://mooring_check"
const Progression = preload("res://features/game/progression.gd")
const CHUNKY = preload("res://features/toon/chunky_look.gd")
const LINES = preload("res://features/ports/mooring_lines.gd")
const SAILED: Array[String] = ["container", "container_5", "bulk", "bulk_5", "heavy", "heavy_5"]
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("MOORING FAILED: " + label)
	return condition

func wipe() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)

func check_models() -> void:
	for kind: String in Progression.CONTAINER_KINDS + Progression.BULK_KINDS + Progression.HEAVY_KINDS:
		var ship: ShipDefinition = Progression.definition(kind)
		var model: Node3D = CHUNKY.model(kind, ship)
		var size: Vector3 = ship.hull_size_m
		for end: String in ["Bow", "Stern"]:
			for side: String in ["L", "R"]:
				var lead: Marker3D = model.find_child("Mooring%s%s" % [end, side], true, false) as Marker3D
				if not expect(lead != null, "%s has a %s %s fairlead" % [kind, end, side]): continue
				var at: Vector3 = lead.position
				expect((at.x < 0.0) == (side == "L") and absf(at.x) > size.x * 0.4 and absf(at.x) < size.x / 2.0 + 0.6, "%s %s%s fairlead is on the rail (x %.1f)" % [kind, end, side, at.x])
				expect((at.z > 0.0) == (end == "Bow") and absf(at.z) < size.z / 2.0, "%s %s%s fairlead is at its end of the hull" % [kind, end, side])
				expect(at.y > 1.0 and at.y < size.y * 2.0 + 2.0, "%s %s%s fairlead is above the water on deck" % [kind, end, side])
		model.free()

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

func is_bollard(port: Node3D, at: Vector3) -> bool:
	for point: Vector3 in port.bollard_points():
		if (port.global_transform * point).distance_to(at) < 0.01: return true
	return false

func moor(game: Node, kind: String) -> void:
	game.ship_kind = kind
	game.heavy_mode = kind.begins_with("heavy")
	game.bulk_active = ""
	game.fleet[kind] = {"fuel": 1.0, "condition": 1.0}
	for index: int in game.world_ports.size():
		if not game.select_port(index): continue
		var ship: HandlingShip = game.ship
		var port: Node3D = game.world_ports[index]
		for frame: int in 2: await physics_frame
		ship.global_transform = port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
		ship.velocity = Vector3.ZERO
		for frame: int in 2: await physics_frame
		if not game.docking.request_dock(1, game.service_id(), game.cargo_id()).ok: continue
		expect(game.mooring.ropes(1).is_empty(), "%s has no lines out while sliding in" % kind)
		for frame: int in 600:
			await physics_frame
			if game.docking.state(1) == "docked": break
		if not expect(game.docking.state(1) == "docked", "%s docks at %s" % [kind, port.definition.id]): return
		var berth: Transform3D = ship.global_transform
		game.mooring.advance(LINES.TIE_SECONDS + 0.1)
		var ropes: Array = game.mooring.ropes(1)
		var springs: bool = ship.definition.hull_size_m.z >= LINES.SPRING_LENGTH_M
		expect(ropes.size() == (4 if springs else 2), "%s puts out %d lines (got %d)" % [kind, 4 if springs else 2, ropes.size()])
		expect(is_equal_approx(game.mooring.lines_out(1), 1.0), "%s lines are made fast" % kind)
		var to_port: Transform3D = port.global_transform.affine_inverse()
		for rope: Dictionary in ropes:
			expect(rope.mesh.visible and (rope.mesh.mesh as ImmediateMesh).get_surface_count() == 1, "%s line is drawn" % kind)
			expect(is_bollard(port, rope.to), "%s line is made fast to a quay bollard" % kind)
			var from: Vector3 = to_port * (rope.from as Node3D).global_position
			expect(absf(from.x - port.quay_side * port.BOLLARD_X_M) < ship.definition.hull_size_m.x / 2.0, "%s line leaves from its quay-side rail" % kind)
			expect(from.distance_to(to_port * rope.to) < ship.definition.hull_size_m.z, "%s line is a sensible length" % kind)
		# Bow line leads ahead of the bow, stern line astern of the stern.
		var ahead: Vector3 = to_port.basis * ship.global_basis.z
		if ropes.size() >= 2:
			expect(((to_port * ropes[0].to) - (to_port * (ropes[0].from as Node3D).global_position)).dot(ahead) > 0.0, "%s bow line leads forward" % kind)
			# A ship 5 at berth 1 overhangs the quay's start; then the stern line
			# goes to the aftmost bollard, the best there is.
			var stern: Vector3 = to_port * (ropes[1].from as Node3D).global_position
			var aftmost: float = INF
			for point: Vector3 in port.bollard_points(): aftmost = minf(aftmost, point.dot(ahead))
			var tied: Vector3 = to_port * ropes[1].to
			expect((tied - stern).dot(ahead) < 0.0 or (stern.dot(ahead) < aftmost and is_equal_approx(tied.dot(ahead), aftmost)), "%s stern line leads aft" % kind)
		# Undock: the ship stays put while the lines let go and reel in.
		game.set_physics_process(false)
		game.docking.set_physics_process(false)
		expect(game.docking.request_undock(1), "%s can undock" % kind)
		game.docking.advance(LINES.LET_GO_SECONDS / 2.0)
		game.mooring.advance(0.0)
		expect(game.docking.state(1) == "undocking" and ship.docked and not ship.helm_available(), "%s is held while the lines come in" % kind)
		expect(game.mooring.lines_out(1) > 0.3 and game.mooring.lines_out(1) < 0.7, "%s lines are halfway in (%.2f)" % [kind, game.mooring.lines_out(1)])
		expect(ship.global_transform.origin.distance_to(berth.origin) < 0.01, "%s does not move while letting go" % kind)
		game.docking.advance(LINES.LET_GO_SECONDS / 2.0 + 0.01)
		game.mooring.advance(0.0)
		expect(game.docking.state(1) in ["underway", "approaching"] and ship.helm_available(), "%s helm is back once the lines are in" % kind)
		expect(game.mooring.ropes(1).is_empty() and game.mooring.lines_out(1) == 0.0, "%s has no lines out after undocking" % kind)
		game.docking.set_physics_process(true)
		game.set_physics_process(true)
		return
	expect(false, "%s found a port to dock at" % kind)

func run() -> void:
	await process_frame
	wipe()
	check_models()
	var game: Node = await open_game()
	if game != null and expect(not game.persistence.blocked, "Isolated save opens"):
		expect(game.mooring != null and game.docking.undock_seconds == LINES.LET_GO_SECONDS, "The game has mooring lines and holds Undock for them")
		for kind: String in SAILED: await moor(game, kind)
	if current_scene != null:
		current_scene.queue_free()
		for frame: int in 3: await process_frame
	wipe()
	for failure: String in failures: push_error(failure)
	print("MOORING_CHECK_PASS checks=%d" % checks if failures.is_empty() else "MOORING_CHECK_FAILED %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
