extends Node
const Units = preload("res://features/units/game_units.gd")
const Distance = preload("res://features/units/voyage_distance.gd")
var count: int = 0
var failures: int = 0
func check(condition: bool, message: String) -> void:
	count += 1
	if not condition:
		failures += 1
		push_error(message)
func example(amount: float, source: String, target: String, expected: float) -> void:
	var result: Dictionary = Units.convert(amount, source, target)
	check(result.ok and abs(result.value - expected) < 0.0000001, source + " -> " + target)
func _ready() -> void:
	example(1852.0,"meter","nautical_mile",1.0)
	example(2.0,"nautical_mile","meter",3704.0)
	example(1.0,"knot","meter_per_second",1852.0 / 3600.0)
	example(10.0 * 1852.0 / 3600.0,"meter_per_second","knot",10.0)
	example(1.0,"hour","second",3600.0)
	example(1.25,"second","millisecond",1250.0)
	example(1.0,"metric_tonne","gram",1000000.0)
	example(1.0,"cubic_meter","milliliter",1000000.0)
	example(1.0,"petroleum_barrel","liter",158.987294928)
	example(158.987294928,"liter","petroleum_barrel",1.0)
	example(2.0,"heavy_item_count","heavy_item_count",2.0)
	for pair: Array in [["hold_count","metric_tonne"],["dwt_tonne","metric_tonne"],["container_slot","container_count"],["cubic_meter","gram"],["gram","milliliter"]]:
		check(not Units.convert(1.0,pair[0],pair[1]).ok,"No implicit " + pair[0] + " conversion")
	check(not Units.convert(1.5,"container_count","container_count").ok,"Whole counts only")
	check(not Units.convert(INF,"meter","nautical_mile").ok,"Infinity rejected")
	check(not Units.convert(NAN,"meter","meter").ok,"NaN rejected")
	check(not Units.convert(-1,"second","millisecond").ok,"Negative duration rejected")
	check(not Units.convert(1,"unknown","meter").ok,"Unknown unit rejected")
	check(not Units.convert(Units.MAX_INTEGER,"cubic_meter","milliliter").ok,"Conversion overflow")
	check(Units.quantize(1.5,"nearest").value == 2,"Half rounds up")
	check(Units.quantize(1.9,"floor").value == 1,"Floor")
	check(Units.quantize(1.1,"ceil").value == 2,"Ceil")
	check(not Units.quantize(1.0,"implicit").ok,"Explicit rounding")
	for text: String in ["0","0.01","12.3","90000000000.00"]:
		var parsed: Dictionary = Units.parse_credits(text)
		check(parsed.ok and Units.parse_credits(Units.format_minor(parsed.value).value).value == parsed.value,"Exact money round trip")
	check(Units.parse_credits("12.30").value == 1230,"Decimal money")
	for text: String in ["1.005","-1","1e3"," 1","NaN","90000000000.01"]:
		check(not Units.parse_credits(text).ok,"Reject ambiguous/out-of-range money")
	check(Units.add_minor(Units.MAX_INTEGER,0).value == Units.MAX_INTEGER,"Money bound allowed")
	check(not Units.add_minor(Units.MAX_INTEGER,1).ok,"Money addition overflow")
	check(not Units.add_minor(true,1).ok,"Boolean not money")
	check(Units.scaled_seconds(5.0,2.0).value == 10.0,"Explicit time scale")
	check(not Units.scaled_seconds(1.0,0.0).ok,"Reject zero time scale")
	var voyage: VoyageDistance = Distance.new()
	check(not voyage.navigation_nm().ok,"Unconfigured distance rejected")
	check(voyage.configure(1852.0,2.0).ok,"Scaled route configured")
	check(voyage.navigation_nm().value == 2.0 and voyage.payout_fixture(125).value == 250,"Navigation and payout share same scaled distance")
	check(not voyage.configure(100.0).ok,"No silent distance change")
	check(voyage.payout_fixture(0).value == 0,"Zero rate")
	check(not voyage.payout_fixture(Units.MAX_INTEGER).ok,"Quote intermediate overflow rejected")
	var fraction: VoyageDistance = Distance.new()
	fraction.configure(926.0)
	check(fraction.navigation_nm().value == 0.5 and fraction.payout_fixture(101).value == 50,"Floor once at final minor unit")
	check(not Distance.new().configure(-1.0).ok,"Bad route rejected")
	print("UNITS_CHECK_PASS (%d checks)" % count if failures == 0 else "UNITS_CHECK_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
