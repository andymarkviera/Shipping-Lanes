extends RefCounted
## One registered adapter per trusted ship manifest; loading UI cannot choose ownership.
var manifest: RefCounted
var ship_id: String

func _init(owner: String, cargo_manifest: RefCounted) -> void:
	ship_id = owner
	manifest = cargo_manifest

func candidate(entry: Dictionary) -> Dictionary:
	if entry.ship_id != ship_id: return {"ok": false, "message": "Wrong ship."}
	var payload: Dictionary = entry.payload
	var rows: Array[Dictionary] = manifest.lines()
	if payload.get("action") == "load":
		if not payload.get("batch") is Dictionary: return {"ok": false, "message": "Missing cargo batch."}
		rows.append(payload.batch.duplicate(true))
	elif payload.get("action") == "unload":
		if not payload.get("batch_id") is String or not payload.get("quantity") is int or payload.quantity <= 0: return {"ok": false, "message": "Invalid unload request."}
		var found: bool = false
		for i: int in rows.size():
			if rows[i].batch_id != payload.batch_id: continue
			if payload.quantity > rows[i].quantity: return {"ok": false, "message": "Not enough cargo."}
			rows[i].quantity -= payload.quantity
			if rows[i].quantity == 0: rows.remove_at(i)
			found = true
			break
		if not found: return {"ok": false, "message": "Cargo not found."}
	else: return {"ok": false, "message": "Unsupported operation."}
	var error: String = manifest.validate(rows)
	return {"ok": error.is_empty(), "message": error, "rows": rows}

func validate(entry: Dictionary) -> String:
	return candidate(entry).message

func complete(entry: Dictionary) -> Dictionary:
	var proposed: Dictionary = candidate(entry)
	if not proposed.ok: return proposed
	return manifest.replace(proposed.rows)
