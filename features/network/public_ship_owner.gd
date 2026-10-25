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
var checkpoint_busy: bool = false
var save_at_ms: int = 0
var last_saved_ms: int = 0
const SAVE_INTERVAL_MS: int = 10000

func _process(_delta: float) -> void:
	if ship == null or departing or not authority.active or checkpoint_busy or authority.busy: return
	if Time.get_ticks_msec() >= save_at_ms:
		save_at_ms = Time.get_ticks_msec() + SAVE_INTERVAL_MS
		checkpoint_current()

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

func restore_grant(result: Dictionary, activate: bool = true) -> void:
	if ship != null:
		remove_child(ship)
		ship.queue_free()
	ship = Hull.instantiate()
	ship.simulation_paused = true
	add_child(ship)
	# Public surface-navigation hulls must not slide above/below another hull.
	ship.axis_lock_linear_y = true
	ship.state.instance_id = result.profile.ship.id
	ship.state.fuel_liters = result.profile.ship.fuel_liters
	geographic_anchor = result.profile.ship.position.duplicate(true)
	# Admission starts paused until safe placement in a server physics group.
	ship.position = Vector3.ZERO
	ship.rotation.y = -deg_to_rad(geographic_anchor.heading)
	cargo_records = result.profile.cargo.duplicate(true)
	ship.simulation_paused = not activate
	departing = false
	save_at_ms = Time.get_ticks_msec() + SAVE_INTERVAL_MS

func reframe(origin: Dictionary, address: Dictionary) -> void:
	var old_origin: Dictionary = Geo.normalized(geographic_anchor.latitude, geographic_anchor.longitude)
	var old_transport: float = Nav.transport_rotation(old_origin, address)
	var new_transport: float = Nav.transport_rotation(origin, address)
	ship.velocity = ship.velocity.rotated(Vector3.UP, old_transport - new_transport)
	ship.position = Nav.local_position(origin, address)
	ship.rotation.y = -deg_to_rad(address.heading_deg) - new_transport
	geographic_anchor = {"latitude": origin.latitude_deg, "longitude": origin.longitude_deg, "heading": origin.heading_deg}

func begin_transfer(data: Dictionary) -> Dictionary:
	if departing or ship == null or not authority.permits({"account": data.get("account"), "epoch": data.get("epoch"), "generation": data.get("generation")}):
		return {"ok": false, "code": "LOCAL_QUIESCED"}
	departing = true
	park()
	while checkpoint_busy or authority.busy: await get_tree().process_frame
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
	if checkpoint_busy or authority.busy: return {"ok": false, "code": "LOCAL_BUSY"}
	checkpoint_busy = true
	var current: Dictionary = await authority.request(authority.owned("inspect"))
	if not current.get("ok", false):
		authority.quiesce()
		checkpoint_busy = false
		return current
	# Capture pose and fuel together after inspect; ordinary sailing stays live.
	var address: Dictionary = current_address()
	var snapshot: Dictionary = {"expected_revision": int(current.revision), "position": {"latitude": address.latitude_deg, "longitude": address.longitude_deg, "heading": address.heading_deg}, "fuel_liters": ship.state.fuel_liters}
	var saved: Dictionary = await authority.request(authority.owned("checkpoint", snapshot))
	if not saved.get("ok", false): authority.quiesce()
	else: last_saved_ms = Time.get_ticks_msec()
	checkpoint_busy = false
	return saved

func helm(candidate: Dictionary, throttle: float, rudder: float, lateral: float = 0.0) -> bool:
	if departing or not authority.permits(candidate) or ship == null or ship.docked: return false
	if not is_finite(throttle) or not is_finite(rudder) or not is_finite(lateral): return false
	ship.command_throttle(throttle)
	ship.maneuver(rudder, lateral)
	return true
