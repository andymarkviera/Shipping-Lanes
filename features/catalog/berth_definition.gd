class_name BerthDefinition
extends ContentDefinition
@export var port_id: String = ""
@export var cargo_type_ids: Array[String] = []

@export var position_m: Vector3 = Vector3.ZERO
@export var heading_degrees: float = 0.0
@export var envelope_m: Vector3 = Vector3(24, 20, 100)
@export var service_ids: Array[String] = []

@export var max_docking_speed_mps: float = 0.15
@export var max_heading_error_degrees: float = 10.0
@export var clearance_margin_m: float = 1.0

func eligibility_error() -> String:
	if not envelope_m.is_finite() or minf(envelope_m.x, minf(envelope_m.y, envelope_m.z)) <= 0: return "Invalid berth envelope"
	if not position_m.is_finite() or not is_finite(heading_degrees): return "Invalid berth pose"
	if not is_finite(max_docking_speed_mps) or max_docking_speed_mps < 0: return "Invalid docking speed"
	if not is_finite(max_heading_error_degrees) or max_heading_error_degrees < 0 or max_heading_error_degrees > 90: return "Invalid heading tolerance"
	if not is_finite(clearance_margin_m) or clearance_margin_m < 0: return "Invalid clearance margin"
	return ""
