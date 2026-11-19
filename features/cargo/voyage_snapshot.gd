extends RefCounted
## Bounded, object-free authority checkpoint. Restoring never executes saved code.
const Offers = preload("res://features/cargo/container_offers.gd")
const Manifest = preload("res://features/cargo/cargo_manifest.gd")
const Operations = preload("res://features/cargo/cargo_operation.gd")
const HeavyJobs = preload("res://features/cargo/heavy_ocean_job.gd")
const Heavy = preload("res://features/handling/heavy_lifter.gd")
const Progression = preload("res://features/game/progression.gd")
const PORT_IDS = ["port_brindle_quay", "port_slatewater_works"]

static func capture(view: Node3D) -> Dictionary:
	var body: HandlingShip = view.ship
	var operations: Dictionary = body.state.operations.snapshot()
	for record: Dictionary in operations.records.values(): record.ship_id = view.ship_key()
	var heavy: Dictionary = {}
	if view.heavy_mode:
		heavy = {"active": view.heavy_jobs.active.duplicate(true), "completed": view.heavy_jobs.completed.duplicate(true), "attached": body.attached, "height": body.deck_height, "target": body.deck_target, "payload_pose": floating_pose(body)}
	var data: Dictionary = {"version": 2, "realm": "private_port_voyage_v1", "owner": "preview_captain", "heavy_mode": view.heavy_mode,
		"port": view.world_ports.find(view.port), "pose": body.global_transform, "fuel": body.state.fuel_liters, "condition": body.state.condition,
		"offers": view.offers._offers.duplicate(true), "clock": view.offers._now_ms, "manifest": body.state.manifest.lines(),
		"operations": operations, "loading": view.loading.operation, "loading_offer": view.loading.offer_id, "sequence": view.loading.sequence,
		"docked": view.docking.state(view.owner_id) == "docked", "heavy": heavy, "heavy_completed": view.heavy_jobs.completed.duplicate(true), "credits": view.reward_minor}
	# The game writes version 5 (M4): money spent (M2, version 3), the ship being
	# sailed, the ships owned with their stored fuel and hull, the bulk job (M3,
	# version 4) and the pay banked from bulk and heavy jobs, which repeat.
	if view.get("game_mode") == true:
		data.version = 5
		data.spent = view.spent_minor
		data.ship = view.ship_kind
		data.fleet = view.fleet.duplicate(true)
		data.bulk = {"active": view.bulk_active, "done": []}
		data.banked = view.banked_minor
	return data

## Port IDs a save may name: all four in a version 5 game save, else the first two.
static func port_ids(d: Dictionary) -> Array:
	var ids: Array = PORT_IDS.duplicate()
	if d.get("version") == 5:
		ids.clear()
		for entry: Dictionary in Progression.WORLD: ids.append(entry.id)
	return ids

static func floating_pose(body: HandlingShip) -> Transform3D:
	# A new heavy lifter adds its floating load deferred. For the rest of that
	# tick the load is outside the tree, where global_transform is an engine error.
	var floating: Node3D = body.payload_body
	if floating.is_inside_tree(): return floating.global_transform
	var parent: Node3D = body.get_parent() as Node3D
	return (parent.global_transform if parent != null else Transform3D.IDENTITY) * floating.transform

