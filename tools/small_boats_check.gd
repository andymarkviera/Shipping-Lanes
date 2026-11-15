extends SceneTree
## Patch 2.4 item 8: the small boats family. Records and prices (cheap, no
## cargo, fastest the racer), toon models with mooring fairleads, and the wave
## jumping: at full speed on high water the offshore racer gets big airtime, the
## speedboat small hops and the fishing boat none; every landing is clean (no
## chatter, no flip) at 30 and 60 frames per second.
const Progression = preload("res://features/game/progression.gd")
const Hangar = preload("res://features/game/boat_hangar.gd")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
var checks: int = 0
var failures: int = 0

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await process_frame
	var root_node: Node3D = Node3D.new()
	root.add_child(root_node)
	# Patch 2.9.1: the family also holds the pirate ships (pirate_galleon_check).
	var boats: Array[String] = Progression.SMALL_KINDS.filter(func(kind: String) -> bool: return not Progression.PIRATE_KINDS.has(kind))
	expect(boats == ["small_fishing", "small_speedboat", "small_racer"] and Progression.SMALL_KINDS.slice(0, 3) == boats, "Three small boats, cheapest first")
	var top: Dictionary = {}
	for kind: String in boats:
		var definition: ShipDefinition = Progression.definition(kind)
		expect(definition.id.begins_with("ship_small_") and Progression.ladder_kind(definition.id) == kind, "%s has its own record and save ID" % kind)
		expect(definition.handling_error().is_empty(), "%s record is valid: %s" % [kind, definition.handling_error()])
		expect(definition.cargo_type_ids.is_empty() and definition.cargo_capacities.is_empty() and definition.dwt_tonnes == 0, "%s carries no cargo" % kind)
		expect(int(Progression.SHIPS[kind].price_minor) < int(Progression.SHIPS.container.price_minor), "%s is cheaper than the starter ship" % kind)
		expect(Hangar.ladder().has(kind) and Hangar.family_of(kind) == "small" and Hangar.tier_of(kind) == Progression.small_tier(kind), "%s is in the hangar's Small boats family" % kind)
		expect(Progression.heavy_tier(kind) == 0 and Progression.bulk_tier(kind) == 0 and Progression.container_tier(kind) == 0, "%s is in no cargo family" % kind)
		top[kind] = definition.forward_acceleration_mps2 / definition.linear_drag_per_second
		expect(top[kind] <= CollisionRules.SUPPORTED_SPEED_MPS, "%s is within the collision speed cap" % kind)
		var model: Node3D = CHUNKY_LOOK.model(kind, definition)
		for marker: String in ["MooringBowL", "MooringBowR", "MooringSternL", "MooringSternR"]:
			expect(model.find_child(marker, true, false) != null, "%s model has %s" % [kind, marker])
		expect(model.get_child_count() > 8, "%s model is dressed (%d parts)" % [kind, model.get_child_count()])
		model.free()
	# Patch 2.9 item 4: speedboat 50 kn, offshore (cigarette) racer 200 kn.
	expect(absf(Hangar.top_knots(Progression.definition("small_speedboat")) - 50.0) < 0.05, "The speedboat tops out at 50 kn")
	expect(absf(Hangar.top_knots(Progression.definition("small_racer")) - 200.0) < 0.05, "The offshore racer tops out at 200 kn")
	expect(top.small_racer > top.small_speedboat and top.small_speedboat > top.small_fishing, "The racer is fastest, the fishing boat slowest")
	# A save naming a small boat by its record ID reads it as the kind.
	var save: Dictionary = {"ship": "ship_small_racer_03", "fleet": {"container": {"fuel": 1.0, "condition": 1.0}, "ship_small_racer_03": {"fuel": 0.5, "condition": 1.0}}}
	Progression.migrate(save)
	expect(save.ship == "small_racer" and save.fleet.has("small_racer"), "Small boat record IDs migrate to kinds")
	var air: Dictionary = {}
	for fps: int in [30, 60]:
		for kind: String in boats:
			air["%s@%d" % [kind, fps]] = ride(root_node, kind, fps, top[kind])
	for fps: int in [30, 60]:
		var racer: float = air["small_racer@%d" % fps]
		var speedboat: float = air["small_speedboat@%d" % fps]
		expect(racer >= 0.7, "The racer gets big airtime at %d fps (%.2f s)" % [fps, racer])
		expect(speedboat > 0.05 and speedboat < racer * 0.7, "The speedboat jumps, but less than the racer, at %d fps (%.2f s)" % [fps, speedboat])
		expect(air["small_fishing@%d" % fps] == 0.0, "The fishing boat never leaves the water at %d fps" % fps)
	expect(absf(air["small_racer@30"] - air["small_racer@60"]) <= 0.35 * air["small_racer@60"], "Racer airtime does not depend on the frame rate")
	# Patch 2.9 item 5: the cigarette-style racer model, level at rest, bow-up on the plane.
	var racer_model: Node3D = CHUNKY_LOOK.model("small_racer", Progression.definition("small_racer"))
	var racer_hull: MeshInstance3D = racer_model.get_node("Hull") as MeshInstance3D
	var bounds: AABB = racer_hull.mesh.get_aabb()
	expect(bounds.size.z / bounds.size.x >= 4.0, "The racer hull is long and narrow (%.1f : 1)" % (bounds.size.z / bounds.size.x))
	expect(bounds.position.y < -1.0 and bounds.end.y < 2.0, "The racer hull is a low deep-V (keel %.2f m, deck %.2f m)" % [bounds.position.y, bounds.end.y])
	expect(racer_model.get_child_count() >= 40, "The racer has seats, windscreen and four outboards (%d parts)" % racer_model.get_child_count())
	racer_model.free()
	var racer_def: ShipDefinition = Progression.definition("small_racer")
	expect(racer_def.plane_trim_degrees > 0.0 and Progression.definition("small_speedboat").plane_trim_degrees == 0.0, "Only the racer has a planing trim")
	var rest: Vector2 = trim(root_node, racer_def, 0.0)
	expect(absf(rest.x) <= deg_to_rad(0.6) and absf(rest.y) < 0.05, "The racer floats level at rest (%.2f deg, %.2f m)" % [rad_to_deg(rest.x), rest.y])
	var planing: Vector2 = trim(root_node, racer_def, 20.0)
	expect(planing.x <= -deg_to_rad(3.5), "The racer rides bow-up on the plane (%.2f deg)" % rad_to_deg(planing.x))
	expect(planing.y > 0.1, "The racer lifts on the plane so the stern stays clear (%.2f m)" % planing.y)
	print("SMALL_BOATS_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

## Runs a boat at full speed for 60 s on high water. Returns its longest jump.
func ride(parent: Node3D, kind: String, fps: int, speed: float) -> float:
	var definition: ShipDefinition = Progression.definition(kind)
	var body: CharacterBody3D = CharacterBody3D.new()
	parent.add_child(body)
	var motion: ShipVisualMotion = ShipVisualMotion.new()
	motion.body = body
	motion.quality = 2
	motion.configure_hull(definition)
	body.add_child(motion)
	motion.set_process(false)
	var landings: Array[float] = []
	motion.landed.connect(func(impact: float) -> void: landings.append(impact))
	var step: float = 1.0 / fps
	var jumps: int = 0
	var was_airborne: bool = false
	var last_y: float = 0.0
	var worst_step: float = 0.0
	var steepest: float = 0.0
	var rolled: float = 0.0
	var finite: bool = true
	var shallow_landings: int = 0
	var air_since: float = 0.0
	for tick: int in range(60 * fps):
		# Speed up for the first 5 s, then hold full speed; a gentle turn now and then.
		body.velocity = Vector3(0, 0, speed * minf(1.0, tick * step / 5.0))
		if tick % (fps * 12) == 0: body.rotation.y += 0.05
		motion._process(step)
		finite = finite and motion.position.is_finite() and motion.rotation.is_finite()
		if motion.airborne and not was_airborne:
			jumps += 1
			air_since = 0.0
		if motion.airborne: air_since += step
		if not motion.airborne and was_airborne and air_since < 0.1: shallow_landings += 1
		was_airborne = motion.airborne
		if tick > 0: worst_step = maxf(worst_step, absf(motion.position.y - last_y))
		last_y = motion.position.y
		steepest = maxf(steepest, absf(motion.rotation.x))
		rolled = maxf(rolled, absf(motion.rotation.z))
	var label: String = "%s at %d fps" % [kind, fps]
	print("JUMP %s: %d jumps, longest %.2f s, %d landings (hardest %.2f), max pitch %.1f deg, max roll %.1f deg, biggest height step %.3f m" % [label, jumps, motion.longest_air_s, landings.size(), landings.max() if not landings.is_empty() else 0.0, rad_to_deg(steepest), rad_to_deg(rolled), worst_step])
	expect(finite, "%s stays finite" % label)
	expect(steepest <= deg_to_rad(14.01) and rolled <= deg_to_rad(12.01), "%s never flips (pitch and roll stay mild)" % label)
	expect(worst_step <= 12.0 / fps, "%s moves smoothly, no snaps (%.3f m in one frame)" % [label, worst_step])
	expect(shallow_landings <= maxi(1, jumps / 5), "%s does not chatter on the water (%d of %d jumps shorter than 0.1 s)" % [label, shallow_landings, jumps])
	body.queue_free()
	return motion.longest_air_s

## Patch 2.9 item 5: average pitch and height of a hull held at one speed on
## flat water (no ocean, so no swell or jumps) after it has settled.
func trim(parent: Node3D, definition: ShipDefinition, speed: float) -> Vector2:
	var body: CharacterBody3D = CharacterBody3D.new()
	parent.add_child(body)
	var motion: ShipVisualMotion = ShipVisualMotion.new()
	motion.body = body
	motion.quality = 0
	motion.configure_hull(definition)
	motion.jump_lift = 0.0
	body.add_child(motion)
	motion.set_process(false)
	body.velocity = Vector3(0, 0, speed)
	var pitch: float = 0.0
	var height: float = 0.0
	var samples: int = 0
	for tick: int in range(30 * 60):
		motion._process(1.0 / 60.0)
		if tick >= 10 * 60:
			pitch += motion.rotation.x
			height += motion.position.y
			samples += 1
	body.queue_free()
	return Vector2(pitch / samples, height / samples)
