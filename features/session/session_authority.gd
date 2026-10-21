class_name SessionAuthority
extends RefCounted
## Fixture authority; optionally backed by the private durable economy store.
## The actor argument comes from a trusted session adapter, never request payload.
const PLAYER_ID: String = "player_test"
const SHIP_ID: String = "ship_test"
const TEST_COST_MINOR: int = 10000
var _ledger: EconomyLedger = EconomyLedger.new()
var _clock: SimulationClock = SimulationClock.new()
var _attached: bool = false
var _operation: Dictionary = {"status":"idle","started_world_ms":0,"due_world_ms":0,"completed_world_ms":0,"completion_count":0}
var _state: Dictionary = {
	"revision":0,
	"player":{"id":PLAYER_ID,"wallet_minor":20000},
	"ship":{"id":SHIP_ID,"owner_id":PLAYER_ID,"definition_id":"ship_starter_container_01","fuel_ml":40000,"inventory_id":"inventory_test"},
	"inventory":{"id":"inventory_test","owner_id":SHIP_ID,"cargo":{"cargo_test_container":0}}
}

func open_economy_recovery(path: String, private_realm: String) -> bool:
	var durable: DurableEconomy = DurableEconomy.new()
	if _ledger is DurableEconomy: (_ledger as DurableEconomy).close_store()
	_ledger = durable
	if not durable.open_store(path, private_realm):
		durable.close_store()
		return false
	return true

func close_economy_recovery() -> void:
	if _ledger is DurableEconomy: (_ledger as DurableEconomy).close_store()

func view() -> Dictionary:
	var snapshot: Dictionary = _state.duplicate(true)
	var economy: Dictionary = _ledger.view()
	snapshot.revision = economy.revision
	snapshot.player.wallet_minor = economy.player_minor
	snapshot.inventory.cargo.cargo_test_container = economy.player_quantity
	return snapshot

func request_test_load(actor_id: String, ship_id: String, expected_revision: Variant) -> Dictionary:
	if actor_id != _state.player.id:
		return response(false,"unknown_actor","This player is not in the session.")
	if ship_id != _state.ship.id:
		return response(false,"unknown_ship","This ship is not in the session.")
	if _state.ship.owner_id != actor_id:
		return response(false,"not_owner","You do not own this ship.")
	if not GameUnits.valid_integer(expected_revision):
		return response(false,"invalid_revision","The request has an invalid revision.")
	if expected_revision != view().revision:
		return response(false,"stale_revision","The session changed. Review it and try again.")
	return request_economy(actor_id, ship_id, EconomyLedger.request("test_load:" + str(expected_revision), "purchase_container", 1, expected_revision))

func economy_audit() -> Dictionary:
	return _ledger.audit()

func request_economy(actor_id: String, ship_id: String, request: Variant) -> Dictionary:
	if actor_id != _state.player.id: return response(false, "unknown_actor", "This player is not in the session.")
	if ship_id != _state.ship.id: return response(false, "unknown_ship", "This ship is not in the session.")
	if _state.ship.owner_id != actor_id: return response(false, "not_owner", "You do not own this ship.")
	var receipt: Dictionary = _ledger.execute(actor_id, request)
	var message: String = "Transaction rejected: " + receipt.code
	if receipt.ok:
		message = "Test container loaded." if request.operation == "purchase_container" else "Test cargo delivery paid." if request.operation == "deliver_container" else "Test service fee paid."
	elif receipt.code == "insufficient_funds": message = "Not enough test credits. Start a new test session to reset."
	var result: Dictionary = response(receipt.ok, receipt.code, message)
	result.receipt = receipt
	return result

func response(ok: bool, code: String, message: String) -> Dictionary:
	return {"ok":ok,"code":code,"message":message,"state":view()}

func attach_clock() -> void:
	_attached = true
	_clock.reanchor()

func detach_clock(cancel_work: bool) -> void:
	_attached = false
	_clock.reanchor()
	if cancel_work and _operation.status == "running":
		_operation.status = "canceled"

func pump(now_us: int, advancing: bool) -> void:
	if not _attached: return
	_clock.sample(now_us, advancing)
	var now_ms: int = _clock.view().clock_ms
	if _operation.status == "running" and now_ms >= _operation.due_world_ms:
		_operation.status = "completed"
		_operation.completed_world_ms = _operation.due_world_ms
		_operation.completion_count += 1

func timer_view() -> Dictionary:
	var result: Dictionary = _operation.duplicate(true)
	result.clock = _clock.view()
	result.attached = _attached
	result.remaining_ms = maxi(0, int(_operation.due_world_ms) - int(result.clock.clock_ms)) if _operation.status == "running" else 0
	return result

func request_test_timer(actor_id: String) -> Dictionary:
	if actor_id != PLAYER_ID: return {"ok":false,"message":"Unknown player."}
	if not _attached: return {"ok":false,"message":"Session is not active."}
	if _operation.status == "running": return {"ok":false,"message":"A test timer is already running."}
	var now_ms: int = _clock.view().clock_ms
	_operation = {"status":"running","started_world_ms":now_ms,"due_world_ms":now_ms + 10000,"completed_world_ms":0,"completion_count":0}
	return {"ok":true,"message":"Ten-second test started. No credits or cargo are changed."}
