class_name PropulsionFuel
extends RefCounted
## Runtime liters stay in ShipState. No rounding per tick; persistence comes later.
var state: ShipState
var definition: ShipDefinition
var last_burn_lps: float = 0.0

func _init(ship_state: ShipState, ship_definition: ShipDefinition) -> void:
	state = ship_state
	definition = ship_definition

func consume(delta: float, engine: float, thruster: float, paused: bool, docked: bool) -> float:
	last_burn_lps = 0.0
	if not is_finite(delta) or delta <= 0 or paused: return 0.0
	if state.fuel_liters <= 0: return 0.0
	if docked and not definition.fuel_burn_when_docked: return 0.0
	var rate: float = definition.fuel_idle_lps
	if not docked:
		rate += absf(engine) * definition.fuel_full_output_lps * (definition.fuel_reverse_multiplier if engine < 0 else 1.0)
		rate += absf(thruster) * definition.fuel_thruster_lps
	var requested: float = rate * delta
	var used: float = minf(state.fuel_liters, requested)
	state.fuel_liters = maxf(0.0, state.fuel_liters - used)
	last_burn_lps = used / delta
	return used / requested if requested > 0 else 1.0

func add_liters(amount: float) -> float:
	if not is_finite(amount) or amount <= 0: return 0.0
	var accepted: float = minf(amount, maxf(0, definition.fuel_capacity_liters - state.fuel_liters))
	state.fuel_liters += accepted
	return accepted
