extends RefCounted
## Patch 2.5 item 2: chunky toon bridges across the straits. Each bridge is
## built in its own frame: X runs across the strait (shore to shore), Z along
## it, Y up from the sea. The structure (deck, towers, piers) and the rigging
## (cables, hangers, rails) are one merged mesh each, with shared materials,
## so a bridge costs a few draw calls and the rigging stops drawing far away.
## Towers and piers are solid and stand on land; the deck has no collision
## (no ship reaches it, and the chase camera passes under it smoothly).
const Progression = preload("res://features/game/progression.gd")

const DECK_T: float = 4.0
const DECK_W: float = 26.0
## Towers stand this far inland of the shoreline, on the beach.
const TOWER_SET_M: float = 30.0
## Flat deck beyond the shore, then a ramp down onto the hills.
const FLAT_M: float = 150.0
const RAMP_M: float = 320.0
const RAMP_FOOT_Y: float = 16.0
const PIER_STEP_M: float = 60.0
const STRUCTURE_RANGE_M: float = 9000.0
const RIGGING_RANGE_M: float = 3000.0
const PAINT = {"suspension": Color("d4513a"), "arch": Color("3f9a7d"), "cable_stayed": Color("f1efe6"), "truss": Color("4f7fb5")}
const STONE: Color = Color("c9bfa8")
const ROAD: Color = Color("6e7280")
const CABLE: Color = Color("3a3448")

static var _paints: Dictionary = {}

static func paint(color: Color) -> StandardMaterial3D:
	if not _paints.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		_paints[color] = material
	return _paints[color]

## Deck underside and top, metres above the sea.
static func deck_bottom() -> float:
	return Progression.BRIDGE_CLEARANCE_M

static func deck_top() -> float:
	return Progression.BRIDGE_CLEARANCE_M + DECK_T

## Half the strait's clear width at the bridge.
static func half_span(index: int) -> float:
	return float(Progression.bridge_strait(index).width_m) / 2.0

## The world direction (X, Z) the bridge runs in: across its strait.
static func across(index: int) -> Vector2:
	var strait: Dictionary = Progression.bridge_strait(index)
	return (strait.to - strait.from).normalized().orthogonal()

## How far each end of the bridge reaches from its centre.
static func reach(index: int) -> float:
	return half_span(index) + FLAT_M + RAMP_M

class Parts:
	var tools: Dictionary = {}
	var piers: Array[Transform3D] = []
	var pier_sizes: Array[Vector3] = []

	func box(color: Color, size: Vector3, at: Transform3D) -> void:
		if not tools.has(color):
			var tool: SurfaceTool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[color] = tool
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		(tools[color] as SurfaceTool).append_from(mesh, 0, at)

	## A beam of square section `thick` from `a` to `b`.
	func beam(color: Color, a: Vector3, b: Vector3, thick: float) -> void:
		var direction: Vector3 = b - a
		if direction.length() < 0.01: return
		var up: Vector3 = Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.RIGHT
		box(color, Vector3(thick, thick, direction.length()), Transform3D(Basis.looking_at(direction, up), (a + b) / 2.0))

	## A solid column standing on the ground, also part of the collision.
	func pier(color: Color, size: Vector3, at: Vector3) -> void:
		box(color, size, Transform3D(Basis.IDENTITY, at))
		piers.append(Transform3D(Basis.IDENTITY, at))
		pier_sizes.append(size)

static func _commit(parts: Parts, colors: Array) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for color: Color in colors:
		if not parts.tools.has(color): continue
		(parts.tools[color] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, paint(color))
	return mesh

