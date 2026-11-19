extends CanvasLayer
const DISPLAY = preload("res://features/ui/display_fonts.gd")
## Patch 2.4 item 7: M opens a big 3D globe of the whole world in the middle of
## the screen. Drag turns it freely (round and over the poles), the wheel zooms,
## M or Esc closes. The world keeps running; the helm keeps the keyboard and the
## small minimap stays. Read-only: it draws, it owns nothing.
## The world wraps east-west and north-south; the globe lays it out like an
## atlas page wrapped on a ball: the east-west edge meets itself, and the
## north and south edges are the poles.
const Navigation = preload("res://features/ports/local_navigation.gd")
const Progression = preload("res://features/game/progression.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const DRAG_RADIANS_PER_PIXEL: float = 0.006
const ZOOM_NEAR: float = 1.6
const ZOOM_FAR: float = 4.2
const ZOOM_STEP: float = 1.12
const MAP_SIZE: Vector2i = Vector2i(1024, 512)
## Patch 2.5 item 1B: the dotted course along the sea route, like the minimap.
const COURSE_DOT_SPACING: float = 0.012
const COURSE_DOT_SIZE: float = 0.007
## Patch 2.9.1 item 5: a starter-size hull is this long on the unit globe.
const BOAT_LENGTH: float = 0.1
const MAX_BOATS: int = 64
const BOAT_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 colour : source_color;
void fragment() {
	// The globe's own toon light: lit, then one shade band.
	float light = dot(NORMAL, normalize(vec3(-0.5, 0.6, 0.65)));
	ALBEDO = colour * (light > 0.05 ? 1.0 : 0.72);
}
"""
const SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D map : filter_linear, repeat_enable;
varying vec3 spot;
void vertex() { spot = VERTEX; }
void fragment() {
	vec3 p = normalize(spot);
	vec2 uv = vec2(atan(p.x, p.z + (abs(p.x) + abs(p.z) < 1e-6 ? 1e-6 : 0.0)) / 6.2831853 + 0.5, 0.5 - asin(clamp(p.y, -1.0, 1.0)) / 3.1415927);
	vec3 colour = texture(map, uv).rgb;
	// Toon light from the upper left, like the minimap: lit, then one shade band.
	float light = dot(NORMAL, normalize(vec3(-0.5, 0.6, 0.65)));
	colour *= light > 0.05 ? 1.0 : 0.72;
	ALBEDO = colour;
}
"""
var view: Node3D
var screen: Control
var frame: SubViewportContainer
var touch: Control
var camera: Camera3D
var spin: Node3D
## Patch 2.9.1 item 5: the boats on the globe are small toon 3D models drawn
## from a list of ship entries, each {kind, position, heading}: kind is the
## Progression ship kind, position a world position, heading radians from north
## (+Z) towards +X. Today the list is the player's own boat; Patch 3.0 adds the
## other players' boats to `other_ships` and they are drawn the same way.
var other_ships: Array[Dictionary] = []
## Pooled models, one per entry drawn; rebuilt only when an entry's kind changes.
var boats: Array[Node3D] = []
var boat_paints: Dictionary = {}
var boat_ink: StandardMaterial3D
var goal_marker: MeshInstance3D
var course_line: MeshInstance3D
var course_dots: int = 0
var port_markers: Array[MeshInstance3D] = []
var zoom: float = 3.2
var clock: float = 0.0

## (east, north) radians of a world position: longitude -PI..PI, latitude
## -PI/2..PI/2. Matches the minimap: east is -X, north is +Z.
static func lon_lat(world: Vector3) -> Vector2:
	var step: Vector3 = Progression.short_way(world - Progression.WRAP_CENTRE)
	return Vector2(-step.x / Progression.WRAP_M * TAU, clampf(step.z / Progression.WRAP_M * PI, -PI / 2, PI / 2))

## A world position on the unit globe.
static func on_globe(world: Vector3) -> Vector3:
	var at: Vector2 = lon_lat(world)
	return Vector3(cos(at.y) * sin(at.x), sin(at.y), cos(at.y) * cos(at.x))

## The globe turned so `world` faces the viewer with north up.
static func facing(world: Vector3) -> Basis:
	var at: Vector2 = lon_lat(world)
	return Basis(Vector3.RIGHT, at.y) * Basis(Vector3.UP, -at.x)

## Pixel of the atlas page for a world X/Z.
static func page_pixel(x: float, z: float) -> Vector2:
	var at: Vector2 = lon_lat(Vector3(x, 0, z))
	return Vector2((at.x / TAU + 0.5) * MAP_SIZE.x, (0.5 - at.y / PI) * MAP_SIZE.y)

## The atlas page: sea, a soft grid, green land, the white ice cap. Built once.
static func atlas() -> ImageTexture:
	var page: Image = Image.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGB8)
	page.fill(Color("1aa0d8"))
	for line: int in 12:
		page.fill_rect(Rect2i(line * MAP_SIZE.x / 12, 0, 2, MAP_SIZE.y), Color("3fb4e2"))
	for line: int in range(1, 6):
		page.fill_rect(Rect2i(0, line * MAP_SIZE.y / 6, MAP_SIZE.x, 2), Color("3fb4e2"))
	# Patch 2.9.1 item 6: the polar ice cap, pixel by pixel from its depth grid:
	# white ice, an ink line along its coast. Its rows lie at the page's top
	# and bottom, where the globe's poles are.
	var ice: Dictionary = Progression.polar_ice()
	if not ice.is_empty():
		var ice_count: Vector2i = ice.count
		var ice_depth: PackedFloat32Array = ice.depth
		for py: int in MAP_SIZE.y:
			var north: float = (py + 0.5) / MAP_SIZE.y * Progression.WRAP_M
			var row: int = floori((-north if north < Progression.WRAP_M / 2 else Progression.WRAP_M - north) / ice.cell) + ice.half
			if row < 0 or row >= ice_count.y: continue
			for px: int in MAP_SIZE.x:
				var d: float = ice_depth[row * ice_count.x + posmod(floori((1.0 - (px + 0.5) / MAP_SIZE.x) * Progression.WRAP_M / ice.cell), ice_count.x)]
				if d > 0.0: page.set_pixel(px, py, Color("8fc3d6") if d < 20.0 else Color("f7fbfd"))
	# Patch 2.9 item 6A: the natural land, pixel by pixel from the coast depth
	# grid (nearest sample): green inland, an ink line along the coast.
	var grid: Dictionary = Progression.natural_land()
	if grid.is_empty(): return ImageTexture.create_from_image(page)
	var count: Vector2i = grid.count
	var depth: PackedFloat32Array = grid.depth
	var cell: float = grid.cell
	var origin: Vector2 = grid.origin
	var corner_a: Vector2 = page_pixel(origin.x, origin.y)
	var corner_b: Vector2 = page_pixel(origin.x + count.x * cell, origin.y + count.y * cell)
	var from: Vector2i = Vector2i(corner_a.min(corner_b).floor()).clamp(Vector2i.ZERO, MAP_SIZE - Vector2i.ONE)
	var to: Vector2i = Vector2i(corner_a.max(corner_b).ceil()).clamp(Vector2i.ZERO, MAP_SIZE - Vector2i.ONE)
	var ink: Color = Color("2f7a33")
	for py: int in range(from.y, to.y + 1):
		var z: float = Progression.WRAP_CENTRE.z + (0.5 - (py + 0.5) / MAP_SIZE.y) * Progression.WRAP_M
		var j: int = roundi((z - origin.y) / cell)
		if j < 0 or j >= count.y: continue
		for px: int in range(from.x, to.x + 1):
			var x: float = Progression.WRAP_CENTRE.x + (0.5 - (px + 0.5) / MAP_SIZE.x) * Progression.WRAP_M
			var i: int = roundi((x - origin.x) / cell)
			if i < 0 or i >= count.x: continue
			var d: float = depth[j * count.x + i]
			if d > 0.0: page.set_pixel(px, py, ink if d < 20.0 else PLAYFUL.LEAF)
	return ImageTexture.create_from_image(page)

