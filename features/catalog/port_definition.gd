class_name PortDefinition
extends ContentDefinition
@export var berth_ids: Array[String] = []

@export_file("*.tscn") var scene_path: String = ""
@export var service_ids: Array[String] = []
@export var spawn_position_m: Vector3 = Vector3.ZERO
@export var approach_position_m: Vector3 = Vector3.ZERO
@export var spawn_heading_degrees: float = 0.0
