extends Node
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	# Muted inside this verification process only; player settings stay untouched.
	AudioServer.set_bus_mute(0, true)
	var ship: HandlingShip = HandlingShip.new()
	add_child(ship)
	ship.set_physics_process(false)
	ship.velocity = Vector3(0, 0, 1852.0 / 3600.0)
	var state: Dictionary = HandlingFeedback.instruments(ship)
	check(is_equal_approx(state.speed_knots, 1.0), "Speed uses knots")
	check(state.heading_degrees == 0.0 and state.direction == "AHEAD", "Local north and ahead read correctly")
	ship.rotation.y = -PI / 2
	ship.velocity = -ship.basis.z
	state = HandlingFeedback.instruments(ship)
	check(is_equal_approx(state.heading_degrees, 90.0) and state.direction == "ASTERN", "Starboard heading and reverse direction")
	check(state.fuel_liters == ship.state.fuel_liters, "Fuel reflects instance state")
	ship.velocity = Vector3.ZERO
	ship.command_throttle(0.8)
	ship.advance_engine(0.2)
	state = HandlingFeedback.instruments(ship)
	check(state.command > state.engine and state.direction == "STOPPED", "Order, engine and motion remain distinct")
	var feedback: HandlingFeedback = HandlingFeedback.new()
	add_child(feedback)
	var before: Transform3D = ship.transform
	var velocity_before: Vector3 = ship.velocity
	feedback.update(ship, true, 0.5)
	check(feedback.engine.playing and feedback.engine.pitch_scale > 0.8, "Engine output drives sound")
	ship.maneuver(0, 1)
	feedback.update(ship, true, 0.5)
	check(feedback.thruster.playing, "Low-speed lateral power drives thruster sound")
	ship.velocity = ship.basis.z * 8.0
	feedback.update(ship, true, 2.0)
	check(not feedback.thruster.playing, "Thruster sound fades above cutoff")
	ship.velocity = velocity_before
	feedback.sound_horn(false)
	check(not feedback.horn.playing, "Blocked horn input stays silent")
	feedback.sound_horn(true)
	check(feedback.horn.playing, "Horn starts on allowed command")
	feedback.update(ship, false, 0.1)
	check(not feedback.engine.playing and not feedback.thruster.playing and not feedback.horn.playing, "Blocked input stops all feedback audio")
	check(ship.transform == before and ship.velocity == velocity_before, "Feedback does not write ship motion")
	for kind: String in ["engine", "thruster", "horn"]:
		var sound: AudioStreamWAV = HandlingFeedback.tone(kind)
		var peak: int = 0
		for index: int in range(sound.data.size() / 2): peak = maxi(peak, absi(sound.data.decode_s16(index * 2)))
		check(peak > 1000 and peak < 32767, kind + " PCM is non-silent and unclipped")
		check(sound.loop_mode == (AudioStreamWAV.LOOP_DISABLED if kind == "horn" else AudioStreamWAV.LOOP_FORWARD), kind + " loop policy")
		if kind == "horn": check(sound.data.decode_s16(0) == 0 and absi(sound.data.decode_s16(sound.data.size() - 2)) < 20, "Horn has soft envelope endpoints")
	measure_baseline()
	var scene: Node3D = (load("res://features/handling/handling_test.tscn") as PackedScene).instantiate()
	add_child(scene)
	AudioServer.set_bus_mute(0, true)
	await get_tree().create_timer(0.1).timeout
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = scene.controls.preferences.bindings["horn"]
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	check(scene.feedback.horn.playing, "Mapped H action reaches horn")
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().create_timer(1.4).timeout
	check(not scene.feedback.horn.playing, "Horn finishes without a held loop")
	check(scene.readout.text.contains("Heading") and scene.readout.text.contains("Fuel "), "Visible heading/fuel instruments")
	remove_child(scene)
	scene.queue_free()
	print("FEEDBACK_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)

func measure_baseline() -> void:
	var subject: HandlingShip = HandlingShip.new()
	add_child(subject)
	subject.set_physics_process(false)
	var acceleration_ticks: int = 0
	var acceleration_distance: float = 0.0
	while subject.forward_speed() < 4.0 and acceleration_ticks < 3600:
		subject.adjust_command(1, 1.0 / 60.0)
		subject.advance_motion(1.0 / 60.0)
		acceleration_distance += subject.forward_speed() / 60.0
		acceleration_ticks += 1
	check(acceleration_ticks < 3600, "Baseline reaches maneuvering speed")
	var brake_ticks: int = 0
	var brake_distance: float = 0.0
	while subject.forward_speed() > 0.0 and brake_ticks < 3600:
		subject.adjust_command(-1, 1.0 / 60.0)
		subject.advance_motion(1.0 / 60.0)
		brake_distance += maxf(subject.forward_speed(), 0.0) / 60.0
		brake_ticks += 1
	check(brake_ticks < 3600, "Baseline reverse order stops ahead motion")
	print("HANDLING_BASELINE hold-W to 4m/s: %.2fs %.2fm; hold-S to stop: %.2fs %.2fm" % [acceleration_ticks / 60.0, acceleration_distance, brake_ticks / 60.0, brake_distance])
	remove_child(subject)
	subject.free()
