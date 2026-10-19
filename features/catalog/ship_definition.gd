class_name ShipDefinition
extends ContentDefinition
@export_file("*.tscn") var scene_path: String = ""
@export var cargo_type_ids: Array[String] = []
@export_group("Prototype handling (SI units)")
@export var forward_acceleration_mps2: float = 0.8
@export var reverse_acceleration_mps2: float = 0.5
@export var linear_drag_per_second: float = 0.08
@export var forward_throttle_limit: float = 1.0
@export var reverse_throttle_limit: float = 0.6
@export var command_rate_per_second: float = 0.5
@export var engine_ramp_up_per_second: float = 0.5
@export var engine_ramp_down_per_second: float = 1.0

@export var max_turn_rate_degrees: float = 3.0
@export var turn_acceleration_degrees: float = 2.0
@export var rudder_full_effect_speed_mps: float = 4.0
@export var thruster_acceleration_mps2: float = 0.4
@export var lateral_drag_per_second: float = 0.4
@export var thruster_cutoff_speed_mps: float = 4.0

func handling_error() -> String:
	for field: String in ["forward_acceleration_mps2", "reverse_acceleration_mps2", "linear_drag_per_second", "forward_throttle_limit", "reverse_throttle_limit", "command_rate_per_second", "engine_ramp_up_per_second", "engine_ramp_down_per_second", "max_turn_rate_degrees", "turn_acceleration_degrees", "rudder_full_effect_speed_mps", "thruster_acceleration_mps2", "lateral_drag_per_second", "thruster_cutoff_speed_mps"]:
		var value: float = get(field)
		if not is_finite(value) or value <= 0.0:
			return "Invalid positive handling value: " + field
	if forward_throttle_limit > 1.0 or reverse_throttle_limit > 1.0:
		return "Throttle limits must not exceed 1"
	return ""
