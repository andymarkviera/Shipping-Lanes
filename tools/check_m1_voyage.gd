extends SceneTree
## M1 scripted playthrough (REBUILD_PLAN.md section 3): one real voyage.
## Opens the home menu, clicks PLAY, sails from the Brindle Quay spawn to its berth,
## takes a container job, sails to Slatewater Works, delivers, checks the wallet,
## leaves through "Main menu", clicks CONTINUE and checks the wallet came back.
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
	if not expect(game.controls.input_allowed(), "New game: helm accepts input; " + why_stuck(game)): return

	if not await berth_approach(game, brindle, "Brindle Quay berth"): return
	if not await dock(game, "Brindle Quay"): return
	if not await click(game, "CARGO"): return
	if not await click(game, "Accept selected job"): return
	if not await until(func() -> bool: return game.offers.active_job(OWNER).get("state") == "loaded", 60, "Container job loads"): return
	var job: Dictionary = game.offers.active_job(OWNER)
	expect(job.destination_port_id == "port_slatewater_works", "The job is for Slatewater Works")
	expect(game.ship.state.manifest.lines().size() == 1, "Containers are on board")
	print("M1_VOYAGE job %s: %d container(s), %.2f credits" % [job.id, job.quantity, job.reward_minor / 100.0])

	if not await undock(game, "Brindle Quay"): return
	# Straight ahead until the stern is past the quay, then turn for Slatewater.
	if not await sail_to(game, brindle.berth_anchor.global_position + Vector3(0, 0, 160), 40.0, 6.0, "Clear of Brindle Quay"): return
	if not await sail_to(game, slatewater.berth_anchor.global_position + Vector3(-200, 0, -755), 80.0, 10.0, "Turn-in point south-west of Slatewater"): return
	if not await berth_approach(game, slatewater, "Slatewater Works berth"): return
	expect(game.port == slatewater, "The game switched to Slatewater Works on arrival")
	expect(game.ship.state.condition >= 1.0, "No collision damage on the way (condition %.2f)" % game.ship.state.condition)
	if not await dock(game, "Slatewater Works"): return
	if not await click(game, "CARGO"): return
	if not await click(game, "Deliver cargo at this port"): return
	expect(game.reward_minor == job.reward_minor and job.reward_minor > 0, "Delivery pays the job into the wallet (wallet %d, job %d)" % [game.reward_minor, job.reward_minor])
	expect(game.ship.state.manifest.lines().is_empty(), "Delivered containers leave the ship")
	await settle()
	expect(game.voyage_hud.is_visible_in_tree() and ("Money %.2f credits" % (job.reward_minor / 100.0)) in game.voyage_hud.instruments.text, "The money is shown on the game HUD (%s)" % game.voyage_hud.instruments.text.replace("\n", " | "))
	expect(not game.details.visible and not game.helm.gauge_display.visible, "Developer readouts are hidden in the game by default")

	if not await click(game, "Main menu"): return
	menu = await open_scene(MAIN_SCRIPT, "Home menu after the voyage")
	if menu == null: return
	expect(menu.menu.game_button.text == "CONTINUE", "With a save, the button says CONTINUE")
	if not await click(menu, "CONTINUE"): return
	game = await open_game("Continue")
	if game == null: return
	expect(game.reward_minor == job.reward_minor, "Continue restores the wallet (wallet %d)" % game.reward_minor)
	expect(game.port == game.world_ports[1] and game.docking.state(1) == "docked", "Continue restores the ship docked at Slatewater Works")
	expect(game.offers.view(job.id).get("state") == "delivered" and game.offers.active_job(OWNER).is_empty(), "Continue keeps the job delivered, not repeatable")
	if not await undock(game, "Continue"): return
	hold("ship_throttle_up", true)
	await until(func() -> bool: return game.ship.forward_speed() > 0.2, 15, "Continue: ship gains speed with the throttle key held; " + why_stuck(game))
	release_all()
	note("After Continue", game.ship)
	if not await click(game, "Main menu"): return
	await open_scene(MAIN_SCRIPT, "Home menu at the end")

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
