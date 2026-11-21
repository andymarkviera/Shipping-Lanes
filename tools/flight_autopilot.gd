extends RefCounted
## Patch 4.0 checks: a small scripted pilot for FlightModel. It flies the
## plane's ordinary keyboard inputs (throttle, pitch, roll, yaw, brake) only,
## so a take-off and landing it manages proves the physics are flyable: climb
## out, fly to a fix five km before the destination runway, track the runway's
## centre line down a 3 degree glide path, flare, touch down and brake.
## Patch 4.0.1 item 2: sloppy_start / sloppy_inputs fly the approach an
## average player would: set up off the centre line, a little fast and high,
## nearly lined up, then only coarse inputs (a rough turn towards the runway's
## heading, throttle back, hands off the pitch, no flare, S to brake). The
## assists (runway alignment, auto-level glide, auto-flare) do the rest.
const Airports = preload("res://features/planes/airports.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Progression = preload("res://features/game/progression.gd")
var destination: int = 0
var phase: String = "takeoff"
var cruise_m: float = 260.0
var takeoff_heading: float = NAN

func _init(target: int) -> void:
	destination = target

func runway_axis() -> Vector3:
	var entry: Dictionary = Airports.all()[destination]
	return Vector3(sin(entry.heading), 0, cos(entry.heading))

func threshold() -> Vector3:
	var entry: Dictionary = Airports.all()[destination]
	return entry.at - runway_axis() * (entry.length * 0.5 - 80.0)

func inputs(m: RefCounted) -> Dictionary:
	var stall: float = Planes.stall_speed(m.kind)
	var axis: Vector3 = runway_axis()
	var touch: Vector3 = threshold()
	var local: Vector3 = Progression.short_way(m.position - touch)
	var along: float = local.x * axis.x + local.z * axis.z
	var across: float = local.x * axis.z - local.z * axis.x
	var runway_heading: float = atan2(axis.x, axis.z)
	var want: float = runway_heading
	var altitude: float = cruise_m
	var speed: float = stall * 1.7
	match phase:
		"takeoff":
			if not m.on_ground and m.agl_m > 60.0: phase = "outbound"
		"outbound":
			# Fly to a point well out on the approach side, then join the line.
			var to: Vector3 = Progression.short_way(touch - axis * 5600.0 - m.position)
			speed = stall * 1.3
			want = atan2(to.x, to.z)
			if along < -4800.0 and along > -6200.0 and absf(across) < 1500.0: phase = "join"
		"join":
			want = runway_heading - clampf(across * 0.0007, -0.7, 0.7)
			speed = stall * 1.2
			# Start down early: never above the 3 degree glide path.
			altitude = minf(cruise_m, Airports.RUNWAY_Y + 40.0 + maxf(150.0 - along, 0.0) * tan(deg_to_rad(3.0)))
			if along > -3800.0 and absf(across) < 350.0 and absf(angle_difference(m.heading(), runway_heading)) < 0.35: phase = "final"
			elif along > -2500.0: phase = "outbound" # Not lined up: go round again.
		"final":
			if m.on_ground: phase = "rollout"
	var out: Dictionary = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "brake": 0.0}
	if phase == "takeoff":
		if is_nan(takeoff_heading): takeoff_heading = m.heading()
		out.throttle = 1.0
		if m.on_ground and m.velocity.length() > float(m.p.rotate_mps): out.pitch = 0.8
		elif not m.on_ground: out.pitch = clampf((deg_to_rad(9.0) - m.pitch_angle()) * 4.0, -1.0, 1.0)
		out.roll = clampf(-angle_difference(m.heading(), takeoff_heading) * 4.0, -1.0, 1.0)
		return out
	if phase == "rollout":
		out.brake = 1.0
		out.roll = steer_ground(m, axis)
		return out
	if phase == "final":
		# Hold the centre line; ride the 3 degree glide path.
		want = runway_heading - clampf(across * 0.003, -0.45, 0.45)
		altitude = Airports.RUNWAY_Y + m.gear_height_m - 2.0 + maxf(150.0 - along, 0.0) * tan(deg_to_rad(3.0))
		speed = stall * 1.12
	var error: float = angle_difference(m.heading(), want)
	# Bank right (positive) turns the nose towards -X, the plane's right.
	var limit: float = deg_to_rad(8.0 if phase == "final" and m.agl_m < 60.0 else 35.0)
	var bank_target: float = clampf(-error * 1.6, -limit, limit)
	out.roll = clampf((bank_target - m.bank_angle()) * 3.0, -1.0, 1.0)
	var climb: float = clampf((altitude - m.position.y) * 0.25, -7.0, 7.0)
	if phase == "final" and m.agl_m < 6.0:
		# Flare: idle, and settle on at a gentle sink.
		climb = -1.6
		speed = 0.0
	# The arcade model holds its attitude hands off (no auto-trim), so the pilot
	# flies the flight path angle: pitch towards the climb it wants.
	var airspeed: float = maxf(m.velocity.length(), 1.0)
	var path: float = asin(clampf(m.velocity.y / airspeed, -1.0, 1.0))
	var want_path: float = asin(clampf(climb / airspeed, -0.35, 0.35))
	out.pitch = clampf((want_path - path) * 6.0, -1.0, 1.0)
	out.throttle = clampf(0.45 + (speed - m.velocity.length()) * 0.12, 0.0, 1.0)
	return out

