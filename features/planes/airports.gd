extends RefCounted
## Patch 4.0 item 8: the airports. As many as there are ports, placed from one
## fixed seed on coastal land: each runway lies along the coast, every part of
## it on land (BAND_M metres inland: past the beach, never far up country),
## clear of every port and its approach, the polar ice, the city, the volcano,
## the straits' bridges and each other. The strip stands on a level airfield
## embankment at RUNWAY_Y, just above the tallest green hill (TOON_COAST). Everything comes from baked data (the land grid, the ice grid,
## Progression.WORLD) and the fixed seed, so client and server work out the
## same airports. Built once and cached. No state lives here.
const Progression = preload("res://features/game/progression.gd")
const CITY_LOOK = preload("res://features/toon/city_look.gd")
const SEED: int = 40400
const RUNWAY_M: float = 1100.0
const RUNWAY_WIDTH_M: float = 34.0
## The runway's surface height: just above the green hills' tops (18 m).
const RUNWAY_Y: float = 19.5
## Every runway sample (centre and both edges) lies this far inland: on dry
## land, and the middle within a few hundred metres of the coast.
const BAND_M: Vector2 = Vector2(24.0, 700.0)
const MIDDLE_INLAND_M: float = 320.0
const PORT_CLEAR_M: float = 1100.0
const AIRPORT_CLEAR_M: float = 1800.0
const ICE_CLEAR_M: float = 250.0
## Patch 4.0.1 item 7: the airfield, the flat, cleared footprint of an airport
## (runway, apron, terminal and tower, plus a margin): FIELD_END_M past each
## runway end, FIELD_SEA_M beyond the seaward edge and FIELD_LAND_M beyond the
## inland edge (where the apron and terminal stand). Terrain.sample is level
## at RUNWAY_Y over all of it (no hill pokes through), and plane_look draws it
## as one grass embankment with the tarmac on top.
const FIELD_END_M: float = 60.0
const FIELD_SEA_M: float = 30.0
const FIELD_LAND_M: float = 95.0
const NAMES: Array[String] = ["Brindle Field", "Slatewater Air", "Cinder Strip", "Gannet Aerodrome", "Ironreach Airfield", "Hearth Point Airport", "Kelp Field", "Ember Airstrip"]
## Patch 4.0.3 item 8: the seed places the first SEEDED airports, as it
## always did (so the others stay exactly where they were); then the FIXED
## ones replace theirs. Andy moved two onto the polar ice caps, near the
## poles: Cinder Strip (north) and Gannet Aerodrome, now South Runway (the
## south cap's centre). Each keeps its index and ID, so saved planes, jobs
## and job IDs still point at it (a plane saved there starts on the new
## runway; a job to it is flown to the new place). On the globe the world's
## north/south edge is the pole, so a polar runway lies east-west
## POLE_RUNWAY_M from it, on the level snow round the pole (PolarIce.relief
## fades out there), its surface POLAR_RUNWAY_Y: a hand above the cap's
## plateau (PolarIce.PLATEAU_Y, 46 m), so the snowfield under it is a thin
## step, like the grass round the others. `side`: which side of the runway
## the terminal stands (away from the pole).
const SEEDED: int = 6
const POLE_RUNWAY_M: float = 300.0
const POLAR_RUNWAY_Y: float = 46.6
## Patch 4.0.3 item 7: and Point Nemo's runway (the seventh airport, one per
## port), along its main islet (tools/world_layout/point_nemo.py), west of
## it the port, at the land runways' height.
const FIXED: Dictionary = {
	2: {"name": "Cinder Strip", "x": 4400.0, "pole": 1.0, "heading": PI / 2.0, "side": 1.0},
	3: {"name": "South Runway", "x": -250.0, "pole": -1.0, "heading": PI / 2.0, "side": -1.0},
	6: {"name": "Point Nemo", "x": 6550.0, "z": -1610.0, "heading": 0.0, "side": -1.0},
}
## Patch 4.0.3 item 8: where the two moved airports stood before (their
## runway middles), for the save checks and the history.
const MOVED_FROM: Dictionary = {2: Vector3(3322.917, 19.5, -2200.0), 3: Vector3(-250.0, 19.5, -3410.714)}
static var _cache: Array[Dictionary] = []

static func count() -> int:
	return Progression.WORLD.size()

## Patch 4.0.3 item 8: `position` seen from `at` (a point inside the world,
## like an airport's), for planes and airports: round the world east-west,
## but never across the north/south edge (that is the pole; a plane flying
## over it comes back on the same side, FlightModel.cross_pole). The same as
## Progression.short_way everywhere but near the poles.
static func local_to(at: Vector3, position: Vector3) -> Vector3:
	var step: Vector3 = Progression.wrapped(position) - at
	step.x = wrapf(step.x, -Progression.WRAP_M / 2, Progression.WRAP_M / 2)
	return step

## Whether airport `index` stands on a polar ice cap (a snow runway).
static func polar(index: int) -> bool:
	return bool(all()[index].get("polar", false))

