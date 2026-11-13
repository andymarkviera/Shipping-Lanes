class_name OrbitCameraRig
extends Node3D
const Focus = preload("res://features/camera/camera_focus.gd")
var focus: CameraFocus
var controls: PlayerControls
var camera: Camera3D
var orbiting: bool = false
var orbit_offset: float = 0.0
var pitch_order: float = 0.45
var distance_order: float = 115.0
var pivot: Vector3
var yaw: float = PI
var pitch: float = 0.45
var distance: float = 115.0
var arm_length: float = 115.0
var initialized: bool = false
var probe: SphereShape3D = SphereShape3D.new()
const SMOOTHING: float = 5.0
const MIN_PITCH: float = 0.12
const MAX_PITCH: float = 1.25

func _ready() -> void:
	probe.radius = 0.75
	camera = Camera3D.new()
	camera.near = 0.2
	camera.far = 3000.0
	add_child(camera)
	camera.current = true

func bind_controls(source: PlayerControls) -> void:
	if is_instance_valid(controls):
		controls.camera_motion_requested.disconnect(orbit)
		controls.command_requested.disconnect(command)
	release_mouse()
	controls = source
	controls.camera_motion_requested.connect(orbit)
	controls.command_requested.connect(command)

func set_focus(target: CameraFocus) -> void:
	focus = target
	if not is_instance_valid(focus): return
	distance_order = clampf(distance_order, minimum_distance(), maximum_distance())
	# Only the first focus initializes immediately. Subsequent targets blend.
	if not initialized:
		pivot = focus.global_position
		yaw = behind_heading()
		distance = distance_order
		arm_length = distance_order
		initialized = true

## Moves the view by a fixed step with no smoothing (the world wrapped round).
func shift(by: Vector3) -> void:
	pivot += by
	camera.global_position += by

func minimum_distance() -> float:
	return maxf(8.0, focus.hull_radius * 1.3)

func maximum_distance() -> float:
	return maxf(60.0, focus.hull_radius * 8.0)

func behind_heading() -> float:
	var bow: Vector3 = focus.global_basis.z
	return atan2(bow.x, bow.z) + PI

func command(action: StringName) -> void:
	if not is_instance_valid(controls) or not controls.input_allowed(): return
	match action:
		&"camera_orbit":
			orbiting = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		&"camera_zoom_in": zoom(-1.0)
		&"camera_zoom_out": zoom(1.0)
		&"camera_recenter":
			orbit_offset = 0.0
			pitch_order = 0.45

func zoom(direction: float) -> void:
	if is_instance_valid(focus) and is_finite(direction):
		distance_order = clampf(distance_order * exp(clampf(direction, -1.0, 1.0) * 0.12), minimum_distance(), maximum_distance())

func orbit(motion: Vector2) -> void:
	if not orbiting or not is_instance_valid(controls) or not controls.input_allowed(): return
	orbit_offset = wrapf(orbit_offset - motion.x * 0.005, -PI, PI)
	pitch_order = clampf(pitch_order + motion.y * 0.005, MIN_PITCH, MAX_PITCH)

func release_mouse() -> void:
	if orbiting:
		orbiting = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		release_mouse()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release_mouse()

func _exit_tree() -> void:
	release_mouse()

func _process(_delta: float) -> void:
	if orbiting and (not is_instance_valid(controls) or not controls.input_allowed() or not Input.is_action_pressed("camera_orbit")):
		release_mouse()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(focus):
		release_mouse()
		return
	var blend: float = 1.0 - exp(-SMOOTHING * delta)
	pivot = pivot.lerp(focus.global_position, blend)
	yaw = lerp_angle(yaw, behind_heading() + orbit_offset, blend)
	pitch = lerpf(pitch, pitch_order, blend)
	distance = lerpf(distance, distance_order, blend)
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = CollisionRules.SOLID_WATERCRAFT
	query.transform = Transform3D(Basis.IDENTITY, pivot)
	query.exclude = focus.excluded_bodies()
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	# A target-switch path can pass through geometry. Preserve the previous view
	# until the interpolated focus exits, instead of casting from inside a pier.
	if not space.intersect_shape(query, 1).is_empty(): return
	query.motion = offset
	var fractions: PackedFloat32Array = space.cast_motion(query)
	var safe_fraction: float = fractions[0] if not fractions.is_empty() else 1.0
	var safe_distance: float = maxf(0.01, offset.length() * safe_fraction - 0.1)
	arm_length = safe_distance if safe_distance < arm_length else lerpf(arm_length, safe_distance, blend)
	camera.global_position = pivot + offset.normalized() * arm_length
	camera.look_at(pivot, Vector3.UP)
