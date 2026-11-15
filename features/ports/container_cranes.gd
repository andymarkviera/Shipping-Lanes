extends Node3D
## Patch 2.4 item 5: quay cranes that move containers one at a time, the game
## only. Every berth of every port has PER_BERTH toon ship-to-shore cranes on
## rails along the quay, booms raised while idle. When a container ship is
## docked, cranes_for(capacity) of them lower their booms and work: on loading
## each container is lifted from the quay onto its slot, on unloading (delivery,
## or a cancelled load) lifted off again. Big ships get more cranes, each owning
## a band of bays, so a full ship 5 still loads in about a minute.
## Looks only: the manifest and the loading timer (port_loading.gd) stay the
## authority. While loading, loading_preview says how many containers of the
## job the timer has reached; the cranes start one move per container and
## Undock waits (busy()) until the last box is down.
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const VISUALS = preload("res://features/cargo/container_visuals.gd")
const Offers = preload("res://features/cargo/container_offers.gd")
const PER_BERTH: int = 6
const PARK_STEP_M: float = 47.0
## Closest two cranes can work (their bogies are 12 m long; bays of the
## biggest ship are 13.6 m apart).
const GAP_M: float = 13.0
## Port-local distances from the berth centreline toward the land (times quay_side).
const SEA_LEG_Q: float = 26.0
const LAND_LEG_Q: float = 38.0
const PICK_Q: float = 32.0
const BACK_Q: float = 48.0
const BOOM_TIP_Q: float = -30.0
const BOOM_Y: float = 52.0
const HOOK_TOP_Y: float = 45.0
const QUAY_TOP_Y: float = 4.0
const RAISED_RADIANS: float = 1.2
const ROLL_MPS: float = 20.0
const BOOM_SECONDS: float = 1.5
const MIN_PERIOD: float = 0.9
const MAX_PERIOD: float = 5.0
const SEEN_M: float = 3500.0
const ORANGE: Color = Color("f0a326")
const WHITE: Color = Color("f4efe1")
const INK: Color = Color("2d2f36")
const GLASS: Color = Color("7fc6d8")

## The docking authority whose docked ships are worked.
var docking: Node
## Callable(owner) -> Vector2i(containers of the loading job the timer has
## reached so far, job quantity); Vector2i.ZERO when nothing is loading.
var loading_preview: Callable
## Port -> Array (per berth) of Array (rail order) of crane dictionaries.
var ports: Dictionary = {}
## Owner -> the work on its docked ship.
var works: Dictionary = {}
var meshes: Dictionary = {}
var materials: Dictionary = {}

## Cranes for a ship of this many container slots: 2 for ship 1 up to 6 for
## ship 5 (fewer if the ship has fewer bays far enough apart).
static func cranes_for(capacity: int) -> int:
	return clampi(roundi(sqrt(capacity / 8.0)), 1, PER_BERTH)

## Seconds a crane takes per box when the busiest crane moves per_crane of a
## job of quantity boxes: a little quicker than the loading timer, which
## leaves time to roll from bay to bay.
static func period_for(quantity: int, per_crane: int) -> float:
	if quantity <= 0 or per_crane <= 0: return MIN_PERIOD
	return clampf(0.85 * Offers.loading_seconds(quantity) / per_crane, MIN_PERIOD, MAX_PERIOD)

## Boxes the busiest crane moves when quantity boxes share out over the bands.
static func most_per_crane(bands: Array, quantity: int) -> int:
	for most: int in range(1, quantity + 1):
		var total: int = 0
		for band: int in bands: total += mini(band, most)
		if total >= quantity: return most
	return quantity

func add_port(port: Node3D) -> void:
	if ports.has(port) or not ("berth_anchors" in port) or not ("quay_side" in port): return
	var berths: Array = []
	for anchor: Marker3D in port.berth_anchors:
		var row: Array = []
		for index: int in PER_BERTH:
			var crane: Dictionary = make_crane(port, anchor.position.z + (index - (PER_BERTH - 1) / 2.0) * PARK_STEP_M)
			crane.index = index
			row.append(crane)
		berths.append(row)
	ports[port] = berths

