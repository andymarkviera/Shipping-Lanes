extends SceneTree
const Bulk = preload("res://features/cargo/bulk_earnings.gd")
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const Ship = preload("res://features/catalog/records/bulk_ship.tres")
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")
var checks: int = 0
var failures: int = 0
var locations: Dictionary = {"port_brindle_quay": Geo.normalized(0, 0), "port_slatewater_works": Geo.normalized(0, rad_to_deg(1852.0 / Nav.RADIUS_M))}
var rates: Dictionary = {"cargo_bulk_grain": 100, "cargo_bulk_coal": 120, "cargo_bulk_ore": 150, "cargo_bulk_limestone": 80}
var modifiers: Dictionary = {"port_brindle_quay": 11000, "port_slatewater_works": 9000}
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func publish(service: RefCounted, id: String = "proof", grams: Variant = 123456789, cargo: String = "cargo_bulk_grain") -> Dictionary:
	return service.publish(id, cargo, grams, "hold_forward", "port_brindle_quay", "port_slatewater_works", locations, rates, modifiers)
func accept_load(service: RefCounted, manifest: RefCounted, id: String = "proof") -> void:
	check(service.accept(id, "captain", "owned_ship", "port_brindle_quay", manifest).ok, "accept quoted bulk")
	check(service.load_at(id, "captain", "owned_ship", "port_brindle_quay", manifest, true).ok, "load actual bulk manifest")
