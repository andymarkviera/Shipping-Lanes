extends SceneTree
## Patch 2.4 item 7: the 3D globe map. In the real game scene: M opens it over a
## running world (no pause, helm keeps the keys, minimap stays), centred on the
## ship with north up; dragging turns it freely all the way round and over the
## poles; the wheel zooms within limits; M and Esc close it without opening the
## Esc menu; the hangar takes over from it. Isolated save folder.
## Run: godot --headless --path . --script res://tools/globe_map_check.gd

const FOLDER: String = "user://globe_map_check"
const GlobeMap = preload("res://features/game/globe_map.gd")
const Progression = preload("res://features/game/progression.gd")
const Airports = preload("res://features/planes/airports.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("GLOBE MAP FAILED: " + label)
	return condition

func settle() -> void:
	for frame: int in 3:
		await process_frame
		await physics_frame

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
	await settle()

func drag(map: CanvasLayer, by: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = by
	map.on_touch(motion)

func wheel(map: CanvasLayer, button: MouseButton) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = button
	click.pressed = true
	map.on_touch(click)

func run() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)
	# The mapping: every port on the globe, apart, the polar ones far north/south.
	var spots: Array[Vector3] = []
	for place: Dictionary in Progression.WORLD:
		var at: Vector2 = GlobeMap.lon_lat(place.at)
		expect(absf(GlobeMap.on_globe(place.at).length() - 1.0) < 0.001, place.id + " sits on the globe")
		for other: Vector3 in spots: expect(other.distance_to(GlobeMap.on_globe(place.at)) > 0.05, place.id + " stands apart")
		spots.append(GlobeMap.on_globe(place.at))
		if place.id == "port_north_pole": expect(at.y > deg_to_rad(50), "North pole port is far north")
		if place.id == "port_south_pole": expect(at.y < -deg_to_rad(50), "South pole port is far south")
	var probe: Vector3 = Vector3(1234, 0, -567)
	expect((GlobeMap.facing(probe) * GlobeMap.on_globe(probe)).distance_to(Vector3.BACK) < 0.001, "Facing turns a spot to the viewer")
	expect(GlobeMap.on_globe(probe).distance_to(GlobeMap.on_globe(probe + Vector3(Progression.WRAP_M, 0, 0))) < 0.001, "East-west wrap meets itself")
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
	await settle()
	var map: CanvasLayer = game.globe_map
	expect(map != null and not map.is_open(), "Globe map starts closed")
	await key(KEY_M)
	expect(map.is_open(), "M opens the globe map")
	expect(not paused, "The world is not paused")
	expect(game.minimap.is_visible_in_tree(), "The small minimap stays")
	expect(game.controls.input_allowed(), "The helm keeps the keyboard")
	var ship_up: Vector3 = map.spin.basis * GlobeMap.on_globe(game.ship.global_position)
	expect(ship_up.distance_to(Vector3.BACK) < 0.01, "Opens centred on the ship")
	expect((map.spin.basis * Vector3.UP).y > 0.5, "Opens north up")
	var size: Vector2 = map.frame.size
	var room: Vector2 = map.screen.get_viewport_rect().size
	expect(size.x > 0 and absf(size.x - size.y) < 1 and (map.frame.position + size / 2).distance_to(room / 2) < 2, "Globe is a square in the middle")
	# Patch 4.0 item D14: the land stands up in relief; ports and airports sit on it.
	expect(map.relief != null and map.relief.get_parent() == map.spin and map.relief.mesh == GlobeMap.relief_mesh(), "The land relief shell is on the globe, built once")
	var shell: Array = GlobeMap.relief_mesh().surface_get_arrays(0) if GlobeMap.relief_mesh().get_surface_count() > 0 else []
	if expect(not shell.is_empty(), "The relief shell has a surface"):
		var verts: PackedVector3Array = shell[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = shell[Mesh.ARRAY_NORMAL]
		var raised: int = 0
		var peak: float = 0.0
		var outward: bool = true
		for index: int in verts.size():
			var height: float = verts[index].length() - 1.0
			if height > 0.004: raised += 1
			peak = maxf(peak, height)
			outward = outward and normals[index].dot(verts[index]) > 0.5
		expect(verts.size() > 2000 and verts.size() < 40000, "The relief shell keeps a modest vertex count (%d)" % verts.size())
		expect(raised > verts.size() / 4 and peak > 0.012 and peak < 0.035, "The land is raised into hills and ridges (%d raised, peak %.4f)" % [raised, peak])
		expect(outward, "Relief normals face out of the globe")
	expect(GlobeMap.ground(Vector3(Progression.VOLCANO.at.x, 0, Progression.VOLCANO.at.y)) > 1.015, "Ember Isle stands up as a cone")
	expect(is_equal_approx(GlobeMap.ground(Progression.WRAP_CENTRE + Vector3(Progression.WRAP_M / 2, 0, 0)), 1.0), "The open sea is not raised")
	var lifted: bool = true
	for index: int in map.port_markers.size():
		var berth: Vector3 = game.world_ports[index].berth_anchor.global_position
		lifted = lifted and map.port_markers[index].position.length() >= GlobeMap.ground(berth) + GlobeMap.MARKER_LIFT * 0.9
	expect(map.port_markers.size() == game.world_ports.size() and lifted, "Every port is marked, above the land relief")
	expect(map.airport_markers.size() == Airports.count() and Airports.all().size() == Airports.count(), "Every airport is marked (%d of %d)" % [map.airport_markers.size(), Airports.count()])
	for index: int in map.airport_markers.size():
		var airport: Dictionary = Airports.all()[index]
		var pin: Node3D = map.airport_markers[index]
		var along: Vector3 = Vector3(sin(airport.heading), 0, cos(airport.heading)) * airport.length * 0.5
		var highest: float = maxf(GlobeMap.ground(airport.at), maxf(GlobeMap.ground(airport.at + along), GlobeMap.ground(airport.at - along)))
		expect(pin.position.normalized().distance_to(GlobeMap.on_globe(airport.at)) < 0.001 and pin.position.length() > highest + 0.004, airport.name + " is marked above the land relief")
		expect(pin.get_child_count() >= 3 and absf(pin.basis.y.normalized().dot(GlobeMap.on_globe(airport.at)) - 1.0) < 0.001, airport.name + " marker is a runway glyph standing upright")
	# Patch 2.5 item 1B: the dotted course follows the sea route round the land.
	var goal: Vector3 = game.world_ports[2].berth_anchor.global_position
	var route: Array[Vector3] = Progression.course(game.ship.global_position, goal, 2)
	map.draw_course({"position": goal, "route": route})
	expect(map.course_dots > route.size(), "The globe draws the course along the route (%d dots, %d legs)" % [map.course_dots, route.size()])
	map.draw_course({})
	expect(map.course_dots == 0, "No job, no course on the globe")
	# Patch 2.9.1 item 5: boats are toon 3D models drawn from a ship-entry list.
	var entries: Array[Dictionary] = map.ship_entries()
	expect(entries.size() == 1 and entries[0].kind == game.ship_kind and entries[0].position == game.ship.global_position, "The entry list is the player's own boat")
	expect(map.boats.size() == 1 and map.boats[0].visible and map.boats[0].get_child_count() >= 3, "The player's boat is a 3D model")
	var own: Node3D = map.boats[0]
	expect(own.position.normalized().distance_to(GlobeMap.on_globe(game.ship.global_position)) < 0.001 and own.position.length() > 1.0, "The model sits on the globe at the ship")
	expect(own.basis.is_conformal() and own.basis.determinant() > 0.0, "The model is not mirrored or skewed")
	# Heading: north, then east, then the real ship's own bow.
	var here: Vector3 = game.ship.global_position
	var up: Vector3 = GlobeMap.on_globe(here)
	var listed: Array[Dictionary] = [{"kind": "container", "position": here, "heading": 0.0}]
	map.show_ships(listed)
	var bow: Vector3 = own.basis.z.normalized()
	expect(bow.distance_to((GlobeMap.on_globe(here + Vector3(0, 0, 40)) - up).normalized()) < 0.05, "Heading 0 points the bow north")
	expect(absf(own.basis.y.normalized().dot(up) - 1.0) < 0.001, "The keel is down on the globe")
	listed[0].heading = -PI / 2
	map.show_ships(listed)
	expect(own.basis.z.normalized().distance_to((GlobeMap.on_globe(here + Vector3(-40, 0, 0)) - up).normalized()) < 0.05, "Heading -90 degrees points the bow east (-X)")
	# Each kind its own hull; the pool builds a model once and reuses it.
	var shapes: Dictionary = {}
	var kinds: Array[String] = ["container", "bulk", "heavy", "small_fishing", "small_speedboat", "small_brigantine", "small_galleon"]
	for kind: String in kinds:
		listed[0].kind = kind
		map.show_ships(listed)
		var parts: String = ""
		for part: MeshInstance3D in own.get_children(): parts += "%s%s%s;" % [part.mesh.get_class(), part.position, part.mesh.material.get_shader_parameter("colour")]
		shapes[parts] = true
		expect(own.get_meta("kind") == kind and map.boats.size() == 1, kind + " rebuilds the pooled model in place")
	expect(shapes.size() == kinds.size(), "Every kind has its own look (%d of %d)" % [shapes.size(), kinds.size()])
	expect(GlobeMap.boat_family("small_galleon") == "pirate" and GlobeMap.boat_family("bulk_3") == "bulk" and GlobeMap.boat_family("unknown_kind") == "container", "Kinds map to hull families, unknown ones to a container ship")
	var kept: Node = own.get_child(0)
	map.show_ships(listed)
	expect(own.get_child(0) == kept, "An unchanged kind is not rebuilt")
	expect(float(own.get_meta("length")) > GlobeMap.BOAT_LENGTH, "A galleon draws bigger than the starter")
	# Other ships (Patch 3.0 fills these): drawn the same way, culled round the back.
	var far: Vector3 = game.ship.global_position + Vector3(Progression.WRAP_M / 2, 0, 0)
	var others: Array[Dictionary] = [{"kind": "small_galleon", "position": game.ship.global_position + Vector3(600, 0, 600), "heading": 1.0}, {"kind": "bulk", "position": far, "heading": 2.0}]
	map.other_ships = others
	await settle()
	expect(map.boats.size() == 3 and map.boats[0].get_meta("kind") == game.ship_kind and map.boats[1].get_meta("kind") == "small_galleon" and map.boats[1].visible, "Other ships in the list are drawn as their own models")
	expect(not map.boats[2].visible and map.boats[2].get_child_count() == 0, "A boat round the back of the globe is hidden and not built")
	others.clear()
	await settle()
	expect(map.boats.size() == 3 and not map.boats[1].visible and not map.boats[2].visible and map.boats[0].visible, "Spare models are kept and hidden")
	expect(not ("ship_marker" in map), "The flat arrow marker is gone")
	# Over the poles: drag down half a turn, then on; the basis stays clean.
	var start: Basis = map.spin.basis
	var saw_pole: bool = false
	for step: int in 100:
		drag(map, Vector2(0, 10.5))
		var pole: Vector3 = map.spin.basis * Vector3.UP
		saw_pole = saw_pole or pole.z > 0.99
	expect(saw_pole, "Dragging rolls the globe over the north pole")
	expect(map.spin.basis.is_conformal() and absf(map.spin.basis.determinant() - 1.0) < 0.001, "Turned globe stays a clean rotation")
	map.spin.basis = start
	for step: int in 100: drag(map, Vector2(TAU / GlobeMap.DRAG_RADIANS_PER_PIXEL / 100.0, 0))
	expect((map.spin.basis * Vector3.BACK).distance_to(start * Vector3.BACK) < 0.01, "Dragging sideways goes all the way round")
	drag(map, Vector2(37, -81))
	expect(not map.spin.basis.is_equal_approx(start), "Diagonal drag turns it")
	for step: int in 30: wheel(map, MOUSE_BUTTON_WHEEL_UP)
	expect(is_equal_approx(map.zoom, GlobeMap.ZOOM_NEAR), "Wheel zooms in to a limit")
	for step: int in 30: wheel(map, MOUSE_BUTTON_WHEEL_DOWN)
	expect(is_equal_approx(map.zoom, GlobeMap.ZOOM_FAR), "Wheel zooms out to a limit")
	var clock_before: int = Engine.get_physics_frames()
	await settle()
	expect(Engine.get_physics_frames() > clock_before and map.is_open(), "Physics runs while the map is open")
	await key(KEY_ESCAPE)
	expect(not map.is_open(), "Esc closes the map")
	expect(not game.game_menu.is_open(), "Esc on the map does not open the menu")
	await key(KEY_M)
	expect(map.is_open(), "M opens it again")
	await key(KEY_M)
	expect(not map.is_open(), "M closes it")
	await key(KEY_M)
	game.hangar.open()
	await settle()
	expect(not map.is_open(), "The hangar takes over from the map")
	game.hangar.close()
	await settle()
	finish()

func finish() -> void:
	print("GLOBE MAP CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