func busy(owner: int) -> bool:
	if not live(owner): return false
	var work: Dictionary = works[owner]
	if work.target != work.visuals.shown_count or work.visuals.target_count != work.visuals.shown_count: return true
	for crane: Dictionary in work.cranes:
		if not crane.move.is_empty(): return true
	return false

## The owner has work on a ship that still exists (a swapped ship ends it).
func live(owner: int) -> bool:
	if works.has(owner) and not is_instance_valid(works[owner].visuals): end_work(owner)
	return works.has(owner)

## Containers still to move for the owner's ship (0 when idle).
func remaining(owner: int) -> int:
	if not live(owner): return 0
	var work: Dictionary = works[owner]
	var moving: int = 0
	for crane: Dictionary in work.cranes:
		if not crane.move.is_empty(): moving += 1
	return maxi(absi(work.target - work.visuals.shown_count), moving)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if docking != null:
		for owner: int in docking.members.keys():
			var entry: Dictionary = docking.members[owner]
			var visuals: Node3D = visuals_of(entry.body)
			var ok: bool = entry.state == "docked" and visuals != null and ports.has(entry.port) and entry.berth_index >= 0 and entry.berth_index < ports[entry.port].size()
			if works.has(owner) and (not ok or works[owner].body != entry.body or works[owner].port != entry.port or works[owner].berth != entry.berth_index):
				end_work(owner)
			if ok and not works.has(owner): start_work(owner, entry, visuals)
			if works.has(owner): step_work(owner, delta)
			elif visuals != null and visuals.crane_driven and visuals.shown_count != visuals.target_count:
				# Away from the cranes (towed, swapped, loaded from a save): plain view.
				visuals.show_first(visuals.target_count)
	for owner: int in works.keys():
		if docking == null or not docking.members.has(owner): end_work(owner)
	for port: Node3D in ports:
		for berth: int in ports[port].size():
			park(port, berth, delta)
			for crane: Dictionary in ports[port][berth]: draw(port, crane)

static func visuals_of(body) -> Node3D:
	if not is_instance_valid(body) or body.get("assembly") == null: return null
	var visuals: Node3D = body.assembly.container_visuals
	return visuals if visuals != null and visuals.instances != null and visuals.capacity > 0 else null

func start_work(owner: int, entry: Dictionary, visuals: Node3D) -> void:
	var row: Array = ports[entry.port][entry.berth_index]
	# Bays: slots at the same port-local z, in order along the quay. Bays
	# closer than GAP_M stay with one crane.
	var to_port: Transform3D = entry.port.global_transform.affine_inverse() * visuals.instances.global_transform
	var bays: Dictionary = {}
	for slot: int in visuals.capacity:
		var z: float = snappedf((to_port * visuals.layout.centres[slot]).z, 0.5)
		if not bays.has(z): bays[z] = []
		bays[z].append(slot)
	var keys: Array = bays.keys()
	keys.sort()
	var count: int = mini(cranes_for(visuals.capacity), keys.size())
	var first: int = (PER_BERTH - count) / 2
	var cranes: Array = row.slice(first, first + count)
	visuals.hand_to_cranes()
	var work: Dictionary = {"body": entry.body, "port": entry.port, "berth": entry.berth_index, "visuals": visuals,
		"cranes": cranes, "target": visuals.shown_count, "batch": "", "period": MIN_PERIOD, "reserved": {}, "bands": [], "slot_z": {}}
	# Bands: runs of bays, about the same number of slots each, handed out to
	# the cranes in rail order.
	var share: float = float(visuals.capacity) / count
	var band: int = 0
	var taken: int = 0
	for crane: Dictionary in cranes:
		crane.band = []
		crane.move = {}
		crane.work = owner
		crane.want = crane.z
	var centres: PackedVector3Array = visuals.layout.centres
	for z: float in keys:
		if band < count - 1 and taken >= share * (band + 1): band += 1
		for slot: int in bays[z]: work.slot_z[slot] = z
		# Bay by bay along the band; in a bay, the bottom tier first.
		var bay: Array = bays[z]
		bay.sort_custom(func(a: int, b: int) -> bool: return centres[a].y < centres[b].y - 0.01 or (absf(centres[a].y - centres[b].y) <= 0.01 and a < b))
		cranes[band].band.append_array(bay)
		taken += bay.size()
	for crane: Dictionary in cranes: work.bands.append(crane.band.size())
	works[owner] = work

