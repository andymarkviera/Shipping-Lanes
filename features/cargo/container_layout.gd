class_name ContainerLayout
extends Resource
## Container centres in the hull's visual coordinate system; no physics or save state.
@export var centres: PackedVector3Array = PackedVector3Array()
@export var container_size_m: Vector3 = Vector3(2.438, 2.59, 6.058)
@export var colors: PackedColorArray = PackedColorArray([Color("b56749"), Color("799c9c"), Color("c8a568")])

func valid() -> bool:
	if centres.is_empty() or centres.size() > 256 or colors.is_empty(): return false
	if not container_size_m.is_finite() or minf(container_size_m.x, minf(container_size_m.y, container_size_m.z)) <= 0: return false
	for centre: Vector3 in centres:
		if not centre.is_finite(): return false
	return true
