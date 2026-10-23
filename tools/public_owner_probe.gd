extends Node
## Operator-owned file courier only; never a network or player command channel.
const OwnerScene = preload("res://features/network/public_ship_owner.gd")
var ship_owner: Node3D
var folder: String
var sequence: int = 0
var working: bool = false
var started: int

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--owner-folder="): folder = arg.trim_prefix("--owner-folder=")
	if folder.is_empty(): get_tree().quit(1); return
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder + "/config.json"))
	ship_owner = OwnerScene.new()
	add_child(ship_owner)
	if not config is Dictionary or not ship_owner.authority.configure(config): get_tree().quit(1); return
	started = Time.get_ticks_msec()
	write_result("ready", {"ok": true})

func write_result(name_: String, result: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(folder + "/" + name_ + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	DirAccess.rename_absolute(folder + "/" + name_ + ".tmp", folder + "/" + name_ + ".json")

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - started > 180000: get_tree().quit(0); return
	if working: return
	var path: String = folder + "/command-" + str(sequence) + ".json"
	if not FileAccess.file_exists(path): return
	working = true
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for field: String in ["epoch", "generation", "expected_revision"]:
		if data.has(field) and data[field] == floor(data[field]): data[field] = int(data[field])
	if data.get("binding") is Dictionary:
		for field: String in ["epoch", "generation"]:
			if data.binding.has(field) and data.binding[field] == floor(data.binding[field]): data.binding[field] = int(data.binding[field])
	DirAccess.remove_absolute(path)
	var result: Dictionary
	match data.get("op"):
		"status":
			result = {"active": ship_owner.authority.active, "binding": ship_owner.authority.binding, "phase": ship_owner.authority.phase, "deadline": ship_owner.authority.deadline_ms, "has_hull": ship_owner.ship != null}
			if ship_owner.ship != null:
				result.merge({"ship_id": ship_owner.ship.state.instance_id, "fuel": ship_owner.ship.state.fuel_liters, "speed": ship_owner.ship.velocity.length(), "distance": ship_owner.ship.position.length(), "paused": ship_owner.ship.simulation_paused, "collision": ship_owner.ship.collision_layer, "visible": ship_owner.ship.visible, "throttle": ship_owner.ship.commanded_throttle, "anchor": ship_owner.geographic_anchor, "cargo": ship_owner.cargo_records})
		"reparent_checkpoint":
			var before: int = ship_owner.last_saved_ms
			ship_owner.checkpoint_current()
			var inflight: bool = ship_owner.authority.busy and ship_owner.checkpoint_busy
			var stable: Node3D = Node3D.new()
			add_child(stable)
			ship_owner.reparent(stable)
			var deadline: int = Time.get_ticks_msec() + 8000
			while ship_owner.checkpoint_busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
			result = {"ok": inflight and not ship_owner.checkpoint_busy and ship_owner.last_saved_ms > before, "inflight": inflight}
		"helm": result = {"ok": ship_owner.helm(data.binding, data.throttle, data.rudder)}
		"admit", "claim": result = await ship_owner.acquire(data)
		"begin": result = await ship_owner.begin_transfer(data)
		_: result = await ship_owner.authority.request(data)
	write_result("reply-" + str(sequence), result)
	sequence += 1
	working = false
