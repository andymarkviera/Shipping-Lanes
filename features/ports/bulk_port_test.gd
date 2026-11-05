extends "res://features/ports/port_test.gd"
## Separate private fixtures: bulk/gas capacity with the starter's placeholder presentation.
const BulkService = preload("res://features/cargo/bulk_service.gd")
@export_enum("bulk", "gas") var cargo_family: String = "bulk"
var bulk = BulkService.new()
var bulk_panel: VBoxContainer
var cargo_scroll: ScrollContainer
var elapsed: float = 0.0
var booted: bool = false

func create_ship() -> HandlingShip:
	var body: HandlingShip = super.create_ship()
	body.definition = body.definition.duplicate(true)
	body.definition.id = bulk.ship_definition.id
	body.definition.display_name = bulk.ship_definition.display_name
	body.definition.cargo_type_ids = bulk.ship_definition.cargo_type_ids.duplicate()
	body.definition.cargo_capacities = {}
	body.definition.container_layout = null
	body.definition.bulk_holds = bulk.ship_definition.bulk_holds.duplicate(true)
	body.definition.bulk_mixing_policy = bulk.ship_definition.bulk_mixing_policy
	body.definition.gas_tanks = bulk.ship_definition.gas_tanks.duplicate(true)
	body.definition.gas_mixing_policy = bulk.ship_definition.gas_mixing_policy
	body.definition.dwt_tonnes = bulk.ship_definition.dwt_tonnes
	return body

func _ready() -> void:
	bulk = BulkService.new(cargo_family)
	save_enabled = false
	super._ready()
	for place: Node3D in world_ports:
		place.definition = place.definition.duplicate(true)
		place.berth = place.berth.duplicate(true)
		place.definition.service_ids.append(cargo_family + "_transfer")
		place.berth.service_ids.append(cargo_family + "_transfer")
		place.berth.cargo_type_ids.append_array(bulk.ship_definition.cargo_type_ids)
		if cargo_family == "gas":
			place.berth.gas_pipelines = bulk.terminals[place.definition.id].gas_pipelines.duplicate(true)
			bulk.terminals[place.definition.id] = place.berth
	switch_button.hide()
	# Existing cargo controls belong to container/heavy fixtures, not this authority.
	jobs_panel.hide()
	bulk_panel = preload("res://features/cargo/bulk_service_panel.gd").new()
	bulk_panel.family = cargo_family
	cargo_scroll = ScrollContainer.new()
	cargo_scroll.custom_minimum_size = Vector2(460, 350)
	services.add_child(cargo_scroll)
	bulk_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo_scroll.add_child(bulk_panel)
	for child: Node in services.get_child(0).get_children():
		if child is Button and child.text in ["CARGO", "Close services"]: child.hide()
	button(services.get_child(0), "Show / hide " + cargo_family + " cargo", func(): cargo_scroll.visible = not cargo_scroll.visible)
	bulk_panel.load_requested.connect(func(id: String):
		sync_context()
		if bulk.start_loading(id): elapsed = 0
		publish_state())
	bulk_panel.discharge_requested.connect(func(quantity: int):
		sync_context()
		if bulk.start_discharge(quantity): elapsed = 0
		publish_state())
	bulk_panel.cancel_requested.connect(func(): bulk.cancel(); publish_state())
	ship.simulation_paused = true
	controls.set_menu_open(true)
	if not bulk.open("user://worlds/private_" + cargo_family + "_voyage/voyage.db"):
		booted = true
		return
	if bulk.store.revision == 1 and bulk.pose == Transform3D.IDENTITY:
		bulk.pose = ship.global_transform
		bulk.fuel = ship.state.fuel_liters
		bulk.checkpoint()
	port = world_ports[BulkService.PORTS.find(bulk.port)]
	bind_port()
	ship.global_transform = bulk.pose
	ship.state.fuel_liters = bulk.fuel
	ship.state.condition = bulk.condition
	await get_tree().physics_frame
	if bulk.docked:
		if not docking.request_dock(1, service_id(), cargo_id()).ok:
			bulk.stop("Saved berth is unavailable. Save preserved; reopen when clear.")
		else:
			docking.advance(1.1)
			if docking.state(1) != "docked": bulk.stop("Could not restore bulk docking. Save preserved.")
	booted = true
	ship.simulation_paused = bulk.blocked
	controls.set_menu_open(false)
	publish_state()
	get_tree().auto_accept_quit = false

func service_id() -> String: return cargo_family + "_transfer"
func cargo_id() -> String: return "cargo_gas_lng" if cargo_family == "gas" else "cargo_bulk_grain"
func ship_key() -> String: return bulk.ship_id
func can_switch() -> bool: return false

func sync_context() -> void:
	var docked_now: bool = docking.state(1) == "docked" and ship.docked
	if not bulk.active.is_empty() and (not docked_now or bulk.port != port.definition.id):
		bulk.transact(func(candidate: RefCounted) -> Dictionary: return candidate.cancel_pending(true))
	bulk.port = port.definition.id
	bulk.docked = docked_now
	bulk.pose = ship.global_transform
	bulk.fuel = ship.state.fuel_liters
	bulk.condition = ship.state.condition

func publish_state() -> void:
	ship.state.manifest.replace(bulk.manifest.lines())
	reward_minor = bulk.credits
	var state: Dictionary = bulk.presentation()
	state.at_destination = state.job.get("destination_port_id") == port.definition.id
	bulk_panel.refresh(state, bulk.offers.list_at(port.definition.id), bulk.docked)

func _physics_process(delta: float) -> void:
	if not booted or bulk.blocked: return
	super._physics_process(delta)
	sync_context()
	elapsed += delta
	if elapsed >= .25:
		if bulk.active.is_empty():
			if elapsed >= 1.0: bulk.checkpoint(); elapsed = 0
		else:
			bulk.advance(elapsed)
			elapsed = 0
	publish_state()
	if bulk.blocked: ship.zero_throttle(); ship.simulation_paused = true

func _process(_delta: float) -> void:
	if not booted or not is_instance_valid(ship): return
	jobs_panel.hide()
	cargo_scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 240, 180, 420)
	services.visible = docking.state(1) == "docked" or bulk.blocked
	details.text = "%s voyage fixture · %s\nWallet: %.2f credits" % [cargo_family.capitalize(), port.definition.display_name, bulk.credits / 100.0]
	dock_button.disabled = bulk.blocked or not bulk.active.is_empty() or dock_button.disabled
	refuel_button.disabled = bulk.blocked or not bulk.active.is_empty()
	repair_button.disabled = refuel_button.disabled
	loading_text.text = bulk.notice if bulk.blocked else "RMB orbit · Wheel zoom · Esc menu"
	minimap.queue_redraw()
	# Editing service controls suppresses helm input; physics/world time keeps running.
	controls.set_menu_open(services.visible)
	if bulk.blocked: publish_state()

func refuel() -> void:
	if not bulk.active.is_empty() or bulk.blocked: return
	super.refuel()
	sync_context()
	bulk.checkpoint()

func repair() -> void:
	if not bulk.active.is_empty() or bulk.blocked: return
	super.repair()
	sync_context()
	bulk.checkpoint()

func leave() -> void:
	if not bulk.blocked:
		sync_context()
		if not bulk.checkpoint(): return
	get_tree().change_scene_to_file("res://features/main/main.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not bulk.blocked:
			sync_context()
			if not bulk.checkpoint(): return
		get_tree().quit()

func _exit_tree() -> void:
	if bulk.store != null: bulk.store.close()
	super._exit_tree()