## On the wheels: keep the nose on the centre line.
func steer_ground(m: RefCounted, axis: Vector3) -> float:
	var want: float = atan2(axis.x, axis.z)
	var local: Vector3 = Progression.short_way(m.position - threshold())
	var off: float = local.x * axis.z - local.z * axis.x
	return clampf(-angle_difference(m.heading(), want) * 4.0 + off * 0.04, -1.0, 1.0)

## Patch 4.0.1: an approach start for the sloppy pilot: `out_m` before the
## runway's near end, `offset_m` off the centre line, `turn` radians off its
## heading, `high_m` above a 3 degree path, at `fast` x the stall speed.
func sloppy_start(m: RefCounted, out_m: float = 3000.0, offset_m: float = 90.0, turn: float = deg_to_rad(8.0), high_m: float = 25.0, fast: float = 1.4) -> void:
	var entry: Dictionary = Airports.all()[destination]
	var axis: Vector3 = runway_axis()
	var side: Vector3 = Vector3(axis.z, 0, -axis.x)
	var near_end: Vector3 = entry.at - axis * entry.length * 0.5
	var at: Vector3 = near_end - axis * out_m + side * offset_m
	at.y = Airports.RUNWAY_Y + m.gear_height_m + out_m * tan(deg_to_rad(3.0)) + high_m
	m.position = at
	m.basis = Basis(Vector3.UP, atan2(axis.x, axis.z) + turn) * Basis(Vector3(1, 0, 0), deg_to_rad(2.0))
	m.velocity = m.basis.z * Planes.stall_speed(m.kind) * fast
	m.on_ground = false
	m.engine = 0.3
	m.agl_m = at.y - Airports.RUNWAY_Y
	phase = "sloppy"

func sloppy_inputs(m: RefCounted) -> Dictionary:
	var out: Dictionary = {"throttle": 0.25, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "brake": 0.0}
	if m.on_ground: phase = "rollout"
	if phase == "rollout":
		# S held at idle: the brakes. No steering at all.
		out.throttle = 0.0
		out.brake = 1.0
		return out
	var entry: Dictionary = Airports.all()[destination]
	var axis: Vector3 = runway_axis()
	# A coarse turn towards the far end of the runway: a nudge of roll while
	# the nose is more than 6 degrees off it, then hands off (the auto-level
	# rolls it level); hands off altogether in the last 20 m.
	var aim_at: Vector3 = Progression.short_way(entry.at + axis * entry.length * 0.5 - m.position)
	var error: float = angle_difference(m.heading(), atan2(aim_at.x, aim_at.z))
	# (A nudge that rolls about 9 degrees a second, whatever the plane.)
	if absf(error) > deg_to_rad(6.0) and m.agl_m > 20.0: out.roll = -signf(error) * clampf(9.0 / float(m.p.roll_dps), 0.04, 0.3)
	# Coarse pitch: a nudge down while well above a 3 degree path, a nudge
	# up while well below it; hands off in between (and in the last 40 m).
	var local: Vector3 = Progression.short_way(m.position - (entry.at - axis * entry.length * 0.5))
	var to_go: float = -(local.x * axis.x + local.z * axis.z)
	var path_m: float = Airports.RUNWAY_Y + maxf(to_go, 0.0) * tan(deg_to_rad(3.0))
	if m.agl_m > 40.0:
		if m.position.y > path_m + 40.0: out.pitch = -0.2
		elif m.position.y < path_m - 40.0: out.pitch = 0.2
	# Coarse throttle: a set approach power, more when slow, idle when fast,
	# idle at the end.
	var stall: float = Planes.stall_speed(m.kind)
	out.throttle = 0.3
	if m.airspeed() < stall * 1.1: out.throttle = 0.6
	elif m.airspeed() > stall * 1.6: out.throttle = 0.0
	if m.agl_m < 15.0: out.throttle = 0.0
	return out
