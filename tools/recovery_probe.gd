extends Node
var root_path: String
var phase: String
var failures: int = 0
var checks: int = 0
var store: DurableEconomy
const REALM: String = "private_recovery_test"

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func intent(id: String, operation: String, revision: int, quantity: int = 1) -> Dictionary:
	return EconomyLedger.request(id, operation, quantity, revision)

func execute(data: Dictionary) -> Dictionary:
	return store.execute(SessionAuthority.PLAYER_ID, data)

func balances(money: int, cargo: int, revision: int) -> void:
	var state: Dictionary = store.view()
	expect(state.player_minor == money, "Recovered wallet")
	expect(state.player_quantity == cargo, "Recovered cargo")
	expect(state.revision == revision, "Recovered revision")
	expect(state.player_minor + state.system_minor == 1020000, "Money conserved")
	expect(state.player_quantity + state.stock_quantity + state.delivered_quantity == 100, "Cargo conserved")

func crash(stage: String) -> void:
	var target: String = {"pending":"snapshot_written", "prepared":"before_commit", "committed":"after_commit"}.get(phase, "")
	if stage != target: return
	var marker: FileAccess = FileAccess.open(root_path + "/" + phase + ".ready", FileAccess.WRITE)
	marker.store_string(stage)
	marker.close()
	while true: OS.delay_msec(50) # Harness terminates only this child PID.

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--recovery-root="): root_path = arg.trim_prefix("--recovery-root=")
		if arg.begins_with("--recovery-phase="): phase = arg.trim_prefix("--recovery-phase=")
	var pattern: RegEx = RegEx.new()
	pattern.compile("^user://action-recovery/[a-f0-9]{32}$")
	if pattern.search(root_path) == null or phase not in ["init", "pending", "recover", "prepared", "retry", "committed", "verify", "reopen"]:
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(root_path)
	store = DurableEconomy.new()
	expect(store.open_store(root_path + "/economy.db", REALM), "Private store opens: " + store.storage_error)
	if not store.usable:
		get_tree().quit(1)
		return
	store.fault_hook = crash
	match phase:
		"init":
			balances(20000, 0, 0)
			var authority: SessionAuthority = SessionAuthority.new()
			expect(authority.open_economy_recovery(root_path + "/economy.db", REALM), "Session binds durable authority")
			expect(authority.request_test_load(SessionAuthority.PLAYER_ID, SessionAuthority.SHIP_ID, 0).ok, "Existing session purchase flow commits")
			expect(authority.view().player.wallet_minor == 10000, "Session shows committed wallet")
			authority.close_economy_recovery()
		"pending":
			balances(10000, 1, 1)
			execute(intent("delivery", "deliver_container", 1))
		"recover":
			balances(10000, 1, 1)
			expect(store.audit().receipt_count == 1, "No receipt for partial write")
			expect(execute(intent("delivery", "deliver_container", 1)).ok, "Retry rolled-back delivery")
			balances(15000, 0, 2)
		"prepared":
			balances(15000, 0, 2)
			execute(intent("prepared_fee", "service_fee", 2))
		"retry":
			balances(15000, 0, 2)
			expect(store.audit().receipt_count == 2, "Uncommitted receipt rolled back")
			expect(execute(intent("prepared_fee", "service_fee", 2)).ok, "Retry prepared action")
			balances(14000, 0, 3)
		"committed":
			balances(14000, 0, 3)
			execute(intent("lost_reply", "service_fee", 3))
		"verify":
			balances(13000, 0, 4)
			expect(store.audit().receipt_count == 4, "Committed receipt survives kill")
			var replay: Dictionary = execute(intent("lost_reply", "service_fee", 3))
			expect(replay.ok and replay.duplicate and replay.revision == 4, "Lost reply returns original result")
			balances(13000, 0, 4)
			expect(execute(intent("lost_reply", "purchase_container", 3)).code == "id_conflict", "Same ID changed payload rejected")
			expect(store.execute("other_player", intent("lost_reply", "service_fee", 3)).code == "not_owner", "Ownership before receipt")
			expect(execute(intent("failed", "purchase_container", 4, 2)).code == "insufficient_funds", "Failure retained")
			var other: DurableEconomy = DurableEconomy.new()
			expect(other.open_store(root_path + "/economy.db", REALM), "Second writer opens")
			expect(execute(intent("winner", "service_fee", 4)).ok, "First writer commits")
			expect(other.execute(SessionAuthority.PLAYER_ID, intent("loser", "service_fee", 4)).code == "stale_revision", "Second writer reads locked current revision")
			expect(other.execute(SessionAuthority.PLAYER_ID, intent("winner", "service_fee", 4)).duplicate, "Second writer sees original receipt")
			other.close_store()
			balances(12000, 0, 5)
		"reopen":
			balances(12000, 0, 5)
			expect(store.audit().receipt_count == 7, "All success and failure receipts retained")
			expect(execute(intent("failed", "purchase_container", 4, 2)).code == "insufficient_funds", "Failure remains original across restart")
			expect(execute(intent("winner", "service_fee", 4)).duplicate, "Success remains original across restart")
			var authority: SessionAuthority = SessionAuthority.new()
			expect(authority.open_economy_recovery(root_path + "/economy.db", REALM), "Fresh session restores")
			expect(authority.view().revision == 5 and authority.view().player.wallet_minor == 12000, "Session state restored")
			authority.close_economy_recovery()
			var wrong: SessionAuthority = SessionAuthority.new()
			expect(not wrong.open_economy_recovery(root_path + "/economy.db", "private_other"), "Wrong realm cannot restore")
			expect(wrong.request_economy(SessionAuthority.PLAYER_ID, SessionAuthority.SHIP_ID, intent("forbidden", "service_fee", 0)).code == "storage_unavailable", "Failed open never falls back to fresh money")
			var public_store: DurableEconomy = DurableEconomy.new()
			expect(not public_store.open_store(root_path + "/economy.db", "public_fixture"), "Public namespace rejected")
			public_store.close_store()
			expect(store.audit().entries.size() == 5, "Recovered balanced journal")
			check_damaged_copy("future", "PRAGMA user_version=2", "unsupported_schema")
			check_damaged_copy("snapshot", "UPDATE snapshot SET player_minor=999", "invalid_recovery_record")
			check_damaged_copy("receipt", "UPDATE receipts SET amount=999 WHERE sequence=1", "invalid_recovery_record")
			check_damaged_copy("missing", "DELETE FROM receipts WHERE sequence=2", "invalid_recovery_record")
	store.close_store()
	if failures == 0: print("RECOVERY_PHASE_PASS ", phase, " (", checks, " checks)")
	get_tree().quit(0 if failures == 0 else 1)

func check_damaged_copy(label: String, mutation: String, code: String) -> void:
	var path: String = root_path + "/" + label + ".db"
	expect(store.db.backup_to(path), "Database-safe diagnostic copy: " + label)
	var altered: SQLite = SQLite.new()
	altered.path = path
	altered.verbosity_level = 0
	expect(altered.open_db(), "Diagnostic copy opens")
	expect(altered.query(mutation), "Diagnostic mutation")
	expect(altered.query("SELECT * FROM snapshot"), "Read damaged fixture")
	var before: Array = altered.query_result.duplicate(true)
	altered.close_db()
	var recovery: DurableEconomy = DurableEconomy.new()
	expect(not recovery.open_store(path, REALM) and recovery.storage_error == code, "Refuse damaged/incompatible " + label)
	expect(recovery.execute(SessionAuthority.PLAYER_ID, intent("blocked", "service_fee", 0)).code == "storage_unavailable", "No writes after failed recovery")
	recovery.close_store()
	expect(altered.open_db(), "Reinspect failed recovery")
	expect(altered.query("SELECT * FROM snapshot") and altered.query_result == before, "Failed recovery does not reset data")
	altered.close_db()
