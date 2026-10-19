class_name CollisionCourse
extends Node3D
## Vertical prism colliders keep this planar prototype from climbing sloped rocks.
func solid_box(title: String, size: Vector3, at: Vector3, color: Color, heading: float = 0.0) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = title
	body.collision_layer = CollisionRules.SHORE
	body.collision_mask = CollisionRules.HULL | CollisionRules.CHARACTER
	body.position = at
	body.rotation.y = heading
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	return body

func _ready() -> void:
	# Course stays beyond the original gold-marker U-turn and starter berth.
	solid_box("HeadOnPier", Vector3(90, 6, 2), Vector3(0, 0, 300), Color("76695b"))
	solid_box("AngledPier", Vector3(3, 6, 90), Vector3(100, 0, 180), Color("76695b"), 0.4)
	solid_box("CoastWest", Vector3(80, 14, 220), Vector3(-260, 2, 220), Color("76695b"))
	solid_box("CoastNorth", Vector3(180, 14, 80), Vector3(-200, 2, 360), Color("847765"))
	solid_box("RockA", Vector3(22, 9, 18), Vector3(75, 1, 80), Color("76695b"), 0.35)
	solid_box("RockB", Vector3(18, 7, 25), Vector3(120, 0, 50), Color("847765"), -0.3)
