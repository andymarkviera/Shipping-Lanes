extends Node
const Owner = preload("res://features/network/public_ship_owner.gd")
const World = preload("res://features/network/public_physics_world.gd")
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")
var world: Node
var owners: Array = []
var checks: int = 0
var failures: int = 0
var ticks: int = 0
var touched: bool = false
var safe: bool = true
var closest: float = INF

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func make_owner(address: Dictionary) -> Node3D:
	var owner: Node3D = Owner.new()
	add_child(owner)
	owner.restore_grant({"profile": {"ship": {"id": str(owner.get_instance_id()), "fuel_liters": 800.0, "position": {"latitude": address.latitude_deg, "longitude": address.longitude_deg, "heading": address.heading_deg}}, "cargo": []}})
	return owner

func mapping_case(latitude: float, longitude: float) -> void:
	var origin: Dictionary = Geo.normalized(latitude, longitude, 90.0)
	var first: Node3D = make_owner(origin)
	var second: Node3D = make_owner(Nav.travel(origin, 180.0))
	var distant: Node3D = make_owner(Nav.travel(origin, 3000.0))
	var before: Dictionary = second.current_address()
	second.ship.velocity = Vector3(2, 0, 3)
	world.sync([first, second, distant])
	check(first.ship.get_world_3d() == second.ship.get_world_3d(), "nearby hulls share real physics space")
	check(first.ship.get_world_3d() != distant.ship.get_world_3d(), "distant hull keeps independent precision chart")
	check(Nav.separation(before, second.current_address()) < 0.001, "merge preserves geographic position")
	check(absf(Geo.longitude_delta(before.heading_deg, second.current_address().heading_deg)) < 0.001, "merge preserves heading across seam/pole")
	check(absf(second.ship.velocity.length() - sqrt(13.0)) < 0.001 and second.ship.state.fuel_liters == 800, "merge preserves velocity magnitude and fuel")
	var blocked: Node3D = make_owner(origin)
	check(not world.can_place(blocked, [first]), "overlapping saved spawn is refused")
	check(world.can_place(distant, [first, second]), "clear distant spawn remains allowed")
	blocked.queue_free()
	var away: Dictionary = Nav.travel(origin, 600.0)
	second.reframe(away, away)
	world.sync([first, second, distant])
	check(first.ship.get_world_3d() != second.ship.get_world_3d(), "separating ships split physics groups")
	check(Nav.separation(away, second.current_address()) < 0.001, "split preserves canonical position")
	second.reframe(before, before)
	world.sync([first, second, distant])
	check(first.ship.get_world_3d() == second.ship.get_world_3d(), "returning ships merge again")
	first.ship.position.z += 700
	second.ship.position.z += 700
	var moved: Dictionary = second.current_address()
	world.sync([first, second, distant])
	check(Nav.separation(moved, second.current_address()) < 0.001 and first.ship.position.length() < 0.001, "moving group rebases without teleporting canonical positions")
	for owner: Node3D in [first, second, distant]:
		owner.reparent(self, false)
		owner.queue_free()
	world.sync([])

func _ready() -> void:
	process_physics_priority = -100
	world = World.new()
	add_child(world)
	mapping_case(0.0, 179.99)
	mapping_case(89.99, 30.0)
	var origin: Dictionary = Geo.normalized(0, 0, 0)
	var other: Dictionary = Nav.travel(origin, 100)
	other.heading_deg = 180.0
	owners = [make_owner(origin), make_owner(other)]
	world.sync(owners)
	owners[0].ship.velocity = Vector3(0, 0, 20)
	owners[1].ship.velocity = Vector3(0, 0, -20)

func _physics_process(_delta: float) -> void:
	world.sync(owners)
	ticks += 1
	var first: HandlingShip = owners[0].ship
	var second: HandlingShip = owners[1].ship
	if first.get_slide_collision_count() > 0 or second.get_slide_collision_count() > 0: touched = true
	closest = minf(closest, second.position.z - first.position.z)
	if second.position.z - first.position.z < 63.9: safe = false
	if ticks == 180:
		check(touched, "two moving authoritative hulls make real contact")
		check(safe, "head-on hulls never pass through one another")
		check(first.velocity.length() < 0.1 and second.velocity.length() < 0.1, "collision removes closing velocity")
		owners[0].park()
		check(first.collision_layer == 0 and first.collision_mask == 0 and not first.is_physics_processing(), "fenced hull cannot obstruct shared space")
		print("PUBLIC_PHYSICS_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
		get_tree().quit(0 if failures == 0 else 1)
