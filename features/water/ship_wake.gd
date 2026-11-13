class_name ShipWake
extends MeshInstance3D
## World-space presentation; never writes to the navigation body.
## Draws the hull foam ring, the bow wave and spray, and a long V wake with
## swirls that stays behind in the water and fades (Patch 2.0 sailing feel).
const FOAM_SHADER = preload("res://features/water/ship_foam.gdshader")
const LIFETIME: float = 14.0
const MAX_SAMPLES: int = 40
const SPRAY_SPEED_FRACTION: float = 0.3
var ship: CharacterBody3D
var ocean: OceanPresentation
var half_length: float = 30.0
var half_width: float = 6.5
var samples: Array[Dictionary] = []
var clock: float = 0.0
var serial: int = 0
var last_position: Vector3
var has_position: bool = false
var strength: float = 0.0
var surface: ImmediateMesh = ImmediateMesh.new()
var foam: ShaderMaterial
var spray: CPUParticles3D
var spray_material: StandardMaterial3D
var drawing: bool = false

func _ready() -> void:
	mesh = surface
	foam = ShaderMaterial.new()
	foam.shader = FOAM_SHADER
	material_override = foam
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 1.0
	build_spray()

## Chunky white blobs thrown up at the bow; flat colour to match the toon foam.
func build_spray() -> void:
	spray_material = StandardMaterial3D.new()
	spray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var blob: SphereMesh = SphereMesh.new()
	blob.radius = 0.5
	blob.height = 1.0
	blob.radial_segments = 6
	blob.rings = 3
	blob.material = spray_material
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0.0, 0.6))
	shrink.add_point(Vector2(0.25, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	spray = CPUParticles3D.new()
	spray.name = "BowSpray"
	spray.mesh = blob
	spray.amount = 28
	spray.lifetime = 1.2
	spray.local_coords = false
	spray.emitting = false
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.direction = Vector3.UP
	spray.spread = 50.0
	spray.gravity = Vector3(0, -11, 0)
	spray.scale_amount_min = 0.6
	spray.scale_amount_max = 1.4
	spray.scale_amount_curve = shrink
	add_child(spray)

func _process(delta: float) -> void:
	if not is_instance_valid(ship) or not is_instance_valid(ocean): return
	advance(delta)
	draw_foam()
	update_spray()

func travel_sign() -> float:
	return 1.0 if ship.velocity.dot(ship.global_basis.z) >= 0.0 else -1.0

func advance(delta: float) -> void:
	var position_now: Vector3 = ship.global_position
	if has_position and position_now.distance_to(last_position) > 50.0:
		samples.clear()
		clock = 0.0
	last_position = position_now
	has_position = true
	for sample: Dictionary in samples: sample.age += delta
	while not samples.is_empty() and samples[0].age >= LIFETIME: samples.pop_front()
	var speed: float = Vector2(ship.velocity.x, ship.velocity.z).length()
	strength = clampf(speed / 8.0, 0.0, 1.0)
	clock += delta
	var interval: float = 0.55 if ocean.quality == 0 else 0.35
	if speed > 0.15 and clock >= interval:
		clock = 0.0
		serial += 1
		var direction: Vector3 = ship.velocity.normalized()
		samples.append({"center": trailing_point(direction), "direction": direction, "age": 0.0, "power": strength, "serial": serial})
		if samples.size() > MAX_SAMPLES: samples.pop_front()

## The point on the hull outline that the water leaves last.
func trailing_point(direction: Vector3) -> Vector3:
	var bow: Vector3 = ship.global_basis.z
	var across: Vector3 = ship.global_basis.x
	var trailing_extent: float = 1.0 / maxf(absf(direction.dot(bow)) / half_length, absf(direction.dot(across)) / half_width)
	return ship.global_position - direction * trailing_extent

## One cross-section of the wake: the churned middle and the two V arms.
func section(sample: Dictionary) -> Dictionary:
	var life: float = clampf(sample.age / LIFETIME, 0.0, 1.0)
	var power: float = sample.power
	var number: float = float(sample.serial)
	var direction: Vector3 = sample.direction
	var across: Vector3 = Vector3(direction.z, 0, -direction.x)
	var spread: float = half_width * 0.9 + sample.age * (1.0 + 1.3 * power)
	var sway: float = 0.3 + life * 2.2
	var center: Vector3 = sample.center + across * sin(number * 1.1) * life * 2.5
	return {
		"fade": pow(1.0 - life, 1.5) * (0.3 + power * 0.7),
		"center": center,
		"churn": half_width * (0.5 + power * 0.9) * (1.0 - life) * (0.8 + 0.2 * sin(number * 2.3)),
		"left": sample.center - across * (spread + sin(number * 1.7 + ocean.elapsed * 0.5) * sway),
		"right": sample.center + across * (spread + sin(number * 1.3 + 2.0 - ocean.elapsed * 0.5) * sway),
		"inner_left": sample.center - across * (spread * 0.55 + cos(number * 1.9) * sway),
		"inner_right": sample.center + across * (spread * 0.55 + cos(number * 1.5 + 1.0) * sway),
		# The lines pinch shut now and then, so they read as tapered brush strokes.
		"arm": (0.5 + power * 1.5) * (1.0 - 0.5 * life) * clampf(0.5 + 0.8 * sin(number * 0.8), 0.0, 1.0),
		"inner": (0.3 + power * 0.9) * (1.0 - life) * clampf(0.3 + 0.9 * sin(number * 1.3 + 1.0), 0.0, 1.0),
	}

func draw_foam() -> void:
	surface.clear_surfaces()
	foam.set_shader_parameter("water_time", ocean.elapsed)
	foam.set_shader_parameter("quality", ocean.quality)
	foam.set_shader_parameter("foam_color", ocean.palette.foam_color)
	if samples.is_empty() and strength < 0.01: return
	drawing = false
	var previous: Dictionary = {}
	for sample: Dictionary in samples:
		var current: Dictionary = section(sample)
		if not previous.is_empty(): join(previous, current)
		previous = current
		if sample.serial % 3 == 0 and ocean.quality > 0: swirl(sample, current)
	if strength > 0.01:
		# Tie the newest part of the trail to the hull so no gap opens behind the stern.
		if not previous.is_empty():
			var direction: Vector3 = ship.velocity.normalized()
			join(previous, section({"center": trailing_point(direction), "direction": direction, "age": 0.0, "power": strength, "serial": serial + 1}))
		hull_ring()
		bow_wave()
	if drawing: surface.surface_end()

func join(a: Dictionary, b: Dictionary) -> void:
	var gap: float = a.center.distance_to(b.center)
	if gap <= 0.05 or gap >= 20.0: return
	strip(a.center, b.center, a.churn, b.churn, a.fade, b.fade)
	for key: String in ["left", "right"]:
		strip(a[key], b[key], a.arm, b.arm, a.fade, b.fade)
	for key: String in ["inner_left", "inner_right"]:
		strip(a[key], b[key], a.inner, b.inner, a.fade * 0.8, b.fade * 0.8)

## A curl of foam left in the churned water. It opens up slowly as it ages.
func swirl(sample: Dictionary, current: Dictionary) -> void:
	var age: float = sample.age
	var grown: float = smoothstep(0.8, 2.5, age)
	if grown <= 0.0: return
	var life: float = clampf(age / LIFETIME, 0.0, 1.0)
	var number: int = sample.serial / 3
	var side: float = 1.0 if number % 2 == 0 else -1.0
	var direction: Vector3 = sample.direction
	var across: Vector3 = Vector3(direction.z, 0, -direction.x)
	var middle: Vector3 = current.center + across * side * (half_width * 0.5 + age * 0.45)
	var radius: float = (1.5 + life * 5.0) * (0.6 + sample.power * 0.6)
	var start: float = float(number) * 2.1 + side * age * 0.3
	var last: Vector3
	for part: int in range(10):
		var t: float = float(part) / 9.0
		var angle: float = start + side * t * TAU * 0.85
		var point: Vector3 = middle + (across * cos(angle) + direction * sin(angle)) * radius * (1.0 - 0.75 * t)
		if part > 0:
			var t0: float = float(part - 1) / 9.0
			strip(last, point, (1.0 - t0) * (0.5 + sample.power), (1.0 - t) * (0.5 + sample.power), current.fade * grown, current.fade * grown)
		last = point

## Foam hugging the waterline all the way round, thicker and livelier at speed.
func hull_ring() -> void:
	var bow: Vector3 = ship.global_basis.z
	var across: Vector3 = ship.global_basis.x
	var center: Vector3 = ship.global_position
	var forward: float = travel_sign()
	var parts: int = 20 if ocean.quality == 0 else 36
	var last: Vector3
	var last_width: float = 0.0
	for part: int in range(parts + 1):
		var angle: float = TAU * float(part) / float(parts)
		var c: float = cos(angle)
		var s: float = sin(angle)
		# Rounded box, so the ring follows a ship-shaped outline, not an ellipse.
		var point: Vector3 = center + across * signf(c) * sqrt(absf(c)) * (half_width + 0.6) + bow * signf(s) * sqrt(absf(s)) * (half_length + 0.6)
		var lead: float = maxf(s * forward, 0.0)
		var width: float = (0.5 + strength * 1.4) * (0.7 + 0.3 * sin(angle * 9.0 + ocean.elapsed * 3.0)) + strength * 1.6 * lead * lead
		if part > 0: strip(last, point, last_width, width, 0.3 + strength * 0.65, 0.3 + strength * 0.65)
		last = point
		last_width = width

## Two white curls peeling off the bow and sweeping back along the hull.
func bow_wave() -> void:
	if strength < 0.12: return
	var bow: Vector3 = ship.global_basis.z * travel_sign()
	var across: Vector3 = ship.global_basis.x
	var tip: Vector3 = ship.global_position + bow * (half_length + 1.5 + strength * 2.0)
	var pulse: float = 0.85 + 0.15 * sin(ocean.elapsed * 5.0)
	for side: float in [-1.0, 1.0]:
		var last: Vector3 = tip
		for part: int in range(1, 8):
			var t: float = float(part) / 7.0
			var point: Vector3 = tip + across * side * t * (half_width * 1.5 + strength * 5.0) - bow * t * t * half_length * (0.45 + strength * 0.35)
			var t0: float = float(part - 1) / 7.0
			strip(last, point, (0.4 + (1.0 - t0) * strength * 3.2) * pulse, (0.4 + (1.0 - t) * strength * 3.2) * pulse, 0.9 * strength * (1.0 - t0 * 0.7), 0.9 * strength * (1.0 - t * 0.7))
			last = point

func update_spray() -> void:
	var bow: Vector3 = ship.global_basis.z * travel_sign()
	var tip: Vector3 = ship.global_position + bow * (half_length - 1.0)
	tip.y = ocean.global_position.y + OceanPresentation.swell_height(tip.x, tip.z, ocean.elapsed, ocean.quality) + 0.4
	spray.global_position = tip
	spray.global_basis = Basis.looking_at(-bow, Vector3.UP)
	spray.emission_box_extents = Vector3(half_width * 0.7, 0.2, 2.0)
	spray.initial_velocity_min = 2.0 + strength * 3.0
	spray.initial_velocity_max = 4.0 + strength * 6.0
	spray_material.albedo_color = ocean.palette.foam_color
	spray.emitting = strength >= SPRAY_SPEED_FRACTION

## A flat ribbon from a to b whose width and opacity can differ at each end.
func strip(a: Vector3, b: Vector3, width_a: float, width_b: float, opacity_a: float, opacity_b: float) -> void:
	if width_a <= 0.01 and width_b <= 0.01: return
	# The surface opens on the first ribbon; an empty surface is an engine error.
	if not drawing:
		surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		drawing = true
	var direction: Vector3 = (b - a).normalized()
	var side: Vector3 = Vector3(direction.z, 0, -direction.x) * 0.5
	var corners: Array[Vector3] = [a - side * width_a, a + side * width_a, b + side * width_b, b - side * width_b]
	var opacities: Array[float] = [opacity_a, opacity_a, opacity_b, opacity_b]
	for corner: int in [0, 1, 2, 0, 2, 3]:
		var point: Vector3 = corners[corner]
		point.y = ocean.global_position.y + 0.12
		surface.surface_set_color(Color(1, 1, 1, opacities[corner]))
		surface.surface_add_vertex(to_local(point))
