class_name PrototypeCatalog
extends RefCounted
const RECORDS: Array[ContentDefinition] = [
	preload("res://features/catalog/records/starter_ship.tres"),
	preload("res://features/catalog/records/test_container.tres"),
	preload("res://features/catalog/records/test_port.tres"),
	preload("res://features/catalog/records/test_berth.tres"),
	preload("res://features/catalog/records/heavy_lifter.tres"),
	preload("res://features/catalog/records/test_industrial.tres"),
	preload("res://features/ports/brindle_quay.tres"),
	preload("res://features/ports/brindle_quay_berth.tres"),
	preload("res://features/ports/slatewater_works.tres"),
	preload("res://features/ports/slatewater_works_berth.tres"),
	preload("res://features/catalog/records/coastal_ship.tres"),
	preload("res://features/catalog/records/swift_ship.tres"),
	preload("res://features/catalog/records/bulk_grain.tres"),
	preload("res://features/catalog/records/bulk_coal.tres"),
	preload("res://features/catalog/records/bulk_ore.tres"),
	preload("res://features/catalog/records/bulk_limestone.tres"),
	preload("res://features/catalog/records/gas_lng.tres"),
	preload("res://features/catalog/records/gas_nitrogen.tres"),
	preload("res://features/catalog/records/gas_oxygen.tres"),
	preload("res://features/catalog/records/gas_argon.tres"),
	preload("res://features/catalog/records/oil.tres"),
	# Step 85 rehearsal records. Append only: checks address earlier rows by index.
	preload("res://features/catalog/records/bulk_salt.tres"),
	preload("res://features/catalog/records/harbor_ship.tres"),
	preload("res://features/ports/cinder_point.tres"),
	preload("res://features/ports/cinder_point_berth.tres"),
	# M4: the game's fourth port.
	preload("res://features/ports/gannet_light.tres"),
	preload("res://features/ports/gannet_light_berth.tres"),
	# Patch 2.1 item 3: the two polar ports.
	preload("res://features/ports/north_pole.tres"),
	preload("res://features/ports/north_pole_berth.tres"),
	preload("res://features/ports/south_pole.tres"),
	preload("res://features/ports/south_pole_berth.tres"),
	# Patch 2.2 item 1: container ships 2-5.
	preload("res://features/catalog/records/container_02_ship.tres"),
	preload("res://features/catalog/records/container_03_ship.tres"),
	preload("res://features/catalog/records/container_04_ship.tres"),
	preload("res://features/catalog/records/container_05_ship.tres"),
]

## Presentation lookups, so callers never switch on a literal record ID.
static func display_name(id: String, fallback: String = "") -> String:
	for record: ContentDefinition in RECORDS:
		if record.id == id: return record.display_name
	return id if fallback.is_empty() else fallback

static func short_name(id: String) -> String:
	return display_name(id).get_slice(" ", 0)

static func cargo_ids(capacity_pool: String) -> Array[String]:
	var ids: Array[String] = []
	for record: ContentDefinition in RECORDS:
		if record is CargoDefinition and record.capacity_pool == capacity_pool: ids.append(record.id)
	return ids
