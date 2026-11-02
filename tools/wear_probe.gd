extends Node
const Owner = preload("res://features/network/public_ship_owner.gd")
const Gauges = preload("res://features/feedback/vessel_gauges.gd")
var checks: int = 0
func check(value: bool, text: String) -> void:
	assert(value, text)
	checks += 1
	print("PASS ", text)
func _ready() -> void:
	var owner = Owner.new()
	add_child(owner)
	owner.set_process(false)
	owner.set_physics_process(false)
	owner.authority.set_process(false)
	owner.authority.active = true
	owner.restore_grant({"profile":{"ship":{"id":"wear_fixture", "definition":"ship_starter_container_01", "fuel_liters":800.0, "position":{"latitude":0.0,"longitude":0.0,"heading":0.0}},"cargo":[]}})
	owner.ship.set_physics_process(false)
	owner.ship.actual_throttle = 0.5
	owner._physics_process(3600)
	check(owner.operating_seconds == 3600, "active propulsion uses simulated seconds")
	owner.ship.docked = true
	owner._physics_process(3600)
	check(owner.operating_seconds == 3600, "docked time does not wear")
	owner.ship.docked = false
	owner.ship.simulation_paused = true
	owner._physics_process(3600)
	check(owner.operating_seconds == 3600, "paused time does not wear")
	owner.ship.simulation_paused = false
	owner.ship.actual_throttle = 0
	owner._physics_process(3600)
	check(owner.operating_seconds == 3600, "neutral idle does not wear")
	owner.ship.lateral_order = 0.5
	owner._physics_process(60)
	check(owner.operating_seconds == 3660, "propulsion thruster time counts")
	owner.authority.active = false
	owner._physics_process(3600)
	check(owner.operating_seconds == 3660, "fenced owner cannot wear")
	owner.authority.active = true
	owner.ship.state.fuel_liters = 0
	owner._physics_process(3600)
	check(owner.operating_seconds == 3660, "empty fuel does not wear")
	owner.ship.state.condition = 0.8
	check(owner.ship.propulsion_condition_factor() == 1, "healthy propulsion unchanged")
	owner.ship.state.condition = 0.25
	check(is_equal_approx(owner.ship.propulsion_condition_factor(), 0.875), "one condition mildly reduces propulsion")
	owner.ship.condition_affects_propulsion = false
	check(owner.ship.propulsion_condition_factor() == 1, "local handling fixtures retain existing tuning")
	owner.queue_free()
	var layer := CanvasLayer.new()
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color("243642")
	backdrop.size = Vector2(720, 320)
	layer.add_child(backdrop)
	for index: int in range(3):
		var gauge = Gauges.new()
		gauge.position = Vector2(40 + index * 220, 100)
		layer.add_child(gauge)
		gauge.update_values([1.0,0.5,0.1][index], [1.0,0.5,0.1][index])
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("SHIPPING_WEAR_PREVIEW")
	if not output.is_empty(): get_viewport().get_texture().get_image().save_png(output)
	print("WEAR_RUNTIME_PASS ", checks)
	get_tree().quit()
