extends RefCounted
## Session authority for physical heavy cargo. No expiry or player transfers.
var active: Dictionary = {}
var completed: Dictionary = {}
var reward_pending: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

## Patch 2.2 item 3: pay of a tier's jobs as a multiple of ship 1's, and the
## size of each of the three loads as a share of the ship's biggest load.
const TIER_PAY: Array[int] = [1, 6, 18, 42, 90]
const LOAD_SHARE: Array[float] = [0.7, 0.85, 0.95]
## Patch 2.4 item 6: job i carries look i (heavy_load_looks.gd) on every tier.
const LOOKS = preload("res://features/cargo/heavy_load_looks.gd")

## The three jobs at a port for one tier. Ship 1 keeps its M4 IDs
## ("<port>_heavy_<i>"); tiers 2-5 are "<port>_heavy_t<tier>_<i>".
func list_at(port_id: String, tier: int = 1) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i: int in 3:
		var id: String = ("%s_heavy_%d" % [port_id, i]) if tier == 1 else ("%s_heavy_t%d_%d" % [port_id, tier, i])
		var title: String = LOOKS.NAMES[i] if tier == 1 else "%s, %d t" % [LOOKS.NAMES[i], roundi(load_of(tier, i).mass_kg / 1000.0)]
		rows.append({"id": id, "title": title, "reward_minor": (70000 + i * 15000) * TIER_PAY[tier - 1], "tier": tier, "state": "completed" if completed.has(id) else ("accepted" if active.get("id", "") == id else "available")})
	return rows

## Every tier's jobs at a port, for checking saves.
func list_all(port_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for tier: int in range(1, 6): rows.append_array(list_at(port_id, tier))
	return rows

## Tier of a heavy job ID, 1 for the M4 IDs.
static func tier_of(id: String) -> int:
	var parts: PackedStringArray = id.split("_heavy_")
	if parts.size() == 2 and parts[1].length() == 4 and parts[1][0] == "t" and parts[1][1] in "2345": return int(parts[1][1])
	return 1

## Size and mass of load `index` for a tier: a share of that tier's biggest load.
## Tier 1 keeps the one prototype load.
static func load_of(tier: int, index: int) -> Dictionary:
	if tier <= 1: return {"size": Vector3(14, 8, 32), "mass_kg": 0.0, "look": index}
	var hull: Vector3 = (load("res://features/game/progression.gd").definition("heavy_%d" % tier) as ShipDefinition).hull_size_m
	var k: Vector3 = Vector3(hull.x / 24.0, 1.0, hull.z / 90.0)
	var share: float = LOAD_SHARE[index]
	return {"size": Vector3(14, 8, 32) * Vector3(k.x, sqrt(k.x), k.z) * share, "mass_kg": 200000.0 * k.x * k.z * share, "look": index}

static func load_for(id: String) -> Dictionary:
	return load_of(tier_of(id), int(id.get_slice("_", id.get_slice_count("_") - 1)))

func accept(id: String, body: HandlingShip, port: Node3D, docked: bool) -> bool:
	if not docked or not body.docked or not body.has_method("attach_payload") or not active.is_empty() or body.attached: return false
	var job: Dictionary = {}
	var tier: int = tier_of(id)
	for row: Dictionary in list_at(port.definition.id, tier):
		if row.id == id and row.state == "available": job = row
	if job.is_empty(): return false
	# A bigger ship lifts a bigger, heavier piece. It must fit this hull.
	if body.has_method("use_job_load") and not body.use_job_load(load_for(id)): return false
	var pickup: Vector3 = port.to_global(Vector3(-port.quay_side * 95, -1, -80))
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = body.payload_shape.shape
	query.transform = Transform3D(port.global_basis, pickup + Vector3(0, 4, 0))
	query.collision_mask = CollisionRules.HULL | CollisionRules.SHORE | CollisionRules.CARGO_VISUAL
	query.exclude = [body.payload_body.get_rid()]
	if not port.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return false
	var destination: Vector3 = port.to_global(Vector3(-port.quay_side * rng.randf_range(450, 850), 0, rng.randf_range(-1200, -800)))
	active = {"id": id, "state": "pickup", "origin": port.definition.id, "drop": destination, "reward_minor": job.reward_minor}
	body.payload_body.global_transform = Transform3D(port.global_basis, pickup)
	body.payload_body.visible = true
	body.payload_body.collision_layer = CollisionRules.HULL
	body.release_guard = func(): return can_release(body)
	return true

func can_release(body: HandlingShip) -> bool:
	if active.is_empty(): return true
	return active.state == "carrying" and body.cargo_mount.global_position.distance_to(active.drop) <= 30

func update(body: HandlingShip) -> void:
	if active.is_empty(): return
	if active.state == "pickup" and body.attached:
		# Ocean destination is geographic data on this job, not a fabricated port ID.
		active.state = "carrying"
	if active.state == "carrying" and not body.attached and body.payload_body.global_position.distance_to(active.drop) <= 30:
		completed[active.id] = active.duplicate(true)
		reward_pending += active.reward_minor
		active.clear()
		body.release_guard = Callable()
		body.payload_body.collision_layer = 0
		body.payload_body.hide()

func cancel_pickup(body: HandlingShip) -> bool:
	if active.is_empty() or active.state != "pickup" or body.attached: return false
	active.clear()
	body.release_guard = Callable()
	body.payload_body.collision_layer = 0
	body.payload_body.hide()
	return true
