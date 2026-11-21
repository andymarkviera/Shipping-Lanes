extends "res://features/game/boat_hangar.gd"
## Patch 4.0.2 item 7: the planes hangar. The "Planes" buttons (the port
## card's and the airport card's) open it: a toon aircraft hangar (a curved
## steel roof on red trusses, a painted concrete floor with a yellow guide
## line, the big doors rolled open onto the apron and the sky, work lamps)
## with one plane turning slowly on a turntable. It is the boat hangar's
## screen, layout, fonts, buttons and keys (this script extends
## features/game/boat_hangar.gd and overrides only what is about planes):
## left/right cycle the planes, the card shows price, fuel, speed and
## capacity, and Buy / Select / Fly go through Aviation's own actions, so
## the rules (and the server's authority online) are the same as the old
## Planes list. Back (Esc) returns to the game.
const Planes = preload("res://features/planes/plane_catalog.gd")
const PlaneLook = preload("res://features/planes/plane_look.gd")
const Levels = preload("res://features/game/levels.gd")
## Every plane is drawn this long in the hangar; the real size is in the stats.
const PLANE_SHOWN_LENGTH: float = 46.0

var aviation: Node
var fly_button: Button

func current() -> String:
	return kinds[index] if not kinds.is_empty() else ""

func open() -> void:
	if is_open(): return
	for kind: String in Planes.ORDER: show_model(kind)
	set_family("")
	index = maxi(0, kinds.find(str(aviation.plane_kind)))
	notice = ""
	screen.show()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view.controls.set_menu_open(true)
	refresh()

## No families: every plane, cheapest first.
func set_family(_id: String) -> void:
	var keep: String = current()
	family = ""
	kinds.clear()
	kinds.append_array(Planes.ORDER)
	index = maxi(0, kinds.find(keep))
	notice = ""
	refresh()

func step_family(_by: int) -> void:
	pass

func owned(kind: String) -> bool:
	return aviation.planes.has(kind)

## Why the main button (Buy or Select) cannot act on this plane; "" when it can.
func action_reason(kind: String) -> String:
	if owned(kind): return aviation.select_reason(kind)
	return aviation.buy_reason(kind)

## Why Fly (switch from the boat to this plane) cannot be used; "" when it can.
func fly_reason(kind: String) -> String:
	if not owned(kind): return "Buy it first."
	if aviation.flying(): return "You are flying already."
	return aviation.switch_reason()

func press_action() -> void:
	var kind: String = current()
	if kind.is_empty() or Time.get_ticks_msec() - last_action_ms < ACTION_COOLDOWN_MS: return
	var reason: String = action_reason(kind)
	if not reason.is_empty():
		notice = reason
		refresh()
		return
	last_action_ms = Time.get_ticks_msec()
	var had: bool = owned(kind)
	if had: aviation.select(kind)
	else: aviation.buy(kind)
	notice = str(view.offer_notice)
	if not had and owned(kind): notice = "Bought the %s. Press Fly to take it up." % Planes.PLANES[kind].name
	refresh()

func press_fly() -> void:
	var kind: String = current()
	if kind.is_empty() or Time.get_ticks_msec() - last_action_ms < ACTION_COOLDOWN_MS: return
	if owned(kind) and kind != aviation.plane_kind and aviation.select_reason(kind).is_empty(): aviation.select(kind)
	var reason: String = fly_reason(kind)
	if not reason.is_empty():
		notice = reason
		refresh()
		return
	last_action_ms = Time.get_ticks_msec()
	aviation.switch_to_plane()
	notice = str(view.offer_notice)
	close()

## Planes are not sold back (as before); the second button is Fly.
func press_sell() -> void:
	press_fly()

static func knots(mps: float) -> int:
	return roundi(mps * 1.944)

