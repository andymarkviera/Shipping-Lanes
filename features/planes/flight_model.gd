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
## with airspeed. Arcade assists: a coordinated turn (the nose follows the
## bank, sideslip is cancelled), a stall recovery (the nose-up command fades
## out at the stall angle and a stalled wing drops the nose) and a runway
## alignment on final approach.
## Patch 4.0.1 item 1 (Andy reversed the 4.0 call): the auto-level is back.
## Hands off (no pitch or roll command), the plane gently rolls wings-level
## and settles into level flight, an arcade instructor; the moment the player
## commands pitch or roll it fades right out, so it never fights the aim.
## Item 2: landing is forgiving. Near an airport, as the throttle drops, the
## flaps give more lift and drag; touchdown tolerates a moderate sink rate
## and some bank; the last few metres flare on their own (auto-flare); the
## runway alignment reaches 3 km out and 25 degrees either side; on the wheels
## the spoilers dump lift at idle and the brakes (S at idle) stop it quickly.
## The airfield around a runway (Airports.airfield_at) is flat and landable.
## Patch 4.0.2 item 6: the gear is the player's again. The input's "gear"
## (1 down, 0 up) is a lever: the gear moves when the lever changes (G), so
## the server and the client agree however many frames carry it. It comes
## up on its own after take-off (climbing, above GEAR_RETRACT_AGL_M); a
## landing with the gear up is a belly landing (a hard landing and a repair
## bill, not a crash) unless it sinks faster than BELLY_MAX_SINK_MPS.
## Item 5: no upside-down flight: the bank stays inside bank_limit() and
## the pitch inside PITCH_LIMIT_RAD.
## Patch 4.0.3 item 1 (Andy: mouse aim is too complex): keyboard flying. The
## input is the keys, and the model flies the plane from them, the same on
## the server and the client. "pitch" (W +1 / S -1) raises or lowers the nose;
## released, the auto-trim holds the altitude the plane levels off at
## (hold_altitude). "roll" (D +1 / A -1) banks to bank_limit() (45 degrees,
## the Fighter 60) for a coordinated turn; released, it rolls level. "trick"
## (E +1 / Q -1, held by Aviation for one whole turn) is a barrel roll: the
## only way past the bank limit. "brake" in the air is the air brake.
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
const Airports = preload("res://features/planes/airports.gd")
## Patch 4.0.6 item 1: storms shake planes (turbulence). From the position and
## the shared clock only, so the server and the client's replay agree.
const Storms = preload("res://features/sky/storms.gd")
## No bumps this low (take-off, the flare): the gusts fade in up to here.
const TURBULENCE_AGL_M: float = 40.0
const GRAVITY: float = 9.81
const SEA_RHO: float = 1.225
const SCALE_HEIGHT_M: float = 8500.0
const MAX_ALTITUDE_M: float = 12000.0
const ENGINE_RATE: float = 0.6
## Touch-down limits on a runway.
const MAX_SINK_MPS: float = 8.5
const MAX_BANK_RAD: float = deg_to_rad(30.0)
const MAX_NOSE_DOWN_RAD: float = deg_to_rad(-10.0)
const MAX_NOSE_UP_RAD: float = deg_to_rad(20.0)
## Rolling off a runway onto grass faster than this is a crash.
const OFF_RUNWAY_MPS: float = 12.0
## Patch 4.0.2 item 6: the gear comes up on its own after take-off, once
## climbing faster than GEAR_RETRACT_CLIMB_MPS above GEAR_RETRACT_AGL_M.
const GEAR_RETRACT_AGL_M: float = 30.0
const GEAR_RETRACT_CLIMB_MPS: float = 0.5
## A gear-up touchdown sinking faster than this is a crash; slower is a
## belly landing: it slides to a stop on BELLY_FRICTION (g) and is billed.
const BELLY_MAX_SINK_MPS: float = 12.0
const BELLY_FRICTION: float = 0.45
## The belly rests this share of the gear height above the ground.
const BELLY_HEIGHT: float = 0.35
## Patch 4.0.2 item 5, Patch 4.0.3 item 1: the bank limit (BANK_LIMIT_DEG,
## the Fighter jet's FIGHTER_BANK_LIMIT_DEG) and the pitch limit (the nose
## command eases off LIMIT_GAIN per second of margin, aimed PITCH_SOFT_RAD
## inside it, and past it the nose is turned back).
const BANK_LIMIT_DEG: float = 45.0
const FIGHTER_BANK_LIMIT_DEG: float = 60.0
const PITCH_LIMIT_RAD: float = deg_to_rad(60.0)
const PITCH_SOFT_RAD: float = deg_to_rad(6.0)
const LIMIT_GAIN: float = 4.0
## Patch 4.0.3 item 1: A / D bank towards the limit at ROLL_GAIN per second
## of bank error (at most the plane's roll rate); a barrel roll turns at
## least BARREL_DPS. A key counts as held above KEY_HELD.
const ROLL_GAIN: float = 2.5
## Stall protection in a turn: A / D bank only as far as the wing can carry
## (the load of the bank at most 1 / TURN_LIFT_SHARE of what the wing lifts
## at this speed), never less than TURN_MIN_DEG; past the limit by less than
## BANK_SNAP_RAD the bank is held at the limit.
const TURN_LIFT_SHARE: float = 0.75
const TURN_MIN_DEG: float = 15.0
const BANK_SNAP_RAD: float = deg_to_rad(20.0)
const BARREL_DPS: float = 120.0
const KEY_HELD: float = 0.05
## The auto-trim: with W / S released the flight path eases level (at
## TRIM_GAIN per radian, at most PATH_RATE of the pitch rate); once the
## climb or sink is under HOLD_CAPTURE_MPS that altitude is held, returning
## to it at HOLD_GAIN metres a second per metre off (at most HOLD_MAX_MPS).
const TRIM_GAIN: float = 3.0
const PATH_TRIM: float = 0.6
const PATH_TRIM_MAX_RAD: float = deg_to_rad(8.0)
## W / S hold a climb (or a descent) this steep; the nose turns at most
## PATH_RATE of the plane's pitch rate.
const CLIMB_PATH_DEG: float = 15.0
const FIGHTER_CLIMB_PATH_DEG: float = 30.0
const PATH_RATE: float = 0.5
const CLIMB_SLOW: float = 1.15
const CLIMB_FAST: float = 1.5
const HOLD_CAPTURE_MPS: float = 1.5
const HOLD_GAIN: float = 0.25
const HOLD_MAX_MPS: float = 6.0
## Space in the air: the air brake's extra drag coefficient.
const AIR_BRAKE_CD: float = 0.06
## Arcade: the controls keep this share of their authority however slow.
const ARCADE_AUTHORITY: float = 0.3
## The nose-up command fades out over the last few degrees before the stall.
const STALL_MARGIN_RAD: float = deg_to_rad(3.0)
## Runway alignment: gear down, below RUNWAY_ASSIST_AGL_M, within
## RUNWAY_ASSIST_RAD of a runway's line, RUNWAY_ASSIST_ACROSS_M either side
## and up to RUNWAY_ASSIST_OUT_M before its near end.
const RUNWAY_ASSIST_RAD: float = deg_to_rad(25.0)
const RUNWAY_ASSIST_ACROSS_M: float = 450.0
const RUNWAY_ASSIST_AGL_M: float = 320.0
const RUNWAY_ASSIST_OUT_M: float = 3000.0
const RUNWAY_DRIFT_MPS: float = 12.0
const RUNWAY_DRIFT_ACCEL: float = 3.5
## In the landing configuration (gear down, throttle below LANDING_LEVER),
## the auto-trim holds a gentle glide (GLIDE_RAD down) instead of an
## altitude, so a hands-off final settles onto the runway.
const LANDING_LEVER: float = 0.5
const GLIDE_RAD: float = deg_to_rad(3.0)
const GLIDE_AIM_M: float = 150.0
const GLIDE_FIX_GAIN: float = 0.004
const GLIDE_FIX_RAD: float = deg_to_rad(2.0)
## Patch 4.0.1 item 2: the auto-flare. Gear down, below FLARE_AGL_M and
## sinking faster than FLARE_SINK_MPS, the sink eases towards it (ground
## effect and a gentle nose-up) by the time the wheels touch.
const FLARE_AGL_M: float = 9.0
const FLARE_SINK_MPS: float = 2.5
const FLARE_EASE: float = 7.0
const FLARE_PITCH_RAD: float = deg_to_rad(4.0)
## Flaps: lift and drag that grow as the engine drops (gear down).
const FLAP_LIFT: float = 0.35
const FLAP_LIFT_IDLE: float = 0.3
const FLAP_DRAG: float = 0.025
const FLAP_DRAG_IDLE: float = 0.05
## On the wheels at idle the spoilers keep this share of the lift.
const SPOILER_LIFT: float = 0.35
## Grass on the airfield beside the runway: extra rolling friction (g).
const AIRFIELD_FRICTION: float = 0.08

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
## Patch 4.0.2 item 6: the last gear lever seen (-1 none yet), whether the
## plane has just left the ground (the gear comes up once it climbs away),
## and this step's events: the gear came up on its own, a belly landing.
var gear_lever: float = -1.0
## Patch 4.0.3 item 1: the altitude the auto-trim holds (NAN: none yet; it
## is taken once the plane levels off after W / S are released).
var hold_altitude: float = NAN
var climbing_out: bool = false
var gear_auto_up: bool = false
var belly_landed: bool = false
var on_belly: bool = false
## 0..1: the storm round the plane at the last step (Patch 4.0.6).
var turbulence: float = 0.0

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
	climbing_out = false
	on_belly = false
	gear_auto_up = false
	belly_landed = false
	hold_altitude = NAN

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
	gear_lever = other.gear_lever
	hold_altitude = other.hold_altitude
	climbing_out = other.climbing_out
	on_belly = other.on_belly

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

