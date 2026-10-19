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
		check(absf(scene.visual_root.position.y) <= 0.14, "Visual bob is bounded")
	check(scene.ocean.elapsed > 0.5, "Pattern animation clock advances")
	scene.ocean.apply_palette(load("res://features/water/coastal_ocean.tres"))
	check(scene.ocean.ocean_material.get_shader_parameter("surface_color") == scene.ocean.palette.surface_color, "Coastal palette applies without changing shader")
	check(scene.ship.transform == body_transform, "Palette change cannot move ship")
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
