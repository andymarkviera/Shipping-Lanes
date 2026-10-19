extends Node3D
const Ship = preload("res://features/handling/handling_ship.gd")
var fixtures: Array[Dictionary] = []
var ticks: int = 0
var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func wall(at: Vector3, size: Vector3, layer: int = CollisionRules.SHORE) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = at
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func fixture(label: String, speed: Vector3, kind: String, heading: float = 0.0, layer: int = CollisionRules.SHORE) -> void:
	var origin: Vector3 = Vector3(fixtures.size() * 300, 0, 0)
	var ship: HandlingShip = Ship.new()
	ship.position = origin + Vector3(0, 0, -7 if kind == "reverse" else 7)
	ship.rotation.y = heading
	ship.velocity = speed
	CollisionRules.add_box_hull(ship)
	add_child(ship)
	if kind in ["side", "corner", "rotation"]:
		wall(origin + Vector3(-6.6 if kind == "rotation" else 8, 0, 0), Vector3(0.1, 20, 200))
	if kind not in ["side", "rotation"]:
		wall(origin + Vector3(0, 0, -40 if kind == "reverse" else 40), Vector3(200, 20, 0.1), layer)
	if kind == "hold": ship.command_throttle(1.0)
	if kind == "rotation": ship.maneuver(1.0, 0.0)
	fixtures.append({"label": label, "ship": ship, "origin": origin, "kind": kind, "layer": layer, "valid": true, "max_speed": speed.length(), "contact": false, "last": ship.position})

func _ready() -> void:
	for speed: float in [1.0, 10.0, 20.0]:
		fixture("head-on %.0f m/s" % speed, Vector3(0, 0, speed), "head")
	fixture("stern-first", Vector3(0, 0, -3.75), "reverse")
	fixture("maximum-speed stern-first", Vector3(0, 0, -20), "reverse")
	fixture("glancing maximum speed", Vector3(12, 0, 16), "glance")
	fixture("angled hull", Vector3(8, 0, 16), "angle", 0.45)
	fixture("lateral collision", Vector3(1, 0, 0), "side")
	fixture("corner", Vector3(12, 0, 16), "corner")
	fixture("sustained forward order", Vector3(0, 0, 10), "hold")
	fixture("rotation beside quay", Vector3(0, 0, 4), "rotation")
	for layer: int in [CollisionRules.TRIGGER, CollisionRules.CARGO_VISUAL, CollisionRules.CHARACTER]:
		fixture("non-solid layer %d" % layer, Vector3(0, 0, 20), "ignore", 0.0, layer)
	fixture("other hull layer", Vector3(0, 0, 20), "head", 0.0, CollisionRules.HULL)
	fixture("overspeed clamped", Vector3(0, 0, 200), "head")

func _physics_process(_delta: float) -> void:
	# Parent samples the completed previous tick before children advance.
	if ticks > 0:
		for item: Dictionary in fixtures:
			var ship: HandlingShip = item.ship
			var relative: Vector3 = ship.position - item.origin
			var ext_z: float = absf(cos(ship.rotation.y)) * 32 + absf(sin(ship.rotation.y)) * 6.5
			var ext_x: float = absf(cos(ship.rotation.y)) * 6.5 + absf(sin(ship.rotation.y)) * 32
			var valid: bool = ship.velocity.is_finite() and absf(relative.y) < 0.001 and ship.velocity.length() <= 20.001
			if item.kind not in ["ignore", "rotation", "side", "reverse"]: valid = valid and relative.z + ext_z < 39.951
			if item.kind == "reverse": valid = valid and relative.z - ext_z > -39.951
			if item.kind in ["side", "corner"]: valid = valid and relative.x + ext_x < 7.951
			if item.kind == "rotation": valid = valid and relative.x - ext_x > -6.551
			valid = valid and ship.position.distance_to(item.last) <= 20.0 / 60.0 + 0.005
			if item.valid and not valid: print("CONTACT_DIAGNOSTIC %s tick=%d position=%s velocity=%s step=%f" % [item.label, ticks, relative, ship.velocity, ship.position.distance_to(item.last)])
			item.valid = item.valid and valid
			item.last = ship.position
			item.contact = item.contact or ship.get_slide_collision_count() > 0
	if ticks == 180:
		for item: Dictionary in fixtures:
			var ship: HandlingShip = item.ship
			var relative: Vector3 = ship.position - item.origin
			check(item.valid, item.label + ": no penetration, tunneling or uncontrolled displacement")
			if item.kind == "ignore":
				check(relative.z > 40.0, item.label + ": excluded from hull mask")
			elif item.kind == "rotation":
				check(absf(ship.rotation.y) < 0.01, "Near-wall rotation is conservatively blocked")
			else:
				check(item.contact, item.label + ": actual contact observed")
			if item.kind == "glance": check(relative.x > 5, "Glancing contact preserves travel along wall")
			if item.kind == "hold": check(absf(ship.velocity.z) < 0.02, "Held thrust at wall does not bounce")
		check(fixtures[0].ship.collision_layer == CollisionRules.HULL and fixtures[0].ship.collision_mask == CollisionRules.SOLID_WATERCRAFT, "Hull layer policy applied")
		print("COLLISION_CHECK_%s (%d checks, 16 fixtures, 180 ticks)" % ["PASS" if failures == 0 else "FAIL", checks])
		set_physics_process(false)
		get_tree().quit(0 if failures == 0 else 1)
	ticks += 1
