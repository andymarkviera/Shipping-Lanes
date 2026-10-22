extends Node
## Application owns local navigation; it never pauses the shared SceneTree.
enum State { BOOT, TITLE, SERVERS, PLAYING, PAUSED, SETTINGS, SAVES }
const Session = preload("res://features/main/test_session.gd")
var developer_overlay: DeveloperOverlay
var state: State = State.BOOT
var settings_return: State = State.TITLE
var session: TestSession
var continuation: Dictionary = {}
var slots: PrivateSaveSlots = PrivateSaveSlots.new()
var active_slot: int = 0
var recovery_target: int = -1
var recovery_source: int = -1
var persistent_world: LocalWorldSave
var orbit_captured: bool = false
var catalog: DefinitionRegistry = DefinitionRegistry.new()
@onready var controls: PlayerControls = $Controls
@onready var menu: ApplicationMenu = $UI/Menu

func _ready() -> void:
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--public-physics-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/public_physics_probe.tscn")
		return
	for argument: String in OS.get_cmdline_user_args():
		if get_tree().current_scene == self and argument.begins_with("--public-server-config="):
			get_tree().change_scene_to_file.call_deferred("res://features/network/public_server.tscn")
			return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--public-peer-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/public_peer_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--public-owner-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/public_owner_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--identity-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/identity_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--auth-transport-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/auth_transport_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--slots-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/slots_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--migration-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/migration_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--persistence-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/persistence_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--recovery-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/recovery_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--public-storage-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/public_storage_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--economy-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/economy_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--action-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/action_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--capacity-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/capacity_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--connected-world-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/connected_world_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--cargo-network-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/cargo_network_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--replication-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/replication_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--network-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/network_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--fuel-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/fuel_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--composition-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/composition_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--heavy-lifter-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/heavy_lifter_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--world-size-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/world_size_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--feedback-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/feedback_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--collision-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/collision_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--water-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/water_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--camera-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/camera_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--handling-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/handling_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--diagnostics-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/diagnostics_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--clocks-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/clocks_probe.tscn")
		return
	if get_tree().current_scene == self and OS.get_cmdline_user_args().has("--session-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/session_probe.tscn")
		return
	if OS.get_cmdline_user_args().has("--units-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/units_probe.tscn")
		return
	if OS.get_cmdline_user_args().has("--contracts-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/contracts_probe.tscn")
		return
	if OS.get_cmdline_user_args().has("--storage-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/storage_probe.tscn")
		return
	if OS.get_cmdline_user_args().has("--geography-check"):
		get_tree().change_scene_to_file.call_deferred("res://tools/geography_probe.tscn")
		return
	var errors: PackedStringArray = catalog.load_definitions(PrototypeCatalog.RECORDS)
	if not errors.is_empty():
		push_error("Catalog validation failed: " + "; ".join(errors))
		get_tree().quit(1)
		return
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(Vector2i(960, 640))
		DisplayServer.window_set_title("Container Ship Sim")
	developer_overlay = DeveloperOverlay.new()
	add_child(developer_overlay)
	menu.selected.connect(navigate)
	$UI/Settings.closed.connect(func() -> void: transition(settings_return))
	controls.command_requested.connect(func(action: StringName) -> void:
		if action == &"pause":
			pause_session())
	active_slot = clampi(int(get_tree().get_meta("local_save_slot", 0)), 0, 2)
	refresh_save_status()
	transition(State.TITLE)
	print("Shipping Lanes: Main scene loaded successfully.")

func navigate(action: String) -> void:
	match action:
		"local_network": get_tree().change_scene_to_file("res://features/network/private_network_test.tscn")
		"saves":
			menu.slot_picker.select(active_slot)
			refresh_save_status()
			transition(State.SAVES)
		"select_slot": refresh_save_status()
		"use_slot": select_save_slot(menu.slot_picker.selected)
		"new_slot":
			if slots.create_new(menu.slot_picker.selected): select_save_slot(menu.slot_picker.selected)
			menu.slot_result.text = slots.message
			refresh_save_status()
		"recover_slot": offer_recovery()
		"confirm_recovery":
			if recovery_source >= 0 and recovery_target >= 0:
				if slots.recover(recovery_source, recovery_target): select_save_slot(recovery_target)
				menu.slot_result.text = slots.message
				recovery_target = -1
				recovery_source = -1
				refresh_save_status()
		"play": start_saved_session()
		"handling":
			if slots.occupied(active_slot) and not FileAccess.file_exists(slots.folder(active_slot) + "/world.db"):
				menu.save_notice.text = "Main save unavailable. Open Local Saves for recovery."
				return
			get_tree().set_meta("local_save_requested", true)
			get_tree().change_scene_to_file("res://features/handling/handling_test.tscn")
		"heavy_lifter": get_tree().change_scene_to_file("res://features/handling/heavy_lifter_test.tscn")
		"test_load": request_test_load()
		"test_timer": request_test_timer()
		"continue": continue_session()
		"servers": transition(State.SERVERS)
		"settings": open_settings()
		"pause": pause_session()
		"resume": transition(State.PLAYING)
		"title": return_to_title()
		"exit": get_tree().quit()

