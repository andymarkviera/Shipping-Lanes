extends CanvasLayer
## Patch 2.3 item 1: the TEMPORARY debug game mode, a test tool for trying every
## boat on the map. To remove it: delete this folder, the DEBUG button in
## application_menu.gd, the "debug" lines in main.gd and the lines marked
## "Patch 2.3 debug" in port_test.gd and boat_hangar.gd.
##
## The title's DEBUG button sets the tree meta META and opens the real game
## scene. That scene then runs with its save switched off (no voyage
## persistence is created, so no save file is opened, read or written) and adds
## this layer: the DEBUG tag, every ladder ship owned, credits topped up, a
## HANGAR button that works anywhere (Select swaps on the spot), a quick-travel
## list to every port and a ship readout. MAIN MENU throws the world away.
const META: StringName = &"debug_game"
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const Progression = preload("res://features/game/progression.gd")
const Hangar = preload("res://features/game/boat_hangar.gd")
## One billion credits, topped up whenever it falls below half.
const CREDITS_MINOR: int = 100_000_000_000
## "Full speed" in the readout: within this many knots of top speed (what the
## HUD rounds to the top speed).
const FULL_SPEED_MARGIN_KNOTS: float = 0.5

const DISPLAY = preload("res://features/ui/display_fonts.gd")
var view: Node
var tag: Label
var badge: PanelContainer
var toggle_button: Button
var panel: PanelContainer
var readout: Label
var notice: Label
var travel_list: VBoxContainer
## Patch 4.0.2 item 8: the panel's content follows the vehicle: the boat
## controls while sailing, the plane controls while flying.
var boat_box: VBoxContainer
var plane_box: VBoxContainer
var plane_readout: Label
var plane_notice: Label
const Planes = preload("res://features/planes/plane_catalog.gd")
const Airports = preload("res://features/planes/airports.gd")

## True while the tree is in a debug session (set by the title's DEBUG button).
static func active(tree: SceneTree) -> bool:
	return tree != null and bool(tree.get_meta(META, false))

## Seconds from a stop to within FULL_SPEED_MARGIN_KNOTS of top speed at full
## ahead: half the engine ramp, then the drag curve (HandlingShip.advance_motion).
static func seconds_to_full(definition: ShipDefinition) -> float:
	var top: float = Hangar.top_knots(definition)
	if top <= FULL_SPEED_MARGIN_KNOTS or definition.linear_drag_per_second <= 0.0: return 0.0
	return 0.5 / maxf(0.01, definition.engine_ramp_up_per_second) + log(top / FULL_SPEED_MARGIN_KNOTS) / definition.linear_drag_per_second

func _ready() -> void:
	layer = 8
	for kind: String in Hangar.ladder(): view.fleet[kind] = {"fuel": 1.0, "condition": 1.0}
	view.reward_minor = CREDITS_MINOR
	# Patch 4.0: every plane, at any level, in the single-player test mode.
	if is_instance_valid(view.get("aviation")): view.aviation.unlock_all()
	# Patch 3.2: the DEBUG tag is a small badge in the bottom-left corner, on its
	# own top layer (visible over the hangar, the map and the Esc menu) and clear
	# of every heading.
	var top: CanvasLayer = CanvasLayer.new()
	top.layer = 100
	add_child(top)
	badge = PanelContainer.new()
	var red: StyleBoxFlat = PLAYFUL.box(Color("c8372a"), Color.WHITE, 6, 2, 0)
	red.content_margin_left = 6
	red.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", red)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.offset_left = 6
	badge.offset_bottom = -4
	top.add_child(badge)
	tag = Label.new()
	tag.text = "DEBUG"
	DISPLAY.plain(tag, Color.WHITE, 12)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(tag)
	# Patch 3.2 follow-up: collapsed by default into a small "Debug Menu" button
	# at the bottom left, above the badge; it toggles the full controls (Esc closes).
	toggle_button = add_button(self, "Debug Menu", toggle)
	PLAYFUL.dress(toggle_button)
	DISPLAY.style_button(toggle_button)
	toggle_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	toggle_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toggle_button.offset_left = 20
	toggle_button.offset_bottom = -30
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 20
	panel.offset_bottom = -84
	PLAYFUL.dress(panel)
	panel.hide()
	add_child(panel)
	var both: VBoxContainer = VBoxContainer.new()
	panel.add_child(both)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "BoatDebug"
	both.add_child(stack)
	boat_box = stack
	readout = Label.new()
	DISPLAY.plain(readout, Color.WHITE, 16)
	stack.add_child(readout)
	add_button(stack, "Hangar", func() -> void: view.hangar.open())
	# Patch 3.1: jump to the next time of day (local test world only).
	add_button(stack, "Next Time of Day", func() -> void: preload("res://features/sky/day_night.gd").skip_phase())
	var heading: Label = Label.new()
	heading.text = "Quick Travel"
	DISPLAY.plain(heading, PLAYFUL.SUN, 16)
	stack.add_child(heading)
	travel_list = VBoxContainer.new()
	stack.add_child(travel_list)
	for index: int in view.world_ports.size():
		add_button(travel_list, view.world_ports[index].definition.display_name, travel.bind(index))
	notice = Label.new()
	DISPLAY.plain(notice, PLAYFUL.CREAM, 15)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.x = 220
	stack.add_child(notice)
	build_plane_box(both)

