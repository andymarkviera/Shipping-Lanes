extends SceneTree
## Patch 2.9.1 item 1: the pirate galleon. Its record (slow, heavy, wide turns,
## no cargo, prestige price, save ID), its place in the hangar's Other boats
## family, the model (every promised part, inside the hull box and under the
## bridges, few draw calls, distant detail not drawn), flags that flap, a
## deeper roll than a cargo hull of its beam, and level trim at rest.
const Progression = preload("res://features/game/progression.gd")
const Hangar = preload("res://features/game/boat_hangar.gd")
const CHUNKY_LOOK = preload("res://features/toon/chunky_look.gd")
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const GALLEON = preload("res://features/toon/pirate_galleon.gd")
const KIND: String = "small_galleon"
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
	var definition: ShipDefinition = Progression.definition(KIND)
	# The record and its place in the ladder.
	expect(Progression.SMALL_KINDS.has(KIND) and Progression.PIRATE_KINDS.has(KIND), "The galleon is a pirate ship in the small (Other boats) family")
	expect(definition.id == "ship_pirate_galleon_01" and Progression.ladder_kind(definition.id) == KIND, "It has its own record and save ID")
	expect(definition.handling_error().is_empty(), "The record is valid: " + definition.handling_error())
	expect(definition.cargo_type_ids.is_empty() and definition.cargo_capacities.is_empty() and definition.dwt_tonnes == 0, "It carries no cargo")
	expect(Progression.container_tier(KIND) + Progression.bulk_tier(KIND) + Progression.heavy_tier(KIND) == 0, "It is in no cargo family")
	expect(Hangar.ladder().has(KIND) and Hangar.family_of(KIND) == "small" and Hangar.tier_of(KIND) == 5, "The hangar lists it last in Other boats, after the brigantine")
	expect(Hangar.FAMILIES[4] == ["Other boats", "small"] and Hangar.FAMILY_NAMES.small == "Other boats", "The filter is named Other boats on the same family ID")
	expect(Hangar.capacity_text(KIND) == "none, just for fun", "The card says it carries nothing")
	var price: int = int(Progression.SHIPS[KIND].price_minor)
	expect(price >= int(Progression.SHIPS.container_4.price_minor) and price > 100 * int(Progression.SHIPS.small_racer.price_minor), "It is a prestige buy (%s credits)" % Hangar.credits(price))
	var save: Dictionary = {"ship": "ship_pirate_galleon_01", "fleet": {"container": {"fuel": 1.0, "condition": 1.0}, "ship_pirate_galleon_01": {"fuel": 0.5, "condition": 1.0}}}
	Progression.migrate(save)
	expect(save.ship == KIND and save.fleet.has(KIND), "Its record ID migrates to the kind")
	for old: String in ["ship_small_fishing_01", "ship_small_speedboat_02", "ship_small_racer_03", "ship_starter_container_01"]:
		expect(Progression.SHIPS.has(Progression.ladder_kind(old)), "Old save ID %s still maps to a ship" % old)
	# Handling: about 10-12 kn, slower than every cargo ship, wide turns.
	var knots: float = Hangar.top_knots(definition)
	expect(knots >= 10.0 and knots <= 12.0, "Top speed is 10-12 kn (%.1f)" % knots)
	var size: Vector3 = definition.hull_size_m
	var feeder: Vector3 = Progression.definition("container_2").hull_size_m
	var panamax: ShipDefinition = Progression.definition("container_3")
	expect(size.z >= feeder.z and size.z <= panamax.hull_size_m.z and size.x <= panamax.hull_size_m.x, "It is about as long as a mid-size container ship and fits its berths (%d x %d m)" % [roundi(size.z), roundi(size.x)])
	var slowest: float = 1000.0
	for kind: String in Progression.CONTAINER_KINDS + Progression.BULK_KINDS + Progression.HEAVY_KINDS:
		var other: ShipDefinition = Progression.definition(kind)
		slowest = minf(slowest, Hangar.top_knots(other))
		expect(definition.max_turn_rate_degrees < other.max_turn_rate_degrees and definition.turn_acceleration_degrees < other.turn_acceleration_degrees, "It turns more slowly than %s" % kind)
	expect(knots < slowest, "It is slower than every cargo ship (%.1f kn against %.1f)" % [knots, slowest])
	var seconds_to_speed: float = 3.0 / definition.linear_drag_per_second
	expect(seconds_to_speed > 3.0 / panamax.linear_drag_per_second, "It gathers way more slowly than the Panamax (%.0f s)" % seconds_to_speed)
	expect(definition.camera_distance_m >= size.z * 1.5 and definition.camera_radius_m >= size.z * 0.5, "The chase camera stands off far enough for the masts")
	# The model.
	var started: int = Time.get_ticks_usec()
	var model: Node3D = CHUNKY_LOOK.model(KIND, definition)
	var first_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	var again: Node3D = CHUNKY_LOOK.model(KIND, definition)
	var second_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	TOON_LOOK.apply(model)
	root.add_child(model)
	print("GALLEON build %.1f ms, cached %.2f ms" % [first_ms, second_ms])
	expect(first_ms < 1500.0 and second_ms < 20.0, "The model builds quickly and is cached (%.0f ms, then %.2f ms)" % [first_ms, second_ms])
	var triangles: int = 0
	var drawn: int = 0
	var bounds: AABB = AABB()
	for label: String in ["Hull", "Structure", "Detail", "Rigging", "Sails", "Glow", "Flags"]:
		var part: MeshInstance3D = model.get_node_or_null(label) as MeshInstance3D
		if not expect(part != null and part.mesh != null and part.mesh.get_surface_count() == 1, "The model has its %s" % label): continue
		expect(part.mesh == (again.get_node(label) as MeshInstance3D).mesh, "%s is shared between ships, not rebuilt" % label)
		var count: int = part.mesh.get_faces().size() / 3
		print("GALLEON %s: %d triangles" % [label, count])
		triangles += count
		drawn += 1
		# Flags fly aft of the hull box; everything else must stay inside it.
		if label != "Flags": bounds = part.mesh.get_aabb() if bounds.size == Vector3.ZERO else bounds.merge(part.mesh.get_aabb())
	again.free()
	expect(drawn == 7 and model.find_children("*", "MeshInstance3D", true, false).size() == 7, "The whole ship is seven meshes (few draw calls)")
	expect(triangles > 12000 and triangles < 40000, "Richly detailed but still low-poly (%d triangles)" % triangles)
	expect(bounds.position.z >= -size.z / 2.0 - 0.01 and bounds.end.z <= size.z / 2.0 + 0.01, "The model is as long as its collision box (%.1f to %.1f m)" % [bounds.position.z, bounds.end.z])
	expect(absf(bounds.position.x) <= size.x / 2.0 + 2.0 and bounds.end.x <= size.x / 2.0 + 2.0, "Guns and yards overhang the collision box by under 2 m (%.1f m half width)" % bounds.end.x)
	expect(bounds.end.y <= GALLEON.AIR_DRAFT_M and GALLEON.AIR_DRAFT_M <= Progression.BRIDGE_CLEARANCE_M - 15.0, "The masts pass 15 m under the bridges (%.1f m against %.0f m)" % [bounds.end.y, Progression.BRIDGE_CLEARANCE_M])
	expect(bounds.end.y >= 48.0, "The masts are tall (%.1f m)" % bounds.end.y)
	var hull: AABB = (model.get_node("Hull") as MeshInstance3D).mesh.get_aabb()
	expect(hull.position.y < -3.0 and hull.end.y > 18.0 and hull.size.x <= size.x, "A deep hull with a high stern castle (%.1f to %.1f m)" % [hull.position.y, hull.end.y])
	expect(GALLEON.MASTS.size() == 3, "Three masts")
	for label: String in GALLEON.MASTS:
		var mast: Dictionary = GALLEON.MASTS[label]
		expect(float(mast.truck) > float(mast.cross) and float(mast.cross) > float(mast.top) and float(mast.top) > GALLEON.deck_at(mast.z) + 10.0, "The %s mast stands in three lengths above its deck" % label)
	expect(GALLEON.deck_at(-45.0) > GALLEON.deck_at(-25.0) and GALLEON.deck_at(-25.0) > GALLEON.deck_at(0.0) and GALLEON.deck_at(30.0) > GALLEON.deck_at(0.0), "Poop, quarterdeck, waist and forecastle step as on a galleon")
	# Distant detail is not drawn; the big shapes always are.
	var detail: MeshInstance3D = model.get_node("Detail") as MeshInstance3D
	var rigging: MeshInstance3D = model.get_node("Rigging") as MeshInstance3D
	var furthest: float = maxf(60.0, definition.camera_radius_m * 8.0)
	expect(detail.visibility_range_end == GALLEON.DETAIL_RANGE_M and rigging.visibility_range_end == GALLEON.RIGGING_RANGE_M, "Detail and rigging stop drawing in the distance")
	expect(rigging.visibility_range_end > furthest and detail.visibility_range_end > furthest, "but never at the chase camera's furthest zoom (%.0f m)" % furthest)
	for label: String in ["Hull", "Structure", "Sails", "Flags", "Glow"]:
		expect((model.get_node(label) as MeshInstance3D).visibility_range_end == 0.0, "%s is drawn at every distance" % label)
	# Looks: toon shading with ink outlines, lit windows, flags that flap.
	var structure: ShaderMaterial = (model.get_node("Structure") as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	expect(structure != null and structure.shader == GALLEON.TOON_SHADER and structure.next_pass is ShaderMaterial, "Structure is toon shaded with an ink outline")
	expect(structure == detail.mesh.surface_get_material(0), "Structure and detail share one material")
	var toon: ShaderMaterial = (model.get_node("Hull") as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	expect(toon != null and toon.shader == GALLEON.TOON_SHADER and toon.next_pass != null, "Hull is toon shaded with an ink outline")
	# Patch 2.9.1 item 3: the sails have their own moving toon shader (pirate_rig_check).
	var cloth: ShaderMaterial = (model.get_node("Sails") as MeshInstance3D).material_override as ShaderMaterial
	expect(cloth != null and cloth.shader == GALLEON.RIG.CLOTH_SHADER and cloth.next_pass != null, "Sails are toon shaded with an ink outline")
	var glow: BaseMaterial3D = (model.get_node("Glow") as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
	expect(glow != null and glow.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Cabin windows and lanterns stay lit at night")
	var flags: ShaderMaterial = (model.get_node("Flags") as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	expect(flags != null and flags.shader == GALLEON.FLAG_SHADER and flags.shader.code.contains("TIME"), "The Jolly Roger and pennants flap")
	expect(GALLEON.JOLLY_ROGER.all(func(row: String) -> bool: return row.length() == 21) and "".join(GALLEON.JOLLY_ROGER).count("#") > 60, "The Jolly Roger carries a skull and crossbones")
	for marker: String in ["MooringBowL", "MooringBowR", "MooringSternL", "MooringSternR"]:
		var lead: Marker3D = model.find_child(marker, true, false) as Marker3D
		expect(lead != null and absf(lead.position.x) < size.x / 2.0 and lead.position.y > 10.0, "The model has %s on its rail" % marker)
	model.queue_free()
	# Motion: a deeper roll than a cargo hull of the same beam, never a capsize,
	# and level at rest.
	var roll: float = worst_roll(definition)
	var cargo_roll: float = worst_roll(panamax)
	print("GALLEON roll %.1f deg, Panamax %.1f deg" % [rad_to_deg(roll), rad_to_deg(cargo_roll)])
	expect(roll > cargo_roll * 1.2, "It rolls deeper than the Panamax (%.1f against %.1f deg)" % [rad_to_deg(roll), rad_to_deg(cargo_roll)])
	expect(roll <= deg_to_rad(14.0), "The roll stays safe (%.1f deg)" % rad_to_deg(roll))
	var rest: Vector3 = at_rest(definition)
	expect(absf(rest.x) <= deg_to_rad(0.6) and absf(rest.z) <= deg_to_rad(0.6) and absf(rest.y) < 0.05, "It floats level at rest (pitch %.2f, roll %.2f deg, %.2f m)" % [rad_to_deg(rest.x), rad_to_deg(rest.z), rest.y])
	print("PIRATE_GALLEON_CHECK_%s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func motion_for(definition: ShipDefinition, quality: int) -> ShipVisualMotion:
	var body: CharacterBody3D = CharacterBody3D.new()
	root.add_child(body)
	var motion: ShipVisualMotion = ShipVisualMotion.new()
	motion.body = body
	motion.quality = quality
	motion.configure_hull(definition)
	body.add_child(motion)
	motion.set_process(false)
	return motion

## The hardest roll in 120 s at full speed on high water, with a turn now and then.
func worst_roll(definition: ShipDefinition) -> float:
	var motion: ShipVisualMotion = motion_for(definition, 2)
	var body: CharacterBody3D = motion.body
	var speed: float = definition.forward_acceleration_mps2 / definition.linear_drag_per_second
	var worst: float = 0.0
	var smooth: bool = true
	var last: float = 0.0
	for tick: int in range(120 * 60):
		body.velocity = body.global_basis.z * speed
		body.global_position += body.velocity / 60.0
		if (tick / 600) % 2 == 1: body.rotation.y += deg_to_rad(definition.max_turn_rate_degrees) / 60.0
		motion._process(1.0 / 60.0)
		worst = maxf(worst, absf(motion.rotation.z))
		if tick > 0 and absf(motion.rotation.z - last) > deg_to_rad(0.5): smooth = false
		last = motion.rotation.z
	expect(smooth and motion.rotation.is_finite() and motion.position.is_finite(), "%s rolls smoothly, no snaps" % definition.display_name)
	body.queue_free()
	return worst

## Average pitch, height and roll held still on flat water.
func at_rest(definition: ShipDefinition) -> Vector3:
	var motion: ShipVisualMotion = motion_for(definition, 0)
	var sum: Vector3 = Vector3.ZERO
	var samples: int = 0
	for tick: int in range(60 * 60):
		motion._process(1.0 / 60.0)
		if tick >= 10 * 60:
			sum += Vector3(motion.rotation.x, motion.position.y, motion.rotation.z)
			samples += 1
	motion.body.queue_free()
	return sum / samples