## Bank over the whole circle (right positive), inverted flight included.
func full_bank() -> float:
	return atan2(basis.x.y, basis.y.y)

## Patch 4.0.2 item 6: the gear lever. A change of lever (G) moves the gear
## in the air; on the ground it stays down (or, after a belly landing, up
## until the plane stops). After take-off it comes up on its own.
func apply_gear(lever_in: float) -> void:
	gear_auto_up = false
	if lever_in >= 0.0:
		var want: float = 1.0 if lever_in >= 0.5 else 0.0
		if want != gear_lever and not on_ground: gear_down = want > 0.5
		gear_lever = want
	if climbing_out and not on_ground and gear_down and agl_m > GEAR_RETRACT_AGL_M and velocity.y > GEAR_RETRACT_CLIMB_MPS:
		# (The lever is left as it was: a late "down" from the same press
		# never lowers it again; only a new press of G does.)
		gear_down = false
		gear_auto_up = true
		climbing_out = false

## Patch 4.0.2 item 5, Patch 4.0.3 item 1: the bank limit, radians (A / D
## bank to it and never past it).
func bank_limit() -> float:
	return deg_to_rad(FIGHTER_BANK_LIMIT_DEG if str(p.get("engines", "")) == "afterburner" else BANK_LIMIT_DEG)