func end_work(owner: int) -> void:
	var work: Dictionary = works[owner]
	for crane: Dictionary in work.cranes:
		crane.move = {}
		crane.work = -1
		crane.carried.hide()
	works.erase(owner)

func step_work(owner: int, delta: float) -> void:
	var work: Dictionary = works[owner]
	var visuals: Node3D = work.visuals
	var preview: Vector2i = loading_preview.call(owner) if loading_preview.is_valid() else Vector2i.ZERO
	work.target = clampi(visuals.target_count + preview.x, 0, visuals.capacity)
	# One crane speed per batch: a loading job, or the boxes going ashore.
	var loads: int = 0
	var unloads: int = 0
	for crane: Dictionary in work.cranes:
		if crane.move.is_empty() or crane.move.done: continue
		if crane.move.kind == "load": loads += 1
		else: unloads += 1
	# One crane speed per batch: a loading job, or the boxes going ashore. A
	# load that has just committed keeps its speed for the last boxes.
	var batch: String = work.batch
	var quantity: int = 0
	if preview.y > 0:
		batch = "load%d_%d" % [preview.y, visuals.target_count]
		quantity = preview.y
	elif work.target < visuals.shown_count - unloads and not work.batch.begins_with("off"):
		batch = "off"
		quantity = visuals.shown_count - work.target
	elif work.target == visuals.shown_count and loads + unloads == 0:
		batch = ""
	if batch != work.batch:
		work.batch = batch
		if quantity > 0: work.period = period_for(quantity, most_per_crane(work.bands, quantity))
	for crane: Dictionary in work.cranes:
		crane.raised = maxf(0.0, crane.raised - delta / BOOM_SECONDS)
		if crane.move.is_empty():
			if crane.raised > 0.0: continue
			var slot: int = -1
			var kind: String = ""
			if visuals.shown_count + loads < work.target:
				kind = "load"
				for candidate: int in crane.band:
					if visuals.filled[candidate] == 0 and not work.reserved.has(candidate):
						slot = candidate
						break
			elif visuals.shown_count - unloads > work.target:
				kind = "unload"
				for at: int in range(crane.band.size() - 1, -1, -1):
					var candidate: int = crane.band[at]
					if visuals.filled[candidate] == 1 and not work.reserved.has(candidate):
						slot = candidate
						break
			if slot < 0:
				crane.want = crane.z
				continue
			# Wait while a neighbour at work is too close to that bay; idle
			# neighbours roll aside (park()).
			var z: float = entry_z(work, slot)
			crane.want = z
			if blocked(row_of(work), crane, z): continue
			crane.move = {"kind": kind, "slot": slot, "t": -1.0, "done": false}
			work.reserved[slot] = true
			if kind == "load": loads += 1
			else: unloads += 1
			crane.carried.mesh = work_mesh(visuals)
			crane.carried.material_override = material(visuals.slot_color(slot))
		var move: Dictionary = crane.move
		var local: Vector3 = slot_local(work, crane, move.slot)
		if move.t < 0.0:
			# Roll along the rails to the slot's bay first.
			var goal: float = crane.z + local.z
			crane.z = move_toward(crane.z, goal, ROLL_MPS * delta)
			if absf(goal - crane.z) < 0.05: move.t = 0.0
			continue
		move.t = minf(1.0, move.t + delta / work.period)
		var drop: float = 0.65 if move.kind == "load" else 0.3
		if not move.done and move.t >= drop:
			move.done = true
			visuals.set_slot(move.slot, move.kind == "load")
		if move.t >= 1.0:
			work.reserved.erase(move.slot)
			crane.move = {}

func row_of(work: Dictionary) -> Array:
	return ports[work.port][work.berth]

## Port-local z of the slot's bay.
static func entry_z(work: Dictionary, slot: int) -> float:
	return float(work.slot_z.get(slot, 0.0))

## A neighbour on the rails is moving a box within GAP_M of z.
static func blocked(row: Array, crane: Dictionary, z: float) -> bool:
	for index: int in [crane.index - 1, crane.index + 1]:
		if index < 0 or index >= row.size(): continue
		var other: Dictionary = row[index]
		if not other.move.is_empty() and absf(other.want - z) < GAP_M: return true
	return false

