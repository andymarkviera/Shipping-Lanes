extends SceneTree
## Patch 4.0.3 headless checks (issue #226). First the scene-free ones
## (patch_4_0_3_logic.gd, also run by check_catalog.gd in the Checks job),
## then, in the real game scene with an isolated save: every buyable ship
## class docks at Cinder Point (the port that refused heavy lifters) and
## every heavy lifter at every port; docked, a heavy lifter's port card shows
## one platform button (Drop, then Lift) that lowers and raises the deck,
## and no other class shows it; the dock menu's actions sit on the left
## (Refuel, Repair / Switch to Plane) and the two shops stack on the right
## (Ships over Planes); flying, the throttle slider is the plane's lever
## (0-100%, marked 0% / 50% / 100%) both ways, and R / N / D again on a
## boat; the plane job board is the boat board's cards (cargo picture, the
## route, km, minutes, fuel, gold pay, Accept, the gold edge under the
## mouse), Accept takes the job and the globe draws the course to its
## airport.
## Run: godot --headless --path . --script res://tools/patch_4_0_3_check.gd
const Logic = preload("res://tools/patch_4_0_3_logic.gd")
const Progression = preload("res://features/game/progression.gd")
const Airports = preload("res://features/planes/airports.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Heavy = preload("res://features/handling/heavy_lifter.gd")
const Navigation = preload("res://features/ports/local_navigation.gd")
const Hud = preload("res://features/game/game_hud.gd")
const FOLDER: String = "user://patch_4_0_3_check"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("PATCH 4.0.3 FAILED: " + label)
	return condition

func settle() -> void:
	for frame: int in 3:
		await process_frame
		await physics_frame

func wait_for(test: Callable) -> Node:
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and test.call(scene): return scene
	return null

func run() -> void:
	var logic: RefCounted = Logic.new()
	for part: String in Logic.PARTS: logic.call(part)
	checks += logic.checks
	for label: String in logic.failures:
		failures.append(label)
		print("PATCH 4.0.3 FAILED: " + label)
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = await wait_for(func(scene: Node) -> bool: return scene.get("persistence") != null and is_instance_valid(scene.persistence) and scene.persistence.ready_to_save)
	if not expect(game != null and is_instance_valid(game.get("aviation")), "the game opened with its planes"): return finish()
	await settle()
	await dock_every_class(game)
	await dock_menu(game)
	await flying(game)
	game.leave()
	await wait_for(func(scene: Node) -> bool: return scene.name == "Main")
	finish()

## Sails `kind` from port `index`'s berth approach and docks; true once docked.
func dock(game: Node, kind: String, index: int) -> bool:
	game.ship_kind = kind
	game.heavy_mode = Progression.heavy_tier(kind) > 0
	game.bulk_active = ""
	game.fleet[kind] = {"fuel": 1.0, "condition": 1.0}
	if not game.select_port(index): return false
	for frame: int in 2: await physics_frame
	game.ship.global_transform = game.port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
	game.ship.velocity = Vector3.ZERO
	for frame: int in 2: await physics_frame
	var asked: Dictionary = game.docking.request_dock(game.owner_id, game.service_id(), game.cargo_id())
	if not asked.ok:
		print("  %s at %s: %s" % [kind, game.port.definition.id, asked.get("message", "")])
		return false
	for frame: int in 400:
		await physics_frame
		if game.docking.state(game.owner_id) == "docked": return true
	return false

## Item 4: every class docks; heavy lifters get the Lift / Drop button.
func dock_every_class(game: Node) -> void:
	var cinder: int = Progression.port_index("port_cinder_point")
	for kind: String in Progression.SHIPS:
		if not Progression.buyable(kind): continue
		if not expect(await dock(game, kind, cinder), "%s docks at Cinder Point" % kind): continue
		await settle()
		var heavy: bool = Progression.heavy_tier(kind) > 0
		expect(game.heavy_controls.visible == heavy, "%s: the platform button %s" % [kind, "shows" if heavy else "stays hidden"])
		if not heavy: continue
		expect(game.port_panel.visible and game.lift_button.is_visible_in_tree() and not game.cancel_pickup_button.visible, "%s: docked, the port card shows Lift / Drop (no Cancel pickup without a job)" % kind)
		var ship: HandlingShip = game.ship
		expect(game.lift_button.text == "Drop", "%s: the deck is up, the button says Drop" % kind)
		game.lift_button.pressed.emit()
		await settle()
		expect(is_equal_approx(ship.deck_target, Heavy.LOWERED), "%s: Drop lowers the deck" % kind)
		expect(game.lift_button.text == "Lift", "%s: then the button says Lift" % kind)
		for frame: int in 600:
			await physics_frame
			if absf(ship.deck_height - Heavy.LOWERED) <= 0.001: break
		game.lift_button.pressed.emit()
		await settle()
		expect(is_equal_approx(ship.deck_target, Heavy.RAISED) and game.lift_button.text == "Drop", "%s: Lift raises it again" % kind)
		for frame: int in 600:
			await physics_frame
			if absf(ship.deck_height - Heavy.RAISED) <= 0.001: break
	# And every heavy lifter at every port (the heavy ladder check stages the loads).
	for kind: String in Progression.HEAVY_KINDS:
		for index: int in game.world_ports.size():
			if index == cinder: continue
			expect(await dock(game, kind, index), "%s docks at %s" % [kind, game.world_ports[index].definition.id])

## Item 5: Refuel, Repair ... Ships / Switch to Plane ... Planes.
func dock_menu(game: Node) -> void:
	if not expect(await dock(game, Progression.CONTAINER_KINDS[0], Progression.port_index("port_cinder_point")), "the container ship docks for the dock menu"): return
	await settle()
	await settle()
	var air: Node = game.aviation
	var tabs: Node = game.refuel_button.get_parent()
	var row1: Array = tabs.get_children().filter(func(item: Node) -> bool: return item is Control and item.visible)
	var row2: Array = air.port_row.get_children().filter(func(item: Node) -> bool: return item is Control and item.visible)
	var names1: Array = row1.map(func(item: Control) -> String: return item.text if item is Button else "gap")
	var names2: Array = row2.map(func(item: Control) -> String: return item.text if item is Button else "gap")
	expect(names1.size() == 4 and names1[0].begins_with("Refuel") and names1[1].begins_with("Repair") and names1[2] == "gap" and names1[3] == "Ships", "row 1: Refuel, Repair, then Ships on the right (%s)" % str(names1))
	expect(names2 == ["Switch to Plane", "gap", "Planes"], "row 2: Switch to Plane, then Planes on the right (%s)" % str(names2))
	if names1.size() != 4 or names2.size() != 3: return
	var ships: Rect2 = (row1[3] as Control).get_global_rect()
	var planes: Rect2 = (row2[2] as Control).get_global_rect()
	expect(absf(ships.end.x - planes.end.x) <= 2.0, "Planes sits under Ships, both at the right edge (%.0f, %.0f)" % [ships.end.x, planes.end.x])
	expect(absf((row1[0] as Control).get_global_rect().position.x - (row2[0] as Control).get_global_rect().position.x) <= 2.0, "Switch to Plane starts its row, under Refuel")
	expect(ships.position.x > (row1[1] as Control).get_global_rect().end.x and planes.position.x > (row2[0] as Control).get_global_rect().end.x, "the shops stand clear of the actions")
	expect(planes.position.y > ships.end.y - 1.0, "Planes is below Ships")

## Addendum and item 6: the throttle widget flying, the plane job cards.
func flying(game: Node) -> void:
	var air: Node = game.aviation
	var hud: Control = game.game_hud
	air.unlock_all()
	if not expect(air.switch_to_plane() and game.flying(), "the captain flies a plane from the dock"): return
	await settle()
	expect(hud.slider.is_visible_in_tree() and hud.plane_mode, "flying, the boat's throttle slider stays on the helm bar")
	expect(is_equal_approx(hud.slider.min_value, 0.0) and is_equal_approx(hud.slider.max_value, 1.0), "it runs 0 to 100% (no reverse)")
	expect(hud.marks.map(func(mark: Label) -> String: return mark.text) == Hud.PLANE_MARKS, "marked 0% / 50% / 100%")
	air.lever = 0.5
	await settle()
	expect(is_equal_approx(hud.slider.value, 0.5), "the slider shows the lever (Shift / Ctrl)")
	hud.slider.value = 1.0
	await settle()
	expect(is_equal_approx(air.lever, 1.0), "dragging the slider sets the lever (%.2f)" % air.lever)
	air.lever = 0.0
	await settle()
	# Item 6: the plane job cards.
	var here: int = air.stopped_at()
	if not expect(here >= 0 and air.card.visible, "stopped at the airport, its card shows"): return
	air.refresh_ui()
	await settle()
	var cards: Array = air.card_jobs.get_children().filter(func(item: Node) -> bool: return item is PanelContainer and not item.is_queued_for_deletion())
	var board: Array[Dictionary] = Jobs.board(here, air.plane_entry())
	expect(not cards.is_empty() and cards.size() == board.size(), "one card per plane job (%d of %d)" % [cards.size(), board.size()])
	if cards.is_empty(): return
	var first: PanelContainer = cards[0]
	expect(first.find_child("CargoArt", true, false) != null, "each card has its cargo picture")
	var trip: Label = first.find_child("Trip", true, false)
	expect(trip != null and trip.text.contains(" km") and trip.text.contains(" min") and trip.text.contains(" L fuel"), "and the km, minutes and fuel (%s)" % (trip.text if trip != null else "none"))
	var pay: Label = first.find_child("Pay", true, false)
	expect(pay != null and pay.text.begins_with("+") and pay.get_theme_color("font_color") == hud.PLAYFUL.SUN, "the pay in gold")
	expect(first.get_theme_stylebox("panel") == first.get_meta("rest_style"), "the card's edge is ink at rest")
	first.mouse_entered.emit()
	expect(first.get_theme_stylebox("panel") == first.get_meta("hover_style"), "and gold under the mouse")
	first.mouse_exited.emit()
	expect(first.get_theme_stylebox("panel") == first.get_meta("rest_style"), "and ink again after")
	var take: Button = null
	for item: Node in first.find_children("*", "Button", true, false):
		if (item as Button).text == "Accept": take = item
	if not expect(take != null, "each card has Accept"): return
	take.pressed.emit()
	await settle()
	expect(air.job_id == str(board[0].id), "Accept takes the job (%s)" % air.job_id)
	var target: Dictionary = Navigation.target(game)
	expect(int(target.get("airport", -1)) == int(board[0].destination) and not (target.get("route", []) as Array).is_empty(), "the chart points at the job's airport")
	if expect(is_instance_valid(game.globe_map), "the game has its globe"):
		game.globe_map.open()
		await settle()
		game.globe_map.draw_course(target)
		expect(game.globe_map.course_dots > 0, "and the globe draws the course there (%d dots)" % game.globe_map.course_dots)
		game.globe_map.close()
	air.job_id = ""
	await settle()
	expect(air.switch_to_boat() and not game.flying(), "Switch to Boat")
	await settle()
	expect(not hud.plane_mode and is_equal_approx(hud.slider.min_value, -1.0) and hud.marks.map(func(mark: Label) -> String: return mark.text) == Hud.BOAT_MARKS, "back on the boat, the slider is R / N / D again")

func finish() -> void:
	if failures.is_empty(): print("PATCH_4_0_3_CHECK_PASS (%d checks)" % checks)
	else: print("PATCH_4_0_3_CHECK_FAIL (%d of %d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
