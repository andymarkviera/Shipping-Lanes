extends SceneTree
## M1 scripted playthrough (REBUILD_PLAN.md section 3): one real voyage.
## Opens the home menu, clicks PLAY, sails from the Brindle Quay spawn to its berth,
## takes a container job, sails to Slatewater Works, delivers, checks the wallet,
## leaves through "Main menu", clicks CONTINUE and checks the wallet came back.
## M2 (same run): pays for fuel, runs dry and calls the tow, sinks and is recovered,
## then uses Restart Progress.
## All sailing is real key presses through PlayerControls and ShipHelm; the ship is
## never moved by code. Buttons are clicked only when visible and enabled.
## The save goes to an isolated folder, never the player's game save.
## Run: godot --headless --path . --script res://tools/check_m1_voyage.gd

const FOLDER: String = "user://m1_voyage_check"
const MAIN_SCRIPT: String = "res://features/main/main.gd"
const GAME_SCRIPT: String = "res://features/ports/port_test.gd"
const OWNER: String = "preview_captain"
## Simulated seconds allowed for one sailing leg.
const LEG_SECONDS: int = 600
var failures: Array[String] = []
var bindings: Dictionary = {}
var held: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
		print("M1_VOYAGE FAILED: " + label)
	return condition

func note(label: String, ship: HandlingShip) -> void:
	print("M1_VOYAGE %s x=%.0f z=%.0f speed=%.2f m/s fuel=%.0f L" % [label, ship.global_position.x, ship.global_position.z, ship.forward_speed(), ship.state.fuel_liters])

func wipe() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)

## Runs the simulation faster than real time without changing the 1/60 s physics
## step: more ticks per second, each the same length. Each setting is kept only if
## the engine really reports a 1/60 s step; the last one is plain real time.
func fast_forward() -> void:
	for setting: Vector2i in [Vector2i(30, 1800), Vector2i(16, 960), Vector2i(30, 60), Vector2i(1, 60)]:
		Engine.time_scale = setting.x
		Engine.physics_ticks_per_second = setting.y
		Engine.max_physics_steps_per_frame = maxi(8, 4 * setting.x)
		for frame: int in 3:
			await process_frame
			await physics_frame
		if absf(root.get_physics_process_delta_time() - 1.0 / 60.0) < 0.0001:
			print("M1_VOYAGE time scale %d, %d physics ticks per second" % [setting.x, setting.y])
			return
	expect(false, "Physics step is not 1/60 s")

func key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code as Key
	event.physical_keycode = code as Key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func hold(action: String, on: bool) -> void:
	if bool(held.get(action, false)) == on: return
	held[action] = on
	key(int(bindings[action]), on)

func release_all() -> void:
	for action: String in held.keys(): hold(action, false)

func until(done: Callable, seconds: int, label: String) -> bool:
	for tick: int in seconds * 60:
		if done.call(): return true
		await physics_frame
	return expect(false, label + " (timed out)")

func open_scene(script_path: String, label: String) -> Node:
	for frame: int in 900:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and scene.get_script() != null and scene.get_script().resource_path == script_path:
			return scene
	expect(false, label + " did not open")
	return null

## Clicks a button the way a player can: it must be on screen and enabled.
func click(scene: Node, title: String) -> bool:
	release_all()
	for attempt: int in 50:
		await settle()
		for node: Node in scene.find_children("*", "Button", true, false):
			var item: Button = node as Button
			if item.text == title and item.is_visible_in_tree() and not item.disabled:
				item.pressed.emit()
				await settle()
				return true
	return expect(false, "Button \"%s\" is not on screen or not enabled" % title)

## Lets at least two physics ticks and two _process calls finish, in that order.
## Headless frames can outrun physics ticks, so counting frames alone is not enough.
func settle() -> void:
	for step: int in 2:
		await process_frame
		await physics_frame
	await process_frame

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## One helm decision: which of the real keys to hold this tick to point the bow at
## the target and hold the speed. Steer left turns the bow toward +X.
func helm_toward(ship: HandlingShip, target: Vector3, speed: float) -> void:
	var to: Vector3 = target - ship.global_position
	var bow: Vector3 = ship.global_transform.basis.z
	var error: float = wrapf(atan2(to.x, to.z) - atan2(bow.x, bow.z), -PI, PI) - ship.yaw_rate
	hold("ship_steer_left", error > deg_to_rad(1.0))
	hold("ship_steer_right", error < -deg_to_rad(1.0))
	var top: float = ship.definition.forward_acceleration_mps2 / ship.definition.linear_drag_per_second
	var order: float = clampf(speed / top + 0.2 * (speed - ship.forward_speed()), -0.5, 1.0)
	hold("ship_throttle_up", ship.commanded_throttle < order - 0.05)
	hold("ship_throttle_down", ship.commanded_throttle > order + 0.05)

