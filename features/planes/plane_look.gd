extends RefCounted
## Patch 4.0: the planes, the airports and the crash, built in code in the
## game's chunky toon style (features/toon/chunky_look.gd): bold flat
## colours, few-sided shapes, and toon_look's shading and ink outline over
## them. Looks only: nothing here collides or owns state.
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const JET_FLAME = preload("res://features/toon/jet_flame.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Airports = preload("res://features/planes/airports.gd")
const WHITE: Color = Color("f6f1e3")
const INK: Color = Color("2b2f3a")
const GLASS: Color = Color("24405e")
const TARMAC: Color = Color("4a4f5c")
const STRIPE: Color = Color("f2efe2")
const GRASS_BANK: Color = Color("6f9a5a")
const SNOW_BANK: Color = Color("eef6fa")
## Patch 4.0.2 item 6: the landing gear. It folds up into its wells in
## GEAR_TRAVEL_S seconds (the nose leg forward, the mains inward), the well
## doors swinging open while it moves. Grey legs with a silver oleo, black
## tyres on pale hubs.
const GEAR_TRAVEL_S: float = 1.5
const LEG: Color = Color("9aa1ad")
const OLEO: Color = Color("d9dde3")
const TYRE: Color = Color("23262e")
const HUB: Color = Color("c9ccd4")
## Patch 4.0.2 item 3: the airfield's grass top stands this far below the
## runway's surface and has holes where the runway and the apron are, so
## no two surfaces ever overlap (no z-fighting at any distance). The tarmac
## slabs are SLAB_M thick; the apron's top is APRON_DROP_M below the runway's.
const FIELD_DROP_M: float = 0.12
const APRON_DROP_M: float = 0.04
const SLAB_M: float = 1.2

static func _paint(colour: Color, cache: Dictionary) -> StandardMaterial3D:
	if not cache.has(colour):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.9
		cache[colour] = material
	return cache[colour]

static func _box(parent: Node3D, size: Vector3, at: Vector3, colour: Color, cache: Dictionary) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = _paint(colour, cache)
	parent.add_child(node)
	return node

static func _drum(parent: Node3D, bottom: float, top: float, height: float, at: Vector3, colour: Color, cache: Dictionary, sides: int = 10) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = _paint(colour, cache)
	parent.add_child(node)
	return node

## A plane of `kind`, nose along +Z, wheels at y = 0 (the gear's contact).
## Children: "Props" (spinning prop blades, prop planes, and the Cargo jet's
## turbofan fans "Fan0" and "Fan1"), "HeatShimmer" (the turbofans' faint exhaust haze),
## "JetFlame" (only the Fighter jet's afterburner), "Gear" (hidden in flight).
## Toon-shaded.
static func model(kind: String) -> Node3D:
	var p: Dictionary = Planes.PLANES[kind]
	if str(p.engines) == "afterburner": return _fighter(kind)
	var cache: Dictionary = {}
	var root: Node3D = Node3D.new()
	root.name = "Plane"
	root.set_meta("paint", str(p.colour))
	var length: float = float(p.length_m)
	var span: float = float(p.span_m)
	var main: Color = Color(str(p.colour))
	var trim: Color = Color("ffc940") if kind != "plane_jet" else Color("e2574c")
	var body_r: float = length * (0.075 if kind == "plane_prop" else 0.085)
	var gear_h: float = clampf(length * 0.12, 1.2, 4.5)
	var y: float = gear_h + body_r * 0.6
	var body: Node3D = Node3D.new()
	body.name = "Body"
	root.add_child(body)
	# Fuselage: a long drum, a rounded nose and a tapered tail cone.
	var fuselage: MeshInstance3D = _drum(body, body_r, body_r, length * 0.62, Vector3(0, y, length * 0.04), main, cache, 12)
	fuselage.rotation.x = PI / 2.0
	var nose: MeshInstance3D = _drum(body, body_r * 0.35, body_r, length * 0.14, Vector3(0, y, length * 0.42), main, cache, 12)
	nose.rotation.x = -PI / 2.0
	var tail: MeshInstance3D = _drum(body, body_r * 0.25, body_r, length * 0.26, Vector3(0, y + body_r * 0.25, -length * 0.4), main, cache, 12)
	tail.rotation.x = PI / 2.0
	# A trim stripe down each side and the cockpit glass.
	for side: float in [-1.0, 1.0]:
		_box(body, Vector3(0.06, body_r * 0.3, length * 0.6), Vector3(side * body_r * 0.98, y, length * 0.02), trim, cache)
	_box(body, Vector3(body_r * 1.3, body_r * 0.5, length * 0.08), Vector3(0, y + body_r * 0.55, length * 0.33), GLASS, cache)
	# Wings (high wing on the prop, low on the others), tailplane and fin.
	var wing_y: float = y + (body_r * 0.85 if kind == "plane_prop" else -body_r * 0.4)
	var chord: float = length * (0.16 if kind == "plane_prop" else 0.13)
	var wing: MeshInstance3D = _box(body, Vector3(span, maxf(0.18, body_r * 0.16), chord), Vector3(0, wing_y, length * 0.05), main, cache)
	wing.name = "Wing"
	for side: float in [-1.0, 1.0]:
		_box(body, Vector3(span * 0.08, maxf(0.2, body_r * 0.18), chord * 0.9), Vector3(side * span * 0.46, wing_y + 0.02, length * 0.05), trim, cache)
	_box(body, Vector3(span * 0.36, maxf(0.14, body_r * 0.12), chord * 0.7), Vector3(0, y + body_r * 0.4, -length * 0.45), main, cache)
	var fin: MeshInstance3D = _box(body, Vector3(maxf(0.14, body_r * 0.14), length * 0.16, chord * 0.9), Vector3(0, y + body_r + length * 0.07, -length * 0.44), trim, cache)
	fin.rotation.x = 0.3
	# Engines.
	var props: Node3D = Node3D.new()
	props.name = "Props"
	body.add_child(props)
	match str(p.engines):
		"prop1":
			# Patch 4.0.7 item 2: a two-blade prop with a spinner, clear of the ground.
			_prop(props, Vector3(0, y, length * 0.5 + 0.05), minf(body_r * 2.4, y * 0.85), 2, trim, cache)
		"prop2":
			# Patch 4.0.7 item 2: four-blade props on slim nacelles, clear of
			# the ground and the fuselage (the old blades made an arrow).
			for side: float in [-1.0, 1.0]:
				var x: float = side * span * 0.2
				var engine_y: float = wing_y - body_r * 0.2
				var nacelle: MeshInstance3D = _drum(body, body_r * 0.38, body_r * 0.3, chord * 1.5, Vector3(x, engine_y, length * 0.1), WHITE, cache, 12)
				nacelle.rotation.x = PI / 2.0
				var exhaust: MeshInstance3D = _drum(body, body_r * 0.12, body_r * 0.16, chord * 0.3, Vector3(x + side * body_r * 0.3, engine_y + body_r * 0.1, length * 0.1 - chord * 0.2), INK, cache, 8)
				exhaust.rotation.x = -PI / 2.0
				_prop(props, Vector3(x, engine_y, length * 0.1 + chord * 0.8), minf(body_r * 1.5, engine_y * 0.85), 4, trim, cache)
		"fan2":
			# Patch 4.0.1 item 5: turbofans, no flames. An under-wing nacelle on
			# a pylon, a dark intake with a fan that spins with the throttle,
			# a grey core nozzle and at most a faint heat shimmer behind it.
			# Patch 4.0.7 item 2: a rounded intake lip ring with the fan's
			# blades visible inside it, a spinner, and at the back a core
			# nozzle with a pointed exhaust cone.
			for side: float in [-1.0, 1.0]:
				var x: float = side * span * 0.24
				var radius: float = body_r * 0.5
				var at: Vector3 = Vector3(x, wing_y - body_r * 0.75, length * 0.12)
				_box(body, Vector3(radius * 0.25, body_r * 0.5, chord * 0.8), Vector3(x, wing_y - body_r * 0.3, length * 0.1), WHITE, cache)
				var pod: MeshInstance3D = _drum(body, radius * 0.86, radius, chord * 1.4, at, WHITE, cache, 16)
				pod.rotation.x = PI / 2.0
				var intake: MeshInstance3D = _drum(body, radius * 0.9, radius * 0.9, chord * 0.04, at + Vector3(0, 0, chord * 0.71), INK, cache, 16)
				intake.rotation.x = PI / 2.0
				var lip: MeshInstance3D = MeshInstance3D.new()
				var ring: TorusMesh = TorusMesh.new()
				ring.inner_radius = radius * 0.86
				ring.outer_radius = radius * 1.06
				ring.rings = 20
				ring.ring_segments = 8
				lip.mesh = ring
				lip.rotation.x = PI / 2.0
				lip.position = at + Vector3(0, 0, chord * 0.76)
				lip.material_override = _paint(Color("c9ccd4"), cache)
				body.add_child(lip)
				var core: MeshInstance3D = _drum(body, radius * 0.62, radius * 0.42, chord * 0.4, at - Vector3(0, 0, chord * 0.86), Color("8a8f9c"), cache, 12)
				core.rotation.x = -PI / 2.0
				var plug: MeshInstance3D = _drum(body, radius * 0.36, radius * 0.02, chord * 0.42, at - Vector3(0, 0, chord * 1.2), INK, cache, 10)
				plug.rotation.x = -PI / 2.0
				_fan(props, at + Vector3(0, 0, chord * 0.74), radius * 0.84, cache, "Fan%d" % (0 if side < 0.0 else 1))
				var shimmer: MeshInstance3D = MeshInstance3D.new()
				shimmer.name = "HeatShimmer"
				var haze: CylinderMesh = CylinderMesh.new()
				haze.top_radius = radius * 0.6
				haze.bottom_radius = radius * 0.35
				haze.height = chord * 1.2
				haze.radial_segments = 10
				haze.rings = 1
				shimmer.mesh = haze
				shimmer.rotation.x = PI / 2.0
				shimmer.position = at - Vector3(0, 0, chord * 1.6)
				var air: StandardMaterial3D = StandardMaterial3D.new()
				air.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				air.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				air.albedo_color = Color(1.0, 0.97, 0.9, 0.0)
				air.cull_mode = BaseMaterial3D.CULL_DISABLED
				shimmer.material_override = air
				shimmer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				body.add_child(shimmer)
	# Gear (Patch 4.0.2 item 6): a nose leg and two mains, each folding into a well.
	_gear(root, [Vector3(0, 0, length * 0.36), Vector3(-span * 0.08 - body_r, 0, -length * 0.02), Vector3(span * 0.08 + body_r, 0, -length * 0.02)],
		gear_h, maxf(1.0, body_r * 0.6), kind in ["plane_jet", "plane_turboprop"], cache)
	TOON_LOOK.apply(root)
	return root

## Patch 4.0.2 item 6: the landing gear under "Gear": one "Leg<n>" pivot per
## leg at the top of its strut (the well), holding the strut, the silver
## oleo, a torque link, the axle and the wheel(s) down to y = 0; a dark
## "Well<n>" in the belly and a pair of "Door<n>" panels beside it. The
## first leg is the nose leg. animate() folds them.
static func _gear(root: Node3D, legs: Array, gear_h: float, thick: float, twin: bool, cache: Dictionary) -> void:
	var gear: Node3D = Node3D.new()
	gear.name = "Gear"
	gear.set_meta("travel", 1.0)
	root.add_child(gear)
	var wheel_r: float = gear_h * 0.27
	for index: int in legs.size():
		var at: Vector3 = legs[index]
		var nose: bool = index == 0
		var pivot: Node3D = Node3D.new()
		pivot.name = "Leg%d" % index
		pivot.position = Vector3(at.x, gear_h, at.z)
		pivot.set_meta("fold", Vector3(-PI * 0.5, 0, 0) if nose else Vector3(0, 0, -signf(at.x) * PI * 0.5))
		gear.add_child(pivot)
		var strut: float = gear_h - wheel_r
		_box(pivot, Vector3(0.16, strut * 0.6, 0.16) * thick, Vector3(0, -strut * 0.3, 0), LEG, cache)
		_drum(pivot, 0.06 * thick, 0.06 * thick, strut * 0.45, Vector3(0, -strut * 0.78, 0), OLEO, cache, 8)
		var link: MeshInstance3D = _box(pivot, Vector3(0.05, strut * 0.3, 0.05) * thick, Vector3(0, -strut * 0.72, 0.09 * thick), LEG, cache)
		link.rotation.x = 0.35
		var pair: Array = [-1.0, 1.0] if twin else [0.0]
		var axle_w: float = wheel_r * (1.5 if pair.size() > 1 else 0.6)
		var axle: MeshInstance3D = _drum(pivot, 0.05 * thick, 0.05 * thick, axle_w, Vector3(0, -strut, 0), LEG, cache, 6)
		axle.rotation.z = PI / 2.0
		for offset: float in pair:
			var x: float = offset * axle_w * 0.5
			var tyre: MeshInstance3D = _drum(pivot, wheel_r, wheel_r, wheel_r * 0.7, Vector3(x, -strut, 0), TYRE, cache, 14)
			tyre.rotation.z = PI / 2.0
			var hub: MeshInstance3D = _drum(pivot, wheel_r * 0.5, wheel_r * 0.5, wheel_r * 0.76, Vector3(x, -strut, 0), HUB, cache, 10)
			hub.rotation.z = PI / 2.0
		# The well in the belly and its two doors (closed flush when the gear is up).
		var well: MeshInstance3D = _box(gear, Vector3(wheel_r * 2.2, 0.08, (strut + wheel_r) * (1.0 if nose else 0.6)) if nose else Vector3((strut + wheel_r) * 0.9, 0.08, wheel_r * 2.4), Vector3(at.x, gear_h + 0.02, at.z), INK, cache)
		well.name = "Well%d" % index
		for side: float in [-1.0, 1.0]:
			var hinge: Node3D = Node3D.new()
			hinge.name = "Door%d%s" % [index, "L" if side < 0.0 else "R"]
			hinge.position = Vector3(at.x + side * wheel_r * 1.15, gear_h - 0.01, at.z)
			hinge.set_meta("side", side)
			gear.add_child(hinge)
			_box(hinge, Vector3(wheel_r * 1.1, 0.06, (strut + wheel_r) * (0.9 if nose else 0.55)), Vector3(-side * wheel_r * 0.55, 0, 0), main_door(root), cache)

## The door paint: the plane's own colour (its fuselage's paint).
static func main_door(root: Node3D) -> Color:
	return Color(str(root.get_meta("paint", "c9ccd4")))

## Patch 4.0.1 item 5: a turbofan's front fan: a spinner and a ring of wide
## blades, spun about +Z by animate() like a prop hub.
## Patch 4.0.7 item 2: FAN_BLADES evenly spaced, pitched blades from the hub
## to the lip, each on its own pivot (so every blade runs through the hub),
## and a white spinner cone with a dark swirl mark (it shows the spin).
const FAN_BLADES: int = 18
const FAN_PITCH_RAD: float = 0.6
static func _fan(parent: Node3D, at: Vector3, radius: float, cache: Dictionary, label: String = "Fan") -> void:
	var hub: Node3D = Node3D.new()
	hub.name = label
	hub.position = at
	parent.add_child(hub)
	var spinner: MeshInstance3D = _drum(hub, radius * 0.3, radius * 0.02, radius * 0.5, Vector3(0, 0, radius * 0.22), WHITE, cache, 12)
	spinner.rotation.x = PI / 2.0
	_box(hub, Vector3(radius * 0.05, radius * 0.22, radius * 0.04), Vector3(0, radius * 0.15, radius * 0.12), INK, cache).rotation.x = -0.55
	var blade_mesh: ArrayMesh = _blade_mesh(radius * 0.26, radius * 0.97, radius * 0.17, radius * 0.2, radius * 0.03)
	for index: int in FAN_BLADES:
		var pivot: Node3D = Node3D.new()
		pivot.name = "Blade%d" % index
		pivot.rotation.z = TAU / FAN_BLADES * index
		hub.add_child(pivot)
		var blade: MeshInstance3D = MeshInstance3D.new()
		blade.mesh = blade_mesh
		blade.rotation.y = FAN_PITCH_RAD
		blade.material_override = _paint(Color("7b8291"), cache)
		pivot.add_child(blade)

## Patch 4.0.7 item 2: one blade along +Y, from `root` to `tip` metres off
## the axis: a lens-shaped section, widest a third of the way out
## (`chord_root` at the root, `chord_mid` there, a rounded narrower tip),
## `thick` through. Closed, flat-shaded, so the toon outline wraps it.
static func _blade_mesh(root: float, tip: float, chord_root: float, chord_mid: float, thick: float) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stations: Array = [[root, chord_root], [lerpf(root, tip, 0.35), chord_mid], [lerpf(root, tip, 0.85), chord_mid * 0.75], [tip, chord_mid * 0.35]]
	var rings: Array = []
	for station: Array in stations:
		var y: float = station[0]
		var half: float = float(station[1]) * 0.5
		var t: float = thick * (0.5 if y < tip else 0.3)
		rings.append([Vector3(-half, y, 0), Vector3(0, y, t), Vector3(half, y, 0), Vector3(0, y, -t)])
	for index: int in rings.size() - 1:
		var a: Array = rings[index]
		var b: Array = rings[index + 1]
		var centre: Vector3 = Vector3(0, (float(stations[index][0]) + float(stations[index + 1][0])) * 0.5, 0)
		for side: int in 4:
			var next: int = (side + 1) % 4
			var outward: Vector3 = (a[side] + a[next]) * 0.5 - centre
			outward.y = 0.0
			_triangle(tool, a[side], b[side], b[next], outward)
			_triangle(tool, a[side], b[next], a[next], outward)
	for cap: int in [0, rings.size() - 1]:
		var ring: Array = rings[cap]
		var facing: Vector3 = Vector3.DOWN if cap == 0 else Vector3.UP
		_triangle(tool, ring[0], ring[1], ring[2], facing)
		_triangle(tool, ring[0], ring[2], ring[3], facing)
	return tool.commit()

## Patch 4.0.1 item 4: the Fighter jet. A sleek grey dart: a slim fuselage
## with a long pointed nose and a bubble canopy, swept delta wings, twin
## canted fins and one afterburner nozzle whose flame (JET_FLAME, "JetFlame")
## grows with the throttle. The same nodes as the others ("Gear", "Props"
## empty, "Body").
static func _fighter(kind: String) -> Node3D:
	var p: Dictionary = Planes.PLANES[kind]
	var cache: Dictionary = {}
	var root: Node3D = Node3D.new()
	root.name = "Plane"
	root.set_meta("paint", str(p.colour))
	var length: float = float(p.length_m)
	var span: float = float(p.span_m)
	var main: Color = Color(str(p.colour))
	var dark: Color = Color("4b5566")
	var trim: Color = Color("e2574c")
	var body_r: float = length * 0.055
	var gear_h: float = clampf(length * 0.12, 1.2, 4.5)
	var y: float = gear_h + body_r * 0.7
	var body: Node3D = Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var fuselage: MeshInstance3D = _drum(body, body_r * 1.05, body_r * 0.85, length * 0.62, Vector3(0, y, -length * 0.04), main, cache, 12)
	fuselage.rotation.x = -PI / 2.0
	var nose: MeshInstance3D = _drum(body, body_r * 0.85, 0.04, length * 0.3, Vector3(0, y, length * 0.42), main, cache, 12)
	nose.rotation.x = PI / 2.0
	var tip: MeshInstance3D = _drum(body, 0.06, 0.02, length * 0.06, Vector3(0, y, length * 0.6), dark, cache, 6)
	tip.rotation.x = PI / 2.0
	var canopy: MeshInstance3D = _drum(body, body_r * 0.55, body_r * 0.2, length * 0.2, Vector3(0, y + body_r * 0.8, length * 0.2), GLASS, cache, 10)
	canopy.rotation.x = PI / 2.0
	canopy.scale = Vector3(1.0, 1.0, 0.7)
	# Side intakes and a red trim line.
	for side: float in [-1.0, 1.0]:
		_box(body, Vector3(body_r * 0.6, body_r * 0.9, length * 0.22), Vector3(side * body_r * 1.15, y - body_r * 0.2, length * 0.05), dark, cache)
		_box(body, Vector3(0.05, body_r * 0.18, length * 0.4), Vector3(side * body_r * 1.02, y + body_r * 0.35, -length * 0.02), trim, cache)
	# Swept delta wings and tailplanes (thin prisms).
	var half: float = span * 0.5
	var wing: MeshInstance3D = _prism(body, [Vector2(-body_r, length * 0.12), Vector2(-half, -length * 0.2), Vector2(-half, -length * 0.27), Vector2(-body_r, -length * 0.3),
		Vector2(body_r, -length * 0.3), Vector2(half, -length * 0.27), Vector2(half, -length * 0.2), Vector2(body_r, length * 0.12)], y - body_r * 0.2, 0.22, main, cache)
	wing.name = "Wing"
	_prism(body, [Vector2(-body_r, -length * 0.3), Vector2(-half * 0.45, -length * 0.42), Vector2(-half * 0.45, -length * 0.46), Vector2(-body_r, -length * 0.44),
		Vector2(body_r, -length * 0.44), Vector2(half * 0.45, -length * 0.46), Vector2(half * 0.45, -length * 0.42), Vector2(body_r, -length * 0.3)], y - body_r * 0.1, 0.14, main, cache)
	for side: float in [-1.0, 1.0]:
		var fin: MeshInstance3D = _box(body, Vector3(0.14, length * 0.17, length * 0.16), Vector3(side * body_r * 0.8, y + body_r + length * 0.07, -length * 0.33), dark, cache)
		fin.rotation = Vector3(0.35, 0, side * -0.3)
		_box(body, Vector3(span * 0.04, 0.24, length * 0.06), Vector3(side * half * 0.97, y - body_r * 0.2, -length * 0.23), trim, cache)
	# The afterburner nozzle and its flame (grows with the throttle).
	var nozzle: MeshInstance3D = _drum(body, body_r * 0.75, body_r * 0.9, length * 0.06, Vector3(0, y, -length * 0.37), INK, cache, 12)
	nozzle.rotation.x = PI / 2.0
	# Patch 4.0.7 item 2: a proper afterburner nozzle: a ring of dark steel
	# petals round the exit, and inside it the hot throat ("NozzleGlow", lit
	# by animate(): a dull red at idle, white-hot orange in afterburner).
	for index: int in 10:
		var pivot: Node3D = Node3D.new()
		pivot.rotation.z = TAU / 10.0 * index
		pivot.position = Vector3(0, y, -length * 0.405)
		body.add_child(pivot)
		var petal: MeshInstance3D = _box(pivot, Vector3(body_r * 0.48, 0.06, length * 0.035), Vector3(0, body_r * 0.78, 0), Color("3d434f"), cache)
		petal.rotation.x = -0.18
	var throat: MeshInstance3D = MeshInstance3D.new()
	throat.name = "NozzleGlow"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = body_r * 0.72
	disc.bottom_radius = body_r * 0.72
	disc.height = 0.04
	disc.radial_segments = 14
	disc.rings = 1
	throat.mesh = disc
	throat.rotation.x = PI / 2.0
	throat.position = Vector3(0, y, -length * 0.402)
	var hot: StandardMaterial3D = StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color("5a1d14")
	hot.emission_enabled = true
	hot.emission = Color("ff6a1a")
	hot.emission_energy_multiplier = 0.2
	throat.material_override = hot
	throat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(throat)
	var props: Node3D = Node3D.new()
	props.name = "Props"
	body.add_child(props)
	var flame: Node3D = JET_FLAME.new()
	flame.name = "JetFlame"
	flame.position = Vector3(0, y, -length * 0.4)
	flame.scale = Vector3(body_r * 1.4, body_r * 1.4, body_r * 1.1)
	body.add_child(flame)
	_gear(root, [Vector3(0, 0, length * 0.3), Vector3(-body_r * 1.6, 0, -length * 0.1), Vector3(body_r * 1.6, 0, -length * 0.1)], gear_h, 1.0, false, cache)
	TOON_LOOK.apply(root)
	return root

## A flat-shaded triangle, front face towards `outward` (Godot fronts are
## clockwise seen from the front), as TOON_COAST._triangle.
static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.dot(outward) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	tool.set_normal(normal.normalized())
	for point: Vector3 in [a, b, c]: tool.add_vertex(point)

## A thin prism: a convex-ish outline in X/Z (fanned from its centre), `thick`
## metres tall, centred at height `y`. Closed, so the ink outline wraps it.
static func _prism(parent: Node3D, outline: Array, y: float, thick: float, colour: Color, cache: Dictionary) -> MeshInstance3D:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre: Vector2 = Vector2.ZERO
	for point: Vector2 in outline: centre += point
	centre /= float(outline.size())
	var top: float = y + thick * 0.5
	var bottom: float = y - thick * 0.5
	for index: int in outline.size():
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[(index + 1) % outline.size()]
		_triangle(tool, Vector3(centre.x, top, centre.y), Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3.UP)
		_triangle(tool, Vector3(centre.x, bottom, centre.y), Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y), Vector3.DOWN)
		var out: Vector2 = (a + b) * 0.5 - centre
		var outward: Vector3 = Vector3(out.x, 0, out.y)
		_triangle(tool, Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y), Vector3(b.x, top, b.y), outward)
		_triangle(tool, Vector3(a.x, bottom, a.y), Vector3(b.x, top, b.y), Vector3(a.x, top, a.y), outward)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = _paint(colour, cache)
	parent.add_child(node)
	return node