## Patch 4.0.3 item 1: how far A / D bank now: the bank limit, less when
## slow (the stall protection), so a turn never stalls the wing.
func turn_bank() -> float:
	if stalled or angle_of_attack > deg_to_rad(float(p.stall_deg)) - STALL_MARGIN_RAD: return deg_to_rad(TURN_MIN_DEG)
	var ratio: float = Planes.stall_speed(kind) / maxf(velocity.length(), 1.0)
	var carried: float = acos(clampf(ratio * ratio / TURN_LIFT_SHARE, 0.0, 1.0))
	return clampf(carried, deg_to_rad(TURN_MIN_DEG), bank_limit())

## Patch 4.0.3 item 1: 0..1, how much of a climb the speed allows: none
## under CLIMB_SLOW x the stall speed, all of it from CLIMB_FAST x.
func climb_share() -> float:
	return clampf((velocity.length() / Planes.stall_speed(kind) - CLIMB_SLOW) / (CLIMB_FAST - CLIMB_SLOW), 0.0, 1.0)

## Patch 4.0.3 item 1: how steep W climbs and S descends, radians.
func climb_path() -> float:
	return deg_to_rad(FIGHTER_CLIMB_PATH_DEG if str(p.get("engines", "")) == "afterburner" else CLIMB_PATH_DEG)

