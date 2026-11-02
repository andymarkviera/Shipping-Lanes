extends SceneTree
## Real fleet bridge, hulls, clearance and UI; authority is explicitly an in-memory double.
const Owner = preload("res://features/network/public_ship_owner.gd")
const Fleet = preload("res://features/network/public_fleet_service.gd")
const World = preload("res://features/network/public_physics_world.gd")
var checks: int = 0
var failures: int = 0

class AuthorityDouble extends Node:
	var active: bool = true
	var busy: bool = false
	var snapshot: Dictionary
	var unknown: bool = false
	var calls: Array = []
	func owned(op: String, args: Dictionary = {}) -> Dictionary:
		var result: Dictionary = args.duplicate(true)
		result.op = op
		return result
	func quiesce() -> void: active = false
	func request(args: Dictionary) -> Dictionary:
		calls.append(args.op)
		if args.op == "inspect": return snapshot.duplicate(true)
		if args.op == "checkpoint":
			snapshot.profile.ship.position = args.position.duplicate(true)
			snapshot.profile.ship.fuel_liters = args.fuel_liters
			var fraction: float = snapshot.profile.ship.wear_fraction_bp + args.operating_seconds / 36.0
			snapshot.profile.ship.condition_bp -= int(fraction)
			snapshot.profile.ship.wear_fraction_bp = fraction - int(fraction)
			snapshot.revision += 1
			return {"ok": true, "revision": snapshot.revision, "condition_bp": snapshot.profile.ship.condition_bp}
		if unknown: active = false; return {"ok": false, "code": "OUTCOME_UNKNOWN"}
		var old: Dictionary = snapshot.profile.ship
		for i: int in snapshot.profile.stored_ships.size():
			if snapshot.profile.stored_ships[i].id == args.ship_id:
				var incoming: Dictionary = snapshot.profile.stored_ships.pop_at(i)
				old.storage_port_id = args.port_id
				snapshot.profile.stored_ships.append(old)
				if not incoming.has("position"):
					incoming.position = JSON.parse_string(FileAccess.get_file_as_string("res://services/public_authority/fleet_slots.json"))[args.port_id][args.slot]
				incoming.erase("storage_port_id")
				snapshot.profile.ship = incoming
				snapshot.revision += 1
				return {"ok": true, "code": "FLEET_SWITCHED"}
		return {"ok": false, "code": "SHIP_NOT_STORED"}