## Patch 4.0.7 item 2: a real propeller (Andy: the turboprop's rendered as
## an arrow, the old blades were offset along the wrong line): a spinner
## cone in the plane's trim colour on a dark back plate, and `blades`
## (2 to 4) tapered blades, each on its own pivot evenly round the hub and
## pitched PROP_PITCH_RAD about its own length, with painted tips. "Blur" is
## a subtle translucent disc that animate() fades in only at high RPM.
const PROP_PITCH_RAD: float = 0.38
const BLADE: Color = Color("2f333d")
const BLADE_TIP: Color = Color("ffc940")
static func _prop(parent: Node3D, at: Vector3, radius: float, blades: int, trim: Color, cache: Dictionary) -> void:
	var hub: Node3D = Node3D.new()
	hub.name = "Prop"
	hub.position = at
	hub.set_meta("blades", blades)
	parent.add_child(hub)
	var plate: MeshInstance3D = _drum(hub, radius * 0.17, radius * 0.17, radius * 0.06, Vector3(0, 0, -radius * 0.02), INK, cache, 12)
	plate.rotation.x = PI / 2.0
	var spinner: MeshInstance3D = _drum(hub, radius * 0.16, radius * 0.015, radius * 0.38, Vector3(0, 0, radius * 0.2), trim, cache, 12)
	spinner.rotation.x = PI / 2.0
	var blade_mesh: ArrayMesh = _blade_mesh(radius * 0.1, radius * 0.86, radius * 0.1, radius * 0.16, radius * 0.035)
	var tip_mesh: ArrayMesh = _blade_mesh(radius * 0.86, radius, radius * 0.12, radius * 0.11, radius * 0.03)
	for index: int in blades:
		var pivot: Node3D = Node3D.new()
		pivot.name = "Blade%d" % index
		pivot.rotation.z = TAU / blades * index
		hub.add_child(pivot)
		for part: Array in [[blade_mesh, BLADE], [tip_mesh, BLADE_TIP]]:
			var piece: MeshInstance3D = MeshInstance3D.new()
			piece.mesh = part[0]
			piece.rotation.y = PROP_PITCH_RAD
			piece.material_override = _paint(part[1], cache)
			pivot.add_child(piece)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.01
	mesh.radial_segments = 28
	mesh.rings = 1
	disc.mesh = mesh
	disc.rotation.x = PI / 2.0
	var blur: StandardMaterial3D = StandardMaterial3D.new()
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.albedo_color = Color(0.85, 0.88, 0.92, 0.0)
	blur.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material_override = blur
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.visible = false
	disc.name = "Blur"
	hub.add_child(disc)

