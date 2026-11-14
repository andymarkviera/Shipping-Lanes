extends RefCounted
## Patch 2.4 item 6: the three heavy-lift load looks, built in code in toon
## colours. Looks only: the load's size, mass, collider and rules are unchanged.
## Each look fills its job's load envelope (width x, height y, length z), with
## its origin at the bottom centre, so a bigger heavy lifter's bigger load is a
## bigger piece and it sits flat on the deck.
const CHUNKY = preload("res://features/toon/chunky_look.gd")
const TOON = preload("res://features/toon/toon_look.gd")
const TURBINE: int = 0
const TRANSFORMER: int = 1
const HULL: int = 2
const NAMES: Array[String] = ["Wind turbine tower section", "Transformer block", "Tug hull on cradle"]
const STEEL: Color = Color("3f6f9a")
const DARK: Color = Color("4a4f5a")

## Load `index` of a job uses look `index`, on every tier.
static func build(kind: int, size: Vector3) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "HeavyLoadLook"
	var cache: Dictionary = {}
	match kind:
		TURBINE: _turbine(root, size, cache)
		TRANSFORMER: _transformer(root, size, cache)
		_: _hull(root, size, cache)
	TOON.apply(root)
	return root

## A tapered white tower section lying fore and aft on two saddles, with dark
## flanges at both ends.
static func _turbine(root: Node3D, size: Vector3, cache: Dictionary) -> void:
	var r: float = minf(size.x, size.y) * 0.47
	var y: float = size.y - r * 1.04
	for z: float in [-0.3, 0.3]:
		CHUNKY._box(root, Vector3(size.x * 0.9, y, size.z * 0.06), Vector3(0, y * 0.5, z * size.z), STEEL, cache)
	var tower: MeshInstance3D = CHUNKY._drum(root, r, r * 0.8, size.z * 0.94, Vector3(0, y, 0), CHUNKY.WHITE, cache)
	tower.rotation.x = PI / 2
	for end: float in [-1.0, 1.0]:
		var radius: float = r * (1.04 if end < 0 else 0.84)
		var flange: MeshInstance3D = CHUNKY._drum(root, radius, radius, size.z * 0.03, Vector3(0, y, end * size.z * 0.47), DARK, cache)
		flange.rotation.x = PI / 2

## A green transformer tank on a skid: radiator fins down both sides, white
## bushings and a conservator drum on top.
static func _transformer(root: Node3D, size: Vector3, cache: Dictionary) -> void:
	var tank: Color = Color("5d8a6a")
	var skid: float = size.y * 0.1
	CHUNKY._box(root, Vector3(size.x, skid, size.z * 0.92), Vector3(0, skid * 0.5, 0), DARK, cache)
	var body: float = size.y * 0.6
	CHUNKY._box(root, Vector3(size.x * 0.66, body, size.z * 0.62), Vector3(0, skid + body * 0.5, 0), tank, cache)
	CHUNKY._box(root, Vector3(size.x * 0.7, size.y * 0.04, size.z * 0.66), Vector3(0, skid + body, 0), CHUNKY.WHITE, cache)
	for side: float in [-1.0, 1.0]:
		for i: int in 5:
			var z: float = (i - 2) * size.z * 0.11
			CHUNKY._box(root, Vector3(size.x * 0.15, body * 0.85, size.z * 0.05), Vector3(side * size.x * 0.415, skid + body * 0.5, z), tank.darkened(0.15), cache)
	var top: float = skid + body + size.y * 0.04
	var bushing: float = size.y - top
	for i: int in 3:
		CHUNKY._drum(root, size.x * 0.05, size.x * 0.035, bushing, Vector3((i - 1) * size.x * 0.2, top + bushing * 0.5, size.z * 0.14), CHUNKY.CREAM, cache)
	var conservator: MeshInstance3D = CHUNKY._drum(root, bushing * 0.3, bushing * 0.3, size.x * 0.55, Vector3(0, top + bushing * 0.45, -size.z * 0.2), tank, cache)
	conservator.rotation.z = PI / 2

## A small toon tug hull sitting in three steel cradles, with its wheelhouse.
static func _hull(root: Node3D, size: Vector3, cache: Dictionary) -> void:
	var cradle: float = size.y * 0.2
	var tall: float = size.y * 0.75
	var colour: Color = Color("3f8f5a")
	var hull: MeshInstance3D = MeshInstance3D.new()
	hull.mesh = CHUNKY.hull_mesh(size.z * 0.92, size.x * 0.8, -tall * 0.55, tall * 0.3, tall * 0.4, tall * 0.05, colour, Color("8f9aa3"))
	hull.position.y = cradle + tall * 0.55
	root.add_child(hull)
	for z: float in [-0.32, 0.0, 0.32]:
		CHUNKY._box(root, Vector3(size.x * 0.9, cradle, size.z * 0.04), Vector3(0, cradle * 0.5, z * size.z), STEEL, cache)
		for side: float in [-1.0, 1.0]:
			CHUNKY._box(root, Vector3(size.x * 0.06, tall * 0.35, size.z * 0.04), Vector3(side * size.x * 0.42, cradle + tall * 0.17, z * size.z), STEEL, cache)
	var deck: float = cradle + tall * 0.85
	var house: float = size.y - deck
	CHUNKY._box(root, Vector3(size.x * 0.4, house * 0.7, size.z * 0.18), Vector3(0, deck + house * 0.35, size.z * 0.12), CHUNKY.WHITE, cache)
	CHUNKY._box(root, Vector3(size.x * 0.44, house * 0.3, size.z * 0.2), Vector3(0, deck + house * 0.85, size.z * 0.12), CHUNKY.RUST, cache)
