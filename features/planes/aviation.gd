extends Node
## Patch 4.0 items 8-13: one captain's planes, in the game scene (port_test.gd
## in game_mode). It owns the planes a captain has bought, which one is
## active, whether they are flying a plane or sailing their boat, the airport
## they are at and their plane job, and it runs the flight while they fly.
##
## Authority: in the server's player simulation ("server") and in local and
## debug play ("local") this node is the authority. It steps FlightModel with
## the captain's inputs, takes money for planes, fuel, repairs, fines and
## crash bills (always capped by the wallet, so wallet = earned - spent holds)
## and pays plane jobs (banked, like bulk pay) plus their XP (Levels). On an
## online client ("client") it never changes money, XP, ownership or position:
## it shows the server's state, predicts its own plane with the same physics
## and sends actions through the network runtime.
##
## While a captain flies, their boat is laid up out of sight: no collision, no
## physics, kept under the plane at sea level so everything that follows the
## boat (the sea, the biomes, the minimap, relevance) follows the plane.
## "Switch to Boat" puts it back in the water at the port nearest the plane.
## Patch 4.0.7 item 4: runways in use stop a hovering Jetty.
const JETTY_LAND = preload("res://features/ships/jetty_land.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Airports = preload("res://features/planes/airports.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Flight = preload("res://features/planes/flight_model.gd")
const Look = preload("res://features/planes/plane_look.gd")
const Levels = preload("res://features/game/levels.gd")
const Progression = preload("res://features/game/progression.gd")
const DISPLAY = preload("res://features/ui/display_fonts.gd")
const PLAYFUL = preload("res://features/ui/playful_theme.gd")
const PlaneHangar = preload("res://features/planes/plane_hangar.gd")
## Patch 4.0 item 12: below this height above the ground, away from airports,
## the low-altitude warning sounds; LOW_GRACE_S in a row costs LOW_FINE_MINOR.
const SAFE_AGL_M: float = 150.0
const AIRPORT_ZONE_M: float = 2600.0
const LOW_GRACE_S: float = 10.0
const LOW_FINE_MINOR: int = 100000
## Slower than this on a runway counts as stopped at the airport.
const STOPPED_MPS: float = 2.0
const LEVER_RATE: float = 0.6
## Patch 4.0.1 item 2: a touchdown sinking faster than this costs condition.
const FIRM_SINK_MPS: float = 3.5
## Patch 4.0.3 item 1: Shift / Ctrl move the throttle lever this much a
## second. A barrel roll (Q / E) that has not come round within BARREL_MAX_S
## stops (the bank then rolls back the short way); it needs BARREL_AGL_M of
## air under the plane.
const BARREL_MAX_S: float = 6.0
const BARREL_AGL_M: float = 40.0
## Patch 4.0.1 item 3: after a crash the camera stays on the wreck (the
## explosion, the fireball, smoke and debris, the camera slowly orbiting and
## pulling back) for CRASH_VIEW_S seconds before the respawned plane is shown.
## The server still respawns at once (bill, lost cargo, the plane parked at
## the nearest airport); only the view waits, and the captain's controls are
## held at idle meanwhile so the parked plane stays where the server put it.
const CRASH_VIEW_S: float = 4.0
## Patch 4.0.2 item 6: a belly landing (gear up, not too hard) bills this
## share of a rebuild at once, instead of a crash.
const BELLY_REPAIR_PERCENT: int = 35
## The gear nudge: within GEAR_NUDGE_M of a runway's threshold (either end),
## below GEAR_NUDGE_AGL_M and descending, with the gear up: "Press G — Gear
## down", pulsing, and one short chime.
const GEAR_NUDGE_M: float = 2000.0
const GEAR_NUDGE_AGL_M: float = 300.0
const GEAR_NUDGE_SINK_MPS: float = 0.3

var view: Node3D
var planes: Dictionary = {}
var plane_kind: String = ""
var mode: String = "boat"
var airport: int = 0
var job_id: String = ""
var model: RefCounted
## The captain's latest inputs (Patch 4.0.3 item 1, the keys): throttle
## 0..1 (negative: Space, the brakes), pitch (W / S), roll (A / D) and yaw
## (the barrel roll, Q / E) in -1..1, gear. The helm frame sends them as
## they are; FlightModel flies the plane from them on both sides.
var order: Dictionary = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "gear": 1.0}
var lever: float = 0.0
## Patch 4.0.2 item 6: the gear lever (1 down, 0 up), toggled by G; sent
## with the helm. The model moves the gear when it changes.
var gear_order: float = 1.0
## The gear nudge is showing, and its chime has played for this approach.
var nudge: bool = false
var nudge_chimed: bool = false
var belly_landings: int = 0
## Patch 4.0.2 item 7: the planes hangar (features/planes/plane_hangar.gd).
var hangar: CanvasLayer
var nudge_label: Label
## Patch 4.0.3 item 1: the barrel roll under way (-1 left, +1 right, 0
## none), whether it has passed upside down, its seconds, and whether Q / E
## were held last frame (a roll starts on the press).
var barrel: float = 0.0
var barrel_over: bool = false
var barrel_s: float = 0.0
var barrel_key: float = 0.0
## Seconds of the crash view left (client and local), and the wreck.
var crash_view_left: float = 0.0
var crash_view_at: Vector3 = Vector3.ZERO
var crash_view_from: Vector3 = Vector3.ZERO
var low_seconds: float = 0.0
var warning: bool = false
var crashes: int = 0
var fines: int = 0
## Patch 4.0 item 16: the admin "debug" overlay and the local test mode fly
## every plane at any level.
var debug_unlocked: bool = false
# Presentation (local play and online clients).
var plane_node: Node3D
var shown_kind: String = ""
var chase: Camera3D
var chase_ready: bool = false
var airport_nodes: Array[Node3D] = []
var warn_player: AudioStreamPlayer
var boom_player: AudioStreamPlayer
## Patch 4.0.5 item 3: the plane's own engine sound (PlaneEngineSound), one
## per plane kind, rebuilt when the plane changes.
var engine_sound: Node3D
const EngineSound = preload("res://features/planes/plane_engine_sound.gd")
var seen_crashes: int = 0
var last_crash_at: Vector3 = Vector3.ZERO
var card: PanelContainer
var card_title: Label
var card_info: Label
var card_jobs: VBoxContainer
var card_buttons: Dictionary = {}
var shown_board: Array = []
var board_key: String = ""
var menu: PanelContainer
var menu_rows: Dictionary = {}
var menu_wallet: Label
var port_row: HBoxContainer
var port_buttons: Dictionary = {}
var banner: Label
var marks: FlightMarks
# Client prediction: inputs since the last acknowledged server state.
var history: Array[Dictionary] = []
var offset: Vector3 = Vector3.ZERO
var previous: Transform3D = Transform3D.IDENTITY
var server_state: Dictionary = {}
var snaps: int = 0
var corrections: int = 0

func role() -> String:
	return str(view.runtime_role)

func authority() -> bool:
	return role() in ["server", "local"]

func level() -> int:
	return Levels.level_for(int(view.xp))