static func pose_valid(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and value.origin.length() < 100000 and value.basis.is_equal_approx(value.basis.orthonormalized()) and value.basis.y.is_equal_approx(Vector3.UP) and value.basis.determinant() > .99

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(value) and value >= low and value <= high

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	var d: Dictionary = value
	var spent: int = 0
	var game: bool = d.get("version") == 5
	if d.get("version") in [4, 5]:
		Progression.migrate(d)
		if d.size() != (24 if game else 23) or not Progression.save_valid(d): return false
		spent = d.spent
	elif d.get("version") == 3:
		if d.size() != 20 or not d.get("spent") is int or d.spent < 0: return false
		spent = d.spent
	elif d.size() != 19: return false
	var ports: Array = port_ids(d)
	if d.get("version") not in [1, 2, 3, 4, 5] or d.get("realm") != "private_port_voyage_v1" or d.get("owner") != "preview_captain": return false
	for key: String in ["offers", "operations", "heavy", "heavy_completed"]:
		if not d.get(key) is Dictionary: return false
	for key: String in ["heavy_mode", "docked"]:
		if not d.get(key) is bool: return false
	for key: String in ["clock", "sequence", "credits", "port"]:
		if not d.get(key) is int or d[key] < 0: return false
	for key: String in ["loading", "loading_offer"]:
		if not d.get(key) is String: return false
	if d.port >= ports.size() or d.clock > 9000000000000 or d.sequence > 1000000000 or not pose_valid(d.get("pose")) or absf(d.pose.origin.y) > .01: return false
	# Patch 2.2: a container ship 2-5 checks its cargo and fuel against its own record.
	# Patch 2.2 item 3: so does a heavy-lift ship 2-5.
	var definition: ShipDefinition = Progression.definition(d.ship) if d.version >= 4 else (Heavy.DEFINITION if d.heavy_mode else preload("res://features/catalog/records/starter_ship.tres"))
	if not number(d.get("fuel"), 0, definition.fuel_capacity_liters) or not number(d.get("condition"), 0, 1) or not d.get("manifest") is Array: return false
	var manifest = Manifest.new(definition, PrototypeCatalog.RECORDS)
	var lines: Array[Dictionary] = []
	for row: Variant in d.manifest:
		if not row is Dictionary: return false
		lines.append(row)
	if not manifest.validate(lines).is_empty(): return false
	var seeded = Offers.new()
	# Port Test and older saves hold exactly the six seeded offers. The game (version
	# 5) also holds its own repeating offers, each one rebuilt from its ID to compare.
	if (not game and d.offers.size() != seeded._offers.size()) or d.offers.size() > 20000: return false
	var expected_lines: Array[Dictionary] = []
	var active_count: int = 0
	var credits: int = 0
	var ship_key: String = "preview_heavy" if d.heavy_mode else "preview_ship"
	for id: Variant in d.offers:
		if not id is String: return false
		var untouched: Dictionary = Offers.fresh(id, game)
		var row: Variant = d.offers[id]
		if untouched.is_empty() or not row is Dictionary or row.size() != untouched.size(): return false
		for key: String in untouched:
			if key not in ["state", "owner_id", "ship_id", "accepted_ms"] and row.get(key) != untouched[key]: return false
		if row.get("state") not in ["available", "accepted", "loaded", "delivered", "abandoned"] or not row.get("accepted_ms") is int: return false
		if row.state == "abandoned" and d.version < 2: return false
		if row.state == "available":
			if row.get("owner_id") != "" or row.get("ship_id") != "" or row.accepted_ms != -1: return false
		else:
			if row.get("owner_id") != d.owner or row.get("ship_id") != "preview_ship" or row.accepted_ms < 0 or row.accepted_ms > d.clock: return false
		if row.state in ["accepted", "loaded"]:
			active_count += 1
			if d.heavy_mode: return false
		if row.state == "loaded": expected_lines.append(seeded.batch(row))
		if row.state == "delivered": credits += row.reward_minor
		if row.state == "accepted" and (d.loading_offer != id or not d.docked or row.origin_port_id != ports[d.port]): return false
	if active_count > 1 or lines != expected_lines: return false
	if d.version >= 4:
		if active_count > 0 and not d.bulk.active.is_empty(): return false
		credits += Progression.earned(d)
	if d.operations.get("version") != 1 or not d.operations.get("records") is Dictionary or d.operations.records.size() > 10000: return false
	var live: int = 0
	var committed_offers: Array[String] = []
	for id: Variant in d.operations.records:
		var e: Variant = d.operations.records[id]
		if not id is String or not e is Dictionary or e.size() != 8 or e.get("id") != id or e.get("ship_id") != ship_key or e.get("rule_id") != "port_loading" or not e.get("payload") is Dictionary or not e.get("message") is String: return false
		var offer: Variant = d.offers.get(e.payload.get("offer_id"))
		if not offer is Dictionary or not number(e.get("duration"), .001, 86400) or not offer.get("quantity") is int or e.duration != Offers.loading_seconds(offer.quantity) or not number(e.get("elapsed"), 0, e.duration): return false
		if e.get("state") not in ["reserved", "running", "ready", "committed", "cancelled", "interrupted", "failed"]: return false
		if e.state == "reserved" and e.elapsed != 0: return false
		if e.state in ["ready", "committed"] and e.elapsed != e.duration: return false
		if e.state == "running" and e.elapsed >= e.duration: return false
		if e.state == "committed":
			if offer.state not in ["loaded", "delivered", "abandoned"] or committed_offers.has(offer.id): return false
			committed_offers.append(offer.id)
		if e.state not in Operations.TERMINAL:
			live += 1
			if d.loading != id or d.loading_offer != offer.id or offer.state != "accepted" or not d.docked: return false
	if live > 1 or (live == 0 and (not d.loading.is_empty() or not d.loading_offer.is_empty())): return false
	for row: Dictionary in d.offers.values():
		if row.state == "accepted" and live != 1: return false
		if row.state == "loaded" and not committed_offers.has(row.id): return false
	var jobs = HeavyJobs.new()
	var possible: Dictionary = {}
	for port: String in ports:
		# Patch 2.2 item 3: the game also offers heavy jobs for ships 2-5.
		for row: Dictionary in (jobs.list_all(port) if game else jobs.list_at(port)): possible[row.id] = row
	if d.heavy_completed.size() > possible.size(): return false
	for id: Variant in d.heavy_completed:
		if not heavy_job_valid(d.heavy_completed[id], possible, ports) or d.heavy_completed[id].id != id or d.heavy_completed[id].state != "carrying": return false
		credits += possible[id].reward_minor
	if d.credits != credits - spent: return false
	if not d.heavy_mode: return d.heavy.is_empty()
	var h: Dictionary = d.heavy
	if h.size() != 6 or not h.get("active") is Dictionary or h.get("completed") != d.heavy_completed or not h.get("attached") is bool: return false
	if not number(h.get("height"), Heavy.LOWERED, Heavy.RAISED) or not number(h.get("target"), Heavy.LOWERED, Heavy.RAISED) or not pose_valid(h.get("payload_pose")): return false
	if h.active.is_empty(): return not h.attached
	if active_count > 0 or not heavy_job_valid(h.active, possible, ports) or d.heavy_completed.has(h.active.id): return false
	# A ship cannot hold a heavy job sized for a bigger ship.
	if HeavyJobs.tier_of(h.active.id) > (Progression.heavy_tier(d.ship) if game else 1): return false
	return h.attached == (h.active.state == "carrying")

static func heavy_job_valid(job: Variant, possible: Dictionary, ports: Array = PORT_IDS) -> bool:
	if not job is Dictionary or job.size() != 5 or not possible.has(job.get("id")): return false
	if job.get("state") not in ["pickup", "carrying"] or job.get("origin") not in ports or job.get("reward_minor") != possible[job.id].reward_minor: return false
	if not job.id.begins_with(job.origin + "_heavy_") or not job.get("drop") is Vector3 or not job.drop.is_finite(): return false
	# The drop lies in open water off the origin port: 450 to 850 m out on its open
	# side and 800 to 1200 m south. 0.01 m of slack covers rounding far from zero.
	# Patch 2.9 item 6B: a job saved before its port moved lies off the old spot.
	var place: Dictionary = Progression.WORLD[Progression.port_index(job.origin)]
	if absf(job.drop.y) >= .01: return false
	return drop_off(job.drop, place.at, place.drop_side) or (place.has("was") and drop_off(job.drop, place.was, place.was_side))

static func drop_off(drop: Vector3, at: Vector3, side: float) -> bool:
	var local: Vector3 = drop - at
	var out: float = local.x * side
	return local.z >= -1200.01 and local.z <= -799.99 and out >= 449.99 and out <= 850.01

## A heavy job saved before Patch 2.9 item 6B moved its port, with its drop moved
## the same way: as far out and south of the new spot, on the new open side.
static func moved_job(job: Dictionary) -> Dictionary:
	var result: Dictionary = job.duplicate(true)
	if job.is_empty(): return result
	var place: Dictionary = Progression.WORLD[Progression.port_index(job.origin)]
	if not place.has("was") or drop_off(job.drop, place.at, place.drop_side): return result
	var local: Vector3 = job.drop - place.was
	result.drop = place.at + Vector3(local.x * float(place.was_side) * float(place.drop_side), 0, local.z)
	return result

static func restore(view: Node3D, data: Dictionary) -> bool:
	if not valid(data): return false
	view.heavy_mode = data.heavy_mode
	view.set("ship_kind", "heavy" if data.heavy_mode else "container")
	if data.version >= 4:
		view.set("ship_kind", data.ship)
		view.set("fleet", data.fleet.duplicate(true))
		view.set("bulk_active", data.bulk.active)
		# A version 4 save lists delivered bulk jobs. Their pay moves to the bank.
		view.set("banked_minor", Progression.earned(data))
	if not view.select_port(data.port, true): return false
	await view.get_tree().physics_frame # Deferred floating-body creation must finish.
	if not is_instance_valid(view.ship): return false
	var body: HandlingShip = view.ship
	# Patch 2.9 item 6B: a pose saved before the ports moved may now be inside land.
	# The ship then starts at its port's spawn, where select_port put it.
	var spawn: Transform3D = body.global_transform
	if Progression.afloat(data.pose, body.definition.hull_size_m): body.global_transform = data.pose
	body.zero_throttle()
	body.actual_throttle = 0
	body.velocity = Vector3.ZERO
	body.state.fuel_liters = data.fuel
	body.state.condition = data.condition
	view.offers._offers = data.offers.duplicate(true)
	view.offers._now_ms = data.clock
	view.offer_time = data.clock / 1000.0
	var lines: Array[Dictionary] = []
	for row: Dictionary in data.manifest: lines.append(row)
	if not body.state.manifest.replace(lines).ok: return false
	view.reward_minor = data.credits
	view.set("spent_minor", int(data.get("spent", 0)))
	view.heavy_jobs.completed = {}
	for id: String in data.heavy_completed: view.heavy_jobs.completed[id] = moved_job(data.heavy_completed[id])
	if data.heavy_mode:
		var h: Dictionary = data.heavy
		body.deck_height = h.height
		body.deck_target = h.target
		body.deck_visual.position.y = h.height - Heavy.RAISED
		body.deck_shape.position.y = h.height - .45
		body.cargo_mount.position.y = h.height
		body.payload_shape.position.y = h.height + 4
		# A load left floating moves with a ship moved to its port.
		body.payload_body.global_transform = body.global_transform * data.pose.affine_inverse() * h.payload_pose
		body.attached = h.attached
		view.heavy_jobs.active = moved_job(h.active)
		# Patch 2.2 item 3: the job's own load size; ship 1's is unchanged.
		if not h.active.is_empty() and not body.use_job_load(HeavyJobs.load_for(h.active.id)): return false
		body.payload_shape.position.y = h.height + body.payload_size.y * 0.5
		if h.attached:
			body.payload_visual.reparent(body.cargo_mount, false)
			body.payload_visual.transform = body.payload_pose()
			body.payload_shape.disabled = false
		body.payload_body.collision_layer = CollisionRules.HULL if not h.attached and not h.active.is_empty() else 0
		body.payload_body.visible = not h.active.is_empty()
		if not h.active.is_empty(): body.release_guard = func(): return view.heavy_jobs.can_release(body)
	if data.docked:
		# A docked save from before the ports moved sits off every berth; it docks
		# again from its port's spawn.
		if not view.docking.request_dock(1, view.service_id(), view.cargo_id()).ok:
			if data.heavy_mode and not data.heavy.attached: body.payload_body.global_transform = spawn * data.pose.affine_inverse() * data.heavy.payload_pose
			body.global_transform = spawn
			if not view.docking.request_dock(1, view.service_id(), view.cargo_id()).ok: return false
		# Long enough for the longest easy-docking slide (older saves may sit off centre).
		view.docking.advance(view.docking.MAX_SLIDE_SECONDS + .1)
		if view.docking.state(view.owner_id) != "docked": return false
	var operations: Dictionary = data.operations.duplicate(true)
	for record: Dictionary in operations.records.values(): record.ship_id = body.state.instance_id
	if not body.state.operations.restore(operations): return false
	if not data.loading.is_empty() and body.state.operations.record(data.loading).state == "reserved": body.state.operations.start(data.loading)
	view.loading.sequence = data.sequence
	view.loading.operation = data.loading
	view.loading.offer_id = data.loading_offer
	view.refresh_jobs()
	view.controls.wait_for_release = true
	return true
