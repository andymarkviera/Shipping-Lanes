extends RefCounted
## Patch 4.0.2 headless checks that need no scene (Andy's second plane
## playtest, issue #224): the polar cap has relief (in the world, for the
## planes, and on the globe) the same everywhere it is asked; planes are
## plane icons on the minimap and plane models on the globe; every runway's
## surface is above its airfield's grass, which is cut away under the runway
## and apron (nothing coplanar); no dune, mesa, palm, bush or tower stands on
## any airfield; hands-off mouse aim never banks past the limit nor loops; a
## held A completes a full roll and the plane rolls back afterwards; the gear
## lever (G) moves the gear in the air only; the gear comes up on its own
## after take-off and a late "down" from before does not lower it again; a
## gear-up landing is a belly landing (no crash) and a very hard one is a
## crash; the gear folds in GEAR_TRAVEL_S; the gear replicates; the
## Speedboat's and Jetty's stats are unchanged (the Jetty keeps its jet
## flame where it was); the Jetty hovers over the water with its own downwash
## spray, rooster tail and glow; Shift charges and fires its blaster boost
## (about +60 % speed for 2.5 s, then a 6 s cooldown) with a huge fast-RGB
## flame, a shock ring and a synthesised charge and blast sound; old saves
## load; VERSION is 4.0.2.
## check_catalog.gd (in the Checks job) runs these; tools/patch_4_0_2_check.gd
## runs them too, then the game-scene checks (hangar, debug panel, nudge).
const Progression = preload("res://features/game/progression.gd")
const Levels = preload("res://features/game/levels.gd")
const Airports = preload("res://features/planes/airports.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Flight = preload("res://features/planes/flight_model.gd")
const Terrain = preload("res://features/planes/terrain.gd")
const Look = preload("res://features/planes/plane_look.gd")
const Aviation = preload("res://features/planes/aviation.gd")
const Autopilot = preload("res://tools/flight_autopilot.gd")
const Codec = preload("res://features/network/public_snapshot_codec.gd")
const PolarIce = preload("res://features/toon/polar_ice.gd")
const GlobeMap = preload("res://features/game/globe_map.gd")
const Minimap = preload("res://features/game/globe_minimap.gd")
const Desert = preload("res://features/toon/desert_look.gd")
const Tropical = preload("res://features/toon/tropical_look.gd")
const City = preload("res://features/toon/city_look.gd")
const Chunky = preload("res://features/toon/chunky_look.gd")
const STEP: float = 1.0 / 30.0
const Boost = preload("res://features/ships/jetty_boost.gd")
const JettyFx = preload("res://features/toon/jetty_fx.gd")
const JetFlame = preload("res://features/toon/jet_flame.gd")
const Hud = preload("res://features/game/game_hud.gd")
const PARTS: Array[String] = ["version", "polar_relief", "plane_icons", "runways", "decorations", "bank_limit", "barrel_roll", "gear", "belly", "gear_look", "boats", "jetty_hover", "jetty_boost", "jetty_blaster_look", "jetty_blaster_sound", "saves"]

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
	# Patch 4.0.3: later patches move VERSION on; 4.0.2 or newer.
	expect(connection.VERSION.naturalnocasecmp_to("4.0.2") >= 0, "VERSION is 4.0.2 or later (%s)" % connection.VERSION)

## Item 1: ridges and hills on the cap, for the planes as drawn, wrapped the
## same, and on the globe.
func polar_relief() -> void:
	var grid: Dictionary = Progression.polar_ice()
	if not expect(not grid.is_empty(), "the polar ice grid loads"): return
	var low: float = INF
	var high: float = -INF
	var terrain_high: float = -INF
	var same: bool = true
	var plateau: int = 0
	for column: int in range(0, grid.count.x, 7):
		for row: int in range(0, grid.count.y, 5):
			var at: Vector2 = GlobeMap.polar_spot(column, row)
			var depth: float = Progression.ice_depth(at)
			if depth < PolarIce.RELIEF_FULL_M - 4.0: continue
			plateau += 1
			var lift: float = PolarIce.relief(at, depth)
			low = minf(low, lift)
			high = maxf(high, lift)
			var spot: Vector3 = Vector3(at.x, 0, at.y)
			var sample: Dictionary = Terrain.sample(spot)
			terrain_high = maxf(terrain_high, float(sample.height))
			# The same ice wherever and however often it is asked (client and server).
			var again: Dictionary = Terrain.sample(spot + Vector3(Progression.WRAP_M, 0, 0))
			same = same and absf(float(sample.height) - float(again.height)) < 0.01 and float(Terrain.sample(spot).height) == float(sample.height)
	expect(plateau > 100, "the cap has a plateau to raise (%d samples)" % plateau)
	expect(high > 45.0 and high - low > 35.0, "the plateau has ridges and hills, not a flat top (%.0f to %.0f m of relief)" % [low, high])
	expect(terrain_high > Terrain.ICE_PLATEAU_M + 35.0, "planes meet the ridges: the ice rises to %.0f m (the plateau is %.0f m)" % [terrain_high, Terrain.ICE_PLATEAU_M])
	expect(same, "the ice's height is the same however it is asked (client = server, across the wrap)")
	expect(PolarIce.relief(Vector2(0, 0), 40.0) == 0.0, "no relief by the ice's coast (the cliffs and the polar ports keep their shape)")
	# The drawn ice: the plateau squares now rise and fall.
	# (Patch 4.0.3 item 2: the snow is level right round the pole, so the
	# band sampled is the one further from it, in the North Pole ice field.)
	var part: Dictionary = PolarIce.band_meshes(6, int(grid.half) - 150, int(grid.half) - 40, false, [], StandardMaterial3D.new(), StandardMaterial3D.new(), StandardMaterial3D.new())
	var heights: Dictionary = {}
	var steep: bool = false
	if expect(part.coast != null, "the drawn ice has a mesh"):
		var mesh: ArrayMesh = part.coast
		for surface: int in mesh.get_surface_count():
			var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				if point.y > PolarIce.PLATEAU_Y - 0.5: heights[snappedf(point.y, 1.0)] = true
			steep = steep or surface >= 2
	expect(heights.size() > 30, "the drawn plateau has relief (%d heights above the snow line)" % heights.size())
	expect(steep, "steep ridge faces are drawn in glacier ice")
	# The globe: the cap stands up off the ball like the land.
	var shell: ArrayMesh = GlobeMap.relief_mesh()
	var verts: PackedVector3Array = shell.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] if shell.get_surface_count() > 0 else PackedVector3Array()
	var polar_raised: int = 0
	var polar_peak: float = 0.0
	for vert: Vector3 in verts:
		if absf(vert.normalized().y) < 0.75: continue
		var height: float = vert.length() - 1.0
		if height > GlobeMap.RELIEF_SHORE + GlobeMap.RELIEF_HILL * 1.5: polar_raised += 1
		polar_peak = maxf(polar_peak, height)
	expect(polar_raised > 300 and polar_peak > GlobeMap.RELIEF_MOUNTAIN * 0.5, "the M-map globe's polar caps have relief (%d raised, peak %.4f)" % [polar_raised, polar_peak])

