extends Node3D
## Patch 4.0 item 4: a toon jet flame out of a nozzle, pointing along -Z. Three
## nested cones in flat bands (white-hot core, yellow, orange rim), in the
## game's Wind Waker look: unshaded, so toon_look leaves them alone, with a
## short flicker. The flame grows with the engine: it reads `actual_throttle`
## from the first ancestor that has one (the Jetty's hull), or `power` when
## nothing above it does (the hangar model, a plane's engine). Looks only.
const BANDS: Array = [[Color("ff8a2a"), 1.0], [Color("ffd23f"), 0.72], [Color("fff6d8"), 0.42]]
const LENGTH_M: float = 5.5
const RADIUS_M: float = 0.5
var power: float = 0.15
var source: Node
var cones: Array[MeshInstance3D] = []
var clock: float = 0.0
var shown: float = 0.0

func _ready() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.get("actual_throttle") != null:
			source = node
			break
		node = node.get_parent()
	for band: Array in BANDS:
		var mesh: CylinderMesh = CylinderMesh.new()
		# Wide at the nozzle (the cylinder's bottom), a point at the far end.
		mesh.top_radius = 0.0
		mesh.bottom_radius = RADIUS_M * float(band[1])
		mesh.height = 1.0
		mesh.radial_segments = 8
		mesh.rings = 1
		var paint: StandardMaterial3D = StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_color = band[0]
		var cone: MeshInstance3D = MeshInstance3D.new()
		cone.mesh = mesh
		cone.material_override = paint
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation.x = -PI / 2.0
		add_child(cone)
		cones.append(cone)
	update_shape(0.0)

## 0..1 throttle to show; reversing shows only the idle flicker.
func throttle() -> float:
	if is_instance_valid(source): return clampf(float(source.get("actual_throttle")), 0.0, 1.0)
	return clampf(power, 0.0, 1.0)

func _process(delta: float) -> void:
	update_shape(delta)

func update_shape(delta: float) -> void:
	clock += delta
	shown = lerpf(shown, throttle(), 1.0 - exp(-delta * 8.0))
	var length: float = LENGTH_M * (0.12 + 0.88 * shown)
	for index: int in cones.size():
		var band: float = float(BANDS[index][1])
		var flicker: float = 1.0 + 0.08 * sin(clock * (31.0 + index * 7.0)) + 0.05 * sin(clock * 53.0 + index)
		var cone_length: float = length * band * flicker
		var cone: MeshInstance3D = cones[index]
		cone.scale = Vector3(0.6 + 0.4 * shown, cone_length, 0.6 + 0.4 * shown)
		cone.position = Vector3(0, 0, -cone_length * 0.5)
	visible = shown > 0.02 or not is_instance_valid(source)