## Builds bridge `index` of Progression.BRIDGES, placed in the world.
static func build(index: int) -> Node3D:
	var entry: Dictionary = Progression.BRIDGES[index]
	var color: Color = PAINT[entry.style]
	var half: float = half_span(index)
	var top: float = deck_top()
	var mid: float = deck_bottom() + DECK_T / 2.0
	var structure: Parts = Parts.new()
	var rigging: Parts = Parts.new()
	# The deck: flat over the strait and the shore, then a ramp each side down
	# onto the hills, on stone piers. Rails along both edges.
	var flat: float = half + FLAT_M
	structure.box(ROAD, Vector3(flat * 2.0, DECK_T, DECK_W), Transform3D(Basis.IDENTITY, Vector3(0, mid, 0)))
	for side: float in [-1.0, 1.0]:
		var high: Vector3 = Vector3(side * flat, mid, 0)
		var low: Vector3 = Vector3(side * (flat + RAMP_M), RAMP_FOOT_Y - DECK_T / 2.0, 0)
		var run: Vector3 = low - high
		var ramp_basis: Basis = Basis(Vector3.BACK, atan2(run.y, run.x))
		structure.box(ROAD, Vector3(run.length(), DECK_T, DECK_W), Transform3D(ramp_basis, (high + low) / 2.0))
		for edge: float in [-1.0, 1.0]:
			rigging.beam(color, Vector3(side * (half - 2.0), top + 1.5, edge * (DECK_W / 2.0 - 0.6)), high + Vector3(0, DECK_T / 2.0 + 1.5, edge * (DECK_W / 2.0 - 0.6)), 1.0)
			rigging.beam(color, high + Vector3(0, DECK_T / 2.0 + 1.5, edge * (DECK_W / 2.0 - 0.6)), low + Vector3(0, DECK_T / 2.0 + 1.5, edge * (DECK_W / 2.0 - 0.6)), 1.0)
		# Piers under the shore deck and the ramp, all on land.
		var along: float = half + TOWER_SET_M + PIER_STEP_M
		while along < flat + RAMP_M - 30.0:
			var under: float = mid if along <= flat else lerpf(mid, RAMP_FOOT_Y - DECK_T / 2.0, (along - flat) / RAMP_M)
			var height: float = under + 6.0
			structure.pier(STONE, Vector3(7, height, DECK_W - 6.0), Vector3(side * along, under - height / 2.0, 0))
			along += PIER_STEP_M
	for edge: float in [-1.0, 1.0]:
		rigging.beam(color, Vector3(-(half - 2.0), top + 1.5, edge * (DECK_W / 2.0 - 0.6)), Vector3(half - 2.0, top + 1.5, edge * (DECK_W / 2.0 - 0.6)), 1.0)
	match entry.style:
		"suspension": _suspension(structure, rigging, color, half)
		"arch": _arch(structure, rigging, color, half)
		"cable_stayed": _cable_stayed(structure, rigging, color, half)
		_: _truss(structure, rigging, color, half)
	var root: Node3D = Node3D.new()
	root.name = entry.id
	var at: Vector2 = entry.at
	var way: Vector2 = across(index)
	root.position = Vector3(at.x, 0, at.y)
	root.rotation.y = atan2(-way.y, way.x)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Bridge"
	body.mesh = _commit(structure, [ROAD, STONE, color])
	body.visibility_range_end = STRUCTURE_RANGE_M
	root.add_child(body)
	var lines: MeshInstance3D = MeshInstance3D.new()
	lines.name = "Rigging"
	lines.mesh = _commit(rigging, [color, CABLE])
	lines.visibility_range_end = RIGGING_RANGE_M
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lines)
	var solid: StaticBody3D = StaticBody3D.new()
	solid.name = "Piers"
	solid.collision_layer = CollisionRules.SHORE
	solid.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
	root.add_child(solid)
	for i: int in structure.piers.size():
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = structure.pier_sizes[i]
		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.shape = shape
		collider.transform = structure.piers[i]
		solid.add_child(collider)
	return root

## Two legs per tower, joined by cross beams above the deck and at the top.
static func _tower(parts: Parts, color: Color, x: float, height: float, leg: float, spread: float) -> void:
	for edge: float in [-1.0, 1.0]:
		parts.pier(color, Vector3(leg, height + 6.0, leg), Vector3(x, height / 2.0 - 3.0, edge * spread))
	parts.box(color, Vector3(leg * 0.9, DECK_T + 2.0, spread * 2.0), Transform3D(Basis.IDENTITY, Vector3(x, deck_bottom() - 2.0, 0)))
	for level: float in [0.55, 0.8, 1.0]:
		var y: float = deck_top() + (height - deck_top()) * level - 3.0
		parts.box(color, Vector3(leg * 0.8, 5.0, spread * 2.0), Transform3D(Basis.IDENTITY, Vector3(x, y, 0)))

## The big one: two tall towers, main cables sagging between them and down to
## anchor blocks on each shore, hangers every 15 m.
static func _suspension(structure: Parts, rigging: Parts, color: Color, half: float) -> void:
	var tower_x: float = half + TOWER_SET_M
	var tower_top: float = deck_top() + 100.0
	var sag: float = deck_top() + 5.0
	var spread: float = DECK_W / 2.0 + 2.0
	var anchor_x: float = half + FLAT_M - 10.0
	for side: float in [-1.0, 1.0]:
		_tower(structure, color, side * tower_x, tower_top, 9.0, spread)
		structure.pier(STONE, Vector3(24, deck_top() + 6.0, DECK_W + 10.0), Vector3(side * anchor_x, deck_top() / 2.0 - 3.0, 0))
	for edge: float in [-1.0, 1.0]:
		var z: float = edge * spread
		var steps: int = 28
		var last: Vector3 = Vector3(-tower_x, tower_top, z)
		for step: int in range(1, steps + 1):
			var x: float = lerpf(-tower_x, tower_x, float(step) / steps)
			var point: Vector3 = Vector3(x, sag + (tower_top - sag) * pow(x / tower_x, 2.0), z)
			rigging.beam(CABLE, last, point, 2.2)
			last = point
		for side: float in [-1.0, 1.0]:
			var from: Vector3 = Vector3(side * tower_x, tower_top, z)
			var to: Vector3 = Vector3(side * anchor_x, deck_top() + 4.0, z)
			var bend: Vector3 = (from + to) / 2.0 - Vector3(0, 10, 0)
			rigging.beam(CABLE, from, bend, 2.2)
			rigging.beam(CABLE, bend, to, 2.2)
		var x_hang: float = -tower_x + 15.0
		while x_hang < tower_x - 5.0:
			var cable_y: float = sag + (tower_top - sag) * pow(x_hang / tower_x, 2.0)
			if cable_y - deck_top() > 2.0:
				rigging.beam(CABLE, Vector3(x_hang, deck_top(), z), Vector3(x_hang, cable_y, z), 0.7)
			x_hang += 15.0

