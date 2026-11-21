extends RefCounted
## Patch 4.0 headless checks that need no scene: the boat lineup and the fishing
## boat's refund, the level curve, the airports, the plane jobs and the flight
## model (lift and stall, arcade controls with the auto-level (back in
## 4.0.1), the automatic gear, a scripted take-off and landing for every
## plane, a crash).
## check_catalog.gd (in the Checks job) runs these; tools/patch_4_0_check.gd
## runs them too, then the game-scene checks.
const Progression = preload("res://features/game/progression.gd")
const Levels = preload("res://features/game/levels.gd")
const Airports = preload("res://features/planes/airports.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Flight = preload("res://features/planes/flight_model.gd")
const Terrain = preload("res://features/planes/terrain.gd")
const Aviation = preload("res://features/planes/aviation.gd")
const Autopilot = preload("res://tools/flight_autopilot.gd")
const Hangar = preload("res://features/game/boat_hangar.gd")
const Store = preload("res://features/network/server_save_store.gd")
const STEP: float = 1.0 / 30.0

var checks: int = 0
var failures: PackedStringArray = []

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

## Runs every check; returns the failed labels (empty when all pass).
static func run_all() -> PackedStringArray:
	var suite: RefCounted = new()
	suite.boats()
	suite.levels()
	suite.airports()
	suite.jobs()
	suite.flight()
	suite.saves()
	return suite.failures

func boats() -> void:
	expect(not Progression.SMALL_KINDS.has("small_fishing") and not Progression.buyable("small_fishing"), "the fishing boat is not for sale")
	expect(Progression.SHIPS.small_speedboat.price_minor == 250000, "speedboat costs 2,500.00")
	expect(Progression.SHIPS.small_racer.price_minor == 1200000, "offshore racer costs 12,000.00")
	expect(Progression.SHIPS.small_jetty.price_minor == 3000000 and Progression.SHIPS.small_jetty.name == "Jetty", "the Jetty costs 30,000.00")
	expect(Progression.small_tier("small_jetty") > 0, "the Jetty is a small boat (no cargo jobs)")
	expect(Progression.definition("small_jetty").cargo_type_ids.is_empty(), "the Jetty carries no cargo")
	var jetty: float = Hangar.top_knots(Progression.definition("small_jetty"))
	var racer: float = Hangar.top_knots(Progression.definition("small_racer"))
	expect(absf(jetty - 5.0 * racer) < 0.05 * racer, "the Jetty's top speed is five times the racer's (%.0f vs %.0f kn)" % [jetty, racer])
	# The migration sells a fishing boat back at its full price.
	var price: int = int(Progression.SHIPS.small_fishing.price_minor)
	var save: Dictionary = {"version": 5, "fleet": {"small_fishing": {"fuel": 1.0, "condition": 1.0}, "container": {"fuel": 0.5, "condition": 0.9}},
		"ship": "small_fishing", "spent": price + 5000, "credits": 1000, "banked": 0, "heavy_mode": false, "fuel": 1.0, "condition": 1.0}
	var refund: int = Progression.retire_ships(save)
	expect(refund == price and save.credits == 1000 + price, "a fishing boat is refunded at its full price")
	expect(not save.fleet.has("small_fishing") and save.ship == "container", "the fishing boat leaves the fleet; the captain moves to their other ship")
	expect(save.spent == 5000, "the refund comes off the money spent (wallet = earned - spent)")
	expect(Progression.retire_ships(save) == 0, "the refund is paid once")
	var only: Dictionary = {"version": 5, "fleet": {"small_fishing": {"fuel": 1.0, "condition": 1.0}}, "ship": "small_fishing", "spent": 0, "credits": 0, "banked": 0, "heavy_mode": false}
	Progression.retire_ships(only)
	expect(only.ship == "container" and only.fleet.has("container") and only.credits == price and only.banked == price, "with no other ship the captain gets the starter, and the refund is banked")

func levels() -> void:
	expect(Levels.level_for(0) == 1 and Levels.fresh_progress().xp == 0, "everyone starts at level 1 with 0 XP")
	expect(Levels.level_for(Levels.xp_for_level(10)) == 10 and Levels.level_for(Levels.xp_for_level(10) - 1) == 9, "the level curve is consistent")
	var deliveries: int = ceili(float(Levels.xp_for_level(10)) / float(Levels.xp_for_pay(400000)))
	expect(deliveries >= 20 and deliveries <= 80, "level 10 takes a few hours of normal deliveries (%d at 4,000 credits)" % deliveries)
	expect(Levels.xp_for_pay(1000000) > Levels.xp_for_pay(100000) and Levels.xp_for_pay(0) == 0, "XP grows with the payout")
	expect(Levels.award(100, 50) == 150 and Levels.award(100, -50) == 100, "award only adds")
	expect(Levels.progress_valid(Levels.fresh_progress()), "a fresh progress row is valid")

func airports() -> void:
	var first: Array[Dictionary] = Airports.all().duplicate(true)
	expect(first.size() == Progression.WORLD.size(), "as many airports as ports (%d)" % first.size())
	Airports._cache.clear()
	expect(Airports.all() == first, "the airports are the same every time (fixed seed)")
	for index: int in first.size():
		var entry: Dictionary = first[index]
		expect(Terrain.sample(entry.at).surface == "runway" and Airports.runway_at(Airports.start_pose(index).origin) == index, "%s: its runway is under the start" % entry.name)
		for port: Dictionary in Progression.WORLD:
			expect(Vector2(entry.at.x - port.at.x, entry.at.z - port.at.z).length() >= Airports.PORT_CLEAR_M, "%s stands clear of %s" % [entry.name, port.get("id", "a port")])
		var along: Vector3 = Vector3(sin(entry.heading), 0, cos(entry.heading))
		for end: float in [-0.5, 0.5]:
			var tip: Vector3 = entry.at + along * entry.length * end * 0.98
			expect(Progression.land_depth(Vector2(tip.x, tip.z)) > 0.0 and Progression.ice_depth(Vector2(tip.x, tip.z)) < 0.0, "%s: the runway is on land, off the ice" % entry.name)

func jobs() -> void:
	for kind: String in Planes.ORDER:
		var board: Array[Dictionary] = Jobs.board(0, Planes.PLANES[kind])
		if int(Planes.PLANES[kind].capacity) <= 0:
			expect(board.is_empty(), "%s carries no cargo and is offered no jobs (Patch 4.0.1)" % kind)
			continue
		expect(not board.is_empty(), "%s has plane jobs at the first airport" % kind)
		for row: Dictionary in board:
			expect(int(row.capacity) <= int(Planes.PLANES[kind].capacity) and int(row.origin) == 0 and int(row.destination) != 0, "%s: a job it can carry to another airport" % kind)
			expect(row.kind in ["pax", "pkg"], "plane jobs are Passengers or Packages")
	expect(Jobs.job("air_0_0_pax_4").is_empty() and Jobs.job("bogus").is_empty(), "bad job IDs are refused")

func flight() -> void:
	for kind: String in Planes.ORDER:
		var p: Dictionary = Planes.PLANES[kind]
		var m: RefCounted = Flight.make(kind, Airports.start_pose(0))
		var stall: float = deg_to_rad(float(p.stall_deg))
		m.flaps = false
		expect(m.lift_coefficient(stall * 0.5) < m.lift_coefficient(stall) and m.lift_coefficient(stall + 0.2) < m.lift_coefficient(stall), "%s: lift grows to the stall, then falls away" % kind)
		expect(Planes.top_speed(kind) > Planes.stall_speed(kind) * 1.6, "%s: top speed well above the stall" % kind)
		expect(m.gear_down and m.on_ground and Airports.runway_at(m.position) == 0, "%s: parked on the runway, gear down" % kind)
		# A held bank turns the plane (coordinated); hands off, the auto-level
		# (back in Patch 4.0.1) rolls it gently wings-level (patch_4_0_1_logic).
		var cruise: Transform3D = Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3(1, 0, 0), -deg_to_rad(4.0)) * Basis(Vector3(0, 0, 1), deg_to_rad(30.0)), Vector3(0, 900, 0))
		m.on_ground = false
		m.basis = cruise.basis
		m.position = Airports.all()[0].at + Vector3(0, 900, 0)
		m.velocity = m.basis.z * Planes.stall_speed(kind) * 1.6
		m.engine = 0.7
		for frame: int in 90: m.step({"throttle": 0.7, "roll": 0.0, "pitch": 0.0}, STEP)
		expect(absf(rad_to_deg(m.full_bank())) < 30.0, "%s: hands off, the bank eases towards level (%.1f deg)" % [kind, rad_to_deg(m.full_bank())])
		# With a hand on the stick (a light pull, so no auto-level) a held bank
		# turns the plane: the coordinated turn.
		m.basis = cruise.basis
		m.velocity = m.basis.z * Planes.stall_speed(kind) * 1.6
		for frame: int in 90: m.step({"throttle": 0.7, "roll": 0.0, "pitch": Flight.LEVEL_INPUT + 0.01}, STEP)
		expect(absf(angle_difference(m.heading(), 0.4)) > 0.05, "%s: a held bank turns the plane (coordinated)" % kind)
		expect(not m.gear_down, "%s: the gear is up in cruise" % kind)
		# Too slow: the wing stalls and the assist lowers the nose until it flies.
		m.basis = Basis(Vector3(1, 0, 0), -deg_to_rad(40.0))
		m.velocity = m.basis.z * Planes.stall_speed(kind) * 0.5
		var stalled: bool = false
		for frame: int in 30 * 25:
			m.step({"throttle": 1.0, "pitch": 1.0}, STEP)
			stalled = stalled or m.stalled
		expect(stalled, "%s: it stalls when too slow" % kind)
		expect(not m.stalled and not m.crashed, "%s: the stall assist recovers it" % kind)
		# A scripted flight: take off, fly to the next airport, land and stop.
		m = Flight.make(kind, Airports.start_pose(0))
		var pilot: RefCounted = Autopilot.new(1)
		var gear_up: bool = false
		var gear_down_final: bool = false
		var seconds: float = 0.0
		while seconds < 1200.0 and not m.crashed:
			m.step(pilot.inputs(m), STEP)
			seconds += STEP
			gear_up = gear_up or (not m.on_ground and not m.gear_down)
			if pilot.phase == "final" and m.agl_m < 20.0 and not m.on_ground: gear_down_final = gear_down_final or m.gear_down
			if pilot.phase == "rollout" and m.airspeed() < 0.5: break
		expect(not m.crashed and pilot.phase == "rollout" and m.airspeed() < 0.5 and Airports.runway_at(m.position) == 1,
			"%s: scripted take-off and landing at the next airport (%s %s)" % [kind, pilot.phase, m.crash_reason])
		expect(gear_up and gear_down_final, "%s: the gear retracts after take-off and lowers for the landing" % kind)
		expect(m.fuel_l < float(p.fuel_l), "%s: the flight burns fuel" % kind)
		# Into the sea: a crash.
		var sea: Vector3 = Progression.gate(0)
		m.position = Vector3(sea.x, 6.0, sea.z)
		m.on_ground = false
		m.basis = Basis(Vector3(1, 0, 0), deg_to_rad(20.0))
		m.velocity = m.basis.z * 60.0
		for frame: int in 60: m.step({"throttle": 0.5}, STEP)
		expect(m.crashed and m.crash_reason.contains("sea"), "%s: flying into the sea is a crash" % kind)
	# Arcade mouse aim: right of a level plane rolls right; at 90 degrees of
	# bank the same cursor pulls; centred is nothing at all.
	expect(Aviation.aim_to_plane(Vector2(1, 0), 0.0).is_equal_approx(Vector2(1, 0)), "cursor right of a level plane: bank right")
	expect(Aviation.aim_to_plane(Vector2(1, 0), PI * 0.5).is_equal_approx(Vector2(0, 1)), "cursor right of a plane banked 90 degrees: pull")
	expect(Aviation.aim_to_plane(Vector2.ZERO, 0.7) == Vector2.ZERO, "cursor centred: no command")

func saves() -> void:
	# A 3.2 server save with a fishing boat loads; the boat is refunded.
	var text: String = FileAccess.get_file_as_string("res://tools/fixtures/server_saves/3.2-fishing.json")
	var envelope: Variant = JSON.parse_string(text)
	if not expect(envelope is Dictionary and envelope.has("payload"), "the 3.2 fishing fixture is present"): return
	var raw: Variant = bytes_to_var(Marshalls.base64_to_raw(str(envelope.payload)))
	if not expect(raw is Dictionary and int(raw.get("schema_version", -1)) == 1, "the fixture is schema 1 (3.x)"): return
	var migrated: Dictionary = Store.migrate(raw.duplicate(true))
	expect(not migrated.is_empty() and int(migrated.schema_version) == Store.SCHEMA_VERSION and Store.valid(migrated), "a 3.2 save migrates and is valid")
	for key: Variant in migrated.get("players", {}):
		var row: Dictionary = migrated.players[key]
		expect(not row.voyage.fleet.has("small_fishing") and row.voyage.ship != "small_fishing", "the fishing boat left the fleet")
		expect(row.progress == Levels.fresh_progress(), "old saves start at level 1 with 0 XP")
