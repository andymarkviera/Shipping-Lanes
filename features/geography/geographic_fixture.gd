class_name GeographicFixture
extends RefCounted
## Synthetic marker catalog, not the approved port catalog or physical scale.
static func markers() -> Array[Dictionary]:
	return [
		{"id": "marker_origin", "address": GeographicAddress.normalized(0.0, 0.0)},
		{"id": "marker_seam_east", "address": GeographicAddress.normalized(10.0, 179.999)},
		{"id": "marker_seam_west", "address": GeographicAddress.normalized(10.0, -179.999)},
		{"id": "marker_north", "address": GeographicAddress.normalized(90.0, 37.0, 120.0)},
		{"id": "marker_south", "address": GeographicAddress.normalized(-90.0, -81.0, 270.0)},
	]
