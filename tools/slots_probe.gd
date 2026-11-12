extends Node
var checks: int = 0
var failures: int = 0
func expect(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _ready() -> void:
	var authorized: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--slots-proof=") and arg.trim_prefix("--slots-proof=").length() == 32: authorized = true
	if not authorized:
		get_tree().quit(1)
		return
	# Runner supplies isolated APPDATA; these are real menu/default-slot paths.
	var preferences: FileAccess = FileAccess.open("user://preferences.json", FileAccess.WRITE)
	preferences.store_string(JSON.stringify(InputPreferences.new().to_data()))
	preferences.close()
	var preferences_hash: String = FileAccess.get_sha256("user://preferences.json")
	var app: Node = load("res://features/main/main.tscn").instantiate()
	add_child(app)
	expect(app.menu.play_button.text == "CREATE LOCAL SAVE TEST", "Empty default explicitly says create")
	app.navigate("saves")
	expect(app.menu.pages.saves.visible and "New" in app.menu.slot_status.text, "New slot visible")
	app.navigate("new_slot")
	expect("created" in app.menu.slot_result.text, "Explicit new game succeeds")
	expect("Existing" in app.menu.slot_status.text, "Existing slot distinguished")
	app.navigate("title")
	app.navigate("play")
	expect(app.session != null and app.persistent_world.usable, "Selected slot starts")
	# Start_saved_session made a checkpoint backup before this later payment.
	app.request_test_load()
	expect(app.session.state_view().player.wallet_minor == 10000, "Latest source payment committed")
	app.navigate("title")
	app.navigate("saves")
	app.navigate("recover_slot")
	expect(app.menu.recovery_confirmation.visible, "Recovery requires confirmation")
	expect("backup's time" in app.menu.recovery_confirmation.dialog_text, "Rollback consequence visible")
	expect(not app.slots.occupied(1), "Opening confirmation changes no destination")
	app.menu.recovery_confirmation.hide()
	app.navigate("confirm_recovery")
	expect(app.active_slot == 1 and "restored" in app.menu.slot_result.text, "Recovery creates/selects separate slot")
	expect(app.continuation.is_empty() and app.session == null, "Slot switch clears old authority continuation")
	var original: LocalWorldSave = LocalWorldSave.new()
	expect(original.open_world(app.slots.folder(0)), "Original remains loadable")
	expect(original.authority.view().player.wallet_minor == 10000, "Recovery leaves latest original money unchanged")
	original.close_world()
	var recovered: LocalWorldSave = LocalWorldSave.new()
	expect(recovered.open_world(app.slots.folder(1)), "Recovered copy validates")
	expect(recovered.authority.view().player.wallet_minor == 20000, "Explicit recovery uses backup-time economy")
	recovered.close_world()
	expect(not app.slots.create_new(0), "New game cannot overwrite occupied slot")
	expect(not app.slots.recover(0, 1), "Recovery cannot overwrite occupied destination")
	app.navigate("title")
	app.navigate("play")
	expect(app.persistent_world.root_path == app.slots.folder(1), "Play uses selected slot")
	expect(get_tree().get_meta("local_save_folder") == app.slots.folder(1), "Handling receives selected slot")
	app.navigate("title")
	app.navigate("saves")
	app.menu.slot_picker.select(2)
	app.navigate("new_slot")
	expect(app.active_slot == 2, "Third slot selectable")
	var db: SQLite = SQLite.new()
	db.path = app.slots.folder(2) + "/world.db"
	db.verbosity_level = 0
	expect(db.open_db() and db.query("UPDATE world_meta SET version=99"), "Future save fixture")
	db.close_db()
	app.refresh_save_status()
	expect("Incompatible" in app.menu.slot_status.text, "Incompatible slot distinguished")
	app.navigate("title")
	app.navigate("play")
	expect(app.session == null and "unsupported" in app.menu.save_notice.text, "Incompatible load visibly refuses")
	var fixtures: PrivateSaveSlots = PrivateSaveSlots.new()
	fixtures.base = "user://r"
	expect(fixtures.create_new(0), "Create damage fixture")
	var damaged: LocalWorldSave = LocalWorldSave.new()
	expect(damaged.open_world(fixtures.folder(0)) and damaged.save(damaged.current.location, damaged.current.fuel_ml), "Create validated backup")
	expect(damaged.economy.db.query("UPDATE world_checkpoints SET payload='broken'"), "Damage spatial records only")
	damaged.close_world()
	expect("Recovery required" in fixtures.status(0) and "Backup available" in fixtures.status(0), "Recoverable state distinguished")
	expect(fixtures.recover(0, 1), "Backup recovers damaged world into empty slot")
	expect("Recovery required" in fixtures.status(0), "Damaged original preserved after recovery")
	expect(not fixtures.recover(2, 0), "Missing backup/occupied destination rejected")
	DirAccess.make_dir_recursive_absolute(fixtures.folder(2))
	db.path = fixtures.folder(1) + "/world.db"
	expect(db.open_db() and db.backup_to(fixtures.folder(2) + "/world.backup.db"), "Prepare missing-main backup fixture")
	db.close_db()
	expect("main save missing" in fixtures.status(2), "Missing main is recoverable, never new")
	var marker: FileAccess = FileAccess.open(fixtures.folder(2) + "/recovery.pending", FileAccess.WRITE)
	marker.store_string("interrupted")
	marker.close()
	expect("incomplete" in fixtures.status(2), "Interrupted copy has distinct status")
	var interrupted: LocalWorldSave = LocalWorldSave.new()
	expect(not interrupted.open_world(fixtures.folder(2)), "Interrupted copy cannot initialize a fresh economy")
	expect(not FileAccess.file_exists(fixtures.folder(2) + "/world.db"), "Interrupted copy never creates replacement database")
	interrupted.close_world()
	var blocked: PrivateSaveSlots = PrivateSaveSlots.new()
	blocked.base = "user://blocked"
	var obstruction: FileAccess = FileAccess.open(blocked.base, FileAccess.WRITE)
	obstruction.store_string("unrelated file")
	obstruction.close()
	app.slots = blocked
	app.navigate("saves")
	app.menu.slot_picker.select(0)
	app.navigate("new_slot")
	expect("Cannot create" in app.menu.slot_result.text and not "created" in app.menu.slot_result.text, "Unwritable destination visibly fails without success")
	expect(FileAccess.get_file_as_string(blocked.base) == "unrelated file", "Unrelated obstruction preserved")
	expect(FileAccess.get_sha256("user://preferences.json") == preferences_hash, "Settings remain unchanged")
	app.queue_free()
	await get_tree().process_frame
	get_tree().remove_meta("local_save_slot")
	get_tree().remove_meta("local_save_folder")
	if failures == 0: print("SLOTS_CHECK_PASS (", checks, " checks)")
	get_tree().quit(0 if failures == 0 else 1)
