extends Node
## Nearby server hulls share real collision spaces. Distant groups retain local precision.
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")
const LINK_M: float = 250.0
const REBASE_M: float = 500.0
var spaces: Dictionary = {}

func can_place(owner: Node3D, others: Array) -> bool:
	var address: Dictionary = owner.current_address()
	var size: Vector3 = owner.ship.definition.hull_size_m
	var radius: float = Vector2(size.x, size.z).length() * 0.5
	for other: Node3D in others:
		var other_size: Vector3 = other.ship.definition.hull_size_m
		var clearance: float = radius + Vector2(other_size.x, other_size.z).length() * 0.5 + 2.0
		if Nav.separation(address, other.current_address()) < clearance: return false
	return true

func sync(owners: Array) -> void:
	# Called before hull physics. Capture all canonical states before any reparenting.
	var states: Dictionary = {}
	for owner: Node3D in owners:
		states[owner.get_instance_id()] = {"owner": owner, "address": owner.current_address()}
	var remaining: Array = states.keys()
	remaining.sort()
	var used: Dictionary = {}
	while not remaining.is_empty():
		var group: Array = [remaining.pop_front()]
		var cursor: int = 0
		while cursor < group.size():
			for id: int in remaining.duplicate():
				if Nav.separation(states[group[cursor]].address, states[id].address) <= LINK_M:
					group.append(id)
					remaining.erase(id)
			cursor += 1
		group.sort()
		var key: String = str(group)
		used[key] = true
		var origin: Dictionary = states[group[0]].address
		var remap: bool = not spaces.has(key)
		if remap:
			var viewport: SubViewport = SubViewport.new()
			viewport.own_world_3d = true
			add_child(viewport)
			spaces[key] = {"viewport": viewport, "origin": origin.duplicate()}
		elif Nav.separation(spaces[key].origin, origin) > REBASE_M:
			spaces[key].origin = origin.duplicate()
			remap = true
		if remap:
			for id: int in group:
				var owner: Node3D = states[id].owner
				if owner.get_parent() != spaces[key].viewport: owner.reparent(spaces[key].viewport, false)
				owner.reframe(spaces[key].origin, states[id].address)
	for key: String in spaces.keys():
		if not used.has(key):
			# Departing owners must be detached by the session before sync.
			spaces[key].viewport.queue_free()
			spaces.erase(key)
