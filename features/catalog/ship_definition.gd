class_name ShipDefinition
extends ContentDefinition
@export_file("*.tscn") var scene_path: String = ""
@export var cargo_type_ids: Array[String] = []
@export var cargo_capacities: Dictionary = {}
## Independent metadata; zero means unspecified, never inferred from holds.
@export var dwt_tonnes: int = 0
## Stable hold IDs -> {capacity_grams, cargo_type_ids}; one commodity per hold.
@export var bulk_holds: Dictionary = {}
@export_enum("single_commodity_per_hold") var bulk_mixing_policy: String = "single_commodity_per_hold"
@export var gas_tanks: Dictionary = {}
@export_enum("single_commodity_per_tank") var gas_mixing_policy: String = "single_commodity_per_tank"
@export var container_layout: ContainerLayout
@export_file("*.tscn") var runtime_scene_path: String = ""
@export_group("Composition")
@export var hull_size_m: Vector3 = Vector3(13, 4, 64)
@export var camera_radius_m: float = 34.0
@export var camera_distance_m: float = 115.0
@export var wake_half_length_m: float = 30.0
@export var wake_half_width_m: float = 6.5
@export var cargo_anchor_m: Vector3 = Vector3(0, 2.65, 17)
@export var visual_bobbing: bool = true
@export var neutral_snap_zone: float = 0.04
@export var neutral_stop_speed_mps: float = 1.028889
@export var neutral_stop_deceleration_mps2: float = 0.35
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
@export_group("Prototype propulsion fuel (liters, seconds)")
@export var fuel_capacity_liters: float = 1000.0
@export var fuel_full_output_lps: float = 0.5
@export var fuel_idle_lps: float = 0.01
@export var fuel_reverse_multiplier: float = 1.0
@export var fuel_thruster_lps: float = 0.05
@export var fuel_burn_when_docked: bool = false

func bulk_capacity_error() -> String:
	if bulk_mixing_policy != "single_commodity_per_hold": return "Unsupported bulk mixing policy"
	if dwt_tonnes < 0 or dwt_tonnes > 1000000000: return "Invalid DWT rating"
	if bulk_holds.size() > 256: return "Too many bulk holds"
	if cargo_capacities.has("bulk_holds"): return "Bulk capacity must be authored per hold"
	for hold_id: Variant in bulk_holds:
		if not hold_id is String or hold_id.strip_edges().is_empty() or hold_id.length() > 128: return "Invalid bulk hold ID"
		var hold: Variant = bulk_holds[hold_id]
		if not hold is Dictionary or hold.size() != 2 or not hold.has("capacity_grams") or not hold.has("cargo_type_ids"): return "Invalid bulk hold"
		if not hold.capacity_grams is int or hold.capacity_grams <= 0 or hold.capacity_grams > 1000000000: return "Invalid bulk hold capacity"
		if not hold.cargo_type_ids is Array or hold.cargo_type_ids.is_empty(): return "Missing bulk hold compatibility"
		var seen: Array = []
		for cargo_id: Variant in hold.cargo_type_ids:
			if not cargo_id is String or not cargo_type_ids.has(cargo_id) or seen.has(cargo_id): return "Invalid bulk hold compatibility"
			seen.append(cargo_id)
	return ""

func handling_error() -> String:
	var gas_error: String = GasRules.ship_error(self)
	if not gas_error.is_empty(): return gas_error
	var bulk_error: String = bulk_capacity_error()
	if not bulk_error.is_empty(): return bulk_error
	for pool: Variant in cargo_capacities:
		if not pool is String or pool.strip_edges().is_empty(): return "Invalid cargo capacity pool"
		var capacity: Variant = cargo_capacities[pool]
		if not capacity is int or capacity < 0 or capacity > 1000000000: return "Invalid cargo capacity"
	for field: String in ["neutral_snap_zone", "neutral_stop_speed_mps", "neutral_stop_deceleration_mps2"]:
		if not is_finite(get(field)) or get(field) < 0: return "Invalid neutral assistance value: " + field
	if neutral_snap_zone >= minf(forward_throttle_limit, reverse_throttle_limit): return "Neutral zone exceeds throttle range"
	if not is_finite(fuel_capacity_liters) or fuel_capacity_liters <= 0:
		return "Invalid fuel capacity"
	for field: String in ["fuel_full_output_lps", "fuel_idle_lps", "fuel_reverse_multiplier", "fuel_thruster_lps"]:
		var value: float = get(field)
		if not is_finite(value) or value < 0: return "Invalid fuel rule: " + field
	if not hull_size_m.is_finite() or minf(hull_size_m.x, minf(hull_size_m.y, hull_size_m.z)) <= 0 or not cargo_anchor_m.is_finite():
		return "Invalid composition dimensions or anchor"
	for field: String in ["camera_radius_m", "camera_distance_m", "wake_half_length_m", "wake_half_width_m"]:
		var value: float = get(field)
		if not is_finite(value) or value <= 0: return "Invalid composition value: " + field
	for field: String in ["forward_acceleration_mps2", "reverse_acceleration_mps2", "linear_drag_per_second", "forward_throttle_limit", "reverse_throttle_limit", "command_rate_per_second", "engine_ramp_up_per_second", "engine_ramp_down_per_second", "max_turn_rate_degrees", "turn_acceleration_degrees", "rudder_full_effect_speed_mps", "thruster_acceleration_mps2", "lateral_drag_per_second", "thruster_cutoff_speed_mps"]:
		var value: float = get(field)
		if not is_finite(value) or value <= 0.0:
			return "Invalid positive handling value: " + field
	if forward_throttle_limit > 1.0 or reverse_throttle_limit > 1.0:
		return "Throttle limits must not exceed 1"
	return ""
