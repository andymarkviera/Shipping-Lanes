extends Node
const Contract = preload("res://features/contracts/record_contract.gd")
var count: int = 0
var failures: int = 0
var registry: DefinitionRegistry = DefinitionRegistry.new()
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures += 1
		push_error(message)
func rejected(text: String, field: String) -> void:
	var result: Dictionary = Contract.decode(text, registry)
	check(not result.ok and result.record.is_empty() and str(result.errors).contains(field), "Reject with field error: " + field)
func _ready() -> void:
	check(registry.load_definitions(PrototypeCatalog.RECORDS).is_empty(), "Trusted catalog")
	var fixtures: Dictionary = {}
	for kind: String in ["player","ship","job","inventory","operation","world"]:
		var text: String = FileAccess.get_file_as_string("res://features/contracts/fixtures/" + kind + ".json")
		var result: Dictionary = Contract.decode(text, registry)
		check(result.ok, "Valid fixture: " + kind + str(result.errors))
		if not result.ok: continue
		fixtures[kind] = result.record
		check(Contract.decode(JSON.stringify(result.record), registry).ok, "Canonical round trip: " + kind)
		for field: String in result.record.data:
			var bad: Dictionary = result.record.duplicate(true)
			bad.data[field] = null
			rejected(JSON.stringify(bad), "$.data." + field)
	if fixtures.size() != 6:
		get_tree().quit(1)
		return
	check(fixtures.ship.data.name == "", "Missing optional name defaults")
	for invalid: Variant in [-1, 1.5, true, "100", 9000000000001]:
		var bad: Dictionary = fixtures.player.duplicate(true)
		bad.data.wallet_minor = invalid
		rejected(JSON.stringify(bad), "wallet_minor")
	for version: int in [0, 2]:
		var bad: Dictionary = fixtures.player.duplicate(true)
		bad.schema_version = version
		rejected(JSON.stringify(bad), "schema_version")
	var bad: Dictionary = fixtures.player.duplicate(true)
	bad.protocol_version = 2
	rejected(JSON.stringify(bad), "protocol_version")
	bad = fixtures.ship.duplicate(true)
	bad.data.definition_id = "res://tools/storage_probe.gd"
	rejected(JSON.stringify(bad), "definition_id")
	bad = fixtures.ship.duplicate(true)
	bad.data.location.content_revision = true
	rejected(JSON.stringify(bad), "location")
	bad = fixtures.inventory.duplicate(true)
	bad.data.lines.append(bad.data.lines[0].duplicate(true))
	rejected(JSON.stringify(bad), "duplicate")
	bad = fixtures.job.duplicate(true)
	bad.data.unit = "gram"
	rejected(JSON.stringify(bad), "unit")
	bad = fixtures.operation.duplicate(true)
	bad.data.status = "committed"
	rejected(JSON.stringify(bad), "result")
	bad = fixtures.player.duplicate(true)
	bad.data.script = "res://tools/storage_probe.gd"
	rejected(JSON.stringify(bad), "unknown field")
	bad = fixtures.ship.duplicate(true)
	bad.data.name = "res://tools/storage_probe.gd"
	check(Contract.decode(JSON.stringify(bad), registry).ok, "Path-looking display text stays inert")
	bad = fixtures.player.duplicate(true)
	bad.erase("realm_id")
	rejected(JSON.stringify(bad), "realm_id")
	rejected("[gd_resource load_steps=2 format=3]", "invalid JSON")
	rejected("{", "invalid JSON")
	rejected("[]", "expected object")
	rejected(" ".repeat(65537), "exceeds")
	rejected("[".repeat(17) + "0" + "]".repeat(17), "nesting")
	print("CONTRACT_CHECK_PASS (%d checks)" % count if failures == 0 else "CONTRACT_CHECK_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
