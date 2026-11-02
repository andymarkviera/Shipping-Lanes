extends Node
## Dock-only canonical fleet exchange. Reservations cover asynchronous save/commit.
const Inspection = preload("res://features/catalog/fleet_inspection.gd")
var session: Node
var slots: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://services/public_authority/fleet_slots.json"))

func clear_at(owner: Node3D, position_: Dictionary, size: Vector3) -> bool:
	var at: Dictionary = session.Geo.normalized(position_.latitude, position_.longitude, position_.heading)
	if not session.physics_world.Ports.spawn_clear(at, size): return false
	return session.physics_world.clear_address(at, size, session.live_owners(), owner)

func execute(peer: int, ship_id: String) -> Dictionary:
	if not session.members.has(peer): return {"ok": false, "code": "DISCONNECTED"}
	var record: Dictionary = session.members[peer]
	var owner: Node3D = record.hull
	if owner.departing or not owner.authority.active: return {"ok": false, "code": "DISCONNECTED"}
	if owner.voyage_busy or owner.checkpoint_busy or owner.damage_pending or owner.recovery_placing or owner.authority.busy: return {"ok": false, "code": "BUSY"}
	if owner.recovery_required(): return {"ok": false, "code": "RECOVERY_REQUIRED"}
	var port: String = session.voyages.docked_port(peer)
	if port.is_empty(): return {"ok": false, "code": "DOCK_FIRST"}
	if not owner.cargo_records.is_empty() or not session.voyages.active(owner).is_empty(): return {"ok": false, "code": "FLEET_LOADED"}
	var target: Dictionary = {}
	for entry: Dictionary in owner.public_profile.get("stored_ships", []):
		if entry.id == ship_id: target = entry
	if target.is_empty(): return {"ok": false, "code": "SHIP_NOT_STORED"}
	if target.get("storage_port_id") != port: return {"ok": false, "code": "FLEET_WRONG_PORT"}
	var definition: ShipDefinition = Inspection.definition(str(target.definition))
	if definition == null or str(target.definition) not in ["ship_starter_container_01", "ship_coastal_container_01", "ship_swift_container_01"]: return {"ok": false, "code": "UNKNOWN_SHIP"}
	var slot: int = -1
	var position_: Dictionary = target.get("position", {}).duplicate(true)
	if position_.is_empty():
		for index: int in slots[port].size():
			if clear_at(owner, slots[port][index], definition.hull_size_m):
				slot = index
				position_ = slots[port][index].duplicate(true)
				break
	if position_.is_empty() or not clear_at(owner, position_, definition.hull_size_m): return {"ok": false, "code": "FLEET_SPACE_BUSY"}
	owner.voyage_busy = true
	# Keep the old hull/berth until durable success, with no simulated change in flight.
	owner.ship.simulation_paused = true
	var at: Dictionary = session.Geo.normalized(position_.latitude, position_.longitude, position_.heading)
	session.physics_world.spawn_reservations[owner] = {"address": at, "size": definition.hull_size_m}
	var result: Dictionary = await commit(owner, peer, port, ship_id, slot)
	if result.get("ok", false) and owner.authority.active:
		var fresh: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
		if not fresh.get("ok", false): owner.authority.quiesce()
		else:
			# Install even if the peer left while committing: departure must save the NEW hull.
			var leaving: bool = owner.departing
			var origin: Dictionary = session.Geo.normalized(owner.geographic_anchor.latitude, owner.geographic_anchor.longitude)
			owner.restore_grant(fresh, false)
			owner.departing = leaving
			var p: Dictionary = fresh.profile.ship.position
			owner.reframe(origin, session.Geo.normalized(p.latitude, p.longitude, p.heading))
			owner.ship.docked = not leaving
			owner.freeze_wreck()
			owner.recovery_placing = true
			owner.placement_frame = Engine.get_physics_frames() + 2
			record.ship = str(fresh.profile.ship.id)
			record.erase("fuel_quote"); record.erase("repair_quote"); record.erase("ship_quotes")
			if not leaving and session.members.get(peer) == record:
				session.fleet_changed(peer, record)
	else:
		if owner.authority.active and not owner.departing: owner.ship.simulation_paused = false
	session.physics_world.spawn_reservations.erase(owner)
	owner.voyage_busy = false
	return result

func commit(owner: Node3D, peer: int, port: String, ship_id: String, slot: int) -> Dictionary:
	var current: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
	if not current.get("ok", false): owner.authority.quiesce(); return current
	var address: Dictionary = owner.current_address()
	var elapsed: float = owner.operating_seconds
	var saved: Dictionary = await owner.authority.request(owner.authority.owned("checkpoint", {"operating_seconds": elapsed, "expected_revision": int(current.revision), "position": {"latitude": address.latitude_deg, "longitude": address.longitude_deg, "heading": address.heading_deg}, "fuel_liters": owner.ship.state.fuel_liters}))
	if not saved.get("ok", false): owner.authority.quiesce(); return saved
	owner.operating_seconds = maxf(0.0, owner.operating_seconds - elapsed)
	owner.public_profile.ship.condition_bp = int(saved.condition_bp)
	owner.ship.state.condition = int(saved.condition_bp) / 10000.0
	if owner.departing or not owner.authority.active or owner.damage_pending or session.voyages.docked_port(peer) != port: return {"ok": false, "code": "BUSY"}
	return await owner.authority.request(owner.authority.owned("fleet_switch", {"action_id": "fleet_" + Crypto.new().generate_random_bytes(16).hex_encode(), "expected_revision": int(saved.revision), "port_id": port, "ship_id": ship_id, "slot": slot}))
