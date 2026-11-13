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
var cruise_speed_mps: float = 8.0
var full_turn_rate_rad: float = deg_to_rad(3.0)
var speed_fraction: float = 0.0
var lean: float = 0.0
var heave_m: float = 0.0
var last_yaw: float = 0.0
var has_yaw: bool = false

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
		swell_pitch = -atan2(h_bow - h_stern, half_length * 1.4) * SWELL_TILT_GAIN
		swell_roll = atan2(h_right - h_left, half_width * 4.0) * SWELL_TILT_GAIN
	# Idle rocking, plus a faster chop and a lifted bow that grow with speed.
	heave_m = swell_heave + (sin(clock * 0.65) * 0.14 + sin(clock * 1.9 + 1.1) * 0.3 * pace) * strength
	var pitch: float = swell_pitch + (sin(clock * 0.55) * deg_to_rad(0.5) + sin(clock * 1.9) * deg_to_rad(1.4) * pace - deg_to_rad(1.2) * speed_fraction) * strength
	var roll: float = swell_roll + sin(clock * 0.73 + 0.8) * deg_to_rad(1.2) * (1.0 + 1.5 * pace) * strength + lean * TURN_LEAN_RAD
	heave_m = clampf(heave_m, -MAX_HEAVE_M, MAX_HEAVE_M)
	position.y = heave_m - load_sink_m
	rotation.x = clampf(pitch, -MAX_PITCH_RAD, MAX_PITCH_RAD)
	rotation.z = clampf(roll, -MAX_ROLL_RAD, MAX_ROLL_RAD)