func flying() -> bool:
	return mode == "plane" and model != null

func unlocked() -> bool:
	return debug_unlocked or level() >= Levels.PLANE_UNLOCK_LEVEL

func plane_entry() -> Dictionary:
	return Planes.PLANES.get(plane_kind, {})

func condition() -> float:
	return float(planes.get(plane_kind, {}).get("condition", 1.0))

## The airport the plane stands stopped on, or -1.
func stopped_at() -> int:
	if not flying() or not model.on_ground or model.airspeed() > STOPPED_MPS: return -1
	# Patch 4.0.1: anywhere on the airfield (the runway or the grass beside it).
	return Airports.airfield_at(model.position)

# --- Rules (the same reasons on client and server) -----------------------------

## Why "Switch to Plane" cannot be used now, or "".
func switch_reason() -> String:
	if flying(): return "You are already flying."
	if not view.can_switch() or view.cranes_busy(): return "Finish or cancel your current job before switching to a plane."
	if view.docking.state(view.owner_id) != "docked": return "Dock at a port to switch to your plane."
	if not unlocked(): return "Planes unlock at level %d. You are level %d." % [Levels.PLANE_UNLOCK_LEVEL, level()]
	if planes.is_empty(): return "You have no plane yet. Open Planes to buy one."
	return ""

## Why "Switch to Boat" cannot be used now, or "".
func boat_reason() -> String:
	if not flying(): return "You are sailing your boat."
	if stopped_at() < 0: return "Land and stop at an airport first."
	if not job_id.is_empty(): return "Deliver your plane job first."
	return ""

func buy_reason(kind: String) -> String:
	if not Planes.PLANES.has(kind): return "Unknown plane."
	if planes.has(kind): return ""
	if not unlocked(): return "Planes unlock at level %d." % Levels.PLANE_UNLOCK_LEVEL
	if not (stopped_at() >= 0 or (not flying() and view.docking.state(view.owner_id) == "docked")): return "Buy planes at a port or an airport."
	if int(view.reward_minor) < int(Planes.PLANES[kind].price_minor): return "You need %s more credits." % credits(int(Planes.PLANES[kind].price_minor) - int(view.reward_minor))
	return ""

func select_reason(kind: String) -> String:
	if not planes.has(kind): return "Buy it first."
	if kind == plane_kind: return "This is your active plane."
	if flying() and stopped_at() < 0: return "Land and stop at an airport to change planes."
	if not job_id.is_empty(): return "Deliver your plane job first."
	return ""

func service_reason() -> String:
	if stopped_at() < 0: return "Land and stop at an airport."
	return ""

func accept_reason(id: String) -> String:
	var here: int = stopped_at()
	if here < 0: return "Land and stop at an airport to take plane jobs."
	if not job_id.is_empty(): return "Deliver your current plane job first."
	var picked: Dictionary = Jobs.job(id)
	if picked.is_empty() or int(picked.origin) != here: return "That job is not offered here."
	if int(plane_entry().get("capacity", 0)) <= 0: return "Your %s carries no cargo." % plane_entry().name
	if not plane_entry().jobs.has(picked.kind) or int(picked.capacity) > int(plane_entry().capacity): return "Your plane cannot carry that."
	return ""

func deliver_reason() -> String:
	if job_id.is_empty(): return "No plane job aboard."
	var here: int = stopped_at()
	if here < 0: return "Land and stop at %s." % Airports.all()[int(Jobs.job(job_id).destination)].name
	if here != int(Jobs.job(job_id).destination): return "This job belongs at %s." % Airports.all()[int(Jobs.job(job_id).destination)].name
	return ""

static func credits(minor: int) -> String:
	return "%s.%02d" % [Progression.thousands(minor / 100), minor % 100]

# --- Authority actions ---------------------------------------------------------

func say(text: String) -> void:
	view.offer_notice = text

## Patch 4.0 item 13: from a port to the nearest airport, in the active plane.
func switch_to_plane() -> bool:
	if view.network_action("plane_switch"): return false
	var reason: String = switch_reason()
	if not reason.is_empty():
		say(reason)
		return false
	if plane_kind.is_empty() or not planes.has(plane_kind): plane_kind = first_plane()
	var ship: HandlingShip = view.ship
	view.fleet[view.ship_kind] = {"fuel": clampf(ship.state.fuel_liters / maxf(1.0, ship.definition.fuel_capacity_liters), 0.0, 1.0), "condition": clampf(ship.state.condition, 0.0, 1.0)}
	airport = maxi(0, Airports.nearest(ship.global_position))
	view.docking.disconnect_owner(view.owner_id)
	lay_up_boat()
	start_plane(airport)
	view.bind_port()
	# Patch 4.0.5 item 1: the controller's buttons when it was used last.
	say("Now flying your %s from %s. %s for full throttle, then %s to lift off at %d kn." % [plane_entry().name, Airports.all()[airport].name,
		Gamepad.pick("Shift", Gamepad.glyph("RT")), Gamepad.pick("W", "[L-stick] up"), roundi(float(plane_entry().rotate_mps) * 1.944)])
	return true

func first_plane() -> String:
	for kind: String in Planes.ORDER:
		if planes.has(kind): return kind
	return ""

## The boat leaves the water while its captain flies.
func lay_up_boat() -> void:
	var ship: HandlingShip = view.ship
	ship.zero_throttle()
	ship.actual_throttle = 0.0
	ship.velocity = Vector3.ZERO
	ship.collision_layer = 0
	ship.collision_mask = 0
	ship.set_physics_process(false)
	ship.visible = false
	if is_instance_valid(view.wake): view.wake.visible = false
	if is_instance_valid(view.helm):
		view.helm.process_mode = Node.PROCESS_MODE_DISABLED
		view.helm.notice.panel.hide()

func start_plane(index: int) -> void:
	var stored: Dictionary = planes.get(plane_kind, {"fuel": 1.0, "condition": 1.0})
	model = Flight.make(plane_kind, Airports.start_pose(index), float(stored.fuel) * float(plane_entry().fuel_l))
	mode = "plane"
	airport = index
	low_seconds = 0.0
	warning = false
	lever = 0.0
	barrel = 0.0
	barrel_key = 0.0
	gear_order = 1.0
	nudge_chimed = false
	order = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "gear": 1.0}
	follow_boat()

## The parked boat stays under the plane (sea level, upright) so the sea and
## everything that follows the boat follows the plane.
func follow_boat() -> void:
	var ship: HandlingShip = view.ship
	if not is_instance_valid(ship) or model == null: return
	var anchor: Vector3 = view_anchor()
	var at: Vector3 = Vector3(anchor.x, 0.0, anchor.z)
	var jump: Vector3 = at - ship.global_position if ship.is_inside_tree() else Vector3.ZERO
	if ship.is_inside_tree(): ship.global_transform = Transform3D(Basis(Vector3.UP, model.heading()), at)
	else: ship.transform = Transform3D(Basis(Vector3.UP, model.heading()), at)
	if jump.length() > 1500.0 and role() == "local": view.shift_presentation(jump)

