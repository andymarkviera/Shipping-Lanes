class_name HandlingShip
extends CharacterBody3D
## Local, planar handling fixture. +Z is the bow; all values use SI units.
@export var definition: ShipDefinition = preload("res://features/catalog/records/starter_ship.tres")
var commanded_throttle: float = 0.0
var actual_throttle: float = 0.0
var distance_m: float = 0.0

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

func _physics_process(delta: float) -> void:
	advance_engine(delta)
	var acceleration: float = actual_throttle * (definition.forward_acceleration_mps2 if actual_throttle >= 0.0 else definition.reverse_acceleration_mps2)
	var drag: float = definition.linear_drag_per_second
	velocity.z = velocity.z * exp(-drag * delta) + acceleration / drag * (1.0 - exp(-drag * delta))
	velocity.x = 0.0
	velocity.y = 0.0
	var previous: Vector3 = position
	move_and_slide()
	distance_m += position.distance_to(previous)
