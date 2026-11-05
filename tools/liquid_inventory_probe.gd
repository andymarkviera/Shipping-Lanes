extends SceneTree
const Inventory = preload("res://features/cargo/liquid_inventory.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func intent(id: String, kind: String, amount: Variant, lot: String = "lot_1") -> Dictionary:
	return {"id": id, "kind": kind, "barrels": amount, "lot": lot,
		"owner": Inventory.OWNER, "ship": Inventory.SHIP,
		"port": Inventory.BUY_PORT if kind == "buy" else Inventory.SELL_PORT}
func trade(s: RefCounted, r: Dictionary) -> Dictionary:
	return s.transact(r, r.port, true)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var mode: String = "suite"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--oil-mode="): mode = arg.get_slice("=", 1)
	var s = Inventory.new()
	check(s.open("user://oil-proof/inventory.sqlite"), "open isolated inventory")
	if mode == "suite": suite(s)
	elif mode == "seed": check(s.capture().credits == 20000, "initial funds")
	elif mode in ["buy_before", "buy_after", "sell_before", "sell_after"]:
		var stage: String = "before_commit" if mode.ends_with("before") else "after_commit"
		s._store.fault_hook = func(point: String) -> void:
			if point == stage:
				print("OIL_KILL_READY")
				while true: OS.delay_msec(50)
		trade(s, intent("buy1", "buy", 123) if mode.begins_with("buy") else intent("sell1", "sell", 50))
	elif mode == "verify_empty": check(s.capture().credits == 20000 and s.capture().lots.is_empty(), "buy rollback")
	elif mode == "verify_loaded":
		check(s.capture().credits == 4625 and s.capture().lots.lot_1.remaining_barrels == 123, "buy committed once")
		check(trade(s, intent("buy1", "buy", 123)).wallet_delta_minor == 0, "durable buy replay")
	elif mode == "verify_partial":
		check(s.capture().credits == 13375 and s.capture().lots.lot_1.remaining_barrels == 73, "partial sale committed")
		check(trade(s, intent("sell1", "sell", 50)).wallet_delta_minor == 0, "durable sell replay")
	elif mode == "finish": check(trade(s, intent("sell2", "sell", 73)).ok, "sell remainder")
	elif mode == "verify_final":
		check(s.capture().credits == 26150 and s.capture().manifest.is_empty(), "final wallet and cargo")
		check(s.capture().lots.lot_1.realized_profit_minor == 6150, "realized sold-lot profit")
		check(trade(s, intent("sell2", "sell", 73)).wallet_delta_minor == 0, "final replay")
	s.close()
	print("OIL_PASS ", mode, " checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
func suite(s: RefCounted) -> void:
	var before: Dictionary = s.capture()
	var unopened = Inventory.new()
	check(not trade(unopened, intent("unopened", "buy", 1)).ok, "no nondurable trading mode")
	var malformed: Dictionary = intent("missing", "buy", 1); malformed.erase("lot")
	check(not trade(s, malformed).ok and s.capture() == before, "missing lot rejected")
	malformed = intent("price", "buy", 1); malformed["price"] = 0
	check(not trade(s, malformed).ok and s.capture() == before, "caller cannot supply price")
	for amount: Variant in [0, -1, 1.0, "1", true, null, 1000000001, 9223372036854775807]:
		check(not trade(s, intent("invalid", "buy", amount)).ok and s.capture() == before, "invalid quantity leaves state intact")
	check(not trade(s, intent("cash", "buy", 161)).ok and s.capture() == before, "cash limits purchase")
	check(not s.transact(intent("dock", "buy", 1), Inventory.BUY_PORT, false).ok, "must dock")
	check(not s.transact(intent("port", "buy", 1), Inventory.SELL_PORT, true).ok, "authoritative port")
	for field: String in ["owner", "ship", "port", "kind"]:
		var bad: Dictionary = intent("bad", "buy", 1); bad[field] = "foreign"
		check(not trade(s, bad).ok and s.capture() == before, "reject foreign " + field)
	check(trade(s, intent("buy1", "buy", 160)).ok, "exact cash purchase")
	check(s.capture().credits == 0 and s.capture().lots.lot_1.acquisition_cost_minor == 20000, "pay once and retain cost")
	before = s.capture()
	check(trade(s, intent("buy1", "buy", 160)).wallet_delta_minor == 0 and s.capture() == before, "purchase retry")
	var replay_copy: Dictionary = trade(s, intent("buy1", "buy", 160))
	replay_copy.receipt.cost_basis_minor = 0
	check(s.capture() == before, "receipt copy cannot change paid cost")
	check(not trade(s, intent("buy1", "buy", 159)).ok and s.capture() == before, "conflicting replay")
	check(not trade(s, intent("second", "buy", 1, "other")).ok, "one active lot")
	check(not trade(s, intent("over", "sell", 161)).ok, "cannot oversell")
	check(not trade(s, intent("wrong_lot", "sell", 1, "other")).ok, "cannot sell foreign lot")
	check(trade(s, intent("partial", "sell", 53)).receipt.realized_profit_minor == 2650, "partial cost basis")
	for i: int in 107:
		check(trade(s, intent("fragment_%d" % i, "sell", 1)).ok, "fragment sells exactly once")
	check(not trade(s, intent("reuse", "buy", 1)).ok, "sold acquisition lot ID cannot be reused")
	check(s.capture().credits == 28000 and s.capture().lots.lot_1.realized_profit_minor == 8000, "fragment-independent profit")
	before = s.capture()
	check(not trade(s, intent("capacity", "buy", 201, "lot_2")).ok and s.capture() == before, "capacity limits cash-rich purchase")
	check(trade(s, intent("buy2", "buy", 200, "lot_2")).ok, "exact capacity custom purchase")
	before = s.capture()
	var copy = Inventory.new()
	check(copy.restore(bytes_to_var(var_to_bytes(before))) and copy.capture() == before, "object-free round trip")
	for field: String in before:
		var bad: Dictionary = before.duplicate(true); bad[field] = null
		check(not copy.restore(bad) and copy.capture() == before, "reject malformed " + field)
	var tampered: Dictionary = before.duplicate(true)
	tampered.lots.lot_2.acquisition_cost_minor = 0
	check(not Inventory.valid(tampered), "reject altered cost basis")
	tampered = before.duplicate(true); tampered.events.append(tampered.events[0])
	check(not Inventory.valid(tampered), "reject duplicate history")
	var exposed: Dictionary = s.capture(); exposed.lots.clear(); exposed.manifest.clear()
	check(s.capture() == before, "snapshot cannot mutate authority")
	var stale = Inventory.new()
	check(stale.open("user://oil-proof/inventory.sqlite"), "second writer opens")
	check(trade(s, intent("sold2", "sell", 1, "lot_2")).ok, "first writer commits")
	var stale_before: Dictionary = stale.capture()
	check(not trade(stale, intent("stale", "sell", 1, "lot_2")).ok and stale.blocked and stale.capture() == stale_before, "stale writer fenced with no published mutation")
	stale.close()