## Item 2: planes are plane icons on the minimap and plane models on the globe.
func plane_icons() -> void:
	for kind: String in Planes.ORDER:
		expect(Minimap.icon_for(kind) == "plane" and GlobeMap.is_plane(kind), "%s is drawn as a plane on the minimap and the globe" % kind)
	for kind: String in ["small_speedboat", "small_jetty", "container", "bulk_2", ""]:
		expect(Minimap.icon_for(kind) == "boat", "%s is drawn as a boat" % (kind if not kind.is_empty() else "an unknown kind"))
	var outline: PackedVector2Array = Minimap.plane_outline(Vector2(50, 50), Vector2.UP, 1.0)
	expect(outline.size() == 18 and not Geometry2D.triangulate_polygon(outline).is_empty(), "the plane icon is a top-down plane silhouette (%d points)" % outline.size())
	var wide: float = 0.0
	for point: Vector2 in outline: wide = maxf(wide, absf(point.x - 50.0))
	expect(wide > 8.0, "the plane icon has wings")

## Item 3: the runway's surface stands above the grass at every airport, and
## the grass has holes under the runway and the apron (nothing coplanar).
func runways() -> void:
	for index: int in Airports.count():
		var entry: Dictionary = Airports.all()[index]
		var node: Node3D = Look.airport(index)
		var runway: MeshInstance3D = node.find_child("Runway", true, false) as MeshInstance3D
		var field: MeshInstance3D = node.find_child("Airfield", true, false) as MeshInstance3D
		var apron: MeshInstance3D = node.find_child("Apron", true, false) as MeshInstance3D
		if not expect(runway != null and field != null and apron != null, "%s: a runway, an apron and the airfield" % entry.name):
			node.free()
			continue
		var runway_top: float = runway.position.y + runway.mesh.get_aabb().end.y
		var field_top: float = field.position.y + field.mesh.get_aabb().end.y
		var apron_top: float = apron.position.y + (apron.mesh as BoxMesh).size.y * 0.5
		expect(absf(runway_top - float(entry.at.y)) < 0.001, "%s: the runway's surface is where the planes land (%.2f m)" % [entry.name, runway_top])
		expect(runway_top > field_top + 0.05 and apron_top > field_top + 0.05 and runway_top > apron_top, "%s: the runway (%.2f) and apron (%.2f) sit above the grass (%.2f)" % [entry.name, runway_top, apron_top, field_top])
		var width: float = float(entry.width)
		var length: float = float(entry.length)
		var holes: Array[Rect2] = [Look.runway_rect(width, length).grow(-0.01), Rect2(apron.position.x - 12.99, apron.position.z - 79.99, 25.98, 159.98)]
		var points: PackedVector3Array = field.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var covered: bool = false
		for at: int in range(0, points.size(), 3):
			if not (is_equal_approx(points[at].y, points[at + 1].y) and is_equal_approx(points[at].y, points[at + 2].y)) or points[at].y < field.mesh.get_aabb().end.y - 0.01: continue
			var centre: Vector3 = (points[at] + points[at + 1] + points[at + 2]) / 3.0
			for hole: Rect2 in holes: covered = covered or hole.has_point(Vector2(centre.x, centre.z))
		expect(not covered, "%s: no grass lies under the runway or the apron (no z-fighting)" % entry.name)
		# The markings are painted into the runway, not boxes lying on it.
		var loose: int = 0
		for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
			var part: MeshInstance3D = mesh as MeshInstance3D
			if part == runway or part == field or part == apron or not part.mesh is BoxMesh: continue
			var size: Vector3 = (part.mesh as BoxMesh).size
			if size.y < 0.2 and absf(part.position.x) < width * 0.5 and absf(part.position.z) < length * 0.5: loose += 1
		expect(loose == 0, "%s: no stripe boxes lie on the runway" % entry.name)
		var paint: StandardMaterial3D = runway.material_override as StandardMaterial3D
		var toon: ShaderMaterial = runway.material_override as ShaderMaterial
		expect((paint != null and paint.albedo_texture != null) or (toon != null and toon.get_shader_parameter("albedo_texture") != null), "%s: the runway's markings are painted on it" % entry.name)
		node.free()
	var page: Image = Look.runway_texture().get_image()
	expect(page.get_pixel(32, 512).is_equal_approx(Look.STRIPE) or page.get_pixel(32, 528).is_equal_approx(Look.STRIPE) or page.get_pixel(32, 500).is_equal_approx(Look.STRIPE), "the runway paint has a dashed centre line")
	expect(page.get_pixel(16, 512).is_equal_approx(Look.TARMAC), "the runway paint is tarmac between its lines")

