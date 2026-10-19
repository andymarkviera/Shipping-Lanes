extends Node3D
## Static asset inspection only. Sailing controls arrive in the handling steps.

func _ready() -> void:
	$Camera.look_at(Vector3(0, 2, 0), Vector3.UP)
