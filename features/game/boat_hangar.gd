extends CanvasLayer
const DISPLAY = preload("res://features/ui/display_fonts.gd")
## Patch 2.2 item 4: the boat hangar. Opened from SHIPS on the port card, it
## fills the screen with a toon boat shed (doors open to the water, warm lamps)
## and one ship turning slowly on the water. Left/right (on screen, arrow keys,
## A/D, d-pad) cycle the ladder; the family filter sits on top (also up/down).
## Buy and Select go through the port's own ship_action, so the fleet's rules
## (docked, no job aboard) are the same as before. Back (Esc, B) returns to the
## game. Nothing here pauses the world: the helm is only released while open.
## Gas and oil ships are not in the ladder, so they are not in the hangar.
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const Progression = preload("res://features/game/progression.gd")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const FAMILIES = [["All", ""], ["Container", "container"], ["Bulk", "bulk"], ["Heavy lift", "heavy"], ["Other boats", "small"]]
const FAMILY_NAMES = {"container": "Container", "bulk": "Bulk", "heavy": "Heavy lift", "small": "Other boats"}
## Every ship is drawn this long in the shed; the real size is in the stats.
const SHOWN_LENGTH: float = 64.0
const TURN_RADIANS_PER_SECOND: float = 0.3
## A second press inside this window is ignored: one click, one charge.
const ACTION_COOLDOWN_MS: int = 600
const MPS_PER_KNOT: float = 0.514444
const WARM: Color = Color("ffb35c")

var view: Node
var family: String = ""
var kinds: Array[String] = []
var index: int = 0
var last_action_ms: int = -100000
var notice: String = ""
var models: Dictionary = {}
var screen: Control
var viewport: SubViewport
var turntable: Node3D
var name_label: Label
var family_label: Label
var stats_label: Label
var status_label: Label
var wallet_label: Label
var action_button: Button
var sell_button: Button
var filter_buttons: Array[Button] = []

## The whole ladder, container then bulk then heavy lift, smallest first,
## then the "Other boats" (the small boats of Patch 2.4 item 8 and the pirate
## ships of Patch 2.9.1), cheapest first.
static func ladder() -> Array[String]:
	var all: Array[String] = []
	all.append_array(Progression.CONTAINER_KINDS)
	all.append_array(Progression.BULK_KINDS)
	all.append_array(Progression.HEAVY_KINDS)
	all.append_array(Progression.SMALL_KINDS)
	return all

static func family_of(kind: String) -> String:
	return kind.get_slice("_", 0)

static func tier_of(kind: String) -> int:
	return Progression.container_tier(kind) + Progression.bulk_tier(kind) + Progression.heavy_tier(kind) + Progression.small_tier(kind)

static func top_knots(definition: ShipDefinition) -> float:
	return definition.forward_acceleration_mps2 / definition.linear_drag_per_second / MPS_PER_KNOT

## What the hull carries, in the units its jobs use.
static func capacity_text(kind: String) -> String:
	var definition: ShipDefinition = Progression.definition(kind)
	match family_of(kind):
		"container": return "%s containers" % Progression.thousands(Progression.container_capacity(tier_of(kind)))
		"bulk": return "%s t bulk" % Progression.thousands(Progression.bulk_capacity(tier_of(kind)))
		"small": return "none, just for fun"
	# The heavy lifter's mass limit grows with deck area from ship 1 (24 × 90 m, 200 t).
	var size: Vector3 = definition.hull_size_m
	return "%s t heavy load" % Progression.thousands(roundi(200.0 * size.x / 24.0 * size.z / 90.0))

static func credits(minor: int) -> String:
	return "%s.%02d" % [Progression.thousands(minor / 100), minor % 100]

func _ready() -> void:
	layer = 9
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	PLAYFUL.dress(screen)
	add_child(screen)
	var frame: SubViewportContainer = SubViewportContainer.new()
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(frame)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	frame.add_child(viewport)
	build_shed()
	build_overlay()
	set_family("")
	hide_screen()

func current() -> String:
	return kinds[index] if not kinds.is_empty() else ""

func is_open() -> bool:
	return screen.visible

func open() -> void:
	if is_open(): return
	# Build every model once, on first open, so cycling never stalls a frame.
	for kind: String in ladder(): show_model(kind)
	# Open on the ship you are sailing, in the filter you left if it holds it.
	if not kinds.has(view.ship_kind): set_family("")
	index = maxi(0, kinds.find(view.ship_kind))
	notice = ""
	screen.show()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view.controls.set_menu_open(true)
	refresh()