## Where the view (the laid-up boat, the sea, the camera) is centred: the
## wreck during the crash view, the plane otherwise.
func view_anchor() -> Vector3:
	if crash_view_left > 0.0: return crash_view_at
	return model.position if model != null else Vector3.ZERO

func in_crash_view() -> bool:
	return crash_view_left > 0.0

## Patch 4.0 item 13: back to the boat, in the water at the port nearest the plane.
func switch_to_boat() -> bool:
	if view.network_action("boat_switch"): return false
	var reason: String = boat_reason()
	if not reason.is_empty():
		say(reason)
		return false
	store_plane()
	var position: Vector3 = model.position
	var best: int = 0
	var best_distance: float = INF
	for index: int in view.world_ports.size():
		var distance: float = Progression.short_way(view.world_ports[index].global_position - position).length()
		if distance < best_distance:
			best_distance = distance
			best = index
	airport = stopped_at()
	var keep_mode: String = mode
	mode = "boat"
	model = null
	if not view.select_port(best):
		mode = keep_mode
		start_plane(airport)
		say("No room at the port right now; try again in a moment.")
		return false
	var stored: Dictionary = view.fleet.get(view.ship_kind, {"fuel": 1.0, "condition": 1.0})
	view.ship.state.fuel_liters = float(stored.fuel) * view.ship.definition.fuel_capacity_liters
	view.ship.state.condition = float(stored.condition)
	if is_instance_valid(view.helm): view.helm.process_mode = Node.PROCESS_MODE_INHERIT
	say("Back aboard your %s at %s." % [Progression.SHIPS[view.ship_kind].name, view.port.definition.display_name])
	return true

func store_plane() -> void:
	if model == null or plane_kind.is_empty(): return
	planes[plane_kind] = {"fuel": clampf(model.fuel_l / maxf(1.0, float(plane_entry().fuel_l)), 0.0, 1.0), "condition": condition()}

func buy(kind: String) -> bool:
	if view.network_action("plane_buy", kind): return false
	var reason: String = buy_reason(kind)
	if not reason.is_empty() or planes.has(kind):
		say(reason if not reason.is_empty() else "You already own the %s." % Planes.PLANES[kind].name)
		return false
	view.pay(int(Planes.PLANES[kind].price_minor))
	planes[kind] = {"fuel": 1.0, "condition": 1.0}
	if plane_kind.is_empty(): plane_kind = kind
	say("Bought the %s for %s credits." % [Planes.PLANES[kind].name, credits(int(Planes.PLANES[kind].price_minor))])
	return true

func select(kind: String) -> bool:
	if view.network_action("plane_select", kind): return false
	var reason: String = select_reason(kind)
	if not reason.is_empty():
		say(reason)
		return false
	if flying():
		store_plane()
		var here: int = stopped_at()
		plane_kind = kind
		start_plane(here)
	else:
		plane_kind = kind
	say("Your active plane is now the %s." % Planes.PLANES[kind].name)
	return true

func refuel() -> bool:
	if view.network_action("plane_refuel"): return false
	var reason: String = service_reason()
	if not reason.is_empty():
		say(reason)
		return false
	var room: float = float(plane_entry().fuel_l) - model.fuel_l
	var litres: float = minf(room, float(view.reward_minor) / Planes.FUEL_MINOR_PER_LITER)
	if room < 0.05: say("The tank is full.")
	elif litres < 0.05: say("Not enough money for fuel.")
	else:
		var cost: int = mini(int(view.reward_minor), ceili(litres * Planes.FUEL_MINOR_PER_LITER))
		view.pay(cost)
		model.fuel_l += litres
		store_plane()
		say("Refueled %.1f L for %s credits." % [litres, credits(cost)])
	return true

func refuel_price() -> int:
	if model == null: return 0
	var litres: float = minf(float(plane_entry().fuel_l) - model.fuel_l, float(view.reward_minor) / Planes.FUEL_MINOR_PER_LITER)
	return ceili(maxf(litres, 0.0) * Planes.FUEL_MINOR_PER_LITER)

func repair_percent() -> int:
	return ceili((1.0 - condition()) * 100.0 - 0.001)

func repair() -> bool:
	if view.network_action("plane_repair"): return false
	var reason: String = service_reason()
	if not reason.is_empty():
		say(reason)
		return false
	var percent: int = repair_percent()
	while percent > 0 and Planes.repair_minor(plane_kind, percent) > int(view.reward_minor): percent -= 1
	if repair_percent() <= 0: say("No repairs needed.")
	elif percent <= 0: say("Not enough money for repairs.")
	else:
		var cost: int = Planes.repair_minor(plane_kind, percent)
		view.pay(cost)
		planes[plane_kind].condition = minf(1.0, condition() + percent / 100.0)
		say("Repaired to %.0f%% for %s credits." % [condition() * 100.0, credits(cost)])
	return true

func accept(id: String) -> bool:
	if view.network_action("plane_accept", id): return false
	var reason: String = accept_reason(id)
	if not reason.is_empty():
		say(reason)
		return false
	job_id = id
	var picked: Dictionary = Jobs.job(id)
	say("%s aboard. Fly to %s." % [picked.title.capitalize(), Airports.all()[int(picked.destination)].name])
	return true

func deliver() -> bool:
	if view.network_action("plane_deliver"): return false
	var reason: String = deliver_reason()
	if not reason.is_empty():
		say(reason)
		return false
	var pay: int = int(Jobs.job(job_id).reward_minor)
	job_id = ""
	view.banked_minor += pay
	view.reward_minor += pay
	var xp: int = view.award_delivery(pay)
	say("Delivery complete — paid %s credits. +%d XP." % [credits(pay), xp])
	view.play_sound("chime")
	return true

# --- The flight ------------------------------------------------------------------

## Authority tick (server simulation and local play), every physics frame.
func tick(delta: float) -> void:
	if not flying(): return
	if role() == "local": read_local_input(delta)
	var input: Dictionary = flight_input()
	var touched: bool = model.on_ground
	var sink: float = -model.velocity.y
	model.step(input, delta)
	if role() == "local": sync_gear()
	if model.belly_landed and not model.crashed:
		belly_landing()
	elif not touched and model.on_ground and sink > FIRM_SINK_MPS and not model.crashed:
		# A firm landing costs some condition (repaired at an airport).
		planes[plane_kind].condition = maxf(0.05, condition() - (sink - FIRM_SINK_MPS) * 0.05)
	if model.crashed:
		crash()
		return
	airport = maxi(0, Airports.nearest(model.position))
	# Patch 4.0.7 item 4: a plane on a runway or on final holds it (the Jetty
	# hovering over land may not cross a runway in use).
	JETTY_LAND.note_plane(model, airport)
	check_low(delta)
	follow_boat()
	planes[plane_kind].fuel = clampf(model.fuel_l / maxf(1.0, float(plane_entry().fuel_l)), 0.0, 1.0)

