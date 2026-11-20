extends RefCounted
## Patch 4.0 item 5: captain levels. Every completed delivery (boat or plane)
## earns XP that grows with its pay, more slowly than the pay does, so better
## ships still level faster without making the top levels trivial. Quests can
## award XP through the same award() later (QUEST_XP is the hook; empty today).
## The server is the only authority: it awards XP in the player's simulation
## and stores it in the player's save row ("progress"); clients only show it.
## Everyone, including saves from before 4.0, starts at level 1 with 0 XP.
const MAX_LEVEL: int = 50
## Total XP to reach level L is CURVE_XP * (L - 1) ^ CURVE_POWER: level 2 at
## 300 XP, level 10 at about 15,700. An early starter-ship delivery (about
## 2,900 credits) is worth about 540 XP; with the bigger ships a captain earns
## on the way, level 10 (planes) takes a few hours of normal play.
const CURVE_XP: float = 300.0
const CURVE_POWER: float = 1.8
const XP_PER_SQRT_CREDIT: float = 10.0
## Patch 4.0 item 9: planes unlock at this level.
const PLANE_LEVEL: int = 10
## Hook for later quests: quest ID -> XP. award(progress, QUEST_XP[id], "quest").
const QUEST_XP: Dictionary = {}
const Planes = preload("res://features/planes/plane_catalog.gd")
const Jobs = preload("res://features/planes/plane_jobs.gd")
const Airports = preload("res://features/planes/airports.gd")

## Total XP needed to reach `level` (1 needs none).
static func xp_for_level(level: int) -> int:
	if level <= 1: return 0
	return roundi(CURVE_XP * pow(float(mini(level, MAX_LEVEL) - 1), CURVE_POWER))

## The level a total XP reaches, 1 to MAX_LEVEL.
static func level_for(xp: int) -> int:
	var level: int = 1
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1): level += 1
	return level

## 0..1 of the way from this level to the next (1 at MAX_LEVEL).
static func level_progress(xp: int) -> float:
	var level: int = level_for(xp)
	if level >= MAX_LEVEL: return 1.0
	var low: int = xp_for_level(level)
	return clampf(float(xp - low) / float(maxi(1, xp_for_level(level + 1) - low)), 0.0, 1.0)

## XP for a delivery that paid `pay_minor` (hundredths of a credit).
static func xp_for_pay(pay_minor: int) -> int:
	if pay_minor <= 0: return 0
	return maxi(1, roundi(XP_PER_SQRT_CREDIT * sqrt(pay_minor / 100.0)))

## The one way XP is added: the new total. `source` is "delivery" or "quest".
## Never call it on a client view: only the authority's copy counts.
static func award(xp: int, amount: int, _source: String = "delivery") -> int:
	return mini(maxi(xp, 0) + maxi(amount, 0), 2000000000)

## A fresh progress row: level 1, no planes, sailing a boat.
static func fresh_progress() -> Dictionary:
	return {"xp": 0, "planes": {}, "plane": "", "mode": "boat", "airport": 0, "plane_job": ""}

## Strict check of a stored progress row. Plane kinds and jobs are checked
## against their catalogues (features/planes).
static func progress_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 6: return false
	var d: Dictionary = value
	if not d.get("xp") is int or d.xp < 0 or d.xp > 2000000000: return false
	if not d.get("planes") is Dictionary or d.planes.size() > Planes.PLANES.size(): return false
	for kind: Variant in d.planes:
		if not kind is String or not Planes.PLANES.has(kind): return false
		var stored: Variant = d.planes[kind]
		if not stored is Dictionary or stored.size() != 2: return false
		for key: String in ["fuel", "condition"]:
			var number: Variant = stored.get(key)
			if not (number is float or number is int) or not is_finite(number) or number < 0 or number > 1: return false
	if not d.get("plane") is String or (not d.plane.is_empty() and not d.planes.has(d.plane)): return false
	if d.get("mode") not in ["boat", "plane"] or (d.mode == "plane" and d.plane.is_empty()): return false
	if not d.get("airport") is int or d.airport < 0 or d.airport >= Airports.count(): return false
	if not d.get("plane_job") is String: return false
	if not d.plane_job.is_empty() and (d.mode != "plane" or Jobs.job(d.plane_job).is_empty() or int(Jobs.job(d.plane_job).capacity) > int(Planes.PLANES[d.plane].capacity)): return false
	return true
