extends Node
var checks: int = 0
func verify(value: bool, description: String) -> void:
	assert(value, description)
	checks += 1
	print("PASS ", description)
func _ready() -> void:
	var view = preload("res://features/ports/port_test.tscn").instantiate()
	view.save_enabled = false
	add_child(view)
	await get_tree().physics_frame
	await get_tree().process_frame
	for heavy: bool in [false, true]:
		if heavy:
			view.heavy_mode = true
			verify(view.select_port(1), "switch to heavy loader")
		await get_tree().physics_frame
		view.ship.simulation_paused = true
		view.ship.state.condition = 0.4
		view.ship.state.fuel_liters = view.ship.definition.fuel_capacity_liters * 0.3
		var hud = view.helm.gauge_display
		hud._process(0)
		verify(is_equal_approx(hud.gauges.condition,0.4) and is_equal_approx(hud.gauges.fuel,0.3), "both gauges read selected hull and tank capacity")
		view.helm.throttle_display.hide()
		verify(hud.visible, "gauges independent of hidden docking throttle panel")
		var before: float = view.ship.state.condition
		hud.gauges.low_condition_threshold = 0.9
		hud._process(0)
		verify(view.ship.state.condition == before, "visual threshold does not mutate ship condition")
		view._process(0)
		view.set_process(false)
		view.set_physics_process(false)
		view.services.show()
		for frame: int in range(45): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var folder: String = OS.get_environment("SHIPPING_GAUGE_PREVIEW")
		if not folder.is_empty(): get_viewport().get_texture().get_image().save_png(folder + ("/gauges-heavy.png" if heavy else "/gauges-container.png"))
	view.queue_free()
	await get_tree().process_frame
	print("SHARED_GAUGES_PASS ",checks)
	get_tree().quit()
