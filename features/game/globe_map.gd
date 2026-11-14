extends CanvasLayer
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
const SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D map : filter_linear, repeat_enable;
varying vec3 spot;
void vertex() { spot = VERTEX; }
void fragment() {
	vec3 p = normalize(spot);
	vec2 uv = vec2(atan(p.x, p.z) / 6.2831853 + 0.5, 0.5 - asin(clamp(p.y, -1.0, 1.0)) / 3.1415927);
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
var ship_marker: MeshInstance3D
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

## The atlas page: sea, a soft grid, green land, white ice shelves. Built once.
static func atlas() -> ImageTexture:
	var page: Image = Image.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGB8)
	page.fill(Color("1aa0d8"))
	for line: int in 12:
		page.fill_rect(Rect2i(line * MAP_SIZE.x / 12, 0, 2, MAP_SIZE.y), Color("3fb4e2"))
	for line: int in range(1, 6):
		page.fill_rect(Rect2i(0, line * MAP_SIZE.y / 6, MAP_SIZE.x, 2), Color("3fb4e2"))
	# Patch 2.5 item 1B: land in two passes, so a continent made of blocks reads
	# as one shape: an ink coastline, then the fills, which cover the edges
	# inside the continent. One pixel of ink keeps the canal open.
	var ice_from: int = Progression.LAND.size()
	var boxes: Array = []
	for index: int in ice_from + Progression.ICE_SHELVES.size():
		var block: Rect2 = Progression.LAND[index] if index < ice_from else Progression.ICE_SHELVES[index - ice_from]
		var a: Vector2 = page_pixel(block.position.x, block.position.y)
		var b: Vector2 = page_pixel(block.end.x, block.end.y)
		boxes.append([Rect2i(Vector2i(a.min(b).floor()), Vector2i((a.max(b) - a.min(b)).ceil())), index >= ice_from])
	for box: Array in boxes: page.fill_rect(box[0].grow(1), Color("8fc3d6") if box[1] else Color("2f7a33"))
	for box: Array in boxes: page.fill_rect(box[0], Color("f7fbfd") if box[1] else PLAYFUL.LEAF)
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
			name_tag.outline_size = 14
			name_tag.outline_modulate = PLAYFUL.INK
			name_tag.pixel_size = 0.0012
			name_tag.position = dot.position * 1.04 + Vector3(0, 0.05, 0)
			spin.add_child(name_tag)
			port_markers.append(dot)
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.5
		cone.height = 1.4
		ship_marker = marker(cone, PLAYFUL.SUN, 0.05)
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
	var ship_at: Vector3 = view.ship.global_position
	var up: Vector3 = on_globe(ship_at)
	var at: Vector2 = lon_lat(ship_at)
	var east: Vector3 = Vector3(cos(at.x), 0, -sin(at.x))
	var north: Vector3 = up.cross(east).normalized()
	var bow: Vector3 = view.ship.global_basis.z
	var heading: Vector3 = (east * -bow.x + north * bow.z)
	heading = heading.normalized() if heading.length() > 0.0001 else north
	# The arrow grows with the hull, up to twice the starter's, like the minimap.
	var grow: float = clampf(sqrt(view.ship.definition.hull_size_m.z / 64.0), 1.0, 2.0)
	ship_marker.basis = Basis(heading.cross(up), heading, up) * (0.05 * grow)
	ship_marker.position = up * 1.03
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
