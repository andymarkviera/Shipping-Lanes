extends RefCounted
## Patch 2.1 item 4: who holds which berth. One ship per berth, one berth per
## ship. This object is the only judge; the docking authority asks it and never
## writes the table itself. Single-player keeps it local. A future server can
## own the table and hand the game an object with the same four calls (holder,
## claim, release, release_owner); nothing else needs to change.
var holders: Dictionary = {} # "port_id/berth_id" -> owner id (> 0)

static func key(port_id: String, berth_id: String) -> String:
	return port_id + "/" + berth_id

## 0 when the berth is free.
func holder(berth_key: String) -> int:
	return int(holders.get(berth_key, 0))

## True when the owner now holds the berth. A berth held by someone else is
## refused. Claiming a berth gives up any other berth the owner held.
func claim(berth_key: String, owner: int) -> bool:
	if owner <= 0 or berth_key.is_empty(): return false
	var current: int = holder(berth_key)
	if current != 0 and current != owner: return false
	release_owner(owner)
	holders[berth_key] = owner
	return true

func release(berth_key: String, owner: int) -> void:
	if holder(berth_key) == owner: holders.erase(berth_key)

func release_owner(owner: int) -> void:
	for berth_key: String in holders.keys():
		if holders[berth_key] == owner: holders.erase(berth_key)
