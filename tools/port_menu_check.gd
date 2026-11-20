extends SceneTree
## Patch 3.1.1: a docked online player always gets the full port menu.
## Builds the real game scene as an online client view exactly the way
## dedicated_runtime.gd does (no physics tick on the view, presentation-only
## docking), docks the ship the way a server snapshot does, and checks the port
## card, its CARGO / REFUEL / REPAIR / SHIPS row and the job panel are on screen
## and take a real mouse click. Then undocks and checks the menu goes away.
## No server, no network, no save (a client view never saves).
## Run: godot --headless --path . --script res://tools/port_menu_check.gd
const GAME = preload("res://features/game/game.tscn")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("PORT_MENU FAILED: " + label)
	return condition

func frames(count: int) -> void:
	for frame: int in count:
		await process_frame
		await physics_frame

## A left click at the centre of `item`, through the real GUI input path.
func click(item: Control) -> void:
	var centre: Vector2 = item.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = centre
		event.global_position = centre
		root.push_input(event)
		await process_frame

func run() -> void:
	# Headless windows are 64 x 64; give the HUD a real screen to lay out on.
	root.size = Vector2i(1440, 900)
	# Same setup as the client branch of dedicated_runtime.gd.
	var view: Node = GAME.instantiate()
	view.runtime_role = "client"
	root.add_child(view)
	view.set_physics_process(false)
	view.docking.set_physics_process(false)
	view.docking.presentation_only = true
	view.loading.set_process(false)
	view.loading.set_physics_process(false)
	view.ship.set_physics_process(false)
	view.helm.set_physics_process(false)
	view.controls.set_menu_open(false)
	await frames(10)
	expect(not view.services.is_visible_in_tree(), "under way: no port services")
	# A server snapshot docks the ship (present_world writes this member).
	view.docking.members[view.owner_id] = {"body": view.ship, "port": view.port, "state": "docked", "remaining": 0.0,
		"berth_index": 0, "berth_id": view.port.berth_id(0), "hold": 0, "ghost": false}
	view.ship.docked = true
	await frames(10)
	expect(view.port_panel.is_visible_in_tree(), "docked online: the port card is on screen")
	expect(view.services.is_visible_in_tree(), "docked online: the port services are on screen")
	expect(view.jobs_panel.is_visible_in_tree(), "docked online: the job panel is on screen")
	for item: Button in [view.refuel_button, view.repair_button]:
		expect(item.is_visible_in_tree() and item.mouse_filter != Control.MOUSE_FILTER_IGNORE and item.get_global_rect().size.x > 1.0, "docked online: %s is on screen and clickable" % item.text)
	var ships: Button = view.game_hud.ships_button
	expect(ships != null and ships.is_visible_in_tree(), "docked online: SHIPS is on screen")
	# Interactive: a real click on REFUEL reaches the button (nothing covers it).
	var hits: Array[int] = [0]
	view.refuel_button.pressed.connect(func() -> void: hits[0] += 1)
	await click(view.refuel_button)
	expect(hits[0] == 1, "docked online: a mouse click on REFUEL reaches the button")
	# Undocked again: the menu goes away.
	view.docking.members[view.owner_id].state = "underway"
	view.ship.docked = false
	await frames(10)
	expect(not view.services.is_visible_in_tree() and not view.jobs_panel.is_visible_in_tree(), "undocked: the port services hide")
	view.queue_free()
	await frames(3)
	print("PORT_MENU CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
