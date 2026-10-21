extends Node
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func apply(ledger: EconomyLedger, id: String, operation: String, quantity: Variant = 1, revision: Variant = -1) -> Dictionary:
	return ledger.execute(EconomyLedger.PLAYER_ID, EconomyLedger.request(id, operation, quantity, ledger.view().revision if revision == -1 else revision))

func rejected_unchanged(ledger: EconomyLedger, request: Dictionary, expected: String) -> void:
	var before: Dictionary = ledger.view()
	var entries: Array = ledger.audit().entries
	var result: Dictionary = ledger.execute(EconomyLedger.PLAYER_ID, request)
	check(not result.ok and result.code == expected, "Expected rejection: " + expected)
	check(ledger.view() == before and ledger.audit().entries == entries, "Failure preserves all balances/inventories and committed journal")

func _ready() -> void:
	var ledger: EconomyLedger = EconomyLedger.new()
	var initial: Dictionary = ledger.view()
	var purchase: Dictionary = EconomyLedger.request("buy_1", "purchase_container", 1, 0)
	var result: Dictionary = ledger.execute(EconomyLedger.PLAYER_ID, purchase)
	check(result.ok and result.amount_minor == 10000 and result.revision == 1, "Server sets purchase price")
	check(ledger.view().player_minor == 10000 and ledger.view().system_minor == 1010000, "Both money sides commit")
	check(ledger.view().player_quantity == 1 and ledger.view().stock_quantity == 99, "Both cargo sides commit")
	var committed: Dictionary = ledger.view()
	result = ledger.execute(EconomyLedger.PLAYER_ID, purchase)
	check(result.ok and result.duplicate and ledger.view() == committed and ledger.audit().entries.size() == 1, "Repeated purchase neither charges nor grants twice")
	var mismatch: Dictionary = purchase.duplicate(true)
	mismatch.quantity = 2
	rejected_unchanged(ledger, mismatch, "id_conflict")
	check(apply(ledger, "deliver_1", "deliver_container").ok, "Game-funded delivery payout")
	check(ledger.view().player_minor == 15000 and ledger.view().player_quantity == 0 and ledger.view().delivered_quantity == 1, "Payment and surrendered cargo commit together")
	check(apply(ledger, "fee_1", "service_fee").ok and ledger.view().player_minor == 14000, "Game service fee debits once")
	var after: Dictionary = ledger.view()
	check(after.player_minor + after.system_minor == initial.player_minor + initial.system_minor, "Wallet ledger conserves fixture money")
	check(after.player_quantity + after.stock_quantity + after.delivered_quantity == 100, "Inventory transfers conserve cargo")
	var audit: Dictionary = ledger.audit()
	check(audit.entries.size() == 3 and audit.entries[2].quantity == 0, "Each committed operation has one balanced audit entry; service moves no cargo")
	audit.entries[0].amount_minor = 999
	result.amount_minor = 999
	after.player_minor = 999
	check(ledger.audit().entries[0].amount_minor == 10000 and ledger.view().player_minor == 14000, "Views and results cannot mutate ledger")
	rejected_unchanged(ledger, EconomyLedger.request("old", "purchase_container", 1, 0), "stale_revision")
	rejected_unchanged(ledger, EconomyLedger.request("no_load", "deliver_container", 1, 3), "insufficient_cargo")
	for value: Variant in [0, -1, 1.5, 1.0, true, "1", NAN, INF, GameUnits.MAX_INTEGER + 1]:
		rejected_unchanged(ledger, EconomyLedger.request("bad_quantity", "purchase_container", value, 3), "invalid_quantity_or_revision")
	rejected_unchanged(ledger, EconomyLedger.request("bad_revision", "service_fee", 1, true), "invalid_quantity_or_revision")
	rejected_unchanged(ledger, EconomyLedger.request("many_services", "service_fee", 2, 3), "invalid_quantity_or_revision")
	for operation: String in ["transfer", "gift", "trade_ship", "transfer_cargo"]:
		rejected_unchanged(ledger, EconomyLedger.request("peer", operation, 1, 3), "unsupported_operation")
	var peer: Dictionary = EconomyLedger.request("peer", "service_fee", 1, 3)
	peer.recipient = "another_player"
	rejected_unchanged(ledger, peer, "bad_request")
	peer.erase("recipient")
	peer.price_minor = 0
	rejected_unchanged(ledger, peer, "bad_request")
	var before_intruder: Dictionary = ledger.view()
	check(ledger.execute("another_player", purchase).code == "not_owner" and ledger.view() == before_intruder, "Other player cannot execute or retrieve receipts")
	for seed: Dictionary in [{"system_minor": GameUnits.MAX_INTEGER}, {"player_quantity": GameUnits.MAX_INTEGER}, {"revision": GameUnits.MAX_INTEGER}]:
		var bounded: EconomyLedger = EconomyLedger.new(seed)
		rejected_unchanged(bounded, EconomyLedger.request("overflow", "purchase_container", 1, bounded.view().revision), "limit_reached")
	var too_large: EconomyLedger = EconomyLedger.new({"player_minor": GameUnits.MAX_INTEGER})
	rejected_unchanged(too_large, EconomyLedger.request("multiply", "purchase_container", GameUnits.MAX_INTEGER, 0), "limit_reached")
	var delivery_full: EconomyLedger = EconomyLedger.new({"player_quantity": 1, "delivered_quantity": GameUnits.MAX_INTEGER})
	rejected_unchanged(delivery_full, EconomyLedger.request("full", "deliver_container", 1, 0), "limit_reached")
	var empty_stock: EconomyLedger = EconomyLedger.new({"stock_quantity": 0})
	rejected_unchanged(empty_stock, EconomyLedger.request("empty", "purchase_container", 1, 0), "insufficient_cargo")
	var empty_system: EconomyLedger = EconomyLedger.new({"system_minor": 0, "player_quantity": 1})
	rejected_unchanged(empty_system, EconomyLedger.request("unfunded", "deliver_container", 1, 0), "insufficient_funds")
	var broke: EconomyLedger = EconomyLedger.new({"player_minor": 0, "player_quantity": 3})
	var failed: Dictionary = EconomyLedger.request("retry", "purchase_container", 1, 0)
	check(broke.execute(EconomyLedger.PLAYER_ID, failed).code == "insufficient_funds", "Insufficient funds recorded")
	check(apply(broke, "fund", "deliver_container", 3).ok, "Later game payout increases funds")
	var funded: Dictionary = broke.view()
	result = broke.execute(EconomyLedger.PLAYER_ID, failed)
	check(result.duplicate and result.code == "insufficient_funds" and broke.view() == funded, "Retry of failed request cannot turn into a later charge")
	check(apply(broke, "new_purchase", "purchase_container").ok, "New intent may use new balance")
	var cap: EconomyLedger = EconomyLedger.new({}, 2)
	check(apply(cap, "first", "service_fee").ok and apply(cap, "second", "service_fee").ok, "Bounded receipt store accepts capacity")
	rejected_unchanged(cap, EconomyLedger.request("third", "service_fee", 1, 2), "receipt_capacity")
	result = cap.execute(EconomyLedger.PLAYER_ID, EconomyLedger.request("first", "service_fee", 1, 0))
	check(result.ok and result.duplicate and cap.view().player_minor == 18000, "Full receipt store retains successful outcomes")
	var exact: EconomyLedger = EconomyLedger.new({"player_minor": EconomyLedger.SERVICE_MINOR, "system_minor": GameUnits.MAX_INTEGER - EconomyLedger.SERVICE_MINOR})
	check(apply(exact, "boundary", "service_fee").ok and exact.view().player_minor == 0 and exact.view().system_minor == GameUnits.MAX_INTEGER, "Exact zero and maximum boundaries commit safely")
	var serial: EconomyLedger = EconomyLedger.new()
	check(apply(serial, "a", "service_fee", 1, 0).ok, "First same-revision intent commits")
	rejected_unchanged(serial, EconomyLedger.request("b", "service_fee", 1, 0), "stale_revision")
	var bad_seed: EconomyLedger = EconomyLedger.new({"player_minor": -1})
	check(apply(bad_seed, "disabled", "service_fee").code == "invalid_fixture", "Invalid fixture cannot transact")
	var session: SessionAuthority = SessionAuthority.new()
	check(session.request_economy("player_test", "ship_test", purchase).ok, "Session routes economy to ledger")
	check(session.request_economy("player_test", "ship_test", purchase).receipt.duplicate and session.view().player.wallet_minor == 10000, "Session retry keeps receipt and current state")
	check(session.economy_audit().entries.size() == 1, "Playable test session uses audited commit")
	print("ECONOMY_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