## The model's input from the captain's order (the helm frame on the server).
## Patch 4.0.3 item 1: the order's yaw is the barrel roll ("trick").
func flight_input() -> Dictionary:
	return {"throttle": maxf(0.0, float(order.throttle)), "brake": minf(1.0, maxf(0.0, -float(order.throttle)) / 0.6),
		"pitch": order.pitch, "roll": order.roll, "trick": order.yaw, "gear": float(order.get("gear", -1.0))}

## Patch 4.0.2 item 6: G. Flips the gear lever against what the gear is now
## (so it always does what the gear shows). Not on the ground.
func toggle_gear() -> bool:
	if not flying() or model.on_ground or in_crash_view(): return false
	gear_order = 0.0 if model.gear_down else 1.0
	order.gear = gear_order
	say("Gear %s." % ("down" if gear_order > 0.5 else "up"))
	return true

## The lever follows the gear when the gear moved on its own (on the ground,
## after take-off), so the next G always toggles what is shown.
func sync_gear() -> void:
	if model == null: return
	if model.gear_auto_up or model.on_ground:
		gear_order = 1.0 if model.gear_down else 0.0
		order.gear = gear_order

## Patch 4.0.2 item 6: a belly landing. A hard landing, not a crash: the
## repair bill (BELLY_REPAIR_PERCENT, capped by the wallet) is charged now,
## the cargo stays aboard and the plane slides to a stop.
func belly_landing() -> void:
	var bill: int = mini(Planes.repair_minor(plane_kind, BELLY_REPAIR_PERCENT), int(view.reward_minor))
	view.pay(bill)
	belly_landings += 1
	say("Belly landing! The gear was up. Repair bill %s credits." % credits(bill))

## Patch 4.0.2 item 6: whether the "Press G — Gear down" nudge shows: gear
## up, in the air, descending, below GEAR_NUDGE_AGL_M and within
## GEAR_NUDGE_M of either threshold of a runway.
func gear_nudge() -> bool:
	if not flying() or model.on_ground or model.gear_down or in_crash_view(): return false
	if model.agl_m > GEAR_NUDGE_AGL_M or model.velocity.y > -GEAR_NUDGE_SINK_MPS: return false
	return near_threshold(model.position) < GEAR_NUDGE_M

## Metres from a position to the nearest runway threshold (either end of any runway).
static func near_threshold(position: Vector3) -> float:
	var best: float = INF
	for entry: Dictionary in Airports.all():
		var axis: Vector3 = Vector3(sin(entry.heading), 0, cos(entry.heading))
		for end: float in [-1.0, 1.0]:
			var flat: Vector3 = -Airports.local_to(entry.at + axis * end * float(entry.length) * 0.5, position)
			flat.y = 0.0
			best = minf(best, flat.length())
	return best

## Patch 4.0 item 12: low flying away from an airport warns, then fines.
func check_low(delta: float) -> void:
	var near_airport: bool = Airports.distance_to(Airports.nearest(model.position), model.position) < AIRPORT_ZONE_M
	warning = not model.on_ground and model.agl_m < SAFE_AGL_M and not near_airport
	if not warning:
		low_seconds = 0.0
		return
	low_seconds += delta
	if low_seconds >= LOW_GRACE_S:
		low_seconds = 0.0
		var fine: int = mini(LOW_FINE_MINOR, int(view.reward_minor))
		view.pay(fine)
		fines += 1
		say("Fined %s credits for flying below %d m away from an airport." % [credits(fine), int(SAFE_AGL_M)])

## Patch 4.0 item 12: a crash. Cargo is lost, the repair bill is charged (what
## the wallet holds, if less) and the plane is back at the nearest airport.
func crash() -> void:
	last_crash_at = model.position
	var reason: String = model.crash_reason
	var bill: int = mini(Planes.repair_minor(plane_kind, Planes.CRASH_REPAIR_PERCENT), int(view.reward_minor))
	view.pay(bill)
	var lost: bool = not job_id.is_empty()
	job_id = ""
	crashes += 1
	var home: int = maxi(0, Airports.nearest(model.position))
	var fuel: float = model.fuel_l
	planes[plane_kind].condition = 1.0
	# Local play is its own view: the crash view starts before the respawn so
	# the laid-up boat (and the sea with it) stays at the wreck meanwhile.
	if role() == "local": show_crash(last_crash_at)
	start_plane(home)
	model.fuel_l = maxf(fuel, float(plane_entry().fuel_l) * 0.25)
	say("CRASH! %s%s Repair bill %s credits. Your plane is back at %s." % [reason, " Cargo lost." if lost else "", credits(bill), Airports.all()[home].name])

## Patch 4.0.3 item 1 (Andy: keyboard only, no mouse aim). W / S climb and
## descend (released, the plane holds its altitude); A / D turn (it banks
## itself, up to the limit, and rolls level when released); Shift / Ctrl
## move the throttle lever, which stays where it is set; Space is the wheel
## brakes on the ground and the air brake in the air; Q / E a barrel roll;
## G the gear (on_command). The mouse never steers (right-drag still looks
## round). Space sends a negative throttle, as S at idle did before: the
## server's helm frame and its checks are unchanged.
func read_local_input(delta: float) -> void:
	var controls: PlayerControls = view.controls
	# Patch 4.0.5 item 1: or a controller's RT / LT.
	var axis: float = clampf(controls.held_key(KEY_SHIFT) - controls.held_key(KEY_CTRL) + controls.lever_axis(), -1.0, 1.0)
	lever = clampf(lever + axis * LEVER_RATE * delta, 0.0, 1.0)
	if controls.action_strength("ship_throttle_zero") > 0.0: lever = 0.0
	if in_crash_view():
		# Watching the wreck: the respawned plane waits at idle.
		lever = 0.0
		barrel = 0.0
		order = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "gear": gear_order}
		return
	var pitch: float = controls.action_strength("ship_throttle_up") - controls.action_strength("ship_throttle_down")
	var brake: bool = controls.action_strength("ship_brake") > 0.0
	var roll_keys: float = controls.action_strength("ship_thruster_right") - controls.action_strength("ship_thruster_left")
	order = key_order(pitch, controls.steering_axis(), roll_keys, brake, delta)

## Patch 4.0.3 item 1: the order from the keys: pitch (W +1, S -1), turn (D
## +1, A -1), roll keys (E +1, Q -1), brake (Space). A press of Q / E in the
## air starts a barrel roll that is held for one whole turn (barrel_step).
func key_order(pitch: float, turn: float, roll_keys: float, brake: bool, delta: float) -> Dictionary:
	barrel_step(roll_keys, delta)
	return {"throttle": -0.6 if brake else lever, "pitch": clampf(pitch, -1.0, 1.0), "roll": clampf(turn, -1.0, 1.0),
		"yaw": barrel, "gear": gear_order}

