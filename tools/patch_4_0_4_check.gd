extends SceneTree
## Patch 4.0.4 headless checks (issue #228), in the real game scene with an
## isolated save. First the scene-free parts (patch_4_0_4_logic.gd, also run
## by check_catalog.gd), then:
## - item 2, the plane HUD: flying, the helm bar shows the instrument row
##   (THR gauge 0-100%, IAS, ALT with AGL, V/S, HDG, FUEL, the GEAR light)
##   and it follows the plane; on a boat the row is hidden;
## - item 3, a plane job end to end: dock, switch to a plane, take a job
##   from the airport's board (the card's Accept), fly it with the keys
##   (W / S / A / D / Space pressed through the input map, the throttle
##   lever as Shift / Ctrl or the slider move it, G for the gear), land and
##   stop at the destination, press Deliver; the job is paid (wallet, bank,
##   XP) and the plane can switch back to the boat.
## The flight runs the game's own physics at 60 Hz steps; to keep the check
## short, the engine runs several physics steps per frame (Engine.time_scale
## with the tick rate raised to match, so every step is still 1/60 s).
## Run: godot --headless --path . --script res://tools/patch_4_0_4_check.gd
const Logic = preload("res://tools/patch_4_0_4_logic.gd")
const Autopilot = preload("res://tools/flight_autopilot.gd")
const Airports = preload("res://features/planes/airports.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const FOLDER: String = "user://patch_4_0_4_check"
const KIND: String = "plane_turboprop"
const SPEED_UP: int = 8
const KEYS: Array[StringName] = [&"ship_throttle_up", &"ship_throttle_down", &"ship_steer_left", &"ship_steer_right", &"ship_brake"]
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("PATCH 4.0.4 FAILED: " + label)
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
		print("PATCH 4.0.4 FAILED: " + label)
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = await wait_for(func(scene: Node) -> bool: return scene.get("persistence") != null and is_instance_valid(scene.persistence) and scene.persistence.ready_to_save)
	if not expect(game != null and is_instance_valid(game.get("aviation")), "the game opened with its planes"): return finish()
	await settle()
	await plane_job(game)
	for key: StringName in KEYS: Input.action_release(key)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	game.leave()
	await wait_for(func(scene: Node) -> bool: return scene.name == "Main")
	finish()

## Docks the starting ship at its port (as patch_4_0_3_check does).
func dock_here(game: Node) -> bool:
	if game.docking.state(game.owner_id) == "docked": return true
	game.ship.global_transform = game.port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
	game.ship.velocity = Vector3.ZERO
	for frame: int in 2: await physics_frame
	var asked: Dictionary = game.docking.request_dock(game.owner_id, game.service_id(), game.cargo_id())
	if not asked.ok: return false
	for frame: int in 400:
		await physics_frame
		if game.docking.state(game.owner_id) == "docked": return true
	return false

## The keys this frame: the pilot's W / S / A / D / Space through the input
## map (PlayerControls reads them), its lever as Shift / Ctrl set it, G.
func press(game: Node, pilot: RefCounted, out: Dictionary) -> void:
	var controls: PlayerControls = game.controls
	controls.ship_context_active = true
	controls.window_focused = true
	controls.wait_for_release = false
	var wanted: Dictionary = {&"ship_throttle_up": float(out.pitch) > 0.0, &"ship_throttle_down": float(out.pitch) < 0.0,
		&"ship_steer_left": float(out.roll) < 0.0, &"ship_steer_right": float(out.roll) > 0.0, &"ship_brake": float(out.get("brake", 0.0)) > 0.0}
	for key: StringName in KEYS:
		if wanted[key] and not Input.is_action_pressed(key): Input.action_press(key)
		elif not wanted[key] and Input.is_action_pressed(key): Input.action_release(key)
	game.aviation.lever = pilot.lever
	if float(out.get("gear", -1.0)) > 0.5 and not game.aviation.model.gear_down and not game.aviation.model.on_ground: game.aviation.toggle_gear()

func plane_job(game: Node) -> void:
	var air: Node = game.aviation
	var hud: Control = game.game_hud
	if not expect(await dock_here(game), "the ship docks at its first port"): return
	expect(not hud.flight.visible, "on a boat the plane instruments are hidden")
	air.unlock_all()
	air.plane_kind = KIND
	if not expect(air.switch_to_plane() and game.flying(), "the captain switches to the %s at the dock" % KIND): return
	await settle()
	# Item 2: the instrument row.
	expect(hud.flight.is_visible_in_tree(), "flying, the helm bar shows the plane instruments")
	for key: String in hud.FLIGHT_CELLS:
		expect(hud.flight_values.has(key) and hud.flight_captions.has(key), "the instrument row has %s" % key)
	expect(hud.knots.text.ends_with(" kn"), "the big figure is the airspeed (%s)" % hud.knots.text)
	expect(hud.flight_values.GEAR.text == "DOWN" and hud.gear_state == 1, "on the runway the gear light is green, DOWN")
	expect(hud.flight_values.THR.text == "0%", "the throttle gauge reads 0%% at idle (%s)" % hud.flight_values.THR.text)
	expect(hud.flight_values.FUEL.text == "100%", "the fuel reads full (%s)" % hud.flight_values.FUEL.text)
	expect(hud.flight_values.HDG.text.contains("°"), "the heading is in degrees (%s)" % hud.flight_values.HDG.text)
	air.lever = 0.5
	await settle()
	expect(hud.flight_values.THR.text == "50%" and is_equal_approx(hud.shown_throttle, 0.5), "the gauge follows the lever (%s)" % hud.flight_values.THR.text)
	air.lever = 0.0
	# Item 3: the job, from the board's cards.
	var here: int = air.stopped_at()
	if not expect(here >= 0 and air.card.visible, "stopped at the airport, its card shows"): return
	var board: Array[Dictionary] = Jobs.board(here, air.plane_entry())
	if not expect(not board.is_empty(), "the airport offers plane jobs"): return
	var pick: int = 0
	for index: int in board.size():
		if Jobs.leg_km(here, int(board[index].destination)) < Jobs.leg_km(here, int(board[pick].destination)): pick = index
	await settle()
	var cards: Array = air.card_jobs.get_children().filter(func(item: Node) -> bool: return item is PanelContainer and not item.is_queued_for_deletion())
	if not expect(cards.size() == board.size(), "one card per job (%d of %d)" % [cards.size(), board.size()]): return
	var take: Button = null
	for item: Node in cards[pick].find_children("*", "Button", true, false):
		if (item as Button).text == "Accept": take = item
	if not expect(take != null, "the card has Accept"): return
	take.pressed.emit()
	await settle()
	var job: Dictionary = board[pick]
	if not expect(air.job_id == str(job.id), "Accept takes the job (%s)" % air.job_id): return
	var destination: int = int(job.destination)
	expect(not air.boat_reason().is_empty(), "with a job aboard the plane cannot switch to the boat")
	var wallet: int = int(game.reward_minor)
	var banked: int = int(game.banked_minor)
	var xp: int = int(game.xp)
	# Fly it, with the keys.
	Engine.physics_ticks_per_second = 60 * SPEED_UP
	Engine.max_physics_steps_per_frame = SPEED_UP * 2
	Engine.time_scale = float(SPEED_UP)
	var pilot: RefCounted = Autopilot.new(destination)
	var seconds: float = 0.0
	var climbed: bool = false
	var gear_up_seen: bool = false
	var vs_seen: bool = false
	var low_fines: int = int(air.fines)
	var started: int = Time.get_ticks_msec()
	while seconds < 1500.0 and Time.get_ticks_msec() - started < 240000:
		var m: RefCounted = air.model
		if m == null or air.crashes > 0: break
		press(game, pilot, pilot.inputs(m))
		await physics_frame
		seconds += 1.0 / 60.0
		if not m.on_ground and m.agl_m > 100.0 and not climbed:
			climbed = true
			await process_frame
			expect(hud.flight.is_visible_in_tree() and int(hud.flight_values.IAS.text) > 0 and not hud.flight_values.ALT.text.begins_with("0 "), "in the air the HUD shows airspeed and altitude (%s, %s)" % [hud.flight_values.IAS.text, hud.flight_values.ALT.text])
		if climbed and not vs_seen and absf(m.velocity.y) > 2.0:
			await process_frame
			vs_seen = hud.flight_values["V/S"].text != "0.0"
		if not gear_up_seen and not m.on_ground and not m.gear_down:
			await process_frame
			gear_up_seen = hud.flight_values.GEAR.text == "UP" and hud.gear_state != 1
		if pilot.phase == "rollout" and m.airspeed() < 0.5 and air.stopped_at() == destination: break
	for key: StringName in KEYS: Input.action_release(key)
	air.lever = 0.0
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	print("PATCH_4_0_4 flight: %.0f s simulated in %.1f s, phase %s, crashes %d, fines %d" % [seconds, (Time.get_ticks_msec() - started) / 1000.0, pilot.phase, air.crashes, air.fines - low_fines])
	expect(air.crashes == 0, "the flight does not crash (%s)" % (air.model.crash_reason if air.model != null else ""))
	expect(climbed, "the plane took off and climbed")
	expect(vs_seen, "the V/S reads the climb or sink")
	expect(gear_up_seen, "the gear came up after take-off and the light went red, UP")
	await settle()
	if not expect(air.stopped_at() == destination, "the plane landed and stopped at %s (at %d)" % [Airports.all()[destination].name, air.stopped_at()]): return
	expect(air.model.gear_down and hud.flight_values.GEAR.text == "DOWN", "landed with the gear down, the light green")
	expect(air.model.fuel_l < float(Planes.PLANES[KIND].fuel_l), "the flight burned fuel")
	air.refresh_ui()
	await settle()
	expect(air.card.visible and air.card_buttons.deliver.visible and not air.card_buttons.deliver.disabled, "at the destination the airport card offers Deliver")
	air.card_buttons.deliver.pressed.emit()
	await settle()
	var pay: int = int(job.reward_minor)
	expect(air.job_id.is_empty(), "Deliver hands the job over")
	expect(int(game.reward_minor) >= wallet + pay - int(Planes.repair_minor(KIND, 100)) and int(game.banked_minor) == banked + pay, "the job is paid: banked +%d (wallet %d -> %d)" % [pay, wallet, int(game.reward_minor)])
	expect(int(game.xp) > xp, "and earns XP (%d -> %d)" % [xp, int(game.xp)])
	expect(air.boat_reason().is_empty() and air.switch_to_boat() and not game.flying(), "after delivering, the captain switches back to the boat")
	await settle()
	expect(not hud.flight.visible, "and the plane instruments are hidden again")

func finish() -> void:
	if failures.is_empty(): print("PATCH_4_0_4_CHECK_PASS (%d checks)" % checks)
	else: print("PATCH_4_0_4_CHECK_FAIL (%d of %d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
