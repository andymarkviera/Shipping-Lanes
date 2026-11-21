extends SceneTree
## Patch 4.0.4 item 4: real UDP server + two clients (check_dedicated_split.py
## --flight). The server stages the scene; every other step uses the real
## helm frames, actions and snapshots:
## - client1's captain flies a plane (staged airborne by the server). Its
##   client holds the throttle lever (as Shift / the slider do) and, after a
##   few seconds, presses G (Aviation.toggle_gear). It checks its own plane
##   HUD shows online.
## - client2's captain sails the Jetty (staged by the server: the same hull
##   swap as Switch). Its client presses Shift (client_command), which asks
##   the server for the blaster boost.
## Each client checks the other: client2 sees client1's plane (the right
## kind, in the air, its nameplate) and its gear fold up after G; client1
## sees client2's Jetty hovering (JettyFx and the hover lift on the replica)
## and its blaster charge and blast (the status row's boost count).
## The server checks its own word: the plane flies, the gear is up, the
## Jetty's boost fired.
const Planes = preload("res://features/planes/plane_catalog.gd")
const KIND: String = "plane_turboprop"
const JETTY: String = "small_jetty"
var runtime: Node3D
var started: int
var ready_at: int = 0
var checks: int = 0
var failures: int = 0
var flyer: int = 0
var sailor: int = 0
var staged: bool = false
var server_gear_up: bool = false
var server_boosted: bool = false
var server_airborne: bool = false
# Client side.
var is_flyer: bool = false
var gear_pressed_at: int = 0
var boost_sent: int = 0
var saw_plane: bool = false
var saw_plane_air: bool = false
var saw_gear_down: bool = false
var saw_gear_up: bool = false
var saw_jetty: bool = false
var saw_hover: bool = false
var saw_charge: bool = false
var saw_blast: bool = false
var saw_own_hud: bool = false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	change_scene_to_file.call_deferred("res://features/main/boot.tscn")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FLIGHT_CHECK: " + message)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 60000:
		check(false, "timed out")
		finish()
		return false
	if runtime == null:
		if current_scene != null and current_scene.name == "DedicatedRuntime": runtime = current_scene
		return false
	if runtime.hosting: server_step()
	elif not runtime.entity.is_empty() and runtime.received_states > 0: client_step()
	return false

func server_step() -> void:
	if runtime.contexts.size() == 2 and ready_at == 0: ready_at = Time.get_ticks_msec()
	if ready_at == 0: return
	var age: int = Time.get_ticks_msec() - ready_at
	if not staged and age > 1500 and runtime.contexts.size() == 2:
		staged = true
		for sender: int in runtime.contexts:
			if str(runtime.captains[sender]).ends_with("client1"): flyer = sender
			else: sailor = sender
		check(flyer != 0 and sailor != 0, "one flyer and one Jetty captain")
		if flyer == 0 or sailor == 0: return finish()
		stage_plane(runtime.contexts[flyer])
		stage_jetty(runtime.contexts[sailor])
	if not staged or not runtime.contexts.has(flyer) or not runtime.contexts.has(sailor):
		if staged and age > 8000 and runtime.contexts.is_empty(): server_done()
		return
	var air: Node = runtime.contexts[flyer].aviation
	if air.flying() and not air.model.on_ground and air.model.position.y > 200.0: server_airborne = true
	if air.flying() and not air.model.gear_down: server_gear_up = true
	var jetty: HandlingShip = runtime.contexts[sailor].ship
	if jetty.boost.uses() > 0: server_boosted = true
	if age > 40000: server_done()

## The flyer: a plane in the air over the first airport, gear down, engine
## running (as after a take-off; the client's helm flies it from here).
func stage_plane(context: Node3D) -> void:
	var air: Node = context.aviation
	air.unlock_all()
	air.plane_kind = KIND
	context.docking.disconnect_owner(context.owner_id)
	air.lay_up_boat()
	air.start_plane(0)
	context.bind_port()
	var m: RefCounted = air.model
	m.position.y += 900.0
	m.on_ground = false
	m.velocity = m.basis.z * Planes.stall_speed(KIND) * 1.7
	m.engine = 0.8
	m.gear_down = true
	m.gear_lever = 1.0
	check(air.flying(), "the server flies the flyer's plane")