## Patch 4.0.2 item 5: the nose command (W / S, -1..1) limited so the plane
## never pitches past PITCH_LIMIT_RAD (no loop over onto its back); past
## it, the nose is turned back.
func limit_pitch(pitch_in: float) -> float:
	var pitch: float = clampf(pitch_in, -1.0, 1.0)
	if on_ground: return pitch
	var bank: float = full_bank()
	# The nose-up command (in the plane's frame) raises the nose by cos(bank).
	var raise: float = pitch * cos(bank)
	var nose: float = pitch_angle()
	var p_rate: float = maxf(deg_to_rad(float(p.pitch_dps)), 0.1)
	# It aims a few degrees inside the limit (PITCH_SOFT_RAD), so the stall
	# assist's push and the turn never carry the nose past it.
	var soft: float = PITCH_LIMIT_RAD - PITCH_SOFT_RAD
	if raise > 0.0 and nose > soft - 0.3: pitch *= clampf((soft - nose) * LIMIT_GAIN / p_rate / absf(raise), 0.0, 1.0)
	elif raise < 0.0 and nose < -soft + 0.3: pitch *= clampf((nose + soft) * LIMIT_GAIN / p_rate / absf(raise), 0.0, 1.0)
	if absf(nose) > soft and absf(cos(bank)) > 0.2: pitch = clampf(-signf(nose) * signf(cos(bank)) * ((absf(nose) - soft) * LIMIT_GAIN / p_rate + 0.15), -1.0, 1.0)
	return pitch

## The runway alignment assist (a yaw rate, radians per second): gear down,
## low and nearly lined up with the nearest runway (either end), the nose is
## steered onto a heading that joins the centre line.
func runway_assist() -> float:
	var final: Dictionary = final_approach()
	if final.is_empty(): return 0.0
	# Aim at a point on the centre line ahead (closer as the plane nears it).
	var want: float = float(final.line) - clampf(atan2(float(final.across), maxf(450.0, absf(float(final.across)) * 2.5)), -0.45, 0.45)
	return clampf(angle_difference(heading(), want) * 1.3, -0.3, 0.3)

## Patch 4.0.1 item 2: the final approach the plane is on, or {}: gear down,
## below RUNWAY_ASSIST_AGL_M, within RUNWAY_ASSIST_RAD of a runway's heading
## (either end), RUNWAY_ASSIST_ACROSS_M of its centre line, from
## RUNWAY_ASSIST_OUT_M before its near end to its far end. Every airport is
## tried (the nearest runway middle is not always the one being flown to);
## of several, the one the plane is best lined up with.
## {axis (unit, the way the plane lands), line (its heading), along (metres
## from the runway middle), across (metres right of the line, +side), side}.
func final_approach() -> Dictionary:
	if on_ground or not gear_down or agl_m > RUNWAY_ASSIST_AGL_M: return {}
	var list: Array[Dictionary] = Airports.all()
	var best: Dictionary = {}
	var best_score: float = INF
	for index: int in list.size():
		var entry: Dictionary = list[index]
		var local: Vector3 = Airports.local_to(entry.at, position)
		if absf(local.x) > 5000.0 or absf(local.z) > 5000.0: continue
		var axis: Vector3 = Vector3(sin(entry.heading), 0, cos(entry.heading))
		if Vector3(basis.z.x, 0, basis.z.z).dot(axis) < 0.0: axis = -axis
		var line: float = atan2(axis.x, axis.z)
		var off: float = absf(angle_difference(heading(), line))
		if off > RUNWAY_ASSIST_RAD: continue
		var along: float = local.x * axis.x + local.z * axis.z
		var across: float = local.x * axis.z - local.z * axis.x
		if absf(across) > RUNWAY_ASSIST_ACROSS_M or along > float(entry.length) * 0.5 or along < -float(entry.length) * 0.5 - RUNWAY_ASSIST_OUT_M: continue
		var score: float = absf(across) + off * 600.0
		if score < best_score:
			best_score = score
			best = {"airport": index, "axis": axis, "line": line, "along": along, "across": across, "side": Vector3(axis.z, 0, -axis.x)}
	return best

