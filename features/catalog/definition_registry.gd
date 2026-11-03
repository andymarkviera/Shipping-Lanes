class_name DefinitionRegistry
extends RefCounted
## Transactional publication: a bad catalog never replaces the last valid one.
## Own copies; callers receive copies so editing cannot corrupt shared definitions.
var _records: Dictionary = {}

func get_definition(id: String) -> ContentDefinition:
	var record: ContentDefinition = _records.get(id)
	return record.duplicate(true) if record != null else null

func load_definitions(records: Array[ContentDefinition]) -> PackedStringArray:
	var errors: PackedStringArray = []
	var candidate: Dictionary = {}
	var pattern: RegEx = RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	for record: ContentDefinition in records:
		if record == null:
			errors.append("Null definition")
			continue
		if pattern.search(record.id) == null or record.display_name.strip_edges().is_empty():
			errors.append("Invalid ID or empty display name: " + record.id)
		if candidate.has(record.id):
			errors.append("Duplicate ID: " + record.id)
			continue
		candidate[record.id] = record.duplicate(true)
	for record: ContentDefinition in candidate.values():
		if record is ShipDefinition:
			if not record.handling_error().is_empty():
				errors.append(record.id + ": " + record.handling_error())
			if record.scene_path.is_empty() or not ResourceLoader.exists(record.scene_path, "PackedScene"):
				errors.append("Missing ship scene: " + record.id)
			validate_refs(record.id, record.cargo_type_ids, candidate, "cargo", errors)
			if record.handling_error().is_empty():
				for hold: Dictionary in record.bulk_holds.values():
					for cargo_id: String in hold.cargo_type_ids:
						var cargo: ContentDefinition = candidate.get(cargo_id)
						if not cargo is CargoDefinition or cargo.capacity_pool != "bulk_holds" or cargo.quantity_unit != "gram":
							errors.append("Invalid bulk commodity: " + cargo_id)
			if record.runtime_scene_path.is_empty() or not ResourceLoader.exists(record.runtime_scene_path, "PackedScene"):
				errors.append("Missing runtime ship scene: " + record.id)
		elif record is CargoDefinition:
			if record.quantity_unit not in ["count", "gram", "milliliter"] or record.capacity_pool.strip_edges().is_empty(): errors.append("Invalid cargo capacity rule: " + record.id)
			if record.capacity_pool == "bulk_holds" and record.quantity_unit != "gram": errors.append("Bulk quantities must use grams: " + record.id)
			if record.unit_label.strip_edges().is_empty():
				errors.append("Missing cargo unit: " + record.id)
		elif record is PortDefinition:
			validate_refs(record.id, record.berth_ids, candidate, "berth", errors)
			for berth_id: String in record.berth_ids:
				var berth: ContentDefinition = candidate.get(berth_id)
				if berth is BerthDefinition and berth.port_id != record.id:
					errors.append("Berth belongs to another port: " + berth_id)
		elif record is BerthDefinition:
			if not record.eligibility_error().is_empty(): errors.append(record.id + ": " + record.eligibility_error())
			var port: ContentDefinition = candidate.get(record.port_id)
			if not port is PortDefinition:
				errors.append("Missing or wrong-type port: " + record.id)
			elif not port.berth_ids.has(record.id):
				errors.append("Port does not list berth: " + record.id)
			validate_refs(record.id, record.cargo_type_ids, candidate, "cargo", errors)
		else:
			errors.append("Unsupported definition type: " + record.id)
	if records.is_empty():
		errors.append("Empty catalog")
	if errors.is_empty():
		_records = candidate
	return errors

func validate_refs(owner: String, ids: Array[String], candidate: Dictionary, kind: String, errors: PackedStringArray) -> void:
	if ids.is_empty():
		errors.append("Missing required " + kind + " references: " + owner)
	var seen: Dictionary = {}
	for id: String in ids:
		var record: ContentDefinition = candidate.get(id)
		var valid: bool = record is CargoDefinition if kind == "cargo" else record is BerthDefinition
		if not valid:
			errors.append("Missing or wrong-type " + kind + " reference: " + owner + " -> " + id)
		if seen.has(id):
			errors.append("Repeated reference: " + owner + " -> " + id)
		seen[id] = true