func discharge(service: RefCounted, manifest: RefCounted, action: String, grams: Variant, port: String = "port_slatewater_works", docked: bool = true) -> Dictionary:
	return service.discharge(action, "proof", "captain", "owned_ship", port, manifest, grams, docked)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var s = Bulk.new()
	var m = Manifest.new(Ship, PrototypeCatalog.RECORDS)
	var quote: Dictionary = publish(s)
	check(quote.ok and quote.offer.terms.direct_distance_m == 1852 and quote.offer.reward_minor == 12222, "worked quote: 123.456789t * 1NM * 1 credit * 1.1 * 0.9 = 122.22 credits")
	check(quote.message.contains("both included") and quote.message.contains("separate costs"), "quote includes every earning modifier and distinguishes gross")
	check(not publish(s).ok, "offer ID cannot replace frozen terms")
	check(s.advance_to(9000000000000) and s.view("proof").expires_ms == -1, "offer never expires")
	check(not s.load_at("proof", "captain", "owned_ship", "port_brindle_quay", m, true).ok, "must accept before loading")
	check(s.accept("proof", "captain", "owned_ship", "port_brindle_quay", m).ok, "accept")
	check(not s.load_at("proof", "captain", "owned_ship", "port_brindle_quay", m, false).ok, "loading needs docking")
	check(not s.load_at("proof", "captain", "owned_ship", "port_slatewater_works", m, true).ok, "loading needs origin")
	check(not s.load_at("proof", "stranger", "owned_ship", "port_brindle_quay", m, true).ok, "ownership required")
	check(publish(s, "second").ok and not s.accept("second", "captain", "owned_ship", "port_brindle_quay", m).ok, "one active nonexpiring job")
	check(not s.accept("container_seed_v1_0_0", "captain", "owned_ship", "port_brindle_quay", m).ok, "same job guard includes containers")
	check(s.load_at("proof", "captain", "owned_ship", "port_brindle_quay", m, true).ok, "load accepted grams")
	check(not s.load_at("proof", "captain", "owned_ship", "port_brindle_quay", m, true).ok and m.lines().size() == 1, "duplicate loading cannot mint cargo")
	var before: Array[Dictionary] = m.lines()
	for grams: Variant in [0, -1, 1.0, true, "1", 123456790]:
		check(not discharge(s, m, "bad", grams).ok and m.lines() == before, "bad quantity atomic rejection")
	check(not discharge(s, m, "bad", 1, "port_brindle_quay").ok, "wrong destination cannot earn")
	check(not discharge(s, m, "bad", 1, "port_slatewater_works", false).ok, "undocked cannot earn")
	check(not s.discharge("bad", "proof", "captain", "other_ship", "port_slatewater_works", m, 1, true).ok, "wrong ship cannot earn")
	var first: Dictionary = discharge(s, m, "part1", 50000000)
	check(first.ok and first.reward_minor == 4950 and m.lines()[0].quantity == 73456789, "50t partial pays exactly 49.50 and retains provenance")
	check(s.active_job("captain").id == "proof", "partial keeps job active")
	var replay: Dictionary = discharge(s, m, "part1", 50000000)
	check(replay.ok and replay.duplicate and replay.reward_minor == 0 and replay.receipt == first.receipt, "retry returns same receipt with zero new award")
	check(not discharge(s, m, "part1", 1).ok, "conflicting action cannot pay")
	# Caller modifications and later rates/port changes cannot rewrite published terms.
	quote.offer.terms.direct_distance_m = 999999
	rates.cargo_bulk_grain = 999999; modifiers.port_slatewater_works = 20000
	locations.port_slatewater_works = Geo.normalized(80, 150)
	var final_part: Dictionary = discharge(s, m, "part2", 73456789)
	check(final_part.reward_minor == 7272 and final_part.receipt.cumulative_reward_minor == 12222, "worked receipt equals frozen quote despite changed world/config")
	check(m.lines().is_empty() and s.active_job("captain").is_empty(), "final discharge releases hold and job")
	check(not discharge(s, m, "again", 1).ok, "completed job cannot pay again")
	print(final_part.message)
	# Full delivery hook uses the same receipt calculation.
	locations.port_slatewater_works = Geo.normalized(0, rad_to_deg(1852.0 / Nav.RADIUS_M))
	rates.cargo_bulk_grain = 100; modifiers.port_slatewater_works = 9000
	var direct = Bulk.new(); var detour = Bulk.new()
	var md = Manifest.new(Ship, PrototypeCatalog.RECORDS); var mt = Manifest.new(Ship, PrototypeCatalog.RECORDS)
	publish(direct); publish(detour); accept_load(direct, md); accept_load(detour, mt)
	var sailed: Dictionary = locations.port_brindle_quay
	for i: int in 1000: sailed = Nav.travel(sailed, 1000)
	detour.advance_to(9000000000000)
	check(direct.deliver_at("captain", "owned_ship", "port_slatewater_works", md, true).receipt == detour.deliver_at("captain", "owned_ship", "port_slatewater_works", mt, true).receipt, "million-metre sailing detour cannot raise receipt")
	# One gram fragments carry rounding dust forward; no per-fragment floor loss or exploit.
	var split = Bulk.new(); var ms = Manifest.new(Ship, PrototypeCatalog.RECORDS)
	publish(split, "proof", 1000001); accept_load(split, ms)
	var paid: int = 0
	for i: int in 101:
		var amount: int = 1 if i < 100 else 999901
		paid += discharge(split, ms, "fragment_%d" % i, amount).reward_minor
	check(paid == 99 and split.view("proof").reward_minor == paid, "101 fragments sum to one floor-rounded total")
	for cargo: String in rates:
		var commodity = Bulk.new(); var mc = Manifest.new(Ship, PrototypeCatalog.RECORDS)
		check(publish(commodity, "proof", 400000000, cargo).ok, "all four bulk commodities quoted")
		accept_load(commodity, mc)
		check(commodity.deliver_at("captain", "owned_ship", "port_slatewater_works", mc, true).ok, "all four commodities delivered")
	var bad = Bulk.new()
	for amount: Variant in [0, -1, 1.0, true, 1000000001]: check(not publish(bad, "bad", amount).ok, "invalid published quantity")
	check(not bad.publish("same", "cargo_bulk_grain", 1, "hold_forward", "port_brindle_quay", "port_brindle_quay", locations, rates, modifiers).ok, "same-port payout forbidden")
	modifiers.port_brindle_quay = -1
	check(not publish(bad).ok, "negative modifier fails closed")
	modifiers.port_brindle_quay = 20001
	check(not publish(bad).ok, "oversized modifier fails closed")
	modifiers.port_brindle_quay = 0
	check(publish(bad).ok and bad.view("proof").reward_minor == 0, "explicit zero modifier gives visible zero quote")
	# Existing container lifecycle still works through the shared registry.
	var containers = Bulk.new(); var cm = Manifest.new(PrototypeCatalog.RECORDS[0], PrototypeCatalog.RECORDS)
	check(containers.accept("container_seed_v1_0_0", "captain", "owned_ship", "port_brindle_quay", cm).ok, "container acceptance unchanged")
	check(containers.load_at("container_seed_v1_0_0", "captain", "owned_ship", "port_brindle_quay", cm, true).ok, "container loading unchanged")
	check(containers.deliver_at("captain", "owned_ship", "port_slatewater_works", cm, true).reward_minor == 25000, "container reward unchanged")
	modifiers.port_brindle_quay = 11000
	var guarded = Bulk.new(); var gm = Manifest.new(Ship, PrototypeCatalog.RECORDS)
	publish(guarded); accept_load(guarded, gm)
	var altered: Array[Dictionary] = gm.lines(); altered[0].quantity -= 1
	gm.replace(altered)
	check(not discharge(guarded, gm, "altered", 1).ok and guarded.view("proof").paid_minor == 0 and gm.lines() == altered, "mismatched cargo rejects without ledger or manifest mutation")
	var overfill = Bulk.new(); var om = Manifest.new(Ship, PrototypeCatalog.RECORDS)
	publish(overfill, "proof", 400000001)
	check(not overfill.accept("proof", "captain", "owned_ship", "port_brindle_quay", om).ok and om.lines().is_empty(), "load capacity reserved at acceptance")
	check(not guarded.accept("container_seed_v1_0_0", "captain", "owned_ship", "port_brindle_quay", gm).ok, "loaded bulk blocks container job")
	var locked = Bulk.new(); var lm = Manifest.new(Ship, PrototypeCatalog.RECORDS)
	publish(locked); accept_load(locked, lm)
	var callback_results: Array = []
	lm.changed.connect(func(): callback_results.append(discharge(locked, lm, "reentrant", 1)))
	check(discharge(locked, lm, "outer", 1).ok and callback_results.size() == 1 and not callback_results[0].ok, "manifest signal cannot reenter settlement")
	# Exact arithmetic vectors are generated independently with Python integers.
	var vectors: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bulk_earnings_vectors.json"))
	for vector: Dictionary in vectors:
		var terms: Dictionary = {}
		for key: String in vector.terms: terms[key] = int(vector.terms[key])
		check(Bulk.earnings(int(vector.grams), terms) == int(vector.expected), "independent exact rational vector")
	print("BULK_EARNINGS_PASS ", checks, " failures=", failures)
	quit(1 if failures else 0)