## Patch 4.0.7 item 2: the blur disc shows from BLUR_FROM of full RPM, at
## most BLUR_ALPHA; the props and fans spool up and down at SPOOL_RATE (of
## full RPM) a second, so they spin by RPM, not by the throttle lever.
const BLUR_FROM: float = 0.55
const BLUR_FULL: float = 0.9
const BLUR_ALPHA: float = 0.16
const SPOOL_RATE: float = 0.8

## Spins the props and the turbofans' fans, grows the Fighter's afterburner
## flame and the turbofans' faint heat shimmer with the engine (0..1); hides
## the gear when it is up.
static func animate(plane: Node3D, engine: float, gear_down: bool, delta: float) -> void:
	# Patch 4.0.4 item 1: the moving parts are found once per model, not
	# searched for every frame (own plane and every other captain's).
	if not plane.has_meta("anim_parts"):
		plane.set_meta("anim_parts", {"props": plane.find_child("Props", true, false),
			"flames": plane.find_children("JetFlame", "", true, false), "haze": plane.find_children("HeatShimmer", "", true, false),
			"glows": plane.find_children("NozzleGlow", "", true, false)})
	var parts: Dictionary = plane.get_meta("anim_parts")
	var props: Node = parts.props
	# Patch 4.0.7 item 2: the RPM follows the engine (spool up and down).
	var rpm: float = move_toward(float(plane.get_meta("rpm", engine)), clampf(engine, 0.0, 1.0), SPOOL_RATE * maxf(delta, 0.0))
	plane.set_meta("rpm", rpm)
	if is_instance_valid(props):
		for hub: Node in props.get_children():
			var fan: bool = hub.name.begins_with("Fan")
			var rate: float = (2.0 + 40.0 * rpm) if fan else (5.0 + 70.0 * rpm)
			(hub as Node3D).rotation.z += delta * rate
			if fan: continue
			var blur: MeshInstance3D = hub.get_node_or_null("Blur") as MeshInstance3D
			if blur != null:
				var share: float = smoothstep(BLUR_FROM, BLUR_FULL, rpm)
				blur.visible = share > 0.01
				(blur.material_override as StandardMaterial3D).albedo_color.a = BLUR_ALPHA * share
	for glow: Node in parts.glows:
		# Patch 4.0.7 item 2: the Fighter's nozzle throat glows with the
		# throttle and burns white-hot orange in afterburner (from 0.75).
		var burner: float = smoothstep(0.7, 1.0, engine)
		var paint: StandardMaterial3D = (glow as MeshInstance3D).material_override as StandardMaterial3D
		if paint != null:
			paint.albedo_color = Color("5a1d14").lerp(Color("ff8a2a"), clampf(engine * 1.2, 0.0, 1.0)).lerp(Color("fff1c4"), burner * 0.7)
			paint.emission_energy_multiplier = 0.2 + 1.2 * engine + 4.0 * burner
	for flame: Node in parts.flames:
		flame.set("power", engine)
	for haze: Node in parts.haze:
		var paint: StandardMaterial3D = (haze as MeshInstance3D).material_override as StandardMaterial3D
		if paint != null: paint.albedo_color.a = 0.1 * clampf(engine, 0.0, 1.0) * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03))
	var gear: Node3D = plane.get_node_or_null("Gear") as Node3D
	if gear != null: fold_gear(gear, gear_down, delta)

