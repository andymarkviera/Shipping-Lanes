class_name ShipVisualMotion
extends Node3D
## Presentation only: parent body/collider and camera focus never inherit this.
## The hull rides the drawn swell, bobs and pitches harder with speed and leans
## into turns. All of it is deliberately exaggerated (Patch 2.0 sailing feel).
var elapsed: float = 0.0
var quality: int = 1
## Normalized visual load until authoritative cargo mass is available.
## This prototype offset is not a real ship draft or a navigation restriction.
const FULL_LOAD_SINK_M: float = 0.85
const MAX_HEAVE_M: float = 1.6
const MAX_PITCH_RAD: float = deg_to_rad(7.0)
const MAX_ROLL_RAD: float = deg_to_rad(11.0)
const TURN_LEAN_RAD: float = deg_to_rad(6.0)
const SWELL_TILT_GAIN: float = 2.0
var load_fraction: float = 0.0
var load_sink_m: float = 0.0
## Optional. Without a body the hull still rocks; without an ocean it keeps its own clock.
var body: CharacterBody3D
var ocean: OceanPresentation
var half_length: float = 30.0
var half_width: float = 6.5
var cruise_speed_mps: float = ShipWake.FULL_STRENGTH_SPEED_MPS
var full_turn_rate_rad: float = deg_to_rad(3.0)
var speed_fraction: float = 0.0
var lean: float = 0.0
var heave_m: float = 0.0
var last_yaw: float = 0.0
var has_yaw: bool = false
## Patch 2.4 item 1: the hull this motion was tuned on (ship 1, 64 m, 2.6 m
## deck). Longer hulls pitch through smaller angles so the bow and stern move
## by about as much of their own deck height as ship 1's do, and wider hulls
## roll less; the trim at speed is always bow-up.
const REFERENCE_DECK_PER_HALF_LENGTH: float = 2.6 / 30.0
const REFERENCE_HALF_WIDTH_M: float = 6.5
## Bow or stern may move up or down at most this share of the deck height.
const PITCH_DECK_SHARE: float = 0.3
## Bow-up trim at full ahead on ship 1 (was 1.2 degrees, which sank the stern).
const SPEED_TRIM_RAD: float = deg_to_rad(0.4)
var deck_height_m: float = 2.6
var pitch_scale: float = 1.0
var roll_scale: float = 1.0
var pitch_limit_rad: float = MAX_PITCH_RAD
var roll_limit_rad: float = MAX_ROLL_RAD

## Patch 2.4 item 8: planing small boats jump the waves. The wave face throws
## the hull up (its rise rate times jump_lift); once the water drops away faster
## than gravity pulls the hull down, the hull flies on a ballistic arc and lands
## back on the surface. Presentation only, like the rest of this node: the body,
## collider and camera stay on the water plane.
signal landed(impact: float)
const JUMP_GRAVITY_MPS2: float = 9.81
## Wavelength of the chop a planing hull meets at speed: 2 pi / 0.26, about 24 m.
const CHOP_PER_M: float = 0.26
## Patch 2.9 item 4: the chop is met at no more than this pace, so the 200 kn
## racer jumps like it did at its old 42 kn instead of being flung skyward.
const CHOP_PACE_LIMIT_MPS: float = 21.6
## A hull leaves the water only above this rise rate, and stays down this long
## after landing, so it never chatters on the surface.
const MIN_LAUNCH_MPS: float = 0.8
const SETTLE_S: float = 0.25
const JUMP_PITCH_LIMIT_RAD: float = deg_to_rad(14.0)
const JUMP_ROLL_LIMIT_RAD: float = deg_to_rad(12.0)
var jump_lift: float = 0.0
## Patch 2.9 item 5: bow-up trim on the plane, reached from about a third of
## cruise speed, and how far the hull rises with it (the stern stays wet).
var plane_trim_rad: float = 0.0
var plane: float = 0.0
var chop_height_m: float = 0.0
var top_speed_mps: float = 10.0
var airborne: bool = false
var air_time: float = 0.0
var longest_air_s: float = 0.0
var jump_y: float = 0.0
var jump_vy: float = 0.0
var jump_pitch: float = 0.0
var land_dip: float = 0.0
var land_dip_vy: float = 0.0
var settle: float = 0.0
var travel_m: float = 0.0
var last_surface: float = 0.0
var has_surface: bool = false

