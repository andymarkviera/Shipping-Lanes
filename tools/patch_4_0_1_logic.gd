extends RefCounted
## Patch 4.0.1 headless checks that need no scene (Andy's first plane playtest,
## issue #222): the auto-level returns the plane to wings-level hands off and
## never fights a command; a sloppy approach (off the centre line, a little
## fast and high, coarse inputs, no flare) lands and stops for every plane at
## every airport; the crash view lasts about 4 s; the Fighter jet is at least
## twice the Cargo jet's top speed, the fastest thing in the game, carries no
## cargo and takes no jobs, and its motion replicates unclipped; the Cargo jet
## has turbofans and no flame; planes open at level 1; no terrain rises above
## the runway anywhere inside an airport's footprint and the airfield faces
## up (not a black slab); old saves load; VERSION is 4.0.1.
## check_catalog.gd (in the Checks job) runs these; tools/patch_4_0_1_check.gd
## runs them too, then the game-scene checks.
const Progression = preload("res://features/game/progression.gd")
const Levels = preload("res://features/game/levels.gd")
const Airports = preload("res://features/planes/airports.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Flight = preload("res://features/planes/flight_model.gd")
const Terrain = preload("res://features/planes/terrain.gd")
const Look = preload("res://features/planes/plane_look.gd")
const Aviation = preload("res://features/planes/aviation.gd")
const Autopilot = preload("res://tools/flight_autopilot.gd")
const Hangar = preload("res://features/game/boat_hangar.gd")
const Codec = preload("res://features/network/public_snapshot_codec.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
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
	for part: String in ["version", "auto_level", "sloppy_landing", "crash_view", "fighter", "turbofans", "gate", "airfields", "saves"]: suite.call(part)
	return suite.failures

func version() -> void:
	var connection: GDScript = load("res://features/network/play_connection.gd")
	# Patch 4.0.2: later patches move VERSION on; 4.0.1 or newer.
	expect(connection.VERSION.naturalnocasecmp_to("4.0.1") >= 0, "VERSION is 4.0.1 or later (%s)" % connection.VERSION)

## Item 1: hands off (no pitch or roll), a banked, climbing plane rolls
## wings-level and settles into level flight. Patch 4.0.3 item 1: the keys
## are the commands (W / S, A / D); released, the auto-trim takes over.
func auto_level() -> void:
	for kind: String in Planes.ORDER:
		var m: RefCounted = Flight.make(kind, Airports.start_pose(0))
		m.on_ground = false
		m.position = Airports.all()[0].at + Vector3(0, 1500, 0)
		m.basis = Basis(Vector3.UP, 0.4) * Basis(Vector3(1, 0, 0), -deg_to_rad(8.0)) * Basis(Vector3(0, 0, 1), deg_to_rad(40.0))
		m.velocity = m.basis.z * Planes.stall_speed(kind) * 2.2
		m.engine = 0.6
		var fastest: float = 0.0
		var last_bank: float = m.full_bank()
		for frame: int in 30 * 20:
			m.step({"throttle": 0.6, "pitch": 0.0, "roll": 0.0}, STEP)
			fastest = maxf(fastest, absf(m.full_bank() - last_bank) / STEP)
			last_bank = m.full_bank()
		expect(not m.crashed and absf(rad_to_deg(m.full_bank())) < 2.0, "%s: hands off, the wings come level (%.1f deg)" % [kind, rad_to_deg(m.full_bank())])
		expect(absf(rad_to_deg(m.path_angle())) < 1.5, "%s: hands off, it holds level flight (path %.1f deg)" % [kind, rad_to_deg(m.path_angle())])
		expect(rad_to_deg(fastest) <= float(Planes.PLANES[kind].roll_dps) * 1.1, "%s: it rolls level no faster than its roll rate (%.0f deg/s)" % [kind, rad_to_deg(fastest)])
		# A held D is never fought: the plane banks to the right at once.
		m.basis = Basis(Vector3.UP, 0.4)
		m.velocity = m.basis.z * Planes.stall_speed(kind) * 2.2
		for frame: int in 15: m.step({"throttle": 0.6, "roll": 1.0}, STEP)
		expect(rad_to_deg(m.full_bank()) > 3.0, "%s: a held D banks the plane (%.1f deg)" % [kind, rad_to_deg(m.full_bank())])

## Item 2: the sloppy pilot (tools/flight_autopilot.gd) lands and stops on
## the airfield, for every plane, at every airport, from two messy set-ups.
func sloppy_landing() -> void:
	for kind: String in Planes.ORDER:
		var landed: int = 0
		var tries: int = 0
		var notes: PackedStringArray = []
		for destination: int in Airports.count():
			for setup: Array in [[110.0, 9.0, 25.0, 1.4], [-140.0, -11.0, 15.0, 1.5]]:
				tries += 1
				var m: RefCounted = Flight.make(kind, Airports.start_pose(destination))
				var pilot: RefCounted = Autopilot.new(destination)
				pilot.sloppy_start(m, 3000.0, float(setup[0]), deg_to_rad(float(setup[1])), float(setup[2]), float(setup[3]))
				var seconds: float = 0.0
				var sink: float = 0.0
				var touched: bool = false
				while seconds < 240.0 and not m.crashed:
					var falling: float = -m.velocity.y
					var was_air: bool = not m.on_ground
					m.step(pilot.sloppy_inputs(m), STEP)
					seconds += STEP
					if was_air and m.on_ground and not touched:
						touched = true
						sink = falling
					if m.on_ground and m.airspeed() < 0.5: break
				if not m.crashed and m.on_ground and m.airspeed() < 0.5 and Airports.airfield_at(m.position) == destination and sink <= Flight.MAX_SINK_MPS: landed += 1
				else: notes.append("%s %s: %s" % [Airports.all()[destination].name, setup, m.crash_reason if m.crashed else "did not stop on the airfield"])
		expect(landed == tries, "%s: a sloppy approach lands and stops safely at every airport (%d of %d) %s" % [kind, landed, tries, ", ".join(notes)])

## Item 3: the crash view lasts about 4 s.
func crash_view() -> void:
	expect(Aviation.CRASH_VIEW_S >= 3.5 and Aviation.CRASH_VIEW_S <= 4.5, "the crash view lasts about 4 s (%.1f)" % Aviation.CRASH_VIEW_S)

## Item 4: the Fighter jet.
func fighter() -> void:
	expect(Planes.PLANES.has("plane_fighter") and Planes.ORDER.has("plane_fighter"), "the Fighter jet is in the catalog and the Planes menu")
	if not Planes.PLANES.has("plane_fighter"): return
	var p: Dictionary = Planes.PLANES.plane_fighter
	var jet: Dictionary = Planes.PLANES.plane_jet
	expect(p.name == "Fighter jet" and int(p.price_minor) == 300000000, "the Fighter jet costs 3,000,000.00")
	var top: float = Planes.top_speed("plane_fighter")
	expect(top >= 2.0 * Planes.top_speed("plane_jet"), "the Fighter jet is at least twice the Cargo jet's top speed (%.0f vs %.0f kn)" % [top * 1.944, Planes.top_speed("plane_jet") * 1.944])
	for kind: String in Planes.ORDER:
		if kind != "plane_fighter": expect(top > Planes.top_speed(kind) and float(p.roll_dps) > float(Planes.PLANES[kind].roll_dps) and float(p.pitch_dps) > float(Planes.PLANES[kind].pitch_dps), "the Fighter jet outruns and outturns the %s" % Planes.PLANES[kind].name)
	for kind: String in Progression.SHIPS:
		var definition: ShipDefinition = Progression.definition(kind)
		if definition != null: expect(top > Hangar.top_knots(definition) * 0.514444, "the Fighter jet is faster than the %s" % Progression.SHIPS[kind].name)
	expect(float(p.fuel_l) < float(jet.fuel_l) and Planes.endurance_s("plane_fighter") < Planes.endurance_s("plane_jet"), "the Fighter jet has a small tank (%.0f min)" % (Planes.endurance_s("plane_fighter") / 60.0))
	expect(int(p.capacity) == 0 and p.jobs.is_empty(), "the Fighter jet carries no cargo")
	for origin: int in Airports.count(): expect(Jobs.board(origin, p).is_empty(), "the Fighter jet is offered no jobs at %s" % Airports.all()[origin].name)
	var model: Node3D = Look.model("plane_fighter")
	expect(model.find_child("JetFlame", true, false) != null and model.find_child("Gear", true, false) != null, "the Fighter jet has its afterburner flame")
	model.free()
	# It flies: from the runway at full throttle it lifts off and climbs away.
	var m: RefCounted = Flight.make("plane_fighter", Airports.start_pose(0))
	var pilot: RefCounted = Autopilot.new(1)
	for frame: int in 30 * 40: m.step(pilot.inputs(m), STEP)
	expect(not m.crashed and not m.on_ground and m.agl_m > 50.0, "the Fighter jet takes off (%s)" % m.crash_reason)
	# Replication at its speed: a full-speed dive round-trips through the
	# motion frame unclipped (Patch 4.0 clamped the climb rate at 500 m/s).
	var basis: Basis = Basis(Vector3(1, 0, 0), deg_to_rad(70.0))
	var own: Dictionary = {"ack": 7, "position": Vector3(1200.5, 0, -3400.25), "yaw": 0.3, "velocity": Vector3(230.0, 0, 120.0),
		"ground_speed": 260.0, "yaw_rate": 0.0, "engine": 1.0, "throttle": 1.0, "rudder": 0.0, "lateral": 0.0, "fuel": 40.0, "condition": 1.0,
		"air": {"altitude": 3200.0, "basis": basis, "vy": -top * 0.95, "ground": false, "gear": false, "stall": false}}
	var bytes: PackedByteArray = Codec.encode_motion(own, [])
	var back: Dictionary = Codec.decode_motion(bytes)
	expect(not back.is_empty() and absf(float(back.own.air.vy) + top * 0.95) < 1.0 and back.own.velocity.distance_to(own.velocity) < 1.0, "the Fighter jet's full-speed dive replicates unclipped (vy %.0f)" % (float(back.own.air.vy) if not back.is_empty() else 0.0))
	expect(bytes.size() == Codec.MOTION_HEADER + Codec.MOTION_AIR, "the plane motion frame stays the same size (%d bytes)" % bytes.size())

## Item 5: the Cargo jet's turbofans: fans, no flames.
func turbofans() -> void:
	var model: Node3D = Look.model("plane_jet")
	expect(model.find_child("JetFlame", true, false) == null, "the Cargo jet has no flame node")
	var fans: Array[Node] = model.find_children("Fan*", "", true, false)
	expect(fans.size() == 2, "the Cargo jet has two turbofans with front fans (%d)" % fans.size())
	var before: float = (fans[0] as Node3D).rotation.z if not fans.is_empty() else 0.0
	Look.animate(model, 1.0, true, 0.1)
	expect(not fans.is_empty() and absf((fans[0] as Node3D).rotation.z - before) > 1.0, "the fans spin with the throttle")
	var hazes: Array[Node] = model.find_children("HeatShimmer", "", true, false)
	var faint: bool = not hazes.is_empty()
	for haze: Node in hazes: faint = faint and ((haze as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a <= 0.11
	expect(faint, "at most a faint heat shimmer")
	model.free()

## Item 6: planes are open from level 1; the level system is kept.
func gate() -> void:
	expect(Levels.PLANE_UNLOCK_LEVEL == 1, "planes unlock at level 1 for now (PLANE_UNLOCK_LEVEL)")
	expect(Levels.level_for(0) == 1 and Levels.level_for(Levels.xp_for_level(10)) == 10, "the level system is unchanged")

## Item 7: no terrain bump above the runway inside any airport's footprint,
## the airfield is level and landable all over, and its faces point up.
func airfields() -> void:
	for index: int in Airports.count():
		var entry: Dictionary = Airports.all()[index]
		var along: Vector3 = Vector3(sin(entry.heading), 0, cos(entry.heading))
		var side: Vector3 = Vector3(cos(entry.heading), 0, -sin(entry.heading))
		var span: Vector2 = Airports.field_across(index)
		var half: float = Airports.field_half_length(index)
		var worst_drawn: float = -INF
		var worst_terrain: float = -INF
		var flat: bool = true
		# Every 10 m along and 8 m across, just inside the footprint's edges.
		var a: float = -half + 0.5
		while a <= half - 0.5:
			var c: float = span.x + 0.5
			while c <= span.y - 0.5:
				var spot: Vector3 = entry.at + along * a + side * c
				var sample: Dictionary = Terrain.sample(spot)
				worst_terrain = maxf(worst_terrain, float(sample.height))
				# (Patch 4.0.3 item 8: each at its own runway's height.)
				flat = flat and sample.surface in ["runway", "airfield"] and absf(float(sample.height) - float(entry.at.y)) < 0.01
				var depth: float = Progression.land_depth(Vector2(spot.x, spot.z))
				if depth > TOON_COAST.SAND_FROM_M: worst_drawn = maxf(worst_drawn, maxf(TOON_COAST.sand_height(depth, 0.0), TOON_COAST.hill_height(depth)))
				c += 8.0
			a += 10.0
		expect(flat and worst_terrain <= float(entry.at.y) + 0.01, "%s: the airfield is level and clear (highest %.1f m)" % [entry.name, worst_terrain])
		expect(worst_drawn < float(entry.at.y), "%s: no drawn hill rises above the runway inside the footprint (%.1f m)" % [entry.name, worst_drawn])
		var terminal: Vector3 = entry.terminal
		expect(Airports.on_airfield(index, terminal) and Airports.on_airfield(index, Airports.start_pose(index).origin), "%s: the terminal and the start are on the airfield" % entry.name)
		var node: Node3D = Look.airport(index)
		var field: MeshInstance3D = node.find_child("Airfield", true, false) as MeshInstance3D
		var up: bool = field != null and field.mesh != null and field.material_override != null
		if up:
			var points: PackedVector3Array = field.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var top: float = -INF
			for point: Vector3 in points: top = maxf(top, point.y)
			var faces: int = 0
			for at: int in range(0, points.size(), 3):
				var p0: Vector3 = points[at]
				var p1: Vector3 = points[at + 1]
				var p2: Vector3 = points[at + 2]
				# Godot fronts are clockwise: (c - a) x (b - a) points out.
				var out: Vector3 = (p2 - p0).cross(p1 - p0)
				if is_equal_approx(p0.y, top) and is_equal_approx(p1.y, top) and is_equal_approx(p2.y, top):
					faces += 1
					up = up and out.y > 0.0
				else: up = up and out.y > 0.0
			# Patch 4.0.2 item 3: the top is cut round the runway and the apron
			# (more than two faces) and stands Look.FIELD_DROP_M below the runway.
			up = up and faces >= 2 and absf(top + field.position.y - (float(entry.at.y) - Look.FIELD_DROP_M)) < 0.01
		expect(up, "%s: the airfield ground faces up (grass or snow, not a black slab)" % entry.name)
		node.free()

## Old saves: a 4.0 progress row (a captain below the old level 10 with a
## plane, flying) still loads; a 3.2 server save migrates (patch_4_0_logic).
func saves() -> void:
	var row: Dictionary = {"xp": 1200, "planes": {"plane_jet": {"fuel": 0.5, "condition": 0.8}}, "plane": "plane_jet", "mode": "plane", "airport": 4, "plane_job": ""}
	expect(Levels.progress_valid(row), "a 4.0 progress row loads")
	row.planes["plane_fighter"] = {"fuel": 1.0, "condition": 1.0}
	row.plane = "plane_fighter"
	expect(Levels.progress_valid(row), "a row with the Fighter jet loads")
	row.plane_job = "air_4_1_pkg_4"
	expect(not Levels.progress_valid(row), "a Fighter jet cannot hold a plane job")
	expect(Levels.progress_valid(Levels.fresh_progress()), "a fresh row loads")
