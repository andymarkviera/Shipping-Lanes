extends Node3D
## Server-side live hull lifecycle. Network admission must authenticate before use.
const Client = preload("res://features/network/public_authority_client.gd")
const Hull = preload("res://features/ships/starter_container_01/starter_runtime.tscn")
const Geo = preload("res://features/geography/geographic_address.gd")
const Nav = preload("res://features/geography/navigation_experiment.gd")
var authority: Node
var ship: HandlingShip
var geographic_anchor: Dictionary = {}
var cargo_records: Array = []
var departing: bool = false

func _ready() -> void:
	authority = Client.new()
	add_child(authority)
	authority.fenced.connect(park)

func park() -> void:
	if ship == null: return
	ship.simulation_paused = true
	ship.set_physics_process(false)
	ship.commanded_throttle = 0
	ship.actual_throttle = 0
	ship.maneuver(0, 0)
	ship.velocity = Vector3.ZERO
	ship.yaw_rate = 0
	ship.collision_layer = 0
	ship.collision_mask = 0
	ship.visible = false

func acquire(request: Dictionary) -> Dictionary:
	var result: Dictionary = await authority.request(request)
	if result.get("ok", false) and authority.active:
		restore_grant(result)
	return result

func restore_grant(result: Dictionary) -> void:
	if ship != null:
		remove_child(ship)
		ship.queue_free()
	ship = Hull.instantiate()
	ship.simulation_paused = true
	add_child(ship)
	ship.state.instance_id = result.profile.ship.id
	ship.state.fuel_liters = result.profile.ship.fuel_liters
	geographic_anchor = result.profile.ship.position.duplicate(true)
	# Each owner currently has an isolated local chart. Shared world integration follows.
	ship.position = Vector3.ZERO
	ship.rotation.y = -deg_to_rad(geographic_anchor.heading)
	cargo_records = result.profile.cargo.duplicate(true)
	ship.simulation_paused = false
	departing = false

func begin_transfer(data: Dictionary) -> Dictionary:
	if departing or ship == null or not authority.permits({"account": data.get("account"), "epoch": data.get("epoch"), "generation": data.get("generation")}):
		return {"ok": false, "code": "LOCAL_QUIESCED"}
	departing = true
	park()
	var saved: Dictionary = await checkpoint_current()
	if not saved.get("ok", false): return saved
	var result: Dictionary = await authority.request(data)
	if not result.get("ok", false): authority.quiesce()
	return result

func current_address() -> Dictionary:
	# One mapping for both observer snapshots and durable checkpoints.
	var origin: Dictionary = Geo.normalized(geographic_anchor.latitude, geographic_anchor.longitude)
	var directed: Dictionary = origin.duplicate()
	directed.heading_deg = Geo.wrap_scalar(rad_to_deg(atan2(-ship.position.x, ship.position.z)), 0, 360)
	var address: Dictionary = Nav.travel(directed, Vector2(ship.position.x, ship.position.z).length())
	address.heading_deg = Geo.wrap_scalar(-rad_to_deg(ship.rotation.y + Nav.transport_rotation(origin, address)), 0, 360)
	return address

func checkpoint_current() -> Dictionary:
	# Caller freezes input/physics before committing final pose/fuel.
	var address: Dictionary = current_address()
	var current: Dictionary = await authority.request(authority.owned("inspect"))
	if not current.get("ok", false):
		authority.quiesce()
		return current
	var snapshot: Dictionary = {"expected_revision": int(current.revision), "position": {"latitude": address.latitude_deg, "longitude": address.longitude_deg, "heading": address.heading_deg}, "fuel_liters": ship.state.fuel_liters}
	var saved: Dictionary = await authority.request(authority.owned("checkpoint", snapshot))
	if not saved.get("ok", false):
		authority.quiesce()
		return saved
	return saved

func helm(candidate: Dictionary, throttle: float, rudder: float) -> bool:
	if departing or not authority.permits(candidate) or ship == null: return false
	if not is_finite(throttle) or not is_finite(rudder): return false
	ship.command_throttle(throttle)
	ship.maneuver(rudder, 0)
	return true