## The slot's container centre in the crane's frame.
func slot_local(work: Dictionary, crane: Dictionary, slot: int) -> Vector3:
	var visuals: Node3D = work.visuals
	return crane.node.global_transform.affine_inverse() * (visuals.instances.global_transform * visuals.layout.centres[slot])

## Idle cranes: booms up, back to their parking spots, out of the way of the
## cranes at work on their berth.
func park(port: Node3D, berth: int, delta: float) -> void:
	var row: Array = ports[port][berth]
	var goals: Array[float] = []
	# Cranes moving a box hold their bay; the others head for where they
	# want to be (a waiting crane its next bay, an idle one its parking
	# spot), pushed along to keep GAP_M from their neighbours.
	for crane: Dictionary in row:
		if crane.work < 0:
			crane.raised = minf(1.0, crane.raised + delta / BOOM_SECONDS)
			crane.want = crane.park_z
		goals.append(crane.want)
	for index: int in range(1, row.size()):
		if row[index].move.is_empty(): goals[index] = maxf(goals[index], goals[index - 1] + GAP_M)
	for index: int in range(row.size() - 2, -1, -1):
		if row[index].move.is_empty(): goals[index] = minf(goals[index], goals[index + 1] - GAP_M)
	for index: int in row.size():
		if row[index].move.is_empty(): row[index].z = move_toward(row[index].z, goals[index], ROLL_MPS * delta)

## Puts the crane, its boom, trolley, hoist rope, spreader and box in place.
func draw(port: Node3D, crane: Dictionary) -> void:
	var side: float = float(port.quay_side)
	crane.node.global_transform = port.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, crane.z))
	crane.boom.rotation.z = -side * RAISED_RADIANS * smoothstep(0.0, 1.0, crane.raised)
	var rest: Vector3 = Vector3(side * PICK_Q, HOOK_TOP_Y, 0)
	var hook: Vector3 = rest
	var carrying: bool = false
	var on_quay: bool = false
	var basis: Basis = Basis.IDENTITY
	if crane.work >= 0 and not crane.move.is_empty() and works.has(crane.work):
		var work: Dictionary = works[crane.work]
		var visuals: Node3D = work.visuals
		var height: float = visuals.layout.container_size_m.y
		var lift: float = height / 2.0 + 0.3
		var slot: Vector3 = slot_local(work, crane, crane.move.slot) + Vector3(0, lift, 0)
		var quay: Vector3 = Vector3(side * PICK_Q, QUAY_TOP_Y + height + 0.3, slot.z)
		rest.z = slot.z
		basis = (crane.node.global_basis.inverse() * visuals.instances.global_basis).orthonormalized()
		var t: float = crane.move.t
		if t < 0.0:
			rest.z = 0.0
			hook = rest
		elif crane.move.kind == "load":
			if t < 0.15: hook = rest.lerp(quay, smoothstep(0.0, 1.0, t / 0.15)); on_quay = true
			elif t < 0.2: hook = quay; carrying = true
			elif t < 0.65: hook = travel(quay, slot, (t - 0.2) / 0.45); carrying = true
			elif t < 0.7: hook = slot
			else: hook = travel(slot, rest, (t - 0.7) / 0.3)
		else:
			if t < 0.3: hook = travel(rest, slot, t / 0.3)
			elif t < 0.35: hook = slot; carrying = true
			elif t < 0.8: hook = travel(slot, quay, (t - 0.35) / 0.45); carrying = true
			elif t < 0.85: hook = quay; on_quay = true
			else: hook = rest.lerp(quay, 1.0 - smoothstep(0.0, 1.0, (t - 0.85) / 0.15)); on_quay = true
		if carrying or on_quay:
			crane.carried.show()
			crane.carried.transform = Transform3D(basis, (hook if carrying else quay) - Vector3(0, lift, 0))
		else:
			crane.carried.hide()
		crane.spreader_size = Vector3(visuals.layout.container_size_m.x + 0.3, 0.6, visuals.layout.container_size_m.z + 0.4)
	else:
		crane.carried.hide()
	crane.trolley.position = Vector3(hook.x, BOOM_Y - 1.6, hook.z)
	# Patch 2.9 item 2: the spreader is built at its real size, not a unit box
	# stretched by its node; a stretched box's ink outline grew into the dark
	# bar across each crane (crane_black_bar_*.jpg).
	if crane.spreader_built != crane.spreader_size:
		crane.spreader_built = crane.spreader_size
		crane.spreader.mesh = unit_box(ORANGE, crane.spreader_size)
	crane.spreader.transform = Transform3D(basis, hook)
	var top: float = BOOM_Y - 2.6
	crane.rope.position = Vector3(hook.x, (top + hook.y) / 2.0, hook.z)
	crane.rope.scale = Vector3(1, maxf(0.1, top - hook.y), 1)

