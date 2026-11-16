extends SceneTree
## Patch 2.9.1 item 3: living sails, rigging and flags on both pirate ships.
## The cloth data every sail vertex carries, ropes that can swing, each ship's
## own materials, sails that unfurl with the throttle and furl once stopped,
## fill with speed and back astern, flags that stream, a swing that follows the
## roll without a snap, and a wake at full strength near each hull's own speed.
const Progression = preload("res://features/game/progression.gd")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const GALLEON = preload("res://features/toon/pirate_galleon.gd")
const RIG = preload("res://features/toon/pirate_rig.gd")
const STEP: float = 1.0 / 60.0
var checks: int = 0
var failures: int = 0

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await process_frame
	for kind: String in Progression.PIRATE_KINDS:
		check_model(kind)
		check_sailing(kind)
		check_wake(kind)
	var cargo: ShipDefinition = Progression.definition("container_1")
	var wake: ShipWake = ShipWake.new()
	expect(cargo.wake_full_speed_mps == 0.0 and wake.full_speed_mps == ShipWake.FULL_STRENGTH_SPEED_MPS, "Cargo ships keep the fleet's wake speed")
	wake.free()
	print("PIRATE_RIG_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func check_model(kind: String) -> void:
	var definition: ShipDefinition = Progression.definition(kind)
	var model: Node3D = CHUNKY_LOOK.model(kind, definition)
	TOON_LOOK.apply(model)
	root.add_child(model)
	var rig: Node = model.get_node_or_null("Rig")
	if not expect(rig != null and rig.get_script() == RIG, "%s has a rig" % kind): return
	var sails: MeshInstance3D = model.get_node("Sails") as MeshInstance3D
	var ropes: MeshInstance3D = model.get_node("Rigging") as MeshInstance3D
	var flags: MeshInstance3D = model.get_node("Flags") as MeshInstance3D
	var cloth: ShaderMaterial = sails.material_override as ShaderMaterial
	expect(cloth == rig.sails and cloth.shader == RIG.CLOTH_SHADER and cloth.next_pass == rig.sail_ink and rig.sail_ink.shader == RIG.CLOTH_OUTLINE_SHADER, "%s sails: toon cloth that moves, with an ink outline" % kind)
	expect(ropes.material_override == rig.ropes and rig.ropes.shader == RIG.CLOTH_SHADER and rig.ropes.next_pass == null, "%s ropes move with the same shader, no outline" % kind)
	expect(flags.material_override == rig.flags and rig.flags.shader == RIG.FLAG_SHADER, "%s flags have their own material" % kind)
	var other: Node3D = CHUNKY_LOOK.model(kind, definition)
	expect(other.get_node("Rig").sails != cloth and (other.get_node("Sails") as MeshInstance3D).mesh == sails.mesh, "%s: each ship has its own materials on shared meshes" % kind)
	other.free()
	# The hangar's ship has no hull motion above it: sails set, nothing to run.
	expect(not rig.is_processing() and rig.sail_set == 1.0 and cloth.get_shader_parameter("sail_set") == 1.0, "%s shows her sails set in the hangar" % kind)
	# Sail vertices: furled spot and belly.
	var arrays: Array = sails.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var furled: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var belly: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	if expect(furled != null and belly != null and furled.size() == points.size() * 4 and belly.size() == points.size() * 4, "%s: every sail vertex carries its furled spot and belly" % kind):
		var size: Vector3 = definition.hull_size_m
		var box: AABB = sails.mesh.get_aabb().grow(1.0)
		var inside: bool = true
		var pinned: int = 0
		var deepest: float = 0.0
		var orders: Dictionary = {}
		var gathered: float = 0.0
		for index: int in points.size():
			var spot: Vector3 = Vector3(furled[index * 4], furled[index * 4 + 1], furled[index * 4 + 2])
			var out: Vector3 = Vector3(belly[index * 4], belly[index * 4 + 1], belly[index * 4 + 2])
			if spot != Vector3.ZERO: pinned += 1
			inside = inside and spot.is_finite() and out.is_finite() and box.has_point(spot)
			deepest = maxf(deepest, out.length())
			orders[snappedf(furled[index * 4 + 3], 0.01)] = true
			gathered += spot.distance_to(points[index])
		expect(pinned == points.size(), "%s: no sail vertex was left unpinned" % kind)
		expect(inside and absf(box.position.x) <= size.x, "%s: furled cloth stays on its own spars" % kind)
		expect(deepest > 1.0 and deepest < 4.0, "%s: sails belly by up to %.1f m" % [kind, deepest])
		expect(orders.size() >= 6, "%s: %d sails unfurl one after another" % [kind, orders.size()])
		expect(gathered / points.size() > 2.0, "%s: furling gathers the cloth (%.1f m on average)" % [kind, gathered / points.size()])
	# Ropes: the long ones can bow, the ends stay made fast.
	var rope_arrays: Array = ropes.mesh.surface_get_arrays(0)
	var reach: PackedFloat32Array = rope_arrays[Mesh.ARRAY_CUSTOM1]
	if expect(reach != null and reach.size() == (rope_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 4, "%s: rope vertices carry their swing" % kind):
		var most: float = 0.0
		var still: int = 0
		for index: int in reach.size() / 4:
			most = maxf(most, reach[index * 4 + 3])
			if reach[index * 4 + 3] == 0.0: still += 1
		expect(most > 0.2 and most <= 0.601, "%s: long ropes bow by up to %.2f m" % [kind, most])
		expect(still > reach.size() / 16, "%s: rope ends and short ropes stay put" % kind)
	var triangles: int = ropes.mesh.get_faces().size() / 3
	print("RIG %s: rigging %d triangles" % [kind, triangles])
	expect(triangles < 16000, "%s: the rigging is still light (%d triangles)" % [kind, triangles])
	var colours: PackedColorArray = flags.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var lengths: Dictionary = {}
	for colour: Color in colours: lengths[snappedf(colour.a * 16.0, 0.1)] = true
	expect(lengths.size() >= 3 and lengths.keys().min() > 3.0 and lengths.keys().max() <= 16.0, "%s: each flag tells the shader its length" % kind)
	model.queue_free()

## A hull that can be given a throttle order, like HandlingShip.
func helm() -> CharacterBody3D:
	var script: GDScript = GDScript.new()
	script.source_code = "extends CharacterBody3D\nvar commanded_throttle: float = 0.0\n"
	script.reload()
	var body: CharacterBody3D = CharacterBody3D.new()
	body.set_script(script)
	return body

func check_sailing(kind: String) -> void:
	var definition: ShipDefinition = Progression.definition(kind)
	var body: CharacterBody3D = helm()
	root.add_child(body)
	var motion: ShipVisualMotion = ShipVisualMotion.new()
	motion.body = body
	motion.quality = 2
	motion.configure_hull(definition)
	body.add_child(motion)
	motion.set_process(false)
	var model: Node3D = CHUNKY_LOOK.model(kind, definition)
	motion.add_child(model)
	var rig: Node = model.get_node("Rig")
	rig.set_process(false)
	expect(rig.motion == motion and rig.sail_set == 0.0, "%s at sea starts with her sails furled" % kind)
	var top: float = definition.forward_acceleration_mps2 / definition.linear_drag_per_second
	var smooth: bool = true
	var finite: bool = true
	var run_for: Callable = func(seconds: float, throttle: float, speed: float) -> void:
		for tick: int in range(int(seconds * 60.0)):
			body.set("commanded_throttle", throttle)
			body.velocity = body.global_basis.z * speed
			body.global_position += body.velocity * STEP
			motion._process(STEP)
			var before: Vector3 = Vector3(rig.sail_set, rig.fill, rig.swing)
			rig.advance(STEP)
			var moved: Vector3 = (Vector3(rig.sail_set, rig.fill, rig.swing) - before).abs()
			smooth = smooth and moved.x <= 0.01 and moved.y <= 0.05 and moved.z <= 0.05
			finite = finite and is_finite(rig.sail_set) and is_finite(rig.fill) and is_finite(rig.swing) and is_finite(rig.flow) and is_finite(rig.stream)
	run_for.call(20.0, 0.0, 0.0)
	expect(rig.sail_set == 0.0, "%s keeps her sails furled while stopped" % kind)
	expect(rig.stream < 0.3, "%s: flags hang in light air at rest (%.2f)" % [kind, rig.stream])
	run_for.call(1.0, 1.0, 0.0)
	expect(rig.sail_set > 0.1 and rig.sail_set < 0.5, "%s starts to unfurl as soon as the throttle goes up" % kind)
	run_for.call(RIG.UNFURL_S, 1.0, top * 0.3)
	expect(rig.sail_set == 1.0, "%s has every sail set %.0f s later" % [kind, RIG.UNFURL_S])
	var worst_swing: float = 0.0
	for leg: int in 6:
		run_for.call(10.0, 1.0, top)
		worst_swing = maxf(worst_swing, absf(rig.swing))
	expect(rig.fill > 0.95 and rig.stream > 0.95, "%s: sails fill and flags stream at full speed (%.2f, %.2f)" % [kind, rig.fill, rig.stream])
	expect(rig.flow > 1.0, "%s: the cloth flutters faster with speed" % kind)
	expect(worst_swing > 0.05 and worst_swing <= RIG.MAX_SWING, "%s: cloth and ropes swing with the roll (%.2f)" % [kind, worst_swing])
	rig.show_state()
	expect(is_equal_approx(rig.sails.get_shader_parameter("fill"), rig.fill) and is_equal_approx(rig.sail_ink.get_shader_parameter("sail_set"), 1.0) and is_equal_approx(rig.ropes.get_shader_parameter("swing"), rig.swing) and is_equal_approx(rig.flags.get_shader_parameter("stream"), rig.stream), "%s: the materials are told" % kind)
	# Throttle to zero with way on: sails stay set until she has slowed right down.
	run_for.call(8.0, 0.0, top * 0.5)
	expect(rig.sail_set == 1.0, "%s keeps sail on while she still carries way" % kind)
	run_for.call(RIG.FURL_S + 0.5, 0.0, 0.0)
	expect(rig.sail_set == 0.0, "%s furls once stopped" % kind)
	run_for.call(12.0, -1.0, -top * 0.3)
	expect(rig.sail_set == 1.0 and rig.fill < -0.2, "%s: going astern backs the sails (%.2f)" % [kind, rig.fill])
	expect(smooth and finite, "%s: nothing snaps and every number stays finite" % kind)
	body.queue_free()

func check_wake(kind: String) -> void:
	var definition: ShipDefinition = Progression.definition(kind)
	var top: float = definition.forward_acceleration_mps2 / definition.linear_drag_per_second
	expect(definition.wake_full_speed_mps > top and definition.wake_full_speed_mps < ShipWake.FULL_STRENGTH_SPEED_MPS, "%s has her own wake speed (%.1f m/s for a %.1f m/s hull)" % [kind, definition.wake_full_speed_mps, top])
	var share: float = top / definition.wake_full_speed_mps
	expect(share >= 0.75 and share <= 0.95, "%s throws %.0f%% of a full wake and bow wave at top speed (was %.0f%%)" % [kind, share * 100.0, top / ShipWake.FULL_STRENGTH_SPEED_MPS * 100.0])
	expect(definition.wake_half_length_m <= definition.hull_size_m.z / 2.0 and definition.wake_half_width_m <= definition.hull_size_m.x / 2.0, "%s: the wake fits the hull" % kind)
	expect(definition.plane_trim_degrees == 0.0 and definition.jump_lift == 0.0, "%s is a displacement hull: no planing trim, level at rest" % kind)