## Patch 4.0.3 item 1: the barrel roll. Starts on a press of Q (left) or E
## (right) with BARREL_AGL_M of air below; rolls until the plane has been
## upside down and is back within 30 degrees of level (or BARREL_MAX_S),
## then lets go, and the bank goes back to what A / D ask.
func barrel_step(roll_keys: float, delta: float) -> void:
	var pressed: bool = absf(roll_keys) > 0.5 and absf(barrel_key) <= 0.5
	barrel_key = roll_keys
	if model == null or model.on_ground:
		barrel = 0.0
		return
	if barrel == 0.0:
		if pressed and model.agl_m > BARREL_AGL_M:
			barrel = signf(roll_keys)
			barrel_over = false
			barrel_s = 0.0
		return
	barrel_s += delta
	if absf(model.full_bank()) > deg_to_rad(150.0): barrel_over = true
	if (barrel_over and absf(model.full_bank()) < deg_to_rad(30.0)) or barrel_s > BARREL_MAX_S: barrel = 0.0

## The client's own inputs this frame (it sends them with the helm frame).
func client_input(delta: float) -> Dictionary:
	read_local_input(delta)
	return order

# --- Saving and sync -------------------------------------------------------------

## The progress row's plane fields (Levels.progress_valid); xp is the scene's.
func capture() -> Dictionary:
	store_plane()
	return {"xp": int(view.xp), "planes": planes.duplicate(true), "plane": plane_kind, "mode": mode if flying() else "boat",
		"airport": clampi(airport, 0, Airports.count() - 1), "plane_job": job_id if flying() else ""}

## Restores a saved row (call after the voyage). A captain saved in the air
## starts on the ground at the airport they were nearest.
func restore(data: Dictionary) -> void:
	if not Levels.progress_valid(data): return
	view.xp = int(data.xp)
	planes = data.planes.duplicate(true)
	plane_kind = data.plane
	airport = data.airport
	job_id = ""
	if data.mode == "plane" and planes.has(plane_kind):
		view.docking.disconnect_owner(view.owner_id)
		lay_up_boat()
		start_plane(airport)
		job_id = data.plane_job
		view.bind_port()

## Every plane at any level (the admin debug overlay and the local test mode).
func unlock_all() -> void:
	debug_unlocked = true
	for kind: String in Planes.ORDER:
		if not planes.has(kind): planes[kind] = {"fuel": 1.0, "condition": 1.0}
	if plane_kind.is_empty(): plane_kind = Planes.ORDER[0]

## What the client is sent (reliably, on change).
func state() -> Dictionary:
	return {"xp": int(view.xp), "planes": planes.duplicate(true), "plane": plane_kind, "mode": mode if flying() else "boat",
		"airport": airport, "job": job_id, "warning": warning, "low": snappedf(low_seconds, 0.5), "crashes": crashes,
		"crash_at": last_crash_at, "unlocked": debug_unlocked}

## Client: the server's word on everything but the motion.
func apply_state(data: Dictionary) -> void:
	if not data.get("planes") is Dictionary: return
	view.xp = int(data.get("xp", 0))
	planes = data.planes.duplicate(true)
	plane_kind = str(data.get("plane", ""))
	airport = int(data.get("airport", 0))
	job_id = str(data.get("job", ""))
	warning = bool(data.get("warning", false))
	low_seconds = float(data.get("low", 0.0))
	debug_unlocked = bool(data.get("unlocked", false))
	var air: bool = data.get("mode") == "plane" and Planes.PLANES.has(plane_kind)
	if air and not flying():
		mode = "plane"
		model = Flight.make(plane_kind, Airports.start_pose(airport))
		history.clear()
		offset = Vector3.ZERO
		lay_up_boat()
	elif air and model.kind != plane_kind:
		model = Flight.make(plane_kind, Airports.start_pose(airport))
		history.clear()
	elif not air and flying():
		mode = "boat"
		model = null
		history.clear()
		if is_instance_valid(view.helm): view.helm.process_mode = Node.PROCESS_MODE_INHERIT
	var count: int = int(data.get("crashes", 0))
	if count > seen_crashes and data.get("crash_at") is Vector3: show_crash(data.crash_at)
	seen_crashes = count

## Client prediction, one physics step: the same physics as the server.
func predict(delta: float, sequence: int) -> void:
	if not flying(): return
	var input: Dictionary = flight_input()
	history.append({"seq": sequence, "input": input, "dt": delta})
	while history.size() > 240: history.pop_front()
	previous = model.transform()
	model.step(input, delta)
	sync_gear()
	if model.crashed:
		model.crashed = false
		model.velocity = Vector3.ZERO

## Client: the server's motion for our plane arrived. Reset to it, replay
## the inputs it has not seen yet, and fade the visual gap (no rubber band:
## the gap is measured after the replay, so speed alone never makes one).
func reconcile(own: Dictionary) -> void:
	if not flying() or not own.has("air"): return
	server_state = own
	var shown: Vector3 = model.position + offset
	var acked_lever: float = model.gear_lever
	while not history.is_empty() and int(history[0].seq) <= int(own.ack): acked_lever = float(history.pop_front().input.get("gear", acked_lever))
	model.position = Vector3(own.position.x, own.air.altitude, own.position.z)
	model.basis = own.air.basis
	model.velocity = Vector3(own.velocity.x, own.air.vy, own.velocity.z)
	model.engine = own.engine
	model.fuel_l = own.fuel
	model.on_ground = own.air.ground
	# Patch 4.0.2 item 6: the server's gear, and the lever it last saw.
	model.gear_down = bool(own.air.get("gear", model.gear_down))
	model.on_belly = model.on_ground and not model.gear_down
	model.gear_lever = acked_lever
	model.crashed = false
	for step: Dictionary in history:
		model.step(step.input, step.dt)
		if model.crashed:
			model.crashed = false
			model.velocity = Vector3.ZERO
	previous = model.transform()
	var gap: Vector3 = Progression.short_way(shown - model.position)
	gap.y = shown.y - model.position.y
	# Snap only for a real jump (respawn, a pole or seam crossing, a long stall),
	# scaled with speed so a fast plane's normal error is always smoothed.
	if gap.length() > maxf(25.0, model.airspeed() * 0.6):
		gap = Vector3.ZERO
		snaps += 1
	elif gap.length() > 0.05: corrections += 1
	offset = gap

# --- Presentation ----------------------------------------------------------------

func setup_presentation() -> void:
	for index: int in Airports.count():
		var node: Node3D = Look.airport(index)
		view.add_child(node)
		airport_nodes.append(node)
	chase = Camera3D.new()
	chase.name = "ChaseCamera"
	chase.far = 9000.0
	chase.fov = 70.0
	chase.top_level = true
	add_child(chase)
	warn_player = AudioStreamPlayer.new()
	warn_player.stream = Look.sound("warn")
	warn_player.volume_db = -12.0
	add_child(warn_player)
	boom_player = AudioStreamPlayer.new()
	boom_player.stream = Look.sound("boom")
	boom_player.volume_db = -4.0
	add_child(boom_player)
	build_ui()
	# Patch 4.0.2 item 6: G (the key the pirate ships' salute uses) is the gear while flying.
	if is_instance_valid(view.controls) and not view.controls.command_requested.is_connected(on_command):
		view.controls.command_requested.connect(on_command)
	# Patch 4.0.2 item 7: the planes hangar, opened by the Planes buttons.
	hangar = PlaneHangar.new()
	hangar.view = view
	hangar.aviation = self
	add_child(hangar)

