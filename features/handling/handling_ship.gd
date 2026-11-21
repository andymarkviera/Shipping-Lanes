class_name HandlingShip
extends CharacterBody3D
## Local, planar handling fixture. +Z is the bow; all values use SI units.
@export var definition: ShipDefinition = preload("res://features/catalog/records/starter_ship.tres")
signal validated_impact(damage_bp: int)
@export var harmless_impact_mps: float = 2.0
@export var impact_damage_bp_per_mps_squared: float = 100.0
var impact_cooldowns: Dictionary = {}
var commanded_throttle: float = 0.0
var actual_throttle: float = 0.0
var distance_m: float = 0.0
## Patch 2.9 item 4: how fast the hull really moved over the last physics tick
## (m/s). Unlike velocity it reads 0 when the hull is pinned against land.
var ground_speed_mps: float = 0.0
var rudder: float = 0.0
var lateral_order: float = 0.0
var yaw_rate: float = 0.0
var state: ShipState
var fuel: PropulsionFuel
var simulation_paused: bool = false
## Shown by the helm notice while paused: why, and how to get out. Cleared on resume.
var pause_reason: String = ""
var docked: bool = false
var condition_affects_propulsion: bool = false
## Patch 4.0.2: the Jetty's Shift blaster boost (features/ships/jetty_boost.gd).
## Every hull has one; only the Jetty can trigger it. boost_applied is the
## speed multiplier already in velocity (the last tick's factor).
const JETTY_BOOST = preload("res://features/ships/jetty_boost.gd")
var boost: JETTY_BOOST = JETTY_BOOST.new()
var boost_applied: float = 1.0
## Patch 4.0.6 item 1: the game's hulls (and the client's prediction of its
## own) feel the storms (features/sky/storms.gd): the engine pushes less.
const STORMS = preload("res://features/sky/storms.gd")
var weather: bool = false
## 0..1: the storm at the hull as of the last tick (0 off the game's sea).
var storm: float = 0.0

func propulsion_condition_factor() -> float:
	if not condition_affects_propulsion: return 1.0
	return lerpf(0.75, 1.0, clampf(state.condition / 0.5, 0.0, 1.0))

func helm_available() -> bool:
	return not simulation_paused and not docked

## Patch 4.0.2: Shift on the Jetty. Starts the charge; false when this hull has
## no blaster, the helm is not available, the tank is empty or it is cooling down.
func request_boost() -> bool:
	if not JETTY_BOOST.eligible(definition) or not helm_available(): return false
	if state == null or state.fuel_liters <= 0: return false
	return boost.trigger()

func refuel(amount_liters: float) -> float:
	if velocity.length() > 0.05 or absf(commanded_throttle) > 0.001 or absf(actual_throttle) > 0.001 or absf(lateral_order) > 0.001:
		return 0.0
	return fuel.add_liters(amount_liters)

func maneuver(steering: float, thruster: float) -> void:
	rudder = clampf(steering, -1.0, 1.0) if is_finite(steering) else 0.0
	lateral_order = clampf(thruster, -1.0, 1.0) if is_finite(thruster) else 0.0
	if state != null and state.fuel_liters <= 0: lateral_order = 0

func forward_speed() -> float:
	return velocity.dot(basis.z)

func lateral_speed() -> float:
	return velocity.dot(basis.x)

func _ready() -> void:
	definition = definition.duplicate(true)
	state = ShipState.new(str(get_instance_id()), definition.id, definition.fuel_capacity_liters)
	state.manifest = preload("res://features/cargo/cargo_manifest.gd").new(definition, PrototypeCatalog.RECORDS)
	state.operations = preload("res://features/cargo/cargo_operation.gd").new()
	state.operations.register_rule("manifest", preload("res://features/cargo/manifest_operation_rule.gd").new(state.instance_id, state.manifest))
	fuel = PropulsionFuel.new(state, definition)
	if not definition.handling_error().is_empty():
		push_error(definition.handling_error())
		set_physics_process(false)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = CollisionRules.HULL
	collision_mask = CollisionRules.SOLID_WATERCRAFT
	safe_margin = 0.02
	max_slides = 6
	platform_floor_layers = 0
	platform_wall_layers = 0

