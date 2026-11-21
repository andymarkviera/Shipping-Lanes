extends Node3D
## Patch 4.0.2 (Andy's follow-up on #224): the Jetty's hover and blaster looks.
## Built by chunky_look's _dress_jetty next to the rear thruster, which stays
## exactly as it was (the nozzle, its ring and JetFlame).
##
## Hover: "Downwash" is spray blown out flat over the water under the hull,
## "RoosterTail" is a plume thrown up behind the stern that grows with speed,
## and "Glow" is a light pool on the water under the hull (with
## "GlowLight"). They sit on the water level, below the hovering hull
## (ShipVisualMotion lifts the hull; the body stays on the water plane).
##
## Blaster boost (features/ships/jetty_boost.gd, Shift): during the charge a
## "ChargeOrb" grows at the nozzle and a rising whine plays; on the blast a huge
## "BoostFlame" in fast-cycling RGB bands roars out of the nozzle, a "BlastRing"
## shock wave bursts off the stern and the beam-cannon blast plays. Both sounds
## are synthesised here from sine, saw and noise (no recorded audio).
##
## Patch 4.0.7 item 5 (Andy, issue #234): deliberately EXAGGERATED water
## effects, to sell the Jetty as the fastest boat. Client-side looks only:
## nothing here touches the hull's physics.
## - Under the hover: a dark "Depression" in the water, two "Ripple" rings
##   running out from it, and the spray mist ("Downwash").
## - Moving: a tall "RoosterTail" plume several boat-lengths long, a wide
##   V-shaped "WakeTrench" behind the stern, heavy spray sheets off both
##   sides ("SprayLeft", "SprayRight"); all of them scale with speed.
## - Near top speed (the own Jetty only): "SpeedLines" streaking past and a
##   slight camera FOV kick (FOV_KICK_DEG, more in a blast).
## - The blaster: a big white-hot "BoostBurst" and a "BurstLight" flash.
## - Over land (the Jetty hovers over it, JettyLand) the water effects stop
##   and "Dust" kicks up instead: sand-brown dust, or snow over the ice.
## Performance: every emitter is a GPUParticles3D made once per Jetty and
## reused (the blaster burst restarts); their process materials, draw
## meshes and textures come from one shared pool (_pool), made once for all
## Jetties. LOD: by the camera's distance the effects thin out
## (LOD_NEAR_M, LOD_FAR_M) and stop past LOD_FAR_M; other captains' Jetties
## (replicas, "remote_replica") run at REMOTE_SHARE of the particles and
## never touch the camera.
##
## Looks and sound only: it never changes the hull's speed or state. Online,
## the presentation hull runs no physics, so this node moves its boost clock.
const JETTY_BOOST = preload("res://features/ships/jetty_boost.gd")
const JETTY_LAND = preload("res://features/ships/jetty_land.gd")
const SPRAY: Color = Color(0.93, 0.98, 1.0, 0.85)
## Patch 4.0.7 item 3: the under-glow is a cool white (was teal).
const GLOW: Color = Color("cfe6ff")
const FLAME_LENGTH_M: float = 22.0
const FLAME_RADIUS_M: float = 1.35
const FLAME_BANDS: Array = [1.0, 0.72, 0.42]
## Hue turns per second of the blaster flame (fast RGB).
const HUE_RATE: float = 3.2
const RING_S: float = 0.55
const MIX_RATE: int = 22050
## Patch 4.0.7 item 5: the plume and the wake at full speed are this many
## times their size at a crawl; the plume reaches about PLUME_LENGTHS hull
## lengths back at full speed.
const PLUME_LENGTHS: float = 8.0
const WAKE_LENGTHS: float = 9.0
const RIPPLE_S: float = 1.3
const FOV_KICK_DEG: float = 7.0
const FOV_BLAST_DEG: float = 5.0
const BURST_S: float = 0.9
const LOD_NEAR_M: float = 260.0
const LOD_FAR_M: float = 1100.0
const REMOTE_SHARE: float = 0.55
## How often (seconds) the ground under it is looked up (water, land, ice).
const SURFACE_EVERY_S: float = 0.25
const DUST_SAND: Color = Color("c9b48c")
const DUST_SNOW: Color = Color("f2f7fb")
const DUST_ROCK: Color = Color("8a8580")
static var _charge_sound: AudioStreamWAV
static var _blast_sound: AudioStreamWAV
## Patch 4.0.7 item 5: the shared pool of particle materials, meshes and
## textures (made once, for every Jetty).
static var _pool: Dictionary = {}
## Patch 4.0.4 item 1: Jetty effects in the tree. The last one out lets the
## cached sounds (and, Patch 4.0.7, the pool) go (held past exit, Godot
## reported them as leaked).
static var _live: int = 0

