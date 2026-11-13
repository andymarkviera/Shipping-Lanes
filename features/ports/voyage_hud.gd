extends PanelContainer
## Read-only projection: never owns cargo, timers, receipts or payments.
var heading: Label
var cargo: Label
var route: Label
var instruction: Label
var instruments: Label
var progress: ProgressBar

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -340
	offset_right = -20
	offset_top = 20
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243642")
	for edge: String in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 12)
	add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	heading = label(stack)
	heading.add_theme_color_override("font_color", Color("9ee3b1"))
	cargo = label(stack)
	route = label(stack)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 20
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(progress)
	instruction = label(stack)
	instruments = label(stack)

func label(parent: Node) -> Label:
	var result := Label.new()
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func distance_text(meters: float) -> String:
	return "%.2f km" % (meters / 1000.0) if meters >= 1000 else "%.0f m" % meters

static func describe(view: Node3D) -> Dictionary:
	var result := {"stage": "NO ACTIVE JOB", "cargo": "Cargo aboard: none", "route": "", "next": "Dock at a port, open CARGO and choose one job.", "progress": -1.0}
	var job: Dictionary = view.offers.active_job("preview_captain")
	if view.heavy_mode and not view.heavy_jobs.active.is_empty():
		job = view.heavy_jobs.active
		var carrying: bool = view.ship.attached
		var target: Vector3 = job.drop if carrying else view.ship.payload_body.global_position
		result.stage = "DELIVER HEAVY LOAD" if carrying else "COLLECT HEAVY LOAD"
		result.cargo = "Cargo aboard: 1 industrial module" if carrying else "Cargo aboard: none · 1 module awaiting pickup"
		result.route = "%s · %s\nJob payment: %.2f credits" % ["Ocean drop-off" if carrying else "Nearby pickup", distance_text(view.ship.global_position.distance_to(target)), job.reward_minor / 100.0]
		result.next = "At the drop-off: stop, then Lower to deliver." if carrying else "Undock, Lower, position the platform under the load, stop, then Raise."
		if carrying and view.ship.deck_height < 2.6:
				result.next = "Lowering at the drop-off. Stay stopped until delivery completes." if view.ship.deck_target == -1.0 and view.heavy_jobs.can_release(view.ship) else "Raise the platform fully before sailing."
	elif view.get("bulk_active") is String and not view.bulk_active.is_empty():
		var bulk_job: Dictionary = preload("res://features/game/progression.gd").bulk_job(view.bulk_active)
		var bulk_port: Node3D = view.bulk_destination()
		result.stage = "DELIVER BULK CARGO"
		result.cargo = "Cargo aboard: " + bulk_job.title
		result.route = "%s · %s\nJob payment: %.2f credits" % [bulk_port.definition.display_name, distance_text(view.ship.global_position.distance_to(bulk_port.berth_anchor.global_position)), bulk_job.reward_minor / 100.0]
		result.next = "Sail to the destination, slow down near the quay, then Dock."
		if view.docking.state(1) == "docked":
			result.next = "Open CARGO and select Deliver cargo at this port." if view.port == bulk_port else "Undock and sail to " + bulk_port.definition.display_name + "."
	elif not job.is_empty():
		var destination: Node3D
		for place: Node3D in view.world_ports:
			if place.definition.id == job.destination_port_id: destination = place
		var aboard: int = 0
		for line: Dictionary in view.ship.state.manifest.lines(): aboard += int(line.quantity)
		result.cargo = "Cargo aboard: %d container%s\nJob: %d container%s" % [aboard, "" if aboard == 1 else "s", job.quantity, "" if job.quantity == 1 else "s"]
		result.route = "%s · %s\nJob payment: %.2f credits" % [destination.definition.display_name, distance_text(view.ship.global_position.distance_to(destination.berth_anchor.global_position)), job.reward_minor / 100.0]
		if view.loading.busy():
			result.stage = "LOADING CARGO"
			result.progress = view.loading.progress_percent()
			result.next = "Loading in progress. Stay docked; cargo appears when loading finishes."
		else:
			result.stage = "DELIVER CONTAINERS"
			result.next = "Sail to the destination, slow down near the quay, then Dock."
			if view.docking.state(1) == "docked":
				result.next = "Open CARGO and select Deliver cargo at this port." if view.port == destination else "Undock and sail to " + destination.definition.display_name + "."
	if view.get("game_mode") == true: game_hints(view, result)
	if is_instance_valid(view.persistence) and not view.persistence.ready_to_save:
		result.stage = "SAVE NEEDS ATTENTION" if view.persistence.blocked else "RESTORING VOYAGE"
		result.next = view.offer_notice if view.persistence.blocked else "Please wait while your voyage is restored."
	return result

## M5, the game only: say the next step with no job in hand, and warn early
## about fuel and hull so a new captain is not surprised by a tow or a sinking.
static func game_hints(view: Node3D, result: Dictionary) -> void:
	var docked: bool = view.docking.state(1) == "docked"
	if result.stage == "NO ACTIVE JOB":
		result.next = "Open CARGO, pick a job and click Accept selected job." if docked else "Sail up to a quay (see the minimap), slow down and click Dock. Jobs are under CARGO."
		var ships: Dictionary = preload("res://features/game/progression.gd").SHIPS
		for kind: String in ships:
			if not view.fleet.has(kind) and view.reward_minor >= int(ships[kind].price_minor):
				result.next += "\nYou can afford the %s: %s." % [ships[kind].name, "open SHIPS" if docked else "dock and open SHIPS"]
				break
	if view.ship.state.fuel_liters < view.ship.definition.fuel_capacity_liters * 0.25:
		result.next += "\nFuel is low. " + ("Click REFUEL before you leave." if docked else "Dock at the nearest port and click REFUEL.")
	if view.ship.state.condition < 0.5:
		result.next += "\nThe hull is badly damaged; at 0% the ship sinks. " + ("Click REPAIR." if docked else "Dock and click REPAIR.")

func refresh(view: Node3D) -> void:
	var data: Dictionary = describe(view)
	heading.text = data.stage
	cargo.text = data.cargo
	route.text = data.route
	route.visible = not route.text.is_empty()
	instruction.text = data.next
	progress.visible = data.progress >= 0
	progress.value = maxf(0, data.progress)
	var values: Dictionary = HandlingFeedback.instruments(view.ship)
	instruments.text = "%.1f kn · %s" % [values.speed_knots, values.direction.capitalize()]
	if view.get("game_mode") == true: instruments.text = game_line(view, values)

## The game's one status line: speed, fuel, money. Hull shows only when damaged.
static func game_line(view: Node3D, values: Dictionary) -> String:
	var text: String = "Speed %.1f kn  ·  Fuel %.0f%%" % [values.speed_knots, 100.0 * values.fuel_liters / maxf(1.0, view.ship.definition.fuel_capacity_liters)]
	if view.ship.state.condition < 0.995: text += "  ·  Hull %.0f%%" % (view.ship.state.condition * 100.0)
	return text + "\nMoney %.2f credits" % (view.reward_minor / 100.0)