## Patch 4.0.1 item 2: on final the plane also drifts gently onto the centre
## line (an arcade crosswind-free "magnet"): its sideways speed eases towards
## one that closes the gap, at most RUNWAY_DRIFT_MPS, by RUNWAY_DRIFT_ACCEL.
func runway_drift(dt: float) -> void:
	var final: Dictionary = final_approach()
	if final.is_empty(): return
	var side: Vector3 = final.side
	var lateral: float = velocity.dot(side)
	var want: float = clampf(-float(final.across) * 0.1, -RUNWAY_DRIFT_MPS, RUNWAY_DRIFT_MPS)
	velocity += side * clampf(want - lateral, -RUNWAY_DRIFT_ACCEL * dt, RUNWAY_DRIFT_ACCEL * dt)

## Patch 4.0.3 item 1: the flight path the auto-trim flies with W / S
## released. In the landing configuration a gentle glide that eases into the
## flare's sink; otherwise level until the climb or sink is under
## HOLD_CAPTURE_MPS, then back to that altitude (hold_altitude).
func trim_path(lever: float) -> float:
	var speed: float = maxf(velocity.length(), 1.0)
	if gear_down and lever < LANDING_LEVER:
		hold_altitude = NAN
		if agl_m < FLARE_AGL_M: return -asin(clampf(FLARE_SINK_MPS / speed, 0.0, 0.2))
		# Patch 4.0.3 item 1: on a final approach the glide eases onto the
		# 3 degree slope to the touchdown zone (GLIDE_AIM_M past the
		# threshold), up to GLIDE_FIX_RAD steeper or shallower.
		var final: Dictionary = final_approach()
		if not final.is_empty():
			var entry: Dictionary = Airports.all()[int(final.airport)]
			var to_go: float = -float(entry.length) * 0.5 + GLIDE_AIM_M - float(final.along)
			if to_go > 0.0:
				var slope_y: float = float(entry.at.y) + gear_height_m + to_go * tan(GLIDE_RAD)
				return -GLIDE_RAD + clampf((slope_y - position.y) * GLIDE_FIX_GAIN, -GLIDE_FIX_RAD, GLIDE_FIX_RAD)
		return -GLIDE_RAD
	if is_nan(hold_altitude):
		if absf(velocity.y) >= HOLD_CAPTURE_MPS: return 0.0
		hold_altitude = position.y
	var climb: float = clampf((hold_altitude - position.y) * HOLD_GAIN, -HOLD_MAX_MPS, HOLD_MAX_MPS)
	return asin(clampf(climb / speed, -0.3, 0.3))

## Patch 4.0.3 item 1: the angle of attack whose lift carries the plane
## along its path at this speed and bank (inside the stall margin).
func trim_alpha(bank: float) -> float:
	var stall: float = deg_to_rad(float(p.stall_deg)) - STALL_MARGIN_RAD
	var q: float = 0.5 * air_density(position.y) * velocity.length_squared()
	if q < 1.0: return stall
	var need: float = float(p.mass_kg) * GRAVITY * cos(path_angle()) / (q * float(p.wing_m2) * maxf(cos(bank), 0.3))
	need -= (FLAP_LIFT + FLAP_LIFT_IDLE * (1.0 - engine)) if flaps else 0.0
	return clampf((need - float(p.cl0)) / maxf(float(p.cl_alpha), 0.1), -0.05, stall)

## Flight path angle (radians, climbing positive).
func path_angle() -> float:
	var speed: float = velocity.length()
	return asin(clampf(velocity.y / speed, -1.0, 1.0)) if speed > 1.0 else 0.0

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
	return cl + ((FLAP_LIFT + FLAP_LIFT_IDLE * (1.0 - engine)) if flaps else 0.0)