## Patch 4.0.2 item 6: moves the gear's travel (1 down, 0 up) towards the
## lever at 1 / GEAR_TRAVEL_S per second, folds each leg by it and swings
## the well doors open while the gear is out or moving. A leg fully up is
## hidden inside its closed well.
static func fold_gear(gear: Node3D, down: bool, delta: float) -> float:
	var travel: float = move_toward(float(gear.get_meta("travel", 1.0)), 1.0 if down else 0.0, maxf(delta, 0.0) / GEAR_TRAVEL_S)
	if travel < 0.0001: travel = 0.0
	elif travel > 0.9999: travel = 1.0
	gear.set_meta("travel", travel)
	var eased: float = travel * travel * (3.0 - 2.0 * travel)
	for child: Node in gear.get_children():
		var node: Node3D = child as Node3D
		if child.name.begins_with("Leg"):
			node.rotation = (child.get_meta("fold") as Vector3) * (1.0 - eased)
			node.visible = travel > 0.0
		elif child.name.begins_with("Door"):
			# Open while there is any gear out; shut flush when it is fully up.
			node.rotation.z = float(child.get_meta("side")) * deg_to_rad(80.0) * clampf(travel * 5.0, 0.0, 1.0)
	return travel

## An airport: the runway on its embankment with centre-line and threshold
## stripes, a taxiway, a small terminal with a control tower and a windsock.
static func airport(index: int) -> Node3D:
	var entry: Dictionary = Airports.all()[index]
	var cache: Dictionary = {}
	var root: Node3D = Node3D.new()
	root.name = "Airport%d" % index
	root.position = Vector3(entry.at.x, 0, entry.at.z)
	root.rotation.y = entry.heading
	var length: float = entry.length
	var width: float = entry.width
	# Patch 4.0.3 item 8: the runway's own height (a polar one stands on the ice).
	var top: float = float(entry.at.y)
	var polar: bool = Airports.polar(index)
	# The airfield (Patch 4.0.1 item 7): one grassy embankment over the whole
	# footprint (runway, apron, terminal and a margin), level at the runway's
	# height, so no hill pokes through. Its faces point outward.
	# Patch 4.0.2 item 3: its grass top stands FIELD_DROP_M below the runway
	# and is cut away under the runway and the apron, which are solid tarmac
	# slabs with their markings painted into the runway's own top (no stripe
	# boxes lying on it): no two surfaces overlap, so nothing flickers.
	# The inland side (where the terminal stands), as Airports worked it out.
	var side: float = float(entry.side)
	var span: Vector2 = Airports.field_across(index)
	var holes: Array[Rect2] = [runway_rect(width, length), apron_rect(width, side)]
	var bank: MeshInstance3D = MeshInstance3D.new()
	bank.name = "Airfield"
	bank.mesh = _bank_mesh(span.x, span.y, Airports.field_half_length(index), top + 3.0 - FIELD_DROP_M, holes)
	bank.position = Vector3(0, -3.0, 0)
	# Patch 4.0.3 item 8: a snowfield on the polar ice instead of grass.
	bank.material_override = _paint(SNOW_BANK if polar else GRASS_BANK, cache)
	root.add_child(bank)
	var runway: MeshInstance3D = MeshInstance3D.new()
	runway.name = "Runway"
	runway.mesh = _runway_mesh(width, length)
	runway.position = Vector3(0, top, 0)
	var marked: StandardMaterial3D = StandardMaterial3D.new()
	marked.albedo_texture = runway_texture()
	marked.roughness = 0.9
	runway.material_override = marked
	root.add_child(runway)
	# Taxiway and apron on the inland side, with the terminal and the tower.
	var apron_area: Rect2 = holes[1]
	var apron: MeshInstance3D = _box(root, Vector3(apron_area.size.x, SLAB_M, apron_area.size.y), Vector3(apron_area.get_center().x, top - APRON_DROP_M - SLAB_M * 0.5, apron_area.get_center().y), TARMAC, cache)
	apron.name = "Apron"
	var terminal_x: float = side * (width * 0.5 + 34.0)
	var terminal: MeshInstance3D = _box(root, Vector3(18.0, 8.4, 46.0), Vector3(terminal_x + side * 6.0, top + 3.8, 120.0), WHITE, cache)
	terminal.name = "Terminal"
	_box(root, Vector3(19.0, 1.2, 47.0), Vector3(terminal_x + side * 6.0, top + 8.4, 120.0), Color("3d9be0"), cache)
	for window: int in 5:
		_box(root, Vector3(0.2, 2.2, 5.0), Vector3(terminal_x - side * 3.05, top + 4.4, 102.0 + window * 9.0), GLASS, cache)
	_drum(root, 2.2, 1.8, 18.0, Vector3(terminal_x + side * 6.0, top + 9.0, 92.0), WHITE, cache, 8)
	_drum(root, 3.4, 3.4, 3.6, Vector3(terminal_x + side * 6.0, top + 19.6, 92.0), GLASS, cache, 8)
	_drum(root, 3.8, 1.0, 1.6, Vector3(terminal_x + side * 6.0, top + 22.2, 92.0), Color("e2574c"), cache, 8)
	# Windsock by the threshold.
	_drum(root, 0.15, 0.15, 7.0, Vector3(side * (width * 0.5 + 8.0), top + 3.5, -length * 0.5 + 40.0), WHITE, cache, 6)
	var sock: MeshInstance3D = _drum(root, 0.7, 0.25, 3.0, Vector3(side * (width * 0.5 + 8.0), top + 6.6, -length * 0.5 + 41.6), Color("ff8a2a"), cache, 6)
	sock.rotation.x = PI / 2.0
	TOON_LOOK.apply(root)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visibility_range_end = 5200.0
	return root