## Hoist up, trolley across, lower down: how a quay crane moves a box.
static func travel(from: Vector3, to: Vector3, u: float) -> Vector3:
	u = clampf(u, 0.0, 1.0)
	if u < 0.3: return Vector3(from.x, lerpf(from.y, HOOK_TOP_Y, smoothstep(0.0, 1.0, u / 0.3)), from.z)
	if u < 0.7:
		var across: float = smoothstep(0.0, 1.0, (u - 0.3) / 0.4)
		return Vector3(lerpf(from.x, to.x, across), HOOK_TOP_Y, lerpf(from.z, to.z, across))
	return Vector3(to.x, lerpf(HOOK_TOP_Y, to.y, smoothstep(0.0, 1.0, (u - 0.7) / 0.3)), to.z)

func make_crane(port: Node3D, z: float) -> Dictionary:
	var side: float = float(port.quay_side)
	var node: Node3D = Node3D.new()
	node.name = "QuayCrane"
	add_child(node)
	node.add_child(instance(frame_mesh(side)))
	var boom: Node3D = Node3D.new()
	boom.position = Vector3(side * SEA_LEG_Q, BOOM_Y, 0)
	node.add_child(boom)
	boom.add_child(instance(boom_mesh(side)))
	var trolley: MeshInstance3D = instance(trolley_mesh())
	node.add_child(trolley)
	var rope: MeshInstance3D = instance(unit_box(INK, Vector3(0.3, 1, 0.3)))
	node.add_child(rope)
	var spreader: MeshInstance3D = instance(unit_box(ORANGE, Vector3(2.8, 0.6, 6.5)))
	node.add_child(spreader)
	var carried: MeshInstance3D = MeshInstance3D.new()
	carried.visibility_range_end = SEEN_M
	carried.hide()
	node.add_child(carried)
	var crane: Dictionary = {"node": node, "boom": boom, "trolley": trolley, "rope": rope, "spreader": spreader,
		"carried": carried, "z": z, "park_z": z, "raised": 1.0, "move": {}, "work": -1, "band": [], "want": z, "index": 0, "spreader_size": Vector3(2.8, 0.6, 6.5), "spreader_built": Vector3(2.8, 0.6, 6.5)}
	draw(port, crane)
	return crane

func instance(mesh: Mesh) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.visibility_range_end = SEEN_M
	return node

func material(colour: Color) -> Material:
	if not materials.has(colour):
		var base: StandardMaterial3D = StandardMaterial3D.new()
		base.albedo_color = colour
		base.roughness = 0.85
		materials[colour] = TOON_LOOK.toon_from(base, true)
	return materials[colour]

## One mesh, one surface per colour, from a list of [colour, size, centre].
func build(key: String, parts: Array) -> ArrayMesh:
	if meshes.has(key): return meshes[key]
	var mesh: ArrayMesh = ArrayMesh.new()
	var by_colour: Dictionary = {}
	for part: Array in parts:
		if not by_colour.has(part[0]): by_colour[part[0]] = []
		by_colour[part[0]].append(part)
	for colour: Color in by_colour:
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Array in by_colour[colour]:
			var box: BoxMesh = BoxMesh.new()
			box.size = part[1]
			surface.append_from(box, 0, Transform3D(Basis.IDENTITY, part[2]))
		surface.set_material(material(colour))
		surface.commit(mesh)
	meshes[key] = mesh
	return mesh