## [{id, name, at (runway middle, Vector3 at RUNWAY_Y), heading (radians, +Z
## turned towards +X), length, width, terminal (Vector3), side (+1 or -1: the
## inland side along the runway's across axis, (cos heading, -sin heading))}],
## one per port.
static func all() -> Array[Dictionary]:
	if not _cache.is_empty(): return _cache
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var ring: Array[Vector2] = Progression.coast_ring(110.0, 60.0)
	var placed: Array[Dictionary] = []
	if ring.is_empty(): return _cache
	var tries: int = 0
	while placed.size() < mini(count(), SEEDED) and tries < 6000:
		tries += 1
		var spot: Vector2 = ring[rng.randi_range(0, ring.size() - 1)]
		var heading: float = coast_heading(spot)
		if is_nan(heading): continue
		heading += rng.randf_range(-0.06, 0.06)
		if not site_ok(spot, heading, placed): continue
		var along: Vector2 = Vector2(sin(heading), cos(heading))
		var inland: Vector2 = land_side(spot, along)
		var terminal: Vector2 = spot + inland * (RUNWAY_WIDTH_M * 0.5 + 34.0) + along * 120.0
		var side: float = 1.0 if Vector2(cos(heading), -sin(heading)).dot(inland) > 0.0 else -1.0
		placed.append({"id": "airport_%d" % placed.size(), "name": NAMES[placed.size() % NAMES.size()], "at": Vector3(spot.x, RUNWAY_Y, spot.y),
			"heading": heading, "length": RUNWAY_M, "width": RUNWAY_WIDTH_M, "terminal": Vector3(terminal.x, RUNWAY_Y, terminal.y), "side": side})
	for index: int in FIXED:
		if index < placed.size(): placed[index] = fixed_entry(index)
	for index: int in range(placed.size(), count()):
		if FIXED.has(index): placed.append(fixed_entry(index))
	_cache = placed
	return _cache

## Patch 4.0.3 item 8: a FIXED airport's entry, like a seeded one.
static func fixed_entry(index: int) -> Dictionary:
	var spec: Dictionary = FIXED[index]
	var polar_cap: bool = spec.has("pole")
	var edge: float = Progression.WRAP_CENTRE.z + float(spec.get("pole", 0.0)) * Progression.WRAP_M / 2.0
	var spot: Vector2 = Vector2(float(spec.x), edge - float(spec.pole) * POLE_RUNWAY_M) if polar_cap else Vector2(float(spec.x), float(spec.z))
	var height: float = POLAR_RUNWAY_Y if polar_cap else RUNWAY_Y
	var heading: float = float(spec.heading)
	var along: Vector2 = Vector2(sin(heading), cos(heading))
	var inland: Vector2 = Vector2(cos(heading), -sin(heading)) * float(spec.side)
	var terminal: Vector2 = spot + inland * (RUNWAY_WIDTH_M * 0.5 + 34.0) + along * 120.0
	return {"id": "airport_%d" % index, "name": str(spec.name), "at": Vector3(spot.x, height, spot.y), "heading": heading,
		"length": RUNWAY_M, "width": RUNWAY_WIDTH_M, "terminal": Vector3(terminal.x, height, terminal.y), "side": float(spec.side), "polar": polar_cap}

## The coast's direction at a spot: perpendicular to the land depth's slope.
static func coast_heading(spot: Vector2) -> float:
	var step: float = 20.0
	var slope: Vector2 = Vector2(Progression.land_depth(spot + Vector2(step, 0)) - Progression.land_depth(spot - Vector2(step, 0)),
		Progression.land_depth(spot + Vector2(0, step)) - Progression.land_depth(spot - Vector2(0, step)))
	if slope.length() < 0.5: return NAN
	var tangent: Vector2 = Vector2(-slope.y, slope.x).normalized()
	return atan2(tangent.x, tangent.y)

## The unit side of the runway that faces inland.
static func land_side(spot: Vector2, along: Vector2) -> Vector2:
	var side: Vector2 = Vector2(along.y, -along.x)
	return side if Progression.land_depth(spot + side * 60.0) > Progression.land_depth(spot - side * 60.0) else -side