## A tied arch over the deck, springing from stone piers on the two shores.
static func _arch(structure: Parts, rigging: Parts, color: Color, half: float) -> void:
	var foot_x: float = half + 20.0
	var rise: float = 55.0
	var spread: float = DECK_W / 2.0 + 1.0
	for side: float in [-1.0, 1.0]:
		structure.pier(STONE, Vector3(18, deck_bottom() + 6.0, DECK_W + 6.0), Vector3(side * foot_x, deck_bottom() / 2.0 - 3.0, 0))
	var steps: int = 18
	for edge: float in [-1.0, 1.0]:
		var z: float = edge * spread
		var last: Vector3 = Vector3(-foot_x, deck_top(), z)
		for step: int in range(1, steps + 1):
			var x: float = lerpf(-foot_x, foot_x, float(step) / steps)
			var point: Vector3 = Vector3(x, deck_top() + rise * (1.0 - pow(x / foot_x, 2.0)), z)
			structure.beam(color, last, point, 4.0)
			if step < steps:
				rigging.beam(CABLE, Vector3(x, deck_top(), z), point, 0.8)
			last = point
	for step: int in range(3, steps - 2, 3):
		var x: float = lerpf(-foot_x, foot_x, float(step) / steps)
		structure.box(color, Vector3(3, 3, spread * 2.0), Transform3D(Basis.IDENTITY, Vector3(x, deck_top() + rise * (1.0 - pow(x / foot_x, 2.0)), 0)))

## One tall tower each shore with fans of stay cables to the deck.
static func _cable_stayed(structure: Parts, rigging: Parts, color: Color, half: float) -> void:
	var tower_x: float = half + TOWER_SET_M
	var tower_top: float = deck_top() + 85.0
	var spread: float = DECK_W / 2.0 + 1.5
	for side: float in [-1.0, 1.0]:
		_tower(structure, color, side * tower_x, tower_top, 7.0, spread)
		for edge: float in [-1.0, 1.0]:
			var z: float = edge * spread
			for stay: int in range(1, 8):
				var head: Vector3 = Vector3(side * tower_x, tower_top - 4.0 - stay * 3.0, z)
				var reach_x: float = stay * (tower_x - 6.0) / 7.0
				rigging.beam(CABLE, head, Vector3(side * (tower_x - reach_x), deck_top(), z), 0.9)
				rigging.beam(CABLE, head, Vector3(side * (tower_x + reach_x), deck_top(), z), 0.9)

## A through truss: top chords and diagonals over the deck, on stone piers.
static func _truss(structure: Parts, rigging: Parts, color: Color, half: float) -> void:
	var foot_x: float = half + 25.0
	var height: float = 16.0
	var spread: float = DECK_W / 2.0 + 0.5
	for side: float in [-1.0, 1.0]:
		structure.pier(STONE, Vector3(16, deck_bottom() + 6.0, DECK_W + 6.0), Vector3(side * foot_x, deck_bottom() / 2.0 - 3.0, 0))
	var panels: int = 10
	for edge: float in [-1.0, 1.0]:
		var z: float = edge * spread
		structure.beam(color, Vector3(-foot_x, deck_top() + height, z), Vector3(foot_x, deck_top() + height, z), 3.0)
		structure.beam(color, Vector3(-foot_x, deck_top() + 1.0, z), Vector3(foot_x, deck_top() + 1.0, z), 2.5)
		for panel: int in panels + 1:
			var x: float = lerpf(-foot_x, foot_x, float(panel) / panels)
			structure.beam(color, Vector3(x, deck_top(), z), Vector3(x, deck_top() + height, z), 2.0)
			if panel < panels:
				var next: float = lerpf(-foot_x, foot_x, float(panel + 1) / panels)
				var up_left: bool = panel < panels / 2
				structure.beam(color, Vector3(x, deck_top() + (0.0 if up_left else height), z), Vector3(next, deck_top() + (height if up_left else 0.0), z), 1.6)
	for panel: int in range(0, panels + 1, 2):
		var x: float = lerpf(-foot_x, foot_x, float(panel) / panels)
		structure.box(color, Vector3(2, 2, spread * 2.0), Transform3D(Basis.IDENTITY, Vector3(x, deck_top() + height, 0)))