## Where the nozzle is in the model (set by _dress_jetty before _ready).
var nozzle: Vector3 = Vector3(0, 1.2, -6.9)
var length_m: float = 12.0
var beam_m: float = 3.0
var ship: Node
var motion: Node3D
var downwash: GPUParticles3D
var rooster: GPUParticles3D
var glow: MeshInstance3D
var glow_paint: StandardMaterial3D
var glow_light: OmniLight3D
var flame: Node3D
var flame_cones: Array[MeshInstance3D] = []
var flame_paints: Array[StandardMaterial3D] = []
var orb: MeshInstance3D
var orb_paint: StandardMaterial3D
var ring: MeshInstance3D
var ring_paint: StandardMaterial3D
var voice: AudioStreamPlayer
var clock: float = 0.0
var last_phase: String = "ready"
var ring_age: float = RING_S
## Patch 4.0.7 item 5: the exaggerated effects (see the header).
var depression: MeshInstance3D
var ripples: Array[MeshInstance3D] = []
var wake: MeshInstance3D
var spray_left: GPUParticles3D
var spray_right: GPUParticles3D
var speed_lines: GPUParticles3D
var burst: GPUParticles3D
var burst_light: OmniLight3D
var dust: GPUParticles3D
## "water", "land", "ice", "rock", "runway" or "airfield": what is under it.
var ground: String = "water"
var ground_age: float = SURFACE_EVERY_S
## 0..1: the share of the particles shown (LOD), and whether this is another
## captain's Jetty.
var detail: float = 1.0
var remote: bool = false
var burst_age: float = BURST_S
var fov_kick: float = 0.0
var kicked_camera: Camera3D
## Counters for the checks.
var charges_heard: int = 0
var blasts_heard: int = 0
var bursts_fired: int = 0

func _enter_tree() -> void:
	_live += 1

func _exit_tree() -> void:
	release_camera()
	_live = maxi(0, _live - 1)
	if _live == 0:
		_charge_sound = null
		_blast_sound = null
		_pool.clear()

func _ready() -> void:
	var node: Node = get_parent()
	while node != null:
		if motion == null and node.has_method("hovering"): motion = node as Node3D
		if ship == null and node.get("boost") is RefCounted and node.get("actual_throttle") != null: ship = node
		node = node.get_parent()
	remote = is_instance_valid(ship) and ship.has_meta("remote_replica")
	if downwash == null: build()
	update_fx(0.0)

func unshaded(colour: Color, additive: bool = false) -> StandardMaterial3D:
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = colour
	if colour.a < 1.0 or additive: paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive: paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	return paint

## Patch 4.0.7 item 5: one shared resource from the pool, made on first use.
static func pooled(key: String, make: Callable) -> Resource:
	if not _pool.has(key): _pool[key] = make.call()
	return _pool[key]

## A soft round puff (radial fade), shared by every spray.
static func puff_texture() -> Texture2D:
	return pooled("puff", func() -> Resource:
		var fade: Gradient = Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		fade.add_point(0.55, Color(1, 1, 1, 0.65))
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = fade
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 64
		texture.height = 64
		return texture) as Texture2D

## A billboard puff quad of one size, in a shared material (vertex colours).
static func puff_mesh(size: float, additive: bool = false) -> QuadMesh:
	return pooled("puff_mesh_%.2f_%s" % [size, additive], func() -> Resource:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(size, size)
		var paint: StandardMaterial3D = StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive: paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		paint.vertex_color_use_as_albedo = true
		paint.albedo_texture = puff_texture()
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = paint
		return quad) as QuadMesh

## A colour ramp from `start` fading out (shared by key).
static func fade_ramp(key: String, start: Color, middle: Color) -> GradientTexture1D:
	return pooled("ramp_" + key, func() -> Resource:
		var fade: Gradient = Gradient.new()
		fade.set_color(0, start)
		fade.set_color(1, Color(middle, 0.0))
		fade.add_point(0.35, middle)
		var texture: GradientTexture1D = GradientTexture1D.new()
		texture.gradient = fade
		return texture) as GradientTexture1D

## A shared process material, built by `setup` once.
static func process(key: String, setup: Callable) -> ParticleProcessMaterial:
	return pooled("process_" + key, func() -> Resource:
		var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
		setup.call(material)
		return material) as ParticleProcessMaterial

func emitter(label: String, amount: int, life: float, material: ParticleProcessMaterial, mesh: Mesh) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = label
	particles.amount = amount
	particles.lifetime = life
	particles.local_coords = true
	particles.process_material = material
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-60, -10, -260), Vector3(120, 120, 300))
	add_child(particles)
	return particles