## Whether a runway centred at `spot` along `heading` fits: level beach all
## along both edges and the middle, away from ports, ice, the volcano, bridges
## and the airports already placed.
static func site_ok(spot: Vector2, heading: float, placed: Array[Dictionary]) -> bool:
	for index: int in Progression.WORLD.size():
		var port: Vector3 = Progression.WORLD[index].at
		if spot.distance_to(Vector2(port.x, port.z)) < PORT_CLEAR_M or spot.distance_to(Vector2(port.x, port.z + 500.0)) < PORT_CLEAR_M: return false
		var gate: Vector3 = Progression.gate(index)
		if spot.distance_to(Vector2(gate.x, gate.z)) < PORT_CLEAR_M: return false
	for other: Dictionary in placed:
		if Progression.short_way(Vector3(spot.x, 0, spot.y) - other.at).length() < AIRPORT_CLEAR_M: return false
	if spot.distance_to(Progression.VOLCANO.at) < 900.0: return false
	if Progression.land_depth(spot) > MIDDLE_INLAND_M: return false
	if CITY_LOOK.is_city(Rect2(spot - Vector2(450, 450), Vector2(900, 900))): return false
	for bridge: Dictionary in Progression.BRIDGES:
		if spot.distance_to(bridge.at) < 900.0: return false
	var along: Vector2 = Vector2(sin(heading), cos(heading))
	var side: Vector2 = Vector2(along.y, -along.x)
	var steps: int = 24
	for index: int in steps + 1:
		var at: Vector2 = spot + along * RUNWAY_M * (float(index) / steps - 0.5)
		for offset: float in [-0.5, 0.0, 0.5]:
			var sample: Vector2 = at + side * RUNWAY_WIDTH_M * offset
			var depth: float = Progression.land_depth(sample)
			if depth < BAND_M.x or depth > BAND_M.y: return false
			if Progression.ice_depth(sample) > -ICE_CLEAR_M: return false
	return true

## The airport nearest a world position (the short way round), or -1.
static func nearest(position: Vector3) -> int:
	var best: int = -1
	var best_distance: float = INF
	var list: Array[Dictionary] = all()
	for index: int in list.size():
		var distance: float = local_to(list[index].at, position).length()
		if distance < best_distance:
			best_distance = distance
			best = index
	return best

## Metres from a position to an airport's runway middle, the short way round.
static func distance_to(index: int, position: Vector3) -> float:
	var flat: Vector3 = local_to(all()[index].at, position)
	flat.y = 0.0
	return flat.length()

## Whether a world X/Z lies on airport `index`'s runway (in its rectangle).
static func on_runway(index: int, position: Vector3, margin: float = 0.0) -> bool:
	var entry: Dictionary = all()[index]
	var local: Vector3 = local_to(entry.at, position)
	var along: float = local.x * sin(entry.heading) + local.z * cos(entry.heading)
	var across: float = local.x * cos(entry.heading) - local.z * sin(entry.heading)
	return absf(along) <= entry.length * 0.5 + margin and absf(across) <= entry.width * 0.5 + margin

## Patch 4.0.1 item 7: the airfield's extent across the runway's axis, in the
## runway's frame: [seaward edge, inland edge] (metres from the centre line,
## positive towards (cos heading, -sin heading)), and along it (half length).
static func field_across(index: int) -> Vector2:
	var entry: Dictionary = all()[index]
	var near: float = entry.width * 0.5 + FIELD_SEA_M
	var far: float = entry.width * 0.5 + FIELD_LAND_M
	return Vector2(-near, far) if float(entry.side) > 0.0 else Vector2(-far, near)

static func field_half_length(index: int) -> float:
	return float(all()[index].length) * 0.5 + FIELD_END_M

## Whether a world X/Z lies on airport `index`'s airfield (its whole footprint).
static func on_airfield(index: int, position: Vector3, margin: float = 0.0) -> bool:
	var entry: Dictionary = all()[index]
	var local: Vector3 = local_to(entry.at, position)
	if absf(local.x) > 2000.0 or absf(local.z) > 2000.0: return false
	var along: float = local.x * sin(entry.heading) + local.z * cos(entry.heading)
	var across: float = local.x * cos(entry.heading) - local.z * sin(entry.heading)
	var span: Vector2 = field_across(index)
	return absf(along) <= field_half_length(index) + margin and across >= span.x - margin and across <= span.y + margin

## Patch 4.0.2 item 4: every decoration layer (dunes, mesas, palms, bushes,
## towers) keeps this far off each airfield, plus its own reach.
const DECOR_CLEAR_M: float = 40.0

## Patch 4.0.2 item 4: whether a decoration centred at `at` (X, Z) that
## reaches `reach` metres from its centre stays off every airfield, with
## DECOR_CLEAR_M to spare. Seeded decoration layers call it, so nothing
## stands on a runway, its apron or its grass, whatever the biome.
static func clear_of_airfields(at: Vector2, reach: float = 0.0) -> bool:
	var spot: Vector3 = Vector3(at.x, 0, at.y)
	for index: int in all().size():
		if on_airfield(index, spot, DECOR_CLEAR_M + maxf(reach, 0.0)): return false
	return true

## Any airfield under a position, or -1.
static func airfield_at(position: Vector3) -> int:
	for index: int in all().size():
		if on_airfield(index, position): return index
	return -1

## Any runway under a position, or -1.
static func runway_at(position: Vector3) -> int:
	for index: int in all().size():
		if on_runway(index, position, 6.0): return index
	return -1

## Where a plane waits at airport `index`: on the runway's near end, lined up
## for take-off along it. Basis: +Z forward (as the ships), +Y up.
static func start_pose(index: int) -> Transform3D:
	var entry: Dictionary = all()[index]
	var along: Vector3 = Vector3(sin(entry.heading), 0, cos(entry.heading))
	var origin: Vector3 = entry.at - along * (entry.length * 0.5 - 60.0)
	return Transform3D(Basis(Vector3.UP, entry.heading), origin)
