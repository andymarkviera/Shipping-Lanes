class_name ShipVisualMotion
extends Node3D
## Presentation only: parent body/collider and camera focus never inherit this.
var elapsed: float = 0.0
var quality: int = 1

func _process(delta: float) -> void:
	elapsed += delta
	var strength: float = 0.4 if quality == 0 else 1.0
	position.y = sin(elapsed * 0.65) * 0.14 * strength
	rotation.x = sin(elapsed * 0.55) * deg_to_rad(0.12) * strength
	rotation.z = sin(elapsed * 0.73 + 0.8) * deg_to_rad(0.22) * strength
