extends Node3D
## Patch 2.9.1 item 4: the cannon salute of one pirate ship. A broadside ripples
## from bow to stern on both sides: a muzzle flash and toon smoke puffs at each
## gun, booms, and splashes out at sea. Looks and sound only: nothing is
## launched, nothing is hit, nothing is damaged, and no game state changes.
##
## Frame time: every flash, puff and splash lump is one instance of a single
## MultiMesh that is built once (on the first salute) and reused, and the booms
## share a small set of players. Nothing is created while firing. The node does
## not run at all between salutes.
const COOLDOWN_S: float = 5.0
## Bow gun to stern gun.
const RIPPLE_S: float = 1.1
const LUMPS_PER_GUN: int = 7
const MAX_LUMPS: int = 640
const BOOM_VOICES: int = 5
const BOOMS_PER_SALUTE: int = 9
const GRAVITY: float = 16.0
## Splashes fall this far abeam, and never within this margin of land.
const SPLASH_NEAR_M: float = 110.0
const SPLASH_FAR_M: float = 190.0
const SHORE_MARGIN_M: float = 15.0
const SHOT_SPEED_MPS: float = 150.0
const FLASH: int = 0
const SMOKE: int = 1
const SPLASH: int = 2
const SPARE: int = 255
const FLASH_COLOUR: Color = Color(1.0, 0.84, 0.32)
const Progression = preload("res://features/game/progression.gd")
static var _boom: AudioStreamWAV

var motion: ShipVisualMotion
## Muzzles in the model's own space, in firing order, and when each one fires.
var muzzles: PackedVector3Array = PackedVector3Array()
var delays: PackedFloat32Array = PackedFloat32Array()
## Smaller hulls carry smaller guns.
var gun_scale: float = 1.0
var cooldown_left: float = 0.0
var clock: float = 0.0
var next_gun: int = 0
var random: RandomNumberGenerator = RandomNumberGenerator.new()
## Counters for the checks.
var salutes: int = 0
var shots: int = 0
var splashes: int = 0

var cloud: MultiMesh
var lump_position: PackedVector3Array = PackedVector3Array()
var lump_velocity: PackedVector3Array = PackedVector3Array()
var lump_age: PackedFloat32Array = PackedFloat32Array()
var lump_life: PackedFloat32Array = PackedFloat32Array()
var lump_size: PackedFloat32Array = PackedFloat32Array()
var lump_kind: PackedByteArray = PackedByteArray()
var cursor: int = 0
var live: int = 0
var voices: Array[AudioStreamPlayer] = []
var voice: int = 0

## A short low thump with a rumbling tail, made once for the whole game.
static func boom() -> AudioStreamWAV:
	if _boom != null: return _boom
	_boom = AudioStreamWAV.new()
	_boom.format = AudioStreamWAV.FORMAT_16_BITS
	_boom.mix_rate = 11025
	var count: int = int(0.9 * _boom.mix_rate)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(count * 2)
	var noise: RandomNumberGenerator = RandomNumberGenerator.new()
	noise.seed = 1704
	var rumble: float = 0.0
	for index: int in count:
		var t: float = float(index) / _boom.mix_rate
		# Low-passed noise for the crack and the roll, a falling tone for the thump.
		rumble = lerpf(rumble, noise.randf_range(-1.0, 1.0), 0.18 if t < 0.05 else 0.06)
		var thump: float = sin(TAU * (38.0 * t + 46.0 * (1.0 - exp(-t * 9.0)) / 9.0)) * exp(-t * 6.0)
		var wave: float = (thump * 0.75 + rumble * 1.6 * exp(-t * 5.0)) * minf(1.0, t / 0.004) * minf(1.0, (0.9 - t) / 0.1)
		samples.encode_s16(index * 2, int(clampf(wave, -1.0, 1.0) * 26000))
	_boom.data = samples
	return _boom

