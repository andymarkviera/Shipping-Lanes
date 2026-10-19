class_name HandlingShip
extends CharacterBody3D
## Local, planar handling fixture. +Z is the bow; all values use SI units.
const FORWARD_ACCEL: float = 0.8
const REVERSE_ACCEL: float = 0.5
const DRAG: float = 0.08
var thrust: float = 0.0
var distance_m: float = 0.0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

func _physics_process(delta: float) -> void:
	var acceleration: float = clampf(thrust, -1.0, 1.0) * (FORWARD_ACCEL if thrust >= 0.0 else REVERSE_ACCEL)
	# Exact velocity solution for constant thrust and linear drag over one tick.
	velocity.z = velocity.z * exp(-DRAG * delta) + acceleration / DRAG * (1.0 - exp(-DRAG * delta))
	velocity.x = 0.0
	velocity.y = 0.0
	var previous: Vector3 = position
	move_and_slide()
	distance_m += position.distance_to(previous)
