extends Node3D
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func body() -> HandlingShip:
	var result: HandlingShip = HandlingShip.new()
	add_child(result)
	result.set_physics_process(false)
	return result

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var ship: HandlingShip = body()
	for hz: int in [30, 60, 144]:
		ship.state.fuel_liters = 1000
		for tick: int in range(10 * hz): ship.fuel.consume(1.0 / hz, 0.5, 0.5, false, false)
		check(absf(ship.state.fuel_liters - 997.15) < 0.000001, "Constant mixed output consumption at %d Hz" % hz)
	ship.state.fuel_liters = 1000
	ship.definition.fuel_reverse_multiplier = 2
	ship.fuel.consume(10, -0.5, 0, false, false)
	check(absf(ship.state.fuel_liters - 994.9) < 0.000001, "Configurable reverse multiplier")
	ship.definition.fuel_reverse_multiplier = 1
	ship.state.fuel_liters = 1000
	ship.fuel.consume(10, 0, 0, false, false)
	check(absf(ship.state.fuel_liters - 999.9) < 0.000001, "Neutral idle policy")
	var before: float = ship.state.fuel_liters
	ship.fuel.consume(100, 1, 1, true, false)
	ship.fuel.consume(100, 1, 1, false, true)
	check(ship.state.fuel_liters == before, "Paused and default docked consume nothing")
	ship.definition.fuel_burn_when_docked = true
	ship.fuel.consume(10, 1, 1, false, true)
	check(absf(before - ship.state.fuel_liters - 0.1) < 0.000001, "Docked optional idle only")
	for invalid: float in [-1.0, NAN, INF]:
		before = ship.state.fuel_liters
		ship.fuel.consume(invalid, 1, 1, false, false)
		check(ship.state.fuel_liters == before and ship.refuel(invalid) == 0, "Invalid time/refill rejected")
	ship.state.fuel_liters = 0.001
	var fraction: float = ship.fuel.consume(1, 1, 0, false, false)
	check(ship.state.fuel_liters == 0 and fraction > 0 and fraction < 0.002, "Final partial tick bounded")
	check(ship.fuel.consume(10, 1, 1, false, false) == 0 and ship.state.fuel_liters == 0, "No negative fuel or free output")
	ship.velocity = Vector3(0, 0, 2)
	ship.command_throttle(1)
	ship.actual_throttle = 1
	ship.maneuver(0, 1)
	ship.advance_motion(1.0 / 60)
	check(ship.actual_throttle == 0 and ship.commanded_throttle == 0 and ship.lateral_order == 0, "Empty clears powered orders")
	check(ship.velocity.z > 0 and ship.velocity.z < 2 and ship.velocity.x == 0, "Empty coasts without thruster power")
	ship.maneuver(1, 1)
	ship.command_throttle(1)
	check(ship.rudder == 1 and ship.lateral_order == 0 and ship.commanded_throttle == 0 and ship.helm_available(), "Empty retains rudder input but rejects powered orders")
	check(ship.refuel(100) == 0, "Cannot refuel moving ship")
	ship.velocity = Vector3.ZERO
	check(ship.refuel(100) == 100 and ship.state.fuel_liters == 100, "Stopped empty recovery")
	check(ship.refuel(2000) == 900 and ship.state.fuel_liters == 1000, "Refill clamps to capacity")
	check(ship.refuel(1) == 0, "Full tank cannot overfill")
	ship.command_throttle(1)
	ship.advance_motion(1)
	check(ship.velocity.z > 0 and ship.state.fuel_liters < 1000, "Refueled ship sails and consumes again")
	before = ship.state.fuel_liters
	var pose: Transform3D = ship.transform
	var motion: Vector3 = ship.velocity
	ship.simulation_paused = true
	ship._physics_process(1)
	check(ship.state.fuel_liters == before and ship.transform == pose and ship.velocity == motion, "Explicit simulation pause freezes motion and fuel")
	ship.simulation_paused = false
	ship.docked = true
	ship.definition.fuel_burn_when_docked = false
	ship.advance_motion(1)
	check(ship.actual_throttle == 0 and ship.state.fuel_liters == before, "Docked blocks propulsion")
	var invalid_definition: ShipDefinition = ship.definition.duplicate()
	for field: String in ["fuel_capacity_liters", "fuel_full_output_lps", "fuel_idle_lps", "fuel_reverse_multiplier", "fuel_thruster_lps"]:
		var original: float = invalid_definition.get(field)
		invalid_definition.set(field, -1.0)
		check(not invalid_definition.handling_error().is_empty(), "Reject invalid " + field)
		invalid_definition.set(field, original)
	ship.free()
	# Fixed physics replay under genuinely different rendering caps.
	var totals: Array[float] = []
	for cap: int in [30, 60, 144]:
		Engine.max_fps = cap
		ship = body()
		ship.command_throttle(1)
		for tick: int in range(120):
			await get_tree().physics_frame
			ship.advance_motion(1.0 / 60.0)
		totals.append(ship.state.fuel_liters)
		print("FUEL_SAMPLE cap=%d remaining=%.9f" % [cap, ship.state.fuel_liters])
		ship.free()
	check(absf(totals[0] - totals[1]) < 0.000001 and absf(totals[1] - totals[2]) < 0.000001, "Rendering rate does not affect fixed-tick fuel")
	Engine.max_fps = 0
	for path: String in ["res://features/handling/handling_test.tscn", "res://features/handling/heavy_lifter_test.tscn"]:
		var scene: Node = load(path).instantiate()
		add_child(scene)
		scene.ship.set_physics_process(false)
		scene.helm.set_physics_process(false)
		var panels: Array[Node] = scene.find_children("*", "FuelTestControls", true, false)
		check(panels.size() == 1, "Fuel tools visible in " + path)
		if panels.size() == 1:
			var row: Node = panels[0].get_child(0)
			row.get_child(0).pressed.emit()
			check(scene.ship.state.fuel_liters == 0 and scene.ship.actual_throttle == 0, "Empty button cuts propulsion")
			scene._process(0)
			check(scene.readout.text.contains("EMPTY"), "Empty status visible")
			row.get_child(1).pressed.emit()
			check(scene.ship.state.fuel_liters == scene.ship.definition.fuel_capacity_liters and scene.ship.helm_available(), "Test refill recovers both hulls")
			row.get_child(2).pressed.emit()
			check(scene.ship.simulation_paused, "Pause button")
			row.get_child(2).pressed.emit()
			row.get_child(3).pressed.emit()
			check(scene.ship.docked and not scene.ship.helm_available(), "Dock fixture blocks helm")
			row.get_child(3).pressed.emit()
			check(not scene.ship.docked and not scene.ship.simulation_paused, "Resume and undock")
		scene.free()
	print("FUEL_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
