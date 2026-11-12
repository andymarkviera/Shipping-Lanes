extends SceneTree
## Scripted key-press check (REBUILD_PLAN.md fix-first item 1).
## Opens each sailing scene, holds the real throttle key through PlayerControls and
## ShipHelm, and expects the ship to gain speed. Saves go to an isolated folder.
## Run: godot --headless --path . --script res://tools/check_helm_keys.gd

const FOLDER: String = "user://helm_keys_check"
const HANDLING: String = "res://features/handling/handling_test.tscn"
const MIN_SPEED_MPS: float = 0.2
const MAX_TICKS: int = 180
var failures: Array[String] = []

func _initialize() -> void:
	run_checks.call_deferred()

func expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code as Key
	event.physical_keycode = code as Key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func wipe(name: String) -> String:
	var folder: String = FOLDER + "/" + name
	var dir: DirAccess = DirAccess.open(folder)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	return folder

func sail(label: String, path: String, properties: Dictionary = {}) -> void:
	var scene: Node = load(path).instantiate()
	for property: String in properties: scene.set(property, properties[property])
	root.add_child(scene)
	for tick: int in 30: await physics_frame
	# The oil fixture opens with its price panel up, which counts as a menu.
	# Close it the way its "Oil prices / close" button does.
	if scene.get("oil_scroll") != null: scene.oil_scroll.hide()
	for frame: int in 5: await process_frame
	var ship: HandlingShip = scene.ship
	var controls: PlayerControls = scene.controls
	expect(ship.helm_available(), label + ": ship is not paused or docked at start")
	expect(controls.input_allowed(), label + ": helm accepts input before the key press")
	# Fix-first item 4: the helm notice is silent while the helm works, and names the cause when it does not.
	var notice: Node = scene.helm.notice
	expect(notice.reason() == "", label + ": no helm notice while the helm works (got: %s)" % notice.reason())
	ship.docked = true
	expect(notice.reason().begins_with("DOCKED"), label + ": helm notice explains a docked ship")
	ship.docked = false
	ship.simulation_paused = true
	expect(notice.reason().begins_with("PAUSED"), label + ": helm notice explains a paused ship")
	ship.simulation_paused = false
	var code: int = controls.preferences.bindings["ship_throttle_up"]
	key(code, true)
	var ticks: int = 0
	while ticks < MAX_TICKS and ship.forward_speed() <= MIN_SPEED_MPS:
		await physics_frame
		ticks += 1
	print("HELM_KEYS %s order=%.2f speed=%.2f m/s ticks=%d" % [label, ship.commanded_throttle, ship.forward_speed(), ticks])
	expect(ship.commanded_throttle > 0.1, label + ": held throttle key raises the order")
	expect(ship.forward_speed() > MIN_SPEED_MPS, label + ": ship gains speed with the throttle key held")
	key(code, false)
	scene.free()
	await process_frame

func open_handling_with_save(folder: String) -> Node:
	set_meta("local_save_folder", folder)
	set_meta("local_save_requested", true)
	var scene: Node = load(HANDLING).instantiate()
	root.add_child(scene)
	scene.ship.set_physics_process(false)
	scene.set_process(false)
	return scene

func test_emptied_tank_is_not_saved() -> void:
	var folder: String = wipe("handling")
	var scene: Node = open_handling_with_save(folder)
	expect(scene.local_save != null and scene.local_save.usable, "Empty tank: isolated save opens")
	var before: float = scene.ship.state.fuel_liters
	expect(before > 0, "Empty tank: new save starts with fuel")
	scene.fuel_tools.get_child(0).get_child(0).pressed.emit()
	expect(scene.ship.state.fuel_liters == 0, "Empty tank: test button empties the tank")
	expect(scene.save_progress(), "Empty tank: save while test-emptied")
	expect(scene.ship.state.fuel_liters == 0, "Empty tank: tank stays empty for this visit")
	scene.free()
	await process_frame
	scene = open_handling_with_save(folder)
	expect(absf(scene.ship.state.fuel_liters - before) < 0.0011, "Empty tank: next session restores the fuel from before the test button")
	scene.free()
	await process_frame
	remove_meta("local_save_folder")
	wipe("handling")

func run_checks() -> void:
	await process_frame
	await sail("Boat Handling Test", HANDLING)
	await sail("Heavy-Lifter Test", "res://features/handling/heavy_lifter_test.tscn")
	await sail("Port Test", "res://features/ports/port_test.tscn", {"save_path": wipe("port") + "/voyage.db"})
	await sail("Bulk Port Test", "res://features/ports/bulk_port_test.tscn", {"voyage_path": wipe("bulk") + "/voyage.db"})
	await sail("Gas Port Test", "res://features/ports/gas_port_test.tscn", {"voyage_path": wipe("gas") + "/voyage.db"})
	await sail("Oil fixture", "res://features/ports/oil_port_test.tscn")
	await test_emptied_tank_is_not_saved()
	for name: String in ["port", "bulk", "gas"]: wipe(name)
	for failure: String in failures:
		push_error(failure)
	print("HELM_KEYS_CHECK_PASS" if failures.is_empty() else "HELM_KEYS_CHECK_FAILED")
	quit(0 if failures.is_empty() else 1)
