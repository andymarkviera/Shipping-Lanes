extends RefCounted
## Patch 4.0.6 item 1: storms at sea. The rules only (no nodes): roaming storm
## cells worked out from a seed and the shared world clock (DayNight's: the
## dedicated server's Unix time online, this machine's offline), so every
## player who has the same seed sees the same storms in the same places. The
## server sends its seed and whether storms are on when a captain joins
## (dedicated_runtime.gd storm_setup); the effects that matter are worked out
## only where the simulation runs (local play, the server's player contexts):
## - boats are slowed (HandlingShip.advance_motion, also the client's own-hull
##   prediction, which works it out the same way from the same clock);
## - the hull wears mildly while underway in a storm (port_test.gd), floored at
##   WEAR_FLOOR: a storm alone never sinks a ship;
## - planes get turbulence (FlightModel.step).
## The look (rain, dark sky, lightning, thunder, bigger swell) is storm_look.gd.
## Harbours are sheltered: no storm within HARBOUR_M of a port.
## (No preload of progression.gd: HandlingShip loads this script, and the
## preload would close a loop of scripts that keeps them alive at exit. The
## wrap is Progression's own, checked equal by tools/patch_4_0_6_logic.gd.)
const WRAP_M: float = 4000.0 * PI
const WRAP_CENTRE: Vector3 = Vector3(750, 0, -100)
const DayNight = preload("res://features/sky/day_night.gd")
const DEFAULT_SEED: int = 40006
## Cells alive at once. Their lives are spread evenly, so two or three rage at
## any moment and the others are building or clearing.
const CELLS: int = 5
## One storm's life: it builds, rages, clears, then the cell is calm for a
## while and comes back somewhere else.
const LIFE_SECONDS: float = 1500.0
const RADIUS_MIN_M: float = 900.0
const RADIUS_MAX_M: float = 1500.0
const SPEED_MIN_MPS: float = 4.0
const SPEED_MAX_MPS: float = 9.0
## Full strength from the centre out to this share of the radius, then fading.
const CORE_SHARE: float = 0.55
## A port's harbour: calm within HARBOUR_M, the storm back at full by CALM_FADE_M.
const HARBOUR_M: float = 700.0
const CALM_FADE_M: float = 1100.0
## The engine's push (so the top speed too) at full strength.
const SLOW_AT_FULL: float = 0.6
## Hull (0..1) worn per second at full strength while underway: 3 % a minute.
const WEAR_PER_SECOND: float = 0.0005
## A storm never wears the hull below this.
const WEAR_FLOOR: float = 0.35
## Swell height at full strength, times the calm sea's.
const SWELL_AT_FULL: float = 2.6
## Lightning: each cell may strike once per slot, more often the stronger it is.
const STRIKE_SLOT_S: float = 2.5
const STRIKE_CHANCE: float = 0.45
## Planes: the vertical gust (m/s²) and the roll bump (rad/s) at full strength.
const GUST_MPS2: float = 3.2
const GUST_ROLL: float = 0.22

static var storm_seed: int = DEFAULT_SEED
## Headless checks start without storms so the older checks keep their exact
## numbers; the dedicated server turns them on (and tells its captains), as do
## tools/patch_4_0_6_check.gd and tools/soak_bot.gd.
static var enabled: bool = DisplayServer.get_name() != "headless"
## The swell's height now, times the calm sea's (OceanPresentation.swell_height).
## Looks only: storm_look.gd sets it where the camera is.
static var swell: float = 1.0
## The world positions of the ports (harbour shelter), cached.
static var _harbours: Array[Vector3] = []
## The cells as last worked out, reused for CACHE_S (they move under 0.5 m).
const CACHE_S: float = 0.05
static var _cached_at: float = NAN
static var _cached: Array[Dictionary] = []

## The server's storms arrived (on join), or a check sets its own.
static func configure(new_seed: int, on: bool) -> void:
	storm_seed = new_seed
	_cached_at = NAN
	enabled = on

## Back to this machine's own storms (leaving a server).
static func reset() -> void:
	storm_seed = DEFAULT_SEED
	_cached_at = NAN
	enabled = DisplayServer.get_name() != "headless"

static func short_way(step: Vector3) -> Vector3:
	return Vector3(wrapf(step.x, -WRAP_M / 2, WRAP_M / 2), step.y, wrapf(step.z, -WRAP_M / 2, WRAP_M / 2))

static func wrapped(at: Vector3) -> Vector3:
	return WRAP_CENTRE + short_way(at - WRAP_CENTRE)

static func now() -> float:
	return DayNight.world_seconds()

static func harbours() -> Array[Vector3]:
	if _harbours.is_empty():
		for place: Dictionary in load("res://features/game/progression.gd").WORLD: _harbours.append(place.at)
	return _harbours

## 0..1: how calm a spot is for being near a port (1 = open sea).
static func shelter(at: Vector3) -> float:
	var open: float = 1.0
	for harbour: Vector3 in harbours():
		var way: Vector3 = short_way(at - harbour)
		open = minf(open, smoothstep(HARBOUR_M, CALM_FADE_M, Vector2(way.x, way.z).length()))
	return open

