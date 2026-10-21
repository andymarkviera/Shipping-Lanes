class_name EconomyLedger
extends RefCounted
## Disposable game-to-player economy. No peer recipient, price or transfer API.
const PLAYER_ID: String = "player_test"
const PURCHASE_MINOR: int = 10000
const DELIVERY_MINOR: int = 5000
const SERVICE_MINOR: int = 1000
const LIMIT: int = 1024
var usable: bool = true
var receipt_limit: int = LIMIT
var _data: Dictionary = {"state": {"revision": 0, "player_minor": 20000,
	"system_minor": 1000000, "player_quantity": 0, "stock_quantity": 100,
	"delivered_quantity": 0}, "receipts": {}, "journal": []}

func _init(seed: Dictionary = {}, limit: int = LIMIT) -> void:
	# Trusted fixture seeding only; not exposed through a gameplay request.
	if limit < 1 or limit > LIMIT:
		usable = false
		return
	receipt_limit = limit
	for key: Variant in seed:
		if not _data.state.has(key) or not GameUnits.valid_integer(seed[key]):
			usable = false
			return
	for key: String in seed: _data.state[key] = seed[key]

func view() -> Dictionary:
	return _data.state.duplicate(true)

func audit() -> Dictionary:
	return {"entries": _data.journal.duplicate(true), "receipt_count": _data.receipts.size()}

static func request(id: String, operation: String, quantity: Variant, revision: Variant) -> Dictionary:
	return {"version": 1, "action_id": id, "operation": operation,
		"quantity": quantity, "expected_revision": revision}

func response(code: String, action_id: String = "", amount: int = 0, quantity: int = 0) -> Dictionary:
	return {"ok": code == "ok", "code": code, "action_id": action_id,
		"revision": _data.state.revision, "amount_minor": amount, "quantity": quantity,
		"duplicate": false}

func reject_owned(data: Dictionary, code: String) -> Dictionary:
	# Record a terminal outcome without changing balances, inventory or revision.
	var result: Dictionary = response(code, data.action_id)
	var next: Dictionary = _data.duplicate(true)
	next.receipts[data.action_id] = {"request": data.duplicate(true), "result": result.duplicate(true)}
	_data = next
	return result

func execute(actor: String, data: Variant) -> Dictionary:
	if not usable: return response("invalid_fixture")
	if actor != PLAYER_ID: return response("not_owner")
	if not data is Dictionary or data.size() != 5: return response("bad_request")
	if not data.get("version") is int or data.version != 1: return response("bad_request")
	if not data.get("action_id") is String or data.action_id.is_empty() or data.action_id.length() > 64: return response("bad_action_id")
	if not data.get("operation") is String or data.operation not in ["purchase_container", "deliver_container", "service_fee"]: return response("unsupported_operation", data.action_id)
	if not GameUnits.valid_integer(data.get("quantity")) or data.quantity == 0 or not GameUnits.valid_integer(data.get("expected_revision")): return response("invalid_quantity_or_revision", data.action_id)
	if data.operation == "service_fee" and data.quantity != 1: return response("invalid_quantity_or_revision", data.action_id)
	if _data.receipts.has(data.action_id):
		var receipt: Dictionary = _data.receipts[data.action_id]
		if receipt.request != data: return response("id_conflict", data.action_id)
		var replay: Dictionary = receipt.result.duplicate(true)
		replay.duplicate = true
		return replay
	# Never evict a receipt and risk replaying a committed payment.
	if _data.receipts.size() >= receipt_limit: return response("receipt_capacity", data.action_id)
	var state: Dictionary = _data.state
	if data.expected_revision != state.revision: return reject_owned(data, "stale_revision")
	if state.revision >= GameUnits.MAX_INTEGER: return reject_owned(data, "limit_reached")
	var unit_price: int = PURCHASE_MINOR if data.operation == "purchase_container" else DELIVERY_MINOR if data.operation == "deliver_container" else SERVICE_MINOR
	if data.quantity > GameUnits.MAX_INTEGER / unit_price: return reject_owned(data, "limit_reached")
	var amount: int = data.quantity * unit_price
	var from_wallet: String = "system_minor" if data.operation == "deliver_container" else "player_minor"
	var to_wallet: String = "player_minor" if data.operation == "deliver_container" else "system_minor"
	if state[from_wallet] < amount: return reject_owned(data, "insufficient_funds")
	if state[to_wallet] > GameUnits.MAX_INTEGER - amount: return reject_owned(data, "limit_reached")
	var from_cargo: String = ""
	var to_cargo: String = ""
	if data.operation == "purchase_container":
		from_cargo = "stock_quantity"
		to_cargo = "player_quantity"
	elif data.operation == "deliver_container":
		from_cargo = "player_quantity"
		to_cargo = "delivered_quantity"
	if not from_cargo.is_empty():
		if state[from_cargo] < data.quantity: return reject_owned(data, "insufficient_cargo")
		if state[to_cargo] > GameUnits.MAX_INTEGER - data.quantity: return reject_owned(data, "limit_reached")
	# Prepare balances, both cargo sides, journal and receipt; publish together.
	# No await, signal, callback or external I/O may occur inside this commit.
	var next: Dictionary = _data.duplicate(true)
	next.state[from_wallet] -= amount
	next.state[to_wallet] += amount
	if not from_cargo.is_empty():
		next.state[from_cargo] -= data.quantity
		next.state[to_cargo] += data.quantity
	next.state.revision += 1
	var result: Dictionary = response("ok", data.action_id, amount, 0 if from_cargo.is_empty() else data.quantity)
	result.revision = next.state.revision
	next.journal.append({"action_id": data.action_id, "operation": data.operation,
		"revision": next.state.revision, "debit_wallet": from_wallet, "credit_wallet": to_wallet,
		"amount_minor": amount, "source_inventory": from_cargo, "destination_inventory": to_cargo,
		"quantity": result.quantity})
	next.receipts[data.action_id] = {"request": data.duplicate(true), "result": result.duplicate(true)}
	_data = next
	return result
