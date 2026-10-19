extends Node
var failures: PackedStringArray = []
var count: int = 0
const Geo = preload("res://features/geography/geographic_address.gd")
const Fixture = preload("res://features/geography/geographic_fixture.gd")
func expect(condition: bool, message: String) -> void:
	count += 1
	if not condition:
		failures.append(message)
func _ready() -> void:
	var reflected: Dictionary = Geo.normalized(100.0, 20.0)
	expect(reflected.latitude_deg == 80.0 and reflected.longitude_deg == -160.0, "North reflection")
	reflected = Geo.normalized(-100.0, 20.0)
	expect(reflected.latitude_deg == -80.0 and reflected.longitude_deg == -160.0, "South reflection")
	expect(Geo.normalized(0.0, 540.0).longitude_deg == -180.0, "Seam has one spelling")
	expect(Geo.normalized(NAN, 0.0).is_empty() and Geo.normalized(0.0, INF).is_empty(), "Nonfinite input rejected")
	for marker: Dictionary in Fixture.markers():
		check_address(marker.address)
	for lat: float in [-90.0, -89.999, -60.0, 0.0, 45.0, 89.999, 90.0]:
		for lon: float in [-180.0, -179.999, -80.0, 0.0, 110.0, 179.999]:
			check_address(Geo.normalized(lat, lon, 123.456, 2.75))
	var a: Dictionary = Geo.normalized(10.0, 179.999)
	var b: Dictionary = Geo.normalized(10.0, -179.999)
	expect(abs(Geo.longitude_delta(a.longitude_deg, b.longitude_deg) - 0.002) < 0.00000001, "Adjacent across seam: %.12f, %.12f -> %.12f" % [Geo.longitude_delta(a.longitude_deg, b.longitude_deg), a.longitude_deg, b.longitude_deg])
	expect(Geo.angular_separation(a, b) < deg_to_rad(0.0021), "Globe seam neighbors")
	var travelled: float = 0.0
	var previous: float = 170.0
	for i: int in range(1, 361):
		var current: float = Geo.normalized(0.0, 170.0 + i).longitude_deg
		travelled += Geo.longitude_delta(previous, current)
		previous = current
	expect(abs(travelled - 360.0) < 0.000001 and previous == 170.0, "Synthetic full longitude circuit")
	var invalid: Dictionary = a.duplicate(true)
	invalid.content_revision = 2
	expect(Geo.decode(invalid).is_empty(), "Future revision rejected")
	invalid = a.duplicate(true)
	invalid.latitude_deg = "10"
	expect(Geo.decode(invalid).is_empty(), "Numeric strings rejected")
	invalid = a.duplicate(true)
	invalid.world_id = "another_world"
	expect(Geo.decode(invalid).is_empty(), "Wrong world rejected")
	invalid = a.duplicate(true)
	invalid.frame = "scene_local"
	expect(Geo.decode(invalid).is_empty(), "Transient frame rejected")
	invalid = a.duplicate(true)
	invalid.longitude_deg = 180.0
	expect(Geo.decode(invalid).is_empty(), "Noncanonical payload rejected")
	expect(Geo.from_globe(Vector3.ZERO).is_empty() and Geo.from_flat(0.0, 1.1).is_empty(), "Invalid projections rejected")
	for failure: String in failures:
		push_error(failure)
	print("GEOGRAPHY_CHECK_PASS (%d assertions)" % count if failures.is_empty() else "GEOGRAPHY_CHECK_FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)

func check_address(address: Dictionary) -> void:
	var restored: Dictionary = Geo.decode(JSON.parse_string(JSON.stringify(address)))
	expect(not restored.is_empty(), "JSON address accepted")
	if restored.is_empty():
		return
	expect(abs(restored.latitude_deg - address.latitude_deg) < 0.000000001 and abs(Geo.longitude_delta(restored.longitude_deg, address.longitude_deg)) < 0.000000001, "Scalar JSON precision")
	expect(restored.heading_deg == address.heading_deg and restored.altitude_m == address.altitude_m, "Orientation and altitude preserved")
	var uv: Dictionary = Geo.flat(address)
	var flat_back: Dictionary = Geo.from_flat(uv.u, uv.v)
	expect(abs(flat_back.latitude_deg - address.latitude_deg) < 0.000000001 and abs(Geo.longitude_delta(flat_back.longitude_deg, address.longitude_deg)) < 0.000000001, "Flat round trip")
	var globe_back: Dictionary = Geo.from_globe(Geo.globe(address), address.longitude_deg)
	expect(abs(globe_back.latitude_deg - address.latitude_deg) < 0.00001 and abs(Geo.longitude_delta(globe_back.longitude_deg, address.longitude_deg)) < 0.00001, "Float32 globe round trip")
	var frame: Basis = Geo.tangent_frame(address)
	expect(abs(frame.determinant() - 1.0) < 0.000001 and frame.is_equal_approx(frame.orthonormalized()), "Pole-safe orthonormal frame")
	var forward: Vector3 = Geo.forward(address)
	expect(forward.is_finite() and abs(forward.length() - 1.0) < 0.000001 and abs(forward.dot(frame.y)) < 0.000001, "Finite tangent heading")