func close() -> void:
	if not is_open(): return
	hide_screen()
	view.controls.set_menu_open(false)

func hide_screen() -> void:
	screen.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func set_family(id: String) -> void:
	var keep: String = current()
	family = id
	kinds.clear()
	for kind: String in ladder():
		if family.is_empty() or family_of(kind) == family: kinds.append(kind)
	index = maxi(0, kinds.find(keep))
	for at: int in filter_buttons.size():
		filter_buttons[at].modulate = Color.WHITE if FAMILIES[at][1] == family else Color(1, 1, 1, 0.6)
	notice = ""
	refresh()

func step(by: int) -> void:
	if kinds.is_empty(): return
	index = posmod(index + by, kinds.size())
	notice = ""
	refresh()

func step_family(by: int) -> void:
	var at: int = 0
	for i: int in FAMILIES.size():
		if FAMILIES[i][1] == family: at = i
	set_family(FAMILIES[posmod(at + by, FAMILIES.size())][1])

## Why the main button cannot act on this ship right now; empty when it can.
func action_reason(kind: String) -> String:
	if kind == view.ship_kind: return "This is your active ship."
	var entry: Dictionary = Progression.SHIPS[kind]
	if not view.fleet.has(kind):
		if view.reward_minor < int(entry.price_minor):
			return "You need %s more credits." % credits(int(entry.price_minor) - view.reward_minor)
		if view.docking.state(1) != "docked": return "Dock at a port to buy ships."
		return ""
	# Patch 2.3 debug: switching works anywhere in a debug world.
	if view.docking.state(1) != "docked" and not is_instance_valid(view.get("debug")): return "Dock at a port to switch ships."
	if not view.can_switch(): return "Finish or cancel your current job before changing ships."
	return ""

func press_action() -> void:
	var kind: String = current()
	if kind.is_empty() or Time.get_ticks_msec() - last_action_ms < ACTION_COOLDOWN_MS: return
	if is_instance_valid(view.persistence) and not view.persistence.ready_to_save: return
	var reason: String = action_reason(kind)
	if not reason.is_empty():
		notice = reason
		refresh()
		return
	last_action_ms = Time.get_ticks_msec()
	var owned: bool = view.fleet.has(kind)
	view.ship_action(kind)
	notice = str(view.offer_notice)
	if not owned and view.fleet.has(kind): notice = "Bought the %s. Press Select to sail it." % Progression.SHIPS[kind].name
	refresh()
	# Selected: back to the game on the new ship, waiting off the quay.
	if owned and view.ship_kind == kind: close()

func press_sell() -> void:
	var kind: String = current()
	if kind.is_empty() or Time.get_ticks_msec() - last_action_ms < ACTION_COOLDOWN_MS: return
	last_action_ms = Time.get_ticks_msec()
	view.sell_ship(kind)
	notice = str(view.offer_notice)
	refresh()

func refresh() -> void:
	if view == null or name_label == null: return
	var kind: String = current()
	if kind.is_empty(): return
	show_model(kind)
	var entry: Dictionary = Progression.SHIPS[kind]
	var definition: ShipDefinition = Progression.definition(kind)
	var size: Vector3 = definition.hull_size_m
	var owned: bool = view.fleet.has(kind)
	var face: String = "gold" if kind in ["small_galleon", "small_brigantine"] else "white"
	if name_label.get_theme_font("font") != DISPLAY.font(face): DISPLAY.apply(name_label, face)
	name_label.text = str(entry.name).to_upper() + ("  · ACTIVE" if kind == view.ship_kind else ("  · OWNED" if owned else ""))
	var small: bool = family_of(kind) == "small"
	family_label.text = "%s · %s %d of %d · %d of %d shown" % [FAMILY_NAMES[family_of(kind)], "boat" if small else "ship", tier_of(kind), Progression.SMALL_KINDS.size() if small else 5, index + 1, kinds.size()]
	stats_label.text = "Size %d × %d m   ·   Top speed %.0f kn   ·   Capacity %s   ·   Price %s" % [
		roundi(size.z), roundi(size.x), top_knots(definition), capacity_text(kind), credits(int(entry.price_minor))]
	wallet_label.text = "Wallet: %s credits" % credits(view.reward_minor)
	var reason: String = action_reason(kind)
	if kind == view.ship_kind: action_button.text = "Active"
	elif owned: action_button.text = "Select"
	elif view.reward_minor < int(entry.price_minor): action_button.text = "Need %s more" % credits(int(entry.price_minor) - view.reward_minor)
	else: action_button.text = "Buy · %s" % credits(int(entry.price_minor))
	action_button.disabled = not reason.is_empty()
	action_button.tooltip_text = reason
	sell_button.visible = owned and kind != view.ship_kind
	sell_button.disabled = view.docking.state(1) != "docked"
	var armed: bool = view.sell_kind == kind and Time.get_ticks_msec() <= view.sell_deadline
	sell_button.text = "Confirm sale" if armed else "Sell · +%s" % credits(Progression.resale_minor(kind))
	status_label.text = notice if not notice.is_empty() else ("" if kind == view.ship_kind else reason)

