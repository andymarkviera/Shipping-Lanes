extends RefCounted
## Patch 4.0.7 item 4 (Andy, issue #234): the Jetty hovers over land. The
## rules only (no nodes), so the server (the authority), the client's own
## prediction and the checks all run the same code.
##
## Only the Jetty: land, the polar ice and the icebergs are put in the
## PASSABLE group by the game scene, and a Jetty hull takes a collision
## exception with every body in it (HandlingShip.pass_over_land). Instead of
## those boxes the hull meets the shared terrain (features/planes/terrain.gd,
## baked data, the same on the client and the server):
## - it rides over ground, ice and water, the hull's origin following the
##   ground height (ground_height: the terrain, never below the sea) with a
##   smooth climb and settle (follow_height), so its keel stays about RIDE_M
##   clear (ShipVisualMotion lifts the hull by HOVER_REST_M);
## - a rise steeper than SLOPE_LIMIT_DEG stops it (cliffs, the ice cliffs,
##   the icebergs' flanks and mountains still block): blocked_step();
## - it cannot enter the grounds round a port's quay (its buildings and
##   cranes stand there, and no docking from land), PORT_GROUNDS_M from the
##   quay line, nor a runway or its airfield while a plane uses it
##   (mark_runway_busy, from the planes' authority tick);
## - the volcano's cone and the bridges' piers are not in the group: they
##   still collide as solid bodies, as do the ports' quays and sheds.
## The hull's height is in its position, which the server replicates.
const Terrain = preload("res://features/planes/terrain.gd")
const Progression = preload("res://features/game/progression.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
## The group of solid bodies a Jetty passes over (land, ice, icebergs).
const PASSABLE: String = "jetty_passable"
## Keel clearance over the ground (the hover lift gives it, see header).
const RIDE_M: float = 1.5
const SLOPE_LIMIT_DEG: float = 35.0
## The path of one step is sampled every SAMPLE_M metres (at most MAX_SAMPLES).
const SAMPLE_M: float = 2.0
const MAX_SAMPLES: int = 32
## A rise of up to this is never a slope (the sea's edge, rounding).
const STEP_TOLERANCE_M: float = 0.25
## The height follows the ground ahead (LOOKAHEAD_S of travel), climbing at
## CLIMB_RATE and settling at SETTLE_RATE (1 / seconds), never below it.
const LOOKAHEAD_S: float = 0.15
const CLIMB_RATE: float = 20.0
const SETTLE_RATE: float = 12.0
## Land within this of a port's quay line (TOON_COAST's harbour) is port ground.
const PORT_GROUNDS_M: float = 260.0
## Above the sea by more than this, the Jetty is over land (or ice).
const LAND_M: float = 0.05
## A runway stays in use this long after a plane was last on or over it.
const RUNWAY_BUSY_S: float = 5.0
## Airport index -> Time.get_ticks_msec() until which its runway is in use.
static var busy_runways: Dictionary = {}

## The height the Jetty rides on at a point: the terrain, the sea at 0.
static func ground_height(at: Vector3) -> float:
	return maxf(Terrain.height_at(at), 0.0)

## "water", "land", "ice", "rock", "runway" or "airfield": what is under it.
static func surface(at: Vector3) -> String:
	var below: Dictionary = Terrain.sample(at)
	if float(below.height) <= LAND_M: return "water"
	return str(below.surface)

static func over_land(at: Vector3) -> bool:
	return ground_height(at) > LAND_M

## A plane is on, or about to use, airport `index`'s runway.
static func mark_runway_busy(index: int) -> void:
	if index >= 0: busy_runways[index] = Time.get_ticks_msec() + int(RUNWAY_BUSY_S * 1000.0)

static func runway_busy(index: int) -> bool:
	return index >= 0 and int(busy_runways.get(index, 0)) > Time.get_ticks_msec()

## The planes' authority: a plane on the ground at an airfield, or low on a
## final approach, holds that airport's runway.
static func note_plane(model: RefCounted, airport: int) -> void:
	if model == null or model.crashed: return
	if model.on_ground and float(model.velocity.length()) > 0.5:
		var below: Dictionary = Terrain.sample(model.position)
		if below.surface == "runway": mark_runway_busy(int(below.runway))
		elif below.surface == "airfield": mark_runway_busy(int(below.get("airport", -1)))
		return
	if not model.on_ground:
		var final: Dictionary = model.final_approach()
		if not final.is_empty(): mark_runway_busy(int(final.airport))
		elif float(model.agl_m) < 60.0: mark_runway_busy(airport)

## Port ground: land within PORT_GROUNDS_M of a port's quay line.
static func port_ground(at: Vector3) -> bool:
	var spot: Vector3 = Progression.wrapped(Vector3(at.x, 0, at.z))
	var flat: Vector2 = Vector2(spot.x, spot.z)
	for place: Dictionary in Progression.WORLD:
		var port: Vector2 = Vector2(place.at.x, place.at.z)
		var nearest: Vector2 = Vector2(port.x, clampf(flat.y, port.y - 60.0, port.y + 1000.0))
		if flat.distance_to(nearest) < PORT_GROUNDS_M: return true
	return false

## Why the Jetty may not move from `from` to `to` (only X and Z count), or ""
## when it may: "slope" (a rise steeper than SLOPE_LIMIT_DEG somewhere on the
## way), "port" (onto a port's grounds from land) or "runway" (a runway in use).
static func blocked_step(from: Vector3, to: Vector3) -> String:
	var travel: Vector3 = Vector3(to.x - from.x, 0, to.z - from.z)
	var distance: float = travel.length()
	if distance < 0.0001: return ""
	var count: int = clampi(ceili(distance / SAMPLE_M), 1, MAX_SAMPLES)
	var segment: float = distance / count
	var steep: float = tan(deg_to_rad(SLOPE_LIMIT_DEG))
	var previous: float = ground_height(from)
	# (Already on port ground or a busy airfield, e.g. loaded there: it may leave.)
	var inside_port: bool = previous > LAND_M and port_ground(from)
	var start: Dictionary = Terrain.sample(from)
	# On a runway already (it may leave it), or on an airport's airfield.
	var on_runway: int = int(start.runway) if start.surface == "runway" else -1
	var on_field: int = on_runway if on_runway >= 0 else int(start.get("airport", -1))
	for index: int in range(1, count + 1):
		var at: Vector3 = from + travel * (float(index) / count)
		var below: Dictionary = Terrain.sample(at)
		var height: float = maxf(float(below.height), 0.0)
		if height - previous > steep * segment + STEP_TOLERANCE_M: return "slope"
		# Onto a runway in use (from its own airfield too), or onto the
		# airfield of an airport whose runway is in use.
		if below.surface == "runway" and int(below.runway) != on_runway and runway_busy(int(below.runway)): return "runway"
		if below.surface == "airfield" and int(below.airport) != on_field and runway_busy(int(below.airport)): return "runway"
		if not inside_port and height > LAND_M and port_ground(at): return "port"
		previous = height
	return ""

## The next height of the hull's origin, `height` now, moving `travel`
## (metres this step, X and Z) in `delta` seconds: it climbs to the ground
## ahead quickly, settles gently, and is never under the ground below it.
static func follow_height(at: Vector3, height: float, travel: Vector3, delta: float) -> float:
	var next: Vector3 = Vector3(at.x + travel.x, 0, at.z + travel.z)
	var below: float = ground_height(next)
	var ahead: float = below
	if delta > 0.0: ahead = maxf(below, ground_height(next + Vector3(travel.x, 0, travel.z) / delta * LOOKAHEAD_S))
	var rate: float = CLIMB_RATE if ahead > height else SETTLE_RATE
	var eased: float = lerpf(height, ahead, 1.0 - exp(-rate * maxf(delta, 0.0)))
	return maxf(eased, below)