static func flat(colour: Color) -> StandardMaterial3D:
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = colour
	return paint

func _ready() -> void:
	layer = 8
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(PLAYFUL.INK, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dim)
	frame = SubViewportContainer.new()
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(frame)
	var port_view: SubViewport = SubViewport.new()
	port_view.own_world_3d = true
	port_view.transparent_bg = true
	port_view.msaa_3d = Viewport.MSAA_4X
	frame.add_child(port_view)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.position = Vector3(0, 0, zoom)
	port_view.add_child(camera)
	spin = Node3D.new()
	port_view.add_child(spin)
	var ball: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radial_segments = 96
	sphere.rings = 48
	ball.mesh = sphere
	sphere.radius = 1.0
	sphere.height = 2.0
	var shader: Shader = Shader.new()
	shader.code = SHADER
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("map", atlas())
	ball.material_override = paint
	spin.add_child(ball)
	# Ink outline: a slightly bigger ball seen from inside.
	var rim: MeshInstance3D = MeshInstance3D.new()
	var rim_mesh: SphereMesh = SphereMesh.new()
	rim_mesh.radius = 1.025
	rim_mesh.height = 2.05
	rim.mesh = rim_mesh
	var ink: StandardMaterial3D = flat(PLAYFUL.INK)
	ink.cull_mode = BaseMaterial3D.CULL_FRONT
	rim.material_override = ink
	port_view.add_child(rim)
	for berg: Vector3 in Progression.ICEBERGS:
		var dot: MeshInstance3D = marker(SphereMesh.new(), Color.WHITE, 0.012 + berg.y / 6000.0)
		dot.position = on_globe(Vector3(berg.x, 0, berg.z)) * 1.004
	touch = Control.new()
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(on_touch)
	screen.add_child(touch)
	var hint: Label = Label.new()
	DISPLAY.apply(hint)
	hint.text = "WORLD MAP"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", PLAYFUL.CREAM)
	hint.add_theme_color_override("font_outline_color", PLAYFUL.INK)
	hint.add_theme_constant_override("outline_size", 8)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.offset_top = 24
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(hint)
	screen.hide()

