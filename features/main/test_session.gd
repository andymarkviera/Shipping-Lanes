class_name TestSession
extends Node
## Session owns processing; authority owns clock and pending test work.
var _authority: SessionAuthority = SessionAuthority.new()
var _stopped: bool = false
var hosted: bool = true
var locally_paused: bool = false
var elapsed: float:
	get: return float(_authority.timer_view().clock.clock_ms) / 1000.0

func _ready() -> void:
	_authority.attach_clock()

func _process(_delta: float) -> void:
	_authority.pump(Time.get_ticks_usec(), hosted or not locally_paused)

func stop(preserve_for_continue: bool) -> void:
	_stopped = true
	_authority.detach_clock(not preserve_for_continue)

func _exit_tree() -> void:
	if not _stopped: stop(false)

func snapshot() -> Dictionary:
	return {"hosted":hosted,"authority":_authority}

func restore_continuation(authority: SessionAuthority) -> void:
	if authority != null: _authority = authority

func state_view() -> Dictionary:
	return _authority.view()

func request_test_load(expected_revision: Variant) -> Dictionary:
	return _authority.request_test_load(SessionAuthority.PLAYER_ID, SessionAuthority.SHIP_ID, expected_revision)

func request_test_timer() -> Dictionary:
	return _authority.request_test_timer(SessionAuthority.PLAYER_ID)

func timer_view() -> Dictionary:
	return _authority.timer_view()

func diagnostic_view() -> Dictionary:
	var current: Dictionary = _authority.view()
	return {"role":"Local test (hosted policy)" if hosted else "Offline test",
		"ship_id":current.ship.id,"fuel_ml":current.ship.fuel_ml,
		"speed_mps":null,"throttle":null,"position_m":null}
