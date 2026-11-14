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

var view: Node
var tag: Label
var readout: Label
var notice: Label
var travel_list: VBoxContainer

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
	tag = Label.new()
	tag.text = "DEBUG"
	tag.add_theme_font_size_override("font_size", 34)
	tag.add_theme_color_override("font_color", Color("ff5a4a"))
	tag.add_theme_color_override("font_outline_color", Color.WHITE)
	tag.add_theme_constant_override("outline_size", 10)
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.offset_left = -80
	tag.offset_right = 80
	tag.offset_top = 8
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its own top layer, so the tag stays visible over the hangar and the Esc menu.
	var top: CanvasLayer = CanvasLayer.new()
	top.layer = 100
	add_child(top)
	top.add_child(tag)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 20
	panel.offset_top = -170
	PLAYFUL.dress(panel)
	add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	panel.add_child(stack)
	readout = Label.new()
	stack.add_child(readout)
	add_button(stack, "HANGAR", func() -> void: view.hangar.open())
	var heading: Label = Label.new()
	heading.text = "Quick travel"
	stack.add_child(heading)
	travel_list = VBoxContainer.new()
	stack.add_child(travel_list)
	for index: int in view.world_ports.size():
		add_button(travel_list, view.world_ports[index].definition.display_name, travel.bind(index))
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.x = 220
	stack.add_child(notice)

func add_button(parent: Node, title: String, action: Callable) -> Button:
	var node: Button = Button.new()
	node.text = title
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func _process(_delta: float) -> void:
	if view.reward_minor < CREDITS_MINOR / 2: view.reward_minor = CREDITS_MINOR
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
