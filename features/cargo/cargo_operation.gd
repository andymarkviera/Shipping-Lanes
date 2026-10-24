extends RefCounted
## Trusted authority service. Rules are synchronous, atomic completion adapters.
const TERMINAL: Array[String] = ["committed", "cancelled", "interrupted", "failed"]
var _records: Dictionary = {}
var _locks: Dictionary = {}
var _rules: Dictionary = {}
var releases: int = 0

func register_rule(id: String, rule: RefCounted) -> void:
	_rules[id] = rule

func record(id: String) -> Dictionary:
	return _records.get(id, {}).duplicate(true)

func reserve(id: String, ship_id: String, rule_id: String, payload: Dictionary, duration: float) -> Dictionary:
	if id.is_empty() or ship_id.is_empty() or _records.has(id) or _locks.has(ship_id) or not _rules.has(rule_id) or not is_finite(duration) or duration <= 0 or duration > 86400:
		return {"ok": false, "message": "Invalid or occupied operation."}
	var entry: Dictionary = {"id": id, "ship_id": ship_id, "rule_id": rule_id, "payload": payload.duplicate(true), "duration": duration, "elapsed": 0.0, "state": "reserved", "message": "Reserved"}
	var error: String = _rules[rule_id].validate(entry.duplicate(true))
	if not error.is_empty(): return {"ok": false, "message": error}
	_locks[ship_id] = id
	_records[id] = entry
	return {"ok": true, "message": "Reserved"}

func start(id: String) -> bool:
	if not _records.has(id) or _records[id].state != "reserved": return false
	_records[id].state = "running"
	return true

func progress(id: String, delta: float) -> bool:
	if not _records.has(id) or _records[id].state != "running" or not is_finite(delta) or delta < 0: return false
	var entry: Dictionary = _records[id]
	entry.elapsed = minf(entry.duration, entry.elapsed + delta)
	if entry.elapsed >= entry.duration: entry.state = "ready"
	return true

func finish(entry: Dictionary, state_: String, message: String) -> void:
	entry.state = state_
	entry.message = message
	if _locks.get(entry.ship_id, "") == entry.id:
		_locks.erase(entry.ship_id)
		releases += 1

func commit(id: String) -> Dictionary:
	if not _records.has(id): return {"ok": false, "message": "Unknown operation."}
	var entry: Dictionary = _records[id]
	if entry.state == "committed": return {"ok": true, "message": entry.message}
	if entry.state != "ready": return {"ok": false, "message": "Operation is not ready."}
	var error: String = _rules[entry.rule_id].validate(entry.duplicate(true))
	if not error.is_empty():
		finish(entry, "failed", error)
		return {"ok": false, "message": error}
	entry.state = "committing"
	var result: Dictionary = _rules[entry.rule_id].complete(entry.duplicate(true))
	finish(entry, "committed" if result.ok else "failed", result.message)
	return result.duplicate(true)

func cancel(id: String, interrupted: bool = false) -> bool:
	if not _records.has(id) or _records[id].state not in ["reserved", "running", "ready"]: return false
	finish(_records[id], "interrupted" if interrupted else "cancelled", "Interrupted" if interrupted else "Cancelled")
	return true

func interrupt_ship(ship_id: String) -> void:
	if _locks.has(ship_id): cancel(_locks[ship_id], true)

func snapshot() -> Dictionary:
	return {"version": 1, "records": _records.duplicate(true)}

func restore(data: Dictionary) -> bool:
	# Restore into a fresh service with registered rules, never replace a live owner.
	if not _records.is_empty() or data.get("version") != 1 or not data.get("records") is Dictionary: return false
	var records: Dictionary = data.records.duplicate(true)
	var locks: Dictionary = {}
	for id: Variant in records:
		var e: Variant = records[id]
		if not id is String or id.is_empty() or not e is Dictionary: return false
		for key: String in ["id", "ship_id", "rule_id", "payload", "duration", "elapsed", "state", "message"]:
			if not e.has(key): return false
		if e.id != id or not e.ship_id is String or e.ship_id.is_empty() or not e.rule_id is String or not _rules.has(e.rule_id) or not e.payload is Dictionary or not e.message is String: return false
		if not (e.duration is float or e.duration is int) or not (e.elapsed is float or e.elapsed is int): return false
		if not is_finite(e.duration) or not is_finite(e.elapsed) or e.duration <= 0 or e.duration > 86400 or e.elapsed < 0 or e.elapsed > e.duration: return false
		if e.state not in ["reserved", "running", "ready", "committed", "cancelled", "interrupted", "failed"]: return false
		if e.state == "reserved" and e.elapsed != 0: return false
		if e.state in ["ready", "committed"] and e.elapsed != e.duration: return false
		if e.state == "running" and e.elapsed >= e.duration: return false
		if not TERMINAL.has(e.state):
			if locks.has(e.ship_id) or not _rules[e.rule_id].validate(e.duplicate(true)).is_empty(): return false
			locks[e.ship_id] = id
	_records = records
	_locks = locks
	return true
