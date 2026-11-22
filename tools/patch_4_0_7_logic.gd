extends RefCounted
## Patch 4.0.7 (issue #234), the scene-free checks. check_catalog.gd runs them
## (run_all); tools/patch_4_0_7_check.gd runs them and then the game scene.
## - version: VERSION is 4.0.7 or later.
## - turn: A / D are an arcade coordinated turn: 90 degrees of heading in at
##   most 5 s at cruise (every plane, both ways), the altitude within 20 m,
##   the bank a result inside the 45 / 60 degree caps, easing in over about
##   0.3 s and level again on release.
## - ground_steer: below rotation speed on the ground A / D steer the nose wheel.
## - flight_still: W / S climb and descend (also mid-turn), the throttle
##   lever, the gear lever, the brakes, the barrel roll and the auto-level
##   still work (the earlier suites cover them in depth too).
## - props: every prop plane has real 2-4 blade props (evenly spaced, pitched,
##   through the hub) with a spinner, a blur disc only at high RPM, spinning by
##   RPM; the Cargo jet's turbofans show fan blades, a lip and an exhaust
##   cone; the Fighter's nozzle glows hotter in afterburner.
## - jetty_look: no legs under the Jetty; dark steel colours; few small cool
##   lights; the thruster where it was.
## - jetty_land: the shared terrain (same height for everyone), a beach the
##   Jetty can climb, a crossing of an island from beach to beach, cliffs and
##   the volcano block, port grounds and runways in use block, the height
##   follows the ground smoothly and never below it.
## - jetty_fx: the exaggerated water effects are pooled GPU particles that
##   scale with speed, the blaster bursts, land kicks up dust or snow, and
##   other captains' Jetties run at a lower level of detail.
const Flight = preload("res://features/planes/flight_model.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Airports = preload("res://features/planes/airports.gd")
const Aviation = preload("res://features/planes/aviation.gd")
const Look = preload("res://features/planes/plane_look.gd")
const Terrain = preload("res://features/planes/terrain.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
const Chunky = preload("res://features/toon/chunky_look.gd")
const JettyFx = preload("res://features/toon/jetty_fx.gd")
const JettyLand = preload("res://features/ships/jetty_land.gd")
const Progression = preload("res://features/game/progression.gd")
const PARTS: Array[String] = ["version", "turn", "ground_steer", "flight_still", "props", "jetty_look", "jetty_land", "jetty_fx"]
const STEP: float = 1.0 / 60.0
var failures: Array[String] = []
var checks: int = 0

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

static func run_all() -> PackedStringArray:
	var suite: RefCounted = new()
	for part: String in PARTS: suite.call_part(part)
	return suite.failures

func call_part(part: String) -> void:
	call(part)

func version() -> void:
	var connection: GDScript = load("res://features/network/play_connection.gd")
	expect(connection.VERSION.naturalnocasecmp_to("4.0.7") >= 0, "VERSION is 4.0.7 or later (%s)" % connection.VERSION)

## A plane at cruise: 3 km up, twice its stall speed, gear up, level.
static func cruise(kind: String) -> RefCounted:
	var m: RefCounted = Flight.make(kind, Airports.start_pose(0))
	m.on_ground = false
	m.position = Airports.all()[0].at + Vector3(0, 3000, 0)
	m.basis = Basis(Vector3.UP, 0.4)
	m.velocity = m.basis.z * Planes.stall_speed(kind) * 2.0
	m.engine = 0.7
	m.gear_down = false
	m.agl_m = 3000.0
	return m

## One key frame through the real key mapping (Aviation.key_order).
static func press(pilot: Node, m: RefCounted, pitch: float, turn: float, roll_keys: float = 0.0, brake: bool = false) -> void:
	var order: Dictionary = pilot.key_order(pitch, turn, roll_keys, brake, STEP)
	m.step({"throttle": maxf(0.0, float(order.throttle)), "brake": minf(1.0, maxf(0.0, -float(order.throttle)) / 0.6), "pitch": order.pitch, "roll": order.roll, "trick": order.yaw, "gear": float(order.gear)}, STEP)

## Item 1: the arcade coordinated turn.
func turn() -> void:
	var pilot: Node = Aviation.new()
	for kind: String in Planes.ORDER:
		var m: RefCounted = cruise(kind)
		var cap: float = rad_to_deg(m.bank_limit())
		var want_dps: float = Flight.FIGHTER_TURN_DPS if kind == "plane_fighter" else Flight.TURN_DPS
		expect(want_dps >= (35.0 if kind == "plane_fighter" else 20.0) and want_dps <= (35.0 if kind == "plane_fighter" else 25.0), "%s: A / D turn about %.0f degrees a second at cruise" % [kind, want_dps])
		for key: float in [1.0, -1.0]:
			m = cruise(kind)
			pilot.model = m
			pilot.lever = 0.7
			for frame: int in 60: press(pilot, m, 0.0, 0.0)
			var start_heading: float = m.heading()
			var start_y: float = m.position.y
			var seconds: float = 0.0
			var turned: float = 0.0
			var worst_y: float = 0.0
			var worst_bank: float = 0.0
			var eased_early: float = -1.0
			var eased_full: float = -1.0
			while turned < PI * 0.5 and seconds < 8.0:
				var before: float = m.heading()
				press(pilot, m, 0.0, key)
				seconds += STEP
				turned += absf(angle_difference(before, m.heading()))
				worst_y = maxf(worst_y, absf(m.position.y - start_y))
				worst_bank = maxf(worst_bank, absf(rad_to_deg(m.full_bank())))
				if eased_early < 0.0 and seconds >= 0.1: eased_early = absf(m.turn_rate_cmd) / m.turn_rate_max()
				if eased_full < 0.0 and seconds >= 0.35: eased_full = absf(m.turn_rate_cmd) / m.turn_rate_max()
			var name: String = "D" if key > 0.0 else "A"
			var right_way: bool = (angle_difference(start_heading, m.heading()) < 0.0) == (key > 0.0)
			expect(seconds <= 5.0 and right_way, "%s: %s turns 90 degrees the right way in %.2f s (at most 5 s)" % [kind, name, seconds])
			expect(worst_y <= 20.0 and not m.crashed, "%s: %s holds the altitude in the turn (within %.1f m, at most 20)" % [kind, name, worst_y])
			expect(worst_bank <= cap + 0.5 and worst_bank >= cap * 0.75, "%s: %s banks as the result of the turn, to its %.0f degree cap at most (%.1f)" % [kind, name, cap, worst_bank])
			expect(eased_early > 0.15 and eased_early < 0.6 and eased_full > 0.98, "%s: %s eases in over about 0.3 s (%.2f at 0.1 s, %.2f at 0.35 s)" % [kind, name, eased_early, eased_full])
			expect(absf(rad_to_deg(m.pitch_angle())) < 8.0, "%s: %s keeps the nose near level (%.1f degrees)" % [kind, name, rad_to_deg(m.pitch_angle())])
			var level_at: float = -1.0
			var hold_y: float = m.position.y
			var drift: float = 0.0
			for frame: int in 240:
				press(pilot, m, 0.0, 0.0)
				drift = maxf(drift, absf(m.position.y - hold_y))
				if level_at < 0.0 and absf(rad_to_deg(m.full_bank())) < 2.0 and absf(m.turn_rate_cmd) < 0.001: level_at = frame * STEP
			expect(level_at >= 0.0 and level_at <= 2.0 and drift < 20.0, "%s: %s released, it rolls level and flies straight (%.2f s)" % [kind, name, level_at])
	pilot.free()

## Item 1: below rotation speed on the runway, A / D steer the nose wheel.
func ground_steer() -> void:
	var pilot: Node = Aviation.new()
	for kind: String in Planes.ORDER:
		var m: RefCounted = Flight.make(kind, Airports.start_pose(0))
		pilot.model = m
		pilot.lever = 0.0
		m.velocity = m.basis.z * 10.0
		var heading: float = m.heading()
		for frame: int in 60: press(pilot, m, 0.0, 1.0)
		expect(m.on_ground and not m.crashed and m.airspeed() < float(Planes.PLANES[kind].rotate_mps), "%s: taxiing below rotation speed it stays on the wheels" % kind)
		expect(angle_difference(heading, m.heading()) < -deg_to_rad(3.0), "%s: D steers the nose wheel right (%.1f degrees)" % [kind, rad_to_deg(angle_difference(heading, m.heading()))])
		expect(absf(m.full_bank()) < 0.01, "%s: and the wings stay level on the ground" % kind)
	pilot.free()

## Item 1: W / S, the throttle, the gear, the brakes, the roll and the
## assists still work with the new turn.
func flight_still() -> void:
	var pilot: Node = Aviation.new()
	for kind: String in Planes.ORDER:
		var m: RefCounted = cruise(kind)
		pilot.model = m
		pilot.lever = 0.9
		var y: float = m.position.y
		for frame: int in 180: press(pilot, m, 1.0, 1.0)
		expect(m.position.y > y + 20.0, "%s: W climbs, even in a turn (%.0f m)" % [kind, m.position.y - y])
		for frame: int in 240: press(pilot, m, 0.0, 0.0)
		y = m.position.y
		for frame: int in 300: press(pilot, m, -1.0, 0.0)
		expect(m.position.y < y - 20.0, "%s: S descends (%.0f m)" % [kind, y - m.position.y])
		for frame: int in 300: press(pilot, m, 0.0, 0.0)
		var held: float = m.position.y
		for frame: int in 300: press(pilot, m, 0.0, 0.0)
		expect(absf(m.position.y - held) < 15.0, "%s: released, the altitude holds (%.1f m)" % [kind, m.position.y - held])
		# A barrel roll (E) still goes all the way round, then it is upright.
		m = cruise(kind)
		pilot.model = m
		pilot.barrel = 0.0
		pilot.barrel_key = 0.0
		var past: bool = false
		for frame: int in 60 * 6:
			press(pilot, m, 0.0, 0.0, 1.0 if frame < 2 else 0.0)
			past = past or absf(m.full_bank()) > deg_to_rad(150.0)
		expect(past and absf(rad_to_deg(m.full_bank())) < 3.0 and m.basis.y.y > 0.9 and not m.crashed, "%s: E still barrel-rolls past the limit and comes back upright" % kind)
		# The gear lever (G) and the lever-held throttle.
		pilot.gear_order = 0.0
		press(pilot, m, 0.0, 0.0)
		expect(not m.gear_down, "%s: the gear lever raises the gear in the air" % kind)
		pilot.gear_order = 1.0
		press(pilot, m, 0.0, 0.0)
		expect(m.gear_down, "%s: and lowers it" % kind)
		pilot.gear_order = 0.0
		press(pilot, m, 0.0, 0.0)
		pilot.lever = 1.0
		var slow: float = m.airspeed()
		for frame: int in 240: press(pilot, m, 0.0, 0.0)
		expect(m.engine > 0.9 and m.airspeed() > slow, "%s: full throttle spools the engine up and speeds it up" % kind)
	# The brakes on the runway.
	var rolling: RefCounted = Flight.make("plane_prop", Airports.start_pose(0))
	rolling.velocity = rolling.basis.z * 20.0
	pilot.model = rolling
	pilot.lever = 0.0
	for frame: int in 60 * 3: press(pilot, rolling, 0.0, 0.0, 0.0, true)
	expect(rolling.airspeed() < 1.0 and rolling.on_ground, "Space brakes a rolling plane to a stop (%.1f m/s)" % rolling.airspeed())
	pilot.free()

## A model's MeshInstance3D children under `node` (recursive).
static func meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child: Node in node.find_children("*", "MeshInstance3D", true, false): found.append(child as MeshInstance3D)
	return found

## Item 2: real props, fans and the Fighter's nozzle.
func props() -> void:
	for kind: String in Planes.ORDER:
		var model: Node3D = Look.model(kind)
		var props_node: Node = model.find_child("Props", true, false)
		var engines: String = str(Planes.PLANES[kind].engines)
		if engines.begins_with("prop"):
			var hubs: Array[Node] = props_node.find_children("*Prop*", "", false, false)
			expect(hubs.size() == (1 if engines == "prop1" else 2), "%s: %d propellers" % [kind, hubs.size()])
			for hub: Node in hubs:
				var pivots: Array[Node] = hub.find_children("Blade*", "", false, false)
				var count: int = pivots.size()
				expect(count >= 2 and count <= 4, "%s: a %d-blade prop" % [kind, count])
				var even: bool = true
				var pitched: bool = true
				var through_hub: bool = true
				for index: int in count:
					var pivot: Node3D = pivots[index] as Node3D
					even = even and is_equal_approx(fposmod(pivot.rotation.z, TAU), fposmod(TAU / count * index, TAU))
					for piece: Node in pivot.get_children():
						var blade: MeshInstance3D = piece as MeshInstance3D
						pitched = pitched and absf(blade.rotation.y) > deg_to_rad(10.0)
						var box: AABB = blade.mesh.get_aabb()
						through_hub = through_hub and absf(box.get_center().x) < 0.05 and box.position.y >= -0.01
				expect(even and pitched and through_hub, "%s: the blades are evenly spaced, pitched and run out from the hub (no arrow)" % kind)
				var spinner: bool = false
				for child: Node in hub.get_children():
					if child is MeshInstance3D and (child as MeshInstance3D).mesh is CylinderMesh and ((child as MeshInstance3D).mesh as CylinderMesh).top_radius < 0.05 * ((child as MeshInstance3D).mesh as CylinderMesh).bottom_radius + 0.02: spinner = true
				expect(spinner, "%s: a pointed spinner on the hub" % kind)
			var blur: MeshInstance3D = hubs[0].get_node_or_null("Blur") as MeshInstance3D
			var turns: float = (hubs[0] as Node3D).rotation.z
			for frame: int in 120: Look.animate(model, 0.15, true, STEP)
			var idle_rate: float = ((hubs[0] as Node3D).rotation.z - turns) / 2.0
			expect(blur != null and not blur.visible, "%s: no blur disc at idle RPM" % kind)
			for frame: int in 240: Look.animate(model, 1.0, true, STEP)
			turns = (hubs[0] as Node3D).rotation.z
			for frame: int in 60: Look.animate(model, 1.0, true, STEP)
			var full_rate: float = (hubs[0] as Node3D).rotation.z - turns
			var alpha: float = (blur.material_override as StandardMaterial3D).albedo_color.a
			expect(blur.visible and alpha > 0.05 and alpha <= Look.BLUR_ALPHA + 0.001, "%s: a subtle translucent blur disc at high RPM (alpha %.2f)" % [kind, alpha])
			expect(full_rate > idle_rate * 3.0, "%s: the prop spins by RPM (%.0f vs %.0f rad/s)" % [kind, full_rate, idle_rate])
		elif engines == "fan2":
			var fans: Array[Node] = model.find_children("Fan*", "", true, false)
			expect(fans.size() == 2, "%s: two turbofans" % kind)
			for fan: Node in fans:
				expect(fan.find_children("Blade*", "", false, false).size() == Look.FAN_BLADES, "%s: %s shows its %d fan blades" % [kind, fan.name, Look.FAN_BLADES])
			var lips: int = 0
			var cones: int = 0
			for mesh: MeshInstance3D in meshes(model):
				if mesh.mesh is TorusMesh: lips += 1
				if mesh.mesh is CylinderMesh and (mesh.mesh as CylinderMesh).top_radius < 0.05 and mesh.position.z < 0.0 and absf(mesh.rotation.x + PI / 2.0) < 0.01: cones += 1
			expect(lips == 2 and cones >= 2, "%s: each nacelle has an intake lip and an exhaust cone (%d, %d)" % [kind, lips, cones])
		else:
			var glow: MeshInstance3D = model.find_child("NozzleGlow", true, false) as MeshInstance3D
			if expect(glow != null and model.find_child("JetFlame", true, false) != null, "%s: a nozzle with a glowing throat and its flame" % kind):
				Look.animate(model, 0.2, true, STEP)
				var cool: Color = (glow.material_override as StandardMaterial3D).albedo_color
				Look.animate(model, 1.0, true, STEP)
				var hot: Color = (glow.material_override as StandardMaterial3D).albedo_color
				expect(hot.get_luminance() > cool.get_luminance() + 0.2, "%s: the nozzle glows white-hot in afterburner (%.2f vs %.2f)" % [kind, hot.get_luminance(), cool.get_luminance()])
		model.free()

## Item 3: the Jetty has no legs and is dark steel.
func jetty_look() -> void:
	var definition: ShipDefinition = Progression.definition("small_jetty")
	var model: Node3D = Chunky.model("small_jetty", definition)
	var hull: MeshInstance3D = model.get_node("Hull") as MeshInstance3D
	var keel: float = hull.mesh.get_aabb().position.y
	var legs: int = 0
	var lights: int = 0
	var fx: Node = model.find_child("JettyFx", true, false)
	for mesh: MeshInstance3D in meshes(model):
		if fx != null and fx.is_ancestor_of(mesh): continue
		if mesh == hull: continue
		var box: AABB = mesh.get_aabb()
		var bottom: float = (mesh.transform * box).position.y
		if bottom < keel + 0.3 and mesh.get_parent() == model: legs += 1
		var paint: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		if paint != null and paint.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: lights += 1
	expect(legs == 0, "the Jetty has no legs, struts or foils under it (%d parts reach down)" % legs)
	expect(lights > 0 and lights <= 6, "only a few small cool-white accent lights (%d)" % lights)
	var colours: PackedColorArray = hull.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var dark: bool = not colours.is_empty()
	for colour: Color in colours:
		var plain: Color = colour.linear_to_srgb()
		dark = dark and plain.get_luminance() < 0.8 and plain.s < 0.25
	expect(dark, "the hull is grey, black and steel (no teal or orange)")
	var flame: Node3D = model.find_child("JetFlame", true, false) as Node3D
	var deck: float = 2.6 * definition.hull_size_m.y / 4.0
	expect(flame != null and flame.position.is_equal_approx(Vector3(0, deck - 0.1, -definition.hull_size_m.z / 2.0 - 0.88)), "the thruster and its flame are where they were")
	expect(fx != null, "the hover and blaster effects are kept")
	expect(keel > -1.0 and ShipVisualMotion.HOVER_REST_M + keel >= JettyLand.RIDE_M - 0.01, "the keel rides about %.1f m clear at rest (%.2f m)" % [JettyLand.RIDE_M, ShipVisualMotion.HOVER_REST_M + keel])
	model.free()

## A straight crossing of an island from water to water that the Jetty may
## make, {from, to, top}, or {} (searched on a grid, in a fixed order).
static func island_crossing() -> Dictionary:
	var half: float = Progression.WRAP_M / 2.0
	var centre: Vector3 = Progression.WRAP_CENTRE
	for gx: int in range(-20, 21):
		for gz: int in range(-20, 21):
			var spot: Vector3 = centre + Vector3(gx, 0, gz) * (half / 20.0)
			if JettyLand.surface(spot) != "land": continue
			for way: int in 8:
				var dir: Vector3 = Vector3(sin(way * PI / 4.0), 0, cos(way * PI / 4.0))
				var a: Vector3 = spot
				var b: Vector3 = spot
				var steps: int = 0
				while JettyLand.over_land(a) and steps < 150:
					a -= dir * 10.0
					steps += 1
				while JettyLand.over_land(b) and steps < 300:
					b += dir * 10.0
					steps += 1
				if steps >= 300: continue
				a -= dir * 80.0
				b += dir * 80.0
				if JettyLand.surface(a) != "water" or JettyLand.surface(b) != "water": continue
				var clear: bool = true
				var top: float = 0.0
				var at: Vector3 = a
				for index: int in int(a.distance_to(b) / 8.0):
					var next: Vector3 = a + dir * 8.0 * (index + 1)
					if not JettyLand.blocked_step(at, next).is_empty():
						clear = false
						break
					top = maxf(top, JettyLand.ground_height(next))
					at = next
				if clear and top > 6.0 and a.distance_to(b) > 300.0: return {"from": a, "to": b, "top": top, "dir": dir}
	return {}

## Item 4: the Jetty over land, by the shared terrain.
func jetty_land() -> void:
	# Shared and deterministic: the same answer every time, from baked data.
	var probe: Vector3 = Vector3(1234.5, 0, -2345.5)
	expect(JettyLand.ground_height(probe) == maxf(Terrain.height_at(probe), 0.0) and JettyLand.ground_height(probe) == JettyLand.ground_height(probe), "the ride height is the shared terrain's (never below the sea)")
	# The terrain follows the drawn beach: no step at the waterline.
	expect(is_equal_approx(maxf(TOON_COAST.sand_height(5.0, 0.0), 0.0), maxf(TOON_COAST.sand_height(5.0, 0.0), 0.0)) and TOON_COAST.sand_height(5.0, 0.0) < TOON_COAST.HILL_FOOT_Y - 1.0, "near the waterline the ground is the beach, not the hill's foot")
	var crossing: Dictionary = island_crossing()
	if expect(not crossing.is_empty(), "an island the Jetty can cross from beach to beach"):
		expect(float(crossing.top) > 6.0, "over its hill (%.1f m up)" % float(crossing.top))
		# The height follows the ground: climbing, never under it.
		var at: Vector3 = crossing.from
		var height: float = 0.0
		var under: bool = false
		var lag: float = 0.0
		var dir: Vector3 = crossing.dir
		var end: Vector3 = Vector3(crossing.to) + dir * 200.0
		while at.distance_to(end) > 5.0:
			var travel: Vector3 = dir * 150.0 * STEP
			height = JettyLand.follow_height(at, height, travel, STEP)
			at += travel
			under = under or height < JettyLand.ground_height(at) - 0.001
			lag = maxf(lag, height - JettyLand.ground_height(at))
		expect(not under, "at 150 m/s it never dips under the ground")
		expect(height < 0.5, "and settles back onto the water on the far side (%.2f m)" % height)
	# Steeper than 35 degrees blocks: the volcano and an ice cliff.
	var volcano: Vector3 = Vector3(Progression.VOLCANO.at.x, 0, Progression.VOLCANO.at.y)
	var foot: Vector3 = volcano + Vector3(float(Progression.VOLCANO.base_m) * 0.9, 0, 0)
	expect(JettyLand.blocked_step(foot, foot - Vector3(30, 0, 0)) == "slope", "the volcano's flank is too steep (%s)" % JettyLand.blocked_step(foot, foot - Vector3(30, 0, 0)))
	var cliff: Vector3 = Vector3.INF
	for step: int in 400:
		var spot: Vector3 = Progression.WRAP_CENTRE + Vector3(-Progression.WRAP_M * 0.5 + step * 50.0, 0, Progression.WRAP_M * 0.5 - 1.0)
		var to: Vector3 = spot
		for inward: int in 300:
			to = spot - Vector3(0, 0, inward * 4.0)
			if Terrain.sample(to).surface == "ice": break
		if Terrain.sample(to).surface == "ice" and float(Terrain.sample(to).height) > 8.0 and JettyLand.ground_height(to + Vector3(0, 0, 6)) < 0.1:
			cliff = to
			break
	if cliff != Vector3.INF: expect(JettyLand.blocked_step(cliff + Vector3(0, 0, 6), cliff) == "slope", "the polar ice cliff blocks")
	# Port grounds (buildings, cranes, no docking from land) and busy runways.
	var place: Dictionary = Progression.WORLD[0]
	var quay: Vector3 = Vector3(place.at.x, 0, place.at.z + 300.0)
	expect(JettyLand.port_ground(quay), "the land round a port's quay is port ground")
	# From the airfield's grass beside a runway onto it: free, blocked while a
	# plane uses it, free again after.
	var field: int = 0
	var runway: Vector3 = Airports.all()[field].at
	runway.y = 0.0
	JettyLand.busy_runways.erase(field)
	var axis: Vector3 = Vector3(sin(Airports.all()[field].heading), 0, cos(Airports.all()[field].heading))
	var side: Vector3 = Vector3(axis.z, 0, -axis.x)
	var grass: Vector3 = runway
	for reach: int in 400:
		grass = runway + side * (reach * 1.0)
		if Terrain.sample(grass).surface == "airfield": break
	grass += side * 3.0
	var why: String = JettyLand.blocked_step(grass, runway)
	JettyLand.mark_runway_busy(field)
	var busy: String = JettyLand.blocked_step(grass, runway)
	JettyLand.busy_runways[field] = Time.get_ticks_msec() - 1
	var later: String = JettyLand.blocked_step(grass, runway)
	expect(why != "runway" and busy == "runway" and later != "runway", "a runway blocks only while in use (%s, %s, %s)" % [why, busy, later])
	JettyLand.busy_runways.erase(field)

## Item 5: the exaggerated, pooled effects.
func jetty_fx() -> void:
	var definition: ShipDefinition = Progression.definition("small_jetty")
	var model: Node3D = Chunky.model("small_jetty", definition)
	var twin: Node3D = Chunky.model("small_jetty", definition)
	var fx: Node3D = model.find_child("JettyFx", true, false) as Node3D
	var other: Node3D = twin.find_child("JettyFx", true, false) as Node3D
	fx._ready()
	other._ready()
	for label: String in ["Downwash", "RoosterTail", "SprayLeft", "SprayRight", "WakeTrench", "Depression", "Ripple0", "Ripple1", "BoostBurst", "BurstLight", "SpeedLines", "Dust", "Glow", "BoostFlame", "ChargeOrb", "BlastRing"]:
		expect(fx.get_node_or_null(label) != null, "the Jetty's effects have %s" % label)
	var gpu: bool = true
	for node: Node in fx.get_children():
		if node is CPUParticles3D: gpu = false
	expect(gpu and fx.rooster is GPUParticles3D and fx.spray_left is GPUParticles3D and fx.dust is GPUParticles3D, "every spray is GPU particles")
	expect(fx.rooster.process_material == other.rooster.process_material and fx.rooster.draw_pass_1 == other.rooster.draw_pass_1 and fx.wake.mesh == other.wake.mesh, "two Jetties share one pool of particle materials and meshes")
	var hull: HandlingShip = HandlingShip.new()
	hull.definition = definition
	hull._ready()
	fx.ship = hull
	var top: float = definition.forward_acceleration_mps2 / definition.linear_drag_per_second
	hull.velocity = Vector3(0, 0, top * 0.1)
	fx.update_fx(STEP)
	var slow_plume: Vector3 = fx.rooster.scale
	var slow_wake: Vector3 = fx.wake.scale
	hull.velocity = Vector3(0, 0, top)
	fx.update_fx(STEP)
	expect(fx.rooster.emitting and fx.spray_left.emitting and fx.spray_right.emitting and fx.wake.visible and fx.depression.visible and fx.downwash.emitting, "at speed on the water: plume, spray sheets, the V wake, the depression and the mist")
	expect(fx.rooster.scale.z > slow_plume.z * 2.5 and fx.wake.scale.z > slow_wake.z * 3.0, "the plume and the wake grow with speed (%.1f vs %.1f, %.0f vs %.0f m)" % [fx.rooster.scale.z, slow_plume.z, fx.wake.scale.z, slow_wake.z])
	var material: ParticleProcessMaterial = fx.rooster.process_material as ParticleProcessMaterial
	var reach: float = material.initial_velocity_max * fx.rooster.lifetime * fx.rooster.scale.z * 0.8
	expect(reach > definition.hull_size_m.z * 4.0, "the rooster tail reaches several boat-lengths back (%.0f m)" % reach)
	expect(not fx.speed_lines.emitting or fx.ship != null, "speed lines only for a Jetty")
	hull.request_boost()
	for tick: int in int((JettyFx.JETTY_BOOST.CHARGE_S + 0.1) / STEP):
		hull.advance_motion(STEP)
		fx.update_fx(STEP)
	expect(fx.bursts_fired == 1 and fx.burst.one_shot and fx.burst_light.visible, "the blast fires a big white-hot burst and a flash")
	# Over land: dust (sand) or snow (ice), and no water effects.
	fx.ground = "land"
	fx.ground_age = -100.0
	fx.update_fx(STEP)
	expect(fx.dust.emitting and not fx.rooster.emitting and not fx.wake.visible and not fx.depression.visible, "over land it kicks up dust instead of spray")
	var sand: Material = fx.dust.process_material
	fx.ground = "ice"
	fx.update_fx(STEP)
	expect(fx.dust.process_material != sand, "and snow over the ice")
	# Remote Jetties run at a lower level of detail.
	fx.ground = "water"
	hull.set_meta("remote_replica", true)
	fx.update_fx(STEP)
	expect(fx.remote and fx.level_of_detail() < 1.0 and fx.rooster.amount_ratio < 1.0, "another captain's Jetty runs fewer particles (%.2f)" % fx.level_of_detail())
	expect(not fx.speed_lines.emitting and fx.kicked_camera == null, "and never touches this captain's camera")
	model.free()
	twin.free()
	hull.free()
