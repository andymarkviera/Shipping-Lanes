class_name GameUnits
extends RefCounted
## Explicit dimensions; these conversions never infer capacity or density.
const MAX_INTEGER: int = 9000000000000
const METERS_PER_NM: float = 1852.0
const MM_PER_NM: int = 1852000
# Petroleum barrel = 42 US gallons; US gallon = 231 cubic inches.
const ML_PER_PETROLEUM_BARREL: float = 158987.294928
const UNITS: Dictionary = {
	"meter": ["length",1.0], "nautical_mile": ["length",1852.0], "millimeter": ["length",0.001],
	"second": ["time",1.0], "millisecond": ["time",0.001], "minute": ["time",60.0], "hour": ["time",3600.0],
	"meter_per_second": ["speed",1.0], "knot": ["speed",1852.0 / 3600.0],
	"gram": ["mass",1.0], "kilogram": ["mass",1000.0], "metric_tonne": ["mass",1000000.0],
	"milliliter": ["volume",1.0], "liter": ["volume",1000.0], "cubic_meter": ["volume",1000000.0], "petroleum_barrel": ["volume",ML_PER_PETROLEUM_BARREL],
	"container_count": ["container_count",1.0], "container_slot": ["container_slot",1.0],
	"hold_count": ["hold_count",1.0], "heavy_item_count": ["heavy_item_count",1.0],
	"dwt_tonne": ["deadweight_rating",1.0]
}

static func failure(message: String) -> Dictionary:
	return {"ok":false, "error":message}

static func convert(value: float, from_unit: String, to_unit: String) -> Dictionary:
	if not is_finite(value) or value < 0.0:
		return failure("Quantity must be finite and nonnegative")
	if not UNITS.has(from_unit) or not UNITS.has(to_unit):
		return failure("Unknown unit")
	if UNITS[from_unit][0] != UNITS[to_unit][0]:
		return failure("Incompatible dimensions; no implicit capacity or density conversion")
	if from_unit.ends_with("_count") or from_unit == "container_slot":
		if value != floor(value): return failure("Counts and slots must be whole")
	var converted: float = value * float(UNITS[from_unit][1]) / float(UNITS[to_unit][1])
	if not is_finite(converted) or converted > MAX_INTEGER:
		return failure("Conversion exceeds supported bound")
	return {"ok":true, "value":converted, "unit":to_unit}

static func quantize(value: float, rounding: String) -> Dictionary:
	if not is_finite(value) or value < 0.0 or value > MAX_INTEGER:
		return failure("Quantity out of range")
	var rounded: float
	match rounding:
		"floor": rounded = floor(value)
		"ceil": rounded = ceil(value)
		"nearest": rounded = floor(value + 0.5)
		_: return failure("Explicit floor, ceil or nearest rounding required")
	if rounded > MAX_INTEGER: return failure("Rounded quantity exceeds supported bound")
	return {"ok":true, "value":int(rounded)}

static func valid_integer(value: Variant) -> bool:
	return value is int and value >= 0 and value <= MAX_INTEGER

static func add_minor(a: Variant, b: Variant) -> Dictionary:
	if not valid_integer(a) or not valid_integer(b): return failure("Expected bounded integer minor units")
	if a > MAX_INTEGER - b: return failure("Money overflow")
	return {"ok":true, "value":a + b}

static func parse_credits(text: String) -> Dictionary:
	# Decimal text to integer cents without floating-point rounding.
	var pattern: RegEx = RegEx.new()
	pattern.compile("^(0|[1-9][0-9]{0,10})(\\.[0-9]{1,2})?$")
	if pattern.search(text) == null: return failure("Use nonnegative decimal credits with at most two decimals")
	var parts: PackedStringArray = text.split(".")
	var minor: int = parts[0].to_int() * 100
	if parts.size() == 2: minor += (parts[1] + "0").left(2).to_int()
	if minor > MAX_INTEGER: return failure("Money exceeds supported bound")
	return {"ok":true, "value":minor}

static func format_minor(minor: Variant) -> Dictionary:
	if not valid_integer(minor): return failure("Expected bounded integer minor units")
	var amount: int = minor
	@warning_ignore("integer_division")
	var whole: int = amount / 100
	return {"ok":true, "value":"%d.%02d" % [whole, amount % 100]}

static func scaled_seconds(real_seconds: float, game_seconds_per_real_second: float) -> Dictionary:
	if not is_finite(game_seconds_per_real_second) or game_seconds_per_real_second <= 0.0:
		return failure("Time scale must be finite and positive")
	return GameUnits.convert(real_seconds * game_seconds_per_real_second, "second", "second")