func build() -> void:
	# Downwash: flat spray mist blown out from under the whole hull.
	downwash = emitter("Downwash", 140, 0.9, process("downwash", func(m: ParticleProcessMaterial) -> void:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(beam_m * 0.5, 0.05, length_m * 0.45)
		m.direction = Vector3(0, 0.25, 0)
		m.spread = 88.0
		m.flatness = 0.85
		m.initial_velocity_min = 5.0
		m.initial_velocity_max = 12.0
		m.gravity = Vector3(0, -6.0, 0)
		m.damping_min = 2.0
		m.damping_max = 4.0
		m.scale_min = 0.8
		m.scale_max = 2.2
		m.color_ramp = fade_ramp("mist", Color(1, 1, 1, 0.8), Color(0.9, 0.96, 1.0, 0.5))), puff_mesh(1.8))
	# Rooster tail: a tall plume up and back behind the stern (scaled by speed).
	rooster = emitter("RoosterTail", 420, 1.5, process("rooster", func(m: ParticleProcessMaterial) -> void:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = 0.5
		m.direction = Vector3(0, 0.85, -1.0)
		m.spread = 10.0
		m.initial_velocity_min = 16.0
		m.initial_velocity_max = 26.0
		m.gravity = Vector3(0, -9.0, 0)
		m.scale_min = 1.0
		m.scale_max = 2.6
		m.color_ramp = fade_ramp("plume", Color(1, 1, 1, 0.95), Color(0.88, 0.95, 1.0, 0.7))), puff_mesh(2.6))
	# Spray sheets off both sides, thrown out wide and flat.
	for side: float in [-1.0, 1.0]:
		var sheet: GPUParticles3D = emitter("SprayLeft" if side > 0.0 else "SprayRight", 220, 0.85, process("sheet_%d" % int(side), func(m: ParticleProcessMaterial) -> void:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(0.1, 0.05, length_m * 0.3)
			m.direction = Vector3(side, 0.75, -0.45)
			m.spread = 14.0
			m.flatness = 0.7
			m.initial_velocity_min = 12.0
			m.initial_velocity_max = 22.0
			m.gravity = Vector3(0, -12.0, 0)
			m.scale_min = 0.8
			m.scale_max = 2.0
			m.color_ramp = fade_ramp("sheet", Color(1, 1, 1, 0.9), Color(0.9, 0.96, 1.0, 0.6))), puff_mesh(2.0))
		sheet.position = Vector3(side * beam_m * 0.5, 0, -length_m * 0.05)
		if side > 0.0: spray_left = sheet
		else: spray_right = sheet
	# The blaster's white-hot burst (one shot, restarted on each blast).
	burst = emitter("BoostBurst", 260, 0.75, process("burst", func(m: ParticleProcessMaterial) -> void:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = 0.8
		m.direction = Vector3(0, 0.2, -1.0)
		m.spread = 180.0
		m.initial_velocity_min = 25.0
		m.initial_velocity_max = 70.0
		m.damping_min = 20.0
		m.damping_max = 40.0
		m.gravity = Vector3.ZERO
		m.scale_min = 1.5
		m.scale_max = 4.5
		m.color_ramp = fade_ramp("burst", Color(1, 1, 1, 1), Color(1.0, 0.93, 0.7, 0.9))), puff_mesh(3.2, true))
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.emitting = false
	burst.position = nozzle + Vector3(0, 0, -0.8)
	burst_light = OmniLight3D.new()
	burst_light.name = "BurstLight"
	burst_light.light_color = Color("fff6e0")
	burst_light.omni_range = 40.0
	burst_light.light_energy = 0.0
	burst_light.visible = false
	burst_light.shadow_enabled = false
	burst_light.position = nozzle + Vector3(0, 1.0, -2.0)
	add_child(burst_light)
	# Speed lines: thin streaks rushing past the hull (the own Jetty, at speed).
	speed_lines = emitter("SpeedLines", 70, 0.35, process("lines", func(m: ParticleProcessMaterial) -> void:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(14.0, 5.0, 10.0)
		m.direction = Vector3(0, 0, -1)
		m.spread = 0.0
		m.initial_velocity_min = 140.0
		m.initial_velocity_max = 190.0
		m.gravity = Vector3.ZERO
		m.color_ramp = fade_ramp("lines", Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.5))), pooled("line_mesh", func() -> Resource:
			var streak: BoxMesh = BoxMesh.new()
			streak.size = Vector3(0.04, 0.04, 7.0)
			var paint: StandardMaterial3D = StandardMaterial3D.new()
			paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			paint.vertex_color_use_as_albedo = true
			streak.material = paint
			return streak) as Mesh)
	speed_lines.position = Vector3(0, 4.0, length_m * 1.5)
	speed_lines.emitting = false
	# Dust (or snow) kicked up over land.
	dust = emitter("Dust", 220, 1.6, dust_process("sand", DUST_SAND), puff_mesh(2.6))
	dust.emitting = false
	# The depression under the hover and its running ripple rings.
	depression = MeshInstance3D.new()
	depression.name = "Depression"
	var hollow: CylinderMesh = CylinderMesh.new()
	hollow.top_radius = 0.5
	hollow.bottom_radius = 0.5
	hollow.height = 0.01
	hollow.radial_segments = 24
	hollow.rings = 1
	depression.mesh = hollow
	depression.material_override = unshaded(Color(0.04, 0.12, 0.2, 0.35))
	depression.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(depression)
	for index: int in 2:
		var ripple: MeshInstance3D = MeshInstance3D.new()
		ripple.name = "Ripple%d" % index
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.92
		torus.outer_radius = 1.0
		torus.rings = 32
		torus.ring_segments = 3
		ripple.mesh = torus
		ripple.material_override = unshaded(Color(1, 1, 1, 0.5))
		ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ripple)
		ripples.append(ripple)
	# The V-shaped wake trench behind the stern.
	wake = MeshInstance3D.new()
	wake.name = "WakeTrench"
	wake.mesh = wake_mesh()
	wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wake)
	# Glow: a light pool on the water under the hull.
	var pool: PlaneMesh = PlaneMesh.new()
	pool.size = Vector2(beam_m * 2.6, length_m * 1.2)
	glow_paint = unshaded(Color(GLOW, 0.5), true)
	# (Patch 4.0.7: a soft round pool, not a hard-edged rectangle.)
	glow_paint.albedo_texture = puff_texture()
	glow = MeshInstance3D.new()
	glow.name = "Glow"
	glow.mesh = pool
	glow.material_override = glow_paint
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	glow_light = OmniLight3D.new()
	glow_light.name = "GlowLight"
	glow_light.light_color = GLOW
	glow_light.omni_range = maxf(length_m * 0.8, 6.0)
	glow_light.shadow_enabled = false
	add_child(glow_light)
	# The blaster flame: three nested cones, fast RGB, out of the nozzle.
	flame = Node3D.new()
	flame.name = "BoostFlame"
	flame.position = nozzle
	add_child(flame)
	for band: float in FLAME_BANDS:
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = FLAME_RADIUS_M * band
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.rings = 1
		var paint: StandardMaterial3D = unshaded(Color.WHITE)
		var cone: MeshInstance3D = MeshInstance3D.new()
		cone.mesh = mesh
		cone.material_override = paint
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation.x = -PI / 2.0
		flame.add_child(cone)
		flame_cones.append(cone)
		flame_paints.append(paint)
	# The charge: an orb that swells at the nozzle.
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	orb_paint = unshaded(Color(1, 1, 1, 0.9), true)
	orb = MeshInstance3D.new()
	orb.name = "ChargeOrb"
	orb.mesh = ball
	orb.material_override = orb_paint
	orb.position = nozzle + Vector3(0, 0, -0.3)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	# The blast: a shock ring bursting off the stern.
	var torus_ring: TorusMesh = TorusMesh.new()
	torus_ring.inner_radius = 0.8
	torus_ring.outer_radius = 1.0
	torus_ring.rings = 24
	torus_ring.ring_segments = 6
	ring_paint = unshaded(Color(1, 1, 1, 0.9), true)
	ring = MeshInstance3D.new()
	ring.name = "BlastRing"
	ring.mesh = torus_ring
	ring.material_override = ring_paint
	ring.position = nozzle + Vector3(0, 0, -0.6)
	ring.rotation.x = PI / 2.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	voice = AudioStreamPlayer.new()
	voice.name = "BoostSound"
	voice.volume_db = -8.0
	add_child(voice)