## Patch 4.0.2 item 3: the runway's rectangle in the airport's frame
## (x across, y along), and the apron's on the inland `side`.
static func runway_rect(width: float, length: float) -> Rect2:
	return Rect2(-width * 0.5, -length * 0.5, width, length)

static func apron_rect(width: float, side: float) -> Rect2:
	return Rect2(side * (width * 0.5 + 22.0) - 13.0, 40.0, 26.0, 160.0)

## The runway's paint (one texture for every runway: they share a size):
## tarmac, edge lines, the dashed centre line every 60 m and the six
## threshold bars at each end. Across is U (RUNWAY_WIDTH_M), along is V.
static var _runway_paint: ImageTexture
static func runway_texture() -> ImageTexture:
	if _runway_paint != null: return _runway_paint
	var width: float = Airports.RUNWAY_WIDTH_M
	var length: float = Airports.RUNWAY_M
	var size: Vector2i = Vector2i(64, 1024)
	var page: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	page.fill(TARMAC)
	var paint: Callable = func(x: float, z: float, w: float, l: float) -> void:
		var a: Vector2i = Vector2i(floori((x - w * 0.5 + width * 0.5) / width * size.x), floori((z - l * 0.5 + length * 0.5) / length * size.y))
		var b: Vector2i = Vector2i(ceili((x + w * 0.5 + width * 0.5) / width * size.x), ceili((z + l * 0.5 + length * 0.5) / length * size.y))
		page.fill_rect(Rect2i(a, (b - a).max(Vector2i.ONE)), STRIPE)
	for edge: float in [-1.0, 1.0]: paint.call(edge * (width * 0.5 - 1.2), 0.0, 0.7, length - 8.0)
	for stripe: int in int(length / 60.0) - 1:
		paint.call(0.0, -length * 0.5 + 90.0 + stripe * 60.0, 1.2, 22.0)
	for end: float in [-1.0, 1.0]:
		for bar: int in 6: paint.call((bar - 2.5) * 4.5, end * (length * 0.5 - 22.0), 2.2, 26.0)
	page.generate_mipmaps()
	_runway_paint = ImageTexture.create_from_image(page)
	return _runway_paint