## `local_muzzles` are in the model's space (bow at +Z). Guns fire bow to stern,
## both sides together, each a touch off the beat.
func fit(local_muzzles: PackedVector3Array, scale_of_guns: float) -> void:
	gun_scale = scale_of_guns
	boom()
	if local_muzzles.is_empty(): return
	var bow: float = local_muzzles[0].z
	var stern: float = bow
	for muzzle: Vector3 in local_muzzles:
		bow = maxf(bow, muzzle.z)
		stern = minf(stern, muzzle.z)
	var order: Array = []
	for index: int in local_muzzles.size():
		var muzzle: Vector3 = local_muzzles[index]
		var delay: float = (bow - muzzle.z) / maxf(1.0, bow - stern) * RIPPLE_S + fmod(index * 0.618, 1.0) * 0.09
		order.append([delay, muzzle])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in order:
		delays.append(entry[0])
		muzzles.append(entry[1])
	next_gun = muzzles.size()

func _ready() -> void:
	var above: Node = get_parent()
	while above != null and not above is ShipVisualMotion: above = above.get_parent()
	motion = above as ShipVisualMotion
	set_process(false)

func ready_to_fire() -> bool:
	return cooldown_left <= 0.0 and not muzzles.is_empty() and is_inside_tree()

## Starts a broadside. False while the last one is still cooling down.
func fire() -> bool:
	if not ready_to_fire(): return false
	if cloud == null: build()
	cooldown_left = COOLDOWN_S
	clock = 0.0
	next_gun = 0
	salutes += 1
	set_process(true)
	return true

## The reused lumps and boom players. Once per ship, on her first salute.
func build() -> void:
	var count: int = mini(MAX_LUMPS, muzzles.size() * LUMPS_PER_GUN)
	lump_position.resize(count)
	lump_velocity.resize(count)
	lump_age.resize(count)
	lump_life.resize(count)
	lump_size.resize(count)
	lump_kind.resize(count)
	lump_kind.fill(SPARE)
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 7
	ball.rings = 4
	cloud = MultiMesh.new()
	cloud.transform_format = MultiMesh.TRANSFORM_3D
	cloud.use_colors = true
	cloud.mesh = ball
	cloud.instance_count = count
	var hidden: Transform3D = Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for index: int in count: cloud.set_instance_transform(index, hidden)
	# Flat colour, like the game's other toon puffs; each lump carries its own.
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	var puffs: MultiMeshInstance3D = MultiMeshInstance3D.new()
	puffs.name = "Puffs"
	puffs.multimesh = cloud
	puffs.material_override = paint
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# World space: smoke and splashes stay where they were made as the ship sails on.
	puffs.top_level = true
	puffs.custom_aabb = AABB(Vector3(-1e5, -200, -1e5), Vector3(2e5, 600, 2e5))
	add_child(puffs)
	puffs.global_transform = Transform3D.IDENTITY
	for index: int in BOOM_VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = boom()
		player.volume_db = -15.0
		add_child(player)
		voices.append(player)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	var step: float = clampf(delta, 0.0, 0.1)
	cooldown_left = maxf(0.0, cooldown_left - step)
	if next_gun < muzzles.size():
		clock += step
		while next_gun < muzzles.size() and delays[next_gun] <= clock:
			shoot(next_gun)
			next_gun += 1
	move_lumps(step)
	if next_gun >= muzzles.size() and live == 0 and cooldown_left <= 0.0: set_process(false)

func sea_colour() -> Color:
	if motion != null and is_instance_valid(motion.ocean): return motion.ocean.palette.foam_color
	return Color.WHITE

func water_height(x: float, z: float) -> float:
	if motion == null or not is_instance_valid(motion.ocean): return 0.0
	var ocean: OceanPresentation = motion.ocean
	return ocean.global_position.y + OceanPresentation.swell_height(x, z, ocean.elapsed, ocean.quality)

