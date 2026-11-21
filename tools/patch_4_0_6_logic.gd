extends RefCounted
## Patch 4.0.6 scene-free checks (issue #232). check_catalog.gd runs them in
## the Checks job; tools/patch_4_0_6_check.gd runs them too, plus the game
## scene (a ship and a plane in a real storm, the look, the globe).
## - storms: item 1's rules (features/sky/storms.gd): seeded, shared, moving
##   cells; sheltered harbours; the slow-down, the hull wear and its floor;
##   the swell; the lightning; a plane's turbulence.
## The save migration (item 2) is tools/save_migration_logic.gd.
const Storms = preload("res://features/sky/storms.gd")
const Progression = preload("res://features/game/progression.gd")
const Flight = preload("res://features/planes/flight_model.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const Airports = preload("res://features/planes/airports.gd")
const PARTS: Array[String] = ["version", "wrap", "seeded", "always_weather", "harbours", "strength", "effects", "lightning", "turbulence"]
## A fixed world time, so the numbers never depend on the hour the check runs.
const T0: float = 1795300000.0
var failures: Array[String] = []
var checks: int = 0

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

## Runs every check; returns the failed labels (empty when all pass).
static func run_all() -> PackedStringArray:
	var suite: RefCounted = new()
	for part: String in PARTS: suite.call_part(part)
	return suite.failures

func call_part(part: String) -> void:
	var was: bool = Storms.enabled
	var seed_was: int = Storms.storm_seed
	Storms.configure(Storms.DEFAULT_SEED, true)
	call(part)
	Storms.configure(seed_was, was)

func version() -> void:
	var connection: GDScript = load("res://features/network/play_connection.gd")
	expect(connection.VERSION.naturalnocasecmp_to("4.0.6") >= 0, "VERSION is 4.0.6 or later (%s)" % connection.VERSION)

## storms.gd keeps its own copy of the world's wrap (see its header).
func wrap() -> void:
	expect(is_equal_approx(Storms.WRAP_M, Progression.WRAP_M) and Storms.WRAP_CENTRE.is_equal_approx(Progression.WRAP_CENTRE), "the storms wrap the world as Progression does")
	for at: Vector3 in [Vector3(9000, 0, -7000), Vector3(-6500, 0, 6400), Vector3(12, 0, 3)]:
		expect(Storms.wrapped(at).is_equal_approx(Progression.wrapped(at)), "wrapped(%s) matches" % at)

## The same seed and clock give the same storms (every captain); another seed
## gives others; a storm drifts with its own velocity.
func seeded() -> void:
	Storms.configure(Storms.DEFAULT_SEED, true)
	var first: Array[Dictionary] = Storms.cells(T0)
	expect(first.size() == Storms.CELLS, "%d cells" % Storms.CELLS)
	expect(str(first) == str(Storms.cells(T0)), "the same seed and time give the same storms")
	var moved: int = 0
	for storm: Dictionary in first:
		expect(storm.radius >= Storms.RADIUS_MIN_M and storm.radius <= Storms.RADIUS_MAX_M, "cell %d's radius is in range (%.0f m)" % [storm.index, storm.radius])
		var later: Dictionary = Storms.cell(storm.index, T0 + 60.0)
		if later.life != storm.life: continue
		var step: Vector3 = Storms.short_way(later.center - storm.center)
		if step.is_equal_approx(Storms.short_way(storm.velocity * 60.0)) and step.length() > 200.0: moved += 1
	expect(moved >= 3, "the storms drift (%d of %d moved by their velocity in a minute)" % [moved, first.size()])
	Storms.configure(77, true)
	expect(str(Storms.cells(T0)) != str(first), "another seed gives other storms")
	Storms.configure(Storms.DEFAULT_SEED, true)
	expect(str(Storms.cells(T0)) == str(first), "back to the seed, back to the same storms")

## Over two whole lives there is always a storm raging somewhere, and storms
## cover some of the sea but never most of it.
func always_weather() -> void:
	var calm_moments: int = 0
	var stormy: int = 0
	var samples: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	for step: int in 60:
		var time: float = T0 + step * Storms.LIFE_SECONDS * 2.0 / 60.0
		if float(Storms.strongest(time).get("strength", 0.0)) < 0.5: calm_moments += 1
		for probe: int in 40:
			var at: Vector3 = Storms.WRAP_CENTRE + Vector3(rng.randf_range(-0.5, 0.5) * Storms.WRAP_M, 0, rng.randf_range(-0.5, 0.5) * Storms.WRAP_M)
			samples += 1
			if Storms.intensity_at(at, time) > 0.1: stormy += 1
	expect(calm_moments == 0, "a storm is always raging somewhere (%d calm moments)" % calm_moments)
	var share: float = float(stormy) / samples
	expect(share > 0.02 and share < 0.4, "storms cover some of the sea, not most (%.1f %%)" % (share * 100.0))

## Harbours are sheltered: no storm at any port, ever.
func harbours() -> void:
	var worst: float = 0.0
	for step: int in 40:
		var time: float = T0 + step * 75.0
		for place: Dictionary in Progression.WORLD: worst = maxf(worst, Storms.intensity_at(place.at, time))
	expect(worst == 0.0, "no storm at any port (worst %.2f)" % worst)
	expect(Storms.shelter(Progression.WORLD[0].at) == 0.0 and Storms.shelter(Progression.WORLD[0].at + Vector3(Storms.CALM_FADE_M + 10, 0, 0)) >= 0.0, "the harbour shelter")

## Strongest at the core, nothing outside the cell, nothing when off.
func strength() -> void:
	var spot: Vector3 = Storms.stormy_spot(T0)
	if not expect(spot != Vector3.INF, "a raging storm has open sea in it"): return
	var storm: Dictionary = Storms.strongest(T0)
	expect(Storms.intensity_at(spot, T0) >= 0.45, "inside it the storm is strong (%.2f)" % Storms.intensity_at(spot, T0))
	var out: Vector3 = storm.center + Vector3(storm.radius + 50.0, 0, 0)
	var other: float = 0.0
	for cell: Dictionary in Storms.cells(T0):
		if cell.index == storm.index or cell.strength <= 0.0: continue
		if Vector2(Storms.short_way(out - cell.center).x, Storms.short_way(out - cell.center).z).length() < cell.radius: other = 1.0
	if other == 0.0: expect(Storms.intensity_at(out, T0) == 0.0, "past its edge it is calm")
	Storms.enabled = false
	expect(Storms.intensity_at(spot, T0) == 0.0 and Storms.strikes(T0, T0 + 600.0).is_empty(), "storms off: no storm and no lightning")
	Storms.enabled = true

## The slow-down, the mild wear and its floor, the swell.
func effects() -> void:
	expect(Storms.speed_factor(0.0) == 1.0 and is_equal_approx(Storms.speed_factor(1.0), Storms.SLOW_AT_FULL) and Storms.speed_factor(0.5) < 1.0 and Storms.speed_factor(0.5) > Storms.SLOW_AT_FULL, "a storm slows the boat, more the stronger it is")
	expect(is_equal_approx(Storms.worn(1.0, 1.0, 60.0), 0.97), "a minute in a full storm wears 3 %% of the hull (%.3f)" % Storms.worn(1.0, 1.0, 60.0))
	expect(Storms.worn(1.0, 0.0, 60.0) == 1.0, "no storm, no wear")
	expect(is_equal_approx(Storms.worn(0.36, 1.0, 3600.0), Storms.WEAR_FLOOR), "an hour in a storm stops at the floor (%.2f)" % Storms.worn(0.36, 1.0, 3600.0))
	expect(Storms.worn(0.2, 1.0, 60.0) == 0.2, "a hull already below the floor is not worn further")
	expect(Storms.WEAR_FLOOR > 0.0, "a storm never sinks a ship")
	expect(Storms.swell_scale(0.0) == 1.0 and Storms.swell_scale(1.0) > 2.0, "the swell is bigger in a storm")
	Storms.swell = 2.0
	var tall: float = OceanPresentation.swell_height(10.0, 20.0, 3.0, 1)
	Storms.swell = 1.0
	expect(is_equal_approx(tall, OceanPresentation.swell_height(10.0, 20.0, 3.0, 1) * 2.0), "the hulls' swell (swell_height) rides the storm's")

## The bolts are seeded: the same for everyone, inside raging storms only.
func lightning() -> void:
	var bolts: Array[Dictionary] = Storms.strikes(T0, T0 + 600.0)
	expect(bolts.size() >= 10, "ten minutes of storms strike lightning (%d bolts)" % bolts.size())
	expect(str(bolts) == str(Storms.strikes(T0, T0 + 600.0)), "the same bolts for every captain")
	var split: Array[Dictionary] = Storms.strikes(T0, T0 + 300.0)
	split.append_array(Storms.strikes(T0 + 300.0, T0 + 600.0))
	expect(split.size() == bolts.size(), "split windows find the same bolts (%d, %d)" % [split.size(), bolts.size()])
	var stray: int = 0
	for bolt: Dictionary in bolts:
		var storm: Dictionary = Storms.cell(bolt.cell, bolt.time)
		var way: Vector3 = Storms.short_way(bolt.at - storm.center)
		if storm.strength <= 0.0 or Vector2(way.x, way.z).length() > storm.radius or Storms.shelter(bolt.at) <= 0.0: stray += 1
	expect(stray == 0, "every bolt is inside a raging storm, off the harbours (%d stray)" % stray)

## A plane cruising into a storm is bumped (turbulence), and not in calm air.
func turbulence() -> void:
	var spot: Vector3 = Storms.stormy_spot()
	if not expect(spot != Vector3.INF, "a storm now for the plane"): return
	var tracks: Array = []
	for on: bool in [false, true]:
		Storms.enabled = on
		var m: RefCounted = Flight.make("plane_turboprop", Airports.start_pose(0))
		m.on_ground = false
		m.position = spot + Vector3(0, 1500, 0)
		m.basis = Basis(Vector3.UP, 0.4)
		m.velocity = m.basis.z * Planes.stall_speed("plane_turboprop") * 2.0
		m.engine = 0.7
		m.gear_down = false
		m.agl_m = 1500.0
		var most: float = 0.0
		var climbs: PackedFloat32Array = PackedFloat32Array()
		for frame: int in 300:
			m.step({"throttle": 0.7, "pitch": 0.0, "roll": 0.0, "trick": 0.0}, 1.0 / 60.0)
			most = maxf(most, m.turbulence)
			climbs.append(m.velocity.y)
		tracks.append({"most": most, "climbs": climbs, "crashed": m.crashed})
	Storms.enabled = true
	expect(tracks[0].most == 0.0, "calm air: no turbulence")
	expect(tracks[1].most > 0.3, "in the storm the plane meets turbulence (%.2f)" % tracks[1].most)
	var apart: float = 0.0
	for index: int in tracks[0].climbs.size(): apart = maxf(apart, absf(tracks[0].climbs[index] - tracks[1].climbs[index]))
	expect(apart > 0.3, "the gusts move the plane up and down (%.2f m/s apart)" % apart)
	expect(not tracks[1].crashed, "the turbulence does not crash a cruising plane")
