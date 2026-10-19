class_name VoyageDistance
extends RefCounted
## One canonical distance feeds both navigation and the payout fixture.
## Not a live route finder, authoritative job quote, or approved payout formula.
var _millimeters: int = 0
var _initialized: bool = false

func configure(world_meters: float, navigation_meters_per_world_meter: float = 1.0) -> Dictionary:
	if _initialized: return GameUnits.failure("Distance already fixed; create another measurement")
	if not is_finite(world_meters) or world_meters < 0.0 or not is_finite(navigation_meters_per_world_meter) or navigation_meters_per_world_meter <= 0.0:
		return GameUnits.failure("Invalid distance or scale")
	var amount: Dictionary = GameUnits.quantize(world_meters * navigation_meters_per_world_meter * 1000.0, "nearest")
	if not amount.ok: return amount
	_millimeters = amount.value
	_initialized = true
	return {"ok":true}

func navigation_nm() -> Dictionary:
	if not _initialized: return GameUnits.failure("Distance not configured")
	return {"ok":true, "value":float(_millimeters) / GameUnits.MM_PER_NM}

func payout_fixture(rate_minor_per_nm: Variant) -> Dictionary:
	if not _initialized or not GameUnits.valid_integer(rate_minor_per_nm): return GameUnits.failure("Missing distance or invalid rate")
	var rate: int = rate_minor_per_nm
	# Bound the integer intermediate before multiplication; never overflow first.
	if rate != 0:
		@warning_ignore("integer_division")
		var max_distance: int = GameUnits.MAX_INTEGER / rate
		if _millimeters > max_distance: return GameUnits.failure("Quote intermediate exceeds supported bound")
	@warning_ignore("integer_division")
	var payout: int = (_millimeters * rate) / GameUnits.MM_PER_NM
	return {"ok":true, "value":payout}