func start_session(hosted: bool = true, snapshot: Dictionary = {}) -> void:
	if persistent_world != null and snapshot.get("authority") != persistent_world.authority:
		persistent_world.close_world()
		persistent_world = null
	if snapshot.is_empty() and continuation.has("authority"):
		continuation.authority.detach_clock(true)
	destroy_session()
	session = Session.new()
	session.name = "TestSession"
	session.hosted = hosted
	session.restore_continuation(snapshot.get("authority", null))
	$World.add_child(session)
	continuation = {}
	transition(State.PLAYING)
	menu.show_session_state(session.state_view(), "Disposable test credits and cargo only.")
	if persistent_world != null: menu.show_session_state(session.state_view(), persistent_world.message)

func start_saved_session() -> void:
	var saved: LocalWorldSave = LocalWorldSave.new()
	if slots.occupied(active_slot) and not FileAccess.file_exists(slots.folder(active_slot) + "/world.db"):
		menu.save_notice.text = "Main save unavailable. Open Local Saves for recovery; existing files are preserved."
		return
	if not saved.open_world(slots.folder(active_slot)):
		menu.save_notice.text = saved.message
		saved.close_world()
		return
	if persistent_world != null: persistent_world.close_world()
	persistent_world = saved
	start_session(false, {"authority":saved.authority})
	var recovered_notice: String = saved.message if saved.message.begins_with("Recovered") else ""
	saved.save(saved.current.location, saved.current.fuel_ml)
	menu.show_session_state(session.state_view(), recovered_notice + ("\n" if not recovered_notice.is_empty() else "") + saved.message)

func destroy_session(preserve_for_continue: bool = false) -> void:
	if is_instance_valid(session):
		session.stop(preserve_for_continue)
		$World.remove_child(session)
		session.queue_free()
	session = null

func continue_session() -> void:
	if continuation.is_empty():
		return
	start_session(bool(continuation.hosted), continuation.duplicate(true))

func return_to_title() -> void:
	if is_instance_valid(session):
		continuation = session.snapshot()
	destroy_session(true)
	refresh_save_status()
	transition(State.TITLE)

func pause_session() -> void:
	if state == State.PLAYING:
		transition(State.PAUSED)

func open_settings() -> void:
	if state == State.SETTINGS:
		return
	settings_return = State.PAUSED if is_instance_valid(session) else state
	transition(State.SETTINGS)
	$UI/Settings.open(controls)

func transition(next: State) -> void:
	if next == State.PLAYING and not is_instance_valid(session):
		return
	release_capture()
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	state = next
	controls.set_ship_context(state == State.PLAYING)
	controls.set_menu_open(state != State.PLAYING)
	if is_instance_valid(session):
		session.locally_paused = state != State.PLAYING
	$UI/Settings.hide()
	var pages: Dictionary = {State.TITLE: "title", State.SERVERS: "servers", State.PLAYING: "playing", State.PAUSED: "paused", State.SAVES: "saves"}
	menu.show_page(pages.get(state, ""), not continuation.is_empty())

func release_capture() -> void:
	orbit_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		release_capture()
		pause_session()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if not event.pressed:
			release_capture()
		elif state == State.PLAYING and controls.input_allowed():
			orbit_captured = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	match state:
		State.PLAYING: pause_session()
		State.PAUSED: transition(State.PLAYING)
		State.SERVERS, State.SAVES: return_to_title()
	get_viewport().set_input_as_handled()

func request_test_load() -> void:
	if state != State.PLAYING or not is_instance_valid(session):
		return
	var result: Dictionary = session.request_test_load(menu.session_revision)
	menu.show_session_state(result.state, result.message)

func request_test_timer() -> void:
	if state != State.PLAYING or not is_instance_valid(session): return
	var result: Dictionary = session.request_test_timer()
	menu.show_session_state(session.state_view(), result.message)

func _process(_delta: float) -> void:
	if is_instance_valid(developer_overlay):
		developer_overlay.set_snapshot(session.diagnostic_view() if is_instance_valid(session) else {})
	if is_instance_valid(session):
		menu.show_timer(session.timer_view())
func _exit_tree() -> void:
	if persistent_world != null: persistent_world.close_world()
	if continuation.has("authority"):
		continuation.authority.detach_clock(true)

func refresh_save_status() -> void:
	menu.slot_status.text = slots.status(menu.slot_picker.selected)
	menu.play_button.text = "PLAY" if slots.occupied(active_slot) else "CREATE & PLAY"
	menu.save_notice.text = "Local slot %d: %s" % [active_slot + 1, slots.status(active_slot)]

func select_save_slot(index: int) -> void:
	# A slot switch ends the old local authority; continuation cannot cross slots.
	destroy_session()
	if continuation.has("authority"): continuation.authority.detach_clock(true)
	continuation = {}
	if persistent_world != null:
		persistent_world.close_world()
		persistent_world = null
	active_slot = index
	get_tree().set_meta("local_save_slot", index)
	get_tree().set_meta("local_save_folder", slots.folder(index))
	menu.slot_picker.select(index)
	menu.slot_result.text = "Selected local slot %d." % (index + 1)
	refresh_save_status()

func offer_recovery() -> void:
	recovery_source = menu.slot_picker.selected
	recovery_target = -1
	for index: int in range(3):
		if not slots.occupied(index):
			recovery_target = index
			break
	if recovery_target < 0 or not FileAccess.file_exists(slots.folder(recovery_source) + "/world.backup.db"):
		menu.slot_result.text = "Recovery requires an available backup and an empty slot. No files were changed."
		return
	menu.recovery_confirmation.dialog_text = "Copy slot %d's backup into slot %d?\nMoney, cargo and ship progress will be from the backup's time.\nThe original slot remains untouched." % [recovery_source + 1, recovery_target + 1]
	menu.recovery_confirmation.popup_centered(Vector2i(650, 200))
