extends SceneTree
## Patch 2.5 item 1A: landmasses, straits and oceans in the real game scene.
## The land data (Progression.LAND, LANDMASSES, STRAITS, SEA_LANES): continents
## and big islands; every port backs onto a coast and keeps its berths, spawn,
## approach and heavy drop area in open water; every port reaches every other by
## sea; each strait is a real narrow cut a ship 5 fits through. Then the game: a
## solid body per block, spawn clearance at every port for the biggest hull, a
## ship driven at a coast stops at it, and the minimap course follows the route.
## Part B: toon coasts with surf and harbour walls; the globe atlas draws land
## as one shape per continent with the straits open.
## Patch 2.5 item 2: bridges over the straits: at least three, one suspension;
## the deck clears the tallest ship of every family; towers and piers are solid,
## on land and out of the channel; a ship 5 sized box sweeps under each deck.
## Isolated save folder.
## Run: godot --headless --path . --script res://tools/world_land_check.gd

const FOLDER: String = "user://world_land_check"
const Progression = preload("res://features/game/progression.gd")
const Navigation = preload("res://features/ports/local_navigation.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
const GLOBE_MAP = preload("res://features/game/globe_map.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const TOON_BRIDGE = preload("res://features/toon/toon_bridge.gd")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
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
	# Part B: every block has a toon coast; the blocks share their materials and
	# the surf shares one shader that stops drawing far away.
	var paints: Dictionary = {}
	var surfs: Dictionary = {}
	var coasts: int = 0
	var beaches: int = 0
	for child: Node in game.get_children():
		if not child is StaticBody3D or child.get_node_or_null("Coast") == null: continue
		var coast: MeshInstance3D = child.get_node("Coast")
		coasts += 1
		for surface: int in coast.mesh.get_surface_count(): paints[coast.get_active_material(surface)] = true
		var surf: MeshInstance3D = child.get_node_or_null("Surf")
		if surf == null: continue
		beaches += 1
		surfs[surf.material_override] = true
		expect(surf.visibility_range_end > 0.0 and surf.visibility_range_end <= 2000.0, "%s surf is culled far away" % child.name)
	expect(coasts == Progression.LAND.size() + Progression.ICE_SHELVES.size(), "Every land block has a toon coast (%d)" % coasts)
	# Sand, green top, ice, snow, and (Patch 2.5 item 4) the desert's sand top.
	expect(paints.size() <= 5 and not paints.has(null), "Land shares its materials (%d)" % paints.size())
	expect(beaches >= Progression.LANDMASSES.size() and surfs.size() == 1, "Beaches have surf with one shared shader (%d beaches)" % beaches)
	# The surf takes the sea's time on the game's next drawn frame.
	for frame: int in 2: await process_frame
	expect(game.surf_paint != null and float(game.surf_paint.get_shader_parameter("water_time")) > 0.0 and absf(float(game.surf_paint.get_shader_parameter("water_time")) - game.ocean.elapsed) < 0.5, "Surf rides the sea's swell")
	# A port's side of the land is a harbour wall at deck height, not a beach.
	var ports: Array[Vector2] = []
	for place: Dictionary in Progression.WORLD: ports.append(Vector2(place.at.x, place.at.z))
	for place: Dictionary in Progression.WORLD:
		var walled: bool = false
		for rect: Rect2 in Progression.LAND + Progression.ICE_SHELVES:
			var harbour: Array[bool] = TOON_COAST.harbour_sides(rect, [Vector2(place.at.x, place.at.z)] as Array[Vector2])
			walled = walled or harbour.has(true)
		expect(walled, "%s has a harbour wall" % place.id)
	# The globe atlas draws the land green and leaves the straits open.
	var page: Image = GLOBE_MAP.atlas().get_image()
	for mass: Array in Progression.LANDMASSES:
		var centre: Vector2 = Progression.LAND[mass[1]].get_center()
		var pixel: Vector2i = Vector2i(GLOBE_MAP.page_pixel(centre.x, centre.y))
		expect(page.get_pixelv(pixel).is_equal_approx(Color(PLAYFUL.LEAF, 1.0)), "%s is green on the globe" % mass[0])
	for strait: Dictionary in Progression.STRAITS:
		var middle: Vector2 = (strait.from + strait.to) / 2
		var pixel: Vector2i = Vector2i(GLOBE_MAP.page_pixel(middle.x, middle.y))
		expect(page.get_pixelv(pixel).b > 0.6, "%s is open water on the globe" % strait.name)
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
	await check_bridges(game)
	finish()

func top_of(node: Node, base: Transform3D) -> float:
	var best: float = -INF
	var visual: VisualInstance3D = node as VisualInstance3D
	if visual != null and visual.is_visible_in_tree(): best = (base * visual.global_transform * visual.get_aabb()).end.y
	for child: Node in node.get_children(): best = maxf(best, top_of(child, base))
	return best

func check_bridges(game: Node) -> void:
	var styles: Array = Progression.BRIDGES.map(func(entry: Dictionary) -> String: return entry.style)
	expect(Progression.BRIDGES.size() >= 3 and styles.has("suspension"), "At least three bridges, one a suspension bridge (%d)" % Progression.BRIDGES.size())
	# The tallest ship of every family, dressed as in the game, plus the
	# biggest heavy load on the biggest lifter's deck.
	var tallest: float = 0.0
	var tallest_kind: String = ""
	var kind_before: String = game.ship_kind
	var heavy_before: bool = game.heavy_mode
	for kind: String in Progression.SHIPS:
		game.ship_kind = kind
		game.heavy_mode = Progression.heavy_tier(kind) > 0
		var probe: Node3D = game.create_ship()
		probe.position = Vector3(0, 0, -20000)
		# Measured only: no sound, no physics.
		probe.process_mode = Node.PROCESS_MODE_DISABLED
		game.add_child(probe)
		CHUNKY_LOOK.dress_ship(probe, kind)
		var height: float = top_of(probe, probe.global_transform.affine_inverse())
		if game.heavy_mode: height = maxf(height, 7.5 + 8.0 * sqrt(probe.definition.hull_size_m.x / 24.0))
		if height > tallest:
			tallest = height
			tallest_kind = kind
		probe.queue_free()
	game.ship_kind = kind_before
	game.heavy_mode = heavy_before
	for frame: int in 3: await process_frame
	print("WORLD LAND tallest ship %s %.1f m, bridge clearance %.0f m" % [tallest_kind, tallest, TOON_BRIDGE.deck_bottom()])
	expect(tallest > 30.0 and TOON_BRIDGE.deck_bottom() >= tallest + 15.0, "Bridge decks clear the tallest ship (%s, %.1f m) by 15 m" % [tallest_kind, tallest])
	var paints: Dictionary = {}
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for index: int in Progression.BRIDGES.size():
		var entry: Dictionary = Progression.BRIDGES[index]
		var strait: Dictionary = Progression.bridge_strait(index)
		if not expect(not strait.is_empty(), "%s crosses a strait" % entry.name): continue
		var bridge: Node3D = game.bridges.get_node_or_null(NodePath(entry.id))
		if not expect(bridge != null, "%s is in the game" % entry.name): continue
		var half: float = TOON_BRIDGE.half_span(index)
		var way: Vector2 = TOON_BRIDGE.across(index)
		var at: Vector2 = entry.at
		var cut: Rect2 = Rect2(strait.from, Vector2.ZERO).expand(strait.to).grow(half)
		expect(cut.has_point(at), "%s sits on its strait" % entry.name)
		# Both ends land on land: every point past the shore is solid.
		var landed: bool = true
		var along: float = half + 10.0
		while along <= TOON_BRIDGE.reach(index):
			landed = landed and solid(at + way * along) and solid(at - way * along)
			along += 10.0
		expect(landed, "%s runs onto land at both ends" % entry.name)
		# Towers and piers: solid, on land, out of the channel.
		var piers: StaticBody3D = bridge.get_node("Piers")
		var on_land: bool = piers.collision_layer == CollisionRules.SHORE and piers.get_child_count() >= 4
		for collider: Node in piers.get_children():
			var shape: CollisionShape3D = collider as CollisionShape3D
			var size: Vector3 = (shape.shape as BoxShape3D).size
			for corner: Vector3 in [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
				var point: Vector3 = shape.global_transform * (corner * size / 2.0)
				on_land = on_land and solid(Vector2(point.x, point.z)) and not cut.has_point(Vector2(point.x, point.z))
		expect(on_land, "%s stands its %d towers and piers on land, out of the channel" % [entry.name, piers.get_child_count()])
		# Looks: two merged meshes, the rigging culled sooner than the structure.
		var body: MeshInstance3D = bridge.get_node("Bridge")
		var rigging: MeshInstance3D = bridge.get_node("Rigging")
		expect(body.visibility_range_end > 0.0 and rigging.visibility_range_end > 0.0 and rigging.visibility_range_end < body.visibility_range_end, "%s culls far away" % entry.name)
		for mesh: MeshInstance3D in [body, rigging]:
			for surface: int in mesh.mesh.get_surface_count(): paints[mesh.get_active_material(surface)] = true
		# A ship 5 sized box, as tall as the tallest ship, sweeps under the deck.
		var dir: Vector2 = (strait.to - strait.from).normalized()
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(BIGGEST.x * 1.5, tallest + 6.0, BIGGEST.z)
		query.shape = box
		query.collision_mask = CollisionRules.SHORE
		var clear: bool = true
		for step: int in range(-6, 7):
			var centre: Vector2 = at + dir * step * 50.0
			query.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(centre.x, tallest / 2.0 - 3.0, centre.y))
			clear = clear and space.intersect_shape(query, 1).is_empty()
		expect(clear, "A ship 5 passes under %s" % entry.name)
	expect(paints.size() <= 3 + TOON_BRIDGE.PAINT.size() and not paints.has(null), "Bridges share their materials (%d)" % paints.size())

func finish() -> void:
	print("WORLD LAND CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