## Item 4: no decoration of any biome on (or within DECOR_CLEAR_M of) any
## airfield: dunes, mesas, palms, bushes and towers.
func decorations() -> void:
	var ports: Array[Vector2] = []
	for place: Dictionary in Progression.WORLD: ports.append(Vector2(place.at.x, place.at.z))
	var layers: Dictionary = {}
	var desert: Dictionary = Desert.placements(Progression.LAND, ports)
	if not desert.is_empty():
		layers["dune"] = [desert.dunes, 0.5]
		for band: int in desert.mesas.size(): layers["mesa %d" % band] = [desert.mesas[band], 1.0]
	var tropical: Dictionary = Tropical.placements(Progression.LAND, ports)
	if not tropical.is_empty():
		layers["palm"] = [tropical.trunks, 0.6]
		layers["palm crown"] = [tropical.crowns, 1.0]
		layers["bush"] = [tropical.bushes, 0.5]
	var city: Dictionary = City.placements(Progression.LAND, ports)
	if not city.is_empty():
		for band: int in city.towers.size(): layers["tower %d" % band] = [city.towers[band], 0.5]
	expect(layers.has("dune") and layers.has("palm"), "the desert and tropical layers are checked")
	var total: int = 0
	for label: String in layers:
		var list: Array = layers[label][0]
		var reach: float = float(layers[label][1])
		var on: int = 0
		for placed: Transform3D in list:
			total += 1
			var at: Vector3 = placed.origin
			var spots: Array[Vector3] = [at]
			for x: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]: spots.append(at + placed.basis.x * reach * x + placed.basis.z * reach * z)
			for spot: Vector3 in spots:
				if Airports.airfield_at(Vector3(spot.x, 0, spot.z)) >= 0:
					on += 1
					break
		expect(on == 0, "no %s stands on an airfield (%d do)" % [label, on])
	expect(total > 500, "the decoration layers have content (%d pieces)" % total)
	expect(not Airports.clear_of_airfields(Vector2(Airports.all()[0].at.x, Airports.all()[0].at.z)), "clear_of_airfields refuses a spot on a runway")

## A plane in cruise high over the sea (or the first airport), for the aim checks.
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

## Item 5 (Patch 4.0.3 item 1: the keys): whatever W / S and A / D hold,
## the plane never banks past the limit (45 degrees, the Fighter 60), never
## loops and never flips over.
func bank_limit() -> void:
	var pilot: Node = Aviation.new()
	for kind: String in Planes.ORDER:
		var limit: float = rad_to_deg(Flight.make(kind, Airports.start_pose(0)).bank_limit())
		expect(is_equal_approx(limit, 60.0 if kind == "plane_fighter" else 45.0), "%s: the bank limit is %.0f degrees" % [kind, limit])
		for held: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(1, 1), Vector2(-1, -1), Vector2(0, 1), Vector2(0, -1), Vector2(1, -1)]:
			var m: RefCounted = cruise(kind)
			pilot.model = m
			pilot.lever = 0.7
			var worst: float = 0.0
			var nose: float = 0.0
			var inverted: bool = false
			for frame: int in 30 * 20:
				var order: Dictionary = pilot.key_order(held.y, held.x, 0.0, false, STEP)
				m.step({"throttle": 0.7, "pitch": order.pitch, "roll": order.roll, "trick": order.yaw}, STEP)
				worst = maxf(worst, absf(rad_to_deg(m.full_bank())))
				nose = maxf(nose, absf(rad_to_deg(m.pitch_angle())))
				inverted = inverted or m.basis.y.y < 0.0
				if m.crashed: break
			var keys: String = ("D" if held.x > 0.0 else ("A" if held.x < 0.0 else "")) + ("W" if held.y > 0.0 else ("S" if held.y < 0.0 else ""))
			expect(worst <= limit + 0.5, "%s: %s held never banks past %.0f degrees (%.1f)" % [kind, keys, limit, worst])
			expect(nose <= rad_to_deg(Flight.PITCH_LIMIT_RAD) + 2.0 and not inverted, "%s: %s held never loops or flips over (nose %.1f)" % [kind, keys, nose])
	pilot.free()

## Item 5 (Patch 4.0.3 item 1: Q / E): one press of Q rolls all the way
## round, then the plane is upright again; let go part way (the roll cut
## short), it rolls back upright on its own.
func barrel_roll() -> void:
	var pilot: Node = Aviation.new()
	for kind: String in Planes.ORDER:
		for key: float in [-1.0, 1.0]:
			var m: RefCounted = cruise(kind)
			pilot.model = m
			pilot.lever = 0.8
			pilot.barrel = 0.0
			pilot.barrel_key = 0.0
			var turned: float = 0.0
			var last: float = m.full_bank()
			var seconds: float = 0.0
			var started: bool = false
			while seconds < 25.0 and not m.crashed:
				# Q (or E) pressed for a moment, then let go: the roll goes on.
				var order: Dictionary = pilot.key_order(0.0, 0.0, key if seconds < 0.2 else 0.0, false, STEP)
				started = started or pilot.barrel != 0.0
				m.step({"throttle": 0.8, "pitch": order.pitch, "roll": order.roll, "trick": order.yaw}, STEP)
				turned += angle_difference(last, m.full_bank())
				last = m.full_bank()
				seconds += STEP
				if started and pilot.barrel == 0.0: break
			expect(started and absf(turned) >= TAU - deg_to_rad(40.0) and signf(turned) == key and not m.crashed, "%s: one press of %s rolls all the way round (%.0f degrees in %.1f s)" % [kind, "E" if key > 0.0 else "Q", rad_to_deg(absf(turned)), seconds])
			for frame: int in 30 * 5: m.step({"throttle": 0.8, "pitch": 0.0, "roll": 0.0}, STEP)
			expect(absf(rad_to_deg(m.full_bank())) < 3.0 and m.basis.y.y > 0.9, "%s: then it is upright again (%.1f degrees)" % [kind, rad_to_deg(m.full_bank())])
		# Cut short upside down (the roll held, then nothing): it rolls back.
		var flipped: RefCounted = cruise(kind)
		while absf(flipped.full_bank()) < deg_to_rad(150.0):
			flipped.step({"throttle": 0.8, "trick": -1.0}, STEP)
		var back: float = 0.0
		while back < 20.0 and (absf(flipped.full_bank()) > deg_to_rad(3.0) or flipped.basis.y.y < 0.9):
			flipped.step({"throttle": 0.8}, STEP)
			back += STEP
		expect(back < 20.0 and not flipped.crashed, "%s: let go upside down, it rolls back upright (%.1f s)" % [kind, back])
	pilot.free()

