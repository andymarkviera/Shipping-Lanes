extends RefCounted
## Patch 4.0 checks: a small scripted pilot for FlightModel. Patch 4.0.3
## item 1: it flies with the keyboard only, as a player does: W / S held or
## not (pitch +1, -1 or 0), A / D held or not (roll -1, +1 or 0), the
## throttle lever moved by Shift / Ctrl at Aviation.LEVER_RATE, Space (brake)
## and G (gear). Never a part-way key. So a take-off and landing it manages
## proves the keyboard scheme is flyable: full throttle, W past rotation
## speed, climb out, fly to a fix five km before the destination runway,
## line up, gear down and throttle back (the auto-trim's 3 degree glide), the
## auto-flare, touch down and brake.
## Patch 4.0.1 item 2: sloppy_start / sloppy_inputs fly the approach an
## average player would: set up off the centre line, a little fast and high,
## nearly lined up, then only coarse key taps (a turn towards the runway's
## far end, throttle back, no flare, Space to brake). The assists (runway
## alignment, the glide, auto-flare) do the rest.
const Airports = preload("res://features/planes/airports.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Progression = preload("res://features/game/progression.gd")
## As Aviation.LEVER_RATE: Shift / Ctrl move the lever this much a second.
const LEVER_RATE: float = 0.6
const STEP: float = 1.0 / 60.0
var destination: int = 0
var phase: String = "takeoff"
var cruise_m: float = 260.0
var takeoff_heading: float = NAN
## The throttle lever (Shift / Ctrl move it; it stays where it is left).
var lever: float = 0.0
## Which keys the last frame held (for the checks): "W", "S", "A", "D".
var keys: PackedStringArray = []

## Patch 4.0.3: which end of the runway it lands towards (+1 along its
## heading, -1 the other way): the end whose approach fix is not over a pole.
var landing_way: float = 1.0

func _init(target: int) -> void:
	destination = target
	var entry: Dictionary = Airports.all()[destination]
	var fix: Vector3 = entry.at - Vector3(sin(entry.heading), 0, cos(entry.heading)) * 6000.0
	var pole: Callable = func(at: Vector3) -> float: return Progression.WRAP_M / 2.0 - absf(at.z - Progression.WRAP_CENTRE.z)
	if pole.call(fix) < 900.0 and pole.call(fix) < pole.call(entry.at) - 100.0: landing_way = -1.0

func runway_axis() -> Vector3:
	var entry: Dictionary = Airports.all()[destination]
	return Vector3(sin(entry.heading), 0, cos(entry.heading)) * landing_way

func runway_y() -> float:
	return float(Airports.all()[destination].at.y)

func threshold() -> Vector3:
	var entry: Dictionary = Airports.all()[destination]
	return entry.at - runway_axis() * (entry.length * 0.5 - 80.0)

## Shift or Ctrl held towards `want` this frame.
func move_lever(want: float) -> void:
	lever = move_toward(lever, clampf(want, 0.0, 1.0), LEVER_RATE * STEP)

## A / D: hold the key that turns towards `bank_wanted` (radians, right +)
## while the bank is short of it; let go (the plane rolls level) otherwise.
func turn_key(m: RefCounted, bank_wanted: float) -> float:
	var bank: float = m.bank_angle()
	if bank_wanted > 0.04 and bank < bank_wanted: return 1.0
	if bank_wanted < -0.04 and bank > bank_wanted: return -1.0
	return 0.0

## W / S: held while more than `band` metres off the altitude wanted;
## released in between (the auto-trim then holds the altitude).
func pitch_key(m: RefCounted, altitude: float, band: float) -> float:
	# (Let go early: where the climb or sink will have carried it in 2 s.)
	var ahead: float = m.position.y + m.velocity.y * 2.0
	if ahead < altitude - band: return 1.0
	if ahead > altitude + band: return -1.0
	return 0.0

func inputs(m: RefCounted) -> Dictionary:
	var stall: float = Planes.stall_speed(m.kind)
	var axis: Vector3 = runway_axis()
	var touch: Vector3 = threshold()
	var local: Vector3 = Airports.local_to(touch, m.position)
	var along: float = local.x * axis.x + local.z * axis.z
	var across: float = local.x * axis.z - local.z * axis.x
	var runway_heading: float = atan2(axis.x, axis.z)
	var want: float = runway_heading
	var altitude: float = runway_y() + cruise_m
	var speed: float = stall * 1.7
	match phase:
		"takeoff":
			if not m.on_ground and m.agl_m > 60.0: phase = "outbound"
		"outbound":
			# Fly to a point well out on the approach side, then join the line.
			var to: Vector3 = Airports.local_to(m.position, touch - axis * 5600.0)
			speed = stall * 1.4
			want = atan2(to.x, to.z)
			if along < -4800.0 and along > -6200.0 and absf(across) < 1500.0: phase = "join"
		"join":
			want = runway_heading - clampf(across * 0.0007, -0.7, 0.7)
			speed = stall * 1.3
			# Down to the 3 degree glide path (aimed 150 m past the threshold).
			altitude = minf(runway_y() + cruise_m, runway_y() + 6.0 + maxf(150.0 - along, 0.0) * tan(deg_to_rad(3.0)))
			if along > -3800.0 and absf(across) < 250.0 and absf(angle_difference(m.heading(), runway_heading)) < 0.3 and absf(m.position.y - altitude) < 25.0 and absf(m.velocity.y) < 6.0: phase = "final"
			elif along > -2500.0: phase = "outbound" # Not lined up: go round again.
		"final":
			if m.on_ground: phase = "rollout"
	var out: Dictionary = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "trick": 0.0, "brake": 0.0}
	if phase == "takeoff":
		if is_nan(takeoff_heading): takeoff_heading = m.heading()
		# Shift to full; A / D keep the nose on the centre line; W once past
		# rotation speed, held until well clear of the ground.
		move_lever(1.0)
		out.throttle = lever
		var off: float = -angle_difference(m.heading(), takeoff_heading)
		if m.on_ground and absf(off) > 0.01: out.roll = signf(off)
		if (m.on_ground and m.velocity.length() > float(m.p.rotate_mps)) or not m.on_ground: out.pitch = 1.0
		return note(out)
	if phase == "rollout":
		# Space: the wheel brakes; Ctrl to idle; A / D on the centre line.
		move_lever(0.0)
		out.throttle = lever
		out.brake = 1.0
		out.roll = steer_ground(m, axis)
		out.gear = 1.0
		return note(out)
	# Patch 4.0.2 item 6: the gear is the pilot's: down (G) on final; it
	# came up on its own after take-off.
	if phase == "final": out.gear = 1.0
	var error: float = angle_difference(m.heading(), want)
	var bank_wanted: float = clampf(-error * 1.6, -m.bank_limit(), m.bank_limit())
	if phase == "final":
		# On final: the runway assist lines up the nose; A / D only for a big
		# miss. Gear down and the throttle under half: the auto-trim glides
		# at 3 degrees and flares on its own. No W / S at all.
		bank_wanted = clampf(-angle_difference(m.heading(), runway_heading - clampf(across * 0.003, -0.4, 0.4)) * 1.2, -0.3, 0.3) if m.agl_m > 40.0 else 0.0
		out.roll = turn_key(m, bank_wanted)
		move_lever(clampf(0.3 + (stall * 1.15 - m.velocity.length()) * 0.1, 0.0, 0.45) if m.agl_m > 12.0 else 0.0)
		out.throttle = lever
		return note(out)
	out.roll = turn_key(m, bank_wanted)
	out.pitch = pitch_key(m, altitude, 12.0)
	move_lever(clampf(0.55 + (speed - m.velocity.length()) * 0.1, 0.0, 1.0))
	out.throttle = lever
	return note(out)

