extends HandlingShip
var assembly: ShipAssembly

func _ready() -> void:
	super._ready()
	assembly = ShipAssembly.new()
	add_child(assembly)
	assembly.configure(self)
	ShipAssembly.box_collision(self, definition.hull_size_m, Vector3(0, 1, 0))
