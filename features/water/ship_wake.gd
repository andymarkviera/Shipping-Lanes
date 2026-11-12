class_name ShipWake
extends MeshInstance3D
## World-space presentation; never writes to the navigation body.
const FOAM_SHADER = preload("res://features/water/ship_foam.gdshader")
const LIFETIME: float = 8.0
const MAX_SAMPLES: int = 40
var ship: CharacterBody3D
var ocean: OceanPresentation
var half_length: float = 30.0
var half_width: float = 6.5
var samples: Array[Dictionary] = []
var clock: float = 0.0
var last_position: Vector3
var has_position: bool = false
var strength: float = 0.0
var surface: ImmediateMesh = ImmediateMesh.new()
var foam: ShaderMaterial

func _ready() -> void:
	mesh = surface
	foam = ShaderMaterial.new()
	foam.shader = FOAM_SHADER
	material_override = foam
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 1.0

func _process(delta: float) -> void:
	if not is_instance_valid(ship) or not is_instance_valid(ocean): return
	advance(delta)
	draw_foam()

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
		var direction: Vector3 = ship.velocity.normalized()
		var bow: Vector3 = ship.global_basis.z
		var across: Vector3 = ship.global_basis.x
		var trailing_extent: float = 1.0 / maxf(absf(direction.dot(bow)) / half_length, absf(direction.dot(across)) / half_width)
		var stern: Vector3 = position_now - direction * trailing_extent
		samples.append({"center": stern, "direction": direction, "age": 0.0, "power": strength})
		if samples.size() > MAX_SAMPLES: samples.pop_front()

func draw_foam() -> void:
	surface.clear_surfaces()
	foam.set_shader_parameter("water_time", ocean.elapsed)
	foam.set_shader_parameter("quality", ocean.quality)
	foam.set_shader_parameter("foam_color", ocean.palette.foam_color)
	if samples.is_empty() and strength < 0.01: return
	surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous_center: Vector3
	for index: int in range(samples.size()):
		var sample: Dictionary = samples[index]
		var age: float = sample.age
		var opacity: float = pow(1.0 - age / LIFETIME, 2.0) * (0.25 + sample.power * 0.65)
		var direction: Vector3 = sample.direction
		var across: Vector3 = Vector3(direction.z, 0, -direction.x)
		var center: Vector3 = sample.center - direction * age * 0.6
		# Churned white trail straight behind the stern; it narrows as it ages.
		var gap: float = center.distance_to(previous_center)
		if index > 0 and gap > 0.05 and gap < 20.0:
			ribbon(previous_center, center, half_width * (0.3 + sample.power * 0.7) * (1.0 - age / LIFETIME), opacity)
		previous_center = center
		# Short curved crests spread out and remain behind in world space.
		var radius: float = half_width + age * (1.2 + sample.power)
		for side: float in [-1.0, 1.0]:
			for part: int in range(4):
				var t0: float = float(part) / 4.0
				var t1: float = float(part + 1) / 4.0
				var a: Vector3 = center + across * side * radius * (0.4 + t0 * 0.6) - direction * radius * t0 * t0 * 0.45
				var b: Vector3 = center + across * side * radius * (0.4 + t1 * 0.6) - direction * radius * t1 * t1 * 0.45
				ribbon(a, b, 0.5 + sample.power * 2.0, opacity)
	if strength > 0.01:
		var bow: Vector3 = ship.global_basis.z
		var across: Vector3 = ship.global_basis.x
		var center: Vector3 = ship.global_position
		var travel_sign: float = 1.0 if ship.velocity.dot(bow) >= 0.0 else -1.0
		for side: float in [-1.0, 1.0]:
			for part: int in range(12):
				var z0: float = -half_length + part * (half_length / 6.0)
				var z1: float = z0 + half_length / 6.0 * 0.9
				var pulse: float = 0.85 + 0.15 * sin(ocean.elapsed * 4.0 + part)
				ribbon(center + bow * z0 + across * side * (half_width + 0.5), center + bow * z1 + across * side * (half_width + 0.5), (0.25 + strength * 1.5) * pulse, 0.25 + strength * 0.65)
		for part: int in range(12):
			var angle0: float = PI * float(part) / 12.0
			var angle1: float = PI * float(part + 1) / 12.0
			var a: Vector3 = center + across * cos(angle0) * (half_width + 0.5) + bow * travel_sign * (half_length - 0.5 + sin(angle0) * 4.5)
			var b: Vector3 = center + across * cos(angle1) * (half_width + 0.5) + bow * travel_sign * (half_length - 0.5 + sin(angle1) * 4.5)
			ribbon(a, b, 0.4 + strength * 2.0, 0.3 + strength * 0.65)
	surface.surface_end()

func ribbon(a: Vector3, b: Vector3, width: float, opacity: float) -> void:
	var direction: Vector3 = (b - a).normalized()
	var offset: Vector3 = Vector3(direction.z, 0, -direction.x) * width * 0.5
	for point: Vector3 in [a - offset, a + offset, b + offset, a - offset, b + offset, b - offset]:
		surface.surface_set_color(Color(1, 1, 1, opacity))
		point.y = ocean.global_position.y + 0.08
		surface.surface_add_vertex(to_local(point))
