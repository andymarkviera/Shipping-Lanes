class_name ShipHelm
extends Node
signal menu_requested
var throttle_display = preload("res://features/feedback/throttle_indicator.gd").new()
var gauge_display = preload("res://features/feedback/vessel_gauge_hud.gd").new()
var ship: HandlingShip
var controls: PlayerControls
var feedback: HandlingFeedback

func configure(body: HandlingShip, input: PlayerControls, sound: HandlingFeedback) -> void:
	ship = body
	if throttle_display.get_parent() == null: add_child(throttle_display)
	throttle_display.ship = ship
	if gauge_display.get_parent() == null: add_child(gauge_display)
	gauge_display.ship = ship
	controls = input
	feedback = sound
	process_physics_priority = -10
	process_priority = -10
	controls.command_requested.connect(command)
	feedback.update(ship, false, 0)

func command(action: StringName) -> void:
	if action == &"ship_throttle_zero": ship.zero_throttle()
	if action == &"horn": feedback.sound_horn(controls.input_allowed())
	if action == &"pause": menu_requested.emit()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(ship) or not is_instance_valid(controls): return
	var allowed: bool = controls.input_allowed() and ship.helm_available()
	if not allowed:
		ship.zero_throttle()
		ship.maneuver(0, 0)
		return
	ship.maneuver(controls.steering_axis(), controls.action_strength("ship_thruster_right") - controls.action_strength("ship_thruster_left"))
	if controls.action_strength("ship_throttle_zero") > 0:
		ship.zero_throttle()
	else:
		ship.adjust_command(controls.action_strength("ship_throttle_up") - controls.action_strength("ship_throttle_down"), delta)

func _process(delta: float) -> void:
	if is_instance_valid(ship) and is_instance_valid(controls):
		feedback.update(ship, controls.input_allowed() and not ship.simulation_paused, delta)

func _exit_tree() -> void:
	if is_instance_valid(controls) and controls.command_requested.is_connected(command):
		controls.command_requested.disconnect(command)
