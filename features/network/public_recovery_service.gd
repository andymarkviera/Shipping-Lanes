extends Node
## Game-server-only recovery placement. Clients submit no damage, price or position.
var session: Node
var reservations: Dictionary = {}
const OFFSETS = [0, 150, -150, 300, -300, 450, -450, 600]

func address(slot: int) -> Dictionary:
	return session.Geo.normalized(rad_to_deg(-350.0 / 100000.0), rad_to_deg(-float(OFFSETS[slot]) / 100000.0), 0)

func clear_slot(owner: Node3D, slot: int) -> bool:
	if reservations.has(slot): return false
	var at: Dictionary = address(slot)
	if not session.physics_world.Ports.spawn_clear(at, owner.ship.definition.hull_size_m): return false
	var size: Vector3 = owner.ship.definition.hull_size_m
	for other: Node3D in session.live_owners():
		if other == owner or other.recovery_required(): continue
		var other_size: Vector3 = other.ship.definition.hull_size_m
		var clearance: float = (Vector2(size.x, size.z).length() + Vector2(other_size.x, other_size.z).length()) * .5 + 2.0
		if session.Nav.separation(at, other.current_address()) < clearance: return false
	return true

func execute(peer: int, incident: String) -> Dictionary:
	if not session.members.has(peer): return {"ok": false, "code": "DISCONNECTED"}
	var owner: Node3D = session.members[peer].hull
	if owner.departing or not owner.authority.active: return {"ok": false, "code": "DISCONNECTED"}
	if owner.voyage_busy or owner.checkpoint_busy or owner.damage_pending or owner.authority.busy: return {"ok": false, "code": "BUSY"}
	if not owner.recovery_required() or owner.public_profile.recovery.id != incident: return {"ok": false, "code": "NO_RECOVERY"}
	var slot: int = -1
	for candidate: int in OFFSETS.size():
		if clear_slot(owner, candidate): slot = candidate; break
	if slot < 0: return {"ok": false, "code": "RECOVERY_SPACE_BUSY"}
	session.port_authority.release(peer)
	reservations[slot] = owner.authority.binding.account
	owner.voyage_busy = true
	var current: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
	var result: Dictionary = current
	if current.get("ok", false):
		result = await owner.authority.request(owner.authority.owned("recover", {"action_id": "recover_" + Crypto.new().generate_random_bytes(16).hex_encode(), "expected_revision": int(current.revision), "incident_id": incident, "slot": slot}))
	if owner.authority.active:
		var fresh: Dictionary = await owner.authority.request(owner.authority.owned("inspect"))
		if fresh.get("ok", false):
			owner.install_profile(fresh)
			if result.get("ok", false):
				var p: Dictionary = fresh.profile.ship.position
				var origin: Dictionary = session.Geo.normalized(owner.geographic_anchor.latitude, owner.geographic_anchor.longitude)
				owner.reframe(origin, session.Geo.normalized(p.latitude, p.longitude, p.heading))
				owner.ship.state.fuel_liters = float(fresh.profile.ship.fuel_liters)
				owner.freeze_wreck()
				owner.recovery_placing = true
				owner.placement_frame = Engine.get_physics_frames() + 2
		else: owner.authority.quiesce()
	reservations.erase(slot)
	owner.voyage_busy = false
	return result