func _process(delta: float) -> void:
	if not is_open(): return
	turntable.rotate_y(TURN_RADIANS_PER_SECOND * delta)
	refresh()

## Keys and controller. Taken before the Esc menu sees them.
func _input(event: InputEvent) -> void:
	if not is_open() or event.is_echo() or not event.is_pressed(): return
	if event is InputEventMouse: return
	var key: InputEventKey = event as InputEventKey
	var code: Key = KEY_NONE
	if key != null: code = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if event.is_action("ui_cancel") or code == KEY_ESCAPE: close()
	elif event.is_action("ui_left") or code == KEY_A: step(-1)
	elif event.is_action("ui_right") or code == KEY_D: step(1)
	elif event.is_action("ui_up") or code == KEY_W: step_family(-1)
	elif event.is_action("ui_down") or code == KEY_S: step_family(1)
	elif event.is_action("ui_accept"): press_action()
	else: return
	get_viewport().set_input_as_handled()

## One model per ship, built once and kept: swapping is a visibility change.
func show_model(kind: String) -> void:
	if not models.has(kind):
		var definition: ShipDefinition = Progression.definition(kind)
		var model: Node3D = CHUNKY_LOOK.model(kind, definition)
		model.scale = Vector3.ONE * (SHOWN_LENGTH / maxf(1.0, definition.hull_size_m.z))
		TOON_LOOK.apply(model)
		turntable.add_child(model)
		models[kind] = model
	for shown: String in models: (models[shown] as Node3D).visible = shown == kind