## A small toon marker stuck to the globe.
func marker(mesh: Mesh, colour: Color, size: float) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = flat(colour)
	node.scale = Vector3.ONE * size
	spin.add_child(node)
	return node

func is_open() -> bool:
	return screen.visible

func toggle() -> void:
	if is_open(): close()
	else: open()

## Opens on the ship, north up.
func open() -> void:
	if is_open() or not is_instance_valid(view) or not is_instance_valid(view.ship): return
	if port_markers.is_empty():
		for port: Node3D in view.world_ports:
			var dot: MeshInstance3D = marker(SphereMesh.new(), Color.WHITE, 0.035)
			dot.position = on_globe(port.berth_anchor.global_position) * 1.01
			var name_tag: Label3D = Label3D.new()
			name_tag.text = port.definition.display_name
			name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			name_tag.font_size = 48
			name_tag.font = DISPLAY.font()
			name_tag.modulate = Color.WHITE
			name_tag.outline_size = 0
			name_tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			name_tag.outline_modulate = PLAYFUL.INK
			name_tag.pixel_size = 0.0012
			name_tag.position = dot.position * 1.04 + Vector3(0, 0.05, 0)
			spin.add_child(name_tag)
			port_markers.append(dot)
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.8
		ring.outer_radius = 1.0
		goal_marker = marker(ring, PLAYFUL.SUN, 0.06)
		course_line = marker(ImmediateMesh.new(), PLAYFUL.SUN, 1.0)
		course_line.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	spin.basis = facing(view.ship.global_position)
	zoom = 3.2
	place()
	screen.show()

func close() -> void:
	screen.hide()

