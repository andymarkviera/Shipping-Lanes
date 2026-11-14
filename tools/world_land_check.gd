extends SceneTree
## Patch 2.5 item 1A: landmasses, straits and oceans in the real game scene.
## The land data (Progression.LAND, LANDMASSES, STRAITS, SEA_LANES): continents
## and big islands; every port backs onto a coast and keeps its berths, spawn,
## approach and heavy drop area in open water; every port reaches every other by
## sea; each strait is a real narrow cut a ship 5 fits through. Then the game: a
## solid body per block, spawn clearance at every port for the biggest hull, a
## ship driven at a coast stops at it, and the minimap course follows the route.
## Isolated save folder.
## Run: godot --headless --path . --script res://tools/world_land_check.gd

const FOLDER: String = "user://world_land_check"
const Progression = preload("res://features/game/progression.gd")
const Navigation = preload("res://features/ports/local_navigation.gd")
## The biggest hull in any family (bulk ship 5), with room for its swing.
const BIGGEST: Vector3 = Vector3(38, 8, 276)
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("WORLD LAND FAILED: " + label)
	return condition

func solid(point: Vector2) -> bool:
	for block: Rect2 in Progression.LAND + Progression.ICE_SHELVES:
		if block.has_point(point): return true
	return false

func overlaps_land(area: Rect2) -> bool:
	for block: Rect2 in Progression.LAND + Progression.ICE_SHELVES:
		if block.intersects(area): return true
	return false

func route_length(from: Vector3, route: Array[Vector3]) -> float:
	var total: float = 0.0
	var at: Vector3 = from
	for corner: Vector3 in route:
		total += Progression.short_way(corner - at).length()
		at = corner
	return total

