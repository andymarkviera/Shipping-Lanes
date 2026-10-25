extends Node3D
## Presentation only: pooled instances follow the manifest, never create cargo.
var instances: MultiMeshInstance3D
var manifest: RefCounted
var shown_count: int = 0
var capacity: int = 0

func configure(source: RefCounted, definition: ShipDefinition) -> void:
	var layout: ContainerLayout = definition.container_layout
	if layout == null: return # Heavy industrial cargo keeps its existing lift visual.
	if not layout.valid():
		push_error("Invalid container visual layout for " + definition.id)
		return
	capacity = int(definition.cargo_capacities.get("container_slots", 0))
	if capacity <= 0 or capacity > layout.centres.size():
		push_error("Container layout does not cover ship capacity: " + definition.id)
		return
	manifest = source
	instances = MultiMeshInstance3D.new()
	instances.name = "Containers"
	instances.multimesh = MultiMesh.new()
	instances.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instances.multimesh.use_colors = true
	instances.multimesh.mesh = container_mesh(layout.container_size_m)
	instances.multimesh.instance_count = capacity
	instances.multimesh.visible_instance_count = 0
	for slot: int in capacity:
		instances.multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, layout.centres[slot]))
		instances.multimesh.set_instance_color(slot, layout.colors[slot % layout.colors.size()])
	add_child(instances)
	manifest.changed.connect(refresh)
	refresh()

func refresh() -> void:
	shown_count = clampi(int(manifest.usage().get("container_slots", 0)), 0, capacity)
	instances.multimesh.visible_instance_count = shown_count

static func container_mesh(size: Vector3) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(surface, size, Vector3.ZERO)
	# Shallow ribs and end-door bars keep the temporary boxes readable at boat scale.
	for side: float in [-1, 1]:
		for rib: int in 12:
			append_box(surface, Vector3(.055, size.y - .16, .10), Vector3(side * (size.x / 2 + .025), 0, -size.z / 2 + .3 + rib * (size.z - .6) / 11))
		for bar: float in [-.55, .55]:
			append_box(surface, Vector3(.055, size.y - .2, .065), Vector3(bar, 0, side * (size.z / 2 + .03)))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .85
	surface.set_material(material)
	return surface.commit()

static func append_box(surface: SurfaceTool, size: Vector3, centre: Vector3) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	surface.append_from(box, 0, Transform3D(Basis.IDENTITY, centre))