func on_touch(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		turn(event.relative)
		touch.accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(ZOOM_NEAR, zoom / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(ZOOM_FAR, zoom * ZOOM_STEP)
		touch.accept_event()
	elif event is InputEventPanGesture:
		# Mac trackpad two-finger scroll: up/down zooms like the wheel, sideways spins.
		if absf(event.delta.y) >= absf(event.delta.x): zoom = clampf(zoom * pow(ZOOM_STEP, event.delta.y * 0.35), ZOOM_NEAR, ZOOM_FAR)
		else: turn(Vector2(event.delta.x * -40.0, 0.0))
		touch.accept_event()
	elif event is InputEventMagnifyGesture and event.factor > 0.0:
		zoom = clampf(zoom / event.factor, ZOOM_NEAR, ZOOM_FAR)
		touch.accept_event()

## Turns the globe about the screen's own axes, so it rolls freely every way,
## over the poles too: the surface follows the mouse.
func turn(by: Vector2) -> void:
	spin.basis = (Basis(Vector3.UP, by.x * DRAG_RADIANS_PER_PIXEL) * Basis(Vector3.RIGHT, by.y * DRAG_RADIANS_PER_PIXEL) * spin.basis).orthonormalized()

## M and Esc close it before the helm or the Esc menu see them.
func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed or event.echo: return
	var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if code == KEY_ESCAPE or event.is_action("ui_cancel") or (InputMap.has_action("map_toggle") and event.is_action("map_toggle")):
		close()
		get_viewport().set_input_as_handled()

## The globe sits in the middle, a square most of the screen high.
func place() -> void:
	var room: Vector2 = screen.get_viewport_rect().size
	var side: float = minf(room.x, room.y) * 0.82
	var box: Rect2 = Rect2((room - Vector2(side, side)) / 2, Vector2(side, side))
	frame.position = box.position
	frame.size = box.size
	touch.position = box.position
	touch.size = box.size
	camera.position.z = lerpf(camera.position.z, zoom, 0.25)

func _process(delta: float) -> void:
	if not is_open(): return
	# Another screen took over (hangar, Esc menu) or the ship went away.
	if not is_instance_valid(view) or not is_instance_valid(view.ship) \
			or (view.get("hangar") != null and view.hangar.is_open()) \
			or (view.get("game_menu") != null and view.game_menu.is_open()):
		close()
		return
	clock += delta
	place()
	show_ships(ship_entries())
	for index: int in port_markers.size():
		port_markers[index].material_override.albedo_color = PLAYFUL.SUN if view.world_ports[index] == view.port else Color.WHITE
	var destination: Dictionary = Navigation.target(view)
	goal_marker.visible = not destination.is_empty()
	if goal_marker.visible:
		var goal_up: Vector3 = on_globe(destination.position)
		var side: Vector3 = goal_up.cross(Vector3.FORWARD if absf(goal_up.y) > 0.9 else Vector3.UP).normalized()
		goal_marker.basis = Basis(side, goal_up, side.cross(goal_up)) * (0.06 + 0.012 * sin(clock * 4.0))
		goal_marker.position = goal_up * 1.012
	draw_course(destination)

## The dotted course on the globe: from the ship along the sea route to the
## destination, each leg the short way round the world.
func draw_course(destination: Dictionary) -> void:
	var line: ImmediateMesh = course_line.mesh as ImmediateMesh
	line.clear_surfaces()
	course_dots = 0
	if destination.is_empty(): return
	var corners: Array = destination.get("route", [])
	if corners.is_empty(): corners = [destination.position]
	line.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var from: Vector3 = view.ship.global_position
	for corner: Vector3 in corners:
		var step: Vector3 = Progression.short_way(corner - from)
		var across: float = on_globe(from).distance_to(on_globe(from + step))
		var dots: int = clampi(roundi(across / COURSE_DOT_SPACING), 1, 200)
		for index: int in range(1, dots + 1):
			var up: Vector3 = on_globe(from + step * (index / float(dots)))
			var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.y) > 0.9 else Vector3.UP).normalized() * COURSE_DOT_SIZE
			var other: Vector3 = up.cross(side)
			var middle: Vector3 = up * 1.006
			for point: Vector3 in [middle + side, middle + other, middle - side, middle + side, middle - side, middle - other]:
				line.surface_add_vertex(point)
			course_dots += 1
		from += step
	line.surface_end()