func unit_box(colour: Color, size: Vector3) -> ArrayMesh:
	return build("box_%s_%s" % [colour.to_html(), size], [[colour, size, Vector3.ZERO]])

## Legs, portal, bogies, back boom and machinery house; x is mirrored by quay side.
func frame_mesh(side: float) -> ArrayMesh:
	var parts: Array = []
	var height: float = BOOM_Y - QUAY_TOP_Y
	for q: float in [SEA_LEG_Q, LAND_LEG_Q]:
		for z: float in [-5.0, 5.0]:
			parts.append([ORANGE, Vector3(1.6, height, 1.6), Vector3(side * q, QUAY_TOP_Y + height / 2.0, z)])
		parts.append([INK, Vector3(2.4, 1.6, 11.6), Vector3(side * q, QUAY_TOP_Y + 0.8, 0)])
		parts.append([ORANGE, Vector3(1.4, 1.6, 11.6), Vector3(side * q, 22.0, 0)])
		parts.append([ORANGE, Vector3(1.6, 2.0, 11.6), Vector3(side * q, BOOM_Y - 3.0, 0)])
	for z: float in [-5.0, 5.0]:
		parts.append([ORANGE, Vector3(LAND_LEG_Q - SEA_LEG_Q, 1.4, 1.4), Vector3(side * (SEA_LEG_Q + LAND_LEG_Q) / 2.0, 22.0, z)])
	# Back boom (fixed) from the sea legs to the counterweight end.
	parts.append([ORANGE, Vector3(BACK_Q - SEA_LEG_Q, 2.4, 2.4), Vector3(side * (SEA_LEG_Q + BACK_Q) / 2.0, BOOM_Y, 0)])
	parts.append([WHITE, Vector3(10.0, 4.5, 7.0), Vector3(side * (BACK_Q - 6.0), BOOM_Y + 3.4, 0)])
	# Counterweight and boom head are white, not ink: as black blocks they read
	# as a dark bar at each end of the crane (Patch 2.9 item 2).
	parts.append([WHITE, Vector3(3.0, 3.0, 4.0), Vector3(side * (BACK_Q - 1.0), BOOM_Y - 2.6, 0)])
	# A-frame head tower over the sea legs, where the boom stays hang from.
	parts.append([ORANGE, Vector3(1.4, 14.0, 1.4), Vector3(side * (SEA_LEG_Q + 1.0), BOOM_Y + 7.0, 0)])
	parts.append([ORANGE, Vector3(1.4, 14.0, 1.4), Vector3(side * (LAND_LEG_Q - 1.0), BOOM_Y + 7.0, 0)])
	parts.append([ORANGE, Vector3(LAND_LEG_Q - SEA_LEG_Q, 1.4, 1.6), Vector3(side * (SEA_LEG_Q + LAND_LEG_Q) / 2.0, BOOM_Y + 13.5, 0)])
	return build("frame_%d" % side, parts)

## The boom out over the water, built from its hinge at the sea legs.
func boom_mesh(side: float) -> ArrayMesh:
	var length: float = SEA_LEG_Q - BOOM_TIP_Q
	return build("boom_%d" % side, [
		[ORANGE, Vector3(length, 2.4, 2.4), Vector3(-side * length / 2.0, 0, 0)],
		[WHITE, Vector3(2.0, 3.0, 3.0), Vector3(-side * (length - 1.0), 0.3, 0)],
		[WHITE, Vector3(length * 0.6, 0.4, 0.4), Vector3(-side * length * 0.3, 1.8, 0)]])

func trolley_mesh() -> ArrayMesh:
	return build("trolley", [[INK, Vector3(4.0, 1.4, 3.6), Vector3.ZERO],
		[WHITE, Vector3(2.4, 2.2, 2.4), Vector3(0, -1.8, 1.8)],
		[GLASS, Vector3(2.5, 0.9, 2.5), Vector3(0, -1.6, 1.8)]])

## The ship's container mesh (shared per box size) for the box on the hook.
func work_mesh(visuals: Node3D) -> Mesh:
	var key: String = "box_%s" % visuals.layout.container_size_m
	if not meshes.has(key): meshes[key] = VISUALS.container_mesh(visuals.layout.container_size_m)
	return meshes[key]
