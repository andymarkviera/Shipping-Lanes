extends Control
const DISPLAY = preload("res://features/ui/display_fonts.gd")
const Progression = preload("res://features/game/progression.gd")
## Patch 2.0 item 5: the game's simplified HUD. It lays out what the game scene
## (port_test.gd in game_mode) already owns and adds four small things:
## - the helm bar: an R / N / D throttle slider, the speed in knots and Dock;
## - a notice under the job card that shows for a few seconds and fades;
## - the job hub: one card per offer (what, from, to, pay, Accept).
## It owns no cargo, money or docking state. Test scenes never create it.
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const TOAST_SECONDS: float = 6.0
## Patch 3.2: the port name heading's largest size and the one job-card amount size.
const TITLE_PX: int = 22
const PAY_PX: int = 18
const BOX_COLOURS: Array[Color] = [Color("e2574c"), Color("3d9be0"), Color("ffc940"), Color("7ed957")]
var view: Node3D
var bar: PanelContainer
var slider: HSlider
var knots: Label
## Patch 2.9 item 4: the helm speed, smoothed over about a fifth of a second so
## the whole-knot number does not flicker between two values.
var shown_speed_mps: float = 0.0
var dock_hint: Label
var dragging: bool = false
var toast: PanelContainer
var toast_text: String = ""
var toast_left: float = 0.0
var title: Label
var cards: VBoxContainer
var salute: Label
var salute_left: float = 0.0
var instrument_warning: bool = false
var ships_button: Button
var blaster: Label
## Patch 4.0.3 addendum: flying, the same throttle slider shows the plane's
## lever from 0 to 100% (no reverse), marked 0% / 50% / 100%.
const BOAT_MARKS: Array[String] = ["R", "N", "D"]
const PLANE_MARKS: Array[String] = ["0%", "50%", "100%"]
var plane_mode: bool = false
var marks: Array[Label] = []
## Patch 4.0.4 item 2: the plane's instrument row, in the helm bar over the
## throttle slider while flying (the boat bar's look: cream captions, sunny
## figures in the plain bold face). THR is a 0-100% gauge, then airspeed,
## altitude (with the height over the ground), vertical speed, heading,
## fuel and the gear light. Filled from the plane each frame, shown only
## while flying.
const FLIGHT_CELLS: Array[String] = ["THR", "IAS", "ALT", "V/S", "HDG", "FUEL", "GEAR"]
const COMPASS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const WARN: Color = Color("ff8a7a")
const GEAR_GREEN: Color = Color("7ed957")
const GEAR_RED: Color = Color("ff5a4a")
var flight: HBoxContainer
var flight_values: Dictionary = {}
var flight_captions: Dictionary = {}
var throttle_gauge: Control
var gear_light: Control
var shown_vs_mps: float = 0.0
var shown_throttle: float = 0.0
var gear_state: int = 0
var fuel_low: bool = false
var fitted_title: String = ""

## Patch 4.0.2: the Jetty's blaster line ("" for every other hull).
static func blaster_text(ship: HandlingShip) -> String:
	if ship == null or not HandlingShip.JETTY_BOOST.eligible(ship.definition): return ""
	match ship.boost.phase:
		"charge": return "BLASTER CHARGING..."
		"blast": return "BLASTER BOOST!"
		"cooldown": return "BLASTER %.1f s" % maxf(0.0, HandlingShip.JETTY_BOOST.COOLDOWN_S - ship.boost.clock)
	return "BLASTER READY"

func setup(scene: Node3D) -> void:
	view = scene
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = PLAYFUL.make()
	build_bar()
	build_toast()
	salute = text(self, 32)
	salute.text = "CANNON SALUTE!"
	DISPLAY.plain(salute, Color("ff6a5a"), 32)
	salute.hide()
	arrange_port_card()

func text(parent: Node, size_px: int, colour: Color = Color.WHITE) -> Label:
	var node: Label = Label.new()
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", colour)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