func run() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	# Landmasses: two continents of several blocks, at least two big islands.
	var covered: int = 0
	var continents: int = 0
	var islands: int = 0
	for mass: Array in Progression.LANDMASSES:
		expect(mass[1] == covered and mass[2] > mass[1], "%s follows on in LAND" % mass[0])
		covered = mass[2]
		var area: float = 0.0
		for index: int in range(mass[1], mass[2]): area += Progression.LAND[index].get_area()
		if mass[2] - mass[1] >= 4 and area > 1.0e7: continents += 1
		elif area > 3.0e5: islands += 1
	expect(covered == Progression.LAND.size(), "Every land block belongs to a landmass")
	expect(continents >= 2 and islands >= 2, "Two continents and big islands (%d continents, %d islands)" % [continents, islands])
	# Every port: the quay's root backs onto land; berths, approach, spawn and the
	# heavy drop area are open water.
	for index: int in Progression.WORLD.size():
		var place: Dictionary = Progression.WORLD[index]
		var quay_side: float = -float(place.drop_side)
		var at: Vector2 = Vector2(place.at.x, place.at.z)
		expect(solid(at + Vector2(quay_side * 105, 100)), "%s backs onto a coast" % place.id)
		var water: Rect2 = Rect2(Vector2(minf(at.x + quay_side * 15, at.x - quay_side * 350), at.y - 1400), Vector2(365, 2200))
		expect(not overlaps_land(water), "%s has open water at its berths and approach" % place.id)
		var drop: Rect2 = Rect2(Vector2(minf(at.x + place.drop_side * 450, at.x + place.drop_side * 850), at.y - 1200), Vector2(400, 400))
		expect(not overlaps_land(drop.grow(150)), "%s heavy drop area is open sea" % place.id)
	# Sea access: every port reaches every other through the lanes, every leg
	# keeps clear of land, and no leg is longer than a long tier job.
	var longest: float = 0.0
	for a: int in Progression.WORLD.size():
		for b: int in Progression.WORLD.size():
			if a == b: continue
			var route: Array[Vector3] = Progression.sea_route(Progression.gate(a), Progression.gate(b))
			var from: Vector3 = Progression.gate(a)
			var clear: bool = not route.is_empty()
			for corner: Vector3 in route:
				clear = clear and Progression.clear_line(Vector2(from.x, from.z), Vector2(corner.x, corner.z))
				from = corner
			var length: float = route_length(Progression.gate(a), route)
			longest = maxf(longest, length)
			expect(clear and length < 11000.0, "%s reaches %s by sea (%.0f m, %d turns)" % [Progression.WORLD[a].id, Progression.WORLD[b].id, length, route.size() - 1])
	print("WORLD LAND longest port-to-port sea route %.0f m" % longest)
	# Straits: each is a narrow cut a ship 5 (2.5 beams) fits through, with land
	# close on both sides, and a sea lane runs down it.
	for strait: Dictionary in Progression.STRAITS:
		var half: float = strait.width_m / 2.0
		expect(strait.width_m >= 2.5 * BIGGEST.x, "%s is wide enough for ship 5" % strait.name)
		expect(Progression.clear_line(strait.from, strait.to, half - 5.0), "%s is open water %.0f m across" % [strait.name, strait.width_m])
		var middle: Vector2 = (strait.from + strait.to) / 2.0
		var across: Vector2 = (strait.to - strait.from).normalized().orthogonal()
		expect(solid(middle + across * (half + 40.0)) and solid(middle - across * (half + 40.0)), "%s has land close on both sides" % strait.name)
		expect(not solid(middle + across * (half - 5.0)) and not solid(middle - across * (half - 5.0)), "%s is open from shore to shore" % strait.name)
		expect(Progression.SEA_LANES.has(strait.from) and Progression.SEA_LANES.has(strait.to), "A sea lane runs through %s" % strait.name)
	var likes: Array = Progression.STRAITS.map(func(strait: Dictionary) -> String: return strait.like)
	expect(likes.has("Panama") and likes.size() >= 4, "Three straits and a canal")

	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	var game: Node = null
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and scene.get("persistence") != null and is_instance_valid(scene.persistence) and (scene.persistence.ready_to_save or scene.persistence.blocked):
			game = scene
			break
	if not expect(game != null, "Game scene opened"): return finish()
	for frame: int in 3: await physics_frame
	# A solid body for every block, the size of the block.
	var bodies: int = 0
	for child: Node in game.get_children():
		var body: StaticBody3D = child as StaticBody3D
		if body == null or body.collision_layer != CollisionRules.SHORE or not body.get_child(0) is CollisionShape3D: continue
		if (body.get_child(0) as CollisionShape3D).shape is BoxShape3D: bodies += 1
	expect(bodies == Progression.LAND.size() + Progression.ICE_SHELVES.size(), "Every land block is solid (%d bodies)" % bodies)
	var paints: Dictionary = {}
	for child: Node in game.get_children():
		if child is StaticBody3D and child.get_child_count() > 1 and child.get_child(0).shape is BoxShape3D and child.get_child(1) is MeshInstance3D: paints[(child.get_child(1) as MeshInstance3D).material_override] = true
	expect(paints.size() <= 4, "Land shares its materials (%d)" % paints.size())
	# Spawn clearance at every port holds the biggest hull clear of the land.
	for place: Node3D in game.world_ports:
		if place == game.port: continue
		var spot: Dictionary = place.reserve_spawn(BIGGEST)
		expect(spot.get("ok", false), "%s spawns a ship 5 clear of land (%s)" % [place.definition.id, spot.get("reason", "ok")])
		if spot.get("ok", false): place.spawn_allocator.release(spot.ticket)
	# The minimap course follows the sea route: Brindle Quay to Cinder Point goes
	# round the point, not over it.
	var ship: HandlingShip = game.ship
	var route: Array[Vector3] = Progression.course(ship.global_position, game.world_ports[2].berth_anchor.global_position, 2)
	expect(route.size() >= 2 and route[-1] == game.world_ports[2].berth_anchor.global_position, "The course to Cinder Point turns round the land (%d legs)" % route.size())
	# Solid land: a ship driven at Kelp Isle from the strait stops at its shore.
	var shore: float = Progression.LAND[Progression.LANDMASSES[3][1]].position.x
	ship.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(shore - 110, ship.global_position.y, -500))
	ship.velocity = Vector3.ZERO
	var start: float = ship.global_position.x
	var deepest: float = -INF
	for tick: int in 60 * 20:
		ship.command_throttle(1.0)
		await physics_frame
		deepest = maxf(deepest, ship.global_position.x)
	ship.command_throttle(0.0)
	expect(deepest > start + 40.0, "The ship sailed at the shore (%.0f m)" % (deepest - start))
	expect(deepest < shore, "Land is solid: the ship stops at the shore (centre %.0f m short)" % (shore - deepest))
	finish()

func finish() -> void:
	print("WORLD LAND CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
