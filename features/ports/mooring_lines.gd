extends Node3D
## Patch 2.4 item 4: toon mooring lines, the game only. When a ship finishes
## docking, its lines fly out from the fairleads on its rail
## (chunky_look._mooring_bitts) and make fast to the quay bollards
## (test_port.bollard_points()): a bow line and a stern line, plus a fore and
## an aft spring on ships SPRING_LENGTH_M or longer. On Undock they let go and
## reel back aboard; the game sets the docking authority's undock_seconds to
## LET_GO_SECONDS, so the ship is held in the berth until they are in. Looks
## only: this reads the authority's state and never changes it.
## Patch 2.9 item 3: each line now leans out over the rail clear of the hull,
## sags in the gap, rests over the quay edge (never through it) and loops
## round the bollard post under its head. See lie().
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const TIE_SECONDS: float = 1.2
const LET_GO_SECONDS: float = 1.0
const SPRING_LENGTH_M: float = 120.0
const SIDES: int = 6
const ROPE: Color = Color("e9d29a")
## Patch 2.9 item 3: quay and bollard shapes the lines must clear (port-local,
## from test_port.gd and chunky_look.dress_port()). The timber face's outer
## side is QUAY_FACE_M from the berth centreline; the edge strip's top is
## EDGE_TOP_M; the bollard post has POST_RADIUS_M and its head starts
## HEAD_DROP_M below bollard_points().y, so the loop sits LOOP_DROP_M below it.
const EDGE_TOP_M: float = 4.2
const POST_RADIUS_M: float = 0.9
const LOOP_DROP_M: float = 0.3
const CLEAR_M: float = 0.15
const GAP_SEGMENTS: int = 8
const LOOP_SEGMENTS: int = 12
## The docking authority whose ships are moored.
var docking: Node
## Owner -> {"body", "port", "ropes": [{"from": Node3D, "to": Vector3, "pick": Vector3,
## "mesh"}], "out": 0..1, "hull_x": quay-side hull edge from the centreline,
## "radius": rope radius}. "pick" is the bollard point in port space.
## "out" is how far the lines are out: 0 aboard, 1 made fast.
var rigs: Dictionary = {}
var material: Material

func _ready() -> void:
	var base: StandardMaterial3D = StandardMaterial3D.new()
	base.albedo_color = ROPE
	base.roughness = 0.9
	material = TOON_LOOK.toon_from(base, false)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if docking == null: return
	for owner: int in docking.members.keys():
		var entry: Dictionary = docking.members[owner]
		if entry.state not in ["docked", "undocking"] or not is_instance_valid(entry.body) or not is_instance_valid(entry.port):
			drop(owner)
			continue
		if rigs.has(owner) and (not is_instance_valid(rigs[owner].body) or rigs[owner].body != entry.body or rigs[owner].port != entry.port):
			drop(owner)
		if not rigs.has(owner):
			var made: Dictionary = make_rig(entry.body, entry.port)
			if made.is_empty(): continue
			rigs[owner] = made
		var rig: Dictionary = rigs[owner]
		if entry.state == "docked":
			rig.out = minf(1.0, rig.out + delta / TIE_SECONDS)
		else:
			# Letting go: the lines are aboard by the time the authority frees the ship.
			rig.out = minf(rig.out, clampf(entry.remaining / maxf(docking.undock_seconds, 0.001), 0.0, 1.0))
		draw(rig)
	for owner: int in rigs.keys():
		if not docking.members.has(owner): drop(owner)

## How far the owner's lines are out (0 aboard or none, 1 made fast).
func lines_out(owner: int) -> float:
	return float(rigs[owner].out) if rigs.has(owner) else 0.0

## The owner's line meshes (empty when there are none).
func ropes(owner: int) -> Array:
	return rigs[owner].ropes if rigs.has(owner) else []

func drop(owner: int) -> void:
	if not rigs.has(owner): return
	for rope: Dictionary in rigs[owner].ropes:
		if is_instance_valid(rope.mesh): rope.mesh.queue_free()
	rigs.erase(owner)

