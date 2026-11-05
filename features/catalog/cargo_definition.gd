class_name CargoDefinition
extends ContentDefinition
@export var unit_label: String = ""
@export_enum("count", "gram", "milliliter", "cubic_meter") var quantity_unit: String = "count"
@export var capacity_pool: String = "container_slots"
@export var gas_pipeline_type: String = ""
