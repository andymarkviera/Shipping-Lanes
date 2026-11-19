extends RefCounted
## Shared local-chart interest grid. Full relevant sets make exits explicit.
const CELL_M: float = 350.0
var cells: Dictionary = {}
var positions: Dictionary = {}

func rebuild(next_positions: Dictionary) -> void:
	positions = next_positions
	cells.clear()
	for id: int in positions:
		var key: Vector2i = cell(positions[id])
		if not cells.has(key): cells[key] = []
		cells[key].append(id)

func cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / CELL_M), floori(position.z / CELL_M))

func relevant(owner: int) -> Array[int]:
	var result: Array[int] = []
	if not positions.has(owner): return result
	var center: Vector3 = positions[owner]
	var key: Vector2i = cell(center)
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			for id: int in cells.get(key + Vector2i(x, z), []):
				if center.distance_squared_to(positions[id]) <= CELL_M * CELL_M: result.append(id)
	result.sort()
	return result

# Patch 3.0.1 item 3: ships outside a captain's relevant set still appear on the
# maps, but their motion is sent at a quarter of the near rate (5 Hz at 20 Hz).
const FAR_EVERY: int = 4

## Whether `peer`'s motion belongs in this tick's frame. Far ships are staggered
## by peer so a full server never sends every far ship on the same tick.
static func due(near: bool, tick: int, peer: int) -> bool:
	return near or (tick + peer) % FAR_EVERY == 0

## Seam-aware: the world wraps, so measure the short way round.
static func near(a: Vector3, b: Vector3) -> bool:
	return preload("res://features/game/progression.gd").short_way(a - b).length_squared() <= CELL_M * CELL_M
