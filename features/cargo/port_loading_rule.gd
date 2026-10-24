extends RefCounted
var body: HandlingShip
var port: Node3D
var docking: Node
var offers: RefCounted
var peer: int
var owner: String
var ship_key: String

func validate(entry: Dictionary) -> String:
	if not is_instance_valid(body) or not is_instance_valid(port) or not is_instance_valid(docking): return "Loading interrupted."
	if entry.ship_id != body.state.instance_id or docking.state(peer) != "docked" or not body.docked: return "Dock before loading."
	if not entry.payload.get("offer_id") is String: return "Invalid offer."
	return offers.loading_error(entry.payload.offer_id, owner, ship_key, port.definition.id, body.state.manifest)

func complete(entry: Dictionary) -> Dictionary:
	var error: String = validate(entry)
	if not error.is_empty(): return {"ok": false, "message": error}
	return offers.complete_loading(entry.payload.offer_id, owner, ship_key, port.definition.id, body.state.manifest)
