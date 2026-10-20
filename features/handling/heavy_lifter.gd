extends HandlingShip
const DEFINITION = preload("res://features/catalog/records/heavy_lifter.tres")
const DECK = preload("res://features/ships/heavy_lifter_01/lift_deck.glb")
const PAYLOAD = preload("res://features/ships/heavy_lifter_01/industrial_payload.glb")
const RAISED: float = 2.6
const LOWERED: float = -1.0
var deck_height: float = RAISED
var deck_target: float = RAISED
var deck_visual: Node3D
var deck_shape: CollisionShape3D
var cargo_mount: Node3D
var payload_body: StaticBody3D
var payload_visual: Node3D
var payload_shape: CollisionShape3D
var attached: bool = false
var assembly: ShipAssembly
var notice: String = "Stop, lower the deck, then align the test payload."

func shape(size: Vector3, at: Vector3) -> CollisionShape3D:
	return ShipAssembly.box_collision(self, size, at)

func _init() -> void:
	definition = DEFINITION

func helm_available() -> bool:
	return super.helm_available() and not operating() and (not attached or absf(deck_height - RAISED) <= 0.001)

func _ready() -> void:
	super._ready()
	assembly = ShipAssembly.new()
	add_child(assembly)
	assembly.configure(self)
	deck_visual = DECK.instantiate()
	add_child(deck_visual)
	shape(Vector3(24, 2.5, 90), Vector3(0, -3.25, 0))
	for side: float in [-1, 1]: shape(Vector3(3, 5, 74), Vector3(side * 10.5, 0.5, -5))
	shape(Vector3(20, 13, 17), Vector3(0, 4.5, 32))
	deck_shape = shape(Vector3(18, 0.6, 48), Vector3(0, 2.3, -8))
	payload_shape = shape(Vector3(14, 8, 32), Vector3(0, RAISED + 4, -8))
	payload_shape.disabled = true
	cargo_mount = assembly.cargo_anchor
	payload_body = StaticBody3D.new()
	# Position in the same parent frame, even inside a translated/rotated scene.
	payload_body.transform = transform * Transform3D(Basis.IDENTITY, Vector3(35, LOWERED, -8))
	payload_body.collision_layer = CollisionRules.HULL
	payload_body.collision_mask = 0
	payload_visual = PAYLOAD.instantiate()
	payload_body.add_child(payload_visual)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = payload_shape.shape.duplicate()
	collider.position.y = 4
	payload_body.add_child(collider)
	get_parent().add_child.call_deferred(payload_body)

func _exit_tree() -> void:
	if is_instance_valid(payload_body): payload_body.queue_free()

func stopped() -> bool:
	return velocity.length() < 0.05 and absf(actual_throttle) < 0.01 and absf(commanded_throttle) < 0.01

func operating() -> bool:
	return absf(deck_target - deck_height) > 0.001

func request_height(target: float) -> bool:
	if not stopped() or operating():
		notice = "Come to a complete stop with the engine neutral first."
		return false
	if target not in [RAISED, LOWERED]: return false
	deck_target = target
	notice = "Raising deck…" if target == RAISED else "Lowering deck…"
	return true

func space_clear(at: Transform3D, query_shape: Shape3D) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	query.transform = at
	query.collision_mask = CollisionRules.SOLID_WATERCRAFT
	query.exclude = [get_rid(), payload_body.get_rid()]
	query.margin = 0.02
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func align_test_payload() -> bool:
	if attached or operating() or not stopped() or absf(deck_height - LOWERED) > 0.001:
		notice = "Lower the empty deck while stopped before staging the test load."
		return false
	var pose: Transform3D = global_transform
	pose.origin = to_global(Vector3(0, LOWERED, -8))
	var center: Transform3D = pose.translated_local(Vector3(0, 4, 0))
	if not space_clear(center, payload_shape.shape):
		notice = "The loading space is blocked."
		return false
	# Fixture-only convenience: move the staged load, not the player's ship.
	payload_body.global_transform = pose
	notice = "Test payload aligned. Secure it before raising."
	return true

func attach_payload() -> bool:
	if attached or operating() or not stopped() or absf(deck_height - LOWERED) > 0.001:
		notice = "Stop with the deck fully lowered to secure cargo."
		return false
	var relative: Transform3D = global_transform.affine_inverse() * payload_body.global_transform
	if relative.origin.distance_to(Vector3(0, LOWERED, -8)) > 0.5 or relative.basis.z.dot(Vector3.FORWARD * -1) < cos(deg_to_rad(3)):
		notice = "Payload is not aligned over the deck."
		return false
	if not space_clear(cargo_mount.global_transform.translated_local(Vector3(0, 4, 0)), payload_shape.shape):
		notice = "Cannot secure cargo inside an obstacle."
		return false
	payload_body.collision_layer = 0
	payload_visual.reparent(cargo_mount, false)
	payload_visual.transform = Transform3D.IDENTITY
	payload_shape.disabled = false
	attached = true
	notice = "Payload secured. Raise the deck, then sail."
	return true

func detach_payload() -> bool:
	if not attached or operating() or not stopped() or absf(deck_height - LOWERED) > 0.001:
		notice = "Lower the deck and stop before releasing cargo."
		return false
	payload_body.global_transform = cargo_mount.global_transform
	payload_visual.reparent(payload_body, false)
	payload_visual.transform = Transform3D.IDENTITY
	payload_shape.disabled = true
	payload_body.collision_layer = CollisionRules.HULL
	attached = false
	notice = "Payload floating freely. Move clear before raising an empty deck."
	return true

func advance_deck(delta: float) -> void:
	if not operating(): return
	var next: float = move_toward(deck_height, deck_target, delta * 1.2)
	var deck_pose: Transform3D = global_transform.translated_local(Vector3(0, (next + deck_height) * 0.5 - 0.3, -8))
	var swept: BoxShape3D = BoxShape3D.new()
	swept.size = Vector3(18, 0.6 + absf(next - deck_height), 48)
	var clear: bool = space_clear(deck_pose, swept)
	if attached:
		var cargo_swept: BoxShape3D = BoxShape3D.new()
		cargo_swept.size = Vector3(14, 8 + absf(next - deck_height), 32)
		clear = clear and space_clear(global_transform.translated_local(Vector3(0, (next + deck_height) * 0.5 + 4, -8)), cargo_swept)
	elif deck_target > deck_height:
		# An unsecured floating load must never be raised through.
		var local_load: Vector3 = to_local(payload_body.global_position)
		if absf(local_load.x) < 16 and absf(local_load.z + 8) < 40:
			clear = false
	if not clear:
		deck_target = deck_height
		notice = "Deck stopped: clearance blocked. Move clear or secure the load."
		return
	deck_height = next
	deck_visual.position.y = deck_height - RAISED
	deck_shape.position.y = deck_height - 0.3
	cargo_mount.position.y = deck_height
	payload_shape.position.y = deck_height + 4
	if not operating(): notice = "Deck raised — ready to sail." if deck_height == RAISED else "Deck lowered — ready for loading."

func _physics_process(delta: float) -> void:
	if simulation_paused: return
	if not helm_available():
		zero_throttle()
		maneuver(0, 0)
	advance_deck(delta)
	super._physics_process(delta)
