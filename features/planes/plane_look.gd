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
			_prop(props, Vector3(0, y, length * 0.5), body_r * 2.6, cache)
		"prop2":
			for side: float in [-1.0, 1.0]:
				var x: float = side * span * 0.2
				var nacelle: MeshInstance3D = _drum(body, body_r * 0.38, body_r * 0.32, chord * 1.4, Vector3(x, wing_y - body_r * 0.2, length * 0.1), WHITE, cache)
				nacelle.rotation.x = PI / 2.0
				_prop(props, Vector3(x, wing_y - body_r * 0.2, length * 0.1 + chord * 0.75), body_r * 1.7, cache)
		"fan2":
			# Patch 4.0.1 item 5: turbofans, no flames. An under-wing nacelle on
			# a pylon, a dark intake with a fan that spins with the throttle,
			# a grey core nozzle and at most a faint heat shimmer behind it.
			for side: float in [-1.0, 1.0]:
				var x: float = side * span * 0.24
				var radius: float = body_r * 0.5
				var at: Vector3 = Vector3(x, wing_y - body_r * 0.75, length * 0.12)
				_box(body, Vector3(radius * 0.25, body_r * 0.5, chord * 0.8), Vector3(x, wing_y - body_r * 0.3, length * 0.1), WHITE, cache)
				var pod: MeshInstance3D = _drum(body, radius * 0.9, radius, chord * 1.4, at, WHITE, cache, 14)
				pod.rotation.x = PI / 2.0
				var lip: MeshInstance3D = _drum(body, radius * 1.04, radius * 1.04, chord * 0.12, at + Vector3(0, 0, chord * 0.68), Color("c9ccd4"), cache, 14)
				lip.rotation.x = PI / 2.0
				var intake: MeshInstance3D = _drum(body, radius * 0.86, radius * 0.86, chord * 0.1, at + Vector3(0, 0, chord * 0.7), INK, cache, 14)
				intake.rotation.x = PI / 2.0
				var core: MeshInstance3D = _drum(body, radius * 0.5, radius * 0.3, chord * 0.4, at - Vector3(0, 0, chord * 0.85), Color("8a8f9c"), cache, 10)
				core.rotation.x = -PI / 2.0
				_fan(props, at + Vector3(0, 0, chord * 0.76), radius * 0.82, cache, "Fan%d" % (0 if side < 0.0 else 1))
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
	# Gear: struts and wheels down to y = 0.
	var gear: Node3D = Node3D.new()
	gear.name = "Gear"
	root.add_child(gear)
	for at: Vector3 in [Vector3(0, 0, length * 0.36), Vector3(-span * 0.08 - body_r, 0, -length * 0.02), Vector3(span * 0.08 + body_r, 0, -length * 0.02)]:
		_box(gear, Vector3(0.18, gear_h, 0.18) * maxf(1.0, body_r * 0.6), Vector3(at.x, gear_h * 0.5, at.z), INK, cache)
		var wheel: MeshInstance3D = _drum(gear, gear_h * 0.28, gear_h * 0.28, gear_h * 0.2, Vector3(at.x, gear_h * 0.28, at.z), INK, cache, 8)
		wheel.rotation.z = PI / 2.0
	TOON_LOOK.apply(root)
	return root

## Patch 4.0.1 item 5: a turbofan's front fan: a spinner and a ring of wide
## blades, spun about +Z by animate() like a prop hub.
static func _fan(parent: Node3D, at: Vector3, radius: float, cache: Dictionary, label: String = "Fan") -> void:
	var hub: Node3D = Node3D.new()
	hub.name = label
	hub.position = at
	parent.add_child(hub)
	var spinner: MeshInstance3D = _drum(hub, radius * 0.3, radius * 0.02, radius * 0.45, Vector3(0, 0, radius * 0.1), WHITE, cache, 10)
	spinner.rotation.x = PI / 2.0
	for index: int in 12:
		var angle: float = TAU / 12.0 * index
		var blade: MeshInstance3D = _box(hub, Vector3(radius * 0.2, radius * 0.72, 0.05 * radius), Vector3(sin(angle), cos(angle), 0) * radius * 0.6, Color("6b7280"), cache)
		blade.rotation = Vector3(0, 0.5, -angle)

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
	var props: Node3D = Node3D.new()
	props.name = "Props"
	body.add_child(props)
	var flame: Node3D = JET_FLAME.new()
	flame.name = "JetFlame"
	flame.position = Vector3(0, y, -length * 0.4)
	flame.scale = Vector3(body_r * 1.4, body_r * 1.4, body_r * 1.1)
	body.add_child(flame)
	var gear: Node3D = Node3D.new()
	gear.name = "Gear"
	root.add_child(gear)
	for at: Vector3 in [Vector3(0, 0, length * 0.3), Vector3(-body_r * 1.6, 0, -length * 0.1), Vector3(body_r * 1.6, 0, -length * 0.1)]:
		_box(gear, Vector3(0.16, gear_h, 0.16), Vector3(at.x, gear_h * 0.5, at.z), INK, cache)
		var wheel: MeshInstance3D = _drum(gear, gear_h * 0.26, gear_h * 0.26, gear_h * 0.18, Vector3(at.x, gear_h * 0.26, at.z), INK, cache, 8)
		wheel.rotation.z = PI / 2.0
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