## The same number everywhere for the same seed, cell and life.
static func cell_random(index: int, life: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([storm_seed, index, life])
	return rng

## One cell at a world time: {index, life, center, radius, strength, velocity}.
static func cell(index: int, time: float) -> Dictionary:
	var phase: float = float(index) / CELLS
	var along: float = time / LIFE_SECONDS + phase
	var life: int = floori(along)
	var u: float = along - life
	var rng: RandomNumberGenerator = cell_random(index, life)
	var start: Vector3 = WRAP_CENTRE + Vector3(rng.randf_range(-0.5, 0.5) * WRAP_M, 0.0, rng.randf_range(-0.42, 0.42) * WRAP_M)
	var heading: float = rng.randf() * TAU
	var speed: float = rng.randf_range(SPEED_MIN_MPS, SPEED_MAX_MPS)
	var radius: float = rng.randf_range(RADIUS_MIN_M, RADIUS_MAX_M)
	var velocity: Vector3 = Vector3(sin(heading), 0.0, cos(heading)) * speed
	var center: Vector3 = wrapped(start + velocity * u * LIFE_SECONDS)
	# Builds, rages and clears over the first half of its life; calm after.
	var strength: float = clampf(sin(TAU * u) * 1.5 - 0.2, 0.0, 1.0)
	return {"index": index, "life": life, "center": center, "radius": radius, "strength": strength, "velocity": velocity}

## Every cell now (or at `time`), calm ones too (strength 0).
static func cells(time: float = NAN) -> Array[Dictionary]:
	var at: float = now() if is_nan(time) else time
	var list: Array[Dictionary] = []
	for index: int in CELLS: list.append(cell(index, at))
	return list

## 0..1: how stormy it is at a world position (any copy across the wrap).
static func intensity_at(at: Vector3, time: float = NAN) -> float:
	if not enabled: return 0.0
	var when: float = now() if is_nan(time) else time
	if is_nan(_cached_at) or absf(when - _cached_at) > CACHE_S:
		_cached = cells(when)
		_cached_at = when
	var most: float = 0.0
	for storm: Dictionary in _cached:
		if storm.strength <= 0.0: continue
		var way: Vector3 = short_way(at - storm.center)
		var reach: float = Vector2(way.x, way.z).length()
		if reach >= storm.radius: continue
		most = maxf(most, storm.strength * (1.0 - smoothstep(storm.radius * CORE_SHARE, storm.radius, reach)))
	if most <= 0.0: return 0.0
	return most * shelter(at)

## The engine's push, times this, at a storm's strength.
static func speed_factor(intensity: float) -> float:
	return lerpf(1.0, SLOW_AT_FULL, clampf(intensity, 0.0, 1.0))

## The hull after `delta` seconds underway in a storm of `intensity`.
static func worn(condition: float, intensity: float, delta: float) -> float:
	if intensity <= 0.0 or delta <= 0.0 or condition <= WEAR_FLOOR: return condition
	return maxf(WEAR_FLOOR, condition - WEAR_PER_SECOND * clampf(intensity, 0.0, 1.0) * delta)

static func swell_scale(intensity: float) -> float:
	return lerpf(1.0, SWELL_AT_FULL, clampf(intensity, 0.0, 1.0))

## The plane's gust at a spot: [vertical m/s², roll rad/s]. From the position
## only, so a client's replay of its own plane meets the same air.
static func gust(at: Vector3, intensity: float) -> Vector2:
	if intensity <= 0.0: return Vector2.ZERO
	var lift: float = 0.6 * sin(at.x * 0.021 + at.z * 0.013) + 0.4 * sin(at.z * 0.037 - at.x * 0.017 + at.y * 0.05)
	var roll: float = sin(at.x * 0.029 - at.z * 0.023 + at.y * 0.03)
	return Vector2(lift * GUST_MPS2, roll * GUST_ROLL) * intensity

## Lightning strikes between two world times, every cell: [{time, at, cell}].
## Seeded per cell and slot, so every player sees the same bolts.
static func strikes(from: float, to: float) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if not enabled or to <= from: return list
	for slot: int in range(floori(from / STRIKE_SLOT_S), floori(to / STRIKE_SLOT_S) + 1):
		for index: int in CELLS:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = hash([storm_seed, index, slot, "bolt"])
			var when: float = (slot + rng.randf()) * STRIKE_SLOT_S
			if when < from or when >= to: continue
			var storm: Dictionary = cell(index, when)
			if rng.randf() >= storm.strength * STRIKE_CHANCE: continue
			var angle: float = rng.randf() * TAU
			var out: float = sqrt(rng.randf()) * storm.radius * CORE_SHARE
			var spot: Vector3 = storm.center + Vector3(sin(angle), 0.0, cos(angle)) * out
			if shelter(spot) <= 0.0: continue
			list.append({"time": when, "at": wrapped(spot), "cell": index})
	return list

## The strongest raging cell now (or {}), for checks and the soak bot.
static func strongest(time: float = NAN) -> Dictionary:
	var best: Dictionary = {}
	for storm: Dictionary in cells(time):
		if storm.strength > float(best.get("strength", 0.0)): best = storm
	return best

## A spot of open sea inside a raging storm (or Vector3.INF): the cell's
## centre, else the first sheltered-free point on a ring towards its core.
static func stormy_spot(time: float = NAN) -> Vector3:
	var storm: Dictionary = strongest(time)
	if storm.is_empty(): return Vector3.INF
	for step: int in 9:
		var angle: float = step * TAU / 8.0
		var spot: Vector3 = storm.center + (Vector3.ZERO if step == 0 else Vector3(sin(angle), 0.0, cos(angle)) * storm.radius * 0.3)
		if shelter(spot) >= 1.0: return wrapped(spot)
	return Vector3.INF