## Picks the quay-side fairleads and a bollard for each line. Empty when the
## ship has no fairleads (an imported model) or the port has no bollards.
func make_rig(body: Node3D, port: Node3D) -> Dictionary:
	if not port.has_method("bollard_points") or body.get("definition") == null: return {}
	var bollards: Array[Vector3] = port.bollard_points()
	if bollards.is_empty(): return {}
	var to_port: Transform3D = port.global_transform.affine_inverse()
	var quay_x: float = port.quay_side * port.BOLLARD_X_M
	var leads: Dictionary = {}
	for end: String in ["Bow", "Stern"]:
		var best: Node3D = null
		for side: String in ["L", "R"]:
			var lead: Node3D = body.find_child("Mooring%s%s" % [end, side], true, false) as Node3D
			if lead != null and (best == null or absf((to_port * lead.global_position).x - quay_x) < absf((to_port * best.global_position).x - quay_x)):
				best = lead
		if best == null: return {}
		leads[end] = best
	# Which way the bow points along the quay, and how far each line leads.
	var ahead: float = 1.0 if (to_port.basis * body.global_basis.z).z >= 0.0 else -1.0
	var length: float = maxf(body.definition.hull_size_m.z, 100.0)
	var plan: Array = [["Bow", 0.15], ["Stern", -0.15]]
	if body.definition.hull_size_m.z >= SPRING_LENGTH_M: plan.append_array([["Bow", -0.3], ["Stern", 0.3]])
	var made: Array = []
	for line: Array in plan:
		var from: Node3D = leads[line[0]]
		var want: float = (to_port * from.global_position).z + ahead * float(line[1]) * length
		var pick: Vector3 = bollards[0]
		for point: Vector3 in bollards:
			if absf(point.z - want) < absf(pick.z - want): pick = point
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = "MooringLine"
		mesh.mesh = ImmediateMesh.new()
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.hide()
		add_child(mesh)
		made.append({"from": from, "to": port.global_transform * pick, "pick": pick, "mesh": mesh})
	return {"body": body, "port": port, "ropes": made, "out": 0.0,
		"hull_x": float(port.QUAY_FACE_M) - float(port.quay_gap_m(body.definition)),
		"radius": clampf(body.definition.hull_size_m.x * 0.013, 0.2, 0.45)}

## Each line: thrown out along its resting path with a heaving lift (or
## reeled back), then lying in its rest shape once fast.
func draw(rig: Dictionary) -> void:
	var radius: float = float(rig.radius)
	var t: float = smoothstep(0.0, 1.0, float(rig.out))
	var to_port: Transform3D = rig.port.global_transform.affine_inverse()
	var local: Transform3D = global_transform.affine_inverse() * rig.port.global_transform
	for rope: Dictionary in rig.ropes:
		var mesh: MeshInstance3D = rope.mesh
		var shape: ImmediateMesh = mesh.mesh as ImmediateMesh
		shape.clear_surfaces()
		mesh.visible = t > 0.001 and is_instance_valid(rope.from)
		if not mesh.visible: continue
		var rest: PackedVector3Array = lie(to_port * (rope.from as Node3D).global_position, rope.pick, float(rig.port.quay_side), float(rig.port.QUAY_FACE_M), float(rig.hull_x), radius)
		var points: PackedVector3Array = rest if t >= 0.999 else fly(rest, t)
		for index: int in points.size(): points[index] = local * points[index]
		tube(shape, points, radius)