func build_overlay() -> void:
	var top: VBoxContainer = VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 16
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(top)
	var title: Label = Label.new()
	title.text = "BOAT HANGAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", PLAYFUL.SUN)
	DISPLAY.apply(title)
	top.add_child(title)
	var filters: HBoxContainer = HBoxContainer.new()
	filters.alignment = BoxContainer.ALIGNMENT_CENTER
	filters.add_theme_constant_override("separation", 8)
	top.add_child(filters)
	for entry: Array in FAMILIES:
		filter_buttons.append(make_button(filters, entry[0], set_family.bind(entry[1]), Vector2(150, 44)))
	var back: Button = make_button(screen, "< Back", close, Vector2(140, 48))
	back.position = Vector2(18, 18)
	for side: int in [-1, 1]:
		var arrow: Button = make_button(screen, "<" if side < 0 else ">", step.bind(side), Vector2(76, 110))
		arrow.add_theme_font_size_override("font_size", 52)
		arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT if side < 0 else Control.PRESET_CENTER_RIGHT)
		arrow.offset_top = -55
		arrow.offset_bottom = 55
		arrow.offset_left = 18 if side < 0 else -94
		arrow.offset_right = 94 if side < 0 else -18
	var card: PanelContainer = PanelContainer.new()
	PLAYFUL.dress(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_bottom = -18
	screen.add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	name_label = label(column, 28, PLAYFUL.SUN)
	family_label = label(column, 16, PLAYFUL.CREAM)
	stats_label = label(column, 18, PLAYFUL.CREAM)
	wallet_label = label(column, 18, PLAYFUL.LEAF)
	DISPLAY.apply(wallet_label, "gold")
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	action_button = make_button(actions, "Buy", press_action, Vector2(300, 52))
	sell_button = make_button(actions, "Sell", press_sell, Vector2(220, 52))
	DISPLAY.apply(action_button, "gold")
	DISPLAY.apply(sell_button, "gold")
	status_label = label(column, 15, PLAYFUL.SUN_LIGHT)
	status_label.custom_minimum_size = Vector2(720, 0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func label(parent: Node, font_size: int, colour: Color) -> Label:
	var item: Label = Label.new()
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", colour)
	parent.add_child(item)
	return item

func make_button(parent: Node, title: String, action: Callable, at_least: Vector2) -> Button:
	var item: Button = Button.new()
	item.text = title
	DISPLAY.apply(item, "gold" if title == "Other boats" else "white")
	item.custom_minimum_size = at_least
	item.add_theme_font_size_override("font_size", 20)
	# No keyboard focus: the keys above always reach the hangar.
	item.focus_mode = Control.FOCUS_NONE
	item.pressed.connect(action)
	parent.add_child(item)
	return item

## The shed: plank floor around a water slip, wooden walls and a pitched roof,
## big doors swung open at the back onto the sea and sky, warm hanging lamps.
func build_shed() -> void:
	var stage: Node3D = Node3D.new()
	viewport.add_child(stage)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8fd3f4")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ffe2b8")
	environment.ambient_light_energy = 0.55
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 160, 0)
	sun.light_energy = 0.8
	stage.add_child(sun)
	var cache: Dictionary = {}
	var wood: Color = Color("9c6638")
	var dark_wood: Color = Color("6e4325")
	var roof: Color = Color("b8402f")
	# Water in the slip and the open sea beyond the doors.
	box(stage, Vector3(70, 1, 150), Vector3(0, -0.6, -10), Color("2f8fc9"), cache)
	box(stage, Vector3(1600, 1, 1200), Vector3(0, -0.8, -660), Color("3aa3d8"), cache)
	# Plank floor either side of the slip, with edge beams.
	for side: float in [-1.0, 1.0]:
		box(stage, Vector3(30, 2, 120), Vector3(side * 50, 0, 0), wood, cache)
		box(stage, Vector3(1.5, 2.6, 120), Vector3(side * 35.5, 0.4, 0), dark_wood, cache)
		# Side walls with posts.
		box(stage, Vector3(2, 46, 120), Vector3(side * 65, 23, 0), wood, cache)
		for z: float in [-55.0, -20.0, 15.0, 50.0]:
			box(stage, Vector3(3, 46, 3), Vector3(side * 63, 23, z), dark_wood, cache)
		# The back wall beside the door opening, and a door swung open outward.
		box(stage, Vector3(30, 46, 2), Vector3(side * 50, 23, -60), wood, cache)
		var door: Node3D = Node3D.new()
		door.position = Vector3(side * 35, 0, -61)
		door.rotation_degrees.y = -side * 110.0
		stage.add_child(door)
		box(door, Vector3(34, 36, 1.2), Vector3(-side * 17.0, 18, 0), Color("c98a4a"), cache)
		box(door, Vector3(34, 2, 1.6), Vector3(-side * 17.0, 18, 0), dark_wood, cache)
		# Roof slopes.
		var slope: MeshInstance3D = box(stage, Vector3(72, 2, 124), Vector3(side * 33, 54, 0), roof, cache)
		slope.rotation_degrees.z = -side * 16.0
	# Lintel over the doors.
	box(stage, Vector3(72, 8, 2), Vector3(0, 42, -60), dark_wood, cache)
	# Warm hanging lamps along both walls.
	for side: float in [-1.0, 1.0]:
		for z: float in [-35.0, 5.0, 40.0]:
			ball(stage, 1.6, Vector3(side * 42, 30, z), WARM, cache)
			box(stage, Vector3(0.3, 15, 0.3), Vector3(side * 42, 38, z), Color("2b2f3a"), cache)
			var glow: OmniLight3D = OmniLight3D.new()
			glow.light_color = WARM
			glow.light_energy = 2.2
			glow.omni_range = 55
			glow.position = Vector3(side * 42, 28, z)
			stage.add_child(glow)
	turntable = Node3D.new()
	turntable.position = Vector3(0, 0, -6)
	stage.add_child(turntable)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 55
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0, 26, 72), Vector3(0, 4, -8))
	camera.current = true
	TOON_LOOK.apply(stage)

func box(parent: Node3D, size: Vector3, at: Vector3, colour: Color, cache: Dictionary) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return part(parent, mesh, at, colour, cache)

func ball(parent: Node3D, radius: float, at: Vector3, colour: Color, cache: Dictionary) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return part(parent, mesh, at, colour, cache)

func part(parent: Node3D, mesh: Mesh, at: Vector3, colour: Color, cache: Dictionary) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	if not cache.has(colour):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.9
		cache[colour] = material
	node.material_override = cache[colour]
	parent.add_child(node)
	return node
