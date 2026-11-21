extends RefCounted
## Patch 4.0 item 10/12: what a plane can hit, as a height above the sea at a
## world X/Z. It follows the drawn world: the beach shelf and green hills of
## the land (TOON_COAST), the runways and their airfields (level at
## Airports.RUNWAY_Y, no hill inside an airport's footprint), the polar
## ice cap rising to its snow plateau, the icebergs and the volcano. All from
## baked data, so client and server agree. Sea level is 0.
const Progression = preload("res://features/game/progression.gd")
const TOON_COAST = preload("res://features/toon/toon_coast.gd")
const Airports = preload("res://features/planes/airports.gd")
const ICE_PLATEAU_M: float = 46.0

## {height, surface}: surface is "sea", "land", "runway", "airfield" (the flat
## grass and apron round a runway, Patch 4.0.1), "ice" or "rock".
static func sample(at: Vector3) -> Dictionary:
	var spot: Vector3 = Progression.wrapped(Vector3(at.x, 0, at.z))
	var flat: Vector2 = Vector2(spot.x, spot.z)
	var runway: int = Airports.runway_at(spot)
	if runway >= 0: return {"height": Airports.RUNWAY_Y, "surface": "runway", "runway": runway}
	# Patch 4.0.1 item 7: the airfield around it is level and cleared too.
	var field: int = Airports.airfield_at(spot)
	if field >= 0: return {"height": Airports.RUNWAY_Y, "surface": "airfield", "runway": -1, "airport": field}
	var height: float = 0.0
	var surface: String = "sea"
	var depth: float = Progression.land_depth(flat)
	if depth > 0.0:
		var land: float = maxf(TOON_COAST.sand_height(depth, 0.0), TOON_COAST.hill_height(depth))
		if land > 0.0:
			height = land
			surface = "land"
	var ice: float = Progression.ice_depth(flat)
	if ice > 0.0:
		var top: float = minf(ICE_PLATEAU_M, 9.0 + ice * 0.16)
		if top > height:
			height = top
			surface = "ice"
	for berg: Vector3 in Progression.ICEBERGS:
		var reach: float = Progression.short_way(Vector3(berg.x, 0, berg.z) - spot).length()
		if reach < berg.y:
			var tall: float = berg.y * 0.9 * (1.0 - reach / berg.y * 0.5)
			if tall > height:
				height = tall
				surface = "ice"
	var volcano: Vector2 = Progression.VOLCANO.at
	var base: float = float(Progression.VOLCANO.base_m)
	var from_volcano: float = Vector2(Progression.short_way(Vector3(volcano.x, 0, volcano.y) - spot).x, Progression.short_way(Vector3(volcano.x, 0, volcano.y) - spot).z).length()
	if from_volcano < base:
		var cone: float = 2.0 + float(Progression.VOLCANO.peak_m) * clampf(1.0 - from_volcano / base, 0.0, 1.0)
		if cone > height:
			height = cone
			surface = "rock"
	return {"height": height, "surface": surface, "runway": -1}

static func height_at(at: Vector3) -> float:
	return float(sample(at).height)
