class_name TitleScreen
extends CanvasLayer
## Patch 2.7 item 1: the attract screen. The live toon ocean seen from straight
## above, the Shipping Lanes logo centre-top and a pulsing "Press Any Button".
## Layout fractions come from docs/reference/main_menu/title_press_any_button.png
## (1672 x 941), so the screen matches Andy's mockup at any 16:9 size.
## Patch 2.7 item 2: any key, mouse click or gamepad button fades "Press Any
## Button", slides and shrinks the logo to the top-left, and a container ship
## from the fleet ladder sails in from the left with a big toon wake, then
## cruises in place (layout from docs/reference/main_menu/menu_ship_arrives.png).
## Pressing again skips. Once arrived the screen stays as the menu's backdrop,
## on a layer below the menu.
## Patch 2.7 item 4: Start sends the camera down after the ship to sea level and
## fades into the game (`depart`); coming back to the main menu replays the
## arrival without "Press Any Button" (`replay`). The 3D views render at the
## window's full pixel size, so the ship stays crisp on Retina screens.

## The ship has arrived (or the arrival was skipped): the menu can show.
signal dismissed
## Start's camera dive is over and the screen is covered: change scene now.
signal departed
const LOGO: Texture2D = preload("res://features/title/title_logo.png")
const PRESS: Texture2D = preload("res://features/title/press_any_button.png")
## The mockup's light-blue wave streaks and curled swirl foam, sea removed.
const STREAKS: Texture2D = preload("res://features/title/sea_streaks.png")
const OCEAN_PALETTE: WaterPalette = preload("res://features/title/title_ocean.tres")
const WAKE_SHADER: Shader = preload("res://features/title/menu_wake.gdshader")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const CONTAINER_VISUALS = preload("res://features/cargo/container_visuals.gd")
const PROGRESSION = preload("res://features/game/progression.gd")
const MOCKUP: Vector2 = Vector2(1672, 941)
## Visible sea height in metres for the live ocean's own (faint) swirl lines.
const SEA_VIEW_METRES: float = 260.0
## Streak drift in mockup pixels per second: a slow push up and to the left.
const STREAK_DRIFT: Vector2 = Vector2(-14.0, -4.0)
const FADE_SECONDS: float = 0.35
## The logo on the attract screen and in its menu corner (mockup pixels).
const LOGO_CENTRE_RECT: Rect2 = Rect2(236, 84, 1228, 540)
const LOGO_CORNER_RECT: Rect2 = Rect2(52, 44, 840, 369)
## The ship in menu_ship_arrives.png: 0.80 screen heights long, its centre 0.40
## right of and 0.07 below the screen centre (in screen heights).
const SHIP_SCREEN_LENGTH: float = 0.80
const SHIP_CENTRE: Vector2 = Vector2(0.40, 0.07)
const LOGO_SECONDS: float = 1.2
const SHIP_START: float = 0.15
const ARRIVAL_SECONDS: float = 2.6
## The water slides left under the cruising ship (screen heights per second).
const CRUISE_SPEED: float = 0.075
## Container ladder tiers long enough to carry the mockup's full deck of boxes.
const MENU_SHIPS: Array[String] = ["container_3", "container_4", "container_5"]
## Bright box colours like the mockup's deck load.
## Start: the camera follows the ship down from straight above to a low side
## view (degrees above the sea) while closing in, then fades into the game.
const DEPART_SECONDS: float = 1.9
const DEPART_PITCH: float = 34.0
const DEPART_ZOOM: float = 1.9
const DEPART_FADE: float = 0.5
const BOX_COLOURS: PackedColorArray = [Color("d7263d"), Color("2a6fdb"), Color("f28c28"), Color("f6c445"), Color("2ec4d6"), Color("b5233a"), Color("3b4cc0")]

var clock: float = 0.0
## Seconds since the press; -1 while waiting on the attract screen.
var arriving: float = -1.0
var arrived: bool = false
var water_shift: float = 0.0
## Seconds since Start; -1 until then.
var departing: float = -1.0
var fade: ScreenFade
var ship_view_size: float = 1.0
var ship_rest: Vector2 = Vector2.ZERO
var viewport: SubViewport
var ocean: OceanPresentation
var sea_camera: Camera3D
var root: Control
var sea: SeaStreaks
var press: TextureRect
var logo: Control
var wake: ColorRect
var wake_material: ShaderMaterial
var ship_view: SubViewport
var ship_camera: Camera3D
var ship: Node3D
var ship_kind: String = ""
var ship_width_m: float = 25.0