## The sailor: the Jetty, swapped in at their port as Switch does.
func stage_jetty(context: Node3D) -> void:
	context.fleet[JETTY] = {"fuel": 1.0, "condition": 1.0}
	context.ship_kind = JETTY
	context.heavy_mode = false
	var ok: bool = context.select_port(context.world_ports.find(context.port))
	if ok: runtime.adopt_hull(sailor)
	check(ok and HandlingShip.JETTY_BOOST.eligible(context.ship.definition), "the server sails the sailor's Jetty")

func server_done() -> void:
	check(server_airborne, "the server's plane flew (in the air, over 200 m)")
	check(server_gear_up, "G on the flyer's client raised the server's gear")
	check(server_boosted, "Shift on the sailor's client fired the server's blaster")
	check(runtime.contexts.is_empty(), "both clients left cleanly")
	finish()

func client_step() -> void:
	var view: Node3D = runtime.view
	var now: int = Time.get_ticks_msec()
	if ready_at == 0:
		ready_at = now
		is_flyer = runtime.captain_name.ends_with("client1")
	var age: int = now - ready_at
	if is_flyer: flyer_step(view, now)
	else: sailor_step(view, now)
	if age > 30000:
		if is_flyer:
			check(saw_own_hud, "flying online, the own plane HUD shows (THR, IAS, ALT, GEAR)")
			check(saw_jetty, "the flyer sees the other captain's Jetty")
			check(saw_hover, "and it hovers (JettyFx and the hover lift on the replica)")
			check(saw_charge and saw_blast, "and its blaster charges and blasts (charge %s, blast %s)" % [saw_charge, saw_blast])
		else:
			check(boost_sent > 0, "the sailor pressed Shift on the Jetty")
			check(saw_plane, "the sailor sees the other captain's %s" % KIND)
			check(saw_plane_air, "in the air, with its captain's name")
			check(saw_gear_down and saw_gear_up, "its gear down, then folded up after G (down %s, up %s)" % [saw_gear_down, saw_gear_up])
		finish()

func flyer_step(view: Node3D, now: int) -> void:
	if not view.flying(): return
	# Shift held / the slider: the lever stays where it is set.
	view.aviation.lever = 0.8
	var hud: Control = view.get("game_hud")
	if is_instance_valid(hud) and hud.flight.visible and hud.flight_values.THR.text == "80%" and int(hud.flight_values.IAS.text) > 0 and hud.flight_values.GEAR.text in ["DOWN", "UP"]: saw_own_hud = true
	if gear_pressed_at == 0:
		gear_pressed_at = now + 5000
	elif now > gear_pressed_at and gear_pressed_at > 0 and view.aviation.gear_order > 0.5 and not view.aviation.model.on_ground:
		view.aviation.toggle_gear()
	for id: String in runtime.replicas:
		var body: HandlingShip = runtime.replicas[id].body
		if not HandlingShip.JETTY_BOOST.eligible(body.definition): continue
		saw_jetty = true
		var fx: Node = body.find_child("JettyFx", true, false)
		var lift: Node = null
		for node: Node in body.find_children("*", "", true, false):
			if node.has_method("hovering"):
				lift = node
				break
		if fx != null and lift != null and lift.hovering(): saw_hover = true
		if body.boost.phase == "charge": saw_charge = true
		if body.boost.phase == "blast": saw_blast = true

func sailor_step(view: Node3D, now: int) -> void:
	var age: int = now - ready_at
	if view.ship_kind == JETTY and boost_sent == 0 and age > 6000 and not view.flying():
		var before: int = view.ship.boost.uses()
		runtime.client_command(PlayerControls.BOOST_COMMAND)
		if view.ship.boost.uses() > before: boost_sent += 1
	for id: String in runtime.air_replicas:
		var replica: Dictionary = runtime.air_replicas[id]
		if replica.kind != KIND: continue
		saw_plane = true
		var node: Node3D = replica.node
		if node.global_position.y > 200.0 and str(replica.label.text).begins_with("Probe"): saw_plane_air = true
		var gear: Node3D = node.get_node_or_null("Gear") as Node3D
		if gear == null: continue
		var travel: float = float(gear.get_meta("travel", 1.0))
		if travel > 0.99: saw_gear_down = true
		if saw_gear_down and travel < 0.01: saw_gear_up = true

func finish() -> void:
	print("DEDICATED_FLIGHT_%s %s checks=%d" % ["PASS" if failures == 0 else "FAIL", "server" if runtime != null and runtime.hosting else "client", checks])
	quit(0 if failures == 0 else 1)
