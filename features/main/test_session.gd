class_name TestSession
extends Node
## Disposable flow fixture, not a world clock or network implementation.
var _authority: SessionAuthority = SessionAuthority.new()
var hosted: bool = true
var locally_paused: bool = false
var elapsed: float = 0.0

func _process(delta: float) -> void:
	if hosted or not locally_paused:
		elapsed += delta

func snapshot() -> Dictionary:
	return {"hosted": hosted, "elapsed": elapsed, "authority": _authority}

func restore_continuation(authority: SessionAuthority) -> void:
	# Trusted in-memory continuation, never a file/network deserialization path.
	if authority != null:
		_authority = authority

func state_view() -> Dictionary:
	return _authority.view()

func request_test_load(expected_revision: Variant) -> Dictionary:
	# Local fixture adapter resolves actor and controlled ship outside UI payload.
	return _authority.request_test_load(SessionAuthority.PLAYER_ID, SessionAuthority.SHIP_ID, expected_revision)