class SessionDouble extends Node:
	const Geo = preload("res://features/geography/geographic_address.gd")
	const Nav = preload("res://features/geography/navigation_experiment.gd")
	var members: Dictionary = {}
	var physics_world: Node
	var port_authority: Node
	var voyages: Node
	var changed: int = 0
	func live_owners() -> Array:
		var result: Array = []
		for record: Dictionary in members.values(): result.append(record.hull)
		return result
	func fleet_changed(_peer: int, _record: Dictionary) -> void: changed += 1

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(reason)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var session := SessionDouble.new()
	root.add_child(session)
	var world := World.new()
	session.add_child(world)
	session.physics_world = world
	var ports = preload("res://features/network/public_port_authority.gd").new()
	session.add_child(ports)
	session.port_authority = ports
	var voyages = preload("res://features/network/public_voyage_service.gd").new()
	session.add_child(voyages)
	voyages.set_process(false)
	voyages.session = session
	session.voyages = voyages
	var fleet := Fleet.new()
	session.add_child(fleet)
	fleet.session = session
	var owner := Owner.new()
	session.add_child(owner)
	owner.set_process(false); owner.set_physics_process(false)
	owner.authority.free()
	var authority := AuthorityDouble.new()
	owner.add_child(authority)
	owner.authority = authority
	var initial: Dictionary = {"id": "old", "definition": "ship_starter_container_01", "condition_bp": 7654, "wear_fraction_bp": 0.75, "fuel_liters": 123.25, "position": {"latitude": rad_to_deg(70.0 / 100000.0), "longitude": 0.0, "heading": 4.0}}
	authority.snapshot = {"ok": true, "money": 555, "revision": 1, "profile": {"ship": initial.duplicate(true), "stored_ships": [{"id": "new", "definition": "ship_coastal_container_01", "condition_bp": 9876, "wear_fraction_bp": 0.4, "fuel_liters": 0.0, "storage_port_id": "port_brindle_quay"}], "cargo": [], "jobs": []}}
	owner.restore_grant(authority.snapshot)
	owner.ship.set_physics_process(false)
	owner.ship.docked = true
	owner.operating_seconds = 36.0
	session.members[2] = {"hull": owner, "ship": "old", "epoch": 1, "generation": 1}
	ports.register(2, owner)
	ports.entries[2].state = "docked"; ports.entries[2].port_id = "port_brindle_quay"
	ports.reservations["port_brindle_quay"] = 2
	check((await fleet.execute(2, "missing")).code == "SHIP_NOT_STORED", "reject unowned ID")
	owner.cargo_records = [{"id": "cargo"}]
	check((await fleet.execute(2, "new")).code == "FLEET_LOADED", "loaded ship cannot despawn")
	owner.cargo_records = []
	owner.public_profile.jobs = [{"kind": "container_voyage_v1", "state": "loading"}]
	check((await fleet.execute(2, "new")).code == "FLEET_LOADED", "pending load blocks replacement")
	owner.public_profile.jobs = []
	owner.ship.docked = false
	check((await fleet.execute(2, "new")).code == "DOCK_FIRST", "switch only while docked")
	owner.ship.docked = true
	owner.damage_pending = true
	check((await fleet.execute(2, "new")).code == "BUSY", "pending damage must settle first")
	owner.damage_pending = false
	owner.public_profile.stored_ships[0].storage_port_id = "port_slatewater_works"
	check((await fleet.execute(2, "new")).code == "FLEET_WRONG_PORT", "cannot teleport between storage ports")
	owner.public_profile.stored_ships[0].storage_port_id = "port_brindle_quay"
	var size: Vector3 = owner.ship.definition.hull_size_m
	for port: String in fleet.slots:
		var p: Dictionary = fleet.slots[port][0]
		var at: Dictionary = session.Geo.normalized(p.latitude, p.longitude, p.heading)
		check(world.Ports.spawn_clear(at, size), "authored berth slot clears visible port solids " + port)
	var reserved := Node3D.new()
	session.add_child(reserved)
	world.spawn_reservations[reserved] = {"address": owner.current_address(), "size": size}
	var before: Dictionary = authority.snapshot.duplicate(true)
	check((await fleet.execute(2, "new")).code == "FLEET_SPACE_BUSY", "reservation prevents overlapping switches")
	check(authority.snapshot == before and owner.ship.state.instance_id == "old", "blocked spawn retains current hull and profile")
	world.spawn_reservations.clear()
	var blocker := Owner.new()
	session.add_child(blocker)
	blocker.set_process(false); blocker.set_physics_process(false)
	blocker.restore_grant(authority.snapshot, false)
	session.members[3] = {"hull": blocker}
	check((await fleet.execute(2, "new")).code == "FLEET_SPACE_BUSY", "actual nearby hull blocks replacement")
	check(authority.snapshot == before, "occupied hull causes no canonical mutation")
	session.members.erase(3); blocker.free()
	check((await fleet.execute(2, "new")).code == "FLEET_SWITCHED", "real bridge completes exchange")
	check(owner.ship.state.instance_id == "new" and session.members[2].ship == "new" and session.changed == 1, "active ID and peer notification updated")
	check(owner.ship.definition.id == "ship_coastal_container_01", "owned class handling installed before ready")
	check(owner.ship.state.fuel_liters == 0 and is_equal_approx(owner.ship.state.condition, .9876), "activation grants no fuel or repair")
	check(owner.ship.docked and ports.reservations.port_brindle_quay == 2, "empty purchase keeps service berth for paid fuel")
	check(owner.recovery_placing and owner.ship.collision_layer == 0, "new hull remains inert pending physical recheck")
	check(authority.snapshot.profile.stored_ships[0].condition_bp == 7653 and authority.snapshot.profile.stored_ships[0].wear_fraction_bp == .75, "pending and fractional wear retained")
	check(authority.snapshot.profile.stored_ships[0].fuel_liters == 123.25 and authority.snapshot.money == 555, "outgoing fuel and wallet preserved")
	check(world.spawn_reservations.is_empty(), "reservation released after canonical install")
	owner.recovery_placing = false
	owner.ship.set_physics_process(false)
	var stored_pose: Dictionary = authority.snapshot.profile.stored_ships[0].position.duplicate(true)
	world.spawn_reservations[reserved] = {"address": session.Geo.normalized(stored_pose.latitude, stored_pose.longitude, stored_pose.heading), "size": size}
	check((await fleet.execute(2, "old")).code == "FLEET_SPACE_BUSY", "saved transform blocked without fallback teleport")
	check(owner.ship.state.instance_id == "new", "saved spawn rejection leaves active ID intact")
	world.spawn_reservations.clear()
	check((await fleet.execute(2, "old")).code == "FLEET_SWITCHED", "switch back to damaged original")
	check(owner.ship.state.instance_id == "old" and owner.ship.state.fuel_liters == 123.25 and is_equal_approx(owner.ship.state.condition,.7653), "roundtrip cannot replenish fuel or heal")
	check(authority.snapshot.profile.ship.position == stored_pose, "stored canonical transform retained")
	check(owner.current_address().heading_deg > 3.99 and owner.current_address().heading_deg < 4.01, "heading restored to live hull")
	owner.recovery_placing = false
	owner.ship.set_physics_process(false)
	authority.unknown = true
	check((await fleet.execute(2, "new")).code == "OUTCOME_UNKNOWN" and not authority.active, "uncertain commit fences authority without retry")
	check(owner.ship.state.instance_id == "old" and world.spawn_reservations.is_empty(), "unknown result does not install guessed ship")
	# The actual fleet panel confirms a stable owned ID, blocks active/loaded entries.
	var panel = preload("res://features/catalog/fleet_inspection_panel.gd").new()
	root.add_child(panel)
	var data: Dictionary = {"fleet": [{"id": "owned", "definition": "ship_coastal_container_01", "active": false, "storage_port_id": "port_brindle_quay"}], "port": "port_brindle_quay", "cargo": 0, "job": {}}
	panel.refresh(data, true); panel.show()
	panel.selectors[0].select(panel.choices.size()-1); panel.refresh_details()
	check(not panel.activate.disabled, "stored local ship selectable")
	var sent: Array = []
	panel.activation_requested.connect(func(id: String): sent.append(id))
	panel.activate_selected()
	check(sent.is_empty(), "review click sends no mutation")
	check(panel.confirmation == "owned", "activation requires confirmation bound to owned ID")
	data.cargo = 1; panel.refresh(data, true)
	check(panel.activate.disabled and panel.confirmation.is_empty(), "cargo arrival cancels confirmation")
	data.cargo = 0; panel.refresh(data, true)
	panel.activate_selected(); panel.activate_selected()
	check(sent == ["owned"], "confirmed action sends only the selected owned ID")
	panel.free(); session.free()
	print("FLEET_SWITCH_PASS (%d checks)" % checks if failures == 0 else "FLEET_SWITCH_FAILED (%d/%d)" % [failures, checks])
	quit(0 if failures == 0 else 1)
