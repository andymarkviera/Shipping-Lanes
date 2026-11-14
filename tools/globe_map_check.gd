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