## Patch 4.0.7 item 5: the dust kicked up over land, in one colour (shared).
func dust_process(key: String, colour: Color) -> ParticleProcessMaterial:
	return process("dust_" + key, func(m: ParticleProcessMaterial) -> void:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(beam_m * 0.7, 0.1, length_m * 0.5)
		m.direction = Vector3(0, 0.9, -0.6)
		m.spread = 45.0
		m.initial_velocity_min = 5.0
		m.initial_velocity_max = 15.0
		m.gravity = Vector3(0, -1.5, 0)
		m.damping_min = 1.0
		m.damping_max = 3.0
		m.scale_min = 1.5
		m.scale_max = 4.0
		m.color_ramp = fade_ramp("dust_" + key, Color(colour, 0.85), Color(colour, 0.55)))

## Patch 4.0.7 item 5: the wake's V: two foam arms opening behind the stern
## and a dark trench between them, one unit long (scaled by speed), fading
## out to the far end (vertex colours). Shared by every Jetty.
static func wake_mesh() -> ArrayMesh:
	return pooled("wake", func() -> Resource:
		var tool: SurfaceTool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var foam: Color = Color(1, 1, 1, 0.75)
		var trench: Color = Color(0.03, 0.1, 0.18, 0.45)
		var spread: float = 0.42
		var strips: Array = [[-1.0, foam], [1.0, foam]]
		for strip: Array in strips:
			var side: float = strip[0]
			var colour: Color = strip[1]
			var quad: Array[Vector3] = [Vector3(side * 0.06, 0, 0), Vector3(side * 0.16, 0, 0), Vector3(side * (spread + 0.16), 0, -1.0), Vector3(side * spread, 0, -1.0)]
			var tints: Array[Color] = [colour, colour, Color(colour, 0.0), Color(colour, 0.0)]
			for index: int in [0, 1, 2, 0, 2, 3]:
				tool.set_color(tints[index])
				tool.add_vertex(quad[index])
		var middle: Array[Vector3] = [Vector3(-0.06, 0, 0), Vector3(0.06, 0, 0), Vector3(spread * 0.85, 0, -1.0), Vector3(-spread * 0.85, 0, -1.0)]
		var shades: Array[Color] = [trench, trench, Color(trench, 0.0), Color(trench, 0.0)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			tool.set_color(shades[index])
			tool.add_vertex(middle[index] + Vector3(0, -0.02, 0))
		var paint: StandardMaterial3D = StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.vertex_color_use_as_albedo = true
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		tool.set_material(paint)
		return tool.commit()) as ArrayMesh

## The boost this hull carries (null in the hangar).
func boost() -> JETTY_BOOST:
	if is_instance_valid(ship): return ship.get("boost") as JETTY_BOOST
	return null

## 0..1 share of top speed (0.35 in the hangar so the plume shows).
func pace() -> float:
	if not is_instance_valid(ship) or not ship is CharacterBody3D: return 0.35
	var body: CharacterBody3D = ship as CharacterBody3D
	var definition: Resource = body.get("definition") as Resource
	var top: float = 1.0
	if definition != null: top = maxf(float(definition.get("forward_acceleration_mps2")) / maxf(float(definition.get("linear_drag_per_second")), 0.001), 1.0)
	return clampf(Vector2(body.velocity.x, body.velocity.z).length() / top, 0.0, 1.6)

## The water level in this node's space: below the hull by the hover lift.
## (Patch 4.0.7 item 4: over land the body rides the ground's height, so this
## is the ground there.)
func water_y() -> float:
	if is_instance_valid(motion): return -motion.position.y
	return -2.0

static func rgb(hue: float, value: float = 1.0) -> Color:
	return Color.from_hsv(fposmod(hue, 1.0), 0.85, value)

func _process(delta: float) -> void:
	update_fx(delta)

## Patch 4.0.7 item 5: the LOD share from the camera's distance (1 near, a
## part farther off, 0 past LOD_FAR_M), less for another captain's Jetty.
func level_of_detail() -> float:
	var share: float = 1.0
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() != null else null
	if camera != null:
		var distance: float = camera.global_position.distance_to(global_position)
		share = 1.0 if distance < LOD_NEAR_M else (0.0 if distance > LOD_FAR_M else lerpf(0.45, 0.15, (distance - LOD_NEAR_M) / (LOD_FAR_M - LOD_NEAR_M)))
	return share * (REMOTE_SHARE if remote else 1.0)

## Patch 4.0.7 item 5: what is under the hull now (sampled every
## SURFACE_EVERY_S): "water" in the hangar or off the game's world.
func sample_ground(step: float) -> void:
	ground_age += step
	if ground_age < SURFACE_EVERY_S: return
	ground_age = 0.0
	ground = "water"
	if is_inside_tree() and is_instance_valid(ship) and ship is Node3D and (ship as Node3D).global_position.y > 0.05:
		ground = JETTY_LAND.surface((ship as Node3D).global_position)

func update_fx(delta: float) -> void:
	var step: float = clampf(delta, 0.0, 0.1)
	clock += step
	var power: JETTY_BOOST = boost()
	# Online the presentation hull runs no physics: move its boost clock here.
	if power != null and is_instance_valid(ship) and not (ship as Node).is_physics_processing(): power.advance(step)
	var phase: String = power.phase if power != null else "ready"
	if phase != last_phase:
		if phase == "charge":
			play(charge_sound())
			charges_heard += 1
		if phase == "blast":
			play(blast_sound())
			blasts_heard += 1
			ring_age = 0.0
			fire_burst()
		last_phase = phase
	var charge: float = power.charge() if power != null and phase == "charge" else 0.0
	var blast: float = power.blast() if power != null else 0.0
	var speed: float = pace()
	var full: float = minf(speed, 1.0)
	var water: float = water_y() + 0.08
	sample_ground(step)
	# (The replica is marked after its look is built, so this is read each frame.)
	remote = is_instance_valid(ship) and ship.has_meta("remote_replica")
	detail = level_of_detail()
	var wet: bool = ground == "water"
	var shown: bool = detail > 0.0
	# Hover: the mist, the depression and its ripples under the hull.
	downwash.position = Vector3(0, water, 0)
	lie_flat(downwash, Vector3.ONE)
	downwash.emitting = shown and wet
	downwash.amount_ratio = clampf(detail * (0.6 + 0.4 * blast), 0.05, 1.0)
	depression.visible = shown and wet
	depression.position = Vector3(0, water + 0.01, 0)
	lie_flat(depression, Vector3(beam_m * 1.6, 1.0, length_m * 0.9) * (1.0 + 0.06 * sin(clock * 4.3) + 0.25 * blast))
	for index: int in ripples.size():
		var ripple: MeshInstance3D = ripples[index]
		var age: float = fposmod(clock / RIPPLE_S + index * 0.5, 1.0)
		ripple.visible = shown and wet and detail > 0.3
		ripple.position = Vector3(0, water + 0.03, 0)
		lie_flat(ripple, Vector3(beam_m * (0.7 + 1.9 * age), 0.08, length_m * (0.45 + 0.6 * age)))
		(ripple.material_override as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - age) * (1.0 - full * 0.6)
	# Moving: the rooster-tail plume, the spray sheets and the V wake, all
	# growing with speed (and more in a blast).
	var grow: float = 0.45 + (PLUME_LENGTHS / 3.2 - 0.45) * full + 1.2 * blast
	rooster.position = Vector3(0, water, -length_m * 0.5 - 0.6)
	rooster.emitting = shown and wet and (speed > 0.04 or blast > 0.0)
	lie_flat(rooster, Vector3(0.8 + 1.4 * full + blast, 0.6 + 1.6 * full + blast, grow))
	rooster.amount_ratio = clampf(detail * (0.35 + 0.65 * full), 0.05, 1.0)
	for sheet: GPUParticles3D in [spray_left, spray_right]:
		sheet.position.y = water
		sheet.emitting = shown and wet and detail > 0.3 and speed > 0.08
		lie_flat(sheet, Vector3.ONE * (0.6 + 1.6 * full + 0.8 * blast))
		sheet.amount_ratio = clampf(detail * (0.3 + 0.7 * full), 0.05, 1.0)
	wake.visible = shown and wet and speed > 0.02
	wake.position = Vector3(0, water + 0.25, -length_m * 0.45)
	var wake_length: float = length_m * (1.5 + (WAKE_LENGTHS - 1.5) * full + 3.0 * blast)
	lie_flat(wake, Vector3(wake_length * (0.9 + 0.3 * full), 1.0, wake_length))
	# Over land: dust, or snow over the ice, kicked up instead.
	dust.position = Vector3(0, water, -length_m * 0.2)
	dust.emitting = shown and not wet
	if not wet:
		var colour: String = "snow" if ground == "ice" else ("rock" if ground == "rock" else "sand")
		var kicked: ParticleProcessMaterial = dust_process(colour, DUST_SNOW if colour == "snow" else (DUST_ROCK if colour == "rock" else DUST_SAND))
		if dust.process_material != kicked: dust.process_material = kicked
		dust.amount_ratio = clampf(detail * (0.3 + 0.7 * full + 0.4 * blast), 0.05, 1.0)
		lie_flat(dust, Vector3.ONE * (0.8 + 1.2 * full))
	# The blaster's burst and its flash.
	burst_age += step
	burst_light.visible = burst_age < BURST_S
	burst_light.light_energy = 14.0 * maxf(0.0, 1.0 - burst_age / BURST_S) if burst_light.visible else 0.0
	# Speed lines and the camera's FOV kick: only the own Jetty, near top speed.
	var rush: float = smoothstep(0.75, 1.0, speed) if not remote and is_instance_valid(ship) else 0.0
	speed_lines.emitting = shown and (rush > 0.05 or blast > 0.2) and not remote and is_instance_valid(ship)
	speed_lines.amount_ratio = clampf(maxf(rush, blast), 0.05, 1.0)
	kick_camera(FOV_KICK_DEG * rush + FOV_BLAST_DEG * blast, step)
	var pulse: float = 0.5 + 0.5 * sin(clock * 3.1)
	var hot: float = maxf(charge, blast)
	glow.position = Vector3(0, water + 0.02, 0)
	lie_flat(glow, Vector3.ONE)
	var glow_colour: Color = GLOW.lerp(rgb(clock * HUE_RATE), hot)
	glow_paint.albedo_color = Color(glow_colour, 0.22 + 0.1 * pulse + 0.4 * hot)
	glow_light.position = Vector3(0, water + 0.6, 0)
	glow_light.light_color = glow_colour
	glow_light.light_energy = 1.2 + 0.5 * pulse + 3.0 * hot
	# Charge: the orb swells and spins through the colours.
	orb.visible = charge > 0.0
	if orb.visible:
		var size: float = 0.3 + 1.6 * charge * charge + 0.12 * sin(clock * 47.0)
		orb.scale = Vector3.ONE * size
		orb_paint.albedo_color = Color(rgb(clock * HUE_RATE * 2.0).lerp(Color.WHITE, 0.4 * charge), 0.6 + 0.4 * charge)
	# Blast: the huge RGB flame and the shock ring.
	flame.visible = blast > 0.01
	if flame.visible:
		for index: int in flame_cones.size():
			var band: float = float(FLAME_BANDS[index])
			var flicker: float = 1.0 + 0.1 * sin(clock * (37.0 + index * 9.0)) + 0.06 * sin(clock * 61.0 + index)
			var cone_length: float = FLAME_LENGTH_M * band * flicker * (0.35 + 0.65 * blast)
			var cone: MeshInstance3D = flame_cones[index]
			cone.scale = Vector3(0.5 + 0.5 * blast, cone_length, 0.5 + 0.5 * blast)
			cone.position = Vector3(0, 0, -cone_length * 0.5)
			# Outer band fastest round the wheel, the core nearly white.
			flame_paints[index].albedo_color = rgb(clock * HUE_RATE + index * 0.33).lerp(Color.WHITE, 0.2 + 0.3 * index)
	ring_age += step
	ring.visible = ring_age < RING_S
	if ring.visible:
		var t: float = ring_age / RING_S
		ring.scale = Vector3.ONE * (0.8 + 7.0 * t)
		ring.position = nozzle + Vector3(0, 0, -0.6 - 5.0 * t)
		ring_paint.albedo_color = Color(rgb(clock * HUE_RATE + 0.5), 0.9 * (1.0 - t))

## Patch 4.0.7 item 5: the water-level effects lie flat on the water (or the
## ground): they keep the hull's heading but not its hover pitch and roll
## (a 100 m wake tilted by a few degrees would dive under the sea).
func lie_flat(node: Node3D, size: Vector3) -> void:
	node.scale = size
	if not node.is_inside_tree(): return
	var forward: Vector3 = global_basis.z
	var heading: Basis = Basis(Vector3.UP, atan2(forward.x, forward.z))
	node.global_transform = Transform3D(heading * Basis.from_scale(size), node.global_position)

## Patch 4.0.7 item 5: the big white-hot burst on the blast (reused emitter).
func fire_burst() -> void:
	bursts_fired += 1
	burst_age = 0.0
	if detail <= 0.0: return
	burst.amount_ratio = clampf(maxf(detail, 0.3), 0.05, 1.0)
	burst.restart()
	burst.emitting = true

## Patch 4.0.7 item 5: the slight FOV kick at top speed and in a blast (the
## own Jetty's camera only), eased in and out; the camera's own FOV is kept
## and given back.
func kick_camera(kick: float, step: float) -> void:
	fov_kick = move_toward(fov_kick, kick, step * 20.0)
	if remote or not is_inside_tree() or not is_instance_valid(ship): return
	var camera: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if camera != kicked_camera: release_camera()
	if camera == null: return
	if fov_kick <= 0.01 and kicked_camera == null: return
	if kicked_camera == null:
		kicked_camera = camera
		camera.set_meta("jetty_base_fov", camera.fov)
	camera.fov = float(camera.get_meta("jetty_base_fov", camera.fov)) + fov_kick
	if fov_kick <= 0.01: release_camera()

func release_camera() -> void:
	if is_instance_valid(kicked_camera) and kicked_camera.has_meta("jetty_base_fov"):
		kicked_camera.fov = float(kicked_camera.get_meta("jetty_base_fov"))
		kicked_camera.remove_meta("jetty_base_fov")
	kicked_camera = null

func play(stream: AudioStream) -> void:
	if voice == null or not voice.is_inside_tree(): return
	voice.stream = stream
	voice.play()

static func write(samples: PackedByteArray, index: int, value: float) -> void:
	samples.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 30000.0))

