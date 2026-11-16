extends Node
## Patch 2.9.1 item 3: living sails, rigging and flags for one pirate ship.
## Sails unfurl when the helm asks for way and furl once the ship has stopped,
## fill and flutter with speed (and back when going astern); flags and pennants
## stream; cloth and ropes swing behind the hull's roll. Looks only.
##
## Frame time: the shaders move the vertices. This node only sets four numbers
## on three materials each frame. The meshes stay shared; each ship has its own
## materials, so the hangar's ship (no hull motion above it) keeps its sails set.
const CLOTH_SHADER: Shader = preload("res://features/toon/pirate_cloth.gdshader")
const CLOTH_OUTLINE_SHADER: Shader = preload("res://features/toon/pirate_cloth_outline.gdshader")
const FLAG_SHADER: Shader = preload("res://features/toon/pirate_flag.gdshader")
const UNFURL_S: float = 4.0
const FURL_S: float = 6.0
## Below this share of top speed, with the throttle at zero, the sails come in.
const FURL_BELOW_PACE: float = 0.1
## Swing of the cloth per radian of roll, and the most it may reach.
const SWING_PER_RAD: float = 6.0
const MAX_SWING: float = 1.6
var motion: ShipVisualMotion
var sails: ShaderMaterial = ShaderMaterial.new()
var sail_ink: ShaderMaterial = ShaderMaterial.new()
var ropes: ShaderMaterial = ShaderMaterial.new()
var flags: ShaderMaterial = ShaderMaterial.new()
## 0 furled, 1 set.
var sail_set: float = 1.0
## Share of top speed, signed.
var fill: float = 0.82
var stream: float = 1.0
var flow: float = 0.0
var swing: float = 0.0
var swing_speed: float = 0.0

## Gives the model's Sails, Rigging and Flags their own moving materials.
func fit(model: Node3D) -> void:
	sails.shader = CLOTH_SHADER
	sail_ink.shader = CLOTH_OUTLINE_SHADER
	sails.next_pass = sail_ink
	ropes.shader = CLOTH_SHADER
	flags.shader = FLAG_SHADER
	var looks: Dictionary = {"Sails": sails, "Rigging": ropes, "Flags": flags}
	for label: String in looks:
		var node: MeshInstance3D = model.get_node(label) as MeshInstance3D
		node.material_override = looks[label]
		# The shaders move the cloth: keep it from being culled early.
		node.extra_cull_margin = 3.0

func _ready() -> void:
	var above: Node = get_parent()
	while above != null and not above is ShipVisualMotion: above = above.get_parent()
	motion = above as ShipVisualMotion
	set_process(motion != null)
	# A ship at sea starts with her sails furled; advance() sets them if she has way on.
	if motion != null: sail_set = 0.0
	show_state()

func _process(delta: float) -> void:
	advance(delta)
	show_state()

func advance(delta: float) -> void:
	var step: float = clampf(delta, 0.0, 0.05)
	var body: CharacterBody3D = motion.body
	var signed_pace: float = 0.0
	var order: float = 0.0
	if is_instance_valid(body):
		signed_pace = clampf(body.velocity.dot(body.global_basis.z) / motion.top_speed_mps, -1.0, 1.0)
		if "commanded_throttle" in body: order = absf(float(body.get("commanded_throttle")))
	var pace: float = absf(signed_pace)
	var wanted: bool = order > 0.02 or pace > FURL_BELOW_PACE
	sail_set = move_toward(sail_set, 1.0 if wanted else 0.0, step / (UNFURL_S if wanted else FURL_S))
	var blend: float = 1.0 - exp(-step * 1.5)
	fill = lerpf(fill, signed_pace, blend)
	stream = lerpf(stream, 0.15 + 0.85 * pace, blend)
	flow = fmod(flow + step * 1.6 * pace, TAU * 100.0)
	# Cloth and rope hang toward the low side and lag behind the roll.
	var target: float = -sin(motion.rotation.z) * SWING_PER_RAD
	swing_speed += ((target - swing) * 6.0 - swing_speed * 2.2) * step
	swing = clampf(swing + swing_speed * step, -MAX_SWING, MAX_SWING)

func show_state() -> void:
	for material: ShaderMaterial in [sails, sail_ink, ropes]:
		material.set_shader_parameter("fill", fill)
		material.set_shader_parameter("swing", swing)
		material.set_shader_parameter("flow", flow)
	sails.set_shader_parameter("sail_set", sail_set)
	sail_ink.set_shader_parameter("sail_set", sail_set)
	flags.set_shader_parameter("stream", stream)
	flags.set_shader_parameter("flow", flow)