## The runway slab: its painted top at y = 0 (UV across and along) and four
## sides down to -SLAB_M (in plain tarmac, a spot of the paint with no line).
static func _runway_mesh(width: float, length: float) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = width * 0.5
	var l: float = length * 0.5
	var corners: Array[Vector3] = [Vector3(-w, 0, -l), Vector3(w, 0, -l), Vector3(w, 0, l), Vector3(-w, 0, l)]
	var uv: Callable = func(point: Vector3) -> Vector2: return Vector2((point.x + w) / width, (point.z + l) / length)
	for triangle: Array in [[0, 2, 1], [0, 3, 2]]:
		var a: Vector3 = corners[triangle[0]]
		var b: Vector3 = corners[triangle[1]]
		var c: Vector3 = corners[triangle[2]]
		var normal: Vector3 = (c - a).cross(b - a)
		if normal.y < 0.0:
			var swap: Vector3 = b
			b = c
			c = swap
		tool.set_normal(Vector3.UP)
		for point: Vector3 in [a, b, c]:
			tool.set_uv(uv.call(point))
			tool.add_vertex(point)
	for index: int in 4:
		var a: Vector3 = corners[index]
		var b: Vector3 = corners[(index + 1) % 4]
		var down: Vector3 = Vector3(0, -SLAB_M, 0)
		var outward: Vector3 = ((a + b) * 0.5).normalized()
		for triangle: Array in [[a, b, b + down], [a, b + down, a + down]]:
			var p0: Vector3 = triangle[0]
			var p1: Vector3 = triangle[1]
			var p2: Vector3 = triangle[2]
			if (p2 - p0).cross(p1 - p0).dot(outward) < 0.0:
				var swap: Vector3 = p1
				p1 = p2
				p2 = swap
			tool.set_normal(outward)
			for point: Vector3 in [p0, p1, p2]:
				tool.set_uv(Vector2(0.25, 0.5))
				tool.add_vertex(point)
	return tool.commit()