## Bottom centre: [ R ---N--- D ]  12 kn  [Dock]
func build_bar() -> void:
	bar = PanelContainer.new()
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -20
	bar.offset_bottom = -20
	var column: VBoxContainer = VBoxContainer.new()
	bar.add_child(column)
	build_flight(column)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var throttle: VBoxContainer = VBoxContainer.new()
	throttle.custom_minimum_size.x = 230
	row.add_child(throttle)
	slider = HSlider.new()
	slider.min_value = -1.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.tick_count = 3
	slider.ticks_on_borders = true
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size.y = 24
	# A pointer, not a fill: neutral must not look half full.
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	slider.drag_started.connect(func() -> void: dragging = true)
	slider.drag_ended.connect(func(_changed: bool) -> void: dragging = false)
	slider.value_changed.connect(order)
	throttle.add_child(slider)
	var letters: HBoxContainer = HBoxContainer.new()
	throttle.add_child(letters)
	for letter: String in BOAT_MARKS:
		var mark: Label = text(letters, 18, PLAYFUL.CREAM)
		marks.append(mark)
		mark.text = letter
		mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mark.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][letters.get_child_count() - 1]
	knots = text(row, 28, PLAYFUL.SUN)
	DISPLAY.plain(knots, PLAYFUL.SUN, 28)
	knots.custom_minimum_size.x = 92
	knots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	knots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for item: Button in [view.dock_button, view.cancel_button]:
		item.reparent(row, false)
		item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.dock_button.custom_minimum_size = Vector2(104, 46)
	dock_hint = text(column, 14, PLAYFUL.CREAM)
	DISPLAY.plain(dock_hint, Color("ff8a7a"), 14)
	dock_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Patch 4.0.2: the Jetty's blaster boost state, under the helm bar.
	blaster = text(column, 16, PLAYFUL.SUN)
	DISPLAY.plain(blaster, Color("5ff2e0"), 16)
	blaster.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blaster.hide()