## The card's stat line for a plane.
static func stats_text(kind: String) -> String:
	var p: Dictionary = Planes.PLANES[kind]
	var carries: String = "%d %s" % [int(p.capacity), "passengers or packages" if p.jobs.size() > 1 else "packages"] if int(p.capacity) > 0 else "no cargo: for the joy of flying"
	return "Top speed %d kn   ·   Stalls below %d kn   ·   Fuel %d L (%d min)   ·   Carries %s" % [knots(Planes.top_speed(kind)),
		knots(Planes.stall_speed(kind)), roundi(float(p.fuel_l)), roundi(Planes.endurance_s(kind) / 60.0), carries]

func refresh() -> void:
	if view == null or name_label == null or aviation == null: return
	var kind: String = current()
	if kind.is_empty(): return
	show_model(kind)
	var p: Dictionary = Planes.PLANES[kind]
	var has: bool = owned(kind)
	var active: bool = kind == aviation.plane_kind and has
	name_label.text = str(p.name).to_upper() + ("  · ACTIVE" if active else ("  · OWNED" if has else ""))
	family_label.text = "Plane %d of %d   ·   Price %s credits%s" % [index + 1, kinds.size(), credits(int(p.price_minor)),
		"" if aviation.unlocked() else "   ·   Planes unlock at level %d" % Levels.PLANE_UNLOCK_LEVEL]
	stats_label.text = stats_text(kind)
	wallet_label.text = "Wallet: %s credits" % credits(int(view.reward_minor))
	var reason: String = action_reason(kind)
	if active: action_button.text = "Active"
	elif has: action_button.text = "Select"
	elif int(view.reward_minor) < int(p.price_minor): action_button.text = "Need %s more" % credits(int(p.price_minor) - int(view.reward_minor))
	else: action_button.text = "Buy · %s" % credits(int(p.price_minor))
	action_button.disabled = not reason.is_empty() or active
	action_button.tooltip_text = reason
	var fly: String = fly_reason(kind)
	sell_button.text = "Fly"
	sell_button.visible = has
	sell_button.disabled = not fly.is_empty()
	sell_button.tooltip_text = fly
	status_label.text = notice if not notice.is_empty() else ("" if active else reason)

## One model per plane, built once and kept: swapping is a visibility change.
func show_model(kind: String) -> void:
	if not models.has(kind):
		var model: Node3D = PlaneLook.model(kind)
		model.scale = Vector3.ONE * (PLANE_SHOWN_LENGTH / maxf(1.0, float(Planes.PLANES[kind].length_m)))
		turntable.add_child(model)
		models[kind] = model
	for shown: String in models: (models[shown] as Node3D).visible = shown == kind

func _process(delta: float) -> void:
	if not is_open(): return
	turntable.rotate_y(TURN_RADIANS_PER_SECOND * delta)
	var model: Node3D = models.get(current())
	if model != null: PlaneLook.animate(model, 0.15, true, delta)
	refresh()

func build_overlay() -> void:
	super.build_overlay()
	title_label.text = "PLANE HANGAR"
	# One plane line, no families.
	for button: Button in filter_buttons: button.queue_free()
	filter_buttons.clear()
	fly_button = sell_button