## Draws the streak layer tiled, so it can drift forever and fill ultrawide.
class SeaStreaks extends Control:
	var offset: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var tile: Vector2 = Vector2(STREAKS.get_size()) * size.y / MOCKUP.y
		var shift: Vector2 = Vector2(fposmod(offset.x * tile.x / MOCKUP.x, tile.x), fposmod(offset.y * tile.y / MOCKUP.y, tile.y))
		# Centred like the mockup when the screen is wider than 16:9.
		var start: Vector2 = Vector2(fposmod((size.x - tile.x) * 0.5 + shift.x, tile.x) - tile.x, shift.y - tile.y)
		var y: float = start.y
		while y < size.y:
			var x: float = start.x
			while x < size.x:
				draw_texture_rect(STREAKS, Rect2(Vector2(x, y), tile), false)
				x += tile.x
			y += tile.y

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	# The sea: the game's own ocean in its own small world, camera straight down.
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 0
	# The sea has no fine detail: like the game's 3D view on a Mac (Patch 2.6
	# item 4) it renders at up to 1.5x the logical size, keeping the GPU cool.
	view_rect(viewport, 1.5)
	ocean = OceanPresentation.new()
	ocean.palette = OCEAN_PALETTE
	ocean.quality = 1
	viewport.add_child(ocean)
	sea_camera = top_down_camera(SEA_VIEW_METRES)
	viewport.add_child(sea_camera)
	sea_camera.current = true
	sea = SeaStreaks.new()
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sea.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sea)
	build_wake()
	build_ship()
	# Andy (Nov 16, 2026): keep the original painted Shipping Lanes logo, not sheet lettering.
	logo = art(LOGO)
	press = art(PRESS)
	place(press, Rect2(352, 700, 960, 98))
	press.pivot_offset = press.size * 0.5
	press.resized.connect(func() -> void: press.pivot_offset = press.size * 0.5)
	root.resized.connect(func() -> void: refresh_layout())
	refresh_layout.call_deferred()

## A full-screen picture of a 3D view. Unlike a stretching SubViewportContainer
## it renders at the window's real pixel size, so a 2x Retina screen (content
## scale 2) gets a sharp ship and sea instead of a half-size image scaled up.
func view_rect(view: SubViewport, max_scale: float) -> void:
	var picture: TextureRect = TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(picture)
	picture.add_child(view)
	picture.texture = view.get_texture()
	picture.resized.connect(fit_view.bind(picture, view, max_scale))
	fit_view(picture, view, max_scale)

func fit_view(picture: TextureRect, view: SubViewport, max_scale: float) -> void:
	var scale_factor: float = clampf(get_window().content_scale_factor, 1.0, max_scale)
	view.size = Vector2i((picture.size * scale_factor).round()).max(Vector2i.ONE)

## Straight down: screen up is -Z, screen right is +X.
func top_down_camera(height_m: float) -> Camera3D:
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = height_m
	camera.far = 400.0
	camera.position = Vector3(0, 200, 0)
	camera.rotation = Vector3(-PI / 2.0, 0, 0)
	return camera

func build_wake() -> void:
	wake = ColorRect.new()
	wake.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wake.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wake_material = ShaderMaterial.new()
	wake_material.shader = WAKE_SHADER
	wake.material = wake_material
	wake.visible = false
	root.add_child(wake)

## A container ship from the fleet ladder (random tier 3-5 each launch): the same
## chunky toon model the hangar shows, every slot loaded. Built up front so the
## press does not hitch; its viewport only draws once the arrival starts.
func build_ship() -> void:
	ship_view = SubViewport.new()
	ship_view.own_world_3d = true
	ship_view.transparent_bg = true
	ship_view.msaa_3d = Viewport.MSAA_2X
	ship_view.positional_shadow_atlas_size = 0
	ship_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view_rect(ship_view, 4.0)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1d6")
	environment.ambient_light_energy = 0.6
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	ship_view.add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 150, 0)
	sun.light_energy = 0.85
	ship_view.add_child(sun)
	ship_kind = MENU_SHIPS[randi() % MENU_SHIPS.size()]
	var definition: ShipDefinition = PROGRESSION.definition(ship_kind)
	ship_width_m = definition.hull_size_m.x
	ship_view_size = definition.hull_size_m.z / SHIP_SCREEN_LENGTH
	ship_camera = top_down_camera(ship_view_size)
	ship_view.add_child(ship_camera)
	ship_camera.current = true
	ship = Node3D.new()
	ship.name = "MenuShip"
	var model: Node3D = CHUNKY_LOOK.model(ship_kind, definition)
	TOON_LOOK.apply(model)
	model.add_child(boxes(definition))
	# Bow (+Z) pointing right (+X).
	model.rotation.y = PI / 2.0
	ship.add_child(model)
	ship_view.add_child(ship)
	ship.visible = false