func why_stuck(game: Node) -> String:
	return "helm notice: \"%s\"" % game.helm.notice.reason().replace("\n", " ")

func sail_to(game: Node, target: Vector3, radius: float, cruise: float, label: String) -> bool:
	var ship: HandlingShip = game.ship
	for tick: int in LEG_SECONDS * 60:
		if flat_distance(ship.global_position, target) < radius:
			note(label, ship)
			return true
		helm_toward(ship, target, cruise)
		await physics_frame
	release_all()
	note(label + " TIMED OUT", ship)
	return expect(false, "%s: not reached by key press; %s" % [label, why_stuck(game)])

## Follows the berth centreline (both berths face +Z), slows down, stops with the
## zero-throttle key and waits for the ship to come to rest.
func berth_approach(game: Node, place: Node3D, label: String) -> bool:
	var ship: HandlingShip = game.ship
	var berth: Vector3 = place.berth_anchor.global_position
	var arrived: bool = false
	for tick: int in LEG_SECONDS * 60:
		var remaining: float = berth.z - ship.global_position.z
		if remaining < 20.0:
			arrived = true
			break
		var lined_up: bool = absf(ship.global_position.x - berth.x) < 10.0 and absf(ship.global_transform.basis.z.x) < 0.2
		var aim: Vector3 = Vector3(berth.x, 0, ship.global_position.z + 120.0)
		helm_toward(ship, aim, clampf(remaining * 0.03, 1.0, 10.0 if lined_up else 5.0))
		await physics_frame
	release_all()
	if not arrived:
		note(label + " TIMED OUT", ship)
		return expect(false, "%s: berth not reached by key press; %s" % [label, why_stuck(game)])
	hold("ship_throttle_zero", true)
	for tick: int in 6: await physics_frame
	hold("ship_throttle_zero", false)
	var stopped: bool = await until(func() -> bool: return ship.velocity.length() < 0.05 and ship.commanded_throttle == 0.0, 120, label + ": ship stops at the berth")
	note(label, ship)
	return stopped

func dock(game: Node, label: String) -> bool:
	# The Dock button enables itself on a physics tick once the berth reports ready.
	if not await until(func() -> bool: return game.dock_button.is_visible_in_tree() and not game.dock_button.disabled and game.dock_button.text == "Dock", 10, "%s: Dock is offered (%s)" % [label, game.readiness.text]): return false
	if not await click(game, "Dock"): return false
	return await until(func() -> bool: return game.docking.state(1) == "docked", 10, label + ": ship docks")

func undock(game: Node, label: String) -> bool:
	if not await click(game, "Undock"): return false
	if not await until(func() -> bool: return game.docking.state(1) in ["underway", "approaching"], 10, label + ": ship undocks"): return false
	await settle()
	return expect(game.controls.input_allowed(), "%s: helm accepts input after Undock; %s" % [label, why_stuck(game)])

func press_escape() -> void:
	release_all()
	await settle()
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await settle()

