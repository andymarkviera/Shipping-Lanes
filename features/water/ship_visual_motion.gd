class_name ShipVisualMotion
extends Node3D
## Presentation only: parent body/collider and camera focus never inherit this.
var elapsed: float = 0.0
var quality: int = 1
## Normalized visual load until authoritative cargo mass is available.
## This prototype offset is not a real ship draft or a navigation restriction.
const FULL_LOAD_SINK_M: float = 0.85
var load_fraction: float = 0.0
var load_sink_m: float = 0.0

func set_visual_load(fraction: float) -> void:
	if is_finite(fraction):
		load_fraction = clampf(fraction, 0.0, 1.0)

func _process(delta: float) -> void:
	elapsed += delta
	load_sink_m = move_toward(load_sink_m, load_fraction * FULL_LOAD_SINK_M, maxf(delta, 0.0) * 0.3)
	var strength: float = 0.4 if quality == 0 else 1.0
	position.y = -load_sink_m + sin(elapsed * 0.65) * 0.14 * strength
	rotation.x = sin(elapsed * 0.55) * deg_to_rad(0.12) * strength
	rotation.z = sin(elapsed * 0.73 + 0.8) * deg_to_rad(0.22) * strength
