extends Node
const Ship = preload("res://features/handling/handling_ship.gd")
var ship: HandlingShip
var tick: int = 0
var run_index: int = 0
var results: Array[Vector2] = []
var accelerated: float
var coasted: float
var failures: int = 0
const CAPS: Array[int] = [30, 60, 144]

func _ready() -> void:
	start_run()

func start_run() -> void:
	Engine.max_fps = CAPS[run_index]
	ship = Ship.new()
	add_child(ship)
	ship.thrust = 1.0
	tick = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _physics_process(_delta: float) -> void:
	# Parent runs before child: sample the previous completed physics tick.
	if tick == 60:
		accelerated = ship.velocity.z
		check(accelerated > 0.7 and accelerated < 0.9, "Forward acceleration")
		ship.thrust = 0.0
	if tick == 120:
		coasted = ship.velocity.z
		check(coasted > 0.0 and coasted < accelerated, "Zero thrust coasts with drag")
		ship.thrust = -1.0
	if tick == 180:
		check(ship.velocity.z > 0.0 and ship.velocity.z < coasted, "Reverse brakes forward travel")
	if tick == 300:
		check(ship.velocity.z < 0.0, "Sustained reverse eventually travels astern")
		check(is_zero_approx(ship.position.y) and is_zero_approx(ship.position.x), "Planar movement")
		results.append(Vector2(ship.position.z, ship.velocity.z))
		print("HANDLING_SAMPLE cap=%d ticks=300 position=%.6f speed=%.6f" % [CAPS[run_index], ship.position.z, ship.velocity.z])
		remove_child(ship)
		ship.queue_free()
		run_index += 1
		if run_index == CAPS.size():
			for sample: Vector2 in results:
				check(sample.distance_to(results[0]) < 0.00001, "Rendering cap changed fixed-tick motion")
			Engine.max_fps = 0
			print("HANDLING_CHECK_%s (18 checks)" % ("PASS" if failures == 0 else "FAIL"))
			get_tree().quit(0 if failures == 0 else 1)
			set_physics_process(false)
			return
		start_run.call_deferred()
		return
	tick += 1