## The airfield embankment: a flat top from x0 to x1 across and +-half_length
## along, `height` tall, its four sides sloping down to the ground. Every face
## points outward (fronts clockwise, as _triangle makes them). Patch 4.0.2:
## the top leaves out `holes` (rectangles, x across and y along), where the
## runway and apron slabs stand.
static func _bank_mesh(x0: float, x1: float, half_length: float, height: float, holes: Array[Rect2] = []) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run: float = height * 1.4
	var bottom: Array[Vector3] = [Vector3(x0 - run, 0, -half_length - run), Vector3(x1 + run, 0, -half_length - run), Vector3(x1 + run, 0, half_length + run), Vector3(x0 - run, 0, half_length + run)]
	var upper: Array[Vector3] = [Vector3(x0, height, -half_length), Vector3(x1, height, -half_length), Vector3(x1, height, half_length), Vector3(x0, height, half_length)]
	var middle: Vector3 = Vector3((x0 + x1) * 0.5, 0, 0)
	for index: int in 4:
		var next: int = (index + 1) % 4
		var outward: Vector3 = (bottom[index] + bottom[next]) * 0.5 - middle
		outward.y = 0.0
		outward = outward.normalized() + Vector3.UP * 0.7
		_triangle(tool, bottom[index], upper[next], bottom[next], outward)
		_triangle(tool, bottom[index], upper[index], upper[next], outward)
	# The top, as a grid cut along every hole's edges, without the holes' cells.
	var xs: Array[float] = [x0, x1]
	var zs: Array[float] = [-half_length, half_length]
	for hole: Rect2 in holes:
		for x: float in [hole.position.x, hole.end.x]:
			if x > x0 and x < x1 and not xs.has(x): xs.append(x)
		for z: float in [hole.position.y, hole.end.y]:
			if z > -half_length and z < half_length and not zs.has(z): zs.append(z)
	xs.sort()
	zs.sort()
	for i: int in xs.size() - 1:
		for j: int in zs.size() - 1:
			var centre: Vector2 = Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
			if holes.any(func(hole: Rect2) -> bool: return hole.has_point(centre)): continue
			var a: Vector3 = Vector3(xs[i], height, zs[j])
			var b: Vector3 = Vector3(xs[i + 1], height, zs[j])
			var c: Vector3 = Vector3(xs[i + 1], height, zs[j + 1])
			var d: Vector3 = Vector3(xs[i], height, zs[j + 1])
			_triangle(tool, a, c, b, Vector3.UP)
			_triangle(tool, a, d, c, Vector3.UP)
	return tool.commit()