## Item 6: the gear lever, and the gear coming up on its own after take-off.
func gear() -> void:
	for kind: String in Planes.ORDER:
		var m: RefCounted = cruise(kind)
		m.gear_down = true
		m.step({"throttle": 0.7, "gear": 1.0}, STEP)
		expect(m.gear_down, "%s: the lever left down keeps the gear down" % kind)
		m.step({"throttle": 0.7, "gear": 0.0}, STEP)
		expect(not m.gear_down, "%s: G raises the gear in the air" % kind)
		m.step({"throttle": 0.7, "gear": 0.0}, STEP)
		m.step({"throttle": 0.7}, STEP)
		expect(not m.gear_down, "%s: the gear stays up (no lever change)" % kind)
		m.step({"throttle": 0.7, "gear": 1.0}, STEP)
		expect(m.gear_down, "%s: G lowers it again" % kind)
		var parked: RefCounted = Flight.make(kind, Airports.start_pose(0))
		parked.step({"throttle": 0.0, "gear": 1.0}, STEP)
		parked.step({"throttle": 0.0, "gear": 0.0}, STEP)
		expect(parked.gear_down and parked.on_ground, "%s: on the ground the gear stays down" % kind)
		# Take-off with the lever held down the whole time (as a client sends it).
		var flying: RefCounted = Flight.make(kind, Airports.start_pose(0))
		var pilot: RefCounted = Autopilot.new(1)
		var retracted_at: float = -1.0
		var came_down: bool = false
		for frame: int in 30 * 120:
			var inputs: Dictionary = pilot.inputs(flying)
			inputs.gear = 1.0
			flying.step(inputs, STEP)
			if retracted_at < 0.0 and not flying.on_ground and not flying.gear_down: retracted_at = flying.agl_m
			elif retracted_at >= 0.0: came_down = came_down or flying.gear_down
			if pilot.phase == "outbound" and flying.agl_m > 120.0: break
		expect(retracted_at >= Flight.GEAR_RETRACT_AGL_M and retracted_at < Flight.GEAR_RETRACT_AGL_M + 15.0, "%s: the gear comes up on its own after take-off (at %.0f m)" % [kind, retracted_at])
		expect(not came_down, "%s: and the held lever does not lower it again" % kind)
		flying.step({"throttle": 0.8, "gear": 0.0}, STEP)
		flying.step({"throttle": 0.8, "gear": 1.0}, STEP)
		expect(flying.gear_down, "%s: a new G lowers it" % kind)
	# The gear replicates in the plane's motion frame.
	for down: bool in [true, false]:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(Codec.MOTION_AIR)
		Codec.put_air(bytes, 0, {"altitude": 300.0, "basis": Basis.IDENTITY, "vy": -2.0, "ground": false, "gear": down, "stall": false})
		expect(bool(Codec.get_air(bytes, 0).gear) == down, "the gear (%s) replicates to other players" % ("down" if down else "up"))
	# The nudge's distance: from any runway's threshold.
	var entry: Dictionary = Airports.all()[0]
	var axis: Vector3 = Vector3(sin(entry.heading), 0, cos(entry.heading))
	var near_end: Vector3 = entry.at - axis * float(entry.length) * 0.5
	expect(Aviation.near_threshold(near_end) < 0.5 and Aviation.near_threshold(near_end - axis * 1500.0) <= 1500.01, "the nudge measures from the runways' thresholds")

## Item 6: a gear-up landing is a belly landing, not a crash; a very hard one is.
func belly() -> void:
	for kind: String in Planes.ORDER:
		# Low over the runway's near end, lined up, sinking gently, gear up.
		# (With the gear up the runway assists do not help: they are for a
		# plane set up to land.)
		var m: RefCounted = Flight.make(kind, Airports.start_pose(1))
		var entry: Dictionary = Airports.all()[1]
		var axis: Vector3 = Vector3(sin(entry.heading), 0, cos(entry.heading))
		m.position = entry.at - axis * float(entry.length) * 0.3 + Vector3(0, 8.0, 0)
		m.basis = Basis(Vector3.UP, entry.heading) * Basis(Vector3(1, 0, 0), -deg_to_rad(2.0))
		m.velocity = axis * Planes.stall_speed(kind) * 1.15 + Vector3(0, -2.0, 0)
		m.on_ground = false
		m.engine = 0.2
		m.step({"throttle": 0.2, "gear": 0.0}, STEP)
		expect(not m.gear_down, "%s: on approach with the gear up" % kind)
		var belly_landed: bool = false
		var seconds: float = 0.0
		while seconds < 240.0 and not m.crashed:
			var inputs: Dictionary = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "brake": 1.0 if m.on_ground else 0.0, "gear": 0.0}
			m.step(inputs, STEP)
			belly_landed = belly_landed or m.belly_landed
			seconds += STEP
			if m.on_ground and m.airspeed() < 0.5: break
		expect(belly_landed and not m.crashed, "%s: a gear-up landing is a belly landing, not a crash (%s)" % [kind, m.crash_reason])
		expect(m.on_ground and m.airspeed() < 0.5 and m.gear_down, "%s: it slides to a stop and is put back on its wheels" % kind)
		# Far too hard: still a crash.
		var hard: RefCounted = Flight.make(kind, Airports.start_pose(1))
		# (Patch 4.0.3: low enough that the auto-trim cannot catch it.)
		hard.position.y += 6.0
		hard.on_ground = false
		hard.step({"throttle": 0.0, "gear": 0.0}, STEP)
		hard.velocity = hard.basis.z * Planes.stall_speed(kind) + Vector3(0, -(Flight.BELLY_MAX_SINK_MPS + 6.0), 0)
		for frame: int in 300:
			hard.step({"throttle": 0.0, "gear": 0.0}, STEP)
			if hard.crashed or hard.on_ground: break
		expect(hard.crashed, "%s: a gear-up belly-flop far too hard is still a crash" % kind)
	expect(Aviation.BELLY_REPAIR_PERCENT > 0 and Aviation.BELLY_REPAIR_PERCENT < Planes.CRASH_REPAIR_PERCENT, "a belly landing bills less than a crash")