## Sizes the rocking from a ship record: hull length, beam and deck height
## (chunky_look builds the deck 2.6 m above the waterline per 4 m of hull height).
func configure_hull(definition: ShipDefinition) -> void:
	half_length = definition.wake_half_length_m
	half_width = definition.wake_half_width_m
	full_turn_rate_rad = deg_to_rad(maxf(definition.max_turn_rate_degrees, 0.1))
	deck_height_m = 2.6 * definition.hull_size_m.y / 4.0
	var reach: float = maxf(definition.hull_size_m.z * 0.5, half_length)
	pitch_scale = clampf(deck_height_m / maxf(half_length, 1.0) / REFERENCE_DECK_PER_HALF_LENGTH, 0.1, 1.0)
	pitch_limit_rad = minf(MAX_PITCH_RAD, asin(clampf(PITCH_DECK_SHARE * deck_height_m / maxf(reach, 1.0), 0.0, 1.0)))
	roll_scale = clampf(sqrt(REFERENCE_HALF_WIDTH_M / maxf(half_width, 0.1)), 0.4, 1.0) * clampf(definition.roll_gain, 0.1, 2.0)
	roll_limit_rad = MAX_ROLL_RAD * roll_scale
	jump_lift = maxf(definition.jump_lift, 0.0)
	chop_height_m = maxf(definition.chop_height_m, 0.0)
	plane_trim_rad = deg_to_rad(clampf(definition.plane_trim_degrees, 0.0, 8.0))
	top_speed_mps = maxf(definition.forward_acceleration_mps2 / maxf(definition.linear_drag_per_second, 0.001), 1.0)
	if jump_lift > 0.0:
		pitch_limit_rad = maxf(pitch_limit_rad, JUMP_PITCH_LIMIT_RAD)
		roll_limit_rad = maxf(roll_limit_rad, JUMP_ROLL_LIMIT_RAD)
	hover_m = HOVER_REST_M if JETTY_BOOST.eligible(definition) else 0.0

## Patch 4.0.2: the Jetty hovers. The hull rises HOVER_REST_M off the water at
## rest (its keel about 0.9 m clear), up to HOVER_SPEED_M higher at full speed
## and HOVER_BLAST_M more in a blast, with a slow float, a calm trim and a lean
## into turns; it follows the swell only softly. Presentation only, like the rest of this node: the body, collider and
## camera stay on the water plane. JettyFx draws the downwash under it.
const JETTY_BOOST = preload("res://features/ships/jetty_boost.gd")
const HOVER_REST_M: float = 2.0
const HOVER_SPEED_M: float = 0.8
const HOVER_BLAST_M: float = 0.5
const HOVER_SWELL_SHARE: float = 0.35
const HOVER_PITCH_LIMIT_RAD: float = deg_to_rad(6.0)
const HOVER_ROLL_LIMIT_RAD: float = deg_to_rad(14.0)
var hover_m: float = 0.0
## Patch 4.0.7 item 4: 0..1, how much of the swell the hover follows (none
## over land: the body is higher than LAND_RIDE_M there).
const LAND_RIDE_M: float = 0.3
var water_share: float = 1.0

func hovering() -> bool:
	return hover_m > 0.0

## 0..1: the body's blaster boost now (0 without one).
func blast() -> float:
	if not is_instance_valid(body): return 0.0
	var boost: Variant = body.get("boost")
	if not boost is RefCounted or not (boost as RefCounted).has_method("blast"): return 0.0
	return float((boost as RefCounted).call("blast"))

## The height of the hull above the swell under it for one speed share and blast.
func hover_height(pace: float, boost_share: float, clock: float) -> float:
	return hover_m + HOVER_SPEED_M * clampf(pace, 0.0, 1.0) + HOVER_BLAST_M * clampf(boost_share, 0.0, 1.0) + 0.12 * sin(clock * 2.3) + 0.05 * sin(clock * 5.1 + 0.7)

func set_visual_load(fraction: float) -> void:
	if is_finite(fraction):
		load_fraction = clampf(fraction, 0.0, 1.0)

