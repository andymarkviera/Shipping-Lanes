extends Node
const Snapshot = preload("res://features/cargo/voyage_snapshot.gd")
var store = preload("res://features/cargo/voyage_store.gd").new()
var view: Node3D
var ready_to_save: bool = false
var blocked: bool = false
var elapsed: float = 0
var fingerprint: String = ""

func _ready() -> void:
	process_physics_priority = 100
	boot.call_deferred()

func boot() -> void:
	view = get_parent()
	view.controls.set_menu_open(true)
	view.ship.simulation_paused = true
	view.loading.set_physics_process(false)
	view.set_physics_process(false)
	if not store.open_store(view.save_path):
		stop_with_error(store.error)
		return
	if not store.current.is_empty() and not await Snapshot.restore(view, store.current):
		stop_with_error("Voyage could not be restored safely. Save preserved; no reset performed.")
		return
	await get_tree().physics_frame
	view.ship.simulation_paused = false
	view.loading.set_physics_process(true)
	view.set_physics_process(true)
	view.controls.set_menu_open(false)
	ready_to_save = true
	checkpoint()
	if not blocked: view.offer_notice = store.recovery_notice if not store.recovery_notice.is_empty() else "Voyage saved. Loading resumes; the boat restarts stopped in neutral."

func checkpoint() -> bool:
	if blocked or not ready_to_save or not is_instance_valid(view.ship): return false
	reconcile_heavy()
	return commit_snapshot(Snapshot.capture(view))

func commit_snapshot(data: Dictionary) -> bool:
	if blocked or not ready_to_save: return false
	if not store.save(data):
		stop_with_error(store.error)
		return false
	fingerprint = important_state(data)
	elapsed = 0
	return true

func reconcile_heavy() -> void:
	if view.heavy_mode:
		view.heavy_jobs.update(view.ship)
		view.reward_minor += view.heavy_jobs.reward_pending
		view.heavy_jobs.reward_pending = 0

func important_state(data: Dictionary) -> String:
	var state: Dictionary = data.duplicate(true)
	for key: String in ["pose", "fuel", "clock"]: state.erase(key)
	for record: Dictionary in state.operations.records.values(): record.erase("elapsed")
	state.heavy.erase("height")
	state.heavy.erase("payload_pose")
	return Marshalls.raw_to_base64(var_to_bytes(state)).sha256_text()

func _physics_process(delta: float) -> void:
	if not ready_to_save or blocked: return
	reconcile_heavy()
	elapsed += delta
	var data: Dictionary = Snapshot.capture(view)
	if elapsed >= 1 or important_state(data) != fingerprint: checkpoint()

func stop_with_error(message: String) -> void:
	blocked = true
	ready_to_save = false
	view.controls.set_menu_open(true)
	view.ship.simulation_paused = true
	view.ship.pause_reason = "VOYAGE PAUSED — the save needs attention.\n%s\nClick \"Main menu\" to leave." % message
	view.ship.zero_throttle()
	view.loading.set_physics_process(false)
	view.docking.set_physics_process(false)
	view.set_physics_process(false)
	view.set_process(false)
	view.details.text = "Voyage paused — save needs attention"
	view.readiness.text = message
	for node: Node in view.find_children("*", "Button", true, false):
		if node.text.to_lower() not in ["main menu", "resume", "quit"]: node.disabled = true

func _exit_tree() -> void:
	store.close()
