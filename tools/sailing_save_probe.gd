extends Node3D
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var view = preload("res://features/ports/port_test.tscn").instantiate()
	view.save_enabled = false
	add_child(view)
	view.set_physics_process(false)
	view.loading.set_physics_process(false)
	view.docking.set_physics_process(false)
	await get_tree().physics_frame
	var from_save: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--checkpoint="):
			from_save = true
			var file: FileAccess = FileAccess.open(arg.trim_prefix("--checkpoint="), FileAccess.READ)
			var saved: Dictionary = bytes_to_var(Marshalls.base64_to_raw(file.get_as_text()))
			if not await Snapshot.restore(view, saved):
				push_error("Saved voyage could not restore")
				get_tree().quit(1)
				return
	if not from_save:
		view.ship.global_transform = view.port.berth_anchor.global_transform
		view.docking.request_dock(1, view.service_id(), view.cargo_id())
		view.docking.advance(1.1)
		view.accept_selected()
		view.loading.advance(20)
	if view.ship.state.manifest.lines().is_empty():
		push_error("Sailing regression requires loaded cargo")
		get_tree().quit(1)
		return
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
	view.docking.disconnect_owner(1)
	view.docking.register(1, view.ship, view.port)
	view.ship.global_position = Vector3(4000, 0, -4000)
	await get_tree().physics_frame
	var store = preload("res://features/cargo/voyage_store.gd").new()
	if not store.open_store("user://sailing_regression/voyage.db"):
		push_error(store.error)
		get_tree().quit(1)
		return
	view.ship.command_throttle(1)
	view.ship.maneuver(1, 0)
	for tick: int in 18000:
		view.ship.advance_motion(1.0 / 60)
		view.ship.position += view.ship.velocity / 60
		view._physics_process(1.0 / 60)
		if tick % 60 == 0:
			var data: Dictionary = Snapshot.capture(view)
			if not Snapshot.valid(data):
				var normalized: Dictionary = data.duplicate(true)
				normalized.pose.basis = normalized.pose.basis.orthonormalized()
				print("SAILING_SAVE_REJECT tick=", tick, " determinant=", data.pose.basis.determinant(), " normalized_valid=", Snapshot.valid(normalized))
				get_tree().quit(1)
				return
			if not store.save(data):
				push_error(store.error)
				get_tree().quit(1)
				return
	var saved: Dictionary = store.current.duplicate(true)
	if not await Snapshot.restore(view, saved):
		push_error("Long sailing checkpoint cannot reopen")
		get_tree().quit(1)
		return
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
	view.ship.command_throttle(1)
	view.ship.maneuver(-1, 0)
	for tick: int in 1800:
		view.ship.advance_motion(1.0 / 60)
		view.ship.position += view.ship.velocity / 60
		view._physics_process(1.0 / 60)
		if tick % 60 == 0 and not store.save(Snapshot.capture(view)):
			push_error("Saving fails after reopening: " + store.error)
			get_tree().quit(1)
			return
	if view.ship.state.manifest.lines() != saved.manifest:
		push_error("Sailing changed cargo")
		get_tree().quit(1)
		return
	print("SAILING_SAVE_PASS checkpoints=330 cargo_batches=", view.ship.state.manifest.lines().size())
	store.close()
	get_tree().quit()
