extends RefCounted
## Patch 4.0 item 10: flight physics for one plane. Pure and deterministic: the
## server steps it as the authority, the client steps the same code to predict
## its own plane, and the checks fly it with scripted inputs.
##
## Forces: thrust along the nose; lift from the wing, 0.5 rho V^2 S CL, with CL
## growing with the angle of attack up to the stall and falling away past it;
## parasite + induced drag (plus gear, flaps and the stall); a side force that
## keeps the plane flying where it points; gravity. Air thins with altitude.
## Rotation is rate-commanded (pitch, roll, yaw) with authority that grows
## with airspeed, a gentle auto-trim that holds level flight hands-off (it
## cannot hold a plane up below the stall: the nose then drops), a wing
## leveller when roll is released, and weathervane yaw into the wind.
## On the ground the gear rolls on a runway: nose-wheel steering, brakes,
## rolling friction, and the nose can rotate at the plane's rotate speed.
## Touching anything but a runway, or a runway too hard, too steep, with too
## much bank or with the gear up, is a crash.
##
## Frame: world metres, +Y up (altitude above the sea), +Z forward (as the
## ships), +X to the plane's left. The world wraps east-west like the sea; at
## the north and south edges (the poles of the globe) a plane flies over the
## pole: it comes out on the far side of it, half a world east, heading the
## other way (cross_pole), as on a real sphere.
const Progression = preload("res://features/game/progression.gd")
const Terrain = preload("res://features/planes/terrain.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const GRAVITY: float = 9.81
const SEA_RHO: float = 1.225
const SCALE_HEIGHT_M: float = 8500.0
const MAX_ALTITUDE_M: float = 12000.0
const ENGINE_RATE: float = 0.6
## Touch-down limits on a runway.
const MAX_SINK_MPS: float = 5.0
const MAX_BANK_RAD: float = deg_to_rad(15.0)
const MAX_NOSE_DOWN_RAD: float = deg_to_rad(-6.0)
const MAX_NOSE_UP_RAD: float = deg_to_rad(18.0)
## Rolling off a runway onto grass faster than this is a crash.
const OFF_RUNWAY_MPS: float = 12.0
const GEAR_DOWN_AGL_M: float = 120.0

var kind: String = ""
var p: Dictionary = {}
var position: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY
var velocity: Vector3 = Vector3.ZERO
## Actual engine output 0..1 (it follows the lever at ENGINE_RATE per second).
var engine: float = 0.0
var fuel_l: float = 0.0
var on_ground: bool = true
var gear_down: bool = true
var flaps: bool = true
var stalled: bool = false
var crashed: bool = false
var crash_reason: String = ""
var angle_of_attack: float = 0.0
## Height above whatever is below (ground, runway, ice or sea), metres.
var agl_m: float = 0.0
var crossed_pole: bool = false
var gear_height_m: float = 1.5

static func make(plane_kind: String, pose: Transform3D, fuel: float = -1.0) -> RefCounted:
	var model: RefCounted = new()
	model.setup(plane_kind)
	model.place(pose)
	model.fuel_l = model.p.fuel_l if fuel < 0.0 else clampf(fuel, 0.0, model.p.fuel_l)
	return model

func setup(plane_kind: String) -> void:
	kind = plane_kind
	p = Planes.PLANES[plane_kind]
	gear_height_m = clampf(float(p.length_m) * 0.12, 1.2, 4.5)

## Parks the plane on the ground at a pose (wheels down, engine idle, stopped).
func place(pose: Transform3D) -> void:
	basis = Basis(Vector3.UP, pose.basis.get_euler().y)
	position = pose.origin
	position.y = Terrain.height_at(position) + gear_height_m
	velocity = Vector3.ZERO
	engine = 0.0
	on_ground = true
	gear_down = true
	flaps = true
	stalled = false
	crashed = false
	crash_reason = ""
	agl_m = 0.0

func copy_from(other: RefCounted) -> void:
	if other.kind != kind: setup(other.kind)
	position = other.position
	basis = other.basis
	velocity = other.velocity
	engine = other.engine
	fuel_l = other.fuel_l
	on_ground = other.on_ground
	gear_down = other.gear_down
	flaps = other.flaps
	stalled = other.stalled
	crashed = other.crashed
	crash_reason = other.crash_reason

func transform() -> Transform3D:
	return Transform3D(basis, position)

func airspeed() -> float:
	return velocity.length()

func heading() -> float:
	return atan2(basis.z.x, basis.z.z)

func pitch_angle() -> float:
	return asin(clampf(basis.z.y, -1.0, 1.0))

## Right bank is positive (the left wing, +X, goes up).
func bank_angle() -> float:
	return asin(clampf(basis.x.y, -1.0, 1.0))

static func air_density(altitude: float) -> float:
	return SEA_RHO * exp(-maxf(altitude, 0.0) / SCALE_HEIGHT_M)

## Lift coefficient at an angle of attack (radians). Past the stall the wing
## loses lift; `stalled` reports it.
func lift_coefficient(alpha: float) -> float:
	var stall: float = deg_to_rad(float(p.stall_deg))
	var cl: float = float(p.cl0) + float(p.cl_alpha) * alpha
	if absf(alpha) > stall:
		var peak: float = float(p.cl0) + float(p.cl_alpha) * stall * signf(alpha)
		cl = peak * maxf(0.35, 1.0 - (absf(alpha) - stall) / 0.35)
	return cl + (0.35 if flaps else 0.0)

## One fixed step. `input`: throttle 0..1 (the lever), pitch (+1 nose up),
## roll (+1 right), yaw (+1 right) in -1..1, brake 0..1.
func step(input: Dictionary, dt: float) -> void:
	crossed_pole = false
	if crashed or dt <= 0.0: return
	var lever: float = clampf(float(input.get("throttle", 0.0)), 0.0, 1.0) if fuel_l > 0.0 else 0.0
	var pitch_in: float = clampf(float(input.get("pitch", 0.0)), -1.0, 1.0)
	var roll_in: float = clampf(float(input.get("roll", 0.0)), -1.0, 1.0)
	var yaw_in: float = clampf(float(input.get("yaw", 0.0)), -1.0, 1.0)
	var brake: float = clampf(float(input.get("brake", 0.0)), 0.0, 1.0)
	engine = move_toward(engine, lever, ENGINE_RATE * dt)
	fuel_l = maxf(0.0, fuel_l - float(p.burn_lps) * (0.08 + 0.92 * engine) * dt)
	if fuel_l <= 0.0: engine = move_toward(engine, 0.0, ENGINE_RATE * dt * 2.0)
	var mass: float = float(p.mass_kg)
	var area: float = float(p.wing_m2)
	var forward: Vector3 = basis.z
	var up: Vector3 = basis.y
	var right: Vector3 = -basis.x
	var speed: float = velocity.length()
	var rho: float = air_density(position.y)
	var q: float = 0.5 * rho * speed * speed
	var along: float = velocity.dot(forward)
	angle_of_attack = atan2(-velocity.dot(up), maxf(along, 0.5)) if speed > 1.0 else 0.0
	var beta: float = atan2(velocity.dot(right), maxf(absf(along), 0.5)) if speed > 1.0 else 0.0
	var cl: float = lift_coefficient(angle_of_attack)
	stalled = not on_ground and absf(angle_of_attack) > deg_to_rad(float(p.stall_deg))
	var force: Vector3 = Vector3(0, -GRAVITY * mass, 0)
	force += forward * engine * float(p.thrust_n) * pow(rho / SEA_RHO, 0.7)
	if speed > 0.5:
		var flow: Vector3 = velocity / speed
		var lift_dir: Vector3 = right.cross(flow)
		if lift_dir.length_squared() > 0.000001: force += lift_dir.normalized() * q * area * cl
		var cd: float = float(p.cd0) + float(p.induced_k) * cl * cl + (0.02 if gear_down else 0.0) + (0.025 if flaps else 0.0) + (0.12 if stalled else 0.0)
		force -= flow * q * area * cd
		force -= right * q * area * 0.8 * beta
	# Rotation. Control authority grows with airspeed (dynamic pressure).
	var reference: float = 0.5 * SEA_RHO * pow(float(p.rotate_mps) * 1.25, 2.0)
	var authority: float = clampf(q / reference, 0.0, 1.2)
	var pitch_rate: float = 0.0
	var roll_rate: float = 0.0
	var yaw_rate: float = 0.0
	if on_ground:
		# Nose-wheel steering with either yaw or roll keys; rotate near take-off speed.
		yaw_rate = -(yaw_in + roll_in) * deg_to_rad(30.0) * clampf(speed / 8.0, 0.0, 1.0) * clampf(1.0 - speed / 120.0, 0.3, 1.0)
		if along >= float(p.rotate_mps) * 0.9: pitch_rate = pitch_in * deg_to_rad(float(p.pitch_dps)) * 0.5 * authority
		elif pitch_angle() > 0.0: pitch_rate = -deg_to_rad(4.0)
	else:
		# Auto-trim: the angle of attack that holds the weight (more in a bank),
		# kept below the stall. Hands off, the plane holds its flight path.
		var bank: float = bank_angle()
		var need: float = mass * GRAVITY / maxf(q * area * maxf(cos(bank), 0.5), 1.0)
		var trim: float = clampf((need - float(p.cl0) - (0.35 if flaps else 0.0)) / float(p.cl_alpha), deg_to_rad(-4.0), deg_to_rad(float(p.stall_deg) - 2.0))
		pitch_rate = pitch_in * deg_to_rad(float(p.pitch_dps)) * minf(authority, 1.0)
		pitch_rate += (trim - angle_of_attack) * 2.0 * minf(authority, 1.0) * (1.0 - absf(pitch_in) * 0.7)
		if stalled: pitch_rate -= 0.5 # The stalled wing drops the nose.
		roll_rate = roll_in * deg_to_rad(float(p.roll_dps)) * minf(authority, 1.0)
		if absf(roll_in) < 0.05: roll_rate -= bank * 0.9 * minf(authority, 1.0)
		yaw_rate = -yaw_in * deg_to_rad(float(p.yaw_dps)) * minf(authority, 1.0) - beta * 1.5 * minf(authority, 1.0)
	basis = (basis * Basis(Vector3(1, 0, 0), -pitch_rate * dt) * Basis(Vector3(0, 0, 1), roll_rate * dt) * Basis(Vector3(0, 1, 0), yaw_rate * dt)).orthonormalized()
	velocity += force / mass * dt
	if on_ground:
		forward = basis.z
		var flat_forward: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
		var rolling: float = velocity.dot(flat_forward)
		var friction: float = (0.02 + 0.5 * brake) * GRAVITY * dt
		rolling = move_toward(rolling, 0.0, friction) if absf(rolling) > friction else (0.0 if engine < 0.05 else rolling)
		velocity = flat_forward * rolling + Vector3(0, maxf(velocity.y, 0.0), 0)
	position += velocity * dt
	position.y = minf(position.y, MAX_ALTITUDE_M)
	wrap_world()
	contact()

## East-west round the world like the sea; north-south over the pole.
func wrap_world() -> void:
	var half: float = Progression.WRAP_M / 2.0
	var north: float = position.z - Progression.WRAP_CENTRE.z
	if absf(north) > half:
		cross_pole(signf(north))
	position.x = Progression.WRAP_CENTRE.x + wrapf(position.x - Progression.WRAP_CENTRE.x, -half, half)

## Over the pole: the same distance back from the edge, half a world east,
## turned about the pole so the plane now flies away from it.
func cross_pole(side: float) -> void:
	var edge: float = Progression.WRAP_CENTRE.z + side * Progression.WRAP_M / 2.0
	position.z = 2.0 * edge - position.z
	position.x += Progression.WRAP_M / 2.0
	var turn: Basis = Basis(Vector3.UP, PI)
	# Reflect north-south and turn east-west: a half turn about the pole.
	basis = (turn * basis).orthonormalized()
	velocity = turn * velocity
	crossed_pole = true

## Wheels and everything else against what is below.
func contact() -> void:
	var below: Dictionary = Terrain.sample(position)
	var ground: float = float(below.height)
	agl_m = position.y - gear_height_m - ground
	gear_down = agl_m < GEAR_DOWN_AGL_M or on_ground
	flaps = gear_down and velocity.length() < float(p.rotate_mps) * 1.6
	if agl_m > 0.05:
		on_ground = false
		return
	var sink: float = -velocity.y
	var speed: float = velocity.length()
	if below.surface != "runway":
		if speed > OFF_RUNWAY_MPS or not on_ground or below.surface == "sea":
			crash("Crashed into the %s." % ("sea" if below.surface == "sea" else ("ice" if below.surface == "ice" else "ground")))
			return
	if not on_ground:
		var fault: String = ""
		if not gear_down: fault = "Landed with the gear up."
		elif sink > MAX_SINK_MPS: fault = "Hit the runway too hard."
		elif absf(bank_angle()) > MAX_BANK_RAD: fault = "A wing hit the runway."
		elif pitch_angle() < MAX_NOSE_DOWN_RAD: fault = "Nose-first into the runway."
		elif pitch_angle() > MAX_NOSE_UP_RAD: fault = "Tail strike."
		if not fault.is_empty():
			crash(fault)
			return
	on_ground = true
	agl_m = 0.0
	position.y = ground + gear_height_m
	if velocity.y < 0.0: velocity.y = 0.0
	# Wheels down: wings level, nose no lower than level.
	var yaw: float = heading()
	var pitch: float = clampf(pitch_angle(), 0.0, MAX_NOSE_UP_RAD)
	basis = Basis(Vector3.UP, yaw) * Basis(Vector3(1, 0, 0), -pitch)

func crash(reason: String) -> void:
	crashed = true
	crash_reason = reason
	velocity = Vector3.ZERO
	engine = 0.0