## Patch 4.0 item 12: the crash. A big toon explosion: a white flash, a
## fireball in flat orange and yellow bands that swells and fades, a ring of
## shock, black smoke puffs rising and chunks of debris flung out. It frees
## itself after a few seconds. Unshaded paint keeps the bold flat look.
class Explosion extends Node3D:
	var clock: float = 0.0
	var size: float = 1.0
	var parts: Array = []
	func _init(scale_m: float = 1.0) -> void:
		size = scale_m
		name = "Explosion"
	func _ready() -> void:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(global_position.x * 13.0 + global_position.z * 7.0)
		for band: Array in [[Color("fff6d8"), 0.5, 0.0], [Color("ffd23f"), 0.8, 0.05], [Color("ff8a2a"), 1.0, 0.1], [Color("e2574c"), 1.15, 0.18]]:
			parts.append({"node": _ball(band[0], 1.0), "kind": "fire", "grow": float(band[1]), "delay": float(band[2])})
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.85
		torus.outer_radius = 1.0
		ring.mesh = torus
		ring.material_override = _flat(Color(1, 0.95, 0.8, 0.8), true)
		add_child(ring)
		parts.append({"node": ring, "kind": "ring"})
		for index: int in 10:
			var puff: MeshInstance3D = _ball(Color("3a3f4b"), 1.0)
			parts.append({"node": puff, "kind": "smoke", "drift": Vector3(rng.randf_range(-1, 1), rng.randf_range(1.5, 3.0), rng.randf_range(-1, 1)), "delay": 0.2 + index * 0.06})
		for index: int in 14:
			var chunk: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3.ONE * rng.randf_range(0.6, 1.6) * size
			chunk.mesh = box
			chunk.material_override = _flat(Color("2b2f3a") if index % 3 else Color("ff8a2a"))
			add_child(chunk)
			parts.append({"node": chunk, "kind": "debris", "velocity": Vector3(rng.randf_range(-1, 1), rng.randf_range(0.8, 1.8), rng.randf_range(-1, 1)) * 22.0 * size, "spin": Vector3(rng.randf(), rng.randf(), rng.randf()) * 8.0})
		_process(0.0)
	func _ball(colour: Color, radius: float) -> MeshInstance3D:
		var node: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 10
		sphere.rings = 6
		node.mesh = sphere
		node.material_override = _flat(colour, true)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		return node
	func _flat(colour: Color, clear: bool = false) -> StandardMaterial3D:
		var paint: StandardMaterial3D = StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_color = colour
		if clear: paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return paint
	func _process(delta: float) -> void:
		clock += delta
		for part: Dictionary in parts:
			var node: MeshInstance3D = part.node
			match part.kind:
				"fire":
					var t: float = maxf(clock - float(part.delay), 0.0)
					var radius: float = size * 14.0 * float(part.grow) * (1.0 - exp(-t * 5.0))
					node.scale = Vector3.ONE * maxf(radius, 0.01)
					node.position.y = t * 4.0 * size
					var fade: float = clampf(1.6 - t, 0.0, 1.0)
					(node.material_override as StandardMaterial3D).albedo_color.a = fade
					node.visible = fade > 0.0
				"ring":
					var r: float = size * 60.0 * (1.0 - exp(-clock * 3.0))
					node.scale = Vector3(r, r * 0.3, r)
					(node.material_override as StandardMaterial3D).albedo_color.a = clampf(0.8 - clock, 0.0, 0.8)
				"smoke":
					var s: float = maxf(clock - float(part.delay), 0.0)
					node.position = part.drift * s * 6.0 * size
					node.scale = Vector3.ONE * size * (3.0 + s * 6.0)
					(node.material_override as StandardMaterial3D).albedo_color.a = clampf(0.85 - s * 0.22, 0.0, 0.85) if s > 0.0 else 0.0
				"debris":
					part.velocity.y -= 9.81 * delta
					node.position += part.velocity * delta
					node.rotation += part.spin * delta
					if node.position.y < -2.0: node.visible = false
		if clock > 4.5: queue_free()

## Patch 4.0: short sounds made in code (like HandlingFeedback.tone): "boom"
## (the crash: a cracking burst over a long low rumble) and "warn" (the
## low-altitude alarm: a two-tone beep, looped by its player).
static func sound(kind: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration: float = 2.6 if kind == "boom" else 0.5
	var count: int = int(duration * stream.mix_rate)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(count * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	var low: float = 0.0
	for index: int in count:
		var t: float = float(index) / stream.mix_rate
		var wave: float = 0.0
		if kind == "boom":
			low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.06)
			var crack: float = rng.randf_range(-1.0, 1.0) * exp(-t * 14.0)
			wave = (crack * 0.6 + low * 2.2 * exp(-t * 1.6) + sin(TAU * 38.0 * t) * 0.5 * exp(-t * 2.2)) * minf(1.0, t / 0.004)
		else:
			var tone: float = 880.0 if t < 0.2 else 660.0
			wave = sin(TAU * tone * t) * 0.35 * (1.0 if t < 0.4 else 0.0) * minf(1.0, fmod(t, 0.2) / 0.01)
		samples.encode_s16(index * 2, int(clampf(wave, -1.0, 1.0) * 26000))
	stream.data = samples
	if kind == "warn":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream
