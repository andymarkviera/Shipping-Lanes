class_name SimulationClock
extends RefCounted
## 20 Hz operation clock. Integer microseconds retain fractional tick progress.
const TICK_US: int = 50000
const MAX_FRAME_US: int = 250000
var _clock_ms: int = 0
var _remainder_us: int = 0
var _last_us: int = -1
var _discarded_us: int = 0

func reanchor() -> void:
	_last_us = -1

func sample(now_us: int, advancing: bool) -> int:
	if now_us < 0: return 0
	if _last_us < 0:
		_last_us = now_us
		return 0
	if now_us < _last_us:
		return 0 # A backward sample cannot reset the baseline or grant time twice.
	var delta_us: int = now_us - _last_us
	_last_us = now_us
	if not advancing: return 0
	var accepted: int = mini(delta_us, MAX_FRAME_US)
	_discarded_us += delta_us - accepted
	_remainder_us += accepted
	@warning_ignore("integer_division")
	var ticks: int = _remainder_us / TICK_US
	_remainder_us %= TICK_US
	_clock_ms += ticks * 50
	return ticks

func view() -> Dictionary:
	return {"clock_ms":_clock_ms,"remainder_us":_remainder_us,"discarded_us":_discarded_us,"tick_ms":50}
