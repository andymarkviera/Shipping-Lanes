class_name CameraFocus
extends Node3D
## Attach anywhere on a target and pass this object to the rig. No ship paths.
@export var hull_radius: float = 32.0
var collision_body: CollisionObject3D
var associated_bodies: Array[CollisionObject3D] = []

func excluded_bodies() -> Array[RID]:
	var result: Array[RID] = []
	if is_instance_valid(collision_body): result.append(collision_body.get_rid())
	for body: CollisionObject3D in associated_bodies:
		if is_instance_valid(body): result.append(body.get_rid())
	return result
