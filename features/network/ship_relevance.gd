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