func command_throttle(value: float) -> void:
	if state != null and state.fuel_liters <= 0:
		commanded_throttle = 0
		return
	if is_finite(value):
		commanded_throttle = clampf(value, -definition.reverse_throttle_limit, definition.forward_throttle_limit)

func adjust_command(axis: float, delta: float) -> void:
	command_throttle(adjusted_order(commanded_throttle, axis, delta, definition))

static func adjusted_order(current: float, axis: float, delta: float, tuning: ShipDefinition) -> float:
	if not is_finite(axis) or not is_finite(delta) or delta <= 0: return current
	var next: float = clampf(current + clampf(axis, -1.0, 1.0) * tuning.command_rate_per_second * delta, -tuning.reverse_throttle_limit, tuning.forward_throttle_limit)
	# Capture approaching/crossing zero, but allow a held key to leave neutral.
	if current * axis < 0 and (absf(next) <= tuning.neutral_snap_zone or current * next < 0): return 0.0
	if is_zero_approx(axis) and absf(next) <= tuning.neutral_snap_zone: return 0.0
	return next

func stopping_assist_active() -> bool:
	return commanded_throttle == 0 and actual_throttle == 0 and lateral_order == 0 and velocity.length() <= definition.neutral_stop_speed_mps


func zero_throttle() -> void:
	command_throttle(0.0)

func advance_engine(delta: float) -> void:
	# Opposite orders first ramp to neutral; opposite thrust starts next tick.
	var target: float = commanded_throttle
	if actual_throttle * target < 0.0:
		target = 0.0
	var rate: float = definition.engine_ramp_up_per_second if absf(target) > absf(actual_throttle) else definition.engine_ramp_down_per_second
	actual_throttle = move_toward(actual_throttle, target, rate * delta)

func advance_motion(delta: float) -> void:
	if simulation_paused or not is_finite(delta) or delta <= 0: return
	if docked or state.fuel_liters <= 0:
		zero_throttle()
		actual_throttle = 0
		lateral_order = 0
	if docked:
		velocity = Vector3.ZERO
		yaw_rate = 0
		rudder = 0
	advance_engine(delta)
	if docked or state.fuel_liters <= 0: boost.cancel()
	boost.advance(delta)
	var local_velocity: Vector3 = basis.inverse() * velocity
	# Patch 4.0.2: the hull's own speed, without the boost already in velocity.
	local_velocity.z /= boost_applied
	var requested_side: float = lateral_order * clampf(1.0 - absf(local_velocity.z) / definition.thruster_cutoff_speed_mps, 0.0, 1.0)
	var fuel_fraction: float = fuel.consume(delta, actual_throttle, requested_side, false, docked)
	var effectiveness: float = clampf(absf(local_velocity.z) / definition.rudder_full_effect_speed_mps, 0.0, 1.0)
	# D is starboard: negative yaw with +Z bow/+X port. Astern reverses yaw.
	var target_yaw: float = -rudder * signf(local_velocity.z) * effectiveness * deg_to_rad(definition.max_turn_rate_degrees)
	yaw_rate = move_toward(yaw_rate, target_yaw, deg_to_rad(definition.turn_acceleration_degrees) * delta)
	turn_without_overlap(yaw_rate * delta)
	storm = STORMS.intensity_at(global_position if is_inside_tree() else position) if weather else 0.0
	var acceleration: float = actual_throttle * fuel_fraction * propulsion_condition_factor() * STORMS.speed_factor(storm) * (definition.forward_acceleration_mps2 if actual_throttle >= 0.0 else definition.reverse_acceleration_mps2)
	var drag: float = definition.linear_drag_per_second
	local_velocity.z = local_velocity.z * exp(-drag * delta) + acceleration / drag * (1.0 - exp(-drag * delta))
	var lateral_drag: float = definition.lateral_drag_per_second
	var thruster_effect: float = clampf(1.0 - absf(local_velocity.z) / definition.thruster_cutoff_speed_mps, 0.0, 1.0)
	var side_acceleration: float = -lateral_order * definition.thruster_acceleration_mps2 * thruster_effect * fuel_fraction
	local_velocity.x = local_velocity.x * exp(-lateral_drag * delta) + side_acceleration / lateral_drag * (1.0 - exp(-lateral_drag * delta))
	local_velocity.y = 0.0
	# Patch 4.0.2: the blaster boost scales the speed ahead while it holds.
	boost_applied = boost.factor()
	local_velocity.z *= boost_applied
	velocity = (basis * local_velocity).limit_length(CollisionRules.SUPPORTED_SPEED_MPS)
	if stopping_assist_active():
		velocity = velocity.move_toward(Vector3.ZERO, definition.neutral_stop_deceleration_mps2 * delta)
		if velocity == Vector3.ZERO: yaw_rate = 0
	if state.fuel_liters <= 0:
		zero_throttle()
		actual_throttle = 0
		lateral_order = 0