## Item 6: legs and wheels on every plane, folding up in GEAR_TRAVEL_S.
func gear_look() -> void:
	for kind: String in Planes.ORDER:
		var model: Node3D = Look.model(kind)
		var gear: Node3D = model.get_node_or_null("Gear") as Node3D
		if not expect(gear != null, "%s: has landing gear" % kind):
			model.free()
			continue
		var legs: Array[Node3D] = []
		var doors: int = 0
		for child: Node in gear.get_children():
			if child.name.begins_with("Leg"): legs.append(child)
			if child.name.begins_with("Door"): doors += 1
		var wheels: bool = legs.size() >= 3
		for leg: Node3D in legs: wheels = wheels and leg.get_child_count() >= 6
		expect(wheels and doors == legs.size() * 2, "%s: %d legs with struts, oleos and wheels, and well doors" % [kind, legs.size()])
		var halfway: float = 1.0
		for frame: int in 45: halfway = Look.fold_gear(gear, false, 1.0 / 60.0)
		expect(absf(halfway - 0.5) < 0.02 and legs[0].visible and absf(legs[1].rotation.z) > 0.3, "%s: the gear is half way up after 0.75 s" % kind)
		var up: float = halfway
		for frame: int in 46: up = Look.fold_gear(gear, false, 1.0 / 60.0)
		expect(up == 0.0 and not legs[0].visible, "%s: and up in its wells after %.1f s" % [kind, Look.GEAR_TRAVEL_S])
		for frame: int in 90: Look.fold_gear(gear, true, 1.0 / 60.0)
		expect(legs[0].visible and legs[0].rotation.length() < 0.001, "%s: and down again" % kind)
		model.free()

