class_name RecordContract
extends RefCounted
## Plain JSON only. Validation is not authentication, ownership or settlement.
const MAX_BYTES: int = 65536
const MAX_DEPTH: int = 16
const MAX_INTEGER: int = 9000000000000
const FIELDS: Dictionary = {
	"player": {"account_id":"id", "wallet_minor":"uint", "debt_minor":"uint"},
	"ship": {"owner_id":"id", "definition_id":"ship_definition", "fuel_ml":"uint", "inventory_id":"id", "location":"location", "name":"text"},
	"job": {"owner_id":"id", "cargo_id":"cargo_definition", "quantity":"positive", "unit":"enum:count,gram,milliliter", "origin_port_id":"port_definition", "destination_port_id":"port_definition", "status":"enum:offered,accepted,delivered,canceled", "expires_world_ms":"uint"},
	"inventory": {"owner_id":"id", "lines":"lines"},
	"operation": {"actor_id":"id", "action":"enum:test_transfer", "payload_sha256":"hash", "expected_revision":"uint", "status":"enum:pending,committed,rejected", "result_code":"enum:none,ok,conflict,denied", "committed_world_ms":"uint"},
	"world": {"content_world_id":"enum:world_coordinate_fixture", "content_revision":"positive", "clock_ms":"uint", "clock_policy":"enum:active_session_only", "authority":"enum:private_host,public_service"}
}
const DEFAULTS: Dictionary = {"ship": {"name":""}}

static func decode(text: String, registry: DefinitionRegistry) -> Dictionary:
	var errors: PackedStringArray = []
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return failed("$: record exceeds 65536 bytes")
	# Bound nesting before parsing; ignore braces inside quoted/escaped strings.
	var depth: int = 0
	var quoted: bool = false
	var escaped: bool = false
	for ch: String in text:
		if quoted:
			if escaped: escaped = false
			elif ch == "\\": escaped = true
			elif ch == '"': quoted = false
		elif ch == '"': quoted = true
		elif ch == "{" or ch == "[":
			depth += 1
			if depth > MAX_DEPTH: return failed("$: nesting exceeds 16")
		elif ch == "}" or ch == "]": depth -= 1
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return failed("$: invalid JSON at line %d" % parser.get_error_line())
	if not parser.data is Dictionary:
		return failed("$: expected object")
	var record: Dictionary = parser.data
	var common: Dictionary = {"schema_version":"positive", "protocol_version":"positive", "kind":"text", "id":"id", "revision":"uint", "realm_id":"id", "data":"object"}
	validate_fields(record, common, "$", registry, errors)
	if not errors.is_empty(): return result(errors, {})
	if record.schema_version != 1: errors.append("$.schema_version: unsupported; migration required")
	if record.protocol_version != 1: errors.append("$.protocol_version: unsupported; negotiate before processing")
	if not FIELDS.has(record.kind): errors.append("$.kind: unsupported record type")
	if not errors.is_empty(): return result(errors, {})
	var data: Dictionary = record.data
	if DEFAULTS.has(record.kind):
		for field: String in DEFAULTS[record.kind]:
			if not data.has(field): data[field] = DEFAULTS[record.kind][field]
	validate_fields(data, FIELDS[record.kind], "$.data", registry, errors)
	if not errors.is_empty(): return result(errors, {})
	if record.kind == "job" and data.cargo_id == "cargo_test_container" and data.unit != "count":
		errors.append("$.data.unit: containers require count")
	if record.kind == "operation":
		if (data.status == "committed" and data.result_code != "ok") or (data.status == "pending" and (data.result_code != "none" or data.committed_world_ms != 0)) or (data.status == "rejected" and (not data.result_code in ["conflict","denied"] or data.committed_world_ms != 0)):
			errors.append("$.data: inconsistent operation result")
	if record.kind == "world" and data.content_revision != 1:
		errors.append("$.data.content_revision: unknown catalog revision")
	return result(errors, record)

static func validate_fields(data: Dictionary, schema: Dictionary, path: String, registry: DefinitionRegistry, errors: PackedStringArray) -> void:
	for field: Variant in data:
		if not schema.has(field): errors.append(path + "." + str(field) + ": unknown field")
	for field: String in schema:
		var at: String = path + "." + field
		if not data.has(field): errors.append(at + ": required")
		else: validate_value(data[field], schema[field], at, registry, errors)

static func validate_value(value: Variant, type: String, path: String, registry: DefinitionRegistry, errors: PackedStringArray) -> void:
	var valid: bool = true
	match type:
		"uint", "positive":
			valid = (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= (1 if type == "positive" else 0) and value <= MAX_INTEGER
		"id", "hash":
			var regex: RegEx = RegEx.new()
			regex.compile("^[a-z][a-z0-9_]{0,63}$" if type == "id" else "^[a-f0-9]{64}$")
			valid = value is String and regex.search(value) != null
		"text":
			valid = value is String and value.length() <= 128
			if valid:
				for i: int in value.length():
					if value.unicode_at(i) < 32: valid = false
		"object": valid = value is Dictionary
		"location": valid = value is Dictionary and not GeographicAddress.decode(value).is_empty()
		"ship_definition", "cargo_definition", "port_definition":
			var definition: ContentDefinition = registry.get_definition(value) if value is String else null
			valid = (definition is ShipDefinition if type == "ship_definition" else definition is CargoDefinition if type == "cargo_definition" else definition is PortDefinition)
		"lines":
			valid = value is Array and value.size() <= 128
			if valid:
				var seen: Dictionary = {}
				for i: int in value.size():
					var line: Variant = value[i]
					var at: String = path + "[%d]" % i
					if not line is Dictionary:
						errors.append(at + ": expected object")
						continue
					validate_fields(line, {"cargo_id":"cargo_definition", "quantity":"positive", "unit":"enum:count,gram,milliliter"}, at, registry, errors)
					if line.get("cargo_id") is String:
						if seen.has(line.cargo_id): errors.append(at + ".cargo_id: duplicate inventory line")
						seen[line.cargo_id] = true
					if line.get("cargo_id") == "cargo_test_container" and line.get("unit") != "count": errors.append(at + ".unit: containers require count")
		_:
			valid = type.begins_with("enum:") and value is String and type.trim_prefix("enum:").split(",").has(value)
	if not valid: errors.append(path + ": expected " + type)

static func failed(message: String) -> Dictionary:
	return result(PackedStringArray([message]), {})

static func result(errors: PackedStringArray, record: Dictionary) -> Dictionary:
	return {"ok": errors.is_empty(), "errors": errors, "record": record if errors.is_empty() else {}}
