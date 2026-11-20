extends Node
## Patch 3.1: the day/night cycle. Looks only, plus the shared world clock.
## Time of day comes from one clock every player shares: the dedicated server's
## Unix time (sent on join and with every pong), or this machine's clock offline.
## The look is painted last over the biome chain (polar_biome.gd overlays), so
## the desert, tropics, rain and ice keep their own colours and only get the
## sunset gold and the night blue on top. Repainted at 10 Hz, never per flake.
## Patch 3.1.1: an 18-minute cycle. Day 5 min, sunset 5, night 5, dawn 3.
const CYCLE_SECONDS: float = 1080.0
## Phase starts as fractions of the cycle: day (0), sunset, night, dawn.
const SUNSET_AT: float = 300.0 / CYCLE_SECONDS
const NIGHT_AT: float = 600.0 / CYCLE_SECONDS
const DAWN_AT: float = 900.0 / CYCLE_SECONDS
const REPAINT_SECONDS: float = 0.1
## How far along its arc (0..1) the sun is when the day and the sunset begin.
## Each phase keeps the sun heights it had in 3.1.0, only its length changed.
const ARC_DAY: float = 0.105
const ARC_SUNSET: float = 0.829
## Noon: the top of the arc, inside the day. Headless checks sit here.
const NOON: float = SUNSET_AT * (0.5 - ARC_DAY) / (ARC_SUNSET - ARC_DAY)

const SUNSET_TOP := Color(0.36, 0.30, 0.66)
const SUNSET_HORIZON := Color(1.0, 0.56, 0.30)
const SUNSET_CLOUD := Color(1.0, 0.70, 0.52)
const SUNSET_CLOUD_SHADE := Color(0.86, 0.42, 0.50)
const SUNSET_SUN := Color(1.0, 0.62, 0.34)
const SUNSET_AMBIENT := Color(0.86, 0.62, 0.70)
const SUNSET_GLOW := Color(1.0, 0.42, 0.16)
const SUNSET_DEEP := Color(0.20, 0.22, 0.46)
const SUNSET_SURFACE := Color(0.96, 0.58, 0.42)
const NIGHT_TOP := Color(0.02, 0.04, 0.16)
const NIGHT_HORIZON := Color(0.10, 0.17, 0.36)
const NIGHT_CLOUD := Color(0.30, 0.36, 0.56)
const NIGHT_CLOUD_SHADE := Color(0.16, 0.20, 0.38)
const MOON := Color(0.78, 0.86, 1.0)
const NIGHT_AMBIENT := Color(0.34, 0.44, 0.78)
const NIGHT_DEEP := Color(0.02, 0.07, 0.18)
const NIGHT_SURFACE := Color(0.10, 0.22, 0.40)
const MOON_ENERGY: float = 0.32

## Seconds added to this machine's Unix time: set from the server while
## connected, 0 offline. The debug skip adds to it too.
static var clock_offset: float = 0.0
## Headless checks see a fixed noon, so the older look checks stay exact at any
## hour. tools/day_night_check.gd turns the live clock on.
static var live: bool = DisplayServer.get_name() != "headless"

var polar: Node
var sun: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial
var ocean: OceanPresentation
var day_sun_energy: float = 1.15
var repaint_in: float = 0.0
## 0..1 through the cycle, as last painted.
var shown: float = -1.0

static func world_seconds() -> float:
	return Time.get_unix_time_from_system() + clock_offset

## 0..1 through the cycle for a world clock.
static func cycle_at(seconds: float) -> float:
	return fposmod(seconds, CYCLE_SECONDS) / CYCLE_SECONDS

static func now() -> float:
	return cycle_at(world_seconds()) if live else NOON

## Which song plays: dawn belongs to the day.
static func song_at(t: float) -> String:
	if t >= SUNSET_AT and t < NIGHT_AT: return "sunset"
	if t >= NIGHT_AT and t < DAWN_AT: return "night"
	return "day"

## A server time arrived (seconds, Unix), already corrected by half the round
## trip. Ignores sub-second jitter so the sky never twitches.
static func sync(server_seconds: float) -> void:
	var offset: float = server_seconds - Time.get_unix_time_from_system()
	if absf(offset - clock_offset) > 0.5: clock_offset = offset

## Debug: jump to the start of the next phase.
static func skip_phase() -> void:
	var t: float = now()
	var next: float = SUNSET_AT
	for start: float in [SUNSET_AT, NIGHT_AT, DAWN_AT, 1.0]:
		if t < start - 0.0005:
			next = start
			break
	clock_offset += (next - t) * CYCLE_SECONDS + 1.0

## 0..1 along the sun's arc (dawn to the end of the sunset), above 1 at night.
## Piecewise per phase, so dawn, day and sunset each cover their own stretch.
static func arc_at(t: float) -> float:
	if t >= NIGHT_AT and t < DAWN_AT: return 1.0 + (t - NIGHT_AT) / (DAWN_AT - NIGHT_AT)
	if t >= DAWN_AT: return ARC_DAY * (t - DAWN_AT) / (1.0 - DAWN_AT)
	if t < SUNSET_AT: return lerpf(ARC_DAY, ARC_SUNSET, t / SUNSET_AT)
	return lerpf(ARC_SUNSET, 1.0, (t - SUNSET_AT) / (NIGHT_AT - SUNSET_AT))

