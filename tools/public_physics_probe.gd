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
	set_physics_process(false)
	process_physics_priority = -100
	world = World.new()
	add_child(world)
	await impact_case()
	await port_case()
	set_physics_process(true)
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

func port_case() -> void:
	check(not Geo.decode(Geo.normalized(0, 0, -1e-15)).is_empty(), "Tiny negative heading remains canonical across north")
	var leader: Node3D = make_owner(Nav.travel(Geo.normalized(0, 0, 180), 100))
	var sailor: Node3D = make_owner(Nav.travel(Geo.normalized(0, 0, 0), 70))
	for owner: Node3D in [leader, sailor]:
		owner.ship.set_physics_process(false)
		owner.authority.set_process(false)
		owner.authority.active = true
	world.sync([leader, sailor])
	await get_tree().physics_frame
	await get_tree().physics_frame
	var port: Node3D = world.port_for(sailor, "port_brindle_quay")
	check(port != null and port.get_world_3d() == sailor.ship.get_world_3d(), "Canonical port occupies the ship's real collision world")
	var docks = preload("res://features/network/public_port_authority.gd").new()
	docks.world = world
	add_child(docks)
	docks.register(1, sailor)
	check(docks.status(1).eligible, "Geographic berth accepts aligned stopped hull")
	check(docks.request(1, "dock", "port_brindle_quay").ok, "Server reserves geographic berth")
	docks.advance(1.1)
	check(docks.entries[1].state == "docked" and sailor.ship.docked, "Server docking freezes and secures hull")
	var before: Dictionary = sailor.current_address()
	leader.reparent(self, false)
	world.sync([sailor])
	docks.advance(.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	docks.advance(.1)
	check(docks.entries[1].state == "docked" and docks.reservations.get("port_brindle_quay") == 1, "Berth ownership survives physics regroup/rebase")
	check(Nav.separation(before, sailor.current_address()) < .001, "Docked regroup preserves world position")
	check(sailor.ship.global_position.distance_to(world.port_for(sailor, "port_brindle_quay").berth_anchor.global_position) < .01, "Rebased port and docked ship remain aligned")
	sailor.authority.active = false
	docks.advance(.1)
	check(docks.reservations.is_empty() and not sailor.ship.docked, "Lost authority releases berth")
	var shore: Dictionary = Nav.travel(Geo.normalized(0, 0, rad_to_deg(atan2(60, 70))), sqrt(8500))
	check(not world.Ports.spawn_clear(shore, Vector3(13, 4, 64)), "Saved spawn inside quay is refused")
	check(world.Ports.spawn_clear(before, Vector3(13, 4, 64)), "Clear saved berth position remains allowed")
	for owner: Node3D in [leader, sailor]:
		owner.reparent(self, false)
		owner.queue_free()
	docks.queue_free()
	world.sync([])
	await get_tree().process_frame

func impact_case() -> void:
	for incoming: Vector3 in [Vector3(0, 0, 1.5), Vector3(0, 0, 14), Vector3(14, 0, 1.0)]:
		var owner: Node3D = make_owner(Geo.normalized(10, 10))
		owner.ship.position.z = 7
		owner.ship.velocity = incoming
		var hits: Array[int] = []
		owner.ship.validated_impact.connect(func(amount: int): hits.append(amount))
		var wall := StaticBody3D.new()
		wall.collision_layer = CollisionRules.SHORE
		wall.collision_mask = CollisionRules.HULL
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(200, 10, 1)
		shape.shape = box
		wall.add_child(shape)
		add_child(wall)
		wall.position.z = 40
		var contact: bool = false
		for tick: int in 75:
			await get_tree().physics_frame
			contact = contact or owner.ship.get_slide_collision_count() > 0
		check(contact, "impact threshold fixture makes actual solid contact")
		if incoming.z <= 2: check(hits.is_empty(), "gentle/glancing contact causes no hull damage")
		else: check(hits.size() == 1 and hits[0] > 0 and hits[0] <= 10000, "hard real collision emits one bounded damage event")
		owner.queue_free()
		wall.queue_free()
		await get_tree().process_frame
