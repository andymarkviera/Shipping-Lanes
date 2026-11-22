extends RefCounted
## Patch 4.0.3 headless checks that need no scene (Andy's playtest of 4.0.2,
## issue #226): the keyboard-only flight (W / S released, the plane holds its
## altitude within 20 m for 30 s; A / D never bank past the limit; Space is
## the brakes; Shift / Ctrl move a lever that stays put); every port's berth
## takes every ship class (the heavy lifters too: Cinder Point lacked the
## heavy service); the plane job cards' trip estimates; the throttle widget's
## 0-100% plane range; Point Nemo (its port and runway); the polar runways
## (Cinder Strip on the north cap, South Runway on the south) keep their
## indexes; the plane job's globe course; VERSION is 4.0.3.
## check_catalog.gd (in the Checks job) runs these; tools/patch_4_0_3_check.gd
## runs them too, then the game-scene checks.
const Progression = preload("res://features/game/progression.gd")
const Airports = preload("res://features/planes/airports.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Flight = preload("res://features/planes/flight_model.gd")
const Aviation = preload("res://features/planes/aviation.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Hud = preload("res://features/game/game_hud.gd")
const STEP: float = 1.0 / 30.0
const PARTS: Array[String] = ["version", "altitude_hold", "bank_keys", "brakes_and_lever", "berths", "trips", "throttle_widget", "point_nemo", "polar_runways"]

var checks: int = 0
var failures: PackedStringArray = []

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

## Runs every check; returns the failed labels (empty when all pass).
static func run_all() -> PackedStringArray:
	var suite: RefCounted = new()
	for part: String in PARTS: suite.call(part)
	return suite.failures

func version() -> void:
	var connection: GDScript = load("res://features/network/play_connection.gd")
	expect(connection.VERSION.naturalnocasecmp_to("4.0.3") >= 0, "VERSION is 4.0.3 or later (%s)" % connection.VERSION)

## A plane in level cruise high over the first airport.
func cruise(kind: String) -> RefCounted:
	var m: RefCounted = Flight.make(kind, Airports.start_pose(0))
	m.on_ground = false
	m.position = Airports.all()[0].at + Vector3(0, 3000, 0)
	m.basis = Basis(Vector3.UP, 0.4)
	m.velocity = m.basis.z * Planes.stall_speed(kind) * 2.0
	m.engine = 0.7
	m.gear_down = false
	m.agl_m = 3000.0
	return m

func fly(pilot: Node, m: RefCounted, pitch: float, turn: float, seconds: float) -> void:
	for frame: int in roundi(seconds / STEP):
		var order: Dictionary = pilot.key_order(pitch, turn, 0.0, false, STEP)
		m.step({"throttle": order.throttle, "pitch": order.pitch, "roll": order.roll, "trick": order.yaw}, STEP)
		if m.crashed: return

## Item 1: W / S released, the plane holds its altitude (within 20 m over
## 30 s): from level flight, and after a climb or a descent.
func altitude_hold() -> void:
	var pilot: Node = Aviation.new()
	for kind: String in Planes.ORDER:
		for before: float in [0.0, 1.0, -1.0]:
			var m: RefCounted = cruise(kind)
			pilot.model = m
			pilot.lever = 0.7
			pilot.barrel = 0.0
			pilot.barrel_key = 0.0
			if before != 0.0: fly(pilot, m, before, 0.0, 3.0)
			# After a climb or a descent the plane first levels off (a fast
			# plane on a steep path cannot stop at once); the altitude it
			# captures is then held. The level-off must be quick and short.
			var released: float = m.position.y
			var settle: float = 0.0
			while is_nan(m.hold_altitude) and settle < 15.0 and not m.crashed:
				var easing: Dictionary = pilot.key_order(0.0, 0.0, 0.0, false, STEP)
				m.step({"throttle": easing.throttle, "pitch": easing.pitch, "roll": easing.roll, "trick": easing.yaw}, STEP)
				settle += STEP
			expect(settle < 15.0, "%s: keys released, the plane levels off and captures an altitude (%.1f s, %.0f m past)" % [kind, settle, absf(m.position.y - released)])
			var start: float = m.position.y if is_nan(m.hold_altitude) else m.hold_altitude
			var worst: float = 0.0
			for frame: int in roundi(30.0 / STEP):
				var order: Dictionary = pilot.key_order(0.0, 0.0, 0.0, false, STEP)
				m.step({"throttle": order.throttle, "pitch": order.pitch, "roll": order.roll, "trick": order.yaw}, STEP)
				worst = maxf(worst, absf(m.position.y - start))
				if m.crashed: break
			var what: String = "level" if before == 0.0 else ("after W" if before > 0.0 else "after S")
			expect(not m.crashed and worst <= 20.0, "%s: keys released (%s), the altitude holds within 20 m for 30 s (%.1f m)" % [kind, what, worst])
	pilot.free()

## Item 1: A / D held (with or without W / S) never bank past the limit,
## turn the way pressed, and roll level when released.
func bank_keys() -> void:
	var pilot: Node = Aviation.new()
	for kind: String in Planes.ORDER:
		var limit: float = rad_to_deg(Flight.make(kind, Airports.start_pose(0)).bank_limit())
		for turn: float in [-1.0, 1.0]:
			var m: RefCounted = cruise(kind)
			pilot.model = m
			pilot.lever = 0.7
			var worst: float = 0.0
			# (Patch 4.0.7: the turn is fast enough to come full circle in 15 s,
			# so the heading change is added up, not read at the end.)
			var turned: float = 0.0
			for frame: int in roundi(15.0 / STEP):
				var order: Dictionary = pilot.key_order(0.0, turn, 0.0, false, STEP)
				var before: float = m.heading()
				m.step({"throttle": order.throttle, "pitch": order.pitch, "roll": order.roll, "trick": order.yaw}, STEP)
				turned += absf(angle_difference(before, m.heading()))
				worst = maxf(worst, absf(rad_to_deg(m.full_bank())))
			var key: String = "D" if turn > 0.0 else "A"
			expect(worst <= limit + 0.5 and worst >= limit * 0.5, "%s: %s banks up to, never past, %.0f degrees (%.1f)" % [kind, key, limit, worst])
			expect(turned > deg_to_rad(20.0), "%s: %s turns the plane (%.0f degrees)" % [kind, key, rad_to_deg(turned)])
			fly(pilot, m, 0.0, 0.0, 8.0)
			expect(absf(rad_to_deg(m.full_bank())) < 3.0, "%s: %s released, it rolls level (%.1f)" % [kind, key, rad_to_deg(m.full_bank())])
	pilot.free()

## Item 1: Space is the brakes (a negative throttle, as the server expects);
## Shift / Ctrl move a lever that stays where it is set.
func brakes_and_lever() -> void:
	var pilot: Node = Aviation.new()
	pilot.model = Flight.make("plane_prop", Airports.start_pose(0))
	pilot.lever = 0.5
	var braking: Dictionary = pilot.key_order(0.0, 0.0, 0.0, true, STEP)
	expect(float(braking.throttle) < 0.0, "Space sends the brakes (a negative throttle)")
	pilot.order = braking
	expect(float(pilot.flight_input().brake) >= 0.99 and float(pilot.flight_input().throttle) == 0.0, "the brakes are full on, the engine at idle")
	var rolling: Dictionary = pilot.key_order(0.0, 0.0, 0.0, false, STEP)
	expect(is_equal_approx(float(rolling.throttle), 0.5), "released, the lever is where it was set (%.2f)" % float(rolling.throttle))
	expect(pilot.model.on_ground and pilot.barrel == 0.0, "no barrel roll on the ground")
	pilot.free()

## Item 4: every port's berth offers what every ship class docks for: the
## container service (container, bulk and small boats) and the heavy
## service with industrial cargo (the heavy lifters). Cinder Point lacked
## the heavy one, so heavy lifters were refused there.
func berths() -> void:
	for entry: Dictionary in Progression.WORLD:
		var id: String = str(entry.id)
		var port: PortDefinition = load("res://features/ports/%s.tres" % id.trim_prefix("port_")) as PortDefinition
		if not expect(port != null, "%s has its port record" % id): continue
		var berth: BerthDefinition = load("res://features/ports/%s_berth.tres" % id.trim_prefix("port_")) as BerthDefinition
		if not expect(berth != null and port.berth_ids.has(berth.id), "%s has its berth" % id): continue
		for service: String in ["container_transfer", "heavy_transfer"]:
			expect(berth.service_ids.has(service) and port.service_ids.has(service), "%s offers %s" % [id, service])
		for cargo: String in ["cargo_test_container", "cargo_test_industrial"]:
			expect(berth.cargo_type_ids.has(cargo), "%s's berth takes %s" % [id, cargo])
		# The widest and longest buyable hull fits the berth's envelope.
		for kind: String in Progression.SHIPS:
			if not Progression.buyable(kind): continue
			var hull: Vector3 = Progression.definition(kind).hull_size_m
			expect(hull.x < berth.envelope_m.x and hull.z < berth.envelope_m.z, "%s fits %s's berth (%.0f x %.0f m)" % [kind, id, hull.x, hull.z])

## Item 6: the plane job cards' trip line: km, minutes at cruise and fuel,
## every card on every board, the fuel within the plane's tank.
func trips() -> void:
	expect(Jobs.trip("nonsense", "plane_prop").is_empty() and Jobs.trip(Jobs.make_id(0, 1, "pax", 4), "nonsense").is_empty(), "no trip for an unknown job or plane")
	for kind: String in Planes.ORDER:
		var plane: Dictionary = Planes.PLANES[kind]
		for origin: int in Airports.count():
			for row: Dictionary in Jobs.board(origin, plane):
				var trip: Dictionary = Jobs.trip(str(row.id), kind)
				expect(not trip.is_empty() and is_equal_approx(float(trip.km), Jobs.leg_km(origin, int(row.destination))), "%s %s: the card shows the leg's km" % [kind, row.id])
				var minutes: float = float(trip.km) * 1000.0 / (Planes.top_speed(kind) * Jobs.CRUISE_SHARE) / 60.0
				expect(int(trip.minutes) >= 1 and int(trip.minutes) >= floori(minutes) and int(trip.minutes) <= ceili(minutes) + 1, "%s %s: the minutes at cruise (%d)" % [kind, row.id, int(trip.minutes)])
				expect(float(trip.fuel_l) > 0.0, "%s %s: the fuel needed (%.0f L)" % [kind, row.id, float(trip.fuel_l)])

## Addendum: flying, the throttle widget is 0-100% (no reverse).
func throttle_widget() -> void:
	expect(Hud.PLANE_MARKS == ["0%", "50%", "100%"] and Hud.BOAT_MARKS == ["R", "N", "D"], "the slider is marked 0% / 50% / 100% flying, R / N / D sailing")

## Item 7: Point Nemo, its port and its runway, out in the empty ocean.
func point_nemo() -> void:
	var index: int = Progression.port_index("port_point_nemo")
	if not expect(index >= 0, "Point Nemo is a port"): return
	var port_at: Vector3 = Progression.WORLD[index].at
	var runway: Dictionary = Airports.all()[index] if index < Airports.count() else {}
	expect(str(runway.get("name", "")) == "Point Nemo", "Point Nemo has a runway (%s)" % str(runway.get("name", "")))
	if runway.is_empty(): return
	var near: float = Vector2(runway.at.x - port_at.x, runway.at.z - port_at.z).length()
	expect(near < 2000.0, "the runway is on Point Nemo's island, beside the port (%.0f m)" % near)
	for other: int in Progression.WORLD.size():
		if other == index: continue
		var gap: float = Progression.short_way(Progression.WORLD[other].at - port_at).length()
		expect(gap > 2400.0, "%s is far from Point Nemo (%.0f m)" % [Progression.WORLD[other].id, gap])

## Item 8: Cinder Strip on the north cap, Gannet Aerodrome now South Runway
## on the south cap, both at their old indexes (saves and job IDs follow).
func polar_runways() -> void:
	var list: Array[Dictionary] = Airports.all()
	expect(list[2].name == "Cinder Strip" and Airports.polar(2), "Cinder Strip is on the polar ice (index 2)")
	expect(list[3].name == "South Runway" and Airports.polar(3), "Gannet Aerodrome is now South Runway, on the polar ice (index 3)")
	expect(list[2].at.z > 0.0 and list[3].at.z < 0.0, "Cinder Strip in the north, South Runway in the south")
	for index: int in [2, 3]:
		expect(list[index].at.distance_to(Airports.MOVED_FROM[index]) > 1000.0, "%s moved from where it stood" % list[index].name)
		var job: Dictionary = Jobs.job(Jobs.make_id(0, index, "pax", 4))
		expect(not job.is_empty() and int(job.destination) == index, "an old job to %s still flies there" % list[index].name)