## One fixed step. `input` (Patch 4.0.3 item 1, the keys): throttle 0..1
## (the lever), pitch (W +1 nose up, S -1), roll (D +1 bank right, A -1),
## trick (a barrel roll: E +1 right, Q -1 left), brake 0..1 (Space: the
## wheel brakes, in the air the air brake), gear (the lever, 1 down).
func step(input: Dictionary, dt: float) -> void:
	crossed_pole = false
	if crashed or dt <= 0.0: return
	var lever: float = clampf(float(input.get("throttle", 0.0)), 0.0, 1.0) if fuel_l > 0.0 else 0.0
	var pitch_in: float = clampf(float(input.get("pitch", 0.0)), -1.0, 1.0)
	var roll_in: float = clampf(float(input.get("roll", 0.0)), -1.0, 1.0)
	var trick: float = clampf(float(input.get("trick", 0.0)), -1.0, 1.0)
	var brake: float = clampf(float(input.get("brake", 0.0)), 0.0, 1.0)
	apply_gear(float(input.get("gear", -1.0)))
	belly_landed = false
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
	# (Sliding on its belly the engines give nothing: it cannot take off gear-up.)
	force += forward * engine * float(p.thrust_n) * pow(rho / SEA_RHO, 0.7) * (0.0 if on_belly else 1.0)
	if speed > 0.5:
		var flow: Vector3 = velocity / speed
		var lift_dir: Vector3 = right.cross(flow)
		# On the wheels at idle the spoilers dump most of the lift (no bounce).
		var lift_share: float = SPOILER_LIFT if on_ground and lever < 0.2 else 1.0
		if lift_dir.length_squared() > 0.000001: force += lift_dir.normalized() * q * area * cl * lift_share
		var flap_drag: float = (FLAP_DRAG + FLAP_DRAG_IDLE * (1.0 - engine)) if flaps else 0.0
		var cd: float = float(p.cd0) + float(p.induced_k) * cl * cl + (0.02 if gear_down else 0.0) + flap_drag + (0.12 if stalled else 0.0) + (0.08 if on_ground and lever < 0.2 else 0.0) + (AIR_BRAKE_CD * brake if not on_ground else 0.0)
		force -= flow * q * area * cd
		force -= right * q * area * 0.8 * beta
	# Rotation. Control authority grows with airspeed (dynamic pressure).
	var reference: float = 0.5 * SEA_RHO * pow(float(p.rotate_mps) * 1.25, 2.0)
	var authority: float = clampf(q / reference, 0.0, 1.2)
	var pitch_rate: float = 0.0
	var roll_rate: float = 0.0
	var yaw_rate: float = 0.0
	var turn_rate: float = 0.0
	if on_ground:
		# Nose-wheel steering with A / D; W rotates near take-off speed.
		hold_altitude = NAN
		yaw_rate = -roll_in * deg_to_rad(30.0) * clampf(speed / 8.0, 0.0, 1.0) * clampf(1.0 - speed / 120.0, 0.3, 1.0)
		if along >= float(p.rotate_mps) * 0.9: pitch_rate = pitch_in * deg_to_rad(float(p.pitch_dps)) * 0.5 * authority
		elif pitch_angle() > 0.0: pitch_rate = -deg_to_rad(4.0)
	else:
		# Arcade flight (Patch 4.0.3 item 1: the keys). Assists (Andy,
		# November 20): the turn is coordinated (the nose follows the turn a
		# bank makes, sideslip is cancelled), the stall is recovered (the
		# nose-up command fades out near the stall angle, a stalled wing
		# lowers the nose until it flies again), the nose lines up with the
		# runway on a final approach, the auto-trim holds the altitude (or a
		# glide when set up to land) and the last metres of a landing flare
		# on their own.
		var reach: float = maxf(minf(authority, 1.0), ARCADE_AUTHORITY)
		var bank: float = full_bank()
		var stall_angle: float = deg_to_rad(float(p.stall_deg))
		# W / S: climb or descend at a steady flight path (CLIMB_PATH_DEG, the
		# Fighter's FIGHTER_CLIMB_PATH_DEG); released, the auto-trim holds the
		# altitude (or the glide). Any press drops the held altitude.
		var want_path: float = 0.0
		if absf(pitch_in) > KEY_HELD:
			hold_altitude = NAN
			want_path = pitch_in * climb_path()
		elif absf(bank) < deg_to_rad(80.0):
			want_path = trim_path(lever)
		# The stall protection: too slow, it climbs less (and not at all near
		# the stall), so it never runs out of speed in a climb.
		want_path = minf(want_path, climb_path() * climb_share())
		if absf(pitch_in) > KEY_HELD or absf(bank) < deg_to_rad(80.0):
			var most: float = deg_to_rad(float(p.pitch_dps)) * PATH_RATE
			# The nose goes where the path wants plus the wing's angle for the
			# lift that path needs (trim_alpha), so the path follows it calmly.
			var nose_to: float = want_path + trim_alpha(bank) * cos(bank) + clampf((want_path - path_angle()) * PATH_TRIM, -PATH_TRIM_MAX_RAD, PATH_TRIM_MAX_RAD)
			var turn_in: float = clampf((nose_to - pitch_angle()) * TRIM_GAIN, -most, most) / maxf(cos(bank), 0.5)
			# Inside the pitch limit (no loop over onto the back).
			pitch_rate = limit_pitch(turn_in / maxf(deg_to_rad(float(p.pitch_dps)), 0.01)) * deg_to_rad(float(p.pitch_dps)) * reach
		var roll_max: float = deg_to_rad(float(p.roll_dps)) * reach
		if absf(trick) > KEY_HELD:
			# Q / E: the barrel roll, past the limit (Aviation holds it for one turn).
			roll_rate = signf(trick) * deg_to_rad(maxf(float(p.roll_dps), BARREL_DPS)) * reach
		else:
			# A / D bank to the limit (less when slow: turn_bank), and roll
			# level when released.
			roll_rate = clampf((roll_in * turn_bank() - bank) * ROLL_GAIN, -roll_max, roll_max)
		# The auto-flare (item 2): the last few metres, gear down, the wings
		# level whatever the player holds, and a hard sink raises the nose.
		var flare: float = flare_weight()
		if flare > 0.0:
			if velocity.y < -FLARE_SINK_MPS * 1.5: pitch_rate += clampf((FLARE_PITCH_RAD - pitch_angle()) * 2.0, -0.2, 0.2) * flare
			roll_rate = lerpf(roll_rate, clampf(-bank * 2.0, -0.6, 0.6), flare)
		var margin: float = angle_of_attack - (stall_angle - STALL_MARGIN_RAD)
		if margin > 0.0 and pitch_rate > 0.0: pitch_rate *= clampf(1.0 - margin / STALL_MARGIN_RAD, 0.0, 1.0)
		# (Patch 4.0.3: a wing stalled the other way, nose pushed too far
		# down, has its nose raised.)
		if stalled: pitch_rate -= signf(angle_of_attack) * deg_to_rad(float(p.pitch_dps)) * 0.6
		yaw_rate = -beta * 1.5 * reach + runway_assist()
		# The coordinated turn: the nose follows the turn the bank makes.
		if absf(bank) < PI * 0.5: turn_rate = -GRAVITY * tan(clampf(bank, -1.25, 1.25)) / maxf(speed, float(p.rotate_mps))
	basis = (Basis(Vector3.UP, turn_rate * dt) * basis * Basis(Vector3(1, 0, 0), -pitch_rate * dt) * Basis(Vector3(0, 0, 1), roll_rate * dt) * Basis(Vector3(0, 1, 0), yaw_rate * dt)).orthonormalized()
	# Patch 4.0.3 item 1: outside a barrel roll the bank never passes the
	# limit (a stalled wing or the sideslip's yaw could carry it a little
	# past); a bigger bank (a barrel roll let go) rolls back on its own.
	if not on_ground and absf(trick) <= KEY_HELD:
		var over: float = absf(full_bank()) - bank_limit()
		if over > 0.0 and over < BANK_SNAP_RAD: basis = (basis * Basis(Vector3(0, 0, 1), -signf(full_bank()) * over)).orthonormalized()
	velocity += force / mass * dt
	# Patch 4.0.6 item 1: in a storm the air bumps the plane up and down and
	# rocks its wings (the altitude hold and the roll-level work against it).
	turbulence = 0.0 if on_ground else Storms.intensity_at(position) * clampf(agl_m / TURBULENCE_AGL_M, 0.0, 1.0)
	if turbulence > 0.0:
		var bump: Vector2 = Storms.gust(position, turbulence)
		velocity.y += bump.x * dt
		basis = (basis * Basis(Vector3(0, 0, 1), bump.y * dt)).orthonormalized()
	if not on_ground: runway_drift(dt)
	# The auto-flare's cushion: the sink eases off before the wheels touch.
	var cushion: float = flare_weight()
	if cushion > 0.0 and velocity.y < -FLARE_SINK_MPS:
		velocity.y = move_toward(velocity.y, -FLARE_SINK_MPS, FLARE_EASE * cushion * dt)
	if on_ground:
		forward = basis.z
		var flat_forward: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
		var rolling: float = velocity.dot(flat_forward)
		var friction: float = (0.02 + 1.1 * brake + (AIRFIELD_FRICTION if Terrain.sample(position).surface == "airfield" else 0.0) + (BELLY_FRICTION if on_belly else 0.0)) * GRAVITY * dt
		rolling = move_toward(rolling, 0.0, friction) if absf(rolling) > friction else (0.0 if engine < 0.05 else rolling)
		velocity = flat_forward * rolling + Vector3(0, maxf(velocity.y, 0.0), 0)
	position += velocity * dt
	position.y = minf(position.y, MAX_ALTITUDE_M)
	wrap_world()
	contact()