## Patch 4.0.4 item 2: the plane instruments, one cell each (caption over
## figure), with a drawn throttle gauge and a gear light.
func build_flight(column: VBoxContainer) -> void:
	flight = HBoxContainer.new()
	flight.name = "FlightInstruments"
	flight.add_theme_constant_override("separation", 18)
	flight.alignment = BoxContainer.ALIGNMENT_CENTER
	flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(flight)
	for key: String in FLIGHT_CELLS:
		var cell: VBoxContainer = VBoxContainer.new()
		cell.name = key.replace("/", "")
		cell.add_theme_constant_override("separation", 0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flight.add_child(cell)
		var caption: Label = text(cell, 12, PLAYFUL.CREAM)
		DISPLAY.plain(caption, PLAYFUL.CREAM, 12)
		caption.text = key
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flight_captions[key] = caption
		if key == "THR":
			throttle_gauge = Control.new()
			throttle_gauge.name = "ThrottleGauge"
			throttle_gauge.custom_minimum_size = Vector2(64, 10)
			throttle_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			throttle_gauge.draw.connect(draw_throttle)
			cell.add_child(throttle_gauge)
		if key == "GEAR":
			gear_light = Control.new()
			gear_light.name = "GearLight"
			gear_light.custom_minimum_size = Vector2(56, 10)
			gear_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gear_light.draw.connect(draw_gear)
			cell.add_child(gear_light)
		var value: Label = text(cell, 20, PLAYFUL.SUN)
		DISPLAY.plain(value, PLAYFUL.SUN, 20)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.custom_minimum_size.x = 64 if key in ["THR", "V/S", "GEAR"] else 78
		flight_values[key] = value
	flight.hide()

## The THR gauge: a cream-rimmed bar filled sunny to the lever (0-100%).
func draw_throttle() -> void:
	var area: Rect2 = Rect2(Vector2(2, 1), throttle_gauge.size - Vector2(4, 2))
	throttle_gauge.draw_rect(area, PLAYFUL.INK)
	var fill: Rect2 = Rect2(area.position, Vector2(area.size.x * clampf(shown_throttle, 0.0, 1.0), area.size.y))
	if fill.size.x > 0.5: throttle_gauge.draw_rect(fill, PLAYFUL.SUN)
	throttle_gauge.draw_rect(area, PLAYFUL.CREAM, false, 1.5)
	throttle_gauge.draw_line(Vector2(area.get_center().x, area.position.y), Vector2(area.get_center().x, area.end.y), Color(PLAYFUL.CREAM, 0.6), 1.0)

## The gear light: green with the gear down, red with it up (blinking when
## the "Press G" nudge shows).
func draw_gear() -> void:
	var colour: Color = GEAR_GREEN if gear_state == 1 else GEAR_RED
	if gear_state == 2 and int(Time.get_ticks_msec() / 300) % 2 == 1: colour = Color(GEAR_RED, 0.25)
	var centre: Vector2 = gear_light.size * 0.5
	gear_light.draw_circle(centre, 5.0, colour)
	gear_light.draw_arc(centre, 5.0, 0.0, TAU, 16, PLAYFUL.INK, 1.5, true)

## The compass heading, 0-359 degrees, and its point, from FlightModel's
## heading (atan2(forward.x, forward.z)). North is +Z and east is -X, so the
## bearing turns the other way round.
static func compass(heading_rad: float) -> String:
	var degrees: int = posmod(roundi(-rad_to_deg(heading_rad)), 360)
	return "%03d° %s" % [degrees, COMPASS[posmod(roundi(degrees / 45.0), 8)]]

## Fills the instrument row from the plane (Patch 4.0.4 item 2).
func refresh_flight(aviation: Node, delta: float) -> void:
	var model: RefCounted = aviation.model
	var entry: Dictionary = aviation.plane_entry()
	var throttle: float = clampf(float(aviation.lever), 0.0, 1.0)
	if not is_equal_approx(throttle, shown_throttle):
		shown_throttle = throttle
		throttle_gauge.queue_redraw()
	flight_values.THR.text = "%d%%" % roundi(throttle * 100.0)
	flight_values.IAS.text = "%d kn" % roundi(model.airspeed() * 3600.0 / 1852.0)
	flight_values.ALT.text = "%s m" % Progression.thousands(maxi(0, roundi(model.position.y)))
	flight_captions.ALT.text = "ALT · AGL %s" % Progression.thousands(maxi(0, roundi(model.agl_m)))
	shown_vs_mps = lerpf(shown_vs_mps, model.velocity.y, 1.0 - exp(-4.0 * maxf(delta, 0.0)))
	var vs: float = 0.0 if model.on_ground or absf(shown_vs_mps) < 0.05 else shown_vs_mps
	flight_values["V/S"].text = "%s%.1f" % ["+" if vs > 0.0 else "", vs]
	flight_values.HDG.text = compass(model.heading())
	var share: float = model.fuel_l / maxf(1.0, float(entry.get("fuel_l", 1.0)))
	flight_values.FUEL.text = "%d%%" % roundi(share * 100.0)
	var low: bool = share < 0.2
	if low != fuel_low:
		fuel_low = low
		DISPLAY.plain(flight_values.FUEL, WARN if low else PLAYFUL.SUN, 20)
	var gear: int = 1 if model.gear_down else (2 if aviation.nudge else 0)
	flight_values.GEAR.text = "DOWN" if model.gear_down else "UP"
	if gear != gear_state or gear == 2:
		gear_state = gear
		gear_light.queue_redraw()

func build_toast() -> void:
	toast = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	view.loading_text.reparent(toast, false)
	view.loading_text.custom_minimum_size.x = 290
	view.loading_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view.loading_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## The old top-left panel becomes the port card: shown only while docked (or
## while a heavy job needs its Lower and Raise buttons).
func arrange_port_card() -> void:
	var stack: Node = view.details.get_parent()
	# Patch 3.2: sprite lettering only for the port name, the money and the card title.
	title = text(stack, TITLE_PX, PLAYFUL.SUN)
	DISPLAY.apply(title)
	title.clip_text = true
	DISPLAY.apply(view.voyage_hud.money, "gold")
	DISPLAY.apply(view.voyage_hud.heading)
	DISPLAY.plain(view.details, Color.WHITE)
	DISPLAY.plain(view.navigation, Color.WHITE)

	stack.move_child(title, 0)
	view.readiness.hide()
	# The old button row held Dock, Cancel and Main menu. Dock and Cancel moved
	# to the helm bar; the main menu is behind Esc.
	view.switch_button.get_parent().hide()
	var tabs: Node = view.refuel_button.get_parent()
	for item: Node in tabs.get_children():
		if item is Button and item.text in ["CARGO", "Close services"]: item.hide()
		if item is Button and item.text == "Ships": ships_button = item
	view.offer_text.hide()
	view.jobs_list.hide()
	view.accept_button.hide()
	view.deliver_button.text = "Deliver"
	view.cancel_load_button.text = "Cancel Loading"
	cards = VBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	view.jobs_panel.add_child(cards)
	view.jobs_panel.move_child(cards, 0)

## Patch 4.0.3 addendum: the throttle slider's range and marks follow the
## craft: -1..1 with R / N / D on a boat, 0..1 with 0% / 50% / 100% flying.
func set_plane_mode(air: bool) -> void:
	if air == plane_mode: return
	plane_mode = air
	slider.set_block_signals(true)
	slider.min_value = 0.0 if air else -1.0
	slider.set_block_signals(false)
	var words: Array[String] = PLANE_MARKS if air else BOAT_MARKS
	for index: int in marks.size(): marks[index].text = words[index]

func slider_order(value: float) -> float:
	var tuning: ShipDefinition = view.ship.definition
	return value * (tuning.forward_throttle_limit if value >= 0.0 else tuning.reverse_throttle_limit)

## The slider is a real control: drag or click it to set the engine order.
func order(value: float) -> void:
	# Patch 4.0.3 addendum: flying, the slider is the plane's throttle lever
	# (0-100%, no reverse); Shift / Ctrl move the same lever.
	if plane_mode:
		if is_instance_valid(view.get("aviation")): view.aviation.lever = clampf(value, 0.0, 1.0)
		return
	if not is_instance_valid(view.ship) or not view.ship.helm_available(): return
	if view.runtime_role == "client":
		view.network_runtime.throttle = 0.0 if absf(value) < 0.06 else slider_order(value)
		return
	view.ship.command_throttle(0.0 if absf(value) < 0.06 else slider_order(value))

## One card per offer. Called by the scene whenever its job list changes.
func rebuild_cards() -> void:
	if cards == null: return
	for old: Node in cards.get_children():
		cards.remove_child(old)
		old.queue_free()
	var from: String = view.port.definition.display_name
	for job: Dictionary in view.job_cards:
		job_card(cards, str(job.kind), int(job.count), str(job.what), "%s → %s" % [from, job.to], "", int(job.pay), take.bind(str(job.id)))

## Patch 4.0.3 item 6: one job card, shared by the boat and the plane job
## boards: the cargo picture, what, the route, an optional trip line (the
## plane board's km, minutes and fuel), the gold pay and Accept. The edge
## lights up gold under the mouse.
func job_card(parent: Node, kind: String, count: int, what_text: String, route_text: String, trip_text: String, pay_minor: int, action: Callable) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = "JobCard"
	var rest: StyleBoxFlat = PLAYFUL.box(PLAYFUL.DEEP, PLAYFUL.INK, 12, 2, 8)
	var lit: StyleBoxFlat = PLAYFUL.box(PLAYFUL.DEEP, PLAYFUL.SUN, 12, 2, 8)
	card.add_theme_stylebox_override("panel", rest)
	card.set_meta("rest_style", rest)
	card.set_meta("hover_style", lit)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.mouse_entered.connect(func() -> void: card.add_theme_stylebox_override("panel", lit))
	card.mouse_exited.connect(func() -> void: card.add_theme_stylebox_override("panel", rest))
	parent.add_child(card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var art: Control = Control.new()
	art.name = "CargoArt"
	art.custom_minimum_size = Vector2(58, 44)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(draw_cargo.bind(art, kind, count))
	row.add_child(art)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.custom_minimum_size.x = 210
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var what: Label = text(words, 18)
	DISPLAY.plain(what, Color.WHITE, 18)
	what.text = what_text
	var route: Label = text(words, 13, PLAYFUL.CREAM)
	DISPLAY.plain(route, PLAYFUL.CREAM, 13)
	route.text = route_text
	if not trip_text.is_empty():
		var trip: Label = text(words, 13, PLAYFUL.CREAM)
		DISPLAY.plain(trip, PLAYFUL.CREAM, 13)
		trip.name = "Trip"
		trip.text = trip_text
	# Patch 3.2: the amount is gold in the same plain bold face, one size.
	var pay: Label = text(row, PAY_PX, PLAYFUL.SUN)
	DISPLAY.plain(pay, PLAYFUL.SUN, PAY_PX)
	pay.name = "Pay"
	pay.text = "+%.2f" % (pay_minor / 100.0)
	pay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var accept: Button = view.button(row, "Accept", action)
	accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return card

func take(id: String) -> void:
	view.selected_offer = id
	view.accept_selected()

## A little picture of the load: a stack of boxes, a heap, or one big module.
func draw_cargo(art: Control, kind: String, count: int) -> void:
	var floor_y: float = art.size.y - 4
	if kind == "bulk":
		art.draw_colored_polygon(PackedVector2Array([Vector2(2, floor_y), Vector2(20, floor_y - 26), Vector2(34, floor_y - 18), Vector2(42, floor_y - 30), Vector2(56, floor_y)]), Color("c9a063"))
		art.draw_polyline(PackedVector2Array([Vector2(2, floor_y), Vector2(20, floor_y - 26), Vector2(34, floor_y - 18), Vector2(42, floor_y - 30), Vector2(56, floor_y), Vector2(2, floor_y)]), PLAYFUL.INK, 2, true)
		return
	# Patch 4.0.3 item 6: passengers are a row of little people, packages a
	# pile of brown parcels.
	if kind == "pax":
		for index: int in clampi(count, 1, 5):
			var x: float = 8.0 + index * 10.0
			art.draw_circle(Vector2(x, floor_y - 24), 4.0, BOX_COLOURS[index % BOX_COLOURS.size()].lightened(0.3))
			art.draw_rect(Rect2(x - 4, floor_y - 19, 8, 19), BOX_COLOURS[index % BOX_COLOURS.size()])
			art.draw_rect(Rect2(x - 4, floor_y - 19, 8, 19), PLAYFUL.INK, false, 1.5)
		return
	if kind == "pkg":
		for index: int in clampi(floori(count / 4.0), 1, 10):
			var parcel: Rect2 = Rect2(4 + (index % 5) * 10, floor_y - 12 - floori(index / 5.0) * 13, 9, 12)
			art.draw_rect(parcel, Color("c08a52"))
			art.draw_rect(parcel, PLAYFUL.INK, false, 1.5)
			art.draw_line(parcel.position + Vector2(4.5, 0), parcel.position + Vector2(4.5, 12), PLAYFUL.INK, 1.0)
		return
	if kind == "heavy":
		art.draw_rect(Rect2(8, floor_y - 30, 42, 30), Color("9fb2c4"))
		art.draw_rect(Rect2(8, floor_y - 30, 42, 30), PLAYFUL.INK, false, 2)
		art.draw_line(Vector2(29, floor_y - 30), Vector2(29, 2), PLAYFUL.INK, 2)
		return
	# Up to 15 boxes, five to a row from the bottom: a bigger job is a taller stack.
	for index: int in clampi(count, 1, 15):
		var box: Rect2 = Rect2(2 + (index % 5) * 11, floor_y - 12 - floori(index / 5.0) * 13, 10, 12)
		art.draw_rect(box, BOX_COLOURS[(index * 3 + floori(index / 5.0)) % BOX_COLOURS.size()])
		art.draw_rect(box, PLAYFUL.INK, false, 1.5)

func show_salute() -> void:
	salute_left = 2.0

func refresh(delta: float) -> void:
	salute_left = maxf(0.0, salute_left - delta)
	salute.visible = salute_left > 0.0
	salute.position = Vector2((size.x - salute.size.x) * 0.5, 100)
	salute.modulate.a = minf(1.0, salute_left)
	var ship: HandlingShip = view.ship
	var warn: bool = ship.state.fuel_liters < ship.definition.fuel_capacity_liters * 0.25 or ship.state.condition < 0.5
	if warn != instrument_warning:
		instrument_warning = warn
		if warn: DISPLAY.plain(view.voyage_hud.instruments, Color("ff8a7a"))
		else: DISPLAY.clear(view.voyage_hud.instruments)
	var state: String = view.docking.state(view.owner_id)
	var docked: bool = state == "docked"
	# Helm bar.
	# Speed over ground (what the hull really covers), converted at the exact
	# 1 kn = 1852 m / 3600 s; one world unit is one metre.
	shown_speed_mps = lerpf(shown_speed_mps, ship.ground_speed_mps, 1.0 - exp(-5.0 * maxf(delta, 0.0)))
	if ship.ground_speed_mps < 0.05 and shown_speed_mps < 0.3: shown_speed_mps = 0.0
	knots.text = "%d kn" % roundi(shown_speed_mps * 3600.0 / 1852.0)
	# Patch 4.0: flying, the bar shows airspeed, height and throttle instead.
	var air: bool = view.has_method("flying") and view.flying()
	set_plane_mode(air)
	# Patch 4.0.4 item 2: flying, the big figure is the airspeed and the
	# instrument row above the slider carries the rest.
	knots.custom_minimum_size.x = 92
	flight.visible = air
	if air:
		knots.text = view.aviation.helm_text()
		refresh_flight(view.aviation, delta)
	var commanded: float = ship.commanded_throttle
	if air:
		if not dragging: slider.set_value_no_signal(clampf(float(view.aviation.lever), 0.0, 1.0))
		slider.editable = true
	else:
		if not dragging:
			slider.set_value_no_signal(commanded / maxf(0.01, ship.definition.forward_throttle_limit if commanded >= 0.0 else ship.definition.reverse_throttle_limit))
		slider.editable = ship.helm_available()
	var status: Dictionary = view.dock_status
	var near: bool = state in ["underway", "approaching"] and status.get("code", "") in ["SPEED", "BLOCKED"] and not air
	view.dock_button.visible = not air
	dock_hint.text = str(status.get("message", "")) if near else ""
	dock_hint.visible = near
	blaster.text = "" if air else blaster_text(ship)
	blaster.visible = not blaster.text.is_empty()
	view.dock_button.tooltip_text = "" if not view.dock_button.disabled or docked else "Sail up to a berth and slow down."
	# Patch 2.5 item 8: no key hints on the HUD. They live in Esc > CONTROLS.
	# Notice: shows when it changes, then fades. Loading progress stays up.
	var words: String = view.loading_text.text
	if words != toast_text:
		var lower: String = words.to_lower()
		if "paid" in lower or "credits" in lower:
			DISPLAY.plain(view.loading_text, PLAYFUL.SUN)
		elif "cannot" in lower or "not enough" in lower or "failed" in lower or "collision" in lower or "sank" in lower:
			DISPLAY.plain(view.loading_text, Color("ff8a7a"))
		else:
			DISPLAY.clear(view.loading_text)
		toast_text = words
		toast_left = TOAST_SECONDS
	toast_left = maxf(0.0, toast_left - delta)
	var held: bool = view.loading.busy() or (is_instance_valid(view.persistence) and view.persistence.blocked)
	toast.visible = not words.is_empty() and (held or toast_left > 0.0)
	toast.modulate.a = 1.0 if held else clampf(toast_left, 0.0, 1.0)
	# It sits under the job card on the right, clear of the port card and the helm.
	toast.reset_size()
	toast.position = Vector2(size.x - 20 - toast.size.x, view.voyage_hud.position.y + view.voyage_hud.size.y + 10)
	# Port card.
	view.port_panel.visible = docked or view.heavy_controls.visible or DevMode.enabled
	title.text = view.port.definition.display_name.to_upper()
	title.visible = docked
	# Patch 3.2: the heading fits its card (it shrinks rather than overflows).
	# Patch 4.0.4 item 1: fitted when the name or the card width changes
	# (each fit re-sets a theme override, which re-lays the label out).
	var fit_key: String = "%s|%d" % [title.text, roundi(view.port_panel.size.x)]
	if docked and fit_key != fitted_title:
		fitted_title = fit_key
		DISPLAY.fit(title, maxf(160.0, view.port_panel.size.x - 28.0), TITLE_PX)
	view.navigation.visible = not view.navigation.text.is_empty()
	view.jobs_panel.visible = docked and not view.ships_panel.visible
	if ships_button != null: ships_button.text = "Jobs" if view.ships_panel.visible else "Ships"
	cards.visible = view.accept_reason().is_empty()
	# Deliver shows only where it works; elsewhere the line below says where to go.
	view.deliver_button.visible = view.abandon_button.visible and not view.deliver_button.disabled
	view.receipt_label.hide()