## One gun: flash, three smoke puffs, and (over open water) a splash far abeam.
func shoot(gun: int) -> void:
	var local: Vector3 = muzzles[gun]
	var side: float = 1.0 if local.x >= 0.0 else -1.0
	var at: Vector3 = global_transform * local
	var out: Vector3 = (global_basis.x * side).normalized()
	var carry: Vector3 = Vector3.ZERO
	if motion != null and is_instance_valid(motion.body): carry = Vector3(motion.body.velocity.x, 0.0, motion.body.velocity.z)
	var foam: Color = sea_colour()
	shots += 1
	add_lump(FLASH, at + out * 0.7, carry, 0.0, 0.16, 3.8 * gun_scale, FLASH_COLOUR)
	for puff: int in 3:
		var grey: float = random.randf_range(0.8, 0.97)
		add_lump(SMOKE, at + out * (1.0 + 1.6 * puff), carry * 0.6 + out * (7.0 + 6.0 * puff) * random.randf_range(0.7, 1.1) + Vector3.UP * random.randf_range(0.4, 1.4),
			0.04 * puff, random.randf_range(1.7, 2.6), random.randf_range(3.0, 4.8) * gun_scale, Color(foam.r * grey, foam.g * grey, foam.b * grey * 0.98))
	var flat: Vector3 = Vector3(out.x, 0.0, out.z).normalized()
	var reach: float = random.randf_range(SPLASH_NEAR_M, SPLASH_FAR_M)
	var fall: Vector3 = at + flat * reach + Vector3(random.randf_range(-6.0, 6.0), 0.0, random.randf_range(-6.0, 6.0))
	# A salute only ever wets open water: no splash on or near land.
	if Progression.land_depth(Vector2(fall.x, fall.z)) <= -SHORE_MARGIN_M:
		fall.y = water_height(fall.x, fall.z)
		splashes += 1
		for lump: int in 3:
			var rise: float = random.randf_range(8.0, 14.0) * (1.0 if lump == 0 else 0.7)
			add_lump(SPLASH, fall, Vector3(random.randf_range(-2.0, 2.0), rise, random.randf_range(-2.0, 2.0)),
				reach / SHOT_SPEED_MPS, 2.0 * rise / GRAVITY, random.randf_range(2.4, 4.0) * gun_scale, foam)
	if not voices.is_empty() and gun % maxi(1, ceili(float(muzzles.size()) / BOOMS_PER_SALUTE)) == 0:
		var player: AudioStreamPlayer = voices[voice]
		voice = (voice + 1) % voices.size()
		player.pitch_scale = random.randf_range(0.82, 1.08) / sqrt(gun_scale)
		player.play()

## Takes the next lump in the ring (the oldest, if all are in use).
func add_lump(kind: int, at: Vector3, velocity: Vector3, wait: float, life: float, size: float, colour: Color) -> void:
	if lump_kind.is_empty(): return
	var index: int = cursor
	cursor = (cursor + 1) % lump_kind.size()
	if lump_kind[index] == SPARE: live += 1
	lump_kind[index] = kind
	lump_position[index] = at
	lump_velocity[index] = velocity
	lump_age[index] = -wait
	lump_life[index] = life
	lump_size[index] = size
	cloud.set_instance_color(index, colour)
	cloud.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), at))

func move_lumps(step: float) -> void:
	if live == 0: return
	for index: int in lump_kind.size():
		var kind: int = lump_kind[index]
		if kind == SPARE: continue
		var age: float = lump_age[index] + step
		lump_age[index] = age
		if age < 0.0: continue
		var life: float = lump_life[index]
		if age >= life:
			lump_kind[index] = SPARE
			live -= 1
			cloud.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), lump_position[index]))
			continue
		var t: float = age / life
		var velocity: Vector3 = lump_velocity[index]
		var grow: float = 1.0
		match kind:
			FLASH:
				grow = 1.0 - t * t
			SMOKE:
				# Shoved out, slows in the air, drifts up, swells and then thins away.
				var drag: float = exp(-2.4 * step)
				velocity = Vector3(velocity.x * drag, lerpf(velocity.y, 1.3, 1.0 - drag), velocity.z * drag)
				grow = (0.45 + 0.9 * sqrt(t)) * smoothstep(1.0, 0.55, t)
			SPLASH:
				velocity.y -= GRAVITY * step
				grow = 0.5 + 0.5 * sin(PI * minf(1.0, t * 1.15))
		lump_velocity[index] = velocity
		var at: Vector3 = lump_position[index] + velocity * step
		lump_position[index] = at
		var size: float = lump_size[index] * grow
		# A splash lump is a tall column on the way up.
		var shape: Vector3 = Vector3(size, size * (1.0 + maxf(0.0, velocity.y) * 0.12), size) if kind == SPLASH else Vector3(size, size, size)
		cloud.set_instance_transform(index, Transform3D(Basis.from_scale(shape), at))
