extends Node3D
## Patch 2.5 item 7: the volcano island (Progression.VOLCANO). Its island is a
## LAND block (solid, a toon coast, on the maps); this adds a chunky toon cone
## on it (solid too), a smoke plume from one pooled emitter and lava that glows
## at night. Night is read from the sun: below the horizon or dimmed well under
## its daytime energy. The plume and glow light switch off past CULL_M.
const Progression = preload("res://features/game/progression.gd")
const ROCK := Color("5b4a45")
const ASH := Color("7b6a62")
const LAVA := Color("ff6a1c")
const SMOKE := Color(0.42, 0.40, 0.40, 0.55)
## Lava emission strength by day and at night.
const GLOW_DAY: float = 0.8
const GLOW_NIGHT: float = 4.0
## The glow light at night (metres of reach, energy).
const LIGHT_RANGE_M: float = 520.0
const LIGHT_NIGHT: float = 6.0
const PUFFS: int = 48
const CULL_M: float = 3200.0

var lava: StandardMaterial3D
var smoke: GPUParticles3D
var glow: OmniLight3D
## 0 = day, 1 = full night. What update() last applied.
var night: float = 0.0
var day_sun_energy: float = 1.15

static func crater_height() -> float:
	return float(Progression.VOLCANO.peak_m)

func _init() -> void:
	name = "Volcano"
	var spot: Vector2 = Progression.VOLCANO.at
	position = Vector3(spot.x, 2, spot.y)
	make()

func make() -> void:
	var peak: float = crater_height()
	var base: float = float(Progression.VOLCANO.base_m)
	var rock: StandardMaterial3D = StandardMaterial3D.new()
	rock.albedo_color = ROCK
	rock.roughness = 1.0
	var ash: StandardMaterial3D = StandardMaterial3D.new()
	ash.albedo_color = ASH
	ash.roughness = 1.0
	# Two few-sided drums: a wide skirt and the steep cone, so the toon outline reads.
	add_part("Skirt", base, base * 0.62, peak * 0.3, peak * 0.15, ash)
	add_part("Cone", base * 0.62, base * 0.16, peak * 0.7, peak * 0.3 + peak * 0.35, rock)
	lava = StandardMaterial3D.new()
	lava.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lava.albedo_color = LAVA
	lava.emission_enabled = true
	lava.emission = LAVA
	lava.emission_energy_multiplier = GLOW_DAY
	# Custom-looking (unshaded) materials keep their own paint under the toon pass.
	var crater: MeshInstance3D = MeshInstance3D.new()
	crater.name = "Lava"
	var pool: CylinderMesh = CylinderMesh.new()
	pool.top_radius = base * 0.13
	pool.bottom_radius = base * 0.13
	pool.height = 2.0
	pool.radial_segments = 10
	pool.rings = 1
	crater.mesh = pool
	crater.material_override = lava
	crater.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crater.position.y = peak - 1.0
	add_child(crater)
	# Three lava runs down the slope.
	for run: int in 3:
		var flow: MeshInstance3D = MeshInstance3D.new()
		flow.name = "LavaRun%d" % run
		var strip: BoxMesh = BoxMesh.new()
		strip.size = Vector3(7, 2, base * 0.5)
		flow.mesh = strip
		flow.material_override = lava
		flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var turn: float = TAU * (0.1 + run * 0.37)
		var slope: float = atan2(peak * 0.7, base * 0.46)
		flow.rotation = Vector3(0, turn, 0)
		flow.position = Vector3(sin(turn), 0, cos(turn)) * base * 0.38 + Vector3(0, peak * 0.62, 0)
		flow.rotate_object_local(Vector3.RIGHT, slope)
		add_child(flow)
	# The cone is solid, like the island under it.
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ConeBody"
	body.collision_layer = CollisionRules.SHORE
	body.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = base * 0.62
	shape.height = peak
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = peak / 2.0
	body.add_child(collider)
	add_child(body)
	build_smoke(peak, base)
	glow = OmniLight3D.new()
	glow.name = "LavaGlow"
	glow.light_color = LAVA
	glow.omni_range = LIGHT_RANGE_M
	glow.light_energy = 0.0
	glow.shadow_enabled = false
	glow.visible = false
	glow.position.y = peak + 20.0
	add_child(glow)

func add_part(part: String, bottom: float, top: float, height: float, centre: float, paint: Material) -> void:
	var drum: CylinderMesh = CylinderMesh.new()
	drum.bottom_radius = bottom
	drum.top_radius = top
	drum.height = height
	drum.radial_segments = 9
	drum.rings = 1
	drum.material = paint
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = part
	mesh.mesh = drum
	mesh.position.y = centre
	add_child(mesh)

## One pooled emitter: a slow plume of big soft puffs that drift downwind.
func build_smoke(peak: float, base: float) -> void:
	smoke = GPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = PUFFS
	smoke.lifetime = 16.0
	smoke.preprocess = 16.0
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.visibility_aabb = AABB(Vector3(-300, -20, -300), Vector3(900, 700, 600))
	smoke.position.y = peak + 4.0
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = base * 0.1
	process.direction = Vector3(0.15, 1, 0)
	process.spread = 12.0
	process.initial_velocity_min = 14.0
	process.initial_velocity_max = 20.0
	process.gravity = Vector3(2.5, 0.5, 0.6)
	process.damping_min = 0.4
	process.damping_max = 0.6
	process.scale_min = 0.6
	process.scale_max = 1.0
	var grow: Curve = Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.4))
	var grow_texture: CurveTexture = CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var fade_texture: GradientTexture1D = GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	smoke.process_material = process
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 26.0
	puff.height = 44.0
	puff.radial_segments = 8
	puff.rings = 4
	var look: StandardMaterial3D = StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.vertex_color_use_as_albedo = true
	look.albedo_color = SMOKE
	puff.material = look
	smoke.draw_pass_1 = puff
	add_child(smoke)

## How dark it is, 0..1: the sun below the horizon, or dimmed well under its
## daytime energy. The game has no night yet; this follows the sun when it does.
func darkness(sun: DirectionalLight3D) -> float:
	if sun == null: return 0.0
	var height: float = sun.global_transform.basis.z.y
	var sunk: float = smoothstep(0.15, -0.05, height)
	var dim: float = smoothstep(0.6, 0.2, sun.light_energy / maxf(day_sun_energy, 0.01))
	return maxf(sunk, dim) if sun.visible else 1.0

## Per frame from the game: glow by the dark, cull the plume and light far off.
func update(view: Vector3, sun: DirectionalLight3D) -> void:
	night = darkness(sun)
	lava.emission_energy_multiplier = lerpf(GLOW_DAY, GLOW_NIGHT, night)
	var way: Vector3 = Progression.short_way(global_position - view)
	var near: bool = Vector2(way.x, way.z).length() < CULL_M
	if smoke.emitting != near: smoke.emitting = near
	smoke.visible = near
	glow.light_energy = LIGHT_NIGHT * night
	glow.visible = near and night > 0.01
