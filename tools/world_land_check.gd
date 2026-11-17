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
## Patch 2.9 item 6A: the land is the natural seeded land (natural_land.json):
## a body per landmass, coast chunks culled far away, no long straight coast.
## Patch 2.5 item 2: bridges over the straits: at least three, one suspension;
## the deck clears the tallest ship of every family; towers and piers are solid,
## on land and out of the channel; a ship 5 sized box sweeps under each deck.
## Patch 2.9.1 item 6: the polar ice cap along the north/south edge: solid in
## chunks that follow the ship across the edges, leads open where the routes
## cross, both polar quays backed by ice, drawn on the globe and the minimap.
## Isolated save folder.
## Run: godot --headless --path . --script res://tools/world_land_check.gd

const FOLDER: String = "user://world_land_check"
const Progression = preload("res://features/game/progression.gd")
const Navigation = preload("res://features/ports/local_navigation.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
const GLOBE_MAP = preload("res://features/game/globe_map.gd")
const GLOBE_MINIMAP = preload("res://features/game/globe_minimap.gd")
const POLAR_ICE = preload("res://features/toon/polar_ice.gd")
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
	# Patch 2.9 item 6A: one solid body per landmass holding a box per block.
	var shapes: int = 0
	var masses: int = 0
	for child: Node in game.get_children():
		var body: StaticBody3D = child as StaticBody3D
		if body == null or body.collision_layer != CollisionRules.SHORE or body.get_child_count() == 0 or not body.get_child(0) is CollisionShape3D: continue
		if String(body.name).begins_with("Land"):
			masses += 1
			for collider: Node in body.get_children():
				if collider is CollisionShape3D and (collider as CollisionShape3D).shape is BoxShape3D: shapes += 1
	expect(masses == Progression.LANDMASSES.size() and shapes == Progression.LAND.size(), "Every land block is solid (%d landmasses, %d blocks)" % [masses, shapes])
	# The toon coast: 1 km chunks, culled far away, sharing their materials;
	# the surf shares one shader and stops drawing sooner.
	var paints: Dictionary = {}
	var surfs: Dictionary = {}
	var coasts: int = 0
	var beaches: int = 0
	var culled: bool = true
	var land: Node3D = game.get_node_or_null("NaturalLand")
	if expect(land != null, "The natural land is in the game"):
		for chunk: Node in land.get_children():
			var mesh: MeshInstance3D = chunk as MeshInstance3D
			if mesh == null: continue
			if String(mesh.name).begins_with("Coast"):
				coasts += 1
				culled = culled and mesh.visibility_range_end > 0.0 and mesh.visibility_range_end <= 4000.0
				for surface: int in mesh.mesh.get_surface_count(): paints[mesh.get_active_material(surface)] = true
			else:
				beaches += 1
				surfs[mesh.material_override] = true
				culled = culled and mesh.visibility_range_end > 0.0 and mesh.visibility_range_end <= 2000.0
	expect(coasts >= 20 and culled, "The coast is in %d chunks, culled far away" % coasts)
	# Sand, green top, (Patch 2.5 item 4) the desert's sand top, (item 5) the
	# tropics' lush top and (item 6) the rainy city's wet top.
	expect(paints.size() <= 5 and not paints.has(null), "Land shares its materials (%d)" % paints.size())
	expect(beaches >= 10 and surfs.size() == 1, "Beaches have surf with one shared shader (%d chunks)" % beaches)
	# The surf takes the sea's time on the game's next drawn frame.
	for frame: int in 2: await process_frame
	expect(game.surf_paint != null and float(game.surf_paint.get_shader_parameter("water_time")) > 0.0 and absf(float(game.surf_paint.get_shader_parameter("water_time")) - game.ocean.elapsed) < 0.5, "Surf rides the sea's swell")
	# A port's side of the land is a harbour wall at deck height, not a beach.
	var ports: Array[Vector2] = []
	for place: Dictionary in Progression.WORLD: ports.append(Vector2(place.at.x, place.at.z))
	for place: Dictionary in Progression.WORLD:
		var back: Vector2 = Vector2(place.at.x - float(place.drop_side) * 100.0, place.at.z + 100.0)
		expect(TOON_COAST.harbour_weight(back, ports) >= 1.0 and TOON_COAST.sand_height(6.0, 1.0) >= TOON_COAST.SAND_TOP_Y - 0.01, "%s has a harbour wall" % place.id)
	# Natural: the seed is fixed, the coast follows the grid smoothly and no
	# coast runs dead straight for long, except the harbour walls by the quays.
	var grid: Dictionary = Progression.natural_land()
	expect(grid.get("seed", 0) == 3002 and grid.count.x * grid.count.y == grid.depth.size(), "The land is baked from seed 3002")
	var straight_run: float = 0.0
	for entry: Dictionary in grid.outlines:
		var ring: PackedVector2Array = entry.outline
		for i: int in ring.size():
			var j: int = i + 2
			while j < i + ring.size():
				var a: Vector2 = ring[i]
				var b: Vector2 = ring[j % ring.size()]
				var straight: bool = a.distance_to(b) > 0.0
				for k: int in range(i + 1, j):
					straight = straight and Geometry2D.get_closest_point_to_segment(ring[k % ring.size()], a, b).distance_to(ring[k % ring.size()]) < 6.0
				if not straight: break
				var middle: Vector2 = (a + b) / 2.0
				if TOON_COAST.harbour_weight(middle, ports) <= 0.0: straight_run = maxf(straight_run, a.distance_to(b))
				j += 1
	expect(straight_run <= 400.0, "No straight coast over 400 m away from the quays (straight_run %.0f m)" % straight_run)
	expect(grid.outlines.size() >= 10, "Continents, peninsulas and islands: %d coasts" % grid.outlines.size())
	# The globe atlas draws the land green and leaves the straits open.
	var page: Image = GLOBE_MAP.atlas().get_image()
	for mass: Array in Progression.LANDMASSES:
		var centre: Vector2 = Progression.LAND[mass[1]].get_center()
		for index: int in range(mass[1], mass[2]):
			if Progression.land_depth(Progression.LAND[index].get_center()) > Progression.land_depth(centre): centre = Progression.LAND[index].get_center()
		var pixel: Vector2i = Vector2i(GLOBE_MAP.page_pixel(centre.x, centre.y))
		# Patch 2.9 item 6A: a small isle may be all coast line (ink green).
		expect(page.get_pixelv(pixel).is_equal_approx(Color(PLAYFUL.LEAF, 1.0)) or page.get_pixelv(pixel).is_equal_approx(Color("2f7a33")), "%s is green on the globe" % mass[0])
	for strait: Dictionary in Progression.STRAITS:
		var middle: Vector2 = (strait.from + strait.to) / 2
		var pixel: Vector2i = Vector2i(GLOBE_MAP.page_pixel(middle.x, middle.y))
		expect(page.get_pixelv(pixel).b > 0.6, "%s is open water on the globe" % strait.name)
	# Patch 2.9.1 item 6: the polar ice cap. Every block is solid, in 20 chunks
	# with a culled toon coast; no block crosses an edge of the world.
	var wrap: float = Progression.WRAP_M
	var cap: Node3D = game.get_node_or_null("PolarIce")
	if expect(cap != null and cap.get_child_count() == Progression.ICE_CHUNKS.size() and cap.get_child_count() == 20, "The polar ice cap is in the game in 20 chunks"):
		var boxes: int = 0
		var ice_coasts: int = 0
		var ice_culled: bool = true
		var ice_paints: Dictionary = {}
		var ice_surf: bool = true
		for chunk: Node in cap.get_children():
			var body: StaticBody3D = chunk.get_node_or_null("Ice") as StaticBody3D
			if body == null or body.collision_layer != CollisionRules.SHORE: continue
			for collider: Node in body.get_children():
				if collider is CollisionShape3D and (collider as CollisionShape3D).shape is BoxShape3D: boxes += 1
			for part: Node in chunk.get_children():
				var mesh: MeshInstance3D = part as MeshInstance3D
				if mesh == null: continue
				if String(mesh.name).begins_with("Coast"):
					ice_coasts += 1
					ice_culled = ice_culled and mesh.visibility_range_end > 0.0 and mesh.visibility_range_end <= 4000.0
					for surface: int in mesh.mesh.get_surface_count(): ice_paints[mesh.get_active_material(surface)] = true
				else:
					ice_surf = ice_surf and mesh.material_override == game.surf_paint and mesh.visibility_range_end > 0.0 and mesh.visibility_range_end <= 2000.0
		expect(boxes == Progression.ICE_SHELVES.size() and boxes > 100, "Every block of the ice cap is solid (%d)" % boxes)
		expect(ice_coasts >= 20 and ice_culled and ice_surf, "The ice coast is in %d bands, culled far away, with the land's surf" % ice_coasts)
		expect(ice_paints.size() == 2 and not ice_paints.has(null), "The ice shares two materials: ice and snow")
		# Each chunk sits at its copy nearest the ship, across either edge.
		POLAR_ICE.place(cap, Progression.WRAP_CENTRE + Vector3(wrap / 2 - 10, 0, wrap / 2 - 10))
		var west_north: Node3D = cap.get_child(0)
		var west_south: Node3D = cap.get_child(Progression.ICE_COLUMNS)
		expect(west_north.position.distance_to(Vector3(wrap, 0, 0)) < 1.0 and west_south.position.distance_to(Vector3(wrap, 0, wrap)) < 1.0, "Ice chunks follow the ship across the edges of the world")
		POLAR_ICE.place(cap, game.ship.global_position)
	var world_box: Rect2 = Rect2(Vector2(Progression.WRAP_CENTRE.x, Progression.WRAP_CENTRE.z) - Vector2(wrap, wrap) / 2, Vector2(wrap, wrap)).grow(0.1)
	var inside: bool = true
	for block: Rect2 in Progression.ICE_SHELVES: inside = inside and world_box.encloses(block) and block.size.x <= wrap / Progression.ICE_COLUMNS + 0.1
	expect(inside, "No ice block crosses an edge of the world")
	# The cap lies along the whole edge on both sides, but for the leads; the
	# blocks and the depth grid agree.
	var edge_z: float = Progression.WRAP_CENTRE.z + wrap / 2
	for side: float in [-1.0, 1.0]:
		var iced: int = 0
		for step: int in 200:
			if solid(Vector2(Progression.WRAP_CENTRE.x + (step / 200.0 - 0.5) * wrap + 7.0, edge_z - wrap * maxf(side, 0.0) + side * 40.0)): iced += 1
		expect(iced >= 170 and iced < 200, "The ice cap covers the %s end of the world but for its leads (%d of 200)" % ["south" if side > 0.0 else "north", iced])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2916
	var agree: bool = true
	for sample: int in 600:
		var at: Vector2 = Vector2(Progression.WRAP_CENTRE.x + rng.randf_range(-0.5, 0.5) * wrap, edge_z - rng.randf_range(0.0, 2700.0))
		if rng.randf() < 0.5: at.y = edge_z - wrap + rng.randf_range(0.0, 2700.0)
		var d: float = Progression.ice_depth(at)
		var in_ice: bool = Progression.ICE_SHELVES.any(func(block: Rect2) -> bool: return block.has_point(at))
		if (d > 20.0 and not in_ice) or (d < -20.0 and in_ice): agree = false
	expect(agree and is_equal_approx(Progression.ice_depth(Vector2(0, 0)), -300.0), "The ice depth grid and the solid blocks agree")
	expect(is_equal_approx(Progression.ice_depth(Vector2(900, edge_z - 30)), Progression.ice_depth(Vector2(900 - wrap, edge_z - 30 + wrap))), "The ice is the same one world along")
	# The leads: both sea routes that cross the edge run straight through.
	var south_gate: Vector3 = Progression.gate(Progression.port_index("port_south_pole"))
	expect(Progression.clear_line(Vector2(680, 3550), Vector2(-2600, -4800)) and Progression.clear_line(Vector2(2400, 3550), Vector2(south_gate.x, south_gate.z)), "The leads through the ice are open on both routes across the edge")
	# Both polar quays: deep ice behind them at quay height, sea in front.
	for id: String in ["port_north_pole", "port_south_pole"]:
		var place: Dictionary = Progression.WORLD[Progression.port_index(id)]
		var back: Vector2 = Vector2(place.at.x - float(place.drop_side) * 220.0, place.at.z + 150.0)
		expect(Progression.ice_depth(back) > 60.0 and Progression.ice_depth(Vector2(place.at.x + float(place.drop_side) * 150.0, place.at.z)) < -60.0, "%s has ice behind its quay and sea at its berths" % id)
		expect(absf(POLAR_ICE.ice_height(30.0, Vector2(place.at.x - float(place.drop_side) * 110.0, place.at.z + 150.0), 1.0) - TOON_COAST.SAND_TOP_Y) < 0.01, "%s ice meets the quay at deck height" % id)
	expect(POLAR_ICE.ice_height(-2.0, Vector2.ZERO, 0.0) < -3.0 and POLAR_ICE.ice_height(10.0, Vector2.ZERO, 0.0) >= 5.0 and POLAR_ICE.snow_height(260.0, Vector2.ZERO, 0.0) == POLAR_ICE.PLATEAU_Y, "Ice cliffs rise from under the sea to a snow plateau")
	# The maps: white on the globe atlas, pieces on the minimap.
	var ice_block: Rect2 = Progression.ICE_SHELVES[0]
	for block: Rect2 in Progression.ICE_SHELVES:
		if minf(block.size.x, block.size.y) > minf(ice_block.size.x, ice_block.size.y): ice_block = block
	expect(page.get_pixelv(Vector2i(GLOBE_MAP.page_pixel(ice_block.get_center().x, ice_block.get_center().y))).is_equal_approx(Color("f7fbfd")), "The ice cap is white on the globe")
	var ice_rings: int = 0
	for entry: Array in GLOBE_MINIMAP.land_rings():
		if entry[1]: ice_rings += 1
	expect(ice_rings == Progression.polar_ice().outlines.size() and ice_rings >= 20, "The minimap draws the ice cap's pieces (%d)" % ice_rings)
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
	# Patch 2.9 item 6A: the shore is wherever the natural land starts east of
	# the strait's middle on that line.
	var shore: float = 3925.0
	while not solid(Vector2(shore, -500.0)) and shore < 4600.0: shore += 1.0
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
		# Patch 2.9 item 6A: the natural coast is on a 25 m grid, so the land
		# may start up to one sample (25 m) back from the channel's edge.
		var landed: bool = true
		var along: float = half + 35.0
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
				var landed_here: bool = solid(Vector2(point.x, point.z)) and not cut.has_point(Vector2(point.x, point.z))
				if not landed_here: print("WORLD LAND pier off land: %s at %s" % [entry.name, Vector2(point.x, point.z)])
				on_land = on_land and landed_here
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