## Records the keys of this frame's inputs (for the checks), and returns them.
func note(out: Dictionary) -> Dictionary:
	keys = []
	if float(out.pitch) > 0.0: keys.append("W")
	if float(out.pitch) < 0.0: keys.append("S")
	if float(out.roll) < 0.0: keys.append("A")
	if float(out.roll) > 0.0: keys.append("D")
	return out

## On the wheels: A / D keep the nose on the centre line.
func steer_ground(m: RefCounted, axis: Vector3) -> float:
	var want: float = atan2(axis.x, axis.z)
	var local: Vector3 = Airports.local_to(threshold(), m.position)
	var off: float = local.x * axis.z - local.z * axis.x
	var turn: float = -angle_difference(m.heading(), want) * 4.0 + off * 0.04
	return 0.0 if absf(turn) < 0.05 else signf(turn)

## Patch 4.0.1: an approach start for the sloppy pilot: `out_m` before the
## runway's near end, `offset_m` off the centre line, `turn` radians off its
## heading, `high_m` above a 3 degree path, at `fast` x the stall speed.
func sloppy_start(m: RefCounted, out_m: float = 3000.0, offset_m: float = 90.0, turn: float = deg_to_rad(8.0), high_m: float = 25.0, fast: float = 1.4) -> void:
	var entry: Dictionary = Airports.all()[destination]
	var axis: Vector3 = runway_axis()
	var side: Vector3 = Vector3(axis.z, 0, -axis.x)
	var near_end: Vector3 = entry.at - axis * entry.length * 0.5
	var at: Vector3 = near_end - axis * out_m + side * offset_m
	at.y = runway_y() + m.gear_height_m + out_m * tan(deg_to_rad(3.0)) + high_m
	m.position = Progression.wrapped(at)
	m.position.y = at.y
	m.basis = Basis(Vector3.UP, atan2(axis.x, axis.z) + turn) * Basis(Vector3(1, 0, 0), deg_to_rad(2.0))
	m.velocity = m.basis.z * Planes.stall_speed(m.kind) * fast
	m.on_ground = false
	m.engine = 0.3
	m.agl_m = at.y - runway_y()
	lever = 0.3
	phase = "sloppy"