static func wav(seconds: float) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(int(seconds * MIX_RATE) * 2)
	stream.data = samples
	return stream

## The charge: a whine rising three octaves with a quickening flutter, a rising
## hum under it and a fizz of sparks that thickens as it fills. Made once.
static func charge_sound() -> AudioStreamWAV:
	if _charge_sound != null: return _charge_sound
	var seconds: float = JETTY_BOOST.CHARGE_S + 0.04
	var stream: AudioStreamWAV = wav(seconds)
	var samples: PackedByteArray = stream.data
	var count: int = samples.size() >> 1
	var noise: RandomNumberGenerator = RandomNumberGenerator.new()
	noise.seed = 4022
	var whine: float = 0.0
	var hum: float = 0.0
	var flutter: float = 0.0
	var smooth: float = 0.0
	for index: int in count:
		var t: float = float(index) / MIX_RATE
		var fill: float = clampf(t / JETTY_BOOST.CHARGE_S, 0.0, 1.0)
		whine += TAU * 220.0 * pow(8.0, fill) / MIX_RATE
		hum += TAU * (55.0 + 55.0 * fill) / MIX_RATE
		flutter += TAU * (8.0 + 34.0 * fill * fill) / MIX_RATE
		var raw: float = noise.randf_range(-1.0, 1.0)
		smooth = lerpf(smooth, raw, 0.2)
		var tone: float = (sin(whine) + 0.35 * sin(whine * 2.003) + 0.15 * sin(whine * 3.01)) * (0.72 + 0.28 * sin(flutter))
		var wave: float = tone * (0.15 + 0.55 * fill * fill) + sin(hum) * 0.3 * fill + (raw - smooth) * 0.18 * fill
		wave *= minf(1.0, t / 0.01) * minf(1.0, (seconds - t) / 0.02)
		write(samples, index, tanh(wave * 1.3) * 0.85)
	stream.data = samples
	_charge_sound = stream
	return stream