func on_command(action: StringName) -> void:
	if action == &"cannon_salute" and flying() and view.controls.input_allowed(): toggle_gear()

## Airports keep to their copy nearest the camera, like the icebergs.
func place_airports(around: Vector3) -> void:
	for index: int in airport_nodes.size():
		var at: Vector3 = Progression.nearest(Vector3(Airports.all()[index].at.x, 0, Airports.all()[index].at.z), around)
		at.y = 0.0
		if airport_nodes[index].position.distance_to(at) > 1.0: airport_nodes[index].position = at

func show_crash(at: Vector3) -> void:
	if role() == "server": return
	crash_view_at = at
	crash_view_left = CRASH_VIEW_S
	crash_view_from = chase.global_position if is_instance_valid(chase) and chase.is_inside_tree() else at + Vector3(0, 30, -60)
	if not is_instance_valid(view.ship) or not view.ship.is_inside_tree(): return
	# The laid-up boat (and the sea with it) stays at the wreck while
	# in_crash_view(): follow_boat in local play, the network runtime online.
	var near: Vector3 = Progression.nearest(at, view.ship.global_position)
	var blast: Node3D = Look.Explosion.new(clampf(float(Planes.PLANES.get(plane_kind, {"length_m": 10.0}).length_m) / 10.0, 1.0, 3.0))
	# Patch 4.0.4 item 1: placed before it enters the tree, so its _ready
	# seeds the debris from the wreck's place (every crash looked the same).
	blast.position = near
	view.add_child(blast)
	if is_instance_valid(boom_player): boom_player.play()
	chase_ready = false

## Patch 4.0.1 item 3: the crash camera. It starts where the chase camera was
## and slowly orbits the wreck while pulling back and up; the plane (already
## respawned by the authority) is hidden until the view ends.
func present_crash(delta: float) -> void:
	crash_view_left = maxf(0.0, crash_view_left - delta)
	if is_instance_valid(plane_node): plane_node.visible = crash_view_left <= 0.0
	if not is_instance_valid(chase) or not is_instance_valid(view.ship): return
	var wreck: Vector3 = Progression.nearest(crash_view_at, view.ship.global_position)
	wreck.y = maxf(wreck.y, 2.0)
	var t: float = clampf(1.0 - crash_view_left / CRASH_VIEW_S, 0.0, 1.0)
	var start: Vector3 = Progression.nearest(crash_view_from, wreck) - wreck
	start.y = 0.0
	if start.length() < 5.0: start = Vector3(0, 0, -60)
	var size: float = clampf(float(plane_entry().get("length_m", 10.0)), 8.0, 40.0)
	var radius: float = lerpf(maxf(start.length(), size * 3.0), size * 7.0 + 60.0, t * t * (3.0 - 2.0 * t))
	var turn: float = start.angle_to(Vector3(0, 0, 1)) * signf(start.x if absf(start.x) > 0.001 else 1.0) + t * 0.9
	var orbit: Vector3 = Vector3(sin(turn), 0, cos(turn)) * radius
	chase.global_position = wreck + orbit + Vector3.UP * (size * 1.5 + 18.0 + t * 45.0)
	chase.look_at(wreck + Vector3.UP * size * 0.3, Vector3.UP)
	if not chase.current: chase.make_current()
	if is_instance_valid(marks) and marks.visible: marks.hide()
	if crash_view_left <= 0.0:
		chase_ready = false
		# Back to the plane: the boat (and the sea) rejoin it.
		if role() == "local": follow_boat()

## Places the plane model and the chase camera. Every frame, client and local.
func present(delta: float) -> void:
	var air: bool = flying()
	if is_instance_valid(plane_node) and (not air or shown_kind != plane_kind):
		plane_node.queue_free()
		plane_node = null
	if air and not is_instance_valid(plane_node):
		plane_node = Look.model(plane_kind)
		view.add_child(plane_node)
		shown_kind = plane_kind
		chase_ready = false
	place_airports(view.ship.global_position if is_instance_valid(view.ship) else Vector3.ZERO)
	if not air:
		crash_view_left = 0.0
		if is_instance_valid(chase) and chase.current: view.camera.camera.make_current()
		if is_instance_valid(warn_player) and warn_player.playing: warn_player.stop()
		if is_instance_valid(engine_sound): engine_sound.silence()
		if is_instance_valid(marks) and marks.visible: marks.hide()
		return
	if in_crash_view():
		present_crash(delta)
		if is_instance_valid(engine_sound): engine_sound.silence()
		if is_instance_valid(warn_player) and warn_player.playing: warn_player.stop()
		return
	if is_instance_valid(plane_node): plane_node.visible = true
	var pose: Transform3D = model.transform()
	if role() == "client":
		offset *= exp(-delta / 0.2)
		var blend: float = Engine.get_physics_interpolation_fraction()
		var from: Vector3 = Progression.nearest(previous.origin, pose.origin)
		pose = Transform3D(previous.basis.slerp(pose.basis, blend), from.lerp(pose.origin, blend) + offset)
	pose.origin = Progression.nearest(pose.origin, Vector3(view.ship.global_position.x, pose.origin.y, view.ship.global_position.z)) if is_instance_valid(view.ship) else pose.origin
	plane_node.global_transform = Transform3D(pose.basis, pose.origin - pose.basis.y * model.gear_height_m)
	Look.animate(plane_node, model.engine, model.gear_down, delta)
	# Chase camera: behind and above, smoothed, looking a little ahead.
	var length: float = float(plane_entry().length_m)
	var flat: Vector3 = Vector3(pose.basis.z.x, 0, pose.basis.z.z).normalized()
	if flat.length_squared() < 0.5: flat = Vector3.FORWARD
	var behind: Vector3 = pose.origin - flat * (length * 2.6 + 14.0) - pose.basis.z * length * 0.6 + Vector3.UP * (length * 0.7 + 5.0)
	if not chase_ready or chase.global_position.distance_to(behind) > 600.0:
		chase.global_position = behind
		chase_ready = true
	else:
		chase.global_position = chase.global_position.lerp(behind, 1.0 - exp(-delta * 6.0))
	chase.look_at(pose.origin + pose.basis.z * length * 1.5, Vector3.UP)
	if not chase.current: chase.make_current()
	if is_instance_valid(marks):
		marks.visible = not model.on_ground
		var ahead: Vector3 = pose.origin + (model.velocity.normalized() if model.airspeed() > 1.0 else pose.basis.z) * 400.0
		marks.path_shown = not chase.is_position_behind(ahead)
		if marks.path_shown: marks.path = chase.unproject_position(ahead)
		marks.queue_redraw()
	if warning and not warn_player.playing: warn_player.play()
	elif not warning and warn_player.playing: warn_player.stop()
	# Patch 4.0.5 item 3: the engine's own sound, pitched by its RPM, the
	# roar and the fighter's afterburner by the lever.
	if is_instance_valid(engine_sound) and engine_sound.family != EngineSound.family_of(plane_kind):
		engine_sound.queue_free()
		engine_sound = null
	if not is_instance_valid(engine_sound):
		engine_sound = EngineSound.make(plane_kind, false)
		add_child(engine_sound)
	engine_sound.update(model.engine, lever)

