class_name BerthDefinition
extends ContentDefinition
@export var port_id: String = ""
@export var cargo_type_ids: Array[String] = []

@export var position_m: Vector3 = Vector3.ZERO
@export var heading_degrees: float = 0.0
@export var envelope_m: Vector3 = Vector3(24, 20, 100)
@export var service_ids: Array[String] = []
