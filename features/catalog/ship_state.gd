class_name ShipState
extends RefCounted
## Per-instance mutable fixture. Save schema and authoritative actions come later.
var instance_id: String
var definition_id: String
var fuel_liters: float
var operations: RefCounted
var manifest: RefCounted
var cargo: Dictionary

func _init(ship_id: String, shared_definition_id: String, fuel: float = 0.0, initial_cargo: Dictionary = {}) -> void:
	instance_id = ship_id
	definition_id = shared_definition_id
	fuel_liters = fuel
	cargo = initial_cargo.duplicate(true)
