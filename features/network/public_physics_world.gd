extends Node
## Nearby server hulls share real collision spaces. Distant groups retain local precision.
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")
const LINK_M: float = 250.0
const REBASE_M: float = 500.0
const Ports = preload("res://features/network/public_port_catalog.gd")
var spaces: Dictionary = {}
var changed_frame: int = -1

func can_place(owner: Node3D, others: Array) -> bool:
	if owner.recovery_required(): return true # Inert wreck can always enter to request recovery.
	var address: Dictionary = owner.current_address()
	if not Ports.spawn_clear(address, owner.ship.definition.hull_size_m): return false
	var size: Vector3 = owner.ship.definition.hull_size_m
	var radius: float = Vector2(size.x, size.z).length() * 0.5
	for other: Node3D in others:
		if other == owner or other.recovery_required(): continue
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
			spaces[key] = {"viewport": viewport, "origin": origin.duplicate(), "ports": {}}
		elif Nav.separation(spaces[key].origin, origin) > REBASE_M:
			spaces[key].origin = origin.duplicate()
			remap = true
		if remap:
			changed_frame = Engine.get_physics_frames()
			sync_ports(spaces[key])
			for id: int in group:
				var owner: Node3D = states[id].owner
				if owner.get_parent() != spaces[key].viewport: owner.reparent(spaces[key].viewport, false)
				owner.reframe(spaces[key].origin, states[id].address)
	for key: String in spaces.keys():
		if not used.has(key):
			# Departing owners must be detached by the session before sync.
			spaces[key].viewport.queue_free()
			spaces.erase(key)

func sync_ports(space: Dictionary) -> void:
	for id: String in Ports.IDS:
		if Nav.separation(space.origin, Ports.address(id)) > 2500:
			if space.ports.has(id):
				space.ports[id].queue_free()
				space.ports.erase(id)
			continue
		if not space.ports.has(id):
			var port: Node3D = Ports.SCENES[Ports.IDS.find(id)].instantiate()
			space.viewport.add_child(port)
			space.ports[id] = port
		space.ports[id].transform = Ports.pose(space.origin, id)

func port_for(owner: Node3D, id: String) -> Node3D:
	for space: Dictionary in spaces.values():
		if owner.get_parent() == space.viewport: return space.ports.get(id)
	return null

func nearest_port(owner: Node3D) -> Node3D:
	var nearest: Node3D
	var distance_: float = 150.0
	for id: String in Ports.IDS:
		var port: Node3D = port_for(owner, id)
		if port == null: continue
		var meters: float = owner.ship.global_position.distance_to(port.berth_anchor.global_position)
		if meters < distance_:
			nearest = port
			distance_ = meters
	return nearest