## Patch 4.0.2 item 8: the plane controls: an altitude / speed readout, a
## plane picker, spawn at any airport, refuel, repair, the gear and a jump
## to the nearest airport. Debug only (the local test world).
func build_plane_box(parent: Node) -> void:
	plane_box = VBoxContainer.new()
	plane_box.name = "PlaneDebug"
	parent.add_child(plane_box)
	plane_readout = Label.new()
	DISPLAY.plain(plane_readout, Color.WHITE, 16)
	plane_box.add_child(plane_readout)
	var picker: Label = Label.new()
	picker.text = "Plane"
	DISPLAY.plain(picker, PLAYFUL.SUN, 16)
	plane_box.add_child(picker)
	var row: HBoxContainer = HBoxContainer.new()
	plane_box.add_child(row)
	for kind: String in Planes.ORDER: add_button(row, str(Planes.PLANES[kind].name).get_slice(" ", 0), pick_plane.bind(kind))
	var services: HBoxContainer = HBoxContainer.new()
	plane_box.add_child(services)
	add_button(services, "Refuel", plane_refuel)
	add_button(services, "Repair", plane_repair)
	add_button(services, "Gear", plane_gear)
	add_button(plane_box, "Nearest Airport", nearest_airport)
	add_button(plane_box, "Next Time of Day", func() -> void: preload("res://features/sky/day_night.gd").skip_phase())
	var heading: Label = Label.new()
	heading.text = "Spawn at Airport"
	DISPLAY.plain(heading, PLAYFUL.SUN, 16)
	plane_box.add_child(heading)
	for index: int in Airports.count(): add_button(plane_box, Airports.all()[index].name, spawn_at.bind(index))
	plane_notice = Label.new()
	DISPLAY.plain(plane_notice, PLAYFUL.CREAM, 15)
	plane_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plane_notice.custom_minimum_size.x = 220
	plane_box.add_child(plane_notice)
	plane_box.hide()

## "plane" while flying, "boat" otherwise: which controls the panel shows.
func panel_mode() -> String:
	return "plane" if view.has_method("flying") and view.flying() else "boat"

func air() -> Node:
	return view.get("aviation")

## Swap to another plane on the spot (parked at the nearest airport).
func pick_plane(kind: String) -> void:
	var aviation: Node = air()
	if aviation == null or not aviation.flying(): return
	if not aviation.planes.has(kind): aviation.planes[kind] = {"fuel": 1.0, "condition": 1.0}
	aviation.store_plane()
	aviation.job_id = ""
	aviation.plane_kind = kind
	aviation.start_plane(maxi(0, Airports.nearest(aviation.model.position)))
	plane_notice.text = "Debug: now flying the %s." % Planes.PLANES[kind].name

func spawn_at(index: int) -> void:
	var aviation: Node = air()
	if aviation == null or not aviation.flying(): return
	aviation.store_plane()
	aviation.start_plane(index)
	plane_notice.text = "Debug: on the runway at %s." % Airports.all()[index].name

func nearest_airport() -> void:
	var aviation: Node = air()
	if aviation == null or not aviation.flying(): return
	spawn_at(maxi(0, Airports.nearest(aviation.model.position)))

func plane_refuel() -> void:
	var aviation: Node = air()
	if aviation == null or not aviation.flying(): return
	aviation.model.fuel_l = float(aviation.plane_entry().fuel_l)
	aviation.store_plane()
	plane_notice.text = "Debug: tank full."

func plane_repair() -> void:
	var aviation: Node = air()
	if aviation == null or not aviation.flying(): return
	aviation.planes[aviation.plane_kind].condition = 1.0
	plane_notice.text = "Debug: condition 100%."

func plane_gear() -> void:
	var aviation: Node = air()
	if aviation == null or not aviation.flying(): return
	plane_notice.text = ("Debug: gear %s." % ("down" if aviation.gear_order > 0.5 else "up")) if aviation.toggle_gear() else "The gear stays down on the ground."