## Every container slot filled, in the mockup's bright colours.
func boxes(definition: ShipDefinition) -> Node3D:
	var holder: Node3D = Node3D.new()
	var layout: ContainerLayout = definition.container_layout
	if layout == null or layout.centres.is_empty(): return holder
	var count: int = mini(int(definition.cargo_capacities.get("container_slots", layout.centres.size())), layout.centres.size())
	var instances: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instances.multimesh = MultiMesh.new()
	instances.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instances.multimesh.use_colors = true
	instances.multimesh.mesh = CONTAINER_VISUALS.container_mesh(layout.container_size_m)
	instances.multimesh.instance_count = count
	for slot: int in count:
		var centre: Vector3 = layout.centres[slot]
		instances.multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, centre))
		var mix: int = int(round(centre.z / maxf(layout.container_size_m.z, 1.0))) * 3 + int(round(centre.x)) * 7 + int(round(centre.y))
		instances.multimesh.set_instance_color(slot, BOX_COLOURS[posmod(mix, BOX_COLOURS.size())])
	holder.add_child(instances)
	return holder

func art(texture: Texture2D) -> TextureRect:
	var item: TextureRect = TextureRect.new()
	item.texture = texture
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(item)
	return item

## Anchors a piece at its place in the mockup; keep-aspect stops stretching on
## 16:10 or ultrawide screens.
func place(item: Control, mockup_rect: Rect2) -> void:
	item.anchor_left = mockup_rect.position.x / MOCKUP.x
	item.anchor_top = mockup_rect.position.y / MOCKUP.y
	item.anchor_right = mockup_rect.end.x / MOCKUP.x
	item.anchor_bottom = mockup_rect.end.y / MOCKUP.y
	item.offset_left = 0
	item.offset_top = 0
	item.offset_right = 0
	item.offset_bottom = 0

func refresh_layout() -> void:
	if arriving < 0.0: place_logo(0.0)
	else: update_arrival()

## The logo between its attract spot (0) and the menu corner (1), in pixels so
## it keeps the mockup's corner on 16:10 and ultrawide screens too.
func place_logo(t: float) -> void:
	var view: Vector2 = root.size
	if view.y <= 0.0: return
	var unit: float = view.y / MOCKUP.y
	var start_size: Vector2 = LOGO_CENTRE_RECT.size * unit
	var start: Vector2 = Vector2((view.x - start_size.x) * 0.5, LOGO_CENTRE_RECT.position.y * unit)
	logo.position = start.lerp(LOGO_CORNER_RECT.position * unit, t)
	logo.size = start_size.lerp(LOGO_CORNER_RECT.size * unit, t)

func _process(delta: float) -> void:
	clock += delta
	var cruise: float = 0.0
	if arriving >= 0.0:
		if not arrived:
			arriving = minf(arriving + delta, ARRIVAL_SECONDS)
			update_arrival()
			if arriving >= ARRIVAL_SECONDS: settle()
		cruise = smoothstep(SHIP_START, ARRIVAL_SECONDS, arriving)
	# The water slides left under the cruising ship: streaks, wake and ocean.
	var slide: float = CRUISE_SPEED * cruise * delta
	water_shift += slide
	sea.offset += STREAK_DRIFT * delta - Vector2(slide * MOCKUP.y, 0.0)
	sea.queue_redraw()
	sea_camera.position.x = water_shift * SEA_VIEW_METRES
	if departing >= 0.0: update_departure(delta)
	# The ocean mesh follows in big steps; its waves are drawn in world space.
	ocean.position.x = snappedf(sea_camera.position.x, 500.0)
	if arriving < 0.0:
		# Gentle pulse on "Press Any Button".
		var pulse: float = 0.5 + 0.5 * sin(clock * TAU / 1.6)
		press.modulate.a = lerpf(0.6, 1.0, pulse)
		# Pulse from the centre: keep the pivot on the middle of the line.
		press.pivot_offset = press.size * 0.5
		press.scale = Vector2.ONE * lerpf(1.0, 1.04, pulse)
	if ship.visible:
		wake_material.set_shader_parameter("water_shift", water_shift)
		# Cruising in place: a slow roll and a little heave.
		ship.rotation.x = sin(clock * 0.9) * 0.02
		ship.position.y = sin(clock * 1.3) * 0.25

func update_arrival() -> void:
	press.modulate.a = 1.0 - clampf(arriving / FADE_SECONDS, 0.0, 1.0)
	place_logo(smoothstep(0.0, LOGO_SECONDS, arriving))
	var aspect: float = root.size.x / maxf(root.size.y, 1.0)
	# Centre-right like the mockup, pulled in a little on narrower screens.
	var rest: Vector2 = Vector2(minf(SHIP_CENTRE.x, aspect * 0.5 - SHIP_SCREEN_LENGTH * 0.5 - 0.06), SHIP_CENTRE.y)
	var from_x: float = -aspect * 0.5 - SHIP_SCREEN_LENGTH * 0.5 - 0.05
	var t: float = clampf((arriving - SHIP_START) / (ARRIVAL_SECONDS - SHIP_START), 0.0, 1.0)
	var at: Vector2 = Vector2(lerpf(from_x, rest.x, 1.0 - pow(1.0 - t, 3.0)), rest.y)
	ship_rest = at
	ship.position.x = at.x * ship_camera.size
	ship.position.z = at.y * ship_camera.size
	wake_material.set_shader_parameter("aspect", aspect)
	wake_material.set_shader_parameter("bow", at + Vector2(SHIP_SCREEN_LENGTH * 0.5, 0.0))
	wake_material.set_shader_parameter("half_width", ship_width_m * 0.5 / ship_camera.size)
	wake_material.set_shader_parameter("reveal", clampf((arriving - SHIP_START) / 0.4, 0.0, 1.0))

