extends Node
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var preferences: InputPreferences = InputPreferences.new()
	var old_data: Dictionary = preferences.to_data()
	old_data.erase("water_quality")
	check(InputPreferences.from_data(old_data).water_quality == 1, "Legacy settings default to medium water")
	for bad: Variant in [-1, 3, 1.5, "high", null]:
		var data: Dictionary = preferences.to_data()
		data.water_quality = bad
		check(InputPreferences.from_data(data) == null, "Invalid quality rejected: " + str(bad))
	for quality: int in range(3):
		preferences.water_quality = quality
		check(InputPreferences.from_data(JSON.parse_string(JSON.stringify(preferences.to_data()))).water_quality == quality, "Quality survives JSON round trip")
	var scene: Node3D = (load("res://features/handling/handling_test.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(0.1).timeout
	var body_transform: Transform3D = scene.ship.transform
	var collision: CollisionShape3D
	for child: Node in scene.ship.get_children():
		if child is CollisionShape3D: collision = child
	var collider_transform: Transform3D = collision.global_transform
	var focus_transform: Transform3D = scene.camera.focus.global_transform
	var previous_divisions: int = -1
	for quality: int in range(3):
		scene.ocean.set_quality(quality)
		scene.visual_root.quality = quality
		var previous_visual: Transform3D = scene.visual_root.transform
		await get_tree().create_timer(0.2).timeout
		check(scene.ocean.mesh.subdivide_width > previous_divisions, "Quality increases mesh resolution")
		previous_divisions = scene.ocean.mesh.subdivide_width
		check(scene.ocean.ocean_material.get_shader_parameter("quality") == quality, "Shader quality matches selected tier")
		check(scene.ship.transform == body_transform and scene.ship.velocity == Vector3.ZERO, "Water does not move navigation body")
		check(collision.global_transform == collider_transform, "Bobbing does not move collision")
		check(scene.camera.focus.global_transform == focus_transform, "Bobbing does not move camera focus")
		check(scene.visual_root.transform != previous_visual, "Visible hull animates at every quality")
		check(absf(scene.visual_root.heave_m) <= ShipVisualMotion.MAX_HEAVE_M and absf(scene.visual_root.rotation.x) <= ShipVisualMotion.MAX_PITCH_RAD and absf(scene.visual_root.rotation.z) <= ShipVisualMotion.MAX_ROLL_RAD, "Visual bob, pitch and roll are bounded")
	check(scene.ocean.elapsed > 0.5, "Pattern animation clock advances")
	# Exercise the actual preview control and visual offset without changing physics.
	scene.load_preview.pressed.emit()
	check(scene.visual_root.load_fraction == 0.5, "Preview selects half load")
	scene.load_preview.pressed.emit()
	check(scene.visual_root.load_fraction == 1.0, "Preview selects full load")
	scene.visual_root.set_process(false)
	for tick: int in range(240): scene.visual_root._process(1.0 / 60.0)
	check(is_equal_approx(scene.visual_root.load_sink_m, 0.85), "Full load settles at bounded visual offset")
	check(is_equal_approx(scene.visual_root.position.y, scene.visual_root.heave_m - 0.85), "Loaded hull sits a full load below its empty ride height")
	check(scene.ship.transform == body_transform and scene.ship.velocity == Vector3.ZERO, "Loading cannot move or accelerate body")
	check(collision.global_transform == collider_transform and scene.camera.focus.global_transform == focus_transform, "Loading preserves collision and camera focus")
	scene.visual_root.set_visual_load(NAN)
	check(scene.visual_root.load_fraction == 1.0, "Nonfinite load ignored")
	scene.visual_root.set_visual_load(-2.0)
	check(scene.visual_root.load_fraction == 0.0, "Negative load clamps to empty")
	scene.visual_root.set_visual_load(2.0)
	check(scene.visual_root.load_fraction == 1.0, "Excess load clamps to full")
	scene.load_preview.pressed.emit()
	for tick: int in range(240): scene.visual_root._process(1.0 / 60.0)
	check(scene.visual_root.load_fraction == 0.0 and is_zero_approx(scene.visual_root.load_sink_m), "Unloading returns smoothly to empty")
	check(scene.load_preview.get_viewport().gui_get_focus_owner() == null, "Preview releases focus for helm controls")
	scene.visual_root.set_process(true)
	scene.ocean.apply_palette(load("res://features/water/coastal_ocean.tres"))
	check(scene.ocean.ocean_material.get_shader_parameter("surface_color") == scene.ocean.palette.surface_color, "Coastal palette applies without changing shader")
	check(scene.ship.transform == body_transform, "Palette change cannot move ship")
	scene.wake.set_process(false)
	scene.ship.set_physics_process(false)
	scene.set_physics_process(false)
	scene.ship.velocity = Vector3(0, 0, 8)
	for tick: int in range(120):
		scene.ship.position.z += 8.0 / 60.0
		scene.wake.advance(1.0 / 60.0)
	check(scene.wake.samples.size() > 4, "Motion emits a lingering wake")
	var old_center: Vector3 = scene.wake.samples[0].center
	var wake_body: Transform3D = scene.ship.transform
	scene.wake.advance(0.01)
	check(scene.wake.samples[0].center == old_center, "Trail anchors stay in world space")
	check(scene.ship.transform == wake_body and scene.ship.velocity == Vector3(0, 0, 8), "Wake cannot change navigation")
	check(scene.wake.strength == 1.0, "Cruising motion produces full foam strength")
	var newest: Dictionary = scene.wake.section(scene.wake.samples.back())
	var oldest: Dictionary = scene.wake.section(scene.wake.samples[0])
	check(oldest.left.distance_to(oldest.right) > newest.left.distance_to(newest.right), "Wake arms open into a V behind the ship")
	check(oldest.fade < newest.fade, "Wake fades with age")
	scene.wake.update_spray()
	check(scene.wake.spray.emitting and scene.wake.spray.global_position.z > scene.ship.position.z, "Bow spray flies at the bow at speed")
	# Sailing feel: the hull rocks harder at speed and leans into a turn.
	var motion: ShipVisualMotion = scene.visual_root
	motion.set_process(false)
	var swing: Dictionary = {}
	for pace: float in [0.0, 8.0]:
		scene.ship.velocity = Vector3(0, 0, pace)
		var low: float = INF
		var high: float = -INF
		for tick: int in range(600):
			motion._process(1.0 / 60.0)
			if tick >= 120:
				low = minf(low, motion.rotation.x)
				high = maxf(high, motion.rotation.x)
		swing[pace] = high - low
	check(swing[8.0] > swing[0.0], "Pitching grows with speed")
	check(motion.speed_fraction > 0.95, "Hull motion follows ship speed")
	var upright: float = motion.lean
	for tick: int in range(120):
		scene.ship.rotation.y += deg_to_rad(3.0) / 60.0
		motion._process(1.0 / 60.0)
	check(motion.lean < upright - 0.5, "Hull leans into a turn")
	check(absf(motion.rotation.z) <= ShipVisualMotion.MAX_ROLL_RAD and absf(motion.rotation.x) <= ShipVisualMotion.MAX_PITCH_RAD, "Rocking at speed stays bounded")
	scene.ship.rotation.y = wake_body.basis.get_euler().y
	scene.ship.velocity = Vector3(0, 0, 8)
	check(scene.ship.transform.is_equal_approx(wake_body), "Rocking cannot change navigation")
	motion.set_process(true)
	check(OceanPresentation.swell_height(10, 20, 3, 0) == 0.0 and absf(OceanPresentation.swell_height(10, 20, 3, 2)) <= 0.93, "Swell is flat on low water and bounded otherwise")
	scene.ship.velocity = Vector3(0, 0, 0.5)
	scene.wake.advance(0.3)
	check(scene.wake.strength < 0.1, "Slow movement produces gentle ripples")
	scene.ship.velocity = Vector3(0, 0, -4)
	scene.wake.advance(0.4)
	check(scene.wake.samples.back().center.z > scene.ship.position.z, "Reverse wake starts at opposite end")
	scene.ship.velocity = Vector3(1, 0, 0)
	scene.wake.advance(0.4)
	check(scene.wake.samples.back().direction.x == 1.0, "Lateral movement uses actual velocity")
	scene.ship.position.x += 100
	scene.ship.velocity = Vector3.ZERO
	scene.wake.advance(0.1)
	check(scene.wake.samples.is_empty(), "Teleport clears stale trails")
	scene.ship.velocity = Vector3(0, 0, 8)
	for tick: int in range(100): scene.wake.advance(0.22)
	check(scene.wake.samples.size() <= ShipWake.MAX_SAMPLES, "Wake history stays bounded")
	for tier: int in range(3):
		scene.ocean.set_quality(tier)
		scene.wake.draw_foam()
		check(scene.wake.surface.get_surface_count() == 1 and scene.wake.foam.get_shader_parameter("quality") == tier, "Foam renders with matching water quality")
	scene.ship.velocity = Vector3.ZERO
	for tick: int in range(150): scene.wake.advance(0.1)
	scene.wake.draw_foam()
	check(scene.wake.samples.is_empty() and scene.wake.surface.get_surface_count() == 0, "Stopped boat leaves no permanent trail")
	scene.wake.update_spray()
	check(not scene.wake.spray.emitting, "Stopped boat throws no spray")
	scene.ship.transform = body_transform
	var service: PlayerControls = scene.controls
	var original_path: String = service.preferences_path
	service.preferences_path = "user://water-check-%s.json" % Time.get_ticks_usec()
	var panel: SettingsPanel = SettingsPanel.new()
	add_child(panel)
	panel.open(service)
	panel.water_quality.select(0)
	panel.save()
	service.load_preferences()
	check(service.preferences.water_quality == 0, "Settings UI saves and reloads low water")
	panel.open(service)
	panel.water_quality.select(2)
	panel.close()
	check(service.preferences.water_quality == 0, "Cancel leaves water preference unchanged")
	DirAccess.remove_absolute(service.preferences_path)
	service.preferences_path = original_path
	panel.queue_free()
	remove_child(scene)
	scene.queue_free()
	print("WATER_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