## Item 9: the Speedboat's and Jetty's stats, prices and hitboxes are
## unchanged; their new looks build; the Jetty's thruster and flame stay put.
func boats() -> void:
	var speedboat: ShipDefinition = Progression.definition("small_speedboat")
	var jetty: ShipDefinition = Progression.definition("small_jetty")
	expect(speedboat.hull_size_m == Vector3(2.8, 2, 8.5) and is_equal_approx(speedboat.forward_acceleration_mps2, 12.8611) and is_equal_approx(speedboat.fuel_capacity_liters, 250.0) and is_equal_approx(speedboat.max_turn_rate_degrees, 34.0), "the Speedboat's stats and hitbox are unchanged")
	expect(jetty.hull_size_m == Vector3(3, 2, 12) and is_equal_approx(jetty.forward_acceleration_mps2, 154.3333) and is_equal_approx(jetty.fuel_capacity_liters, 900.0) and is_equal_approx(jetty.max_turn_rate_degrees, 28.0), "the Jetty's stats and hitbox are unchanged")
	expect(int(Progression.SHIPS.small_speedboat.price_minor) == 250000 and int(Progression.SHIPS.small_jetty.price_minor) == 3000000, "their prices are unchanged")
	var boat: Node3D = Chunky.model("small_speedboat", speedboat)
	var parts: int = boat.find_children("*", "MeshInstance3D", true, false).size()
	var hull: MeshInstance3D = boat.get_node("Hull") as MeshInstance3D
	var bounds: AABB = hull.mesh.get_aabb()
	expect(parts > 40 and bounds.size.z <= speedboat.hull_size_m.z + 0.01 and bounds.size.x <= speedboat.hull_size_m.x + 0.01, "the Speedboat is a Marlin-style fishing boat inside its old hull (%d parts)" % parts)
	expect(bounds.end.y > 3.5 * speedboat.hull_size_m.y / 4.0 + 0.3, "with a raised bow")
	boat.free()
	var jet: Node3D = Chunky.model("small_jetty", jetty)
	var flame: Node3D = jet.find_child("JetFlame", true, false) as Node3D
	var deck: float = 2.6 * jetty.hull_size_m.y / 4.0
	expect(flame != null and flame.position.is_equal_approx(Vector3(0, deck - 0.1, -jetty.hull_size_m.z / 2.0 - 0.88)), "the Jetty's jet flame is exactly where it was")
	var jet_hull: AABB = (jet.get_node("Hull") as MeshInstance3D).mesh.get_aabb()
	expect(jet_hull.size.z <= jetty.hull_size_m.z + 0.01 and jet_hull.size.x <= jetty.hull_size_m.x + 0.01, "the Jetty's delta hull fits its old hitbox")
	var points: PackedVector3Array = (jet.get_node("Hull") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var nose: float = 0.0
	var stern: float = 0.0
	for point: Vector3 in points:
		if point.z > jetty.hull_size_m.z * 0.4: nose = maxf(nose, absf(point.x))
		if point.z < -jetty.hull_size_m.z * 0.45: stern = maxf(stern, absf(point.x))
	expect(nose < stern * 0.3, "the Jetty is a long triangle: a pointed nose, a wide stern (%.2f vs %.2f m)" % [nose, stern])
	jet.free()

## A hull of one kind, ready to sail but outside the tree (no physics space:
## advance_motion only, which never needs one with the rudder centred).
func make_hull(kind: String) -> HandlingShip:
	var hull: HandlingShip = HandlingShip.new()
	hull.definition = Progression.definition(kind)
	hull._ready()
	hull.set_physics_process(true)
	return hull

func top_speed(definition: ShipDefinition) -> float:
	return definition.forward_acceleration_mps2 / definition.linear_drag_per_second

## Full ahead at top speed, bow along +Z.
func full_ahead(hull: HandlingShip) -> void:
	hull.command_throttle(1.0)
	hull.actual_throttle = 1.0
	hull.velocity = Vector3(0, 0, top_speed(hull.definition))

## Follow-up: the Jetty hovers over the water (looks only). It is clear of the
## swell all the time, higher at speed and in a blast, never "jumps", and the
## other boats still sit in the water.
func jetty_hover() -> void:
	var definition: ShipDefinition = Progression.definition("small_jetty")
	# A plain body in the tree, like small_boats_check (the motion reads global poses).
	var body: CharacterBody3D = CharacterBody3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(body)
	var motion: ShipVisualMotion = ShipVisualMotion.new()
	motion.body = body
	motion.quality = 2
	motion.configure_hull(definition)
	body.add_child(motion)
	motion.set_process(false)
	expect(motion.hovering() and motion.hover_m >= 1.5, "the Jetty hovers (%.1f m off the water at rest)" % motion.hover_m)
	for kind: String in ["small_speedboat", "small_racer", "container", "bulk_2"]:
		var other: ShipVisualMotion = ShipVisualMotion.new()
		other.configure_hull(Progression.definition(kind))
		expect(not other.hovering(), "the %s still floats in the water" % kind)
		other.free()
	var model: Node3D = Chunky.model("small_jetty", definition)
	var keel: float = (model.get_node("Hull") as MeshInstance3D).mesh.get_aabb().position.y
	model.free()
	var step: float = 1.0 / 60.0
	var top: float = top_speed(definition)
	var clearance: float = INF
	var rest: float = 0.0
	var fast: float = 0.0
	var airborne: bool = false
	var finite: bool = true
	for tick: int in range(20 * 60):
		var t: float = tick * step
		# 3 s at rest, then up to full speed over 5 s, a gentle turn now and then.
		body.velocity = Vector3(0, 0, top * clampf((t - 3.0) / 5.0, 0.0, 1.0))
		if tick % 600 == 0: body.rotation.y += 0.05
		motion._process(step)
		finite = finite and motion.position.is_finite() and motion.rotation.is_finite()
		airborne = airborne or motion.airborne
		var swell: float = OceanPresentation.swell_height(body.position.x, body.position.z, motion.elapsed, 2)
		var tilt: float = absf(sin(motion.rotation.x)) * definition.hull_size_m.z * 0.5 + absf(sin(motion.rotation.z)) * definition.hull_size_m.x * 0.5
		clearance = minf(clearance, motion.position.y + keel - tilt - swell)
		if t >= 1.0 and t < 3.0: rest += motion.position.y / 120.0
		if t >= 17.0: fast += motion.position.y / 180.0
	expect(finite, "the hover stays finite")
	expect(clearance > 0.3, "the Jetty's keel stays clear of the water at every moment (%.2f m at the lowest)" % clearance)
	expect(not airborne and motion.longest_air_s == 0.0, "the Jetty floats, it never jumps the chop")
	expect(fast > rest + 0.4, "it rides higher at full speed (%.2f m) than at rest (%.2f m)" % [fast, rest])
	expect(motion.hover_height(1.0, 1.0, 0.0) > motion.hover_height(1.0, 0.0, 0.0) + 0.4, "and higher still in a blaster boost")
	expect(absf(motion.rotation.x) <= ShipVisualMotion.HOVER_PITCH_LIMIT_RAD + 0.001 and absf(motion.rotation.z) <= ShipVisualMotion.HOVER_ROLL_LIMIT_RAD + 0.001, "its trim and lean stay calm")
	expect(body.position.y == 0.0, "the body and its collider stay on the water plane")
	body.free()

## Follow-up: Shift's blaster boost on the Jetty. A charge, then about +60 %
## speed for 2.5 s, then a 6 s cooldown; only the Jetty, never docked or dry.
func jetty_boost() -> void:
	var definition: ShipDefinition = Progression.definition("small_jetty")
	expect(Boost.eligible(definition) and not Boost.eligible(Progression.definition("small_racer")) and not Boost.eligible(Progression.definition("small_speedboat")) and not Boost.eligible(Progression.definition("container")), "only the Jetty has the blaster")
	expect(Boost.CHARGE_S >= 0.3 and Boost.CHARGE_S <= 1.0, "the blaster charges first (%.2f s)" % Boost.CHARGE_S)
	expect(is_equal_approx(Boost.BLAST_S, 2.5) and is_equal_approx(Boost.COOLDOWN_S, 6.0) and is_equal_approx(Boost.SPEED_GAIN, 0.6), "+60 % for 2.5 s, 6 s cooldown")
	var top: float = top_speed(definition)
	expect(top * (1.0 + Boost.SPEED_GAIN) <= CollisionRules.SUPPORTED_SPEED_MPS, "the boosted Jetty (%.0f m/s) is inside the collision speed cap (%.0f m/s)" % [top * (1.0 + Boost.SPEED_GAIN), CollisionRules.SUPPORTED_SPEED_MPS])
	var jet: HandlingShip = make_hull("small_jetty")
	var twin: HandlingShip = make_hull("small_jetty")
	full_ahead(jet)
	full_ahead(twin)
	expect(jet.boost.available() and jet.request_boost() and jet.boost.phase == "charge", "Shift on the Jetty starts the charge")
	expect(not jet.request_boost(), "a second Shift while charging does nothing")
	var step: float = 1.0 / 60.0
	var phases: Array[String] = ["charge"]
	var charge_gain: float = 0.0
	var blast_s: float = 0.0
	var boosted_s: float = 0.0
	var middle: float = 0.0
	var peak_speed: float = 0.0
	var ready_at: float = -1.0
	var refused_cooling: bool = false
	var ratio: float = 1.0
	for tick: int in range(12 * 60):
		var t: float = (tick + 1) * step
		jet.advance_motion(step)
		twin.advance_motion(step)
		ratio = jet.forward_speed() / maxf(twin.forward_speed(), 0.001)
		var phase: String = jet.boost.phase
		if phase != phases[-1]:
			phases.append(phase)
			if phase == "ready" and ready_at < 0.0: ready_at = t
		if phase == "charge": charge_gain = maxf(charge_gain, ratio - 1.0)
		if phase == "blast":
			blast_s += step
			if middle == 0.0 and jet.boost.clock >= Boost.BLAST_S * 0.5: middle = ratio
		if ratio > 1.5: boosted_s += step
		peak_speed = maxf(peak_speed, jet.velocity.length())
		if absf(t - (Boost.CHARGE_S + Boost.BLAST_S + 1.0)) < step * 0.5: refused_cooling = not jet.request_boost() and jet.boost.phase == "cooldown"
	expect(phases == ["charge", "blast", "cooldown", "ready"], "charge, blast, cooldown, ready (%s)" % ", ".join(phases))
	expect(charge_gain < 0.001, "the charge itself adds no speed")
	expect(middle > 1.55 and middle < 1.65, "the blast runs about 60 %% faster than the same Jetty without it (x%.3f)" % middle)
	expect(absf(blast_s - Boost.BLAST_S) <= step * 1.5, "the blast lasts 2.5 s (%.2f s)" % blast_s)
	expect(boosted_s >= Boost.BLAST_S - 0.4, "more than 50 %% faster for most of it (%.2f s)" % boosted_s)
	expect(peak_speed <= CollisionRules.SUPPORTED_SPEED_MPS + 0.001 and peak_speed > top * 1.5, "the boosted top speed is reached and capped (%.0f m/s)" % peak_speed)
	expect(absf(ratio - 1.0) < 0.002, "afterwards the Jetty is back to its own speed (x%.3f)" % ratio)
	expect(refused_cooling, "Shift does nothing while the blaster cools down")
	expect(absf(ready_at - (Boost.CHARGE_S + Boost.BLAST_S + Boost.COOLDOWN_S)) <= step * 1.5, "it is ready again 6 s after the blast (%.2f s after Shift)" % ready_at)
	expect(jet.request_boost(), "then Shift fires it again")
	# Docking during a blast ends it at once (it still cools down).
	for tick: int in int((Boost.CHARGE_S + 0.5) / step): jet.advance_motion(step)
	expect(jet.boost.phase == "blast", "the second blast is running")
	jet.docked = true
	jet.advance_motion(step)
	expect(jet.boost.phase == "cooldown" and is_equal_approx(jet.boost.factor(), 1.0), "docking ends the blast and starts the cooldown")
	expect(not jet.request_boost(), "a docked Jetty cannot boost")
	var dry: HandlingShip = make_hull("small_jetty")
	dry.state.fuel_liters = 0.0
	expect(not dry.request_boost(), "a Jetty with an empty tank cannot boost")
	var speedboat: HandlingShip = make_hull("small_speedboat")
	full_ahead(speedboat)
	expect(not speedboat.request_boost() and speedboat.boost.phase == "ready", "Shift does nothing on another boat")
	# The HUD line, the key and the server action.
	var hud_jet: HandlingShip = make_hull("small_jetty")
	var lines: Array[String] = [Hud.blaster_text(hud_jet)]
	hud_jet.request_boost()
	lines.append(Hud.blaster_text(hud_jet))
	hud_jet.boost.advance(Boost.CHARGE_S + 0.1)
	lines.append(Hud.blaster_text(hud_jet))
	hud_jet.boost.advance(Boost.BLAST_S + 1.0)
	lines.append(Hud.blaster_text(hud_jet))
	expect(lines == ["BLASTER READY", "BLASTER CHARGING...", "BLASTER BOOST!", "BLASTER 4.9 s"], "the HUD shows the blaster's state (%s)" % ", ".join(lines))
	expect(Hud.blaster_text(speedboat) == "", "no blaster line on other boats")
	expect(PlayerControls.BOOST_COMMAND == &"jetty_boost" and not InputPreferences.valid_key(KEY_SHIFT) and not InputPreferences.DEFAULT_BINDINGS.has("jetty_boost"), "Shift is a fixed key no binding can take")
	var menu: GDScript = load("res://features/game/game_menu.gd")
	expect(menu.FIXED_ROWS.has(["Jetty: blaster boost", "Shift"]), "Esc > Controls lists Shift for the blaster")
	var runtime: GDScript = load("res://features/network/dedicated_runtime.gd")
	expect(runtime.BOAT_ACTIONS.has("boost"), "online, the server's hull runs the boost (gameplay action \"boost\")")
	for hull: HandlingShip in [jet, twin, dry, speedboat, hud_jet]: hull.free()

## Follow-up: the hover and blaster looks. Downwash spray, a rooster tail and a
## glow on the water under the Jetty; the rear thruster is kept; the charge
## orb, then a huge fast-RGB flame and a shock ring.
func jetty_blaster_look() -> void:
	var definition: ShipDefinition = Progression.definition("small_jetty")
	var model: Node3D = Chunky.model("small_jetty", definition)
	var fx: Node3D = model.find_child("JettyFx", true, false) as Node3D
	var thruster: Node3D = model.find_child("JetFlame", true, false) as Node3D
	if not expect(fx != null and fx.get_script() == JettyFx, "the Jetty carries its hover and blaster effects"):
		model.free()
		return
	expect(thruster != null, "and keeps its rear thruster flame")
	fx._ready()
	for label: String in ["Downwash", "RoosterTail", "Glow", "GlowLight", "BoostFlame", "ChargeOrb", "BlastRing", "BoostSound"]:
		expect(fx.get_node_or_null(label) != null, "the Jetty's effects have %s" % label)
	var keel: float = (model.get_node("Hull") as MeshInstance3D).mesh.get_aabb().position.y
	expect(fx.downwash is CPUParticles3D and fx.downwash.position.y < keel - 0.5, "the downwash sprays on the water under the hovering hull")
	expect(fx.rooster.position.z < -definition.hull_size_m.z * 0.5 and fx.rooster.direction.z < 0.0 and fx.rooster.direction.y > 0.0, "the rooster tail is thrown up and back behind the stern")
	expect(fx.glow.position.y < keel and fx.glow_light.light_color.is_equal_approx(JettyFx.GLOW), "the teal glow lies on the water under it")
	expect(fx.flame.position.is_equal_approx(thruster.position), "the blaster flame comes out of the rear thruster's nozzle")
	var plain: Node3D = Chunky.model("small_speedboat", Progression.definition("small_speedboat"))
	expect(plain.find_child("JettyFx", true, false) == null, "other boats have no Jetty effects")
	plain.free()
	var hull: HandlingShip = make_hull("small_jetty")
	full_ahead(hull)
	fx.ship = hull
	var step: float = 1.0 / 60.0
	fx.update_fx(step)
	expect(fx.rooster.emitting and not fx.orb.visible and not fx.flame.visible and not fx.ring.visible, "cruising: the rooster tail flies, no blaster")
	hull.request_boost()
	for tick: int in int(Boost.CHARGE_S * 0.5 / step):
		hull.advance_motion(step)
		fx.update_fx(step)
	expect(fx.orb.visible and not fx.flame.visible and fx.charges_heard == 1, "charging: the orb swells at the nozzle and the charge plays")
	var ring_seen: bool = false
	while hull.boost.phase == "charge":
		hull.advance_motion(step)
		fx.update_fx(step)
		ring_seen = fx.ring.visible
	expect(fx.blasts_heard == 1 and ring_seen, "the blast fires with its sound and a shock ring")
	for tick: int in int(0.4 / step):
		hull.advance_motion(step)
		fx.update_fx(step)
	var outer: MeshInstance3D = fx.flame_cones[0]
	expect(fx.flame.visible and not fx.orb.visible and outer.scale.y > 3.0 * JetFlame.LENGTH_M, "a huge blaster flame (%.1f m, the thruster's is %.1f m)" % [outer.scale.y, JetFlame.LENGTH_M])
	var buckets: Dictionary = {}
	var fastest: float = 0.0
	var last_hue: float = (fx.flame_paints[0] as StandardMaterial3D).albedo_color.h
	for tick: int in int(0.5 / step):
		hull.advance_motion(step)
		fx.update_fx(step)
		var hue: float = (fx.flame_paints[0] as StandardMaterial3D).albedo_color.h
		buckets[int(hue * 6.0) % 6] = true
		fastest = maxf(fastest, absf(angle_difference(last_hue * TAU, hue * TAU)) / TAU / step)
		last_hue = hue
	expect(buckets.size() == 6, "the flame runs through red, yellow, green, cyan, blue and magenta in half a second")
	expect(fastest >= 2.0, "fast RGB (%.1f turns of the colour wheel a second)" % fastest)
	expect(fx.glow_light.light_energy > 3.0, "the under-glow flares in the blast")
	while hull.boost.phase == "blast":
		hull.advance_motion(step)
		fx.update_fx(step)
	fx.update_fx(step)
	expect(not fx.flame.visible and not fx.ring.visible and is_instance_valid(thruster) and thruster.get_parent() == model, "after the blast the flame is gone, the thruster stays")
	# Online the presentation hull runs no physics: the effects move its clock.
	var view_hull: HandlingShip = make_hull("small_jetty")
	view_hull.set_physics_process(false)
	fx.ship = view_hull
	view_hull.request_boost()
	for tick: int in int((Boost.CHARGE_S + 0.2) / step): fx.update_fx(step)
	expect(view_hull.boost.phase == "blast" and fx.flame.visible, "online, the own presentation hull shows the blaster too")
	model.free()
	hull.free()
	view_hull.free()

func peak(samples: PackedByteArray, rate: int, from: float, to: float) -> float:
	var top: float = 0.0
	for index: int in range(int(from * rate), mini(int(to * rate), samples.size() >> 1)):
		top = maxf(top, absf(samples.decode_s16(index * 2) / 32768.0))
	return top

func crossings(samples: PackedByteArray, rate: int, from: float, to: float) -> float:
	var count: int = 0
	var last: int = samples.decode_s16(int(from * rate) * 2)
	for index: int in range(int(from * rate) + 1, mini(int(to * rate), samples.size() >> 1)):
		var value: int = samples.decode_s16(index * 2)
		if (value >= 0) != (last >= 0): count += 1
		last = value
	return count / (to - from)

## Follow-up: the charged beam-cannon sound is made in code from sine, saw and
## noise (no recorded audio): a rising charge whine, then a loud blast that
## dies away.
func jetty_blaster_sound() -> void:
	var charge: AudioStreamWAV = JettyFx.charge_sound()
	var blast: AudioStreamWAV = JettyFx.blast_sound()
	expect(charge != null and blast != null and charge.format == AudioStreamWAV.FORMAT_16_BITS and blast.format == AudioStreamWAV.FORMAT_16_BITS, "the charge and the blast are 16-bit sounds")
	expect(charge.resource_path.is_empty() and blast.resource_path.is_empty() and JettyFx.charge_sound() == charge and JettyFx.blast_sound() == blast, "both are made in code, once")
	var source: String = (JettyFx as GDScript).source_code
	expect(not source.contains(".wav\"") and not source.contains(".ogg") and not source.contains(".mp3") and source.contains("stream.data = samples"), "no recorded audio is loaded")
	expect(absf(charge.get_length() - (Boost.CHARGE_S + 0.04)) < 0.01, "the charge lasts as long as the blaster charges (%.2f s)" % charge.get_length())
	expect(blast.get_length() >= 1.5 and blast.get_length() <= 2.5, "the blast rings for about two seconds (%.2f s)" % blast.get_length())
	var rate: int = charge.mix_rate
	var length: float = charge.get_length()
	var low: float = crossings(charge.data, rate, 0.02, 0.12)
	var high: float = crossings(charge.data, rate, length - 0.14, length - 0.04)
	expect(high > 2.0 * low, "the charge whine rises (%.0f -> %.0f crossings/s)" % [low, high])
	expect(peak(charge.data, rate, length - 0.14, length - 0.04) > 2.0 * peak(charge.data, rate, 0.02, 0.12), "and swells as it fills")
	var blast_length: float = blast.get_length()
	var hit: float = peak(blast.data, blast.mix_rate, 0.0, 0.25)
	expect(hit > 0.6, "the blast hits hard (peak %.2f)" % hit)
	expect(peak(blast.data, blast.mix_rate, blast_length - 0.3, blast_length - 0.15) < hit * 0.35, "and dies away")
	expect(peak(blast.data, blast.mix_rate, blast_length - 0.01, blast_length) < 0.05, "with no click at the end")

## Old saves: 4.0 and 4.0.1 progress rows still load.
func saves() -> void:
	var row: Dictionary = {"xp": 300, "planes": {"plane_prop": {"fuel": 0.4, "condition": 0.6}, "plane_fighter": {"fuel": 1.0, "condition": 1.0}}, "plane": "plane_prop", "mode": "plane", "airport": 2, "plane_job": ""}
	expect(Levels.progress_valid(row), "a 4.0.1 progress row (flying) loads")
	expect(Levels.progress_valid(Levels.fresh_progress()), "a fresh row loads")