## Arrived: the screen stays as the menu's backdrop, under the menu layer.
func settle() -> void:
	arrived = true
	press.visible = false
	layer = -1
	dismissed.emit()

func _input(event: InputEvent) -> void:
	if departing >= 0.0:
		# Nothing else reacts during the dive; Cmd/Ctrl/Alt shortcuts still work.
		var held: InputEventKey = event as InputEventKey
		if held != null and (held.meta_pressed or held.ctrl_pressed or held.alt_pressed): return
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	if arrived or not visible: return
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if not key.pressed or key.echo: return
		# Cmd/Ctrl/Alt shortcuts (Cmd+Q, Alt+F4) and F3 (debug mode) keep working.
		if key.meta_pressed or key.ctrl_pressed or key.alt_pressed: return
		if key.keycode == KEY_F3 or key.physical_keycode == KEY_F3:
			dismiss()
			return
	elif not ((event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)):
		return
	get_viewport().set_input_as_handled()
	dismiss()

## The first press starts the arrival; a second press skips to its end.
func dismiss() -> void:
	if arrived: return
	if arriving >= 0.0:
		arriving = ARRIVAL_SECONDS
		update_arrival()
		settle()
		return
	arriving = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wake.visible = true
	ship.visible = true
	ship_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	update_arrival()

## The menu hides the backdrop on its other pages; nothing draws while hidden.
func set_backdrop_visible(on: bool) -> void:
	visible = on
	set_process(on)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if arriving >= 0.0: ship_view.render_target_update_mode = viewport.render_target_update_mode

## Back from a game: the ship sails in again, straight to the menu (no "Press
## Any Button"). Pressing still skips.
func replay() -> void:
	press.visible = false
	dismiss()

## Start: the logo fades, the camera follows the ship down to sea level, then the
## screen fades to the sea's blue and `departed` fires. Pressing does nothing.
func depart() -> void:
	if departing >= 0.0: return
	if not arrived:
		arriving = ARRIVAL_SECONDS
		update_arrival()
		settle()
	departing = 0.0
	layer = 10
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	sea_camera.far = 2000.0
	ship_camera.far = 1000.0

func update_departure(delta: float) -> void:
	# A slow frame must not skip the dive.
	departing += minf(delta, 1.0 / 30.0)
	var e: float = smoothstep(0.0, DEPART_SECONDS, departing)
	logo.modulate.a = 1.0 - clampf(departing / 0.45, 0.0, 1.0)
	var pitch: float = deg_to_rad(lerpf(90.0, DEPART_PITCH, e))
	var zoom: float = lerpf(1.0, DEPART_ZOOM, e)
	# The point the camera looks at moves from the screen centre onto the ship.
	var focus: Vector2 = ship_rest * e
	orbit(ship_camera, Vector3(focus.x, 0.0, focus.y) * ship_view_size, pitch, ship_view_size / zoom)
	orbit(sea_camera, Vector3(water_shift + focus.x, 0.0, focus.y) * SEA_VIEW_METRES, pitch, SEA_VIEW_METRES / zoom)
	# The flat streaks and wake lie on the sea: an ortho camera tilted by pitch
	# squashes the sea's screen-up axis by sin(pitch), so a 2D scale matches it.
	var scale_by: Vector2 = Vector2(zoom, zoom * sin(pitch))
	var centre: Vector2 = root.size * 0.5
	for layer_item: Control in [sea, wake]:
		layer_item.scale = scale_by
		layer_item.position = centre - centre * scale_by - focus * root.size.y * scale_by
	if fade == null and departing >= DEPART_SECONDS - DEPART_FADE:
		fade = ScreenFade.cover(get_tree(), DEPART_FADE)
		fade.covered.connect(func() -> void: departed.emit(), CONNECT_ONE_SHOT)

## Aim a camera at a sea point from `pitch` above the horizon, looking toward
## screen-up (-Z), so the ship (bow right) is seen from its side.
func orbit(camera: Camera3D, target: Vector3, pitch: float, view_size: float) -> void:
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	camera.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * 200.0
	camera.size = view_size