## 0..1: how much the auto-flare works now (gear down, descending, in the
## last FLARE_AGL_M over a runway or its airfield).
func flare_weight() -> float:
	if on_ground or not gear_down or velocity.y >= 0.0 or agl_m >= FLARE_AGL_M: return 0.0
	if Airports.airfield_at(position) < 0: return 0.0
	return clampf(1.0 - agl_m / FLARE_AGL_M, 0.0, 1.0) * 0.6 + 0.4

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
	var rest: float = gear_height_m * (BELLY_HEIGHT if on_belly else 1.0)
	agl_m = position.y - rest - ground
	flaps = gear_down and velocity.length() < float(p.rotate_mps) * 1.9
	if agl_m > 0.05:
		# A real lift-off (not a plane placed in the air): the gear comes up
		# once it climbs away (apply_gear).
		if on_ground and agl_m < 3.0: climbing_out = true
		on_ground = false
		on_belly = false
		return
	var sink: float = -velocity.y
	var speed: float = velocity.length()
	if below.surface not in ["runway", "airfield"]:
		if speed > OFF_RUNWAY_MPS or not on_ground or below.surface == "sea":
			crash("Crashed into the %s." % ("sea" if below.surface == "sea" else ("ice" if below.surface == "ice" else "ground")))
			return
	var belly: bool = false
	if not on_ground:
		var fault: String = ""
		if not gear_down:
			# Patch 4.0.2 item 6: a belly landing, unless it sinks extremely fast.
			if sink > BELLY_MAX_SINK_MPS: fault = "Belly-flopped onto the runway far too hard."
			elif absf(bank_angle()) > MAX_BANK_RAD: fault = "A wing hit the runway."
			else: belly = true
		elif sink > MAX_SINK_MPS: fault = "Hit the runway too hard."
		elif absf(bank_angle()) > MAX_BANK_RAD: fault = "A wing hit the runway."
		elif pitch_angle() < MAX_NOSE_DOWN_RAD: fault = "Nose-first into the runway."
		elif pitch_angle() > MAX_NOSE_UP_RAD: fault = "Tail strike."
		if not fault.is_empty():
			crash(fault)
			return
	if belly:
		on_belly = true
		belly_landed = true
	on_ground = true
	climbing_out = false
	# Stopped on its belly: the ground crew jack it onto its wheels.
	if on_belly and velocity.length() < 1.0:
		on_belly = false
		gear_down = true
	if not on_belly: gear_down = true
	agl_m = 0.0
	position.y = ground + gear_height_m * (BELLY_HEIGHT if on_belly else 1.0)
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
