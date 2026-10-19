class_name TestSession
extends Node
## Disposable flow fixture, not a world clock or network implementation.
var hosted: bool = true
var locally_paused: bool = false
var elapsed: float = 0.0

func _process(delta: float) -> void:
	if hosted or not locally_paused:
		elapsed += delta

func snapshot() -> Dictionary:
	return {"hosted": hosted, "elapsed": elapsed}
