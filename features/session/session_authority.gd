class_name SessionAuthority
extends RefCounted
## In-memory fixture authority. Only this class changes player/ship/wallet/cargo.
## The actor argument comes from a trusted session adapter, never request payload.
const PLAYER_ID: String = "player_test"
const SHIP_ID: String = "ship_test"
const TEST_COST_MINOR: int = 10000
var _state: Dictionary = {
	"revision":0,
	"player":{"id":PLAYER_ID,"wallet_minor":20000},
	"ship":{"id":SHIP_ID,"owner_id":PLAYER_ID,"definition_id":"ship_starter_container_01","fuel_ml":40000,"inventory_id":"inventory_test"},
	"inventory":{"id":"inventory_test","owner_id":SHIP_ID,"cargo":{"cargo_test_container":0}}
}

func view() -> Dictionary:
	return _state.duplicate(true)

func request_test_load(actor_id: String, ship_id: String, expected_revision: Variant) -> Dictionary:
	if actor_id != _state.player.id:
		return response(false,"unknown_actor","This player is not in the session.")
	if ship_id != _state.ship.id:
		return response(false,"unknown_ship","This ship is not in the session.")
	if _state.ship.owner_id != actor_id:
		return response(false,"not_owner","You do not own this ship.")
	if not GameUnits.valid_integer(expected_revision):
		return response(false,"invalid_revision","The request has an invalid revision.")
	if expected_revision != _state.revision:
		return response(false,"stale_revision","The session changed. Review it and try again.")
	if _state.player.wallet_minor < TEST_COST_MINOR:
		return response(false,"insufficient_funds","Not enough test credits. Start a new test session to reset.")
	if _state.revision >= GameUnits.MAX_INTEGER or _state.inventory.cargo.cargo_test_container >= GameUnits.MAX_INTEGER:
		return response(false,"limit_reached","The test state has reached its limit.")
	# Prepare the entire change, then publish once. No awaits/callbacks mid-action.
	var next: Dictionary = _state.duplicate(true)
	next.player.wallet_minor -= TEST_COST_MINOR
	next.inventory.cargo.cargo_test_container += 1
	next.revision += 1
	_state = next
	return response(true,"ok","Test container loaded.")

func response(ok: bool, code: String, message: String) -> Dictionary:
	return {"ok":ok,"code":code,"message":message,"state":view()}
