extends Node3D
## Presentation only: pooled instances follow the manifest, never create cargo.
var instances: MultiMeshInstance3D
var manifest: RefCounted
var shown_count: int = 0
var capacity: int = 0
var layout: ContainerLayout
## Patch 2.4 item 5: in the game the port cranes (container_cranes.gd) set
## crane_driven while the ship is docked. The manifest then only sets
## target_count and the cranes show or hide one slot at a time (set_slot).
var crane_driven: bool = false
var target_count: int = 0
var filled: PackedByteArray = PackedByteArray()

func configure(source: RefCounted, definition: ShipDefinition) -> void:
	layout = definition.container_layout
	if layout == null: return # Heavy industrial cargo keeps its existing lift visual.
	if not layout.valid():
		push_error("Invalid container visual layout for " + definition.id)
		return
	capacity = int(definition.cargo_capacities.get("container_slots", 0))
	if capacity <= 0 or capacity > layout.centres.size():
		push_error("Container layout does not cover ship capacity: " + definition.id)
		return
	manifest = source
	filled.resize(capacity)
	instances = MultiMeshInstance3D.new()
	instances.name = "Containers"
	instances.multimesh = MultiMesh.new()
	instances.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instances.multimesh.use_colors = true
	instances.multimesh.mesh = container_mesh(layout.container_size_m)
	instances.multimesh.instance_count = capacity
	instances.multimesh.visible_instance_count = 0
	for slot: int in capacity:
		instances.multimesh.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ZERO), layout.centres[slot]))
		instances.multimesh.set_instance_color(slot, layout.colors[slot % layout.colors.size()])
	add_child(instances)
	manifest.changed.connect(refresh)
	refresh()

func refresh() -> void:
	target_count = clampi(int(manifest.usage().get("container_slots", 0)), 0, capacity)
	if not crane_driven: show_first(target_count)

## The first count slots, the rest empty (the manifest view without cranes).
func show_first(count: int) -> void:
	instances.multimesh.visible_instance_count = capacity
	for slot: int in capacity: set_slot(slot, slot < count)
	instances.multimesh.visible_instance_count = count
	shown_count = count

## Shows or hides one container slot.
func set_slot(slot: int, on: bool) -> void:
	if filled[slot] == int(on): return
	filled[slot] = int(on)
	shown_count += 1 if on else -1
	var basis: Basis = Basis.IDENTITY if on else Basis.from_scale(Vector3.ZERO)
	instances.multimesh.set_instance_transform(slot, Transform3D(basis, layout.centres[slot]))

## Cranes take over: every slot is drawn and hidden ones are scaled to nothing.
func hand_to_cranes() -> void:
	crane_driven = true
	instances.multimesh.visible_instance_count = capacity

## Cranes let go: back to the plain manifest view.
func release_cranes() -> void:
	crane_driven = false
	refresh()

func slot_color(slot: int) -> Color:
	return layout.colors[slot % layout.colors.size()]

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
