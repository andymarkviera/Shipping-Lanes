extends Node3D
## Patch 2.4 item 4: toon mooring lines, the game only. When a ship finishes
## docking, its lines fly out from the fairleads on its rail
## (chunky_look._mooring_bitts) and make fast to the quay bollards
## (test_port.bollard_points()): a bow line and a stern line, plus a fore and
## an aft spring on ships SPRING_LENGTH_M or longer. On Undock they let go and
## reel back aboard; the game sets the docking authority's undock_seconds to
## LET_GO_SECONDS, so the ship is held in the berth until they are in. Looks
## only: this reads the authority's state and never changes it.
const TOON_LOOK = preload("res://features/toon/toon_look.gd")
const TIE_SECONDS: float = 1.2
const LET_GO_SECONDS: float = 1.0
const SPRING_LENGTH_M: float = 120.0
const SEGMENTS: int = 12
const SIDES: int = 6
const ROPE: Color = Color("e9d29a")
## The docking authority whose ships are moored.
var docking: Node
## Owner -> {"body", "port", "ropes": [{"from": Node3D, "to": Vector3, "mesh"}], "out": 0..1}.
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
		made.append({"from": from, "to": port.global_transform * pick, "mesh": mesh})
	return {"body": body, "port": port, "ropes": made, "out": 0.0}

## Each line: a heaving arc while it flies out (or back), a gentle sag once fast.
func draw(rig: Dictionary) -> void:
	var radius: float = clampf(rig.body.definition.hull_size_m.x * 0.013, 0.2, 0.45)
	var t: float = smoothstep(0.0, 1.0, float(rig.out))
	var local: Transform3D = global_transform.affine_inverse()
	for rope: Dictionary in rig.ropes:
		var mesh: MeshInstance3D = rope.mesh
		var shape: ImmediateMesh = mesh.mesh as ImmediateMesh
		shape.clear_surfaces()
		mesh.visible = t > 0.001 and is_instance_valid(rope.from)
		if not mesh.visible: continue
		var a: Vector3 = local * (rope.from as Node3D).global_position
		var b: Vector3 = local * rope.to
		var span: float = a.distance_to(b)
		var tip: Vector3 = a.lerp(b, t) + Vector3.UP * sin(PI * t) * span * 0.2
		var sag: float = span * lerpf(0.02, 0.07, t)
		var points: PackedVector3Array = PackedVector3Array()
		for index: int in SEGMENTS + 1:
			var u: float = float(index) / SEGMENTS
			points.append(a.lerp(tip, u) - Vector3.UP * sag * 4.0 * u * (1.0 - u))
		tube(shape, points, radius)

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