func _process(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	elapsed += step
	load_sink_m = move_toward(load_sink_m, load_fraction * FULL_LOAD_SINK_M, step * 0.3)
	var has_ocean: bool = is_instance_valid(ocean)
	var tier: int = ocean.quality if has_ocean else quality
	var clock: float = ocean.elapsed if has_ocean else elapsed
	var strength: float = 0.4 if tier == 0 else 1.0
	var frame: Node3D = body if is_instance_valid(body) else get_parent_node_3d()
	var signed_speed: float = 0.0
	var turn: float = 0.0
	if is_instance_valid(body):
		signed_speed = body.velocity.dot(body.global_basis.z)
		var yaw: float = body.global_rotation.y
		if has_yaw and step > 0.0:
			turn = clampf(angle_difference(last_yaw, yaw) / step / full_turn_rate_rad, -1.0, 1.0)
		last_yaw = yaw
		has_yaw = true
	var blend: float = 1.0 - exp(-step * 2.0)
	speed_fraction = lerpf(speed_fraction, clampf(signed_speed / cruise_speed_mps, -1.0, 1.0), blend)
	var pace: float = absf(speed_fraction)
	# Lean into the turn: the inside rail dips, more at speed.
	lean = lerpf(lean, -turn * (0.35 + 0.65 * pace), blend)
	# Ride the swell: sample it at bow, stern and both sides of the hull.
	var swell_heave: float = 0.0
	var swell_pitch: float = 0.0
	var swell_roll: float = 0.0
	if frame != null and tier > 0:
		var origin: Vector3 = frame.global_position
		var bow: Vector3 = frame.global_basis.z * half_length * 0.7
		var side: Vector3 = frame.global_basis.x * half_width * 2.0
		var h_bow: float = OceanPresentation.swell_height(origin.x + bow.x, origin.z + bow.z, clock, tier)
		var h_stern: float = OceanPresentation.swell_height(origin.x - bow.x, origin.z - bow.z, clock, tier)
		var h_right: float = OceanPresentation.swell_height(origin.x + side.x, origin.z + side.z, clock, tier)
		var h_left: float = OceanPresentation.swell_height(origin.x - side.x, origin.z - side.z, clock, tier)
		swell_heave = (h_bow + h_stern + h_right + h_left) * 0.25
		swell_pitch = -atan2(h_bow - h_stern, half_length * 1.4) * SWELL_TILT_GAIN * pitch_scale
		swell_roll = atan2(h_right - h_left, half_width * 4.0) * SWELL_TILT_GAIN * roll_scale
	# Idle rocking, plus a faster chop and a lifted bow that grow with speed.
	heave_m = swell_heave + (sin(clock * 0.65) * 0.14 + sin(clock * 1.9 + 1.1) * 0.2 * pace) * strength
	var pitch: float = swell_pitch + (sin(clock * 0.55) * deg_to_rad(0.5) + sin(clock * 1.9) * deg_to_rad(1.4) * pace - SPEED_TRIM_RAD * speed_fraction) * strength * pitch_scale
	var roll: float = swell_roll + (sin(clock * 0.73 + 0.8) * deg_to_rad(1.2) * (1.0 + 1.5 * pace) * strength + lean * TURN_LEAN_RAD) * roll_scale
	heave_m = clampf(heave_m, -MAX_HEAVE_M, MAX_HEAVE_M)
	if hovering():
		# Patch 4.0.2: a hover hull floats over the water, never touches it.
		var share: float = blast()
		plane = smoothstep(0.15, 0.6, speed_fraction) if plane_trim_rad > 0.0 else 0.0
		# Patch 4.0.7 item 4: over land (the body rides the ground's height)
		# there is no swell to follow; it fades back in over the water.
		var wet: float = 1.0 if frame == null or frame.global_position.y < LAND_RIDE_M else 0.0
		water_share = move_toward(water_share, wet, step * 2.0)
		swell_heave *= water_share
		swell_pitch *= water_share
		swell_roll *= water_share
		heave_m = swell_heave * HOVER_SWELL_SHARE + hover_height(pace, share, clock)
		position.y = heave_m - load_sink_m * 0.2
		var float_pitch: float = swell_pitch * HOVER_SWELL_SHARE + sin(clock * 1.7) * deg_to_rad(0.6) - plane_trim_rad * 0.6 * plane - deg_to_rad(2.5) * share
		var float_roll: float = swell_roll * HOVER_SWELL_SHARE + sin(clock * 1.3 + 0.4) * deg_to_rad(0.8) + lean * TURN_LEAN_RAD * 1.8
		rotation.x = clampf(float_pitch, -HOVER_PITCH_LIMIT_RAD, HOVER_PITCH_LIMIT_RAD)
		rotation.z = clampf(float_roll, -HOVER_ROLL_LIMIT_RAD, HOVER_ROLL_LIMIT_RAD)
		return
	plane =smoothstep(0.15, 0.6, speed_fraction) if plane_trim_rad > 0.0 else 0.0
	pitch -= plane_trim_rad * plane
	var plane_lift: float = sin(plane_trim_rad * plane) * half_length * 0.45
	if jump_lift > 0.0 and step > 0.0:
		pitch = planing(step, swell_heave, signed_speed, pitch, strength)
		position.y = jump_y + land_dip - load_sink_m + plane_lift
	else:
		position.y = heave_m - load_sink_m + plane_lift
	rotation.x = clampf(pitch, -pitch_limit_rad, pitch_limit_rad)
	rotation.z = clampf(roll, -roll_limit_rad, roll_limit_rad)

## Patch 2.4 item 8: one step of a planing hull over the swell and the chop.
## Returns the pitch to show. Sets jump_y (the hull's height) and land_dip.
func planing(step: float, swell: float, signed_speed: float, pitch: float, strength: float) -> float:
	var speed: float = absf(signed_speed)
	var pace: float = clampf(speed / top_speed_mps, 0.0, 1.0)
	travel_m += minf(speed, CHOP_PACE_LIMIT_MPS) * step
	# Chop only lifts: 0 in a trough, its full height on a crest, and it grows
	# with speed. Two lengths so the jumps do not come like clockwork.
	var phase: float = travel_m * CHOP_PER_M
	var chop: float = chop_height_m * pace * pace * strength * (0.5 + 0.32 * sin(phase) + 0.18 * sin(phase * 1.53 + 1.7))
	var slope: float = chop_height_m * pace * pace * strength * CHOP_PER_M * (0.32 * cos(phase) + 0.18 * 1.53 * cos(phase * 1.53 + 1.7))
	var surface: float = swell + chop
	var rise: float = (surface - last_surface) / step if has_surface else 0.0
	last_surface = surface
	has_surface = true
	# The touch-down dip is a stiff, critically damped spring: it sinks the hull
	# a little and brings it back up smoothly, never with a snap or a bounce.
	land_dip_vy -= (land_dip * 64.0 + land_dip_vy * 16.0) * step
	land_dip += land_dip_vy * step
	settle = maxf(settle - step, 0.0)
	var push: float = rise * jump_lift
	if airborne:
		air_time += step
		jump_vy -= JUMP_GRAVITY_MPS2 * step
		jump_y += jump_vy * step
		if jump_y <= surface:
			# Touch down: back on the water with a soft dip, no bounce.
			var impact: float = -jump_vy
			airborne = false
			longest_air_s = maxf(longest_air_s, air_time)
			jump_y = surface
			jump_vy = rise
			settle = SETTLE_S
			land_dip_vy = -clampf(impact * 0.6, 0.0, 4.5)
			landed.emit(clampf(impact / 6.0, 0.0, 1.0))
	else:
		var ballistic: float = jump_vy - JUMP_GRAVITY_MPS2 * step
		if settle <= 0.0 and jump_vy > MIN_LAUNCH_MPS and ballistic > maxf(push, rise) and speed > 2.0:
			# The water falls away faster than gravity: the hull flies.
			airborne = true
			air_time = 0.0
			jump_vy = ballistic
			jump_y += jump_vy * step
		else:
			jump_vy = maxf(push, rise)
			jump_y = surface
	# In the air the bow follows the arc; on the water it climbs the chop.
	var target: float = pitch
	if airborne: target = -atan2(jump_vy, maxf(speed, 4.0)) * 0.7 - deg_to_rad(2.0) * pace
	else: target = pitch - atan(slope * jump_lift) * 0.8
	jump_pitch = lerpf(jump_pitch, target, 1.0 - exp(-step * (5.0 if airborne else 9.0)))
	return jump_pitch