## The hangar: a concrete floor with a yellow guide line and a turntable, side
## walls of corrugated steel, red roof trusses under a curved roof, the big
## doors rolled open at the back onto a sunny apron, work lamps overhead.
func build_shed() -> void:
	var stage: Node3D = Node3D.new()
	viewport.add_child(stage)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8fd3f4")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1d6")
	environment.ambient_light_energy = 0.6
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 160, 0)
	sun.light_energy = 0.8
	stage.add_child(sun)
	var cache: Dictionary = {}
	var concrete: Color = Color("b9b3a6")
	var steel: Color = Color("7d8796")
	var dark_steel: Color = Color("4b5566")
	var truss: Color = Color("c8372d")
	var guide: Color = Color("f2c230")
	# Floor, the apron and grass beyond the doors.
	box(stage, Vector3(150, 1, 140), Vector3(0, -0.5, 0), concrete, cache)
	box(stage, Vector3(400, 1, 300), Vector3(0, -0.6, -220), Color("5f6673"), cache)
	box(stage, Vector3(1600, 1, 1200), Vector3(0, -0.8, -700), Color("6f9a5a"), cache)
	box(stage, Vector3(1.2, 0.05, 130), Vector3(0, 0.02, -5), guide, cache)
	# The turntable: a round dark plate with a yellow rim.
	var plate: CylinderMesh = CylinderMesh.new()
	plate.top_radius = 30.0
	plate.bottom_radius = 30.0
	plate.height = 0.4
	plate.radial_segments = 32
	part(stage, plate, Vector3(0, 0.2, -6), dark_steel, cache)
	var rim: CylinderMesh = CylinderMesh.new()
	rim.top_radius = 31.0
	rim.bottom_radius = 31.0
	rim.height = 0.25
	rim.radial_segments = 32
	part(stage, rim, Vector3(0, 0.12, -6), guide, cache)
	for side: float in [-1.0, 1.0]:
		# Corrugated side walls (ribs) and the back wall beside the doors.
		box(stage, Vector3(2, 50, 140), Vector3(side * 75, 25, 0), steel, cache)
		for rib: int in range(-64, 70, 8):
			box(stage, Vector3(0.8, 50, 1.2), Vector3(side * 73.8, 25, float(rib)), dark_steel, cache)
		box(stage, Vector3(28, 50, 2), Vector3(side * 61, 25, -70), steel, cache)
		# The door leaves, rolled aside.
		box(stage, Vector3(20, 44, 1.6), Vector3(side * 58, 22, -72.5), Color("d9dde3"), cache)
		# Work lamps along the walls.
		for z: float in [-40.0, 0.0, 40.0]:
			ball(stage, 1.6, Vector3(side * 50, 40, z), WARM, cache)
			var glow: OmniLight3D = OmniLight3D.new()
			glow.light_color = Color("fff1d6")
			glow.light_energy = 2.0
			glow.omni_range = 60
			glow.position = Vector3(side * 50, 38, z)
			stage.add_child(glow)
	# The curved roof: red trusses arching from wall to wall, steel panels over them.
	for frame: int in range(-64, 70, 16):
		var z: float = float(frame)
		for step: int in 8:
			var a: float = PI * step / 8.0
			var b: float = PI * (step + 1) / 8.0
			var from: Vector3 = Vector3(-cos(a) * 75, 50 + sin(a) * 18, z)
			var to: Vector3 = Vector3(-cos(b) * 75, 50 + sin(b) * 18, z)
			var beam: MeshInstance3D = box(stage, Vector3(from.distance_to(to), 1.6, 1.6), (from + to) * 0.5, truss, cache)
			beam.rotation.z = atan2(to.y - from.y, to.x - from.x)
	for step: int in 8:
		var a: float = PI * step / 8.0
		var b: float = PI * (step + 1) / 8.0
		var from: Vector3 = Vector3(-cos(a) * 76, 51 + sin(a) * 18, 0)
		var to: Vector3 = Vector3(-cos(b) * 76, 51 + sin(b) * 18, 0)
		var panel: MeshInstance3D = box(stage, Vector3(from.distance_to(to) + 1.0, 1.0, 140), (from + to) * 0.5, steel, cache)
		panel.rotation.z = atan2(to.y - from.y, to.x - from.x)
	# Lintel over the open doors.
	box(stage, Vector3(150, 8, 2), Vector3(0, 48, -70), dark_steel, cache)
	turntable = Node3D.new()
	turntable.position = Vector3(0, 0.4, -6)
	stage.add_child(turntable)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 55
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0, 24, 66), Vector3(0, 6, -8))
	camera.current = true
	TOON_LOOK.apply(stage)