func _physics_process(delta: float) -> void:
	if simulation_paused: return
	advance_motion(delta)
	var previous: Vector3 = position
	var incoming_velocity: Vector3 = velocity
	var speed_before: float = velocity.length()
	move_and_slide()
	var damage: int = 0
	var now: int = Time.get_ticks_msec()
	for key: int in impact_cooldowns.keys():
		if now >= impact_cooldowns[key]: impact_cooldowns.erase(key)
	for index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(index)
		var closing: float = maxf(0, -(incoming_velocity - collision.get_collider_velocity()).dot(collision.get_normal()))
		var collider: int = collision.get_collider_id()
		if not docked and closing > harmless_impact_mps and not impact_cooldowns.has(collider):
			damage = maxi(damage, clampi(ceili(pow(closing - harmless_impact_mps, 2) * impact_damage_bp_per_mps_squared), 1, 10000))
			impact_cooldowns[collider] = now + 1000
		var normal: Vector3 = get_slide_collision(index).get_normal()
		if velocity.dot(normal) < 0.0: velocity = velocity.slide(normal)
	velocity = velocity.limit_length(speed_before)
	distance_m += position.distance_to(previous)
	ground_speed_mps = Vector2(position.x - previous.x, position.z - previous.z).length() / delta if delta > 0.0 else 0.0
	if damage > 0: validated_impact.emit(damage)

func turn_without_overlap(angle: float) -> void:
	if is_zero_approx(angle): return
	var candidate: Transform3D = global_transform
	# Repeated float rotations otherwise accumulate scale drift. The save/berth
	# validators correctly require a rigid pose; keep the physical hull rigid too.
	candidate.basis = candidate.basis.rotated(Vector3.UP, angle).orthonormalized()
	for child: Node in get_children():
		if not child is CollisionShape3D or child.disabled or child.shape == null: continue
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = child.shape
		query.transform = candidate * child.transform
		query.collision_mask = collision_mask
		query.exclude = [get_rid()]
		var radius: float = child.position.length()
		if child.shape is BoxShape3D:
			radius += child.shape.size.length() * 0.5
		else:
			radius += child.shape.get_debug_mesh().get_aabb().size.length() * 0.5
		# Enclose the angular arc as well as the proposed final hull orientation.
		query.margin = safe_margin + radius * absf(angle)
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			yaw_rate = 0.0
			return
	global_transform = candidate

func interrupt_cargo_operation() -> void:
	# Explicit disconnect/teardown hook; temporary physics-world reparenting is not a disconnect.
	if state != null and state.operations != null:
		state.operations.interrupt_ship(state.instance_id)