static func _prop(parent: Node3D, at: Vector3, radius: float, cache: Dictionary) -> void:
	var hub: Node3D = Node3D.new()
	hub.name = "Prop"
	hub.position = at
	parent.add_child(hub)
	var spinner: MeshInstance3D = _drum(hub, radius * 0.12, radius * 0.05, radius * 0.3, Vector3(0, 0, 0.1), INK, cache)
	spinner.rotation.x = -PI / 2.0
	for index: int in 3:
		var blade: MeshInstance3D = _box(hub, Vector3(radius * 0.14, radius, 0.06), Vector3.ZERO, INK, cache)
		blade.rotation.z = TAU / 3.0 * index
		blade.position = Vector3(sin(TAU / 3.0 * index), cos(TAU / 3.0 * index), 0) * radius * -0.5
	# Unshaded translucent disc: the blur of the spinning prop.
	var disc: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 16
	disc.mesh = mesh
	disc.rotation.x = PI / 2.0
	var blur: StandardMaterial3D = StandardMaterial3D.new()
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.albedo_color = Color(1, 1, 1, 0.18)
	disc.material_override = blur
	disc.name = "Blur"
	hub.add_child(disc)

## Spins the props and the turbofans' fans, grows the Fighter's afterburner
## flame and the turbofans' faint heat shimmer with the engine (0..1); hides
## the gear when it is up.
static func animate(plane: Node3D, engine: float, gear_down: bool, delta: float) -> void:
	var props: Node = plane.find_child("Props", true, false)
	if props != null:
		for hub: Node in props.get_children():
			var rate: float = (2.0 + 40.0 * engine) if hub.name.begins_with("Fan") else (6.0 + 60.0 * engine)
			(hub as Node3D).rotation.z += delta * rate
	for flame: Node in plane.find_children("JetFlame", "", true, false):
		flame.set("power", engine)
	for haze: Node in plane.find_children("HeatShimmer", "", true, false):
		var paint: StandardMaterial3D = (haze as MeshInstance3D).material_override as StandardMaterial3D
		if paint != null: paint.albedo_color.a = 0.1 * clampf(engine, 0.0, 1.0) * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03))
	var gear: Node3D = plane.get_node_or_null("Gear") as Node3D
	if gear != null: gear.visible = gear_down

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
	var top: float = Airports.RUNWAY_Y
	# The airfield (Patch 4.0.1 item 7): one grassy embankment over the whole
	# footprint (runway, apron, terminal and a margin), level at the runway's
	# height, so no hill pokes through. Its faces now point outward (the 4.0
	# top faced down, so it was culled and its ink shell drew a black slab).
	var span: Vector2 = Airports.field_across(index)
	var bank: MeshInstance3D = MeshInstance3D.new()
	bank.name = "Airfield"
	bank.mesh = _bank_mesh(span.x, span.y, Airports.field_half_length(index), top + 3.0)
	bank.position = Vector3(0, -3.0, 0)
	bank.material_override = _paint(GRASS_BANK, cache)
	root.add_child(bank)
	_box(root, Vector3(width, 0.3, length), Vector3(0, top - 0.15, 0), TARMAC, cache)
	var stripes: int = int(length / 60.0)
	for index_stripe: int in stripes:
		_box(root, Vector3(1.2, 0.05, 22.0), Vector3(0, top + 0.03, -length * 0.5 + 60.0 + index_stripe * 60.0 - 30.0), STRIPE, cache)
	for end: float in [-1.0, 1.0]:
		for bar: int in 6:
			_box(root, Vector3(2.2, 0.05, 26.0), Vector3((bar - 2.5) * 4.5, top + 0.03, end * (length * 0.5 - 22.0)), STRIPE, cache)
	# Taxiway and apron on the inland side, with the terminal and the tower.
	var inland: Vector2 = Airports.land_side(Vector2(entry.at.x, entry.at.z), Vector2(sin(entry.heading), cos(entry.heading)))
	var side: float = 1.0 if Vector2(cos(entry.heading), -sin(entry.heading)).dot(inland) > 0.0 else -1.0
	_box(root, Vector3(26.0, 0.25, 160.0), Vector3(side * (width * 0.5 + 22.0), top - 0.1, 120.0), TARMAC, cache)
	var terminal_x: float = side * (width * 0.5 + 34.0)
	var terminal: MeshInstance3D = _box(root, Vector3(18.0, 8.0, 46.0), Vector3(terminal_x + side * 6.0, top + 4.0, 120.0), WHITE, cache)
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

## The airfield embankment: a flat top from x0 to x1 across and +-half_length
## along, `height` tall, its four sides sloping down to the ground. Every face
## points outward (fronts clockwise, as _triangle makes them).
static func _bank_mesh(x0: float, x1: float, half_length: float, height: float) -> ArrayMesh:
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
	_triangle(tool, upper[0], upper[2], upper[1], Vector3.UP)
	_triangle(tool, upper[0], upper[3], upper[2], Vector3.UP)
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