## Patch 2.0 item 1: Esc opens a menu over a world that keeps running, and losing
## the window does not stop the ship either. Called under way, clear of the quay.
func always_running(game: Node) -> void:
	var ship: HandlingShip = game.ship
	var order: float = ship.commanded_throttle
	expect(order > 0.1 and not game.game_menu.is_open(), "Under way with the menu closed before Esc (order %.2f)" % order)
	await press_escape()
	expect(game.game_menu.is_open(), "Esc opens the in-game menu")
	expect(current_scene == game and not paused, "Esc neither leaves the game nor pauses the tree")
	var titles: Array = []
	for node: Node in game.game_menu.panel.find_children("*", "Button", true, false): titles.append(node.text)
	expect(titles == ["RESUME", "SETTINGS", "MAIN MENU", "QUIT"], "The menu offers Resume, Settings, Main Menu and Quit (%s)" % str(titles))
	var from: Vector3 = ship.global_position
	var clock: float = game.offer_time
	for tick: int in 120: await physics_frame
	expect(not game.controls.input_allowed() and game.helm.notice.reason() == "", "Menu open: helm keys are released and no warning banner shows (%s)" % game.helm.notice.reason())
	expect(ship.commanded_throttle == order and flat_distance(ship.global_position, from) > 5.0 and game.offer_time > clock + 1.9,
		"Menu open: the ship sails on and the world clock ticks (moved %.1f m, order %.2f)" % [flat_distance(ship.global_position, from), ship.commanded_throttle])
	if not await click(game, "SETTINGS"): return
	expect(game.game_menu.settings.visible and not game.game_menu.panel.visible, "Settings opens from the menu")
	await press_escape()
	expect(not game.game_menu.settings.visible and game.game_menu.panel.visible, "Esc in Settings returns to the menu")
	await press_escape()
	expect(not game.game_menu.is_open(), "Esc closes the menu")
	await until(func() -> bool: return game.controls.input_allowed(), 5, "Helm returns after the menu closes; " + why_stuck(game))
	# The window loses focus (alt-tab or minimise): no pause, no menu, the ship sails on.
	from = ship.global_position
	game.controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for tick: int in 120: await physics_frame
	expect(not paused and not game.game_menu.is_open() and not ship.simulation_paused and ship.commanded_throttle == order and flat_distance(ship.global_position, from) > 5.0,
		"Window not active: the ship sails on (moved %.1f m, order %.2f)" % [flat_distance(ship.global_position, from), ship.commanded_throttle])
	game.controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await until(func() -> bool: return game.controls.input_allowed(), 5, "Helm returns when the window is active again; " + why_stuck(game))

func open_game(label: String) -> Node:
	var game: Node = await open_scene(GAME_SCRIPT, label)
	if game == null: return null
	if not await until(func() -> bool: return is_instance_valid(game.persistence) and (game.persistence.ready_to_save or game.persistence.blocked), 20, label + ": save opens"): return null
	if not expect(not game.persistence.blocked, "%s: save is usable (%s)" % [label, game.readiness.text]): return null
	expect(game.game_mode and game.save_path.begins_with(FOLDER), label + ": game uses the isolated check save")
	bindings = game.controls.preferences.bindings
	await settle()
	return game

func play() -> void:
	change_scene_to_file("res://features/main/main.tscn")
	var menu: Node = await open_scene(MAIN_SCRIPT, "Home menu")
	if menu == null: return
	expect(menu.menu.game_button.text == "PLAY", "No save yet: the button says PLAY")
	if not await click(menu, "PLAY"): return
	var game: Node = await open_game("New game")
	if game == null: return
	var brindle: Node3D = game.world_ports[0]
	var slatewater: Node3D = game.world_ports[1]
	expect(game.port == brindle and brindle.definition.id == "port_brindle_quay", "New game starts at Brindle Quay")
	expect(game.reward_minor == 0, "New game starts with an empty wallet")
	expect(not game.switch_button.visible, "The game does not offer the test heavy loader")
	# M5: a new captain sees the helm keys and the next step; the two game sounds exist.
	expect(game.game_hud.hint.is_visible_in_tree() and game.game_hud.hint_label.text.contains("throttle") and game.voyage_hud.instruction.text.contains("click Dock"), "New game shows the helm keys and the first step (%s)" % game.voyage_hud.instruction.text)
	# Patch 2.0 item 5: the simplified HUD.
	expect(game.minimap.get_script().resource_path.ends_with("globe_minimap.gd") and game.minimap.is_visible_in_tree(), "The minimap is the globe")
	expect(not game.port_panel.visible and not game.helm.throttle_display.visible and not game.readiness.is_visible_in_tree(), "At sea the top-left panel and the old throttle panel are gone")
	expect(game.game_hud.bar.is_visible_in_tree() and game.game_hud.knots.text == "0 kn" and game.dock_button.get_parent().get_parent().get_parent() == game.game_hud.bar, "The helm bar shows the speed in knots with Dock beside the slider (%s)" % game.game_hud.knots.text)
	expect(game.sfx.has("chime") and game.sfx.has("thud"), "The game has its paid and collision sounds")
	# Patch 2.1 item 3: past any edge of the world the ship comes back on the opposite side.
	var wrap_m: float = game.Progression.WRAP_M
	var home: Vector3 = game.ship.global_position
	for step: Vector3 in [Vector3(wrap_m, 0, 0), Vector3(-wrap_m, 0, 0), Vector3(0, 0, wrap_m), Vector3(0, 0, -wrap_m), Vector3(-wrap_m, 0, wrap_m)]:
		game.ship.global_position = home + step
		for tick: int in 3: await physics_frame
		expect(flat_distance(game.ship.global_position, home) < 1.0, "World wraps: a ship %s past the edge is back on the other side" % step)
	var edge: Vector3 = game.Progression.WRAP_CENTRE + Vector3(wrap_m / 2 - 5, 0, 0)
	expect(game.Progression.wrapped(edge + Vector3(10, 0, 0)).distance_to(edge - Vector3(wrap_m - 10, 0, 0)) < 0.01, "World wraps: 5 m past the east edge is 5 m inside the west edge")
	expect(game.Progression.nearest(edge - Vector3(wrap_m - 10, 0, 0), edge).distance_to(edge + Vector3(10, 0, 0)) < 0.01, "World wraps: the nearest copy of a point is across the edge")
	for rect: Rect2 in game.Progression.LAND:
		var middle: Vector3 = Vector3(rect.get_center().x, 0, rect.get_center().y) - game.Progression.WRAP_CENTRE
		expect(absf(middle.x) + rect.size.x / 2 < wrap_m / 2 - 2000 and absf(middle.z) + rect.size.y / 2 < wrap_m / 2 - 2000, "World wraps: open sea between land %s and every edge" % rect)
	var minimap_script: Script = game.minimap.get_script()
	expect(minimap_script.sphere_point(home + Vector3(wrap_m, 0, 0), home).length() < 0.001 and absf(minimap_script.sphere_point(home + Vector3(0, 0, wrap_m / 4), home).y - PI / 2) < 0.001, "The globe turns once for one trip round the world")
	if not expect(game.controls.input_allowed(), "New game: helm accepts input; " + why_stuck(game)): return

	if not await berth_approach(game, brindle, "Brindle Quay berth"): return
	if not await dock(game, "Brindle Quay"): return
	if not await click(game, "Accept"): return
	if not await until(func() -> bool: return game.offers.active_job(OWNER).get("state") == "loaded", 60, "Container job loads"): return
	var job: Dictionary = game.offers.active_job(OWNER)
	expect(job.destination_port_id == "port_slatewater_works", "The job is for Slatewater Works")
	expect(game.ship.state.manifest.lines().size() == 1, "Containers are on board")
	print("M1_VOYAGE job %s: %d container(s), %.2f credits" % [job.id, job.quantity, job.reward_minor / 100.0])

	if not await undock(game, "Brindle Quay"): return
	# Straight ahead until the stern is past the quay, then turn for Slatewater.
	if not await sail_to(game, brindle.berth_anchor.global_position + Vector3(0, 0, 160), 40.0, 6.0, "Clear of Brindle Quay"): return
	await always_running(game)
	if not await sail_to(game, slatewater.berth_anchor.global_position + Vector3(-200, 0, -755), 80.0, 10.0, "Turn-in point south-west of Slatewater"): return
	await settle()
	expect(game.dock_button.is_visible_in_tree() and game.dock_button.disabled and game.dock_button.text == "Dock", "No berth in range: Dock is on screen and greyed out")
	expect(game.game_hud.knots.text.ends_with(" kn") and int(game.game_hud.knots.text) >= 10 and game.game_hud.slider.value > 0.1, "Under way the bar shows the speed and the throttle order (%s, slider %.2f)" % [game.game_hud.knots.text, game.game_hud.slider.value])
	if not await berth_approach(game, slatewater, "Slatewater Works berth"): return
	expect(game.port == slatewater, "The game switched to Slatewater Works on arrival")
	expect(game.ship.state.condition >= 1.0, "No collision damage on the way (condition %.2f)" % game.ship.state.condition)
	if not await dock(game, "Slatewater Works"): return
	if not await click(game, "Deliver"): return
	expect(game.reward_minor == job.reward_minor and job.reward_minor > 0, "Delivery pays the job into the wallet (wallet %d, job %d)" % [game.reward_minor, job.reward_minor])
	expect(game.ship.state.manifest.lines().is_empty(), "Delivered containers leave the ship")
	await settle()
	# M4: four ports, and the delivered job is replaced at Brindle Quay by a new one.
	var open_jobs: int = 0
	for row: Dictionary in game.offers.list_at("port_brindle_quay"):
		if row.state == "available" and row.id != job.id: open_jobs += 1
	expect(game.world_ports.size() == 4 and open_jobs == 3, "Four ports, and three open jobs at Brindle Quay again (%d ports, %d jobs)" % [game.world_ports.size(), open_jobs])
	expect(game.voyage_hud.money.is_visible_in_tree() and game.voyage_hud.money.text == "%.2f credits" % (job.reward_minor / 100.0), "The money is shown on the game HUD (%s)" % game.voyage_hud.money.text)
	expect(not game.game_hud.hint.visible, "The controls hint is gone after the first delivery")
	expect(game.game_hud.cards.is_visible_in_tree() and game.game_hud.cards.get_child_count() == game.jobs_list.item_count and game.jobs_list.item_count > 0 and not game.jobs_list.visible, "Docked with no job: one card per offer (%d cards)" % game.game_hud.cards.get_child_count())
	expect(not game.details.visible and not game.helm.gauge_display.visible, "Developer readouts are hidden in the game by default")

	# M2: fuel is paid for from the wallet.
	var fuel_before: float = game.ship.state.fuel_liters
	if not await click(game, game.refuel_button.text): return
	expect(game.ship.state.fuel_liters > fuel_before and game.spent_minor > 0 and game.reward_minor == job.reward_minor - game.spent_minor, "REFUEL adds fuel and takes money (fuel %.0f -> %.0f L, spent %d, wallet %d)" % [fuel_before, game.ship.state.fuel_liters, game.spent_minor, game.reward_minor])
	var wallet: int = game.reward_minor

	# Patch 2.0: leave through the Esc menu. Main Menu saves first.
	await press_escape()
	if not await click(game, "MAIN MENU"): return
	menu = await open_scene(MAIN_SCRIPT, "Home menu after the voyage")
	if menu == null: return
	expect(menu.menu.game_button.text == "CONTINUE", "With a save, the button says CONTINUE")
	if not await click(menu, "CONTINUE"): return
	game = await open_game("Continue")
	if game == null: return
	expect(game.reward_minor == wallet, "Continue restores the wallet after the fuel bill (wallet %d)" % game.reward_minor)
	expect(game.port == game.world_ports[1] and game.docking.state(1) == "docked", "Continue restores the ship docked at Slatewater Works")
	expect(game.offers.view(job.id).get("state") == "delivered" and game.offers.active_job(OWNER).is_empty(), "Continue keeps the job delivered, not repeatable")
	if not await undock(game, "Continue"): return
	# Patch 2.0 item 5: the slider is a control too. D end, then back to N.
	game.game_hud.slider.value = 1.0
	await settle()
	expect(is_equal_approx(game.ship.commanded_throttle, game.ship.definition.forward_throttle_limit), "Slider at D orders full ahead (order %.2f)" % game.ship.commanded_throttle)
	game.game_hud.slider.value = 0.0
	await settle()
	expect(game.ship.commanded_throttle == 0.0, "Slider at N orders neutral (order %.2f)" % game.ship.commanded_throttle)
	hold("ship_throttle_up", true)
	await until(func() -> bool: return game.ship.forward_speed() > 0.2, 15, "Continue: ship gains speed with the throttle key held; " + why_stuck(game))
	release_all()
	note("After Continue", game.ship)

	# M2: run dry and call the paid tow. The tank is emptied and the hull is holed by
	# code: burning a full tank or ramming a quay to zero by key press takes too long.
	game.ship.state.fuel_liters = 0.0
	if not await until(func() -> bool: return game.ship.velocity.length() < 0.05, 120, "Out of fuel: the ship drifts to a stop"): return
	if not await click(game, "Call a tow to port"): return
	var fee: int = mini(game.RECOVERY_FEE_MINOR, wallet)
	expect(game.ship.state.fuel_liters > 0.0 and game.reward_minor == wallet - fee, "The tow gives fuel and charges the fee (fuel %.0f L, wallet %d)" % [game.ship.state.fuel_liters, game.reward_minor])
	wallet -= fee
	game.ship.state.condition = 0.0
	if not await until(func() -> bool: return game.ship.state.condition > 0.0, 15, "A sunk ship is recovered; " + why_stuck(game)): return
	fee = mini(game.RECOVERY_FEE_MINOR, wallet)
	expect(not game.ship.simulation_paused and game.reward_minor == wallet - fee, "Recovery returns the ship and charges what the wallet can cover (wallet %d)" % game.reward_minor)

	# M3: buy a second ship, switch, take a bulk job, sell the first ship. The money
	# comes from bulk pay banked by code: earning it takes two more legs.
	release_all()
	await settle()
	game.banked_minor += 150000
	game.reward_minor += 150000
	wallet = game.reward_minor
	if not await berth_approach(game, game.port, "M3 berth, container ship"): return
	if not await dock(game, "M3, container ship"): return
	if not await click(game, "SHIPS"): return
	if not await click(game, game.ship_buttons["bulk"][0].text): return
	expect(game.fleet.has("bulk") and game.reward_minor == wallet - 120000, "Buying the bulk carrier takes its price (wallet %d)" % game.reward_minor)
	if not await click(game, "Switch to Bulk carrier"): return
	expect(game.ship_kind == "bulk" and game.docking.state(1) != "docked", "Switch puts the captain on the bulk carrier, off the quay")
	if not await berth_approach(game, game.port, "M3 berth, bulk carrier"): return
	if not await dock(game, "M3, bulk carrier"): return
	if not await click(game, "Accept"): return
	expect(game.bulk_active == "bulk_1_grain" and game.voyage_hud.heading.text == "DELIVER BULK CARGO", "A bulk job is accepted and shown on the HUD (%s)" % game.voyage_hud.heading.text)
	if not await click(game, "SHIPS"): return
	if not await click(game, game.ship_buttons["container"][1].text): return
	if not await click(game, "Confirm sale"): return
	expect(not game.fleet.has("container") and game.reward_minor == wallet - 120000 + 40000, "Selling the container ship pays half its price (wallet %d)" % game.reward_minor)
	wallet = game.reward_minor
	await press_escape()
	if not await click(game, "MAIN MENU"): return
	menu = await open_scene(MAIN_SCRIPT, "Home menu after the shipyard")
	if menu == null: return
	if not await click(menu, "CONTINUE"): return
	game = await open_game("Continue on the bulk carrier")
	if game == null: return
	expect(game.ship_kind == "bulk" and game.bulk_active == "bulk_1_grain" and game.fleet.size() == 1 and game.reward_minor == wallet, "Continue restores the ship, the fleet, the bulk job and the wallet (ship %s, wallet %d)" % [game.ship_kind, game.reward_minor])

	await press_escape()
	if not await click(game, "MAIN MENU"): return
	menu = await open_scene(MAIN_SCRIPT, "Home menu at the end")
	if menu == null: return
	# M2: Restart Progress erases the save after a confirmation.
	if not await click(menu, "RESTART PROGRESS"): return
	expect(menu.menu.restart_confirmation.visible, "Restart Progress asks for confirmation")
	menu.menu.restart_confirmation.hide()
	menu.menu.restart_confirmation.confirmed.emit()
	await settle()
	expect(menu.menu.game_button.text == "PLAY" and not menu.menu.restart_button.visible, "After Restart Progress the button says PLAY again")

func run() -> void:
	await process_frame
	wipe()
	set_meta("game_save_path", FOLDER + "/voyage.db")
	await fast_forward()
	if failures.is_empty(): await play()
	release_all()
	if current_scene != null:
		current_scene.queue_free()
		for frame: int in 3: await process_frame
	wipe()
	for failure: String in failures: push_error(failure)
	print("M1_VOYAGE_CHECK_PASS" if failures.is_empty() else "M1_VOYAGE_CHECK_FAILED")
	quit(0 if failures.is_empty() else 1)