func add_button(parent: Node, title: String, action: Callable) -> Button:
	var node: Button = Button.new()
	node.text = title
	node.focus_mode = Control.FOCUS_NONE
	DISPLAY.style_button(node)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

## Open or close the full debug controls.
func toggle() -> void:
	panel.visible = not panel.visible

func is_open() -> bool:
	return panel.visible

## Esc closes the open debug controls first (unless another overlay owns Esc).
func _input(event: InputEvent) -> void:
	if not panel.visible or not (event is InputEventKey and event.pressed and not event.echo): return
	if event.keycode != KEY_ESCAPE and event.physical_keycode != KEY_ESCAPE: return
	if view.hangar.is_open() or view.game_menu.is_open() or view.globe_map.is_open(): return
	panel.hide()
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if view.reward_minor < CREDITS_MINOR / 2: view.reward_minor = CREDITS_MINOR
	# Patch 4.0.2 item 8: the panel shows the controls for the vehicle in use.
	var flying: bool = panel_mode() == "plane"
	if is_instance_valid(plane_box): plane_box.visible = flying
	if is_instance_valid(boat_box): boat_box.visible = not flying
	if flying:
		var aviation: Node = air()
		var m: RefCounted = aviation.model
		plane_readout.text = "%s\n%d kn  ·  %d m up  ·  %d m above the sea\nGear %s  ·  Fuel %.0f%%" % [aviation.plane_entry().name, roundi(m.airspeed() * 1.944),
			roundi(maxf(m.agl_m, 0.0)), roundi(m.position.y), "down" if m.gear_down else "up", 100.0 * m.fuel_l / maxf(1.0, float(aviation.plane_entry().fuel_l))]
		return
	if not is_instance_valid(view.ship): return
	var definition: ShipDefinition = view.ship.definition
	readout.text = "%s\n%.1f kn  ·  top %.1f kn\nFull speed in about %.0f s" % [
		Progression.SHIPS[view.ship_kind].name, view.ship.velocity.length() / Hangar.MPS_PER_KNOT,
		Hangar.top_knots(definition), seconds_to_full(definition)]

## Hangar Select away from a berth: the ship swaps where it is, same heading,
## stopped. Returns false to leave the normal (docked) switch to ship_action.
func swap(kind: String) -> bool:
	if kind == view.ship_kind or not view.fleet.has(kind) or view.docking.state(1) == "docked": return false
	if not view.can_switch():
		view.offer_notice = "Finish or cancel your current job before changing ships."
		return true
	var pose: Transform3D = view.ship.global_transform
	var previous: String = view.ship_kind
	view.ship_kind = kind
	view.heavy_mode = Progression.heavy_tier(kind) > 0
	if not view.select_port(view.world_ports.find(view.port)):
		view.ship_kind = previous
		view.heavy_mode = Progression.heavy_tier(previous) > 0
		return true
	# select_port placed it at the port's spawn; bring it back, level, where the old one was.
	view.port.spawn_allocator.release(view.spawn_ticket)
	view.spawn_ticket = 0
	var yaw: float = pose.basis.get_euler().y
	view.ship.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(pose.origin.x, view.ship.global_position.y, pose.origin.z))
	view.ship.state.fuel_liters = view.ship.definition.fuel_capacity_liters
	view.ship.state.condition = 1.0
	view.offer_notice = "Debug: now sailing the %s." % Progression.SHIPS[kind].name
	return true

## Jump the active ship to a port's spawn point, stopped. Not while docked or loading.
func travel(index: int) -> void:
	if view.loading.busy() or view.docking.state(1) not in ["underway", "approaching"]:
		notice.text = "Undock first."
		return
	var target: Node3D = view.world_ports[index]
	var ship: HandlingShip = view.ship
	var layer_before: int = ship.collision_layer
	ship.collision_layer = 0
	view.port.spawn_allocator.release(view.spawn_ticket)
	view.spawn_ticket = 0
	var allocation: Dictionary = target.reserve_spawn(ship.definition.hull_size_m)
	ship.collision_layer = layer_before
	if not allocation.ok:
		notice.text = "%s: spawn occupied." % target.definition.display_name
		return
	var from: Vector3 = ship.global_position
	view.spawn_ticket = allocation.ticket
	view.port = target
	ship.global_transform = allocation.transform
	ship.velocity = Vector3.ZERO
	ship.yaw_rate = 0
	ship.zero_throttle()
	ship.actual_throttle = 0
	var shift: Vector3 = ship.global_position - from
	if ship.get("attached") == true: ship.payload_body.global_position += shift
	view.camera.shift(shift)
	view.wake.shift(shift)
	view.bind_port()
	view.place_icebergs()
	notice.text = "Arrived off %s." % target.definition.display_name