func sloppy_inputs(m: RefCounted) -> Dictionary:
	var out: Dictionary = {"throttle": 0.25, "pitch": 0.0, "roll": 0.0, "trick": 0.0, "brake": 0.0, "gear": 1.0}
	if m.on_ground: phase = "rollout"
	if phase == "rollout":
		# Ctrl to idle and Space: the brakes. No steering at all.
		move_lever(0.0)
		out.throttle = lever
		out.brake = 1.0
		return note(out)
	var entry: Dictionary = Airports.all()[destination]
	var axis: Vector3 = runway_axis()
	# A coarse turn towards the far end of the runway: a tap of A or D (held
	# a quarter of a second, then let go) while the nose is more than 6
	# degrees off it; hands off in the last 20 m.
	var aim_at: Vector3 = Airports.local_to(m.position, entry.at + axis * entry.length * 0.5)
	var error: float = angle_difference(m.heading(), atan2(aim_at.x, aim_at.z))
	if absf(error) > deg_to_rad(6.0) and m.agl_m > 20.0 and absf(m.bank_angle()) < deg_to_rad(12.0): out.roll = -signf(error)
	# Coarse pitch: S while well above a 3 degree path, W while well below
	# it; hands off in between (and in the last 40 m): the glide.
	var local: Vector3 = Airports.local_to(entry.at - axis * entry.length * 0.5, m.position)
	var to_go: float = -(local.x * axis.x + local.z * axis.z)
	var path_m: float = runway_y() + maxf(to_go, 0.0) * tan(deg_to_rad(3.0))
	if m.agl_m > 40.0:
		if m.position.y > path_m + 40.0: out.pitch = -1.0
		elif m.position.y < path_m - 40.0: out.pitch = 1.0
	# Coarse throttle: a set approach power, more when slow, idle when fast,
	# idle at the end (under half: the glide).
	var stall: float = Planes.stall_speed(m.kind)
	var lever_wanted: float = 0.3
	if m.airspeed() < stall * 1.1: lever_wanted = 0.45
	elif m.airspeed() > stall * 1.6: lever_wanted = 0.0
	if m.agl_m < 15.0: lever_wanted = 0.0
	move_lever(lever_wanted)
	out.throttle = lever
	return note(out)