## Patch 2.9.1 item 5: every boat the map shows, the player's own first.
func ship_entries() -> Array[Dictionary]:
	var bow: Vector3 = view.ship.global_basis.z
	var entries: Array[Dictionary] = [{"kind": str(view.get("ship_kind")), "position": view.ship.global_position, "heading": atan2(bow.x, bow.z)}]
	entries.append_array(other_ships)
	entries.append_array(view.other_ships)
	return entries

## "pirate", "small", "bulk", "heavy" or "container" (also any unknown kind).
static func boat_family(kind: String) -> String:
	if Progression.PIRATE_KINDS.has(kind): return "pirate"
	var family: String = kind.get_slice("_", 0)
	return family if family in ["small", "bulk", "heavy"] else "container"

## Hull size in metres of a kind; the starter's for a kind this build lacks.
static func boat_size(kind: String) -> Vector3:
	return Progression.definition(kind).hull_size_m

func boat_part(model: Node3D, mesh: PrimitiveMesh, colour: Color, at: Vector3) -> MeshInstance3D:
	if not boat_paints.has(colour):
		if boat_ink == null:
			# One shared ink outline: the same shape, a little fatter, seen from inside.
			boat_ink = flat(PLAYFUL.INK)
			boat_ink.cull_mode = BaseMaterial3D.CULL_FRONT
			boat_ink.grow = true
			boat_ink.grow_amount = 0.022
		var shader: Shader = boat_paints.get("shader")
		if shader == null:
			shader = Shader.new()
			shader.code = BOAT_SHADER
			boat_paints["shader"] = shader
		var paint: ShaderMaterial = ShaderMaterial.new()
		paint.shader = shader
		paint.set_shader_parameter("colour", colour)
		paint.next_pass = boat_ink
		boat_paints[colour] = paint
	var part: MeshInstance3D = MeshInstance3D.new()
	mesh.material = boat_paints[colour]
	part.mesh = mesh
	part.position = at
	model.add_child(part)
	return part

static func box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh

static func pole(radius: float, height: float) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh

## A small toon model of a kind's hull, built into `model`: one unit long, bow
## along +Z, keel at Y 0. A few boxes each, so a full list stays cheap.
func build_boat(model: Node3D, kind: String) -> void:
	for old: Node in model.get_children():
		model.remove_child(old)
		old.free()
	var size: Vector3 = boat_size(kind)
	var family: String = boat_family(kind)
	var beam: float = clampf(size.x / size.z * 1.5, 0.2, 0.36)
	var brig: bool = kind == "small_brigantine"
	var hull: Color = {"pirate": Color("2c2a33") if brig else Color("7a4a25"), "small": Color.WHITE, "bulk": PLAYFUL.RUST, "heavy": PLAYFUL.SUN_DARK, "container": PLAYFUL.NAVY}[family]
	boat_part(model, box(Vector3(beam, 0.12, 0.72)), hull, Vector3(0, 0.06, -0.14))
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(beam, 0.28, 0.12)
	boat_part(model, prism, hull, Vector3(0, 0.06, 0.36)).basis = Basis(Vector3.RIGHT, PI / 2)
	match family:
		"pirate":
			boat_part(model, box(Vector3(beam, 0.1, 0.2)), hull, Vector3(0, 0.17, -0.4))
			var masts: Array = [-0.1, 0.2] if brig else [-0.24, 0.0, 0.24]
			for index: int in masts.size():
				var tall: float = 0.42 if brig else [0.4, 0.52, 0.42][index]
				boat_part(model, pole(0.014, tall), Color("4a2f1a"), Vector3(0, 0.12 + tall / 2, masts[index]))
				boat_part(model, box(Vector3(beam * 1.5, tall * 0.6, 0.02)), Color("c8372d") if brig else PLAYFUL.CREAM, Vector3(0, 0.14 + tall * 0.55, masts[index] + 0.02))
			boat_part(model, box(Vector3(0.012, 0.06, 0.1)), PLAYFUL.INK, Vector3(0, 0.71 if not brig else 0.6, masts[masts.size() - 2] - 0.06))
		"small":
			boat_part(model, box(Vector3(beam * 0.7, 0.1, 0.26)), PLAYFUL.SUN if kind != "small_fishing" else PLAYFUL.NAVY, Vector3(0, 0.17, -0.12 if kind != "small_fishing" else 0.05))
		"bulk":
			for hatch: int in 4: boat_part(model, box(Vector3(beam * 0.7, 0.035, 0.11)), Color("e9d8a6"), Vector3(0, 0.135, -0.2 + hatch * 0.14))
			boat_part(model, box(Vector3(beam * 0.85, 0.16, 0.1)), Color.WHITE, Vector3(0, 0.2, -0.4))
		"heavy":
			boat_part(model, box(Vector3(beam * 0.85, 0.16, 0.1)), Color.WHITE, Vector3(0, 0.2, 0.14))
			boat_part(model, box(Vector3(beam * 0.8, 0.02, 0.5)), PLAYFUL.DEEP, Vector3(0, 0.13, -0.2))
			boat_part(model, pole(0.02, 0.26), PLAYFUL.SUN, Vector3(beam * 0.35, 0.25, -0.05))
			boat_part(model, box(Vector3(0.025, 0.025, 0.3)), PLAYFUL.SUN, Vector3(beam * 0.35, 0.38, -0.18))
		_:
			var stacks: Array[Color] = [PLAYFUL.RUST, PLAYFUL.SUN, PLAYFUL.LEAF, PLAYFUL.CREAM]
			for stack: int in 4: boat_part(model, box(Vector3(beam * 0.85, 0.07 + 0.03 * (stack % 2), 0.12)), stacks[stack], Vector3(0, 0.155 + 0.015 * (stack % 2), -0.24 + stack * 0.135))
			boat_part(model, box(Vector3(beam * 0.85, 0.2, 0.08)), Color.WHITE, Vector3(0, 0.22, -0.42))
	model.set_meta("kind", kind)
	# Bigger hulls draw bigger, between 0.6 and 2 times the starter's.
	model.set_meta("length", BOAT_LENGTH * clampf(sqrt(size.z / 64.0), 0.6, 2.0))

## Draws the entries: each a model of its own kind, sitting on the globe at its
## position with the bow along its heading. Models are pooled; spares and boats
## round the back of the globe are hidden.
func show_ships(entries: Array[Dictionary]) -> void:
	var shown: int = mini(entries.size(), MAX_BOATS)
	for index: int in shown:
		var entry: Dictionary = entries[index]
		if index == boats.size():
			var fresh: Node3D = Node3D.new()
			spin.add_child(fresh)
			boats.append(fresh)
		var model: Node3D = boats[index]
		var world: Vector3 = entry.position
		var up: Vector3 = on_globe(world)
		model.visible = (spin.basis * up).z > -0.15
		if not model.visible: continue
		if model.get_meta("kind", "") != entry.kind: build_boat(model, entry.kind)
		var at: Vector2 = lon_lat(world)
		var east: Vector3 = Vector3(cos(at.x), 0, -sin(at.x))
		var north: Vector3 = up.cross(east).normalized()
		# World east is -X and north is +Z; a boat on the pole itself still gets a bow.
		var bow: Vector3 = east * -sin(entry.heading) + north * cos(entry.heading)
		bow = bow.normalized() if bow.length() > 0.0001 else north
		model.basis = Basis(up.cross(bow), up, bow) * float(model.get_meta("length"))
		model.position = up * 1.012
	for index: int in range(shown, boats.size()): boats[index].visible = false
