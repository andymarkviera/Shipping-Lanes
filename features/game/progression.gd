extends RefCounted
## M3 data for the game: the ships a captain can own and the bulk jobs.
## Prices and pay are in hundredths of a credit. No state lives here.
const PORTS = ["port_brindle_quay", "port_slatewater_works"]
const SHIPS = {
	"container": {"name": "Container ship", "price_minor": 80000},
	"bulk": {"name": "Bulk carrier", "price_minor": 120000},
	"heavy": {"name": "Heavy lifter", "price_minor": 300000},
}
## A sold ship pays back half its price.
const RESALE_PERCENT: int = 50
## Port to port, like container jobs, but better paid. "origin" indexes PORTS.
const BULK_JOBS = {
	"bulk_0_grain": {"title": "Grain, 4,000 t", "origin": 0, "reward_minor": 90000},
	"bulk_0_coal": {"title": "Coal, 5,000 t", "origin": 0, "reward_minor": 120000},
	"bulk_0_ore": {"title": "Iron ore, 6,000 t", "origin": 0, "reward_minor": 150000},
	"bulk_1_grain": {"title": "Grain, 4,000 t", "origin": 1, "reward_minor": 90000},
	"bulk_1_coal": {"title": "Coal, 5,000 t", "origin": 1, "reward_minor": 120000},
	"bulk_1_ore": {"title": "Iron ore, 6,000 t", "origin": 1, "reward_minor": 150000},
}

static func resale_minor(kind: String) -> int:
	return int(SHIPS[kind].price_minor) * RESALE_PERCENT / 100

static func fraction(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(value) and value >= 0 and value <= 1

## The version 4 save fields: spent, ship, fleet, bulk.
static func save_valid(d: Dictionary) -> bool:
	if not d.get("spent") is int or d.spent < 0: return false
	if not d.get("ship") is String or not SHIPS.has(d.ship) or d.get("heavy_mode") != (d.ship == "heavy"): return false
	if not d.get("fleet") is Dictionary or not d.fleet.has(d.ship): return false
	for kind: Variant in d.fleet:
		if not kind is String or not SHIPS.has(kind): return false
		var stored: Variant = d.fleet[kind]
		if not stored is Dictionary or stored.size() != 2 or not fraction(stored.get("fuel")) or not fraction(stored.get("condition")): return false
	var bulk: Variant = d.get("bulk")
	if not bulk is Dictionary or bulk.size() != 2 or not bulk.get("active") is String or not bulk.get("done") is Array: return false
	if bulk.done.size() > BULK_JOBS.size(): return false
	var seen: Dictionary = {}
	for id: Variant in bulk.done:
		if not id is String or not BULK_JOBS.has(id) or seen.has(id): return false
		seen[id] = true
	if not bulk.active.is_empty() and (d.ship != "bulk" or not BULK_JOBS.has(bulk.active) or seen.has(bulk.active)): return false
	return true

## Pay for the delivered bulk jobs. Call only after save_valid.
static func bulk_earned(d: Dictionary) -> int:
	var total: int = 0
	for id: String in d.bulk.done: total += int(BULK_JOBS[id].reward_minor)
	return total
