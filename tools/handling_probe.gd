extends Node
const Ship = preload("res://features/handling/handling_ship.gd")
var ship: HandlingShip
var turning_ship: HandlingShip
var turns: Array[Vector3] = []
var tick: int = 0
var run_index: int = 0
var results: Array[Vector2] = []
var accelerated: float
var coasted: float
var neutral_speed: float
var failures: int = 0
var checks: int = 0
const CAPS: Array[int] = [30, 60, 144]

func _ready() -> void:
	set_physics_process(false)
	check_throttle()
	check_maneuvers()
	await check_input_scene()
	start_run()
	set_physics_process(true)

func start_run() -> void:
	Engine.max_fps = CAPS[run_index]
	ship = Ship.new()
	add_child(ship)
	ship.command_throttle(1.0)
	turning_ship = Ship.new()
	add_child(turning_ship)
	turning_ship.velocity.z = 4.0
	turning_ship.maneuver(1.0, 0.0)
	tick = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _physics_process(_delta: float) -> void:
	# Parent runs before child: sample the previous completed physics tick.
	if tick == 60:
		accelerated = ship.velocity.z
		check(accelerated > 0.1 and accelerated < 0.4, "Forward acceleration")
		ship.zero_throttle()
	if tick == 90:
		neutral_speed = ship.velocity.z
	if tick == 120:
		coasted = ship.velocity.z
		check(coasted > 0.0 and coasted < neutral_speed, "Zero thrust coasts with drag")
		ship.command_throttle(-1.0)
	if tick == 180:
		check(ship.velocity.z > 0.0 and ship.velocity.z < coasted, "Reverse brakes forward travel")
	if tick == 300:
		check(ship.velocity.z < 0.0, "Sustained reverse eventually travels astern")
		check(is_zero_approx(ship.position.y) and is_zero_approx(ship.position.x), "Planar movement")
		results.append(Vector2(ship.position.z, ship.velocity.z))
		print("HANDLING_SAMPLE cap=%d ticks=300 position=%.6f speed=%.6f" % [CAPS[run_index], ship.position.z, ship.velocity.z])
		turns.append(Vector3(turning_ship.position.x, turning_ship.position.z, turning_ship.rotation.y))
		check(turning_ship.position.x < 0.0 and turning_ship.rotation.y < 0.0, "Forward starboard turn moves right")
		remove_child(turning_ship)
		turning_ship.queue_free()
		remove_child(ship)
		ship.queue_free()
		run_index += 1
		if run_index == CAPS.size():
			for sample: Vector2 in results:
				check(sample.distance_to(results[0]) < 0.00001, "Rendering cap changed fixed-tick motion")
			for sample: Vector3 in turns:
				check(sample.distance_to(turns[0]) < 0.00001, "Repeatable turn across rendering caps")
			Engine.max_fps = 0
			print("HANDLING_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
			get_tree().quit(0 if failures == 0 else 1)
			set_physics_process(false)
			return
		start_run.call_deferred()
		return
	tick += 1


func check_throttle() -> void:
	var subject: HandlingShip = Ship.new()
	subject.definition = subject.definition.duplicate(true)
	subject.command_throttle(100.0)
	check(subject.commanded_throttle == 1.0, "Forward command clamped")
	subject.command_throttle(-100.0)
	check(is_equal_approx(subject.commanded_throttle, -0.6), "Reverse command clamped")
	subject.command_throttle(NAN)
	check(is_equal_approx(subject.commanded_throttle, -0.6), "Non-finite command rejected")
	subject.zero_throttle()
	subject.adjust_command(1.0, 1.0)
	check(is_equal_approx(subject.commanded_throttle, 0.5), "Command adjustment rate")
	subject.adjust_command(0.0, 1.0)
	check(is_equal_approx(subject.commanded_throttle, 0.5), "Released input retains order")
	subject.advance_engine(0.2)
	check(is_equal_approx(subject.actual_throttle, 0.1), "Engine ramps separately from command")
	subject.velocity.z = 4.0
	subject.zero_throttle()
	check(subject.commanded_throttle == 0.0 and is_equal_approx(subject.actual_throttle, 0.1) and subject.velocity.z == 4.0, "Zero order preserves engine response and momentum")
	subject.advance_engine(0.2)
	check(subject.actual_throttle == 0.0 and subject.velocity.z == 4.0, "Engine reaches neutral without clearing speed")
	subject.command_throttle(1.0)
	subject.advance_engine(2.0)
	subject.command_throttle(-0.6)
	subject.advance_engine(0.25)
	check(is_equal_approx(subject.actual_throttle, 0.75), "Reversal ramps down before astern")
	subject.advance_engine(1.0)
	check(subject.actual_throttle == 0.0, "Reversal crosses neutral without overshoot")
	subject.advance_engine(0.2)
	check(is_equal_approx(subject.actual_throttle, -0.1), "Reverse ramps up from neutral")
	var bounded: bool = true
	for index: int in range(600):
		subject.command_throttle(10.0 if index % 2 == 0 else -10.0)
		var previous: float = subject.actual_throttle
		subject.advance_engine(1.0 / 60.0)
		bounded = bounded and subject.actual_throttle >= -0.6 and subject.actual_throttle <= 1.0 and absf(subject.actual_throttle - previous) <= 1.0 / 60.0 + 0.000001
	check(bounded, "Rapid reversals respect limits and per-tick ramp bounds")
	subject.definition.reverse_throttle_limit = 0.25
	subject.command_throttle(-1.0)
	check(subject.commanded_throttle == -0.25, "Ship definition controls reverse limit")
	check(is_equal_approx((load("res://features/catalog/records/starter_ship.tres") as ShipDefinition).reverse_throttle_limit, 0.6), "Fixture tuning copy does not mutate source")
	var registry: DefinitionRegistry = DefinitionRegistry.new()
	check(registry.load_definitions(PrototypeCatalog.RECORDS).is_empty(), "Valid handling definition accepted")
	for field: String in ["linear_drag_per_second", "engine_ramp_up_per_second", "reverse_throttle_limit", "max_turn_rate_degrees", "turn_acceleration_degrees", "rudder_full_effect_speed_mps", "thruster_acceleration_mps2", "lateral_drag_per_second", "thruster_cutoff_speed_mps"]:
		var bad: ShipDefinition = (PrototypeCatalog.RECORDS[0] as ShipDefinition).duplicate(true)
		bad.set(field, NAN)
		var candidates: Array[ContentDefinition] = PrototypeCatalog.RECORDS.duplicate()
		candidates[0] = bad
		check(not registry.load_definitions(candidates).is_empty(), "Invalid handling value rejected: " + field)
	check(registry.get_definition("ship_starter_container_01") != null, "Invalid tuning preserves published catalog")
	subject.free()

func check_input_scene() -> void:
	var scene: Node3D = (load("res://features/handling/handling_test.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(0.1).timeout
	Input.action_press("ship_throttle_up")
	await get_tree().create_timer(0.15).timeout
	check(scene.ship.commanded_throttle > 0.0, "Mapped forward input raises order")
	Input.action_release("ship_throttle_up")
	var held: float = scene.ship.commanded_throttle
	await get_tree().create_timer(0.1).timeout
	check(is_equal_approx(scene.ship.commanded_throttle, held), "Scene retains order on release")
	var zero_event: InputEventKey = InputEventKey.new()
	zero_event.physical_keycode = scene.controls.preferences.bindings["ship_throttle_zero"]
	zero_event.pressed = true
	Input.parse_input_event(zero_event)
	await get_tree().process_frame
	check(scene.ship.commanded_throttle == 0.0, "Mapped zero action clears command")
	zero_event = zero_event.duplicate()
	zero_event.pressed = false
	Input.parse_input_event(zero_event)
	scene.ship.command_throttle(0.5)
	scene.controls.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	Input.action_press("ship_throttle_up")
	await get_tree().create_timer(0.1).timeout
	check(scene.ship.commanded_throttle == 0.0, "Focus loss orders neutral and blocks held input")
	scene.controls.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().create_timer(0.1).timeout
	check(scene.ship.commanded_throttle == 0.0, "Focus return waits for held key release")
	Input.action_release("ship_throttle_up")
	await get_tree().create_timer(0.1).timeout
	scene.ship.position = Vector3(-20, 0, 0)
	scene.ship.velocity = Vector3.ZERO
	scene.ship.actual_throttle = 0.0
	Input.action_press("ship_thruster_right")
	await get_tree().create_timer(4.0).timeout
	check(scene.ship.position.x < -21.0 and scene.ship.position.x >= -21.51, "Mapped thruster approaches solid quay without passing through")
	check(absf(scene.ship.rotation.y) < 0.00001, "Sideways berth approach preserves heading")
	Input.action_release("ship_thruster_right")
	Input.action_press("ship_steer_right")
	await get_tree().create_timer(0.1).timeout
	check(scene.ship.rudder == 1.0, "Mapped rudder reaches handling body")
	scene.controls.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().create_timer(0.1).timeout
	check(scene.ship.rudder == 0.0 and scene.ship.lateral_order == 0.0, "Focus blocks rudder and thrusters")
	Input.action_release("ship_steer_right")
	remove_child(scene)
	scene.queue_free()

func check_maneuvers() -> void:
	var subject: HandlingShip = Ship.new()
	add_child(subject)
	subject.set_physics_process(false)
	subject.maneuver(1.0, 0.0)
	subject.advance_motion(1.0 / 60.0)
	check(subject.yaw_rate == 0.0, "Stationary rudder has no turning authority")
	subject.velocity.z = 4.0
	subject.advance_motion(1.0 / 60.0)
	check(subject.yaw_rate < 0.0 and absf(subject.yaw_rate) <= deg_to_rad(2.0) / 60.0 + 0.000001, "Yaw acceleration bounded without instant heading jump")
	var previous: float = subject.yaw_rate
	subject.maneuver(-1.0, 0.0)
	subject.advance_motion(1.0 / 60.0)
	check(absf(subject.yaw_rate - previous) <= deg_to_rad(2.0) / 60.0 + 0.000001, "Rapid rudder reversal remains bounded")
	subject.rotation = Vector3.ZERO
	subject.yaw_rate = 0.0
	subject.velocity = Vector3(0, 0, -4)
	subject.maneuver(1.0, 0.0)
	subject.advance_motion(1.0 / 60.0)
	check(subject.yaw_rate > 0.0, "Astern reverses rudder yaw direction")
	subject.rotation = Vector3.ZERO
	subject.yaw_rate = 0.0
	subject.velocity = Vector3.ZERO
	subject.maneuver(0.0, 1.0)
	for index: int in range(3600): subject.advance_motion(1.0 / 60.0)
	check(subject.lateral_speed() < -0.99 and subject.lateral_speed() >= -1.00001, "Sustained thruster approaches finite terminal side speed")
	check(is_zero_approx(subject.rotation.y), "Thruster translates without rotating")
	subject.maneuver(0.0, 0.0)
	var side_before: float = absf(subject.lateral_speed())
	subject.advance_motion(1.0)
	check(absf(subject.lateral_speed()) > 0.0 and absf(subject.lateral_speed()) < side_before, "Released thruster coasts with lateral drag")
	subject.velocity = Vector3(0, 0, 8)
	subject.maneuver(0.0, 1.0)
	subject.advance_motion(1.0 / 60.0)
	check(is_zero_approx(subject.lateral_speed()), "Thrusters have no power above cutoff")
	subject.velocity = Vector3.ZERO
	subject.maneuver(0.0, -1.0)
	subject.advance_motion(1.0 / 60.0)
	check(subject.lateral_speed() > 0.0, "Port thruster translates toward +X")
	subject.maneuver(INF, NAN)
	check(subject.rudder == 0.0 and subject.lateral_order == 0.0, "Invalid maneuver orders neutralized")
	subject.maneuver(100.0, -100.0)
	check(subject.rudder == 1.0 and subject.lateral_order == -1.0, "Maneuver input clamped")
	subject.rotation = Vector3.ZERO
	subject.yaw_rate = 0.0
	subject.velocity = Vector3(0, 0, 1)
	subject.maneuver(1.0, 0.0)
	subject.advance_motion(1.0)
	var slow_turn: float = absf(subject.yaw_rate)
	subject.rotation = Vector3.ZERO
	subject.yaw_rate = 0.0
	subject.velocity = Vector3(0, 0, 4)
	subject.advance_motion(1.0)
	check(absf(subject.yaw_rate) > slow_turn, "Rudder authority increases with speed")
	subject.command_throttle(1.0)
	var yaw_bounded: bool = true
	for index: int in range(600):
		subject.advance_motion(1.0 / 60.0)
		yaw_bounded = yaw_bounded and absf(subject.yaw_rate) <= deg_to_rad(subject.definition.max_turn_rate_degrees) + 0.000001
	check(yaw_bounded, "Sustained rudder respects maximum yaw rate")
	subject.maneuver(0.0, 0.0)
	var turn_before: float = absf(subject.yaw_rate)
	subject.advance_motion(1.0 / 60.0)
	check(absf(subject.yaw_rate) > 0.0 and absf(subject.yaw_rate) < turn_before, "Released rudder winds yaw down gradually")
	remove_child(subject)
	subject.free()