# --- UI ------------------------------------------------------------------------------

func build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "AviationUI"
	add_child(layer)
	# The airport card: like the port card, top left, shown stopped on a runway.
	card = PanelContainer.new()
	card.position = Vector2(20, 20)
	PLAYFUL.dress(card)
	layer.add_child(card)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	card.add_child(stack)
	card_title = Label.new()
	DISPLAY.plain(card_title, PLAYFUL.SUN, 22)
	stack.add_child(card_title)
	card_info = Label.new()
	DISPLAY.plain(card_info, Color.WHITE, 14)
	stack.add_child(card_info)
	var row: HBoxContainer = HBoxContainer.new()
	stack.add_child(row)
	card_buttons.refuel = view.button(row, "Refuel", refuel)
	card_buttons.repair = view.button(row, "Repair", repair)
	card_buttons.planes = view.button(row, "Planes", open_menu)
	var row2: HBoxContainer = HBoxContainer.new()
	stack.add_child(row2)
	card_buttons.boat = view.button(row2, "Switch to Boat", switch_to_boat)
	card_buttons.deliver = view.button(row2, "Deliver", deliver)
	card_jobs = VBoxContainer.new()
	card_jobs.add_theme_constant_override("separation", 6)
	stack.add_child(card_jobs)
	card.hide()
	# The port card's second row (Patch 4.0 item 13): Planes and Switch to Plane,
	# in the shared button font and size, under Refuel / Repair / Ships.
	port_row = HBoxContainer.new()
	port_row.name = "PlaneRow"
	view.services.add_child(port_row)
	view.services.move_child(port_row, 1)
	# Patch 4.0.3 item 5: the actions on the left (Refuel, Repair / Switch to
	# Plane), the two shops stacked on the right (Ships over Planes).
	port_buttons.switch = view.button(port_row, "Switch to Plane", switch_to_plane)
	port_row.add_child(spacer("PlaneRowGap"))
	port_buttons.planes = view.button(port_row, "Planes", open_menu)
	var tabs: Node = view.refuel_button.get_parent()
	for item: Node in tabs.get_children():
		if item is Button and item.text == "Ships":
			var gap: Control = spacer("ServiceRowGap")
			tabs.add_child(gap)
			tabs.move_child(gap, item.get_index())
			break
	# The Planes menu (like Ships): one row per plane with Buy or Select.
	menu = PanelContainer.new()
	PLAYFUL.dress(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(menu)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	menu.add_child(column)
	var heading: Label = Label.new()
	DISPLAY.plain(heading, PLAYFUL.SUN, 22)
	heading.text = "Planes"
	column.add_child(heading)
	menu_wallet = Label.new()
	DISPLAY.plain(menu_wallet, PLAYFUL.CREAM, 14)
	column.add_child(menu_wallet)
	for kind: String in Planes.ORDER:
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		column.add_child(line)
		var words: Label = Label.new()
		DISPLAY.plain(words, Color.WHITE, 14)
		words.custom_minimum_size.x = 420
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(words)
		var action: Button = view.button(line, "Buy", menu_action.bind(kind))
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		menu_rows[kind] = {"words": words, "button": action}
	view.button(column, "Close", close_menu)
	menu.hide()
	# The low-altitude and stall warning, and the flight instruments line.
	banner = Label.new()
	DISPLAY.plain(banner, Color("ff6a5a"), 30)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.offset_top = 130
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(banner)
	banner.hide()
	# Patch 4.0.2 item 6: the gear nudge, under the warning banner.
	nudge_label = Label.new()
	nudge_label.name = "GearNudge"
	DISPLAY.plain(nudge_label, PLAYFUL.SUN, 30)
	nudge_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	nudge_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	nudge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nudge_label.offset_top = 180
	nudge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nudge_label.text = "Press G — Gear down"
	layer.add_child(nudge_label)
	nudge_label.hide()
	# The flight-direction marker (where the plane is actually going).
	# Patch 4.0.3 item 1: no aim reticle (the mouse no longer steers).
	marks = FlightMarks.new()
	marks.name = "FlightMarks"
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(marks)
	marks.hide()

## Patch 4.0.3 item 5: an empty stretch that pushes the shops to the right.
static func spacer(title: String) -> Control:
	var gap: Control = Control.new()
	gap.name = title
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.custom_minimum_size.x = 24
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap

## Patch 4.0 arcade HUD: a small winged circle where the flight path
## points (Patch 4.0.3: the mouse reticle is gone with the mouse aim).
class FlightMarks extends Control:
	var path: Vector2 = Vector2.ZERO
	var path_shown: bool = false

	func _draw() -> void:
		if path_shown:
			var green: Color = Color(0.55, 1.0, 0.6, 0.95)
			draw_arc(path, 8.0, 0.0, TAU, 24, green, 2.0, true)
			draw_line(path + Vector2(8, 0), path + Vector2(20, 0), green, 2.0, true)
			draw_line(path - Vector2(8, 0), path - Vector2(20, 0), green, 2.0, true)
			draw_line(path - Vector2(0, 8), path - Vector2(0, 16), green, 2.0, true)

## Patch 4.0.2 item 7: Planes opens the 3D planes hangar (the old list menu
## stays as the fallback when the hangar is missing).
func open_menu() -> void:
	if is_instance_valid(hangar):
		hangar.open()
		return
	menu.show()
	view.controls.set_menu_open(true)
	refresh_menu()

func close_menu() -> void:
	menu.hide()
	view.controls.set_menu_open(false)

func menu_action(kind: String) -> void:
	if planes.has(kind): select(kind)
	else: buy(kind)
	refresh_menu()

func refresh_menu() -> void:
	menu_wallet.text = "Wallet: %s credits · Level %d%s" % [credits(int(view.reward_minor)), level(), "" if unlocked() else " (planes unlock at level %d)" % Levels.PLANE_UNLOCK_LEVEL]
	for kind: String in Planes.ORDER:
		var p: Dictionary = Planes.PLANES[kind]
		var row: Dictionary = menu_rows[kind]
		row.words.text = "%s — %s credits\nTop %d kn · stalls below %d kn · %d L fuel (%d min) · carries %d %s" % [p.name, credits(int(p.price_minor)),
			roundi(Planes.top_speed(kind) * 1.944), roundi(Planes.stall_speed(kind) * 1.944), roundi(float(p.fuel_l)), roundi(Planes.endurance_s(kind) / 60.0),
			int(p.capacity), "passengers or packages" if p.jobs.size() > 1 else "packages"]
		if int(p.capacity) <= 0:
			row.words.text = "%s — %s credits\nTop %d kn · stalls below %d kn · %d L fuel (%d min) · no cargo: for the joy of flying" % [p.name, credits(int(p.price_minor)),
				roundi(Planes.top_speed(kind) * 1.944), roundi(Planes.stall_speed(kind) * 1.944), roundi(float(p.fuel_l)), roundi(Planes.endurance_s(kind) / 60.0)]
		var button: Button = row.button
		var reason: String = select_reason(kind) if planes.has(kind) else buy_reason(kind)
		button.text = ("Active" if kind == plane_kind else "Select") if planes.has(kind) else "Buy"
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason

## Every frame (client and local): cards, buttons, banner.
func refresh_ui() -> void:
	if card == null: return
	var docked: bool = view.docking.state(view.owner_id) == "docked"
	port_row.visible = view.services.visible and not flying()
	var reason: String = switch_reason()
	port_buttons.switch.tooltip_text = reason
	# Disabled (with its reason) while a load is aboard; otherwise a click explains.
	port_buttons.switch.disabled = not view.can_switch()
	port_buttons.planes.disabled = false
	var here: int = stopped_at()
	card.visible = here >= 0
	if card.visible:
		var entry: Dictionary = Airports.all()[here]
		card_title.text = entry.name
		card_info.text = "%s · Fuel %.0f%% · Condition %.0f%%" % [plane_entry().name, 100.0 * model.fuel_l / maxf(1.0, float(plane_entry().fuel_l)), condition() * 100.0]
		card_buttons.refuel.text = "Refuel  %s" % credits(refuel_price()) if refuel_price() > 0 else "Refuel"
		var repair_cost: int = Planes.repair_minor(plane_kind, repair_percent())
		card_buttons.repair.text = "Repair  %s" % credits(repair_cost) if repair_percent() > 0 else "Repair"
		card_buttons.boat.tooltip_text = boat_reason()
		card_buttons.boat.disabled = not job_id.is_empty()
		card_buttons.deliver.visible = not job_id.is_empty()
		var why: String = deliver_reason()
		card_buttons.deliver.disabled = not why.is_empty()
		card_buttons.deliver.tooltip_text = why
		# Patch 4.0.4 item 1: the board only changes with the airport, the
		# plane or the job aboard, so it is built then, not every frame.
		var key: String = "%d|%s|%s" % [here, plane_kind, job_id]
		if key != board_key:
			board_key = key
			var board: Array = Jobs.board(here, plane_entry()) if job_id.is_empty() else []
			shown_board = board.map(func(row: Dictionary) -> String: return row.id)
			for old: Node in card_jobs.get_children():
				card_jobs.remove_child(old)
				old.queue_free()
			# Patch 4.0.3 item 6: the boat board's cards (game_hud.job_card),
			# with the trip: km, minutes at cruise and fuel.
			for row: Dictionary in board:
				var trip: Dictionary = Jobs.trip(str(row.id), plane_kind)
				var trip_text: String = "%.1f km · %d min · %d L fuel" % [trip.km, trip.minutes, roundi(trip.fuel_l)] if not trip.is_empty() else ""
				var route: String = "%s → %s" % [entry.name, Airports.all()[int(row.destination)].name]
				if is_instance_valid(view.get("game_hud")):
					view.game_hud.job_card(card_jobs, str(row.kind), int(row.quantity), str(row.title).capitalize(), route, trip_text, int(row.reward_minor), accept.bind(str(row.id)))
					continue
				var line: HBoxContainer = HBoxContainer.new()
				line.add_theme_constant_override("separation", 10)
				card_jobs.add_child(line)
				var words: Label = Label.new()
				DISPLAY.plain(words, Color.WHITE, 14)
				words.custom_minimum_size.x = 250
				words.text = "%s\n%s\n+%s" % [route, trip_text, credits(int(row.reward_minor))]
				line.add_child(words)
				var take: Button = view.button(line, "Accept", accept.bind(str(row.id)))
				take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if menu.visible: refresh_menu()
	# Patch 4.0.2 item 6: the gear nudge, pulsing, with one chime per approach.
	nudge = gear_nudge()
	if nudge and not nudge_chimed:
		nudge_chimed = true
		if view.has_method("play_sound"): view.play_sound("chime")
	elif not nudge and (not flying() or model.gear_down or model.on_ground or model.agl_m > GEAR_NUDGE_AGL_M * 1.3): nudge_chimed = false
	nudge_label.visible = nudge
	# Patch 4.0.5 item 1: Y on a controller (the key stays G).
	if nudge: nudge_label.text = "Press %s — Gear down" % Gamepad.pick("G", Gamepad.glyph(JOY_BUTTON_Y))
	if nudge: nudge_label.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
	banner.visible = flying() and (warning or model.stalled)
	if banner.visible:
		var flash: bool = int(Time.get_ticks_msec() / 300) % 2 == 0
		banner.text = ("PULL UP — LOW ALTITUDE (fine in %d s)" % ceili(LOW_GRACE_S - low_seconds) if warning else "STALL — LOWER THE NOSE")
		banner.modulate.a = 1.0 if flash else 0.55

## The top-right card's lines while flying (voyage_hud.describe).
func describe() -> Dictionary:
	var result: Dictionary = {"stage": "FLYING", "cargo": "", "route": "", "next": "", "progress": -1.0}
	if not job_id.is_empty():
		var picked: Dictionary = Jobs.job(job_id)
		var destination: Dictionary = Airports.all()[int(picked.destination)]
		result.stage = "FLY %s" % ("PASSENGERS" if picked.kind == "pax" else "PACKAGES")
		result.route = "%s · %.2f km\nJob payment: %s credits" % [destination.name, Airports.distance_to(int(picked.destination), model.position) / 1000.0, credits(int(picked.reward_minor))]
		result.next = "Land and stop at %s, then click Deliver." % destination.name
	elif stopped_at() >= 0:
		result.stage = "AT THE AIRPORT"
	# Patch 4.0.3 item 1: the keys, while on the ground.
	if model.on_ground and job_id.is_empty():
		result.next = "Shift: full throttle. W past %d kn to lift off.\nA / D turn · W / S climb, descend · Space brakes · G gear" % roundi(float(plane_entry().rotate_mps) * 1.944)
		# Patch 4.0.5 item 1: the same, in controller buttons.
		if Gamepad.pad_last:
			result.next = "%s: full throttle. [L-stick] up past %d kn to lift off.\n[L-stick] turn, climb, descend · %s brakes · %s gear" % [Gamepad.glyph("RT"),
				roundi(float(plane_entry().rotate_mps) * 1.944), Gamepad.glyph(JOY_BUTTON_X), Gamepad.glyph(JOY_BUTTON_Y)]
	if model.fuel_l < float(plane_entry().fuel_l) * 0.2: result.next += ("\n" if not result.next.is_empty() else "") + "Fuel is low. Land at an airport and click Refuel."
	return result

func instruments_line() -> String:
	return "Fuel %.0f%%  ·  Condition %.0f%%" % [100.0 * model.fuel_l / maxf(1.0, float(plane_entry().fuel_l)), condition() * 100.0]

## The helm bar's big figure while flying: the airspeed, as the boat shows
## its speed (Patch 4.0.4 item 2: height, climb, heading, fuel, gear and the
## throttle are on the instrument row, game_hud.refresh_flight).
func helm_text() -> String:
	return "%d kn" % roundi(model.airspeed() * 3600.0 / 1852.0)
