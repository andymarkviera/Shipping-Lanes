class_name HandlingShip
extends CharacterBody3D
## Local, planar handling fixture. +Z is the bow; all values use SI units.
@export var definition: ShipDefinition = preload("res://features/catalog/records/starter_ship.tres")
var commanded_throttle: float = 0.0
var actual_throttle: float = 0.0
var distance_m: float = 0.0
var rudder: float = 0.0
var lateral_order: float = 0.0
var yaw_rate: float = 0.0

func maneuver(steering: float, thruster: float) -> void:
	rudder = clampf(steering, -1.0, 1.0) if is_finite(steering) else 0.0
	lateral_order = clampf(thruster, -1.0, 1.0) if is_finite(thruster) else 0.0

func forward_speed() -> float:
	return velocity.dot(basis.z)

func lateral_speed() -> float:
	return velocity.dot(basis.x)

func _ready() -> void:
	definition = definition.duplicate(true)
	if not definition.handling_error().is_empty():
		push_error(definition.handling_error())
		set_physics_process(false)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

func command_throttle(value: float) -> void:
	if is_finite(value):
		commanded_throttle = clampf(value, -definition.reverse_throttle_limit, definition.forward_throttle_limit)

func adjust_command(axis: float, delta: float) -> void:
	command_throttle(commanded_throttle + clampf(axis, -1.0, 1.0) * definition.command_rate_per_second * delta)

func zero_throttle() -> void:
	command_throttle(0.0)

func advance_engine(delta: float) -> void:
	# Opposite orders first ramp to neutral; opposite thrust starts next tick.
	var target: float = commanded_throttle
	if actual_throttle * target < 0.0:
		target = 0.0
	var rate: float = definition.engine_ramp_up_per_second if absf(target) > absf(actual_throttle) else definition.engine_ramp_down_per_second
	actual_throttle = move_toward(actual_throttle, target, rate * delta)

func advance_motion(delta: float) -> void:
	advance_engine(delta)
	var local_velocity: Vector3 = basis.inverse() * velocity
	var effectiveness: float = clampf(absf(local_velocity.z) / definition.rudder_full_effect_speed_mps, 0.0, 1.0)
	# D is starboard: negative yaw with +Z bow/+X port. Astern reverses yaw.
	var target_yaw: float = -rudder * signf(local_velocity.z) * effectiveness * deg_to_rad(definition.max_turn_rate_degrees)
	yaw_rate = move_toward(yaw_rate, target_yaw, deg_to_rad(definition.turn_acceleration_degrees) * delta)
	rotate_y(yaw_rate * delta)
	var acceleration: float = actual_throttle * (definition.forward_acceleration_mps2 if actual_throttle >= 0.0 else definition.reverse_acceleration_mps2)
	var drag: float = definition.linear_drag_per_second
	local_velocity.z = local_velocity.z * exp(-drag * delta) + acceleration / drag * (1.0 - exp(-drag * delta))
	var lateral_drag: float = definition.lateral_drag_per_second
	var thruster_effect: float = clampf(1.0 - absf(local_velocity.z) / definition.thruster_cutoff_speed_mps, 0.0, 1.0)
	var side_acceleration: float = -lateral_order * definition.thruster_acceleration_mps2 * thruster_effect
	local_velocity.x = local_velocity.x * exp(-lateral_drag * delta) + side_acceleration / lateral_drag * (1.0 - exp(-lateral_drag * delta))
	local_velocity.y = 0.0
	velocity = basis * local_velocity

func _physics_process(delta: float) -> void:
	advance_motion(delta)
	var previous: Vector3 = position
	move_and_slide()
	distance_m += position.distance_to(previous)