## Sun height in degrees: -6 at the ends of its arc, 55 at NOON (the old fixed
## sun: rotation -55, -30).
static func sun_elevation(t: float) -> float:
	var u: float = arc_at(t)
	return -6.0 + 61.0 * sin(PI * u) if u <= 1.0 else -30.0

## How much sunset gold (0..1) and night (0..1) is in the look.
static func weights(t: float) -> Vector2:
	var elevation: float = sun_elevation(t)
	var night: float = 1.0 - smoothstep(-6.0, 6.0, elevation)
	var dusk: float = smoothstep(32.0, 4.0, elevation) * (1.0 - night * 0.6)
	return Vector2(dusk, night)

func setup(biome: Node) -> void:
	polar = biome
	sun = polar.sun
	environment = polar.environment
	sky_material = polar.sky_material
	ocean = polar.ocean
	day_sun_energy = sun.light_energy
	polar.overlays.append(self)

func update(delta: float) -> void:
	repaint_in -= delta
	if repaint_in > 0.0 or polar == null or polar.applied < 0.0: return
	repaint_in = REPAINT_SECONDS
	var t: float = now()
	if absf(t - shown) < 0.00002: return
	# The biome chain repaints from its base, then calls paint() on every overlay.
	polar.apply(polar.applied)

func paint() -> void:
	var t: float = now()
	shown = t
	var w: Vector2 = weights(t)
	var dusk: float = w.x
	var night: float = w.y
	var elevation: float = sun_elevation(t)
	# One light: the sun by day, the moon by night. It swaps while both are dark.
	var sun_up: float = smoothstep(-4.0, 3.0, elevation)
	var moon_up: float = smoothstep(NIGHT_AT, NIGHT_AT + 0.03, t) * (1.0 - smoothstep(DAWN_AT - 0.03, DAWN_AT, t))
	if elevation > -4.0:
		var u: float = minf(arc_at(t), 1.0)
		sun.rotation_degrees = Vector3(-maxf(elevation, 2.0), lerpf(-110.0, 50.0, u), 0.0)
		sun.light_energy = sun.light_energy * lerpf(1.0, 0.85, dusk) * sun_up
	else:
		var v: float = clampf((t - NIGHT_AT) / (DAWN_AT - NIGHT_AT), 0.0, 1.0)
		sun.rotation_degrees = Vector3(-(25.0 + 30.0 * sin(PI * v)), lerpf(140.0, 230.0, v), 0.0)
		sun.light_energy = MOON_ENERGY * moon_up
	sun.light_color = sun.light_color.lerp(SUNSET_SUN, dusk).lerp(MOON, night)
	environment.ambient_light_color = environment.ambient_light_color.lerp(SUNSET_AMBIENT, dusk * 0.7).lerp(NIGHT_AMBIENT, night)
	environment.ambient_light_energy = lerpf(environment.ambient_light_energy, 0.42, night)
	var horizon: Color = SUNSET_HORIZON
	if sky_material != null:
		horizon = mix_param("horizon_color", SUNSET_HORIZON, NIGHT_HORIZON, dusk, night)
		mix_param("top_color", SUNSET_TOP, NIGHT_TOP, dusk * 0.8, night)
		mix_param("cloud_shade_color", SUNSET_CLOUD_SHADE, NIGHT_CLOUD_SHADE, dusk, night)
		sky_material.set_shader_parameter("cloud_color", Color.WHITE.lerp(SUNSET_CLOUD, dusk).lerp(NIGHT_CLOUD, night))
		sky_material.set_shader_parameter("sun_color", Color(1.0, 0.97, 0.80).lerp(SUNSET_SUN, dusk).lerp(MOON, night))
		sky_material.set_shader_parameter("glow_color", SUNSET_GLOW)
		sky_material.set_shader_parameter("glow_amount", dusk * (1.0 - night * 0.5))
		sky_material.set_shader_parameter("night_amount", night)
		# Haze matches the sky's horizon so the sea melts into it at any hour.
		environment.fog_light_color = environment.fog_light_color.lerp(horizon, maxf(dusk * 0.8, night))
	if ocean != null and ocean.ocean_material != null:
		mix_ocean("deep_color", SUNSET_DEEP, NIGHT_DEEP, dusk * 0.5, night * 0.85)
		mix_ocean("surface_color", SUNSET_SURFACE, NIGHT_SURFACE, dusk * 0.45, night * 0.85)

func mix_param(key: String, golden: Color, dark: Color, dusk: float, night: float) -> Color:
	var value: Color = polar.sky_param(key)
	value = value.lerp(golden, dusk).lerp(dark, night)
	sky_material.set_shader_parameter(key, value)
	return value

func mix_ocean(key: String, golden: Color, dark: Color, dusk: float, night: float) -> void:
	var value: Variant = ocean.ocean_material.get_shader_parameter(key)
	if not value is Color: return
	ocean.ocean_material.set_shader_parameter(key, (value as Color).lerp(golden, dusk).lerp(dark, night))