## The blast: a deep falling boom, a bright saw zap diving from 1.8 kHz to
## 120 Hz (a detuned pair, so it beats), and a long roaring beam of filtered
## noise over a throbbing rumble, soft-clipped together. Made once.
static func blast_sound() -> AudioStreamWAV:
	if _blast_sound != null: return _blast_sound
	var seconds: float = 1.9
	var stream: AudioStreamWAV = wav(seconds)
	var samples: PackedByteArray = stream.data
	var count: int = samples.size() >> 1
	var noise: RandomNumberGenerator = RandomNumberGenerator.new()
	noise.seed = 4023
	var boom: float = 0.0
	var zap_a: float = 0.0
	var zap_b: float = 0.0
	var throb: float = 0.0
	var roar: float = 0.0
	var roar_low: float = 0.0
	for index: int in count:
		var t: float = float(index) / MIX_RATE
		boom += TAU * (40.0 + 100.0 * exp(-t * 7.0)) / MIX_RATE
		var dive: float = 120.0 + 1680.0 * exp(-t * 6.5)
		zap_a += TAU * dive / MIX_RATE
		zap_b += TAU * dive * 1.012 / MIX_RATE
		throb += TAU * 90.0 / MIX_RATE
		var raw: float = noise.randf_range(-1.0, 1.0)
		roar = lerpf(roar, raw, 0.35)
		roar_low = lerpf(roar_low, roar, 0.08)
		var saw: float = 0.0
		for harmonic: int in range(1, 5):
			saw += (sin(zap_a * harmonic) + sin(zap_b * harmonic)) / float(harmonic)
		var attack: float = minf(1.0, t / 0.003)
		var wave: float = sin(boom) * 0.9 * exp(-t * 3.5)
		wave += saw * 0.22 * exp(-t * 4.0)
		wave += (roar - roar_low) * 0.5 * (1.0 - exp(-t * 40.0)) * exp(-t * 1.3)
		wave += roar_low * 1.4 * exp(-t * 1.6) * (0.7 + 0.3 * sin(throb))
		wave *= attack * minf(1.0, (seconds - t) / 0.12)
		write(samples, index, tanh(wave * 1.4) * 0.9)
	stream.data = samples
	_blast_sound = stream
	return stream