## The port-space rest line of a rope (Patch 2.9 item 3). from: the fairlead;
## pick: the bollard point; side: the quay side; face: the timber face's
## distance from the berth centreline; hull_x: the hull's quay-side edge.
## 1. Out over the rail to just outside the hull, at rail height, so no
##    point below the rail is inside the hull.
## 2. A sag across the gap that only falls toward the quay edge (never below
##    it), to a point clear of the timber face and above the edge strip.
## 3. Straight to the bollard post (both ends above the quay deck).
## 4. A full loop round the post under its head.
static func lie(from: Vector3, pick: Vector3, side: float, face: float, hull_x: float, radius: float) -> PackedVector3Array:
	var edge_x: float = face - radius - CLEAR_M
	var lead: Vector3 = Vector3(side * clampf(maxf(absf(from.x), hull_x + radius + CLEAR_M), 0.0, edge_x - 0.05), from.y, from.z)
	var centre: Vector3 = pick - Vector3.UP * LOOP_DROP_M
	var loop: float = POST_RADIUS_M + radius + 0.05
	var back: Vector3 = Vector3(lead.x - centre.x, 0.0, lead.z - centre.z)
	back = back.normalized() if back.length() > 0.01 else Vector3(side * -1.0, 0.0, 0.0)
	var land: Vector3 = centre + back * loop
	var k: float = clampf((side * edge_x - lead.x) / (land.x - lead.x), 0.0, 1.0) if absf(land.x - lead.x) > 0.01 else 0.0
	var edge: Vector3 = Vector3(side * edge_x, maxf(EDGE_TOP_M + radius, lerpf(lead.y, land.y, k)), lerpf(lead.z, land.z, k))
	var points: PackedVector3Array = PackedVector3Array([from])
	# Sag no deeper than a quarter of the drop keeps the curve falling all the
	# way to the edge point, so it never dips below the quay edge.
	var sag: float = clampf(minf(lead.distance_to(edge) * 0.05, (lead.y - edge.y) / 4.0), 0.0, 2.0)
	for index: int in GAP_SEGMENTS + 1:
		var u: float = float(index) / GAP_SEGMENTS
		points.append(lead.lerp(edge, u) - Vector3.UP * sag * 4.0 * u * (1.0 - u))
	var start: float = atan2(back.z, back.x)
	for index: int in LOOP_SEGMENTS + 1:
		var angle: float = start + TAU * float(index) / LOOP_SEGMENTS
		points.append(centre + Vector3(cos(angle), 0.0, sin(angle)) * loop)
	return points

## The first t of the rest line, lifted in a heaving arc that is highest at
## the flying end and gone once the line is fast. Lifting only raises it, so
## it never clips more than the rest line does.
static func fly(rest: PackedVector3Array, t: float) -> PackedVector3Array:
	var total: float = 0.0
	for index: int in rest.size() - 1: total += rest[index].distance_to(rest[index + 1])
	var reach: float = maxf(total * t, 0.001)
	var lift: float = sin(PI * t) * rest[0].distance_to(rest[rest.size() - 1]) * 0.2
	var points: PackedVector3Array = PackedVector3Array([rest[0]])
	var walked: float = 0.0
	for index: int in rest.size() - 1:
		var step: float = rest[index].distance_to(rest[index + 1])
		var end: float = minf(walked + step, reach)
		var at: Vector3 = rest[index].lerp(rest[index + 1], (end - walked) / maxf(step, 0.0001))
		points.append(at + Vector3.UP * lift * sin(PI * 0.5 * end / reach))
		walked += step
		if walked >= reach: break
	if points.size() < 2: points.append(rest[0] + Vector3.UP * 0.01)
	return points

## A round toon rope along the points (clockwise faces outward).
static func tube(shape: ImmediateMesh, points: PackedVector3Array, radius: float) -> void:
	var count: int = points.size()
	var rings: Array = []
	for index: int in count:
		var along: Vector3 = (points[mini(index + 1, count - 1)] - points[maxi(index - 1, 0)]).normalized()
		var side: Vector3 = along.cross(Vector3.UP)
		if side.length() < 0.01: side = along.cross(Vector3.RIGHT)
		side = side.normalized()
		var up: Vector3 = side.cross(along).normalized()
		var ring: Array[Vector3] = []
		for k: int in SIDES:
			var angle: float = TAU * k / SIDES
			ring.append(side * cos(angle) + up * sin(angle))
		rings.append(ring)
	shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in count - 1:
		for k: int in SIDES:
			var next: int = (k + 1) % SIDES
			for corner: Vector2i in [Vector2i(index, k), Vector2i(index + 1, next), Vector2i(index + 1, k), Vector2i(index, k), Vector2i(index, next), Vector2i(index + 1, next)]:
				var normal: Vector3 = rings[corner.x][corner.y]
				shape.surface_set_normal(normal)
				shape.surface_add_vertex(points[corner.x] + normal * radius)
	shape.surface_end()
